#!/bin/bash
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
  docker stop openwrt_1 >/dev/null
  echo "* cleaning up netns symlink"
  sudo rm -rf /var/run/netns/$CONTAINER
  echo "* removing DHCP lease"
  sudo dhcpcd -q -k "br-${LAN_ID:0:12}"
  echo -ne "* finished"
}

function _gen_config() {
  echo "* generating network config"
  set -a
  source $CONFIG_FILE
  _get_phy_from_dev
  for file in etc/config/*.tpl; do
    envsubst <${file} >${file%.tpl}
    docker cp ${file%.tpl} $CONTAINER:/${file%.tpl}
  done
  set +a
}

function _init_network() {
  echo "* setting up docker network"
  docker network create --driver bridge \
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
  docker inspect $BUILD_TAG >/dev/null 2>&1 || { echo "no image '$BUILD_TAG' found, did you forget to run 'make build'?"; exit 1; }
  
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
      --name $CONTAINER $BUILD_TAG >/dev/null
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

function main() {
  test -z $WIFI_IFACE && _usage
  cd "${SCRIPT_DIR}"
  _get_phy_from_dev
  _nmcli
  _create_or_start_container

  echo "* moving device $WIFI_PHY to docker network namespace"
  pid=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)
  sudo iw phy "$WIFI_PHY" set netns $pid

  echo "* creating netns symlink '$CONTAINER'"
  sudo mkdir -p /var/run/netns
  sudo ln -sf /proc/$pid/ns/net /var/run/netns/$CONTAINER

  _set_hairpin $WIFI_IFACE

  LAN_ID=$(docker network inspect $LAN_NAME -f "{{.Id}}")
  echo "* getting address via DHCP"
  sudo dhcpcd -q "br-${LAN_ID:0:12}"
  
  _reload_fw
  echo "* ready"
}

main
trap "_cleanup" EXIT
tail --pid=$pid -f /dev/null
