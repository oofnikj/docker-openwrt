#!/bin/bash
set -e

source openwrt.conf
IMG=${1:-openwrt-19.07.2-brcm2708-bcm2708-rpi-ext4-factory.img}


mount_rootfs() {
	offset=$(sfdisk -d ${IMG} | grep "${IMG}2" | sed -E 's/.*start=\s+([0-9]+).*/\1/g')
	tmpdir=$(mktemp -u -p .)
	mkdir -p "${tmpdir}"
	sudo mount -o loop,offset=$((512 * $offset)) -t ext4 ${IMG} ${tmpdir}
}

docker_build() {
	sudo docker build \
		--build-arg ROOT_PW=${ROOT_PW} \
		-t ${BUILD_TAG} -f Dockerfile.rpi ${tmpdir}
}


cleanup() {
	sudo umount ${tmpdir}
	rm -rf ${tmpdir}
}

trap cleanup EXIT
mount_rootfs
docker_build