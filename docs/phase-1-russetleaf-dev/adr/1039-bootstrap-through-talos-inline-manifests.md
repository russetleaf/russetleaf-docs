# ADR 1039: Bootstrap Cilium and Argo CD through Talos inline manifests, then hand off to Argo CD

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** the home Talos cluster's bootstrap (`russetleaf-infra/envs/home`, `russetleaf-gitops/platform/`)
- **Phase:** 1. Phase 3 bootstraps EKS differently ([ADR 3003](../../phase-3-russetleaf-com/adr/3003-cilium-chaining-on-eks.md)).

## Context

A new Talos cluster has no network plugin (Talos's default Flannel and kube-proxy are turned off for Cilium, [ADR 1027](1027-cilium-cni.md)), so nothing can run until Cilium is installed, including Argo CD, which is meant to manage everything afterwards. The plan installed Cilium with Terraform's Helm provider right after bootstrap, then Argo CD with Helm by hand, and only then handed both to GitOps. That's three tools and a manual step before the cluster is usable.

Talos images can't contain Kubernetes applications: Image Factory only adds system extensions and kernel settings. But Talos's machine config can carry **inline manifests**, which Talos applies while it creates the cluster.

## Decision

- **Terraform renders** the Cilium chart, the Argo CD chart, a root **Application** pointing at `russetleaf-gitops/bootstrap/home`, and the kubelet serving-certificate approver ([ADR 1035](1035-platform-security.md)) into the machine config's **`cluster.inlineManifests`**, with pinned chart versions and the values Talos documents for Cilium.
- **Talos applies them during bootstrap**, so the cluster comes up with networking, GitOps and its root Application already running.
- **Hand-off:** Phase 1 step 3.1 adds `platform/cilium/` and `platform/argocd/` with the same versions and values, so Argo CD adopts both without changing them; then the Cilium and Argo CD inline manifests are **removed** from the machine config, so later `talosctl upgrade-k8s` runs never roll back versions Argo CD has upgraded. (Before relying on it, confirm in a local Talos-in-Docker cluster that removing an inline manifest leaves its resources in place.)
- The Cilium Application stays on **manual sync**, with the `helm rollback` recovery runbook ([ADR 1016](1016-rollback-strategy.md)).

## Alternatives considered

- **Terraform's Helm provider for Cilium, Helm by hand for Argo CD** (the earlier plan): works, but needs the Kubernetes API reachable from Terraform in the same run that creates the cluster, plus a manual install, before GitOps takes over.
- **Keeping Cilium and Argo CD as inline manifests permanently:** simplest, but then Talos and Argo CD both manage them, and Kubernetes upgrades through Talos would reset whatever Argo CD had upgraded.
- **A custom Talos image with the applications baked in:** not possible; Talos images carry system extensions only.
- **The Cilium CLI or a one-off Job:** documented by Talos too, but an extra manual or imperative step, with nothing left in Git.

## Consequences

- One `terraform apply` produces a cluster that is already running Argo CD and syncing from Git.
- A short, deliberate hand-off in step 3.1, with a check that nothing changes during it.
- The machine config temporarily holds large rendered manifests; they're removed after the hand-off.

## When to revisit

- Talos changes how inline manifests are reconciled on upgrade.
- A full rebuild (the disaster-recovery drill) should bootstrap the same way; if the hand-off step proves fragile there, keep Cilium as an inline manifest and let Talos own its upgrades instead.

## Open items

- Phase 1 step 2.2: render the inline manifests and bootstrap; step 3.1: the hand-off and its check.
