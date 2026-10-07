### Packages directory

A signed apk repository for OpenWrt 25.12 and later (apk-based builds) with:

| package | what it does |
|---|---|
| `wireguard-companion` | toggle WireGuard tunnels on/off and show info about routing, tunnels and the log |
| `wireguard-watchdog` | monitor WireGuard client tunnels and start the next tunnel when one fails |
| `openvpn-watchdog` | monitor OpenVPN client tunnels and start the next tunnel when one fails |

The packages are architecture independent (`noarch`) and install on every router.

#### 1. Trust the signing key (once)

```
wget -O /etc/apk/keys/egc112.pem https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/packages/egc112.pem
```

Optionally check it with `sha256sum /etc/apk/keys/egc112.pem`. It should print:
```
ea3e102c82ccedceef2297942cea6fe2d80d349deca3c6a14f2c0a2e68152a41
```

#### 2. Add the repository

```
echo "https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/packages/packages.adb" > /etc/apk/repositories.d/egc.list
apk update
```

If you already added this URL to `/etc/apk/repositories.d/customfeeds.list`, remove it there,
so the repository is not listed twice.

#### 3. Install

```
apk add wireguard-companion
```

Without the key, `apk update` shows `UNTRUSTED signature` and `apk add` fails with
`unable to select package`. Install the key (step 1); do not use `--allow-untrusted`.
