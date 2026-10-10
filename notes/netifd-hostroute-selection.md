# How netifd picks the interface for a VPN host route

Applies to every protocol that calls `proto_add_host_dependency` (WireGuard, OpenVPN, 6in4, gre, ipip, pptp, ...).
Source: netifd 06d06c8 (`interface-ip.c`, `proto-ext.c`, `interface.c`, `ubus.c`); behaviour measured on
vm-master (OpenWrt master r36208, netifd 6088f7b3), 2026-10-07/09.

## Short answer

netifd does **not** take "the first `/0`", and it does **not** look at ubus or the kernel routing table.
It searches its **own** per-interface route lists for the route that matches the endpoint best, and copies
that route's gateway into a new `/32` (`/128`) host route.

## The lookup, step by step

### Step 0: which interfaces are searched (`proto_ext_update_host_dep`)

| `tunlink` | Searched | If nothing usable |
|---|---|---|
| set (e.g. `wan`) | only that interface; it must be up | the VPN interface is marked **unavailable** and waits |
| empty | **every** interface, in name order (see below) | the VPN interface is marked **unavailable** and waits |

### Step 1: is the endpoint on-link? (`__find_ip_addr_target`, `interface-ip.c:207`)

For each interface, in order: if the endpoint lies inside one of the interface's **own address subnets**, or is
its point-to-point peer, that interface is returned **immediately** and **no host route** is created.

### Step 2: best matching route (`__find_ip_route_target`, `interface-ip.c:238`)

Each interface contributes the routes in two lists:
- **configured routes**: `config route` sections in `/etc/config/network` (`config_ip`);
- **protocol routes**: from DHCP, static gateway, VPN `route_allowed_ips`, the OpenVPN hotplug, ... (`proto_ip`).

A route is a candidate when it is enabled, has the same address family, and its target/mask **contains** the
endpoint. Routes with their own `table` option are skipped. Routes placed in a table via the interface's
`ip4table`/`ip6table` still count.

The best candidate:
1. **The longest prefix wins.** A `/32` beats a `/24`, which beats a `/1`, which beats a `/0`.
2. **On an equal prefix, only an explicit metric can win.** A later candidate replaces the current best only
   if it carries its **own** `metric` on the route (`DEVROUTE_METRIC`) **and** that metric is lower. A metric
   inherited from the interface's `option metric` does not count for this.
3. **Otherwise the first one found stays**, which means interface **name order** decides.

### Step 3: create the host route (`interface_ip_add_target_route`, `interface-ip.c:279`)

netifd copies the winner's **nexthop, mtu, metric, table and lifetime** into a `/32` (`/128`), adds it to the
winning interface's `host_routes` list and installs it in the kernel.

## Interface name order

Interfaces live in an AVL tree sorted with `avl_strcmp` (plain `strcmp`, `interface.c:1692`). That is byte
order:
- digits < UPPERCASE < `_` < lowercase;
- a shorter name sorts before a longer name with the same prefix (`wan` < `wan_backup`).

So `AWAN`, `Proton`, `a_vpn` and `0vpn` all sort **before** `wan`. **Any** of them that has a `0.0.0.0/0` route
(without an explicit higher metric) takes the host routes of every VPN that has no `tunlink`.

**Measured on vm-master (2026-10-10).** Two WireGuard tunnels, `awg_ch` (`route_allowed_ips 1`, `0.0.0.0/0`) and
`awg_mullv_us`:

| Names | `awg_ch`/`wg_ch` endpoint | `awg_mullv_us`/`wg_mullv_us` endpoint |
|---|---|---|
| `wg_ch`, `wg_mullv_us` (after `wan`) | via wan | via wan |
| `awg_ch`, `awg_mullv_us` (before `wan`) | via wan | **`dev awg_ch`**: tunnel inside the other tunnel (it even handshakes) |

- `awg_ch`'s own endpoint still goes via wan: its dependency is resolved during its own setup, before its `/0` is
  handed to netifd, so a VPN can never pick itself.
- **Start order matters too.** `awg_mullv_us` came up one second after `awg_ch`, so `awg_ch`'s `/0` already
  existed. Had it come up first, it would have resolved to wan and stayed there, because resolved host routes are
  never re-evaluated. With such names the result can differ from boot to boot.
