# ADR 1028: Internal certificates with cert-manager and an internal CA

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** both clusters
- **Phase:** 1. Later: Phase 3 uses the same internal CA setup on EKS.

## Context
Public TLS is handled at the edge: Cloudflare (russetleaf.dev) and ACM (russetleaf.com). Inside the clusters, several things need certificates: MariaDB's TLS for WordPress connections (required for the `wordpress` user), the optional client-certificate stretch goal, and any internal endpoint that should use TLS (e.g. OTLP receivers, internal admin services). The design referred to "certificates from the operator or cert-manager" without deciding.

## Decision
- **cert-manager** in `wp-gitops/platform/cert-manager/` on both clusters, with an **internal CA**: a self-signed root, kept as a Kubernetes Secret and backed up in the break-glass kit, issuing an intermediate CA used by a **ClusterIssuer**.
- **trust-manager** distributes the CA bundle to the namespaces that need it, so clients can verify internal certificates.
- Internal certificates for MariaDB (and other internal TLS endpoints) come from this issuer, with automatic renewal and expiry alerts (cert-manager's metrics in Prometheus).
- Components that manage their own webhook certificates (Kyverno, External Secrets, Cilium's Hubble) keep doing so.
- Public certificates stay with Cloudflare and ACM.

## Alternatives considered
- **Each operator's self-generated certificates:** fewer components, but several separate CAs, no single trust bundle, and inconsistent renewal and monitoring.
- **AWS Private CA:** managed, but costs a few hundred dollars a month per CA (or a short-lived-certificate mode with per-certificate charges) and doesn't suit the home cluster.
- **A service mesh issuing mTLS certificates:** not used (ADR 1001).

## Consequences
- One internal CA and trust bundle; certificate renewal and expiry are monitored.
- The root CA key is sensitive: stored as a Secret, copied to the break-glass kit, and rotated by a documented procedure.
- One more platform component (light: about 100–200 MB).

## When to revisit
- A service mesh is adopted (it would issue workload certificates).
- Many more internal TLS endpoints appear: consider short-lived certificates or SPIFFE identities.

## Open items
- Phase 1 step 4.2: cert-manager, trust-manager and the internal CA; expiry alerts.
