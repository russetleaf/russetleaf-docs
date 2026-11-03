# ADR 1019: Multi-account AWS structure aligned with the AWS Security Reference Architecture

- **Status:** Accepted; RCPs, Suspended and Policy Staging OUs, and declarative policies added 2026-11-03
- **Date:** 2026-11-01
- **Applies to:** all AWS usage by both sites
- **Phase:** 1 (the Organization and all accounts except russetleaf-com). Later: Phase 3 creates russetleaf-com.
- **Updates:** [ADR 1007](1007-prowler-not-threatmapper.md) (Security Hub now used; Prowler kept as a second opinion), [ADR 1017](1017-intrusion-detection-and-prevention.md) (organization CloudTrail and GuardDuty, delegated administration), [ADR 1018](1018-disaster-recovery.md) (a dedicated management account; CloudTrail logs in Log Archive)

## Context

The design used **one AWS account** for everything (the home lab's AWS resources, russetleaf.com, Terraform state, CloudTrail, GuardDuty), plus a backup account under an Organization whose **management account was the workload account**. The **AWS Security Reference Architecture (SRA)** recommends instead: a management account that runs nothing; a Security OU with a **Security Tooling** account (delegated administrator for security services) and a **Log Archive** account; separate accounts per workload; organization-wide guardrails (SCPs); and centralized security services (Security Hub, GuardDuty, Config, Access Analyzer, an organization CloudTrail trail).

## Decision

- **Accounts and OUs:** Management (dedicated, new); Security OU: Security Tooling, Log Archive, Backup; Infrastructure OU: russetleaf-infra (Terraform state and CI entry points); Workloads OU: russetleaf-home (the existing account) and russetleaf-com. Two further OUs from AWS's recommended structure, normally empty: **Policy Staging** (new SCPs and RCPs are attached here first, with a test account, before the real OUs) and **Suspended** (a deny-all SCP; moving a compromised account here is the first containment step).
- **Guardrails:** SCPs (no leaving the Organization; no disabling security services; us-east-1 and us-west-2 only; no member-account root actions; no IAM users or access keys except a named exception for the home cluster's scoped keys; Log Archive and Backup buckets protected); **resource control policies (RCPs)** forming a data perimeter (below); **declarative policies** for EC2 settings; centralized root access management; IAM Identity Center with MFA; tag policies; alternate security contacts; per-account and consolidated budgets.
- **Resource control policies (RCPs)** on every OU, limiting who can access the Organization's resources whatever their own resource policies say:
    - **Organization-only access:** S3, KMS, SQS and Secrets Manager resources can be accessed only by identities in the Organization (`aws:PrincipalOrgID`).
    - **AWS services only on the Organization's behalf:** AWS service principals (CloudFront serving media, S3 replication, CloudTrail and Config delivery) are allowed only when acting for the Organization (`aws:SourceOrgID`), which prevents confused-deputy access.
    - **TLS required** for every request to those services (`aws:SecureTransport`), organization-wide rather than in each policy.
    - **STS:** roles can be assumed only by identities in the Organization, or through federation the design uses (the GitHub OIDC provider, IAM Identity Center and, from Phase 1 step 9.1, the home cluster's OIDC issuer).
    - Every cross-account access the design needs (the seed Job, replication to Backup, Terraform state) stays inside the Organization, so the RCPs block nothing intended. RCPs do not apply to the management account, which runs nothing.
- **Declarative policies:** organization-wide EC2 settings that hold even if an account's own settings are changed: block public access to AMIs and EBS snapshots, and IMDSv2 required by default.
- **Security services, delegated to Security Tooling:** Security Hub (AWS Foundational Security Best Practices and CIS standards; critical and high findings to Slack), AWS Config (focused recording and a CIS conformance pack), IAM Access Analyzer (external-access findings, plus policy checks in the Terraform pipeline), organization GuardDuty, an organization CloudTrail trail into Log Archive. Inspector optional; Macie and Detective not used.
- **Resource practices:** account-level S3 Block Public Access, TLS-only bucket policies, bucket-owner-enforced ownership; EBS encryption by default; KMS customer-managed keys for logs and backups; snapshot and AMI public-access blocks; IMDSv2 with hop limit 1 on EKS nodes; VPC endpoints, flow logs, empty default security groups, default VPCs removed.
- **A Well-Architected review** with the free tool, kept in `docs/`, revisited yearly.
- Everything in Terraform: `russetleaf-infra/envs/org/` and `russetleaf-infra/envs/security/`, with existing environments moved into their accounts.

## Alternatives considered

- **Single account (the previous design):** simplest and cheapest, but a compromise or mistake can reach everything; no separation of security tooling and logs from workloads; does not match the SRA.
- **AWS Control Tower:** sets up a similar landing zone automatically, with guardrails and account vending, but adds managed resources and costs, and hides much of what this project wants to show in Terraform. A good choice for a team; Terraform-managed Organizations shows the same structure explicitly.
- **The lean option** (account structure and free guardrails only, without Security Hub and Config): saves about $5–15/month, but loses continuous posture checks and the central findings view the SRA is built around.
- **A shared-services account for everything non-workload** (state, logs and backups together): fewer accounts, but mixes concerns the SRA deliberately separates.

## Consequences

- Each site, the logs, the backups and the security tooling are isolated; a compromised workload account cannot delete logs or backups, and cannot turn off security services (SCPs).
- A **data perimeter**: SCPs limit what the Organization's identities can do, and RCPs limit who can reach its resources, so a mistaken bucket or key policy cannot expose data outside the Organization.
- About **$5–15/month** more (Security Hub, Config, KMS), bringing the always-on total to about $15–35/month at the time (about **$18–40/month** after `rl-home-cp03`'s electricity was added by [ADR 1020](1020-three-node-ha-home-cluster.md); this total already includes the organization-wide security services).
- More moving parts: cross-account access for state, replication and the seed Job; per-account CI roles; per-account quotas; SES access per account (and Bedrock model access in russetleaf-home, Phase 2).
- Restructuring the existing account into the Organization happens early (before most resources exist), which keeps the move simple.
- A credible, SRA-shaped AWS foundation to show and discuss.

## When to revisit

- The project becomes a team effort: consider Control Tower for account vending and drift detection.
- Config costs grow with the demo stack: narrow recording further, or record only during demos.
- russetleaf.com becomes always-on or holds user data: add Macie, Detective and Inspector, and consider a separate network account.

## Open items

- Phase 1 step 2.0: create the management account, the Organization, OUs (including Policy Staging and Suspended), accounts, SCPs, RCPs, declarative policies, Identity Center, tag policies and root access management; move the existing account in.
- Confirm when building: the services RCPs support (S3, STS, KMS, SQS and Secrets Manager at the time of writing; AWS may have added more), the condition keys used, and the declarative policy attributes.
- Phase 1 step 2.0b: the security services in Security Tooling; first Security Hub score recorded.
- Phase 1 step 2.4: Access Analyzer policy checks in the Terraform pipeline.
- Phase 3 steps 0.1 and 1.x: russetleaf.com in its own account (SES, IMDSv2, VPC endpoints, flow logs).
- Run the first Well-Architected review once both sites exist; keep the report in `docs/`.
