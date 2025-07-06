# Copyright 2024 egc
# This is free software, licensed under AGPL-3.0-or-later.
# Add this repo `https://github.com/egc112/OpenWRT-egc-add-on.git` in `./feeds.conf.default` as:
# `src-git egc https://github.com/egc112/OpenWRT-egc-add-on.git`
# In menu (make menuconfig), Network > VPN  enable `wireguard-watchdog`


include $(TOPDIR)/rules.mk

PKG_NAME:=wireguard-companion
PKG_VERSION:=1.0.7
PKG_RELEASE:=1
PKG_LICENSE:=AGPL-3.0-or-later
PKG_MAINTAINER:=Erik Conijn <egc6774@gmail.com

include $(INCLUDE_DIR)/package.mk

define Package/wireguard-companion
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=VPN
	DEPENDS:=+kmod-wireguard +wireguard-tools
	TITLE:=wireguard-watchdog-script
	URL:=https://github.com/egc112/OpenWRT-egc-add-on/tree/main/wireguard-watchdog-with-failover
	PKGARCH:=all
endef

define Package/wireguard-watchdog/description
Shell script to toggle WireGuard tunnels on the router on/off and provide info about routing, tunnels and log
endef

define Package
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/wireguard-watchdog/install
	$(INSTALL_DIR) $(1)/usr/share
	$(INSTALL_BIN) ./wireguard-watchdog.sh $(1)/usr/share/wireguard-watchdog.sh
	$(SED) "s|^\(PKG_VERSION\).*|\1='$(PKG_VERSION)-$(PKG_RELEASE)'|" $(1)/usr/share/wireguard-watchdog.sh
endef

define Package/wireguard-watchdog/postinst
endef

define Package/wireguard-watchdog/prerm
endef

$(eval $(call BuildPackage,wireguard-watchdog))
