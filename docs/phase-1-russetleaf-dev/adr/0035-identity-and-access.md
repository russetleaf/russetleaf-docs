# ADR 0035: Identity and access to the clusters

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** both clusters and their admin tools (the EKS-specific parts are tracked in ADR 0045)
- **Phase:** 1. EKS: ADR 0045 (Phase 3).

> **Update (ADR 0045):** the project is now built in three phases (ADR 0039). This ADR is Phase 1's. **EKS access** (Identity Center permission sets mapped to access entries) and the **EKS audit-log archive** are recorded in ADR 0045 (Phase 3).

## Context
Workload identity was well covered (projected service-account tokens off by default, Pod Identity on EKS, scoped keys at home), and the admin UIs sat behind Cloudflare Access with Google. But for **people**:
- the home cluster was used through Talos's generated **admin kubeconfig**: a long-lived **cluster-admin client certificate** that **can't be revoked**
- day-to-day Talos API access used the full admin role
- there were no defined **human roles**; cluster-admin was the default
- Argo CD, Grafana and Backstage relied on the edge login, without their own SSO and roles
- **audit logs** were kept only 7 days (Loki at home) or briefly (CloudWatch on EKS), and Argo CD's audit trail wasn't collected
- **platform namespaces** had no default-deny network policies
- the home External Secrets bootstrap key remained a static key until a Stretch goal

## Decision
- **OIDC sign-in for people on the home cluster:** **Dex** (in `wp-gitops/platform/dex/`) as the OIDC provider, with a **Google** connector; the API server trusts Dex through Kubernetes' **structured authentication configuration** (issuer, audience, claim mappings and the internal CA from ADR 0030); people use **kubelogin** to get short-lived tokens. Check the Talos version's support for structured authentication configuration (or use the older `--oidc-*` API server flags).
- **Break-glass:** the Talos-generated admin kubeconfig is kept **only in the break-glass kit**, never used day to day, and an **audit alert** (`KubeBreakGlassAdminUsed`) fires whenever its identity makes a request. If Dex is down, the break-glass kubeconfig is the documented way in.
- **Talos API roles:** day-to-day talosconfig uses the **`os:reader`** role; `os:admin` is break-glass and change-time only.
- **Human RBAC roles** (`wp-gitops/platform/rbac/`): **`platform-admin`**, **`operator`** (deploy, restart, view logs; no RBAC or Secret changes) and **`read-only`** ClusterRoles, bound to Dex groups (or, for a single person, specific users); **no day-to-day cluster-admin**. Argo CD's service account remains the identity that changes production.
- **EKS:** see ADR 0045.
- **SSO inside the admin tools:** Argo CD (OIDC through Dex, with its RBAC mapping groups to roles), Grafana (OIDC with Viewer, Editor and Admin roles) and Backstage, all behind Cloudflare Access as well.
- **Audit-log retention:** Kubernetes audit logs are also shipped to an **S3 bucket with Object Lock in the Log Archive account**, kept **1 year** (Alloy writes a copy; EKS: ADR 0045); Argo CD's audit events (who synced or changed what) are collected into Loki and the same archive.
- **Default-deny network policies for platform namespaces** too (Argo CD, monitoring, logging, External Secrets, Kyverno, cert-manager, Dex, KEDA, Argo Rollouts and others), with least-privilege egress per component (e.g. Argo CD → GitHub and GHCR and the API server; External Secrets → Secrets Manager; cert-manager → the API server), tested in CI.
- **Pod Security Admission version pinned** on every namespace (`enforce-version`), so Kubernetes upgrades don't silently change enforcement.
- **Keyless AWS access for the home cluster** (Phase 1 step 9.1) moves from Stretch to **Differentiator**, removing the last static AWS keys.

## Alternatives considered
- **Admin client certificates for everyday use:** simple, but can't be revoked and grant full control.
- **API server OIDC directly against Google:** fewer components, but Google's tokens carry no groups for personal accounts and Google's audience rules make kubectl setup awkward; Dex adds groups and a single issuer for all tools.
- **Pinniped or a hosted identity provider (e.g. Okta, Auth0):** capable; Dex is lighter and self-hosted.
- **Cloudflare Access alone for the admin tools:** strong edge protection, but every signed-in person gets the same rights inside each tool.
- **Short audit retention only:** cheaper, but too short for investigating incidents found later.

## Consequences
- Day-to-day cluster access is short-lived, personal and revocable; full admin is break-glass, alerted and audited.
- One more critical component (Dex); if it fails, the break-glass path is needed.
- Platform default-deny policies take effort to get right (each operator's API and webhook traffic must be allowed), but close a real lateral-movement path.
- A year of tamper-evident audit history for a few cents a month.

## When to revisit
- More people or teams: use identity-provider groups (e.g. Google Workspace groups through Dex) rather than per-user bindings.
- Talos or Kubernetes changes the authentication configuration interface.

## Open items
- Phase 1 step 4.7: Dex, OIDC sign-in, roles, tool SSO, the break-glass alert, Talos `os:reader`.
- Phase 1 step 4.6: audit-log archive and Argo CD audit events.
- Phase 1 step 6.3: platform default-deny policies; step 6.1: PSA version pins.
- EKS: see ADR 0045.
