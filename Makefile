.PHONY: build run clean

include .env

build:
		test -f openwrt-19.07.1-x86-64-generic-rootfs.tar.gz || \
			wget -q https://downloads.openwrt.org/releases/19.07.1/targets/x86/64/openwrt-19.07.1-x86-64-generic-rootfs.tar.gz
		docker build -t ${BUILD_TAG} .

run:
		./run.sh

clean:
		docker rm ${CONTAINER} || true
		docker network rm ${LAN_NAME} ${WAN_NAME} || true