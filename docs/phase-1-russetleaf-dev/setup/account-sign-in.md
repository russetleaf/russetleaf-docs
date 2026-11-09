# Setup guide: two-factor sign-in for the project's accounts

The step-by-step procedure for securing the sign-in of every account the project depends on outside AWS: Google, Microsoft, Bitwarden, GitHub, GitLab, Cloudflare (including its registrar), Slack and the outside monitoring services, plus the settings of the two domain registrations (Phase 1 [step 0.1](../plan.md#step-01-accounts-tools-and-budget-alert)). The AWS root user and IAM Identity Center are covered by the [AWS management account setup guide](aws-management-account.md). The reasoning is in [ADR 1032](../adr/1032-defense-in-depth.md) (account hardening) and [ADR 1056](../adr/1056-aws-root-mfa-two-security-keys.md) (the security keys).

Providers' settings pages change over time. These steps name each setting rather than every click; where the wording differs, follow the setting's name.

## The rule

- **Security keys first.** The operator has two YubiKeys, both **YubiKey Security Key NFC** (FIDO2 and U2F only: no OpenPGP and no OATH, so they hold no authenticator codes): **`yubikey-primary`**, carried on the keychain for daily use, and **`yubikey-backup`**, kept in the safe as the backup. Both are registered, under those names wherever a service asks for one, with every account that supports security keys, and each has a FIDO2 PIN.
- **A passkey on the operator's phone** is added where the service offers passkeys, for convenience.
- **Authenticator codes only where a service requires them,** in Google Authenticator (cloud sync on; the Google Account is in Advanced Protection). Today that is **GitHub**, which requires a code before it accepts security keys, and possibly GitLab and the uptime checker (below). A code is a fallback, not the daily factor.
- **Every password** is generated in Bitwarden and entered only through Bitwarden's autofill, which fills only on the real site, so a look-alike page shows up as a missing autofill.
- **Recovery codes** go into Bitwarden at once, and into the printed and encrypted copies of the break-glass kit at the end of step 0.1 ([break-glass kit setup guide](break-glass-kit.md)).

| Account | Sign-in | Second factors | Recovery |
|---|---|---|---|
| **Google** (the operator's account; holds the AWS root email address) | Advanced Protection | Phone passkey, both YubiKeys | Google's Advanced Protection recovery (takes several days) |
| **Microsoft** (OneDrive, for the encrypted kit) | Password from Bitwarden | Both YubiKeys (and a phone passkey) | Recovery code |
| **Bitwarden** | Master password | Both YubiKeys (FIDO2) | Two-step login recovery code; the `bw` CLI signs in with an API key |
| **GitHub** | Password, or a passkey | An authenticator code first (required), then both YubiKeys and a phone passkey | Recovery codes |
| **GitLab** (the repo mirrors) | Password from Bitwarden | Both YubiKeys; an authenticator code only if GitLab requires one | Recovery codes |
| **Cloudflare** (DNS, tunnel, Access, and the registrar for russetleaf.dev) | Password from Bitwarden | Both YubiKeys | Backup codes |
| **Slack** (workspace owner) | **Sign in with Google** | Google's (Advanced Protection) | Through the Google Account |
| **Heartbeat service** (healthchecks.io) | Password from Bitwarden | Both YubiKeys (WebAuthn) | A second key is the only backup |
| **Uptime checker** | Google sign-in, or a password | Security keys if the service offers them, otherwise an authenticator code | The service's recovery codes |
| **Route 53 Domains** (the registrar for russetleaf.com) | AWS access ([AWS management account setup guide](aws-management-account.md)) | Both YubiKeys | AWS's recovery |

## Before starting

Have these ready:

- **Both YubiKeys**, each with a FIDO2 PIN (set with `ykman fido access change-pin`).
- **The operator's phone**, with Google Authenticator signed in to the Google Account (for GitHub's code).
- **Bitwarden open**, with an entry for each account.

## Part 1: Google, Microsoft and Bitwarden

1. **Google**, moving to the **Advanced Protection Program**:
    1. Under **Security → Passkeys and security keys**, register a **passkey on the phone** and the YubiKeys available (one key and one passkey are enough to enroll; add the second key when it arrives).
    2. Under **Security**, confirm a **recovery phone** and a **recovery email address** in a mailbox other than this Google Account.
    3. **Enroll** on Google's Advanced Protection page, signing in again with the key or passkey when asked.
    4. Under **2-Step Verification**, remove any SMS, voice or authenticator-code second steps that remain. Keep the Google Authenticator app itself: it stays signed in to the account and keeps syncing the codes other services need (GitHub's).
    5. Sign in again on each device, and confirm Google Drive's web upload still works (Advanced Protection blocks most third-party apps from Gmail and Drive data).
2. **Microsoft account** (used for OneDrive): under **Security → Advanced security options**, add both YubiKeys as security keys (and a passkey on the phone if offered); save the **recovery code** in Bitwarden.
3. **Bitwarden:** under **Settings → Security → Two-step login**, add both YubiKeys under **Passkey / FIDO2 WebAuthn**, and save the **two-step login recovery code** (it goes into the printed kit, since it cannot live in the vault it unlocks). Sign the CLI in with the account's **personal API key** (`bw login --apikey`), since the CLI cannot use a security key ([workstation configuration](../plan.md#4-configuration)).

## Part 2: GitHub and GitLab

1. **GitHub:** under **Settings → Password and authentication → Two-factor authentication**:
    1. **Set up an authenticator app** first (GitHub requires a code or SMS before it accepts security keys): scan the code with Google Authenticator. Do not use SMS.
    2. **Save the recovery codes** in Bitwarden.
    3. Under **Security keys**, register **both YubiKeys**; under **Passkeys**, add one on the phone.
    4. Sign in with the passkey or `yubikey-primary` from then on; the code is the fallback.
2. **GitLab:** under **Preferences → Account → Two-factor authentication** (or **Password and authentication**):
    1. **Register both YubiKeys** as WebAuthn devices **without** an authenticator app, if GitLab allows it.
    2. **If GitLab asks for an authenticator app first,** set one up in Google Authenticator, then register both YubiKeys.
    3. **Save the recovery codes** in Bitwarden.

## Part 3: Cloudflare and the domain registrations

1. **Cloudflare account:** under **My Profile → Authentication → Two-Factor Authentication**, add both YubiKeys under **Security Key Authentication** and save the **backup codes** in Bitwarden. Do not add an authenticator app.
2. **russetleaf.dev, at Cloudflare Registrar:** under **Domain Registration → Manage Domains**, confirm **auto-renew** is on and the domain is **locked** (Cloudflare locks registered domains against transfer by default); turn on **DNSSEC** in the zone's DNS settings (one click, since Cloudflare is both registrar and DNS). Registrant contact details stay redacted from public lookups.
3. **russetleaf.com, at Amazon Route 53 Domains:** the registration is in an account of the operator's **2022 AWS Organization**, outside RussetLeaf's Organization. It stays there until Phase 3 [step 1.2](../../phase-3-russetleaf-com/plan.md#step-12-always-on-edge-envsaws-edge) moves it into the russetleaf-com account. Until then, in that 2022 account:
    1. **Registration settings:** under **Route 53 → Domains → Registered domains → russetleaf.com**, confirm **auto-renew** is on, **transfer lock** is on, and **privacy protection** is on for the registrant, administrative and technical contacts.
    2. **Renewal payment:** the yearly renewal is charged to that account's payment method, so keep it valid until the transfer.
    3. **Account sign-in:** the root user has both YubiKeys as its MFA devices (and no authenticator app), and **every IAM user with a console password has MFA**, or has its console password removed. Anyone who can sign in to that account can transfer the domain away.
    4. **Do not close** that account, or leave or delete the 2022 Organization, before the transfer is complete.

    DNSSEC is added in Phase 3, with the new Route 53 hosted zone ([Phase 3 design](../../phase-3-russetleaf-com/design.md)).

## Part 4: Slack and the outside monitoring services

1. **Slack:** create or sign in to the workspace owner account with **Sign in with Google**, so the sign-in goes through the Google Account's Advanced Protection; do not set a separate Slack password. If Slack requires one, generate it in Bitwarden and turn on Slack's own two-factor authentication with Google Authenticator, so the password path is protected too ([Slack and outside monitoring setup guide](slack-and-monitoring.md)).
2. **Heartbeat service** (healthchecks.io): register both YubiKeys under **Account Settings → Two-factor authentication** (security keys are its only second factor).
3. **Uptime checker:** prefer a service that offers security keys or Google sign-in; if it offers only authenticator codes (UptimeRobot, for example), use Google Authenticator and save its recovery codes.

## Checks

- [ ] Signing in to Google, Microsoft, Bitwarden, GitHub, GitLab, Cloudflare and the heartbeat service asks for a security key or passkey (or uses one), and both YubiKeys work on each.
- [ ] The Google Account is in **Advanced Protection**, and Slack signs in through it.
- [ ] Google Authenticator holds codes only for services that require them (GitHub, and GitLab or the uptime checker if they did), and none for AWS root.
- [ ] Every account's recovery codes are in Bitwarden.
- [ ] Both domains have **auto-renew** and a **transfer lock** on, russetleaf.dev has **DNSSEC** on, and russetleaf.com's contacts have **privacy protection**.
- [ ] In the 2022 account that holds russetleaf.com, root uses both YubiKeys and every IAM user with a console password has MFA (or no console password).

## If something goes wrong

- **Lost `yubikey-primary`:** sign in with `yubikey-backup` or a passkey, and remove the lost key from **every** account in the table above, from AWS root and Identity Center, and from the workstation's SSH keys and `sudo` ([workstation YubiKey setup guide](workstation-yubikey.md#if-something-goes-wrong)); then register a replacement (with a PIN) everywhere.
- **Lost the phone:** remove its passkeys from each account (signing in with a YubiKey); Google Authenticator's codes return on a new phone through sync once the Google Account is signed in.
- **Lost both YubiKeys:** use each account's recovery codes from the break-glass kit, a phone passkey where one exists, or the provider's recovery process; AWS root uses AWS's email-and-phone recovery ([AWS management account setup guide](aws-management-account.md#if-something-goes-wrong)).
