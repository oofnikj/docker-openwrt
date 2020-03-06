# Monitoring with InfluxDB + Grafana

A `docker-compose` script for ingesting `collectd` output from OpenWRT to InfluxDB, and using Grafana to build pretty dashboards.

It's networked, so it doesn't need to be run on the same machine as OpenWRT, but it probably should.


## Steps

### On OpenWRT
* Install `collectd` and any additional plugins you want (`collectd-mod-*`) on OpenWRT, plus `luci-app-statistics` for configuration from LuCI
```
# opkg install luci-app-statistics collectd
```

* Set up network export (make sure `LAN_HOST` is set)
```
# cat <<EOF | uci batch
set luci_statistics.influxdb=collectd_network_server
set luci_statistics.influxdb.port='25826'
set luci_statistics.influxdb.host="${LAN_HOST}"
EOF
$ uci commit
$ /etc/init.d/luci_statistics restart
```
### On host
* get `types.db` (not sure if this is totally necessary)
```
$ scp openwrt.home:/usr/share/collectd/types.db \
  influxdb/
```

* from the host, launch InfluxDB and Grafana
```
$ docker-compose up -d
```
