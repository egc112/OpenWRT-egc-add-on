DNS leak

First, if your problem is that you are seeing your ISP DNS server in a DNS leak
test (ipleak.net, dnsleaktest.com), then make sure you disable \`Use DNS servers
advertised by peer\` in the Advanced settings section of the interface (\`
option peerdns '0'\`) and set \`Use custom DNS servers\` if necessary/desired.

A DNS leak is often defined by a DNS query not going through a VPN tunnel.

But a stricter definition is a DNS query not going through the VPN tunnel and
not using a specific DNS server (often a VPN provider pushes a DNS server
(OpenVPN) or hands out a special DNS server to use for WireGuard, (those DNS
servers are often only available when using the tunnel, so cannot be used for
normal DNS via the WAN) .

If you are only interested in sending DNS queries via the tunnel then you will
have no problem if the VPN is the default route as everything will go through
the VPN including DNS requests form the router.

If you want to use the DNS server pushed by your provider in case of OpenVPN or
the DNS servers you entered in the WG interface then you are out of luck.

There is a solution but you need to add a script to the router.

Please read on

How DNSMasq works in OpenWRT

This applies when using DNSMasq to do the DNS resolving by means of a
resolv.conf file which contains the DNS servers set on the active interfaces.

There is a sorting of the DNS servers, the more weight you add the more the DNS
servers will go down to the bottom of the file.

My WAN has two DNS servers with weight 20

config interface 'wan'

option device 'wan'

option proto 'dhcp'

option peerdns '0'

list dns '9.9.9.9'

list dns '1.0.0.1'

option dns_metric '20'

My resolv.conf file (/tmp/resolv.conf.d/resolv.conf.auto) will show those and
those are the ones which DNSMasq is using:

root\@DL-WRX36:\~\# cat /tmp/resolv.conf.d/resolv.conf.auto

\# Interface wan6

\# Interface wan

nameserver 9.9.9.9

nameserver 1.0.0.1

When I activate my WG interface with DNS server and also weight 20, then tat
will be placed at the bottom of the file. By specifying a lesser weight than the
other DNS servers it will be placed at the top of the file:

Weight 20 of WG (same as WAN)

\# Interface wan6

\# Interface wan

nameserver 9.9.9.9

nameserver 1.0.0.1

\# Interface wgoraclecloud

nameserver 149.112.112.112

Weight 10 of WG the WG DNS server is now on top

\# Interface wgoraclecloud

nameserver 149.112.112.112

\# Interface wan

nameserver 9.9.9.9

nameserver 1.0.0.1

But it does not matter at what place a DNS server is as DNSMasq will query all
servers and chooses the fastest one.

Wait, but DNSMasq has a \`strict-order\` setting from the MAN page:

**-o, --strict-order**

>   By default, dnsmasq will send queries to any of the upstream servers it
>   knows about and tries to favour servers that are known to be up. Setting
>   this flag forces dnsmasq to try each query with each server strictly in the
>   order they appear in /etc/resolv.conf

Does this help?

Only a bit, strict-order is not very reliable and when testing you will see
queries using other DNS servers as well.

Strict-order easily gives up and tries the next DNS servers, there was even a
DNSMasq version (2.86?) where it was not working at all.

So using DNS weight and strict order is not a reliable way to prevent DNS leaks.

There are scripts available on the forum which on ifup of the interface replace
the DNS servers in the resolv config file with the ones of the interface so that
you exclusively use the correct DNS servers.

An example can be found
[here](https://github.com/egc112/OpenWRT-egc-add-on/blob/main/stop-dns-leak/wg-update-resolv-3).
This script not only set the DNS servers of the WireGuard interface to use
exclusively by DNSMasq but also always routes those via the VPN so that you
should never have a DNS leak.

The above example was about WireGuard which has its own interface defined, but
what about OpenVPN?

The OpenVPN clients interface is setup by OpenVPN so you cannot define a DNS
server as far as I know. But an OpenVPN server e.g. from your provider can (and
often does) push a DNS server to use to your client.

Unfortunately OpenWRT does not seem do anything by default with these pushed DNS
servers.

If you want to use those you have to add a script.

There are several available I use [this
one](https://github.com/egc112/OpenWRT-egc-add-on/blob/main/stop-dns-leak/ovpn-up-update-resolv-4)
which sets pushed or used DNS servers from the OpenVPN client exclusively to use
by DNSMasq and also always routes the DNS server via the tunnel so that you will
not have a DNS leak.

Policy Based Routing
====================

When using Policy Based routing it highly depends on what the default routing
table has as default route as DNSMasq uses this table to route DNS.

To make sure the DNS queries are going via the tunnel you can use PBR to route
the ip address fo the DNS servers you are suing via the VPN tunnel, or use the
scripts described above as those will also route the used DNS servers via the
tunnel.

Split DNS
=========

When using PBR you often want only your LAN clients which use the VPN tunel to
have DNS queries via the tunnel and client using the WAN just query DNS via the
WAN.

Split DNS can be accomplished in several ways all with its own pros and cons.

### Option 6

DNSMasq by default sends the routers address as DNS server to your local LAN
clients.

You can alter this with option 6 and send specific DNS server to use by your
clients.

As your client now does the DNS query instead of DNSMasq the DNS query just
follows the routing of the client, so if the client is routed via the VPN the
DNS query will go out of the VPN.

Tagging options are set in \`/etc/config/dhcp\`

First you make a tag (in this case tag1) with the option and the DNS servers of
choice.

Then you add clients (e.g. static leases) and assign a tag to these clients,
Below an example of three clients.

It is possible to assign option 6 to a whole interface.

config tag 'tag1'

option dhcp_option '6,8.8.8.8,8.8.4.4'

config host

option name 'client1'

option mac '00:21:63:75:aa:17'

option ip '10.11.12.14'

option tag 'tag1'

config host

option name 'client2'

option mac '01:22:64:76:bb:18'

option ip '10.11.12.15'

option tag 'tag1'

iptables/nftables
-----------------

Iptables with
[redirection](https://openwrt.org/docs/guide-user/firewall/fw3_configurations/intercept_dns)
is also a viable option.

You intercept port 53 from the LAN clients of choice and redirect that to a DNS
server of choice.

For iptables use :

iptables -t nat -I PREROUTING -p udp -s \<ip-address-range\> --dport 53 -j DNAT
--to \<ip-address-DNS-server\>

iptables -t nat -I PREROUTING -p tcp -s \<ip-address-range\> --dport 53 -j DNAT
--to \<ip-address-DNS-server\>

meta nfproto ipv4 tcp dport 53 counter dnat ip to 8.8.4.4:53 comment "!fw4:
Intercept-DNS"

meta nfproto ipv4 udp dport 53 counter dnat ip to 8.8.4.4:53 comment "!fw4:
Intercept-DNS"

ip saddr 192.168.9.224 tcp dport 53 counter dnat ip to 8.8.4.4:53 comment "!fw4:
Intercept-DNS"

ip saddr 192.168.9.224 udp dport 53 counter dnat ip to 8.8.4.4:53 comment "!fw4:
Intercept-DNS"

Port Forwarding

![](media/b1c320dc167d9b7e5e5a1e794b02a47e.png)

/etc/config/firewall:

config redirect 'dns_int'

option name 'Intercept-DNS'

option src 'lan'

option src_dport '53'

option proto 'tcp udp'

option target 'DNAT'

option dest_port '53'

option dest_ip '8.8.4.4'

option src_ip '192.168.9.224

As the query will follow the routing of the client there is no specific need to
set a route for the DNS server involved.

References
----------

Multiple DNS servers

<https://forum.openwrt.org/t/22-03-0-and-multiple-dnsmasq-instances/136348>

<https://openwrt.org/docs/guide-user/base-system/dhcp_configuration?s%5B%5D=multiple&s%5B%5D=dnsmasq&s%5B%5D=instances#multiple_dhcpdns_serverforwarder_instances>

Original script:

<https://forum.openwrt.org/t/need-help-writing-a-shell-script-openvpn-dns-resolver-switchout/61458/4>
