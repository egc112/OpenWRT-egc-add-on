 name: [wireguard-watchdog.sh](https://forum.openwrt.org/t/wireguard-watchdog-with-fail-over/192436)  
version: 0.93, 14-june-2024, by egc  
purpose: WireGuard watchdog with fail-over, by pinging every x seconds through the WireGuard interface, the WireGuard tunnel is monitored,  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; in case of failure of the WireGuard tunnel the next tunnel is automatically started.  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; When the last tunnel has failed, the script will start again with the first tunnel.  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; So in case you have only one tunnel this is just a watchdog which restarts the one tunnel you have.  
script type: shell script  
installation:  
1. Copy wireguard-watchdog.sh from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog/wireguard-watchdog.sh to /usr/share  
   either with, from commandline (SSH):  
   `curl -o /usr/share/wireguard-watchdog.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog/wireguard-watchdog.sh`  
   or by clicking the download icon in the upper right corner of the script  
2. Make executable: `chmod +x /usr/share/wireguard-watchdog.sh`  
3. Edit the script with vi or winscp to add the names of the Wireguard tunnels you want to use for fail over, the names are the names of the interfaces, format is:   
   `WG1=tunnel-name`  
   `WG2=second-tunnel-name`  
   etc., you can set up to 9 tunnels to use.
4. To start on startup of the router, add to System > Startup > Local Startup (/etc/rc.local):  
   `/usr/share/wireguard-watchdog.sh &`  
   Note the ampersand (&) at the end indicating that the script is executed asynchronously  
   Test it first from the commandline before adding it to startup and/or make sure you have a recent backup just in case  
5. The script can take two parameters, the first the ping time in seconds default is 30, the second the ip address used for pinging,   
   default is 8.8.8.8  
   Use a ping time between 10 and 60 seconds, do not set ping time lower than 10 or you run the risk of being banned from the server you are pinging to  
   Instead of an IP address you use for pinging (default 8.8.8.8) you can also set a host-name which resolves to multiple IP addresses:  
   under DHCP and DNS > Hostnames (/etc/config/dhcp, config domain) add, **replace `yourlan` with your lan domain name** :  
   `ping-host.yourlan 8.8.8.8`  
   `ping-host.yourlan 9.9.9.9`  
   Check if the name resolves with: `nslookup ping-host.yourlan`  
   Then use ping-host.yourlan as ping address and all addresses of ping-host.yourlan will be used in a round robin method, this also adds redundancy if one server is down e.g. start with:  
   `/usr/share/wireguard-watchdog.sh 10 ping-host.yourlan &`  
   This will ping every `10` seconds (after a delay of 120 seconds on startup) to `ping-host.yourlan` (= 8.8.8.8 and 9.9.9.9)  
6. reboot  
7. View log with: `logread -e watchdog`, debug by removing the # on the second line of the script, view with: `logread | grep debug`  
8. You can test the script by blocking the endpoint address of a tunnel with:  
   `nft insert rule inet fw4 output ip daddr <ip-endpoint-address> counter reject`  
    do not forget to reset the firewall (service firewall restart) or remove the rule
9. To stop a running script, do from the command line: `killall wireguard-watchdog.sh`

Shortcut install commands, copy by clicking the copy icon in the right corner, paste to command line and execute, scriot is openend, set wg tunnels in script:
```
curl -o /usr/share/wireguard-watchdog.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog/wireguard-watchdog.sh &&  \
chmod +x /usr/share/wireguard-watchdog.sh && vi /usr/share/wireguard-watchdog.sh
```

Note if the only problem is that the DDNS is frequently changing you can run the built-in watchdog which can periodically re-resolves the DNS address by running as a cron job see:  
https://openwrt.org/docs/guide-user/services/vpn/wireguard/extras#dynamic_address  
