FROM scratch
ARG OPENWRT_SOURCE_VER
ADD openwrt-${OPENWRT_SOURCE_VER}-x86-64-generic-rootfs.tar.gz /
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