config dnsmasq
        option domainneeded '1'
        option localise_queries '1'
        option local "/${LAN_DOMAIN}/"
        option domain "${LAN_DOMAIN}"
        option expandhosts '1'
        option authoritative '1'
        option readethers '1'
        option leasefile '/tmp/dhcp.leases'
        option localservice '1'
        option rebind_protection '1'
        option rebind_domain "${LAN_DOMAIN}"
        list server "${UPSTREAM_DNS_SERVER}"

config dhcp 'lan'
        option interface 'lan'
        option start '100'
        option limit '150'
        option leasetime '12h'
        option dhcpv6 'server'
        option ra 'server'
        option ndp 'hybrid'

config dhcp 'wan'
        option ignore       '1'
        option interface    'wan'
        option dhcpv6       'relay'
        option ra           'relay'
        option ndp          'relay'
        option master       '1'

config odhcpd 'odhcpd'
        option maindhcp '0'
        option leasefile '/tmp/hosts/odhcpd'
        option leasetrigger '/usr/sbin/odhcpd-update'
        option loglevel '4'
