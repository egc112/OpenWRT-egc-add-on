#!/bin/sh
#DEBUG=y			# comment/uncomment to disable/enable debug mode
#CHECKSERVER=y		# comment/uncomment to disable/enable check if the WG interface is a server by checking if a port is openend

#  name: wireguard-companion.sh
#  version: 1.01, 14-june-2024, by egc
#  purpose: Toggle WireGuard tunnels on/off, show status and log
#  script type: standalone
#  installation:
#   1. Copy wireguard-companion.sh from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-companion/wireguard-companion.sh to /usr/share
#      either with, from commandline (SSH): curl -o /usr/share/wireguard-companion.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-companion/wireguard-companion.sh
#      or by clicking the download icon in the upper right corner of the script
#   2. Make executable: chmod +x /usr/share/wireguard-companion.sh
#	3. Run from command line with /usr/share/wireguard-companion.sh, most SSH clients will let you run a command on connection, if you use a key to connect, you can have an app like experience
#   4. Debug by removing the # on the second line of this script.
#   5. To skip WireGuard interfaces from the list which are a server, remove the # on the third line of this script
#  usage:
#	Toggle tunnels to enable/disable the WireGuard tunnel, show status, log and restart WireGuard or reboot from the command line
#   A full Network restart (option 7) is only necessary if you disabled all tunnels to get a the default route back
# ================================================================================================================================


green='\e[92m'
blue='\e[96m'
red='\e[91m'
yellow='\e[93m'
clear='\e[0m'

ColorGreen(){
	echo -ne "$green$1$clear"
}
ColorBlue(){
	echo -ne $blue$1$clear
}
ColorYellow(){
	echo -ne $yellow$1$clear
}
ColorRed(){
	echo -ne $red$1$clear
}

[[ -z ${DEBUG+x} ]] || set -x

wireguard_state(){
stat=""
VAR=$(/usr/bin/wg | sed "/$1/,/interface/!d;/interface/d")

if [[ ! -z "$VAR" ]]; then
        echo "${VAR//$'\n'/\\n}" | tr '\n' ' '
fi
}

WrongCommand () {
	menu
}

any_key(){
	read -n 1 -s -r -p "  Press any key to continue"
	return 0
}

show_tunnels(){
	local x=1
	for x in $(seq 1 $maxtunnels); do
		eval "wgx=\$$(echo WG${x})"
		disabled=$(uci -q get network.${wgx}.disabled)
		dstate=${disabled:-0}
		[[ $dstate -eq 0 ]] && state=$(ColorGreen 'enabled ') || state=$(ColorRed 'disabled')
		echo -e "  tunnel $x $state $(ColorYellow ${wgx})"
		x=$((x+1))
	done
}

toggle_confirm(){
	[[ $2 -eq 0 ]] && state="${red}disable${clear}" || state="${green}enable${clear}"
	echo -e -n "\n  Do you want to ${state} tunnel ${yellow}$1${clear}: Y/n ? : "
	read -n 1 y_or_n
	if [[ "$y_or_n" = "N" || "$y_or_n" = "n" ]]; then
		echo -e "\n  ${red}Abort${clear}"
		any_key
		menu
	else
		[[ $2 -eq 0 ]] && uci -q set network.$1.disabled='1' || { uci -q del network.$1.auto; uci -q del network.$1.disabled; }
		pending=1
		return 0
	fi
}

toggle_tunnel(){
	local wgtn=$(eval echo "\$$(echo WG${1})")
	[[ $2 -eq 1 ]] && dstate=1 || dstate=$(uci -q get network.${wgtn}.disabled)
	dstate=${dstate:-0}
	if [[ $dstate -eq 1 ]]; then
		toggle_confirm $wgtn 1
		echo -e "\n  Tunnel $wgtn will be ${green}enabled${clear}"
		echo -e "  ${yellow}Restart Network if all tunnels are disabled${clear}"
		any_key
		return 0
	elif [[ $dstate -eq 0 ]]; then
		toggle_confirm $wgtn 0
		echo -e "\n  Tunnel $wgtn is ${red}disabled${clear}"
		echo -e "  ${yellow}Restart Network if all tunnels are disabled${clear}"
		any_key
		return 0
	else
		echo -e $red"  Tunnel $wgtn does not exist"$clear Please choose an existing tunnel 
		return 1
	fi
	return 0
}

