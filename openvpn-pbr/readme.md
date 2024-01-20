Simple script for OpenVPN Policy Based routing

OpenVPN has the ability to [run scripts](https://openvpn.net/community-resources/reference-manual-for-openvpn-2-6/#scripting-integration) from the openvpn config file  

In this repo you can find scripts which setup a simple Policy Based Routing by source.

Download script and adapt to your need.  
Upload script to your router to `/etc/openvpn`  
Make executable, from Commandline: `chmod +x /etc/openvpn/ovpn-pbr`  
In the OpenVPN config add: 'route-up /etc/openvpn/ovpn-pbr` this will execute the script on route up  





