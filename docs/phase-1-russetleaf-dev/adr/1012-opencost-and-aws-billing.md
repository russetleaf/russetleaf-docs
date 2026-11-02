# ADR 1012: OpenCost for in-cluster allocation, AWS billing for actual costs, and how cost alerts flow

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** both sites and the AWS account
- **Phase:** 1 (OpenCost at home, AWS Budgets, anomaly detection). Later: Phase 2 adds Bedrock spend and cost per summary; Phase 3 adds the per-demo cost report, the GPU-node alert and the demo safety net.

## Context
The design used OpenCost on both clusters (with Kubecost as an optional alternative on EKS) and AWS Budgets and Cost Anomaly Detection for the account, but:
- OpenCost has **no alerting** of its own, and nothing produced the "weekly OpenCost summary" listed for `#rl-costs`.
- OpenCost estimates costs from **list prices**, not the actual bill, and on EKS its data is **lost at every `demo-down`**, since it lives in the demo cluster's Prometheus.
- The AWS side and the cluster side weren't connected: nothing compared estimated demo costs with what AWS actually charged.
- The project's tags (`Project`, `Site`, `Env`, `Stack`) weren't **activated as cost allocation tags**, so Budgets and Cost Explorer couldn't filter by them.

## Decision
- **OpenCost on both sites** for allocation (per namespace, workload and node), using each cluster's Prometheus.
- **AWS billing** (Budgets, Cost Anomaly Detection, Cost Explorer) as the source of truth for **actual** costs.
- **Alerts to `#rl-costs`:**
  - AWS Budgets, Cost Anomaly Detection and the Bedrock budget, through SNS and Amazon Q Developer
  - the demo safety-net workflow (also `#rl-critical`)
  - OpenCost-based Prometheus alerts, routed by Alertmanager like all other alerts: `GPUNodeRunningLong` (EKS) and `NamespaceDailyCostSpike` (both)
- **Reports:**
  - a **weekly OpenCost allocation summary** for the home cluster, from a scheduled workflow on the in-cluster runners
  - a **per-demo actual-cost report** from **Cost Explorer** (grouped by `Site` and `Stack`), run daily because of Cost Explorer's ~24-hour lag, comparing actual cost per demo hour with the ~$1/hour estimate
- **Activate the cost allocation tags** with Terraform (`aws_ce_cost_allocation_tag`) in `russetleaf-infra/bootstrap/`.

## Alternatives considered
- **Kubecost (free tier or the EKS bundle):** adds billing reconciliation and built-in budget alerts, but runs more components (memory box 1 can't spare) and would differ between sites; the Cost Explorer report covers reconciliation more simply.
- **AWS billing only:** exact, but can't show which workload in a cluster drives cost, and doesn't cover the home cluster's hardware.
- **OpenCost only:** shows allocation but not the actual bill, and misses everything outside Kubernetes (NAT Gateways, RDS, S3, Bedrock).
- **Long-term storage for EKS OpenCost data** (e.g. remote-writing Prometheus to the home cluster or a managed service): keeps per-demo allocation history, but adds plumbing for a cluster that runs a few hours at a time; the Cost Explorer report keeps the important number (actual cost per demo).

## Consequences
- Every cost signal ends up in `#rl-costs`, whether it comes from AWS or the clusters.
- Estimates and actual costs are compared after every demo, so the cost tables in the Phase 1 design stay honest.
- Per-workload allocation history on EKS isn't kept between demos; only the actual totals are.
- Cost Explorer API calls cost about $0.01 each; a daily report costs pennies a month.

## When to revisit
- russetleaf.com becomes always-on: keep OpenCost data continuously and consider Kubecost's billing reconciliation.
- More memory at home: Kubecost becomes affordable if its extra features are wanted.
- Costs grow enough to justify a dedicated FinOps tool.

## Open items
- Phase 1 step 2.1: activate the cost allocation tags (they must already exist on a resource).
- Phase 1 step 7.3: OpenCost alerts and the weekly summary workflow.
- Phase 3 step 5.2: the per-demo Cost Explorer report; record actual cost per demo hour.
