Missing IPv6 default route in pbr_XXX tables  
Setup  
R7800 23.05.5 NSS build  
PBR 1.1.7-25  
OpenVPN interface mullvad_ro  
Wireguard interface mullvad_se  
Both OpenVPN and Wireguard are setup with disabled default routing and are using IPv4 and IPv6.  
Wireguard by disabling Route Allowed IPs  
OpenVPN by adding:  
```  
pull-filter ignore "redirect-gateway"  
pull-filter ignore "redirect-gateway ipv6"  
pull-filter ignore "route-ipv6 0000::/2"  
pull-filter ignore "route-ipv6 4000::/2"  
pull-filter ignore "route-ipv6 8000::/2"  
pull-filter ignore "route-ipv6 C000::/2"  
```  
Main table has default route via the WAN:  
IPv4  
```  
root@R7800-1:~# ip -4 route show table main  
default via 192.168.0.1 dev eth0.2 proto static src 192.168.0.5  
10.15.0.0/16 dev tun11 proto kernel scope link src 10.15.0.13  
10.68.89.0/24 dev mullvad_se proto kernel scope link src 10.68.89.7  
149.40.50.98 via 192.168.0.1 dev eth0.2 proto static  
172.21.21.0/24 dev WGserver proto kernel scope link src 172.21.21.1  
172.21.21.3 dev WGserver proto static scope link  
172.21.21.10 dev WGserver proto static scope link  
192.168.0.0/24 dev eth0.2 proto kernel scope link src 192.168.0.5  
192.168.5.0/24 dev br-lan proto kernel scope link src 192.168.5.1  
192.168.15.0/24 dev br-guest proto kernel scope link src 192.168.15.1  
```  
  
Main table IPv6:  
```  
root@R7800-1:~# ip -6 route show table main  
default from 2001:1c03:59c1:3300::5 via fe80::bea5:11ff:fe3e:71f1 dev eth0.2 proto static metric 512 pref medium  
default from 2001:1c03:59c1:3300::/64 via fe80::bea5:11ff:fe3e:71f1 dev eth0.2 proto static metric 512 pref medium  
default from 2001:1c03:59c1:3304::/62 via fe80::bea5:11ff:fe3e:71f1 dev eth0.2 proto static metric 512 pref medium  
2001:1c03:59c1:3300::/56 from 2001:1c03:59c1:3300::5 via fe80::bea5:11ff:fe3e:71f1 dev eth0.2 proto static metric 512 pref medium  
2001:1c03:59c1:3300::/56 from 2001:1c03:59c1:3300::/64 via fe80::bea5:11ff:fe3e:71f1 dev eth0.2 proto static metric 512 pref medium  
2001:1c03:59c1:3300::/56 from 2001:1c03:59c1:3304::/62 via fe80::bea5:11ff:fe3e:71f1 dev eth0.2 proto static metric 512 pref medium  
2001:1c03:59c1:3300::/64 dev eth0.2 proto static metric 256 pref medium  
unreachable 2001:1c03:59c1:3300::/64 dev lo proto static metric 2147483647 pref medium  
2001:1c03:59c1:3304::/64 dev br-guest proto static metric 1024 pref medium  
2001:1c03:59c1:3305::/64 dev br-lan proto static metric 1024 pref medium  
unreachable 2001:1c03:59c1:3304::/62 dev lo proto static metric 2147483647 pref medium  
fc00:bbbb:bbbb:bb01::5:5906 dev mullvad_se proto kernel metric 256 pref medium  
fd84:348d:d649:5::/64 dev br-lan proto static metric 1024 pref medium  
fd84:348d:d649:15::/64 dev br-guest proto static metric 1024 pref medium  
unreachable fd84:348d:d649::/48 dev lo proto static metric 2147483647 pref medium  
fdda:d0d0:cafe:1301::/64 dev tun11 proto kernel metric 256 pref medium  
fddb:b40f:f9bc:4ba5::2 dev WGserver proto static metric 1024 pref medium  
fddb:b40f:f9bc:4ba5::/64 dev WGserver proto kernel metric 256 pref medium  
fe80::/64 dev br-lan proto kernel metric 256 pref medium  
fe80::/64 dev eth0.2 proto kernel metric 256 pref medium  
fe80::/64 dev eth1 proto kernel metric 256 pref medium  
fe80::/64 dev br-guest proto kernel metric 256 pref medium  
fe80::/64 dev eth0 proto kernel metric 256 pref medium  
fe80::/64 dev phy0-ap0 proto kernel metric 256 pref medium  
fe80::/64 dev tun11 proto kernel metric 256 pref medium  
```  
  
