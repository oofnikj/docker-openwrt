#!/bin/sh

# Extracts the rootfs from OpenWRT Raspberry Pi image available from
# https://downloads.openwrt.org/releases/19.07.3/targets/brcm2708/bcm2708/
# and builds a Docker container out of it
#
# Refer to https://openwrt.org/toh/raspberry_pi_foundation/raspberry_pi
# to choose the right image
#
# If building on x86, you must have qemu-arm and binfmt-support installed
set -e

IMG=${1:-'image.img'}
. ./openwrt.conf

check_uid() {
	if [[ $(id -u) -ne 0 ]]; then
		echo "this script must be run as root"
		exit 1
	fi
}

mount_rootfs() {
	echo "* mounting image"
	offset=$(sfdisk -d ${IMG} | grep "${IMG}2" | sed -E 's/.*start=\s+([0-9]+).*/\1/g')
	tmpdir=$(mktemp -u -p .)
	mkdir -p "${tmpdir}"
	mount -o loop"${LOOP_ARGS}",offset=$((512 * $offset)) -t ext4 ${IMG} ${tmpdir}
}

docker_build() {
	echo "* building Docker image"
	docker build \
		--build-arg ROOT_PW="${ROOT_PW}" \
		--build-arg ts="$(date)" \
		--build-arg version="${VERSION:-$OPENWRT_SOURCE_VER}" \
		-t ${IMAGE_TAG} -f Dockerfile.rpi ${tmpdir}
}


cleanup() {
	echo "* cleaning up"
	umount ${tmpdir} || true
	rm -rf ${tmpdir}
}

check_uid
test -f ${IMG} || { echo 'no image file found'; exit 1; }
trap cleanup EXIT
mount_rootfs
docker_build