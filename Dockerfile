FROM scratch
ADD openwrt-19.07.1-x86-64-generic-rootfs.tar.gz /
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