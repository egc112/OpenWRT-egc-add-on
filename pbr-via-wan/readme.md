Name: 98-pbr-via-wan  
Version: 1.0.2 24-oct-2024 by egc  
Description: OpenWRT hotplug script routing a specific sourceport, local IP address or interface etc. via the WAN  
Usage: e.g. When running a concurrent VPN client and VPN server or port forwarding via the WAN and needing to route the port  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;via the WAN back and/or when excluding some local IP addresses from using the VPN  
Installation:  
Copy script from:   
 https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/pbr-via-wan/98-pbr-via-wan to `/etc/hotplug.d/iface/`  
either with, from commandline (SSH):  
```
curl -o /etc/hotplug.d/iface/98-pbr-via-wan https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/pbr-via-wan/98-pbr-via-wan
```
or by clicking the download icon in the upper right corner of the script.  
Set the VPN client interface as MYINTERFACE, this interface will be used as trigger for this script  
Remove the first # of the SPORT/IPADDR/ADDLOCALROUTES line to enable it, if desired  
Adapt the port (e.g. your local VPN server port) and/or local IP addresses you want to route via the WAN  
Reboot or restart network (service network restart)  

## Alternative solution
Add the following rules, remove/adapt the rule you need, to /etc/rc.local or add via LuCI > System > Startup > Local Startup:
```
GATEWAY="$(ifstatus wan | grep nexthop | sed 's/[^0-9.]//g')"  
ip route add default via $GATEWAY table 101  
ip rule add sport 1194 table 101
ip rule add from 192.168.1.64/26 table 101
```
Reboot router to take effect

*Although this alternative solution is persistent between reboots this is not persistent between network restarts, if the network is restarted either by yourself (`service network restart`) or by a process, the changes are gone, so the script option is the better one*  
