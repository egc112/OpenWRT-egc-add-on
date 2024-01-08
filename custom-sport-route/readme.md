This is a Work in progress so only in its early stages and not tested and finalized  

Name: 98-custom-sport-route   
Version: 08-jan-2024  
Description: OpenWRT hoptlug script routing a specific sourceport via the WAN  
Usage: When running a concurrent VPN client and VPN server and needing to route the VPN server port via the WAN  
Installation:   
  copy script to /etc/hotplug.d/net  
  make executable: cmod +x /etc/hotplug.d/custom-sport-route  
  adapt the port you want to route via the WAN  

## Alternative solution
Add the following rules to /etc/rc.local or add via LuCI > System >Startup > Local Startup:
```
GATEWAY="$(ifstatus wan | grep nexthop | sed 's/[^0-9.]//g')"  
ip route add default via $GATEWAY table 101  
ip rule add sport 1194 table 101 
```
Althoug this is persistent between reboots this is not persistent between network restarts, if you restart the network (`service network restart`) the cnages are gone.

