# ADR 1017: Intrusion detection and prevention in layers

- **Status:** Accepted; updated by [ADR 1019](1019-aws-multi-account-sra.md), [ADR 1020](1020-three-node-ha-home-cluster.md), [ADR 1058](1058-security-detections-as-code.md)
- **Date:** 2026-11-01
- **Applies to:** both sites and the AWS account
- **Phase:** 1. Later: Phase 3 adds AWS WAF, GuardDuty's EKS monitoring and the EKS audit alerts.

> **Update ([ADR 1019](1019-aws-multi-account-sra.md)):** CloudTrail is now a single **organization trail** delivering to the **Log Archive** account, and GuardDuty is enabled organization-wide with the **Security Tooling** account as delegated administrator; GuardDuty and Security Hub findings are routed to Slack from there.

> **Update ([ADR 1020](1020-three-node-ha-home-cluster.md)):** With the three-node home cluster's extra memory, **CrowdSec is realistic at home** (recommended, no longer optional).

> **Update ([ADR 1058](1058-security-detections-as-code.md)):** the Kubernetes audit alert rules are written as **Sigma rules**, tagged with MITRE ATT&CK techniques, tested in CI and converted to Loki ruler rules; CloudTrail and GuardDuty events are also forwarded into Loki's `security` tenant, kept for 90 days, so the sources can be searched together. No SIEM product is used.

## Context

Falco provides runtime detection inside containers, but on its own it is not an intrusion detection and prevention strategy. The design already had several prevention layers (the Cloudflare and AWS WAFs, edge login for the admin area, default-deny CiliumNetworkPolicies, Kyverno admission rules, seccomp, gVisor, read-only filesystems) and detection layers (Falco, Hubble, posture scanners). Three gaps remained:

- **Nothing watched the Kubernetes API** for suspicious activity (for example, `exec` into pods, Secret reads, RBAC changes, anonymous requests).
- **No continuous AWS account threat detection**: no CloudTrail trail and no GuardDuty, only monthly Prowler scans, although the account holds keys, buckets and Bedrock access around the clock.
- **The home edge** had only basic Cloudflare settings: no managed rules, no login rate limiting, and XML-RPC (a common brute-force target) open.

## Decision

- **Kubernetes API audit monitoring:**
    - home: Talos API server audit logging with a focused policy, collected into Loki, with Loki alert rules (`KubeExecIntoProdPod`, `KubeUnexpectedSecretRead`, `KubeRBACChangedOutsideArgoCD`, `KubeAnonymousOrForbiddenSpike`, `KubeAuditLogMissing`) to `#rl-security`
    - EKS: audit logs in CloudWatch, plus GuardDuty's EKS audit-log monitoring
- **AWS account:** ~~a multi-region **CloudTrail** trail in the workload account~~ an **organization CloudTrail trail** delivering to the Log Archive account ([ADR 1019](1019-aws-multi-account-sra.md)), with log-file validation, and **GuardDuty** (organization-wide), with findings sent through EventBridge, SNS and Amazon Q Developer to `#rl-security` (high severity also to `#rl-critical`).
- **Home edge:** Cloudflare's free managed rule set, a rate-limiting rule on `/wp-login.php`, `/xmlrpc.php` blocked at the edge, and XML-RPC disabled inside WordPress (both sites).
- **Optional:** CrowdSec with a Cloudflare bouncer to ban abusive IPs automatically; Tetragon enforcement ([ADR 1015](1015-process-allow-listing.md)).
- **Not used:** an in-cluster network IDS (Suricata or Zeek).

## Alternatives considered

- **Falco's Kubernetes audit plugin** instead of Loki alert rules: richer rule language, but needs the API server to send audit events to a webhook (more Talos configuration) and more memory; Loki already holds the logs and runs alert rules.
- **AWS Network Firewall** for the demo VPC: stateful filtering of all VPC traffic by domain and IP, including the nodes' own outbound traffic, but about $0.40 an hour per endpoint plus data (check current pricing), over half again the demo's hourly cost. **Route 53 Resolver DNS Firewall** is used instead (Phase 3 step 1.3): an allow-list of domains for the whole VPC at a few cents per demo, which stops lookups of unknown domains from pods and nodes alike, though not connections to raw IP addresses; pod traffic is also limited by Cilium's DNS-name policies.
- **Suricata or Zeek in the cluster:** heavy on CPU and memory, and most traffic is either TLS terminated (and inspected) at the WAFs, or covered by Cilium policies and Hubble.
- **GuardDuty Runtime Monitoring** (an AWS agent on EKS nodes): overlaps with Falco, adds cost per node (roughly $10–20 a month on EKS), and does not cover the home cluster; Falco runs the same rules on both. For **EC2**, it could also watch Phase 2's rented GPU training instance, where Falco does not run, but that instance lives an hour or two with outbound-only networking and a narrow role, and GuardDuty's standard detections already cover its API calls and network traffic ([ADR 2005](../../phase-2-ai-mlops/adr/2005-fine-tuning-on-a-rented-gpu.md)).
- **AWS Shield Advanced:** DDoS response team access, cost protection against attack-driven scaling, and advanced detection, for about $3,000 a month with a one-year commitment; far out of proportion for a site that is an offline page most of the time. **Shield Standard** (free, automatic on CloudFront, Route 53 and the ALB), the CloudFront flat-rate plan's DDoS protection and the edge rate limits ([ADR 3009](../../phase-3-aws-russetleaf-dev/adr/3009-edge-waf-on-cloudfront-free-plan.md)) cover this project; the Business flat-rate plan's anti-DDoS rule group is the cheaper next step if one is ever needed. At home, Cloudflare provides DDoS protection.
- **GuardDuty Malware Protection for S3:** scans new objects in a bucket (here, the media buckets) for malware; low value while only signed-in admins can upload, and billed per GB scanned; worth adding if visitors could ever upload files.
- ~~**AWS Security Hub:** aggregates findings and runs posture checks continuously, but costs per check; Prowler ([ADR 1007](1007-prowler-not-threatmapper.md)) and GuardDuty cover the needs here.~~ **Superseded by [ADR 1019](1019-aws-multi-account-sra.md):** Security Hub is now used.
- **Cloudflare Pro** (paid WAF rule sets): more rules, but the free managed rule set plus rate limiting and XML-RPC blocking covers the WordPress basics at no cost.

## Consequences

- Attacks are met at every layer: blocked at the edge or by policy where possible, and detected at runtime, in the Kubernetes API, and in the AWS account where not.
- New alerts to tune (audit rules in particular), reviewed in the monthly alert-noise review.
- About $1–5/month for GuardDuty; CloudTrail storage costs pennies.
- Home audit logs add log volume to Loki; the focused audit policy keeps it small.

## When to revisit

- aws.russetleaf.dev becomes always-on or holds personal data: consider GuardDuty Runtime Monitoring, Shield Advanced (if outages carry real cost) and Cloudflare Pro or AWS WAF Bot Control.
- More memory at home: Falco's audit plugin (CrowdSec and Tetragon are already realistic since [ADR 1020](1020-three-node-ha-home-cluster.md)).
- A home-network IDS (router-level) becomes part of the lab.

## Open items

- Phase 1 step 2.0b: the organization CloudTrail trail, GuardDuty and the Slack routing; test with GuardDuty sample findings.
- Phase 1 steps 2.2 and 4.6: the Talos audit policy, collection into Loki, and the audit alert rules.
- Phase 1 step 2.3: Cloudflare managed rules, rate limiting and XML-RPC blocking.
- Phase 1 step 7.9 (optional): CrowdSec.
