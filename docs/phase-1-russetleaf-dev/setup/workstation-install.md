# Setup guide: installing the workstation with full-disk encryption

The step-by-step procedure for installing **Ubuntu 24.04 LTS** on the operator's workstation with **full-disk encryption** ([local workstation setup](../plan.md#local-workstation-setup-ubuntu-2404)): downloading and verifying the installation image, writing it to a USB stick, and the installer's encrypted disk setup. The workstation holds the project's signing key, the YubiKey SSH key handles, cached tokens and the keyring, so its disk is encrypted. Ubuntu cannot encrypt an existing installation in place, so a workstation installed without encryption is installed again. The same procedure replaces a lost workstation ([disaster recovery plan](../disaster-recovery.md)).

**Note:** the steps and labels in this guide are those Ubuntu's documentation and installer showed when the procedure was last carried out. Ubuntu changes its installer and documentation between releases, and its current installation tutorial is written for a newer release (26.04), so a label can differ on 24.04 media. Where the screen differs, follow what it shows and fix this guide to match.

## Before starting

- **Ubuntu 24.04 LTS, not 26.04:** the setup script and its tests are built on 24.04, and 24.04 keeps an X11 desktop session, which 26.04 removed ([decision log](../plan.md#decision-log), 2026-11-24; [improvement I1-11](../improvements.md)).
- **Another device with the project's Bitwarden open** (a phone, or another computer's browser, with a YubiKey), for the passwords needed while the workstation is being installed.
- **Two new Bitwarden items, made before installing:** `Workstation - disk encryption`, holding a passphrase of six or more words from Bitwarden's generator (passphrase type), typed at every startup, before Ubuntu (or its Bitwarden) runs, so it is usually memorized, or read from Bitwarden on another device; Bitwarden is its written copy; and `Workstation - login`, holding the user account's password. Both stay in Bitwarden (and so in the vault exports), not in the break-glass kit.
- **A USB stick of 8 GB or more** whose contents can be erased, written directly with the image (Part 2). It is not the break-glass kit's `RL-KIT` stick, and not a multi-image boot stick such as Ventoy: with Secure Boot on, Ventoy starts only after its own key is enrolled in the firmware (or Secure Boot is turned off), and an enrolled key stays trusted by the firmware after the install, while a stick written directly starts Ubuntu through its Canonical-signed boot loader with no change to the firmware. (Ubuntu's own guide also warns of a Ventoy release that breaks the installation.)
- **A computer running Ubuntu** to download, verify and write the image (the old workstation before it is wiped, or any other Ubuntu computer). On Windows, Ubuntu's documentation uses Rufus ([References](#references)).
- **Both YubiKeys,** for the steps after the install ([workstation YubiKey setup guide](workstation-yubikey.md)).
- **When replacing a workstation:** everything on the old one that exists nowhere else is copied off first, every repository is committed and pushed, and the old disk is wiped by this install.

## Part 1: Download and verify the image

1. **Download** the newest Ubuntu 24.04 desktop image and its checksum files from Ubuntu's releases page for 24.04 ([References](#references)): the `ubuntu-24.04.<n>-desktop-amd64.iso` with the highest number (`ubuntu-24.04.5.1-desktop-amd64.iso` in November 2026, 5.8 GB), `SHA256SUMS` and `SHA256SUMS.gpg`, into one folder.
2. **Verify the checksum file's signature** in a temporary keyring, so Ubuntu's key does not stay in the operator's own:

    ```bash
    export GNUPGHOME="$(mktemp -d -p /dev/shm)"
    gpg --keyid-format long --keyserver hkps://keyserver.ubuntu.com \
      --recv-keys 843938DF228D22F7B3742BC0D94AA3F0EFE21092
    gpg --keyid-format long --verify SHA256SUMS.gpg SHA256SUMS
    ```

    It prints a good signature from `Ubuntu CD Image Automatic Signing Key (2012)` and the primary key fingerprint `8439 38DF 228D 22F7 B374  2BC0 D94A A3F0 EFE2 1092`. A warning that the key is not certified with a trusted signature is expected: the fingerprint is what is checked, against this guide and Ubuntu's verification tutorial.
