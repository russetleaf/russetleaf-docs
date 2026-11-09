# ADR 1005: Loki and Grafana Alloy for logs

- **Status:** Accepted; ELK alternative expanded 2026-11-06; updated by [ADR 1058](1058-security-detections-as-code.md)
- **Date:** 2026-11-01
- **Applies to:** both sites
- **Phase:** 1. Later: Phase 2 adds the summarizer and Bedrock log alerts; Phase 3 adds Loki on EKS (14-day retention).

> **Update ([ADR 1058](1058-security-detections-as-code.md)):** the `security` tenant is kept for **90 days** (the `apps` tenant stays at 7), and security analysis across sources is done with **Sigma rules converted to Loki alert rules**, with CloudTrail and GuardDuty events forwarded into Loki, instead of waiting for a SIEM.

## Context

The design covered metrics (Prometheus), alerts (Alertmanager to Slack), network flows (Hubble), security events (Falco) and optional traces (Tempo), but had **no central log storage**. Logs could only be read live with `kubectl logs` or `stern`; once a pod restarted, was evicted, or a staging run was deleted, its logs were lost. That makes debugging and incident review much harder.

Constraints: `rl-home-cp01` of the home lab has 8 GB of RAM and already uses about 6–7 GB; both sites should work the same way; the home site runs outside AWS; cost must stay near zero.

## Decision

- **Grafana Loki** in **single-binary mode** stores logs, with its data in an **S3 bucket** per site and a small local cache. Retention: **7 days** at home, **14 days** for russetleaf.com (bucket in the always-on edge stack, so demo logs outlive the demo).
- **Grafana Alloy** runs on every node, collects container logs, applies a **small fixed label set** (`site`, `env`, `cluster`, `namespace`, `app`, `container`), drops noise and masks obvious secrets.
- **Talos system logs** are sent by Talos to Alloy, so node-level logs are searchable too.
- **Loki's ruler** sends log-based alerts to the existing Alertmanager → Slack routing.
- The **EKS control plane audit logs** stay in CloudWatch Logs.

## Alternatives considered

- **VictoriaLogs:** lighter on memory than Loki and simple to run; a reasonable fit for 8 GB. Not chosen because Loki is more widely used and integrates natively with Grafana (correlation with metrics and traces).
- **ELK (Elasticsearch, Logstash, Kibana) or OpenSearch:** the long-standing standard for central logs, with **full-text search** over every word of every log line, rich aggregations, and security-analytics features. Against it here:
    - **Indexing everything is expensive:** Elasticsearch builds an index of every word, so it needs fast local disk and a lot of memory. Loki indexes only a few labels (`site`, `env`, `namespace`, `app` and the others above) and stores the compressed log text in **S3**, which is cheap and needs no disks to manage; at this project's volume, searching the text within a label and time range is fast enough.
    - **Memory:** even one Elasticsearch node, with Logstash and Kibana, needs about 3–4 GB or more (Elasticsearch runs on the Java virtual machine with its own heap), against Loki's 0.3–0.7 GB, on nodes whose memory is already allocated ([ADR 1020](1020-three-node-ha-home-cluster.md)).
    - **Running it:** shards, index lifecycle policies, snapshots and upgrades, for a cluster that is meant to be run by one person.
    - **Managed on AWS:** Amazon OpenSearch Service removes the running work but costs about $25 a month or more for the smallest instance (OpenSearch Serverless costs much more; check current pricing), does not cover the home site without shipping its logs out, and charges for data sent to it.
    - **One toolset:** Loki is queried in the same Grafana as Prometheus and Tempo, with links from a metric or trace to the matching logs; ELK would add a second interface (Kibana) and query language.
    - **Licensing:** Elastic moved Elasticsearch and Kibana from Apache 2.0 to source-available licenses in 2021 and added an open-source option (AGPL) in 2024; **OpenSearch** is the Apache-licensed fork made in 2021 and now run by the Linux Foundation. Either could be used; neither changes the points above.
    - **What is given up:** fast search for an arbitrary word across all logs, and the built-in security analytics. Searches here start from labels and a time range, and security analysis across sources ~~is left to [ADR 1019](1019-aws-multi-account-sra.md)'s trigger (adopt Security Lake once a SIEM is connected)~~ is built on Loki with Sigma rules ([ADR 1058](1058-security-detections-as-code.md)).
- **CloudWatch Logs only:** fine on AWS, but does not cover the home site, and costs per GB ingested.
- **Promtail** as the collector: deprecated in favor of Alloy.
- **No central logs (status quo):** rejected; losing logs on every restart is not production-grade.

## Consequences

- Logs survive restarts and deletions, and are searchable alongside metrics and traces in Grafana.
- New alert type: log-based alerts with runbooks.
- Roughly **0.3–0.7 GB** more memory in use on `rl-home-cp01`; retention, label count and dropped noise must be watched.
- Alloy needs a narrow Kyverno `PolicyException` (host paths for log files, a host port for Talos logs).
- Logs may hold personal data (IP addresses, occasionally emails): short retention, masking and restricted Grafana access are required.

## When to revisit

- Memory becomes a blocker (originally `rl-home-cp01`; since [ADR 1020](1020-three-node-ha-home-cluster.md), `rl-home-cp03` hosts Loki): consider VictoriaLogs, or shorter retention.
- Log volume grows enough that Loki's single-binary mode struggles: move to its scalable deployment mode (on AWS) or reduce what is collected.
- A requirement for long-term log retention (for example, an audit): add S3 lifecycle transitions to cheaper storage classes.

## Open items

- Phase 1 step 4.6: record actual memory use and daily log volume after a week.
- Phase 3 step 2.4: confirm the 14-day retention is enough for reviewing demos.
