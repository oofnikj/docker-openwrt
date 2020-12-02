# Monitoring with InfluxDB + Grafana

![[11858]](https://grafana.com/api/dashboards/11858/images/7666/image)
https://grafana.com/grafana/dashboards/11858

A `docker-compose` script for ingesting `collectd` output from OpenWrt to InfluxDB, using Grafana to build pretty dashboards.

**NOTE**: Docker assigns IP addresses to containers sequentially. By default, OpenWrt assigns DHCP addresses with an offset of 100, so there is a very minimal chance that the Docker-assigned addresses will overlap with the OpenWrt DHCP range, unless you change the default LAN DHCP range (or run more than 100 additional containerized services...).


## Steps

### On host

* Create a `.env` file based on the provided example (modify according to your needs)
* launch InfluxDB and Grafana
```
$ docker-compose up -d
```

### On OpenWrt
* Access the OpenWrt shell either by running `docker exec -it openwrt_1 sh -l` from the host, or SSHing directly in to OpenWrt from the LAN network
* Install `collectd` and any additional plugins you want (`collectd-mod-*`) on OpenWrt, plus `luci-app-statistics` for configuration from LuCI
```
# opkg install luci-app-statistics collectd
```

* Set up network export
```
# export INFLUXDB_ADDRESS=<your InfluxDB IP address>
# uci batch <<EOF
set luci_statistics.influxdb=collectd_network_server
set luci_statistics.influxdb.port='25826'
set luci_statistics.influxdb.host="${INFLUXDB_ADDRESS}"
EOF
# uci commit
# /etc/init.d/luci_statistics restart
```

* Define a static hostname for Grafana (optional)
```
# uci batch <<EOF 
add dhcp domain
set dhcp.@domain[-1].name=grafana
set dhcp.@domain[-1].ip=${INFLUXDB_ADDRESS}
EOF
# uci commit
# /etc/init.d/dnsmasq reload