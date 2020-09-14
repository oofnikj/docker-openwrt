#!/usr/bin/env bash
# set -x 

function _usage() {
  echo "Could not find config file."
  echo "Usage: $0 [/path/to/openwrt.conf]"
  exit 1
}

SCRIPT_DIR=$(cd $(dirname $0) && pwd )
DEFAULT_CONFIG_FILE=$SCRIPT_DIR/openwrt.conf
CONFIG_FILE=${1:-$DEFAULT_CONFIG_FILE}
source $CONFIG_FILE 2>/dev/null || { _usage; exit 1; }

function _nmcli() {
  type nmcli >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo "* setting interface '$WIFI_IFACE' to unmanaged"
    nmcli dev set $WIFI_IFACE managed no
    nmcli radio wifi on
  fi
}

function _get_phy_from_dev() {
  test $WIFI_ENABLED = 'true' || return
  test -z $WIFI_PHY || return
  if [[ -f /sys/class/net/$WIFI_IFACE/phy80211/name ]]; then
    WIFI_PHY=$(cat /sys/class/net/$WIFI_IFACE/phy80211/name 2>/dev/null)
    echo "* got '$WIFI_PHY' for device '$WIFI_IFACE'"
  else
    echo "$WIFI_IFACE is not a valid phy80211 device"
    exit 1
  fi
}

function _cleanup() {
  echo -e "\n* cleaning up..."
  echo "* stopping container"
  docker stop $CONTAINER >/dev/null
  echo "* cleaning up netns symlink"
  sudo rm -rf /var/run/netns/$CONTAINER
  if [[ $LAN_DRIVER = "macvlan" ]] ; then
    echo "* removing host macvlan interface"
    sudo ip link del dev macvlan0
  fi
  echo -ne "* finished"
}

function _gen_config() {
  echo "* generating network config"
  set -a
  _get_phy_from_dev
  source $CONFIG_FILE
  for file in etc/config/*.tpl; do
    envsubst <${file} >${file%.tpl}
    docker cp ${file%.tpl} $CONTAINER:/${file%.tpl}
  done
  set +a
}

function _init_network() {
  echo "* setting up docker network"
  docker network create --driver $LAN_DRIVER \
    -o parent=$LAN_PARENT \
    --subnet $LAN_SUBNET \
    $LAN_NAME || exit 1

  docker network create --driver macvlan \
    -o parent=$WAN_PARENT \
    $WAN_NAME || exit 1
}

function _set_hairpin() {
  echo -n "* set hairpin mode on interface '$1'"
  for i in {1..10}; do
    echo -n '.'
    sudo ip netns exec $CONTAINER ip link set $WIFI_IFACE type bridge_slave hairpin on 2>/dev/null && { echo 'ok'; break; }
    sleep 3
  done
  if [[ $i -ge 10 ]]; then
    echo -e "\ncouldn't set hairpin mode, wifi clients will probably be unable to talk to each other"
  fi
}

function _create_or_start_container() {
  docker inspect $IMAGE_TAG >/dev/null 2>&1 || { echo "no image '$IMAGE_TAG' found, did you forget to run 'make build'?"; exit 1; }
  
  if docker inspect $CONTAINER >/dev/null 2>&1; then
    echo "* starting container '$CONTAINER'"
    docker start $CONTAINER
  else
    _init_network
    echo "* creating container $CONTAINER"
    docker create \
      --network $LAN_NAME \
      --cap-add NET_ADMIN \
      --cap-add NET_RAW \
      --hostname openwrt \
      --dns 127.0.0.1 \
      --ip $LAN_ADDR \
      --sysctl net.netfilter.nf_conntrack_acct=1 \
      --sysctl net.ipv6.conf.all.disable_ipv6=0 \
      --sysctl net.ipv6.conf.all.forwarding=1 \
      --name $CONTAINER $IMAGE_TAG >/dev/null
    docker network connect $WAN_NAME $CONTAINER

    _gen_config
    docker start $CONTAINER
  fi
}

function _reload_fw() {
  echo "* reloading firewall rules"
  docker exec -i $CONTAINER sh -c '
    for iptables in iptables ip6tables; do
      for table in filter nat mangle; do
        $iptables -t $table -F
      done
    done
    /sbin/fw3 -q restart'
}

function _prepare_wifi() {
  test $WIFI_ENABLED = 'true' || return
  test -z $WIFI_IFACE && _usage
  _get_phy_from_dev
  _nmcli
  echo "* moving device $WIFI_PHY to docker network namespace"
  sudo iw phy "$WIFI_PHY" set netns $pid
  _set_hairpin $WIFI_IFACE
}

function _prepare_lan() {
  if [[ $LAN_DRIVER == "macvlan" ]] ; then
    echo "* setting up host macvlan interface"
    LAN_IFACE=macvlan0
    sudo ip link add $LAN_IFACE link $LAN_PARENT type macvlan mode bridge
    sudo ip link set $LAN_IFACE up
    sudo ip route add $LAN_SUBNET dev $LAN_IFACE
  elif [[ $LAN_DRIVER == "bridge" ]] ; then
    LAN_ID=$(docker network inspect $LAN_NAME -f "{{.Id}}")
    LAN_IFACE=br-${LAN_ID:0:12}
  else
    echo "invalid network driver type, must be 'bridge' or 'macvlan'"
    exit 1
  fi
}

function main() {
  cd "${SCRIPT_DIR}"
  _create_or_start_container

  pid=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)

  echo "* creating netns symlink '$CONTAINER'"
  sudo mkdir -p /var/run/netns
  sudo ln -sf /proc/$pid/ns/net /var/run/netns/$CONTAINER

  _prepare_wifi
  _prepare_lan
  
  echo "* getting address via DHCP"
  sudo dhcpcd -q $LAN_IFACE
  
  _reload_fw
  echo "* ready"
}

main
trap "_cleanup" EXIT
tail --pid=$pid -f /dev/null
