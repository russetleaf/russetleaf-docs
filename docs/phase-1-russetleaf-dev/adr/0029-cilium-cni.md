# ADR 0029: Cilium as the network plugin on both clusters

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** both sites

## Context
The network plugin (CNI) is one of the most consequential and hardest-to-change cluster decisions: it determines whether network policies are enforced, how traffic is observed and encrypted, and how services are load-balanced. Talos defaults to **Flannel**, which doesn't enforce network policies; EKS defaults to the **Amazon VPC CNI**, which gives pods VPC IP addresses and can enforce standard network policies.

The design needs: enforced default-deny policies, **outbound rules by DNS name** (AWS service IPs change constantly), some **layer-7** rules, flow visibility, encryption between nodes, and the same policy model on both clusters.

## Decision
- **Cilium** on both clusters, with **CiliumNetworkPolicies** (and a cluster-wide default-deny baseline), **Hubble** for flow visibility and metrics, and **WireGuard** transparent encryption.
- **Talos:** Cilium as the full CNI, replacing Flannel **and kube-proxy**.
- **EKS:** Cilium in **chaining mode** on top of the VPC CNI (which keeps assigning VPC IP addresses), with the VPC CNI's own policy enforcement off.

## Alternatives considered
- **Flannel (Talos default):** simple, but no network policy enforcement at all.
- **Calico:** mature, enforces standard and its own policies, supports DNS-based rules in some editions and WireGuard; a credible choice. Cilium was preferred for its eBPF data path (replacing kube-proxy), Hubble's built-in flow visibility and metrics, layer-7 policies, and its strong fit with Tetragon.
- **VPC CNI alone on EKS** (with its network policy support): AWS-native and simplest on EKS, but standard NetworkPolicies only (no DNS-name or layer-7 rules), no Hubble, and a different model from the home cluster.
- **Cilium replacing the VPC CNI entirely on EKS (ENI mode):** possible, but moves further from what AWS supports out of the box; chaining keeps EKS close to its defaults.

## Consequences
- One policy model, one observability tool and one set of alerts across both clusters.
- DNS-name outbound rules make "WordPress may only reach S3, SQS, SES and STS" enforceable.
- More moving parts than the defaults: Cilium upgrades are high-risk (ADR 0017's Cilium recovery path), and Talos requires specific Cilium settings.
- WireGuard support in chaining mode depends on the Cilium version (ADR 0001's open item).

## When to revisit
- Cilium in chaining mode proves fragile on EKS: fall back to the VPC CNI's policies on EKS only.
- A managed alternative (e.g. AWS adding DNS-based policies to the VPC CNI) closes the gap.

## Open items
- Home plan step 2.2 and AWS plan step 1.4: install and connectivity tests.
