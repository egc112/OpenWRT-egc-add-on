name: owrt-wg-watchdog.sh
version: 0.1, 23-mar-2024, by egc
purpose: WireGuard watchdog , in case of failure of a wireguard tunnel the next tunnel is automatically started
script type: shell script
installation:
1. copy owrt-wg-watchdog.sh from https://github.com/egc112/ddwrt/tree/main/adblock/dnsmasq to /usr/share
   either with: curl -o /jffs/ddwrt-adblock-d.sh https://raw.githubusercontent.com/egc112/ddwrt/main/adblock/dnsmasq/ddwrt-adblock-d.sh
   or by clicking the download icon in the upper right corner of the script
4. make executable: chmod +x /jffs/ddwrt-adblock-d.sh
5. add to Administration  > Commands: 
     /jffs/ddwrt-adblock-d.sh & 
     if placed on USB then "Save USB" ; if jffs2 is used then : "Save Startup"
     Depending on the speed of your router or use of VPN, you might need to precede the command with: sleep 30
6. add the following to the "additional dnsmasq options" field on the
    services page:
    conf-dir=/tmp,*.blck
    /tmp/ is the directory where the blocklists: *.blck are placed and can be checked
7. modify options e.g. URL list, MYWHITELIST and MYBLACKLIST:
    vi /jffs/ddwrt-adblock-d.sh 
    or edit with WinSCP
8. (optional) enable cron (administration->management) and add the
    following job (runs daily at 4 a.m.):
    0 4 * * * root /jffs/ddwrt-adblock-d.sh
9. reboot
10. (optional) Prevent LAN clients to use their own DNS by ticking/enabling Forced DNS Redirection and
   Forced DNS Redirection DoT on Basic Setup page
11. Debug by removing the # on the second line of this script, view with: logread | grep debug
