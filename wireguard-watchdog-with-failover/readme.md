 name: [wireguard-watchdog.sh](https://forum.openwrt.org/t/wireguard-watchdog-with-fail-over/192436)  
version: 1.01, 31-aug-2025, by egc  
purpose: WireGuard watchdog with fail-over, by pinging every x seconds through the WireGuard interface, the WireGuard tunnel is monitored,  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; in case of failure of the WireGuard tunnel the next tunnel is automatically started.  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; When the last tunnel has failed, the script will start again with the first tunnel.  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; So in case you have only one tunnel this is just a watchdog which restarts the one tunnel you have.  
script type: shell script  
installation:  
1. Copy wireguard-watchdog.sh from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog-with-failover/wireguard-watchdog.sh to /usr/share  
   either with, from commandline (SSH):  
   `curl -o /usr/share/wireguard-watchdog.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog-with-failover/wireguard-watchdog.sh`  
   or by clicking the download icon in the upper right corner of the script  
2. Make executable: `chmod +x /usr/share/wireguard-watchdog.sh`  
3. Edit the script with vi or winscp to add the names of the Wireguard tunnels you want to use for fail over, the names are the names of the interfaces, format is:   
   `WG1=tunnel-name`  
   `WG2=second-tunnel-name`  
   etc., you can set up to 9 tunnels to use.  
   If desired you can change the number of seconds between log messages (alive), the Restart behaviour (`RESTARTNETWORK=`): either restart the whole Network or only the WireGuard interface and the Restart behaviour of [Policy Based Routing](https://docs.openwrt.melmac.net/pbr/) (`RESTARTPBR=`).  
   If you are not sure do not change it but ask in the forum.  
   If you have an URL as endpoint which needs to be resolved first or other difficulties connecting then use as allowed IPs `128.0.0.0/1` and `0.0.0.0/1` instead of `0.0.0.0/0`
5. To start on startup of the router, add to System > Startup > Local Startup (/etc/rc.local):  
   `/usr/share/wireguard-watchdog.sh &`  
   Note the ampersand (&) at the end indicating that the script is executed asynchronously  
   Test it first from the commandline before adding it to startup and/or make sure you have a recent backup just in case  
6. The script can take two parameters, the first the ping time in seconds default is 30, the second the ip address used for pinging,   
   default is 8.8.8.8  
   Use a ping time between 10 and 60 seconds, do not set ping time lower than 10 or you run the risk of being banned from the server you are pinging to  
   Instead of an IP address you use for pinging (default 8.8.8.8) you can also set a host-name which resolves to multiple IP addresses:  
   under DHCP and DNS > Hostnames (/etc/config/dhcp, config domain) add:  
   `ping-host.mylan 8.8.8.8`  
   `ping-host.mylan 9.9.9.9`  
   Check if the name resolves with: `nslookup ping-host.mylan`  
   Then use ping-host.mylan as ping address and all addresses of ping-host.mylan will be used in a round robin method, this also adds redundancy if one server is down e.g. start with:  
   `/usr/share/wireguard-watchdog.sh 10 ping-host.mylan &`  
   This will ping every `10` seconds (after a delay of 120 seconds on startup) to `ping-host.mylan` (= 8.8.8.8 and 9.9.9.9)  
7. reboot  
8. View log with: `logread -e watchdog`, debug by removing the # on the second line of the script, view with: `logread | grep debug`  
9. You can test the script by blocking the endpoint address of a tunnel with:  
   `nft insert rule inet fw4 output ip daddr <ip-endpoint-address> counter reject`  
    do not forget to reset the firewall (service firewall restart) or remove the rule
10. To stop a running script, do from the command line: `killall wireguard-watchdog.sh` or `kill -9 $(pidof wireguard-watchdog.sh)`

Shortcut install commands, copy by clicking the copy icon in the right corner, paste to command line and execute, scriot is openend, set wg tunnels in script:
```
curl -o /usr/share/wireguard-watchdog.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-watchdog-with-failover/wireguard-watchdog.sh &&  \
chmod +x /usr/share/wireguard-watchdog.sh && vi /usr/share/wireguard-watchdog.sh
```
  
**Note:** if the only problem is that the DDNS address of the server is frequently changing you can run the built-in watchdog which periodically re-resolves the DNS address of the server by running as a cron job see:  
https://openwrt.org/docs/guide-user/services/vpn/wireguard/extras#dynamic_address  

### Usage with PBR  
You can use fail-over with PBR by doing the following:  
Create the WG Interfaces you want to use and use `option4table '101'` and if necessary `option6table '101'`. When the interface is brought up it will create a routing table 101 with default route via the WG tunnel.   
Next step is to make rules to use table 101 e.g.:  
```
config rule
	# for ip source:
	#option src '192.168.30.0/24'
	# destination e.g. from all to dest
	#option dest '25.52.71.40/32'
	# for interface
	#option in 'lan'
	# for proto
	#option ipproto 'icmp`
	# for source port
	#option sport '116'
	option lookup '101'
```
These are examples of rules you can use, all will use table 101 and it does not matter which WG interface is active.  
