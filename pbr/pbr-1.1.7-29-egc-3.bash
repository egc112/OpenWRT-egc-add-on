#!/bin/sh /etc/rc.common
# Copyright 2020-2024 MOSSDeF, Stan Grishin (stangri@melmac.ca)
# shellcheck disable=SC2018,SC2019,SC2034,SC3043,SC3057,SC3060

# sysctl net.ipv4.conf.default.rp_filter=1
# sysctl net.ipv4.conf.all.rp_filter=1

# shellcheck disable=SC2034
START=94
# shellcheck disable=SC2034
USE_PROCD=1

[ -n "${IPKG_INSTROOT}" ] && return 0

readonly packageName='pbr'
readonly PKG_VERSION='1.1.7-29-egc-3'
readonly packageCompat='9'
readonly serviceName="$packageName $PKG_VERSION"
readonly packageConfigFile="/etc/config/${packageName}"
readonly packageLockFile="/var/run/${packageName}.lock"
readonly dnsmasqFileDefault="/var/dnsmasq.d/${packageName}"
readonly _OK_='\033[0;32m\xe2\x9c\x93\033[0m'
readonly __OK__='\033[0;32m[\xe2\x9c\x93]\033[0m'
readonly _OKB_='\033[1;34m\xe2\x9c\x93\033[0m'
readonly __OKB__='\033[1;34m[\xe2\x9c\x93]\033[0m'
readonly _FAIL_='\033[0;31m\xe2\x9c\x97\033[0m'
readonly __FAIL__='\033[0;31m[\xe2\x9c\x97]\033[0m'
readonly _ERROR_='\033[0;31mERROR\033[0m'
readonly _WARNING_='\033[0;33mWARNING\033[0m'
readonly ip_full='/usr/libexec/ip-full'
# shellcheck disable=SC2155
readonly ipTablePrefix="$packageName"
# shellcheck disable=SC2155
readonly agh="$(command -v AdGuardHome)"
# shellcheck disable=SC2155
readonly nft="$(command -v nft)"
readonly nftIPv4Flag='ip'
readonly nftIPv6Flag='ip6'
readonly nftTempFile="/var/run/${packageName}.nft"
readonly nftPermFile="/usr/share/nftables.d/ruleset-post/30-${packageName}.nft"
readonly nftPrefix="$packageName"
readonly nftTable='fw4'
readonly chainsList='forward input output postrouting prerouting'
readonly ssConfigFile='/etc/shadowsocks'
readonly torConfigFile='/etc/tor/torrc'
readonly xrayIfacePrefix='xray_'
readonly rtTablesFile='/etc/iproute2/rt_tables'

# package config options
procd_boot_timeout=
enabled=
fw_mask=
icmp_interface=
ignored_interface=
ipv6_enabled=
nft_user_set_policy=
nft_user_set_counter=
procd_boot_delay=
procd_reload_delay=
procd_lan_interface=
procd_wan_ignore_status=
procd_wan_interface=
procd_wan6_interface=
resolver_set=
resolver_instance=
strict_enforcement=
supported_interface=
verbosity=
wan_ip_rules_priority=
wan_mark=
nft_rule_counter=
nft_set_auto_merge=
nft_set_counter=
nft_set_flags_interval=
nft_set_flags_timeout=
nft_set_flags_gc_interval=
nft_set_policy=
nft_set_timeout=

# run-time
aghConfigFile='/etc/AdGuardHome/AdGuardHome.yaml'
gatewaySummary=
errorSummary=
warningSummary=
wanIface4=
wanIface6=
dnsmasqFile=
dnsmasqFileList=
ifaceMark=
ifaceTableID=
ifacePriority=
ifacesAll=
ifacesSupported=
firewallWanZone=
wanGW4=
wanGW6=
serviceStartTrigger=
processDnsPolicyError=
processPolicyError=
processPolicyWarning=
resolver_set_supported=
policy_routing_nft_prev_param4=
policy_routing_nft_prev_param6=
nft_rule_params=
nft_set_params=
torDnsPort=
torTrafficPort=

# shellcheck disable=SC1091
. /lib/functions.sh
# shellcheck disable=SC1091
. /lib/functions/network.sh
# shellcheck disable=SC1091
. /usr/share/libubox/jshn.sh

