# OpenWRT in Docker

Inspired by other projects that run `hostapd` in a Docker container. This goes one step further and boots a full network OS intended for embedded devices called [OpenWRT](https://openwrt.org/), so you can manage all aspects of your network from a user-friendly web UI.

I only tested this on x86_64, but it might work on ARM too with some minor tweaking.


## Dependencies

* docker
* iw
* iproute2
* envsubst (part of `gettext` or `gettext-base` package)
* dhcpcd

## Build
```
$ make build
```
If you want additional OpenWRT packages to be present in the base image, add them to the Dockerfile. Otherwise you can install them with `opkg` after bringing up the container.

A searchable package list is available on [openwrt.org](https://openwrt.org/packages/table/start).

## Configure

Configuration is performed using a config file, `openwrt.conf`. Values read from this file at runtime are used to generate OpenWRT format config files.

To add or change a configuration, modify the config templates in `etc/config/<section>.tpl`.

## Run
```
$ make run
```

If you're lucky, browse to http://openwrt.home (or whatever you set in `LAN_DOMAIN`) and you should be presented with the login page. The default login is `root` with the password set as ${ROOT_PW}.

To shut down the router, press `Ctrl+C`. Any settings you configured or additional packages you installed will persist until you run `make clean`, which will delete the container.

## Cleanup
```
$ make clean
```
This will delete the container and all associated Docker networks so you can start fresh if you screw something up.

## Notes

### Hairpinning

This took a couple of tries to get working. The most challenging issue was getting traffic from WLAN clients to reach each other.

In order for this to work, OpenWRT bridges all interfaces in the LAN zone and sets hairpin mode (aka [reflective relay](https://lwn.net/Articles/347344/)) on the WLAN interface, meaning packets arriving on that interface can be 'reflected' back out through the same interface.
OpenWRT is not able to set this mode from inside the container even with `NET_ADMIN` capabilities, so this must be done from the host. 

`run.sh` tries to handle this, and prints a warning if it fails.

### Network namespace

For `hostapd` running inside the container to have access to the physical wireless device, we need to set the device's network namespace to the PID of the running container. This causes the interface to 'disappear' from the primary network namespace for the duration of the container's parent process. `run.sh` checks if the host is using NetworkManager to manage the wifi interface, and tries to steal it away if so.

### Troubleshooting

Logs are redirected to `stdout` so the Docker daemon can process them. They are accessible with:
```
$ docker logs ${CONTAINER} [-f]
```

As an alternative to installing debug packages inside your router, it's possible to execute commands available to the host inside the network namespace. A symlink is created in `/var/run/netns/<container_name>` for convenience:

```
$ sudo ip netns exec ${CONTAINER} tcpdump -vvi any 
```