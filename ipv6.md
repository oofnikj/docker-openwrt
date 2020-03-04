# IPv6

IPv6 is not enabled by default in Docker. Since we are configuring our network inside the container all we need to do is add the following `sysctl`s:
```
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.all.forwarding=1
```
And leave the rest to OpenWrt.

It's recommended to generate a good random ULA prefix using something like https://simpledns.plus/private-ipv6 and setting `LAN6_PREFIX` to something other than the default.

## Bandwidth 

For bandwidth monitoring of ipv6 it may also be necessary to load the module `nf_conntrack_ipv6` on the host:
```
$ sudo modprobe nf_conntrack_ipv6
```

## Other
I noticed that my syslog was filled with the following line about every 3-5 seconds:
```
Tue Mar  3 23:39:26 2020 daemon.notice netifd: wan6 (5949): /lib/netifd/dhcpv6.script: line 14: can't create /proc/sys/net/ipv6/conf/eth1/mtu: Read-only file system
```

Every time ICMPv6 RA messages are received, `odhcp6c` triggers this script. Since we are running in Docker and can't modify `sysctl`s from inside the container, this error would be printed.

The <s>solution</s> workaround is to comment out any lines in `/lib/netifd/dhcpv6.script` that try to modify kernel parameters. See [etc/dhcpv6.script](./etc/dhcpv6.script).

Obviously this is an ugly hack but it works.
The other solution would be to run the container with `--privileged`, but that's a terrible idea.