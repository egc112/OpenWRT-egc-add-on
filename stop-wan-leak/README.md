Name: 09-stop-wan-leak  
Version: 0.91 4-nov-2025 by egc  
Description: OpenWRT hoptlug script disabling forwarding to stop a wan leak while PBR is starting  
Operating mode: The script is triggered by the WAN interface going up this can happen multiple times but after the WAN interface is up the critical period starts  
Usage: e.g. if you want to be sure there is no wan leak while using your VPN and PBR  
Note this only takes care of forwarding so blocking your lan client from accessing the wan, the router itself can still access the wan  
Installation:  
Copy script from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/stop-wan-leak/09-stop-wan-leak to `/etc/hotplug.d/iface` on your router  
either with, from commandline (SSH):  
```
  curl -o /etc/hotplug.d/iface/09-stop-wan-leak https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/stop-wan-leak/09-stop-wan-leak
```
or by clicking the download icon in the upper right corner of the script and using e.g. winscp to transfer the script.  
Edit script and set MYWANIF to your current wan, use `ifconfig` from commandline to check  
Reboot or restart network (service network restart)  
Check the working with `logread -e stop-wan-leak`  
Enable debugging by removing the # before the #DEBUG= ... on line 2, check debug output with `logread -e stop-wan-leak`  
