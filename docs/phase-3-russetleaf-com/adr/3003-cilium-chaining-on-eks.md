# ADR 3003: Cilium on EKS in chaining mode with the VPC CNI

- **Status:** Accepted (split from ADR 1027)
- **Date:** 2026-11-02
- **Applies to:** the EKS cluster
- **Phase:** 3

## Context
ADR 1027 chose Cilium on both clusters so they share one policy model (CiliumNetworkPolicies with DNS-name and layer-7 rules), Hubble and WireGuard. On EKS, the **Amazon VPC CNI** is the default and gives pods VPC IP addresses, which security groups, the ALB's `ip` targets and VPC endpoints rely on.

## Decision

- **Cilium in chaining mode** on top of the VPC CNI: the VPC CNI keeps assigning VPC addresses; Cilium adds policy enforcement, Hubble and (if supported) WireGuard. The VPC CNI's own network policy enforcement is **off**.
- **Installed by Terraform's Helm provider** right after the cluster and managed node group exist (`cni.chainingMode: aws-cni`, `cni.exclusive: false`, `enableIPv4Masquerade: false`, `routingMode: native`), then managed by Argo CD from `platform/cilium/overlays/aws`.
- **Karpenter NodePools add the startup taint** `node.cilium.io/agent-not-ready=true:NoExecute`, so no pod lands on a new node before Cilium is ready.
- **WireGuard:** turned on only if the installed Cilium version supports it in chaining mode; otherwise left off and recorded, relying on the TLS already on every sensitive connection (ADR 1001).

## Alternatives considered

- **VPC CNI alone** (with its network policy support): AWS-native and simplest, but standard NetworkPolicies only (no DNS-name or layer-7 rules), no Hubble, and a different model from the home cluster.
- **Cilium replacing the VPC CNI entirely (ENI mode):** possible, but further from what AWS supports out of the box; chaining keeps EKS close to its defaults.

## Consequences

- The same base policies, dashboards and alerts work on both clusters.
- Two CNI components to keep compatible on EKS; upgrades are rehearsed during a demo session.
- Encryption between EKS nodes depends on the Cilium version.

## When to revisit

- Chaining proves fragile: fall back to the VPC CNI's policies on EKS only.
- AWS adds DNS-based policies to the VPC CNI.

## Open items

- Phase 3 step 1.4: install, connectivity tests and the WireGuard check; step 2.3: the startup taint.