submenu_toggle(){
	local wgtn
	show_tunnels
	[[ "$1" -eq 1 ]] && TOGGLE="enable, all \n  others are disabled" || TOGGLE=toggle
	echo -ne "\n  ${yellow}Enter tunnel to $TOGGLE (1 - $nrtun, 0=Exit):${clear} "
	[[ "$maxtunnels" -lt 10 ]] && read -n 1 tn || read tn # use this with more than 10 tunnels
	if  [[ $tn -eq 0 ]] 2>/dev/null; then
		echo -e "\n  Returning to main menu"
		return 0
	elif [[ $tn -gt 0 && $tn -le $maxtunnels ]] 2>/dev/null; then
		toggle_tunnel $tn $1
		if [[ "$1" -eq 1 ]]; then
			for x in $(seq 1 $maxtunnels); do
				[[ $x -eq $tn ]] && continue
				wgtn=$(eval echo "\$$(echo WG${x})")
				uci -q set network.$wgtn.disabled='1'
			done
		fi
		uci commit network
		service network reload
		return 0
	else
		echo -e $red"\n  Wrong option, choose valid tunnel!\n"$clear; submenu_toggle $1
	fi
}

submenu_showstatus(){
	wg show
	echo -e "\n"
	any_key
	return 0
}

search_tunnels() {
	local i=0
	for line in $(uci -q show | grep "proto='wireguard'" | awk -F. '{print $2}'); do 
		if [[ ! -z ${CHECKSERVER+x} ]] && [[ ! -z $(uci -q get network.${line}.listen_port) ]] && grep -q "$(uci -q get network.${line}.listen_port)" /etc/config/firewall; then
			echo "$line is wg server"
		else
			i=$((i+1))
			eval WG$i=$line
		fi
	done
	maxtunnels=${i}
}

menu(){
	clear
	[[ $pending -eq 1 ]] && echo -e "\n  ${yellow}Restart Network (option 8) if all tunnels are \n  disabled or default route is missing${clear}"
	echo -e "\n   number   state   label"
	show_tunnels
	echo -e -n "
  WireGuard toggle script to enable/disable tunnels
  $(ColorGreen '1)') Showtunnels/Refresh
  $(ColorGreen '2)') Toggle tunnel
  $(ColorGreen '3)') Enable tunnel, Disable all others
  $(ColorGreen '4)') Show WireGuard Status
  $(ColorGreen '5)') Show Routes
  $(ColorGreen '6)') Show Log
  $(ColorGreen '8)') Restart Network
  $(ColorGreen '9)') Save Settings and Reboot Router
  $(ColorGreen '0)') Exit
  $(ColorBlue 'Choose an option:') "
	read -n 1 a
	case $a in
		"1"|"" )
			menu
			;;
		2 )
			echo -e "  Toggle tunnel on/off\n"
			submenu_toggle 0
			menu
			;;
		3 )
			echo -e "  Enable tunnel, Disable others\n"
			submenu_toggle 1
			menu
			;;
		4 )
			echo -e "  Show WireGuard Status\n"
			submenu_showstatus
			menu
			;;
		5 )
			echo -e "  Show Routes\n"
			ip route show
			any_key
			menu
			;;
		6 )
			logread
			any_key
			menu
			;;
		8 )
			echo -e "\n  Restarting Network"
			uci commit network
			service network restart
			pending=0
			any_key
			menu
			;;
		9 )
			echo -e -n "\n  Are you sure you want to Reboot y/N?: "
			read -n 1 y_or_n
			if [[ "$y_or_n" = "Y" || "$y_or_n" = "y" ]]; then
				echo -e "\n  Rebooting, Bye Bye"
				uci commit
				/sbin/reboot
				exit 0
			else
				echo -e "  ABORT"
				any_key
			fi
			menu
			;;
		0 ) echo -e "\n  Thanks for using wireguard-companion.sh"; exit 0 ;;
		*) echo -e $red"  Wrong option."$clear; any_key; WrongCommand;;
	esac
}

clear
pending=0
search_tunnels
menu
