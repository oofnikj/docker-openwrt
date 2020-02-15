config 'interface'    'loopback'
    option 'ifname'   'lo'
    option 'proto'    'static'
    option 'ipaddr'   '127.0.0.1'
    option 'netmask'  '255.0.0.0'
 
config 'interface'    'lan'
    option 'type'     'bridge'
    option 'ifname'   'eth0'
    option 'proto'    'static'
    option 'ipaddr'   "${NET_ADDR}"
    option 'gateway'  "${NET_GW}"
    option 'netmask'  "${NET_NETMASK}"