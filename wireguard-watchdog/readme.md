 name: owrt-wg-watchdog.sh  
version: 0.2, 24-mar-2024, by egc  
purpose: WireGuard watchdog with fail-over, by pinging every x seconds through the WireGuard interface, the WireGuard tunnel is monitored,  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; in case of failure of the WireGuard tunnel the next tunnel is automatically started  
script type: shell script  
installation:  
1. Copy owrt-wg-watchdog.sh from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog/owrt-wg-watchdog.sh to /usr/share  
   either with:  
   `curl -o /usr/share/owrt-wg-watchdog.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog/owrt-wg-watchdog.sh`  
   or by clicking the download icon in the upper right corner of the script  
2. Make executable: `chmod +x /usr/share/owrt-wg-watchdog.sh`  
3. Edit the script with vi or winscp to add the names of the Wireguard tunnels you want to use for fail over, the names are the names of the interfaces, format is:   
   `WG1=tunnel-name`  
   `WG2=second-tunnel-name`  
   etc., you can set up to 9 tunnels to use.
4. To start on startup of the router, add to System > Startup > Local Startup (/etc/rc.local):  
   `/usr/share/owrt-wg-watchdog.sh &`  
   Note the ampersand (&) at the end indicating that the script is executed asynchronously  
5. The script can take two parameters, the first the ping time in seconds default is 30, the second the ip address used for pinging,   
   default is 8.8.8.8  
   Use a ping time between 10 and 60 seconds, do not set ping time lower than 10 or you run the risk of being banned from the server you are pinging to  
   As IP address you want to use for pinging (default 8.8.8.8) you can set an address which resolves to multiple IP addresses,
   under DHCP and DNS > Hostnames (/etc/config/dhcp, config domain) add:  
   `ping-host 8.8.8.8`  
   `ping-host 9.9.9.9`  
   Check if the name resolves with `nslookup ping-host`  
   Then use ping-host as ping address and all addresses of ping-host will be used in a round robin method, this also adds redundancy if one server is down e.g.:  
   `/usr/share/owrt-wg-watchdog.sh 10 ping-host &`  
   This will ping every 10 seconds, after a delay of 120 seconds on startup, to 8.8.8.8 and 9.9.9.9  
7. reboot  
8. View log with: `logread -e watchdog`, debug by removing the # on the second line of the script, view with: `logread | grep debug`  
9. You can test the script by blocking the endpoint address of a tunnel with:  
   `nft insert rule inet fw4 output ip daddr <ip-endpoint-address> counter reject`  
    do not forget to reset the firewall (service firewall restart) or remove the rule
 
