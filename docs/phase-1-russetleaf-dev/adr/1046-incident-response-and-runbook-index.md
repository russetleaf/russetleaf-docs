# ADR 1046: Incident response, incident runbooks and one runbook index

- **Status:** Accepted
- **Date:** 2026-11-03
- **Applies to:** both sites
- **Phase:** 1 (the process, the index and most runbooks). Later: Phase 2 adds its credentials to the leak runbook; Phase 3 adds the AWS WAF steps and the stuck-teardown runbook.

## Context

The project plans runbooks for **changes and losses**: one per alert, a rollback runbook per layer ([ADR 1016](1016-rollback-strategy.md)), the [disaster recovery plan](../disaster-recovery.md), CA rotation ([ADR 1035](1035-platform-security.md)), the privacy runbooks ([ADR 1036](1036-compliance-frameworks-and-privacy.md)) and the compromised-container runbook ([ADR 1045](1045-container-forensics.md)). A review of the plans found gaps on the **incident** side, where something is actively wrong and the normal path (Git, then Argo CD) is unavailable or not enough:

- **No incident process:** no severity levels, no rule for when an incident is declared, no timeline, and nothing that coordinates the hand-offs to the breach runbook, forensics and postmortems ([ADR 1023](1023-reliability-practice.md)).
- **Credential leaks:** the repos are public, and the home cluster holds scoped long-lived AWS keys until Phase 1 step 9.1. The disaster recovery plan covers a whole account being compromised, not one credential leaking.
- **Control-plane recovery:** etcd quorum loss and node replacement are one sentence in the disaster recovery plan, although they are the riskiest recoveries on the home lab.
- **WordPress:** the 48-hour target for security fixes ([ADR 1011](1011-update-strategy.md)) does not say what to do when a vulnerability is exploited and **no fix exists yet**, and a compromise that lives in the **database** (a rogue admin, injected content) is not a container problem.
- **Power:** there is no UPS ([ADR 1014](1014-availability-levels.md)), and the node-failure drills only ever take one node down. A power cut takes all three down at once, including both MariaDB members.
- **GitOps down:** the only rollback mechanism is a Git revert. With GitHub down or Argo CD broken, there is no sanctioned way to change the cluster, and self-heal would revert a manual change anyway.
- **Lost access:** if Dex, Google or Cloudflare Access fails, kubectl, Grafana and Argo CD are lost together. The break-glass **alert** has a runbook; **using** break-glass does not.
- **Smaller gaps:** the Talos and Kubernetes upgrade procedure exists only as a table row; nothing covers a compromised CI pipeline or signing identity, a stuck demo teardown, Terraform state problems, or a bot flood.
- **No index:** runbooks are written in about fifteen plan steps across three phases, live in `russetleaf-gitops`, and are listed nowhere, so neither the operator nor a reviewer can see what exists, what is missing, or when each was last rehearsed.

## Decision

**An incident process** (`incident-response.md`), short enough for one operator:

| Severity | Meaning | Examples | Response |
|---|---|---|---|
| **SEV1** | The site is down, data is at risk, or a security incident is confirmed | Uptime check failing; a confirmed compromise; personal data exposed; a credential leaked | Act now; post updates in the incident thread at least every 30 minutes; postmortem required |
| **SEV2** | Degraded, redundancy lost, or a security signal that needs investigating | One node down; a Falco allow-list alert; a high GuardDuty finding; backups failing | Act the same day; postmortem required |
| **SEV3** | No user impact | A warning alert; a failed scheduled scan | Fix in normal work; no postmortem |

