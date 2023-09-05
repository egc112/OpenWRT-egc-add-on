Severe performance degradation for IPQ806x Kernel 5.11 and higher.
==================================================================

Recently a bug has been discovered which explains the severe performance
degradation for IPQ806x Kernel 5.11 and higher:
<https://github.com/openwrt/openwrt/issues/11676>
<https://github.com/openwrt/openwrt/pull/13323>
<https://www.spinics.net/lists/netdev/msg931629.html>

In short the introduction of `hrtimer` in
`drivers/net/ethernet/stmicro/stmmac/stmmac_main.c` and `
drivers/net/ethernet/stmicro/stmmac/stmmac.h` seems to have introduced a bug
for the krait cores which started wasting many CPU cycles re-arming the hrtimer.

Commit:
<https://github.com/torvalds/linux/commit/d5a05e69ac6e4c431c380ced2b534c91f7bc3280>

This patch reverts this commit. This patch is a workaround as there could be
unwanted side effects, the devs are studying on a proper solution, but in the
mean time you can try this.

From the Github repo: <https://github.com/egc112/OpenWRT-egc-add-on> download
the zip file (under the green `Code button`

Extract the content of the patches directory in the zip file to your `patches`
directory.

There are two hrtimer patches, one for Kernel 5.15 (23.05) in
`/patches/root/5.15` and for Kernel 6.1 (Main/Master) in
`/patches/root/6.1`.

After you have prepared your build system and are ready to compile, copy the
patch for the Kernel version you are using to the OpenWRT root directory.

From that directory execute the patch (this is for Kernel 5.15) with:
`patch -p1 \< 901-net-stmmac-revert-hrtimer-5.15.patch`

This patch will add the following file to
`target/linux/ipq806x/patches-5.15/901-net-stmmac-revert-hrtimer.patch`

You can simply check with:
`ls target/linux/ipq806x/patches-5.15/901-net-stmmac-revert-hrtimer.patch`

Alternatively there is a ready made build with this hrtimer patch for Linksys
EA8500 and Netgear R7800.

Both 23.05 Snapshot, basic builds with wireless, Luci, WireGuard and OpenVPN.
Both tested on my own routers and both are working.
