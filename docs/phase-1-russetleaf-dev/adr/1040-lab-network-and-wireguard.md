# ADR 1040: Lab network behind its own router, reached over WireGuard

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** the home network, the three Talos nodes and the workstation
- **Phase:** 1

## Context

[ADR 1032](1032-defense-in-depth.md) requires the cluster to be separated from household devices. The home network is a Spectrum router, a mesh Wi-Fi extender in the server room, and an unmanaged switch connecting the servers. None of these can create VLANs or isolate wired devices, and Spectrum's routers don't allow custom routes. The workstation is on the household Wi-Fi and must stay there.

The decision is needed before Talos is installed: the nodes' addresses and the cluster's virtual IP are written into the Talos configuration and certificates, so moving the cluster to another subnet later means re-addressing or rebuilding it.

## Decision

- **A TP-Link ER605 (v2) router in front of the lab:** WAN port to the mesh extender, LAN port to the switch. The lab is its own subnet, **`10.10.0.0/24`**: gateway `10.10.0.1`, cluster virtual IP `10.10.0.10`, boxes 1–3 at `10.10.0.11`–`.13`.
- **Isolation:** an access-control rule on the ER605 lets the lab reach the internet but **not `192.168.1.0/24`**; the ER605's NAT keeps household devices out; no port forwards anywhere (the Cloudflare Tunnel is outbound-only).
- **Workstation access over WireGuard:** the ER605's WireGuard server (clients `10.10.99.0/24`) listens on its WAN address on the household network, so the workstation connects from the household Wi-Fi with **no port forwarding on the Spectrum router**. The client profile is a **split tunnel** (only `10.10.0.0/24`). The Talos host firewall allows the Kubernetes and Talos APIs only from the lab subnet and the WireGuard clients.
- **The admin tools don't need the VPN:** Grafana, Argo CD and Hubble UI stay behind Cloudflare Access.
- The ER605 runs in standalone mode, with a DHCP reservation for its WAN address on the Spectrum router; its admin login and configuration backup go in the break-glass kit ([ADR 1018](1018-disaster-recovery.md)).

## Alternatives considered

- **VLANs** (a VLAN-capable router and a managed switch, e.g. UniFi or an OPNsense mini PC): the textbook approach, but more equipment and configuration than one isolated segment needs.
- **No separation (deferred):** relies on the Talos firewall and Cilium's default-deny egress policies, which already stop pods reaching household devices, but leaves a compromised node or broadly permitted platform component able to reach them; and re-addressing later is costly.
- **Routing the lab subnet without NAT:** would let household devices reach the lab directly, but needs a static route on the Spectrum router, which it doesn't support.
- **Other routers with WireGuard** (e.g. GL.iNet, MikroTik): equally suitable; the ER605 v2 supports WireGuard, firewall rules and multiple subnets at low cost.

## Consequences

- Household devices and the cluster can't reach each other; `kubectl` and `talosctl` work only over the tunnel.
- The tunnel works only inside the house (it isn't exposed to the internet), which is enough for this project.
- One more device to keep updated and backed up; double NAT for the cluster's outbound traffic (no effect on the Cloudflare Tunnel).
- If the mesh extender's link to the Spectrum router is wireless, the cluster's internet connection is too; traffic between the nodes stays on the switch.

## When to revisit

- Remote access from outside the house is needed: consider Cloudflare Access for the APIs, or a port forward for WireGuard.
- More segments are needed (e.g. separating staging, or IoT devices): move to VLANs with a managed switch.

## Open items

- Phase 1 step 0.3: set up the ER605, the firewall rule and WireGuard; step 2.2: the addresses, the virtual IP and the Talos firewall.
