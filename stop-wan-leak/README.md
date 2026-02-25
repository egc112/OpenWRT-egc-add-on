## WAN leak while using a VPN ##
When using a VPN you do not want to leak traffic via the WAN as that will expose your actual IP address.  
This can happen if your default route is via the WAN and you use PBR to route traffic via the VPN.  

This directory contains scripts to monitor and stop wan-leakage  
`monitor-ip.sh` is a simple script to continuously check your external IP address from a LAN client to check if there is leakage of traffic via the wan.  
Instalation and usage instructions can be found in the script.  
For Windows users I have also added a powershell verion of the script.  
  
`09-stop-wan-leak` is a hotplug script which can be used to stop forwarding while the router boots or interfaces go up/down this can be useful e.g. if you are using [Policy Based Routing](https://openwrt.org/docs/guide-user/network/routing/pbr) or the  [PBR-app](https://docs.openwrt.melmac.ca/pbr/1.2.2/).  
Instalation and usage instructions can be found in the script.  
  
`pbr-1.2.2-r7-stop-wan-leak.bash` is a replacement for the `PBR-app` script with some extra code which will stop forwarding during (re)start/reload or when interfaces go up and down so this should be the best way to stop wan leakage while using the [PBR app](https://docs.openwrt.melmac.ca/pbr/1.2.2/).  
Before you start make a backup of your settings and make sure you have a copy of your firmware, you should not need it but better safe then sorry.  
Download the test version:  
open `pbr-1.2.2-r7-stop-wan-leak.bash` and click the download icon in the upper right hand corner to download the file to your desktop.  
On your router:  
rename the original `/etc/init.d/pbr` script to `/etc/init.d/pbr-org`, and/or copy it to your desktop.  
Copy `pbr-1.2.2-r7-stop-wan-leak.bash` from your desktop to `/etc/init.d/pbr` on your router, efectively replacing the old `/etc/init.d/pbr` with this new pbr script.  
To stop wan leakage while using PBR **add to the PBR config**: `option stop_wan_leak '1'`  
Reboot the router  

### How to check if you do not have leakage via the wan ###  
Manually:  
If you have setup PBR to use a VPN for your PC/workstation then you can view the external IP address if you go to `ipleak.net` in your webbrowser.  
When doing a reboot of the router or on your router doing things like service br start or ifup wan or ifup < wg_interface > you can check on your PC/workstation by repeatedly refreshing your webbrowser with `ipleak.net`  
Automatically:  
I have created a monitor-ip.sh script which continuously checks your external IP address, it is designed to run on Linux but it will probably also run under WSL on Windows.  
Download the script to your home directory and make executable, while in your home directory: `chmod +x ./monitor-ip.sh`   
To execute the script from your home directory: `./monitor-ip.sh`, stop the script with CTRL + C  
  
### How to test for possible leakage ###  
While you monitor external IP from your LAN client e.g. with the `monitor-ip.sh script`, you can perform the following actions from your routers command line:  
`service pbr restart`  
`service pbr start`  
`service pbr reload`  
`ifup wan`  
`ifup < vpn interface > `  
`service network restart`  
`service firewall restart`  
`reboot`  
