# ADR 1011: Update strategy: Git-driven, risk-tiered updates with Renovate

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** both sites and all four repos
- **Phase:** 1. Later: Phase 2 adds model and summarizer updates; Phase 3 adds EKS versions and add-ons.

## Context

The project has many layers that need regular updates: WordPress core, plugins and themes; base images; the summarizer's Python dependencies; platform components (Cilium, Argo CD, Kyverno, Falco, Loki and others); Talos and Kubernetes at home; EKS, AMIs, RDS and ElastiCache on AWS; OpenTofu providers; CLI tools and GitHub Actions; and the models. The design already pins versions (images by digest, charts, OpenTofu), disables WordPress's in-place updates (`DISALLOW_FILE_MODS`), and has ci kind tests, on-demand staging, promotion pull requests and Argo Rollouts canaries. What was missing was one consistent strategy, plus coverage of WordPress plugin vulnerabilities (which Trivy does not detect) and of end-of-life versions.

## Decision

- **Every update is a pull request**, created by **Renovate** where possible (Composer via WPackagist for WordPress plugins and themes; custom version rules for Talos, Kubernetes and the EKS AMI), tested by CI and promoted like any other change. Nothing updates itself in place.
- **Risk tiers:**
    - **Patch** updates to platform charts, CLI tools and GitHub Actions **auto-merge** once CI passes.
    - **Minor and major** platform updates are reviewed by hand and rehearsed on a **local Talos-in-Docker cluster** first.
    - **Application** updates (WordPress image, summarizer) go through **ci → staging → promotion → canary**.
    - **Talos and Kubernetes** upgrades follow a fixed procedure (backups, local rehearsal, one node at a time: `rl-home-cp02`, `rl-home-cp01`, then `rl-home-cp03`; rollback with `talosctl rollback`).
    - **EKS** versions are bumped before demos, since the stack is rebuilt each time; RDS's MariaDB version stays matched to the home MariaDB.
    - **Models** change only after the evaluation gate and a gateway canary.
- **Security updates** skip the weekly schedule and are released within **48 hours**, triggered by **WPScan** (WordPress plugins and themes, weekly and in CI), Trivy Operator (running images) and Renovate's security alerts.
- A **monthly version-age report** flags anything within 90 days of end of support.
- **Cadence:** weekly Renovate review and image rebuild; monthly Talos patches and platform minors; quarterly Kubernetes minor upgrades.

## Alternatives considered

- **WordPress auto-updates:** keeps plugins current with no effort, but changes code in place, bypasses CI, staging, signing and the read-only filesystem, and makes rollback hard. Incompatible with [ADR 1002](1002-s3-media-not-efs.md).
- **Auto-merging everything that passes CI:** less review work, but minor and major platform changes (for example, Cilium, Kyverno) can break the cluster in ways CI on kind does not catch.
- **Manual updates only:** easy to fall behind, with no reminders; Renovate's Dependency Dashboard and the version-age report prevent that.
- **Dependabot instead of Renovate:** works for common ecosystems, but Renovate handles more (Helm charts in Argo CD manifests, `.mise.toml`, Composer via WPackagist, custom version rules) and has better grouping and auto-merge controls.
- **A full staging cluster for platform updates:** would catch more, but `rl-home-cp01` has no memory for a second cluster; local Talos-in-Docker rehearsal is the lightweight substitute.

## Consequences

- Updates are small, frequent, reviewed and reversible; nothing drifts from Git.
- Weekly review effort (mostly reading Renovate pull requests), and a monthly maintenance session.
- Plugins must be installable through Composer (WPackagist covers the WordPress.org directory; premium plugins would need another source).
- WPScan's free tier limits daily requests; the weekly and per-build scans fit within it for a small plugin list.
- Platform updates are not covered by staging; local rehearsal and canary-free rollback (Git revert) are the safeguards.

## When to revisit

- Updates become too frequent to review weekly: widen auto-merge (for example, minor versions of well-behaved components).
- A second cluster or more memory becomes available: use it as a platform staging environment.
- The site adopts premium plugins outside WPackagist: add their update sources.

## Open items

- Phase 1 step 1.1: write the shared Renovate configuration (schedule, grouping, auto-merge rules, custom version rules).
- Phase 1 step 5.1: move plugins to Composer with WPackagist, and add WPScan to CI and a weekly schedule.
- Phase 1 step 7.6: build the version-age report workflow.
- Record the first Talos and Kubernetes upgrade (with timings and any issues) in the decision log.
