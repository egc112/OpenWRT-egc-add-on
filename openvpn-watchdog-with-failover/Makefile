# Copyright 2024 egc
# This is free software, licensed under AGPL-3.0-or-later.
# Add this repo `https://github.com/egc112/OpenWRT-egc-add-on.git` in `./feeds.conf.default` as:
# `src-git egc https://github.com/egc112/OpenWRT-egc-add-on.git`
# In menu (make menuconfig), Network > VPN  enable `openvpn-watchdog`


include $(TOPDIR)/rules.mk

PKG_NAME:=openvpn-watchdog
PKG_VERSION:=1.0.7
PKG_RELEASE:=1
PKG_LICENSE:=AGPL-3.0-or-later
PKG_MAINTAINER:=Erik Conijn <egc6774@gmail.com

include $(INCLUDE_DIR)/package.mk

define Package/openvpn-watchdog
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=VPN
	DEPENDS:=+kmod-openvpn-openssl
	TITLE:=openvpn-watchdog-script
	URL:=https://github.com/egc112/OpenWRT-egc-add-on/tree/main/openvpn-watchdog-with-failover
	PKGARCH:=all
endef

define Package/openvpn-watchdog/description
Shell script to monitor OpenVPN client tunnels and in case of a fail, the next tunnel will be started
endef

define Package
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/openvpn-watchdog/install
	$(INSTALL_DIR) $(1)/usr/share
	$(INSTALL_BIN) ./openvpn-watchdog.sh $(1)/usr/share/openvpn-watchdog.sh
	$(SED) "s|^\(PKG_VERSION\).*|\1='$(PKG_VERSION)-$(PKG_RELEASE)'|" $(1)/usr/share/openvpn-watchdog.sh
endef

define Package/openvpn-watchdog/postinst
endef

define Package/openvpn-watchdog/prerm
endef

$(eval $(call BuildPackage,openvpn-watchdog))
