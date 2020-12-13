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
	echo "* removing host $LAN_DRIVER interface"
	if [[ $LAN_DRIVER != "bridge" ]] ; then
		sudo ip link del dev $LAN_IFACE
	elif [[ $LAN_PARENT =~ \. ]] ; then
		sudo ip link del dev $LAN_PARENT
	fi
	echo "* Rolling back ip address for main if"
	sudo service dhcpcd start
	sudo dhclient -r
	test $WIFI_ENABLED = 'false' || echo "* returning $WIFI_PHY to host"
	test $WIFI_ENABLED = 'false' || sudo iw phy "$WIFI_PHY" set netns 1
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
	local LAN_ARGS
	case $LAN_DRIVER in
		bridge)
			LAN_ARGS=""
		;;
		macvlan)
			LAN_ARGS="-o parent=$LAN_PARENT"
		;;
		ipvlan)
			LAN_ARGS="-o parent=$LAN_PARENT -o ipvlan_mode=l2"
		;;
		*)
			echo "invalid choice for LAN network driver"
			exit 1
		;;
	esac
	docker network create --driver $LAN_DRIVER \
		$LAN_ARGS \
		--subnet $LAN_SUBNET \
		$LAN_NAME || exit 1

	if [ ! -z "$WAN_PARENT" ]; then
		docker network create --driver macvlan \
			-o parent=$WAN_PARENT \
			$WAN_NAME || exit 1
	fi
}

function _set_hairpin() {
	test $WIFI_HAIRPIN = 'true' || return
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
	if ! docker inspect $IMAGE_TAG >/dev/null 2>&1; then
		echo "no image '$IMAGE_TAG' found, did you forget to run 'make build'?"
		exit 1

	elif docker inspect $CONTAINER >/dev/null 2>&1; then
		echo "* starting container '$CONTAINER'"
		docker start $CONTAINER || exit 1

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
		if [ ! -z "$WAN_PARENT" ]; then
			docker network connect $WAN_NAME $CONTAINER
		fi

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
	case $LAN_DRIVER in
		macvlan)
			echo "* setting up host $LAN_DRIVER interface"
			LAN_IFACE=macvlan0
			sudo ip link add $LAN_IFACE link $LAN_PARENT type $LAN_DRIVER mode bridge
			sudo ip link set $LAN_IFACE up
			sudo ip route add $LAN_SUBNET dev $LAN_IFACE
		;;
		ipvlan)
			echo "* setting up host $LAN_DRIVER interface"
			LAN_IFACE=ipvlan0
			sudo ip link add $LAN_IFACE link $LAN_PARENT type $LAN_DRIVER mode l2
			sudo ip link set $LAN_IFACE up
			sudo ip route add $LAN_SUBNET dev $LAN_IFACE
		;;
		bridge)
			LAN_ID=$(docker network inspect $LAN_NAME -f "{{.Id}}")
			LAN_IFACE=br-${LAN_ID:0:12}

			# test if $LAN_PARENT is a VLAN of $WAN_PARENT, create it if it doesn't exist and add it to the bridge
			local lan_array=(${LAN_PARENT//./ })
			if [[ ${lan_array[0]} = $WAN_PARENT ]] && ! ip link show $LAN_PARENT >/dev/null 2>&1 ; then
				sudo ip link add link ${lan_array[0]} name $LAN_PARENT type vlan id ${lan_array[1]}
			fi
			sudo ip link set $LAN_PARENT master $LAN_IFACE

			# Fix: Orignal code assumed pi would fetch new ip address from the openwrt
			# The only way it makes sense is when working with the pi as a `workstation` and not as network device.
			# Still, this is usable on workstation scenario but the pi should just have a static ip address that is the
			# First address of the segment (docker bride takes .1 which will become the `main` ip for the pi) 
			echo "* Release current IF address make sure dhcpcd does not come back and screw up ips for the host"
			sudo service dhcpcd stop
			sudo dhclient -r
			echo "* Removing eth0 ip address to prevent confusion with docker bridge"
			sudo ip addr flush dev eth0
		;;
		*)
			echo "invalid network driver type, must be 'bridge' or 'macvlan'"
			exit 1
		;;
	esac
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

	_reload_fw
	echo "* ready"
}

main
trap "_cleanup" EXIT
tail --pid=$pid -f /dev/null
