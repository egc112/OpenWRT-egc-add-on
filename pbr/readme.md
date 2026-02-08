This directory contains a test version for PBR.  
Before you start make a backup of your settings and make sure you have a copy of your firmware, you should not need it but better safe then sorry.  
Download the test version: open `pbr-1.2.1-93-stop-wan-leak-egc-1.bash` and click the download icon in the upper right hand corner.  
On your router, rename the original `/etc/init.d/pbr` script to `/etc/init.d/pbr-org`, and/or copy it to your Desktop.  
Copy the new script to `/etc/init.d/pbr`
<!-- Make the new script executable: `chmod +x /etc/init.d/pbr` -->
**To stop wan leakage while PBR restarts add to the PBR config: `option stop_wan_leak '1'`**  
Reboot the router  

How to check if you do not have a leakage via the wan:  
Manually: 
If you have setup PBR to use a VPN for your PC/workstation then you can view the external IP address if you go to `ipleak.net` in your webbrowser.  
When doing a reboot of the router or on your router doing things like `service br start` or `ifup wan` or `ifup < wg_interface >` you can check on your PC/workstation by repeatedly refreshing your webbrowser with `ipleak.net`
automatically:  
I have created a `monitor-ip.sh` script which continuously checks your external IP address it is designed to run on Linux it will probably also run under WSL on Linux.  
Download the script to your home directory and make executable with and whil in your home directory: `chmod +x ./monitor-ip.sh`.  
To execute the script from your home directory: `./monitor-ip.sh`, sto the script form running with `CTRL + C`  

If you encounter problels starting up, especially when using Adblock and OpenVPN which are slow to setup, adding some delay is often necessary:
```
	option procd_boot_delay '30'
	option procd_reload_delay '20'
	option procd_boot_trigger_delay '9000'    # for build 1.1.8-r30 and after
```
You might need different values, especially if you run Adblock or other resource intensive services you might need to increase the `procd_boot_trigger_delay` to 9000 or (a lot) more, max is 99000.

Alternatively add to `/etc/rc.local` :
```
{ sleep 60 && service pbr restart; logger -t "pbr" "pbr restarted from rc.local"; } &
```
