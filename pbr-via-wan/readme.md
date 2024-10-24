Name: 98-pbr-via-wan  
Version: 1.0.1 24-oct-2024 by egc  
Description: OpenWRT hoptlug script routing a specific sourceport, local IP address or interface etc. via the WAN  
Usage: e.g. When running a concurrent VPN client and VPN server or port forwarding via the WAN and needing to route the port  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;via the WAN back and/or when excluding some local IP addresses from using the VPN  
Installation:  
&nbsp;&nbsp;Set the VPN client interface as MYINTERFACE, this interface will be used as trigger for this script  
&nbsp;&nbsp;Remove the first # of the SPORT/IPADDR/ADDLOCALROUTES line to enable it, if desired  
&nbsp;&nbsp;Adapt the port (e.g. your local VPN server port) and/or local IP addresses you want to route via the WAN  
&nbsp;&nbsp;Copy script to /etc/hotplug.d/iface  
&nbsp;&nbsp;Reboot or restart network (service network restart)  

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
