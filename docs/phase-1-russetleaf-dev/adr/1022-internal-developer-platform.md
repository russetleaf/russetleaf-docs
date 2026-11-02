# ADR 1022: Internal developer platform (Backstage, golden paths, multi-tenancy) and hub-and-spoke Argo CD

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** the home cluster as the platform; russetleaf.com as a managed spoke
- **Phase:** 1 (Backstage, the golden path, multi-tenancy, the Argo CD hub with a local spoke cluster). Later: Phase 3 adds EKS as a second spoke.

## Context
The project had become a capable platform (GitOps, signed supply chain, policies, observability, SLOs), but only for the services it was built around. Staff-level platform work is judged by whether **other engineers** can use the platform easily and safely. Separately, each cluster ran its own Argo CD, so there was no single place to manage both.

## Decision
- **Backstage** as the developer portal (catalog, TechDocs, links to dashboards, runbooks and SLOs), with PostgreSQL run by **CloudNativePG**.
- **A golden-path software template** that creates a complete new service (repo, CI with the full supply-chain pipeline, a Kyverno-compliant chart, CiliumNetworkPolicies, SLOs, dashboard, alerts, runbook stub, ApplicationSet registration).
- **Proof:** create a **second, different service** from the template and measure time to first production deploy.
- **Multi-tenancy:** per-tenant namespaces, Argo CD projects, quotas and limit ranges, RBAC, Kyverno policies and OpenCost showback.
- **Hub-and-spoke Argo CD:** the home Argo CD manages EKS during demos (registered by `demo-up` with IAM authentication, EKS API endpoint restricted to the home network), using ApplicationSets with cluster generators; the per-cluster Argo CD remains the fallback.

## Alternatives considered
- **Port or Cortex (hosted portals):** less to run, but hosted services; Backstage is the open-source standard.
- **Templates without a portal** (e.g. Copier or Cookiecutter plus a docs site): lighter, but no catalog or ownership view; acceptable fallback if Backstage's upkeep proves too much.
- **Per-cluster Argo CD only:** simpler networking, but no fleet view; kept as fallback.
- **Kargo or Argo CD's own multi-cluster tooling as the hub:** possible later; ApplicationSets cover two clusters well.

## Consequences
- The platform's value is demonstrated by a second service built on it, with a measured onboarding time.
- Backstage is a sizeable application to run and upgrade (Node.js plugins, PostgreSQL); about 1–1.5 GB of memory on box 3.
- The EKS API endpoint is reachable from the home network during demos (restricted by address and IAM).
- One Argo CD view for both clusters.

## When to revisit
- Backstage upkeep outweighs its value for a solo project: fall back to templates plus a docs site.
- More clusters: consider a dedicated management cluster or a managed Argo CD.

## Open items
- Phase 1 steps 8.3, 8.4 and 8.8; Phase 3 step 6.5.
