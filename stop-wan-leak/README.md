### WAN leak while using a VPN
When using a VPN you do not want to leak traffic via the WAN.  

This directory contains scripts to monitor and stop wan-leakage  
`monitor-ip.sh` is a simple script to continuously check your external IP address from a LAN client to check if ther is leakage of trffic via the wan.  
`09-stop-wan-leak` is a hotplug script which can be used to stop forwarding while the router boots or interfaces go up/down this can be useful e.g.  if you are using the [PBR app](https://docs.openwrt.melmac.ca/pbr/1.2.1/).  
