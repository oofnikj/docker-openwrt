#!/bin/sh
set -eu

# https://downloads.openwrt.org/snapshots/targets/armvirt/64/openwrt-armvirt-64-default-rootfs.tar.gz
# https://downloads.openwrt.org/snapshots/targets/armvirt/32/openwrt-armvirt-32-default-rootfs.tar.gz
# https://downloads.openwrt.org/snapshots/targets/x86/64/openwrt-x86-64-rootfs.tar.gz
# https://downloads.openwrt.org/releases/19.07.5/targets/x86/64/openwrt-19.07.5-x86-64-generic-rootfs.tar.gz
# https://downloads.openwrt.org/releases/19.07.5/targets/armvirt/64/openwrt-19.07.5-armvirt-64-default-rootfs.tar.gz
# https://downloads.openwrt.org/releases/19.07.5/targets/armvirt/32/openwrt-19.07.5-armvirt-32-default-rootfs.tar.gz

download_rootfs() {
  local rootfs_url version
	case ${OPENWRT_SOURCE_VER} in
    snapshot)
      if [[ $ARCH = "armvirt-32" ]] ; then
        rootfs_url="https://downloads.openwrt.org/snapshots/targets/armvirt/32/openwrt-armvirt-32-default-rootfs.tar.gz"
        version="https://downloads.openwrt.org/snapshots/targets/armvirt/32/version.buildinfo"
      elif [[ $ARCH = "armvirt-64" ]] ; then
        rootfs_url="https://downloads.openwrt.org/snapshots/targets/armvirt/64/openwrt-armvirt-64-default-rootfs.tar.gz"
        version="https://downloads.openwrt.org/snapshots/targets/armvirt/64/version.buildinfo"
      elif [[ $ARCH = "x86-64" ]] ; then
        rootfs_url="https://downloads.openwrt.org/snapshots/targets/x86/64/openwrt-x86-64-rootfs.tar.gz"
        version="https://downloads.openwrt.org/snapshots/targets/x86/64/version.buildinfo"
      fi
    ;;
    *)
      if [[ $ARCH = "armvirt-32" ]] ; then
        rootfs_url="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/armvirt/32/openwrt-${OPENWRT_SOURCE_VER}-armvirt-32-default-rootfs.tar.gz"
        version="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/armvirt/32/version.buildinfo"
      elif [[ $ARCH = "armvirt-64" ]] ; then
        rootfs_url="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/armvirt/64/openwrt-${OPENWRT_SOURCE_VER}-armvirt-64-default-rootfs.tar.gz"
        version="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/armvirt/64/version.buildinfo"
      elif [[ $ARCH = "x86-64" ]] ; then
        rootfs_url="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/x86/64/openwrt-${OPENWRT_SOURCE_VER}-x86-64-generic-rootfs.tar.gz"
        version="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/x86/64/version.buildinfo"
      fi
    ;;
  esac
  wget "${rootfs_url}" -q -O rootfs.tar.gz
  wget "${version}" -q -O version.buildinfo
}

docker_build() {
  docker build \
		--build-arg ts="$(date)" \
		--build-arg version="$(cat version.buildinfo)" \
		-t $IMAGE:$TAG .
}

cleanup() {
  rm -rf rootfs.tar.gz version.buildinfo
}

trap cleanup EXIT
download_rootfs
docker_build