Table pbr_mullvad_se (WireGuard) IPv4:  
```  
root@R7800-1:~# ip -4 route show table pbr_mullvad_se  
default via 10.68.89.7 dev mullvad_se  
172.21.21.0/24 dev WGserver proto kernel scope link src 172.21.21.1  
172.21.21.3 dev WGserver proto static scope link  
172.21.21.10 dev WGserver proto static scope link  
192.168.5.0/24 dev br-lan proto kernel scope link src 192.168.5.1  
192.168.15.0/24 dev br-guest proto kernel scope link src 192.168.15.1  
```  
Table pbr_mullvad_se (WireGuard) IPv6:  
```  
root@R7800-1:~# ip -6 route show table pbr_mullvad_se  
fc00:bbbb:bbbb:bb01::5:5906 dev mullvad_se proto kernel metric 256 pref medium  
```  
Table pbr-mullvad_ro (OpenVPN) IPv4:  
```  
root@R7800-1:~# ip -4 route show table pbr_mullvad_ro  
default via 10.15.0.13 dev tun11  
172.21.21.0/24 dev WGserver proto kernel scope link src 172.21.21.1  
172.21.21.3 dev WGserver proto static scope link  
172.21.21.10 dev WGserver proto static scope link  
192.168.5.0/24 dev br-lan proto kernel scope link src 192.168.5.1  
192.168.15.0/24 dev br-guest proto kernel scope link src 192.168.15.1  
```  
Table pbr-mullvad_ro (OpenVPN) IPv6:  
```  
root@R7800-1:~# ip -6 route show table pbr_mullvad_ro  
fdda:d0d0:cafe:1301::/64 dev tun11 proto kernel metric 256 pref medium  
fe80::/64 dev tun11 proto kernel metric 256 pref medium  
```  
It is clear that the default route for IPv6 is missing for Wireguard and OpenVPN interfaces.  
The problematic line is [line 1692]( https://github.com/stangri/pbr/blob/f86303e755f8f1cf30fa666e9842df496ff70866/files/etc/init.d/pbr#L1692):  
```  
ip -6 route add default via "$gw6" dev "$dev6" table "$tid" >/dev/null 2>&1 || ipv6_error=1  
```  
Note the missing `try`, I think it is missing for a reason as it will error otherwise.  
The underlying cause is that OpenVPN and WireGuard interfaces are link scope meaning they do not need a gateway.  
This is contrast to the WAN which is a global scope interface which really needs a gateway for the default interface.  
For IPv4 link scope interfaces I think the gateway which is specified is just ignored but for IPv6 specifying the gateway results in an error.  
Bottom line do not specify a gateway for these interfaces.  
Because I am only sure about OpenVPN and Wireguard interfaces not needing a gateway you can do a simple hack like this preserving the gateway setting but if it fails set only the device:  
Replace the [line 1692]( https://github.com/stangri/pbr/blob/f86303e755f8f1cf30fa666e9842df496ff70866/files/etc/init.d/pbr#L1692) with this:  
```  
#ip -6 route add default via "$gw6" dev "$dev6" table "$tid" >/dev/null 2>&1 || ipv6_error=1  
if ! ip -6 route add default via "$gw6" dev "$dev6" table "$tid" >/dev/null 2>&1; then  
try ip -6 route add default dev "$dev6" table "$tid" metric 128 >/dev/null 2>&1 || ipv6_error=1 # might need metric to override default route  
fi  
```  
Basically try with a default gateway and if not successful just use only the device.  
When I have added this to the pbr script:  
Table pbr_mullvad_se (WireGuard) IPv6:  
```  
root@R7800-1:~# ip -6 route show table pbr_mullvad_se  
fc00:bbbb:bbbb:bb01::5:5906 dev mullvad_se proto kernel metric 256 pref medium  
default dev mullvad_se metric 128 pref medium  
```  
  
Table pbr-mullvad_ro (OpenVPN) IPv6:  
```  
root@R7800-1:~# ip -6 route show table pbr_mullvad_ro  
fdda:d0d0:cafe:1301::/64 dev tun11 proto kernel metric 256 pref medium  
fe80::/64 dev tun11 proto kernel metric 256 pref medium  
default dev tun11 metric 128 pref medium  
```  
  
The default IPv6 route for both the OpenVPN and WireGuard interfaces is now made with only the device and not the gateway.  
I checked that it works so you really do not need a gateway on a scope link interface.  
An ugly hack but it works for now  
  
  
  
Note the following needs more testing but was an exercise for my understanding:  
I went a step further and wanted to look if the following could work:  
Only if the interface is WAN then both for IPv4 and IPv6 use the gateway and in all other cases only use the device and not the gateway for the default route.  
I tried that and that works for IPv4  
I replaced the code in [line 1756]( https://github.com/stangri/pbr/blob/f86303e755f8f1cf30fa666e9842df496ff70866/files/etc/init.d/pbr#L1756) with:  
```  
#else  
# try ip -4 route add default via "$gw4" dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1  
elif is_wan "$iface"; then  
try ip -4 route add default via "$gw4" dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1  
else  
try ip -4 route add default dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1  
fi  
# shellcheck disable=SC2086  
```  
  
For IPv6 I tried the same [line 1692]( https://github.com/stangri/pbr/blob/f86303e755f8f1cf30fa666e9842df496ff70866/files/etc/init.d/pbr#L1692):  
```  
#ip -6 route add default via "$gw6" dev "$dev6" table "$tid" >/dev/null 2>&1 || ipv6_error=1  
if is_wan "$iface"; then  
#echo -e "\negc: WAN interface=$iface; gw6=$gw6; dev6=$dev6; tid=$tid\n"  
try ip -6 route add default via "$gw6" dev "$dev6" table "$tid" metric 128 >/dev/null 2>&1  
else  
try ip -6 route add default dev "$dev6" table "$tid" metric 128 >/dev/null 2>&1 || ipv6_error=1 # might need metric to override default route  
fi  
```  
  
But it was not working because the gw6 was not correct.  
The gw6 is correctly identified at startup but not when going through the interfaces, it seems because for IPv6 it is sending the WAN interface to `pbr_get_gateway6()` instead of WAN6  
So as an ugly hack I added the following code to `pbr_get_gateway6()` (line 183)  
Basically if the interface is WAN replace with WAN6 (ugly, ugly, I know but just for testing)  
https://github.com/stangri/pbr/blob/f86303e755f8f1cf30fa666e9842df496ff70866/files/etc/init.d/pbr#L183  
```  
pbr_get_gateway6() {  
local iface="$2" dev="$3" gw  
#egc  
if [ "$iface" == "$procd_wan_interface" ]; then  
iface="$procd_wan6_interface"  
fi  
network_get_gateway6 gw "$iface" true  
if [ -z "$gw" ] || [ "$gw" = '::/0' ] || [ "$gw" = '::0/0' ] || [ "$gw" = '::' ]; then  
gw="$(ip -6 a list dev "$dev" 2>/dev/null | grep inet6 | grep 'scope global' | awk '{print $2}')"  
fi  
eval "$1"='$gw'  
}  
```  
  
Anyway now everything came together and it sort of works.  
But still some loose ends, when using IPv6 I am testing for `is_wan` but I should test for `is_wan6` but that does not work as the WAN interface is used instead of WAN6 which of course has a relation with also not finding the IPv6 gateway so if you decide to take this road that needs attention  
I hope you can make sense of this and forget all the ugly hacks.  
  
  
Conclusion:  
IPv6 pbr_XXX tables are missing default route as link scope interfaces cannot and do not have to deal with gateway addresses  
As a workaround try this patch:  
```  
--- pbr-1.1.7-25.bash	2024-10-17 14:57:20.322141800 +0200  
+++ pbr-1.1.7-25-egc-2.bash	2024-10-17 15:32:43.051180800 +0200  
@@ -1700,7 +1706,10 @@  
 						if [ -z "$gw6" ] || [ "$gw6" = "::/0" ]; then  
 							try ip -6 route add unreachable default table "$tid" >/dev/null 2>&1 || ipv6_error=1  
 						elif ip -6 route list table main | grep -q " dev $dev6 "; then  
-							ip -6 route add default via "$gw6" dev "$dev6" table "$tid" >/dev/null 2>&1 || ipv6_error=1  
+							#ip -6 route add default via "$gw6" dev "$dev6" table "$tid" >/dev/null 2>&1 || ipv6_error=1  
+							if ! ip -6 route add default via "$gw6" dev "$dev6" table "$tid" >/dev/null 2>&1; then  
+								try ip -6 route add default dev "$dev6" table "$tid" metric 128 >/dev/null 2>&1 || ipv6_error=1  # might need metric to override default route  
+							fi  
 							while read -r i; do  
 								i="$(echo "$i" | sed 's/ linkdown$//')"  
 								i="$(echo "$i" | sed 's/ onlink$//')"  
```  
  
But consider only using gateway for WAN as other interfaces are probabaly always link scope (needs testing)  
This patch also deals with the absent gw6 when interface WAN is processed:  
```  
--- pbr-1.1.7-25.bash	2024-10-17 14:57:20.322141800 +0200  
+++ pbr-1.1.7-25-egc-3-clean.bash	2024-10-19 11:01:41.584512600 +0200  
@@ -182,6 +182,9 @@  
 }  
 pbr_get_gateway6() {  
 	local iface="$2" dev="$3" gw  
+	if [ "$iface" == "$procd_wan_interface" ]; then  
+		iface="$procd_wan6_interface"  
+	fi  
 	network_get_gateway6 gw "$iface" true  
 	if [ -z "$gw" ] || [ "$gw" = '::/0' ] || [ "$gw" = '::0/0' ] || [ "$gw" = '::' ]; then  
 		gw="$(ip -6 a list dev "$dev" 2>/dev/null | grep inet6 | grep 'scope global' | awk '{print $2}')"  
@@ -1672,8 +1675,10 @@  
 					ipv4_error=0  
 					if [ -z "$gw4" ]; then  
 						try ip -4 route add unreachable default table "$tid" >/dev/null 2>&1 || ipv4_error=1  
-					else  
+					elif is_wan "$iface"; then  
 						try ip -4 route add default via "$gw4" dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1  
+					else  
+						try ip -4 route add default dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1  
 					fi  
 # shellcheck disable=SC2086  
 					while read -r i; do  
@@ -1700,7 +1705,11 @@  
 						if [ -z "$gw6" ] || [ "$gw6" = "::/0" ]; then  
 							try ip -6 route add unreachable default table "$tid" >/dev/null 2>&1 || ipv6_error=1  
 						elif ip -6 route list table main | grep -q " dev $dev6 "; then  
-							ip -6 route add default via "$gw6" dev "$dev6" table "$tid" >/dev/null 2>&1 || ipv6_error=1  
+							if is_wan "$iface"; then  
+								try ip -6 route add default via "$gw6" dev "$dev6" table "$tid" metric 128 >/dev/null 2>&1  
+							else  
+								try ip -6 route add default dev "$dev6" table "$tid" metric 128 >/dev/null 2>&1 || ipv6_error=1  # might need metric to override default route  
+							fi  
 							while read -r i; do  
 								i="$(echo "$i" | sed 's/ linkdown$//')"  
 								i="$(echo "$i" | sed 's/ onlink$//')"  
@@ -1763,8 +1772,10 @@  
 			if [ -n "$gw4" ] || [ "$strict_enforcement" -ne '0' ]; then  
 				if [ -z "$gw4" ]; then  
 					try ip -4 route add unreachable default table "$tid" >/dev/null 2>&1 || ipv4_error=1  
-				else  
+				elif is_wan "$iface"; then  
 					try ip -4 route add default via "$gw4" dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1  
+				else  
+					try ip -4 route add default dev "$dev" table "$tid" >/dev/null 2>&1 || ipv4_error=1  
 				fi  
 				try ip rule add fwmark "${mark}/${fw_mask}" table "$tid" priority "$priority" || ipv4_error=1  
 			fi  
```  
  
  
  
Note to myself:  
For testing always restart network, openvpn and pbr  
```  
service network restart && service openvpn restart && service pbr stop && service pbr start  
```  

