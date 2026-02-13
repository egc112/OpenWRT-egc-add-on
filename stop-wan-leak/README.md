### WAN leak while using a VPN
When using a VPN you do not want to leak traffic via the WAN.  

This directory contains scripts to monitor and stop wan-leakage  
`monitor-ip.sh` is a simple script to continuously check your external IP address from a LAN client to check if ther is leakage of trffic via the wan.  
Instalation and usage instructions can be found in the script.  
   

`09-stop-wan-leak` is a hotplug script which can be used to stop forwarding while the router boots or interfaces go up/down this can be useful e.g. if you are using the [PBR app](https://docs.openwrt.melmac.ca/pbr/1.2.1/).  
Instalation and usage instructions can be found in the script.  
  
`pbr-1.2.1-97-stop-wan-leak-1.bash` is a replacement for your pbr script which is pbr-1.2.1-97 with some extra code which will stop forwarding during (re)start/reload or when interfaces go up and down so this should be the best way to stop wan leakage while using the [PBR app](https://docs.openwrt.melmac.ca/pbr/1.2.1/).  
Before you start make a backup of your settings and make sure you have a copy of your firmware, you should not need it but better safe then sorry.  
Download the test version: open pbr-1.2.1-97-stop-wan-leak-1.bash and click the download icon in the upper right hand corner.
On your router, rename the original /etc/init.d/pbr script to /etc/init.d/pbr-org, and/or copy it to your Desktop.
Copy the new script to /etc/init.d/pbr  
To stop wan leakage while using PBR add to the PBR config: `option stop_wan_leak '1'`  
Reboot the router  

How to check if you do not have a leakage via the wan:  
Manually:  
If you have setup PBR to use a VPN for your PC/workstation then you can view the external IP address if you go to `ipleak.net` in your webbrowser.  
When doing a reboot of the router or on your router doing things like service br start or ifup wan or ifup < wg_interface > you can check on your PC/workstation by repeatedly refreshing your webbrowser with `ipleak.net`  
Automatically:  
I have created a monitor-ip.sh script which continuously checks your external IP address, it is designed to run on Linux but it will probably also run under WSL on Windows.  
Download the script to your home directory and make executable, while in your home directory: chmod +x ./monitor-ip.sh.  
To execute the script from your home directory: ./monitor-ip.sh, stop the script with CTRL + C  
