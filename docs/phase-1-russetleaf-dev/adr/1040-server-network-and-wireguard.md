# ADR 1040: Server network behind its own router, reached over WireGuard

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** the main network, the three Talos nodes and the workstation
- **Phase:** 1

> **Update ([decision log](../plan.md#decision-log), 2026-11-20):** the network behind the ER605 is called **the server network** (it was "the lab network"), and the workstation's WireGuard tunnel is **`rl-mgmt`**; the decision is unchanged.

## Context

[ADR 1032](1032-defense-in-depth.md) requires the cluster to be separated from devices on the main network. The main network is the internet service provider's router (the **ISP router**; here a Spectrum SAX1V1K), a TP-Link RE315 (AC1200 Mesh Wi-Fi Range Extender) in the server room, and an unmanaged switch (a TP-Link TL-SG105) connecting the servers. None of these can create VLANs or isolate wired devices, and the ISP router does not allow custom routes. The workstation is on the main network's Wi-Fi and must stay there.

The decision is needed before Talos is installed: the nodes' addresses and the cluster's virtual IP are written into the Talos configuration and certificates, so moving the cluster to another subnet later means re-addressing or rebuilding it.

## Decision

- **A TP-Link ER605 (v2) router in front of the servers:** WAN port to the RE315's Ethernet port, LAN port to the switch. The server network is its own subnet, **`10.10.0.0/24`**: gateway `10.10.0.1`, cluster virtual IP `10.10.0.10`, the three nodes at `10.10.0.11`–`.13`.
- **Isolation:** an access-control rule on the ER605 lets the server network reach the internet but **not `192.168.1.0/24`**; the ER605's NAT keeps devices on the main network out; no port forwards anywhere (the Cloudflare Tunnel is outbound-only).
- **Workstation access over WireGuard:** the ER605's WireGuard server (clients `10.10.99.0/24`) listens on its WAN address on the main network, so the workstation connects from the main network's Wi-Fi with **no port forwarding on the ISP router**. The client profile is a **split tunnel** (only `10.10.0.0/24`). The Talos host firewall allows the Kubernetes and Talos APIs only from the server subnet and the WireGuard clients.
- **The admin tools do not need the VPN:** Grafana, Argo CD and Hubble UI stay behind Cloudflare Access.
- The ER605 runs in standalone mode, with a DHCP reservation for its WAN address on the ISP router; its admin login and configuration backup go in the break-glass kit ([ADR 1018](1018-disaster-recovery.md)).

## Alternatives considered

- **VLANs** (a VLAN-capable router and a managed switch, for example, UniFi or an OPNsense mini PC): the textbook approach, but more equipment and configuration than one isolated segment needs.
- **No separation (deferred):** relies on the Talos firewall and Cilium's default-deny egress policies, which already stop pods reaching devices on the main network, but leaves a compromised node or broadly permitted platform component able to reach them; and re-addressing later is costly.
- **Routing the server subnet without NAT:** would let devices on the main network reach the servers directly, but needs a static route on the ISP router, which it does not support.
- **Other routers with WireGuard** (for example, GL.iNet, MikroTik): equally suitable; the ER605 v2 supports WireGuard, firewall rules and multiple subnets at low cost.

## Consequences

- Devices on the main network and the cluster cannot reach each other; `kubectl` and `talosctl` work only over the tunnel.
- The tunnel works only on site (it is not exposed to the internet), which is enough for this project.
- One more device to keep updated and backed up; double NAT for the cluster's outbound traffic (no effect on the Cloudflare Tunnel).
- The RE315 reaches the ISP router over Wi-Fi, and its Ethernet port is **10/100 Mbps**, so the cluster's internet connection is limited to 100 Mbps and to the quality of that Wi-Fi link; traffic between the nodes stays on the switch at 1 Gbps. A faster uplink is in the [improvements list](../improvements.md) (I1-10).

## When to revisit

- Remote access from off site is needed: consider Cloudflare Access for the APIs, or a port forward for WireGuard.
- More segments are needed (for example, separating staging, or IoT devices): move to VLANs with a managed switch.

## Open items

- Phase 1 step 0.3: set up the ER605, the firewall rule and WireGuard; step 2.2: the addresses, the virtual IP and the Talos firewall.