output_ok() { output 1 "$_OK_"; output 2 "$__OK__\n"; }
output_okn() { output 1 "$_OK_\n"; output 2 "$__OK__\n"; }
output_okb() { output 1 "$_OKB_"; output 2 "$__OKB__\n"; }
output_okbn() { output 1 "$_OKB_\n"; output 2 "$__OKB__\n"; }
output_fail() { output 1 "$_FAIL_"; output 2 "$__FAIL__\n"; }
output_failn() { output 1 "$_FAIL_\n"; output 2 "$__FAIL__\n"; }
str_contains() { [ -n "$1" ] && [ -n "$2" ] && [ "${1//$2}" != "$1" ]; }
str_contains_word() { echo "$1" | grep -q -w "$2"; }
str_extras_to_underscore() { echo "$1" | tr '[\. ~`!@#$%^&*()\+/,<>?//;:]' '_'; }
str_extras_to_space() { echo "$1" | tr ',;{}' ' '; }
str_first_value_interface() { local i; for i in $1; do is_supported_interface "$i" && { echo "$i"; break; }; done; }
str_first_value_ipv4() { local i; for i in $1; do is_ipv4 "$i" && { echo "$i"; break; }; done; }
str_first_value_ipv6() { local i; for i in $1; do is_ipv6 "$i" && { echo "$i"; break; }; done; }
str_first_word() { echo "${1%% *}"; }
# shellcheck disable=SC2317
str_replace() { printf "%b" "$1" | sed -e "s/$(printf "%b" "$2")/$(printf "%b" "$3")/g"; }
str_replace() { echo "${1//$2/$3}"; }
str_to_dnsmsaq_nftset() { echo "$1" | tr ' ' '/'; }
str_to_lower() { echo "$1" | tr 'A-Z' 'a-z'; }
str_to_upper() { echo "$1" | tr 'a-z' 'A-Z'; }
debug() { local i j; for i in "$@"; do eval "j=\$$i"; logger "${packageName:+-t $packageName}" "${i}: ${j} "; done; }
quiet_mode() {
	case "$1" in
		on) verbosity=0;;
		off) verbosity="$(uci_get "$packageName" 'config' 'verbosity' '2')";;
	esac
}
output() {
# Target verbosity level with the first parameter being an integer
	is_integer() { case "$1" in ''|*[!0-9]*) return 1;; esac; }
	local msg memmsg logmsg text
	local sharedMemoryOutput="/dev/shm/$packageName-output"
	if [ -z "$verbosity" ] && [ -n "$packageName" ]; then
		verbosity="$(uci_get "$packageName" 'config' 'verbosity' '2')"
	fi
	if [ "$#" -ne '1' ] && is_integer "$1"; then
		if [ "$((verbosity & $1))" -gt '0' ] || [ "$verbosity" = "$1" ]; then shift; text="$*"; else return 0; fi
	fi
	text="${text:-$*}";
	[ -t 1 ] && printf "%b" "$text"
	msg="${text//$serviceName /service }";
	if [ "$(printf "%b" "$msg" | wc -l)" -gt '0' ]; then
		[ -s "$sharedMemoryOutput" ] && memmsg="$(cat "$sharedMemoryOutput")"
		logmsg="$(printf "%b" "${memmsg}${msg}" | sed 's/\x1b\[[0-9;]*m//g')"
		logger -t "${packageName:-service} [$$]" "$(printf "%b" "$logmsg")"
		rm -f "$sharedMemoryOutput"
	else
		printf "%b" "$msg" >> "$sharedMemoryOutput"
	fi
}
pbr_find_iface() {
	local iface i param="$2"
	case "$param" in
		wan6)  iface="$procd_wan6_interface";;
		wan|*) iface="$procd_wan_interface";;
	esac
	eval "$1"='${iface}'
}
pbr_get_gateway4() {
	local iface="$2" dev="$3" gw
	network_get_gateway gw "$iface" true
	if [ -z "$gw" ] || [ "$gw" = '0.0.0.0' ]; then
#		gw="$(ubus call "network.interface.${iface}" status | jsonfilter -e "@.route[0].nexthop")"
		gw="$(ip -4 a list dev "$dev" 2>/dev/null | grep inet | awk '{print $2}' | awk -F "/" '{print $1}')"
	fi
	eval "$1"='$gw'
}
pbr_get_gateway6() {
	local iface="$2" dev="$3" gw
	#egc
	if [ "$iface" == "$procd_wan_interface" ]; then
		iface="$procd_wan6_interface"
	fi
	network_get_gateway6 gw "$iface" true
	#echo -e "iface=$iface; network_get_gateway6=$gw\n"
	if [ -z "$gw" ] || [ "$gw" = '::/0' ] || [ "$gw" = '::0/0' ] || [ "$gw" = '::' ]; then
		gw="$(ip -6 a list dev "$dev" 2>/dev/null | grep inet6 | grep 'scope global' | awk '{print $2}')"
	fi
	eval "$1"='$gw'
}
filter_options() {
	local opt="$1" values="$2" v _ret
	for v in $values; do
		str_contains "$opt" _negative && { is_negation "$v" || continue; }
		eval "is_$opt" "${v#!}" || continue
		_ret="${_ret:+$_ret }$v"
	done
	echo "$_ret"
	return 0
}
inline_set() {
	local value="$1" inline_set i
	for i in $value; do
		[ "${i:0:1}" = "!" ] && i=${i:1}
		[ "${i:0:1}" = "@" ] && i=${i:1}
		inline_set="${inline_set:+$inline_set, }$i"
	done
	echo "$inline_set"
}
# shellcheck disable=SC2016
is_bad_user_file_nft_call() { grep -q '"\$nft" list' "$1" || grep '"\$nft" -f' "$1"; }
is_config_enabled() {
# shellcheck disable=SC2317
	_check_config() { local en; config_get_bool en "$1" 'enabled' '1'; [ "$en" -gt '0' ] && _cfg_enabled=0; }
	local cfg="$1" _cfg_enabled=1
	[ -n "$1" ] || return 1
	config_load "$packageName"
	config_foreach _check_config "$cfg"
	return "$_cfg_enabled"
}
# shellcheck disable=SC2317
uci_get_device() { uci_get 'network' "$1" 'device' || uci_get 'network' "$1" 'dev'; }
uci_get_protocol() { uci_get 'network' "$1" 'proto'; }
is_default_dev() { [ "$1" = "$(ip -4 r | grep -m1 'dev' | grep -Eso 'dev [^ ]*' | awk '{print $2}')" ]; }
is_disabled_interface() { [ "$(uci_get 'network' "$1" 'disabled')" = '1' ]; }
is_domain(){ echo "$1" | grep -qE '^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.)*[a-zA-Z]{2,}$'; }
is_dslite() { local p; network_get_protocol p "$1"; [ "${p:0:6}" = "dslite" ]; }
is_family_mismatch() { ( is_ipv4 "${1//!}" && is_ipv6 "${2//!}" ) || ( is_ipv6 "${1//!}" && is_ipv4 "${2//!}" ); }
is_greater() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }
is_greater_or_equal() { test "$(printf '%s\n' "$@" | sort -V | head -n '1')" = "$2"; }
is_ignored_interface() { str_contains_word "$ignored_interface" "$1"; }
is_ignore_target() { [ "$(str_to_lower "$1")" = 'ignore' ]; }
is_integer() { case "$1" in ''|*[!0-9]*) return 1;; esac; }
is_ipv4() { expr "${1%/*}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; }
is_ipv6() { ! is_mac_address "$1" && str_contains "$1" ':'; }
is_ipv6_global() { [ "${1:0:4}" = '2001' ]; }
is_ipv6_link_local() { [ "${1:0:4}" = 'fe80' ]; }
is_ipv6_unique_local() { [ "${1:0:2}" = 'fc' ] || [ "${1:0:2}" = 'fd' ]; }
is_list() { str_contains "$1" ',' || str_contains "$1" ' '; }
is_lan() { local d; network_get_device d "$1"; str_contains "$procd_lan_interface" "$d"; }
is_l2tp() { local p; network_get_protocol p "$1"; [ "${p:0:4}" = "l2tp" ]; }
is_mac_address() { expr "$1" : '[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]$' >/dev/null; }
is_negation() { [ "${1:0:1}" = '!' ]; }
is_netifd_table() { grep -q "ip.table.*$1" /etc/config/network; }
is_netifd_table_interface() { local iface="$1"; [ "$(uci_get 'network' "$iface" 'ip4table')" = "${packageName}_${iface%6}" ]; }
is_oc() { local p; network_get_protocol p "$1"; [ "${p:0:11}" = "openconnect" ]; }
is_ovpn() { local d; uci_get_device d "$1"; [ "${d:0:3}" = "tun" ] || [ "${d:0:3}" = "tap" ] || [ -f "/sys/devices/virtual/net/${d}/tun_flags" ]; }
is_ovpn_valid() { local dev_net dev_ovpn; uci_get_device dev_net "$1"; dev_ovpn="$(uci_get 'openvpn' "$1" 'dev')"; [ -n "$dev_net" ] && [ -n "$dev_ovpn" ] && [ "$dev_net" = "$dev_ovpn" ]; }
is_phys_dev(){ [ "${1:0:1}" = "@" ] && [ -L "/sys/class/net/${1#@}" ]; }
is_present() { command -v "$1" >/dev/null 2>&1; }
is_service_running() { is_service_running_nft; }
is_service_running_nft() { [ -x "$nft" ] && [ -n "$(get_mark_nft_chains)" ]; }
is_supported_iface_dev() { local n dev; for n in $ifacesSupported; do network_get_device dev "$n"; [ "$1" = "$dev" ] && return 0; done; return 1; }
is_supported_protocol() { grep -o '^[^#]*' /etc/protocols | grep -w -v '0' | grep . | awk '{print $1}' | grep -q "$1"; }
is_pptp() { local p; network_get_protocol p "$1"; [ "${p:0:4}" = "pptp" ]; }
is_softether() { local d; network_get_device d "$1"; [ "${d:0:4}" = "vpn_" ]; }
# egc
#is_supported_interface() { is_lan "$1" && return 1; str_contains_word "$supported_interface" "$1" || { ! is_ignored_interface "$1" && ! is_disabled_interface "$1" && { is_wan "$1" || is_wan6 "$1" || is_tunnel "$1"; }; } || is_ignore_target "$1" || is_xray "$1"; }
is_supported_interface() { { is_lan "$1" || is_disabled_interface "$1"; } && return 1; str_contains_word "$supported_interface" "$1" || { ! is_ignored_interface "$1" && { is_wan "$1" || is_wan6 "$1" || is_tunnel "$1"; }; } || is_ignore_target "$1" || is_xray "$1"; }
is_tailscale() { local d; network_get_device d "$1"; [ "${d:0:9}" = "tailscale" ]; }
is_tor() { [ "$(str_to_lower "$1")" = "tor" ]; }
is_tor_running() {
	local ret=0
	is_ignored_interface 'tor' && return 1
	[ -s "$torConfigFile" ] || return 1
	json_load "$(ubus call service list "{ 'name': 'tor' }")" >/dev/null || return 1
	json_select 'tor' >/dev/null || return 1
	json_select 'instances' >/dev/null || return 1
	json_select 'instance1' >/dev/null || return 1
	json_get_var ret 'running' >/dev/null || return 1
	json_cleanup
	if [ "$ret" = "0" ]; then return 1; else return 0; fi
}
is_tunnel() { is_dslite "$1" || is_l2tp "$1" || is_oc "$1" || is_ovpn "$1" || is_pptp "$1" || is_softether "$1" || is_tailscale "$1" || is_tor "$1" || is_wg "$1"; }
is_url() { is_url_file "$1" || is_url_dl "$1"; }
is_url_dl() { is_url_ftp "$1" || is_url_http "$1" || is_url_https "$1"; }
is_url_file() { [ "$1" != "${1#file://}" ]; }
is_url_ftp() { [ "$1" != "${1#ftp://}" ]; }
is_url_http() { [ "$1" != "${1#http://}" ]; }
is_url_https() { [ "$1" != "${1#https://}" ]; }
is_wan() { [ "$1" = "$wanIface4" ] || { [ "${1##wan}" != "$1" ] && [ "${1##wan6}" = "$1" ]; } || [ "${1%%wan}" != "$1" ]; }
is_wan6() { [ -n "$wanIface6" ] && [ "$1" = "$wanIface6" ] || [ "${1/#wan6}" != "$1" ] || [ "${1/%wan6}" != "$1" ]; }
is_wg() { local p lp; network_get_protocol p "$1"; uci_get_listen_port lp "$1"; [ -z "$lp" ] && [ "${p:0:9}" = "wireguard" ]; }
is_wg_server() { local p lp; network_get_protocol p "$1"; uci_get_listen_port lp "$1"; [ -n "$lp" ] && [ "${p:0:9}" = "wireguard" ]; }
is_xray() { [ -n "$(get_xray_traffic_port "$1")" ]; }
dnsmasq_kill() { killall -q -s HUP dnsmasq; }
dnsmasq_restart() { output 3 'Restarting dnsmasq '; if /etc/init.d/dnsmasq restart >/dev/null 2>&1; then output_okn; else output_failn; fi; }
# shellcheck disable=SC2155
get_ss_traffic_ports() { local i="$(jsonfilter -i "$ssConfigFile" -q -e "@.inbounds[*].port")"; echo "${i:-443}"; }
# shellcheck disable=SC2155
get_tor_dns_port() { local i="$(grep -m1 DNSPort "$torConfigFile" | awk -F: '{print $2}')"; echo "${i:-9053}"; }
# shellcheck disable=SC2155
get_tor_traffic_port() { local i="$(grep -m1 TransPort "$torConfigFile" | awk -F: '{print $2}')"; echo "${i:-9040}"; }
get_xray_traffic_port() { local i="${1//$xrayIfacePrefix}"; [ "$i" = "$1" ] && unset i; echo "$i"; }
get_rt_tables_id() { local iface="$1"; grep "${ipTablePrefix}_${iface}\$" "$rtTablesFile" | awk '{print $1;}'; }
get_rt_tables_next_id() { echo "$(($(sort -r -n "$rtTablesFile" | grep -o -E -m 1 "^[0-9]+")+1))"; }
get_rt_tables_non_pbr_next_id() { echo "$(($(grep -v "${ipTablePrefix}_" "$rtTablesFile" | sort -r -n  | grep -o -E -m 1 "^[0-9]+")+1))"; }
# shellcheck disable=SC2016
resolveip_to_nftset() { resolveip "$@" | sed -n 'H;${x;s/\n/,/g;s/^,//;p;};d'; }
resolveip_to_nftset4() { resolveip_to_nftset -4 "$@"; }
resolveip_to_nftset6() { [ -n "$ipv6_enabled" ] && resolveip_to_nftset -6 "$@"; }
# shellcheck disable=SC2016
ipv4_leases_to_nftset() { [ -s '/tmp/dhcp.leases' ] || return 1; grep "$1" '/tmp/dhcp.leases' | awk '{print $3}' | sed -n 'H;${x;s/\n/,/g;s/^,//;p;};d' | tr '\n' ' '; }
# shellcheck disable=SC2016
ipv6_leases_to_nftset() { [ -s '/tmp/hosts/odhcpd' ] || return 1; grep -v '^#' '/tmp/hosts/odhcpd' | grep "$1" | awk '{print $1}' | sed -n 'H;${x;s/\n/,/g;s/^,//;p;};d' | tr '\n' ' '; }
# shellcheck disable=SC3037
ports_to_nftset() { echo -en "$1"; }
get_mark_nft_chains() { [ -x "$nft" ] && "$nft" list table inet "$nftTable" 2>/dev/null | grep chain | grep "${nftPrefix}_mark_" | awk '{ print $2 }'; }
get_nft_sets() { [ -x "$nft" ] && "$nft" list table inet "$nftTable" 2>/dev/null | grep 'set' | grep "${nftPrefix}_" | awk '{ print $2 }'; }
__ubus_get() { ubus call service list "{ 'name': '$packageName' }" | jsonfilter -e "$1"; }
ubus_get_status() { __ubus_get "@.${packageName}.instances.main.data.status.${1}"; }
ubus_get_interface() { __ubus_get "@.${packageName}.instances.main.data.gateways[@.name='${1}']${2:+.$2}"; }
ubus_get_gateways() { __ubus_get "@.${packageName}.instances.main.data.gateways"; }
uci_get_listen_port() {
	local __tmp
	__tmp="$(uci_get 'network' "$2" 'listen_port')"
	[ -z "$__tmp" ] && unset "$1" && return 1
	eval "$1=$__tmp"
}

# luci app specific
is_enabled() { uci_get "$1" 'config' 'enabled'; }
is_running_nft_file() { [ -s "$nftPermFile" ]; }
is_running_nft() { "$nft" list table inet fw4 | grep chain | grep -q pbr_mark_ >/dev/null 2>&1; }
check_nft() { [ -x "$nft" ]; }
check_agh() { [ -x "$agh" ] && { [ -s "$aghConfigFile" ] || [ -s "${agh%/*}/AdGuardHome.yaml" ]; }; }
check_dnsmasq() { command -v dnsmasq >/dev/null 2>&1; }
check_unbound() { command -v unbound >/dev/null 2>&1; }
check_dnsmasq_nftset() {
	local o;
	check_nft || return 1
	check_dnsmasq || return 1
	o="$(dnsmasq -v 2>/dev/null)"
	! echo "$o" | grep -q 'no-nftset' && echo "$o" | grep -q 'nftset'
}
print_json_bool() { json_init; json_add_boolean "$1" "$2"; json_dump; json_cleanup; }
print_json_string() { json_init; json_add_string "$1" "$2"; json_dump; json_cleanup; }
try() {
	if ! "$@" >/dev/null 2>&1; then
		state add 'errorSummary' 'errorTryFailed' "$*"
		return 1
	fi
}

if type extra_command >/dev/null 2>&1; then
	extra_command 'status' "Generates output required to troubleshoot routing issues
		Use '-d' option for more detailed output
		Use '-p' option to automatically upload data under VPR paste.ee account
			WARNING: while paste.ee uploads are unlisted, they are still publicly available
		List domain names after options to include their lookup in report"
	extra_command 'version' 'Show version information'
	extra_command 'on_firewall_reload' '	Run service on firewall reload'
	extra_command 'on_interface_reload' '	Run service on indicated interface reload'
else
# shellcheck disable=SC2034
	EXTRA_COMMANDS='on_firewall_reload on_interface_reload status version'
# shellcheck disable=SC2034
	EXTRA_HELP="	status	Generates output required to troubleshoot routing issues
		Use '-d' option for more detailed output
		Use '-p' option to automatically upload data under VPR paste.ee account
			WARNING: while paste.ee uploads are unlisted, they are still publicly available
		List domain names after options to include their lookup in report"
fi

get_text() {
	local r
	case "$1" in
		errorConfigValidation) r="Config ($packageConfigFile) validation failure!";;
		errorNoNft) r="Resolver set support (${resolver_set}) requires nftables, but nft binary cannot be found!";;
		errorResolverNotSupported) r="Resolver set (${resolver_set}) is not supported on this system!";;
		errorServiceDisabled) r="The ${packageName} service is currently disabled!";;
		errorNoWanGateway) r="The ${serviceName} service failed to discover WAN gateway!";;
		errorNoWanInterface) r="The %s interface not found, you need to set the 'pbr.config.procd_wan_interface' option!";;
		errorNoWanInterfaceHint) r="Refer to https://docs.openwrt.melmac.net/pbr/#procd_wan_interface.";;
		errorNftsetNameTooLong) r="The nft set name '%s' is longer than allowed 255 characters!";;
		errorUnexpectedExit) r="Unexpected exit or service termination: '%s'!";;
		errorPolicyNoSrcDest) r="Policy '%s' has no source/destination parameters!";;
		errorPolicyNoInterface) r="Policy '%s' has no assigned interface!";;
		errorPolicyNoDns) r="Policy '%s' has no assigned DNS!";;
		errorPolicyProcessNoInterfaceDns) r="Interface '%s' has no assigned DNS!";;
		errorPolicyUnknownInterface) r="Policy '%s' has an unknown interface!";;
		errorPolicyProcessCMD) r="'%s'!";;
		errorFailedSetup) r="Failed to set up '%s'!";;
		errorFailedReload) r="Failed to reload '%s'!";;
		errorUserFileNotFound) r="Custom user file '%s' not found or empty!";;
		errorUserFileSyntax) r="Syntax error in custom user file '%s'!";;
		errorUserFileRunning) r="Error running custom user file '%s'!";;
		errorUserFileNoCurl) r="Use of 'curl' is detected in custom user file '%s', but 'curl' isn't installed!";;
		errorNoGateways) r="Failed to set up any gateway!";;
		errorResolver) r="Resolver '%s'!";;
		errorPolicyProcessNoIpv6) r="Skipping IPv6 policy '%s' as IPv6 support is disabled!";;
		errorPolicyProcessUnknownFwmark) r="Unknown packet mark for interface '%s'!";;
		errorPolicyProcessMismatchFamily) r="Mismatched IP family between in policy '%s'!";;
		errorPolicyProcessUnknownProtocol) r="Unknown protocol in policy '%s'!";;
		errorPolicyProcessInsertionFailed) r="Insertion failed for both IPv4 and IPv6 for policy '%s'!";;
		errorPolicyProcessInsertionFailedIpv4) r="Insertion failed for IPv4 for policy '%s'!";;
		errorInterfaceRoutingEmptyValues) r="Received empty tid/mark or interface name when setting up routing!";;
		errorFailedToResolve) r="Failed to resolve '%s'!";;
		errorTryFailed) r="Command failed: %s";;
		errorNftFileInstall) r="Failed to install fw4 nft file '%s'!";;
		errorDownloadUrlNoHttps) r="Failed to download '%s', HTTPS is not supported!";;
		errorDownloadUrl) r="Failed to download '%s'!";;
		errorNoDownloadWithSecureReload) r="Policy '%s' refers to URL which can't be downloaded in 'secure_reload' mode!";;
		errorFileSchemaRequiresCurl) r="The file:// schema requires curl, but it's not detected on this system!";;
		errorIncompatibleUserFile) r="Incompatible custom user file detected '%s'!";;
		errorDefaultFw4TableMissing) r="Default fw4 table '%s' is missing!";;
		errorDefaultFw4ChainMissing) r="Default fw4 chain '%s' is missing!";;
		errorRequiredBinaryMissing) r="Required binary '%s' is missing!";;
		warningInvalidOVPNConfig) r="Invalid OpenVPN config for '%s' interface.";;
		warningResolverNotSupported) r="Resolver set (${resolver_set}) is not supported on this system.";;
		warningPolicyProcessCMD) r="'%s'";;
		warningTorUnsetParams) r="Please unset 'src_addr', 'src_port' and 'dest_port' for policy '%s'.";;
		warningTorUnsetProto) r="Please unset 'proto' or set 'proto' to 'all' for policy '%s'.";;
		warningTorUnsetChainNft) r="Please unset 'chain' or set 'chain' to 'prerouting' for policy '%s'.";;
		warningOutdatedWebUIApp) r="The WebUI application is outdated (version %s), please update it.";;
		warningBadNftCallsInUserFile) r="Incompatible nft calls detected in user include file, disabling fw4 nft file support.";;
		warningDnsmasqInstanceNoConfdir) r="Dnsmasq instance '%s' targeted in settings, but it doesn't have its own confdir.";;
		warningDhcpLanForce) r="Please set 'dhcp.lan.force=1' to speed up service start-up.";;
	esac
	echo "$r"
}

process_url() {
	local url="$1"
	local dl_command dl_https_supported dl_temp_file
# TODO: check for FILE schema and missing curl
	if is_present 'curl'; then
		dl_command="curl --silent --insecure"
		dl_flag="-o"
	elif is_present '/usr/libexec/wget-ssl'; then
		dl_command="/usr/libexec/wget-ssl --no-check-certificate -q"
		dl_flag="-O"
	elif is_present wget && wget --version 2>/dev/null | grep -q "+https"; then
		dl_command="wget --no-check-certificate -q"
		dl_flag="-O"
	else
		dl_command="uclient-fetch --no-check-certificate -q"
		dl_flag="-O"
	fi
	if curl --version 2>/dev/null | grep -q "Protocols: .*https.*" \
		|| wget --version 2>/dev/null | grep -q "+ssl"; then
		dl_https_supported=1
	else
		unset dl_https_supported
	fi
	while [ -z "$dl_temp_file" ] || [ -e "$dl_temp_file" ]; do
		dl_temp_file="$(mktemp -u -q -t "${packageName}_tmp.XXXXXXXX")"
	done
	if is_url_file "$url" && ! is_present 'curl'; then
		state add 'errorSummary' 'errorFileSchemaRequiresCurl' "$url"
	elif is_url_https "$url" && [ -z "$dl_https_supported" ]; then
		state add 'errorSummary' 'errorDownloadUrlNoHttps' "$url"
	elif $dl_command "$url" "$dl_flag" "$dl_temp_file" 2>/dev/null; then
		sed 'N;s/\n/ /;s/\s\+/ /g;' "$dl_temp_file"
	else
		state add 'errorSummary' 'errorDownloadUrl' "$url"
	fi
	rm -f "$dl_temp_file"
}

