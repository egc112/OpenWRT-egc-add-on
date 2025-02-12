Name: 97-custom-pbr-via-vpn  
Version: 08-apr-2024 by egc  
Description: OpenWRT hotplug script for routing ipaddress/interface via a VPN.  
Usage: simple hotplug script to route e.g. a guest interface or subnet or specific ipaddress via the VPN.  
Installation:  
Copy script from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/pbr-via-vpn/97-custom-pbr-via-vpn to `/etc/hotplug.d/iface`  
either with, from commandline (SSH):  
`curl -o /etc/hotplug.d/iface/97-custom-pbr-via-vpn https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/pbr-via-vpn/97-custom-pbr-via-vpn`  
or by clicking the download icon in the upper right corner of the script.  
In the script adapt the vpn-interface you want to use and ipaddress/interface you want to route via the VPN.  
Stop default routing via the VPN do:   
for WireGuard: disable "Route Allowed IPs" in the peer section  
for OpenVPN: in the openvpn config add:  
       `  pull-filter ignore "redirect-gateway"`  
  
Reboot or restart network (service network restart)  

