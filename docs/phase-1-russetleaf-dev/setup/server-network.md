# Setup guide: the server network and WireGuard

The step-by-step procedure for the server network: the **TP-Link ER605 (v2)** router (`rl-onprem-rt01`) that separates the cluster from the main network, and the **WireGuard** tunnel the workstation uses to reach it (Phase 1 [step 0.3](../plan.md#step-03-network-segmentation)). The reasoning is in [ADR 1040](../adr/1040-server-network-and-wireguard.md), and the addresses and hardware in the Phase 1 design's [On-premises hardware](../design.md#on-premises-hardware).

```text
Workstation (Wi-Fi, 192.168.1.x) ──WireGuard──┐
                                              ▼
ISP router ── powerline ── ER605 WAN (192.168.1.y) │ ER605 LAN (10.10.0.1) ── switch ── the three nodes
```

**Note:** the click paths in this guide are those the router's web interface showed when the procedure was last carried out. Firmware updates change the interface without notice, and TP-Link's documentation can lag behind the interface. Before following a path, check TP-Link's current documentation for the ER605 (v2); where the screen still differs, follow what it shows and fix this guide to match. TP-Link's ER605 V2 user guide dates from 2022 and does not match firmware 2.4.x: where TP-Link's newer articles cover a page, the steps follow them, and the rest are confirmed against the screen when first carried out.

## Before starting

- A **wired link to the ISP router** that carries the ER605's own MAC address (Part 2, step 2): here **two TP-Link TL-PA4010 powerline adapters** (AV600), or an Ethernet cable.
- The **ER605 (v2)**, the **TL-SG105** switch (`rl-onprem-sw01`), and network cables. WireGuard needs hardware version **V2**: the label underneath gives the region code and hardware version together (for example `UN/2.36`, which is ER605(UN) v2.36), where **2.x** means V2, and Part 1 confirms it on the router's **System Status** page.
- The **latest V2 firmware** from the ER605's download page ([References](#references)), with its release note, downloaded **on the second computer** (below): the firmware is uploaded from that computer's browser, because the workstation reaches the router only over WireGuard, which Part 4 sets up. One V2 firmware serves every 2.x hardware version: check that the release note's **Applied Model** list includes the one on the label. The release note also gives a **minimum version for the update** (**Minimum FW Version for Update**): a router on an older version installs that version first. For 2.4.10 Build 20260916 the minimum is 2.3.2 Build 20251029. The download is a `.zip` archive; Part 1 extracts the firmware file from it.
- The **workstation**, with `wireguard-tools` installed (the [workstation setup script](../plan.md#1-run-the-setup-script) installs it), and **Bitwarden** (the project's password manager) open.
- A **second computer with an Ethernet port** and a web browser, on any operating system (Linux, macOS or Windows), for the first login and firmware update (Part 1) and the checks at the end. It needs none of the project's credentials or keys. The workstation stays on the main network's Wi-Fi throughout.
- The **MAC addresses** of the three nodes' network ports, for the address reservations. They need not be known in advance: once the nodes are on the switch, the ER605 lists each one that asks it for an address (Part 2, step 4). A node with no operating system asks only while it tries to start from the network; otherwise its BIOS setup shows the MAC address.
- Access to the **ISP router's** settings, to reserve the ER605's WAN address: its web page or its provider's app (for the Spectrum SAX1V1K used here, the **My Spectrum** app).

## Part 1: Wiring, first login and firmware

The ER605's web interface is used in **standalone mode** throughout: no Omada controller.

1. **The powerline link** (from TP-Link's user guide for the TL-PA4010; skip with a cable):
    1. **Pair the adapters** in one room, each plugged directly into a wall outlet (not a power strip, extension cord or surge protector): press **Pair** on one for 1 second (its **Power** LED, the power symbol, blinks), and within two minutes on the other. Pairing is complete when the **Powerline** LED (the house icon) is on. Pairing encrypts the link, so other powerline adapters on the wiring cannot join it. Holding **Pair** for more than 6 seconds resets an adapter.
    2. **Place them:** one in a wall outlet near the ISP router, cabled to a **LAN** port on it; the other in a wall outlet in the server room. The **Powerline** LED on: a good signal; blinking: a weak signal, so try another outlet; off: no link.
2. **Wire it:** the ER605's **WAN** port to the server-room powerline adapter, one of its **LAN** ports to the switch, and the three nodes to the switch. The port labels show which ports are WAN and which are LAN.
3. **First login:** connect the second computer by cable to a spare LAN port of the ER605, with its wired connection set to get an address automatically, and open `http://192.168.0.1`. Create the **username and password** the page asks for, generated in Bitwarden and saved in a new item for the router, then log in with them.
4. **Check the firmware:** **Status → System Status → System Status** shows the hardware and firmware versions. If the firmware is older than the release note's minimum, install that version first, as in steps 5 and 6.
5. **Extract the firmware file:** the router accepts only the firmware file itself, not the `.zip` archive it was downloaded in. Extract the archive with the operating system's archive tool, and use the firmware file from the extracted folder.
6. **Update the firmware:** **System Tools → Management → Firmware Upgrade**, select the extracted firmware file, and **Upgrade**. The router restarts; log in again and check the new version on the **System Status** page.

## Part 2: WAN, LAN and addresses

1. **WAN:** **Network → WAN → WAN**. In the **Connection Configuration** section, the **Connection Type** stays **Dynamic IP** (from the ISP router); enter the **Host Name** `rl-onprem-rt01` ([ADR 1041](../adr/1041-naming-convention.md)), which the ISP router then shows for this device, and **Save**. The WAN address the router gets is shown on **Status → System Status → System Status**: it is the WireGuard endpoint. Leave **Network → WAN → WAN Mode** as it is: changing the number of WAN ports can lose the configuration.
2. **Keep that address fixed:** in the ISP router's settings, reserve the address the ISP router gave the ER605 (it appears under its host name, `rl-onprem-rt01`). For the Spectrum SAX1V1K, which is managed only through the **My Spectrum** app (its own web page shows only a link to the app): the **Services** tab, **Manage network**, the router, **Advanced Settings**, **Port Forwarding & IP Reservations**; under **Create IP Reservation**, the ER605's entry, with **Reserve IP Address** on. Add no port forward. Restart the ER605 afterwards (unplug it for ten seconds) and check on the **System Status** page that its WAN address has not changed. If the ISP router cannot reserve addresses, give the ER605 a **static WAN address** instead (**Connection Type** **Static IP**), outside the ISP router's DHCP range, with the ISP router, `192.168.1.1`, as gateway.

    **The link to the ISP router must carry the ER605's own MAC address:** an Ethernet cable, or a bridge that acts like one (a pair of powerline or MoCA adapters). A **Wi-Fi range extender** between them does not: TP-Link's range extenders, for example, replace the MAC address of each wired device behind them with a virtual one, or with the extender's own ([References](#references)), so the ISP router cannot tell the ER605 apart and neither a reservation nor a safely chosen static address is possible. With an ISP router managed only through an app, whose DHCP range is not shown, a reservation is the only safe choice.
3. **The LAN and its DHCP server:** **Network → LAN → LAN** lists the LAN networks; the router starts with one, at `192.168.0.1`. Edit that entry with the pencil icon in its **Operation** column (do not **Add** a second network), set the fields below, and **Save**:

    | Field | Value |
    |---|---|
    | **IP Address** | **`10.10.0.1`**, subnet mask `255.255.255.0` |
    | **"Vlan"** (as the page spells it) | Unchanged |
    | DHCP | **DHCP** (selected by default: the router is the network's DHCP server) |
    | **IP Address Range** | **`10.10.0.100`** to **`10.10.0.199`** |
    | **Lease Time** | Unchanged |
    | **Default Gateway** | `10.10.0.1` |
    | **Primary DNS** / **Secondary DNS** | **`1.1.1.1`** / **`9.9.9.9`** |
    | **Advanced Settings** | Unchanged |

    The router moves to the new address, so the browser loses the page: unplug the second computer's cable from the ER605 and plug it back in, so it gets an address in the new range, then log in at `http://10.10.0.1`. The DNS servers are public ones, not the ISP router: the firewall rule in Part 3 blocks the main network, which would break DNS for anything using `192.168.1.1`.
4. **Address reservations:** once the nodes are on the switch and have asked for an address (a node with no operating system asks only when it starts something from the network or from a USB stick; at the latest, when it first starts the Talos installer in step 2.2), the router's **DHCP Client List** shows each one with its MAC address; select **Reserve** on a node's entry to reserve the address it has, or go to **Network → LAN → Address Reservation**, select **Add**, and enter the node's MAC address, the IP address below and the hostname as its description ([ADR 1041](../adr/1041-naming-convention.md)), then **OK**. Edit an entry reserved from the client list to give it the address below.

    | Description | IP Address |
    |---|---|
    | `rl-onprem-cp01` | `10.10.0.11` |
    | `rl-onprem-cp02` | `10.10.0.12` |
    | `rl-onprem-cp03` | `10.10.0.13` |

    Leave **`10.10.0.10` unused**: it is the cluster's virtual IP. The reserved addresses are outside the DHCP range, which TP-Link allows as long as they are in the network's subnet. A node picks up its reserved address when it next renews its lease: unplug and reconnect its cable. Talos also sets these addresses statically in step 2.2.

5. **Label the case** with the router's name, `rl-onprem-rt01`.

## Part 3: The firewall and remote access

1. **The two networks as IP groups:** a rule in the **LAN->WAN** direction names its source and destination by IP groups, not by LAN networks (the **Network** type is offered only for **LAN->LAN** rules). **Preferences → IP Group → IP Address**, then **Add**, twice, each with **OK**: `main_net`, the network `192.168.1.0` with mask `24` (the form takes the prefix length); and `server_net`, `10.10.0.0` with mask `24`. Then, on the **IP Group** tab of the same page, **Add**, twice, each with **OK**: `main`, with the address `main_net`; and `servers`, with `server_net`.

    **Names on the router** take only letters, digits and underscores, for IP groups, access-control rules and the WireGuard interface alike: the router refuses hyphens.
2. **Block the server network from the main network:** **Firewall → Access Control**, then **Add**:

    | Field | Value |
    |---|---|
    | Name | `servers_to_main_deny` |
    | **Policy** | **BLOCK** |
    | **IP Type** | IPv4 |
    | **Protocols** | **ALL** (the default) |
    | **Direction** | **LAN->WAN** (the main network is on the ER605's WAN side) |
    | Source **Type** | **IP Group**: `servers` |
    | Destination **Type** | **IP Group**: `main` |
    | **Effective Time** | Any |
    | **States** | **New**, **Established**, **Related** and **Invalid**, all selected (the default) |

    Then **OK**. The router allows whatever no rule blocks, so this one rule is enough: the server network can still reach the internet, and nothing from the main network can start a connection into it, because the ER605's NAT drops it.
3. **Nothing comes in:** check each of these; on firmware 2.4.10 all were already in this state, so nothing needed changing. Change only a setting that differs.
    - **Transmission → NAT → Virtual Servers** lists **no** entries (no port forwards); check **One-to-One NAT** and **NAT-DMZ** under **Transmission → NAT** too.
    - **Service → UPnP**: **Enable UPnP** cleared, and **Save**, so no device on the server network can open its own port forward.
    - **System Tools → Admin Setup → Remote Management** lists **no** entries, so the web interface cannot be reached from the WAN side.
    - **System Tools → Controller Settings**: **Cloud-Based Controller Management** off.
    - **System Tools → Diagnostics → Remote Assistance**: the box cleared, so TP-Link's technicians cannot reach the router by SSH.

    The Cloudflare Tunnel is outbound-only, so nothing needs to come in. These paths, from the 2022 user guide, match firmware 2.4.10.
4. **HTTPS for the web interface:** **System Tools → Admin Setup → System Settings**: **HTTPS Server Status** and **Redirect HTTP to HTTPS** checked (both already on with firmware 2.4.10; otherwise check them and **Save**). The router's certificate is self-signed, so the browser warns on the first visit; from then on, the admin password is not sent in the clear.

## Part 4: WireGuard for the workstation

The workstation's private key is generated on the workstation and never leaves it; the router only learns its public key. TP-Link's WireGuard articles ([References](#references)) describe the older **VPN → WireGuard** menu and the newer **VPN → VPN Server**; the steps below use **VPN → Site-to-Site VPN**, as confirmed on firmware 2.4.10, because it is the form that takes the workstation's public key.

1. **The workstation's keys:**

    ```bash
    mkdir -p ~/.config/wireguard && chmod 700 ~/.config/wireguard
    wg genkey | tee ~/.config/wireguard/rl-mgmt.key | wg pubkey > ~/.config/wireguard/rl-mgmt.pub
    chmod 600 ~/.config/wireguard/rl-mgmt.key
    cat ~/.config/wireguard/rl-mgmt.pub      # the public key, for the router
    ```

2. **The tunnel on the ER605:** **VPN → Site-to-Site VPN**, then **Add**, with **WireGuard** as the type. Firmware 2.4.x has no separate WireGuard menu: its **VPN → VPN Server** also offers WireGuard, but generates each client's key pair on the router (the client's **Public Key** cannot be entered, in either **Authorization** mode), so the client's private key would be stored on the router and exported in a file. A site-to-site tunnel takes the other side's public key instead, and the workstation is that other side. The tunnel:

    | Field | Value |
    |---|---|
    | **Name** | `rl_mgmt` (the router's name; the workstation's side is `rl-mgmt`) |
    | **Status** | Enabled |
    | **Interface** | **WAN1** |
    | Port | `51820` (the default) |
    | **Local IP Address** | `10.10.99.1` (the router's address in the tunnel) |
    | **Private Key** / **Public Key** | Unchanged: the router generates its own pair; the **Public Key** goes into the workstation's profile (step 4) |

3. **The workstation as the peer,** in the same form's peer section:

    | Field | Value |
    |---|---|
    | **Name** | `workstation` |
    | **Public Key** | The workstation's public key from step 1. It is not secret, so copy it to the second computer by any convenient means and paste it: typing 44 characters can outlast the router's **Web Idle Timeout** (on **System Tools → Admin Setup → System Settings**) |
    | **Endpoint** / **Endpoint Port** | Empty: the workstation connects to the router, not the other way round |
    | **Allowed Address** | `10.10.99.2/32` (the workstation's address in the tunnel, and nothing else) |
    | **Preshared Key** | Empty: a preshared key would have to be typed into the router from the second computer, spreading a second secret |
    | **Persistent Keepalive** | Empty: the workstation's profile keeps the tunnel alive |
    | **Status** | Enabled |

    Save the peer, then the tunnel.
4. **The client profile:** on the workstation, write `~/.config/wireguard/rl-mgmt.conf` (mode `600`). It is a **split tunnel**: only the server network's traffic goes through it, so there is no `DNS` line and `AllowedIPs` lists only the server subnet.

    Write it with the private key read from its file, so the key is never shown or typed; the router's public key is copied from the tunnel's **Public Key** field on the ER605 (it is not secret):

    ```bash
    router_public_key='<the ER605 tunnel public key>'
    wan_address='<the ER605 WAN address>'
    (
      umask 077
      cat > ~/.config/wireguard/rl-mgmt.conf <<EOF
    [Interface]
    PrivateKey = $(cat ~/.config/wireguard/rl-mgmt.key)
    Address = 10.10.99.2/24

    [Peer]
    PublicKey = ${router_public_key}
    Endpoint = ${wan_address}:51820
    AllowedIPs = 10.10.0.0/24
    PersistentKeepalive = 25
    EOF
    )
    grep -v PrivateKey ~/.config/wireguard/rl-mgmt.conf   # check everything but the key
    ```

5. **Import it into NetworkManager,** and keep it off until needed:

    ```bash
    nmcli connection import type wireguard file ~/.config/wireguard/rl-mgmt.conf
    nmcli connection modify rl-mgmt connection.autoconnect no
    nmcli connection up rl-mgmt        # when working on the cluster
    nmcli connection down rl-mgmt
    ```

    Then test it: with the tunnel up, `ping -c 3 10.10.0.1` answers and `ip route get 1.1.1.1` shows the Wi-Fi interface, not `rl-mgmt` (a split tunnel); with it down, `ping -c 3 10.10.0.1` gets no reply. The import works on Ubuntu 24.04 (NetworkManager 1.46; confirmed 2026-11-22), although the `nmcli` manual describes `connection import` only for VPN plugins.

6. **Delete the key files; keep no copy of the private key:** NetworkManager keeps its own copy of the profile, readable only by root, so delete the files in `~/.config/wireguard/` (`rm ~/.config/wireguard/rl-mgmt.*`). The private key is not stored in Bitwarden or the break-glass kit: after a lost or rebuilt workstation, a new key pair is generated (step 1) and the peer's **Public Key** on the ER605 is replaced (step 3), signing in to the ER605 from a computer on the server network with the admin login from the kit. Secrets that can be regenerated are regenerated rather than copied ([ADR 1018](../adr/1018-disaster-recovery.md)).

## Part 5: Backups and BIOS passwords

1. **Back up the ER605's configuration:** with the tunnel up (Part 4), open `https://10.10.0.1` on the workstation, go to **System Tools → Management → Backup & Restore**, choose **Export unencrypted configuration file** in the **Backup** section, and download it. The router's own encryption is not used: it adds a password that would be stored beside the file anyway, and a backup that cannot be decrypted at restore time is worthless; the file is encrypted with the kit passphrase instead. The file (about 250 KB with firmware 2.4.10) is too large for a Bitwarden note, so it is kept **next to the vault exports**, in the same places and with the same encryption ([break-glass kit setup guide](break-glass-kit.md#part-4-the-encrypted-export-of-the-bitwarden-vault)):
    1. **Encrypt it in memory** and prove the encrypted copy, removing the download from the disk:

        ```bash
        rl_tmp="$(mktemp -d -p /dev/shm rl-router.XXXX)"
        cfg="${rl_tmp}/rl-onprem-rt01-config-$(date +%F).bin"
        cp ~/Downloads/'<the downloaded file>' "${cfg}"
        shred -u ~/Downloads/'<the downloaded file>'
        gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-count 65011712 \
          --output "${cfg}.gpg" "${cfg}"
        gpgconf --reload gpg-agent
        gpg --decrypt "${cfg}.gpg" | cmp - "${cfg}" && echo "Encrypted copy verified"
        rm "${cfg}"
        ```

        On an SSD, `shred` cannot guarantee that the old blocks are overwritten; full-disk encryption on the workstation covers what remains.
    2. **Store it** like the exports: upload `rl-onprem-rt01-config-<date>.bin.gpg` from `${rl_tmp}` to the kit folders on Google Drive and OneDrive and check the uploaded copies ([break-glass kit setup guide](break-glass-kit.md#part-3-the-encrypted-copy-in-google-drive-and-onedrive), Part 3, step 4); then copy it to the USB stick, check the copy and unmount the stick (Part 4, step 5), and return it to the safe.
    3. **Point to it from the router's Bitwarden item,** so the vault says where the backup is: with the CLI unlocked in the project's data folder (`export BW_SESSION="$(bw unlock --raw)"`, run on its own),

        ```bash
        bw sync      # the CLI's copy of the vault does not include items added since its last sync
        item_id="$(bw get item '<the router item>' | jq -r .id)"
        bw get item "${item_id}" \
          | jq --arg f "$(basename "${cfg}").gpg" \
            '.notes = ((.notes // "") + "\n\nConfiguration backup: " + $f + " (encrypted with the kit passphrase), in the kit folders on Google Drive and OneDrive and on the RL-KIT USB stick.")' \
          | bw encode | bw edit item "${item_id}" >/dev/null && echo "Note added"
        bw lock && unset BW_SESSION
        rm -rf "${rl_tmp}"
        ```

    Repeat after every configuration change, replacing the older backup in all three places (deleting the old cloud copies from the trash too: [break-glass kit setup guide](break-glass-kit.md#keeping-the-kit-current), **Replacing a cloud copy**) and its note. To restore: decrypt the file with the kit passphrase (`gpg --output /dev/shm/rl-onprem-rt01.bin --decrypt <file>`), and import it on the same page of the ER605.
2. **BIOS administrator passwords** on all three nodes, so the firmware settings cannot be changed without one. Generate each in Bitwarden as **20 lowercase letters and digits**, the one format all three accept (the OptiPlex 3040's BIOS takes only lowercase letters, digits and a few symbols, up to 32 characters; the OptiPlex 5060's takes 4 to 32; the ThinkCentre's is not case sensitive), and save it in an item per node (`BIOS rl-onprem-cp01` and so on) before entering it. The other BIOS settings (Secure Boot, the TPM, power-on after a power cut) are part of step 2.2.

    | Node | Open setup | Set the password | Save and exit |
    |---|---|---|---|
    | `rl-onprem-cp01` (ThinkCentre M710q) | Repeatedly press **F1** while it starts | **Security** → **Set Administrator Password**, then follow the instructions on the right of the screen | **F10**, then **Yes** |
    | `rl-onprem-cp02` (OptiPlex 3040 Micro) | Press **F2** as soon as the Dell logo appears | **Security** → **Admin Password**: **Enter the new password**, then **Confirm new password** | **Exit** |
    | `rl-onprem-cp03` (OptiPlex 5060 Micro) | Press **F2** as soon as the Dell logo appears | **Security** → **Admin Password**: **Enter the new password**, then **Confirm new password** | **Exit** |

    Open setup again on each node afterwards: it now asks for the password. Lenovo's procedure comes from the guide for the same generation of Tiny models (the M700 and M900), since the M710q's own guides have no setup chapter; Dell's from each model's manual. Leave **Admin Setup Lockout** (Dell) off: with it on, setup cannot be opened at all while the password is set.

## Checks

The test for step 0.3:

- [ ] From the **second computer plugged into the switch**: it gets a `10.10.0.1xx` address with DNS servers `1.1.1.1` and `9.9.9.9`, the internet works, and the ISP router at `192.168.1.1` (or any device on the main network) is **unreachable**. The commands for each operating system:
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

- [ ] From the **workstation with WireGuard up**: `ping 10.10.0.1` answers, and ordinary internet traffic does not go through the tunnel (`ip route get 1.1.1.1` shows the Wi-Fi interface, not `rl-mgmt`).
- [ ] With **WireGuard down**: `10.10.0.1` is **not** reachable.
- [ ] From **another device on the main network**: the server network is not reachable.
- [ ] The router has **no port forwards**, **UPnP is off** and **remote management is off**.
- [ ] Bitwarden has the ER605's admin login (with a note pointing to the configuration backup) and the three BIOS passwords, and the encrypted configuration backup is in the kit folders on Google Drive and OneDrive and on the USB stick; no copy of the workstation's WireGuard private key exists outside NetworkManager.

Step 2.2 repeats the isolation checks from a pod inside the cluster.

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- TP-Link (Omada): ["ER605 support page (firmware, release notes, datasheet)"](https://support.omadanetworks.com/us/product/er605/), checked 2026-11-19
- TP-Link: ["ER605 V2 User Guide (REV1.1.0)"](https://static.tp-link.com/upload/manual/2022/202208/20220830/1910013241_ER605(UN)2.0_UG.pdf) (standalone mode: login, status, WAN, LAN, DHCP, address reservation, IP groups, access control, NAT, UPnP, admin setup, controller settings, management, remote assistance), checked 2026-11-19
- TP-Link: ["ER605(UN) V2 2.4.10 release note"](https://support.omadanetworks.com/us/document/136658/) (the release note's PDF: the applied hardware versions and the minimum version for the update), checked 2026-11-19
- TP-Link: ["AV600 Powerline Starter Kit TL-PA4010 KIT"](https://www.tp-link.com/us/home-networking/powerline/tl-pa4010-kit/) (one 10/100 Mbps Ethernet port per adapter) and ["AV600 Powerline Adapter TL-PA4010 / TL-PA411 User Guide (REV3.0.0)"](https://www.tp-link.com/us/document/68994/) (the LEDs, pairing, placement), checked 2026-11-21
- TP-Link: ["RE315 AC1200 Mesh Wi-Fi Range Extender"](https://www.tp-link.com/us/home-networking/range-extender/re315/) (an example of a range extender) and ["RE315/RE215 User Guide (REV1.1.0)"](https://static.tp-link.com/upload/manual/2024/202408/20240820/1910013762_RE315_UG_REV1.1.0.pdf) (the Ethernet port in Range Extender mode), checked 2026-11-19
- TP-Link: ["Proxy Mode - Retrieve Virtual MAC Address from the Wi-Fi Range Extender"](https://community.tp-link.com/en/home/kb/detail/412804) (how range extenders rewrite the MAC addresses of the devices behind them), checked 2026-11-20
- Microsoft: ["ipconfig"](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ipconfig), ["ping"](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ping) and ["Resolve-DnsName"](https://learn.microsoft.com/en-us/powershell/module/dnsclient/resolve-dnsname) (the checks from Windows), checked 2026-11-19
- Apple: ["Use DHCP or a manual IP address on Mac"](https://support.apple.com/guide/mac-help/use-dhcp-or-a-manual-ip-address-on-mac-mchlp2718/mac) and ["Change DNS settings on Mac"](https://support.apple.com/guide/mac-help/change-dns-settings-on-mac-mh14127/mac) (the checks from macOS), checked 2026-11-19
- Ubuntu: ["ip-address"](https://manpages.ubuntu.com/manpages/noble/man8/ip-address.8.html), ["resolvectl"](https://manpages.ubuntu.com/manpages/noble/man1/resolvectl.1.html) and ["ping"](https://manpages.ubuntu.com/manpages/noble/man8/ping.8.html) (the checks from Linux), checked 2026-11-19
- TP-Link (Omada): ["How to Find the Hardware Version on Your TP-Link Device"](https://support.omadanetworks.com/us/document/14139/), checked 2026-11-19
- TP-Link Community: ["ER605/How to block a device from internet access?"](https://community.tp-link.com/en/business/forum/topic/586812) (a **LAN->WAN** rule with IP groups as source and destination; TP-Link's article does not say which source types each direction offers, and the router offers **Network** only for **LAN->LAN**), checked 2026-11-20
- Dell: ["OptiPlex 3040M Owner's Manual"](https://downloads.dell.com/topicspdf/optiplex-3040m-desktop_owners-manual2_en-us.pdf) (System Setup, the system and setup passwords and their allowed characters) and ["OptiPlex 5060 Micro Setup and specifications guide"](https://downloads.dell.com/topicspdf/optiplex-5060-desktop_Specifications3_en-us.pdf) (System setup: Security, **Admin Password**, password length), checked 2026-11-20
- Lenovo: ["ThinkCentre M700 and M900 User Guide"](https://download.lenovo.com/pccbbs/thinkcentre_pdf/m700_m900_tiny_ug_en.pdf) (the Setup Utility: starting it, BIOS passwords, exiting), checked 2026-11-20
- TP-Link (Omada): ["Omada Gateway Access Control Configuration Examples"](https://support.omadanetworks.com/en/document/13189/) (standalone mode: IP groups and access-control rules), checked 2026-11-20
- TP-Link (Omada): ["How to Configure DHCP Server on Omada Gateway"](https://support.omadanetworks.com/us/document/13196/) (standalone mode: the LAN network's fields) and ["How to Configure DHCP Address Reservation on Omada Gateway in Standalone Mode"](https://support.omadanetworks.com/us/document/13294/) (address reservations, the DHCP client list), checked 2026-11-20
- TP-Link (Omada): ["How to Configure WireGuard VPN on Omada Gateway"](https://support.omadanetworks.com/us/document/13314/) (standalone mode: **VPN → VPN Server** for clients, with **Authorization** **Auto** or **Manual**, and **VPN → Site-to-Site VPN**, whose peer takes the other side's public key), checked 2026-11-22
- TP-Link (Omada): ["How to Configure WireGuard VPN on Omada Router in Standalone Mode"](https://support.omadanetworks.com/us/document/13120/) (the ER605 v2), checked 2026-11-19
- WireGuard: ["Quick Start"](https://www.wireguard.com/quickstart/), checked 2026-11-12
- NetworkManager: ["nmcli reference manual"](https://networkmanager.dev/docs/api/latest/nmcli.html), checked 2026-11-12
- Ubuntu: ["nmcli - command-line tool for controlling NetworkManager"](https://manpages.ubuntu.com/manpages/noble/man1/nmcli.1.html) (Ubuntu 24.04, NetworkManager 1.46: `connection import`), checked 2026-11-22
