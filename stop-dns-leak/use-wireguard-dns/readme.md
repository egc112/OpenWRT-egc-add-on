### Use DNS servers for WireGuard  

 Script to set WG DNS servers exclusive to DNSMasq  
 File name: 98-wg-update-resolv-4  
 Version 15-may-24  

Before you start make a backup of your settings just in case  
  
Install:  
  Copy 98-wg-update-resolv-4 from https://github.com/egc112/OpenWRT-egc-add-on/blob/main/stop-dns-leak/use-wireguard-dns/98-wg-update-resolv-4 to /etc/hotplug.d/iface  
  either from commandline (SSH):  
    `curl -o /etc/hotplug.d/iface/98-wg-update-resolv-4 https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/stop-dns-leak/use-wireguard-dns/98-wg-update-resolv-4`  
   or by clicking the download icon in the upper right corner of the script on github and use scp/WinSCP to transfer the file  
   Make executable: `chmod +x /etc/hotplug.d/iface/98-wg-update-resolv-4`  
   If you have only one WG interface it will be set automagically, otherwise add the name of the WG interface in the script  
    
 Fundamentals:  
  On ifup of the WG interface the resolv.conf file will be replaced with a file containing only the WG DNS server(s)  
  All WireGuard DNS servers will be explicitly routed via the tunnel, useful when using PBR  
  On ifdown the old resolv.conf file is restored and routes deleted  
  This is not compatible with the use of encrypted DNS or the setting of `Use Custom DNS servers`  (server=)  

 View log with: `logread -e hotplug-call`, debug by removing the # on the second line of the script, view with: `logread | grep debug`  

 When something goes wrong, disable the VPN and restore DNS with: `uci del dhcp.@dnsmasq[0].resolvfile && uci commit dhcp` , and reboot  



