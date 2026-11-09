# Phase 1 roadmap: russetleaf.dev

The milestones for building [Phase 1](plan.md), with target dates, and the actual dates once each is reached. The steps, tiers and estimates come from the plan's [progress checklist](plan.md#progress-checklist); day-to-day work is tracked as GitHub Issues (one per step) grouped into these milestones, on a public GitHub Projects board.

## Assumptions (baseline of 2026-11-02)

- **Start:** planning on Monday, November 2, 2026; building from **Tuesday, November 3**.
- **Pace:** about **60 hours a week**, worked as **10 hours a day, six days a week**, with **Saturdays off**.
- **Fixed dates:** `rl-home-cp03` (the 16 GB server) and the ER605 lab router arrive by November 4, so **November 3–4** are for the preliminaries the servers need (accounts and tools, decisions, the lab network, the repos, the AWS accounts and the OpenTofu state bucket), and **November 5–6** are for the servers: the cluster up on November 5, hardening and tests on November 6.
- **Time-boxing M1:** its steps are estimated at 21–39 hours against 20 available, so only what the servers need is done on November 3–4; the rest (the repos' full CI guardrails, from step 1.1) is finished after November 6 and counted in M3's dates.
- **Order after that:** the Core tier first (in plan order), then step 9.3 (the post go-live review of the [improvements list](improvements.md)), then the other Extended steps, then the Advanced steps, as the plan recommends.
- **Estimates:** the plan's focused-hour ranges (expect ±50%). **Target** is the date at the midpoint of the estimates; **latest** is the date at the high end.
- **Not included:** holidays (Thanksgiving, late December), days lost to waiting (AWS approvals, DNS), and the drop in pace that long stretches of 10-hour days usually bring. Plan around the **latest** dates.

## Milestones

| Milestone | Steps | Est. hours | Target | Latest | Actual | Actual hours |
|---|---|---|---|---|---|---|
| **M1 Foundations** | 0.1–0.3, 1.1, 2.0, 2.1 | 21–39 | Wed, Nov 4, 2026 | Wed, Nov 4, 2026 | | |
| **M2 Cluster up** | 2.2 | 13–19 | Fri, Nov 6, 2026 | Fri, Nov 6, 2026 | | |
| **M3 AWS, GitOps and platform services** | 2.0b, 2.3, 2.4, 3.1, 4.1–4.7 | 64–105 | Wed, Nov 18, 2026 | Sun, Nov 22, 2026 | | |
| **M4 WordPress live with staging and promotion** | 5.1–5.7, 5.10, 5.12 | 56–95 | Thu, Nov 26, 2026 | Wed, Dec 2, 2026 | | |
| **M5 Core tier complete and published** | 6.1, 6.3, 9.2 | 27–39 | Tue, Dec 1, 2026 | Mon, Dec 7, 2026 | | |
| **M6 Production hardening and operations** | 9.3, 2.5, 5.8, 5.9, 5.11, 6.2, 6.4, 6.5, 7.1–7.6, 7.8–7.15, 9.1 | 103–181 | Thu, Dec 17, 2026 | Mon, Dec 28, 2026 | | |
| **M7 Advanced practices; Phase 1 complete** | 7.7, 8.1–8.9 | 89–144 | Thu, Dec 31, 2026 | Thu, Jan 14, 2027 | | |
| **Total** | | **373–622** | | | | |

**The first four days:**

| Day | Work |
|---|---|
| **Tue, Nov 3** | Step 0.1 (accounts, tools, budget alert, the break-glass kit started), 0.2 (decisions), and the ER605 set up as `rl-home-rt01` (0.3: lab subnet, address reservations under the nodes' hostnames, firewall rule, WireGuard to the workstation) |
| **Wed, Nov 4** | Step 1.1 (repos created with branch protection; full CI guardrails later), 2.0 (AWS Organization and accounts) and 2.1 (OpenTofu state bucket and CI roles); `rl-home-cp03` arrives: BIOS, TPM and Secure Boot settings on all three nodes, hostname labels on the machines, and the Talos image schematic |
| **Thu, Nov 5** | Step 2.2, day 1: Talos on all three nodes with their hostnames (`rl-home-cp01` to `rl-home-cp03`), etcd healthy, the virtual IP, Cilium and Argo CD from the inline manifests |
| **Fri, Nov 6** | Step 2.2, day 2: Secure Boot and disk-encryption checks, firewall, kubelet settings, the remaining tests, and the rebuild from scratch |

What each milestone shows when it is done:

- **M1:** accounts, tools, budget alert, the lab network with WireGuard access, decisions recorded, the repos, the AWS Organization and accounts, and the OpenTofu state bucket.
- **M2:** the three-node, highly available Talos cluster with Cilium and Argo CD, hardened and tested.
- **M3:** the organization's security services, the home AWS and Cloudflare resources, russetleaf.com's registration and DNS moved into the Organization, the OpenTofu pipeline, the repos' CI guardrails, Argo CD managing everything; storage, secrets and certificates, ingress through the tunnel, monitoring and alerting, MariaDB and Valkey, logging, and OIDC sign-in.
- **M4:** russetleaf.dev live on the custom image and theme, with ci tests, on-demand staging, promotion and the privacy basics.
- **M5:** Kyverno and network policies enforced, the docs polished, and the project published as a finished Core tier. **First complete release.**
- **M6:** the post go-live review of the improvements list, progressive delivery, sandboxing, runtime security, security detections as code, cost and tracing, keyless AWS access, and the rollback, node-failure and disaster drills.
- **M7:** SLOs and error budgets, DORA metrics, Backstage and a second service, the threat model and control matrix, chaos and postmortems, strategy documents, fleet management, and knowledge sharing (engineering write-ups).

## Tracking and reporting

- **Issues:** one per step, created from the plan by `tools/plan_to_issues.py` (see its usage notes), labeled by tier and stage, in the milestone above, with the step's substeps as a checklist and its test as acceptance criteria.
- **Step specs:** before starting a step, write its spec with Claude from [`../specs/TEMPLATE.md`](../specs/TEMPLATE.md); the pull request links the issue and the spec.
- **Actuals:** record actual hours per step in the plan's checklist, and fill in this table's **Actual** columns when a milestone closes.
- **Milestone retro:** when a milestone closes, add a short note to the plan's decision log: estimated vs actual hours, what took longer and why, and what changes for the next milestone.
- **Re-baselining:** if a milestone finishes more than a week late, re-plan the remaining dates here (keep the original baseline in Git history and say so in the decision log) rather than letting the table go stale.
