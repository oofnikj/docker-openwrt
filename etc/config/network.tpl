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

config 'interface'    'wan'
    option 'ifname'   'eth1'
    option 'proto'    'dhcp'