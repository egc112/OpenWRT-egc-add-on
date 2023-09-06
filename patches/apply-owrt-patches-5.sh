#!/bin/bash

# to view what is happening
set -x 

# set the directory where the patches are located
OWRT_PATCHES=/shrd/openwrt/patches

# OWRT_BASE is the root directory of the OpenWRT build system if the script is not run from there and or this variable is not exported then set it here
# OWRT_BASE=/linuxdata/openwrt

cd $OWRT_BASE
FAILED=0

# Patches for all kernels
echo " Applying root patches for all"
if ls $OWRT_PATCHES/root/*.patch >/dev/null 2>&1; then
	for patch in $OWRT_PATCHES/root/*.patch
	do
		[[ -z "${patch}" ]] && { echo " No patches to apply for Root"; break; }
		echo Applying "${patch}"
		cd $OWRT_BASE
		patch -p1 < "${patch}"
		if [ $? -ne 0 ]; then
			FAILED=1
		fi
	done
else
	echo " NO root patches to apply for all"
fi

# Patches for specific kernels
echo " Applying root patches for Kernel:[$KERNEL]"
if ls $OWRT_PATCHES/root/$KERNEL/*.patch >/dev/null 2>&1; then
	for patch in $OWRT_PATCHES/root/$KERNEL/*.patch
	do
		echo Applying "${patch}"
		cd $OWRT_BASE
		patch -p1 < "${patch}"
		if [ $? -ne 0 ]; then
			FAILED=1
		fi
	done
else
	echo " NO root patches to apply for Kernel:[$KERNEL]"
fi

# Patches for packages
echo " Applying patches for Packages"
if ls $OWRT_PATCHES/packages/*.patch >/dev/null 2>&1; then
	for patch in $OWRT_PATCHES/packages/*.patch
	do
		[[ -z "${patch}" ]] && { echo " No patches to apply for Packages"; break; }
		echo Applying "${patch}"
		cd $OWRT_BASE/feeds/packages
		patch -p1 < "${patch}"
		if [ $? -ne 0 ]; then
			FAILED=1
		fi
	done
else
	echo " NO patches to apply for Packages"
fi

# Patches for LuCi
echo " Applying patches for LuCi"
if ls $OWRT_PATCHES/luci/*.patch >/dev/null 2>&1; then
	for patch in $OWRT_PATCHES/luci/*.patch
	do
		[[ -z "${patch}" ]] && { echo " No patches to apply for Luci"; break; }
		echo Applying "${patch}"
		cd $OWRT_BASE/feeds/luci
		patch -p1 < "${patch}"
		if [ $? -ne 0 ]; then
			FAILED=1
		fi
	done
else
	echo " NO patches to apply for LuCi"
fi

# copy scramble patches to feeds/packages/net/openvpn/patches
echo " Applying OpenVPN patches for Kernel:[$KERNEL]"
if ls $OWRT_PATCHES/openvpn-scramble/feeds/$KERNEL/*.patch >/dev/null 2>&1; then
	for patch in $OWRT_PATCHES/openvpn-scramble/feeds/$KERNEL/*.patch
	do
		[[ -z "${patch}" ]] && { echo " No patches to apply for OpenVPN scramble"; break; }
		echo copying "${patch}"
		cp ${patch} $OWRT_BASE/feeds/packages/net/openvpn/patches/
		if [ $? -ne 0 ]; then
			FAILED=1
		fi
	done
else
	echo " NO patches to apply for OpenVPN Scramble"
fi

if [ $FAILED -ne 0 ]; then
	echo
	echo FAILED applying patches!
	echo
	echo Please see above output and fix before building!
	echo
	exit 1
fi

cd $OWRT_BASE

