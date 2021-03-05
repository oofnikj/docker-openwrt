#!/bin/sh
set -e


download_rootfs() {
	case ${OPENWRT_SOURCE_VER} in
		snapshot)
		# special snowflake raspberry pi zero
			if [ "$ARCH" = "bcm2708" ] ; then
				img_url="https://downloads.openwrt.org/snapshots/targets/bcm27xx/bcm2708/openwrt-bcm27xx-bcm2708-rpi-squashfs-factory.img.gz"
				version="https://downloads.openwrt.org/snapshots/targets/bcm27xx/bcm2708/version.buildinfo"
				gen_rootfs_from_img
				return
			elif [ "$ARCH" = "armvirt-32" ] ; then
				rootfs_url="https://downloads.openwrt.org/snapshots/targets/armvirt/32/openwrt-armvirt-32-default-rootfs.tar.gz"
				version="https://downloads.openwrt.org/snapshots/targets/armvirt/32/version.buildinfo"
			elif [ "$ARCH" = "armvirt-64" ] ; then
				rootfs_url="https://downloads.openwrt.org/snapshots/targets/armvirt/64/openwrt-armvirt-64-default-rootfs.tar.gz"
				version="https://downloads.openwrt.org/snapshots/targets/armvirt/64/version.buildinfo"
			elif [ "$ARCH" = "x86-64" ] ; then
				rootfs_url="https://downloads.openwrt.org/snapshots/targets/x86/64/openwrt-x86-64-rootfs.tar.gz"
				version="https://downloads.openwrt.org/snapshots/targets/x86/64/version.buildinfo"
			else
				echo "Unsupported architecture!"
				exit 1
			fi
		;;
		*)
			if [ "$ARCH" = "bcm2708" ] ; then
				img_url="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/brcm2708/bcm2708/openwrt-${OPENWRT_SOURCE_VER}-brcm2708-bcm2708-rpi-squashfs-factory.img.gz"
				version="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/brcm2708/bcm2708/version.buildinfo"
				gen_rootfs_from_img
				return
			elif [ "$ARCH" = "armvirt-32" ] ; then
				rootfs_url="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/armvirt/32/openwrt-${OPENWRT_SOURCE_VER}-armvirt-32-default-rootfs.tar.gz"
				version="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/armvirt/32/version.buildinfo"
			elif [ "$ARCH" = "armvirt-64" ] ; then
				rootfs_url="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/armvirt/64/openwrt-${OPENWRT_SOURCE_VER}-armvirt-64-default-rootfs.tar.gz"
				version="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/armvirt/64/version.buildinfo"
			elif [ "$ARCH" = "x86-64" ] ; then
				rootfs_url="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/x86/64/openwrt-${OPENWRT_SOURCE_VER}-x86-64-generic-rootfs.tar.gz"
				version="https://downloads.openwrt.org/releases/${OPENWRT_SOURCE_VER}/targets/x86/64/version.buildinfo"
			else
				echo "Unsupported architecture!"
				exit 1
			fi
		;;
	esac
	wget "${rootfs_url}" -O rootfs.tar.gz
	wget "${version}" -O version.buildinfo
}

gen_rootfs_from_img() {
	local offset
	wget "${img_url}" -O- | gzip -d > image.img
	wget "${version}" -O version.buildinfo
	offset=$(sfdisk -d image.img | grep "image.img2" | sed -E 's/.*start=\s+([0-9]+).*/\1/g')
	fakeroot unsquashfs -no-progress -quiet -offset $(( 512 * offset )) -dest "$tmpdir" image.img
	fakeroot tar czf rootfs.tar.gz -C "$tmpdir" .
}

docker_build() {
	docker build \
		--build-arg ts="$(date)" \
		--build-arg version="$(cat version.buildinfo)" \
		-t "$IMAGE":"$TAG" .
}

cleanup() {
	rm -rf rootfs.tar.gz version.buildinfo image.img
	if [ -d "$tmpdir" ] ; then
		rm -rf "$tmpdir"
	fi
}

test -n "$ARCH" || { echo "\$ARCH is unset. Exiting"; exit 1; }
trap cleanup EXIT
tmpdir=$(mktemp -u -p .)
download_rootfs
docker_build