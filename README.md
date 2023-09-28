# OpenWRT-egc-add-on
Repository with snippets which might be useful to the community

## [HRtimer patches](https://github.com/egc112/OpenWRT-egc-add-on/blob/main/patches/Severe%20performance%20degradation%20for%20IPQ806x-3.md)
The hrtimer patches can be found in the [patches](https://github.com/egc112/OpenWRT-egc-add-on/tree/main/patches/root) directory

You can also find builds for various routers with the HRTimer patch included.   
Builds are 23.05 snapshot with LuCi, wireless, OpenVPN and WireGuard

For 23.05 you do not need any patches any more as the revert hrtimer patch is now included in 23.05 snapshot.

For the main branch with Kernel 6.1 an experimental patch which uses a different approach is included this needs to be tested.  
[A build with this patch](https://github.com/egc112/OpenWRT-egc-add-on/tree/main/patches/root/6.1/build%20for%20R7800%20ansuel) is included but is experimental, you probabaly need to reset to defaults as it is also using DSA (need confirmation).
DO NOT USE this experimetal build if you do not know how to debrick!
A build with the revert patch and Kernel 6.1 is also available

## [Radio firmware for IPQ807x Dynalink DL-WRX36](https://github.com/egc112/OpenWRT-egc-add-on/tree/main/DL-WRX36)  

## [Stop DNS leak when using VPN (OpenVPN and WireGuard)](https://github.com/egc112/OpenWRT-egc-add-on/tree/main/stop-dns-leak)
