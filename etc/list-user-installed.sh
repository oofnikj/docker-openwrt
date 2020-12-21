#!/bin/sh

# source: https://openwrt.org/docs/guide-user/installation/generic.sysupgrade

awk '/^Package:/{PKG= $2}
/^Status: .*user installed/{print PKG}' /usr/lib/opkg/status | sort