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
      dnsmasq-full \
      iptables-mod-checksum
RUN opkg list-upgradable | awk '{print $1}' | xargs opkg upgrade
RUN echo "iptables -A POSTROUTING -t mangle -p udp --dport 68 -j CHECKSUM --checksum-fill" >> /etc/firewall.user

CMD [ "/sbin/init" ]