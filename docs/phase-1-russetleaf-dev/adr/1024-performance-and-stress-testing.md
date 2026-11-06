# ADR 1024: Performance and stress testing with k6, and a performance regression gate

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** both sites and the AI pipeline
- **Phase:** 1 (load, stress, spike, soak, the regression gate, a capacity estimate). Later: Phase 2 adds the AI burst test; Phase 3 measures EKS for the capacity plan.

## Context

Load tests appeared only in passing (the gVisor comparison, light load during node-failure drills, and capacity tests on EKS). Nothing found **where and how** the sites break, tested sudden surges or long-running load, measured the AI pipeline's capacity under a burst of posts, or stopped a slower release from being promoted. Load from a single source would also be rate-limited or blocked by the Cloudflare and AWS WAF rules, and home tests would be limited by the home internet connection.

## Decision

- Six test types: **smoke, load, stress/breakpoint, spike, soak** and an **AI pipeline burst**, with defined places to run them (staging, quiet production windows, EKS during demos).
- **k6** scripts in `russetleaf-gitops/perf/` with thresholds in code; the **k6 Operator** for distributed, in-cluster tests against the ingress; results to Prometheus and Grafana; summaries in `docs/performance/`.
- **Edge tests** through Cloudflare or CloudFront only with a narrow, temporary WAF allow rule applied by OpenTofu.
- A **performance regression gate** in `staging-test`: the **current production version and the candidate are load-tested back to back in staging** (same hardware, same conditions, minutes apart), each **three times**, comparing **medians**; more than about 20% slower, or over the error threshold, fails promotion. The gate **waits** while `rl-home-cp02` is busy with a summarization burst or a stress test is running, so shared-cluster load does not cause false failures.
- Results feed the SLO targets, the capacity and cost plan, KEDA limits and Bedrock budget thresholds.

## Alternatives considered

- **Locust, Gatling or JMeter:** capable tools; k6 is lighter, scriptable in JavaScript, has a Kubernetes operator and native Prometheus output, and fits the existing Grafana stack.
- **Grafana Cloud k6 or other hosted load testing:** easy to scale and run from many regions, but a paid hosted service; in-cluster tests cover these sites' needs.
- **Testing only through the edge from a workstation:** realistic, but limited by home bandwidth and blocked by the WAFs; used only for deliberate edge tests.
- **No regression gate:** simpler, but lets performance degrade release by release unnoticed.
- **Comparing staging results with a stored production baseline:** simpler, but noisy on a shared three-node cluster (LLM work on `rl-home-cp02` and monitoring on `rl-home-cp03` vary over time); back-to-back runs in the same conditions are more reliable.

## Consequences

- The breaking points, bottlenecks and recovery behavior of both sites and the AI pipeline are known and documented.
- Promotions take a few minutes longer (the short load test).
- Stress and soak tests use the home cluster heavily for a while; run them at quiet times, in staging where possible.
- Temporary WAF exceptions must be removed reliably after edge tests (applied and removed by OpenTofu).

## When to revisit

- Traffic grows enough that in-cluster tests cannot generate realistic load: use a hosted, multi-region load-testing service.
- The regression threshold proves too noisy: widen it or compare medians over several runs.

## Open items

- Phase 1 step 5.9: k6 Operator, scripts, the baseline and the regression gate.
- Phase 2 step 2.6: the AI pipeline burst test.
- Phase 1 step 7.12: stress, spike and soak tests at home.
- Phase 3 step 5.4: stress, spike and burst tests on EKS.
