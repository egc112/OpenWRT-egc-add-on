# DNS leak  
### under construction version 0.1  
First, if your problem is that you are seeing your ISP DNS server in a DNS leak test (ipleak.net, dnsleaktest.com), then make sure you disable `Use DNS servers advertised by peer` in the Advanced settings section of the interface (` option peerdns '0'`) and set `Use custom DNS servers` if necessary/desired, or better use Secure DNS (DoT, DoH) with [SmartDNS](https://forum.openwrt.org/t/smartdns-config-with-dns-over-https/130488/20?u=egc) or [DNS over HTTPS](https://openwrt.org/docs/guide-user/services/dns/doh_dnsmasq_https-dns-proxy).    
A DNS leak is often defined by a DNS query not going through a VPN tunnel.    
But a stricter definition is a DNS query not going through the VPN tunnel and not using a specific DNS server (often a VPN provider pushes a DNS server (OpenVPN) or hands out a special DNS server to use for WireGuard, (those DNS servers are often only available when using the tunnel, so cannot be used for normal DNS via the WAN) .    
If you are only interested in sending DNS queries via the tunnel then you will have no problem if the VPN is the default route as everything will go through the VPN including DNS requests from the router.    
If you want to use the DNS server pushed by your provider in case of OpenVPN or the DNS servers you entered in the WG interface there are two soutions:    
If the DNS servers from your provider are known beforehand and the DNS servers are publicly available (you can test from the routers command line or from e.g. windos cmd prompt with: `nslookup google.com <ip-addressof DNS-server>`    
If that works then add the DNS servers from your provider to DNSMasq (GUI: DHCP and DNS add servers under DNS Forwardings and on `Resolv and Host Files` enable `Ignore resolv file` (option `no-resolv`).    
```    
config dnsmasq    
list server '162.252.172.57'    
option noresolv '1'  
```  
This will Make dnsmasq forward all requests to your designated server(s) and disallow the use of any other available upstream DNS servers.  
If the DNS servers are not known beforehand (often in case of OpenVPN) or are not publicly available there is a solution to this particular problem but you need to add a script to the router, if you are interested, please read on.  
## How DNSMasq works in OpenWRT  
This applies when using DNSMasq to do the DNS resolving by means of a resolv.conf file which contains the DNS servers set on the active interfaces.  
There is a sorting of the DNS servers, the more weight you add the more the DNS servers will go down to the bottom of the file.  
My WAN has two DNS servers with weight 20  
```  
config interface 'wan'  
    option device 'wan'  
    option proto 'dhcp'  
    option peerdns '0'  
    list dns '9.9.9.9'  
    list dns '1.0.0.1'  
    option dns_metric '20'  
```  
My resolv.conf file (/tmp/resolv.conf.d/resolv.conf.auto) will show those and those are the ones which DNSMasq is using:  
root@DL-WRX36:~# cat /tmp/resolv.conf.d/resolv.conf.auto  
```  
# Interface wan6  
# Interface wan  
nameserver 9.9.9.9  
nameserver 1.0.0.1  
```  
When I activate my WG interface with DNS server and also weight 20, then that will be placed at the bottom of the file. By specifying a lesser weight than the other DNS servers it will be placed at the top of the file:  
Weight 20 of WG (same as WAN)  
```  
# Interface wan6  
# Interface wan  
nameserver 9.9.9.9  
nameserver 1.0.0.1  
# Interface wgoraclecloud  
nameserver 149.112.112.112  
Weight 10 of WG the WG DNS server is now on top  
# Interface wgoraclecloud  
nameserver 149.112.112.112  
# Interface wan  
nameserver 9.9.9.9  
nameserver 1.0.0.1  
```  
But it does not matter at what place a DNS server is as DNSMasq will query all servers and chooses the fastest one.  
Wait, but DNSMasq has a `strict-order` setting from the MAN page:  
`-o, --strict-order`  
By default, dnsmasq will send queries to any of the upstream servers it knows about and tries to favour servers that are known to be up. Setting this flag forces dnsmasq to try each query with each server strictly in the order they appear in /etc/resolv.conf  
Does this help?  
Only a bit, strict-order is not very reliable and when testing you will see queries using other DNS servers as well.  
Strict-order easily gives up and tries the next DNS servers, there was even a DNSMasq version (2.86?) where it was not working at all.  
So using DNS weight and strict order is not a reliable way to prevent DNS leaks.  
There are scripts available on the forum which on ifup of the interface replace the DNS servers in the resolv config file with the ones of the interface so that you exclusively use the correct DNS servers.  
An example can be found [here](https://github.com/egc112/OpenWRT-egc-add-on/tree/main/stop-dns-leak/use-wireguard-dns). This script not only set the DNS servers of the WireGuard interface to use exclusively by DNSMasq but also always routes those via the VPN so that you should never have a DNS leak.  
The above example was about WireGuard which has its own interface defined, but what about OpenVPN?  
The OpenVPN clients interface is setup by OpenVPN so you cannot define a DNS server as far as I know. But an OpenVPN server e.g. from your provider can (and often does) push a DNS server to use to your client.  
Unfortunately OpenWRT does not seem do anything by default with these pushed DNS servers.  
If you want to use those you have to add a script.  
There are several available [I use this one](https://github.com/egc112/OpenWRT-egc-add-on/tree/main/stop-dns-leak/use-openvpn-dns) which sets pushed or used DNS servers from the OpenVPN client exclusively to use by DNSMasq and also always routes the DNS server via the tunnel so that you will not have a DNS leak.  
    
## Policy Based Routing  
When using Policy Based routing it highly depends on what the default routing table has as default route as DNSMasq uses this table to route DNS.  
To make sure the DNS queries are going via the tunnel you can use PBR to route the ip address fo the DNS servers you are suing via the VPN tunnel, or use the scripts described above as those will also route the used DNS servers via the tunnel.  
    
## Split DNS  
When using PBR you often want only your LAN clients which use the VPN tunel to have DNS queries via the tunnel and client using the WAN just query DNS via the WAN.  
Split DNS can be accomplished in several ways all with its own pros and cons.  

**Important notice, nowadays a lot of clients (e.g. phone and laptop) use private DNS which nullifies any attempt for DNS redirect so you have to make sure private DNS is disabled!**  
    
### Option 6  
DNSMasq by default sends the routers address as DNS server to your local LAN clients.  
You can alter this with option 6 and send specific DNS server to use by your clients.  
As your client now does the DNS query instead of DNSMasq the DNS query just follows the routing of the client, so if the client is routed via the VPN the DNS query will go out of the VPN.  
Tagging options are set in `/etc/config/dhcp`  
First you make a tag (in this case tag1) with the option and the DNS servers of choice.  
Then you add clients (e.g. static leases (note: with static leases you have to disable random MAC addresses)) and assign a tag to these clients, Below an example of three clients.    
```  
config tag 'tag1'  
    list dhcp_option '6,8.8.8.8,8.8.4.4'  

config host  
    option name 'client1'
    option mac '00:21:63:75:aa:17'
    option ip '10.11.12.14'
    list tag 'tag1'  

config host  
    option name 'client2'  
    option mac '01:22:64:76:bb:18'  
    option ip '10.11.12.15'  
    list tag 'tag1'  
```  
    
It is also possible to assign option 6 to a whole interface, e.g. add under the general options:    
` list dhcp_option 'br-guest,6,8.8.8.8,8.8.4.4'`    
Or under the interface option so that it only is set for that interface:    
` list dhcp_option '6,8.8.8.8,8.8.4.4'`  
  
In Luci:  
Network > Interfaces > Choose interface e.g. LAN > Advanced settings > DHCP options  
  
Reference: https://openwrt.org/docs/guide-user/base-system/dhcp_configuration#dhcp_options  
    
### iptables/nftables  
Iptables with redirection is also a viable option.  
You intercept port 53 from the LAN clients of choice and redirect that to a DNS server of choice.  
For iptables use :  
```
iptables:
iptables -t nat -I PREROUTING -p udp -s <ip-address-range> --dport 53 -j DNAT --to <ip-address-DNS-server>  
iptables -t nat -I PREROUTING -p tcp -s <ip-address-range> --dport 53 -j DNAT --to <ip-address-DNS-server>  
nftables:
ip saddr 192.168.9.224 tcp dport 53 counter dnat ip to 8.8.4.4:53 comment "!fw4: Intercept-DNS"  
ip saddr 192.168.9.224 udp dport 53 counter dnat ip to 8.8.4.4:53 comment "!fw4: Intercept-DNS"  
```  
You can also use `Port Forwarding` to make the iptables rules:  
   
```  
/etc/config/firewall:  
config redirect
	option target 'DNAT'
	option name 'DNSto8888ipv4'
	option src 'lan'
	option src_dport '53'
	option dest_ip '8.8.8.8'
	list src_mac 'D0:AB:D5:92:CC:CC'
	option reflection '0'

config redirect
	option target 'DNAT'
	option name 'DNSto8888ipv6'
	option src 'lan'
	list src_mac 'D0:AB:D5:92:CC:CC'
	option src_dport '53'
	option reflection '0'
	option dest_ip '2001:4860:4860::8888'
	option family 'ipv6'
```

or for a whole interface e.g. `guest`
```
config redirect
        option name 'DNS-Guest'
        option target 'DNAT'
        option src 'guest'
        option src_dport '53'
        option dest_ip '8.8.4.4'
```

As the query will follow the routing of the client there is no specific need to set a route for the DNS server involved.  

### Running Multiple DNS instances  
For Split DNS you can use a second DNSMasq instance listing on another port and then redirect port 53 from the local LAN clients using your VPN to the port the second instance of DNSMasq is listening on.  
Set as upstream resolver on this second intance the VPN DNS server.  
See: https://openwrt.org/docs/guide-user/base-system/dhcp_configuration#multiple_dhcpdns_serverforwarder_instances 

### PBR DNS Policies
[PBR version 1.1.8](https://docs.openwrt.melmac.net/pbr/ ) uses this DNS redirect mechanism, described above, and incorporated that into the GUI.  
![Alt text](img/dns-policy-3.jpg?raw=true "Optional Title")  
You can enter the local LAN clients MAC address, IP addresses or even a whole interface (=device as shown by ifconfig e.g. @br-lan) (see [section 8.2.3. DNS Policy Options](https://docs.openwrt.melmac.net/pbr/#DNSPolicyOptions) ) and the VPN tunnel or remote DNS, the DNS address set on the tunnels interface will be used to redirect the DNS query.  
For WireGuard you can enter the DNS address in the Interfaces >  Advanced settings > Use Custom DNS servers or add in /etc/config/network under the interface `list dns '<ip-address-of-dns>'`  
For OpenVPN you have to make an interface and add the DNS address:  
/etc/config/network  
```
config interface 'tun1'
	option proto 'none'
	option device 'tun1'
	list dns '10.0.0.2'
	list dns '2001:4860:4860::8888'

```
**Note 1:**  
DNS policies redirect DNS53 so make sure your client is not using Private DNS. Nowadays a lot of clients and browsers are using Private DNS, so check your OS and your browser that Private DNS is disabled!  
Also check if you have not enabled VPN on the client itself.  
  
**Note 2:**   
If you also have IPv6 enabled you have to make two rules, one for IPv4 and one for IPv6, the IPv4 rule is IPv4 only so you have to use an IPv4 DNS server. For the IPv6 rule you have to use an IPv6 DNS server. If you specify an interface (=device) then the interface must have both an IPv4 and IPv6 DNS server set!
If both source and DNS target have IPv4 and IPv6 addresses, you can suffice with one rule, as shown in the picture, where the MAC address is IPv4 and IPv6 and the DNS target (interface) also has an IPv4 and IPv6 DNS server set.
For the clients address you have to specify the clients IPv4 address for the IPv4 rule and an IPv6 address for the IPv6 rule, as a client can have multiple aIPv6 addresses it is sometimes not clear which is the preferred one so for a single client you can use the MAC address for both IPv4 and IPv6.  
 
**Note 3:**  
When using DNS policies the DNS route is following the clients route, so you have to take care that the DNS servers you are using are indeed available via this route.  
So you cannot use DNS server which are not publicly available if you are routing via the WAN.  

**Regular [DNS hijack rules](https://openwrt.org/docs/guide-user/firewall/fw3_configurations/intercept_dns) or other DNS hijacking rules such as the force DNS redirect of HTTPS-DNS proxy are not compatible with PBR DNS Policies!**  
nft rules are executed top to bottom and the PBR DNS Policies are appended to the nft rules, so usually are below other DNS hijacking rules and thus will not be executed (depending on the startup of the processesse but PBR ususally starts later than most processes).  
Starting with version 1.1.8-r10 the DNS policy is moved to the `chain-pre` so is executed earlier, although this is no guarantee. So the hack below is no longer necessary starting with 1.1.8-r10!  
Experimental hack to work with existing DNS hijacking:  
Move 30-pbr.nft from post chain to pre chain, to take precedence over DNS hijacking, execute the following two lines lines from the command line:  
```
mkdir -p /usr/share/nftables.d/chain-pre/dstnat/
mv /usr/share/nftables.d/chain-post/dstnat/30-pbr.nft /usr/share/nftables.d/chain-pre/dstnat/
```
MOVE back to undo changes:  
```
mv /usr/share/nftables.d/chain-pre/dstnat/30-pbr.nft /usr/share/nftables.d/chain-post/dstnat/
```
  
## Different DNS servers and routing per domain 
When using destination routing for a specific domain, you often have to take care that the DNS resolution for that domain is also routed accordingly.  
DNSMasq gives you the ability to use a different DNS server per domain.  
This works by using the server directive e.g. for resolving the bbc and google domain only with 9.9.9.9:  
`server=/bbc.com/google.com/9.9.9.9`  
For openWRT you can use the GUI: Network > DHCP and DNS > Forwards > DNS Forwards and add: `/bbc.com/google/com/9.9.9.9`  
or add to `/etc/config/dhcp`:  
```
list server '/bbc.com/google/com/9.9.9.9'
```
  
Next you can use PBR to route the traffic to 9.9.9.9 via the VPN.   
As DNSMasq sits on the router you have to use an `OUTPUT` PBR rule that targets traffic coming out of the router.  
In the PBR GUI (Services > Policy Routing) create a new rule with remote address `9.9.9.9`, Chain: output, Interface: your VPN,    
or add in /etc/config/pbr:  
```
config policy
	option name 'quadnine'
	option chain 'output'
	option interface 'myvpn'
```
For some discusion and explanation, see: https://forum.openwrt.org/t/wireguard-and-pbr-with-vpn-dns-leaks/205661/8?u=egc  

Some general focus points for Domain based routing:  
- You need to have DNSMasq full installed to use nftsets (recommended) see the [PBR read.me](https://docs.openwrt.melmac.net/pbr/#Domain-BasedPolicies)).  
- DNSMasq must be used as DNS resolver so the use of DNS hijacking needs special attention, see [PBR DNS policies above](https://github.com/egc112/OpenWRT-egc-add-on/tree/main/stop-dns-leak#pbr-dns-policies).  
- The domains must first be resolved by DNSMasq before they are added to the set so flush DNS cache on router **and** client or reboot both router and client.  
- It takes about a minute after Saving and Applying before services have restarted and routing is in place so be patient!
- Domain based PBR rules usually have to come first, so make sure those rules are on top in the GUI!
  
## Stopping DNS hijacking  
https://openwrt.org/docs/guide-user/firewall/fw3_configurations/intercept_dns  
## References  
Some more explanation
https://forum.openwrt.org/t/bypass-optus-sports-vpn/204035/9?u=egc
Multiple DNS servers  
https://forum.openwrt.org/t/22-03-0-and-multiple-dnsmasq-instances/136348  
https://openwrt.org/docs/guide-user/base-system/dhcp_configuration?s%5B%5D=multiple&s%5B%5D=dnsmasq&s%5B%5D=instances#multiple_dhcpdns_serverforwarder_instances  
Original script:  
https://forum.openwrt.org/t/need-help-writing-a-shell-script-openvpn-dns-resolver-switchout/61458/4  

### Upgrade PBR
```
opkg update
opkg install wget-ssl
echo -e -n 'untrusted comment: OpenWrt usign key of Stan Grishin\nRWR//HUXxMwMVnx7fESOKO7x8XoW4/dRidJPjt91hAAU2L59mYvHy0Fa\n' > /etc/opkg/keys/7ffc7517c4cc0c56
sed -i '/stangri_repo/d' /etc/opkg/customfeeds.conf
echo 'src/gz stangri_repo https://repo.openwrt.melmac.net' >> /etc/opkg/customfeeds.conf
opkg update
```
See also: https://docs.openwrt.melmac.net/  

Rename on router: /etc/config/pbr to /etc/config/pbr.old  

LuCi > System > Software > Configure opkg  
  
1.	Update OPKG Lists  
2.	Upgrade PBR and Luci-PBR, do not overwrite  

Or manually:  
Locate the pbr and luci-pbr package at: https://dev.melmac.net/repo  
Download the two packages: pbr-iptables_x.x.x-x_all.ipk and luci-app-pbr_x.x.x-x_all.ipk to your desktop by clicking on the .ipk file and when it has openend, on the download icon in the upper right hand corner.  
In Luci Administration > Software 'Upload Package' and install both packages  



