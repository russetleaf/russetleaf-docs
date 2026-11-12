# Setup guide: the GitHub organization

The step-by-step procedure for the project's **GitHub organization**, `russetleaf`, which holds every RussetLeaf repo (Phase 1 [step 1.1](../plan.md#step-11-create-the-repos)): creating it, requiring security-key-grade two-factor authentication, verifying russetleaf.dev for the organization and for GitHub Pages, and publishing the docs site from `russetleaf-docs` at `docs.russetleaf.dev`. The reasoning is in [ADR 1060](../adr/1060-github-organization-and-gitlab-group.md). The organization's other settings (base permissions, the workflow token, allowed Actions, rulesets) are code in `russetleaf-infra/envs/github/` from step 2.4.

**Note:** the click paths in this guide are those the services showed when the procedure was last carried out. Providers change their consoles without notice, and their own documentation can lag behind the console. Before following a path, check the provider's current documentation, linked in each part; where the screen still differs, follow what it shows and fix this guide to match.

## Before starting

Have these ready:

- **The operator's personal GitHub account,** with both YubiKeys registered and the preferred two-factor method set to security keys ([account sign-in setup guide](account-sign-in.md#part-2-github-and-gitlab)). An organization that requires two-factor authentication can only be created and owned by an account that already uses it.
- **The Workspace address** `<name>@russetleaf.dev` ([Google Workspace setup guide](google-workspace.md)), for the organization's contact email.
- **The Cloudflare dashboard,** signed in, for the TXT and CNAME records of russetleaf.dev ([account sign-in setup guide](account-sign-in.md#part-3-cloudflare-and-the-domain-registration)).

To add a record in Cloudflare: **Account home → russetleaf.dev → DNS → Records → Add record**, choose the **Type**, enter the **Name** without the trailing `.russetleaf.dev` (Cloudflare appends the domain), keep **TTL** on Auto, and **Save**.

## Part 1: Create the organization

1. In the upper-right corner of any GitHub page, select the profile picture, then **Settings**.
2. In the **Access** section of the sidebar, select **Organizations**, then **New organization** next to the "Organizations" header.
3. Choose the **Free** plan, and fill in the form:
    - **Organization name:** `russetleaf`
    - **Contact email:** `<name>@russetleaf.dev`
    - **This organization belongs to:** the operator's personal account
4. Skip inviting members.
5. Leave the organization profile's **website** empty until russetleaf.dev is live: the "Verified" badge (Part 3) appears only when the profile's website and email are on verified domains, and `docs.russetleaf.dev` would be a second domain to verify. Set it to `https://russetleaf.dev` once the site is published (step 9.2).

## Part 2: Require two-factor authentication

1. Profile picture → **Organizations** → **russetleaf** → **Settings** (under the organization name).
2. In the **Security** section of the sidebar, select **Authentication security**.
3. Under **Two-factor authentication**, select "Require two-factor authentication for everyone in your organization" and "Only allow secure two-factor methods", then **Save**, and **Confirm**. GitHub asks for a security key to confirm.

Secure methods are passkeys, security keys, authenticator apps and GitHub Mobile; SMS is not. As the only owner, the operator cannot turn off two-factor authentication on the personal account while the organization requires it.

## Part 3: Verify russetleaf.dev for the organization

This gives the organization's profile its **Verified** badge.

1. In the organization's **Settings**, **Security** section of the sidebar, select **Verified and approved domains**.
2. Select **Add a domain**, enter `russetleaf.dev`, and select **Add domain**.
3. Under **Add a DNS TXT record**, GitHub shows the record: the name is `_gh-russetleaf-o` (on russetleaf.dev) and the value is a one-time code. Add it in Cloudflare as type **TXT**, name `_gh-russetleaf-o`, with the value as the content.
4. Back on GitHub, select **Verify**. If it fails, wait a few minutes (GitHub allows up to 72 hours); to return later, select **⋯** next to the domain, then **Continue verifying**, then **Verify**.
5. Keep the TXT record: step 2.3 imports it into OpenTofu with the rest of russetleaf.dev's DNS.

## Part 4: Verify russetleaf.dev for the published sites

A separate verification, in the organization's Pages settings, so that only the organization's repos can publish a Pages site on russetleaf.dev and its immediate subdomains, including `docs.russetleaf.dev`. Without it, a Pages site that is disabled while its DNS record still points at GitHub can be taken over by another GitHub account.

1. In the organization's **Settings**, **Code, planning, and automation** section of the sidebar, select **Pages**.
2. Select **Add a domain**, enter `russetleaf.dev`, and select **Add domain**.
3. Add the TXT record GitHub shows in Cloudflare: type **TXT**, name `_github-pages-challenge-russetleaf`, with the value as the content.
4. Back on GitHub, select **Verify** (or **⋯ → Continue verifying → Verify** later; GitHub allows up to 24 hours).
5. Keep the TXT record for as long as the domain is used: GitHub rechecks it, and removing it removes the protection.

A domain already verified for Pages by another account cannot be verified here until that account deletes its verification (its profile **Settings → Pages**, **⋯** next to the domain, **Delete**).

## Part 5: The docs site

1. **The repo:** create `russetleaf-docs` in the organization (profile picture → **Organizations** → **russetleaf** → **Repositories** → **New repository**), public, as [ADR 1038](../adr/1038-documentation-repo-and-site.md) describes. Its `docs` workflow builds the site with Zensical and deploys it to GitHub Pages.
2. **Pages source:** in the repo's **Settings**, **Code, planning, and automation** section, **Pages**: under **Build and deployment**, set **Source** to **GitHub Actions**.
3. **Custom domain,** before the DNS record, so that no one else can claim the name in between: on the same page, under **Custom domain**, enter `docs.russetleaf.dev` and **Save**. With the GitHub Actions source, no `CNAME` file is needed in the repo.
4. **The DNS record** in Cloudflare: type **CNAME**, name `docs`, target `russetleaf.github.io` (the organization's Pages host, without the repo name), and **Proxy status** set to **DNS only**, so GitHub can issue the site's certificate.
5. **HTTPS:** once the DNS check on the Pages settings page passes, select **Enforce HTTPS**. GitHub can take up to 24 hours to issue the certificate before the option is available.

## Checks

The organization's part of the step 1.1 test:

- [ ] The organization's **Authentication security** shows two-factor authentication required, with only secure methods.
- [ ] **Verified and approved domains** shows russetleaf.dev as **Verified**.
- [ ] The organization's **Pages** settings show russetleaf.dev as verified.
- [ ] `dig +short docs.russetleaf.dev CNAME` returns `russetleaf.github.io.`.
- [ ] `https://docs.russetleaf.dev` loads the site with a valid certificate, and `http://` redirects to it.
- [ ] The repo's **Pages** settings show the custom domain `docs.russetleaf.dev`, the DNS check passed and **Enforce HTTPS** on.

## If something goes wrong

- **"Domain is already taken" or the Pages verification fails:** another account has verified the domain for Pages or uses it as a custom domain. Delete that verification or custom domain in the other account (see Part 4), then verify again.
- **The site shows a 404 from GitHub, or a certificate error:** check that the CNAME points to `russetleaf.github.io` and is **DNS only**, and that the custom domain is set in the repo's Pages settings. If HTTPS stays unavailable after 24 hours, remove the custom domain, save, add it again and save, which restarts certificate issuance.
- **Locked out of the personal account:** the organization is owned by that account alone, so use its recovery codes or a YubiKey ([account sign-in setup guide](account-sign-in.md#if-something-goes-wrong)).

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- GitHub: ["Creating a new organization from scratch"](https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/creating-a-new-organization-from-scratch), checked 2026-11-12
- GitHub: ["Requiring two-factor authentication in your organization"](https://docs.github.com/en/organizations/keeping-your-organization-secure/managing-two-factor-authentication-for-your-organization/requiring-two-factor-authentication-in-your-organization), checked 2026-11-12
- GitHub: ["Verifying or approving a domain for your organization"](https://docs.github.com/en/organizations/managing-organization-settings/verifying-or-approving-a-domain-for-your-organization), checked 2026-11-12
- GitHub: ["Verifying your custom domain for GitHub Pages"](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/verifying-your-custom-domain-for-github-pages), checked 2026-11-12
- GitHub: ["Managing a custom domain for your GitHub Pages site"](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site), checked 2026-11-12
- GitHub: ["About GitHub Pages"](https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages), checked 2026-11-12
- GitHub: ["Troubleshooting custom domains and GitHub Pages"](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/troubleshooting-custom-domains-and-github-pages), checked 2026-11-12
- Cloudflare: ["Manage DNS records"](https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/), checked 2026-11-12
