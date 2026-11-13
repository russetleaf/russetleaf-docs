# ADR 1058: Security detections as code in Sigma, on Loki, instead of a SIEM product

- **Status:** Accepted
- **Date:** 2026-11-08
- **Applies to:** russetleaf.dev; aws.russetleaf.dev reuses the rules when its cluster runs
- **Phase:** 1 (step 7.15). Later: Phase 3 converts the same rules for the EKS audit logs in CloudWatch.

> **Update (2026-11-13):** step 7.16 adds two sources to the `security` tenant, with their own Sigma rules: the DMARC aggregate reports for russetleaf.dev (parsed by parsedmarc) and the Google Workspace sign-in and admin events (from the Admin SDK Reports API) ([ADR 1059](1059-google-workspace-identity.md)).

## Context

The design has no SIEM (security information and event management system). Its functions are spread across separate tools: Falco and the Kubernetes audit alert rules in Loki ([ADR 1017](1017-intrusion-detection-and-prevention.md)), GuardDuty and Security Hub in the Security Tooling account, CloudTrail and Config history in the Log Archive account ([ADR 1019](1019-aws-multi-account-sra.md)), the Cloudflare WAF and CrowdSec. Every alert reaches `#rl-security`. [ADR 1005](1005-loki-alloy-for-logs.md) left security analysis across sources to [ADR 1019](1019-aws-multi-account-sra.md)'s trigger, which adopts Security Lake once a SIEM is connected.

That covers detection and alerting, but leaves three gaps that a SIEM normally fills:

- **No single place to investigate.** Following an incident means searching Loki, CloudTrail (through Athena), GuardDuty and Cloudflare separately, with no shared timeline.
- **Short retention.** The home cluster's logs are kept for 7 days. Only the API audit log is archived (1 year, [ADR 1033](1033-identity-and-access.md)), and the archive is not searchable from Grafana. An intrusion found after a week has lost its Falco events and sign-in logs.
- **Detection rules without a standard form or tests.** The Loki alert rules are written by hand in LogQL, nothing checks that they still fire after a change in log format, and the planned MITRE ATT&CK detection map (step 7.1, [ADR 1036](1036-compliance-frameworks-and-privacy.md)) would be kept by hand.

Constraints: about 32 GB of memory across three nodes, mostly allocated ([ADR 1020](1020-three-node-ha-home-cluster.md)); cost near zero; one operator; Talos nodes, which run no host agents; open-source tools by default ([ADR 1053](1053-open-source-tools-by-default.md)).

## Decision

**No dedicated SIEM product.** The three missing functions are built on the existing Loki, Grafana and Alertmanager instead:

- **Detections as code in Sigma.** Sigma is the open, vendor-neutral format for detection rules. The project's rules live in `russetleaf-gitops/platform/detections/`, one YAML file per rule, each tagged with the MITRE ATT&CK techniques it covers. Grafana's pySigma Loki backend (with `sigma-cli`) converts them to Loki ruler rules in CI, so they run on the existing ruler and reach Slack through the existing Alertmanager routes. The hand-written Kubernetes audit alerts are rewritten as Sigma rules, with the same names.
- **Every rule is tested.** CI runs each rule against sample log lines: at least one that must match and one that must not. A rule without both does not merge.
- **The ATT&CK detection map is generated** from the rules' tags, together with the tags of the Falco rules, the GuardDuty finding types and the other sources, so it cannot drift from what is deployed.
- **Longer retention for the `security` tenant only:** Loki's per-tenant retention keeps the `security` tenant ([ADR 1035](1035-platform-security.md)) for **90 days**; the `apps` tenant stays at 7 days. The tenant gains the Falco events, CrowdSec decisions and the WordPress sign-in requests (`/wp-login.php` and the admin area).
- **AWS events in the same queries.** CloudTrail management events and GuardDuty findings are forwarded into the `security` tenant (from the Log Archive bucket's event notifications, and from EventBridge), so one Grafana query covers the AWS accounts and the cluster. The Log Archive account keeps the authoritative copies.
- **A security overview dashboard** in Grafana's Security organization: alerts by ATT&CK technique, an incident timeline across sources, and the sign-in activity.

A full SIEM is recorded in the [improvements list](../improvements.md) (I1-4), with its triggers.

## Alternatives considered

- **Wazuh** (open source, GPL): host intrusion detection, file integrity monitoring and a SIEM with its own dashboard. Its agent needs a host operating system to run on, which Talos does not provide, so it would see only what the cluster already sends; its indexer (an OpenSearch fork) needs about 4–8 GB of memory; and its detections overlap with Falco and GuardDuty.
- **Security Onion:** a complete security monitoring distribution, but it needs a dedicated machine with 16 GB of memory or more, and it is built around network sensors (Suricata, Zeek), which [ADR 1017](1017-intrusion-detection-and-prevention.md) chose not to use.
- **OpenSearch Security Analytics,** at home or as Amazon OpenSearch Service, optionally fed by **Security Lake:** runs Sigma rules natively and correlates findings. At home, it has the memory cost [ADR 1005](1005-loki-alloy-for-logs.md) rejected; on AWS, about $25 a month or more for the smallest instance, plus Security Lake's per-GB ingestion and a second copy of every log.
- **Elastic Security:** the same memory and operating costs as OpenSearch, with more features under Elastic's licenses.
- **Splunk, Microsoft Sentinel or Datadog Cloud SIEM:** proprietary ([ADR 1053](1053-open-source-tools-by-default.md)), and paid beyond small free tiers that do not hold this project's volume for 90 days.
- **Loki rules written by hand, as now:** no standard format, no tests, and a hand-kept ATT&CK map.
- **Falco's rules only:** they cover the container runtime, not the API audit log, AWS or the WordPress sign-ins.

## Consequences

- An investigation starts in one place: Grafana's Security organization, with 90 days of security events from the cluster and the AWS accounts.
- Detection rules are reviewed, versioned and tested like code, and the ATT&CK map shows what is really deployed.
- The rules are portable: the same Sigma files convert for OpenSearch, Elastic or Splunk, so adopting a SIEM later keeps the work.
- About 0.2–0.5 GB more memory for Loki, from the larger `security` tenant; storage costs cents a month in S3.
- The `security` tenant holds visitors' IP addresses (the sign-in requests) for 90 days. The retention schedule and the record of processing record it, with the reason (detecting and investigating attacks on the sign-in page).
- Not provided: case management, threat-intelligence enrichment, and user and entity behavior analytics. For one operator, incidents are tracked as GitHub Issues and postmortems ([ADR 1046](1046-incident-response-and-runbook-index.md)).
- Sigma's correlation rules (several events in sequence) depend on the backend's support; the rules that need it stay as hand-written LogQL, tested the same way, until the backend supports them.

## When to revisit

- A second operator or a security team joins, and needs case management or shared investigations: adopt a SIEM (I1-4).
- A compliance audit requires a SIEM, or security log retention beyond 90 days that is searchable.
- The `security` tenant's volume makes Loki slow to query, or its memory grows past about 1 GB.
- aws.russetleaf.dev becomes always-on, with its own logs to correlate: reconsider Security Lake under [ADR 1019](1019-aws-multi-account-sra.md)'s trigger.

## Open items

- Phase 1 step 7.15: check the licenses of `sigma-cli` and the pySigma Loki backend against [ADR 1053](1053-open-source-tools-by-default.md), and the license of any SigmaHQ community rule adapted (the Detection Rule License requires attribution); record the security tenant's daily volume and Loki's memory after a week.
