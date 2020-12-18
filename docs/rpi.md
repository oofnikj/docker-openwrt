# Raspberry Pi Instructions

Turn your Pi into a pretty okay-ish travel router (or a very slow main router)!

OpenWrt officially supports Raspberry Pi hardware if you want to run it as your primary OS. But running in a container brings many advantages, one of which is not having to re-flash your SD card if you already have some services running.

Pre-built images are available on Docker Hub. These images have been tested on a Zero W and Pi 4 running Raspberry Pi OS, but should work for other versions too. Refer to the table below (and the notes in [openwrt.conf](../openwrt.conf.example)) to choose the right image for your hardware.

Set the `IMAGE` and `TAG` variables in openwrt.conf accordingly, replacing `<version>` with the desired release version (e.g. "19.07.5") or "snapshot" for the latest development snapshot:

| RPi version              | image:tag                             |
|--------------------------|---------------------------------------|
| Pi A / B / B+ / Zero W   | `oofnik/openwrt:<version>-bcm2708`    |
| Pi 2 / 3 / 4 (32-bit OS) | `oofnik/openwrt:<version>-armvirt-32` |
| Pi 3 / 4 (64-bit OS)     | `oofnik/openwrt:<version>-armvirt-64` |


---
## Build 
You can build the OpenWrt Docker image yourself on the Pi, or on your x86 PC with `qemu-user` and `binfmt-support` installed. The image will be built according to the parameters `OPENWRT_SOURCE_VER`, `ARCH`, `IMAGE` and `TAG` (see [openwrt.conf](../openwrt.conf.example) for documentation). Packages `fakeroot` and `squashfs-tools` must be installed.

```shell
$ make build
```

If you built the image on your PC, send it to your Raspberry Pi over SSH:
```
$ docker save $IMAGE:$TAG | ssh <your_raspberry_pi_host> docker load
```

## IPv6
By default Raspberry Pi OS does not load the kernel module for IPv6 `iptables` on boot.

Run `sudo modprobe ip6_tables` to load it immediately.

To persist on reboot, run

    $ echo 'ip6_tables' | sudo tee /etc/modules-load.d/ip6-tables.conf

## DHCP
Raspberry Pi OS ships with a default `dhcpcd` configuration that assigns a DHCP address to every new interface added to the system including virtual ones.

This is not necessarily what we want. Instead we would like to limit the interfaces `dhcpcd` watches to only the physical ones, i.e., interfaces `eth*` and `wl*`:

```
$ echo 'allowinterfaces eth* wl*' | sudo tee -a /etc/dhcpcd.conf
$ sudo dhcpcd -n
```