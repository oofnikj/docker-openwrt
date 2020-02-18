.PHONY: build run clean

include .env

build:
		docker build -t ${BUILD_TAG} .

run:
		./run.sh

clean:
		docker rm ${CONTAINER} || true
		docker network rm ${LAN_NAME} ${WAN_NAME} || true