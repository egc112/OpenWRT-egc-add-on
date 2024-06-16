# Copyright 2024 egc
# This is free software, licensed under AGPL-3.0-or-later.
# Add this repo `https://github.com/egc112/OpenWRT-egc-add-on.git` in `./feeds.conf.default` as:
# `src-git egc https://github.com/egc112/OpenWRT-egc-add-on.git`
# In menu (make menuconfig), Network > VPN  enable `wireguard-companion`


include $(TOPDIR)/rules.mk

PKG_NAME:=wireguard-companion
PKG_VERSION:=1.0.6
PKG_RELEASE:=1
PKG_LICENSE:=AGPL-3.0-or-later
PKG_MAINTAINER:=Erik Conijn <egc6774@gmail.com

include $(INCLUDE_DIR)/package.mk

define Package/wireguard-companion
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=VPN
	DEPENDS:=+wireguard-tools
	TITLE:=wireguard-companion-script
	URL:=https://github.com/egc112/OpenWRT-egc-add-on/tree/main/wireguard-companion
	PKGARCH:=all
endef

define Package/wireguard-companion/description
Shell script to toggle WireGuard tunnels on the router on/off and provide info about routing, tunnels and log
endef

define Package
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/wireguard-companion/install
	$(INSTALL_DIR) $(1)/usr/share
	$(INSTALL_BIN) ./wireguard-companion.sh $(1)/usr/share/wireguard-companion.sh
	$(SED) "s|^\(PKG_VERSION\).*|\1='$(PKG_VERSION)-$(PKG_RELEASE)'|" $(1)/usr/share/wireguard-companion.sh
endef

define Package/wireguard-companion/postinst
endef

define Package/wireguard-companion/prerm
endef

$(eval $(call BuildPackage,wireguard-companion))
