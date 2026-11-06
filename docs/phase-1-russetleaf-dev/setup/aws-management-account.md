# Setup guide: the AWS management account

The step-by-step procedure for the AWS **management account**: creating it (Phase 1 [step 0.1](../plan.md#step-01-accounts-tools-and-budget-alert)), then the one-time console setup of the Organization and IAM Identity Center that lets Terraform take over ([step 2.0](../plan.md#step-20-aws-organization-and-accounts-security-reference-architecture)). The account's role is described in the Phase 1 design's [AWS account structure](../design.md#aws-account-structure-and-best-practices-security-reference-architecture), and the reasoning in [ADR 1019](../adr/1019-aws-multi-account-sra.md).

The management account owns the Organization and the bill, and sets the guardrails for every other account. It is the one account those guardrails cannot restrict, so it **runs nothing**: no workloads, no Terraform state, no IAM users. People reach it only through IAM Identity Center; its root user is kept for the few tasks only root can do, and for break-glass.

AWS's console changes over time. These steps name each setting rather than every click; where the wording differs, follow the setting's name.

## Before starting

Have these ready:

- **A new email address** for the account's root user, used for nothing else. An alias of the operator's mailbox works, for example `<name>+rl-management@<domain>`: the mail still arrives, but the address is unique to this account.
- **Bitwarden open** (the project's password manager), with a new entry for the account, so the root password is generated there and never typed or reused.
- **Two MFA devices** for root (decision log, 2026-11-05), so losing one (or the phone holding it) never locks the account:
    - **Google Authenticator on the operator's phone, the main factor,** used at each root sign-in. Turn off its **cloud sync** (use the app without signing in to a Google account, or sign out of it in the app's settings), so the codes exist only on the phone rather than also in the Google account.
    - **A YubiKey, the backup,** registered as a security key and kept in the **safe** with the printed break-glass kit ([break-glass kit setup guide](break-glass-kit.md)).
    - **The accepted risk:** AWS accepts any registered device at sign-in, so a code from an app (TOTP) makes root phishable: a fake sign-in page can pass the password and code on to AWS straight away, which it cannot do with a security key. Root is signed in to only a few times, and only through **Bitwarden's autofill**: if Bitwarden does not offer the root login on a page, the address is wrong.
    - **Not in Bitwarden:** Bitwarden can store passkeys and authenticator codes, but it also holds the root password, so a root factor there would put both factors in one vault.
    - **No recovery codes:** AWS has none for root MFA. With both devices lost, AWS's recovery checks the root email address and then calls the account's phone number, so both must stay current. **Do not save the authenticator's secret key** (the QR code shown during setup) as a backup: a copy of it is a third factor, and the YubiKey already covers a lost phone.
- **A payment card and a phone** for AWS's identity check (a small temporary charge, then an SMS or voice call). The advanced sign-up below requires a payment method.

## Part 1: create the account (step 0.1)

1. **Sign up with "Sign up for AWS (advanced)"**, not the simplified "Sign up for AWS (new)" experience: the simplified one creates no root user, has AWS manage the Organization's SCPs and RCPs, and does not offer IAM Access Analyzer, all of which the design needs ([ADR 1019](../adr/1019-aws-multi-account-sra.md)). Use the new email address and **`russetleaf-management`** as the account name, and enter the code AWS emails to confirm the address.
2. **Root password:** generate a long random password in Bitwarden and paste it in.
3. **Contact information:** choose the **Personal** account type, and enter the operator's name, address and phone number.
4. **Payment and identity:** add the card, then complete the SMS or voice check.
5. **Support plan:** choose **Basic** (free). Paid support is not needed for this project.
6. **Sign in as the root user** (the "root user" option on the sign-in page, with the email address).
7. **MFA on root,** before anything else: open **IAM → Security credentials** (the page for the root user) and assign an MFA device. Register the **YubiKey** first (device type **Security key**; touch it when asked), then **Google Authenticator** (device type **Authenticator app**: scan the QR code with the app and enter two codes in a row). An account allows several MFA devices on root. Do not save the QR code or its secret key. Sign out and back in to confirm MFA is asked for, and choose the authenticator app.
8. **No root access keys:** on the same page, confirm the **Access keys** section is empty. Never create one: the root user only ever signs in to the console.
9. **Billing access for Identity Center roles:** in **Account** (from the account menu), turn on **IAM user and role access to Billing information**. Only root can do this; without it, the admin role from Part 2 cannot see budgets or costs.
10. **Alternate contacts:** in the same **Account** page, set the **Security**, **Billing** and **Operations** contacts to the operator, so AWS's security notices reach a person. (Terraform manages these from step 2.0.)
11. **Billing preferences:** in **Billing and Cost Management → Billing preferences**, turn on **Free Tier usage alerts**, and the **billing alerts** that let CloudWatch alarm on charges. Under **Invoice delivery preferences**, choose **PDF invoices delivered by email**, so each month's invoice arrives as a PDF.
12. **The budget:** in **Billing and Cost Management → Budgets**, create a **monthly cost budget** named **`RussetLeaf Monthly Cost Budget`**, of **$50**, with email alerts at **85% of actual** and **100% of forecast** spend, to the operator's email. Because this is the management account, the budget covers every account the Organization creates later (consolidated billing). Terraform takes it over in step 2.0.
13. **Region:** in the console's region menu, choose **US East (N. Virginia), `us-east-1`**, the project's region. The SCPs in step 2.0 allow only `us-east-1` and `us-west-2`.
14. **The break-glass kit** ([disaster recovery plan](../disaster-recovery.md#break-glass-kit)): record the **account ID** (shown in the account menu), the **root email**, the **root password**, and **which MFA devices are registered** (Google Authenticator on the phone, the YubiKey in the safe). Add the starred items to the printed copy and the encrypted cloud copies ([break-glass kit setup guide](break-glass-kit.md)), and put the YubiKey back in the safe.
15. **Sign out.** Nothing else is done in this account until step 2.0.

**Checks:**

- [ ] Signing in as root asks for MFA, and both MFA devices work (sign in once with each).
- [ ] Google Authenticator's cloud sync is off for the root entry.
- [ ] The root user's **Security credentials** page shows **no access keys**.
- [ ] **IAM user and role access to Billing information** is on.
- [ ] **Invoice delivery preferences** are set to **PDF invoices delivered by email**.
- [ ] The **RussetLeaf Monthly Cost Budget** ($50) exists with its two alerts (85% of actual, 100% of forecast).
- [ ] The **alternate contacts** are set.
- [ ] The **break-glass kit** has the account ID, root login and MFA notes, and the printed copy is updated.

## Part 2: bootstrap the Organization and Identity Center (step 2.0)

Terraform manages the Organization from step 2.0, but it needs a way to sign in first. An organization-wide IAM Identity Center can only be **enabled in the console**, so this part is done by hand once, as root, and Terraform imports the result.

1. **Sign in as root** (with MFA), in region **`us-east-1`**.
2. **Create the Organization:** open **AWS Organizations** and choose **Create an organization**, with **all features** enabled. If AWS asks to verify the management account's email address, follow the link it sends (it is needed before accounts can be invited).
3. **Enable IAM Identity Center:** open **IAM Identity Center** and choose **Enable**, as an **organization instance** (with AWS Organizations). Its home region is **`us-east-1`**, which cannot be changed later without deleting the instance.
4. **Identity source:** keep the default, the **Identity Center directory**.
5. **The AWS access portal address:** under **Settings**, change the portal's subdomain to something memorable (for example `russetleaf`, giving `https://russetleaf.awsapps.com/start`), and record it in the break-glass kit.
6. **MFA settings:** under **Settings → Authentication**, require MFA **every time users sign in**, require users to **register an MFA device at sign-in**, and allow **security keys and built-in authenticators** (passkeys) only, with **authenticator apps** turned off: Identity Center is signed in to daily, so it keeps phishing-resistant factors only (decision log, 2026-11-05).
7. **The operator's user:** under **Users**, add a user for the operator (their name and email), and accept the invitation from the email: set a password (from the password manager) and register two MFA devices: a **passkey** on the operator's phone (not in Bitwarden, which holds the password) for daily sign-in, and the **YubiKey** from the safe as the backup.
8. **A bootstrap admin permission set:** under **Permission sets**, create one from the predefined **AdministratorAccess** policy, named **`admin`** (the name Terraform will manage it under), with a session duration of **4 hours**.
9. **Assign it:** under **AWS accounts**, select the management account, and assign the operator's user with the **`admin`** permission set.
10. **Sign in from the workstation:**

    ```bash
    aws configure sso
    #   SSO session name:        russetleaf
    #   SSO start URL:           https://russetleaf.awsapps.com/start  (the portal address from step 5)
    #   SSO region:              us-east-1
    #   Registration scopes:     sso:account:access  (the default)
    #   Then choose the management account and the admin role in the browser, and answer:
    #   Default client region:   us-east-1
    #   Output format:           json
    #   Profile name:            rl-mgmt-admin
    aws sso login --sso-session russetleaf
    aws sts get-caller-identity --profile rl-mgmt-admin
    ```

11. **Sign out of the root user.** From here on, people use the AWS access portal and the `rl-mgmt-admin` profile; root is used only for break-glass and root-only tasks.
12. **Hand over to Terraform:** in `russetleaf-infra/envs/org/`, import the Organization, the `admin` permission set, the operator's user and the account assignment (for example with `import` blocks), so Terraform manages them from then on. Everything else in step 2.0 (OUs, accounts, SCPs, RCPs, the other permission sets) is created by Terraform.

**Checks:**

- [ ] The Organization exists with **all features** enabled, and the management account is its only account so far.
- [ ] Signing in to the **AWS access portal** asks for MFA, and shows the management account with the `admin` role.
- [ ] `aws sts get-caller-identity --profile rl-mgmt-admin` returns the management account, with an `AWSReservedSSO_admin_...` role.
- [ ] No IAM users exist in the management account, and root still has no access keys.
- [ ] After the import, `terraform plan` in `envs/org` proposes no changes to the imported resources.

## If something goes wrong

- **Lost the phone:** get the YubiKey from the safe, sign in with it, remove the Google Authenticator device, and register the app on the new phone right away (sync off). Do the same for the Identity Center passkey.
- **Lost the YubiKey:** sign in with Google Authenticator, remove the YubiKey, and register a new one.
- **Lost both MFA devices:** on the root sign-in page, choose **Troubleshoot MFA**, then **Sign in using alternative factors**. AWS sends a link to the root email address, then calls the phone number on the account. There are no recovery codes, which is why the root email address and the phone number are kept current in the break-glass kit. If neither works, contact AWS Support.
- **The management account is compromised or lost:** follow the [disaster recovery plan](../disaster-recovery.md#scenarios) ("Management account compromised or lost").
