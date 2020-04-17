# Bandwidth Monitoring

OpenWRT comes with a decent selection of traffic monitoring tools, both CLI and web UI. I use `nlbwmon`, which integrates well with the web interface and creates pretty graphs. Here's how to install it.

## Enable conntrack accounting

`nlbwmon` uses the Linux netfilter conntrack subsystem to track connections and packet counts, so you need to make sure the `nf_conntrack` kernel module is loaded on your host system (it probably is). But just to check:
```
$ lsmod | grep nf_conntrack
```

Conntrack accounting is off by default, so we have to enable it inside the container:
```
$ sudo ip netns exec ${CONTAINER} sysctl -w net.netfilter.nf_conntrack_acct=1
```
Alternatively this can be enabled when creating the container by adding the flag
```
--sysctl net.netfilter.nf_conntrack_acct=1
```
to the `docker create` command in `run.sh`.

## Install packages
Inside the container:
```
# opkg install nlbwmon luci-app-nlbwmon
# service nlbwmon enable
# service nlbwmon start
```

There should now be a "Bandwidth Monitor" section in LuCI.

## Configuration
The default configuration is extremely conservative with storage. Since we're not running on a device with 4MB flash storage, we can increase the defaults:

```
# cat <<EOF | uci import
package nlbwmon
config nlbwmon
	option  refresh_interval      '30s'
	option  database_directory    '/var/lib/nlbwmon'
	option  database_interval     '1'
	option  protocol_database     '/usr/share/nlbwmon/protocols'
	option  commit_interval       '60s'
	option  database_limit        '0'
	option  database_generations  '0'
	list    local_network         "${LAN_SUBNET}"
	list    local_network         'lan'
EOF
# service nlbwmon restart
```

For a more complex (and useful) solution, see [Monitoring with InfluxDB + Grafana](../monitoring/README.md)