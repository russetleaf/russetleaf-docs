# Exercise program

How the project tests its runbooks, recovery plan and break-glass kit: the types of exercise, one calendar for all of them, and the procedure every exercise follows, from planning to the after-action report. An untested runbook is a guess; an exercise finds the wrong step, the renamed button and the missing permission before an incident does.

The program follows three standards:

- **NIST SP 800-61 Rev. 3** puts exercises in the Improvement category of incident response (ID.IM-02: "Improvements are identified from security tests and exercises"), and points to SP 800-84 for how to run them.
- **NIST SP 800-84** covers "designing, developing, conducting, and evaluating test, training, and exercise (TT&E) events": the procedure below has the same stages.
- **HSEEP 2020** (the Homeland Security Exercise and Evaluation Program) gives the definitions of each exercise type, the **progressive approach** (exercises "aligned to a common set of program priorities and objectives with an increasing level of complexity over time"), the **hotwash** straight after an exercise, and the **after-action report and improvement plan (AAR/IP)**.

Each runbook's own cadence is shown in the [runbook index](runbooks.md); this page holds the calendar they all come from, and the [disaster recovery plan](phase-1-russetleaf-dev/disaster-recovery.md#drills) and the plan's [recurring tasks](phase-1-russetleaf-dev/plan.md#ongoing-operations-after-the-build) point here.

## Exercise types

| Type | HSEEP definition | Used for |
|---|---|---|
| **Tabletop exercise** | "A discussion-based exercise in response to a scenario, intended to generate a dialogue of various issues to facilitate a conceptual understanding, identify strengths and areas for improvement, and/or achieve changes in perceptions about plans, policies, or procedures." | Incident runbooks that cannot be carried out without real harm (a stolen safe, a compromised cluster, a personal data breach): each step is talked through against the runbook, and every console page, menu and label it names is opened and checked, without changing anything |
| **Drill** | "An operations-based exercise often employed to validate a single operation or function." | Recovery and rollback procedures: a restore, a rollback, a node failure, a cold start, a credential replaced, carried out for real in a scratch instance, staging, a local Talos-in-Docker cluster or a maintenance window |
| **Full disaster drill** | A series of drills run end to end | The whole [disaster recovery plan](phase-1-russetleaf-dev/disaster-recovery.md): the site rebuilt using only the break-glass kit and the backups |

Following the progressive approach, a new runbook is first walked through as a tabletop, then drilled where that is safe, and only then included in the full disaster drill.

## Rules

- **Every runbook marked Written** in the [runbook index](runbooks.md) is exercised **at least once a year**: by its own drill or tabletop in the calendar, or, if it has none, as a scenario in one of the twice-yearly incident tabletops, which between them cover every such runbook each year.
- **The first exercise** of a runbook is part of the step that writes it, as the index records.
- **After a significant change** to a runbook, or when an exercise or an incident finds that a provider has changed its console, the runbook is exercised again within a month, as a tabletop at least.
- **An exercise starts** once the plan step in its **Begins after** column is done; until then, its row is not yet due.
- **Safety:** a tabletop changes nothing; it opens console pages only to read them. A drill runs in a scratch instance, staging or a local cluster, except the node-failure and cold-start drills, which run on the real cluster during a maintenance window announced in `#rl-deploys`. Each drill has an **abort condition**, set while planning it.
- **A missed exercise** is run the following month, and its report says so.

## Calendar

The months spread the work across the year; the day within a month is the operator's choice.

| Exercise | Type | When | Begins after | Runbook or guide | What it proves |
|---|---|---|---|---|---|
| Restore the latest database backup into a scratch MariaDB instance, and check the post count | Drill | Monthly | [Step 4.5](phase-1-russetleaf-dev/plan.md#step-45-database-and-cache) | `docs/runbooks/rollback-data.md` | Backups are usable |
| Roll back an application, platform, configuration, OpenTofu or secrets change in staging | Drill | Monthly | [Step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | The rollback runbooks | A bad change can be undone, in the time recorded |
| Test the outside monitoring: pause the heartbeat or block the uptime check | Drill | February, May, August, November | [Step 0.1](phase-1-russetleaf-dev/plan.md#step-01-accounts-tools-and-budget-alert) | [Slack and outside monitoring setup guide](phase-1-russetleaf-dev/setup/slack-and-monitoring.md#checks) | `#rl-critical` is notified when the site or the cluster goes silent |
| Restore a database backup **from the backup account's copy**, signed in only to the Backup account | Drill | February, May, August, November | [Step 2.5](phase-1-russetleaf-dev/plan.md#step-25-disaster-recovery-copies) | [Disaster recovery plan](phase-1-russetleaf-dev/disaster-recovery.md) | The off-account copies are readable without the account they protect against |
| Restore a database backup **from the encrypted Cloudflare R2 copy**, with the GPG key from the break-glass kit | Drill | February, May, August, November | [Step 2.5](phase-1-russetleaf-dev/plan.md#step-25-disaster-recovery-copies) | [Break-glass kit setup guide](phase-1-russetleaf-dev/setup/break-glass-kit.md#using-the-key) | The copy outside AWS is usable without any AWS access |
| Node failure: take one node offline, alternating nodes | Drill | February, May, August, November | [Step 7.11](phase-1-russetleaf-dev/plan.md#step-711-node-failure-drills) | `docs/runbooks/replace-node.md` | Failover works, in the time recorded |
| Roll back Talos, Kubernetes, Cilium and Kyverno on a local Talos-in-Docker cluster | Drill | February, May, August, November | [Step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | The rollback runbooks | Platform upgrades can be undone |
| Recover a deleted staging namespace from Git and backups | Drill | February, May, August, November, with the rollback drills | [Step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | `docs/runbooks/restore-deleted-resources.md` | A deletion is recoverable without a cluster backup tool |
| Incident tabletop: a scenario from the security incident runbooks, chosen so that each runbook without its own exercise is covered once a year | Tabletop | March, September | [Step 4.4](phase-1-russetleaf-dev/plan.md#step-44-monitoring) | `docs/runbooks/incident-response.md` and the runbooks of the scenario | The severity, hand-offs and runbooks work for incidents that cannot be drilled |
| Restore the other copies: a repo from its Git bundle, a media object from the replica, and OpenTofu state from the Backup account | Drill | April, October | [Step 2.5](phase-1-russetleaf-dev/plan.md#step-25-disaster-recovery-copies) | [Disaster recovery plan](phase-1-russetleaf-dev/disaster-recovery.md) | The other copies are usable, not just the database's |
| Check the break-glass kit (and that the talosconfigs' client certificates are not near expiry), and walk through the [break-glass kit compromise runbook](runbooks/break-glass-kit-compromise.md) | Drill and tabletop | May, November | [Step 0.1](phase-1-russetleaf-dev/plan.md#step-01-accounts-tools-and-budget-alert) | [Break-glass kit setup guide](phase-1-russetleaf-dev/setup/break-glass-kit.md#keeping-the-kit-current) | Access can be recovered, and a stolen kit can be contained |
| Full disaster drill: rebuild russetleaf.dev using only the break-glass kit and the backups | Full disaster drill | January | [Step 7.10](phase-1-russetleaf-dev/plan.md#step-710-first-full-disaster-drill) | [Disaster recovery plan](phase-1-russetleaf-dev/disaster-recovery.md) | The whole plan works; the time recorded is the recovery time |
| Control-plane recovery on a local Talos-in-Docker cluster with two of its three nodes stopped | Drill | February | [Step 7.10](phase-1-russetleaf-dev/plan.md#step-710-first-full-disaster-drill) | `docs/runbooks/etcd-recovery.md` | Quorum loss is recoverable |
| Restore a database dump from the **monthly** copies, and re-apply the erasure log | Drill | April, with the other copies | [Step 5.12](phase-1-russetleaf-dev/plan.md#step-512-compliance-scope-and-privacy-gdpr-basics) | [Disaster recovery plan](phase-1-russetleaf-dev/disaster-recovery.md) | Damage found late is recoverable, without bringing back erased personal data |
| Cold start: cut power to all three nodes | Drill | June | [Step 7.11](phase-1-russetleaf-dev/plan.md#step-711-node-failure-drills) | `docs/runbooks/cold-start.md` | The cluster and database come back on their own, or by the checklist |
| Revoke and replace one credential from the inventory | Drill | July | [Step 4.2](phase-1-russetleaf-dev/plan.md#step-42-secrets-and-internal-certificates) | `docs/runbooks/credential-leak.md` | A leaked credential can be replaced, and the old one is refused |
| Make one backup copy late on purpose (pause the R2 job) | Drill | August | [Step 2.5](phase-1-russetleaf-dev/plan.md#step-25-disaster-recovery-copies) | [Disaster recovery plan](phase-1-russetleaf-dev/disaster-recovery.md) | `BackupCopiesStale` fires |
| *(Phase 3)* Restore aws.russetleaf.dev's database from the latest logical dump in the backup account | Drill | October | [Phase 3 step 5.1b](phase-3-aws-russetleaf-dev/plan.md#step-51b-rollback-drill-on-eks) | [Disaster recovery plan](phase-1-russetleaf-dev/disaster-recovery.md) | The AWS-side copy works |
| Clone a repo from its GitLab mirror over SSH with each YubiKey | Drill | November, with the yearly SSH key renewal | [Step 0.1](phase-1-russetleaf-dev/plan.md#step-01-accounts-tools-and-budget-alert) | [Workstation YubiKey setup guide](phase-1-russetleaf-dev/setup/workstation-yubikey.md#renewing-the-keys-every-year) | The first restore path for a lost GitHub works from the workstation |

## Running an exercise

The operator usually plays every part: planner, facilitator, player and evaluator. Setting the success criteria **before** the exercise keeps the evaluation honest; a second person, when one is available, makes a better facilitator for a tabletop, presenting the scenario and its developments without the operator knowing them in advance.

1. **Plan,** at least a few days before:
    - the **objective**: what the exercise is to prove (the calendar's **What it proves**), and the runbook or guide it follows;
    - the **scenario**, for a tabletop: the starting situation, and a few **injects**, developments presented during the exercise (for example, "the Workspace password reset email does not arrive");
    - the **success criteria**: the runbook's own checks, and a target time where the runbook or the plan sets one;
    - for a drill, the environment, what may be touched, and the **abort condition** (for example, "staging does not come back within 30 minutes: restore it from Git and stop").
2. **Conduct:**
    - start a record, with the date and the start time;
    - follow the runbook **step by step, as written**, and record each step's start time and outcome. Where the runbook is wrong or unclear, do what the situation needs, and record both what the runbook said and what was done;
    - in a tabletop, open each console page the step names and check the path and the labels against the screen, without changing anything;
    - stop at the abort condition, and record why.
3. **Hotwash,** straight after: while it is fresh, write down what worked (**strengths**) and what did not (**areas for improvement**).
4. **After-action report and improvement plan,** within a week, as `docs/postmortems/<date>-exercise-<name>.md` ([ADR 1023](phase-1-russetleaf-dev/adr/1023-reliability-practice.md)), with the sections in the template below.
5. **Improve and close:**
    - fix the runbook, guide or plan in the same change as the report, wherever the fix needs no decision;
    - record any fix that waits, with its reason and trigger, in the [improvements list](phase-1-russetleaf-dev/improvements.md);
    - set the runbook's **Rehearsed** date in the [runbook index](runbooks.md).

### After-action report template

```markdown
# Exercise: <name>, <date>

- **Type:** tabletop | drill | full disaster drill
- **Runbook or guide:** <link>
- **Scenario or environment:** <one paragraph>

## Objectives and results

| Objective | Success criterion | Result (met, partly met, not met) |
|---|---|---|

## Timeline

| Time | Step | Outcome |
|---|---|---|

## Strengths

## Areas for improvement

Each one: what happened, why (the root cause), and its effect.

## Improvement plan

| Action | Where it is done or tracked | By |
|---|---|---|

## Changes made

The commits that fixed the runbook or other documents.
```

## References

The official pages this program follows, each checked on the date shown. When a page has moved or changed, find the current one, update the program if needed, and change the date.

- NIST: ["Incident Response Recommendations and Considerations for Cybersecurity Risk Management: A CSF 2.0 Community Profile (SP `800-61r3`)"](https://doi.org/10.6028/NIST.SP.800-61r3), April 2025 (Table 2, ID.IM-02 and ID.IM-04), checked 2026-11-19
- NIST: ["Guide to Test, Training, and Exercise Programs for IT Plans and Capabilities (SP `800-84`)"](https://doi.org/10.6028/NIST.SP.800-84), September 2006, checked 2026-11-19
- FEMA: ["Homeland Security Exercise and Evaluation Program (HSEEP)"](https://www.fema.gov/emergency-managers/national-preparedness/exercises/hseep), the 2020 doctrine (Tables 2.5 and 2.7, the exercise types; the player hotwash; the AAR/IP), checked 2026-11-19
- CISA: ["CISA Tabletop Exercise Packages"](https://www.cisa.gov/resources-tools/services/cisa-tabletop-exercise-packages), scenarios for tabletop exercises, checked 2026-11-19
