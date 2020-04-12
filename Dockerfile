ARG OPENWRT_TAG
FROM openwrtorg/rootfs:${OPENWRT_TAG}
ARG ROOT_PW
RUN echo -e "${ROOT_PW}\n${ROOT_PW}" | passwd
RUN mkdir -p /var/lock
RUN opkg remove dnsmasq && \
    opkg update && \
    opkg install luci \
      wpa-supplicant \
      hostapd \
      iw-full \
      ip-full \
      kmod-mac80211 \
      iperf3 \
      dnsmasq-full

CMD [ "/sbin/init" ]