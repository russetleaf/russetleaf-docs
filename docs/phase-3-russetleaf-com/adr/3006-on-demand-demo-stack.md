# ADR 3006: russetleaf.com as an on-demand demo stack behind an always-on edge

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** russetleaf.com, `russetleaf-infra/envs/aws-edge` and `envs/aws`, the demo workflows
- **Phase:** 3

## Context

The full AWS design (EKS, RDS Multi-AZ with RDS Proxy, ElastiCache, NAT Gateways, ALB, WAF) costs roughly $515–575 a month if left running: far too much for a portfolio site. But russetleaf.com should still answer when the stack is down, and bringing it up should be one command, not an afternoon.

## Decision

- **Two Terraform root modules:** `envs/aws-edge` (**always on**, about $1/month: the Route 53 zone, ACM certificates, the CloudFront distribution, the offline-page bucket, the media bucket, the log and trace buckets, the RDS final snapshot) and `envs/aws` (the **demo stack**: VPC, EKS, Karpenter, RDS, ElastiCache, WAF, queues).
- **CloudFront's error fallback** serves the **offline page** (status 503, pointing to russetleaf.dev) whenever the origin is unreachable, with short error caching and a 2-second origin timeout, so the switch between live and offline needs no DNS changes.
- **`demo-up` and `demo-down` workflows** (GitHub Actions on the home ARC runners): apply, wait for Argo CD and the site, run kube-bench, register with the Argo CD hub; and the reverse, with a final RDS snapshot and an Alertmanager silence. A **safety-net workflow** alerts when the stack has been up longer than its limit.
- **Content between demos:** a final snapshot on destroy restored on the next `demo-up`; media lives in the always-on edge; an optional seed from russetleaf.dev's backups.
- **Cost guardrails:** the russetleaf-com account's budgets and anomaly detection, a per-demo cost report, and about $0.70 per demo hour.

## Alternatives considered

- **Always on:** the real production pattern, but about $515–575 a month.
- **Route 53 failover routing** to the offline page: works, but needs health checks and DNS TTL waits; CloudFront's error fallback is instant and free.
- **No AWS site; Terraform only (plan, Checkov and Infracost in CI, never applied):** costs nothing and still shows the design as reviewed code, but no live demo; a good interim step if Phase 3 is postponed.
- **A smaller always-on AWS stack** (e.g. a single small EKS node and no RDS): cheaper, but no longer the production design it is meant to show.

## Consequences

- russetleaf.com always answers; the full design costs about $0.70 an hour only while demoing.
- The demo workflows become the most exercised Terraform paths, so drift and teardown problems surface quickly.
- Anything stored only in the demo stack (Prometheus data, OpenCost data) is lost at `demo-down`; durable data goes to the always-on buckets.

## When to revisit

- russetleaf.com needs to be always on, or to hold user data: move the full WAF rule set to CloudFront (the Pro plan; [ADR 3009](3009-edge-waf-on-cloudfront-free-plan.md)), consider a warm standby, and revisit [ADR 1018](../../phase-1-russetleaf-dev/adr/1018-disaster-recovery.md)'s AWS items.

## Open items

- Phase 3 step 1.2: the always-on edge; step 5.1: the demo workflows and safety net; step 4.2: the cost review.
