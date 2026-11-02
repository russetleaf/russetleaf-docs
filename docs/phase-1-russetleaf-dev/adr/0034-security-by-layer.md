# ADR 0034: Security by layer (the 4 C's) and the remaining controls

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** both sites, the AWS accounts and the supporting SaaS accounts
- **Phase:** 1 (most controls). Later: Phase 2 adds prompt-injection guardrails; Phase 3 adds the AWS edge and VPC controls.

## Context
Cloud-native security is commonly described in four layers, the **4 C's**: **Cloud** (the provider and infrastructure), **Cluster** (Kubernetes), **Container** (images and runtime) and **Code** (the application and its dependencies); each layer depends on the one outside it. A review against that model, and against cloud provider, infrastructure, isolation, artifact, image, workload and application-code security, found the design strong in depth but with gaps:
- the project's **other providers** (GitHub, Cloudflare, Google Cloud, Slack, the domain registrars) weren't hardened like AWS
- the **home network** put the nodes on the same LAN as household devices; **Secure Boot** and **BIOS passwords** weren't decided
- **user namespaces** weren't used
- **Helm charts** weren't signed or pinned by digest; critical **third-party images** weren't mirrored; `packages: write` wasn't limited to release jobs; Python and PHP dependencies weren't **hash-pinned**
- the summarizer's **base image** wasn't specified
- **Secrets as environment variables** weren't prevented
- the sites had **no HTTP security headers**, **no DAST**, no WordPress-specific hardening (user enumeration, keys and salts), and no **OWASP ASVS** mapping
- the controls weren't summarised **by layer**

## Decision
- **Summarise every control by layer** in the Phase 1 design ("Security by layer"), and organise the threat model and control matrix (Phase 1 step 8.5) by the 4 C's, with an **OWASP ASVS** mapping for the application.
- **SaaS account hardening:** passkeys or hardware security keys for GitHub, Cloudflare, Google, AWS (Identity Center), Slack and the registrars; **registrar lock** on both domains; GitHub organisation settings (default workflow token **read-only**, only verified or allow-listed Actions, required reviews, environment protections), managed with Terraform's **GitHub provider** where possible; Cloudflare **least-privilege API tokens** and audit-log review; a minimal Google Cloud project; a **quarterly access review** of all of them.
- **Home network and boot:** a **lab VLAN** (or separate router subnet) with rules allowing the cluster out to the internet and in from the workstation only, and blocking it from household devices; **Talos Secure Boot images** with the TPM-sealed disk encryption (ADR 0033); **BIOS passwords**.
- **User namespaces** (`hostUsers: false`) for application pods where the Kubernetes and Talos versions support them (root in a container then maps to an unprivileged user on the node).
- **Artifact integrity:** sign **Helm charts** with cosign (verified in CI before the version-bump pull request) and **pin charts by digest** in `wp-gitops`; grant `packages: write` only to release jobs; **mirror critical third-party images** into GHCR (copied by digest after verifying upstream signatures, then re-signed) for availability and rate limits; **hash-pinned dependencies** (uv's lock file with hashes; `composer.lock`).
- **Image:** a **distroless or slim multi-stage** base for the summarizer.
- **Workload:** **Secrets mounted as files**, not environment variables (Kyverno rule), and least-privilege RBAC on Secrets.
- **Application:**
  - **HTTP security headers**: HSTS at Cloudflare and CloudFront; Content-Security-Policy in report-only mode first, then enforced; X-Content-Type-Options, X-Frame-Options or `frame-ancestors`, Referrer-Policy, Permissions-Policy.
  - **DAST**: OWASP **ZAP** baseline scan of staging in the promotion gate (and once against russetleaf.com during a demo).
  - **WordPress hardening**: block user enumeration (author archives and the REST `users` endpoint for anonymous visitors); **auth keys and salts** from Secrets Manager, rotated (which signs everyone out); XML-RPC already off.

## Alternatives considered
- **Leaving non-AWS providers at defaults:** they hold the code, DNS, sign-in and alerts; a compromise there bypasses the AWS controls.
- **Flat home network:** simpler, but a compromised node could reach household devices (and vice versa).
- **Signing images only:** leaves charts (which define what runs) unverified.
- **A WAF-only approach to web security:** WAFs don't set browser security policies (CSP, HSTS) or find application flaws the way DAST does.
- **A commercial DAST or ASVS tool:** ZAP's baseline scan is free and enough for this site.

## Consequences
- Every control is placed in a layer, making gaps visible and interview answers structured.
- More settings to maintain (headers, CSP reports, mirror jobs, access reviews), mostly automated.
- CSP may break plugins at first; report-only mode finds problems before enforcement.
- Rotating keys and salts signs admins out (acceptable, and done on a schedule).

## When to revisit
- User namespaces aren't supported yet: re-check after Talos and Kubernetes upgrades.
- The router can't do VLANs: use a separate router or firewall for the lab.

## Open items
- Phase 1 steps 0.1, 0.3, 1.1, 2.2, 2.3, 5.1, 5.2, 5.6, 5.7, 6.1 and 8.5 and Phase 2 step 2.4; Phase 3 steps 1.2, 2.4 and 5.1.
