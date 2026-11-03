# ADR 1032: Defense in depth: controls by layer, and the gaps closed

- **Status:** Accepted (retitled on 2026-11-02; formerly "Security by layer (the 4 C's) and the remaining controls")
- **Date:** 2026-11-02
- **Applies to:** both sites, the AWS accounts and the supporting SaaS accounts
- **Phase:** 1 (most controls). Later: Phase 2 adds prompt-injection guardrails; Phase 3 adds the AWS edge and VPC controls.

> **Update ([ADR 1040](1040-lab-network-and-wireguard.md)):** the lab network is a separate subnet behind a TP-Link ER605 router (the household router cannot do VLANs), and the workstation reaches the cluster over WireGuard.

## Context

Defense in depth means layering controls so a failure at one layer is caught at another. For a Kubernetes platform, the layers are commonly named after Kubernetes' security documentation (the "4 C's"): **Cloud** (the provider and infrastructure), **Cluster** (Kubernetes), **Container** (images and runtime) and **Code** (the application and its dependencies); each depends on the one outside it. A review against those layers, and against cloud provider, infrastructure, isolation, artifact, image, workload and application-code security, found the design strong in depth but with gaps:

- the project's **other providers** (GitHub, Cloudflare, Google Cloud, Slack, the domain registrars) were not hardened like AWS
- the **home network** put the nodes on the same LAN as household devices; **Secure Boot** and **BIOS passwords** were not decided
- **user namespaces** were not used
- **Helm charts** were not signed or pinned by digest; critical **third-party images** were not mirrored; `packages: write` was not limited to release jobs; Python and PHP dependencies were not **hash-pinned**
- the summarizer's **base image** was not specified
- **Secrets as environment variables** were not prevented
- the sites had **no HTTP security headers**, **no DAST**, no WordPress-specific hardening (user enumeration, keys and salts), and no **OWASP ASVS** mapping
- the controls were not summarized **by layer**

## Decision

- **Summarize the controls by layer** in the overview's "Defense in depth" section (what each layer protects against, its main controls, and where the details are), and organize the threat model and control matrix (Phase 1 step 8.5) by the same layers, with an **OWASP ASVS** mapping for the application.
- **SaaS account hardening:** passkeys or hardware security keys for GitHub, Cloudflare, Google, AWS (Identity Center), Slack and the registrars; **registrar lock** on both domains; GitHub organization settings (default workflow token **read-only**, only verified or allow-listed Actions, required reviews, environment protections), managed with Terraform's **GitHub provider** where possible; Cloudflare **least-privilege API tokens** and audit-log review; a minimal Google Cloud project; a **quarterly access review** of all of them.
- **Home network and boot:** a **lab VLAN** (or separate router subnet) with rules allowing the cluster out to the internet and in from the workstation only, and blocking it from household devices; **Talos Secure Boot images** with the TPM-sealed disk encryption ([ADR 1031](1031-kubernetes-component-hardening.md)); **BIOS passwords**.
- **User namespaces** (`hostUsers: false`) for application pods where the Kubernetes and Talos versions support them (root in a container then maps to an unprivileged user on the node).
- **Artifact integrity:** sign **Helm charts** with cosign (verified in CI before the version-bump pull request) and **pin charts by digest** in `russetleaf-gitops`; grant `packages: write` only to release jobs; **mirror critical third-party images** into GHCR (copied by digest after verifying upstream signatures, then re-signed) for availability and rate limits; **hash-pinned dependencies** (uv's lock file with hashes; `composer.lock`).
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
- **A WAF-only approach to web security:** WAFs do not set browser security policies (CSP, HSTS) or find application flaws the way DAST does.
- **A commercial DAST or ASVS tool:** ZAP's baseline scan is free and enough for this site.

## Consequences

- Every control is placed in a layer, making gaps visible and the security story easy to follow.
- More settings to maintain (headers, CSP reports, mirror jobs, access reviews), mostly automated.
- CSP may break plugins at first; report-only mode finds problems before enforcement.
- Rotating keys and salts signs admins out (acceptable, and done on a schedule).

## When to revisit

- User namespaces are not supported yet: re-check after Talos and Kubernetes upgrades.
- ~~The router cannot do VLANs: use a separate router or firewall for the lab.~~ Done: [ADR 1040](1040-lab-network-and-wireguard.md).

## Open items

- Phase 1 steps 0.1, 0.3, 1.1, 2.2, 2.3, 5.1, 5.2, 5.6, 5.7, 6.1 and 8.5 and Phase 2 step 2.4; Phase 3 steps 1.2, 2.4 and 5.1.
