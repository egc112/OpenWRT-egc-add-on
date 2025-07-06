name: openvpn-watchdog.sh  
version: 0.31, 06-jul-2025, by egc  
purpose: OpenVPN watchdog with fail-over, by pinging every x seconds through the OpenVPN interface, the OpenVPN tunnel is monitored,  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;in case of failure of the OpenVPN tunnel the next tunnel is automatically started  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;When the last tunnel has failed, the script will start again with the first tunnel.  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;So in case you have only one tunnel this is just a watchdog which restarts the one tunnel you have or reboot the router  
script type: shell script  
    
Before installing the script, setup your OpenVPN tunnels you want to use for this fail over group to each use its own device tunX,  
where X is a unique number, start with 11.  
Set in the OpenVPN config of each tunnel you want to use: "dev tunX" instead of "dev tun".  
Make an interface with the same name as the OpenVPN instance, protocol unmanaged and device (custom): "tunX", corresponding with each OpenVPN instance.  
Add this interface to the WAN firewall zone or to your own created VPN Client firewall zone.  
Important notice: not all VPN providers support pinging through the tunnel e.g. vpnumlimited/keepsolid, so test that first!  
  
  installation:
  1. Copy openvpn-watchdog.sh from `https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/openvpn-watchdog-with-failover/openvpn-watchdog.sh` to `/usr/share`
     either with, from commandline (SSH): `curl -o /usr/share/openvpn-watchdog.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/openvpn-watchdog-with-failover/openvpn-watchdog.sh`
     or by clicking the download icon in the upper right corner of the script
  2. Make executable: `chmod +x /usr/share/openvpn-watchdog.sh`
  3. Edit the script with vi or winscp to add the names of the OpenVPN tunnels you want to **exclude** for fail over, the names are the names of the OpenVPN Instances (Luci > VPN > OpenVPN), format is:
     `no_vpntunnels="<no_vpntunnel_1> <no_vpntunnel_2>"`, see example in script
    Instead of letting the OpenVPN service restart you can reboot the whole router, by setting reboot=1. To make sure the router is not constantly rebooting,
    there is an increasing time between reboots if the VPN is not succesful, to a maximum of 20 minutes.  
  5. To start on startup of the router, add to System > Startup > Local Startup (/etc/rc.local):
     `/usr/share/openvpn-watchdog.sh &`
     Note the ampersand (&) at the end indicating that the script is executed asynchronously
  5  The script takes two parameters, the first the ping time in seconds (default is 30), the second the ip address used for pinging (default is 8.8.8.8).
     Use a ping time between 10 and 60 seconds, do not set ping time lower than 10 or you run the risk of being banned from the server you are pinging to
     Instead of an IP address you use for pinging (default 8.8.8.8) you can also set a host-name which resolves to multiple IP addresses:
     under DHCP and DNS > Hostnames (/etc/config/dhcp, config domain) add:
     `ping-host.mylan 8.8.8.8`
     `ping-host.mylan 9.9.9.9`
     Check if the name resolves with: `nslookup ping-host.mylan`
     Then use ping-host.mylan as ping address and all addresses of ping-host.mylan will be used in a round robin method, this also adds redundancy if one server is down e.g. start with:
     `/usr/share/openvpn-watchdog.sh 10 ping-host.mylan &`
     This will ping every 10 seconds (after a delay of 120 seconds on startup) to ping-host.mylan (= 8.8.8.8 and 9.9.9.9)
  6. reboot
  7. View log with: `logread -e watchdog`, debug by removing the on the second line of this script, view with: `logread | grep debug`
  8. You can test the script by blocking the endpoint address of a tunnel with:
     `nft insert rule inet fw4 output ip daddr <ip-endpoint-address> counter reject`
     do not forget to reset the firewall (service firewall restart) or remove the rule
  9. To stop a running script, do from the command line: `killall openvpn-watchdog.sh`

Shortcut install commands, copy by clicking the copy icon in the right corner, paste to command line and execute, scriot is openend, set wg tunnels in script:
```
curl -o /usr/share/openvpn-watchdog.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/openvpn-watchdog-with-failover/openvpn-watchdog.sh &&  \
chmod +x /usr/share/openvpn-watchdog.sh && vi /usr/share/openvpn-watchdog.sh
```
    
