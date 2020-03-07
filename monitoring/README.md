# Monitoring with InfluxDB + Grafana

![[11858]](https://grafana.com/api/dashboards/11858/images/7666/image)
https://grafana.com/grafana/dashboards/11858

A `docker-compose` script for ingesting `collectd` output from OpenWRT to InfluxDB, and using Grafana to build pretty dashboards.

Docker assigns IP addresses sequentially. By default OpenWRT assigns DHCP addresses with an offset of 100, so we have a very high chance that the Docker-assigned addresses will not overlap the OpenWRT DHCP addresses. But it's something we need to be aware of.


## Steps

### On host

* launch InfluxDB and Grafana
```
$ docker-compose up -d
```

* get InfluxDB IP address
```
$ INFLUXDB_HOST=$(docker inspect monitoring_influxdb_1 -f '
  {{- range .NetworkSettings.Networks}}
  {{- .IPAddress -}}
  {{end -}}')

$ echo $INFLUXDB_HOST
```

### On OpenWRT
* Install `collectd` and any additional plugins you want (`collectd-mod-*`) on OpenWRT, plus `luci-app-statistics` for configuration from LuCI
```
# opkg install luci-app-statistics collectd
```

* Set up network export (make sure `INFLUXDB_HOST` from above is set)
```
# cat <<EOF | uci batch
set luci_statistics.influxdb=collectd_network_server
set luci_statistics.influxdb.port='25826'
set luci_statistics.influxdb.host="${INFLUXDB_HOST}"
EOF
# uci commit
# /etc/init.d/luci_statistics restart
```