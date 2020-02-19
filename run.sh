#!/bin/bash
# set -x 

source .env

function _usage() {
  echo "$0 [interface_name]"
  exit 1
}

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
  source .env
  _get_phy_from_dev
  for file in etc/config/*.tpl; do
    envsubst <${file} >${file%.tpl}
    docker cp ${file%.tpl} $CONTAINER:/${file%.tpl}
  done
  set +a
}

function _init_network() {
  echo "* setting up docker network"
  LAN_ID=$(docker network create --driver bridge \
    --subnet $LAN_SUBNET \
    $LAN_NAME)

  WAN_ID=$(docker network create --driver macvlan \
    -o parent=$WAN_PARENT \
    --subnet $WAN_SUBNET \
    $WAN_NAME)
}

function _create_or_start_container() {
  docker inspect $CONTAINER >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
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
      --ip $LAN_ADDR \
      --sysctl net.ipv4.conf.default.arp_ignore=1 \
      --name $CONTAINER openwrt >/dev/null
    docker network connect $WAN_NAME $CONTAINER

    _gen_config
    docker start $CONTAINER
  fi
}

function main() {
  test -z $WIFI_IFACE && _usage

  _get_phy_from_dev
  _nmcli
  _create_or_start_container

  echo "* moving device $WIFI_PHY to docker network namespace"
  pid=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)
  sudo iw phy "$WIFI_PHY" set netns $pid

  echo "* creating netns symlink '$CONTAINER'"
  sudo mkdir -p /var/run/netns
  sudo ln -sf /proc/$pid/ns/net /var/run/netns/$CONTAINER


  echo "* set hairpin mode on wifi interface"
  for _ in {1..10}; do
    sudo ip netns exec $CONTAINER ip link set $WIFI_IFACE type bridge_slave hairpin on && break
    sleep 1
  done

  echo "* getting address via DHCP"
  sudo dhcpcd -q --noarp "br-${LAN_ID:0:12}"
  
  echo "* ready"
}

main
trap "_cleanup" EXIT
tail --pid=$pid -f /dev/null