- **Declaring:** a critical alert, or the operator's judgment, opens an incident with a message in `#rl-critical` (SEV1 and SEV2) stating the severity, what is known, and the runbook being followed. That message's **thread is the timeline**: every command, finding and decision is posted there as it happens, and becomes the postmortem's timeline.
- **Order of work:** stabilize, then preserve evidence (for security incidents, before anything is deleted; [ADR 1045](1045-container-forensics.md)), then recover, then hand off (the breach runbook's 72-hour clock, credential rotation, the postmortem).
- **Postmortems** from [ADR 1023](1023-reliability-practice.md)'s template for every SEV1 and SEV2, and for notable drills.

**Emergency changes outside GitOps** (`emergency-change.md`), allowed only in a SEV1 when the Git path is unavailable (GitHub down, Argo CD broken) or too slow to contain an attack:

1. Turn off auto-sync on the root Application and the affected one, so self-heal does not revert the change.
2. Make the change as `platform-admin`, posting each command in the incident thread. The audit alerts it raises (`KubeWorkloadCreatedOutsideArgoCD`, `KubeRBACChangedOutsideArgoCD`) are expected and acknowledged in the thread.
3. **Within 24 hours**, open a pull request that either records the change in Git or reverts it, then turn auto-sync back on. `ArgoCDAppOutOfSync` keeps firing until this is done, so the change cannot be forgotten.

**New runbooks**, each written in the plan step where its subject is built and tested there:

| Runbook | Covers | Phase 1 step | Later |
|---|---|---|---|
| `incident-response.md` | The process above | 4.4 | — |
| `credential-leak.md` | An inventory of every credential (where it lives, how to revoke and replace it, what breaks meanwhile); revoke first, then check for use | 4.2 | Phase 2 step 2.2 adds the LiteLLM keys |
| `lost-access.md` | Sign-in failures; using break-glass and what to rotate afterwards | 4.7 | — |
| `terraform-state.md` | A stuck lock, drift, restoring an earlier state version | 2.4 | — |
| `upgrade-talos-kubernetes.md` | The upgrade procedure, one node at a time, with stop conditions | 7.8 | — |
| `etcd-recovery.md` | Quorum lost: recover from a snapshot with `talosctl bootstrap --recover-from` | 7.10 | — |
| `replace-node.md` | Remove the etcd member, reset or replace the machine, re-enroll the TPM, rejoin | 7.11 | — |
| `cold-start.md` | All three nodes lost power: what to check, in order, as they come back (MariaDB first) | 7.11 | — |
| `emergency-change.md` | The rule above | 7.14 | — |
| `wordpress-compromise.md` | Rogue admins, injected content, defacement: preserve, remove access, end every session, restore content | 7.14 | — |
| `emergency-vulnerability.md` | An exploited vulnerability with no fix: a WAF rule to block the exploit, removing the plugin, maintenance mode | 7.14 | Phase 3 step 4.1 adds AWS WAF |
| `supply-chain-compromise.md` | A compromised workflow, runner, dependency or signing identity: stop promotion, find affected digests, tighten Kyverno, rebuild from a known-good commit | 7.14 | — |
| `under-attack.md` | A bot flood or DDoS: Cloudflare's "I'm Under Attack" security level per hostname, tighter rate limits, CrowdSec | 7.14 | Phase 3 step 4.1 adds AWS WAF |
| `demo-teardown-stuck.md` | `demo-down` hanging, and finding leftover resources by tag | — | Phase 3 step 5.1 |

**One runbook index:** the **[Runbooks](../../runbooks.md)** page on the docs site lists every runbook in every repo: what it covers, the step that writes it, and how it is rehearsed. It is the only list, so it cannot drift from a second copy:

- Runbooks stay in the repo that uses them, mostly `russetleaf-gitops/docs/runbooks/` ([ADR 1038](1038-documentation-repo-and-site.md)). That folder's `README.md` points to the index.
- A runbook appears in the index as a plain path until it exists. The step that writes it turns the path into a link and fills in the date of its first drill.
- Alert runbooks are named after their alert (`docs/runbooks/<alert>.md`) and listed in the index by group, with the step that adds each group.
- Each step's spec says which runbooks the step writes or changes.

**Drills added:** an incident tabletop exercise twice a year, a cold-start drill and a control-plane recovery rehearsal once a year, and a credential revoke-and-replace once a year, alongside the existing rollback, restore and disaster drills.

## Alternatives considered

- **An incident tool** (PagerDuty, incident.io, Rootly): on-call schedules, escalation and automatic timelines, all built for teams. One operator gains little over a Slack thread, and each adds an account and cost. Worth revisiting with a second operator.
- **A public status page** (Atlassian Statuspage, Upptime, Instatus): useful when users depend on the site; for a portfolio site, the uptime check and the incident thread are enough.
- **One large incident playbook** instead of separate runbooks: everything in one place, but slow to follow under pressure. Separate runbooks from the shared template are quicker to use, and Phase 2's assistant can cite the right one ([ADR 2007](../../phase-2-ai-mlops/adr/2007-ai-diagnosis-and-remediation-proposals.md)).
- **The index in `russetleaf-gitops` only:** next to the runbooks, but invisible on the docs site, which is the project's front door, and it would miss the runbooks in other repos. Keeping two lists would let them drift.
- **Backstage TechDocs as the index:** renders and searches runbooks well, but Backstage is an Advanced step (8.3) that may not be built; it can render the same pages later.
- **Forbidding all changes outside GitOps:** the purest rule, but it leaves no way to contain an attack while GitHub is down. A narrow, recorded exception with a 24-hour reconciliation is safer than an unofficial one.
- **A UPS instead of the cold-start runbook:** prevents most power-cut incidents, and [ADR 1014](1014-availability-levels.md) still recommends one, but long outages and failed batteries still happen, so the runbook is needed either way.

## Consequences

- Every incident has a severity, a timeline and a defined set of hand-offs; the riskiest recoveries are written down step by step and rehearsed.
- A reviewer can see on one page what runbooks exist, what is still planned, and when each was last rehearsed.
- About **16–28 more hours** in Phase 1 (mostly in the drills) and **2–3** in Phase 3.
- A sanctioned way to change the cluster outside GitOps now exists. It is limited to SEV1, alerts on every use, and must be reconciled within 24 hours.
- The index must be kept current: each step that writes a runbook updates it, and a quarterly review checks it against the runbooks folders.

## When to revisit

- A second operator joins: split the incident roles, add an on-call rotation and consider a paging or incident tool.
- russetleaf.com becomes always-on or holds user data: consider a status page and tighter response targets.
- An incident happens for which no runbook existed: write one, and check the index for similar gaps.

## Open items

- Phase 1 steps 2.4, 4.2, 4.4, 4.7, 5.8, 7.8, 7.10, 7.11 and 7.14: write the runbooks listed above, and turn each index entry into a link.
- Phase 2 step 2.2: add the LiteLLM keys to the credential inventory.
- Phase 3 steps 4.1 and 5.1: the AWS WAF steps and the stuck-teardown runbook.
