# ADR 1055: AWS root MFA: a synced authenticator app, with the Google Account under Advanced Protection (accepted risk)

- **Status:** Superseded by [ADR 1056](1056-aws-root-mfa-two-security-keys.md) (two security keys, no authenticator app, 2026-11-06)
- **Date:** 2026-11-06
- **Applies to:** the AWS management account's root user (the only root user with credentials; member accounts have none, [ADR 1019](1019-aws-multi-account-sra.md))
- **Phase:** 1 (step 0.1; the Security Hub suppression in step 2.0b)

## Context

The root user of the management account has two MFA devices ([AWS management account setup guide](../setup/aws-management-account.md#before-starting)): **Google Authenticator** on the operator's phone as the main factor, and a **YubiKey** (security key) in the safe as the backup. The guide first required Google Authenticator's **cloud sync to be off**, so the codes existed only on the phone (decision log, 2026-11-05). The operator wants sync on, so that a lost or replaced phone gets its codes back without a recovery procedure.

With sync on, the authenticator's secrets for the root user are stored in the operator's **Google Account**. The **root email address** is in the same Google Account. On their own, the two would put the whole root user behind one Google sign-in: whoever controls that account can reset the root password by email and read a current code from the synced app, without needing Bitwarden. The Google Account's own sign-in, which accepted authenticator codes as well as the YubiKey, could be phished.

Two further facts apply whatever is decided about sync:

- **An authenticator app (TOTP) on root can be phished** at AWS's sign-in page, unlike a security key; AWS accepts any registered device.
- **CIS AWS Foundations** (run by Security Hub, [ADR 1019](1019-aws-multi-account-sra.md)) expects **hardware MFA for the root user**; its control **IAM.6** is expected to fail while a virtual MFA device is registered.

## Decision

- **Google Authenticator keeps cloud sync on,** as the root user's main factor; the YubiKey stays registered as the backup, in the safe.
- **The Google Account is enrolled in Google's Advanced Protection Program:** every sign-in needs a **passkey or security key** (no authenticator codes, SMS or voice), with at least two registered (a passkey on the operator's phone and the YubiKey), and Google's stricter account recovery. This makes the Google Account resistant to phishing, which is what keeps one Google sign-in from being an easy path to root.
- **Controls already in place stay as they are:** root is signed in to only a few times and only through **Bitwarden's autofill** (it fills only on AWS's real sign-in page); root has **no access keys**; every root console sign-in alerts **`#rl-security` and `#rl-critical`** (step 2.0b); the authenticator's secret is not copied anywhere else.
- **Security Hub control IAM.6** ("Hardware MFA should be enabled for the root user") is **suppressed** in the management account, with a link to this ADR as the reason (step 2.0b), and is reviewed with the other accepted findings in the weekly Security Hub review.
- **Scope:** this is an accepted risk for a project with one operator and no paying users. It would **not** be acceptable in an organization with several administrators, customer data or a compliance audit, where root uses hardware MFA only, the root email is a shared, separately protected mailbox, and no root factor is synced to a person's account.

## Alternatives considered

- **Sync off** (the earlier decision): the codes exist only on the phone, but a lost phone means signing in with the YubiKey from the safe and re-registering; it does not fix TOTP phishing at AWS or the IAM.6 finding.
- **The YubiKey as the main factor, no authenticator app:** phishing-resistant and passes IAM.6, but every root sign-in needs the key from the safe, and a second security key is needed as the backup.
- **Two hardware security keys:** the strongest option and what CIS expects; one more key to buy, and no app on the phone.
- **Aegis or Ente Auth** (open-source authenticators, [ADR 1053](1053-open-source-tools-by-default.md)): Aegis has no cloud sync; Ente Auth syncs with end-to-end encryption, so its provider cannot read the secrets. Either is a drop-in replacement, but the operator prefers Google Authenticator.
- **A separate mailbox for the root email address:** splits the email reset path from the synced codes; Advanced Protection makes the shared Google Account acceptable, so this is kept as an option rather than required.

## Consequences

- **The risk is accepted as minor,** not removed:
    - **Malware on the phone,** or a stolen, already signed-in Google session, could still reach the synced codes and the root email address; Advanced Protection blocks phishing, not these. The root sign-in alerts make any use visible within minutes.
    - **TOTP at AWS's own sign-in page** can still be phished; signing in only through Bitwarden's autofill is the defense.
- **Availability improves:** a new phone restores the codes once the Google Account is signed in with its passkey or the YubiKey.
- **Recovery depends on the Google Account more:** Advanced Protection's account recovery takes several days, and both the root email reset and the synced codes are in that account. Its passkey and security keys are therefore kept current in the break-glass kit, like the AWS root devices.
- **Security Hub's CIS score** shows IAM.6 as suppressed, with this ADR as the recorded reason.

## When to revisit

- A second person needs root or administrator access, the project takes on customer data or paying users, or a compliance audit is required: move root to hardware MFA only (two security keys) and give it a separate root mailbox.
- Any incident involving the Google Account, the phone or the root user.
- Google changes Advanced Protection, or Google Authenticator's sync gains (or loses) end-to-end encryption.
