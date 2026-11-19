# Runbook: break-glass kit compromised

**Note:** the click paths in this runbook come from each provider's documentation, checked on the dates in [References](#references). Providers change their consoles without notice, and their own documentation can lag behind the console. Where a provider's documentation does not name a button, the step says so: record the label the screen shows at the first drill, and fix the step. During an incident, follow what the screen shows.

## Summary

The **break-glass kit** holds every credential the project needs to regain access: the passwords, recovery codes and authenticator keys of every account, Bitwarden's master password and two-step login recovery code, the machine credentials in the project's vault, and the GPG key that decrypts the backup copies in Cloudflare R2 ([disaster recovery plan](../phase-1-russetleaf-dev/disaster-recovery.md#break-glass-kit), [break-glass kit setup guide](../phase-1-russetleaf-dev/setup/break-glass-kit.md)). This runbook is for any exposure of the kit. Its worst case is the **theft of the safe**, which takes the printed kit, the USB stick with the GPG key, and `yubikey-backup` with its PIN (in the kit) together, so the thief holds a password and a second factor for almost every account.

The response follows the incident response life cycle of NIST SP 800-61 Rev. 3, which maps it onto the CSF 2.0 Functions: **Detect** (the exposure is found and its scope estimated), **Respond** (the incident is managed, analyzed, reported and mitigated: contained, then eradicated), **Recover** (restoration, verified, then the end of recovery declared), and **Improvement** (lessons learned). Containment comes first and in order of **blast radius**: the accounts that can reset others (Bitwarden, then the two Google Accounts, whose mailboxes receive every other account's resets) before the rest. NIST SP 800-63B-4, section 4.5, adds the rule for the stolen key: a compromised authenticator is invalidated promptly, since "the consequences of not invalidating a compromised authenticator are usually more significant than the denial-of-service potential of invalidating one in error."

The rule for when credentials change is [ADR 1061](../phase-1-russetleaf-dev/adr/1061-credential-rotation.md): an exposed kit changes every password in it, and the kit passphrase.

## Symptoms

- The safe is missing, opened or damaged, or the home was broken into.
- The printed kit, the USB stick or `yubikey-backup` is missing from the safe, or was seen, photographed or handled by someone else.
- A decrypted copy of the kit file, or of a vault export, may have been left on a disk, in a download folder or on another computer, or the kit passphrase may have been seen or typed on an untrusted computer.
- An account in the kit sends an unexpected alert: a new sign-in, a changed password, a removed or added security key, recovery codes viewed or regenerated, or Advanced Protection or two-step login changed.

## Impact

| Exposed | What it gives | Severity |
|---|---|---|
| The **safe** (printed kit, USB stick and `yubikey-backup`) | A password and a second factor (the key and its PIN) for every account that takes security keys; Bitwarden's master password and recovery code; recovery codes and authenticator keys for the rest; every machine credential in the vault; the GPG key and its passphrase | SEV1 |
| The **printed kit** only, or a decrypted kit file | The same, except the second factor: accounts with security keys still need a YubiKey, but each one's recovery codes bypass it | SEV1 |
| The **kit passphrase** only, with the cloud copies intact | Nothing until a cloud copy is also obtained; then the same as the kit | SEV2 |
| The **USB stick** only | The GPG key's secret part, still encrypted with its passphrase (in the kit), and the vault exports, still encrypted with the kit passphrase | SEV2 |

The severities are those of the planned incident response runbook (`docs/runbooks/incident-response.md` in `russetleaf-gitops`). The steps below assume the worst case; for a lesser exposure, skip the steps for what was not exposed (for example, the YubiKey steps when only a decrypted file leaked).

## Checks

1. **Record the start:** the date and time the exposure was found, the last time the kit was known to be safe, and what is missing or exposed (NIST SP 800-61r3, RS.MA-02 and RS.AN-06: the facts and every action are recorded as they happen). Keep the record on paper or in a file on the workstation, not in a service that may be compromised. Every step below adds its time and outcome to it.
2. **Decide which computer is trusted:** the workstation, if it was not taken and shows no sign of tampering. If it was taken too, use another computer with a fresh browser profile, and treat the workstation as retired ([workstation YubiKey setup guide](../phase-1-russetleaf-dev/setup/workstation-yubikey.md#a-second-or-replacement-workstation), step 3).
3. **Have `yubikey-primary` at hand,** with its PIN. Every account is secured with it, and it becomes each account's only security key until a replacement arrives.
4. **Order a replacement YubiKey** (a Security Key NFC, or a YubiKey 5 series key, which can also hold the GPG key later: [improvement I1-1](../phase-1-russetleaf-dev/improvements.md)) at once, so the accounts have a second key again as soon as possible.
5. **Report a theft to the police,** for the insurance claim and the record (NIST SP 800-61r3, RS.CO-02, R5). Do not wait for the report before starting the fixes.

## Likely causes

- A burglary or a theft of the safe.
- The printed kit handled outside the safe (during a refresh) and left where others could see it.
- A decrypted kit file or vault export left behind after a drill, outside `/dev/shm`.
- The kit passphrase typed where it could be recorded.

## Fixes

Work through the parts in order: each secures the account that the later ones depend on. In each part, the **Bitwarden item** to update is named first; update it as each value changes, so the vault stays current. Bitwarden is the project's own account, opened on the trusted computer.

### Part 1: Bitwarden

Bitwarden holds the working copy of everything else, and the thief holds its master password, its recovery code and a registered key. Changing the master password locks the thief out of new sign-ins; the recovery code cannot be replaced directly, since Bitwarden generates a new one only when the old one is used, so it is used on purpose.

1. **Sign in** to the web app (`https://vault.bitwarden.com`) with the master password and `yubikey-primary`.
2. **Check the devices:** **Settings → Security → Devices** lists each device with **Recently active** and **First login**. Note any device that is not the operator's in the record: it means the vault was opened by someone else.
3. **Change the master password:** **Settings → Security → Master password**, then **Current master password**, a new passphrase generated in Bitwarden's generator (memorized, never saved in the vault) in **New master password** and its confirmation, and **Change master password**. Bitwarden signs the web app out at once; other signed-in apps may stay active for up to an hour. Leave the box that also rotates the account's encryption key cleared, unless step 2 found a device that is not the operator's, which means the vault's encryption key may have been obtained: then first log out of every other Bitwarden app (the desktop app, the browser extension, the phone), since Bitwarden warns that changes made in a session with the old key corrupt the vault beyond recovery, and tick that box. The kit's vault exports are plain JSON encrypted with GPG, so a new key does not affect them ([References](#references)).
4. **Replace the recovery code by using it:** at `https://vault.bitwarden.com/#/recover-2fa/`, enter the account email, the **new** master password and the current recovery code (shown under **Settings → Security → Two-step login → View recovery code**), and select **Submit**. Bitwarden turns off every two-step login method, which removes both keys, signs in, and generates a new recovery code. The thief's copy of the old code is then useless, and so is `yubikey-backup`.
5. **Register `yubikey-primary` again at once:** **Settings → Security → Two-step login**, the **Passkey** option, **Manage** (it asks for the master password), the **Name** `yubikey-primary`, **Read Key** (touch the key, with its PIN), **Save** and **Close**. Then log out and log in once with it.
6. **Note the new recovery code** in the incident record's sealed part, or leave it in Bitwarden to copy into the new kit (Part 15); it is never saved in the vault.
7. **Rotate the API key:** **Settings → Security → Keys → View API key** (it asks for the master password), then **Rotate API Key**. Only the `client_secret` changes, and the CLI sessions using the old one end. Update the item `Bitwarden - RussetLeaf API key`, then sign the CLI in again in the project's data folder: `bw logout`, then `bw login --apikey`.
8. **Check the organization:** in the `RussetLeaf` organization, the members are still the project account (Owner) and the operator's personal account, and the `Shared accounts` collection holds its five items.

### Part 2: Google Workspace

The Workspace account receives every service's mail, AWS root's included, and is the project's Google sign-in. **Bitwarden item:** the Workspace account's item.

1. **Remove `yubikey-backup`:** in the Admin console, **Menu → Directory → Users**, select the operator's account, then **Security** at the top. Select the **Passkeys & security keys** section to show the table, scroll to the right, hover over the `yubikey-backup` row, select **Remove**, then **Remove** again, and **Done**.
2. **Change the password:** on the same page, **Password → Reset Password**, enter a password generated in Bitwarden, and **Reset**, then **Done**. Update the item's password.
3. **Sign the account out everywhere:** on the same page, **Sign-in cookies → Reset**, then **Done**. The account is signed out of every device and browser; Gmail sessions can take up to an hour to end. Sign in again on the trusted computer with `yubikey-primary`.
4. **Replace the backup codes:** on the same page, **2-Step Verification → Get backup verification codes**, then **Generate new codes**; the old set stops working. Replace the codes in the item's notes.
5. **Review the sign-ins:** **Menu → Reporting → Audit and investigation → User log events**, with the time range set to begin at the last time the kit was known to be safe (the default is the last 7 days). Note every sign-in that is not the operator's, and any change to 2-step verification, recovery details or Advanced Protection. **Recovery information** on the account's **Security** page still shows the personal Google Account and the operator's phone.

### Part 3: The personal Google Account

It is the Workspace account's recovery email, the Cloudflare sign-in, and the Google Drive copy of the kit. **Bitwarden item:** the personal Google Account's item in `Shared accounts`.

1. **Remove `yubikey-backup`:** in the Google Account, **Security & sign-in**, then, in the "**How you sign in to Google**" panel, **Passkeys and security keys**; next to `yubikey-backup`, select **Edit**, then **Remove this key**. Advanced Protection keeps working with `yubikey-primary` alone; register the replacement as soon as it arrives (Part 14).
2. **Change the password:** **Security & sign-in**, then **Password** under "**How you sign in to Google**"; enter a password generated in Bitwarden, and **Change Password**. Google signs the account out everywhere except the device used to confirm it. Update the item's password.
3. **Review the devices:** **Security & sign-in**, then **Manage all devices** under "**Your devices**"; select any device that is not the operator's and **Sign out**. Note it in the record.
4. **Check the recovery details:** the recovery phone and recovery email on the **Security & sign-in** page are still the operator's.

### Part 4: AWS root

**Bitwarden item:** the AWS root item.

1. **Sign in as the root user** with the root email, the password and `yubikey-primary`.
2. **Remove `yubikey-backup`:** the account name at the top right, then **Security credentials** (and **Continue to Security credentials** if asked). In **Multi-factor authentication (MFA)**, select the `yubikey-backup` device, then **Remove**, and **Remove** again. AWS emails the root address to confirm.
3. **Change the password:** the account name, then **Security credentials**; on the **Account** page, next to **Account settings**, select **Edit** and sign in again; under **Password**, select **Edit**, fill in **Current password**, **New password** (generated in Bitwarden) and **Confirm new password**, and select **Save changes**. Update the item's password. AWS's documentation does not say whether this ends other root sessions.
4. **Check the access keys:** the **Access keys** section of the same page is still empty.
5. **Review root activity:** in **CloudTrail → Event history**, remove the default **Read-only: false** filter, choose **Event name** under **Lookup attributes** with the value `ConsoleLogin`, and set the time range to begin at the last time the kit was known to be safe. Event history keeps 90 days. Note every root sign-in that is not the operator's; if there is one, follow the [disaster recovery plan](../phase-1-russetleaf-dev/disaster-recovery.md#scenarios) ("Management account compromised or lost") as well.
6. **After step 2.0:** also remove `yubikey-backup` from the operator's IAM Identity Center user, and follow the planned `docs/runbooks/lost-access.md` for the Identity Center break-glass login.

### Part 5: Microsoft

It holds the OneDrive copy of the kit. **Bitwarden item:** the Microsoft item in `Shared accounts`.

1. **Remove `yubikey-backup`:** on the security settings page (`https://account.live.com/proofs/manage/additional`), under "**Ways to prove who you are**", find `yubikey-backup` and select **Remove**, then confirm. Microsoft's documentation shows **Remove** only for phone, authenticator app and email methods; record the label shown for a security key at the first drill.
2. **Change the password:** to a password generated in Bitwarden, from the same account's security settings. Microsoft's documentation page for this was not available when this runbook was written; record the path at the first drill. Update the item's password.
3. **Replace the recovery code:** on the same page, in the **Recovery code** section, select **Generate a new code**; the previous code stops working. Replace it in the item.
4. **Sign out everywhere and review the activity:** Microsoft offers **Sign out everywhere** and a **Recent activity** page from the account's security settings; their help pages were not available when this runbook was written, so record the paths at the first drill. Note any sign-in that is not the operator's.

### Part 6: GitHub

**Bitwarden item:** the GitHub item in `Shared accounts`.

1. **Remove `yubikey-backup`:** the profile picture, **Settings**, then **Password and authentication** under **Access**; in **Two-factor methods**, under **Security keys**, remove `yubikey-backup`. GitHub's documentation covers adding a key but not removing one; record the labels at the first drill.
2. **Delete its SSH key:** **Settings → SSH and GPG keys**; under **SSH keys**, select **Delete** next to `workstation yubikey-backup <year>`.
3. **Change the password:** **Settings → Password and authentication**; under **Change password**, enter the old password and a new one generated in Bitwarden, twice, and select **Update password**. Update the item's password.
4. **Replace the recovery codes:** on the same page, next to **Recovery codes**, select **View**, then **Generate new recovery codes**; the old codes stop working. Replace them in the item's notes.
5. **Revoke other sessions:** **Settings → Sessions**; for each web session that is not the current one, select **See more**, then **Revoke session**.
6. **Review the security log:** **Settings → Security log** (under **Archives**), which covers the last 90 days; filter with `operation:authentication`. Note anything the operator did not do, such as a new SSH key, token, OAuth app or change to two-factor authentication, and undo it.

### Part 7: GitLab

**Bitwarden item:** the GitLab item in `Shared accounts`.

1. **Remove `yubikey-backup`:** the avatar, **Edit profile**, then **Access → Password and authentication**; in the **WebAuthn devices** section, remove `yubikey-backup`. GitLab's documentation says devices can be removed one at a time but does not name the control; record it at the first drill. Do **not** select **Disable 2FA**, which removes every factor.
2. **Delete its SSH key:** **Edit profile → Access → SSH keys**; next to `workstation yubikey-backup <year>`, select **Remove**, then **Delete**. (**Revoke** applies to signing keys and would mark commits as unverified.)
3. **Change the password:** **Edit profile → Access → Password and authentication → Change password**; fill in **Current password**, **New password** (generated in Bitwarden) and **Password confirmation**, and select **Save password**. Update the item's password.
4. **Replace the recovery codes:** on the same page, in **Recovery codes**, select **Regenerate recovery codes**, enter the password, and select **Regenerate recovery codes** again; the old codes stop working. Replace them in the item's notes.
5. **Revoke other sessions:** **Edit profile → Access → Active sessions**; select **Revoke** next to every session except the current one.
6. **The mirror token** is replaced in Part 12.

### Part 8: Cloudflare

Cloudflare's Google sign-in is protected again by Part 3; this part covers its password sign-in and its own second factor. **Bitwarden item:** the Cloudflare item.

1. **Remove `yubikey-backup`:** **My Profile → Authentication**; in the **Security Key Authentication** card, select **Edit**, then **Delete** next to `yubikey-backup`, enter the password, and select **Remove**.
2. **Change the password:** **My Profile → Authentication**; on **Password**, select **Change Password**, enter a password generated in Bitwarden, and **Save**. Update the item's password.
3. **Replace the backup codes:** **My Profile → Authentication**; for **Two-Factor Authentication**, select **Manage**, then, for **Backup codes**, **Regenerate**; the old codes stop working. Replace them in the item's notes.
4. **Revoke other sessions:** **My Profile → Sessions**; select **Revoke** on each session that is not the current one, entering the password when asked.
5. **Roll any API tokens:** **My Profile → API Tokens**; for each token, the three-dot menu, **Roll**, then **Confirm**, and update wherever it is stored.
6. **Review the audit log:** **Manage Account → Audit Logs** (`https://dash.cloudflare.com/?to=/:account/audit-log`), searching by the user email over the time since the kit was last known safe (the dashboard shows the last 90 days). Undo any change the operator did not make, checking in particular DNS records, Registrar settings for russetleaf.dev (transfer lock, DNSSEC) and members.

### Part 9: Slack

Slack's second factor is an authenticator code, whose backup codes are in the kit. **Bitwarden item:** the Slack item.

1. **Change the password:** at `https://my.slack.com/account`, next to **Password**, select **Expand**, then "**Reset your password by email**", and follow the link sent to the Workspace address (secured in Part 2), with a password generated in Bitwarden. Slack's documentation describes only this reset, not a change with the current password. Update the item's password.
2. **Sign out other sessions:** on the same page, select **Sign out all other sessions**.
3. **Replace the backup codes:** Slack's documentation does not describe replacing them. At `https://my.slack.com/account/settings`, next to **Two-factor Authentication**, select **Expand** and use what the page offers to set up the authenticator again (which issues new backup codes), or, if it offers nothing, ask Slack support; record the labels at the first drill. Replace the authenticator entry in Google Authenticator and the backup codes in the item's notes.
4. **Review the access logs:** at `https://my.slack.com/account`, select **Access Logs** at the top right. Note any session that is not the operator's.
5. **The bot token** is replaced in Part 12.

### Part 10: Better Stack

Better Stack signs in with a link emailed to the Workspace address, secured in Part 2, so the kit's exposure affects only its authenticator key and recovery codes. **Bitwarden item:** the Better Stack item.

1. **Sign in** with a new sign-in link and the current authenticator code.
2. **Replace the authenticator key and recovery codes:** **Settings → Security** (`https://betterstack.com/settings/security`). Better Stack's documentation describes only **Enable two-factor authentication**, not turning it off or replacing the codes; turn two-factor authentication off and on again with what the page offers, add the new key to Google Authenticator (deleting the old entry), and replace the recovery codes in the item's notes. Record the labels at the first drill.
3. **Test:** log out, and log in with a new link and the new code.

### Part 11: healthchecks.io

**Bitwarden item:** the healthchecks.io item.

1. **Remove `yubikey-backup`:** **Settings**, the **Account** tab; in **Two-factor Authentication**, under **Security keys**, select **Remove** next to `yubikey-backup`, then **Remove Security Key**.
2. **Change the password:** in **Email and Password**, select **Change Password**, enter a password generated in Bitwarden, and select **Set Password**. Update the item's password.
3. healthchecks.io has no page to review or end other sessions. Check that the account's projects, and each project's checks and integrations are as expected.

### Part 12: Machine credentials

1. **The GitLab mirror token** (item `Gitlab - russetleaf/russetleaf-docs Personal Access Token`, one per mirrored repo): in GitLab, **Edit profile → Access → Personal access tokens**; next to the token, the vertical ellipsis, **Rotate**, then **Rotate** in the dialog. The old token stops working at once. (GitLab documents rotation for personal access tokens on its legacy token page; if a fine-grained token offers no **Rotate**, revoke it and create a new one as in the [GitLab group setup guide](../phase-1-russetleaf-dev/setup/gitlab-group.md#part-4-create-the-token-for-each-repo), Part 4.) Update the item, then the repo's Actions secret, without showing the token:

    ```bash
    export BW_SESSION="$(bw unlock --raw)"
    ```

    ```bash
    bw get password "<item name>" | gh secret set GITLAB_PAT --repo russetleaf/russetleaf-docs
    gh workflow run "Backup to GitLab" --repo russetleaf/russetleaf-docs
    ```

    The run succeeds, which shows the new token works. `gh secret set` replaces a secret of the same name (GitHub's API creates or updates it).
2. **The Slack bot token** (item `Slack - bot token for russetleaf`): revoke it, which also deactivates the bot and removes it from its channels, then install the app again for a new one:

    ```bash
    curl -sS -H "Authorization: Bearer $(bw get password '<item name>')" https://slack.com/api/auth.revoke
    ```

    The response shows `"revoked": true`. In the app's settings (`https://api.slack.com/apps`, `russetleaf-bot`), open **Install App** and install it to the workspace again; the new **Bot token** is under **OAuth Tokens** on **OAuth & Permissions**. Update the item, add the bot to every channel again ([Slack setup guide](../phase-1-russetleaf-dev/setup/slack-and-monitoring.md#part-2-the-bot-russetleaf-bot), Part 2, step 3), and post a test message as in that guide's checks.
3. **Credentials added in later steps** are replaced by the planned `docs/runbooks/credential-leak.md`, from the credential inventory (step 4.2). Until that runbook is written, the table lists them:

    | Credential | Added in | Replaced by |
    |---|---|---|
    | Google OAuth client secrets | Step 4.7 | A new secret in the Google Cloud console, then the Secrets Manager entry |
    | OpenTofu state passphrase | Step 2.0 | [ADR 1054](../phase-1-russetleaf-dev/adr/1054-opentofu-state-and-plan-encryption.md): a new passphrase, with the previous one kept for 12 months |
    | Scoped IAM access keys | Step 2.0 | A new key, then deleting the old one |
    | Talos secrets bundle and break-glass kubeconfig | Step 2.2 | The planned `docs/runbooks/rotate-cluster-ca.md` |

### Part 13: The GPG key

The thief holds the secret key (on the USB stick and the `paperkey` page) and its passphrase (in the kit), so the key is replaced. It was never published to a keyserver, so there is nothing to revoke publicly: what matters is that nothing new is encrypted to it.

1. **Create a new key** with the [break-glass kit setup guide](../phase-1-russetleaf-dev/setup/break-glass-kit.md#part-1-create-the-gpg-key), Part 1, in a new item; rename the old item by adding `(compromised <date>)` to its name.
2. **After step 2.5,** give the new public key to the cluster's backup job, and make a fresh copy to Cloudflare R2. The R2 copies encrypted to the old key can be read by anyone with both the old key and access to the bucket: replace the R2 credentials, and delete the old copies once fresh ones exist, rather than waiting for them to expire (35 days).
3. **Delete the old item** once no copy encrypted to the old key remains.

### Part 14: The workstation and the YubiKeys

1. **The login password** (the Ubuntu workstation's item): change it with `passwd`, to a password generated in Bitwarden, and update the item.
2. **The disk encryption passphrase,** if the disk is encrypted (the same item): find the encrypted partition with `lsblk -o NAME,TYPE,FSTYPE` (the one with `crypto_LUKS`), and change the passphrase with `sudo cryptsetup luksChangeKey /dev/<partition>`, entering the old one, then a new one of six or more random words. Update the item.
3. **`sudo` and the SSH keys:** remove `yubikey-backup` from the workstation as for a lost key, the other way round: delete `~/.ssh/id_ed25519_sk_backup_*` and its `IdentityFile` line in `~/.ssh/config`, and rebuild `/etc/u2f_mappings` with `yubikey-primary` only ([workstation YubiKey setup guide](../phase-1-russetleaf-dev/setup/workstation-yubikey.md), Part 2, step 3). Its SSH keys were deleted from GitHub and GitLab in Parts 6 and 7.
4. **The Git signing key's passphrase** (item `Workstation RussetLeaf Git signing key`): the key file never left the workstation, but its passphrase was in the kit. Change it with `ssh-keygen -p -f ~/.ssh/id_ed25519_russetleaf_git_signing`, and update the item.
5. **The PIN of `yubikey-primary`** (item `YubiKey PINs`): change it with `ykman fido access change-pin`, which asks for the current and the new PIN, so neither appears in the shell history. Update the item.
6. **The replacement key,** when it arrives: set its PIN with `ykman fido access change-pin`, add it to the `YubiKey PINs` item, and register it as `yubikey-backup` everywhere the old one was removed, following each account's setup guide: Bitwarden, the two Google Accounts, Microsoft, GitHub, GitLab, Cloudflare and healthchecks.io ([account sign-in setup guide](../phase-1-russetleaf-dev/setup/account-sign-in.md), [Google Workspace setup guide](../phase-1-russetleaf-dev/setup/google-workspace.md#part-3-the-accounts-sign-in)), AWS root ([AWS management account setup guide](../phase-1-russetleaf-dev/setup/aws-management-account.md#part-1-create-the-account-step-01), Part 1, step 7), and the workstation's SSH keys and `sudo` ([workstation YubiKey setup guide](../phase-1-russetleaf-dev/setup/workstation-yubikey.md)). Test each sign-in with each key on its own.

### Part 15: A new kit

1. **Choose a new kit passphrase** ([break-glass kit setup guide](../phase-1-russetleaf-dev/setup/break-glass-kit.md#before-starting)), since the old one may have been exposed with the kit, and memorize it.
2. **Make the kit again** with the setup guide, Parts 2 to 4, with Bitwarden's new master password and recovery code, a new USB stick, and the new GPG key. Delete the old cloud copies of the kit and the vault exports from Google Drive and OneDrive.
3. **Keep the safe somewhere new,** or change its combination, and put in it the new printed kit, the new USB stick and the replacement `yubikey-backup`.

### Part 16: Close the incident

1. **Check that recovery is complete** (NIST SP 800-61r3, RC.RP-05): every account in the kit signs in with each YubiKey on its own, the vault's items match the new values, the [break-glass kit setup guide](../phase-1-russetleaf-dev/setup/break-glass-kit.md#checks) checks pass, and the reviews in Parts 1 to 11 found no change still in place that the operator did not make.
2. **Write the after-action report** (RC.RP-06): the timeline from the record, what was exposed, what was changed and when, anything found in the logs, and the lessons learned (the Improvement Category, ID.IM), with each fix to this runbook or another document made in the same change.
3. **Update the runbook index:** record the date under **Rehearsed** in the [runbook index](../runbooks.md), and fix every step whose labels were recorded during the response.

## Escalation

- **An account cannot be secured,** because the thief changed its password or second factor first: use the provider's account recovery, as described in each guide's "If something goes wrong" section ([account sign-in](../phase-1-russetleaf-dev/setup/account-sign-in.md#if-something-goes-wrong), [Google Workspace](../phase-1-russetleaf-dev/setup/google-workspace.md#if-something-goes-wrong), [AWS management account](../phase-1-russetleaf-dev/setup/aws-management-account.md#if-something-goes-wrong)), and contact the provider's support.
- **An account shows activity the operator did not perform:** the incident is an account takeover as well as an exposure; follow the planned `docs/runbooks/credential-leak.md` for what that account could reach, and the [disaster recovery plan](../phase-1-russetleaf-dev/disaster-recovery.md#scenarios) for AWS.
- **Personal data may have been reached** (once the site holds any): the planned `docs/runbooks/personal-data-breach.md`, which has a 72-hour notification deadline.

## Related

- [Break-glass kit setup guide](../phase-1-russetleaf-dev/setup/break-glass-kit.md) and the [disaster recovery plan](../phase-1-russetleaf-dev/disaster-recovery.md#break-glass-kit)
- [ADR 1061](../phase-1-russetleaf-dev/adr/1061-credential-rotation.md) (credential rotation on events) and [ADR 1056](../phase-1-russetleaf-dev/adr/1056-aws-root-mfa-two-security-keys.md) (the two security keys)
- [Account sign-in setup guide](../phase-1-russetleaf-dev/setup/account-sign-in.md) and [workstation YubiKey setup guide](../phase-1-russetleaf-dev/setup/workstation-yubikey.md)
- [Runbook index](../runbooks.md)

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- NIST: ["Incident Response Recommendations and Considerations for Cybersecurity Risk Management: A CSF 2.0 Community Profile (SP `800-61r3`)"](https://doi.org/10.6028/NIST.SP.800-61r3), April 2025 (section 2.1, the life cycle model; Table 3, the Respond and Recover categories), checked 2026-11-18
- NIST: ["Digital Identity Guidelines: Authentication and Authenticator Management (SP `800-63B-4`)"](https://pages.nist.gov/800-63-4/sp800-63b.html) (section 4.5, invalidation), checked 2026-11-18
- Bitwarden: ["Your Master Password"](https://bitwarden.com/help/master-password/), checked 2026-11-18
- Bitwarden: ["Account Encryption Key"](https://bitwarden.com/help/account-encryption-key/), checked 2026-11-18
- Bitwarden: ["Recovery Code for Two-Step Login"](https://bitwarden.com/help/two-step-recovery-code/), checked 2026-11-18
- Bitwarden: ["Passkey Two-Step Login"](https://bitwarden.com/help/setup-two-step-login-fido/), checked 2026-11-18
- Bitwarden: ["CLI Authentication via API Key"](https://bitwarden.com/help/personal-api-key/), checked 2026-11-18
- Bitwarden: ["Manage Devices"](https://bitwarden.com/help/manage-devices/), checked 2026-11-18
- Google: ["Manage a user's security settings"](https://knowledge.workspace.google.com/admin/security/manage-a-users-security-settings) (security keys, password, sign-in cookies, backup codes), checked 2026-11-18
- Google: ["User log events"](https://knowledge.workspace.google.com/admin/reports/user-log-events), checked 2026-11-18
- Google: ["Lost security key (Advanced Protection)"](https://support.google.com/accounts/answer/7539956), checked 2026-11-18
- Google: ["Change or reset your password"](https://support.google.com/accounts/answer/41078), checked 2026-11-18
- Google: ["Find, secure, or sign out of devices"](https://support.google.com/accounts/answer/3067630), checked 2026-11-18
- AWS: ["Deactivate an MFA device"](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_disable.html), checked 2026-11-18
- AWS: ["Change the password for the root user"](https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-password.html), checked 2026-11-18
- AWS: ["Working with CloudTrail event history"](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events-console.html), checked 2026-11-18
- Microsoft: ["How to help keep your Microsoft account secure"](https://support.microsoft.com/en-us/account-billing/how-to-help-keep-your-microsoft-account-secure-628538c2-7006-33bb-5ef4-c917657362b9), checked 2026-11-18
- Microsoft: ["How to get a Microsoft account recovery code"](https://support.microsoft.com/en-us/accounts-billing/manage/how-to-get-a-microsoft-account-recovery-code), checked 2026-11-18
- GitHub: ["Updating your GitHub access credentials"](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/updating-your-github-access-credentials), checked 2026-11-18
- GitHub: ["Configuring two-factor authentication recovery methods"](https://docs.github.com/en/authentication/securing-your-account-with-two-factor-authentication-2fa/configuring-two-factor-authentication-recovery-methods), checked 2026-11-18
- GitHub: ["Viewing and managing your sessions"](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/viewing-and-managing-your-sessions), checked 2026-11-18
- GitHub: ["Reviewing your security log"](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/reviewing-your-security-log), checked 2026-11-18
- GitHub: ["Reviewing your SSH keys"](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/reviewing-your-ssh-keys), checked 2026-11-18
- GitHub: ["`gh secret set`"](https://cli.github.com/manual/gh_secret_set), checked 2026-11-18
- GitLab: ["Two-factor authentication"](https://docs.gitlab.com/user/profile/account/two_factor_authentication/) and ["Troubleshooting two-factor authentication (recovery codes)"](https://docs.gitlab.com/user/profile/account/two_factor_authentication_troubleshooting/), checked 2026-11-18
- GitLab: ["Passwords"](https://docs.gitlab.com/user/profile/user_passwords/), checked 2026-11-18
- GitLab: ["Active sessions"](https://docs.gitlab.com/user/profile/active_sessions/), checked 2026-11-18
- GitLab: ["Personal access tokens"](https://docs.gitlab.com/user/profile/personal_access_tokens/) and ["Fine-grained personal access tokens"](https://docs.gitlab.com/auth/tokens/fine_grained_access_tokens/), checked 2026-11-18
- GitLab: ["Use SSH keys to communicate with GitLab"](https://docs.gitlab.com/user/ssh/), checked 2026-11-18
- Cloudflare: ["Two-factor authentication"](https://developers.cloudflare.com/fundamentals/user-profiles/2fa/), checked 2026-11-18
- Cloudflare: ["Change password or email"](https://developers.cloudflare.com/fundamentals/user-profiles/change-password-or-email/), checked 2026-11-18
- Cloudflare: ["Manage active sessions"](https://developers.cloudflare.com/fundamentals/account/account-security/manage-active-sessions/), checked 2026-11-18
- Cloudflare: ["Audit logs"](https://developers.cloudflare.com/fundamentals/account/account-security/audit-logs/) and ["Secure a compromised account"](https://developers.cloudflare.com/fundamentals/account/account-security/secure-a-compromised-account/), checked 2026-11-18
- Cloudflare: ["Roll a token"](https://developers.cloudflare.com/fundamentals/api/how-to/roll-token/), checked 2026-11-18
- Slack: ["Reset your password"](https://slack.com/help/articles/201909068-Reset-your-password), checked 2026-11-18
- Slack: ["Sign out of Slack"](https://slack.com/help/articles/214613347), checked 2026-11-18
- Slack: ["Set up two-factor authentication"](https://slack.com/help/articles/204509068-Set-up-two-factor-authentication), checked 2026-11-18
- Slack: ["View access logs for your account"](https://slack.com/help/articles/360002084827-View-access-logs-for-your-account), checked 2026-11-18
- Slack: ["auth.revoke"](https://docs.slack.dev/reference/methods/auth.revoke) and ["Quickstart: app settings"](https://docs.slack.dev/app-management/quickstart-app-settings), checked 2026-11-18
- Better Stack: ["Two-factor authentication"](https://betterstack.com/docs/uptime/two-factor-authentication/), checked 2026-11-18
- healthchecks.io: the account settings templates in its source code ([`profile.html`](https://github.com/healthchecks/healthchecks/blob/master/templates/accounts/profile.html), [`remove_credential.html`](https://github.com/healthchecks/healthchecks/blob/master/templates/accounts/remove_credential.html), [`set_password.html`](https://github.com/healthchecks/healthchecks/blob/master/templates/accounts/set_password.html)), checked 2026-11-18
- GnuPG: ["OpenPGP Key Management"](https://gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html), checked 2026-11-18
- Yubico: ["FIDO Commands (YubiKey Manager CLI)"](https://docs.yubico.com/software/yubikey/tools/ykman/FIDO_Commands.html), checked 2026-11-18
- Ubuntu: ["cryptsetup-luksChangeKey"](https://manpages.ubuntu.com/manpages/noble/en/man8/cryptsetup-luksChangeKey.8.html) (Ubuntu 24.04), checked 2026-11-18
- OpenSSH: `man ssh-keygen` (`-p`, changing a key's passphrase; OpenSSH 9.6 on Ubuntu 24.04), checked 2026-11-18
