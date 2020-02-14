#!/bin/bash
set -x

CONTAINER='openwrt_1'
IFACE=$1

function _usage {
  echo "$0 [interface_name]"
  exit 1
}

function _get_phy_from_dev {
  if [[ -f /sys/class/net/$IFACE/phy80211/name ]] ; then
    PHY=$(cat /sys/class/net/$IFACE/phy80211/name 2>/dev/null)
  else
    echo "$IFACE is not a valid phy80211 device"
    exit 1
  fi
}

# we need this because openwrt renames the interface
function _get_dev_from_phy {
  for dev in /sys/class/net/*; do
    test -f $dev/phy80211/name && phy=$(cat $dev/phy80211/name 2>/dev/null)
    if [[ "$phy" = "$1" ]]; then
      IFACE_NEW=$(basename $dev)
      break
    else
      IFACE_NEW=''
    fi
  done
}

function _cleanup {
  docker stop openwrt_1
  while [[ -z $IFACE_NEW ]]; do
    _get_dev_from_phy $PHY
    sleep 1
  done
  sudo ip link set dev $IFACE_NEW down
  sudo ip link set dev $IFACE_NEW name $IFACE
}

function main {
  test -z $IFACE && _usage

  _get_phy_from_dev
  nmcli dev set $IFACE managed no

  docker run --rm \
    --network=bridge \
    -p8080:80 -d \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --hostname openwrt\
    --name $CONTAINER openwrt

  pid=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)

  sudo iw phy "$PHY" set netns $pid

}

main
trap "_cleanup" EXIT
tail --pid=$pid -f /dev/null