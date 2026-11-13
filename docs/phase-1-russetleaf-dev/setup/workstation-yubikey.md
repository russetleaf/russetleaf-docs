# Setup guide: the YubiKeys on the workstation (SSH and sudo)

The step-by-step procedure for using the two YubiKeys on the Ubuntu workstation ([local workstation setup](../plan.md#local-workstation-setup-ubuntu-2404)): **SSH keys held on the YubiKeys** for GitHub and GitLab, and **`sudo` that needs a YubiKey touch as well as the password**. The keys themselves, and the accounts they protect, are covered by the [account sign-in setup guide](account-sign-in.md) and [ADR 1056](../adr/1056-aws-root-mfa-two-security-keys.md).

Both keys are **YubiKey Security Key NFC** (FIDO2 and U2F): **`yubikey-primary`**, carried on the keychain for daily use, and **`yubikey-backup`**, kept in the safe as the backup. Each is registered everywhere below, so losing one never locks the operator out.

## What changes, and what does not

| Use | Before | After |
|---|---|---|
| SSH to GitHub and GitLab (push, pull, `gh`) | `~/.ssh/id_ed25519_github`, a key file with no passphrase | A **security-key SSH key** per YubiKey (`ed25519-sk`); each push or pull needs the key plugged in and a touch. A copied `~/.ssh` folder is useless without the YubiKey. |
| Commit signing | The same key file | Unchanged: `id_ed25519_github` stays the **signing** key, now with a **passphrase** (kept in Bitwarden) and unlocked through `ssh-agent`, because signing every commit with a touch would be impractical ([workstation configuration](../plan.md#4-configuration)) |
| `sudo` and `sudo -i` | Password | **A YubiKey touch, then the password** (`pam_u2f`). The touch is needed again only when `sudo`'s 15-minute timestamp expires. |
| Graphical admin prompts (polkit), the login screen, the disk passphrase | Password | Unchanged |

## Before starting

Have these ready:

- **Both YubiKeys**, each with a FIDO2 PIN (`ykman fido access change-pin`).
- **The setup script run** ([`setup-ubuntu.sh`](https://github.com/russetleaf/russetleaf-docs/blob/main/scripts/workstation/setup-ubuntu.sh)), which installs `libpam-u2f` and `pamu2fcfg`; OpenSSH and `libfido2`, which security-key SSH keys need, come with Ubuntu.
- **Bitwarden open**, for the signing key's passphrase.
- For Part 2, **a second terminal with a root shell** (`sudo -i`), kept open until the checks pass, so a mistake in the PAM files can be undone.

## Part 1: SSH keys on the YubiKeys

1. **Create one SSH key per YubiKey.** With `yubikey-primary` plugged in (touch it when it blinks):

    ```bash
    ssh-keygen -t ed25519-sk -O application=ssh:russetleaf -C "workstation yubikey-primary" -f ~/.ssh/id_ed25519_sk_primary
    ```

    Then swap to `yubikey-backup` and repeat with `-C "workstation yubikey-backup" -f ~/.ssh/id_ed25519_sk_backup`. Press Enter at the passphrase prompts: the files hold only a handle that is useless without its YubiKey.
2. **Register both public keys** (`~/.ssh/id_ed25519_sk_primary.pub` and `~/.ssh/id_ed25519_sk_backup.pub`):
    - **GitHub:** **Settings → SSH and GPG keys → New SSH key**, key type **Authentication key**.
    - **GitLab:** **Preferences → SSH Keys → Add new key**, usage type **Authentication**.
3. **Point SSH at them** in `~/.ssh/config` (create it with `chmod 600`):

    ```text
    Host github.com gitlab.com
        IdentityFile ~/.ssh/id_ed25519_sk_primary
        IdentityFile ~/.ssh/id_ed25519_sk_backup
        IdentitiesOnly yes
    ```

4. **Test:** `ssh -T git@github.com` and `ssh -T git@gitlab.com` each ask for a touch and greet the GitHub or GitLab user.
5. **The commit-signing key is for signing only:** the separate key file from the [workstation setup](../plan.md#4-configuration), `id_ed25519_github`, is never used to sign in.
    1. It has a passphrase, generated in and saved to Bitwarden (to add one: `ssh-keygen -p -f ~/.ssh/id_ed25519_github`).
    2. On **GitHub** it is listed only under **Signing keys**, not **Authentication keys**; on **GitLab**, its usage type is **Signing**.
    3. Commits stay signed as before (`gpg.format ssh`, `user.signingkey` pointing to `id_ed25519_github.pub`); `ssh-add ~/.ssh/id_ed25519_github` unlocks it once per session.
6. **Put `yubikey-backup` back in the safe.**

## Part 2: `sudo` with a YubiKey and the password

The registered keys go in a **root-owned file** (`/etc/u2f_mappings`), not in the home folder, so a program running as the operator cannot add a key of its own. A fixed **origin** (`pam://russetleaf-workstation`) keeps the registration valid if the hostname changes.

1. **Open a root shell in a second terminal** (`sudo -i`) and leave it open until the checks below pass.
2. **Register both keys** (touch each when it blinks):

    ```bash
    origin="pam://russetleaf-workstation"
    first="$(pamu2fcfg -u "${USER}" -o "${origin}" -i "${origin}")"   # yubikey-primary plugged in
    # swap to yubikey-backup
    second="$(pamu2fcfg -n -o "${origin}" -i "${origin}")"            # -n: no user name, appended to the line
    printf '%s%s\n' "${first}" "${second}" | sudo tee /etc/u2f_mappings >/dev/null
    sudo chown root:root /etc/u2f_mappings
    sudo chmod 644 /etc/u2f_mappings
    ```

    The file holds one line, `<user>:<primary-key>:<backup-key>`; it contains public data only.
3. **Require the key for `sudo` and `sudo -i`:** with `sudo vim`, add this line to **both** `/etc/pam.d/sudo` and `/etc/pam.d/sudo-i`, directly **above** `@include common-auth`:

    ```text
    auth       required   pam_u2f.so authfile=/etc/u2f_mappings origin=pam://russetleaf-workstation appid=pam://russetleaf-workstation cue
    ```

    `required` means the touch must succeed and the password (from `common-auth`) is still asked for; `cue` prints "Please touch the device".
4. **Test in a new terminal** (not the root shell): `sudo -k; sudo true` shows the touch prompt, then asks for the password, and succeeds; repeat with `yubikey-backup`; with no YubiKey plugged in, `sudo -k; sudo true` fails even with the right password. Only then close the root shell.
5. **Put `yubikey-backup` back in the safe.**

## Checks

- [ ] `ssh -T git@github.com` and `ssh -T git@gitlab.com` work with each YubiKey and fail with none plugged in.
- [ ] GitHub lists the two `ed25519-sk` keys as **authentication** keys and `id_ed25519_github` only as a **signing** key; a new commit shows **Verified**.
- [ ] `ssh-keygen -y -P "" -f ~/.ssh/id_ed25519_github` fails (the signing key has a passphrase), and the passphrase is in Bitwarden.
- [ ] `sudo -k; sudo true` needs a touch of either key and the password, and fails without a key.
- [ ] `/etc/u2f_mappings` is owned by root and holds both keys.

## If something goes wrong

- **Lost `yubikey-primary`:** on GitHub and GitLab, delete its SSH key (`workstation yubikey-primary`), and delete `~/.ssh/id_ed25519_sk_primary*`; rebuild `/etc/u2f_mappings` with `yubikey-backup` and the replacement (Part 2, step 2); then do the rest of the replacement in the [account sign-in setup guide](account-sign-in.md#if-something-goes-wrong).
- **`sudo` stops working after the PAM change:** in the root shell kept open in Part 2, remove the `pam_u2f.so` line from both files.
- **Both keys lost, or no root shell open:** boot into **recovery mode** (GRUB's **Advanced options**, then the **root** shell; on a default Ubuntu install it needs no root password, but the disk passphrase is still asked for), run `mount -o remount,rw /`, and remove the `pam_u2f.so` line from both files.

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- OpenBSD: ["ssh-keygen(1) manual page (ed25519-sk keys and the FIDO authenticator options)"](https://man.openbsd.org/ssh-keygen), checked 2026-11-12
- OpenSSH: ["OpenSSH 8.2 release notes (FIDO/U2F support)"](https://www.openssh.org/txt/release-8.2), checked 2026-11-12
- Yubico: ["Securing SSH with FIDO2"](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html), checked 2026-11-12
- Yubico: ["pam-u2f"](https://developers.yubico.com/pam-u2f/), checked 2026-11-12
- Yubico: ["FIDO Commands (YubiKey Manager CLI)"](https://docs.yubico.com/software/yubikey/tools/ykman/FIDO_Commands.html), checked 2026-11-12
- GitHub: ["Adding a new SSH key to your GitHub account"](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account), checked 2026-11-12
- GitLab: ["Use SSH keys with GitLab"](https://docs.gitlab.com/user/ssh/), checked 2026-11-12
