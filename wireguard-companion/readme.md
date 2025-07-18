name: [wireguard-companion.sh](https://forum.openwrt.org/t/wireguard-companion-script-to-administer-your-wireguard-tunnels/200866)  
version: 1.07, 17-june-2024, by egc  
purpose: Toggle WireGuard tunnels on/off, show status and log  
script type: standalone  
installation:  
Shortcut:  see below

 1. Copy wireguard-companion.sh from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-companion/wireguard-companion.sh to /usr/share  
    either with, from commandline (SSH): `curl -o /usr/share/wireguard-companion.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-companion/wireguard-companion.sh` 
    or by clicking the download icon in the upper right corner of the script  
 2. Make executable: `chmod +x /usr/share/wireguard-companion.sh`  
 3. Run from command line with `/usr/share/wireguard-companion.sh`, most SSH clients will let you run a command on connection, if you use a [SSH-key to connect](https://openwrt.org/docs/guide-user/security/dropbear.public-key.auth) you can have an app like experience e.g. from your phone running a terminal app like connectbot.  
 4. Debug by removing the # on the second line of this script.  
 5. To automatcally skip WireGuard interfaces which are setup as server, remove the # on the third line of this script, this works by identifying a listen port.
 6. If you toggle a WG tunnel off the defaulte route via the WAN is not automatically reinstated, to mitigate this use as Allowed IPs `0.0.0.0/1, 128.0.0.0/1` instead of `0.0.0.0/0`
usage:  
	Toggle tunnels to enable/disable the WireGuard tunnel, show status, log and restart WireGuard or reboot from the command line  
	A full Network restart (option 8) is only necessary if you disabled all tunnels to get a the default route back

**Shortcut install**, copy by clicking the copy icon in the right corner and execute on the command line:  
```
curl -o /usr/share/wireguard-companion.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-companion/wireguard-companion.sh && chmod +x /usr/share/wireguard-companion.sh
```

![wireguard-companion](https://github.com/egc112/OpenWRT-egc-add-on/blob/main/wireguard-companion/wireguard-companion.jpg "wireguard-companion")

For a very **simple solution** when you have just one tunnel and want to toggle it on/off see: https://forum.openwrt.org/t/best-way-to-toggle-wireguard-on-and-off/200226/4?u=egc
