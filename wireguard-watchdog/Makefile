# Copyright 2024 egc
# This is free software, licensed under AGPL-3.0-or-later.

include $(TOPDIR)/rules.mk

PKG_NAME:=wireguard-watchdog
PKG_VERSION:=0.95
PKG_RELEASE:=1
PKG_LICENSE:=AGPL-3.0-or-later
PKG_MAINTAINER:=Erik Conijn <egc6774@gmail.com

include $(INCLUDE_DIR)/package.mk

define Package/wireguard-watchdog
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=VPN
	DEPENDS:=
	TITLE:=wireguard-watchdog-script
	URL:=https://github.com/egc112/OpenWRT-egc-add-on/tree/main/wireguard-watchdog
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
