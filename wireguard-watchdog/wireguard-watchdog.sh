#!/bin/sh
#DEBUG=; set -x # comment/uncomment to disable/enable debug mode

# name: wireguard-watchdog.sh
# version: 0.96, 24-oct-2024, by egc
# purpose: WireGuard watchdog with fail-over, by pinging every x seconds through the WireGuard interface, the WireGuard tunnel is monitored,
#          in case of failure of the WireGuard tunnel the next tunnel is automatically started
#          When the last tunnel has failed, the script will start again with the first tunnel.
#          So in case you have only one tunnel this is just a watchdog which restarts the one tunnel you have.
# script type: shell script
# installation:
# 1. Copy wireguard-watchdog.sh from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog/wireguardg-watchdog.sh to /usr/share
#    either with, from commandline (SSH): curl -o /usr/share/wireguard-watchdog.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog/wireguardg-watchdog.sh
#    or by clicking the download icon in the upper right corner of the script
# 2. Make executable: chmod +x /usr/share/wireguard-watchdog.sh
# 3. Edit the script with vi or winscp to add the names of the Wireguard tunnels you want to use for fail over, the names are the names of the interfaces, format is:
#    WG1=tunnel-name
#    WG2=second-tunnel-name
#    etc., you can set up to 9 tunnels to use.
# 4. To start on startup of the router, add to System > Startup > Local Startup (/etc/rc.local):
#    /usr/share/wireguard-watchdog.sh &
#    Note the ampersand (&) at the end indicating that the script is executed asynchronously
# 5  The script can take two parameters, the first the ping time in seconds default is 30, the second the ip address used for pinging,
#    default is 8.8.8.8
#    Use a ping time between 10 and 60 seconds, do not set ping time lower than 10 or you run the risk of being banned from the server you are pinging to
#    Instead of an IP address you use for pinging (default 8.8.8.8) you can also set a host-name which resolves to multiple IP addresses:
#    under DHCP and DNS > Hostnames (/etc/config/dhcp, config domain) add:
#    ping-host.mylan 8.8.8.8
#    ping-host.mylan 9.9.9.9
#    Check if the name resolves with: nslookup ping-host.mylan
#    Then use ping-host.mylan as ping address and all addresses of ping-host.mylan will be used in a round robin method, this also adds redundancy if one server is down e.g. start with:
#    /usr/share/wireguard-watchdog.sh 10 ping-host.mylan &
#    This will ping every 10 seconds (after a delay of 120 seconds on startup) to ping-host.mylan (= 8.8.8.8 and 9.9.9.9)
# 6. reboot
# 7. View log with: logread -e watchdog, debug by removing the # on the second line of this script, view with: logread | grep debug
# 8. You can test the script by blocking the endpoint address of a tunnel with:
#    nft insert rule inet fw4 output ip daddr <ip-endpoint-address> counter reject
#    do not forget to reset the firewall (service firewall restart) or remove the rule
# 9. To stop a running script, do from the command line: killall wireguard-watchdog.sh


#Add the Wireguard tunnels you want to use for fail over as a continuous range e.g. WG1, WG2 etc., max 9 tunnels
WG1="wg_mullv_se"
WG2="wgoraclecloud"
#WG1="name-of-wg1-interface"
#WG2="name-of-wg2-interface"

#set seconds between log message indicating running watchdog
alive=3600

#------Do not change below this line------------
# shellcheck disable=SC3010,SC3037,SC2116,SC2005
(
SLEEP="$1"
if [[ -z $SLEEP ]]; then
	SLEEP=30
elif [[ $SLEEP -gt 60 || $SLEEP -lt 10 ]]; then 
	echo "WireGuard watchdog ERROR: Sleep is $SLEEP but needs to be in the range of 10 - 60 seconds"
	exit 1
fi

PINGIP="$2"
if [[ -z $PINGIP ]]; then
	PINGIP=8.8.8.8
elif ! nslookup "$PINGIP" >/dev/null 2>&1; then
	echo "WireGuard watchdog ERROR: could not resolve PINGIP $PINGIP"
	exit 1
fi
activetunnel=1
get_tunnels(){
	echo -e -n "WireGuard watchdog: Available tunnels: "
	for i in $(seq 1 9);do 
		[[ -z $(eval echo "\$$(echo WG"${i}")") ]] && { maxtunnels=$((i - 1)); break; }
		eval echo -n "\$$(echo WG"${i}")"
		echo -n "; "
	done
	echo ""
}

set_active(){
	activetunnel=$1
	[[ $activetunnel -gt $maxtunnels ]] && { activetunnel=1; echo "WireGuard watchdog: all tunnels failed, starting over"; }
	for i in $(seq 1 "$maxtunnels"); do
		eval "wgi=\$$(echo WG"${i}")"
		if [[ $i = "$activetunnel" ]]; then
			uci -q del network."${wgi}".disabled
			uci -q del network."${wgi}".auto
		else
			uci -q set network."${wgi}".disabled='1'
		fi
	done
	uci -q commit network
	# if you only want to restart the WG interface
	# ifup $WG1
	( service network restart >/dev/null 2>&1 ) &
	sleep 20
}
search_active() {
	for i in $(seq "$activetunnel" "$maxtunnels"); do
		eval "wgi=\$$(echo WG"${i}")"
		uci -q show | grep "$wgi=interface" 1>/dev/null || echo "WireGuard watchdog ERROR: tunnel $wgi does not exist"
		if ! [[ "$(uci -q get network."$wgi".disabled)" = "1" ]] >/dev/null 2>&1; then
			echo "WireGuard watchdog: tunnel $wgi is enabled"
			activetunnel=$i
			wga="$wgi"
			break
		fi
		[[ $i -eq $maxtunnels ]] && set_active 1
	done
}
watchdog(){
	echo "WireGuard watchdog: started, pinging every $SLEEP seconds to $PINGIP on tunnel ${wga} with endpoint $(uci get network.@wireguard_"${wga}"[0].endpoint_host)"
	while sleep "$SLEEP"; do
		[[ $active -gt $alive ]] >/dev/null 2>&1 && { echo "WireGuard watchdog: still running, pinging every $SLEEP seconds to $PINGIP on tunnel ${wga} with endpoint $(uci get network.@wireguard_"${wga}"[0].endpoint_host)"; \
			active=0; } || active=$((active + SLEEP))
		while ! ping -qc1 -W6 -n "$PINGIP" -I "${wga}" >/dev/null 2>&1; do
			sleep 5
			if ! ping -qc1 -W6 -n "$PINGIP" -I "${wga}" >/dev/null 2>&1; then
				echo "WireGuard watchdog: tunnel ${wga} is DOWN, starting next tunnel"
				activetunnel=$((activetunnel + 1))
				set_active $activetunnel
				search_active
				echo "WireGuard watchdog: started, pinging every $SLEEP seconds to $PINGIP on tunnel ${wga} with endpoint $(uci get network.@wireguard_"${wga}"[0].endpoint_host)"
			fi
		done
	done
}
echo "WireGuard watchdog: $0 is started, waiting for services"
sleep 120	# on startup wait till everything is running
get_tunnels
search_active
watchdog
) 2>&1 | logger $([ ${DEBUG+x} ] && echo '-p user.debug') \
    -t $(echo $(basename "$0") | grep -Eo '^.{0,23}')[$$] &
