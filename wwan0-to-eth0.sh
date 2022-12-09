#!/bin/bash

# ------------------------------------------------------------------------------
# Share LTE modem at `wwan0` with ethernet port at `eth0`.
#
# Shamelessly piggy-backing off the work done by arpitjindal97:
# https://github.com/arpitjindal97/raspbian-recipes/blob/master/wifi-to-eth-route.sh
#
# Prerequisits are:
#
# 1. Basic configuration of the Pi, i.e. SSH, UFW, Fail2Ban;
# 2. Configuration of the `wwan0` interface to start and obtain an ip on boot;
#    and;
# 3. Installation of `dnsmasq`.
#
# Please see the project r`README.md` for full setup instructuins.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
# Interface variables
# --------------------------------------
ETH="eth0"
WWAN="wwan0"
# --------------------------------------
# Network variables
# --------------------------------------
IP_ADDRESS="192.168.2.1"
NETMASK="24"
DHCP_RANGE_START="192.168.2.2"
DHCP_RANGE_END="192.168.2.10"
DHCP_TIME="12h"
DNS_SERVER="1.1.1.1"

sudo systemctl start network-online.target &> /dev/null

# ------------------------------------------------------------------------------
# Sets the forwarding and routes in `iptables`.
# ------------------------------------------------------------------------------
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t nat -A POSTROUTING -o $WWAN -j MASQUERADE
sudo iptables -A FORWARD -i $WWAN -o $ETH -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i $ETH -o $WWAN -j ACCEPT

# ------------------------------------------------------------------------------
# Enables packet fowarding.
# ------------------------------------------------------------------------------
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# ------------------------------------------------------------------------------
# Sets our `eth0` device with the variable values, then deletes the default
# route created by `dhcpcd`.`
#
# *N.B.*
# The ip address is in CIDR format. Values can be calculated at:
# https://jodies.de/ipcalc
# ------------------------------------------------------------------------------
sudo ip link set dev $ETH down
sudo ip link set dev $ETH up
sudo ip addr add $IP_ADDRESS/$NETMASK dev $

sudo ip route del 0/0 dev $ETH &> /dev/null

# ------------------------------------------------------------------------------
# Stops `dnsmasq` and removes any config files previously created.
# ------------------------------------------------------------------------------
sudo systemctl stop dnsmasq

sudo rm -rf /etc/dnsmasq.d/* &> /dev/null

# ------------------------------------------------------------------------------
# Creates a custom `dnsmasq` config file using the variables, copies it to the
# correct folder and starts `dnsmasq`.
# ------------------------------------------------------------------------------
echo -e "interface=$ETH
bind-interfaces
server=$DNS_SERVER
domain-needed
bogus-priv
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,$DHCP_TIME" > /tmp/custom-dnsmasq.conf

sudo cp /tmp/custom-dnsmasq.conf /etc/dnsmasq.d/custom-dnsmasq.conf
sudo systemctl start dnsmasq