load_package_config() {
	local param="$1"
	local user_file_check_result i
	config_load "$packageName"
	config_get_bool enabled                   'config' 'enabled' '0'
	config_get      fw_mask                   'config' 'fw_mask' 'ff0000'
	config_get      icmp_interface            'config' 'icmp_interface'
	config_get      ignored_interface         'config' 'ignored_interface'
	config_get_bool ipv6_enabled              'config' 'ipv6_enabled' '0'
	config_get_bool nft_rule_counter          'config' 'nft_rule_counter' '0'
	config_get_bool nft_set_auto_merge        'config' 'nft_set_auto_merge' '1'
	config_get_bool nft_set_counter           'config' 'nft_set_counter' '0'
	config_get_bool nft_set_flags_interval    'config' 'nft_set_flags_interval' '1'
	config_get_bool nft_set_flags_timeout     'config' 'nft_set_flags_timeout' '0'
	config_get      nft_set_gc_interval       'config' 'nft_set_gc_interval'
	config_get      nft_set_policy            'config' 'nft_set_policy' 'performance'
	config_get      nft_set_timeout           'config' 'nft_set_timeout'
	config_get      resolver_set              'config' 'resolver_set'
	config_get      resolver_instance         'config' 'resolver_instance' '*'
	config_get_bool strict_enforcement        'config' 'strict_enforcement' '1'
	config_get      supported_interface       'config' 'supported_interface'
	config_get      verbosity                 'config' 'verbosity' '2'
	config_get      procd_boot_delay          'config' 'procd_boot_delay' '0'
	config_get      procd_boot_timeout        'config' 'procd_boot_timeout' '30'
	config_get      procd_lan_interface       'config' 'procd_lan_interface'  'br-lan'
	config_get      procd_wan_ignore_status   'config' 'procd_wan_ignore_status' '0'
	config_get      procd_wan_interface       'config' 'procd_wan_interface'  'wan'
	config_get      procd_wan6_interface      'config' 'procd_wan6_interface' 'wan6'
	config_get      wan_ip_rules_priority     'config' 'wan_ip_rules_priority' '30000'
	config_get      wan_mark                  'config' 'wan_mark' '010000'
	fw_mask="0x${fw_mask}"
	wan_mark="0x${wan_mark}"
	if [ -x "$agh" ] && [ ! -s "$aghConfigFile" ]; then
		[ -s "${agh%/*}/AdGuardHome.yaml" ] && aghConfigFile="${agh%/*}/AdGuardHome.yaml"
	fi
	[ -n "$ipv6_enabled" ] && [ "$ipv6_enabled" -eq '0' ] && unset ipv6_enabled
	[ -n "$nft_user_set_counter" ] && [ "$nft_user_set_counter" -eq '0' ] && unset nft_user_set_counter
	fw_maskXor="$(printf '%#x' "$((fw_mask ^ 0xffffffff))")"
	fw_maskXor="${fw_maskXor:-0xff00ffff}"

	[ "$nft_rule_counter" != '1' ]       && unset nft_rule_counter
	[ "$nft_set_auto_merge" != '1' ]     && unset nft_set_auto_merge
	[ "$nft_set_counter" != '1' ]        && unset nft_set_counter
	[ "$nft_set_flags_interval" != '1' ] && unset nft_set_flags_interval
	[ "$nft_set_flags_timeout" != '1' ]  && unset nft_set_flags_timeout
	[ -z "${nft_set_flags_timeout}${nft_set_timeout}" ] && unset nft_set_gc_interval
	local nft_set_flags
	if [ -n "${nft_set_flags_interval}${nft_set_flags_timeout}" ]; then
		[ -n "$nft_set_flags_interval" ] && nft_set_flags='flags interval'
		if [ -n "$nft_set_flags_timeout" ]; then
			if [ -n "$nft_set_flags" ]; then
				nft_set_flags="${nft_set_flags}, timeout"
			else
				nft_set_flags='flags timeout'
			fi
		fi
	fi

	nft_rule_params="${nft_rule_counter:+counter}"

	nft_set_params=" \
		${nft_set_auto_merge:+ auto-merge;} \
		${nft_set_counter:+ counter;} \
		${nft_set_flags:+ $nft_set_flags;} \
		${nft_set_gc_interval:+ gc_interval "$nft_set_gc_interval";} \
		${nft_set_policy:+ policy "$nft_set_policy";} \
		${nft_set_timeout:+ timeout "$nft_set_timeout";} \
		"

}

load_environment() {
	_system_health_check() {
		local i _ret=0
		if [ "$(uci_get 'firewall' 'defaults' 'auto_includes')" = '0' ]; then
			uci_remove 'firewall' 'defaults' 'auto_includes'
			uci_commit firewall
		fi
		if [ "$(uci_get dhcp lan force 0)" = '0' ]; then
			state add 'warningSummary' 'warningDhcpLanForce'
		fi
		# TODO: implement ip-full check
		# state add 'errorSummary' 'errorRequiredBinaryMissing' 'ip-full'
		if ! nft_call list table inet fw4; then
			state add 'errorSummary' 'errorDefaultFw4TableMissing' 'fw4'
			_ret='1'
		fi
		if is_config_enabled 'dns_policy' || is_tor_running; then
			if ! nft_call list chain inet fw4 dstnat; then
				state add 'errorSummary' 'errorDefaultFw4ChainMissing' 'dstnat'
				_ret='1'
			fi
		fi
		for i in $chainsList; do
			if ! nft_call list chain inet fw4 "mangle_${i}"; then
				state add 'errorSummary' 'errorDefaultFw4ChainMissing' "mangle_${i}"
				_ret='1'
			fi
		done
		return "$_ret"
	}
	local param="$1" validation_result="$2"
	case "$param" in
		on_start)
			output 1 "Loading environment ($param) "
			load_package_config "$param"
			if [ "$enabled" -eq '0' ]; then
				output 1 "$_FAIL_\n"
				state add 'errorSummary' 'errorServiceDisabled'
				return 1
			fi
			if [ -n "$validation_result" ] && [ "$validation_result" != '0' ]; then
				output 1 "$_FAIL_\n"
				output "${_ERROR_}: The $packageName config validation failed!\n"
				output "Please check if the '$packageConfigFile' contains correct values for config options.\n"
				state add 'errorSummary' 'errorConfigValidation'
				return 1
			fi
			_system_health_check || { output 1 "$_FAIL_\n"; return 1; }
			resolver 'check_support' && resolver 'configure_instances'
			load_network "$param"
			output 1 "$_OK_\n"
		;;
		on_stop)
			output 1 "Loading environment ($param) "
			load_package_config "$param"
			load_network "$param"
			output 1 "$_OK_\n"
		;;
		on_triggers|*)
			load_package_config "$param"
			load_network "$param"
		;;
	esac
}

load_network() {
# shellcheck disable=SC2317
	_build_ifaces_supported() { is_supported_interface "$1" && ! str_contains "$ifacesSupported" "$1" && ifacesSupported="${ifacesSupported}${1} "; }
# shellcheck disable=SC2317
	_find_firewall_wan_zone() { [ "$(uci_get 'firewall' "$1" 'name')" = "wan" ] && firewallWanZone="$1"; }
	local i param="$1"
	local dev4 dev6
	if [ -z "$ifacesSupported" ]; then
		config_load 'firewall'
		config_foreach _find_firewall_wan_zone 'zone'
		for i in $(uci_get 'firewall' "$firewallWanZone" 'network'); do
			is_supported_interface "$i" && ! str_contains "$ifacesSupported" "$1" && ifacesSupported="${ifacesSupported}${i} "
		done
		config_load 'network'
		config_foreach _build_ifaces_supported 'interface'
	fi
	wanIface4="$procd_wan_interface"
	network_get_device dev4 "$wanIface4"
	[ -z "$dev4" ] && network_get_physdev dev4 "$wanIface4"
	[ -z "$wanGW4" ] && pbr_get_gateway4 wanGW4 "$wanIface4" "$dev4"
	if [ -n "$ipv6_enabled" ]; then
		wanIface6="$procd_wan6_interface"
		network_get_device dev6 "$wanIface6"
		[ -z "$dev6" ] && network_get_physdev dev6 "$wanIface6"
		[ -z "$wanGW6" ] && pbr_get_gateway6 wanGW6 "$wanIface6" "$dev6"
	fi

	case "$param" in
		on_boot|on_start)
			[ -n "$wanIface4" ] && output 2 "Using wan interface (${param}): $wanIface4 \n"
			[ -n "$wanGW4" ] && output 2 "Found wan gateway (${param}): $wanGW4 \n"
			[ -n "$wanIface6" ] && output 2 "Using wan6 interface (${param}): $wanIface6 \n"
			[ -n "$wanGW6" ] && output 2 "Found wan6 gateway (${param}): $wanGW6 \n"
		;;
	esac
	wanGW="${wanGW4:-$wanGW6}"
}

is_wan_up() {
	local sleepCount='1' param="$1"
	[ "$procd_wan_ignore_status" -eq '1' ] && return 0
	[ "$param" = 'on_boot' ] || procd_boot_timeout='1'
	if [ -z "$(uci_get network "$procd_wan_interface")" ]; then
		state add 'errorSummary' 'errorNoWanInterface' "$procd_wan_interface"
		state add 'errorSummary' 'errorNoWanInterfaceHint'
		return 1
	fi
	while [ -z "$wanGW" ]; do
		load_network "$param"
		if [ "$((sleepCount))" -gt "$((procd_boot_timeout))" ] || [ -n "$wanGW" ]; then break; fi
		output "$serviceName waiting for $procd_wan_interface gateway...\n"
		sleep 1
		network_flush_cache
		sleepCount=$((sleepCount+1))
	done
	if [ -n "$wanGW" ]; then
		return 0
	else
		state add 'errorSummary' 'errorNoWanGateway'
		return 1
	fi
}

nft_call() { [ -x "$nft" ] && "$nft" "$@" >/dev/null 2>&1; }
nft_file() {
	local i
	[ -x "$nft" ] || return 1
	case "$1" in
		add|add_command)
			shift
			echo "$*" >> "$nftTempFile"
		;;
		create)
			rm -f "$nftTempFile" "$nftPermFile"
			for i in "$nftTempFile" "$nftPermFile"; do 
				mkdir -p "${i%/*}"
			done
			{ echo '#!/usr/sbin/nft -f'; echo ''; } > "$nftTempFile"
		;;
		delete|rm|remove)
			rm -f "$nftTempFile" "$nftPermFile"
		;;
		enabled)
			return 0
		;;
		exists)
			[ -s "$nftPermFile" ] && return 0 || return 1
		;;
		install)
			[ -s "$nftTempFile" ] || return 1
			output "Installing fw4 nft file "
			if nft_call -c -f "$nftTempFile" && \
				cp -f "$nftTempFile" "$nftPermFile"; then
				output_okn
			else
				state add 'errorSummary' 'errorNftFileInstall' "$nftTempFile"
				output_failn
			fi
		;;
	esac
}
nft() { [ -x "$nft" ] && [ -n "$*" ] && nft_file 'add_command' "$@"; }
nft4() { nft "$@"; }
nft6() { [ -n "$ipv6_enabled" ] || return 0; nft "$@"; }
nftset() {
	local command="$1" iface="$2" target="${3:-dst}" type="${4:-ip}" uid="$5" comment="$6" param="$7" mark="$7"
	local nftset4 nftset6 i param4 param6
	local ipv4_error=1 ipv6_error=1
	nftset4="${nftPrefix}${iface:+_$iface}_4${target:+_$target}${type:+_$type}${uid:+_$uid}"
	nftset6="${nftPrefix}${iface:+_$iface}_6${target:+_$target}${type:+_$type}${uid:+_$uid}"

	[ -x "$nft" ] || return 1

	if [ "${#nftset4}" -gt '255' ]; then 
		state add 'errorSummary' 'errorNftsetNameTooLong' "$nftset4"
		return 1
	fi

	case "$command" in
		add)
			if is_mac_address "$param" || is_list "$param"; then
				nft4 add element inet "$nftTable" "$nftset4" "{ $param }" && ipv4_error=0
				nft6 add element inet "$nftTable" "$nftset6" "{ $param }" && ipv6_error=0
			elif is_ipv4 "$param"; then
				nft4 add element inet "$nftTable" "$nftset4" "{ $param }" && ipv4_error=0
			elif is_ipv6 "$param"; then
				nft6 add element inet "$nftTable" "$nftset6" "{ $param }" && ipv6_error=0
			else
				if [ "$target" = 'src' ]; then
					param4="$(ipv4_leases_to_nftset "$param")"
					param6="$(ipv6_leases_to_nftset "$param")"
				fi
				[ -z "$param4" ] && param4="$(resolveip_to_nftset4 "$param")"
				[ -z "$param6" ] && param6="$(resolveip_to_nftset6 "$param")"
				if [ -z "$param4" ] && [ -z "$param6" ]; then
					state add 'errorSummary' 'errorFailedToResolve' "$param"
				else
					[ -n "$param4" ] && nft4 add element inet "$nftTable" "$nftset4" "{ $param4 }" && ipv4_error=0
					[ -n "$param6" ] && nft6 add element inet "$nftTable" "$nftset6" "{ $param6 }" && ipv6_error=0
				fi
			fi
		;;
		add_dnsmasq_element)
			[ -n "$ipv6_enabled" ] || unset nftset6
			# shellcheck disable=SC2086
			echo "nftset=/${param}/4#inet#${nftTable}#${nftset4}${nftset6:+,6#inet#${nftTable}#$nftset6} # $comment" | tee -a $dnsmasqFileList >/dev/null 2>&1 && ipv4_error=0
		;;
		create)
			case "$type" in
				ip|net)
					nft4 add set inet "$nftTable" "$nftset4" "{ type ipv4_addr; $nft_set_params comment \"$comment\";}" && ipv4_error=0
					nft6 add set inet "$nftTable" "$nftset6" "{ type ipv6_addr; $nft_set_params comment \"$comment\";}" && ipv6_error=0
				;;
				mac)
					nft4 add set inet "$nftTable" "$nftset4" "{ type ether_addr; $nft_set_params comment \"$comment\";}" && ipv4_error=0
					nft6 add set inet "$nftTable" "$nftset6" "{ type ether_addr; $nft_set_params comment \"$comment\";}" && ipv6_error=0
				;;
				esac
		;;
		create_dnsmasq_set)
			nft4 add set inet "$nftTable" "$nftset4" "{ type ipv4_addr; $nft_set_params comment \"$comment\";}" && ipv4_error=0
			nft6 add set inet "$nftTable" "$nftset6" "{ type ipv6_addr; $nft_set_params comment \"$comment\";}" && ipv6_error=0
		;;
		create_user_set)
			case "$type" in
				ip|net)
					nft4 add set inet "$nftTable" "$nftset4" "{ type ipv4_addr; $nft_set_params comment \"$comment\";}" && ipv4_error=0
					nft6 add set inet "$nftTable" "$nftset6" "{ type ipv6_addr; $nft_set_params comment \"$comment\";}" && ipv6_error=0
					case "$target" in
						dst)
							nft4 add rule inet "$nftTable" "${nftPrefix}_prerouting" "${nftIPv4Flag}" daddr "@${nftset4}" "${nft_rule_params}" goto "${nftPrefix}_mark_${mark}" && ipv4_error=0
							nft6 add rule inet "$nftTable" "${nftPrefix}_prerouting" "${nftIPv6Flag}" daddr "@${nftset6}" "${nft_rule_params}" goto "${nftPrefix}_mark_${mark}" && ipv6_error=0
						;;
						src)
							nft4 add rule inet "$nftTable" "${nftPrefix}_prerouting" "${nftIPv4Flag}" saddr "@${nftset4}" "${nft_rule_params}" goto "${nftPrefix}_mark_${mark}" && ipv4_error=0
							nft6 add rule inet "$nftTable" "${nftPrefix}_prerouting" "${nftIPv6Flag}" saddr "@${nftset6}" "${nft_rule_params}" goto "${nftPrefix}_mark_${mark}" && ipv6_error=0
						;;
					esac
					;;
				mac)
					nft4 add set inet "$nftTable" "$nftset4" "{ type ether_addr; $nft_set_params comment \"$comment\"; }" && ipv4_error=0
					nft6 add set inet "$nftTable" "$nftset6" "{ type ether_addr; $nft_set_params comment \"$comment\"; }" && ipv6_error=0
					nft4 add rule inet "$nftTable" "${nftPrefix}_prerouting" ether saddr "@${nftset4}" "${nft_rule_params}" goto "${nftPrefix}_mark_${mark}" && ipv4_error=0
					nft6 add rule inet "$nftTable" "${nftPrefix}_prerouting" ether saddr "@${nftset6}" "${nft_rule_params}" goto "${nftPrefix}_mark_${mark}" && ipv6_error=0
					;;
				esac
		;;
		delete|destroy)
			nft_call delete set inet "$nftTable" "$nftset4" && ipv4_error=0
			nft_call delete set inet "$nftTable" "$nftset6" && ipv6_error=0
		;;
		delete_user_set)
			nft_call delete set inet "$nftTable" "$nftset4" && ipv4_error=0
			nft_call delete set inet "$nftTable" "$nftset6" && ipv6_error=0
			case "$type" in
				ip|net)
					case "$target" in
						dst)
							nft_call delete rule inet "$nftTable" "${nftPrefix}_prerouting" "$nftIPv4Flag" daddr "@${nftset4}" goto "${nftPrefix}_mark_${mark}" && ipv4_error=0
							nft_call delete rule inet "$nftTable" "${nftPrefix}_prerouting" "$nftIPv6Flag" daddr "@${nftset6}" goto "${nftPrefix}_mark_${mark}" && ipv6_error=0
						;;
						src)
							nft_call delete rule inet "$nftTable" "${nftPrefix}_prerouting" "$nftIPv4Flag" saddr "@${nftset4}" goto "${nftPrefix}_mark_${mark}" && ipv4_error=0
							nft_call delete rule inet "$nftTable" "${nftPrefix}_prerouting" "$nftIPv6Flag" saddr "@${nftset6}" goto "${nftPrefix}_mark_${mark}" && ipv6_error=0
						;;
					esac
					;;
				mac)
					nft_call delete rule inet "$nftTable" "${nftPrefix}_prerouting" "ether" saddr "@${nftset4}" goto "${nftPrefix}_mark_${mark}" && ipv4_error=0
					nft_call delete rule inet "$nftTable" "${nftPrefix}_prerouting" "ether" saddr "@${nftset6}" goto "${nftPrefix}_mark_${mark}" && ipv6_error=0
					;;
				esac
		;;
		flush|flush_user_set)
			nft_call flush set inet "$nftTable" "$nftset4" && ipv4_error=0
			nft_call flush set inet "$nftTable" "$nftset6" && ipv6_error=0
		;;
	esac
