GATE_DNS=wge.eastus.cloudapp.azure.com
GATE_PORT=31194
#CLIENT_IP=192.168.5.2
CLIENT_IP=$1

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -eq 192 && ${ip[1]} -eq 168 \
            && ${ip[2]} -eq 5 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

if valid_ip $CLIENT_IP; then
EXISTS_IP=$(sudo cat /etc/wireguard/wg0.conf | grep "$CLIENT_IP/32" | wc -l)
  if [ $EXISTS_IP -gt 0 ]; then
      echo "The IP address already exists"
      exit 0
  fi
else
  echo "IP address is not valid. It must have format 192.168.5.X/32 where 0 < X < 255"
  exit 0
fi

cat <<FOK > ./client.sh
#!/bin/bash
SUPPORTED_OS=\$(cat /etc/os-release | grep ID_LIKE | grep -E 'centos|fedora|redhat|rhel' | wc -l)
if [ \$SUPPORTED_OS -eq 0 ]; then
  echo "Only Red Hat based distros are supported"
  exit 0
fi
OS_VERSION=\$(cat /etc/os-release | grep VERSION_ID | sed -n -e '/VERSION_ID/ s/.*\= *//p' | tr -d '"')
yum update -y
yum install deltarpm -y

case \$OS_VERSION in

  7)
    echo "Installing components for RHEL version 7."
    cp /etc/yum.repos.d/backup/* /etc/yum.repos.d/
    mv /etc/yum.repos.d/kioskos.repo /etc/yum.repos.d/backup/
    #yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y
    #curl -o /etc/yum.repos.d/jdoss-wireguard-epel-7.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
    #yum install wireguard-dkms wireguard-tools -y
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    yum install https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm -y
    yum install epel-release -y
    yum install yum-plugin-elrepo -y
    yum update kernel -y
    yum install kmod-wireguard wireguard-tools -y
    ;;

  8)
    echo "Installing components for RHEL version 8."
    yum install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm -y
    dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
    yum install kmod-wireguard wireguard-tools -y
    ;;

  *)
    echo "We support only version 7 or 8."
    exit 0
    ;;
esac
yum install nmcli -y
nmcli con mod eth0 connection.autoconnect yes
mkdir -v /etc/wireguard/
sh -c 'umask 077; touch /etc/wireguard/wg0.conf'
ls -l /etc/wireguard/wg0.conf
cd /etc/wireguard/
sudo sh -c 'umask 077; wg genkey | tee privatekey | wg pubkey > publickey'
cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
## client private key ##
PrivateKey = \$(cat /etc/wireguard/privatekey)
 
## client ip address ##
Address = $CLIENT_IP/24
 
[Peer]
## CentOS 8 server public key ##
PublicKey = $(cat /etc/wireguard/publickey)
 
## set ACL ##
AllowedIPs = 192.168.5.0/24
## Turn on NAT for client so internet routed thorugh our vpn
#AllowedIPs = 0.0.0.0/0
 
## Your CentOS 8 server's public IPv4/IPv6 address and port ##
Endpoint = $GATE_DNS:$GATE_PORT
 
##  Key connection alive ##
PersistentKeepalive = 15
EOF
systemctl enable wg-quick@wg0 --now
#reboot
useradd wire
mkdir -p /home/wire/.ssh/
echo $(cat /home/wire/.ssh/id_ed25519.pub) >> /home/wire/.ssh/authorized_keys
chown -R wire:wire /home/wire/
chmod 0600 /home/wire/.ssh/authorized_keys
echo "Execute the following command at the the Wireguard Server" > ~/connection_string.txt
echo "sudo /usr/sbin/register_wireguard \$(cat /etc/wireguard/publickey) $CLIENT_IP/32" >> ~/connection_string.txt
echo "Please see /root/connection_string.txt for further steps."

case \$OS_VERSION in

  7)
    echo "Installing components for RHEL version 7."
    rm -rf /etc/yum.repos.d/CentOS* 
    rm -rf /etc/yum.repos.d/elrepo.repo
    rm -rf /etc/yum.repos.d/epel.repo
    rm -rf /etc/yum.repos.d/epel-testing.repo
    mv /etc/yum.repos.d/backup/kioskos.repo /etc/yum.repos.d/
    ;;
  *)
    echo "We support only version 7 or 8."
    exit 0
    ;;
esac

FOK
#yum install shc -y
shc -r -f ./client.sh