- **Name order only breaks ties between candidates.** After `awg_ch` was set to `route_allowed_ips 0`, it handed
  netifd no routes at all (`ifstatus awg_ch` → `route: []`). So it was skipped although it still sorts before
  `wan`, and the US endpoint went via wan, the only interface with a covering route (measured 2026-10-10).
  **Point-to-point has nothing to do with it:** `awg_ch` was the same point-to-point link when it won. What
  counts is whether netifd has a route for that interface. The kernel route `10.65.53.0/24 dev awg_ch proto kernel`
  is only its address subnet, used for the on-link check. For point-to-point links, that check also matches the
  IPv4 peer address, which a VPN endpoint never is.
- `tunlink 'wan'` on `awg_mullv_us` pins it back to wan, regardless of names. **But on stock netifd it first did
  nothing:** the endpoint stayed `dev awg_ch` until `ifup wan`. At boot, `awg_mullv_us`'s first setup had resolved to
  wan a moment before `awg_ch`'s `/0` existed. It restarted once, resolved to `awg_ch`, and left the old entry in
  wan's list. So `tunlink=wan` found an "identical" entry and installed nothing. After `ifup wan` it goes via eth0
  (measured). Even a first-time `tunlink` can hit the stale entry, not only a switch back; openwrt/netifd#96 fixes
  that.

Example: an alias of wan named `AWAN` (device `@wan`, with `option gateway`) has its own `/0`. That ties with
wan's `/0` and wins by name. The host route then hangs off `AWAN`, and the main table gets a duplicate default
route as a side effect. The alias itself is not tested, but the same name-order effect is measured below. `tunlink` is the clean way to choose the uplink.

## What you can see

| | Visible? | Where |
|---|---|---|
| The **input**: configured + protocol routes per interface | **yes** | `ifstatus <iface>` → `route` (`ubus.c:899-900`). `metric` appears only when set explicitly on the route, which is the field step 2 uses |
| The **output**: netifd's `host_routes` list | **no** | not in any ubus dump |
| The kernel host route | yes | `ip route show <endpoint>` (`proto static`). Can differ from netifd's list: that is the stale-route problem fixed by openwrt/netifd#96 |
| netifd's choice for an address | yes, with a side effect | `ubus call network add_host_route '{"target":"<ip>"}'` returns the interface, **but really creates the host route**. Test boxes only |

## Consequences

- **The kernel is not consulted.** The host route can go elsewhere than `ip route get` says. On vm-master the
  kernel default went via `wg_ch`, yet netifd chose `wan` (name order). Routes created outside netifd (pbr
  tables, mwan3, a manual `ip route add`) are invisible to it.
- **"Default route = WAN" is only usually true.** On vm-master:

  | Situation | netifd picked |
  |---|---|
  | wan and `wg_ch` both `/0`, no explicit metric | `wan` (name order) |
  | `wg_ch` also has `0.0.0.0/1` + `128.0.0.0/1` | `wg_ch` (longest prefix) |
  | `wg_ch` has only `/1` routes, no `/0` | `wg_ch` (longest prefix) |
  | fake `193.32.127.0/24` on `lan` | `lan` (longest prefix) |
  | same, with `tunlink wan` | `wan` (`tunlink` overrides) |

- **IPv6 source routes:** only the destination is compared, not the `from` prefix, so source routing on wan6
  does not block the lookup.
- **A resolved host route is never re-evaluated.** Once the dependency is attached to an interface, a better
  route appearing elsewhere later does not move it. It only follows changes of its own parent route (gateway,
  lifetime: commit 9b62f2a). It moves again only after the VPN or its uplink restarts.
- **Stock netifd never removes it when the VPN goes down.** It stays in the uplink's list, and switching back
  to that uplink later is a no-op (the `keep` path). Fixed by openwrt/netifd#96; until then
  `service network restart` or `ifup <uplink>` clears it.

## Side note: a VPN `/0` replaces wan's default in the kernel

A VPN with `route_allowed_ips 1` and `0.0.0.0/0` (or an OpenVPN default route) adds a default with the same
kernel metric, which **replaces** wan's default in the main table (the routes are installed with
`NLM_F_REPLACE`). Removing that `/0` later deletes the kernel default and leaves **no** IPv4 default until wan
restarts (`ifup wan` or `service network restart`). Seen on vm-master with `wg_ch`, `wg_proton_nl` and `awg_ch`.
This is independent of the host-route logic, but often happens together with it.

## Related

- `tunlink` support: WireGuard (backend yes, LuCI field in openwrt/luci#9120), 6in4 (openwrt/luci#9108),
  gre/ipip/xfrm/openfortivpn (LuCI fields exist), OpenVPN (not yet; only partly useful, because its host
  route is added after the first connect).
- Host-route removal on teardown: openwrt/netifd#96.