# nft6 returns true if IPv6 support is not enabled
	[ -z "$ipv6_enabled" ] && ipv6_error='1'
	if [ "$ipv4_error" -eq '0' ] || [ "$ipv6_error" -eq '0' ]; then
		return 0
	else
		return 1
	fi
}

cleanup_rt_tables() { 
	local i
# shellcheck disable=SC2013
	for i in $(grep -oh "${ipTablePrefix}_.*" "$rtTablesFile"); do
		! is_netifd_table "$i" && sed -i "/${i}/d" "$rtTablesFile"
	done
	sync
}

cleanup_main_chains() {
	local i j
	for i in $chainsList dstnat; do
		i="$(str_to_lower "$i")"
		nft_call flush chain inet "$nftTable" "${nftPrefix}_${i}"
	done
}

cleanup_marking_chains() {
	local i j
	for i in $(get_mark_nft_chains); do
		nft_call flush chain inet "$nftTable" "$i"
		nft_call delete chain inet "$nftTable" "$i"
	done
}

cleanup_sets() {
	local i
	for i in $(get_nft_sets); do
		nft_call flush set inet "$nftTable" "$i"
		nft_call delete set inet "$nftTable" "$i"
	done
}

state() {
	local action="$1" param="$2" value="${3//#/_}"
	shift 3
# shellcheck disable=SC2124
	local extras="$@"
	local line error_id error_extra label
	case "$action" in
		add)
			line="$(eval echo "\$$param")"
			eval "$param"='${line:+$line#}${value}${extras:+ $extras}'
		;;
		json)
			json_init
			json_add_object "$packageName"
			case "$param" in
				errorSummary)
					json_add_array 'errors';;
				warningSummary)
					json_add_array 'warnings';;
			esac
			if [ -n "$(eval echo "\$$param")" ]; then
				while read -r line; do
					if str_contains "$line" ' '; then
						error_id="${line% *}"
						error_extra="${line#* }"
					else
						error_id="$line"
					fi
					json_add_object
					json_add_string 'id' "$error_id"
					json_add_string 'extra' "$error_extra"
					json_close_object
				done <<EOF
$(eval echo "\$$param" | tr \# \\n)
EOF
			fi
			json_close_array
			json_close_object
			json_dump
		;;
		print)
			[ -z "$(eval echo "\$$param")" ] && return 0
			case "$param" in
				errorSummary)
					label="${_ERROR_}:";;
				warningSummary)
					label="${_WARNING_}:";;
			esac
				while read -r line; do
					if str_contains "$line" ' '; then
						error_id="${line% *}"
						error_extra="${line#* }"
						printf "%b $(get_text "$error_id")\n" "$label" "$error_extra"
					else
						error_id="$line"
						printf "%b $(get_text "$error_id")\n" "$label"
					fi
				done <<EOF
$(eval echo "\$$param" | tr \# \\n)
EOF
		;;
		set)
			eval "$param"='${value}${extras:+ $extras}'
		;;
	esac
}

_resolver_dnsmasq_confdir() {
	local cfg="$1"
	local confdir
	[ -z "$(uci_get 'dhcp' "$cfg")" ] && return 1;
	config_get confdir "$1" 'confdir'
	if [ -z "$confdir" ] && [ "$resolver_instance" != "*" ]; then
		state add 'warningSummary' 'warningDnsmasqInstanceNoConfdir' "$cfg"
	fi
	if [ -n "$confdir" ] && ! str_contains "$dnsmasqFileList" "$confdir"; then
		dnsmasqFile="${confdir}/${packageName}"
		dnsmasqFileList="${dnsmasqFileList:+$dnsmasqFileList }${dnsmasqFile}"
	fi
}

resolver() {
	local agh_version
	local param="$1" iface="$2" target="$3" type="$4" uid="$5" name="$6" value="$7"
	shift

	if [ "$param" = 'cleanup_all' ]; then
		local dfl
		for dfl in $dnsmasqFileList; do
			rm -f "$dfl"
		done
		return 0
	fi

	case "$resolver_set" in
		''|none)
			case "$param" in
				add_resolver_element) return 1;;
				create_resolver_set) return 1;;
				check_support) return 0;;
				cleanup) return 0;;
				configure) return 0;;
				init) return 0;;
				init_end) return 0;;
				kill) return 0;;
				reload) return 0;;
				restart) return 0;;
				compare_hash) return 0;;
				store_hash) return 0;;
			esac
		;;
		dnsmasq.nftset)
			case "$param" in
				add_resolver_element)
					[ -n "$resolver_set_supported" ] || return 1
					local d
					for d in $value; do
						nftset 'add_dnsmasq_element' "$iface" "$target" "$type" "$uid" "$name" "$d"
					done
#					nftset 'add_dnsmasq_element' "$iface" "$target" "$type" "$uid" "$name" "$(str_to_dnsmsaq_nftset "$value")"
				;;
				create_resolver_set)
					[ -n "$resolver_set_supported" ] || return 1
					nftset 'create_dnsmasq_set' "$iface" "$target" "$type" "$uid" "$name" "$value"
				;;
				check_support)
					if [ ! -x "$nft" ]; then
						state add 'errorSummary' 'errorNoNft'
						return 1
					fi
					if ! dnsmasq -v 2>/dev/null | grep -q 'no-nftset' && dnsmasq -v 2>/dev/null | grep -q 'nftset'; then
						resolver_set_supported='true'
						return 0
					else
						state add 'warningSummary' 'warningResolverNotSupported'
						return 1
					fi
				;;
				cleanup)
					if [ -n "$resolver_set_supported" ]; then
						local dfl
						for dfl in $dnsmasqFileList; do
							rm -f "$dfl"
						done
					fi
				;;
				configure)
					if [ -n "$resolver_set_supported" ]; then
						local dfl
						for dfl in $dnsmasqFileList; do
							mkdir -p "${dfl%/*}"
							chmod -R 660 "${dfl%/*}"
							chown -R root:dnsmasq "${dfl%/*}"
							touch "$dfl"
							chmod 660 "$dfl"
							chown root:dnsmasq "$dfl"
						done
					fi
				;;
				configure_instances)
					config_load 'dhcp'
					if [ "$resolver_instance" = "*" ]; then
						config_foreach _resolver_dnsmasq_confdir 'dnsmasq'
						dnsmasqFile="${dnsmasqFile:-$dnsmasqFileDefault}"
						str_contains "$dnsmasqFileList" "$dnsmasqFileDefault" || \
							dnsmasqFileList="${dnsmasqFileList:+$dnsmasqFileList }${dnsmasqFileDefault}"
					else
						for i in $resolver_instance; do
							_resolver_dnsmasq_confdir "@dnsmasq[$i]" \
							|| _resolver_dnsmasq_confdir "$i"
						done
						dnsmasqFile="${dnsmasqFile:-$dnsmasqFileDefault}"
						str_contains "$dnsmasqFileList" "$dnsmasqFileDefault" || \
							dnsmasqFileList="${dnsmasqFileList:-$dnsmasqFileDefault}"
					fi
				;;
				init) :;;
				init_end) :;;
				kill)
					[ -n "$resolver_set_supported" ] && killall -q -s HUP dnsmasq;;
				reload)
					[ -z "$resolver_set_supported" ] && return 1
					output 3 'Reloading dnsmasq '
					if /etc/init.d/dnsmasq reload >/dev/null 2>&1; then
						output_okn
						return 0
					else
						output_failn
						return 1
					fi
				;;
				restart)
					[ -z "$resolver_set_supported" ] && return 1
					output 3 'Restarting dnsmasq '
					if /etc/init.d/dnsmasq restart >/dev/null 2>&1; then
						output_okn
						return 0
					else
						output_failn
						return 1
					fi
				;;
				compare_hash)
					[ -z "$resolver_set_supported" ] && return 1
					local resolverNewHash
					if [ -s "$dnsmasqFile" ]; then
						resolverNewHash="$(md5sum "$dnsmasqFile" | awk '{ print $1; }')"
					fi
					[ "$resolverNewHash" != "$resolverStoredHash" ]
				;;
				store_hash)
					[ -s "$dnsmasqFile" ] && resolverStoredHash="$(md5sum "$dnsmasqFile" | awk '{ print $1; }')";;
			esac
		;;
		unbound.nftset)
			case "$param" in
				add_resolver_element) :;;
				create_resolver_set) :;;
				check_support) :;;
				cleanup) :;;
				configure) :;;
				init) :;;
				init_end) :;;
				kill) :;;
				reload) :;;
				restart) :;;
				compare_hash) :;;
				store_hash) :;;
			esac
		;;
	esac
}

# original idea by @egc112: https://github.com/egc112/OpenWRT-egc-add-on/tree/main/stop-dns-leak
dns_policy_routing() {
	local mark i nftInsertOption='add' proto='tcp udp' proto_i
	local param4 param6
	local negation value dest4 dest6 first_value
	local inline_set_ipv4_empty_flag inline_set_ipv6_empty_flag
	local name="$1" src_addr="$2" dest_dns="$3" uid="$4"
	local chain='dstnat' iface='dns'

	if [ -z "${dest_dns_ipv4}${dest_dns_ipv6}" ]; then
		processPolicyError='true'
		state add 'errorSummary' 'errorPolicyProcessNoInterfaceDns' "'$dest_dns'"
		return 1
	fi

	if [ -z "$ipv6_enabled" ] && is_ipv6 "$(str_first_word "$src_addr")"; then
		processPolicyError='true'
		state add 'errorSummary' 'errorPolicyProcessNoIpv6' "$name"
		return 1
	fi

	if { is_ipv4 "$(str_first_word "$src_addr")" && [ -z "$dest_dns_ipv4" ]; } || \
		{ is_ipv6 "$(str_first_word "$src_addr")" && [ -z "$dest_dns_ipv6" ]; }; then 
		processPolicyError='true'
		state add 'errorSummary' 'errorPolicyProcessMismatchFamily' "${name}: '$src_addr' '$dest_dns'"
		return 1
	fi

	for proto_i in $proto; do
		unset param4
		unset param6

		dest4="dport 53 dnat ip to ${dest_dns_ipv4}:53"
		dest6="dport 53 dnat ip6 to ${dest_dns_ipv6}:53"

		if [ -n "$src_addr" ]; then
			if [ "${src_addr:0:1}" = "!" ]; then
				negation='!='; src_addr="${src_addr//\!}"; nftset_suffix='_neg';
			else
				unset negation; unset nftset_suffix;
			fi
			value="$src_addr"
			first_value="$(str_first_word "$value")"
			if is_phys_dev "$first_value"; then
				param4="${param4:+$param4 }iifname ${negation:+$negation }{ $(inline_set "$value") }"
				param6="${param6:+$param6 }iifname ${negation:+$negation }{ $(inline_set "$value") }"
			elif is_mac_address "$first_value"; then
				param4="${param4:+$param4 }ether saddr ${negation:+$negation }{ $(inline_set "$value") }"
				param6="${param6:+$param6 }ether saddr ${negation:+$negation }{ $(inline_set "$value") }"
			elif is_domain "$first_value"; then
				local inline_set_ipv4='' inline_set_ipv6='' d=''
				for d in $value; do
					local resolved_ipv4 resolved_ipv6
					resolved_ipv4="$(resolveip_to_nftset4 "$d")"
					resolved_ipv6="$(resolveip_to_nftset6 "$d")"
					if [ -z "${resolved_ipv4}${resolved_ipv6}" ]; then
						state add 'errorSummary' 'errorFailedToResolve' "$d"
					else
					[ -n "$resolved_ipv4" ] && inline_set_ipv4="${inline_set_ipv4:+$inline_set_ipv4, }$resolved_ipv4"
					[ -n "$resolved_ipv6" ] && inline_set_ipv6="${inline_set_ipv6:+$inline_set_ipv6, }$resolved_ipv6"
					fi
				done
				[ -n "$inline_set_ipv4" ] || inline_set_ipv4_empty_flag='true'
				[ -n "$inline_set_ipv6" ] || inline_set_ipv6_empty_flag='true'
				param4="${param4:+$param4 }${nftIPv4Flag} saddr ${negation:+$negation }{ $inline_set_ipv4 }"
				param6="${param6:+$param6 }${nftIPv6Flag} saddr ${negation:+$negation }{ $inline_set_ipv6 }"
			else
				param4="${param4:+$param4 }${nftIPv4Flag} saddr ${negation:+$negation }{ $(inline_set "$value") }"
				param6="${param6:+$param6 }${nftIPv6Flag} saddr ${negation:+$negation }{ $(inline_set "$value") }"
			fi
		fi

		param4="$nftInsertOption rule inet ${nftTable} ${nftPrefix}_${chain} ${param4} ${nft_rule_params} meta nfproto ipv4 ${proto_i} ${dest4} comment \"$name\""
		param6="$nftInsertOption rule inet ${nftTable} ${nftPrefix}_${chain} ${param6} ${nft_rule_params} meta nfproto ipv6 ${proto_i} ${dest6} comment \"$name\""

		local ipv4_error='0' ipv6_error='0'
		if [ "$policy_routing_nft_prev_param4" != "$param4" ] && \
			[ -n "$first_value" ] && ! is_ipv6 "$first_value" && \
			[ -z "$inline_set_ipv4_empty_flag" ] && [ -n "$dest_dns_ipv4" ]; then
				nft4 "$param4" || ipv4_error='1'
				policy_routing_nft_prev_param4="$param4"
		fi
		if [ "$policy_routing_nft_prev_param6" != "$param6" ] && [ "$param4" != "$param6" ] && \
			[ -n "$first_value" ] && ! is_ipv4 "$first_value" && \
			[ -z "$inline_set_ipv6_empty_flag" ] && [ -n "$dest_dns_ipv6" ]; then
				nft6 "$param6" || ipv6_error='1'
				policy_routing_nft_prev_param6="$param6"
		fi

		if [ -n "$ipv6_enabled" ] && [ "$ipv4_error" -eq '1' ] && [ "$ipv6_error" -eq '1' ]; then
			processPolicyError='true'
			state add 'errorSummary' 'errorPolicyProcessInsertionFailed' "$name"
			state add 'errorSummary' 'errorPolicyProcessCMD' "nft $param4"
			state add 'errorSummary' 'errorPolicyProcessCMD' "nft $param6"
			logger -t "$packageName" "ERROR: nft $param4"
			logger -t "$packageName" "ERROR: nft $param6"
		elif [ -z "$ipv6_enabled" ] && [ "$ipv4_error" -eq '1' ]; then
			processPolicyError='true'
			state add 'errorSummary' 'errorPolicyProcessInsertionFailedIpv4' "$name"
			state add 'errorSummary' 'errorPolicyProcessCMD' "nft $param4"
			logger -t "$packageName" "ERROR: nft $param4"
		fi
	done
}

