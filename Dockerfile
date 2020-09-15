FROM scratch
ADD rootfs.tar.gz /
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
RUN opkg list-upgradable | awk '{print $1}' | xargs opkg upgrade || true
RUN echo "iptables -A POSTROUTING -t mangle -p udp --dport 68 -j CHECKSUM --checksum-fill" >> /etc/firewall.user

ARG ts
ARG version
LABEL org.opencontainers.image.created=$ts
LABEL org.opencontainers.image.version=$version
LABEL org.opencontainers.image.source=https://github.com/oofnikj/docker-openwrt

CMD [ "/sbin/init" ]