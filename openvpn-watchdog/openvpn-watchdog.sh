#!/bin/sh
# shellcheck disable=SC3010,SC3020,SC3043,SC3001,SC3060

#DEBUG=; set -x # comment/uncomment to disable/enable debug mode

# name: openvpn-watchdog.sh
# version: 0.2, 24-july-2024, by egc
# purpose: OpenVPN watchdog with fail-over, by pinging every x seconds through the OpenVPN interface, the OpenVPN tunnel is monitored,
#          in case of failure of the OpenVPN tunnel the next tunnel is automatically started
#          When the last tunnel has failed, the script will start again with the first tunnel.
#          So in case you have only one tunnel this is just a watchdog which restarts the one tunnel you have
# script type: shell script

# Before installing the script setup your OpenVPN tunnels you want to use for this fail over group to use each to use its own tunX
#   where X is a unique number, start with 11
#   Set in the OpenVPN config of each tunnel you want to use: "dev tunX" instead of "dev tun"
# Make  an interface with the same name as the OpenVPN instance, protocol unmanaged and device (custom): "tunX", corresponding with each OpenVPN instance
# Add this interface to the WAN firewall zone or to your own created VPN Client firewall zone
# Important notice: not all VPN providers support pinging through the tunnel e.g. vpnumlimited/keepsolid, so test that first!

# installation:
# 1. Copy openvpn-watchdog.sh from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/openvpn-watchdog/openvpn-watchdog.sh to /usr/share
#    either with, from commandline (SSH): curl -o /usr/share/openvpn-watchdog.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/openvpn-watchdog/openvpn-watchdog.sh
#    or by clicking the download icon in the upper right corner of the script
# 2. Make executable: chmod +x /usr/share/openvpn-watchdog.sh
# 3. Edit the script with vi or winscp to add the names of the OpenVPN tunnels you want to **exclude** for fail over, the names are the names of the interfaces, format is:
#    no_vpntunnels="<no_vpntunnel_1> <no_vpntunnel_2>", see example below
# 4. To start on startup of the router, add to System > Startup > Local Startup (/etc/rc.local):
#    /usr/share/openvpn-watchdog.sh &
#    Note the ampersand (&) at the end indicating that the script is executed asynchronously
# 5  The script takes two parameters, the first the ping time in seconds (default is 30), the second the ip address used for pinging (default is 8.8.8.8).
#    Use a ping time between 10 and 60 seconds, do not set ping time lower than 10 or you run the risk of being banned from the server you are pinging to
#    Instead of an IP address you use for pinging (default 8.8.8.8) you can also set a host-name which resolves to multiple IP addresses:
#    under DHCP and DNS > Hostnames (/etc/config/dhcp, config domain) add:
#    ping-host.mylan 8.8.8.8
#    ping-host.mylan 9.9.9.9
#    Check if the name resolves with: nslookup ping-host.mylan
#    Then use ping-host.mylan as ping address and all addresses of ping-host.mylan will be used in a round robin method, this also adds redundancy if one server is down e.g. start with:
#    /usr/share/openvpn-watchdog.sh 10 ping-host.mylan &
#    This will ping every 10 seconds (after a delay of 120 seconds on startup) to ping-host.mylan (= 8.8.8.8 and 9.9.9.9)
# 6. reboot
# 7. View log with: logread -e watchdog, debug by removing the # on the second line of this script, view with: logread | grep debug
# 8. You can test the script by blocking the endpoint address of a tunnel with:
#    nft insert rule inet fw4 output ip daddr <ip-endpoint-address> counter reject
#    do not forget to reset the firewall (service firewall restart) or remove the rule
# 9. To stop a running script, do from the command line: killall openvpn-watchdog.sh

#Add the OpenVPN tunnels you do NOT want to use for fail over, separated with a space, delimeted with " " and then remove the #
#no_vpntunnels="<no_vpntunnel_1> <no_vpntunnel_2>"

alive=3600      # Set seconds between log message indicating running watchdog
reboot=0        # 0 is no reboot on failure but only restart OpenVPN (with the next tunnel), 1 is reboot on failure
wait_time=30    # alllow time to establish the next tunnel

