### Use Pushed DNS servers for OpenVPN
 Description: Script to grab DNS servers from the tunnel for exclusive use by DNSMasq and route those via the tunnel to prevent DNS leaks  
 Filename: ovpn-update-resolv-9  
 Version: 15-may-2024  
   
 Before you start make a backup of your settings just in case  
   
 Install:  
   Copy `ovpn-update-resolv-9` from https://github.com/egc112/OpenWRT-egc-add-on/blob/main/stop-dns-leak/use-openvpn-dns/ovpn-update-resolv-9 to /etc/openvpn  
   either from commandline (SSH):  
     `curl -o /etc/openvpn/ovpn-update-resolv-9 https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/stop-dns-leak/use-openvpn-dns/ovpn-update-resolv-9`  
   or by clicking the download icon in the upper right corner of the script on github and use scp/WinSCP to transfer the file  
  Make executable: `chmod +x /etc/openvpn/ovpn-update-resolv-9`  
  Add in the OpenVPN config file these two lines:  
   `up /etc/openvpn/ovpn-update-resolv-9`  
   `down /etc/openvpn/ovpn-update-resolv-9`  
    
 Fundamentals:  
  Gets the pushed DNS servers and DNS servers manually set in conf file with: `dhcp-option DNS ip-address-of-DNS-server`  
  DNS servers are set in a new resolv file which is used exclusively by DNSMasq to prevent DNS leaks.  
  Sets route for the DNS servers via the tunnel, necessary when using PBR  
  To stop getting the pushed DNS servers by the OpenVPN server add to conf file: `pull-filter ignore "dhcp-option DNS"`  
     but if you add this setting then you must add your own DNS servers otherwise you will not have DNS!  
  To set your own DNS servers to use when the tunnel is up, add in the openvpn conf file: `dhcp-option DNS ip-address-DNS-server`  
  To set your own search domain to use when the tunnel is up, add in the openvpn conf file: `dhcp-option DOMAIN my-search-domain`  
  When something goes wrong, disable the VPN and restore DNS with: `uci del dhcp.@dnsmasq[0].resolvfile && uci commit dhcp` , and reboot  

  Note: This script is **not** compatible with the use of `Ignore resolv file` (option noresolv), DNS Forwards ( list server=) or with the use of encrypted DNS e.g. unbound, dnscrypt and https-dns-proxy, but encrypted DNS is
  not needed as the DNS is already send encrypted via the VPN to a trusted DNS server.  

References  
 https://openwrt.org/docs/guide-user/services/vpn/openvpn/extrasnetwork_interface 
