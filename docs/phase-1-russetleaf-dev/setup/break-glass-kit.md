# Setup guide: the break-glass kit and the GPG key

The step-by-step procedure for the **break-glass kit** (Phase 1 [step 0.1](../plan.md#step-01-accounts-tools-and-budget-alert)): the project's **GPG key** on a YubiKey, the **printed copy** in the safe, and the **encrypted copy** in Google Drive and OneDrive. What the kit holds, and why, is in the [disaster recovery plan](../disaster-recovery.md#break-glass-kit); the choices behind this procedure are in the decision log (2026-11-05).

The kit lives in three places, so that losing any two still leaves a way back in:

| Copy | Where | Opened with | Covers |
|---|---|---|---|
| Working copy | Bitwarden | The master password and Bitwarden's two-step login | Day-to-day use |
| Printed copy | The safe at home, with the YubiKey and a USB stick holding the GPG key's backup | Physical access to the safe | Losing Bitwarden access |
| Encrypted copy | Google Drive and OneDrive | A **passphrase the operator memorizes**, kept out of Bitwarden and the cloud | Losing the home (and the safe) and Bitwarden access together |

The encrypted copy uses a passphrase only, **not** the YubiKey's key: the YubiKey sits in the same safe, and the cloud copy must still open after the safe is lost.

The GPG key decrypts the backup copies in Cloudflare R2 ([step 2.5](../plan.md#step-25-disaster-recovery-copies)). It lives on the YubiKey, so no copy of the secret key stays on the workstation's disk; its backups are a passphrase-protected export (on the USB stick, and inside the encrypted kit) and a `paperkey` printout (in the safe). Commits are signed with SSH, not this key ([workstation configuration](../plan.md#4-configuration)).

## Before starting

Have these ready:

- **The workstation**, set up with [`setup-ubuntu.sh`](https://github.com/smscully/russetleaf-docs/blob/main/scripts/workstation/setup-ubuntu.sh), which installs `gnupg`, `scdaemon`, `pcscd`, `paperkey` and `yubikey-manager` (`ykman`).
- **The YubiKey** that is the AWS root user's backup MFA device ([AWS management account setup guide](aws-management-account.md#before-starting)). Its OpenPGP function needs **firmware 5.2.3 or later** for the key types below; check with `ykman info`.
- **Bitwarden open,** with a new entry for the GPG key (its passphrase, its fingerprint, the YubiKey's PINs and the public key, as a secure note).
- **A USB stick** for the safe, used for nothing else.
- **A printer** connected by USB or on the home network, not a cloud print service, so the printed pages are not stored by a third party.
- **Sign-ins to Google Drive and OneDrive.**
- **The kit passphrase:** generate a passphrase of six or more words with Bitwarden's generator (passphrase type) **without saving it**, and memorize it. It is written down nowhere except, optionally, a sealed copy with a trusted person. Everything in the encrypted copy depends on remembering it, so the 6-monthly check below tests it.

All secret files are made in a folder in memory (`/dev/shm`), so they never reach the disk, and the folder is deleted at the end:

```bash
RL_KIT=/dev/shm/rl-kit
mkdir -m 700 "${RL_KIT}"
```

## Part 1: the GPG key on the YubiKey

1. **Create the key:** a primary key for certifying (it renews the key's expiry) and an encryption subkey, both expiring after two years. Enter a passphrase generated in Bitwarden when asked, and save it in Bitwarden.

    ```bash
    gpg --quick-generate-key "RussetLeaf backups" ed25519 cert 2y
    FPR="$(gpg --list-keys --with-colons "RussetLeaf backups" | awk -F: '/^fpr/ {print $10; exit}')"
    gpg --quick-add-key "${FPR}" cv25519 encr 2y
    echo "${FPR}"    # record the fingerprint in Bitwarden
    ```

2. **Export the backups before anything else.** Moving the keys to the YubiKey removes them from the workstation, so this is the only moment a copy can be made.

    ```bash
    gpg --armor --export "${FPR}" >"${RL_KIT}/gpg-public-key.asc"
    gpg --armor --export-secret-keys "${FPR}" >"${RL_KIT}/gpg-secret-key.asc"
    gpg --export-secret-keys "${FPR}" | paperkey --output "${RL_KIT}/gpg-paperkey.txt"
    ```

    The export stays protected by the key's passphrase. The `paperkey` file holds only the secret parts, so restoring from it also needs the public key, which is kept with it.

3. **Test the export** in a scratch keyring, so a bad backup is found now rather than in a disaster:

    ```bash
    test_home="$(mktemp -d -p /dev/shm)"
    gpg --homedir "${test_home}" --import "${RL_KIT}/gpg-secret-key.asc"
    echo "backup test" | gpg --homedir "${test_home}" --trust-model always --encrypt --recipient "${FPR}" |
      gpg --homedir "${test_home}" --decrypt
    gpgconf --homedir "${test_home}" --kill gpg-agent
    rm -rf "${test_home}"
    ```

    The decryption prints `backup test` after asking for the key's passphrase.

4. **Set the YubiKey's OpenPGP PINs:** generate a **PIN** (8 digits) and an **Admin PIN** (8 digits) in Bitwarden, then replace the defaults (PIN `123456`, Admin PIN `12345678`) with `gpg --card-edit`, then `admin`, then `passwd`: option **1** changes the PIN and option **3** the Admin PIN. Three wrong PINs block the PIN; three wrong Admin PINs lock the OpenPGP function until it is reset ([If something goes wrong](#if-something-goes-wrong)).
5. **Require a touch** for each use, so malware on the workstation cannot use the key unnoticed (each command asks for the Admin PIN):

    ```bash
    ykman openpgp keys set-touch sig on
    ykman openpgp keys set-touch dec on
    ```

6. **Move the keys to the YubiKey** with `gpg --edit-key "${FPR}"`:
    - `keytocard`, and choose the **Signature key** slot (for the primary key);
    - `key 1`, then `keytocard`, and choose the **Encryption key** slot;
    - `save`. GnuPG then replaces the secret keys on disk with stubs that point to the YubiKey.
7. **Confirm** that `gpg --list-secret-keys` shows `sec>` and `ssb>` (the `>` means the key is on the card), and that `gpg --card-status` lists both keys. If `gpg --card-status` finds no card while `ykman info` does, add the line `disable-ccid` to `~/.gnupg/scdaemon.conf` and run `gpgconf --kill scdaemon`, so GnuPG reaches the YubiKey through `pcscd`.
8. **Save the public key in Bitwarden** (the contents of `gpg-public-key.asc`, in the secure note). Step 2.5 gives it to the cluster's backup job.

## Part 2: the kit file and the printed copy

1. **Write the kit file** in `"${RL_KIT}/kit.txt"` with `nano` (which keeps no backup copies), from the entries in Bitwarden: every item in the [disaster recovery plan's list](../disaster-recovery.md#break-glass-kit), plus the GPG key's **fingerprint** and **passphrase** and the YubiKey's **PIN** and **Admin PIN**. Then append the GPG key's public key and secret key export:

    ```bash
    cat "${RL_KIT}/gpg-public-key.asc" "${RL_KIT}/gpg-secret-key.asc" >>"${RL_KIT}/kit.txt"
    ```

2. **Print** the starred items of the kit file, the GPG passphrase and PINs, and `gpg-paperkey.txt` with the public key (`gpg-public-key.asc`). Date each page.
3. **Copy to the USB stick** `gpg-public-key.asc`, `gpg-secret-key.asc` and `gpg-paperkey.txt`.
4. **Put in the safe:** the printed pages, the USB stick, and the YubiKey once Part 3 is done. The safe then holds the AWS root password and an MFA device together, which is accepted for a home safe (decision log, 2026-11-05).

## Part 3: the encrypted copy in Google Drive and OneDrive

1. **Encrypt the kit file with the memorized passphrase,** using AES-256 and a slow passphrase hash, which makes guessing the passphrase from a stolen copy expensive:

    ```bash
    gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-count 65011712 \
      --output "${RL_KIT}/russetleaf-break-glass-kit.txt.gpg" "${RL_KIT}/kit.txt"
    ```

2. **Prove the passphrase,** after clearing the passphrase that `gpg-agent` has just cached (otherwise the test proves nothing):

    ```bash
    gpgconf --reload gpg-agent
    gpg --decrypt "${RL_KIT}/russetleaf-break-glass-kit.txt.gpg" | head -n 5
    ```

3. **Upload** `russetleaf-break-glass-kit.txt.gpg` to a folder in **Google Drive** and a folder in **OneDrive**, through their web pages. Neither needs sharing with anyone.
4. **Clean up:** delete the folder in memory, and put the YubiKey in the safe.

    ```bash
    rm -rf "${RL_KIT}"
    ```

## Checks

- [ ] `gpg --list-secret-keys` shows `sec>` and `ssb>`, and `gpg --card-status` lists the signature and encryption keys on the YubiKey.
- [ ] With `FPR` set to the key's fingerprint, `echo test | gpg --encrypt --recipient "${FPR}" | gpg --decrypt` asks for the PIN and a touch, and prints `test`; with the YubiKey unplugged, the decryption fails.
- [ ] The secret key export decrypted a test message in a scratch keyring (Part 1, step 3).
- [ ] The encrypted kit **downloaded from Google Drive**, and again **from OneDrive**, decrypts with the memorized passphrase after `gpgconf --reload gpg-agent`.
- [ ] The safe holds the printed pages, the `paperkey` printout, the USB stick and the YubiKey.
- [ ] Bitwarden holds the GPG key's fingerprint, passphrase and public key, and the YubiKey's PINs.
- [ ] `/dev/shm/rl-kit` no longer exists.

## Keeping the kit current

- **When an item changes** (a new recovery code, a new password, the Talos secrets bundle after step 2.2): update Bitwarden, then repeat Part 2, step 1 and Part 3 with the GPG exports from the USB stick, replace both cloud copies, and replace the printed pages that changed (shredding the old ones).
- **Every 6 months** ([drill](../disaster-recovery.md#drills)): download both cloud copies and decrypt them after `gpgconf --reload gpg-agent`, compare them with Bitwarden, and check the GPG key's expiry date (`gpg --list-keys "${FPR}"`).
- **Renew the GPG key** at least a month before it expires: with the YubiKey plugged in, run `gpg --quick-set-expire "${FPR}" 2y` and `gpg --quick-set-expire "${FPR}" 2y '*'` (each asks for the PIN and a touch). Export the public key again, and update it in Bitwarden, in the cluster's backup job (step 2.5), on the USB stick and in the kit. The secret key does not change, so the secret key export and the `paperkey` printout stay valid; restoring from them afterwards needs the new public key.

## If something goes wrong

- **The YubiKey is lost or broken:** replace it as the AWS root user's backup device ([AWS management account setup guide](aws-management-account.md#if-something-goes-wrong)), and as the Identity Center backup. Restore the GPG key onto the new YubiKey: remove the old stubs with `gpg --delete-secret-keys "${FPR}"`, import `gpg-secret-key.asc` from the USB stick (or from the encrypted kit), then repeat Part 1, steps 4 to 7. From the `paperkey` printout instead, rebuild the secret key first: `gpg --dearmor <gpg-public-key.asc >pub.gpg`, then `paperkey --pubring pub.gpg --secrets gpg-paperkey.txt | gpg --import` (with the printed text typed into `gpg-paperkey.txt`).
- **The PIN is blocked** (three wrong tries): unblock it with the Admin PIN (`gpg --card-edit`, then `admin`, `passwd`, option **2**).
- **The Admin PIN is blocked:** the OpenPGP function can only be reset, which erases its keys: run `ykman openpgp reset`, then restore the key as for a lost YubiKey. The YubiKey's security-key function, used for AWS, is not affected.
- **The kit passphrase is forgotten:** the cloud copies cannot be opened. While the printed copy and Bitwarden are still available, choose a new passphrase and repeat Part 3, replacing both cloud copies.
- **The Google or Microsoft account is compromised:** the copy stays protected by the passphrase. Secure the account, then make a new copy with a new passphrase, and change the most important items in it (the AWS root password, the Bitwarden master password) if the passphrase could have been weak or seen.
