FROM scratch
ADD rootfs.tar.gz /
RUN mkdir -p /var/lock
RUN opkg remove --force-depends \
      dnsmasq* \
      wpad* \
      iw* && \
    opkg update && \
    opkg install luci \
      wpad-wolfssl \
      iw-full \
      ip-full \
      kmod-mac80211 \
      dnsmasq-full \
      iptables-mod-checksum
RUN opkg list-upgradable | awk '{print $1}' | xargs opkg upgrade || true

RUN echo "iptables -A POSTROUTING -t mangle -p udp --dport 68 -j CHECKSUM --checksum-fill" >> /etc/firewall.user
RUN sed -i '/^exit 0/i cat \/tmp\/resolv.conf > \/etc\/resolv.conf' /etc/rc.local

ARG ts
ARG version
LABEL org.opencontainers.image.created=$ts
LABEL org.opencontainers.image.version=$version
LABEL org.opencontainers.image.source=https://github.com/oofnikj/docker-openwrt

CMD [ "/sbin/init" ]