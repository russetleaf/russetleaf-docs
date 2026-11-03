# ADR 1017: Intrusion detection and prevention in layers

- **Status:** Accepted; updated by [ADR 1019](1019-aws-multi-account-sra.md), [ADR 1020](1020-three-node-ha-home-cluster.md)
- **Date:** 2026-11-01
- **Applies to:** both sites and the AWS account
- **Phase:** 1. Later: Phase 3 adds AWS WAF, GuardDuty's EKS monitoring and the EKS audit alerts.

> **Update ([ADR 1019](1019-aws-multi-account-sra.md)):** CloudTrail is now a single **organization trail** delivering to the **Log Archive** account, and GuardDuty is enabled organization-wide with the **Security Tooling** account as delegated administrator; GuardDuty and Security Hub findings are routed to Slack from there.

> **Update ([ADR 1020](1020-three-node-ha-home-cluster.md)):** With the three-node home cluster's extra memory, **CrowdSec is realistic at home** (recommended, no longer optional).

## Context

Falco provides runtime detection inside containers, but on its own it is not an intrusion detection and prevention strategy. The design already had several prevention layers (the Cloudflare and AWS WAFs, edge login for the admin area, default-deny CiliumNetworkPolicies, Kyverno admission rules, seccomp, gVisor, read-only filesystems) and detection layers (Falco, Hubble, posture scanners). Three gaps remained:

- **Nothing watched the Kubernetes API** for suspicious activity (e.g. `exec` into pods, Secret reads, RBAC changes, anonymous requests).
- **No continuous AWS account threat detection**: no CloudTrail trail and no GuardDuty, only monthly Prowler scans, although the account holds keys, buckets and Bedrock access around the clock.
- **The home edge** had only basic Cloudflare settings: no managed rules, no login rate limiting, and XML-RPC (a common brute-force target) open.

## Decision

- **Kubernetes API audit monitoring:**
    - home: Talos API server audit logging with a focused policy, collected into Loki, with Loki alert rules (`KubeExecIntoProdPod`, `KubeUnexpectedSecretRead`, `KubeRBACChangedOutsideArgoCD`, `KubeAnonymousOrForbiddenSpike`, `KubeAuditLogMissing`) to `#rl-security`
    - EKS: audit logs in CloudWatch, plus GuardDuty's EKS audit-log monitoring
- **AWS account:** a multi-region **CloudTrail** trail (management events, log-file validation, own S3 bucket with `prevent_destroy`) and **GuardDuty**, with findings sent through EventBridge, SNS and Amazon Q Developer to `#rl-security` (high severity also to `#rl-critical`).
- **Home edge:** Cloudflare's free managed rule set, a rate-limiting rule on `/wp-login.php`, `/xmlrpc.php` blocked at the edge, and XML-RPC disabled inside WordPress (both sites).
- **Optional:** CrowdSec with a Cloudflare bouncer to ban abusive IPs automatically; Tetragon enforcement ([ADR 1015](1015-process-allow-listing.md)).
- **Not used:** an in-cluster network IDS (Suricata or Zeek).

## Alternatives considered

- **Falco's Kubernetes audit plugin** instead of Loki alert rules: richer rule language, but needs the API server to send audit events to a webhook (more Talos configuration) and more memory; Loki already holds the logs and runs alert rules.
- **Suricata or Zeek in the cluster:** heavy on CPU and memory, and most traffic is either TLS terminated (and inspected) at the WAFs, or covered by Cilium policies and Hubble.
- **GuardDuty Runtime Monitoring** (an AWS agent on EKS nodes): overlaps with Falco, adds cost per node, and does not cover the home cluster.
- **AWS Security Hub:** aggregates findings and runs posture checks continuously, but costs per check; Prowler ([ADR 1007](1007-prowler-not-threatmapper.md)) and GuardDuty cover the needs here.
- **Cloudflare Pro** (paid WAF rule sets): more rules, but the free managed rule set plus rate limiting and XML-RPC blocking covers the WordPress basics at no cost.

## Consequences

- Attacks are met at every layer: blocked at the edge or by policy where possible, and detected at runtime, in the Kubernetes API, and in the AWS account where not.
- New alerts to tune (audit rules in particular), reviewed in the monthly alert-noise review.
- About $1–5/month for GuardDuty; CloudTrail storage costs pennies.
- Home audit logs add log volume to Loki; the focused audit policy keeps it small.

## When to revisit

- russetleaf.com becomes always-on or holds personal data: consider GuardDuty Runtime Monitoring, Security Hub, and Cloudflare Pro or AWS WAF Bot Control.
- More memory at home: CrowdSec, Falco's audit plugin, or Tetragon enforcement.
- A home-network IDS (router-level) becomes part of the lab.

## Open items

- Phase 1 step 2.1: CloudTrail, GuardDuty and the Slack routing; test with GuardDuty sample findings.
- Phase 1 steps 2.2 and 4.6: the Talos audit policy, collection into Loki, and the audit alert rules.
- Phase 1 step 2.3: Cloudflare managed rules, rate limiting and XML-RPC blocking.
- Phase 1 step 7.9 (optional): CrowdSec.
