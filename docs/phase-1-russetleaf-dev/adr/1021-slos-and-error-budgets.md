# ADR 1021: SLOs with error budgets that gate promotions; DORA metrics

- **Status:** Accepted; updated by senior review
- **Date:** 2026-11-01
- **Applies to:** russetleaf.dev (and russetleaf.com during demos)
- **Phase:** 1 (site and API SLOs). Later: Phase 2 adds summary freshness and quality.


> **Update (senior review):** Availability and latency SLIs are measured at the **ingress inside the cluster**, so home internet outages don't burn the error budget (the external uptime check still alerts on them). The error-budget policy has an **exclusion process** for documented external incidents (e.g. ISP or Bedrock outages): an annotation linking the incident record removes that window from the budget calculation.
## Context
Alerting was threshold-based (error spikes, latency, freshness of backups), and promotions to production depended only on CI and staging results. There were no explicit reliability targets, no way to balance shipping changes against reliability, and no measurement of how well delivery works.

## Decision
- Define **SLOs** with SLIs for the site (availability 99.5%, latency 95% under 1 s), the AI summaries (freshness 99% within 15 minutes, quality 95% online-evaluation pass rate) and the home Kubernetes API (99.9%), over 28-day windows.
- Generate recording rules and **multi-window, multi-burn-rate alerts** with **Sloth** from SLO definitions in Git; fast burn pages `#rl-critical`, slow burn tickets the site channel; retire threshold alerts the SLOs replace.
- **Error-budget policy enforced in automation:** when a budget is exhausted, `promote-to-prod` blocks promotions except `fix` or `reliability` changes until it recovers.
- Compute the **DORA metrics** (deployment frequency, lead time, change failure rate, time to restore) from GitHub, Argo CD and incident records, published to Prometheus and Grafana.

## Alternatives considered
- **Pyrra:** similar to Sloth, with a UI; Sloth's plain rule generation fits the GitOps flow with less to run.
- **Grafana's SLO feature (Grafana Cloud):** managed and polished, but a hosted service; the self-hosted stack is the point here.
- **Threshold alerts only:** simple but noisy, and says nothing about whether reliability is good enough to keep shipping.
- **A manual error-budget policy:** easy to ignore; automation makes the policy real.

## Consequences
- Paging becomes based on user impact rather than individual symptoms.
- Shipping slows automatically when reliability suffers, which is the intended trade-off.
- SLO targets need tuning in the first months (too strict blocks everything; too loose means nothing).
- DORA trends become visible and reviewable.

## When to revisit
- The targets prove unrealistic for home hardware (power and internet outages count against availability).
- More services join the platform: SLOs become part of the golden-path template.

## Open items
- Phase 1 step 8.1: SLO definitions, Sloth rules, dashboards, the promotion gate; tune targets after the first month.
- Phase 1 step 8.2: the DORA workflow and dashboard.
