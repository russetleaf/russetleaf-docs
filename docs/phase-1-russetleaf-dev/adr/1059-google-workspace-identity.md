# ADR 1059: Google Workspace on russetleaf.dev as the project's identity

- **Status:** Accepted
- **Date:** 2026-11-10
- **Applies to:** the project's accounts and sign-ins, both sites
- **Phase:** 1 (step 0.1). Later phases use the same identity.

## Context

The project's accounts were registered to the operator's personal Google Account: the AWS root email addresses (as aliases of the personal mailbox), Slack, the Google sign-in for the WordPress admins and Dex, and the Google Cloud project that issues the OAuth clients. That ties the platform's identity to a personal mailbox, offers no groups for role-based access (Dex maps cluster roles from groups, [ADR 1033](1033-identity-and-access.md)), and gives no administrator control over how the identity signs in.

## Decision

- **A Google Workspace organization on russetleaf.dev, Business Starter, one user:** the operator's account `<name>@russetleaf.dev`, also the super administrator. Business Starter's 30 GB, custom domain, groups, 2-Step Verification enforcement and Advanced Protection cover the project's needs; Business Standard's 2 TB and Business Plus's Vault and device management do not apply to one operator.
- **Security keys enforced** for the organization (**Only security key or passkey**, with security codes not allowed), the account in **Advanced Protection**, and administrator-generated backup codes in the break-glass kit ([Google Workspace setup guide](../setup/google-workspace.md)).
- **Groups as addresses:** each AWS account's root email, and the DMARC reports address, is a Google group with the operator as member, so the address does not depend on one mailbox.
- **The Workspace account is used for:** Slack's "Continue with Google", the Google sign-in of the WordPress admins and of Dex (restricted to the russetleaf.dev domain, with Dex reading the Workspace groups for roles), the Google Cloud project, the AWS accounts' and the IAM Identity Center user's email, the GitHub organization's and GitLab group's contact email, and the outside monitoring services.
- **The personal Google Account is kept for two jobs only:** the Workspace account's recovery email, and the **Cloudflare** sign-in. Cloudflare is russetleaf.dev's registrar and DNS host, and Google's administrator recovery proves domain ownership through DNS, so neither may depend on russetleaf.dev's own mail. Bitwarden and Microsoft (OneDrive, the second encrypted kit copy) stay personal; the Google Drive copy of the kit stays in the personal account, outside the Workspace organization.
- **Mail for russetleaf.dev** is Gmail (MX, SPF, DKIM, DMARC starting at `p=none`); WordPress's mail stays on SES.
- **IAM Identity Center keeps its own directory:** Workspace is not its identity provider, so a Workspace outage or billing problem cannot lock the operator out of AWS.

## Alternatives considered

- **Keep the personal Google Account:** no cost, but no groups for roles, no domain-restricted sign-in, no enforced security keys, and the platform's identity stays a personal mailbox.
- **Business Standard or Plus:** more storage, Meet recordings, Vault and device management, none of which one operator needs, at two to three times the price.
- **Microsoft 365 with Entra ID:** comparable, but the design's sign-ins (Dex, Cloudflare Access, WordPress) already use Google, and Slack's Google sign-in is available on the free plan.
- **Workspace as IAM Identity Center's identity provider (SAML and SCIM):** one sign-in for AWS too, but AWS access would then depend on Google; reconsidered if a second operator joins.
- **Moving Cloudflare to the Workspace account:** one identity everywhere, but a circular dependency between the domain, its DNS and the account that recovers them.

## Consequences

- One project identity on the project's domain, with roles from groups and sign-in restricted to the domain.
- About $7 a month for one Business Starter user (check the current price and billing period at sign-up).
- Mail to russetleaf.dev, including the AWS root email path, depends on the Workspace subscription and the domain's renewal; both stay on auto-renew, and the [disaster recovery plan](../disaster-recovery.md) covers their loss.
- One super administrator: Google recommends a second one to generate backup codes; for one operator, the backup codes in the break-glass kit take its place ([improvement I1-6](../improvements.md)).
- Google Workspace is a proprietary hosted service, recorded as an exception in [ADR 1053](1053-open-source-tools-by-default.md).

## When to revisit

- A second operator joins: add a second super administrator, and reconsider Workspace as IAM Identity Center's identity provider.
- Storage passes about 20 GB, or the project needs Vault or device management: move up a tier.
- Google changes Advanced Protection or security-key enforcement for Workspace accounts.

## Open items

- Phase 1 step 0.1: the organization, the mail records and the groups; the existing accounts moved to the new addresses.
- Phase 1 step 2.3: the domain's Google records imported into OpenTofu with the rest of russetleaf.dev's DNS.
- Phase 1 step 4.7: Dex's Google connector reading Workspace groups (a service account with read access to the Directory API).
- Phase 1 step 7.16: the DMARC reports and the account's sign-in and admin events in the `security` tenant, with detection rules.
