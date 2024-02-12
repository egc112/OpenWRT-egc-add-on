Simple scripts for OpenVPN Policy Based routing

OpenVPN has the ability to [run scripts](https://openvpn.net/community-resources/reference-manual-for-openvpn-2-6/#scripting-integration) from the openvpn config file  

In this repo you can find scripts which setup a simple Policy Based Routing by source.

These scripts will route the (ip) sources of your choice via the VPN and all other things via the WAN.  
To do this you first have to take care of disabling the default routing via the VPN.  
To stop default route via the VPN add the following to the OpenVPN config:  
`pull-filter ignore "redirect-gateway"`  
`redirect-private def1`  
(This last entry is optional but could be necessary if you want the $route_vpn_gateway/vpn_gateway to make routes in route-up scripts or openvpn config)  

Next, download scripts and adapt to your needs.  
Upload scripts to your router to `/etc/openvpn`  

For up script:  
Make executable, from Commandline: `chmod +x /etc/openvpn/ovpn-pbr-up`  
In the OpenVPN config add: `route-up /etc/openvpn/ovpn-pbr-up` this will execute the script on route up.  
Due to a recently resolved bug this should work on 23.05.2 and Main/snapshot builds from 21-jan-2024 or newer.  
For older builds use `up` instead of `route-up`  

For down script:  
Make executable, from Commandline: `chmod +x /etc/openvpn/ovpn-pbr-down`  
In the OpenVPN config add: `down /etc/openvpn/ovpn-pbr-down` this will execute the script on closing of the OpenVPN  






