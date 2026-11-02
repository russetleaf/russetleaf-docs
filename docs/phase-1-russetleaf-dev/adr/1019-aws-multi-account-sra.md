# ADR 1019: Multi-account AWS structure aligned with the AWS Security Reference Architecture

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** all AWS usage by both sites
- **Phase:** 1 (the Organization and all accounts except russetleaf-com). Later: Phase 3 creates russetleaf-com.
- **Updates:** ADR 1007 (Security Hub now used; Prowler kept as a second opinion), ADR 1017 (organization CloudTrail and GuardDuty, delegated administration), ADR 1018 (a dedicated management account; CloudTrail logs in Log Archive)

## Context

The design used **one AWS account** for everything (the home lab's AWS resources, russetleaf.com, Terraform state, CloudTrail, GuardDuty), plus a backup account under an Organization whose **management account was the workload account**. The **AWS Security Reference Architecture (SRA)** recommends instead: a management account that runs nothing; a Security OU with a **Security Tooling** account (delegated administrator for security services) and a **Log Archive** account; separate accounts per workload; organization-wide guardrails (SCPs); and centralized security services (Security Hub, GuardDuty, Config, Access Analyzer, an organization CloudTrail trail).

## Decision

- **Accounts and OUs:** Management (dedicated, new); Security OU: Security Tooling, Log Archive, Backup; Infrastructure OU: russetleaf-infra (Terraform state and CI entry points); Workloads OU: russetleaf-home (the existing account) and russetleaf-com.
- **Guardrails:** SCPs (no leaving the Organization; no disabling security services; us-east-1 and us-west-2 only; no member-account root actions; no IAM users or access keys except a named exception for the home cluster's scoped keys; Log Archive and Backup buckets protected); centralized root access management; IAM Identity Center with MFA; tag policies; alternate security contacts; per-account and consolidated budgets.
- **Security services, delegated to Security Tooling:** Security Hub (AWS Foundational Security Best Practices and CIS standards; critical and high findings to Slack), AWS Config (focused recording and a CIS conformance pack), IAM Access Analyzer (external-access findings, plus policy checks in the Terraform pipeline), organization GuardDuty, an organization CloudTrail trail into Log Archive. Inspector optional; Macie and Detective not used.
- **Resource practices:** account-level S3 Block Public Access, TLS-only bucket policies, bucket-owner-enforced ownership; EBS encryption by default; KMS customer-managed keys for logs and backups; snapshot and AMI public-access blocks; IMDSv2 with hop limit 1 on EKS nodes; VPC endpoints, flow logs, empty default security groups, default VPCs removed.
- **A Well-Architected review** with the free tool, kept in `docs/`, revisited yearly.
- Everything in Terraform: `russetleaf-infra/envs/org/` and `russetleaf-infra/envs/security/`, with existing environments moved into their accounts.

## Alternatives considered

- **Single account (the previous design):** simplest and cheapest, but a compromise or mistake can reach everything; no separation of security tooling and logs from workloads; doesn't match the SRA.
- **AWS Control Tower:** sets up a similar landing zone automatically, with guardrails and account vending, but adds managed resources and costs, and hides much of what this project wants to show in Terraform. A good choice for a team; Terraform-managed Organizations shows the same structure explicitly.
- **The lean option** (account structure and free guardrails only, without Security Hub and Config): saves about $5–15/month, but loses continuous posture checks and the central findings view the SRA is built around.
- **A shared-services account for everything non-workload** (state, logs and backups together): fewer accounts, but mixes concerns the SRA deliberately separates.

## Consequences

- Each site, the logs, the backups and the security tooling are isolated; a compromised workload account can't delete logs or backups, and can't turn off security services (SCPs).
- About **$5–15/month** more (Security Hub, Config, KMS), bringing the always-on total to about $15–35/month at the time (about **$18–40/month** after box 3's electricity was added by ADR 1020; this total already includes the organization-wide security services).
- More moving parts: cross-account access for state, replication and the seed Job; per-account CI roles; per-account quotas (request the GPU quota in russetleaf-com); SES and Bedrock model access per account.
- Restructuring the existing account into the Organization happens early (before most resources exist), which keeps the move simple.
- A credible, SRA-shaped AWS foundation to show and discuss.

## When to revisit

- The project becomes a team effort: consider Control Tower for account vending and drift detection.
- Config costs grow with the demo stack: narrow recording further, or record only during demos.
- russetleaf.com becomes always-on or holds user data: add Macie, Detective and Inspector, and consider a separate network account.

## Open items

- Phase 1 step 2.0: create the management account, the Organization, OUs, accounts, SCPs, Identity Center, tag policies and root access management; move the existing account in.
- Phase 1 step 2.0b: the security services in Security Tooling; first Security Hub score recorded.
- Phase 1 step 2.4: Access Analyzer policy checks in the Terraform pipeline.
- Phase 3 steps 0.1 and 1.x: russetleaf.com in its own account (GPU quota, SES, Bedrock access, IMDSv2, VPC endpoints, flow logs).
- Run the first Well-Architected review once both sites exist; keep the report in `docs/`.
