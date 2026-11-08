# ADR 1012: OpenCost for in-cluster allocation, AWS billing for actual costs, and how cost alerts flow

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** both sites and the AWS account
- **Phase:** 1 (OpenCost at home, AWS Budgets, anomaly detection). Later: Phase 2 adds Bedrock spend and cost per summary; Phase 3 adds the per-demo cost report and the demo safety net.

## Context

The design used OpenCost on both clusters (with Kubecost as an optional alternative on EKS) and AWS Budgets and Cost Anomaly Detection for the account, but:

- OpenCost has **no alerting** of its own, and nothing produced the "weekly OpenCost summary" listed for `#rl-costs`.
- OpenCost estimates costs from **list prices**, not the actual bill, and on EKS its data is **lost at every `demo-down`**, since it lives in the demo cluster's Prometheus.
- The AWS side and the cluster side were not connected: nothing compared estimated demo costs with what AWS actually charged.
- The project's tags (`Project`, `Site`, `Env`, `Stack`) were not **activated as cost allocation tags**, so Budgets and Cost Explorer could not filter by them.

## Decision

- **OpenCost on both sites** for allocation (per namespace, workload and node), using each cluster's Prometheus.
- **AWS billing** (Budgets, Cost Anomaly Detection, Cost Explorer) as the source of truth for **actual** costs.
- **Alerts to `#rl-costs`:**
    - AWS Budgets, Cost Anomaly Detection and the Bedrock budget, through SNS and Amazon Q Developer
    - the demo safety-net workflow (also `#rl-critical`)
    - OpenCost-based Prometheus alerts, routed by Alertmanager like all other alerts: `NamespaceDailyCostSpike` (both sites)
- **Reports:**
    - a **weekly OpenCost allocation summary** for the home cluster, from a scheduled workflow on the in-cluster runners
    - a **per-demo actual-cost report** from **Cost Explorer** (grouped by `Site` and `Stack`), run daily because of Cost Explorer's ~24-hour lag, comparing actual cost per demo hour with the ~$0.70/hour estimate
- **Activate the cost allocation tags** with OpenTofu (`aws_ce_cost_allocation_tag`) in `russetleaf-infra/envs/org/`, in the management account (where they apply organization-wide).

## Alternatives considered

- **Kubecost (free tier or the EKS bundle):** adds billing reconciliation and built-in budget alerts, but runs more components (memory `rl-home-cp01` cannot spare) and would differ between sites; the Cost Explorer report covers reconciliation more simply.
- **AWS billing only:** exact, but cannot show which workload in a cluster drives cost, and does not cover the home cluster's hardware.
- **OpenCost only:** shows allocation but not the actual bill, and misses everything outside Kubernetes (NAT Gateways, RDS, S3, Bedrock).
- **Long-term storage for EKS OpenCost data** (for example, remote-writing Prometheus to the home cluster or a managed service): keeps per-demo allocation history, but adds plumbing for a cluster that runs a few hours at a time; the Cost Explorer report keeps the important number (actual cost per demo).

## Consequences

- Every cost signal ends up in `#rl-costs`, whether it comes from AWS or the clusters.
- Estimates and actual costs are compared after every demo, so the cost tables in the Phase 1 design stay honest.
- Per-workload allocation history on EKS is not kept between demos; only the actual totals are.
- Cost Explorer API calls cost about $0.01 each; a daily report costs pennies a month.

## When to revisit

- russetleaf.com becomes always-on: keep OpenCost data continuously and consider Kubecost's billing reconciliation.
- More memory at home: Kubecost becomes affordable if its extra features are wanted.
- Costs grow enough to justify a dedicated FinOps tool.

## Open items

- Phase 1 step 2.0: activate the cost allocation tags (they must already exist on a resource).
- Phase 1 step 7.3: OpenCost alerts and the weekly summary workflow.
- Phase 3 step 4.2: the per-demo Cost Explorer report; record actual cost per demo hour.
