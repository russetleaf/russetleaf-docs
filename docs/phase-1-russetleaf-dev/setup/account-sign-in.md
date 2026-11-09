# Setup guide: two-factor sign-in for the project's accounts

The step-by-step procedure for securing the sign-in of every account the project depends on outside AWS: Google, Microsoft, Bitwarden, GitHub, GitLab, Cloudflare (including its registrar), Slack and the outside monitoring services, plus the settings of the two domain registrations (Phase 1 [step 0.1](../plan.md#step-01-accounts-tools-and-budget-alert)). The AWS root user and IAM Identity Center are covered by the [AWS management account setup guide](aws-management-account.md). The reasoning is in [ADR 1032](../adr/1032-defense-in-depth.md) (account hardening) and [ADR 1056](../adr/1056-aws-root-mfa-two-security-keys.md) (the security keys).

Providers' settings pages change over time. These steps name each setting rather than every click; where the wording differs, follow the setting's name.

## The rule

- **Security keys first.** The operator has two YubiKeys, both **YubiKey Security Key NFC** (FIDO2 and U2F only: no OpenPGP and no OATH, so they hold no authenticator codes): **`yubikey-primary`**, carried on the keychain for daily use, and **`yubikey-backup`**, kept in the safe as the backup. Both are registered, under those names wherever a service asks for one, with every account that supports security keys, and each has a FIDO2 PIN.
- **A passkey on the operator's phone** is added where the service offers passkeys, for convenience.
- **Authenticator codes only where a service requires them,** in Google Authenticator (cloud sync on; the Google Account is in Advanced Protection). **GitHub** requires a code before it accepts security keys, so a code is set up only to turn on two-factor sign-in; once both YubiKeys work and the recovery codes are saved, the entry is **deleted from the app**. The code stays enabled at GitHub, but no one can produce it, which removes the one factor a phishing page could ask for. GitLab gets the same treatment if it requires a code; the uptime checker keeps its entry only if codes are all it offers (below).
- **Every password** is generated in Bitwarden and entered only through Bitwarden's autofill, which fills only on the real site, so a look-alike page shows up as a missing autofill.
- **Recovery codes** go into Bitwarden at once, and into the printed and encrypted copies of the break-glass kit at the end of step 0.1 ([break-glass kit setup guide](break-glass-kit.md)).

| Account | Sign-in | Second factors | Recovery |
|---|---|---|---|
| **Google** (the operator's account; holds the AWS root email address) | Advanced Protection | Phone passkey, both YubiKeys | Google's Advanced Protection recovery (takes several days) |
| **Microsoft** (OneDrive, for the encrypted kit) | Password from Bitwarden | Both YubiKeys (and a phone passkey) | Recovery code |
| **Bitwarden** | Master password | Both YubiKeys (FIDO2) | Two-step login recovery code; the `bw` CLI signs in with an API key |
| **GitHub** | Password, or a passkey | Both YubiKeys and a phone passkey; an authenticator code is set up first (required), then deleted from the app | Recovery codes |
| **GitLab** (the repo mirrors) | Password from Bitwarden | Both YubiKeys; an authenticator code only if GitLab requires one | Recovery codes |
| **Cloudflare** (DNS, tunnel, Access, and the registrar for russetleaf.dev) | Password from Bitwarden | Both YubiKeys | Backup codes |
| **Slack** (workspace owner) | **Sign in with Google** | Google's (Advanced Protection) | Through the Google Account |
| **Heartbeat service** (healthchecks.io) | Password from Bitwarden | Both YubiKeys (WebAuthn) | A second key is the only backup |
| **Uptime checker** | Google sign-in, or a password | Security keys if the service offers them, otherwise an authenticator code | The service's recovery codes |
| **Route 53 Domains** (the registrar for russetleaf.com) | AWS access ([AWS management account setup guide](aws-management-account.md)) | Both YubiKeys | AWS's recovery |

## Before starting

Have these ready:

- **Both YubiKeys**, each with a FIDO2 PIN (set with `ykman fido access change-pin`).
- **The operator's phone**, with Google Authenticator signed in to the Google Account (to set up GitHub's code).
- **Bitwarden open**, with an entry for each account.

## Part 1: Google, Microsoft and Bitwarden

1. **Google**, moving to the **Advanced Protection Program**:
    1. Under **Security → Passkeys and security keys**, register a **passkey on the phone** and the YubiKeys available (one key and one passkey are enough to enroll; add the second key when it arrives).
    2. Under **Security**, confirm a **recovery phone** and a **recovery email address** in a mailbox other than this Google Account.
    3. **Enroll** on Google's Advanced Protection page, signing in again with the key or passkey when asked.
    4. Under **2-Step Verification**, remove any SMS, voice or authenticator-code second steps that remain. Keep the Google Authenticator app itself: it stays signed in to the account for the codes some services need to set up two-factor sign-in (GitHub's).
    5. Sign in again on each device, and confirm Google Drive's web upload still works (Advanced Protection blocks most third-party apps from Gmail and Drive data).
2. **Microsoft account** (used for OneDrive): under **Security → Advanced security options**, add both YubiKeys as security keys (and a passkey on the phone if offered); save the **recovery code** in Bitwarden.
3. **Bitwarden:** under **Settings → Security → Two-step login**, add both YubiKeys under **Passkey / FIDO2 WebAuthn**, and save the **two-step login recovery code** (it goes into the printed kit, since it cannot live in the vault it unlocks). Sign the CLI in with the account's **personal API key** (`bw login --apikey`), since the CLI cannot use a security key ([workstation configuration](../plan.md#4-configuration)).

## Part 2: GitHub and GitLab

1. **GitHub:** under **Settings → Password and authentication → Two-factor authentication**:
    1. **Set up an authenticator app** first (GitHub requires a code or SMS before it accepts security keys): scan the code with Google Authenticator. Do not use SMS.
    2. **Save the recovery codes** in Bitwarden.
    3. Under **Security keys**, register **both YubiKeys**; under **Passkeys**, add one on the phone.
    4. **Sign in once with each YubiKey** (sign out between them), then use the passkey or `yubikey-primary` from then on.
    5. **Delete the GitHub entry in Google Authenticator**, only after steps 2 and 4. Sync removes it from the Google Account too. The recovery codes are then the only way in without a YubiKey or the passkey. To use codes again later, sign in with a key and set up the authenticator app again under the same settings, which issues a new secret.
2. **GitLab:** under **Preferences → Account → Two-factor authentication** (or **Password and authentication**):
    1. **Register both YubiKeys** as WebAuthn devices **without** an authenticator app, if GitLab allows it.
    2. **If GitLab asks for an authenticator app first,** set one up in Google Authenticator, register both YubiKeys, and delete the entry from the app once both keys work and the recovery codes are saved, as for GitHub.
    3. **Save the recovery codes** in Bitwarden.

## Part 3: Cloudflare and the domain registrations

1. **Cloudflare account:** under **My Profile → Authentication → Two-Factor Authentication**, add both YubiKeys under **Security Key Authentication** and save the **backup codes** in Bitwarden. Do not add an authenticator app.
2. **russetleaf.dev, at Cloudflare Registrar:** under **Domain Registration → Manage Domains**, confirm **auto-renew** is on and the domain is **locked** (Cloudflare locks registered domains against transfer by default); turn on **DNSSEC** in the zone's DNS settings (one click, since Cloudflare is both registrar and DNS). Registrant contact details stay redacted from public lookups.
3. **russetleaf.com, at Amazon Route 53 Domains,** in the **russetleaf-com** account from Phase 1 [step 2.3](../plan.md#step-23-aws-and-cloudflare-resources-for-the-home-lab), managed in OpenTofu (`envs/aws-edge`): **auto-renew**, **transfer lock** and **privacy protection** are on, and AWS sign-in is protected by Identity Center (Part 2 of the [AWS management account setup guide](aws-management-account.md)).

    DNSSEC is added in Phase 3, with the new Route 53 hosted zone ([Phase 3 design](../../phase-3-russetleaf-com/design.md)).

## Part 4: Slack and the outside monitoring services

1. **Slack:** create or sign in to the workspace owner account with **Sign in with Google**, so the sign-in goes through the Google Account's Advanced Protection; do not set a separate Slack password. If Slack requires one, generate it in Bitwarden and turn on Slack's own two-factor authentication with Google Authenticator, so the password path is protected too ([Slack and outside monitoring setup guide](slack-and-monitoring.md)).
2. **Heartbeat service** (healthchecks.io): register both YubiKeys under **Account Settings → Two-factor authentication** (security keys are its only second factor).
3. **Uptime checker:** prefer a service that offers security keys or Google sign-in; if it offers only authenticator codes (UptimeRobot, for example), use Google Authenticator and save its recovery codes.

## Checks

- [ ] Signing in to Google, Microsoft, Bitwarden, GitHub, GitLab, Cloudflare and the heartbeat service asks for a security key or passkey (or uses one), and both YubiKeys work on each.
- [ ] The Google Account is in **Advanced Protection**, and Slack signs in through it.
- [ ] Google Authenticator holds no entry for GitHub, GitLab or AWS root; at most one for the uptime checker, if codes are all it offers.
- [ ] Every account's recovery codes are in Bitwarden.
- [ ] Both domains have **auto-renew** and a **transfer lock** on, russetleaf.dev has **DNSSEC** on, and russetleaf.com's contacts have **privacy protection**.

## If something goes wrong

- **Lost `yubikey-primary`:** sign in with `yubikey-backup` or a passkey, and remove the lost key from **every** account in the table above, from AWS root and Identity Center, and from the workstation's SSH keys and `sudo` ([workstation YubiKey setup guide](workstation-yubikey.md#if-something-goes-wrong)); then register a replacement (with a PIN) everywhere.
- **Lost the phone:** remove its passkeys from each account (signing in with a YubiKey); Google Authenticator's codes return on a new phone through sync once the Google Account is signed in.
- **Lost both YubiKeys:** use each account's recovery codes from the break-glass kit, a phone passkey where one exists, or the provider's recovery process; AWS root uses AWS's email-and-phone recovery ([AWS management account setup guide](aws-management-account.md#if-something-goes-wrong)).
