# ADR 3005: EKS access through Identity Center, and the EKS audit-log archive

- **Status:** Accepted (split from [ADR 1033](../../phase-1-russetleaf-dev/adr/1033-identity-and-access.md))
- **Date:** 2026-11-02
- **Applies to:** the EKS cluster, IAM Identity Center, the Log Archive account
- **Phase:** 3

## Context

[ADR 1033](../../phase-1-russetleaf-dev/adr/1033-identity-and-access.md) gives people short-lived, personal, revocable access to the home cluster (Dex OIDC, group-based roles, an alerted break-glass path) and keeps a year of audit logs in the Log Archive account. EKS authenticates people through IAM, and its audit logs go to CloudWatch, so the same goals need AWS-specific mechanisms.

## Decision

- **Access entries only** (authentication mode API, no `aws-auth` ConfigMap), with the cluster creator's automatic admin access turned off.
- **IAM Identity Center permission sets** mapped to EKS access policies: **view** (`AmazonEKSViewPolicy`) for day-to-day, **edit** (`AmazonEKSEditPolicy`) for operating, **cluster-admin** (`AmazonEKSClusterAdminPolicy`) only through a separate, break-glass permission set; plus the CI apply role scoped to what OpenTofu needs.
- **Audit logs:** control-plane audit logging on with short CloudWatch retention, plus a **subscription filter → Firehose → the Log Archive account's Object Lock bucket**, kept **1 year**.
- **Persistence alerts** ([ADR 1034](../../phase-1-russetleaf-dev/adr/1034-kubernetes-threat-model-coverage.md)) from the audit log as CloudWatch Logs metric filters and alarms to `#rl-security`, created and destroyed with the demo stack; GuardDuty's EKS audit-log monitoring on.

## Alternatives considered

- **Dex OIDC on EKS too:** one identity model for both clusters, but EKS's IAM-based access is what EKS users are expected to know, and Identity Center already holds the logins.
- **The `aws-auth` ConfigMap:** the older mechanism; access entries are managed through the API and OpenTofu and cannot be broken by a bad ConfigMap edit.
- **CloudWatch retention only:** simpler, but logs would stay in the workload account, and long retention there costs more.

## Consequences

- People never hold long-lived EKS credentials; cluster-admin needs a separate, auditable sign-in.
- EKS and home audit logs end up in the same tamper-evident archive.

## When to revisit

- russetleaf.com becomes always-on, or more people need access: add per-team permission sets and namespace-scoped access policies.

## Open items

- Phase 3 step 1.4: access entries and audit-log archive; step 4.1: verify both in the security review.
