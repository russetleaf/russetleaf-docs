# Setup guide: the lab network and WireGuard

The step-by-step procedure for the lab network: the **TP-Link ER605 (v2)** router (`rl-home-rt01`) that separates the cluster from the household network, and the **WireGuard** tunnel the workstation uses to reach it (Phase 1 [step 0.3](../plan.md#step-03-home-network-segmentation)). The reasoning is in [ADR 1040](../adr/1040-lab-network-and-wireguard.md), and the addresses and hardware in the Phase 1 design's [Home hardware](../design.md#home-hardware).

```text
Workstation (Wi-Fi, 192.168.1.x) ──WireGuard──┐
                                              ▼
Spectrum router ── mesh extender ── ER605 WAN (192.168.1.y) │ ER605 LAN (10.10.0.1) ── switch ── the three nodes
```

**Note:** the click paths in this guide are those the router's web interface showed when the procedure was last carried out. Firmware updates change the interface without notice, and TP-Link's documentation can lag behind the interface. Before following a path, check TP-Link's current documentation for the ER605 (v2); where the screen still differs, follow what it shows and fix this guide to match.

## Before starting

- The **ER605 (v2)**: check the label underneath says hardware version **V2** (WireGuard needs it), the **TL-SG105** switch (`rl-home-sw01`), and network cables.
- The **workstation**, with `wireguard-tools` installed (the [workstation setup script](../plan.md#1-run-the-setup-script) installs it), and **Bitwarden** (the project's password manager) open.
- A **laptop** (or any spare device) that can be plugged into the lab switch, for the checks at the end.
- The **MAC addresses** of the three nodes' network ports (on a label, or in each machine's BIOS), for the address reservations.

## Part 1: Wiring and first login

1. **Wire it:** the ER605's **WAN** port to the mesh extender, one of its **LAN** ports to the switch, and the three nodes to the switch. (The port labels show which ports are WAN and which are LAN.)
2. **First login:** connect the workstation (or laptop) by cable to a spare LAN port, and open the ER605's default address, `http://192.168.0.1`. Create the **admin username and password** it asks for, generated in the password manager. Use it in **standalone mode** (no Omada controller).
3. **Update the firmware:** download the latest **ER605 V2** firmware from TP-Link's support site (check its release notes mention WireGuard), and install it from the **firmware upgrade** page under the system tools. The router restarts.

## Part 2: WAN, LAN and addresses

1. **WAN:** leave the WAN connection on **dynamic IP (DHCP)** from the Spectrum router, and note the address it gets: this is the WireGuard endpoint.
2. **Keep that address fixed:** on the Spectrum router, reserve that address for the ER605's WAN MAC address. If the Spectrum router cannot reserve addresses, give the ER605 a **static WAN address** instead, outside the Spectrum router's DHCP range (with the Spectrum router, `192.168.1.1`, as gateway).
3. **LAN:** change the LAN address to **`10.10.0.1`**, subnet mask `255.255.255.0`. The web interface moves to `http://10.10.0.1`; reconnect the cable (or renew the address) and sign in there.
4. **DHCP on the LAN:** a pool of **`10.10.0.100`–`10.10.0.199`**, and set the **DNS servers** handed out to **`1.1.1.1`** and **`9.9.9.9`**, not the Spectrum router: the firewall rule in Part 3 blocks the household network, which would break DNS for anything using `192.168.1.1`.
5. **Address reservations,** matched by MAC address under each node's hostname ([ADR 1041](../adr/1041-naming-convention.md)):

    | Hostname | Address |
    |---|---|
    | `rl-home-cp01` | `10.10.0.11` |
    | `rl-home-cp02` | `10.10.0.12` |
    | `rl-home-cp03` | `10.10.0.13` |

    Leave **`10.10.0.10` unused**: it is the cluster's virtual IP. Talos also sets these addresses statically in step 2.2. If the router accepts reservations only inside the pool, widen the pool to `10.10.0.11`–`10.10.0.199`; `.10` stays outside it either way.

6. **Name the router `rl-home-rt01`** where the system settings allow a device name, and put a label with that name on the case.

## Part 3: The firewall

1. **The household network as a group:** in the IP group settings, create a group named **`household`** for **`192.168.1.0/24`**.
2. **Block the lab from it:** in the **access control** rules, add a rule:

    | Setting | Value |
    |---|---|
    | Name | `lab-to-household-deny` |
    | Policy | Deny |
    | Direction | LAN → WAN |
    | Source | The LAN network (`10.10.0.0/24`) |
    | Destination | The `household` group |
    | Services | All |

    The lab can still reach the internet; nothing from the household network can start a connection into the lab, because the ER605's NAT drops it.
3. **Nothing comes in:** confirm there are **no port forwards** (virtual servers), turn **UPnP off** (so no device in the lab can open its own port forward), and make sure **remote management from the WAN side is off**. The Cloudflare Tunnel is outbound-only, so nothing needs to come in.

## Part 4: WireGuard for the workstation

The workstation's private key is generated on the workstation and never leaves it; the router only learns its public key.

1. **The workstation's keys:**

    ```bash
    mkdir -p ~/.config/wireguard && chmod 700 ~/.config/wireguard
    wg genkey | tee ~/.config/wireguard/rl-lab.key | wg pubkey > ~/.config/wireguard/rl-lab.pub
    chmod 600 ~/.config/wireguard/rl-lab.key
    cat ~/.config/wireguard/rl-lab.pub      # the public key, for the router
    ```

2. **The WireGuard server on the ER605:** in the VPN settings, create a **WireGuard** interface with listen port **`51820`** and local address **`10.10.99.1/24`**. Copy the **public key** the router generates for it.
3. **The workstation as a peer:** add a peer named after the workstation, with the workstation's **public key** from step 1, allowed address **`10.10.99.2/32`**, and a keepalive of **25 seconds**.
4. **The client profile:** on the workstation, write `~/.config/wireguard/rl-lab.conf` (mode `600`). It is a **split tunnel**: only the lab's traffic goes through it, so there is no `DNS` line and `AllowedIPs` lists only the lab subnet.

    ```ini
    [Interface]
    PrivateKey = <the contents of ~/.config/wireguard/rl-lab.key>
    Address = 10.10.99.2/24

    [Peer]
    PublicKey = <the ER605's WireGuard public key>
    Endpoint = <the ER605's WAN address>:51820
    AllowedIPs = 10.10.0.0/24
    PersistentKeepalive = 25
    ```

5. **Import it into NetworkManager,** and keep it off until needed:

    ```bash
    nmcli connection import type wireguard file ~/.config/wireguard/rl-lab.conf
    nmcli connection modify rl-lab connection.autoconnect no
    nmcli connection up rl-lab        # when working on the cluster
    nmcli connection down rl-lab
    ```

6. **Keep a copy in the break-glass kit:** store the profile in the password manager ([disaster recovery plan](../disaster-recovery.md#break-glass-kit)), then delete the files in `~/.config/wireguard/` (NetworkManager keeps its own copy, readable only by root).

## Part 5: Backups and BIOS passwords

1. **Back up the ER605's configuration** from the backup page under the system tools, and store the file in the password manager with the admin login. Repeat after every change.
2. **BIOS passwords** on all three nodes: enter each machine's setup (**F1** on the Lenovo ThinkCentre, **F2** on the Dell OptiPlex machines) and set the **administrator (supervisor) password**, from the password manager. The other BIOS settings (Secure Boot, the TPM, power-on after a power cut) are part of step 2.2.

## Checks

The test for step 0.3:

- [ ] From a **laptop plugged into the lab switch**: the internet works, it gets a `10.10.0.1xx` address with DNS servers `1.1.1.1` and `9.9.9.9`, and the Spectrum router's admin page at `192.168.1.1` (or any household device) is **unreachable**.
- [ ] From the **workstation with WireGuard up**: `ping 10.10.0.1` answers, and ordinary internet traffic does not go through the tunnel (`ip route get 1.1.1.1` shows the Wi-Fi interface, not `rl-lab`).
- [ ] With **WireGuard down**: `10.10.0.1` is **not** reachable.
- [ ] From **another household device**: the lab is not reachable.
- [ ] The router has **no port forwards**, **UPnP is off** and **remote management is off**.
- [ ] The break-glass kit has the ER605's admin login, its configuration backup, the WireGuard profile and the three BIOS passwords.

Step 2.2 repeats the isolation checks from a pod inside the cluster.
