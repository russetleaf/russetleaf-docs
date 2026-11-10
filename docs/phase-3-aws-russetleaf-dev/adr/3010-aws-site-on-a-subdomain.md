# ADR 3010: The AWS site on a subdomain of russetleaf.dev

- **Status:** Accepted
- **Date:** 2026-11-10
- **Applies to:** the AWS site (Phase 3) and russetleaf.dev's DNS
- **Phase:** 3. Phase 1 is unaffected, apart from the names.

## Context

Phase 3 built its site on a second domain, registered with Route 53 Domains in an AWS account outside the Organization. The design had to move that registration into the Organization, copy its hosted zone, and manage a second registrar, a second set of registrar locks and a second DNSSEC chain of trust. The site exists to show the full AWS production design (EKS, RDS, CloudFront) next to the home site, not to serve a separate audience under its own name.

## Decision

- **The AWS site is `aws.russetleaf.dev`,** a subdomain of the project's one domain. The Phase 3 account is **russetleaf-aws**; its tags, labels, profiles and channels use `aws` (`Site=aws`, `site=aws`, `rl-aws-*`, `#rl-aws-alerts`).
- **DNS is delegated:** Route 53 hosts the `aws.russetleaf.dev` zone in russetleaf-aws, and the russetleaf.dev zone at Cloudflare holds NS records for `aws` pointing at it. Both are managed in `russetleaf-infra/envs/aws-edge` (the AWS and Cloudflare providers). CloudFront, ACM and ExternalDNS work as designed, against the subdomain zone.
- **DNSSEC:** Route 53 signs the subdomain zone, and its DS record is added to the russetleaf.dev zone, which Cloudflare already signs.
- **No second domain:** the project registers, renews and secures only russetleaf.dev.

## Alternatives considered

- **A second domain (the earlier design):** a separate name for the AWS site, but a second registrar account to secure, a registration to move into the Organization, and a second DNSSEC chain, for no technical gain.
- **A path on russetleaf.dev** (for example `/aws/`): one hostname, but the two sites would share an origin, cookies and the edge, so the AWS site could not have its own CloudFront distribution, certificates and DNS zone.
- **Delegating `aws.russetleaf.dev` to Cloudflare DNS only:** no Route 53 zone, but ExternalDNS, ACM validation and the CloudFront alias records would depend on Cloudflare's API from AWS, and the AWS design would no longer show Route 53.

## Consequences

- One domain, one registrar and one DNSSEC chain to look after; the Phase 1 plan no longer moves a domain into the Organization.
- The subdomain's zone depends on the NS and DS records in the russetleaf.dev zone: a mistaken change there takes the AWS site offline, so those records are managed in code with the rest of `envs/aws-edge`.
- The two sites share a registrable domain: WordPress cookies stay host-only (the default), so a cookie set on one site is not sent to the other. Every `.dev` name already requires HTTPS.
- The Phase 3 documents, account, tags and channel names use `aws` throughout.

## When to revisit

- The AWS site needs its own audience or brand, separate from russetleaf.dev.
- A policy requires the sites to be in separate domains (for example, separate cookie or certificate scopes).