policy_routing() {
	local mark i nftInsertOption='add'
	local param4 param6 proto_i negation value dest4 dest6
	local nftset_suffix first_value_src first_value_dest
	local src_inline_set_ipv4_empty_flag src_inline_set_ipv6_empty_flag
	local dest_inline_set_ipv4_empty_flag dest_inline_set_ipv6_empty_flag
	local name="$1" iface="$2" src_addr="$3" src_port="$4" dest_addr="$5" dest_port="$6" proto chain uid="$9"
	proto="$(str_to_lower "$7")"
	chain="$(str_to_lower "$8")"
	chain="${chain:-prerouting}"
	mark=$(eval echo "\$mark_${iface//-/_}")

	if [ -z "$ipv6_enabled" ] && \
		{ is_ipv6 "$(str_first_word "$src_addr")" || is_ipv6 "$(str_first_word "$dest_addr")"; }; then
		processPolicyError='true'
		state add 'errorSummary' 'errorPolicyProcessNoIpv6' "$name"
		return 1
	fi

	if is_tor "$iface"; then
		unset dest_port
		unset proto
	elif is_xray "$iface"; then
		unset dest_port
		[ -z "$src_port" ] && src_port='0-65535'
		dest4="tproxy $nftIPv4Flag to: $(get_xray_traffic_port "$iface") accept"
		dest6="tproxy $nftIPv6Flag to: $(get_xray_traffic_port "$iface") accept"
	elif [ -n "$mark" ]; then
		dest4="goto ${nftPrefix}_mark_${mark}"
		dest6="goto ${nftPrefix}_mark_${mark}"
	elif [ "$iface" = "ignore" ]; then
		dest4="return"
		dest6="return"
	else
		processPolicyError='true'
		state add 'errorSummary' 'errorPolicyProcessUnknownFwmark' "$iface"
		return 1
	fi

	# TODO: implement actual family mismatch check on lists
#	if is_family_mismatch "$src_addr" "$dest_addr"; then 
#		processPolicyError='true'
#		state add 'errorSummary' 'errorPolicyProcessMismatchFamily' "${name}: '$src_addr' '$dest_addr'"
#		return 1
#	fi

	if [ -z "$proto" ]; then
		if [ -n "${src_port}${dest_port}" ]; then 
			proto='tcp udp'
		else
			proto='all'
		fi
	fi

	for proto_i in $proto; do
		unset param4
		unset param6
		if [ "$proto_i" = 'all' ]; then
			unset proto_i
		elif ! is_supported_protocol "$proto_i"; then
			processPolicyError='true'
			state add 'errorSummary' 'errorPolicyProcessUnknownProtocol' "${name}: '$proto_i'"
			return 1
		fi

		if [ -n "$src_addr" ]; then
			if [ "${src_addr:0:1}" = "!" ]; then
				negation='!='; value="${src_addr//\!}"; nftset_suffix='_neg';
			else
				unset negation; value="$src_addr"; unset nftset_suffix;
			fi
			first_value_src="$(str_first_word "$value")"
			if is_phys_dev "$first_value_src"; then
				param4="${param4:+$param4 }iifname ${negation:+$negation }{ $(inline_set "$value") }"
				param6="${param6:+$param6 }iifname ${negation:+$negation }{ $(inline_set "$value") }"
			elif is_mac_address "$first_value_src"; then
				param4="${param4:+$param4 }ether saddr ${negation:+$negation }{ $(inline_set "$value") }"
				param6="${param6:+$param6 }ether saddr ${negation:+$negation }{ $(inline_set "$value") }"
			elif is_domain "$first_value_src"; then
				local inline_set_ipv4='' inline_set_ipv6='' d=''
				unset src_inline_set_ipv4_empty_flag
				unset src_inline_set_ipv6_empty_flag
				for d in $value; do
					local resolved_ipv4 resolved_ipv6
					resolved_ipv4="$(resolveip_to_nftset4 "$d")"
					resolved_ipv6="$(resolveip_to_nftset6 "$d")"
					if [ -z "${resolved_ipv4}${resolved_ipv6}" ]; then
						state add 'errorSummary' 'errorFailedToResolve' "$d"
					else
					[ -n "$resolved_ipv4" ] && inline_set_ipv4="${inline_set_ipv4:+$inline_set_ipv4, }$resolved_ipv4"
					[ -n "$resolved_ipv6" ] && inline_set_ipv6="${inline_set_ipv6:+$inline_set_ipv6, }$resolved_ipv6"
					fi
				done
				[ -n "$inline_set_ipv4" ] || src_inline_set_ipv4_empty_flag='true'
				[ -n "$inline_set_ipv6" ] || src_inline_set_ipv6_empty_flag='true'
				param4="${param4:+$param4 }${nftIPv4Flag} saddr ${negation:+$negation }{ $inline_set_ipv4 }"
				param6="${param6:+$param6 }${nftIPv6Flag} saddr ${negation:+$negation }{ $inline_set_ipv6 }"
			else
				param4="${param4:+$param4 }${nftIPv4Flag} saddr ${negation:+$negation }{ $(inline_set "$value") }"
				param6="${param6:+$param6 }${nftIPv6Flag} saddr ${negation:+$negation }{ $(inline_set "$value") }"
			fi
		fi

		if [ -n "$dest_addr" ]; then 
			if [ "${dest_addr:0:1}" = "!" ]; then
				negation='!='; value="${src_addr//\!}"; nftset_suffix='_neg';
			else
				unset negation; value="$dest_addr"; unset nftset_suffix;
			fi
			first_value_dest="$(str_first_word "$value")"
			if is_phys_dev "$first_value_dest"; then
				param4="${param4:+$param4 }oifname ${negation:+$negation }{ $(inline_set "$value") }"
				param6="${param6:+$param6 }oifname ${negation:+$negation }{ $(inline_set "$value") }"
			elif is_domain "$first_value_dest"; then
				local target='dst' type='ip'
				if resolver 'create_resolver_set' "$iface" "$target" "$type" "$uid" "$name" && \
					resolver 'add_resolver_element' "$iface" "$target" "$type" "$uid" "$name" "$value"; then
					param4="${param4:+$param4 }${nftIPv4Flag} daddr ${negation:+$negation }@${nftPrefix}_${iface}_4_${target}_${type}_${uid}${nftset_suffix}"
					param6="${param6:+$param6 }${nftIPv6Flag} daddr ${negation:+$negation }@${nftPrefix}_${iface}_6_${target}_${type}_${uid}${nftset_suffix}"
				else
					local inline_set_ipv4='' inline_set_ipv6='' d=''
					unset dest_inline_set_ipv4_empty_flag
					unset dest_inline_set_ipv6_empty_flag
					for d in $value; do
						local resolved_ipv4 resolved_ipv6
						resolved_ipv4="$(resolveip_to_nftset4 "$d")"
						resolved_ipv6="$(resolveip_to_nftset6 "$d")"
						if [ -z "${resolved_ipv4}${resolved_ipv6}" ]; then
							state add 'errorSummary' 'errorFailedToResolve' "$d"
						else
						[ -n "$resolved_ipv4" ] && inline_set_ipv4="${inline_set_ipv4:+$inline_set_ipv4, }$resolved_ipv4"
						[ -n "$resolved_ipv6" ] && inline_set_ipv6="${inline_set_ipv6:+$inline_set_ipv6, }$resolved_ipv6"
						fi
					done
					[ -n "$inline_set_ipv4" ] || dest_inline_set_ipv4_empty_flag='true'
					[ -n "$inline_set_ipv6" ] || dest_inline_set_ipv6_empty_flag='true'
					param4="${param4:+$param4 }${nftIPv4Flag} daddr ${negation:+$negation }{ $inline_set_ipv4 }"
					param6="${param6:+$param6 }${nftIPv6Flag} daddr ${negation:+$negation }{ $inline_set_ipv6 }"
				fi
			else
				param4="${param4:+$param4 }${nftIPv4Flag} daddr ${negation:+$negation }{ $(inline_set "$value") }"
				param6="${param6:+$param6 }${nftIPv6Flag} daddr ${negation:+$negation }{ $(inline_set "$value") }"
			fi
		fi

		if [ -n "$src_port" ]; then
			if [ "${src_port:0:1}" = "!" ]; then
				negation='!='; value="${src_port:1}"
			else
				unset negation; value="$src_port";
			fi
			param4="${param4:+$param4 }${proto_i:+$proto_i }sport ${negation:+$negation }{ $(inline_set "$value") }"
			param6="${param6:+$param6 }${proto_i:+$proto_i }sport ${negation:+$negation }{ $(inline_set "$value") }"
		fi

		if [ -n "$dest_port" ]; then
			if [ "${dest_port:0:1}" = "!" ]; then
				negation='!='; value="${dest_port:1}"
			else
				unset negation; value="$dest_port";
			fi
			param4="${param4:+$param4 }${proto_i:+$proto_i }dport ${negation:+$negation }{ $(inline_set "$value") }"
			param6="${param6:+$param6 }${proto_i:+$proto_i }dport ${negation:+$negation }{ $(inline_set "$value") }"
		fi

		if is_tor "$iface"; then
			local dest_udp_53 dest_tcp_80 dest_udp_80 dest_tcp_443 dest_udp_443
			local ipv4_error='0' ipv6_error='0'
			local dest_i dest4 dest6
			chain='dstnat'
			param4="$nftInsertOption rule inet $nftTable ${nftPrefix}_${chain} ${nft_rule_params} meta nfproto ipv4 $param4"
			param6="$nftInsertOption rule inet $nftTable ${nftPrefix}_${chain} ${nft_rule_params} meta nfproto ipv6 $param6"
			dest_udp_53="udp dport 53 redirect to :${torDnsPort} comment \"Tor-DNS-UDP\""
			dest_tcp_80="tcp dport 80 redirect to :${torTrafficPort} comment \"Tor-HTTP-TCP\""
			dest_udp_80="udp dport 80 redirect to :${torTrafficPort} comment \"Tor-HTTP-UDP\""
			dest_tcp_443="tcp dport 443 redirect to :${torTrafficPort} comment \"Tor-HTTPS-TCP\""
			dest_udp_443="udp dport 443 redirect to :${torTrafficPort} comment \"Tor-HTTPS-UDP\""
			for dest_i in dest_udp_53 dest_tcp_80 dest_udp_80 dest_tcp_443 dest_udp_443; do
				eval "dest4=\$$dest_i"
				eval "dest6=\$$dest_i"
				nft4 "$param4" "$dest4" || ipv4_error='1'
				nft6 "$param6" "$dest6" || ipv6_error='1'
				if [ -n "$ipv6_enabled" ] && [ "$ipv4_error" -eq '1' ] && [ "$ipv6_error" -eq '1' ]; then
					processPolicyError='true'
					state add 'errorSummary' 'errorPolicyProcessInsertionFailed' "$name"
					state add 'errorSummary' 'errorPolicyProcessCMD' "nft $param4 $dest4"
					state add 'errorSummary' 'errorPolicyProcessCMD' "nft $param6 $dest6"
					logger -t "$packageName" "ERROR: nft $param4 $dest4"
					logger -t "$packageName" "ERROR: nft $param6 $dest6"
				elif [ -z "$ipv6_enabled" ] && [ "$ipv4_error" -eq '1' ]; then
					processPolicyError='true'
					state add 'errorSummary' 'errorPolicyProcessInsertionFailedIpv4' "$name"
					state add 'errorSummary' 'errorPolicyProcessCMD' "nft $param4 $dest4"
					logger -t "$packageName" "ERROR: nft $param4 $dest4"
				fi
			done
		else
			param4="$nftInsertOption rule inet $nftTable ${nftPrefix}_${chain} ${param4} ${nft_rule_params} ${dest4} comment \"$name\""
			param6="$nftInsertOption rule inet $nftTable ${nftPrefix}_${chain} ${param6} ${nft_rule_params} ${dest6} comment \"$name\""
			local ipv4_error='0' ipv6_error='0'
			if [ "$policy_routing_nft_prev_param4" != "$param4" ] && \
				[ -z "$src_inline_set_ipv4_empty_flag" ] && [ -z "$dest_inline_set_ipv4_empty_flag" ] && \
				[ "$filter_group_src_addr" != 'ipv6' ] && [ "$filter_group_src_addr" != 'ipv6_negative' ] && \
				[ "$filter_group_dest_addr" != 'ipv6' ] && [ "$filter_group_dest_addr" != 'ipv6_negative' ]; then
					nft4 "$param4" || ipv4_error='1'
					policy_routing_nft_prev_param4="$param4"
			fi
			if [ "$policy_routing_nft_prev_param6" != "$param6" ] && [ "$param4" != "$param6" ] && \
				[ -z "$src_inline_set_ipv6_empty_flag" ] && [ -z "$dest_inline_set_ipv6_empty_flag" ] && \
				[ "$filter_group_src_addr" != 'ipv4' ] && [ "$filter_group_src_addr" != 'ipv4_negative' ] && \
				[ "$filter_group_dest_addr" != 'ipv4' ] && [ "$filter_group_dest_addr" != 'ipv4_negative' ]; then
					nft6 "$param6" || ipv6_error='1'
					policy_routing_nft_prev_param6="$param6"
			fi
			if [ -n "$ipv6_enabled" ] && [ "$ipv4_error" -eq '1' ] && [ "$ipv6_error" -eq '1' ]; then
				processPolicyError='true'
				state add 'errorSummary' 'errorPolicyProcessInsertionFailed' "$name"
				state add 'errorSummary' 'errorPolicyProcessCMD' "nft $param4"
				state add 'errorSummary' 'errorPolicyProcessCMD' "nft $param6"
				logger -t "$packageName" "ERROR: nft $param4"
				logger -t "$packageName" "ERROR: nft $param6"
			elif [ -z "$ipv6_enabled" ] && [ "$ipv4_error" -eq '1' ]; then
				processPolicyError='true'
				state add 'errorSummary' 'errorPolicyProcessInsertionFailedIpv4' "$name"
				state add 'errorSummary' 'errorPolicyProcessCMD' "nft $param4"
				logger -t "$packageName" "ERROR: nft $param4"
			fi
		fi
	done
}

