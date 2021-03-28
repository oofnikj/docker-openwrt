# Configure OpenVPN server

Here is a short guide on how to set up a VPN server on OpenWRT.

* Need to create `/dev/net/tun` inside the container on boot:
```
# sed -i '$i\
mkdir -p /dev/net\
mknod /dev/net/tun c 10 200' /etc/rc.local
```


## Add firewall rules
We will be using `10.16.0.0/24` as our VPN subnet.

* Add `tun0` device to LAN zone and allow port 1194 UDP from WAN:

```
# cat <<EOF | uci batch
rename firewall.@zone[0]="lan"
rename firewall.@zone[1]="wan"
rename firewall.@forwarding[0]="lan_wan"
del_list firewall.lan.device="tun0"
add_list firewall.lan.device="tun0"
delete firewall.vpn
set firewall.ovpn="rule"
set firewall.ovpn.name="Allow-OpenVPN"
set firewall.ovpn.src="wan"
set firewall.ovpn.dest_port="1194"
set firewall.ovpn.proto="udp"
set firewall.ovpn.target="ACCEPT"
commit firewall
EOF
# /etc/init.d/firewall restart
```

* Add NAT rule to masquerade VPN traffic:
```
# cat <<EOF | uci batch
set firewall.ovpn_nat=nat
set firewall.ovpn_nat.target='MASQUERADE'
set firewall.ovpn_nat.src='*'
set firewall.ovpn_nat.name='OpenVPN-NAT'
set firewall.ovpn_nat.src_ip='10.16.0.0/24'
commit firewall
EOF
# /etc/init.d/firewall restart
```

## Generate certificates
* Install packages
```
# opkg update
# opkg install openvpn-openssl openvpn-easy-rsa luci-app-openvpn
```

* Set configuration params
``` 
# export EASYRSA_PKI=/etc/easy-rsa/pki
# export EASYRSA_REQ_CN=<my-vpn.example.com>
```

* Generate pre-shared key
```
# openvpn --genkey --secret ${EASYRSA_PKI}/tls.pem
```
 
* (Re-)initialize the PKI directory
```
# easyrsa --batch init-pki
```

* Generate DH parameters
```
# easyrsa --batch gen-dh
```

* Create a new CA if you don't already have one
```
# easyrsa --batch build-ca nopass
```
* Generate a keypair and sign locally for a server
```
# easyrsa --batch build-server-full server nopass
```

* Generate a keypair and sign locally for a client
```
# easyrsa --batch build-client-full client nopass
```

Repeat the last step for any additional clients.

## Generate server configuration with UCI

```
# cat <<EOF | uci import
package openvpn
config openvpn "$(echo $EASYRSA_REQ_CN | sed 's/\./_/g')"
  option enabled "1"
  option server "10.16.0.0 255.255.255.0"
  option proto "udp"
  option port "1194"
  option dev "tun"
  option comp_lzo "adaptive"
  option mssfix "1420"
  option topology "subnet"
  option keepalive "10 60"
  option verb "3"
  option user "nobody"
  option group "nogroup"
  option tls_crypt "${EASYRSA_PKI}/tls.pem"
  option dh "${EASYRSA_PKI}/dh.pem"
  option ca "${EASYRSA_PKI}/ca.crt"
  option cert "${EASYRSA_PKI}/issued/server.crt"
  option key "${EASYRSA_PKI}/private/server.key"
  option cipher "AES-128-CBC"
  list push "comp-lzo adaptive"
  list push "redirect-gateway def1"
  list push "dhcp-option DNS $(uci get network.lan.ipaddr)"
  list push "dhcp-option DOMAIN $(uci get dhcp.@dnsmasq[0].domain)"
EOF
# /etc/init.d/openvpn restart
```

* Generate inline client config
```
# cat <<EOF > client.ovpn
client
dev tun
remote ${EASYRSA_REQ_CN} 1194 udp
resolv-retry infinite
user 999
group 999
nobind
persist-key
persist-tun
tls-client
topology subnet
remote-cert-tls server
cipher AES-128-CBC

<tls-crypt>
$(cat ${EASYRSA_PKI}/tls.pem)
</tls-crypt>
<ca>
$(openssl x509 -in $EASYRSA_PKI/ca.crt)
</ca>
<cert>
$(openssl x509 -in $EASYRSA_PKI/issued/client.crt)
</cert>
<key>
$(cat $EASYRSA_PKI/private/client.key)
</key>
EOF
```

Copy `client.ovpn` to your client and try to connect.

---
## Reference
1. https://openwrt.org/docs/guide-user/services/vpn/openvpn/basic
1. https://openvpn.net/community-resources/reference-manual-for-openvpn-2-4
