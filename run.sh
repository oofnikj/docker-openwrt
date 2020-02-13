#!/bin/bash
set -ex

CONTAINER='openwrt_1'
IFACE=$1
PHY=$(cat /sys/class/net/$IFACE/phy80211/name) || { echo "interface $IFACE not found"; exit 1; }

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


nmcli dev set $IFACE managed no
# sudo iw phy $PHY interface add $IFACE_AP type managed

docker run --rm -it \
  --network=bridge \
  -p8080:80 -d \
  --cap-add NET_ADMIN \
  --cap-add NET_RAW \
  --name $CONTAINER openwrt

pid=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)

sudo iw phy "$PHY" set netns $pid


trap "_cleanup" EXIT
cat
