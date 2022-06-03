#!/bin/bash
# The first parameter is client public key, second parameter is client IP address with /32 at the end.
# /root/register.sh D2bLDfDO8EjxthSuMaSHkmTEwSzQCrNm1ePYFQ/CKVw= 192.168.128.2/32 
# wg set wg0 peer nhAK5GUcye4iGKrZOxvGNH04o65mtZTYOOQHQ/NdpSA= allowed-ips 192.168.128.1/32

function valid_ip()
{
    local  ip_out=$1
    local  stat=1

    local ip=${ip_out::-3}
    local suffix=${ip_out: -3}
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -eq 192 && ${ip[1]} -eq 168 && ${ip[2]} -eq 5 && ${ip[3]} -lt 255 && ${ip[3]} -gt 1 && $suffix == "/32" ]]
        stat=$?
    fi
    return $stat
}

HASH=$1
CLIENT_IP=$2

if valid_ip $CLIENT_IP; then
EXISTS_IP=$(sudo cat /etc/wireguard/wg0.conf | grep $CLIENT_IP | wc -l)
EXISTS_HASH=$(sudo cat /etc/wireguard/wg0.conf | grep $HASH | wc -l)
  if [ $EXISTS_IP -gt 0 ]; then
      echo "The IP address already exists"
      exit 0
  fi
  if [ $EXISTS_HASH -gt 0 ]; then
      echo "The HASH already exists"
      exit 0
  fi
else
  echo "IP address is not valid. It must have format 192.168.5.X/32 where 0 < X < 255"
  exit 0
fi

systemctl stop wg-quick@wg0
#cat <<EOF >> /etc/wireguard/wg0.conf
#
#[Peer]
### client VPN public key ##
#PublicKey = $1
### client VPN IP address (note /32 subnet) ##
#AllowedIPs = $2
#EOF
echo "#####" >> /etc/wireguard/wg0.conf
echo "[Peer]" >> /etc/wireguard/wg0.conf
echo "PublicKey = $1" >> /etc/wireguard/wg0.conf
echo "AllowedIPs = $2" >> /etc/wireguard/wg0.conf
echo "" >> /etc/wireguard/wg0.conf

systemctl start wg-quick@wg0 

if [ $? -eq 1 ]; then
  cat /etc/wireguard/wg0.conf | head -n -5 >  /etc/wireguard/wg0.conf
  echo "The configuration file is not valid or other error occured that prevent WireGuard to start. Returing back to the preivous configuration"
  systemctl start wg-quick@wg0 
  exit 0
else
  echo "Record added"
fi
