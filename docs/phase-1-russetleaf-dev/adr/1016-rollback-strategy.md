# ADR 1016: Rollback strategy: Git revert by default, automatic canary rollback, back up before schema changes

- **Status:** Accepted; updated by [ADR 1046](1046-incident-response-and-runbook-index.md)
- **Date:** 2026-11-01
- **Applies to:** both sites
- **Phase:** 1. Later: Phase 2 adds model-routing rollback and re-summarizing; Phase 3 adds the demo-stack and edge rollbacks.

> **Update ([ADR 1046](1046-incident-response-and-runbook-index.md)):** when the Git path is unavailable (GitHub down, Argo CD broken) or too slow to contain an attack, a **SEV1** may change the cluster directly through the `emergency-change.md` runbook: auto-sync off for the affected apps, every command recorded in the incident thread, and a pull request that records or reverts the change within 24 hours.

## Context

Rollback mechanisms existed in pieces (Argo Rollouts canaries, Git reverts, `talosctl rollback`, database backups and snapshots, staging gates), but there was no single strategy. Several cases were not covered:

- **Database schema changes:** WordPress core upgrades change the database structure on first run, so rolling back the image afterwards can break the site.
- **Argo CD auto-sync:** a manual `argocd app rollback` is immediately overwritten by auto-sync.
- **Components that rollback depends on:** a broken Cilium (networking) or Kyverno (admission) can prevent the fix from being deployed.
- **OpenTofu:** a revert can still destroy or replace stateful resources.
- **AI summaries:** reverting a prompt or model leaves bad summaries already saved.
- **Secrets:** a bad rotation needs a quick path back.
- No decision rules, and no practice.

## Decision

- **Rules:** roll back first and investigate after (user-facing errors not clearing within 5 minutes); fix forward only when rollback is riskier or the fix is trivial and ships within 15 minutes; record every rollback.
- **Default mechanism: Git revert**, synced by Argo CD (applications, platform, configuration, model routing, OpenTofu).
- **Automatic rollback** for application releases through **Argo Rollouts** canary analysis.
- **Schema changes:** CI labels releases that change WordPress's database version; the promotion workflow takes an **on-demand backup** (a manual RDS snapshot on AWS) before such a release can be merged; recovery is restore-and-roll-back or fix forward, decided within 15 minutes.
- **High-risk components:** Cilium on manual sync with a workstation recovery path (`helm rollback`); Kyverno's webhooks exclude `kube-system`, `kyverno` and `argocd`, with an emergency webhook-removal procedure; Argo CD recoverable with `helm rollback`.
- **OpenTofu:** `prevent_destroy` on stateful resources; reverts go through a reviewed saved plan, stopping on any destructive change to stateful resources.
- **Talos:** `talosctl rollback`; Kubernetes minor downgrades are not supported, so restore from the pre-upgrade etcd snapshot.
- **EKS demo stack:** rebuild with previous versions; RDS point-in-time restore for data mistakes.
- **Secrets:** fall back to Secrets Manager's `AWSPREVIOUS` version.
- **AI summaries:** a re-summarize job re-queues posts summarized by a bad prompt or model version.
- **Drills:** monthly in staging, quarterly locally for Talos, Cilium and Kyverno, and once on EKS, with timings recorded.

## Alternatives considered

- **`argocd app rollback` as the default:** quick, but conflicts with auto-sync and leaves Git out of step with the cluster.
- **Always fixing forward:** avoids schema-rollback problems, but keeps users on a broken site while the fix is written and tested.
- **Blue/green deployments for every release:** cleaner cut-overs, but doubles the running workload; `rl-home-cp01` cannot afford it, and canaries achieve most of the benefit.
- **Database migration tooling with down-migrations:** WordPress core does not provide reversible migrations, so backups are the practical safety net.

## Consequences

- Rollback is mostly a Git revert, so it is fast, reviewable and leaves Git as the record of what runs.
- Schema-changing releases take a few extra minutes (the backup) before promotion.
- Cilium upgrades need a manual sync and a little more care.
- `prevent_destroy` means deleting a protected resource on purpose requires a deliberate two-step change.
- Runbooks and drills need maintaining; drills also catch broken backups and recovery paths early.

## When to revisit

- A third node (or more memory) makes blue/green deployments affordable.
- aws.russetleaf.dev becomes always-on: add blue/green or regional failover to its rollback options.
- WordPress or a plugin adopts reversible migrations.

## Open items

- Phase 1 step 5.7: the `schema-change` label and the pre-promotion backup.
- Phase 1 step 6.1: Kyverno webhook exclusions and the emergency procedure, tested.
- Phase 1 step 3.1: Cilium on manual sync, and the `helm rollback` recovery path tested locally.
- Phase 2 step 2.4: the re-summarize job.
- Phase 1 step 7.8: the first set of rollback drills, with timings.
