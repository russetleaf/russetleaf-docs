# Setup guide: the lab network and WireGuard

The step-by-step procedure for the lab network: the **TP-Link ER605 (v2)** router (`rl-onprem-rt01`) that separates the cluster from the main network, and the **WireGuard** tunnel the workstation uses to reach it (Phase 1 [step 0.3](../plan.md#step-03-lab-network-segmentation)). The reasoning is in [ADR 1040](../adr/1040-lab-network-and-wireguard.md), and the addresses and hardware in the Phase 1 design's [On-premises hardware](../design.md#on-premises-hardware).

```text
Workstation (Wi-Fi, 192.168.1.x) ──WireGuard──┐
                                              ▼
ISP router ── RE315 extender ── ER605 WAN (192.168.1.y) │ ER605 LAN (10.10.0.1) ── switch ── the three nodes
```

**Note:** the click paths in this guide are those the router's web interface showed when the procedure was last carried out. Firmware updates change the interface without notice, and TP-Link's documentation can lag behind the interface. Before following a path, check TP-Link's current documentation for the ER605 (v2); where the screen still differs, follow what it shows and fix this guide to match.

## Before starting

- The **TP-Link RE315** extender (AC1200 Mesh Wi-Fi Range Extender), already set up in **Range Extender** mode on the main network's Wi-Fi: its Ethernet port connects a wired device to the extended network ([References](#references)).
- The **ER605 (v2)**, the **TL-SG105** switch (`rl-onprem-sw01`), and network cables. WireGuard needs hardware version **V2**: the label underneath gives the region code and hardware version together (for example `UN/2.36`, which is ER605(UN) v2.36), where **2.x** means V2, and Part 1 confirms it on the router's **System Status** page.
- The **latest V2 firmware** from the ER605's download page ([References](#references)), with its release note, downloaded **on the second computer** (below): the firmware is uploaded from that computer's browser, because the workstation reaches the router only over WireGuard, which Part 4 sets up. One V2 firmware serves every 2.x hardware version: check that the release note's **Applied Model** list includes the one on the label. The release note also gives a **minimum version for the update** (**Minimum FW Version for Update**): a router on an older version installs that version first. For 2.4.10 Build 20260916 the minimum is 2.3.2 Build 20251029. The download is a `.zip` archive; Part 1 extracts the firmware file from it.
- The **workstation**, with `wireguard-tools` installed (the [workstation setup script](../plan.md#1-run-the-setup-script) installs it), and **Bitwarden** (the project's password manager) open.
- A **second computer with an Ethernet port** and a web browser, on any operating system (Linux, macOS or Windows), for the first login and firmware update (Part 1) and the checks at the end. It needs none of the project's credentials or keys. The workstation stays on the main network's Wi-Fi throughout.
- The **MAC addresses** of the three nodes' network ports, for the address reservations. They need not be known in advance: once the nodes are on the switch, the ER605 lists each one that asks it for an address (Part 2, step 5). A node with no operating system asks only while it tries to start from the network; otherwise its BIOS setup shows the MAC address.
- Access to the **ISP router's** settings, to reserve the ER605's WAN address: its web page or its provider's app (for the Spectrum SAX1V1K used here, the **My Spectrum** app).

## Part 1: Wiring, first login and firmware

The ER605's web interface is used in **standalone mode** throughout: no Omada controller.

1. **Wire it:** the ER605's **WAN** port to the Ethernet port of the RE315, one of its **LAN** ports to the switch, and the three nodes to the switch. The port labels show which ports are WAN and which are LAN.
2. **First login:** connect the second computer by cable to a spare LAN port of the ER605, with its wired connection set to get an address automatically, and open `http://192.168.0.1`. Create the **username and password** the page asks for, generated in Bitwarden and saved in a new item for the router, then log in with them.
3. **Check the firmware:** **Status → System Status → System Status** shows the hardware and firmware versions. If the firmware is older than the release note's minimum, install that version first, as in steps 4 and 5.
4. **Extract the firmware file:** the router accepts only the firmware file itself, not the `.zip` archive it was downloaded in. Extract the archive with the operating system's archive tool, and use the firmware file from the extracted folder.
5. **Update the firmware:** **System Tools → Management → Firmware Upgrade**, select the extracted firmware file, and **Upgrade**. The router restarts; log in again and check the new version on the **System Status** page.

## Part 2: WAN, LAN and addresses

1. **WAN:** **Network → WAN → WAN**. In the **Connection Configuration** section, the **Connection Type** stays **Dynamic IP** (from the ISP router); enter the **Host Name** `rl-onprem-rt01` ([ADR 1041](../adr/1041-naming-convention.md)), which the ISP router then shows for this device, and **Save**. The WAN address the router gets is shown on **Status → System Status → System Status**: it is the WireGuard endpoint. Leave **Network → WAN → WAN Mode** as it is: changing the number of WAN ports can lose the configuration.
2. **Keep that address fixed:** in the ISP router's settings, reserve the address the ISP router gave the ER605 (it appears under its host name, `rl-onprem-rt01`). Restart the ER605 afterwards (unplug it for ten seconds) and check on the **System Status** page that its WAN address has not changed. If the ISP router cannot reserve addresses, give the ER605 a **static WAN address** instead (**Connection Type** **Static IP**), outside the ISP router's DHCP range, with the ISP router, `192.168.1.1`, as gateway.

    **The link to the ISP router must carry the ER605's own MAC address:** an Ethernet cable, or a bridge that acts like one (a pair of powerline or MoCA adapters). A **Wi-Fi range extender** between them does not: TP-Link's range extenders, for example, replace the MAC address of each wired device behind them with a virtual one, or with the extender's own ([References](#references)), so the ISP router cannot tell the ER605 apart and neither a reservation nor a safely chosen static address is possible. With an ISP router managed only through an app, whose DHCP range is not shown, a reservation is the only safe choice.
3. **LAN:** **Network → LAN → LAN**. Set **IP Address** to **`10.10.0.1`** and **Subnet Mask** to `255.255.255.0`, and **Save**. The browser moves to `http://10.10.0.1`; if it does not, unplug and reconnect the cable, so the workstation gets a new address, and log in there.
4. **DHCP on the LAN:** on the same page, in the DHCP server settings: **Starting/Ending IP Address** **`10.10.0.100`** to **`10.10.0.199`**, **Default Gateway** `10.10.0.1`, **Primary/Secondary DNS** **`1.1.1.1`** and **`9.9.9.9`**, and **Status** checked; then **Save**. The DNS servers are public ones, not the ISP router: the firewall rule in Part 3 blocks the main network, which would break DNS for anything using `192.168.1.1`.
5. **Address reservations:** first find each node's MAC address: **Network → LAN → DHCP Client List** shows every device that has an address from the ER605, with its **Client Name**, **MAC Address**, **Assigned IP Address** and **Lease Time**. Then **Network → LAN → Address Reservation**, then **Add** for each node: its **MAC Address**, the **IP Address** below, the hostname as **Description** ([ADR 1041](../adr/1041-naming-convention.md)), **Status** checked, and **OK**.

    | Description | IP Address |
    |---|---|
    | `rl-onprem-cp01` | `10.10.0.11` |
    | `rl-onprem-cp02` | `10.10.0.12` |
    | `rl-onprem-cp03` | `10.10.0.13` |

    Leave **`10.10.0.10` unused**: it is the cluster's virtual IP. Talos also sets these addresses statically in step 2.2. If the router accepts reservations only inside the pool, widen the pool to `10.10.0.11`–`10.10.0.199`; `.10` stays outside it either way.

6. **Label the case** with the router's name, `rl-onprem-rt01`.

## Part 3: The firewall and remote access

1. **The two networks as IP groups:** **Preferences → IP Group → IP Address**, then **Add**, twice: **Name** `main_net`, **IP Address Type** **IP Address/Mask**, `192.168.1.0` / `255.255.255.0`; and **Name** `lab_net`, `10.10.0.0` / `255.255.255.0`; each with **OK**. Then **Preferences → IP Group → IP Group**, **Add**, twice: **Group Name** `main` with **Address Name** `main_net`, and **Group Name** `lab` with `lab_net`; each with **OK**. (Names take only letters, digits and underscores.)
2. **Block the lab from the main network:** **Firewall → Access Control → Access Control**, then **Add**:

    | Setting | Value |
    |---|---|
    | Name | `lab-to-main-deny` |
    | Policy | Block |
    | Service Type | ALL |
    | Direction | LAN -> WAN |
    | Source | `lab` |
    | Destination | `main` |
    | Effective Time | Any |

    Then **OK**. The lab can still reach the internet; nothing from the main network can start a connection into the lab, because the ER605's NAT drops it.
3. **Nothing comes in:**
    - **Transmission → NAT → Virtual Servers** lists **no** entries (no port forwards); check **One-to-One NAT** and **NAT-DMZ** under **Transmission → NAT** too.
    - **Service → UPnP**: **Enable UPnP** cleared, and **Save**, so no device in the lab can open its own port forward.
    - **System Tools → Admin Setup → Remote Management** lists **no** entries, so the web interface cannot be reached from the WAN side.
    - **System Tools → Controller Settings**: **Cloud-Based Controller Management** off.
    - **System Tools → Diagnostics → Remote Assistance**: the box cleared, so TP-Link's technicians cannot reach the router by SSH.

    The Cloudflare Tunnel is outbound-only, so nothing needs to come in.
4. **HTTPS for the web interface:** **System Tools → Admin Setup → System Settings**: **HTTPS Server Status** and **Redirect HTTP to HTTPS** checked, and **Save**. The router's certificate is self-signed, so the browser warns on the first visit; from then on, the admin password is not sent in the clear.

## Part 4: WireGuard for the workstation

The workstation's private key is generated on the workstation and never leaves it; the router only learns its public key. The steps follow TP-Link's WireGuard article for the ER605 v2 in standalone mode ([References](#references)).

1. **The workstation's keys:**

    ```bash
    mkdir -p ~/.config/wireguard && chmod 700 ~/.config/wireguard
    wg genkey | tee ~/.config/wireguard/rl-lab.key | wg pubkey > ~/.config/wireguard/rl-lab.pub
    chmod 600 ~/.config/wireguard/rl-lab.key
    cat ~/.config/wireguard/rl-lab.pub      # the public key, for the router
    ```

2. **The WireGuard server on the ER605:** **VPN → WireGuard → WireGuard**, then **Add**: **Name** `rl-lab`, **MTU** `1420` (the default), **Listen Port** **`51820`** (the default), **Local IP Address** **`10.10.99.1`**; the router generates its own key pair. Save the interface, then use its **Export** to get the router's **public key**.
3. **The workstation as a peer:** **VPN → WireGuard → Peers**, then **Add**: **Interface** `rl-lab`, **Public Key** the workstation's public key from step 1, **Endpoint** and **Endpoint Port** left empty (the router is the server), **Allowed Address** **`10.10.99.2/32`**, and, if the page offers it, a persistent keepalive of **25 seconds**; then save.
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

    **Note:** the `nmcli` manual for NetworkManager 1.46 (Ubuntu 24.04) says `connection import` supports "only VPN configurations", imported by VPN plugins, and its WireGuard settings include no way to add a peer. Whether the import above works is confirmed when this step is first carried out, and this guide is updated with the result. If `nmcli` refuses it, use `wg-quick`, from the `wireguard-tools` package the setup script installs, which reads the same file and names the interface after it (`rl-lab`); it needs the file to stay in place, readable only by the operator:

    ```bash
    sudo wg-quick up ~/.config/wireguard/rl-lab.conf      # when working on the cluster
    sudo wg-quick down ~/.config/wireguard/rl-lab.conf
    ```

6. **Keep a copy in the break-glass kit:** store the profile in Bitwarden ([disaster recovery plan](../disaster-recovery.md#break-glass-kit)), then refresh the kit ([break-glass kit setup guide](break-glass-kit.md#keeping-the-kit-current)). With the NetworkManager import, then delete the files in `~/.config/wireguard/` (NetworkManager keeps its own copy, readable only by root); with `wg-quick`, keep `rl-lab.conf` (mode `600`) and delete only `rl-lab.key` and `rl-lab.pub`, since the profile holds the private key.

## Part 5: Backups and BIOS passwords

1. **Back up the ER605's configuration:** **System Tools → Management → Backup & Restore**, and, in the **Backup** section, **Backup**; the browser saves the file. The break-glass kit reads only text in a vault item, not attachments ([break-glass kit setup guide](break-glass-kit.md#before-starting)), so the file goes into the notes of the router's Bitwarden item as base64 text, which `base64 -d` turns back into the file for a restore. With the CLI unlocked in the project's data folder (`export BW_SESSION="$(bw unlock --raw)"`, run on its own), move the file into memory and add it to the item:

    ```bash
    mv ~/Downloads/<the backup file> /dev/shm/rl-onprem-rt01.cfg
    item_id="$(bw get item '<the router item>' | jq -r .id)"
    bw get item "${item_id}" \
      | jq --arg cfg "$(base64 -w 76 /dev/shm/rl-onprem-rt01.cfg)" --arg date "$(date +%F)" \
        '.notes = ((.notes // "") + "\n\nConfiguration backup " + $date + " (base64):\n" + $cfg)' \
      | bw encode | bw edit item "${item_id}" >/dev/null && echo "Backup added to the item"
    rm /dev/shm/rl-onprem-rt01.cfg
    ```

    Bitwarden refuses a note whose encrypted form is longer than 10,000 characters (about 7,000 characters of text), and `bw edit` then reports the error. In that case, encrypt the file with the kit passphrase instead, as the kit's vault exports are ([break-glass kit setup guide](break-glass-kit.md#part-4-the-encrypted-export-of-the-bitwarden-vault), Part 4, step 3), and store it with them. Repeat after every change, replacing the older backup in the notes, then refresh the kit.
2. **BIOS passwords** on all three nodes: enter each machine's setup (**F1** on the Lenovo ThinkCentre, **F2** on the Dell OptiPlex machines) and set the **administrator (supervisor) password**, from Bitwarden. The other BIOS settings (Secure Boot, the TPM, power-on after a power cut) are part of step 2.2.

## Checks

The test for step 0.3:

- [ ] From the **second computer plugged into the lab switch**: it gets a `10.10.0.1xx` address with DNS servers `1.1.1.1` and `9.9.9.9`, the internet works, and the ISP router at `192.168.1.1` (or any device on the main network) is **unreachable**. The commands for each operating system:
    - **Linux** (systemd-resolved, as on Ubuntu), in a terminal:

        ```bash
        ip -4 address show            # the Ethernet interface: inet 10.10.0.1xx/24
        resolvectl dns                # the Ethernet interface: 1.1.1.1 9.9.9.9
        ping -c 3 1.1.1.1             # replies
        resolvectl query docs.russetleaf.dev
        ping -c 3 192.168.1.1         # 100% packet loss
        ```

    - **macOS:** **Apple menu → System Settings → Network**, the Ethernet connection, then **Details**: **TCP/IP** shows the IP address and **DNS** the DNS servers. Then, in Terminal, `ping -c 3 1.1.1.1` replies, `ping -c 3 192.168.1.1` gets no reply, and `docs.russetleaf.dev` opens in the browser.
    - **Windows,** in PowerShell:

        ```powershell
        ipconfig /all                 # the Ethernet adapter: IPv4 Address 10.10.0.1xx, DNS Servers 1.1.1.1 and 9.9.9.9
        ping 1.1.1.1                  # replies
        Resolve-DnsName docs.russetleaf.dev
        ping 192.168.1.1              # Request timed out
        ```

- [ ] From the **workstation with WireGuard up**: `ping 10.10.0.1` answers, and ordinary internet traffic does not go through the tunnel (`ip route get 1.1.1.1` shows the Wi-Fi interface, not `rl-lab`).
- [ ] With **WireGuard down**: `10.10.0.1` is **not** reachable.
- [ ] From **another device on the main network**: the lab is not reachable.
- [ ] The router has **no port forwards**, **UPnP is off** and **remote management is off**.
- [ ] The break-glass kit has the ER605's admin login, its configuration backup, the WireGuard profile and the three BIOS passwords.

Step 2.2 repeats the isolation checks from a pod inside the cluster.

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- TP-Link (Omada): ["ER605 support page (firmware, release notes, datasheet)"](https://support.omadanetworks.com/us/product/er605/), checked 2026-11-19
- TP-Link: ["ER605 V2 User Guide (REV1.1.0)"](https://static.tp-link.com/upload/manual/2022/202208/20220830/1910013241_ER605(UN)2.0_UG.pdf) (standalone mode: login, status, WAN, LAN, DHCP, address reservation, IP groups, access control, NAT, UPnP, admin setup, controller settings, management, remote assistance), checked 2026-11-19
- TP-Link: ["ER605(UN) V2 2.4.10 release note"](https://support.omadanetworks.com/us/document/136658/) (the release note's PDF: the applied hardware versions and the minimum version for the update), checked 2026-11-19
- TP-Link: ["RE315 AC1200 Mesh Wi-Fi Range Extender"](https://www.tp-link.com/us/home-networking/range-extender/re315/) (one 10/100 Mbps Ethernet port) and ["RE315/RE215 User Guide (REV1.1.0)"](https://static.tp-link.com/upload/manual/2024/202408/20240820/1910013762_RE315_UG_REV1.1.0.pdf) (the Ethernet port in Range Extender mode), checked 2026-11-19
- TP-Link: ["Proxy Mode - Retrieve Virtual MAC Address from the Wi-Fi Range Extender"](https://community.tp-link.com/en/home/kb/detail/412804) (how range extenders rewrite the MAC addresses of the devices behind them), checked 2026-11-20
- Microsoft: ["ipconfig"](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ipconfig), ["ping"](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ping) and ["Resolve-DnsName"](https://learn.microsoft.com/en-us/powershell/module/dnsclient/resolve-dnsname) (the checks from Windows), checked 2026-11-19
- Apple: ["Use DHCP or a manual IP address on Mac"](https://support.apple.com/guide/mac-help/use-dhcp-or-a-manual-ip-address-on-mac-mchlp2718/mac) and ["Change DNS settings on Mac"](https://support.apple.com/guide/mac-help/change-dns-settings-on-mac-mh14127/mac) (the checks from macOS), checked 2026-11-19
- Ubuntu: ["ip-address"](https://manpages.ubuntu.com/manpages/noble/man8/ip-address.8.html), ["resolvectl"](https://manpages.ubuntu.com/manpages/noble/man1/resolvectl.1.html) and ["ping"](https://manpages.ubuntu.com/manpages/noble/man8/ping.8.html) (the checks from Linux), checked 2026-11-19
- TP-Link (Omada): ["How to Find the Hardware Version on Your TP-Link Device"](https://support.omadanetworks.com/us/document/14139/), checked 2026-11-19
- TP-Link (Omada): ["How to Configure WireGuard VPN on Omada Router in Standalone Mode"](https://support.omadanetworks.com/us/document/13120/) (the ER605 v2), checked 2026-11-19
- WireGuard: ["Quick Start"](https://www.wireguard.com/quickstart/), checked 2026-11-12
- NetworkManager: ["nmcli reference manual"](https://networkmanager.dev/docs/api/latest/nmcli.html), checked 2026-11-12
- Ubuntu: ["nmcli - command-line tool for controlling NetworkManager"](https://manpages.ubuntu.com/manpages/noble/man1/nmcli.1.html) (Ubuntu 24.04, NetworkManager 1.46: `connection import` supports only VPN configurations), checked 2026-11-13
- Ubuntu: ["wg-quick - set up a WireGuard interface simply"](https://manpages.ubuntu.com/manpages/noble/man8/wg-quick.8.html) (Ubuntu 24.04), checked 2026-11-13