dns_policy_process() {
	local i j uid="$1"

	[ "$enabled" -gt '0' ] || return 0

	src_addr="$(str_extras_to_space "$src_addr")"
	dest_dns="$(str_extras_to_space "$dest_dns")"

	local dest_dns_interface dest_dns_ipv4 dest_dns_ipv6
	dest_dns_interface="$(str_first_value_interface "$dest_dns")"
	dest_dns_ipv4="$(str_first_value_ipv4 "$dest_dns")"
	dest_dns_ipv6="$(str_first_value_ipv6 "$dest_dns")"
	if is_supported_interface "$dest_dns_interface"; then
		local d
		for d in $(uci -q get network."$dest_dns_interface".dns); do
			if ! is_family_mismatch "$src_addr" "$d"; then
				if is_ipv4 "$d"; then
					dest_dns_ipv4="${dest_dns_ipv4:-$d}"
				elif is_ipv6 "$d"; then
					dest_dns_ipv6="${dest_dns_ipv6:-$d}"
				fi
			fi
		done
	fi

	unset processDnsPolicyError
	output 2 "Routing '$name' DNS to $dest_dns "
	if [ -z "$src_addr" ]; then
		state add 'errorSummary' 'errorPolicyNoSrcDest' "$name"
		output_fail; return 1;
	fi
	if [ -z "$dest_dns" ]; then
		state add 'errorSummary' 'errorPolicyNoDns' "$name"
		output_fail; return 1;
	fi

	# group by type of src_addr values so that one nft set can be created per type within policy
	local filter_list_src_addr='phys_dev phys_dev_negative mac_address mac_address_negative domain domain_negative ipv4 ipv4_negative ipv6 ipv6_negative'
	local filter_group_src_addr filtered_value_src_addr
	for filter_group_src_addr in $filter_list_src_addr; do
		filtered_value_src_addr=$(filter_options "$filter_group_src_addr" "$src_addr")
		if [ -n "$src_addr" ] && [ -n "$filtered_value_src_addr" ]; then
			if str_contains "$filter_group_src_addr" 'ipv4' && [ -z "$dest_dns_ipv4" ] ; then
					continue
			fi
			if str_contains "$filter_group_src_addr" 'ipv6' && [ -z "$dest_dns_ipv6" ] ; then
					continue
			fi
			dns_policy_routing "$name" "$filtered_value_src_addr" "$dest_dns" "$uid"
		fi
	done

	if [ -n "$processDnsPolicyError" ]; then
		output_fail
	else
		output_ok
	fi
}

policy_process() {
	local i j uid="$1"

	[ "$enabled" -gt '0' ] || return 0

	src_addr="$(str_extras_to_space "$src_addr")"
	src_port="$(str_extras_to_space "$src_port")"
	dest_addr="$(str_extras_to_space "$dest_addr")"
	dest_port="$(str_extras_to_space "$dest_port")"

	unset processPolicyError
	proto="$(str_to_lower "$proto")"
	[ "$proto" = 'auto' ] && unset proto
	[ "$proto" = 'all' ] && unset proto
	output 2 "Routing '$name' via $interface "
	if [ -z "${src_addr}${src_port}${dest_addr}${dest_port}" ]; then
		state add 'errorSummary' 'errorPolicyNoSrcDest' "$name"
		output_fail; return 1;
	fi
	if [ -z "$interface" ]; then
		state add 'errorSummary' 'errorPolicyNoInterface' "$name"
		output_fail; return 1;
	fi
	if ! is_supported_interface "$interface"; then
		state add 'errorSummary' 'errorPolicyUnknownInterface' "$name"
		output_fail; return 1;
	fi

	unset j
	for i in $src_addr; do
		if is_url "$i"; then
			i="$(process_url "$i")"
		fi
		j="${j:+$j }$i"
	done
	src_addr="$j"

	unset j
	for i in $dest_addr; do
		if is_url "$i"; then
			i="$(process_url "$i")"
		fi
		j="${j:+$j }$i"
	done
	dest_addr="$j"

	# TODO: if only src_addr is set add option 121 to dhcp leases?

	local filter_list_src_addr='phys_dev phys_dev_negative mac_address mac_address_negative domain domain_negative ipv4 ipv4_negative ipv6 ipv6_negative'
	local filter_list_dest_addr='domain domain_negative ipv4 ipv4_negative ipv6 ipv6_negative'
	local filter_group_src_addr filtered_value_src_addr filter_group_dest_addr filtered_value_dest_addr
	[ -z "$src_addr" ] && filter_list_src_addr='none'
	for filter_group_src_addr in $filter_list_src_addr; do
		filtered_value_src_addr=$(filter_options "$filter_group_src_addr" "$src_addr")
		if [ -z "$src_addr" ] || { [ -n "$src_addr" ] && [ -n "$filtered_value_src_addr" ]; }; then
			[ -z "$dest_addr" ] && filter_list_dest_addr='none'
			for filter_group_dest_addr in $filter_list_dest_addr; do
				filtered_value_dest_addr=$(filter_options "$filter_group_dest_addr" "$dest_addr")
				if [ -z "$dest_addr" ] || { [ -n "$dest_addr" ] && [ -n "$filtered_value_dest_addr" ]; }; then
					if str_contains "$filter_group_src_addr" 'ipv4' && str_contains "$filter_group_dest_addr" 'ipv6'; then
							continue
					fi
					if str_contains "$filter_group_src_addr" 'ipv6' && str_contains "$filter_group_dest_addr" 'ipv4'; then
							continue
					fi
					policy_routing "$name" "$interface" "$filtered_value_src_addr" "$src_port" "$filtered_value_dest_addr" "$dest_port" "$proto" "$chain" "$uid"
				fi
			done
		fi
	done

	if [ -n "$processPolicyError" ]; then
		output_fail
	else
		output_ok
	fi
}

interface_routing() {
	local action="$1" tid="$2" mark="$3" iface="$4" gw4="$5" dev="$6" gw6="$7" dev6="$8" priority="$9"
	local dscp s=0 i ipv4_error=1 ipv6_error=1
	if [ -z "$tid" ] || [ -z "$mark" ] || [ -z "$iface" ]; then
		state add 'errorSummary' 'errorInterfaceRoutingEmptyValues'
		return 1
	fi
	case "$action" in
		create)
			if is_netifd_table_interface "$iface"; then
				ipv4_error=0
				ip -4 rule del table "$tid" prio "$priority" >/dev/null 2>&1
				try ip -4 rule add fwmark "${mark}/${fw_mask}" table "$tid" priority "$priority" || ipv4_error=1
				try nft add chain inet "$nftTable" "${nftPrefix}_mark_${mark}" || ipv4_error=1 
				try nft add rule inet "$nftTable" "${nftPrefix}_mark_${mark} ${nft_rule_params} mark set mark and ${fw_maskXor} xor ${mark}" || ipv4_error=1
				try nft add rule inet "$nftTable" "${nftPrefix}_mark_${mark} return" || ipv4_error=1
				if [ -n "$ipv6_enabled" ]; then
					ipv6_error=0
					ip -6 rule del table "$tid" prio "$priority" >/dev/null 2>&1
					try ip -6 rule add fwmark "${mark}/${fw_mask}" table "$tid" priority "$((priority-1))" || ipv6_error=1
				fi
			else
				if ! grep -q "$tid ${ipTablePrefix}_${iface}" "$rtTablesFile"; then
					sed -i "/${ipTablePrefix}_${iface}/d" "$rtTablesFile"
					echo "$tid ${ipTablePrefix}_${iface}" >> "$rtTablesFile"
					sync
				fi
				ip -4 rule flush table "$tid" >/dev/null 2>&1
				ip -4 route flush table "$tid" >/dev/null 2>&1
				if [ -n "$gw4" ] || [ "$strict_enforcement" -ne '0' ]; then
					ipv4_error=0
					if [ -z "$gw4" ]; then
						try ip -4 route add unreachable default table "$tid" >/dev/null 2>&1 || ipv4_error=1
					#egc
					#else
					#	try ip -4 route add default via "$gw4" dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1
					elif is_wan "$iface"; then
						try ip -4 route add default via "$gw4" dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1
					else
						try ip -4 route add default dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1
					fi
# shellcheck disable=SC2086
					while read -r i; do
						i="$(echo "$i" | sed 's/ linkdown$//')"
						i="$(echo "$i" | sed 's/ onlink$//')"
						idev="$(echo "$i" | grep -Eso 'dev [^ ]*' | awk '{print $2}')"
						if ! is_supported_iface_dev "$idev"; then
							try ip -4 route add $i table "$tid" >/dev/null 2>&1 || ipv4_error=1
						fi
					done << EOF
					$(ip -4 route list table main)
EOF
#					$(ip -4 route list table main proto static)
					try ip -4 rule add fwmark "${mark}/${fw_mask}" table "$tid" priority "$priority" || ipv4_error=1
				fi
				try nft add chain inet "$nftTable" "${nftPrefix}_mark_${mark}" || ipv4_error=1 
				try nft add rule inet "$nftTable" "${nftPrefix}_mark_${mark} ${nft_rule_params} mark set mark and ${fw_maskXor} xor ${mark}" || ipv4_error=1
				try nft add rule inet "$nftTable" "${nftPrefix}_mark_${mark} return" || ipv4_error=1
				if [ -n "$ipv6_enabled" ]; then
					ipv6_error=0
					ip -6 rule flush table "$tid" >/dev/null 2>&1
					ip -6 route flush table "$tid" >/dev/null 2>&1
					if { [ -n "$gw6" ] && [ "$gw6" != "::/0" ]; } || [ "$strict_enforcement" -ne '0' ]; then
						if [ -z "$gw6" ] || [ "$gw6" = "::/0" ]; then
							try ip -6 route add unreachable default table "$tid" >/dev/null 2>&1 || ipv6_error=1
						elif ip -6 route list table main | grep -q " dev $dev6 "; then
							#ip -6 route add default via "$gw6" dev "$dev6" table "$tid" >/dev/null 2>&1 || ipv6_error=1
							if is_wan "$iface"; then
								#echo -e "\negc: WAN interface=$iface; gw6=$gw6; dev6=$dev6; tid=$tid\n"
								try ip -6 route add default via "$gw6" dev "$dev6" table "$tid" metric 128 >/dev/null 2>&1
							else
								try ip -6 route add default dev "$dev6" table "$tid" metric 128 >/dev/null 2>&1 || ipv6_error=1  # might need metric to override default route
							fi
							while read -r i; do
								i="$(echo "$i" | sed 's/ linkdown$//')"
								i="$(echo "$i" | sed 's/ onlink$//')"
								# shellcheck disable=SC2086
								try ip -6 route add $i table "$tid" >/dev/null 2>&1 || ipv6_error=1
							done << EOF
							$(ip -6 route list table main | grep " dev $dev6 ")
EOF
						else
							try ip -6 route add "$(ip -6 -o a show "$dev6" | awk '{print $4}')" dev "$dev6" table "$tid" >/dev/null 2>&1 || ipv6_error=1
							try ip -6 route add default dev "$dev6" table "$tid" >/dev/null 2>&1 || ipv6_error=1
							#try ip -6 route add default dev "$dev6" table "$tid" metric 128 >/dev/null 2>&1 || ipv6_error=1  # might need metric to override existing default route
						fi
						try ip -6 rule add fwmark "${mark}/${fw_mask}" table "$tid" priority "$((priority-1))" >/dev/null 2>&1 || ipv6_error=1
					fi
				fi
			fi
			if [ "$ipv4_error" -eq '0' ] || [ "$ipv6_error" -eq '0' ]; then
				dscp="$(uci_get "$packageName" 'config' "${iface}_dscp")"
				if [ "${dscp:-0}" -ge '1' ] && [ "${dscp:-0}" -le '63' ]; then
					try nft add rule inet "$nftTable" "${nftPrefix}_prerouting ${nftIPv4Flag} dscp ${dscp} ${nft_rule_params} goto ${nftPrefix}_mark_${mark}" || s=1
					if [ -n "$ipv6_enabled" ]; then
						try nft add rule inet "$nftTable" "${nftPrefix}_prerouting ${nftIPv6Flag} dscp ${dscp} ${nft_rule_params} goto ${nftPrefix}_mark_${mark}" || s=1
					fi
				fi
				if [ "$iface" = "$icmp_interface" ]; then
					try nft add rule inet "$nftTable" "${nftPrefix}_output ${nftIPv4Flag} protocol icmp ${nft_rule_params} goto ${nftPrefix}_mark_${mark}" || s=1
					if [ -n "$ipv6_enabled" ]; then
						try nft add rule inet "$nftTable" "${nftPrefix}_output ${nftIPv6Flag} protocol icmp ${nft_rule_params} goto ${nftPrefix}_mark_${mark}" || s=1
					fi
				fi
			else
				s=1
			fi
			return "$s"
		;;
		create_user_set)
			nftset 'create_user_set' "$iface" 'dst' 'ip' 'user' '' "$mark" || s=1
			nftset 'create_user_set' "$iface" 'src' 'ip' 'user' '' "$mark" || s=1
			nftset 'create_user_set' "$iface" 'src' 'mac' 'user' '' "$mark" || s=1
			return "$s"
		;;
		delete|destroy)
			ip rule del table "$tid" prio "$priority" >/dev/null 2>&1
			if ! is_netifd_table_interface "$iface"; then
				ip rule flush table "$tid" >/dev/null 2>&1
				ip route flush table "$tid" >/dev/null 2>&1
				sed -i "/${ipTablePrefix}_${iface}\$/d" "$rtTablesFile"
				sync
			fi
			return "$s"
		;;
		reload_interface)
			ip rule del table "$tid" prio "$priority" >/dev/null 2>&1
			is_netifd_table_interface "$iface" && return 0;
			ipv4_error=0
			if ! is_netifd_table_interface "$iface"; then
				ip rule flush table "$tid" >/dev/null 2>&1
				ip route flush table "$tid" >/dev/null 2>&1
			fi
			if [ -n "$gw4" ] || [ "$strict_enforcement" -ne '0' ]; then
				if [ -z "$gw4" ]; then
					try ip -4 route add unreachable default table "$tid" >/dev/null 2>&1 || ipv4_error=1
				#else
				#	try ip -4 route add default via "$gw4" dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1
				elif is_wan "$iface"; then
					try ip -4 route add default via "$gw4" dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1
				else
					try ip -4 route add default dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1
				fi
				try ip rule add fwmark "${mark}/${fw_mask}" table "$tid" priority "$priority" || ipv4_error=1
			fi
			if [ -n "$ipv6_enabled" ]; then
				ipv6_error=0
				if { [ -n "$gw6" ] && [ "$gw6" != "::/0" ]; } || [ "$strict_enforcement" -ne '0' ]; then
					if [ -z "$gw6" ] || [ "$gw6" = "::/0" ]; then
						try ip -6 route add unreachable default table "$tid" || ipv6_error=1
					elif ip -6 route list table main | grep -q " dev $dev6 "; then
						while read -r i; do
							# shellcheck disable=SC2086
							try ip -6 route add $i table "$tid" >/dev/null 2>&1 || ipv6_error=1
						done << EOF
						$(ip -6 route list table main | grep " dev $dev6 ")
