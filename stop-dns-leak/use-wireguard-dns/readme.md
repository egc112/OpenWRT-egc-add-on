### Use DNS servers for WireGuard  

 Script to set WG DNS servers exclusive to DNSMasq  
 File name: 98-wg-update-resolv-4  
 Version 14-05-24
   
 Install: 
  Copy this cript to /etc/hotplug.d/iface  
  Make executable: `chmod +x /etc/hotplug.d/iface/wg-update-resolv-3`  
  If you have only one WG interface it will be set automagically, otherwise add the name of the WG interface in the script  
    
 Fundamentals:  
  On ifup of the WG interface the resolv.conf file will be replaced with a file containing only the WG DNS server(s)  
  All WireGuard DNS servers will be explicitly routed via the tunnel usefull when using PBR  
  On ifdown the old resolv.conf file is restored and routes deleted  
  This is not compatible with the use of encrypted DNS or the setting of `Use Custom DNS servers`  (server=)  

 View log with: `logread -e hotplug-call`, debug by removing the # on the second line of the script, view with: `logread | grep debug`


