#!/bin/bash

source .env

function _usage {
  echo "$0 [interface_name]"
  exit 1
}

function _get_phy_from_dev {
  if [[ -f /sys/class/net/$WIFI_IFACE/phy80211/name ]] ; then
    WIFI_PHY=$(cat /sys/class/net/$WIFI_IFACE/phy80211/name 2>/dev/null)
    echo "* got '$WIFI_PHY' for device '$WIFI_IFACE'"
  else
    echo "$WIFI_IFACE is not a valid phy80211 device"
    exit 1
  fi
}

function _cleanup {
  echo -e "\n* cleaning up..."
  echo "* stopping container"
  docker stop openwrt_1 >/dev/null
  echo -ne "* finished"
}

function _gen_config {
  echo "* generating network config"
  set -a
  source .env
  _get_phy_from_dev
  for file in etc/config/*.tpl; do
    envsubst < ${file} > ${file%.tpl}.gen
    docker cp ${file%.tpl}.gen $CONTAINER:/${file%.tpl}
  done
  set +a
}

function _init_network {
  echo "* setting up docker network"
  docker network create --driver macvlan \
    -o parent=$NET_PARENT \
    --gateway $NET_GW \
    --subnet $NET_SUBNET \
      $NET_NAME 2>/dev/null

  sudo ip link add macvlan0 link $NET_PARENT type macvlan mode bridge
  sudo ip addr add $NET_HOST/24 dev macvlan0
  sudo ip link set macvlan0 up
  sudo ip route add $NET_ADDR/32 dev macvlan0
}

function _create_or_start_container {
  docker inspect $CONTAINER >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo "* starting container '$CONTAINER'"
    docker start $CONTAINER
  else
    echo "* creating container $CONTAINER"
    docker create \
      --network $NET_NAME \
      --cap-add NET_ADMIN \
      --cap-add NET_RAW \
      --hostname openwrt\
      --name $CONTAINER openwrt >/dev/null

    _gen_config
    docker start $CONTAINER
  fi
}

function main {
  test -z $WIFI_IFACE && _usage

  _get_phy_from_dev

  echo "* setting interface '$WIFI_IFACE' to unmanaged"
  nmcli dev set $WIFI_IFACE managed no
  
  _init_network
  _create_or_start_container

  echo "* moving device $WIFI_PHY to docker network namespace"
  pid=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)
  sudo iw phy "$WIFI_PHY" set netns $pid

  echo "* ready"
}

main
trap "_cleanup" EXIT
tail --pid=$pid -f /dev/null