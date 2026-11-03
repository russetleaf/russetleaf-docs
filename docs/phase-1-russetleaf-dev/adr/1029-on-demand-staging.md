# ADR 1029: On-demand, scale-to-zero staging on the home cluster

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** russetleaf.dev (staging for both sites' application versions)
- **Phase:** 1. Later: Phase 2 adds the summarizer to staging.

## Context

Every release needs testing against real AWS services, real models and realistic data before production. Options range from no staging, to an always-on copy, to a separate cluster. The home cluster's memory was tight when staging was designed (two 8 GB nodes); with [ADR 1020](1020-three-node-ha-home-cluster.md)'s third node it could now afford an always-on copy.

## Decision

- **Staging exists only while it is being tested:** Argo CD Applications for staging (WordPress, a small MariaDB, the summarizer) are in Git with **auto-sync off**; the `staging-test` workflow syncs them, loads **scrubbed** production data, runs smoke tests, the performance regression gate and a short soak, records the results, then **deletes** them (volumes included).
- Staging has its own namespaces, database, bucket, queue, secrets and Bedrock budget; it shares the gateway and the self-hosted model.
- AWS has no separate staging: russetleaf.com's versions are tested at home first.

## Alternatives considered

- **Always-on staging:** faster to test against and closer to production over time, but uses memory continuously and drifts from production data; the three-node cluster could now afford it, but on-demand staging also demonstrates an ephemeral-environment pattern and starts fresh each time.
- **A separate staging cluster:** strongest isolation, but needs more hardware.
- **Preview environments per pull request:** excellent for teams; too heavy for this cluster, and the ci kind clusters cover per-pull-request integration tests.
- **No staging (ci only):** cheaper, but nothing tests real AWS services, real models and real data before production.

## Consequences

- No standing memory cost; each test starts from a clean, recent, scrubbed copy of production.
- Each promotion takes longer (create, load data, test, soak, delete).
- Platform components are shared with production, so platform upgrades cannot be staged this way ([ADR 1011](1011-update-strategy.md)'s local rehearsal covers them).

## When to revisit

- Promotions become frequent enough that setup time matters: keep staging always on.
- More hardware: a separate staging cluster for platform upgrades.

## Open items

- Phase 1 steps 5.6 and 5.7.
