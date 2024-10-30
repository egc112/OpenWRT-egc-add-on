https://openwrt.org/docs/guide-user/network/routing/basics\#policy-based_routing  
https://openwrt.org/docs/techref/netifd  
<https://openwrt.org/docs/guide-user/network/routing/pbr_netifd  
https://github.com/openwrt/netifd  
  
When setting up a routing table with netifd e.g.:  
(for IPV in 4 6 do)  
```  
uci set network.mullvad_se.ip\${IPV}table="2"  
```  
  
/etc/config/network:  
```  
config interface 'mullvad_se'  
option proto 'wireguard'  
option private_key 'YGa '  
list addresses 'fc00:bbbb:bbbb:bb01::5:5906/128'  
list addresses '10.68.89.7/24'  
**option ip4table '2'**  
```  

inetid removes the default route for that specific interface from the main table and  
sets that default route in the pbr table, in addition to the local route which  
is also moved from the main table to the pbr table.  
So the interface has to set a default route in order to get one in the PBR table.  
It is no problem that there are multiple default routes as those are moved to the pbr tables.  
So with netifd you always let the interface set the default route.  
Of course you can always manually set a default route:  
```  
uci -q delete network.mullvad_se_rt\${IPV%4}  
uci set network.mullvad_se_rt\${IPV%4}="route\${IPV%4}"  
uci set network.mullvad_se_rt\${IPV%4}.interface="mullvad_se"  
uci set network.mullvad_se_rt.target="0.0.0.0/0"  
uci set network.mullvad_se_rt6.target="::/0"  
uci commit  
```  
/etc/config/network:  
```  
config route 'mullvad_se_rt'  
option interface 'mullvad_se'  
option target '0.0.0.0/0'  
config route6 'mullvad_se_rt6'  
option interface 'mullvad_se'  
option target '::/0'  
```  
Option `table` does not seem necessary as this route takes effect on the table  
of the interface (where there is a default route via this interface?) so this  
seems redundant but does not hurt and at least it makes it clear on what table  
this route is set:  
```  
uci set network.mullvad_se_rt.table="2"  
```   
Note if you setup a pbr_wan table the default route is gone from the main table!  
  
I could not have netifd play nice with OpenVPN it seems like it only can deal with managed interfaces!  
So this seems like a deal breaker to me but has to be researhed further  


<details>
  <summary>Routes and rules from Stan</summary>
with netifd  
IPv4 table 257 route: default via 97.107.189.1 dev eth6 proto static src  
97.107.189.5  
IPv4 table 257 rule(s):  
9999: from all sport 51820 lookup pbr_wan  
20000: from all to 97.107.189.5/25 lookup pbr_wan  
30000: from all fwmark 0x10000/0xff0000 lookup pbr_wan  
90009: from all iif lo lookup pbr_wan  
IPv4 table 258 route:  
IPv4 table 258 rule(s):  
20000: from all to 172.20.185.163 lookup pbr_ivpnbg  
29998: from all fwmark 0x20000/0xff0000 lookup pbr_ivpnbg  
90094: from all iif lo lookup pbr_ivpnbg  
IPv4 table 259 route:  
IPv4 table 259 rule(s):  
20000: from all to 172.20.160.56 lookup pbr_ivpnca  
29996: from all fwmark 0x30000/0xff0000 lookup pbr_ivpnca  
90097: from all iif lo lookup pbr_ivpnca  
IPv4 table 260 route:  
IPv4 table 260 rule(s):  
20000: from all to 172.27.155.115 lookup pbr_ivpnil  
29994: from all fwmark 0x40000/0xff0000 lookup pbr_ivpnil  
90100: from all iif lo lookup pbr_ivpnil  
IPv4 table 261 route:  
IPv4 table 261 rule(s):  
20000: from all to 172.21.184.209 lookup pbr_ivpnus  
29992: from all fwmark 0x50000/0xff0000 lookup pbr_ivpnus  
90101: from all iif lo lookup pbr_ivpnus  
IPv4 table 262 route:  
IPv4 table 262 rule(s):  
20000: from all to 10.6.168.248 lookup pbr_piaca  
29990: from all fwmark 0x60000/0xff0000 lookup pbr_piaca  
90107: from all iif lo lookup pbr_piaca  
IPv4 table 263 route:  
IPv4 table 263 rule(s):  
20000: from all to 10.31.179.215 lookup pbr_piail  
29988: from all fwmark 0x70000/0xff0000 lookup pbr_piail  
90105: from all iif lo lookup pbr_piail  
IPv4 table 264 route:  
IPv4 table 264 rule(s):  
20000: from all to 10.26.232.252 lookup pbr_piauk  
29986: from all fwmark 0x80000/0xff0000 lookup pbr_piauk  
90104: from all iif lo lookup pbr_piauk  
IPv4 table 265 route:  
IPv4 table 265 rule(s):  
20000: from all to 10.4.251.106 lookup pbr_piaus  
29984: from all fwmark 0x90000/0xff0000 lookup pbr_piaus  
90106: from all iif lo lookup pbr_piaus  
no netifd  
IPv4 table 256 route: default via 97.107.189.1 dev eth6  
IPv4 table 256 rule(s):  
29983: from all sport 51820 lookup pbr_wan  
30000: from all fwmark 0x10000/0xff0000 lookup pbr_wan  
IPv4 table 257 route: default via 172.20.185.163 dev ivpnbg  
IPv4 table 257 rule(s):  
29998: from all fwmark 0x20000/0xff0000 lookup pbr_ivpnbg  
IPv4 table 258 route: default via 172.20.160.56 dev ivpnca  
IPv4 table 258 rule(s):  
29996: from all fwmark 0x30000/0xff0000 lookup pbr_ivpnca  
IPv4 table 259 route: default via 172.27.155.115 dev ivpnil  
IPv4 table 259 rule(s):  
29994: from all fwmark 0x40000/0xff0000 lookup pbr_ivpnil  
IPv4 table 260 route: default via 172.21.184.209 dev ivpnus  
IPv4 table 260 rule(s):  
29992: from all fwmark 0x50000/0xff0000 lookup pbr_ivpnus  
IPv4 table 261 route: default via 10.6.168.248 dev piaca  
IPv4 table 261 rule(s):  
29990: from all fwmark 0x60000/0xff0000 lookup pbr_piaca  
IPv4 table 262 route: default via 10.31.179.215 dev piail  
IPv4 table 262 rule(s):  
29988: from all fwmark 0x70000/0xff0000 lookup pbr_piail  
IPv4 table 263 route: default via 10.26.232.252 dev piauk  
IPv4 table 263 rule(s):  
29986: from all fwmark 0x80000/0xff0000 lookup pbr_piauk  
IPv4 table 264 route: default via 10.4.251.106 dev piaus  
IPv4 table 264 rule(s):  
29984: from all fwmark 0x90000/0xff0000 lookup pbr_piaus  
</details>  
