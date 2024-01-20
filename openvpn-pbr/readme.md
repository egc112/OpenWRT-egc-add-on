Simple scripts for OpenVPN Policy Based routing

OpenVPN has the ability to [run scripts](https://openvpn.net/community-resources/reference-manual-for-openvpn-2-6/#scripting-integration) from the openvpn config file  

In this repo you can find scripts which setup a simple Policy Based Routing by source.

Download scripts and adapt to your need.  
Upload scripts to your router to `/etc/openvpn`  

For up script:  
Make executable, from Commandline: `chmod +x /etc/openvpn/ovpn-pbr-up`  
In the OpenVPN config add: 'route-up /etc/openvpn/ovpn-pbr-up` this will execute the script on route up  

For down script:  
Make executable, from Commandline: `chmod +x /etc/openvpn/ovpn-pbr-down`  
In the OpenVPN config add: 'route-pre-down /etc/openvpn/ovpn-pbr-down` this will execute the script on route down  






