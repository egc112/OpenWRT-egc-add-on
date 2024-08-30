This directory contains a test version for PBR.  
Before you start make a backup of your settings and make sure you have a copy of your firmware, you should not need it but better safe then sorry.  
Download the test version: open `pbr-1.1.7-4-egc-2.bash` and click the download icon in the upper right hand corner.  
On your router, rename the original `/etc/init.d/pbr` script to `/etc/init.d/pbr-org` , and/or copy it to your Desktop  
Copy the new script to `/etc/init.d/pbr`  
Make the new script executable: `chmod +x /etc/init.d/pbr`
Reboot the computer  

Note that especailly OpenVPN is slow to setup so adding some delay is often necessary:
```
	option procd_boot_delay '30'
	option procd_reload_delay '20'
```
You might need different values
