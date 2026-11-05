# ADR 1019: Multi-account AWS structure aligned with the AWS Security Reference Architecture

- **Status:** Accepted; RCPs, Suspended and Policy Staging OUs, and declarative policies added 2026-11-03; russetleaf-home created new instead of invited, 2026-11-04
- **Date:** 2026-11-01
- **Applies to:** all AWS usage by both sites
- **Phase:** 1 (the Organization and all accounts except russetleaf-com). Later: Phase 3 creates russetleaf-com.
- **Updates:** [ADR 1007](1007-prowler-not-threatmapper.md) (Security Hub now used; Prowler kept as a second opinion), [ADR 1017](1017-intrusion-detection-and-prevention.md) (organization CloudTrail and GuardDuty, delegated administration), [ADR 1018](1018-disaster-recovery.md) (a dedicated management account; CloudTrail logs in Log Archive)

## Context

The design used **one AWS account** for everything (the home lab's AWS resources, russetleaf.com, Terraform state, CloudTrail, GuardDuty), plus a backup account under an Organization whose **management account was the workload account**. The **AWS Security Reference Architecture (SRA)** recommends instead: a management account that runs nothing; a Security OU with a **Security Tooling** account (delegated administrator for security services) and a **Log Archive** account; separate accounts per workload; organization-wide guardrails (SCPs); and centralized security services (Security Hub, GuardDuty, Config, Access Analyzer, an organization CloudTrail trail).

## Decision

- **Accounts and OUs:** Management (dedicated, new); Security OU: Security Tooling, Log Archive, Backup; Infrastructure OU: russetleaf-infra (Terraform state and CI entry points); Workloads OU: russetleaf-home and russetleaf-com. **Every account is created new by the Organization**, russetleaf-home included. Two further OUs from AWS's recommended structure, normally empty: **Policy Staging** (new SCPs and RCPs are attached here first, with a test account, before the real OUs) and **Suspended** (a deny-all SCP; moving a compromised account here is the first containment step).
- **Guardrails:** SCPs (no leaving the Organization; no disabling security services; us-east-1 and us-west-2 only; no member-account root actions; no IAM users or access keys except a named exception for the home cluster's scoped keys; Log Archive and Backup buckets protected); **resource control policies (RCPs)** forming a data perimeter (below); **declarative policies** for EC2 settings; centralized root access management; IAM Identity Center with MFA; tag policies; alternate security contacts; per-account and consolidated budgets.
- **Resource control policies (RCPs)** on every OU, limiting who can access the Organization's resources whatever their own resource policies say:
    - **Organization-only access:** S3, KMS, SQS and Secrets Manager resources can be accessed only by identities in the Organization (`aws:PrincipalOrgID`).
    - **AWS services only on the Organization's behalf:** AWS service principals (CloudFront serving media, S3 replication, CloudTrail and Config delivery) are allowed only when acting for the Organization (`aws:SourceOrgID`), which prevents confused-deputy access.
    - **TLS required** for every request to those services (`aws:SecureTransport`), organization-wide rather than in each policy.
    - **STS:** roles can be assumed only by identities in the Organization, or through federation the design uses (the GitHub OIDC provider, IAM Identity Center and, from Phase 1 step 9.1, the home cluster's OIDC issuer).
    - Every cross-account access the design needs (the seed Job, replication to Backup, Terraform state) stays inside the Organization, so the RCPs block nothing intended. RCPs do not apply to the management account, which runs nothing.
- **Management policies:** tag policies; an **AI services opt-out policy** (AWS AI services may not store or use the Organization's content to improve their models); a **chat applications policy** (Amazon Q Developer in chat applications limited to the project's Slack workspace). Newer policy types (e.g. for Security Hub or Inspector) are reviewed when building.
- **Declarative policies:** organization-wide EC2 settings that hold even if an account's own settings are changed: block public access to AMIs and EBS snapshots, and IMDSv2 required by default.
- **Security services, delegated to Security Tooling:** Security Hub (AWS Foundational Security Best Practices and CIS AWS Foundations v3.0; critical and high findings to Slack), **EventBridge sign-in alerts** for the management account's root user and the break-glass permission set, AWS Config (focused recording, with daily rather than continuous recording for the high-churn demo resource types in russetleaf-com, and a CIS conformance pack), IAM Access Analyzer (external-access findings, plus policy checks in the Terraform pipeline), organization GuardDuty, an organization CloudTrail trail into Log Archive (management events, plus S3 data events for the Terraform state and backup buckets only). Inspector optional; Macie and Detective not used.
- **Resource practices:** account-level S3 Block Public Access, TLS-only bucket policies, bucket-owner-enforced ownership; EBS encryption by default; KMS customer-managed keys for logs and backups; snapshot and AMI public-access blocks; IMDSv2 with hop limit 1 on EKS nodes; VPC endpoints, flow logs, empty default security groups, default VPCs removed.
- **A Well-Architected review** with the free tool, kept in `docs/`, revisited yearly.
- Everything in Terraform: `russetleaf-infra/envs/org/` and `russetleaf-infra/envs/security/`, with existing environments moved into their accounts.

## Alternatives considered

- **Single account (the previous design):** simplest and cheapest, but a compromise or mistake can reach everything; no separation of security tooling and logs from workloads; does not match the SRA.
- **AWS Control Tower:** sets up a similar landing zone automatically, with guardrails and account vending, but adds managed resources and costs, and hides much of what this project wants to show in Terraform. A good choice for a team; Terraform-managed Organizations shows the same structure explicitly.
- **The lean option** (account structure and free guardrails only, without Security Hub and Config): saves about $5–15/month, but loses continuous posture checks and the central findings view the SRA is built around.
- **Amazon Macie** (discovers sensitive data in S3 and flags bucket exposure): the only sensitive data is already known and located (commenters' emails and password hashes in the database dumps), and is protected by a customer-managed key, lifecycle limits, Object Lock and CloudTrail data events ([ADR 1043](1043-database-encryption.md), [ADR 1042](1042-s3-versioning-lifecycle-and-storage-classes.md)); Macie would mostly confirm the record of processing, at a per-GB scanning cost. Added if russetleaf.com becomes always-on or holds user data (below).
- **AWS Security Lake** (collects CloudTrail, VPC flow logs, Route 53 resolver logs, Security Hub findings and EKS audit logs from every account into one S3 data lake in the OCSF format, for Athena or a SIEM): the important logs are already centralized (the organization trail, Config history, flow logs and EKS audit logs in Log Archive; findings in Security Hub; Kubernetes events in Loki), and nothing in the design consumes OCSF; it would add per-GB ingestion and normalization costs and a second copy of the same data.
- **Amazon Detective** (investigation graphs built from CloudTrail, flow logs and GuardDuty findings): useful for a security team handling many findings; for one operator, Security Hub, GuardDuty and the logs in Log Archive are enough. Added if russetleaf.com becomes always-on or holds user data (below).
- **AWS Firewall Manager** (pushes WAF, Shield, security-group and network-firewall policies across accounts; needs Config; about $100 per policy per region per month): the project has two web ACLs, both in Terraform, and SCPs and declarative policies already enforce settings organization-wide.
- **CloudTrail to CloudWatch Logs with CIS metric-filter alarms:** the older CIS benchmark's alarms on root use, failed sign-ins and security changes; adds per-GB log costs, while CIS v3.0, the EventBridge sign-in alerts and GuardDuty cover the important cases.
- **VPC flow logs in CloudWatch Logs with alarms:** per-GB costs for little gain on a demo stack; flow logs go to Log Archive for investigations, GuardDuty already analyzes flow logs for threats, and Hubble covers pod traffic.
- **AWS Systems Manager** (Session Manager, Patch Manager, Parameter Store): Talos has no shell or agent and the EKS nodes are replaced rather than logged into or patched in place (pinned AMI and Talos versions instead); Secrets Manager holds the secrets and everything else is in Git. Session Manager on Phase 2's rented GPU instance is an optional debugging aid, off by default.
- **Backup policies (AWS Organizations):** they configure AWS Backup plans across accounts, and AWS Backup is not used ([ADR 1018](1018-disaster-recovery.md)).
- **Automatic rotation of third-party tokens** (Cloudflare, Slack, Google OAuth) with custom Secrets Manager rotation functions: one Lambda per provider to write and maintain; these rotate on the manual schedules in the ongoing-operations tables instead. Automatic rotation is used where AWS provides it (the RDS master password, RDS Proxy's `wordpress` secret), and short-lived values replace rotation elsewhere (IAM auth tokens, the per-demo Valkey token). Passwords that never leave the home cluster (MariaDB, Valkey) are generated there and rotated automatically by a scheduled job ([ADR 1047](1047-in-cluster-credentials-and-rotation.md)).
- **AWS Resource Access Manager (RAM):** shares subnets, Transit Gateways, Resolver rules or DNS Firewall rule groups between accounts; the cross-account access here (the seed Job, replication, Terraform state) uses bucket and key policies inside the Organization, and nothing is shared at the network level. It comes with a separate network account (below).
- **IAM Identity Center ABAC** (user attributes passed as session tags, matched against resource tags): suits many people across teams; with one operator and a few permission sets (admin, read-only, break-glass, and the agents' plan-only set), explicit permission sets are clearer. Revisit with identity-provider groups when more people join ([ADR 1033](1033-identity-and-access.md)).
- **AWS Trusted Advisor beyond its free checks:** the core checks (S3 bucket permissions, open security-group ports, root MFA, public EBS and RDS snapshots, service limits) are available in every account at no cost and need no setup; the full checks and the organization view need a Business support plan (about $100 a month at least, more than the project's AWS bill), and Security Hub, Prowler and AWS Budgets already cover their security and cost findings.
- **A shared-services account for everything non-workload** (state, logs and backups together): fewer accounts, but mixes concerns the SRA deliberately separates.

- **Inviting the existing account as russetleaf-home** (the earlier plan): would keep the account and its history, but that account is already the **management account of its own Organization** (created in 2022 for an earlier project, with three member accounts). It could join another Organization only after removing or closing those accounts and deleting its Organization, and it holds no RussetLeaf resources, so there is nothing to bring across.
- **AWS Billing Transfer** (another Organization's management account, such as the 2022 one, pays RussetLeaf's consolidated bill): one card for both, but Cost Anomaly Detection does not work for a transferred bill, Budgets and Cost Explorer show only pro forma costs (without credits), the transfer can start only on the first of a month, and RussetLeaf's billing would depend permanently on an Organization outside the project. Consolidated billing within the Organization already gives one bill for every RussetLeaf account.
- **Reusing that 2022 Organization** (its management account as RussetLeaf's): no new management account, but it would inherit years of unrelated resources, IAM users with long-lived keys and an old SCP, in the one account that is meant to run nothing.

## Consequences

- Each site, the logs, the backups and the security tooling are isolated; a compromised workload account cannot delete logs or backups, and cannot turn off security services (SCPs).
- A **data perimeter**: SCPs limit what the Organization's identities can do, and RCPs limit who can reach its resources, so a mistaken bucket or key policy cannot expose data outside the Organization.
- About **$5–15/month** more (Security Hub, Config, KMS), included in the home lab's always-on total of about **$14–33/month** (with `rl-home-cp03`'s electricity from [ADR 1020](1020-three-node-ha-home-cluster.md); see the Phase 1 design's cost table).
- More moving parts: cross-account access for state, replication and the seed Job; per-account CI roles; per-account quotas; SES access per account (and Bedrock model access in russetleaf-home, Phase 2).
- Nothing is migrated: every account starts empty inside the Organization, under its guardrails from the first day. The operator's older AWS Organization (from a 2022 project) stays separate and is not part of RussetLeaf; it is cleaned up or closed on its own schedule.
- A credible, SRA-shaped AWS foundation to show and discuss.

## When to revisit

- The project becomes a team effort: consider Control Tower for account vending and drift detection.
- Config costs grow with the demo stack despite daily recording: narrow recording further, or record only during demos.
- russetleaf.com becomes always-on or holds user data: add Macie, Detective and Inspector, and consider a separate network account.
- A SIEM is connected (e.g. Splunk or OpenSearch Security Analytics), or log volume makes querying the raw Log Archive painful: adopt Security Lake.

## Open items

- Phase 1 step 2.0: create the management account, the Organization, OUs (including Policy Staging and Suspended), accounts, SCPs, RCPs, declarative policies, Identity Center, tag policies and root access management, with every account (russetleaf-home included) created new; the Organization and Identity Center are first enabled by hand in the console, then imported into Terraform.
- Confirm when building: the services RCPs support (S3, STS, KMS, SQS and Secrets Manager at the time of writing; AWS may have added more), the condition keys used, and the declarative policy attributes.
- Phase 1 step 2.0b: the security services in Security Tooling; first Security Hub score recorded.
- Phase 1 step 2.4: Access Analyzer policy checks in the Terraform pipeline.
- Phase 3 steps 0.1 and 1.x: russetleaf.com in its own account (SES, IMDSv2, VPC endpoints, flow logs).
- Run the first Well-Architected review once both sites exist; keep the report in `docs/`.
