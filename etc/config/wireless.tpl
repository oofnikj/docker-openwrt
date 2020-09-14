config 'wifi-device'    'radio0'
    option 'type'       'mac80211'
    option 'phy'        "${WIFI_PHY}"
    option 'hwmode'     "${WIFI_HW_MODE}"
    option 'htmode'     "${WIFI_HT_MODE}"
    option 'channel'    "${WIFI_CHANNEL}"

config 'wifi-iface'     "${WIFI_IFACE}"
    option 'device'     'radio0'
    option 'network'    'lan'
    option 'mode'       'ap'
    option 'ifname'     "${WIFI_IFACE}"
    option 'ssid'       "${WIFI_SSID}"
    option 'encryption' "${WIFI_ENCRYPTION}"
    option 'key'        "${WIFI_KEY}"
    option 'disassoc_low_ack' '0'
