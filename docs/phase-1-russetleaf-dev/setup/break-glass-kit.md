# Setup guide: the break-glass kit and the GPG key

The step-by-step procedure for the **break-glass kit** (Phase 1 [step 0.1](../plan.md#step-01-accounts-tools-and-budget-alert)): the project's **GPG key**, the **printed copy** in the safe, and the **encrypted copy** in Google Drive and OneDrive. What the kit holds, and why, is in the [disaster recovery plan](../disaster-recovery.md#break-glass-kit); the choices behind this procedure are in the decision log (2026-11-05).

The kit lives in three places, so that losing any two still leaves a way back in:

| Copy | Where | Opened with | Covers |
|---|---|---|---|
| Working copy | Bitwarden | The master password and Bitwarden's two-step login | Day-to-day use |
| Printed copy | The safe, with `yubikey-backup` and a USB stick holding the GPG key | Physical access to the safe | Losing Bitwarden access |
| Encrypted copy | Google Drive and OneDrive | A **passphrase the operator memorizes**, kept out of Bitwarden and the cloud | Losing the safe and Bitwarden access together |

The printed and encrypted copies hold only the **root credentials**: those that recover everything else. They are seven items from Bitwarden (listed in [Before starting](#before-starting)), plus Bitwarden's account email and two-step login recovery code, which are kept out of the vault. Bitwarden's **master password** is not in the kit: like the kit passphrase, it is only memorized, so a stolen safe does not open the vault. Every other credential is reached through Bitwarden once it is open again, and, if Bitwarden itself is lost, from the encrypted export of the whole vault, renewed after every change and quarterly ([Part 4](#part-4-the-encrypted-export-of-the-bitwarden-vault)). So the printed kit changes only when a root credential changes, and the rest of the vault is never printed. This is the usual practice for offline emergency credentials, such as AWS's for the root user's credentials.

## The GPG key

The GPG key decrypts the backup copies in Cloudflare R2 ([step 2.5](../plan.md#step-25-disaster-recovery-copies)). The cluster holds only its public key. It is **not used for the copies in AWS**: those are encrypted with KMS keys, re-encrypted in the Backup account with that account's own keys, and protected by Object Lock, which already covers a compromised workload account; encrypting them with GPG as well would put this key in every routine restore and staging refresh ([ADR 1043](../adr/1043-database-encryption.md)). The R2 copy is outside AWS, where KMS cannot protect it, so GPG is its only encryption. The secret key is needed only for a restore or the quarterly drill, so it is **kept only in the kit**, never in the workstation's keyring:

- a passphrase-protected **export** on the USB stick in the safe, and inside the encrypted kit in Google Drive and OneDrive;
- a **`paperkey` printout** in the safe, in case the USB stick fails.

The USB stick itself is **not encrypted**. It holds the GPG key's three files, the two encrypted vault exports ([Part 4](#part-4-the-encrypted-export-of-the-bitwarden-vault)) and the server network router's encrypted configuration backup ([server network setup guide](server-network.md#part-5-backups-and-bios-passwords)). The secret parts in the key's export and its `paperkey` file stay encrypted with the key's passphrase, since `gpg` exports a protected key as it is and `paperkey` copies those parts unchanged; the public key needs no protection; and the vault exports are encrypted with the memorized kit passphrase, like the cloud copies. The GPG key's passphrase is in the printed kit (in its Bitwarden item), so the safe is what protects the key's files on the stick, as it protects the printed passwords; the kit passphrase is never written down, so the vault exports stay protected even if the safe is stolen. Encrypting the whole stick would add a third secret to keep, and would stop it opening on any computer at hand, which is why it is exFAT.

For a restore or a drill, it is loaded into a keyring in memory (`/dev/shm`) and deleted afterwards ([Using the key](#using-the-key)). Its passphrase, kept in Bitwarden and in the kit, protects it while it is in use.

Both of the operator's YubiKeys are Security Key NFC, which have no OpenPGP function, so neither can hold the key. Moving the key onto a **YubiKey 5 series** key later adds a PIN and a touch to every use, and changes nothing else ([Moving the key to a YubiKey later](#moving-the-key-to-a-yubikey-later)); it is [improvement I1-1](../improvements.md). Commits are signed with SSH, not this key ([workstation configuration](../plan.md#4-configuration)).

## Before starting

Have these ready:

- **The workstation**, set up with [`setup-ubuntu.sh`](https://github.com/russetleaf/russetleaf-docs/blob/main/scripts/workstation/setup-ubuntu.sh), which installs `gnupg` and `paperkey`.
- **The project's Bitwarden account open,** with the kit's seven items, as text in each item's fields or notes (not as attachments, which the kit cannot read). The generator in Part 2 finds them by these names, so each item is named exactly so (capitals aside); what each is for is in the [disaster recovery plan](../disaster-recovery.md#break-glass-kit). Three of them are in the `Shared accounts` collection of the project's organization ([account sign-in setup guide](account-sign-in.md#part-1-the-personal-google-account-microsoft-and-bitwarden)):
    - `AWS Root - russetleaf-management`
    - `Bitwarden - RussetLeaf API key`
    - `Google Personal - Operator`
    - `Google Workspace - RussetLeaf`
    - `Microsoft Personal - Operator`
    - `RussetLeaf backups GPG key`
    - `YubiKey PINs`

    Part 1 adds the **Secure note** item for the GPG key, `RussetLeaf backups GPG key`, with its passphrase in a hidden field and its fingerprint in a text field, and the public key in the notes.
- **The Bitwarden CLI (`bw`) signed in** with the account's personal API key, since the CLI cannot use a security key: in the Bitwarden web app, **Settings → Security → Keys → View API key** (it asks for the master password) shows the `client_id` and `client_secret`, which are saved in the vault as the item `Bitwarden - RussetLeaf API key` ([account sign-in setup guide](account-sign-in.md#part-1-the-personal-google-account-microsoft-and-bitwarden), step 3); run `bw login --apikey` in the project's CLI data folder (set up below) and paste them when asked ([workstation configuration](../plan.md#4-configuration)). `bw status` then shows `locked` and the Workspace address.
- **A USB stick** for the safe, used for nothing else, formatted as **exFAT** (which Linux, Windows and macOS all read and write, so any computer at hand can open it years later) and named **`RL-KIT`**. Formatting erases the stick. Disks offers exFAT once `exfatprogs` is installed, which the setup script does.
    1. Open **Disks**: press the Super key (the Windows-logo key), type `Disks`, and press **Enter**.
    2. In the list of devices on the left, select the USB stick. Check its size and model, so the right device is erased.
    3. In the **Volumes** map on the right, select the **partition**: the large block that fills almost the whole stick, showing its current name and file system. A small **Free Space** block of about 1 to 4 MB before it is the **partition alignment** gap: partitioning tools start the first partition on a 1 MiB or 4 MiB boundary so it lines up with the flash memory's erase blocks. Leave it unselected and unchanged; it costs no usable space.
    4. In the toolbar under the **Volumes** map, select the menu button, then **Format Partition…**.
    5. Enter the name `RL-KIT`, choose the type **Other**, then **exFAT**, and select **Next**.
    6. Check that the details name the USB stick, `RL-KIT` and exFAT, and select **Format**.
    7. **Mount it:** Disks leaves the new file system unmounted. With the partition still selected, select the mount button (the triangle) in the toolbar under the **Volumes** map, or select `RL-KIT` in the Files sidebar.
    8. Check the result: `lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT` shows the partition with `exfat` and `RL-KIT`, mounted at `/media/<user>/RL-KIT`.
- **A printer** connected by USB or on the main network, not a cloud print service, so the printed pages are not stored by a third party. The setup script sets CUPS, the workstation's print service, to keep no copy of a document once it has printed (`PreserveJobFiles No`; by default CUPS keeps each one on disk for a day), so the kit file never stays on the disk.
    1. **Add the printer:** a USB printer is usually added on its own when it is connected and turned on. Otherwise, or for a network printer, press the Super key (the Windows-logo key), type `Printers`, and select **Printers**; select **Unlock** in the top right corner if it is shown, then **Add Printer…**, select the printer and select **Add**. A network printer that is not listed can be added by entering its address in the text field at the bottom of the dialog, then **Add**.
    2. **Check the print service setting:** `grep -x 'PreserveJobFiles No' /etc/cups/cupsd.conf` prints the line. If it prints nothing, run the setup script again.
    3. **Print a test page from the terminal,** the way the kit is printed: `lpstat -p` lists the printer's name, then `printf 'RussetLeaf printer test\n' | lp -d <printer>` prints one page with that line on it (`lp` reports `0 file(s)` when it reads from a pipe, which is expected). Once the page is out, `sudo find /var/spool/cups -maxdepth 1 -name 'd*'` prints nothing: CUPS keeps a document's data in a `d` file there while it prints and, with this setting, deletes it afterwards (the `c` files that remain hold only the job's name and history).
- **Sign-ins to Google Drive and OneDrive:** the personal Google Account's Drive and the personal Microsoft account. The Workspace account's Drive is not used: that account depends on russetleaf.dev and on credentials the kit itself holds, so it can be out of reach in exactly the cases the kit is for, and as the project's sign-in everywhere it is the account most exposed to attack; a third copy would also be one more to replace at every refresh.
- **The kit passphrase:** generate a passphrase of six or more words with Bitwarden's generator (passphrase type) **without saving it**, and memorize it. It is written down nowhere except, optionally, a sealed copy with a trusted person. Everything in the encrypted copy depends on remembering it, so the 6-monthly check below tests it.

The first line points `bw` at the project's account rather than any personal one. All secret files, and the keyring the key is created in, are made in memory (`/dev/shm`), so they never reach the disk, and they are deleted at the end:

```bash
export BITWARDENCLI_APPDATA_DIR="${HOME}/.config/Bitwarden CLI RussetLeaf"
RL_KIT=/dev/shm/rl-kit
mkdir -m 700 "${RL_KIT}"
export GNUPGHOME="${RL_KIT}/gnupg"
mkdir -m 700 "${GNUPGHOME}"
```

## Part 1: Create the GPG key

1. **Create the key:** a primary key for certifying (it renews the key's expiry) and an encryption subkey, both expiring after two years. First create the item in Bitwarden: **New → Secure note**, named `RussetLeaf backups GPG key`, then generate a passphrase with the generator's **Passphrase** type (six or more words) and in the item's **Custom fields** section, select **Add field** and add a field of type **Hidden**, with the **Name** `Passphrase` and the passphrase as its **Value**, and save. When `gpg` asks for the key's passphrase (twice, in a passphrase window), paste it from the item.

    ```bash
    gpg --quick-generate-key "RussetLeaf backups" ed25519 cert 2y
    FPR="$(gpg --list-keys --with-colons "RussetLeaf backups" | awk -F: '/^fpr/ {print $10; exit}')"
    gpg --quick-add-key "${FPR}" cv25519 encr 2y
    echo "${FPR}"    # add to the item as a Text custom field named Fingerprint
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

4. **Save the public key in Bitwarden:** paste the contents of `gpg-public-key.asc` (`cat "${RL_KIT}/gpg-public-key.asc"`) into the notes of `RussetLeaf backups GPG key`, and save. Step 2.5 gives it to the cluster's backup job.
5. **Close the keyring in memory,** so the key exists only as the export:

    ```bash
    gpgconf --kill gpg-agent
    rm -rf "${GNUPGHOME}"
    unset GNUPGHOME
    ```

## Part 2: The kit file and the printed copy

The kit file is generated from Bitwarden rather than typed, so every password and recovery code in it is an exact copy, and every refresh is the same command.

1. **Generate the kit file** from the whole vault, as text in memory. First unlock Bitwarden on its own, since a prompt in the middle of a pasted block takes the lines pasted after it as its input and garbles them; `bw unlock` asks for the master password:

    ```bash
    export BW_SESSION="$(bw unlock --raw)"
    ```

    Then run the whole block:

    ```bash
    bw sync
    kit_items='["AWS Root - russetleaf-management", "Bitwarden - RussetLeaf API key",
      "Google Personal - Operator", "Google Workspace - RussetLeaf",
      "Microsoft Personal - Operator", "RussetLeaf backups GPG key", "YubiKey PINs"]'
    bw list items \
      | jq --argjson names "${kit_items}" \
        '($names | map(ascii_downcase)) as $want | [.[] | select((.name | ascii_downcase) as $n | $want | index($n))]' \
        >"${RL_KIT}/items.json"
    {
      printf "RussetLeaf break-glass kit, generated %s from the project's Bitwarden vault\n\n" "$(date +%F)"
      jq -r 'sort_by(.name | ascii_downcase)[]
        | "==== \(.name) ====",
          (if .login then
             (if .login.username then "Username: \(.login.username)" else empty end),
             (if .login.password then "Password: \(.login.password)" else empty end),
             (if .login.totp then "Authenticator key (TOTP): \(.login.totp)" else empty end),
             ((.login.uris // [])[] | "URL: \(.uri)")
           else empty end),
          (((.sshKey // {}), (.card // {}), (.identity // {})) | to_entries[]
             | select(.value != null and .value != "") | "\(.key): \(.value)"),
          ((.fields // [])[] | "\(.name): \(.value // "")"),
          (if .notes then "Notes:", .notes else empty end),
          (if (.attachments // []) | length > 0 then "WARNING: this item has attachments, which are not in the kit" else empty end),
          ""' "${RL_KIT}/items.json"
      printf -- '---- end of the Bitwarden items ----\n'
    } >"${RL_KIT}/kit.txt"
    jq -r --argjson names "${kit_items}" \
      '($names | map(ascii_downcase)) - map(.name | ascii_downcase)
       | if length == 0 then "All kit items found" else "Missing: \(join(", "))" end' "${RL_KIT}/items.json"
    jq length "${RL_KIT}/items.json"
    grep -c '^==== ' "${RL_KIT}/kit.txt"
    grep -c '^WARNING' "${RL_KIT}/kit.txt"
    rm "${RL_KIT}/items.json"
    ```

    Every field of a login, an SSH key, a card or an identity item is written out, with its custom fields and notes. The block prints `All kit items found`, then `7` twice (seven items, each in the file once; an `8` means two items share a name, and only one should keep it) and `0` (no item has attachments). A **Missing** line names an item that was renamed or deleted: correct its name in Bitwarden, or this list if the kit's contents changed on purpose, and generate the file again. An item with attachments is reported by name in the file: move what the attachment holds into the item's notes, and generate the file again.

2. **Add Bitwarden's own recovery details,** which are kept out of the vault: with the recovery code, the account signs in without a YubiKey, so it is not left where anyone reading the unlocked vault would find it ([account sign-in setup guide](account-sign-in.md#part-1-the-personal-google-account-microsoft-and-bitwarden)). Open the file with `vim -n -i NONE -c 'setlocal noundofile nobackup nowritebackup' "${RL_KIT}/kit.txt"` (the options keep every copy of the text in memory: `-n` turns off the swap file and `-i NONE` the `viminfo` file, which would save yanked text in the home folder, and the settings turn off undo and backup files, which a `vimrc` may send to a folder on disk), and add these two lines **below the title line**, after a blank line (`gg`, then `o` opens a new line under the title; press **Enter** once for the blank line), so the title stays the first line of the printed kit:

    ```text
    Bitwarden account email: <name>@russetleaf.dev
    Bitwarden two-step login recovery code: <the recovery code>
    ```

    The **recovery code is pasted, not typed:** in the Bitwarden web app, **Settings → Security → Two-step login → View recovery code** (it asks for the master password) shows it; copy it and paste it into the file (**Ctrl+Shift+V** in the terminal, in vim's insert mode). Then copy any harmless text, so the code does not stay on the clipboard.

    **The master password is not added.** The recovery code replaces only the second factor (the YubiKeys); the master password is needed with it, and Bitwarden cannot recover or reset it (its encryption is zero-knowledge). Keeping it only in memory, like the kit passphrase, means a stolen safe gives the thief the recovery code but not the vault. If it is forgotten, the vault is rebuilt in a new Bitwarden account from the latest encrypted vault export ([Part 4](#part-4-the-encrypted-export-of-the-bitwarden-vault)), opened with the kit passphrase, so the two memorized secrets are kept **different**, and only forgetting both loses the vault. The 6-monthly check below confirms both.

3. **Print** the kit file, the `paperkey` file and the public key, on a printer connected by USB or on the main network, straight from memory: `lpstat -p` lists the printers, then

    ```bash
    lp -d <printer> "${RL_KIT}/kit.txt" "${RL_KIT}/gpg-paperkey.txt" "${RL_KIT}/gpg-public-key.asc"
    ```

    The kit file carries the date it was generated on its first page.
4. **Append the GPG key's exports** to the kit file, for the encrypted copy (Part 3), after printing, so the long secret key export is not printed (the `paperkey` printout is its paper form):

    ```bash
    cat "${RL_KIT}/gpg-public-key.asc" "${RL_KIT}/gpg-secret-key.asc" >>"${RL_KIT}/kit.txt"
    ```

5. **Copy to the USB stick** `gpg-public-key.asc`, `gpg-secret-key.asc` and `gpg-paperkey.txt`, check the copies, and unmount the stick, which also finishes writing to it, before removing it:

    ```bash
    kit_usb="/media/${USER}/RL-KIT"
    cp "${RL_KIT}"/gpg-{public-key.asc,secret-key.asc,paperkey.txt} "${kit_usb}/"
    for f in gpg-public-key.asc gpg-secret-key.asc gpg-paperkey.txt; do
      cmp "${RL_KIT}/${f}" "${kit_usb}/${f}" && echo "${f}: copied"
    done
    udisksctl unmount --block-device "$(findmnt -no SOURCE "${kit_usb}")"
    ```

    Each file is reported as copied, and `udisksctl` reports the stick unmounted. If it reports `target is busy`, a program still has the stick open, most often **Files**, which keeps running in the background after its windows close: `fuser -vm "${kit_usb}"` names the program. For Files, select the eject button next to **RL-KIT** in the Files sidebar, which unmounts the stick, or quit Files with `nautilus -q` and run the `udisksctl` line again.
6. **Put in the safe:** the printed pages and `yubikey-backup`; the USB stick follows at the end of Part 4, which adds the vault exports to it. The safe then holds the AWS root password and an MFA device together, which is accepted for a safe (decision log, 2026-11-05).

## Part 3: The encrypted copy in Google Drive and OneDrive

1. **Encrypt the kit file with the memorized passphrase,** using AES-256 and a slow passphrase hash, which makes guessing the passphrase from a stolen copy expensive:

    ```bash
    gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-count 65011712 \
      --output "${RL_KIT}/russetleaf-break-glass-kit.txt.gpg" "${RL_KIT}/kit.txt"
    ```

2. **Prove the passphrase,** after clearing the passphrase that `gpg-agent` has just cached (otherwise the test proves nothing):

    ```bash
    gpgconf --reload gpg-agent
    gpg --decrypt "${RL_KIT}/russetleaf-break-glass-kit.txt.gpg" | head -n 1
    ```

    It prints the kit's title line, and only that line, since the next lines hold Bitwarden's recovery code.

3. **Upload** `russetleaf-break-glass-kit.txt.gpg` to a folder in **Google Drive** and a folder in **OneDrive**, through their web pages. Neither needs sharing with anyone.
4. **Check the uploaded copies:** download the file from Google Drive and from OneDrive (to `~/Downloads`, where the browser names the second one with a number), and compare each with the file decrypted in step 2. A copy with the same bytes decrypts the same way, so the kit's contents never need to be shown on screen:

    ```bash
    for f in ~/Downloads/russetleaf-break-glass-kit*.gpg; do
      cmp "${RL_KIT}/russetleaf-break-glass-kit.txt.gpg" "${f}" && echo "${f}: identical"
    done
    rm ~/Downloads/russetleaf-break-glass-kit*.gpg
    ```

    Two files are reported as identical.

## Part 4: The encrypted export of the Bitwarden vault

This part adds a copy of the **whole vault** that can be read and imported **without Bitwarden**: a plain JSON export, encrypted with GPG and the memorized kit passphrase. The kit file holds only the root credentials, as text for a person to sign in with; the export is the whole vault, with Bitwarden's complete record of each item (its type, password history, saved passkeys and URI settings, and the `Shared accounts` collection), so if Bitwarden's service, apps or account are unavailable for good, GnuPG and the passphrase alone rebuild the vault in one import, into a new Bitwarden account or another password manager, instead of it being typed in again from the printed kit. Bitwarden's own encrypted exports are not used, because both kinds need Bitwarden to read them: an "account restricted" export imports only into the same account, and a "password protected" one into a Bitwarden account. A vault export does not include organization items, so the `Shared accounts` collection is exported separately, as a second file.

1. **Unlock the CLI and sync,** so the export is current (skip this if the CLI is still unlocked from Part 2):

    ```bash
    export BW_SESSION="$(bw unlock --raw)"
    bw sync
    ```

2. **Check for attachments:** a JSON export does not contain file attachments. The command prints how many items have them:

    ```bash
    bw list items | jq '[.[] | select((.attachments // []) | length > 0)] | length'
    ```

    If it is not `0`, keep each attachment's content as a secure note instead (or export the vault in the `zip` format, which includes attachments, to `"${RL_KIT}"` and encrypt that file the same way). Items in the trash and Sends are never exported.

3. **Export and encrypt in one step,** so the plain export is never written to a file: with `--raw` and no output file, `bw` writes the export to standard output, which `gpg` encrypts with the same settings as the kit.

    ```bash
    bw --raw export --format json \
      | gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-count 65011712 \
        --output "${RL_KIT}/russetleaf-vault-export.json.gpg"
    org_id="$(bw list organizations | jq -r '.[] | select(.name == "RussetLeaf") | .id')"
    bw --raw export --format json --organizationid "${org_id}" \
      | gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-count 65011712 \
        --output "${RL_KIT}/russetleaf-shared-export.json.gpg"
    ```

4. **Prove them,** after clearing the cached passphrase: each decrypted export is valid JSON, and the two item counts add up to the number `bw` lists.

    ```bash
    gpgconf --reload gpg-agent
    gpg --decrypt "${RL_KIT}/russetleaf-vault-export.json.gpg" | jq '.items | length'
    gpg --decrypt "${RL_KIT}/russetleaf-shared-export.json.gpg" | jq '.items | length'
    bw list items | jq 'length'
    ```

5. **Store them** next to the kit: upload `russetleaf-vault-export.json.gpg` and `russetleaf-shared-export.json.gpg` to the same Google Drive and OneDrive folders, and check the uploaded copies as in Part 3, step 4 (with `russetleaf-vault-export*.gpg` and `russetleaf-shared-export*.gpg` in place of the kit's name). Then plug in the USB stick, copy both to it, check the copies and unmount it as in Part 2, step 5, and put it in the safe:

    ```bash
    kit_usb="/media/${USER}/RL-KIT"
    cp "${RL_KIT}"/russetleaf-{vault,shared}-export.json.gpg "${kit_usb}/"
    for f in russetleaf-vault-export.json.gpg russetleaf-shared-export.json.gpg; do
      cmp "${RL_KIT}/${f}" "${kit_usb}/${f}" && echo "${f}: copied"
    done
    udisksctl unmount --block-device "$(findmnt -no SOURCE "${kit_usb}")"
    ```

6. **Lock the CLI and clean up:** delete the folder in memory.

    ```bash
    bw lock
    unset BW_SESSION
    rm -rf "${RL_KIT}"
    ```

**Reading the exports without Bitwarden:** on any computer with GnuPG, decrypt each into memory (`gpg --output /dev/shm/vault.json --decrypt russetleaf-vault-export.json.gpg`), read the entries with a text editor or `jq` (for example `jq '.items[] | {name, login}' /dev/shm/vault.json`), and delete the file when done. The same file imports into a new password manager that reads Bitwarden's JSON format, Bitwarden included.

## Checks

- [ ] The secret key export decrypted a test message in a scratch keyring (Part 1, step 3).
- [ ] With `FPR` set to the key's fingerprint, `gpg --list-secret-keys "${FPR}"` in the workstation's own keyring finds **no** key.
- [ ] The encrypted kit decrypts with the memorized passphrase after `gpgconf --reload gpg-agent` (Part 3, step 2), and the copies **downloaded from Google Drive** and **from OneDrive** are identical to it (Part 3, step 4).
- [ ] The kit file holds the seven items and Bitwarden's two recovery lines (no master password), and nothing else from the vault (Part 2, steps 1 and 2).
- [ ] The safe holds the printed pages, the `paperkey` printout, the USB stick and `yubikey-backup`.
- [ ] Bitwarden holds the GPG key's fingerprint, passphrase and public key.
- [ ] Both exports (the vault and the `Shared accounts` collection) decrypt with the memorized passphrase after `gpgconf --reload gpg-agent`, and their item counts add up to the number `bw` lists (Part 4, step 4); the copies downloaded from Google Drive and OneDrive are identical to them, and copies are on the USB stick.
- [ ] `/dev/shm/rl-kit` no longer exists.

## Using the key

For a restore from Cloudflare R2 or the quarterly drill, load the key from the USB stick (or from the encrypted kit) into a keyring in memory, decrypt, then delete the keyring:

```bash
export GNUPGHOME="$(mktemp -d -p /dev/shm)"
gpg --import /media/"${USER}"/RL-KIT/gpg-secret-key.asc
gpg --output mariadb-dump.sql.gz --decrypt mariadb-dump.sql.gz.gpg
gpgconf --kill gpg-agent
rm -rf "${GNUPGHOME}"
unset GNUPGHOME
```

Put the USB stick back in the safe afterwards.

## Keeping the kit current

- **When a kit item changes** (one of the seven items, or Bitwarden's recovery code: for example a replaced YubiKey's PIN, a used or regenerated backup code, a rotated API key; [ADR 1061](../adr/1061-credential-rotation.md)): update Bitwarden, then repeat Part 2, steps 1 to 4, and Part 3 with the GPG exports from the USB stick, replace both cloud copies (see **Replacing a cloud copy** below), and replace the printed kit pages (shredding the old ones). Make a new vault export at the same time (Part 4), replacing the old copies. A change to any other item needs no refresh: it is in Bitwarden at once, and in the next vault export (below).
- **The vault export** is renewed (Part 4, steps 1 to 6) **after each piece of work that adds or changes items** (a plan step, an improvement, a rotation, a new subsystem's credentials: one export at its end, however many items changed), and **quarterly** regardless. The export is what restores the vault if Bitwarden is lost or the memorized master password is forgotten, so a change not yet exported would have to be redone; the new exports replace the old ones in both cloud folders (see below) and on the USB stick.
- **Replacing a cloud copy** (a refreshed kit, new vault exports, a new router configuration backup): **delete the old file first**, then upload the new one, since uploading over a file can keep the old one as an earlier version; then delete the old file from the trash too, where both services otherwise keep it for 30 days, so a superseded copy does not linger:
    - **Google Drive** (`drive.google.com`): in the folder, select the file and delete it; then **Trash** in the left panel, select the file, and **Delete forever** (**Empty trash** deletes everything in the trash).
    - **OneDrive** (`onedrive.live.com`): in the folder, select the file and delete it; then **Recycle bin** in the left navigation, select the file, and **Delete** at the top (**Empty recycle bin** deletes everything in it).
- **Every 6 months** (in May and November, by the [exercise program](../../exercises.md#calendar)'s calendar): confirm both memorized secrets, signing in to the Bitwarden web app with the master password typed (not filled in) and decrypting the cloud copies with the kit passphrase; download both cloud copies and decrypt them after `gpgconf --reload gpg-agent`, check the GPG key's expiry date (`gpg --show-keys gpg-public-key.asc`), and check the kit for **drift** from Bitwarden: generate a fresh kit file (Part 2, step 1, after the setup lines in [Before starting](#before-starting)), and compare its Bitwarden items with the cloud copy's, without printing either:

    ```bash
    items='/^==== /,/^---- end of the Bitwarden items ----$/p'
    gpg --decrypt russetleaf-break-glass-kit.txt.gpg | sed -n "${items}" >"${RL_KIT}/kit-cloud.txt"
    sed -n "${items}" "${RL_KIT}/kit.txt" >"${RL_KIT}/kit-now.txt"
    cmp -s "${RL_KIT}/kit-cloud.txt" "${RL_KIT}/kit-now.txt" && echo "The kit is current" || echo "The kit is stale: refresh it"
    ```

    A stale kit means a refresh was missed: refresh it as above.
- **Renew the GPG key** at least a month before it expires: load it as in [Using the key](#using-the-key), run `gpg --quick-set-expire "${FPR}" 2y` and `gpg --quick-set-expire "${FPR}" 2y '*'`, and export the public key, the secret key and the `paperkey` file again (Part 1, step 2). Update the public key in Bitwarden and in the cluster's backup job (step 2.5), replace the files on the USB stick and the printout, and refresh the kit (Part 2, steps 1 to 4, and Part 3). The key and its fingerprint do not change, so existing backups still decrypt.

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
- **The kit may be exposed, or the safe is stolen:** follow the [break-glass kit compromise runbook](../../runbooks/break-glass-kit-compromise.md).
- **The Google or Microsoft account is compromised:** the copy stays protected by the passphrase. Secure the account, then make a new copy with a new passphrase, and change the most important items in it (the AWS root password, the Bitwarden master password, the GPG key) if the passphrase could have been weak or seen.

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- GnuPG: ["OpenPGP Key Management"](https://gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html), checked 2026-11-12
- GnuPG: ["Operational GPG Commands (export and symmetric encryption)"](https://gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html), checked 2026-11-12
- GnuPG: ["OpenPGP Options (the s2k options)"](https://gnupg.org/documentation/manuals/gnupg/OpenPGP-Options.html), checked 2026-11-12
- GnuPG: ["Invoking GPG-AGENT"](https://gnupg.org/documentation/manuals/gnupg/Invoking-GPG_002dAGENT.html), checked 2026-11-12
- GnuPG: ["Invoking gpgconf"](https://gnupg.org/documentation/manuals/gnupg/Invoking-gpgconf.html), checked 2026-11-12
- `paperkey`: ["Paperkey - an OpenPGP key archiver"](https://www.jabberwocky.com/software/paperkey/), checked 2026-11-12
- Yubico: ["Importing keys (keytocard)"](https://developers.yubico.com/PGP/Importing_keys.html), checked 2026-11-12
- Yubico: ["OpenPGP Commands (YubiKey Manager CLI)"](https://docs.yubico.com/software/yubikey/tools/ykman/OpenPGP_Commands.html), checked 2026-11-12
- Google: ["Delete files in Google Drive"](https://support.google.com/drive/answer/2375102?hl=en&co=GENIE.Platform%3DDesktop) (the trash, **Delete forever**), checked 2026-11-24
- Microsoft: ["Delete files or folders in OneDrive"](https://support.microsoft.com/en-us/onedrive/delete-files-or-folders-in-onedrive) (the recycle bin), checked 2026-11-24
- Bitwarden: ["Forgot My Master Password"](https://bitwarden.com/help/forgot-master-password/) (zero-knowledge: the master password cannot be reset) and ["Two-step Login Recovery Code"](https://bitwarden.com/help/two-step-recovery-code/), checked 2026-11-23
- Bitwarden: ["Managing Items"](https://bitwarden.com/help/managing-items/) and ["Custom Fields"](https://bitwarden.com/help/custom-fields/), checked 2026-11-18
- Bitwarden: ["Export Vault Data"](https://bitwarden.com/help/export-your-data/), checked 2026-11-13
- Bitwarden: ["Encrypted Exports"](https://bitwarden.com/help/encrypted-export/), checked 2026-11-13
- Bitwarden: ["Password Manager CLI"](https://bitwarden.com/help/cli/) (and `bw export --help`, version 2026.10.1: `--raw` with no output file writes to standard output), checked 2026-11-13
- CUPS: ["cupsd.conf"](https://www.cups.org/doc/man-cupsd.conf.html) (`PreserveJobFiles`: the default keeps job files for one day), and `man cupsd.conf` for CUPS 2.4.7 on Ubuntu 24.04, checked 2026-11-18
- udisks: ["udisksctl"](https://storaged.org/doc/udisks2-api/latest/udisksctl.1.html) (`unmount`), and `man udisksctl` for udisks 2.10.1 on Ubuntu 24.04, checked 2026-11-18
- GNOME Help: ["Set up a local printer"](https://help.gnome.org/users/gnome-help/stable/printing-setup.html) (GNOME Help 46, installed with Ubuntu 24.04), checked 2026-11-18
- Google: ["Upload files & folders to Google Drive"](https://support.google.com/drive/answer/2424368), checked 2026-11-12
- Microsoft: ["Upload and save files and folders to OneDrive"](https://support.microsoft.com/en-us/onedrive/upload-and-save-files-and-folders-to-onedrive), checked 2026-11-12