#---------Do not change below this line------------
(
activets=
vpns=
activeti=0
maxtunnels=0
active_time=0

SLEEP="$1"
: "${SLEEP:=10}"
if [[ $SLEEP -gt 60 || $SLEEP -lt 10 ]]; then 
	echo "openvpn watchdog ERROR: Sleep is $SLEEP but needs to be in the range of 10 - 60 seconds"
	exit 1
fi

PINGIP="$2"
: "${PINGIP:=8.8.8.8}"
if ! nslookup "$PINGIP" >/dev/null 2>&1; then
	echo "openvpn watchdog ERROR: could not resolve PINGIP $PINGIP"
	exit 1
fi

set_activetunneli(){
	local vpni="$1" i=1 vpn
	[[ $vpni -gt $maxtunnels ]] && { vpni=1; echo "openvpn watchdog: all tunnels failed, starting over"; }
	for vpn in $vpns; do
		if [[ $i -eq $vpni ]]; then
			uci -q set openvpn."${vpn}".enabled='1'
			activets="$vpn"
			activeti=$i
			echo "$vpn"
			echo "openvpn watchdog: tunnel $activets is enabled, this is tunnel $activeti of $maxtunnels"
		else
			uci -q del openvpn."${vpn}".enabled
		fi
		i=$(( i + 1 ))
	done
	uci -q commit openvpn
	( service openvpn restart >/dev/null 2>&1 ) &
	sleep $wait_time
	get_tun
}

search_active() {
	local vpn i=1
	for vpn in $vpns; do
		uci -q show | grep "openvpn.${vpn}" 1>/dev/null || echo "openvpn watchdog ERROR: tunnel ${vpn} does not exist"
		if [[ "$(uci -q get openvpn."${vpn}".enabled)" = "1" ]] >/dev/null 2>&1; then
			activets="$vpn"
			activeti=$i
			echo "openvpn watchdog: tunnel $activets is enabled, this is tunnel $activeti of $maxtunnels"
			break
		fi
		i=$((i + 1))
		[[ $i -gt $maxtunnels ]] && { echo "openvpn watchdog: all tunnels failed, starting over"; set_activetunneli 1; }
	done
}

search_tunnels(){
	local vpn vpnt
	while read -r vpn; do 
		vpnt="${vpn%=openvpn}"
		vpns="$vpns ${vpnt#*.}"
		maxtunnels=$((maxtunnels + 1))
	done < <(uci show openvpn | grep '=openvpn')
	echo "openvpn watchdog: number of tunnels: $maxtunnels; Available tunnels:$vpns"
}

remove_vpn(){
	local vpn i=0
	if [[ -n "$no_vpntunnels" ]]; then
		for vpn in $no_vpntunnels; do
			vpns=${vpns//"$vpn"}
		done
		for vpn in $vpns; do i=$(( i + 1)); done
		maxtunnels=$i
		echo "openvpn watchdog: removed $no_vpntunnels, new number of tunnels: $maxtunnels; Available tunnels:$vpns"
	fi
}

get_tun(){
	tun="$(uci -q get network."${activets}".device)"
	[[ -z $tun ]] && { echo "openvpn watchdog ERROR: could not obtain interface for $activets"; exit 1; }
	echo "openvpn watchdog: tunnel interface for $activets is $tun"
}

watchdog(){
	vpn_boot_delay=$(uci -q get system.openvpn_watchdog.vpn_boot_delay)
	[[ -z $vpn_boot_delay ]] && { uci -q delete system.openvpn_watchdog > /dev/null 2>&1; uci -q set system.openvpn_watchdog=vpnwatch; \
		uci -q set system.openvpn_watchdog.vpn_boot_delay=0; vpn_boot_delay=0; }
	logger -p user.info "openvpn watchdog $0 on tunnel $activets, pinging via interface $tun"
	if ping -qc1 -W6 -n "$PINGIP" -I "$tun" &> /dev/null && [[ "$reboot" -eq 1 && $(uci get system.openvpn_watchdog.vpn_boot_delay) -ne 0 ]]; then
		uci set system.openvpn_watchdog.vpn_boot_delay='0'; 
		uci system commit
	fi
	while sleep "$SLEEP"; do
		[[ $active_time -gt $alive ]] >/dev/null 2>&1 && { echo "openvpn watchdog: still running on tunnel $activets, pinging every $SLEEP seconds via interface $tun to $PINGIP "; \
			active_time=0; } || active_time="$((active_time + SLEEP))"
		if ! ping -qc1 -W6 -n "$PINGIP" -I "$tun" &> /dev/null; then
			sleep 6
			if ! ping -qc1 -W6 -n "$PINGIP" -I "$tun" &> /dev/null; then
				if [[ "$reboot" -eq 1 ]]; then
					vpn_boot_delay=$((vpn_boot_delay + 5))
					[[ $vpn_boot_delay -gt 60 ]] && vpn_boot_delay=60
					uci set system.vpn_watchdog.vpn_boot_delay="$vpn_boot_delay"
					uci system commit
					sleep $((vpn_boot_delay*20))
					logger -p user.warning "openvpn watchdog: openvpn tunnel $activets failed, now rebooting"
					activeti=$((activeti + 1))
					set_activetunneli $activeti
					reboot
				else
					logger -p user.warning "openvpn watchdog: openvpn tunnel $activets failed, now restarting openvpn client"
					activeti=$((activeti + 1))
					set_activetunneli $activeti
				fi
			fi
		fi
	done
}

echo "openvpn watchdog: $0 is started, waiting for services, this can take up to two minutes"
sleep 1	# on startup wait till everything is running
search_tunnels
remove_vpn
search_active
get_tun
watchdog
) 2>&1 | logger $([ ${DEBUG+x} ] && echo '-p user.debug') \
    -t $(echo $(basename "$0") | grep -Eo '^.{0,23}')[$$] &
