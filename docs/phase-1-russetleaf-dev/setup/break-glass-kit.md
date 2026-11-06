# Setup guide: the break-glass kit and the GPG key

The step-by-step procedure for the **break-glass kit** (Phase 1 [step 0.1](../plan.md#step-01-accounts-tools-and-budget-alert)): the project's **GPG key**, the **printed copy** in the safe, and the **encrypted copy** in Google Drive and OneDrive. What the kit holds, and why, is in the [disaster recovery plan](../disaster-recovery.md#break-glass-kit); the choices behind this procedure are in the decision log (2026-11-05).

The kit lives in three places, so that losing any two still leaves a way back in:

| Copy | Where | Opened with | Covers |
|---|---|---|---|
| Working copy | Bitwarden | The master password and Bitwarden's two-step login | Day-to-day use |
| Printed copy | The safe at home, with the safe YubiKey and a USB stick holding the GPG key | Physical access to the safe | Losing Bitwarden access |
| Encrypted copy | Google Drive and OneDrive | A **passphrase the operator memorizes**, kept out of Bitwarden and the cloud | Losing the home (and the safe) and Bitwarden access together |

## The GPG key

The GPG key decrypts the backup copies in Cloudflare R2 ([step 2.5](../plan.md#step-25-disaster-recovery-copies)). The cluster holds only its public key. It is **not used for the copies in AWS**: those are encrypted with KMS keys, re-encrypted in the Backup account with that account's own keys, and protected by Object Lock, which already covers a compromised workload account; encrypting them with GPG as well would put this key in every routine restore and staging refresh ([ADR 1043](../adr/1043-database-encryption.md)). The R2 copy is outside AWS, where KMS cannot protect it, so GPG is its only encryption. The secret key is needed only for a restore or the quarterly drill, so it is **kept only in the kit**, never in the workstation's keyring:

- a passphrase-protected **export** on the USB stick in the safe, and inside the encrypted kit in Google Drive and OneDrive;
- a **`paperkey` printout** in the safe, in case the USB stick fails.

For a restore or a drill, it is loaded into a keyring in memory (`/dev/shm`) and deleted afterwards ([Using the key](#using-the-key)). Its passphrase, kept in Bitwarden and in the kit, protects it while it is in use.

Both of the operator's YubiKeys are Security Key NFC, which have no OpenPGP function, so neither can hold the key. Moving the key onto a **YubiKey 5 series** key later adds a PIN and a touch to every use, and changes nothing else ([Moving the key to a YubiKey later](#moving-the-key-to-a-yubikey-later)); it is [improvement I1-1](../improvements.md). Commits are signed with SSH, not this key ([workstation configuration](../plan.md#4-configuration)).

## Before starting

Have these ready:

- **The workstation**, set up with [`setup-ubuntu.sh`](https://github.com/smscully/russetleaf-docs/blob/main/scripts/workstation/setup-ubuntu.sh), which installs `gnupg` and `paperkey`.
- **Bitwarden open,** with a new entry for the GPG key (its passphrase and fingerprint, and the public key as a secure note).
- **A USB stick** for the safe, used for nothing else.
- **A printer** connected by USB or on the home network, not a cloud print service, so the printed pages are not stored by a third party.
- **Sign-ins to Google Drive and OneDrive.**
- **The kit passphrase:** generate a passphrase of six or more words with Bitwarden's generator (passphrase type) **without saving it**, and memorize it. It is written down nowhere except, optionally, a sealed copy with a trusted person. Everything in the encrypted copy depends on remembering it, so the 6-monthly check below tests it.

All secret files, and the keyring the key is created in, are made in memory (`/dev/shm`), so they never reach the disk, and they are deleted at the end:

```bash
RL_KIT=/dev/shm/rl-kit
mkdir -m 700 "${RL_KIT}"
export GNUPGHOME="${RL_KIT}/gnupg"
mkdir -m 700 "${GNUPGHOME}"
```

## Part 1: create the GPG key

1. **Create the key:** a primary key for certifying (it renews the key's expiry) and an encryption subkey, both expiring after two years. Enter a passphrase generated in Bitwarden when asked, and save it in Bitwarden.

    ```bash
    gpg --quick-generate-key "RussetLeaf backups" ed25519 cert 2y
    FPR="$(gpg --list-keys --with-colons "RussetLeaf backups" | awk -F: '/^fpr/ {print $10; exit}')"
    gpg --quick-add-key "${FPR}" cv25519 encr 2y
    echo "${FPR}"    # record the fingerprint in Bitwarden
    ```

2. **Export it:**

    ```bash
    gpg --armor --export "${FPR}" >"${RL_KIT}/gpg-public-key.asc"
    gpg --armor --export-secret-keys "${FPR}" >"${RL_KIT}/gpg-secret-key.asc"
    gpg --export-secret-keys "${FPR}" | paperkey --output "${RL_KIT}/gpg-paperkey.txt"
    ```

    The export stays protected by the key's passphrase. The `paperkey` file holds only the secret parts, so restoring from it also needs the public key, which is kept with it.

3. **Test the export** in a second scratch keyring, so a bad backup is found now rather than in a disaster:

    ```bash
    test_home="$(mktemp -d -p /dev/shm)"
    gpg --homedir "${test_home}" --import "${RL_KIT}/gpg-secret-key.asc"
    echo "backup test" | gpg --homedir "${test_home}" --trust-model always --encrypt --recipient "${FPR}" |
      gpg --homedir "${test_home}" --decrypt
    gpgconf --homedir "${test_home}" --kill gpg-agent
    rm -rf "${test_home}"
    ```

    The decryption prints `backup test` after asking for the key's passphrase.

4. **Save the public key in Bitwarden** (the contents of `gpg-public-key.asc`, in the secure note). Step 2.5 gives it to the cluster's backup job.
5. **Close the keyring in memory,** so the key exists only as the export:

    ```bash
    gpgconf --kill gpg-agent
    rm -rf "${GNUPGHOME}"
    unset GNUPGHOME
    ```

## Part 2: the kit file and the printed copy

1. **Write the kit file** in `"${RL_KIT}/kit.txt"` with `vim -n -i NONE -c 'setlocal noundofile nobackup nowritebackup'`, from the entries in Bitwarden. The options keep every copy of the text in the folder in memory: `-n` turns off the swap file and `-i NONE` the `viminfo` file (which would save yanked text in the home folder), and the settings turn off undo and backup files, which a `vimrc` may send to a folder on disk. The kit file lists every item in the [disaster recovery plan's list](../disaster-recovery.md#break-glass-kit), plus the GPG key's **fingerprint** and **passphrase**. Then append the GPG key's public key and secret key export:

    ```bash
    cat "${RL_KIT}/gpg-public-key.asc" "${RL_KIT}/gpg-secret-key.asc" >>"${RL_KIT}/kit.txt"
    ```

2. **Print** the starred items of the kit file, the GPG fingerprint and passphrase, and `gpg-paperkey.txt` with the public key (`gpg-public-key.asc`). Date each page.
3. **Copy to the USB stick** `gpg-public-key.asc`, `gpg-secret-key.asc` and `gpg-paperkey.txt`.
4. **Put in the safe:** the printed pages, the USB stick and the safe YubiKey. The safe then holds the AWS root password and an MFA device together, which is accepted for a home safe (decision log, 2026-11-05).

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
4. **Clean up:** delete the folder in memory.

    ```bash
    rm -rf "${RL_KIT}"
    ```

## Checks

- [ ] The secret key export decrypted a test message in a scratch keyring (Part 1, step 3).
- [ ] With `FPR` set to the key's fingerprint, `gpg --list-secret-keys "${FPR}"` in the workstation's own keyring finds **no** key.
- [ ] The encrypted kit **downloaded from Google Drive**, and again **from OneDrive**, decrypts with the memorized passphrase after `gpgconf --reload gpg-agent`.
- [ ] The safe holds the printed pages, the `paperkey` printout, the USB stick and the safe YubiKey.
- [ ] Bitwarden holds the GPG key's fingerprint, passphrase and public key.
- [ ] `/dev/shm/rl-kit` no longer exists.

## Using the key

For a restore from Cloudflare R2 or the quarterly drill, load the key from the USB stick (or from the encrypted kit) into a keyring in memory, decrypt, then delete the keyring:

```bash
export GNUPGHOME="$(mktemp -d -p /dev/shm)"
gpg --import /media/"${USER}"/<usb-stick>/gpg-secret-key.asc
gpg --output mariadb-dump.sql.gz --decrypt mariadb-dump.sql.gz.gpg
gpgconf --kill gpg-agent
rm -rf "${GNUPGHOME}"
unset GNUPGHOME
```

Put the USB stick back in the safe afterwards.

## Keeping the kit current

- **When an item changes** (a new recovery code, a new password, the Talos secrets bundle after step 2.2): update Bitwarden, then repeat Part 2, step 1 and Part 3 with the GPG exports from the USB stick, replace both cloud copies, and replace the printed pages that changed (shredding the old ones).
- **Every 6 months** ([drill](../disaster-recovery.md#drills)): download both cloud copies and decrypt them after `gpgconf --reload gpg-agent`, compare them with Bitwarden, and check the GPG key's expiry date (`gpg --show-keys gpg-public-key.asc`).
- **Renew the GPG key** at least a month before it expires: load it as in [Using the key](#using-the-key), run `gpg --quick-set-expire "${FPR}" 2y` and `gpg --quick-set-expire "${FPR}" 2y '*'`, and export the public key, the secret key and the `paperkey` file again (Part 1, step 2). Update the public key in Bitwarden and in the cluster's backup job (step 2.5), replace the files on the USB stick and the printout, and refresh the kit (Part 2, step 1 and Part 3). The key and its fingerprint do not change, so existing backups still decrypt.

## Moving the key to a YubiKey later

A **YubiKey 5 series** key (for example the YubiKey 5 NFC; OpenPGP with Ed25519 needs firmware 5.2.3 or later, shown by `ykman info`) can hold the key, so that every use needs the YubiKey, a PIN and a touch. The setup script already installs `scdaemon`, `pcscd` and `yubikey-manager` for this. The key, its fingerprint and its public key stay the same, so the cluster and existing backups are not affected.

1. **Load the key** into a keyring in memory, as in [Using the key](#using-the-key), but keep the keyring until step 5.
2. **Set the OpenPGP PINs:** generate a **PIN** and an **Admin PIN** (8 digits each) in Bitwarden, then replace the defaults (PIN `123456`, Admin PIN `12345678`) with `gpg --card-edit`, then `admin`, then `passwd`: option **1** changes the PIN and option **3** the Admin PIN.
3. **Require a touch:** `ykman openpgp keys set-touch sig on` and `ykman openpgp keys set-touch dec on` (each asks for the Admin PIN).
4. **Move the keys** with `gpg --edit-key "${FPR}"`: `keytocard` (the primary key, to the **Signature key** slot), then `key 1` and `keytocard` (to the **Encryption key** slot), then `save`. If `gpg --card-status` finds no card while `ykman info` does, add `disable-ccid` to `scdaemon.conf` in the keyring folder and run `gpgconf --kill scdaemon`.
5. **Delete the keyring in memory,** and in the workstation's own keyring import the public key and run `gpg --card-status`, which creates stubs pointing to the YubiKey. Check that `gpg --list-secret-keys` shows `sec>` and `ssb>` (the `>` means the key is on the card).
6. **Keep the exports** on the USB stick and in the kit as the backup, add the PINs to Bitwarden and the kit, and update this guide, the [disaster recovery plan](../disaster-recovery.md#break-glass-kit) and the decision log.

## If something goes wrong

- **The USB stick fails or is lost:** take the export from the encrypted kit in Google Drive or OneDrive, or rebuild it from the `paperkey` printout (type the printed text into `gpg-paperkey.txt`, then `gpg --dearmor <gpg-public-key.asc >pub.gpg` and `paperkey --pubring pub.gpg --secrets gpg-paperkey.txt >gpg-secret-key.gpg`), and write a new stick.
- **The GPG key's passphrase is lost:** copies of it are in Bitwarden, the printed kit and the encrypted kit; if all are lost, the R2 copies cannot be decrypted. Create a new key (Part 1), give its public key to the cluster, and rely on the copies in AWS until the R2 copies made with the old key have expired (35 days).
- **The kit passphrase is forgotten:** the cloud copies cannot be opened. While the printed copy and Bitwarden are still available, choose a new passphrase and repeat Part 3, replacing both cloud copies.
- **The Google or Microsoft account is compromised:** the copy stays protected by the passphrase. Secure the account, then make a new copy with a new passphrase, and change the most important items in it (the AWS root password, the Bitwarden master password, the GPG key) if the passphrase could have been weak or seen.
