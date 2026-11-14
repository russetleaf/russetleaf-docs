# Setup guide: the YubiKeys on the workstation (SSH and sudo)

The step-by-step procedure for using the two YubiKeys on the Ubuntu workstation ([local workstation setup](../plan.md#local-workstation-setup-ubuntu-2404)): **SSH keys held on the YubiKeys** for GitHub and GitLab, and **`sudo` that needs a YubiKey touch as well as the password**. The keys themselves, and the accounts they protect, are covered by the [account sign-in setup guide](account-sign-in.md) and [ADR 1056](../adr/1056-aws-root-mfa-two-security-keys.md).

Both keys are **YubiKey Security Key NFC** (FIDO2 and U2F): **`yubikey-primary`**, carried on the keychain for daily use, and **`yubikey-backup`**, kept in the safe as the backup. Each is registered everywhere below, so losing one never locks the operator out.

## What each key protects

| Use | How it is protected |
|---|---|
| SSH to GitHub and GitLab (push, pull, `gh`) | A **security-key SSH key** per YubiKey (`ed25519-sk`): a new connection needs the key plugged in and a touch, and is reused for 10 minutes of activity, so a copied `~/.ssh` folder is useless without the YubiKey. Day-to-day work uses only GitHub; the keys are registered on GitLab too so that, if GitHub is lost, the repos can be restored from their GitLab mirrors, or work can continue there, at once ([disaster recovery plan](../disaster-recovery.md)), and the yearly renewal proves it |
| Commit signing | A separate key file, `~/.ssh/id_ed25519_signing`, used with the project's Git identity (the Workspace address) in RussetLeaf repos only, with a **passphrase** (kept in Bitwarden) and unlocked once per session through `ssh-agent`, registered only as a **signing** key, on GitHub and on GitLab, with no expiry date. A YubiKey could hold it, but this model (FIDO2 only, with no cached-touch setting) would ask for a touch on every commit, and again for every commit a rebase rewrites; the passphrase protects the file instead (Part 1, step 5) |
| `sudo` and `sudo -i` | **A YubiKey touch, then the password** (`pam_u2f`); the touch is needed again only when `sudo`'s 15-minute timestamp expires |
| Graphical admin prompts (polkit), the login screen, the disk passphrase | The password only |

## Before starting

Have these ready:

- **Both YubiKeys**, each with a FIDO2 PIN (`ykman fido access change-pin`).
- **The setup script run** ([`setup-ubuntu.sh`](https://github.com/russetleaf/russetleaf-docs/blob/main/scripts/workstation/setup-ubuntu.sh)), which installs `libpam-u2f` and `pamu2fcfg`; OpenSSH and `libfido2`, which security-key SSH keys need, come with Ubuntu.
- **Bitwarden open**, for the signing key's passphrase.
- For Part 2, **a second terminal with a root shell** (`sudo -i`), kept open until the checks pass, so a mistake in the PAM files can be undone.

## Part 1: SSH keys on the YubiKeys

1. **Create one SSH key per YubiKey,** with the current year in the file name and the comment, so each yearly generation ([Renewing the keys every year](#renewing-the-keys-every-year)) has its own names. Each command is complete on one line (`$(date +%Y)` fills in the year), so it can be copied on its own. Plug in `yubikey-primary` only, and touch it when it blinks:

    ```bash
    ssh-keygen -t ed25519-sk -O application=ssh:russetleaf -C "workstation yubikey-primary $(date +%Y)" -f ~/.ssh/id_ed25519_sk_primary_"$(date +%Y)"
    ```

    Then swap to `yubikey-backup`:

    ```bash
    ssh-keygen -t ed25519-sk -O application=ssh:russetleaf -C "workstation yubikey-backup $(date +%Y)" -f ~/.ssh/id_ed25519_sk_backup_"$(date +%Y)"
    ```

    `ssh-keygen` asks for a touch but not for the FIDO2 PIN: a key that is not resident (no `-O resident`) and not created with `-O verify-required` needs only proof that someone is present at the YubiKey, both to create it and to use it. Press Enter at the passphrase prompts: the files hold only a handle that is useless without its YubiKey. (A key that does not support Ed25519 fails with `invalid format` or `feature not supported`; the Security Key NFC supports it.)
2. **Register both public keys** on GitHub and on GitLab, each with its comment as the title (for example `workstation yubikey-primary 2026` and `workstation yubikey-backup 2026`). Print a key with `cat ~/.ssh/id_ed25519_sk_primary_<year>.pub`, triple-click the line to select all of it, and copy the whole line: the key type `sk-ssh-ed25519@openssh.com` (an OpenSSH type name, not an email address), the key itself, and the comment, separated by spaces.
    - **GitHub:** profile picture → **Settings** → in the **Access** section of the sidebar, **SSH and GPG keys** → **New SSH key**. Fill in the **Title**, choose the key type for **authentication** (GitHub offers authentication or signing), paste the line into **Key**, select **Add SSH key**. GitHub asks for a YubiKey before the first key is added (its **sudo mode**) and not again for the second while the session stays in sudo mode.
    - **GitLab:** avatar → **Edit profile** → in the left sidebar, **Access → SSH keys** → **Add new key**. Paste the line into **Key**, fill in the **Title**, set **Usage type** to **Authentication** (the default is **Authentication & Signing**), keep the default **Expiration date** (one year from the day the key is added), and select **Add key**. The date is optional on GitLab.com; it is kept so that the [yearly renewal](#renewing-the-keys-every-year) happens, which also proves that the YubiKeys and a restore from GitLab still work. Record the date in Bitwarden: open the GitLab login item, select **Edit**, and under **Custom fields** select **New custom field**, with the type **Text**, the **Name** `SSH keys expire (workstation)` and the date as the **Value**; then **Save**. GitLab emails a warning seven days before the date; renew the keys before it ([Renewing the keys every year](#renewing-the-keys-every-year)).
3. **Point SSH at them** in `~/.ssh/config`, readable only by the operator, and let one touch serve a burst of pushes. A new Ubuntu install has no `~/.ssh/config`; this creates it, with the year filled in:

    ```bash
    cat >~/.ssh/config <<EOF
    Host github.com gitlab.com
        IdentityFile ~/.ssh/id_ed25519_sk_primary_$(date +%Y)
        IdentityFile ~/.ssh/id_ed25519_sk_backup_$(date +%Y)
        IdentitiesOnly yes
        ControlMaster auto
        ControlPath ~/.ssh/cm-%C
        ControlPersist 10m
    EOF
    chmod 600 ~/.ssh/config
    ```

    `IdentitiesOnly yes` makes SSH offer only these two keys, never the signing key.

    **Connection reuse:** the first push or pull opens an authenticated connection (one touch) and keeps it open; later pushes and pulls to the same host reuse it without a touch, until it has been idle for 10 minutes. The socket lives in `~/.ssh`, which only the operator can write to, as the `ssh_config` manual recommends. `ssh -O exit git@github.com` (or `git@gitlab.com`) closes it at once, for example before leaving the workstation unlocked. Anyone using the operator's logged-in session during that window can push without a touch, so the window stays short.

4. **Test:** `ssh -T git@github.com` and `ssh -T git@gitlab.com` each ask for a touch and greet the user (GitHub: `Hi <user>! You've successfully authenticated, but GitHub does not provide shell access.`; GitLab: `Welcome to GitLab, @<user>!`). The first connection to each asks to confirm the host's fingerprint; compare it with [GitHub's SSH key fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints) and [GitLab.com's SSH host key fingerprints](https://docs.gitlab.com/user/gitlab_com/) (section "SSH host keys fingerprints") before answering `yes`.
5. **Set up commit signing and the project's Git identity.** Commits are signed with an Ed25519 key file that has a passphrase, not with the YubiKeys (see the table above), and is never used to sign in. RussetLeaf repos use the project's identity, the operator's Workspace address, so no personal address reaches the public history; other repos on the machine keep their own settings.
    1. **Create the signing key.** Generate a passphrase in Bitwarden first and save it in a new item, `workstation signing key`; enter it when `ssh-keygen` asks:

        ```bash
        ssh-keygen -t ed25519 -C "workstation signing" -f ~/.ssh/id_ed25519_signing
        ```

    2. **Write the project's Git settings** to their own file, replacing `<name>@russetleaf.dev` with the operator's Workspace address, and run the whole block:

        ```bash
        email="<name>@russetleaf.dev"
        mkdir -p ~/.config/git
        cat >~/.config/git/russetleaf.gitconfig <<EOF
        [user]
            email = ${email}
            signingkey = ${HOME}/.ssh/id_ed25519_signing.pub
        [gpg]
            format = ssh
        [gpg "ssh"]
            allowedSignersFile = ${HOME}/.config/git/allowed_signers
        [commit]
            gpgsign = true
        [tag]
            gpgsign = true
        EOF
        printf '%s namespaces="git" %s\n' "${email}" "$(cut -d' ' -f1,2 ~/.ssh/id_ed25519_signing.pub)" >>~/.config/git/allowed_signers
        ```

        The `allowed_signers` line lets `git log --show-signature` check the project's signatures on the workstation.
    3. **Apply them only to RussetLeaf repos:** an `includeIf` in the global Git configuration loads the file in any repo with a remote in the `russetleaf` organization or group, over SSH or HTTPS ([`git-config` conditional includes](https://git-scm.com/docs/git-config#_conditional_includes), Git 2.36 or later). Run the whole block:

        ```bash
        for url in git@github.com:russetleaf/** https://github.com/russetleaf/** git@gitlab.com:russetleaf/** https://gitlab.com/russetleaf/**; do
          git config --global "includeIf.hasconfig:remote.*.url:${url}.path" ~/.config/git/russetleaf.gitconfig
        done
        ```

        `git config --global` adds these lines at the end of the global file, so they override an earlier `user.email` or `user.signingkey`.
    4. **Register the public key** (`cat ~/.ssh/id_ed25519_signing.pub`, the whole line) with the title `workstation signing`:
        - **GitHub:** as in step 2, with the key type for **signing**, so it appears under **Signing keys** only. GitHub shows a commit as **Verified** when its email is a verified address of the account, so the Workspace address must be one ([GitHub organization setup guide](github-organization.md)).
        - **GitLab:** as in step 2, with the **Usage type** **Signing** and the **Expiration date** cleared, so the key does not expire. GitLab shows commits signed with it as **Verified** when the Workspace address is a verified email of the account ([GitLab group setup guide](gitlab-group.md#part-2-notifications-to-the-workspace-address-once)), which matters if work moves to GitLab ([disaster recovery plan](../disaster-recovery.md)).

        The key is replaced only with the workstation, or at once if it may be compromised.
    5. **Unlock it once per session** with `ssh-add ~/.ssh/id_ed25519_signing` (the passphrase from Bitwarden). Git signs through `ssh-agent`, so commits made without a terminal, such as a coding agent's, also work while the key is unlocked; `ssh-add -D` clears it, for example before leaving the workstation unlocked.
    6. **Test,** inside a RussetLeaf repo: `git config user.email` shows the Workspace address and `git config user.signingkey` the new key; after the next commit, `git log --show-signature -1` reports a good signature for the Workspace address, and the commit shows **Verified** on GitHub once pushed. Outside a RussetLeaf repo, `git config user.email` shows the global value.
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

## Renewing the keys every year

The authentication keys are given GitLab's default one-year expiry on purpose (the date is optional on GitLab.com): the renewal it forces is a yearly check that both YubiKeys work, that the procedure is current, and that the repos can be cloned from GitLab, as a restore would need. A GitLab SSH key stops working for Git on its expiry date and cannot be extended: GitLab requires a new key. GitHub keys do not expire, but they are renewed at the same time, so each YubiKey has one current key for both services and the year in its names shows which generation it is. The new keys are created, registered and tested **before** the old ones are removed, so a working key is registered at every point. Start before the date in Bitwarden (GitLab's email arrives seven days before), with `yubikey-backup` taken out of the safe:

1. **Create the new keys:** Part 1, step 1. The new year goes into the names; the old files stay in place.
2. **Register them on GitHub and GitLab:** Part 1, step 2, with the new year in the titles. Replace the date in the Bitwarden custom field with the new expiry date.
3. **Test the new keys on their own,** without `~/.ssh/config`, so SSH cannot fall back to an old key. For each YubiKey, plugged in alone, and with its own file:

    ```bash
    ssh -F /dev/null -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_sk_primary_"$(date +%Y)" -T git@github.com
    ssh -F /dev/null -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_sk_primary_"$(date +%Y)" -T git@gitlab.com
    ```

    and the same with `id_ed25519_sk_backup_"$(date +%Y)"` and `yubikey-backup`. Each asks for a touch and greets the user, as in Part 1, step 4.
4. **Switch `~/.ssh/config` to the new keys:** close any open connections (`ssh -O exit git@github.com` and `ssh -O exit git@gitlab.com`), replace the old year in the two `IdentityFile` lines with the new one (with `vim ~/.ssh/config`), and repeat the test in Part 1, step 4.
5. **Clone a mirror from GitLab,** as a restore would, into a temporary folder that is deleted afterwards:

    ```bash
    tmp="$(mktemp -d)" && git clone git@gitlab.com:russetleaf/russetleaf-docs.git "${tmp}/russetleaf-docs" && git -C "${tmp}/russetleaf-docs" log -1 --oneline && rm -rf "${tmp}"
    ```

    The commit it prints is the latest one on `main` on GitHub. Record the result in the decision log, as for the other [drills](../disaster-recovery.md#drills).
6. **Remove the old keys,** only after steps 4 and 5 pass:
    - **GitHub:** profile picture → **Settings** → in the **Access** section of the sidebar, **SSH and GPG keys** → next to each old key, **Delete**.
    - **GitLab:** avatar → **Edit profile** → in the left sidebar, **Access → SSH keys** → next to each old key, **Remove** (the remove icon), then **Delete**. **Revoke** is only for a compromised key: on GitLab it also marks the commits a signing key has signed as **Unverified**, while **Delete** leaves them verified.
    - **The workstation:** `rm ~/.ssh/id_ed25519_sk_primary_<old-year> ~/.ssh/id_ed25519_sk_primary_<old-year>.pub ~/.ssh/id_ed25519_sk_backup_<old-year> ~/.ssh/id_ed25519_sk_backup_<old-year>.pub`.
7. **Put `yubikey-backup` back in the safe.**

The `pam_u2f` registration for `sudo` (Part 2) does not expire and is not renewed.

## A second or replacement workstation

Nothing in this guide is stored on the YubiKeys themselves: the SSH keys are not resident (the YubiKey holds the secret, and a handle file in `~/.ssh` on each machine points to it), and the `pam_u2f` registration lives in each machine's `/etc/u2f_mappings`. Each workstation therefore gets its own registrations, and adding or retiring one changes nothing on the others:

1. **Set up the new machine** with the setup script ([workstation configuration](../plan.md#4-configuration)), then follow Parts 1 and 2 on it, naming its keys after the machine, for example `-C "laptop yubikey-primary $(date +%Y)"` and `-f ~/.ssh/id_ed25519_sk_laptop_primary_"$(date +%Y)"`, and the same titles on GitHub and GitLab. Its keys are renewed every year in the same way.
2. **Commit signing:** follow Part 1, step 5 on the new machine, naming its key after it (for example `-C "laptop signing"` and the title `laptop signing`). A signing key is replaced, never copied, and commits signed by the old one stay verified after it is removed: GitHub stores a verification record with each commit when it is pushed and does not re-check it when a key is rotated, revoked or deleted, and GitLab keeps them verified when a key is deleted rather than revoked.
3. **Retire the old machine:** on GitHub and GitLab, delete its SSH keys and its signing key (on GitLab with **Remove** and **Delete**, not **Revoke**); on the machine itself, delete `~/.ssh` and `/etc/u2f_mappings` before it is wiped or given away.

## Checks

- [ ] `ssh -T git@github.com` and `ssh -T git@gitlab.com` work with each YubiKey and fail with none plugged in.
- [ ] GitHub lists the current year's two `ed25519-sk` keys, and no older ones, under **Authentication keys** (a subheading of **SSH keys** on the **SSH and GPG keys** page) and `workstation signing` only under **Signing keys**; GitLab lists the two as **Authentication** and `workstation signing` as **Signing**, with no expiry date; a new commit shows **Verified** on GitHub.
- [ ] `ssh-keygen -y -P "" -f ~/.ssh/id_ed25519_signing` fails (the signing key has a passphrase), and the passphrase is in Bitwarden.
- [ ] Inside a RussetLeaf repo, `git config user.email` shows the Workspace address, and `git log --show-signature -1` reports a good signature for it.
- [ ] `sudo -k; sudo true` needs a touch of either key and the password, and fails without a key.
- [ ] `/etc/u2f_mappings` is owned by root and holds both keys.

## If something goes wrong

- **Lost `yubikey-primary`:** on GitHub and GitLab, delete its SSH key (`workstation yubikey-primary <year>`), delete `~/.ssh/id_ed25519_sk_primary_*`, and create and register a key on the replacement (Part 1, steps 1 and 2, the `yubikey-primary` command only), with its file in the first `IdentityFile` line of `~/.ssh/config`; rebuild `/etc/u2f_mappings` with `yubikey-backup` and the replacement (Part 2, step 2); then do the rest of the replacement in the [account sign-in setup guide](account-sign-in.md#if-something-goes-wrong).
- **`sudo` stops working after the PAM change:** in the root shell kept open in Part 2, remove the `pam_u2f.so` line from both files.
- **Both keys lost, or no root shell open:** boot into **recovery mode** (GRUB's **Advanced options**, then the **root** shell; on a default Ubuntu install it needs no root password, but the disk passphrase is still asked for), run `mount -o remount,rw /`, and remove the `pam_u2f.so` line from both files.

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- OpenBSD: ["ssh-keygen(1) manual page (ed25519-sk keys and the FIDO authenticator options)"](https://man.openbsd.org/ssh-keygen), checked 2026-11-14 (and the installed `man ssh-keygen`, OpenSSH 9.6p1)
- OpenBSD: ["ssh_config(5) manual page (ControlMaster, ControlPath, ControlPersist)"](https://man.openbsd.org/ssh_config), checked 2026-11-14 (and the installed `man ssh_config`)
- OpenSSH: ["OpenSSH 8.2 release notes (FIDO/U2F support)"](https://www.openssh.org/txt/release-8.2), checked 2026-11-12
- Yubico: ["Securing SSH with FIDO2"](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html), checked 2026-11-12
- Yubico: ["pam-u2f"](https://developers.yubico.com/pam-u2f/), checked 2026-11-12 (and the installed `man pamu2fcfg` and `man pam_u2f`, version 1.1.0)
- Yubico: ["FIDO Commands (YubiKey Manager CLI)"](https://docs.yubico.com/software/yubikey/tools/ykman/FIDO_Commands.html), checked 2026-11-12
- GitHub: ["Adding a new SSH key to your GitHub account"](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account), checked 2026-11-14
- GitHub: ["Generating a new SSH key and adding it to the ssh-agent"](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) (a key for a hardware security key), checked 2026-11-14
- GitHub: ["Telling Git about your signing key"](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key), checked 2026-11-14
- GitHub: ["Testing your SSH connection"](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection), checked 2026-11-14
- GitHub: ["GitHub's SSH key fingerprints"](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints), checked 2026-11-14
- GitLab: ["GitLab.com settings"](https://docs.gitlab.com/user/gitlab_com/) (SSH host key fingerprints), checked 2026-11-14
- GitLab: ["Use SSH keys with GitLab"](https://docs.gitlab.com/user/ssh/) (adding a key, the `ED25519_SK` type, the optional expiry date and its notifications, removing a key, verifying the connection), checked 2026-11-14
- GitLab: ["Sign commits with SSH keys"](https://docs.gitlab.com/user/project/repository/signed_commits/ssh/) (section "Signed commits with removed SSH keys": Delete compared with Revoke), checked 2026-11-14
- Git: ["git-config"](https://git-scm.com/docs/git-config) (section "Conditional includes", `hasconfig:remote.*.url`), checked 2026-11-14 (and the installed `man git-config`, Git 2.43.0)
- GitHub: ["About commit signature verification"](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification) (section "Persistent commit signature verification"), checked 2026-11-14
- GitHub: ["Reviewing your SSH keys"](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/reviewing-your-ssh-keys) (deleting a key), checked 2026-11-14
