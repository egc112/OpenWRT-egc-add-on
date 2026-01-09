#!/bin/sh
#DEBUG=; set -x; logger -t stop-wan-leak $(env); # uncomment/comment to enable/disable debug mode

# Name: 09-stop-wan-leak
# Version: 0.95 9-jan-2026 by egc
# Description: OpenWRT hoptlug script disabling forwarding to stop a wan leak while PBR is starting
# Operating mode: The script is triggered by the WAN interface going up this can happen multiple times but after the WAN interface is up the critical period starts
# Usage: e.g. if you want to be sure there is no wan leak while using your VPN and PBR
# Note this only takes care of forwarding so blocking your lan client from accessing the wan, the router itself can still access the wan
# Installation:
#  Copy script from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/stop-wan-leak-pbr/09-stop-wan-leak to your router either
#     with, from commandline (SSH): curl -o /etc/hotplug.d/iface/09-stop-wan-leak https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/stop-wan-leak-pbr/09-stop-wan-leak
#     or by clicking the download icon in the upper right corner of the script and using e.g. winscp to transfer the script.
#  The logical interface name of the wan interface, as shown in /etc/network, is taken from the `uplink_interface` of the PBR config, default: `wan`. If that cannot be found then the value of `MYWANIF` in this script is taken, default is `wan` but you can edit it.
#  Reboot or restart network (service network restart)
#  This script will only run if it is enabled in the PBR config with: ` option stop_wan_leak_on_start '1' `
# Check the working with `logread -e stop-wan-leak`
# Enable debugging by removing the # before the #DEBUG= ... on line 2, check debug output with `logread -e stop-wan-leak`
# To preserve the script between upgrades add to /etc/sysupgrade.conf: `/etc/hotplug.d/iface/09-stop-wan-leak`

# https://forum.openwrt.org/t/pbr-wg-bootup-leak-bootup-killswitch-scripts/241991/7

MYWANIF="wan"	# set the logical interface you are using as wan

MAXSLEEP=60		# Maximum sleep time to prevent deadlock
PBRSLEEP=5		# Extra sleep time after PBR is enabled to make sure PBR rules are functioning

#==========DO NOT ALTER BELOW THIS LINE==================
SLEEP=0
{
is_enabled() { ls /etc/rc.d/*"${1}"* >/dev/null 2>&1; }

#when disabled exit
if [ "$(uci -q get pbr.config.stop_wan_leak_on_start)" != "1" ]; then 
	echo "stop-wan-leak: not RUNNING because it is not enabled in pbr config: option stop_wan_leak_on_start '1' "
	exit 0
fi

#Determine wan device
WANIF="$(uci -q get pbr.config.uplink_interface)"
if [ -z "$WANIF" ]; then 
	WANIF="$MYWANIF"
	echo "stop-wan-leak: no uplink interface defined in PBR config, assuming the logical interface name of wan is $WANIF"
else
	echo "stop-wan-leak: logical wan interface name on which the trigger is set is $WANIF"
fi

if [ "$INTERFACE" == "$WANIF" ] && [ "$ACTION" == "ifup" ]; then
	echo "stop-wan-leak: disable forwarding on ifup of $WANIF"
	/sbin/sysctl -w net.ipv4.ip_forward=0
	/sbin/sysctl -w net.ipv6.conf.all.forwarding=0
fi

while [ $SLEEP -le $MAXSLEEP ]; do
	SLEEP=$((SLEEP + 1))
	sleep 1
	# if pbr is not enabled break
	if ! is_enabled "pbr"; then
		echo "stop-wan-leak: pbr is not enabled so going to enable forwarding"
		break
	fi
	#if pbr is enabled and running then also enable forwarding
	if ubus call service list '{"name":"pbr"}' | grep -q '"running": '; then
	 sleep $PBRSLEEP
	 SLEEP=$((SLEEP + 5))
	 echo "stop-wan-leak: forwarding disabled during $SLEEP sec but is now enabled after PBR is running "
	 break
	fi
done
/sbin/sysctl -w net.ipv4.ip_forward=1
/sbin/sysctl -w net.ipv6.conf.all.forwarding=1
if [ $SLEEP -gt $MAXSLEEP ]; then
	echo "stop-wan-leak: ERROR: forwarding is now enabled due to exceeding the maximum sleep time of $MAXSLEEP sec. wan leak possible !"
else
	echo "stop-wan-leak: forwarding is now enabled after $SLEEP sec."
fi
} 2>&1 | logger $([ ${DEBUG+x} ] && echo '-p user.debug') \
    -t $(echo $(basename $0) | grep -Eo '^.{0,23}')[$$] &
