Scramble options can be used to obfuscate the connection this can be useful to escape censoring.   
It is supported by a number of OpenVPN providers e.g. TorGuard, StrongVPN, IPvanish etc. and also by DDWRT, Android and Windows (see below).  

Get the necessary patches for compiling [here](https://github.com/egc112/OpenWRT-egc-add-on/tree/main/openvpn-scramble/feeds), for stable 23.05.2 which uses K5.15 and OpenVPN 2.5.8 use the patches from 515, for Main build with Kernel 6.1 and OpenVPN 2.6.8 uses patches from 61) 
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

Note: scramble options must be the same on client and server side!  

Both DDWRT OpenVPN Client and server supports scramble, there are also clients available for Android and Windows:  
https://github.com/lawtancool  
 
Android:  
https://github.com/lawtancool/ics-openvpn-xor/releases  

Windows:  
https://github.com/lawtancool/openvpn-windows-xor/releases


To check if the scramble options are available (compiled in) into your firmware:  
`strings /usr/sbin/openvpn | grep scramble`  

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
  
Note xor patches are not compatible with dco.   
If dco is available in your firmware add in the openvpn config: `disable-dco`  

