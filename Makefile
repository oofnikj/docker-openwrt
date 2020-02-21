.PHONY: build run clean

include openwrt.conf

build:
		@docker build --build-arg ROOT_PW=${ROOT_PW} -t ${BUILD_TAG} .

run:
		./run.sh

clean:
		docker rm ${CONTAINER} || true
		docker network rm ${LAN_NAME} ${WAN_NAME} || true
		docker rmi ${BUILD_TAG}