https://svn.dd-wrt.com/ticket/5590  

To checkif the scramble options are avaialbel (compiled in) into your firmware:  
`strings /usr/sbin/openvpn | grep scramble`  

https://shenzhensuzy.wordpress.com/2019/01/26/openvpn-with-xor-patch/  

Get tunnelblicks patches:  
https://tunnelblick.net/cOpenvpn_xorpatch.html  
https://github.com/Tunnelblick/Tunnelblick/tree/master/third_party/sources/openvpn/openvpn-2.6.4/patches  
https://github.com/clayface/openvpn_xorpatch  

https://scramblevpn.wordpress.com/2017/04/16/compile-patched-openvpn-ipk-package-for-openwrtlede-router/  
  
To compile:  
Copy all patch files to `feeds/packages/net/openvpn/patches`  
On compiling the patches are executed automatically  

Usage:  
Scramble options can be used to obfuscate the connection this can be useful to escape censoring.   
It is supported by a number of OpenVPN providers e.g. TorGuard, StrongVPN, IPvanish etc.  

Note: scramble options must be the same on client and server side!  

In the OpenVPN config add:  
`scramble "password"`  
scramble is the leftmost option name. This can be followed by a string which will be used to perform a simple xor operation on the packet payload.  
Note for tunnelblick (and this is what is used here) this option is:  
`scramble xormask "password"`  

However if the following are used instead, a different action will occur.  
`scramble reverse`  
This simply reverses all the data in the packet. This should be enough to get past the regular expression detection in both China and Iran.  

`scramble xorptrpos`  
This performs a xor operation, utilising the current position in the packet payload.  

`scramble obfuscate "password"`  
This method is more secure. It utilises the 3 types of scrambling mentioned above. "password" is the string which you want to use.  

Both DDWRT OpenVPN Client and server supports scramble there are also clients available for Android and Windows:  
https://github.com/lawtancool  
 
Android:  
https://github.com/lawtancool/ics-openvpn-xor/releases  

Windows:  
https://github.com/lawtancool/openvpn-windows-xor/releases

See also:  
https://forum.openwrt.org/t/scramble-obfuscate-in-openvpn/151570  

https://tunnelblick.net/cOpenvpn_xorpatch.html  
https://github.com/Tunnelblick/Tunnelblick/tree/master/third_party/sources/openvpn/openvpn-2.6.4/patches  
https://scramblevpn.wordpress.com/2017/04/16/compile-patched-openvpn-ipk-package-for-openwrtlede-router/
https://forums.openvpn.net/viewtopic.php?t=12605  
https://github.com/clayface/openvpn_xorpatch/blob/master/openvpn_xor.patch   
https://svn.dd-wrt.com/changeset/47850   
  
Note xor patches are not compatible with dco so compile with --disable-dco   