EOF
					else
						try ip -6 route add "$(ip -6 -o a show "$dev6" | awk '{print $4}')" dev "$dev6" table "$tid" >/dev/null 2>&1 || ipv6_error=1
						try ip -6 route add default dev "$dev6" table "$tid" >/dev/null 2>&1 || ipv6_error=1
						#try ip -6 route add default dev "$dev6" table "$tid" metric 128 >/dev/null 2>&1 || ipv6_error=1  # might need metric to override existing default route
					fi
				fi
				try ip -6 rule add fwmark "${mark}/${fw_mask}" table "$tid" priority "$priority" || ipv6_error=1
			fi
			if [ "$ipv4_error" -eq '0' ] || [ "$ipv6_error" -eq '0' ]; then
				s=0
			else
				s=1
			fi
			return "$s"
		;;
	esac
}

json_add_gateway() {
	local action="$1" tid="$2" mark="$3" iface="$4" gw4="$5" dev4="$6" gw6="$7" dev6="$8" priority="$9" default="${10}"
	json_add_object ''
	json_add_string 'name' "$iface"
	json_add_string 'device_ipv4' "$dev4"
	json_add_string 'gateway_ipv4' "$gw4"
	json_add_string 'device_ipv6' "$dev6"
	json_add_string 'gateway_ipv6' "$gw6"
	if [ -n "$default" ]; then
		json_add_boolean 'default' '1'
	else
		json_add_boolean 'default' '0'
	fi
	json_add_string 'action' "$action"
	json_add_string 'table_id' "$tid"
	json_add_string 'mark' "$mark"
	json_add_string 'priority' "$priority"
	json_close_object
}

process_interface() {
	local gw4 gw6 dev dev6 s=0 dscp iface="$1" action="$2" reloadedIface="$3"
	local displayText dispDev dispGw4 dispGw6 dispStatus

	if [ "$iface" = 'all' ] && [ "$action" = 'prepare' ]; then
		config_load 'network'
		ifaceMark="$(printf '0x%06x' "$wan_mark")"
		ifacePriority="$wan_ip_rules_priority"
		unset ifaceTableID
		return 0
	fi

	if [ "$iface" = 'tor' ]; then 
		case "$action" in
			create|reload)
				torDnsPort="$(get_tor_dns_port)"
				torTrafficPort="$(get_tor_traffic_port)"
				displayText="${iface}/53->${torDnsPort}/80,443->${torTrafficPort}"
				gatewaySummary="${gatewaySummary}${displayText}\n"
				;;
			destroy)
				;;
		esac
		return 0
	fi

	if is_wg_server "$iface"; then
		local disabled listen_port
		disabled="$(uci_get 'network' "$iface" 'disabled')"
		listen_port="$(uci_get 'network' "$iface" 'listen_port')"
		case "$action" in
			create|reload)
				if [ "$disabled" != '1' ] && [ -n "$listen_port" ]; then
					if [ -n "$wanIface4" ]; then
						ip rule del sport "$listen_port" table "pbr_${wanIface4}" >/dev/null 2>&1
						ip rule add sport "$listen_port" table "pbr_${wanIface4}" >/dev/null 2>&1
					fi
					if [ -n "$ipv6_enabled" ] && [ -n "$wanIface6" ]; then
						ip rule del sport "$listen_port" table "pbr_${wanIface6}" >/dev/null 2>&1
						ip rule add sport "$listen_port" table "pbr_${wanIface6}" >/dev/null 2>&1
					fi
				fi
			;;
			destroy)
				if [ -n "$listen_port" ]; then
					ip rule del sport "$listen_port" table "pbr_${wanIface4}" >/dev/null 2>&1
					ip rule del sport "$listen_port" table "pbr_${wanIface6}" >/dev/null 2>&1
				fi
			;;
		esac
		str_contains_word "$supported_interface" "$iface" || return 0
	fi

	is_supported_interface "$iface" || return 0
	is_wan6 "$iface" && return 0
	[ "$((ifaceMark))" -gt "$((fw_mask))" ] && return 1

	if is_ovpn "$iface" && ! is_ovpn_valid "$iface"; then
		: || state add 'warningSummary' 'warningInvalidOVPNConfig' "$iface"
	fi

	network_get_device dev "$iface"
	[ -z "$dev" ] && network_get_physdev dev "$iface"
	if is_wan "$iface" && [ -n "$wanIface6" ] && str_contains "$wanIface6" "$iface"; then
		network_get_device dev6 "$wanIface6"
		[ -z "$dev6" ] && network_get_physdev dev6 "$wanIface6"
	fi

	[ -z "$dev6" ] && dev6="$dev"
	[ -z "$ifaceMark" ] && ifaceMark="$(printf '0x%06x' "$wan_mark")"
	[ -z "$ifacePriority" ] && ifacePriority="$wan_ip_rules_priority"

	case "$action" in
		pre_init)
			[ -z "$ifaceTableID" ] && ifaceTableID="$(get_rt_tables_non_pbr_next_id)"
			eval "pre_init_mark_${iface//-/_}"='$ifaceMark'
			eval "pre_init_priority_${iface//-/_}"='$ifacePriority'
			eval "pre_init_tid_${iface//-/_}"='$ifaceTableID'
			ifaceMark="$(printf '0x%06x' $((ifaceMark + wan_mark)))"
			ifacePriority="$((ifacePriority - 1))"
			ifaceTableID="$((ifaceTableID + 1))"
			return 0
		;;
		create)
			ifaceTableID="$(get_rt_tables_id "$iface")"
			[ -z "$ifaceTableID" ] && ifaceTableID="$(get_rt_tables_next_id)"
			eval "mark_${iface//-/_}"='$ifaceMark'
			eval "tid_${iface//-/_}"='$ifaceTableID'
			pbr_get_gateway4 gw4 "$iface" "$dev"
			pbr_get_gateway6 gw6 "$iface" "$dev6"
			dispGw4="${gw4:-0.0.0.0}"
			dispGw6="${gw6:-::/0}"
			[ "$iface" != "$dev" ] && dispDev="$dev"
			if is_default_dev "$dev"; then
				[ "$verbosity" = '1' ] && dispStatus="$_OK_" || dispStatus="$__OK__"
			fi
			displayText="${iface}/${dispDev:+$dispDev/}${dispGw4}${ipv6_enabled:+/$dispGw6}"
			output 2 "Setting up routing for '$displayText' "
			if interface_routing 'create' "$ifaceTableID" "$ifaceMark" "$iface" "$gw4" "$dev" "$gw6" "$dev6" "$ifacePriority"; then
				json_add_gateway 'create' "$ifaceTableID" "$ifaceMark" "$iface" "$gw4" "$dev" "$gw6" "$dev6" "$ifacePriority" "$dispStatus"
				gatewaySummary="${gatewaySummary}${displayText}${dispStatus:+ $dispStatus}\n"
				if is_netifd_table_interface "$iface"; then output_okb; else output_ok; fi
			else
				state add 'errorSummary' 'errorFailedSetup' "$displayText"
				output_fail
			fi
		;;
		create_user_set)
			ifaceTableID="$(get_rt_tables_id "$iface")"
			[ -z "$ifaceTableID" ] && ifaceTableID="$(get_rt_tables_next_id)"
			eval "mark_${iface//-/_}"='$ifaceMark'
			eval "tid_${iface//-/_}"='$ifaceTableID'
			pbr_get_gateway4 gw4 "$iface" "$dev"
			pbr_get_gateway6 gw6 "$iface" "$dev6"
			dispGw4="${gw4:-0.0.0.0}"
			dispGw6="${gw6:-::/0}"
			[ "$iface" != "$dev" ] && dispDev="$dev"
			if is_default_dev "$dev"; then
				[ "$verbosity" = '1' ] && dispStatus="$_OK_" || dispStatus="$__OK__"
			fi
			displayText="${iface}/${dispDev:+$dispDev/}${dispGw4}${ipv6_enabled:+/$dispGw6}"
			interface_routing 'create_user_set' "$ifaceTableID" "$ifaceMark" "$iface" "$gw4" "$dev" "$gw6" "$dev6" "$ifacePriority"
		;;
		destroy)
			ifaceTableID="$(get_rt_tables_id "$iface")"
			[ -z "$ifaceTableID" ] && ifaceTableID="$(get_rt_tables_next_id)"
			eval "mark_${iface//-/_}"='$ifaceMark'
			eval "tid_${iface//-/_}"='$ifaceTableID'
			pbr_get_gateway4 gw4 "$iface" "$dev"
			pbr_get_gateway6 gw6 "$iface" "$dev6"
			dispGw4="${gw4:-0.0.0.0}"
			dispGw6="${gw6:-::/0}"
			[ "$iface" != "$dev" ] && dispDev="$dev"
			if is_default_dev "$dev"; then
				[ "$verbosity" = '1' ] && dispStatus="$_OK_" || dispStatus="$__OK__"
			fi
			displayText="${iface}/${dispDev:+$dispDev/}${dispGw4}${ipv6_enabled:+/$dispGw6}"
			displayText="${iface}/${dispDev:+$dispDev/}${dispGw4}${ipv6_enabled:+/$dispGw6}"
			output 2 "Removing routing for '$displayText' "
			interface_routing 'destroy' "${ifaceTableID}" "${ifaceMark}" "${iface}"
			if is_netifd_table_interface "$iface"; then output_okb; else output_ok; fi
		;;
		reload)
			ifaceTableID="$(get_rt_tables_id "$iface")"
			[ -z "$ifaceTableID" ] && ifaceTableID="$(get_rt_tables_next_id)"
			eval "mark_${iface//-/_}"='$ifaceMark'
			eval "tid_${iface//-/_}"='$ifaceTableID'
			pbr_get_gateway4 gw4 "$iface" "$dev"
			pbr_get_gateway6 gw6 "$iface" "$dev6"
			dispGw4="${gw4:-0.0.0.0}"
			dispGw6="${gw6:-::/0}"
			[ "$iface" != "$dev" ] && dispDev="$dev"
			if is_default_dev "$dev"; then
				[ "$verbosity" = '1' ] && dispStatus="$_OK_" || dispStatus="$__OK__"
			fi
			displayText="${iface}/${dispDev:+$dispDev/}${dispGw4}${ipv6_enabled:+/$dispGw6}"
			gatewaySummary="${gatewaySummary}${displayText}${dispStatus:+ $dispStatus}\n"
		;;
		reload_interface)
			ifaceTableID="$(get_rt_tables_id "$iface")"
			[ -z "$ifaceTableID" ] && ifaceTableID="$(get_rt_tables_next_id)"
			eval "mark_${iface//-/_}"='$ifaceMark'
			eval "tid_${iface//-/_}"='$ifaceTableID'
			pbr_get_gateway4 gw4 "$iface" "$dev"
			pbr_get_gateway6 gw6 "$iface" "$dev6"
			dispGw4="${gw4:-0.0.0.0}"
			dispGw6="${gw6:-::/0}"
			[ "$iface" != "$dev" ] && dispDev="$dev"
			if is_default_dev "$dev"; then
				[ "$verbosity" = '1' ] && dispStatus="$_OK_" || dispStatus="$__OK__"
			fi
			displayText="${iface}/${dispDev:+$dispDev/}${dispGw4}${ipv6_enabled:+/$dispGw6}"
			if [ "$iface" = "$reloadedIface" ]; then
				output 2 "Reloading routing for '$displayText' "
				if interface_routing 'reload_interface' "$ifaceTableID" "$ifaceMark" "$iface" "$gw4" "$dev" "$gw6" "$dev6" "$ifacePriority"; then
					json_add_gateway 'reload_interface' "$ifaceTableID" "$ifaceMark" "$iface" "$gw4" "$dev" "$gw6" "$dev6" "$ifacePriority" "$dispStatus"
					gatewaySummary="${gatewaySummary}${displayText}${dispStatus:+ $dispStatus}\n"
					if is_netifd_table_interface "$iface"; then output_okb; else output_ok; fi
				else
					state add 'errorSummary' 'errorFailedReload' "$displayText"
					output_fail
				fi
			else
				gatewaySummary="${gatewaySummary}${displayText}${dispStatus:+ $dispStatus}\n"
			fi
		;;
	esac
#	ifaceTableID="$((ifaceTableID + 1))"
	ifaceMark="$(printf '0x%06x' $((ifaceMark + wan_mark)))"
	ifacePriority="$((ifacePriority - 2))"
	return $s
}

user_file_process() {
	local shellBin="${SHELL:-/bin/ash}"
	[ "$enabled" -gt '0' ] || return 0
	if [ ! -s "$path" ]; then
		state add 'errorSummary' 'errorUserFileNotFound' "$path"
		output_fail
		return 1
	fi
	if ! $shellBin -n "$path"; then
		state add 'errorSummary' 'errorUserFileSyntax' "$path"
		output_fail
		return 1
	fi
	if is_bad_user_file_nft_call "$path"; then
		state add 'errorSummary' 'errorIncompatibleUserFile' "$path"
		output_fail
		return 1
	fi
	output 2 "Running $path "
# shellcheck disable=SC1090
	if ! . "$path"; then
		state add 'errorSummary' 'errorUserFileRunning' "$path"
		if grep -q -w 'curl' "$path" && ! is_present 'curl'; then
			state add 'errorSummary' 'errorUserFileNoCurl' "$path"
		fi
		output_fail
		return 1
	else
		output_ok
		return 0
	fi
}

boot() {
	local procd_boot_delay
	config_load "$packageName"
	config_get procd_boot_delay 'config' 'procd_boot_delay' '0'
	nft_file 'delete'
	ubus -t 30 wait_for network.interface 2>/dev/null
	{ is_integer "$procd_boot_delay" && sleep "$procd_boot_delay"; \
		rc_procd start_service 'on_boot' && service_started 'on_boot'; } &
}

