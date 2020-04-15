.PHONY: build build-rpi run clean install uninstall

include openwrt.conf

build:
	@docker build \
	  --build-arg ROOT_PW=${ROOT_PW} \
		--build-arg OPENWRT_TAG=${OPENWRT_TAG} \
		-t ${BUILD_TAG} .

build-rpi:
	./build-rpi.sh
	@echo 
	@echo "Send the image to your Raspberry Pi with this command:"
	@echo "docker save ${BUILD_TAG} | ssh <your_raspberry_pi_host> docker load"

run:
	./run.sh

clean:
	docker rm ${CONTAINER} || true
	docker network rm ${LAN_NAME} ${WAN_NAME} || true

install:
	install -Dm644 openwrt.service /usr/lib/systemd/system/openwrt.service
	sed -i -E "s#(ExecStart=).*#\1`pwd`/run.sh#g" /usr/lib/systemd/system/openwrt.service
	systemctl daemon-reload
	systemctl enable openwrt.service
	@echo "OpenWRT service installed and will be started on next boot automatically."
	@echo "To start it now, run 'systemctl start openwrt.service'."

uninstall:
	systemctl stop openwrt.service
	systemctl disable openwrt.service
	rm /usr/lib/systemd/system/openwrt.service
	systemctl daemon-reload