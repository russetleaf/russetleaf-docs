# Phase 1 roadmap: russetleaf.dev

The milestones for building [Phase 1](plan.md), with target dates, and the actual dates once each is reached. The steps, tiers and estimates come from the plan's [progress checklist](plan.md#progress-checklist); day-to-day work is tracked as GitHub Issues (one per step) grouped into these milestones, on a public GitHub Projects board.

## Assumptions (baseline of 2026-11-02)

- **Start:** Monday, November 2, 2026.
- **Pace:** about **60 hours a week**, worked as **10 hours a day, six days a week**, with **Saturdays off**.
- **Order:** the Core tier first (in plan order), then the Differentiators, then the Staff and Stretch steps, as the plan recommends.
- **Estimates:** the plan's focused-hour ranges (expect ±50%). **Target** is the date at the midpoint of the estimates; **latest** is the date at the high end.
- **Not included:** holidays (Thanksgiving, late December), days lost to waiting (box 3's delivery, AWS approvals, DNS), and the drop in pace that long stretches of 10-hour days usually bring. Plan around the **latest** dates.

## Milestones

| Milestone | Steps | Est. hours | Target | Latest | Actual | Actual hours |
|---|---|---|---|---|---|---|
| **M1 Foundations** | 0.1–1.1 | 11–21 | Tue, Nov 3, 2026 | Wed, Nov 4, 2026 | | |
| **M2 Cluster and AWS foundations** | 2.0–2.4 | 36–57 | Mon, Nov 9, 2026 | Tue, Nov 10, 2026 | | |
| **M3 GitOps and platform services** | 3.1–4.7 | 41–67 | Sun, Nov 15, 2026 | Wed, Nov 18, 2026 | | |
| **M4 WordPress live with staging and promotion** | 5.1–5.7, 5.10, 5.12 | 54–91 | Mon, Nov 23, 2026 | Sun, Nov 29, 2026 | | |
| **M5 Core tier complete and published** | 6.1, 6.3, 9.2 | 27–39 | Fri, Nov 27, 2026 | Thu, Dec 3, 2026 | | |
| **M6 Senior tier: operations evidence** | 2.5, 5.8, 5.9, 5.11, 6.2, 6.4, 6.5, 7.1–7.6, 7.8–7.12, 9.1 | 72–127 | Wed, Dec 9, 2026 | Fri, Dec 18, 2026 | | |
| **M7 Staff tier and Phase 1 complete** | 7.7, 8.1–8.9 | 89–144 | Tue, Dec 22, 2026 | Mon, Jan 4, 2027 | | |
| **Total** | | **330–546** | | | | |

What each milestone shows when it's done:

- **M1:** accounts, tools, budget alert, network segmentation, decisions recorded, the repos public with their CI guardrails.
- **M2:** the AWS Organization with its security services, the three-node Talos cluster with Cilium, the home AWS and Cloudflare resources, and the Terraform pipeline.
- **M3:** Argo CD managing everything; storage, secrets and certificates, ingress through the tunnel, monitoring and alerting, MariaDB and Valkey, logging, and OIDC sign-in.
- **M4:** russetleaf.dev live on the custom image and theme, with ci tests, on-demand staging, promotion and the privacy basics.
- **M5:** Kyverno and network policies enforced, the docs polished, and the project published as a finished Core tier. **First portfolio milestone.**
- **M6:** progressive delivery, sandboxing, runtime security, cost and tracing, keyless AWS access, and the rollback, node-failure and disaster drills.
- **M7:** SLOs and error budgets, DORA metrics, Backstage and a second service, the threat model and control matrix, chaos and postmortems, strategy documents, fleet management, and public writing.

## Tracking and reporting

- **Issues:** one per step, created from the plan by `tools/plan_to_issues.py` (see its usage notes), labeled by tier and stage, in the milestone above, with the step's substeps as a checklist and its test as acceptance criteria.
- **Step specs:** before starting a step, write its spec with Claude from [`../specs/TEMPLATE.md`](../specs/TEMPLATE.md); the pull request links the issue and the spec.
- **Actuals:** record actual hours per step in the plan's checklist, and fill in this table's **Actual** columns when a milestone closes.
- **Milestone retro:** when a milestone closes, add a short note to the plan's decision log: estimated vs actual hours, what took longer and why, and what changes for the next milestone.
- **Re-baselining:** if a milestone finishes more than a week late, re-plan the remaining dates here (keep the original baseline in Git history and say so in the decision log) rather than letting the table go stale.