on_firewall_reload() { 
	if [ ! -e "$packageLockFile" ]; then
		logger -t "$packageName" "Reload on firewall action aborted: service is stopped."
		return 0
	else
		if nft_file 'exists'; then
			logger -t "$packageName" "Reusing the fw4 nft file."
		else
			rc_procd start_service 'on_firewall_reload' "$1"
		fi
	fi
}

on_interface_reload() { 
	if [ ! -e "$packageLockFile" ]; then
		logger -t "$packageName" "Reload on interface change aborted: service is stopped."
		return 0
	else
		rc_procd start_service 'on_interface_reload' "$1"
	fi
}

start_service() {
	local resolverStoredHash resolverNewHash i param="$1" reloadedIface

	load_environment "${param:-on_start}" "$(load_validate_config)" || return 1
#	is_wan_up "$param" || return 1

	process_interface 'all' 'prepare'
	config_foreach process_interface 'interface' 'pre_init'

	case "$param" in
		on_boot)
			serviceStartTrigger='on_start'
		;;
		on_firewall_reload)
			serviceStartTrigger='on_start'
		;;
		on_interface_reload)
			reloadedIface="$2"
			local tid pre_init_tid
			tid="$(get_rt_tables_id "$reloadedIface")"
			pre_init_tid="$(eval echo "\$pre_init_tid_${reloadedIface//-/_}")"
			if [ "$tid" = "$pre_init_tid" ]; then
				serviceStartTrigger='on_interface_reload'
			else
				serviceStartTrigger='on_start'
				unset reloadedIface
			fi
		;;
		on_reload)
			serviceStartTrigger='on_reload'
		;;
		on_restart)
			serviceStartTrigger='on_start'
		;;
	esac

	if [ -n "$reloadedIface" ] && ! is_supported_interface "$reloadedIface"; then
		return 0
	fi

	if [ -n "$(ubus_get_status error)" ] || [ -n "$(ubus_get_status warning)" ]; then
		serviceStartTrigger='on_start'
		unset reloadedIface
	elif ! is_service_running; then
		serviceStartTrigger='on_start'
		unset reloadedIface
	elif [ -z "$(ubus_get_status gateways)" ]; then
		serviceStartTrigger='on_start'
		unset reloadedIface
	else
		serviceStartTrigger="${serviceStartTrigger:-on_start}"
	fi

	procd_open_instance 'main'
	procd_set_param command /bin/true
	procd_set_param stdout 1
	procd_set_param stderr 1
	procd_open_data

	case $serviceStartTrigger in
		on_interface_reload)
			output 1 "Reloading Interface: $reloadedIface "
			json_add_array 'gateways'
			process_interface 'all' 'prepare'
			config_foreach process_interface 'interface' 'reload_interface' "$reloadedIface"
			json_close_array
			output 1 '\n'
		;;
		on_reload|on_start|*)
			resolver 'store_hash'
			resolver 'cleanup_all'
			resolver 'configure'
			resolver 'init'
			cleanup_main_chains
			cleanup_sets
			cleanup_marking_chains
			cleanup_rt_tables
			nft_file 'create'
			output 1 'Processing interfaces '
			json_add_array 'gateways'
			process_interface 'all' 'prepare'
			config_foreach process_interface 'interface' 'create'
			process_interface 'tor' 'destroy'
			is_tor_running && process_interface 'tor' 'create'
			json_close_array
			ip route flush cache
			output 1 '\n'
			if is_config_enabled 'policy'; then
				output 1 'Processing policies '
				config_load "$packageName"
				config_foreach load_validate_policy 'policy' policy_process
				output 1 '\n'
			fi
			if is_config_enabled 'dns_policy'; then
				output 1 'Processing dns policies '
				config_load "$packageName"
				config_foreach load_validate_dns_policy 'dns_policy' dns_policy_process
				output 1 '\n'
			fi
			if is_config_enabled 'include' || [ -d "/etc/${packageName}.d/" ]; then
				process_interface 'all' 'prepare'
				config_foreach process_interface 'interface' 'create_user_set'
				output 1 'Processing user file(s) '
				config_load "$packageName"
				config_foreach load_validate_include 'include' user_file_process
				if [ -d "/etc/${packageName}.d/" ]; then
					local i
					for i in "/etc/${packageName}.d/"*; do
						local enabled='1' path="$i"
						[ -f "$i" ] && user_file_process
					done
				fi
				output 1 '\n'
			fi
			nft_file 'install'
			resolver 'init_end'
			resolver 'compare_hash' && resolver 'restart'
		;;
	esac

	if [ -z "$gatewaySummary" ]; then
		state add 'errorSummary' 'errorNoGateways'
	fi
	json_add_object 'status'
	[ -n "$gatewaySummary" ] && json_add_string 'gateways' "$gatewaySummary"
	[ -n "$errorSummary" ] && json_add_string 'errors' "$errorSummary"
	[ -n "$warningSummary" ] && json_add_string 'warnings' "$warningSummary"
	if [ "$strict_enforcement" -ne '0' ] && str_contains "$gatewaySummary" '0.0.0.0'; then
		json_add_string 'mode' 'strict'
	fi
	json_close_object
	procd_close_data
	procd_close_instance
}

service_started() {
	if nft_file 'exists'; then
		procd_set_config_changed firewall
		if nft_file 'exists'; then
			[ -n "$gatewaySummary" ] && output "$serviceName (fw4 nft file mode) started with gateways:\n${gatewaySummary}"
		else
			output "$serviceName FAILED TO START in fw4 nft file mode!!!"
			output "Check the output of nft -c -f $nftTempFile"
		fi
	else
		[ -n "$gatewaySummary" ] && output "$serviceName (nft mode) started with gateways:\n${gatewaySummary}"
	fi
	state print 'errorSummary'
	state print 'warningSummary'
	touch "$packageLockFile"
	if [ -n "$errorSummary" ]; then
		return 2
	elif [ -n "$warningSummary" ]; then
		return 1
	else
		return 0
	fi
}

service_triggers() {
	local n
	load_environment 'on_triggers'
# shellcheck disable=SC2034
	PROCD_RELOAD_DELAY=$(( procd_reload_delay * 1000 ))
	procd_open_validate
		load_validate_config
		load_validate_policy
		load_validate_include
	procd_close_validate
	procd_open_trigger
		procd_add_config_trigger "config.change" 'openvpn' "/etc/init.d/${packageName}" reload 'on_openvpn_change'
		procd_add_config_trigger "config.change" "${packageName}" "/etc/init.d/${packageName}" reload
		for n in $ifacesSupported; do 
			procd_add_interface_trigger "interface.*" "$n" "/etc/init.d/${packageName}" on_interface_reload "$n"
		done
	procd_close_trigger
#	procd_add_raw_trigger "interface.*.up" 4000 "/etc/init.d/${packageName}" restart 'on_interface_up'
	if [ "$serviceStartTrigger" = 'on_start' ]; then
		output 3 "$serviceName monitoring interfaces: ${ifacesSupported}\n"
	fi
}

# shellcheck disable=SC2015
stop_service() {
	local i nft_file_mode
	! is_service_running && [ "$(get_rt_tables_next_id)" = "$(get_rt_tables_non_pbr_next_id)" ] && return 0
	[ "$1" = 'quiet' ] && quiet_mode 'on'
	load_environment 'on_stop'
	if nft_file 'exists'; then
		nft_file_mode=1
	fi
	output 'Resetting chains and sets '
	if nft_file 'delete' && cleanup_main_chains && cleanup_sets && cleanup_marking_chains; then
		output_okn
	else
		output_failn
	fi 
	output 1 'Resetting interfaces '
	config_load 'network'
	config_foreach process_interface 'interface' 'destroy'
	process_interface 'tor' 'destroy'
	cleanup_rt_tables
	output 1 "\n"
	ip route flush cache
	unset ifaceMark
	unset ifaceTableID
	resolver 'store_hash'
	resolver 'cleanup_all'
	resolver 'compare_hash' && resolver 'restart'
	if [ "$enabled" -ne '0' ]; then
		if [ -n "$nft_file_mode" ]; then
			output "$serviceName (fw4 nft file mode) stopped "; output_okn;
		else
			output "$serviceName (nft mode) stopped "; output_okn;
		fi
	fi
	rm -f "$packageLockFile"
}

version() { echo "$PKG_VERSION"; }

status_service() {
	local i dev dev6 wan_tid

	json_load "$(ubus call system board)"; json_select release; json_get_var dist distribution; json_get_var vers version
	if [ -n "$wanIface4" ]; then
		network_get_gateway wanGW4 "$wanIface4"
		network_get_device dev "$wanIface4"
	fi
	if [ -n "$wanIface6" ]; then
		network_get_device dev6 "$wanIface6"
		wanGW6=$(ip -6 route show | grep -m1 " dev $dev6 " | awk '{print $1}')
		[ "$wanGW6" = "default" ] && wanGW6=$(ip -6 route show | grep -m1 " dev $dev6 " | awk '{print $3}')
	fi
	while [ "${1:0:1}" = "-" ]; do param="${1//-/}"; eval "set_$param=1"; shift; done
	[ -e "/var/${packageName}-support" ] && rm -f "/var/${packageName}-support"
# shellcheck disable=SC2154
	status="$serviceName running on $dist $vers."
	[ -n "$wanIface4" ] && status="$status WAN (IPv4): ${wanIface4}/${dev}/${wanGW4:-0.0.0.0}."
	[ -n "$wanIface6" ] && status="$status WAN (IPv6): ${wanIface6}/${dev6}/${wanGW6:-::/0}."

	echo "$_SEPARATOR_"
	echo "$packageName - environment"
	echo "$status"
	echo "$_SEPARATOR_"
	dnsmasq --version 2>/dev/null | sed '/^$/,$d'
	if nft_file 'exists'; then
		echo "$_SEPARATOR_"
		echo "$packageName fw4 nft file: $nftPermFile"
		sed '1d;2d;' "$nftPermFile"
	fi
	echo "$_SEPARATOR_"
	echo "$packageName chains - policies"
	for i in $chainsList dstnat; do
		"$nft" -a list table inet "$nftTable" | sed -n "/chain ${nftPrefix}_${i} {/,/\t}/p"
	done
	echo "$_SEPARATOR_"
	echo "$packageName chains - marking"
	for i in $(get_mark_nft_chains); do
		"$nft" -a list table inet "$nftTable" | sed -n "/chain ${i} {/,/\t}/p"
	done
	echo "$_SEPARATOR_"
	echo "$packageName nft sets"
	for i in $(get_nft_sets); do
		"$nft" -a list table inet "$nftTable" | sed -n "/set ${i} {/,/\t}/p"
	done
	if [ -s "$dnsmasqFileDefault" ]; then
		echo "$_SEPARATOR_"
		echo "dnsmasq sets"
		cat "$dnsmasqFileDefault"
	fi
#	echo "$_SEPARATOR_"
#	ip rule list | grep "${packageName}_"
	echo "$_SEPARATOR_"
	tableCount="$(grep -c "${packageName}_" "$rtTablesFile")" || tableCount=0
	wan_tid=$(($(get_rt_tables_next_id)-tableCount))
	i=0; while [ "$i" -lt "$tableCount" ]; do
		echo "IPv4 table $((wan_tid + i)) route: $(ip -4 route show table $((wan_tid + i)) | grep default)"
		echo "IPv4 table $((wan_tid + i)) rule(s):"
		ip -4 rule list table "$((wan_tid + i))"
		if [ -n "$ipv6_enabled" ]; then
			echo "IPv6 table $((wan_tid + i)) route: $(ip -6 route show table $((wan_tid + i)) | grep default)"
			echo "IPv6 table $((wan_tid + i)) rule(s):"
			ip -6 route show table $((wan_tid + i))
		fi
		i=$((i + 1))
	done
}

# shellcheck disable=SC2120
load_validate_config() {
	uci_load_validate "$packageName" "$packageName" "$1" "${2}${3:+ $3}" \
		'enabled:bool:0' \
		'strict_enforcement:bool:1' \
		'ipv6_enabled:bool:0' \
		'resolver_set:or("", "none", "dnsmasq.nftset")' \
		'resolver_instance:list(or(integer, string)):*' \
		'verbosity:range(0,2):2' \
		'wan_mark:regex("[A-Fa-f0-9]{8}"):010000' \
		'fw_mask:regex("[A-Fa-f0-9]{8}"):ff0000' \
		'icmp_interface:or("", tor, uci("network", "@interface"))' \
		'ignored_interface:list(or(tor, uci("network", "@interface")))' \
		'supported_interface:list(or(ignore, tor, regex("xray_.*"), uci("network", "@interface")))' \
		'procd_boot_delay:integer:0' \
		'procd_boot_timeout:integer:30' \
		'procd_reload_delay:integer:0' \
		'procd_lan_interface:list(or(network)):br-lan' \
		'procd_wan_ignore_status:bool:0' \
		'procd_wan_interface:network:wan' \
		'procd_wan6_interface:network:wan6' \
		'wan_ip_rules_priority:uinteger:30000' \
		'webui_supported_protocol:list(string)' \
		'nft_rule_counter:bool:0'\
		'nft_set_auto_merge:bool:1'\
		'nft_set_counter:bool:0'\
		'nft_set_flags_interval:bool:1'\
		'nft_set_flags_timeout:bool:0'\
		'nft_set_gc_interval:or("", string)'\
		'nft_set_policy:or("", memory, performance):performance'\
		'nft_set_timeout:or("", string)'
}

# shellcheck disable=SC2120
load_validate_dns_policy() {
	local name
	local enabled
	local src_addr
	local dest_dns
	uci_load_validate "$packageName" 'policy' "$1" "${2}${3:+ $3}" \
		'name:string:Untitled' \
		'enabled:bool:1' \
		'src_addr:list(neg(or(host,network,macaddr,string)))' \
		'dest_dns:list(or(host,network,string))'
}

# shellcheck disable=SC2120
load_validate_policy() {
	local name
	local enabled
	local interface
	local proto
	local chain
	local src_addr
	local src_port
	local dest_addr
	local dest_port
	uci_load_validate "$packageName" 'policy' "$1" "${2}${3:+ $3}" \
		'name:string:Untitled' \
		'enabled:bool:1' \
		'interface:or("ignore", "tor", regex("xray_.*"), uci("network", "@interface")):wan' \
		'proto:or(string)' \
		'chain:or("", "forward", "input", "output", "prerouting", "postrouting", "FORWARD", "INPUT", "OUTPUT", "PREROUTING", "POSTROUTING"):prerouting' \
		'src_addr:list(neg(or(host,network,macaddr,string)))' \
		'src_port:list(neg(or(portrange,string)))' \
		'dest_addr:list(neg(or(host,network,string)))' \
		'dest_port:list(neg(or(portrange,string)))'
}

# shellcheck disable=SC2120
load_validate_include() {
	local path=
	local enabled=
	uci_load_validate "$packageName" 'include' "$1" "${2}${3:+ $3}" \
		'path:file' \
		'enabled:bool:0'
}