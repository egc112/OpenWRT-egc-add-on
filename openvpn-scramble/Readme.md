OpenVPN traffic can be discovered with [Deep Packet Inspection (DPI)](https://en.wikipedia.org/wiki/Deep_packet_inspection) by your provider or censoring authority.  

As a first step to make OpenVPN traffic less suspicious use port 443.  

The next step to escape censoring is to obfuscate/scramble your OpenVPN traffic.  
Scramble options are supported by a number of OpenVPN providers e.g. TorGuard, [StrongVPN](https://support.strongvpn.com/hc/en-us/articles/360034090394-About-the-Scramble-feature-in-StrongVPN), IPvanish etc. and also by DDWRT, Android and Windows (see below).  

Scramble options are not present by default in OpenWRT (they are in DDWRT) so you have to add those yourself and make a build with it.  
Get the necessary patches for compiling [here](https://github.com/egc112/OpenWRT-egc-add-on/tree/main/openvpn-scramble/feeds), for stable 23.05 which uses K5.15 and OpenVPN 2.5.8 use the patches from 515. For 24.10 and Main build with Kernel 6.6 and OpenVPN 2.6.12 use patches from 66 
The patches are derived from tunnelblicks patches:   
https://tunnelblick.net/cOpenvpn_xorpatch.html  
https://github.com/Tunnelblick/Tunnelblick/tree/master/third_party/sources/openvpn/openvpn-2.6.4/patches  
https://github.com/clayface/openvpn_xorpatch  
https://scramblevpn.wordpress.com/2017/04/16/compile-patched-openvpn-ipk-package-for-openwrtlede-router/  
  
To compile:  
Copy all patch files to `feeds/packages/net/openvpn/patches`  
On compiling the patches are executed automatically  

Usage:
In the OpenVPN config add:  
For the tunnelblick patches (and that is what is used here) this option is:  
`scramble xormask "password"`  
For other builds use:  
`scramble "password"`  
scramble is the leftmost option name. This can be followed by a string which will be used to perform a simple xor operation on the packet payload.  

However if the following are used instead, a different action will occur.  
`scramble reverse`  
This simply reverses all the data in the packet. This should be enough to get past the regular expression detection in both China and Iran.  

`scramble xorptrpos`  
This performs a xor operation, utilising the current position in the packet payload.  

`scramble obfuscate "password"`  
This method is more secure. It utilises the 3 types of scrambling mentioned above. "password" is the string which you want to use.  

Note 1: scramble options must be the same on client and server side!  
Note 2: xor patches are not compatible with dco.   
If dco is available in your firmware add in the openvpn config: `disable-dco`  

Both [DDWRT OpenVPN Client (page 14)](https://forum.dd-wrt.com/phpBB2/download.php?id=48550) and Server support scramble, there are also clients available for Android and Windows:  
https://github.com/lawtancool  
 
Android:  
https://github.com/lawtancool/ics-openvpn-xor/releases  

Windows:  
https://github.com/lawtancool/openvpn-windows-xor/releases

MacOS:  
https://tunnelblick.net/  
  
To check if the scramble options are available (compiled in) into your firmware:  
`strings /usr/sbin/openvpn | grep scramble`  
  
 
#### DCO
Upcoming OpenVPN version will have DCO (Data Channel Offload), unfortunately the scramble options are not compatible with DCO.  
so even if DCO is compiled in you have to disable DCO (in openVPN config add: `disable-dco`)  

See also:  
https://shenzhensuzy.wordpress.com/2019/01/26/openvpn-with-xor-patch/  
https://forum.openwrt.org/t/scramble-obfuscate-in-openvpn/151570  
https://svn.dd-wrt.com/ticket/5590  
https://tunnelblick.net/cOpenvpn_xorpatch.html  
https://github.com/Tunnelblick/Tunnelblick/tree/master/third_party/sources/openvpn/openvpn-2.6.4/patches  
https://scramblevpn.wordpress.com/2017/04/16/compile-patched-openvpn-ipk-package-for-openwrtlede-router/
https://forums.openvpn.net/viewtopic.php?t=12605  
https://github.com/clayface/openvpn_xorpatch/blob/master/openvpn_xor.patch   
https://svn.dd-wrt.com/changeset/47850   
  


