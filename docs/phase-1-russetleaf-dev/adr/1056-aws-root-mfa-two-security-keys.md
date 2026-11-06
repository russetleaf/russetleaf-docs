# ADR 1056: AWS root MFA: two hardware security keys, no authenticator app

- **Status:** Accepted. It supersedes [ADR 1055](1055-aws-root-mfa-synced-authenticator.md).
- **Date:** 2026-11-06
- **Applies to:** the AWS management account's root user, and the operator's IAM Identity Center user
- **Phase:** 1 (step 0.1; the Security Hub check in step 2.0b)

## Context

[ADR 1055](1055-aws-root-mfa-synced-authenticator.md) kept Google Authenticator, with cloud sync on, as the root user's main factor, because the only security key lived in the safe and opening it for every sign-in was impractical. It accepted three costs: an authenticator code can be phished at AWS's sign-in page, the synced codes sit in the same Google account as the root email address, and Security Hub's CIS control **IAM.6** (hardware MFA for the root user) had to be suppressed.

The operator now has a **second YubiKey**, carried on the keychain. With one key at hand and one in the safe, the reason for the authenticator app is gone.

## Decision

- **The root user's MFA devices are two YubiKeys,** registered as security keys: the **keychain key** for sign-ins, and the **safe key** as the backup, kept apart from it. **No authenticator app (virtual MFA device) is registered**, and the Google Authenticator entry for root is deleted.
- **Both keys have a FIDO2 PIN,** so a lost or stolen key cannot be used without it (and the root password, in Bitwarden, is still needed).
- **Changing over:** register the keychain key on root first, confirm a sign-in with it, then remove the virtual MFA device, so root always has a working factor.
- **IAM.6 is not suppressed:** with only hardware MFA on root, the control should pass; step 2.0b checks it.
- **The Google account stays in Advanced Protection,** with a phone passkey and both YubiKeys registered: it still holds the root email address, which is AWS's recovery path when both keys are lost.
- **The IAM Identity Center user** signs in with a **passkey on the phone** or the **keychain key**, with the safe key registered as the backup.

## Alternatives considered

- **Keep the synced authenticator app** ([ADR 1055](1055-aws-root-mfa-synced-authenticator.md)): restores codes on a new phone, but leaves root phishable through a code and its factor in the Google account; the keychain key now gives the same convenience without either cost.
- **Keep the app as a third factor:** AWS accepts any registered device, so a third, phishable factor weakens root to the level of that factor; two keys in different places already cover the loss of one.
- **A third security key:** more protection against losing both, but AWS's email-and-phone recovery already covers that rare case.

## Consequences

- **Root cannot be phished:** a security key answers only AWS's real sign-in page.
- **No root factor is stored in the Google account or on the phone,** and the accepted risk of [ADR 1055](1055-aws-root-mfa-synced-authenticator.md) no longer exists.
- **Security Hub's CIS score** includes IAM.6 as passed, with nothing suppressed for root.
- **The keychain key travels,** so it is more likely to be lost: the PIN protects it, the safe key covers the loss, and a lost key is removed from root (and from the other accounts it is registered with) at once.
- **Losing both keys** means AWS's recovery through the root email address and the account's phone number, as before.

## When to revisit

- A second person needs root or administrator access: give each person their own keys, and consider a shared, separately protected root mailbox.
- AWS changes the MFA options for root (for example, passkeys tied to a platform account).
