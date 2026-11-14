# Setup guide: Google Workspace on russetleaf.dev

The step-by-step procedure for the project's **Google Workspace** organization on the russetleaf.dev domain (Phase 1 [step 0.1](../plan.md#step-01-accounts-tools-and-budget-alert)): the operator's account `<name>@russetleaf.dev`, the domain's mail records, security keys enforced for every sign-in, Advanced Protection, and the groups that receive the AWS accounts' email. The reasoning is in [ADR 1059](../adr/1059-google-workspace-identity.md).

The steps follow Google's Admin Help ([verify the domain](https://knowledge.workspace.google.com/admin/domains/verify-your-domain-with-a-txt-record), [MX records](https://knowledge.workspace.google.com/admin/domains/set-up-mx-records-for-google-workspace), [SPF](https://knowledge.workspace.google.com/admin/security/set-up-spf), [DKIM](https://knowledge.workspace.google.com/admin/security/set-up-dkim), [DMARC](https://knowledge.workspace.google.com/admin/security/set-up-dmarc), [2-Step Verification](https://knowledge.workspace.google.com/admin/security/deploy-2-step-verification), [Advanced Protection](https://knowledge.workspace.google.com/admin/security/enable-user-enrollment-in-the-advanced-protection-program), [admin recovery](https://knowledge.workspace.google.com/admin/users/recovering-administrator-access-to-your-account)).
**Note:** the click paths in this guide are those the services showed when the procedure was last carried out. Providers change their consoles without notice, and their own documentation can lag behind the console. Before following a path, check the provider's current documentation, linked in each part; where the screen still differs, follow what it shows and fix this guide to match.

**Important:** two Google Accounts are involved. The **Workspace account** is the project's identity. The operator's **personal Google Account** (in Advanced Protection, [account sign-in setup guide](account-sign-in.md)) is kept for the two jobs that must not depend on russetleaf.dev: the Workspace account's **recovery email**, and the **Cloudflare** sign-in. Cloudflare is the registrar and DNS host for russetleaf.dev, and Google's own admin recovery proves ownership of the domain through a DNS record; if either depended on the Workspace account, a domain or DNS problem would lock the operator out of the one place that can fix it.

## Before starting

Have these ready:

- **Both YubiKeys**, each with a FIDO2 PIN.
- **Bitwarden**, for the Workspace account's password and backup codes.
- **The Cloudflare dashboard**, signed in, for the DNS records of russetleaf.dev.
- **The personal Google Account's address** and the operator's **phone number**, for recovery.

## Part 1: Sign up and verify the domain

