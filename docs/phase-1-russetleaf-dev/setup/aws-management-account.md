# Setup guide: the AWS management account

The step-by-step procedure for the AWS **management account**: creating it (Phase 1 [step 0.1](../plan.md#step-01-accounts-tools-and-budget-alert)), then the one-time console setup of the Organization and IAM Identity Center that lets Terraform take over ([step 2.0](../plan.md#step-20-aws-organization-and-accounts-security-reference-architecture)). The account's role is described in the Phase 1 design's [AWS account structure](../design.md#aws-account-structure-and-best-practices-security-reference-architecture), and the reasoning in [ADR 1019](../adr/1019-aws-multi-account-sra.md).

The management account owns the Organization and the bill, and sets the guardrails for every other account. It is the one account those guardrails cannot restrict, so it **runs nothing**: no workloads, no Terraform state, no IAM users. People reach it only through IAM Identity Center; its root user is kept for the few tasks only root can do, and for break-glass.

AWS's console changes over time. These steps name each setting rather than every click; where the wording differs, follow the setting's name.

## Before starting

Have these ready:

- **A new email address** for the account's root user, used for nothing else. An alias of the operator's mailbox works, for example `<name>+rl-management@<domain>`: the mail still arrives, but the address is unique to this account.
- **Bitwarden open** (the project's password manager), with a new entry for the account, so the root password is generated there and never typed or reused.
- **Two MFA devices** for root: two hardware security keys, or one key and a passkey ([ADR 1032](../adr/1032-defense-in-depth.md)). The second is the backup, kept apart from the first, so losing one (or the phone holding it) never locks the account; without a working device, the only way back in is AWS's slower root account recovery.
    - **A passkey on the operator's phone** works as one of the two. Pair it with a **hardware security key** as the backup, kept with the printed break-glass kit rather than on the same key ring or in the same bag as the phone.
    - **Not in Bitwarden:** Bitwarden can store passkeys, but it also holds the root password, so a root passkey there would put both factors in one vault.
    - **Not an authenticator app as the only factor:** a code from an app (TOTP) works with AWS, but it can be phished, unlike a passkey or security key. If the phone's MFA is an authenticator app, the hardware key becomes the main factor and the app its backup.
- **A payment card and a phone** for AWS's identity check (a small temporary charge, then an SMS or voice call). The advanced sign-up below requires a payment method.

## Part 1: create the account (step 0.1)

1. **Sign up with "Sign up for AWS (advanced)"**, not the simplified "Sign up for AWS (new)" experience: the simplified one creates no root user, has AWS manage the Organization's SCPs and RCPs, and does not offer IAM Access Analyzer, all of which the design needs ([ADR 1019](../adr/1019-aws-multi-account-sra.md)). Use the new email address and **`russetleaf-management`** as the account name, and enter the code AWS emails to confirm the address.
2. **Root password:** generate a long random password in Bitwarden and paste it in.
3. **Contact information:** choose the **Personal** account type, and enter the operator's name, address and phone number.
4. **Payment and identity:** add the card, then complete the SMS or voice check.
5. **Support plan:** choose **Basic** (free). Paid support is not needed for this project.
6. **Sign in as the root user** (the "root user" option on the sign-in page, with the email address).
7. **MFA on root,** before anything else: open **IAM → Security credentials** (the page for the root user) and assign an MFA device. Register the **first security key or passkey**, then **the second one** as well (an account allows several MFA devices on root). Sign out and back in to confirm MFA is asked for.
8. **No root access keys:** on the same page, confirm the **Access keys** section is empty. Never create one: the root user only ever signs in to the console.
9. **Billing access for Identity Center roles:** in **Account** (from the account menu), turn on **IAM user and role access to Billing information**. Only root can do this; without it, the admin role from Part 2 cannot see budgets or costs.
10. **Alternate contacts:** in the same **Account** page, set the **Security**, **Billing** and **Operations** contacts to the operator, so AWS's security notices reach a person. (Terraform manages these from step 2.0.)
11. **Billing preferences:** in **Billing and Cost Management → Billing preferences**, turn on **Free Tier usage alerts**, and the **billing alerts** that let CloudWatch alarm on charges.
12. **The budget:** in **Billing and Cost Management → Budgets**, create a **monthly cost budget** of **$25**, with email alerts at **80% of actual** and **100% of forecast** spend, to the operator's email. Because this is the management account, the budget covers every account the Organization creates later (consolidated billing). Terraform takes it over in step 2.0.
13. **Region:** in the console's region menu, choose **US East (N. Virginia), `us-east-1`**, the project's region. The SCPs in step 2.0 allow only `us-east-1` and `us-west-2`.
14. **The break-glass kit** ([disaster recovery plan](../disaster-recovery.md#break-glass-kit)): record the **account ID** (shown in the account menu), the **root email**, the **root password**, and **which MFA devices are registered and where the backup is kept**. Add the starred items to the printed copy.
15. **Sign out.** Nothing else is done in this account until step 2.0.

**Checks:**

- [ ] Signing in as root asks for MFA, and both MFA devices work.
- [ ] The root user's **Security credentials** page shows **no access keys**.
- [ ] **IAM user and role access to Billing information** is on.
- [ ] The **$25 budget** exists with its two alerts.
- [ ] The **alternate contacts** are set.
- [ ] The **break-glass kit** has the account ID, root login and MFA notes, and the printed copy is updated.

## Part 2: bootstrap the Organization and Identity Center (step 2.0)

Terraform manages the Organization from step 2.0, but it needs a way to sign in first. An organization-wide IAM Identity Center can only be **enabled in the console**, so this part is done by hand once, as root, and Terraform imports the result.

1. **Sign in as root** (with MFA), in region **`us-east-1`**.
2. **Create the Organization:** open **AWS Organizations** and choose **Create an organization**, with **all features** enabled. If AWS asks to verify the management account's email address, follow the link it sends (it is needed before accounts can be invited).
3. **Enable IAM Identity Center:** open **IAM Identity Center** and choose **Enable**, as an **organization instance** (with AWS Organizations). Its home region is **`us-east-1`**, which cannot be changed later without deleting the instance.
4. **Identity source:** keep the default, the **Identity Center directory**.
5. **The AWS access portal address:** under **Settings**, change the portal's subdomain to something memorable (for example `russetleaf`, giving `https://russetleaf.awsapps.com/start`), and record it in the break-glass kit.
6. **MFA settings:** under **Settings → Authentication**, require MFA **every time users sign in**, require users to **register an MFA device at sign-in**, and allow **security keys and built-in authenticators** (passkeys).
7. **The operator's user:** under **Users**, add a user for the operator (their name and email), and accept the invitation from the email: set a password (from the password manager) and register **both** MFA devices.
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

- **Lost one MFA device:** sign in with the other, remove the lost device, and register a replacement right away.
- **Lost both MFA devices:** use AWS's account recovery for the root user (it verifies the account's email address and phone number); this is why both are kept current in the break-glass kit.
- **The management account is compromised or lost:** follow the [disaster recovery plan](../disaster-recovery.md#scenarios) ("Management account compromised or lost").
