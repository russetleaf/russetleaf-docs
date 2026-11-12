# Setup guide: two-factor sign-in for the project's accounts

The step-by-step procedure for securing the sign-in of every account the project depends on outside AWS: the Google Accounts, Microsoft, Bitwarden, GitHub, GitLab, Cloudflare (including its registrar), Slack and the outside monitoring services, plus the settings of the domain registration (Phase 1 [step 0.1](../plan.md#step-01-accounts-tools-and-budget-alert)). The project's Google Workspace organization has its own guide, the [Google Workspace setup guide](google-workspace.md), and the AWS root user and IAM Identity Center are covered by the [AWS management account setup guide](aws-management-account.md). The reasoning is in [ADR 1032](../adr/1032-defense-in-depth.md) (account hardening), [ADR 1056](../adr/1056-aws-root-mfa-two-security-keys.md) (the security keys) and [ADR 1059](../adr/1059-google-workspace-identity.md) (the Workspace identity).

**Note:** the click paths in this guide are those the services showed when the procedure was last carried out. Providers change their consoles without notice, and their own documentation can lag behind the console. Before following a path, check the provider's current documentation, linked in each part; where the screen still differs, follow what it shows and fix this guide to match.

## The rule

- **Terms:** in this guide, a **security key** is one of the two YubiKeys, whatever a service calls it: GitHub and AWS say *security key*, Google lists security keys under *Passkeys and security keys*, Microsoft calls them *passkeys*, and Bitwarden lists them under *Passkey / FIDO2 WebAuthn*. A **phone passkey** is a passkey stored on the phone or in a password manager. **Google sign-in (OIDC)** is federated sign-in with a Google Account over OpenID Connect, the authentication layer on OAuth 2.0 (the buttons labeled "Sign in with Google" or "Continue with Google"); Google authenticates the user, with its own second factor, and the service receives an ID token. **Password sign-in** is the service's own username and password, with the service's own second factor. Each step names the menu as the service shows it.
- **Two Google Accounts:** the **Workspace account** (`<name>@russetleaf.dev`) is the project's identity, used for Slack, Google sign-in in the platform and the services' email addresses. The operator's **personal Google Account** is used only where the project must not depend on russetleaf.dev: the Workspace account's recovery email and the **Cloudflare** sign-in ([ADR 1059](../adr/1059-google-workspace-identity.md)). Both are in **Advanced Protection** with both YubiKeys.
- **Security keys first.** The operator has two YubiKeys, both **YubiKey Security Key NFC** (FIDO2 and U2F only: no OpenPGP and no OATH, so they hold no authenticator codes): **`yubikey-primary`**, carried on the keychain for daily use, and **`yubikey-backup`**, kept in the safe as the backup. Both are registered, under those names wherever a service asks for one, with every account that supports security keys, and each has a FIDO2 PIN.
- **Phone passkeys are optional.** A passkey stored on the phone or in a password manager resists phishing as a YubiKey does, but it is not required anywhere and the checks do not look for one; keep or remove them as convenient. (Google creates one for each Android phone signed in to the account.) The YubiKeys are the required factor on every account.
- **Google sign-in (OIDC)** where a service supports it and has no security keys of its own (Slack), so authentication is done by a Google Account in Advanced Protection. Where a service also enforces its own second factor on a Google sign-in (Slack's authenticator code, Cloudflare's security keys), both apply.
- **Authenticator codes only where a service requires them,** in Google Authenticator on the phone (signed in to the personal Google Account, cloud sync on). **GitHub** requires a code before it accepts security keys, so a code is set up only to turn on two-factor sign-in; once both YubiKeys work and the recovery codes are saved, the entry is **deleted from the app**. The code stays enabled at GitHub, but no one can produce it, which removes the one factor a phishing page could ask for. **GitLab** gets the same treatment, since it issues recovery codes only with an authenticator code. **Slack** keeps its entry, since codes are its only second factor (applied to both password sign-in and Google sign-in), and so does the uptime checker if codes are all it offers (below).
- **Every password** is generated in Bitwarden and entered only through Bitwarden's autofill, which fills only on the real site, so a look-alike page shows up as a missing autofill.
- **Recovery codes** go into Bitwarden at once, and into the printed and encrypted copies of the break-glass kit at the end of step 0.1 ([break-glass kit setup guide](break-glass-kit.md)).

| Account | Sign-in | Second factors | Recovery |
|---|---|---|---|
| **Google Workspace** (`<name>@russetleaf.dev`, the project's identity) | Password from Bitwarden | Both YubiKeys, enforced by the organization; Advanced Protection | Administrator-generated backup codes; then the personal Google Account as recovery email ([Google Workspace setup guide](google-workspace.md)) |
| **Personal Google Account** (Workspace recovery, Cloudflare sign-in, Google Authenticator) | Advanced Protection | Both YubiKeys | Google's Advanced Protection recovery (takes several days) |
| **Microsoft** (OneDrive, for the encrypted kit) | Password from Bitwarden | Both YubiKeys | Recovery code |
| **Bitwarden** | Master password | Both YubiKeys (FIDO2) | Two-step login recovery code; the `bw` CLI signs in with an API key |
| **GitHub** (the personal account, owner of the `russetleaf` organization) | Password from Bitwarden | Both YubiKeys; an authenticator code is set up first (required), then deleted from the app | Recovery codes |
| **GitLab** (the personal account, owner of the `russetleaf` group of mirrors) | Password from Bitwarden | Both YubiKeys (WebAuthn devices); an authenticator code is set up first for the recovery codes, then deleted from the app; email OTP off | Recovery codes |
| **Cloudflare** (DNS, tunnel, Access, and the registrar for russetleaf.dev) | Google sign-in (OIDC) with the personal Google Account; password sign-in with the password from Bitwarden | Both YubiKeys (Cloudflare's own, required on both sign-in methods); Advanced Protection on the Google sign-in | Backup codes |
| **Slack** (workspace owner, Free plan) | Google sign-in (OIDC) with the Workspace account; password sign-in with the password from Bitwarden as the fallback | An authenticator code (Slack's own, required on both sign-in methods); Advanced Protection on the Google sign-in | Backup codes |
| **Heartbeat service** (healthchecks.io) | Password from Bitwarden | Both YubiKeys (WebAuthn) | A second key is the only backup |
| **Uptime checker** | Google sign-in with the Workspace account, or a password | Security keys if the service offers them, otherwise an authenticator code | The service's recovery codes |

## Before starting

Have these ready:

- **Both YubiKeys**, each with a FIDO2 PIN (set with `ykman fido access change-pin`).
- **The operator's phone**, with Google Authenticator signed in to the personal Google Account (to set up GitHub's, GitLab's and Slack's codes).
- **Bitwarden open**, with an entry for each account.
- **The Workspace account**, set up by the [Google Workspace setup guide](google-workspace.md).

## Part 1: The personal Google Account, Microsoft and Bitwarden

1. **The personal Google Account**, moving to the **Advanced Protection Program**:
    1. Under **Security → Passkeys and security keys**, register **both YubiKeys** as security keys.
    2. Under **Security**, confirm a **recovery phone** and a **recovery email address** in a mailbox other than this Google Account.
    3. **Enroll** from `https://landing.google.com/advancedprotection/` with **Get started**, signing in again with a YubiKey when asked.
    4. Under **2-Step Verification**, remove any SMS, voice or authenticator-code second steps that remain. Keep the Google Authenticator app itself: it stays signed in to this account for the codes some services need (GitHub's and GitLab's, briefly, and Slack's).
    5. Sign in again on each device, and confirm Google Drive's web upload still works (Advanced Protection blocks most third-party apps from Gmail and Drive data); the encrypted kit's Google Drive copy lives here.
2. **Microsoft account** (used for OneDrive): under **Security → Advanced security options**, add both YubiKeys (Microsoft lists them as passkeys); save the **recovery code** in Bitwarden.
3. **Bitwarden:** under **Settings → Security → Two-step login**, add both YubiKeys under **Passkey / FIDO2 WebAuthn** (Bitwarden's name for security keys), and save the **two-step login recovery code** (it goes into the printed kit, since it cannot live in the vault it unlocks). Sign the CLI in with the account's **personal API key** (`bw login --apikey`), since the CLI cannot use a security key ([workstation configuration](../plan.md#4-configuration)).

## Part 2: GitHub and GitLab

1. **GitHub, the operator's personal account:** under **Settings → Password and authentication → Two-factor authentication**:
    1. **Set up an authenticator app** first (GitHub requires a code or SMS before it accepts security keys): scan the code with Google Authenticator. Do not use SMS.
    2. **Save the recovery codes** in Bitwarden.
    3. Under **Security keys**, register **both YubiKeys**.
    4. **Sign in once with each YubiKey** (sign out between them), then use `yubikey-primary` from then on.
    5. **Delete the GitHub entry in Google Authenticator**, only after steps 2 and 4. Sync removes it from the Google Account too. The recovery codes are then the only way in without a YubiKey. To use codes again later, sign in with a key and set up the authenticator app again under the same settings, which issues a new secret.
    6. **Set the preferred two-factor method** to **Security keys**, so sign-in and GitHub's "Confirm access" prompts ask for a YubiKey first. Do not use GitHub Mobile as a two-factor method.
    7. **The `russetleaf` organization** ([ADR 1060](../adr/1060-github-organization-and-gitlab-group.md)): in the organization's **Settings → Authentication security**, select "Require two-factor authentication for everyone in your organization" and "Only allow secure two-factor methods", then **Save**.
2. **GitLab, the operator's personal account** (steps from GitLab's [two-factor authentication](https://docs.gitlab.com/user/profile/account/two_factor_authentication/) and [passkeys](https://docs.gitlab.com/auth/passkeys) documentation): select the avatar → **Edit profile** → **Access** → **Password and authentication**. A YubiKey is registered either as a **WebAuthn device** (a second factor after the password) or under **Passkey sign-in** (replacing the password), not both; this guide uses WebAuthn devices, as on the other accounts.
    1. **Set up the OTP authenticator** with Google Authenticator (a code and the GitLab password). GitLab generates **recovery codes only for an OTP authenticator**, not for security keys, so this step is what provides them. Do not use SMS.
    2. **Save the recovery codes** in Bitwarden; GitLab shows them right after the OTP authenticator is set up.
    3. In the **WebAuthn devices** section, select **Register device**, then **Set up new device**; with only `yubikey-primary` plugged in, enter its PIN and touch it, then enter the GitLab password and the name `yubikey-primary`, and select **Register device**. Repeat for `yubikey-backup`.
    4. **Sign in once with each YubiKey** (sign out between them).
    5. **Turn off email OTP** if it is on. GitLab.com turns it on by itself for accounts without another second factor (multi-factor sign-in has been mandatory there since April 2026); once the YubiKeys are registered it is not needed, and it would leave a code by email as another way in. Do not select **Disable 2FA**, which turns off two-factor sign-in, YubiKeys included.
    6. **Delete the GitLab entry in Google Authenticator**, as for GitHub, only after steps 2 and 4.

    With two-factor sign-in on, Git over HTTPS and the API no longer accept the password; they use a personal access token, as the GitHub-to-GitLab backup already does.

## Part 3: Cloudflare and the domain registration

The steps follow Cloudflare's documentation ([two-factor authentication](https://developers.cloudflare.com/fundamentals/user-profiles/2fa/), [auto-renew](https://developers.cloudflare.com/registrar/account-options/renew-domains/), [domain management](https://developers.cloudflare.com/registrar/account-options/domain-management/), [DNSSEC](https://developers.cloudflare.com/registrar/get-started/enable-dnssec/)).

1. **Cloudflare account:** Cloudflare holds the domain that the Workspace account depends on, so it uses the **personal Google Account**, not the Workspace account.
    1. **Google sign-in (OIDC):** sign up with **Sign in with Google**, choosing the personal Google Account.
    2. **A Cloudflare password**, required before Cloudflare's own two-factor authentication can be enrolled: an account created with Google sign-in has none. Sign out, select the password-reset link on the dashboard's sign-in page (shown only when signed out), enter the personal Google Account's address, and set a password generated in Bitwarden from the reset email.
    3. **Both YubiKeys as Cloudflare's second factor:** signed in, open the profile menu's **My Profile**, then **Access Management → Authentication** in the left menu. Under **Two-Factor Authentication**, select **Set up**; under **Security Key Authentication**, select **Add**, enter the Cloudflare password, touch the key (with its PIN), and name it `yubikey-primary`. Cloudflare then asks for the password again and shows the **backup codes**: save them in Bitwarden. Add `yubikey-backup` the same way. Leave **Mobile App Authentication** and **Email Authentication** off.
    4. **Test in private windows:** Google sign-in asks for a YubiKey at Google and then for a security key at Cloudflare; password sign-in asks for a security key; each key works on its own.
2. **russetleaf.dev, at Cloudflare Registrar:** open the **Manage domains** page at `https://dash.cloudflare.com/?to=/:account/registrar/domains` (the target of the "Go to Manage domains" button in Cloudflare's documentation), which lists the account's registered domains. The dashboard's tabs differ from those documents' wording; the names below are the dashboard's.
    1. **Auto-renew:** in the russetleaf.dev row, the **Auto-renew** toggle is on (the default).
    2. Select **Manage** in the same row. The domain's page has the tabs **Overview**, **Contacts** and **Settings**; open **Settings**.
    3. **Transfer lock:** the **Transfer to another registrar** section shows an **Unlock** button while the domain is locked. Leave it locked; selecting **Unlock** generates the authorization code that lets the domain move to another registrar.
    4. **DNSSEC:** in the **DNSSEC** section, enable it. Cloudflare sends the DS record to the registry itself, within one to two days; afterward the same section shows DNSSEC as active.
    5. **WHOIS privacy:** the **WHOIS privacy** section shows it on (the default), so the contact details are redacted from public lookups.
    6. Leave **Move to another Cloudflare account** and **Delete domain** untouched.

## Part 4: Slack and the outside monitoring services

1. **Slack** (Free plan; the steps follow Slack's [sign-in](https://slack.com/help/articles/212681477-Sign-in-to-Slack), [two-factor authentication](https://slack.com/help/articles/204509068-Set-up-two-factor-authentication) and [mandatory two-factor authentication](https://slack.com/help/articles/212221668-Mandatory-workspace-two-factor-authentication) articles). Slack accepts no security keys ("Slack doesn't support Universal 2nd Factor (U2F) yet"), so the daily sign-in is Google sign-in (OIDC), with Slack's authenticator code required on every sign-in:
    1. **The owner account's email** is the Workspace address: under `my.slack.com/account`, next to **Email Address**, select **Expand**, enter the password and the new address, and select **Update Email**; then open the confirmation message Slack sends to the Workspace mailbox and select its confirmation button. Slack matches a Google sign-in to the account by the ID token's email address, so change it before step 6, and update the Slack entry's username in Bitwarden.
    2. **The password:** generated in Bitwarden. Slack's docs describe no way to remove it, and a workspace owner can always sign in with it.
    3. **Two-factor authentication:** at `my.slack.com/account/settings`, next to **Two-factor Authentication**, select **Expand**, then **Set Up Two-Factor Authentication**; enter the password, choose **Use an app**, scan the code with Google Authenticator, and select **Verify Code**. Slack can also send a code by text message to confirm the change; the account's second factor is still the app, which the same page shows afterward. Do not choose SMS as the method. Keep this entry in the app.
    4. **The backup codes** in Bitwarden; Slack keeps them viewable on the same account page.
    5. **For the whole workspace:** in the admin pages, **Security → Security settings → Sign-in settings** (open them from **Admin** in the desktop sidebar, or, if the sidebar has no **Admin**, from the workspace name at the top left, which opens the admin home); next to **Two-factor authentication for email sign-in**, select **Edit**, then **Require members to have 2FA set up** and **Authenticator apps only**, and **Save**.
    6. **Google sign-in (OIDC):** sign out in the browser, then at `slack.com/signin` select **Continue with Google** and choose the Workspace account; Google asks for a YubiKey, then Slack asks for its own authenticator code (Slack's two-factor authentication applies to both sign-in methods), and opens the existing workspace with the owner account. Test it in a private window, since a browser already signed in to Google asks for no key. If Slack offers to create a new account or workspace instead, stop: the address in step 1 does not match. The desktop and phone apps keep their sessions; when they next ask, sign in the same way. Password sign-in, with the password from Bitwarden and the authenticator code, is the fallback.
2. **Heartbeat service** (healthchecks.io): sign up with the Workspace address, and register both YubiKeys under **Account Settings → Two-factor authentication** (security keys are its only second factor).
3. **Uptime checker:** prefer a service that offers security keys or Google sign-in (OIDC) with the Workspace account; if it offers only authenticator codes (UptimeRobot, for example), use Google Authenticator and save its recovery codes.

## Checks

- [ ] Signing in to the Workspace account, the personal Google Account, Microsoft, Bitwarden, GitHub, GitLab, Cloudflare and the heartbeat service accepts both YubiKeys.
- [ ] Both Google Accounts are in **Advanced Protection**; Cloudflare uses Google sign-in (OIDC) with the personal one, and Slack with the Workspace account. Cloudflare asks for a security key, and Slack for its authenticator code, on both Google sign-in and password sign-in.
- [ ] The GitHub organization requires two-factor authentication with only secure methods.
- [ ] Google Authenticator holds no entry for GitHub, GitLab or AWS root; it holds Slack's, and at most one for the uptime checker, if codes are all it offers.
- [ ] Every account's recovery codes are in Bitwarden.
- [ ] russetleaf.dev has **auto-renew**, the **transfer lock** and **DNSSEC** on.

## If something goes wrong

- **Lost `yubikey-primary`:** sign in with `yubikey-backup`, and remove the lost key from **every** account in the table above, from AWS root and Identity Center, and from the workstation's SSH keys and `sudo` ([workstation YubiKey setup guide](workstation-yubikey.md#if-something-goes-wrong)); then register a replacement (with a PIN) everywhere.
- **Lost the phone:** no sign-in depends on it, since the YubiKeys are the required factor. Sign out its sessions and remove any phone passkeys from each account (signing in with a YubiKey); Google Authenticator's entries (Slack's, and the uptime checker's if any) return on a new phone through sync once the personal Google Account is signed in.
- **Lost both YubiKeys:** use each account's recovery codes from the break-glass kit, or the provider's recovery process; the Workspace account uses its backup codes, then the personal Google Account as its recovery email ([Google Workspace setup guide](google-workspace.md#if-something-goes-wrong)); AWS root uses AWS's email-and-phone recovery ([AWS management account setup guide](aws-management-account.md#if-something-goes-wrong)).

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- Google: ["Get Google's strongest account security with the Advanced Protection Program"](https://support.google.com/accounts/answer/7519408), checked 2026-11-12
- Google: ["Advanced Protection Program"](https://landing.google.com/advancedprotection/), checked 2026-11-12
- Google: ["Use a security key for 2-Step Verification"](https://support.google.com/accounts/answer/6103523), checked 2026-11-12
- Microsoft: ["Create and save a passkey"](https://support.microsoft.com/en-us/accounts-billing/security/create-save-passkey), checked 2026-11-12
- Microsoft: ["How to get a Microsoft account recovery code"](https://support.microsoft.com/en-us/accounts-billing/manage/how-to-get-a-microsoft-account-recovery-code), checked 2026-11-12
- Bitwarden: ["Passkey Two-Step Login"](https://bitwarden.com/help/setup-two-step-login-fido/), checked 2026-11-12
- Bitwarden: ["Recovery Code for Two-Step Login"](https://bitwarden.com/help/two-step-recovery-code/), checked 2026-11-12
- Bitwarden: ["CLI Authentication via API Key"](https://bitwarden.com/help/personal-api-key/), checked 2026-11-12
- Yubico: ["Introduction to the YubiKey Series (the Security Key Series supports FIDO2 and U2F only)"](https://docs.yubico.com/hardware/yubikey/yk-tech-manual/yk5-intro.html), checked 2026-11-12
- GitHub: ["Configuring two-factor authentication"](https://docs.github.com/en/authentication/securing-your-account-with-two-factor-authentication-2fa/configuring-two-factor-authentication), checked 2026-11-12
- GitHub: ["Configuring two-factor authentication recovery methods"](https://docs.github.com/en/authentication/securing-your-account-with-two-factor-authentication-2fa/configuring-two-factor-authentication-recovery-methods), checked 2026-11-12
- GitHub: ["Changing your two-factor authentication method"](https://docs.github.com/en/authentication/securing-your-account-with-two-factor-authentication-2fa/changing-your-two-factor-authentication-method), checked 2026-11-12
- GitHub: ["Requiring two-factor authentication in your organization"](https://docs.github.com/en/organizations/keeping-your-organization-secure/managing-two-factor-authentication-for-your-organization/requiring-two-factor-authentication-in-your-organization), checked 2026-11-12
- GitHub: ["GitHub Terms of Service (B. Account Terms: one free account per person)"](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service), checked 2026-11-12
- GitLab: ["Passkeys"](https://docs.gitlab.com/auth/passkeys), checked 2026-11-12
- GitLab: ["Two-factor authentication"](https://docs.gitlab.com/user/profile/account/two_factor_authentication/), checked 2026-11-12
- Cloudflare: ["Two-factor authentication"](https://developers.cloudflare.com/fundamentals/user-profiles/2fa/), checked 2026-11-12
- Cloudflare: ["Email address and password"](https://developers.cloudflare.com/fundamentals/user-profiles/change-password-or-email/), checked 2026-11-12
- Cloudflare: ["Renew domains"](https://developers.cloudflare.com/registrar/account-options/renew-domains/), checked 2026-11-12
- Cloudflare: ["Domain management"](https://developers.cloudflare.com/registrar/account-options/domain-management/), checked 2026-11-12
- Cloudflare: ["Transfer domain out from Cloudflare"](https://developers.cloudflare.com/registrar/account-options/transfer-out-from-cloudflare/), checked 2026-11-12
- Cloudflare: ["Enable DNSSEC"](https://developers.cloudflare.com/registrar/get-started/enable-dnssec/), checked 2026-11-12
- Cloudflare: ["WHOIS redaction"](https://developers.cloudflare.com/registrar/account-options/whois-redaction/), checked 2026-11-12
- Slack: ["Change your email address"](https://slack.com/help/articles/207262907-Change-your-email-address), checked 2026-11-12
- Slack: ["Set up two-factor authentication"](https://slack.com/help/articles/204509068-Set-up-two-factor-authentication), checked 2026-11-12
- Slack: ["Mandatory workspace two-factor authentication"](https://slack.com/help/articles/212221668-Mandatory-workspace-two-factor-authentication), checked 2026-11-12
- Slack: ["Sign in to Slack"](https://slack.com/help/articles/212681477-Sign-in-to-Slack), checked 2026-11-12
- Slack: ["Change a member's role (where the admin pages open when the sidebar has no Admin item)"](https://slack.com/help/articles/218124397-Change-a-members-role), checked 2026-11-12
- Healthchecks.io: ["Frequently Asked Questions (authentication mechanisms)"](https://healthchecks.io/faq/), checked 2026-11-12
- UptimeRobot: ["Set Up Two-Factor Authentication (2FA) in UptimeRobot"](https://help.uptimerobot.com/en/articles/11588518-set-up-two-factor-authentication-2fa-in-uptimerobot), checked 2026-11-12
