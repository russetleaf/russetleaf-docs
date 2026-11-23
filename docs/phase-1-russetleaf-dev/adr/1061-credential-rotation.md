# ADR 1061: Credential rotation: on events for passwords, on a schedule for machine credentials

- **Status:** Accepted
- **Date:** 2026-11-17
- **Applies to:** both sites, the AWS accounts and the supporting SaaS accounts
- **Phase:** 1 (step 0.1 for the accounts and the break-glass kit; step 4.2 for the credential inventory). Later phases add their credentials to the inventory under the same rule.

> **Update ([decision log](../plan.md#decision-log), 2026-11-23):** the break-glass kit holds only the root credentials, so it is refreshed only when one of them changes (one of its seven items, or Bitwarden's recovery code). Other changes are covered by Bitwarden and the quarterly encrypted vault export, with no reprint.

## Context

The project holds two kinds of credential. The first is the operator's **passwords** for the accounts it depends on (AWS root and Identity Center, the Google Accounts, Microsoft, Bitwarden, GitHub, GitLab, Cloudflare, Slack and the outside monitoring services). Each is long, random and unique, generated in Bitwarden, and every account also needs a second factor: one of the two YubiKeys wherever the service supports security keys, otherwise an authenticator code ([ADR 1056](1056-aws-root-mfa-two-security-keys.md), [account sign-in setup guide](../setup/account-sign-in.md)). The second is **machine credentials**: tokens, keys, client secrets and passphrases used by workflows and the clusters, which have no second factor and are copied into secret stores, workflow secrets and sometimes logs.

Several machine credentials already have rotation schedules, set one at a time ([ADR 1047](1047-in-cluster-credentials-and-rotation.md), [ADR 1054](1054-opentofu-state-and-plan-encryption.md) and the plan's recurring tasks), but no decision covers passwords, and nothing ties a rotation to the **break-glass kit**, which is generated from the project's Bitwarden vault and goes stale when an item in it changes ([break-glass kit setup guide](../setup/break-glass-kit.md)).

Current guidance has moved away from scheduled password changes. NIST SP 800-63B-4, section 3.1.1.2, says: "Verifiers and CSPs SHALL NOT require subscribers to change passwords periodically. However, verifiers SHALL force a change if there is evidence that the authenticator has been compromised." The UK National Cyber Security Centre (NCSC) says, in its password guidance: "Regular password changing harms rather than improves security."

## Decision

- **Passwords are changed on events, not on a schedule.** A password is changed at once when any of these happens:
    - there is evidence or suspicion that it was exposed (typed into a phishing page or an untrusted computer, seen by someone, found in a log or a breach notice);
    - the provider reports a breach affecting credentials;
    - a copy of the break-glass kit, or the Bitwarden vault, may have been exposed: then every password in the kit is changed, and the kit passphrase too, following the [break-glass kit compromise runbook](../../runbooks/break-glass-kit-compromise.md);
    - a device signed in to the account is lost or stolen, if the device was unlocked or the password was saved on it.

    The account's sessions are signed out at the same time, and a used recovery code is replaced by generating a new set.
- **Machine credentials are rotated on a schedule,** since nothing else protects them if they leak. Each has an interval, set where it is used:

    | Credential | Interval | Where it is set |
    |---|---|---|
    | GitLab mirror tokens (`GITLAB_PAT`) | Yearly (12-month expiry) | [GitLab group setup guide](../setup/gitlab-group.md), plan recurring tasks |
    | Workstation SSH keys on GitHub and GitLab | Yearly (GitLab's 12-month expiry) | [Workstation YubiKey setup guide](../setup/workstation-yubikey.md#renewing-the-keys-every-year) |
    | OpenTofu state passphrase | Yearly, and at once after a suspected leak | [ADR 1054](1054-opentofu-state-and-plan-encryption.md) |
    | Google OAuth client secrets | Yearly | Plan recurring tasks |
    | WordPress keys and salts | Quarterly | Plan recurring tasks |
    | MariaDB and Valkey passwords | Quarterly (automatic) | [ADR 1047](1047-in-cluster-credentials-and-rotation.md) |
    | Scoped IAM access keys | Every 90 days, until step 9.1 removes them | Plan recurring tasks |
    | GPG backup key | Its expiry is extended every 2 years (the key itself is kept, so existing backups still decrypt) | [Break-glass kit setup guide](../setup/break-glass-kit.md#keeping-the-kit-current) |

    The **credential inventory** (step 4.2) lists every credential that is not a short-lived session, with its interval. A credential with no interval of its own (for example the Slack bot token or a webhook URL) is replaced on the same events as a password, and its row says so.
- **The break-glass kit is refreshed after every change** to an item in the project's Bitwarden vault, whether a scheduled rotation or an event: the kit file is generated again, printed, encrypted and uploaded ([break-glass kit setup guide](../setup/break-glass-kit.md#keeping-the-kit-current)). The **6-monthly kit drill** generates a fresh kit file and compares it with the decrypted cloud copy, so a missed refresh is found.

## Alternatives considered

- **Changing every password on a schedule (for example every 90 days):** the long-standing practice. With random, unique passwords from a password manager, a change adds no strength, and every account already needs a second factor that a stolen password does not give; it would also make the kit stale every quarter and multiply the chances of a mistake in a recovery path. NIST and the NCSC now advise against it.
- **No rotation at all, machine credentials included:** the least work, but a leaked token, key or client secret has no second factor behind it, and a long-lived one can be used for as long as the leak goes unnoticed. Expiry limits that window, and a regular rotation keeps the procedure practised for the day it is needed after a leak.
- **Rotating machine credentials only on events too:** consistent with the rule for passwords, but the events that reveal a machine credential's leak (a token in a CI log, a copied secret) are often not noticed at all.

## Consequences

- Passwords stay stable, so the printed and encrypted kit change only when something happens, and each change has a recorded reason.
- The scheduled rotations stay where they already are, now under one rule, and each one that changes an item in the vault ends with a kit refresh.
- The rule depends on the second factors: an account that loses its second factor, or a service that offers none, gets no protection from a stable password.

## When to revisit

- A compliance framework the project adopts ([ADR 1036](1036-compliance-frameworks-and-privacy.md)) requires periodic password changes.
- An account has to work without a second factor.
- NIST or the NCSC change their guidance.

## References

- NIST: ["Digital Identity Guidelines: Authentication and Authenticator Management (SP `800-63B-4`)"](https://pages.nist.gov/800-63-4/sp800-63b.html) (section 3.1.1.2, password verifiers), checked 2026-11-17
- UK NCSC: ["Password policy: updating your approach"](https://www.ncsc.gov.uk/collection/passwords/updating-your-approach) ("Don't enforce regular password expiry"), checked 2026-11-17
