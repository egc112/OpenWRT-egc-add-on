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
This is a permanent solution in contrast to the script but is easy to implement.  
First create a routing table with table number 101 with default route via the wan, but to creat this we need to know the gateway of the WAN.  
The gateway is revealed with, from the command line:  
`ifstatus wan | grep nexthop`  
Add the routing table to /etc/config/network:  
```
config route
	option interface 'wan'
	option target '0.0.0.0/0'
	option table '101'
	option gateway '<address of gateway>'
```
Next make a rule to use this table 101:  
```
config rule
	# for ip source:
	option src '192.168.30.0/24'
	# destination e.g. from all to dest
	option dest '25.52.71.40/32'
	# for interface
	#option in 'lan'
	# for proto
	option ipproto 'icmp`
	# for source port
	option sport '116'
	#table number to use for lookup
	option lookup '101'
```
  
Unfortunately this does not yet work for source port (sport the PR for that is pending so for sourceport we have to fall back to the following:  
Add the following rules, remove/adapt the rule you need, to /etc/rc.local or add via LuCI > System > Startup > Local Startup:
```
GATEWAY="$(ifstatus wan | grep nexthop | sed 's/[^0-9.]//g')"  
ip route add default via $GATEWAY table 101  
ip rule add sport 1194 table 101
ip rule add from 192.168.1.64/26 table 101
```
Reboot router to take effect
*Although this is persistent between reboots this is not persistent between network restarts, if the network is restarted either by yourself (`service network restart`) or by a process, the changes are gone, so the script option is the better one*  
