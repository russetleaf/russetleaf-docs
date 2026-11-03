# ADR 1023: Reliability practice: scheduled chaos experiments and blameless postmortems

- **Status:** Accepted; updated by [ADR 1046](1046-incident-response-and-runbook-index.md)
- **Date:** 2026-11-01
- **Applies to:** russetleaf.dev (and russetleaf.com during demos)
- **Phase:** 1. Later: Phase 2 adds latency injected into model calls.

> **Update ([ADR 1046](1046-incident-response-and-runbook-index.md)):** incidents now have **severity levels** (SEV1–3) and an incident thread in `#rl-critical` as the timeline; a postmortem is required for every **SEV1 and SEV2**, and incident tabletop exercises run twice a year.

## Context

The design had rollback, node-failure and disaster drills, but no regular, hypothesis-driven testing of failure modes inside the running system, and no standard way of learning from incidents.

## Decision

- **Chaos Mesh** for scheduled experiments, each with a written hypothesis, expected outcome, blast radius and abort condition: kill the MariaDB primary; add latency to model calls; kill a WordPress pod mid-canary; fill a node's disk; partition `rl-home-cp02` from the others. Run in staging first, then in production at quiet times, with results in `docs/chaos/`. **Latency to Bedrock** is injected at the **LLM gateway** (a Toxiproxy sidecar in front of the gateway's upstream calls, or the gateway's own fault-injection setting) rather than with Chaos Mesh's network rules: Chaos Mesh can delay traffic to external hosts, but targeting AWS endpoints by name is unreliable because their IP addresses change.
- **Blameless postmortems** from a template (summary, impact, timeline, root causes, what went well, action items with owners and dates) for every real incident and notable drill, in `docs/postmortems/`; at least two from the build.
- **SLO-based paging** ([ADR 1021](1021-slos-and-error-budgets.md)), and every page links a runbook.

## Alternatives considered

- **LitmusChaos:** similar capabilities with a larger footprint (its control plane and database); Chaos Mesh is lighter and integrates well with Kubernetes and Grafana.
- **AWS Fault Injection Service:** AWS-only; useful on EKS for spot interruptions (already used there), but does not cover the home cluster.
- **Ad-hoc drills only:** less systematic, and easy to skip.

## Consequences

- Failure modes are tested regularly, with written expectations and outcomes.
- Incidents produce improvements rather than just fixes.
- Chaos in production carries some risk; experiments have abort conditions and start in staging.

## When to revisit

- Experiments become routine and stable: automate them as part of releases (e.g. a chaos stage before promotion).

## Open items

- Phase 1 step 8.6: Chaos Mesh, the first experiments, the postmortem template and the first two postmortems.
