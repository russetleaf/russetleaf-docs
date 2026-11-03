# ADR 1027: Cilium as the network plugin on both clusters

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** both sites
- **Phase:** 1. EKS: [ADR 3003](../../phase-3-russetleaf-com/adr/3003-cilium-chaining-on-eks.md) (Phase 3).

> **Update ([ADR 3003](../../phase-3-russetleaf-com/adr/3003-cilium-chaining-on-eks.md)):** the project is now built in three phases ([ADR 1037](1037-project-phases.md)). This ADR covers the decision to use Cilium and its use on Talos (Phase 1). **Cilium on EKS, in chaining mode with the VPC CNI,** is recorded in [ADR 3003](../../phase-3-russetleaf-com/adr/3003-cilium-chaining-on-eks.md) (Phase 3).

> **Update ([ADR 1039](1039-bootstrap-through-talos-inline-manifests.md)):** at home, Cilium is installed at bootstrap through Talos's inline manifests, then adopted by Argo CD.

## Context

The network plugin (CNI) is one of the most consequential and hardest-to-change cluster decisions: it determines whether network policies are enforced, how traffic is observed and encrypted, and how services are load-balanced. Talos defaults to **Flannel**, which does not enforce network policies; EKS defaults to the **Amazon VPC CNI**, which gives pods VPC IP addresses and can enforce standard network policies.

The design needs: enforced default-deny policies, **outbound rules by DNS name** (AWS service IPs change constantly), some **layer-7** rules, flow visibility, encryption between nodes, and the same policy model on both clusters.

## Decision

- **Cilium** on both clusters, with **CiliumNetworkPolicies** (and a cluster-wide default-deny baseline), **Hubble** for flow visibility and metrics, and **WireGuard** transparent encryption.
- **Talos:** Cilium as the full CNI, replacing Flannel **and kube-proxy**.
- **EKS:** see [ADR 3003](../../phase-3-russetleaf-com/adr/3003-cilium-chaining-on-eks.md).

## Alternatives considered

- **Flannel (Talos default):** simple, but no network policy enforcement at all.
- **Calico:** mature, enforces standard and its own policies, supports DNS-based rules in some editions and WireGuard; a credible choice. Cilium was preferred for its eBPF data path (replacing kube-proxy), Hubble's built-in flow visibility and metrics, layer-7 policies, and its strong fit with Tetragon.
- EKS-specific alternatives (the VPC CNI alone, Cilium in ENI mode): see [ADR 3003](../../phase-3-russetleaf-com/adr/3003-cilium-chaining-on-eks.md).

## Consequences

- One policy model, one observability tool and one set of alerts across both clusters.
- DNS-name outbound rules make "WordPress may only reach S3, SQS, SES and STS" enforceable.
- More moving parts than the defaults: Cilium upgrades are high-risk ([ADR 1016](1016-rollback-strategy.md)'s Cilium recovery path), and Talos requires specific Cilium settings.

## When to revisit

- A managed alternative (e.g. AWS adding DNS-based policies to the VPC CNI) closes the gap.

## Open items

- Phase 1 step 2.2: install and connectivity tests (EKS: [ADR 3003](../../phase-3-russetleaf-com/adr/3003-cilium-chaining-on-eks.md)).
