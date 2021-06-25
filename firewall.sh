#!/bin/bash
WAN="ens19"
LOCAL="ens18"
VPN="tun0"
LOCAL_NET="192.168.11.0/24"
WAN_IP="твой-внешний-ип"
LOCAL_IP="192.168.11.1"

echo 'Сбрасываем все правила...'
iptables -F INPUT
iptables -F FORWARD
iptables -F OUTPUT
iptables -t nat -F
iptables -t mangle -F

echo 'Настраиваем правила поумолчанию...'
iptables -P FORWARD DROP
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A INPUT -i $LOCAL -j ACCEPT
iptables -A INPUT -i docker+ -j ACCEPT
iptables -A INPUT -i br+ -j ACCEPT
iptables -A FORWARD -i tun+ -o $WAN -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $WAN -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT

echo 'Разрешаем ssh icmp'
iptables -A INPUT -p TCP --dport 22 -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -p TCP --dport 873 -j ACCEPT

echo 'Разрешаем DNS и HTTP'
iptables -A INPUT -p udp -m udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp -m udp --sport 53 --dport 1024:65535 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
#iptables -A OUTPUT -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT

echo 'Разрешаем ftp-client'
# Allow FTP connections @ port 21
iptables -A INPUT  -p tcp --sport 21 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --dport 21 -m state --state NEW,ESTABLISHED -j ACCEPT


echo 'forwarding to RDP'
iptables -t nat -A PREROUTING --dst $WAN_IP -p TCP --dport 53121 -j DNAT --to-destination 192.168.11.3:3389
iptables -t nat -A POSTROUTING --dst $WAN_IP -p TCP --dport 53121 -j SNAT --to-source $WAN_IP
iptables -t nat -A OUTPUT --dst $WAN_IP -p TCP --dport 53121 -j DNAT --to-destination 192.168.11.3
iptables -I FORWARD -i $WAN -o $LOCAL -d 192.168.11.3 -p TCP --dport 3389 -j ACCEPT


echo 'some forwarding to 3000'
iptables -t nat -A PREROUTING --dst $WAN_IP -p TCP --dport 3000 -j DNAT --to-destination 192.168.11.107:3000
iptables -t nat -A POSTROUTING --dst $WAN_IP -p TCP --dport 3000 -j SNAT --to-source $WAN_IP
iptables -t nat -A OUTPUT --dst $WAN_IP -p TCP --dport 3000 -j DNAT --to-destination 192.168.11.107
iptables -I FORWARD -i $WAN -o $LOCAL -d 192.168.11.107 -p TCP --dport 3000 -j ACCEPT

echo 'forwarding ssh to some server'
iptables -t nat -A PREROUTING --dst $WAN_IP -p TCP --dport 63121 -j DNAT --to-destination 192.168.11.100:22
iptables -t nat -A POSTROUTING --dst $WAN_IP -p TCP --dport 63121 -j SNAT --to-source $WAN_IP
iptables -t nat -A OUTPUT --dst $WAN_IP -p TCP --dport 63121 -j DNAT --to-destination 192.168.11.100
iptables -I FORWARD -i $WAN -o $LOCAL -d 192.168.11.100 -p TCP --dport 63121 -j ACCEPT


echo 'Разрешаем VPN-сервер'
iptables -A INPUT -p tcp -m tcp --dport 34556 -j ACCEPT

echo 'Включаем NАТ'
iptables -t nat -A POSTROUTING -o $WAN -j SNAT --to-source $WAN_IP
iptables -A FORWARD -i $LOCAL -j ACCEPT
iptables -A FORWARD -o $LOCAL -j ACCEPT

iptables -A FORWARD -s 10.8.0.0/24 -j ACCEPT
iptables -A FORWARD -d 10.8.0.0/24 -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -s 172.18.0.0/24 -j ACCEPT
iptables -A FORWARD -d 172.18.0.0/24 -m state --state ESTABLISHED,RELATED -j ACCEPT

