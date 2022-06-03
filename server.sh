#!/bin/bash
yum update -y
yum install epel-release -y
yum install 'dnf-command(config-manager)'
yum config-manager --set-enabled powertools -y
yum install cockpit -y
systemctl enable --now cockpit.socket
yum copr enable jdoss/wireguard -y
yum install wireguard-dkms wireguard-tools -y
mkdir -v /etc/wireguard/
sh -c 'umask 077; touch /etc/wireguard/wg0.conf'
ls -l /etc/wireguard/wg0.conf
cd /etc/wireguard/
sh -c 'umask 077; wg genkey | tee privatekey | wg pubkey > publickey'

cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
## VPN server private IP address ##
Address = 192.168.5.1/24
 
## VPN server port ##
ListenPort = 31194
 
## VPN server's private key i.e. /etc/wireguard/privatekey ##
PrivateKey = $(cat /etc/wireguard/privatekey)
 
## Save and update this config file when a new peer (vpn client) added ##
SaveConfig = true
EOF

cat <<EOF > /etc/firewalld/services/wireguard.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>wireguard</short>
  <description>WireGuard open UDP port 31194 for client connections</description>
  <port protocol="udp" port="31194"/>
</service>
EOF
systemctl restart firewalld
firewall-cmd --permanent --add-service=wireguard --zone=public
firewall-cmd --permanent --zone=public --add-masquerade
firewall-cmd --add-service=cockpit
firewall-cmd --add-service=cockpit --permanent
firewall-cmd --reload
firewall-cmd --list-all

cat <<EOF > /etc/sysctl.d/99-custom.conf
## Turn on bbr ##
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
 
## for IPv4 ##
net.ipv4.ip_forward = 1
 
## Turn on basic protection/security ##
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.tcp_syncookies = 1
 
## for IPv6 - uncomment the following line ##
#net.ipv6.conf.all.forwarding = 1
EOF

sysctl -p /etc/sysctl.d/99-custom.conf

firewall-cmd --add-interface=wg0 --zone=internal
firewall-cmd --permanent --zone=internal --add-masquerade
systemctl enable wg-quick@wg0 --now
useradd wire
mkdir /home/wire/.ssh/
ssh-keygen -t ed25519 -N "" -C "remote" -f /home/wire/.ssh/id_ed25519
chown -R wire:wire /home/wire/
chmod 0600 /home/wire/.ssh/id_ed25519.pub