# Phase 1 roadmap: russetleaf.dev

The milestones for building [Phase 1](plan.md), with target dates, and the actual dates once each is reached. The steps, tiers and estimates come from the plan's [progress checklist](plan.md#progress-checklist); day-to-day work is tracked as GitHub Issues (one per step) grouped into these milestones, on a public GitHub Projects board.

## Assumptions (baseline of 2026-11-13)

This baseline replaces the first one, of 2026-11-02, which planned the foundations for November 3–4 and is kept in Git history (decision log, 2026-11-13). Between the two, step 0.2 was finished, and step 0.1 grew to include the Google Workspace identity, the security keys on every account, and the GitHub organization and GitLab group, which took the time the first baseline gave to the cluster.

- **Start:** building resumes on **Sunday, November 15, 2026**.
- **Pace:** about **60 hours a week**, worked as **10 hours a day, six days a week**, with **Saturdays off**.
- **Holidays:** no work on **Thanksgiving (Thursday, November 26)**, **December 24–25** and **December 31–January 1**.
- **Hardware:** all three servers and the ER605 router are on hand, so the lab network and the cluster start as soon as the plan reaches them.
- **Remaining work:** every unfinished step counts at its full estimate, including those already started (0.1 and 1.1); step 0.2 is done and not counted.
- **Order:** the Core tier first (in plan order), then step 9.3 (the post go-live review of the [improvements list](improvements.md)), then the other Extended steps, then the Advanced steps, as the plan recommends.
- **Estimates:** the plan's focused-hour ranges (expect ±50%). **Target** is the date at the midpoint of the estimates; **latest** is the date at the high end.
- **Not included:** days lost to waiting (AWS approvals, DNS), and the drop in pace that long stretches of 10-hour days usually bring. Plan around the **latest** dates.

## Milestones

| Milestone | Steps | Est. hours | Target | Latest | Actual | Actual hours |
|---|---|---|---|---|---|---|
| **M1 Foundations** | 0.1–0.3, 1.1, 2.0, 2.1 | 24–44 (0.2 done) | Wed, Nov 18, 2026 | Thu, Nov 19, 2026 | | |
| **M2 Cluster up** | 2.2 | 13–19 | Thu, Nov 19, 2026 | Sun, Nov 22, 2026 | | |
| **M3 AWS, GitOps and platform services** | 2.0b, 2.3, 2.4, 3.1, 4.1–4.7 | 62–102 | Tue, Dec 1, 2026 | Fri, Dec 4, 2026 | | |
| **M4 WordPress live with staging and promotion** | 5.1–5.7, 5.10, 5.12 | 56–95 | Wed, Dec 9, 2026 | Tue, Dec 15, 2026 | | |
| **M5 Core tier complete and published** | 6.1, 6.3, 9.2 | 33–49 | Mon, Dec 14, 2026 | Mon, Dec 21, 2026 | | |
| **M6 Production hardening and operations** | 9.3, 2.5, 5.8, 5.9, 5.11, 6.2, 6.4, 6.5, 7.1–7.6, 7.8–7.16, 9.1 | 111–195 | Wed, Jan 6, 2027 | Mon, Jan 18, 2027 | | |
| **M7 Advanced practices; Phase 1 complete** | 7.7, 8.1–8.9 | 89–144 | Tue, Jan 19, 2027 | Wed, Feb 3, 2027 | | |
| **Total remaining** | | **388–648** | | | | |

The whole of Phase 1 is ~389–650 hours, step 0.2's 1–2 included ([plan](plan.md#priorities-and-time-estimates)).

**The first five working days:**

| Day | Work |
|---|---|
| **Sun, Nov 15** | Step 0.1: the YubiKeys on the workstation ([setup guide](setup/workstation-yubikey.md)), the Slack channels, bot and monitoring accounts ([setup guide](setup/slack-and-monitoring.md)), the break-glass kit ([setup guide](setup/break-glass-kit.md)), and `yubikey-backup` into the safe |
| **Mon, Nov 16** | Step 0.3: the ER605 as `rl-home-rt01` ([lab network setup guide](setup/lab-network.md)); step 1.1 begins: the code repos in the organization, with their mirrors |
| **Tue, Nov 17** | Step 1.1 continued: the guardrails (secret scanning, Checkov, Renovate, the bash and documentation checks), the issues and project board |
| **Wed, Nov 18** | Steps 2.0 and 2.1: the AWS Organization, its accounts and IAM Identity Center ([setup guide](setup/aws-management-account.md)), then the OpenTofu state bucket and CI roles |
| **Thu, Nov 19** | Step 2.2 begins: Talos on all three nodes, etcd, the virtual IP, Cilium and Argo CD |

What each milestone shows when it is done:

- **M1:** accounts, tools, budget alert, the lab network with WireGuard access, decisions recorded, the repos, the AWS Organization and accounts, and the OpenTofu state bucket.
- **M2:** the three-node, highly available Talos cluster with Cilium and Argo CD, hardened and tested.
- **M3:** the organization's security services, the home AWS and Cloudflare resources, the OpenTofu pipeline, the repos' CI guardrails, Argo CD managing everything; storage, secrets and certificates, ingress through the tunnel, monitoring and alerting, MariaDB and Valkey, logging, and OIDC sign-in.
- **M4:** russetleaf.dev live on the custom image and theme, with ci tests, on-demand staging, promotion and the privacy basics.
- **M5:** Kyverno and network policies enforced, the docs polished, and the project published as a finished Core tier. **First complete release.**
- **M6:** the post go-live review of the improvements list, progressive delivery, sandboxing, runtime security, security detections as code, mail and identity monitoring, cost and tracing, keyless AWS access, and the rollback, node-failure and disaster drills.
- **M7:** SLOs and error budgets, DORA metrics, Backstage and a second service, the threat model and control matrix, chaos and postmortems, strategy documents, fleet management, and knowledge sharing (engineering write-ups).

## Tracking and reporting

- **Issues:** one per step, created from the plan by `tools/plan_to_issues.py` (see its usage notes), labeled by tier and stage, in the milestone above, with the step's substeps as a checklist and its test as acceptance criteria.
- **Step specs:** before starting a step, write its spec with Claude from [`../specs/TEMPLATE.md`](../specs/TEMPLATE.md); the pull request links the issue and the spec.
- **Actuals:** record actual hours per step in the plan's checklist, and fill in this table's **Actual** columns when a milestone closes.
- **Milestone retro:** when a milestone closes, add a short note to the plan's decision log: estimated vs actual hours, what took longer and why, and what changes for the next milestone.
- **Re-baselining:** if a milestone finishes more than a week late, re-plan the remaining dates here (keep the original baseline in Git history and say so in the decision log) rather than letting the table go stale.
