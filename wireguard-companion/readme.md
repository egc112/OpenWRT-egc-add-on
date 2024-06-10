name: wireguard-companion.sh  
version: 0.94, 12-june-2024, by egc  
purpose: Toggle WireGuard tunnels on/off, show status and log  
script type: standalone  
installation:  
 1. Copy wireguard-companion.sh from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-companion/wireguard-companion.sh to /usr/share  
    either with, from commandline (SSH): `curl -o /usr/share/wireguard-companion.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/wireguard-companion/wireguard-companion.sh` 
    or by clicking the download icon in the upper right corner of the script  
 2. Make executable: `chmod +x /usr/share/wireguard-companion.sh`  
 3. Run from command line with `/usr/share/wireguard-companion.sh`, most SSH clients will let you run a command on connection, if you use a key to connect you can have an app like experience.  
 4. Debug by removing the # on the second line of this script.  
 5. To skip WireGuard interfaces from the list which are setup as server, remove the # on the third line of this script  
usage:  
	Toggle tunnels to enable/disable the WireGuard tunnel, show status, log and restart WireGuard or reboot from the command line  
	A full Network restart (option 7) is only necessary if you disabled all tunnels to get a the default route back  

