Name: 98-pbr-via-wan  
Version: 12-feb-2024 by egc  
Description: OpenWRT hoptlug script routing a specific sourceport or local IP address via the WAN  
Usage: e.g. When running a concurrent VPN client and VPN server and needing to route the VPN server port via the WAN and/or  
	when excluding some local IP addresses from using the VPN  
Installation:   
 in this script below adapt the port (e.g. your local VPN server port) and/or local IP addresses you want to route via the WAN   
 copy script to /etc/hotplug.d/iface  
 reboot or restart network (service network restart)  

## Alternative solution
Add the following rules to /etc/rc.local or add via LuCI > System > Startup > Local Startup:
```
GATEWAY="$(ifstatus wan | grep nexthop | sed 's/[^0-9.]//g')"  
ip route add default via $GATEWAY table 101  
ip rule add sport 1194 table 101
ip rule add from 192.168.1.64/26 table 101
```
Reboot router to take effect

*Although this alternative solution is persistent between reboots this is not persistent between network restarts, if the network is restarted either by yourself (`service network restart`) or by a process, the changes are gone, so the script option is the better one*  
