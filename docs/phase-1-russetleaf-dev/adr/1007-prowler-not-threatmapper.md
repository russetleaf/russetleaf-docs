# ADR 1007: Prowler for AWS account posture; Deepfence ThreatMapper not used

- **Status:** Accepted; updated by ADR 1019
- **Date:** 2026-11-01
- **Applies to:** both sites (the AWS account is shared by the home lab's AWS resources and russetleaf.com)
- **Phase:** 1. Later: Phase 3 adds a Prowler run per demo with the stack up.


> **Update (ADR 1019):** The project now follows the AWS Security Reference Architecture, with **Security Hub** (AWS Foundational Security Best Practices and CIS standards) as the **continuous** posture check across all accounts. Prowler remains as a free monthly **second opinion**, now run against every account. The "AWS Security Hub" alternative below was rejected on cost at the time; ADR 1019 accepts that cost (about $5–15/month with Config and KMS).
## Context
Deepfence ThreatMapper is an open-source security platform combining vulnerability, secret and malware scanning, Kubernetes and cloud-account posture checks, and **ThreatGraph**, which ranks findings by attack path using observed network topology. (Live runtime detection is in Deepfence's commercial ThreatStryker, not ThreatMapper.)

Most of its features are already covered in this design:

| ThreatMapper feature | Already covered by |
|---|---|
| Image and running-container vulnerability scanning | Trivy (CI), Trivy Operator |
| Secret scanning | gitleaks (repos), Trivy (images) |
| Kubernetes posture and compliance | Kubescape CLI, Trivy Operator, kube-bench, Kyverno |
| Infrastructure-code scanning | Checkov |
| Network topology | Hubble |
| Runtime detection | Falco |
| Attack-path ranking | Nothing (nice to have at this scale) |
| Malware scanning | Nothing (low value: minimal, signed, scanned, immutable images with read-only filesystems) |
| **AWS account posture** | **Nothing (the real gap)** |

Nothing checked the AWS account's actual settings (IAM users and keys, root MFA, CloudTrail, S3 public-access settings, security groups, encryption defaults, GuardDuty status). Terraform and Checkov only check what's written in code, not what's configured in the account, including anything created by hand or by AWS.

ThreatMapper's management console bundles several databases and services; its documented requirements are on the order of 16 GB of RAM and 4 CPU cores for the console alone, more than box 1 has in total.

## Decision
- **Don't use ThreatMapper.**
- **Use Prowler** (open source) to scan the AWS account against **CIS AWS Foundations**, **AWS Foundational Security Best Practices** and related checks:
  - a **scheduled GitHub Actions workflow** in `russetleaf-infra`, **monthly** (the account exists permanently), plus manual runs; it assumes a **read-only audit role** through GitHub OIDC (AWS's `SecurityAudit` and `ViewOnlyAccess` managed policies), so no keys are stored
  - an extra run **once per AWS demo** with the demo stack up, to check EKS, RDS, the ALB and the rest while they exist
  - reports kept as workflow artifacts, a summary committed to `russetleaf-gitops/docs/security/`, and a short Slack message to `#rl-security` with the counts of failed high and critical checks
  - accepted findings explained in the summary (e.g. checks that don't apply to a demo account)

## Alternatives considered
- **ThreatMapper:** broadest single tool, but its console needs more memory than box 1 has, and it duplicates tools already built into CI and the clusters.
- ~~**AWS Security Hub** (with the Foundational Security Best Practices standard): continuous and AWS-native, but billed per check, and covers only AWS; a reasonable upgrade if the account ever holds production data.~~ **Superseded by ADR 1019:** Security Hub is now used as the continuous check, with Prowler as a second opinion.
- **Kubescape or Trivy for cloud posture:** focused on Kubernetes and images rather than full AWS account configuration.
- **No account scanning:** leaves configuration done outside Terraform unchecked.

## Consequences
- The AWS account is checked against recognized frameworks at no cost, with nothing to run in the clusters.
- Scans are periodic, not continuous; AWS Budgets, Cost Anomaly Detection and CloudWatch alarms remain the continuous signals.
- No attack-path ranking or malware scanning; acceptable at this scale.

## When to revisit
- Much more memory available (e.g. a dedicated security node), making ThreatMapper's console affordable.
- ~~The AWS account holding production or personal data: consider AWS Security Hub for continuous checks.~~ Done (ADR 1019).
- Many more services, where attack-path ranking would help prioritize findings.

## Open items
- Phase 1 step 7.5: first Prowler run; record the baseline and accepted findings.
- Phase 3 step 5.1: first run with the demo stack up.
- Check ThreatMapper's current project status if this decision is revisited.
