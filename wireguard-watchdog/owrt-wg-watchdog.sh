vi or winscp#!/bin/sh
#DEBUG=; set -x # comment/uncomment to disable/enable debug mode

# name: owrt-wg-watchdog.sh
# version: 0.1, 23-mar-2024, by egc
# purpose: WireGuard watchdog , in case of failure of a wireguard tunnel the next tunnel is automatically started
# script type: shell script
# installation:
# 1. Copy owrt-wg-watchdog.sh from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog/owrt-wg-watchdog.sh to /usr/share
#    either with: curl -o /usr/share/owrt-wg-watchdog.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog/owrt-wg-watchdog.sh
#    or by clicking the download icon in the upper right corner of the script
# 2. Make executable: chmod +x /usr/share/owrt-wg-watchdog.sh
# 3. Edit the script with vi or winscpIn to add the names of the Wireguard tunnels you want to use for fail over, the names are the names of the interfaces, format is:
#    WG1=tunnel-name
#    WG2=second-tunnel-name
#    etc., you can set up to 9 tunnels to use.
# 4. To start on startup of the router, add to System > Startup > Local Startup (/etc/rc.local):
#    /usr/share/owrt-wg-watchdog.sh &
#    Note the ampersand (&) at the end indicating that the script is executed asynchronously
# 5. The script can take two parameters, the first the ping time in seconds default is 30, the second the ip address used for pinging, default 8.8.8.8 
#    Use a ping time between 10 and 60 seconds, do not set ping time lower than 10 or you run the risk of being banned from the server you are pinging to
#    As IP address you want to use for pinging (default 8.8.8.8) you can set an address which resolves to multiple IP addresses,
#    under DHCP and DNS > Hostnames (/etc/config/dhcp, config domain) add:
#    ping-host 8.8.8.8
#    ping-host 9.9.9.9
#    Then use ping-host as ping address and all addresses of ping-host will be used in a round robin method, this also adds redundancy if one server is down:
#    /usr/share/owrt-wg-watchdog.sh 10 ping-host &
# 6. reboot
# 7. Debug by removing the # on the second line of this script, view with: logread | grep debug  



#Add the Wireguard tunnels you want to use for fail over as a continuous range e.g. WG1, WG2 etc max 9 tunnels
WG1="wg_mullv_se"
WG2="wgoraclecloud"
#WG3=
#WG4=

#------Do not change below this line------------
(
SLEEP="$1"
PINGIP="$2"
: ${SLEEP:=30}
: ${PINGIP:=8.8.8.8}
activetunnel=1

# get max numer of tunnels
for i in $(seq 1 9);do 
	#eval echo "\$$(echo WG${i})"
	[[ -z $(eval echo "\$$(echo WG${i})") ]] && { maxtunnels=$((i - 1)); break; }
done

# activate tunnel
set_active(){
	activetunnel=$1
	[[ $activetunnel -gt $maxtunnels ]] && { activetunnel=1; echo "WireGuard watchdog: all tunnels failed starting over"; }
	for i in $(seq 1 $maxtunnels); do
		eval "wgi=\$$(echo WG${i})"
		if [[ $i = "$activetunnel" ]]; then
			#uci set network.${wgi}.disabled="0"
			uci -q del network.${wgi}.disabled
		else
			uci -q set network.${wgi}.disabled="1"
		fi
	done
	uci -q commit network
	( service network restart >/dev/null 2>&1 ) &
	sleep 20
}
# search for present active tunnel
search_active() {
	for i in $(seq $activetunnel $maxtunnels); do
		eval "wgi=\$$(echo WG${i})"
		# check if tunnel exists
		uci show | grep "interface='$wgi'" 1>/dev/null || echo echo "WireGuard watchdog ERROR: tunnel $wgi does not exist"
		if ! [[ $(uci -q get network.$wgi.disabled) = "1" ]] >/dev/null 2>&1; then
			echo "WireGuard watchdog: tunnel $wgi is enabled"
			activetunnel=$i
			wga="$wgi"
			break
		fi
		# if no active tunnel is found then restart with first tunnel active
		[[ $i -eq $maxtunnels ]] && set_active 1
	done
}

watchdog(){
	echo "WireGuard watchdog: $0 on tunnel ${wga} is running"
		while sleep $SLEEP; do
		while ! ping -qc1 -W6 -n $PINGIP -I ${wga} &> /dev/null; do
			sleep 7
			if ! ping -qc1 -W6 -n $PINGIP -I ${wga} &> /dev/null; then
				echo "WireGuard watchdog: tunnel ${wga} is DOWN, starting next tunnel"
				activetunnel=$((activetunnel + 1))
				set_active $activetunnel
				search_active
			fi
		done
	done
}

echo "WireGuard watchdog: $0 is started"
sleep 120	# on startup wait till everything is running
search_active
watchdog

) 2>&1 | logger $([ ${DEBUG+x} ] && echo '-p user.debug') \
    -t $(echo $(basename $0) | grep -Eo '^.{0,23}')[$$] &