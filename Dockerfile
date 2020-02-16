FROM scratch
# ADD https://downloads.openwrt.org/releases/19.07.1/targets/x86/64/openwrt-19.07.1-x86-64-generic-rootfs.tar.gz \
ADD openwrt-19.07.1-x86-64-generic-rootfs.tar.gz /
RUN mkdir -p /var/lock
RUN opkg remove dnsmasq && \
    opkg update && \
    opkg install luci \
      wpa-supplicant \
      hostapd \
      iw-full \
      kmod-mac80211 \
      iperf3 \
      dnsmasq-full
COPY etc/config/network.tpl /etc/config/network
COPY etc/config/wireless.tpl /etc/config/wireless
CMD [ "/sbin/init" ]