config globals globals
    option 'ula_prefix' 'auto'

config 'interface'    'loopback'
    option 'ifname'   'lo'
    option 'proto'    'static'
    option 'ipaddr'   '127.0.0.1'
    option 'netmask'  '255.0.0.0'
 
config 'interface'    'lan'
    option 'type'     'bridge'
    option 'ifname'   'eth0'
    option 'proto'    'static'
    option 'ipaddr'   "${LAN_ADDR}"
    option 'gateway'  "${LAN_GW}"
    option 'netmask'  "${LAN_NETMASK}"
    option 'ip6assign' 64

config 'interface'    'wan'
    option 'ifname'   'eth1'
    option 'proto'    'dhcp'

config 'interface'    'wan6'
    option 'ifname'   'eth1'
    option 'proto'    'dhcpv6'