1. **Sign up** for **Google Workspace Business Starter**, with the existing domain **russetleaf.dev**, one user: the operator's account `<name>@russetleaf.dev`, which is also the organization's **super administrator**. Generate its password in Bitwarden.
2. **Verify the domain:** in the setup tool (or the Admin console's **Menu → Account → Domains → Manage domains → Verify domain**), choose **Cloudflare** as the host. Google offers to add the records itself: it opens the Cloudflare dashboard with the records filled in, and after the operator authorizes them, it verifies the domain and activates Gmail. It adds the verification TXT record, the MX record (`smtp.google.com`), SPF and a DKIM key, which are checked in Part 2.
3. **If the automatic setup is not offered** (or fails): copy the TXT value Google shows, which starts with `google-site-verification=`, add it in Cloudflare's DNS for russetleaf.dev (type **TXT**, name `@`), and select **Confirm** in the Admin console. Google can take up to 72 hours to see the record. Keep the record in place; Google rechecks it later.

## Part 2: Mail records

Check each record in Cloudflare's DNS, and add any that the automatic setup did not create:

1. **MX:** type **MX**, name `@`, mail server `smtp.google.com` (the automatic setup uses priority 10, Google's manual steps priority 1; with one MX record either works), and no other MX record. If Gmail is not yet active, select **Activate Gmail** under **Manage domains**.
2. **SPF:** type **TXT**, name `@`, value `v=spf1 include:_spf.google.com ~all`. SES, which sends WordPress's mail, uses its own MAIL FROM domain by default and does not need an entry here; its DKIM records are added in [step 2.3](../plan.md#step-23-aws-and-cloudflare-resources-for-the-home-lab).
3. **DKIM:** the automatic setup adds the key (name `google._domainkey`, value starting `v=DKIM1;k=rsa;p=`). Otherwise, 24 to 72 hours after Gmail is active, go to **Menu → Apps → Google Workspace → Gmail → Authenticate email**, select russetleaf.dev, choose **Generate New Record** with a **2048**-bit key and the default prefix `google`, and add the TXT record it shows. Either way, on **Authenticate email**, select **Start authentication** if the status is not already "Authenticating email with DKIM". The page can keep showing "You must update the DNS records for this domain" for up to 48 hours after the record is added; Google's help says to ignore it once the record in DNS matches the one shown and the status says "Authenticating email with DKIM".
4. **DMARC**, at least 48 hours after SPF and DKIM are authenticating, and after the reports group exists (Part 4):
    1. **Check alignment first:** send a message from `<name>@russetleaf.dev` to an outside Gmail address and open it there with **⋮ (More) → Show original**. The `Authentication-Results` line must show `dkim=pass header.i=@russetleaf.dev header.s=google` and `spf=pass ... smtp.mailfrom=<name>@russetleaf.dev`, so both pass for russetleaf.dev itself. Before the record exists, that line has no `dmarc=` result, while Gmail's summary at the top of the page shows DMARC as `FAIL`; the summary label does not mean a check failed.
    2. **Add the record** in the Cloudflare dashboard: **Account home → russetleaf.dev → DNS → Records → Add record**, with **Type** `TXT`, **Name** `_dmarc` (Cloudflare appends the domain), **TTL** Auto and **Content** `v=DMARC1; p=none; rua=mailto:<dmarc-reports-group>@russetleaf.dev`, then **Save**. Confirm first that no other `_dmarc` record exists: two records make DMARC fail for every message. Cloudflare's dashboard also offers a DMARC record under its recommendations; use it only if its content is exactly this, since it can point the reports elsewhere.
    3. **Test:** a new message checked the same way shows `dmarc=pass`, and the daily reports arrive under the DMARC group's label within a day or two.
    4. **Tighten later:** start at `p=none`, review the reports, and move to `quarantine` and then `reject` once only Google and SES appear ([improvement I1-5](../improvements.md)).

These records are imported into OpenTofu with the rest of russetleaf.dev's DNS in [step 2.3](../plan.md#step-23-aws-and-cloudflare-resources-for-the-home-lab).

## Part 3: The account's sign-in

1. **Recovery information:** in **Menu → Directory → Users**, select the operator's account, then **Security → Recovery information**: the **personal Google Account** as the recovery email and the operator's phone as the recovery phone.
2. **Security keys:** signed in as the Workspace account, under **Security → Passkeys and security keys**, register `yubikey-primary` and `yubikey-backup` (security keys, named as such). Google asks for a key at sign-in only once 2-Step Verification applies to the account, so the keys are tested in step 3.
3. **Enforce security keys for the organization:** the setup tool's 2-Step Verification step opens the same admin setting, **Menu → Security → Authentication → 2-step verification**:
    - **Allow users to turn on 2-Step Verification:** selected.
    - **Enforcement:** **On**.
    - **Methods:** **Only security key or passkey**.
    - **Allow user to trust the device:** cleared, so every sign-in asks for a key; a key touch costs little, and a trusted browser would skip the check.
    - **New user enrollment period:** none (one user, whose keys are registered first).
    - **2-Step Verification policy suspension grace period:** one day, the time during which an administrator-generated backup code lets the account sign in, for example after a lost key.
    - **Security codes:** "Don't allow users to generate security codes". A security code is a one-time code made with a key, for signing in on a device that cannot use one; the YubiKeys work by USB and, on the phone, by NFC, so none is needed, and a code is the one thing a phishing page could ask for.

    **Test before leaving the page:** keep the Admin console open, signed in, in the current window, then sign in to the Workspace account in a **private window** with `yubikey-primary`, and again in a new private window with `yubikey-backup`. If either fails, set **Enforcement** back to **Off** from the open Admin console window, which stays signed in.
4. **Backup codes:** with **Only security key or passkey** enforced, users cannot generate their own backup codes; generate them for the operator's account as the administrator (the user's **Security** settings), save them in Bitwarden, and add them to the printed kit at the end of step 0.1 ([break-glass kit setup guide](break-glass-kit.md)).
5. **Advanced Protection:** in **Menu → Security → Authentication → Advanced Protection Program**, keep **Enable user enrollment** (the default) and the option "Don't allow users to generate security codes"; then, signed in as the Workspace account, open `https://landing.google.com/advancedprotection/` (the self-enrollment page Google's Workspace help names), select **Get started**, and enroll, confirming with a YubiKey. Use a private window signed in only as the Workspace account, so the enrollment does not pick up the personal Google Account. Confirm under **Menu → Directory → Users** → the account → **Security**, where **Advanced Protection** shows **On**. Enrolling signs the account out of every device.

## Part 4: Groups

Each address that a service sends important mail to is a **group** with the operator as its member, so the address is not tied to one mailbox and can gain a second member later:

1. **Allow outside senders, once for the organization:** in **Menu → Apps → Google Workspace → Groups for Business → Sharing settings**, select "Group owners can allow incoming email from outside the organization"; leave "Group owners can allow external members" cleared and access from outside the organization **Private**; save. AWS and the DMARC reporters are outside the organization, and groups refuse their mail otherwise.
2. **Create each group** in **Menu → Directory → Groups → Create group**, with the operator as owner:
    - one group per **AWS account's root email** (the management account first; the accounts step 2.0 creates later), for example `<aws-account-group>@russetleaf.dev`, with the real names kept in Bitwarden rather than in these documents
    - the **DMARC reports** group

    Leave **Security** cleared. For the access type, start from **Restricted** and change only **Who can post**, selecting every option: **Group owners**, **Group managers**, **Group members**, **Entire organization** and **External**. Keep the Restricted defaults for who can contact the owners, view conversations, view members and manage members, so the group's contents stay private. Then **Create Group**.
3. **Membership** (Admin console): open the group, then **Members**; if the operator is not listed, select **Add members**, choose the account, and **Add To Group**. The operator's role is **Owner**.
4. **Spam handling and moderation** (the Google Groups app, not the Admin console, whose group page has only **Access settings**): at `https://groups.google.com`, open the group, then **Group settings → Posting policies**; set **Spam message handling** to "Post suspicious messages to the group" and **Message moderation** to "No moderation", and **Save changes**. A message held for moderation (an AWS verification code, for example) would otherwise block the procedure waiting for it.
5. **Gmail filters** (the Workspace mailbox), one per group, because Gmail's own spam filter sends a new domain's group mail to **Spam** at first: in Gmail's search options, enter the group's address in **To**, select **Create filter**, then **Never send it to Spam** and **Apply the label**: `AWS/<group-name>` for each AWS account's group (Gmail creates the parent **AWS** label, so all AWS mail is together and each account is separate), and a label named after the group for DMARC reports (optionally with **Skip the Inbox**). Each AWS account that step 2.0 creates gets its own group, filter and label.
6. **Test** each group by sending a message from the personal Google Account: it arrives in the operator's Gmail under the group's label, not in **Spam**. Mark any earlier test found in **Spam** as **Report not spam**.

## Part 5: Where the Workspace account is used

- **Sign-in with Google** for Slack ([account sign-in setup guide](account-sign-in.md)), Google sign-in for the WordPress admins and Dex (restricted to the russetleaf.dev domain; [ADR 1008](../adr/1008-google-sign-in-for-admins.md), [ADR 1033](../adr/1033-identity-and-access.md)), and the Google Cloud project that issues those OAuth clients.
- **The email address** of the AWS accounts (groups, Part 4), the IAM Identity Center user, the GitHub organization's and GitLab group's contact email, the heartbeat service and the uptime checker.
- **Not** for Cloudflare, Bitwarden or Microsoft, which stay on the operator's personal accounts.

## Part 6: Security alerts

Google's **Alert Center** raises alerts about the organization's accounts, such as a suspicious sign-in or a new administrator. Each alert comes from a **rule**, and the rule decides whether anyone is emailed. These steps make sure the alerts that point to misuse of the account reach the operator's mailbox. Step 7.16 later sends the same events to the cluster's detections and to Slack ([plan](../plan.md#step-716-mail-and-identity-monitoring)).

1. **Open the rules:** in the Admin console, **Menu → Rules**. (From **Menu → Security → Alert center**, **Manage alerts and email notifications** opens the same page.)
2. **For each of these rules** (all are available on Business Starter): **Suspicious login**, **Leaked password**, **Government-backed attacks**, **Suspicious programmatic login**, **User suspended due to suspicious activity**, **User granted Admin privilege**, **Primary admin changed**, and **Admin password reset**:
    1. Select the rule to open **Rule details**, then the **Actions** panel.
    2. Turn **Alerts** **On**, with the default severity.
    3. Under **Send email notifications**, select **All super administrators**.
    4. Select **NEXT: REVIEW**, then **UPDATE RULE**.
3. **See the alerts** at **Menu → Security → Alert center**. Google keeps alerts for about 10 years.

## Checks

- [ ] russetleaf.dev shows as **verified** under **Manage domains**, and Gmail as active.
- [ ] A message from an outside address reaches `<name>@russetleaf.dev`, and a message from it to an outside Gmail address shows `spf=pass`, `dkim=pass` and `dmarc=pass` under **Show original**.
- [ ] Signing in to the Workspace account asks for a security key, both YubiKeys work, and **2-step verification** shows enforcement **On**, **Only security key or passkey**, and security codes not allowed.
- [ ] The account is enrolled in **Advanced Protection**, and its recovery email is the personal Google Account.
- [ ] The backup codes are in Bitwarden.
- [ ] Each group receives a message from outside the organization, under its label and not in **Spam**.
- [ ] Each rule in Part 6 shows **Alerts** on and email notifications to **All super administrators**.

## If something goes wrong

- **Lost `yubikey-primary`:** sign in with `yubikey-backup`, remove the lost key under **Passkeys and security keys**, and register a replacement; then follow the [account sign-in setup guide](account-sign-in.md#if-something-goes-wrong) for the other accounts.
- **Locked out of the Workspace account** (both keys lost): sign in with a backup code from the kit; failing that, use Google's account recovery with the recovery email or phone; failing that, Google's administrator recovery, which proves ownership of russetleaf.dev with a DNS record added at Cloudflare. That last path is why Cloudflare does not sign in with the Workspace account.
- **Mail stops arriving:** check the MX record and the domain's verification under **Manage domains**; removing the TXT verification record can cost the domain its verified status.
- **The Workspace subscription lapses:** mail to russetleaf.dev stops, and with it the AWS root email path. Keep the subscription's payment method current, and the domain's auto-renew on.

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- Google: ["Choose your Google Workspace edition"](https://knowledge.workspace.google.com/admin/getting-started), checked 2026-11-12
- Google: ["Verify your domain with a TXT record"](https://knowledge.workspace.google.com/admin/domains/verify-your-domain-with-a-txt-record), checked 2026-11-12
- Google: ["Set up MX records for Google Workspace"](https://knowledge.workspace.google.com/admin/domains/set-up-mx-records-for-google-workspace), checked 2026-11-12
- Google: ["Set up SPF"](https://knowledge.workspace.google.com/admin/security/set-up-spf), checked 2026-11-12
- Google: ["Set up DKIM"](https://knowledge.workspace.google.com/admin/security/set-up-dkim), checked 2026-11-12
- Google: ["Set up DMARC"](https://knowledge.workspace.google.com/admin/security/set-up-dmarc), checked 2026-11-12
- Google: ["Recommended DMARC rollout"](https://knowledge.workspace.google.com/admin/security/recommended-dmarc-rollout), checked 2026-11-12
- Google: ["Deploy 2-Step Verification"](https://knowledge.workspace.google.com/admin/security/deploy-2-step-verification), checked 2026-11-12
- Google: ["Manage a user's security settings (backup verification codes)"](https://knowledge.workspace.google.com/admin/security/manage-a-users-security-settings), checked 2026-11-12
- Google: ["Add recovery information for admins & users"](https://knowledge.workspace.google.com/admin/users/add-recovery-information-for-admins-and-users), checked 2026-11-12
- Google: ["Enable user enrollment in the Advanced Protection Program"](https://knowledge.workspace.google.com/admin/security/enable-user-enrollment-in-the-advanced-protection-program), checked 2026-11-12
- Google: ["Advanced Protection Program"](https://landing.google.com/advancedprotection/), checked 2026-11-12
- Google: ["Recovering administrator access to your account"](https://knowledge.workspace.google.com/admin/users/recovering-administrator-access-to-your-account), checked 2026-11-12
- Google: ["Set organization-wide policies for using groups"](https://knowledge.workspace.google.com/admin/groups/set-organization-wide-policies-for-using-groups), checked 2026-11-12
- Google: ["Create a group in your organization"](https://knowledge.workspace.google.com/admin/groups/create-a-group-in-your-organization), checked 2026-11-12
- Google: ["Add or invite users to a group"](https://knowledge.workspace.google.com/admin/groups/add-or-invite-users-to-a-group), checked 2026-11-12
- Google: ["Create a group (Google Workspace Learning Center: posting policies, spam message handling)"](https://support.google.com/a/users/answer/9303222), checked 2026-11-12
- Google: ["Create rules to filter your emails"](https://support.google.com/mail/answer/6579), checked 2026-11-12
- Google: ["Trace an email with its full header (Show original)"](https://support.google.com/mail/answer/29436), checked 2026-11-12
- Google: ["About the alert center"](https://knowledge.workspace.google.com/admin/security/about-the-alert-center), checked 2026-11-13
- Google: ["Use the alert center"](https://knowledge.workspace.google.com/admin/security/use-the-alert-center), checked 2026-11-13
- Google: ["View alert details"](https://knowledge.workspace.google.com/admin/security/view-alert-details) (the alert types), checked 2026-11-13
- Google: ["Configure alert center email notifications"](https://knowledge.workspace.google.com/admin/security/configure-alert-center-email-notifications), checked 2026-11-13
- Google: ["Use rules to turn alerts on or off"](https://knowledge.workspace.google.com/admin/security/use-rules-to-turn-alerts-on-or-off), checked 2026-11-13
- Cloudflare: ["Set up Google Workspace DNS records"](https://developers.cloudflare.com/dns/manage-dns-records/how-to/set-up-google-workspace/), checked 2026-11-12
- Cloudflare: ["Manage DNS records"](https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/), checked 2026-11-12
