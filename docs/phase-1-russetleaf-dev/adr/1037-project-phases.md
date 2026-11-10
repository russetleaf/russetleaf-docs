# ADR 1037: Build the project in three phases

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** the whole project and its documents
- **Phase:** all (recorded in Phase 1)

## Context

The project had grown to two sites and one design document: russetleaf.dev at home and aws.russetleaf.dev on EKS, with AI post summaries and an MLOps lifecycle running through both. Effort was estimated at roughly 525–875 focused hours. Built in one go, that is a year or more of evenings with nothing finished in between, and much of it (the EKS demo stack, GPU fine-tuning) adds less to the core platform than the time it takes. The home lab alone already shows most of the platform work: infrastructure as code, GitOps, security, observability, delivery and operations.

## Decision

Build in **three phases**, each complete and usable on its own, with its own design, build plan and decisions:

| Phase | Builds | Needs |
|---|---|---|
| **1. russetleaf.dev** | WordPress on the three-node Talos cluster at home, with the AWS Organization it uses, GitOps, platform services, security, observability, staging and promotion, DR, and the Advanced-tier practices | — |
| **2. AI summaries and MLOps** | The summary pipeline (SQS, KEDA, LiteLLM, Bedrock, the self-hosted model on `rl-home-cp02`), the evaluation gate, MLflow, guardrails, online evaluation, drift, feedback and DVC | Phase 1 |
| **3. aws.russetleaf.dev** | The EKS demo site (Karpenter, RDS with RDS Proxy, ElastiCache, CloudFront, ALB, WAF, the always-on edge) | Phase 1 |

- **Documents:** the [overview](../../overview.md) holds what is shared (the phases, how the two sites compare, security views, effort, repositories, the ADR index); each phase has a folder with `design.md`, `plan.md` and `adr/`.
- **ADR numbers start with the phase:** Phase 1's decisions are numbered 1001 upwards, Phase 2's 2001 upwards and Phase 3's 3001 upwards, so each phase's set is contiguous and complete on its own, and a number shows its phase at a glance. Numbers are unique across the project and do not change once used. Each ADR lives in the `adr/` folder of the phase that first implements it. (The ADRs were renumbered into this scheme on 2026-11-02, before any were published; earlier commits use the old 0001–0048 numbers.) Where a decision has a substantial later-phase part, that part is a separate ADR in the later phase (3002–3005); smaller later-phase parts are noted in the ADR's **Phase** line.
- **Plans group steps into stages** ("Phase" always means one of the three project phases); step references across phases name the phase ("Phase 1 step 4.6").
- **Phase 1 stands alone:** nothing in it waits for AI or EKS. `rl-home-cp02` is an ordinary third node until Phase 2; fleet management uses a local spoke cluster until Phase 3; the capacity plan uses home load tests until Phase 3.

## Alternatives considered

- **One plan, tiers only (Core, Extended, Advanced):** tiers rank steps by value, but the AI and EKS work was interleaved through every stage, so no subset was complete without the rest.
- **Two phases (home with AI, then EKS):** keeps the AI pipeline in the first build, but delays a finished site by a few months, and the AI work is the part furthest from the platform's core.
- **Separate documents per site:** duplicates the shared platform design, which is most of it.

## Consequences

- A complete, publishable project after Phase 1 (about 375–626 hours, or 183–301 for its Core tier).
- Phases 2 and 3 can be skipped, reordered or done years apart without leaving half-built work.
- Some integration work is repeated per phase (policies, network rules, monitoring for new components), adding roughly 15–25 hours overall.
- Phase 1's design mentions later phases only in short notes; the details live in their own design documents.

## When to revisit

- A job target makes one later phase more valuable (for example, MLOps roles: do Phase 2 next; cloud platform roles: Phase 3).
- A phase turns out too large to finish: split it further rather than leaving it half done.

## Open items

- ~~Phase 1 step 1.1: move the `docs/` tree into `russetleaf-gitops`~~: the docs stay in their own repo ([ADR 1038](1038-documentation-repo-and-site.md)).