3. **Verify the image** against the signed checksums, then delete the temporary keyring:

    ```bash
    sha256sum --check --ignore-missing SHA256SUMS
    gpgconf --kill gpg-agent
    rm -rf "${GNUPGHOME}" && unset GNUPGHOME
    ```

    The image is reported `OK`. Any other result means the download is damaged or altered: download it again.

## Part 2: Write the image to the USB stick

On Ubuntu, with **Disks**:

1. Plug in the USB stick, then open **Disks**: press the Super key (the Windows-logo key), type `Disks`, and press **Enter**.
2. Select the **USB stick** in the list on the left. Check its size and model, so the right device is erased, not the disk the computer runs from.
3. Close any window that shows the stick's files.
4. In the window header, select **Drive Options** (⋮), then **Restore Disk Image…**.
5. Next to **Image to Restore**, select the verified image, then **Start Restoring…**, confirm, and enter the user's password.
6. When the progress bar finishes, select **Eject this disk** (⏏) and remove the stick.

## Part 3: Start the installer

1. **Back up:** everything on the workstation's disk is erased in Part 4.
2. **Intel RST:** Ubuntu's installer does not support disks in Intel RST (RAID) mode. Check before installing: `lspci | grep -i -E 'sata|raid'` shows `[RAID mode]` or `RAID bus controller` when it is on. If so, set the firmware's storage mode to **AHCI** (the disk is erased anyway). On a Dell OptiPlex, for example the 9020: press **F2** as the Dell logo appears, then **System Configuration → SATA Operation → AHCI**, apply, and exit ([References](#references)). Keep the firmware in UEFI mode with Secure Boot on.
3. **Start from the USB stick:** plug it in, turn the computer on, and press the boot-menu key while it starts (**F12** on most computers, Dell's included; `Esc`, **F2** or **F10** on some, shown briefly on the start screen), then choose the USB stick under the **UEFI** boot options.
4. Choose **Try or Install Ubuntu** in the boot menu if one appears.

## Part 4: Install with encryption

The installer's screens, in order:

1. **Language,** **accessibility,** **keyboard layout,** and an **internet connection** (wired, or Wi-Fi), so the installer can download updates.
2. **Install Ubuntu** (not **Try Ubuntu**), then the **interactive** installation.
3. **Applications:** the default selection.
4. **Third-party software:** both options, as Ubuntu recommends (graphics and Wi-Fi drivers, and extra media formats).
5. **Disk setup: Erase disk and install Ubuntu.** Before continuing, open the advanced options on this screen (**Advanced features…** on 24.04 media) and choose **Use LVM and encryption**. Do **not** choose hardware-backed (TPM) encryption, which Ubuntu describes as highly experimental on 24.04, or ZFS. Check that the disk shown is the workstation's own disk.
6. **The disk passphrase** (the "security key" on some 24.04 media): paste the passphrase from the `Workstation - disk encryption` item. It is asked for at every startup, before the login screen. Ubuntu warns that the data cannot be recovered without it.
7. **Account:** the user's name, the computer's name, a user name, and the password from the `Workstation - login` item; keep the option that requires the password to log in selected ("Require my password to log in").
8. **Time zone,** then review the summary and select **Install**.
9. **Installation complete:** **Restart Now**, remove the USB stick when asked, and press **Enter**.

## Part 5: First start

1. **Unlock the disk** with the passphrase at the prompt, then sign in.
2. **Apply the updates** that **Software Updater** offers, and restart if it asks.
3. **Set the firmware password and check Secure Boot** ([Part 6](#part-6-firmware-password-and-secure-boot)), before anything else is set up.

## Part 6: Firmware password and Secure Boot

Without a firmware password, anyone at the keyboard can turn Secure Boot off or change the boot settings; with it, the firmware's settings can be viewed but not changed. Secure Boot means only signed boot loaders and kernels start, so a changed boot chain cannot capture the disk passphrase. Both are among the CIS Benchmarks' expectations for an administrator's workstation.

1. **Generate the password** in Bitwarden, on the other device, in a new item named `Workstation - firmware administrator`: **20 lowercase letters and digits**, since firmware setup screens use a limited keyboard layout and reject or mistype some symbols.
2. **Set it:** restart, press **F2** as the Dell logo appears, and in the menu on the left open **Security → Admin Password**. Leave **Enter the old password** empty, type the new password in **Enter the new password** and again in **Confirm new password**, then press **Enter** ([References](#references)). The firmware shows a password once it is set. On other computers, the setting is usually under **Security** or **Passwords**.
3. **Check Secure Boot** in the same setup screens: **Secure Boot → Secure Boot Enable** shows **Enabled** (it needs UEFI boot mode, which Part 3 kept). If it shows **Disabled**, select **Enabled**.
4. **Apply** and **Exit**; the computer restarts and asks for the disk passphrase as before.
5. **Confirm from Ubuntu:**

    ```bash
    mokutil --sb-state           # SecureBoot enabled
    ```

6. **Continue with the [local workstation setup](../plan.md#local-workstation-setup-ubuntu-2404):** the setup script, which also turns on the firewall and sets the screen lock for every user, locked against change (after 10 minutes without activity, as the CIS Benchmarks expect of an administrator's workstation, at most 15); then the [workstation Bitwarden setup guide](workstation-bitwarden.md) and the [workstation YubiKey setup guide](workstation-yubikey.md) (on a replacement workstation, its section on a new machine), and the rest.

## Checks

- [ ] The image's checksum was `OK`, from a checksum file with a good signature from Ubuntu's key, fingerprint `8439 38DF 228D 22F7 B374  2BC0 D94A A3F0 EFE2 1092` (Part 1).
- [ ] The computer asks for the disk passphrase at every start, before the login screen.
- [ ] `lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINTS` shows the main partition as `crypto_LUKS`, with an unlocked `crypt` device holding the system (`/`).
- [ ] Firmware setup (**F2**) asks for the administrator password before a setting can be changed, and the password is in Bitwarden.
- [ ] `mokutil --sb-state` prints `SecureBoot enabled`.
- [ ] After the setup script: `gsettings get org.gnome.desktop.session idle-delay` prints `uint32 600`, `gsettings get org.gnome.desktop.screensaver lock-enabled` prints `true`, and `gsettings writable org.gnome.desktop.session idle-delay` prints `false` (the setting is locked).
- [ ] After the setup script: `sudo ufw status verbose` shows `Status: active` and `Default: deny (incoming), allow (outgoing)`.
- [ ] The new items are in Bitwarden, and the disk passphrase is memorized.

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- Dell: ["OptiPlex 9020 Mini Tower Owner's Manual"](https://dl.dell.com/topicspdf/optiplex-9020-desktop_owners-manual2_en-us.pdf) (System Setup with F2, the one-time boot menu with F12, **SATA Operation**), checked 2026-11-27
- Dell: ["How to set an admin password in the BIOS"](https://www.dell.com/support/kbdoc/en-us/000219905/how-to-set-an-admin-password-in-the-bios) (what the administrator password protects; **Security** or **Passwords**, by model), checked 2026-11-27
- Center for Internet Security: ["CIS Ubuntu Linux 24.04 LTS Benchmark"](https://www.cisecurity.org/benchmark/ubuntu_linux) (the screen-lock, firewall and boot recommendations), checked 2026-11-27
- Ubuntu: ["Ubuntu 24.04 releases"](https://releases.ubuntu.com/24.04/) (the images, `SHA256SUMS` and `SHA256SUMS.gpg`), checked 2026-11-24
- Ubuntu: ["How to verify your Ubuntu download"](https://ubuntu.com/tutorials/how-to-verify-ubuntu) (the signature and checksum checks; its examples use an older release and key), checked 2026-11-24
- Ubuntu: ["Create a bootable USB stick"](https://ubuntu.com/desktop/docs/en/latest/how-to/create-a-bootable-usb-stick/) (Disks, **Restore Disk Image…**; Rufus on Windows), checked 2026-11-24
- Ubuntu: ["Install Ubuntu Desktop"](https://ubuntu.com/desktop/docs/en/latest/tutorial/install-ubuntu-desktop/) (the installer's screens and disk encryption; written for 26.04) and the earlier 24.04 tutorial, ["Install Ubuntu desktop"](https://ubuntu.com/tutorials/install-ubuntu-desktop) (the encryption options on 24.04 media, TPM encryption as experimental, Intel RST, the boot-menu keys), checked 2026-11-24
