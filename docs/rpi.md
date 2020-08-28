# Building on Raspberry Pi

Turn your Pi into a pretty okay-ish travel router (or a very slow main router)!

OpenWrt officially supports Raspberry Pi hardware if you want to run it as your OS. But running in a container brings many advantages, one of which is not having to re-flash your SD card.

This has been tested on a Raspberry Pi Zero W running Raspbian Lite, but should work for other versions too. Just make sure you download the right image for your Pi version (refer to the notes in [build-rpi.sh](./build-rpi.sh)).

**UPDATE 2020-08-28**: Pre-built images are now available on Docker Hub! Refer to the table below to choose the right image. Set the `BUILD_TAG` parameter in openwrt.conf accordingly:

| RPi version             | image:tag                |
|------------------------|---------------------------|
| Pi A / B / B+ / Zero W | `oofnik/openwrt:rpi-zero` |
| Pi 2 B (all)           | `oofnik/openwrt:rpi2`     |
| Pi 3 B / B+            | `oofnik/openwrt:rpi3`     |
| Pi 4 / 4B              | `oofnik/openwrt:rpi4`     |

---
## Build 
You can build the OpenWRT docker image on the Pi itself, or on your x86 PC with `qemu-user` and `binfmt-support` installed.

First download and extract the OpenWRT factory image for your Pi. Refer to the [OpenWrt Table of Hardware](https://openwrt.org/toh/raspberry_pi_foundation/raspberry_pi) to choose the right image. Then run the `make` target as root (need access to mount loop filesystems).

The variable `RPI_SOURCE_IMG` can be specified in openwrt.conf or on the command line:
```
$ wget https://downloads.openwrt.org/releases/19.07.3/targets/brcm2708/bcm2708/openwrt-19.07.3-brcm2708-bcm2708-rpi-ext4-factory.img.gz -O image.img.gz
$ gzip -d image.img.gz
$ sudo make build-rpi
```

If you built the image on your PC, send it to your Raspberry Pi over SSH (`$BUILD_TAG` is a config variable):
```
$ docker save $BUILD_TAG | ssh <your_raspberry_pi_host> docker load
```

## IPv6
By default Raspbian does not load the kernel module for IPv6 `iptables` on boot.

Run `sudo modprobe ip6_tables` to load it immediately.

To persist on reboot, run

    $ echo 'ip6_tables' | sudo tee /etc/modules-load.d/ip6-tables.conf