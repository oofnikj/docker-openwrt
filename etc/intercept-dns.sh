#!/bin/sh 
###
# DNS interceptor
# iptables equivalent:
# sudo iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT
#
# can be applied by:
# $ cat intercept-dns.sh | docker exec -i openwrt_1 sh
###
uci -q delete firewall.dns_int
/sbin/uci batch <<EOF 
set firewall.dns_int="redirect"
set firewall.dns_int.name="Intercept-DNS"
set firewall.dns_int.src="lan"
set firewall.dns_int.src_dport="53"
set firewall.dns_int.family="ipv4"
set firewall.dns_int.proto="tcp udp"
set firewall.dns_int.target="DNAT"
set firewall.dns_int.dest='lan'
EOF
uci commit firewall
/etc/init.d/firewall restart