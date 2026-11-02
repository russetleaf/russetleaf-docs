# ADR 3008: Karpenter for EKS nodes, with general and GPU node pools

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** the EKS cluster's nodes
- **Phase:** 3 (the GPU pool only if Phase 2 is built)

## Context

EKS nodes cost money by the hour, demos are short, traffic during a load test varies widely, and the self-hosted model (if Phase 2 is built) needs a GPU only while it runs. Fixed managed node groups would sit partly idle and can't pick cheaper instance types or spot capacity flexibly.

## Decision

- **A small managed node group** (two nodes) runs Karpenter itself, CoreDNS and other system pods.
- **Karpenter** creates all other nodes from two **NodePools**:
    - a **general pool** (spot and on-demand, several instance families) for WordPress and platform services, with **consolidation** to remove idle or underused nodes and a disruption budget;
    - a **GPU pool** (g6 family, spot preferred) for the model server and fine-tuning, labeled `workload=llm` and tainted `dedicated=llm:NoSchedule`, with consolidation limited so the model isn't moved needlessly; created only if Phase 2 is built.
- **Spot interruption handling** through an SQS queue fed by EventBridge, so pods move before AWS reclaims a node.
- **Node settings** in the `EC2NodeClass`: AL2023 with a pinned AMI version tracked by Renovate, IMDSv2 with hop limit 1, encrypted root volumes, kubelet limits (ADR 3004), and the Cilium startup taint (ADR 3003).
- **Cost alert:** `GPUNodeRunningLong` from OpenCost when a GPU node runs longer than expected.

## Alternatives considered

- **Cluster Autoscaler with managed node groups:** the older, widely used option, but slower, tied to node group definitions, and weaker at mixing instance types and spot.
- **EKS Auto Mode:** AWS manages Karpenter-style provisioning for you; simpler, but hides the configuration this project is meant to show, and adds a per-node management fee.
- **Fargate:** no nodes to manage, but no DaemonSets (Falco, Cilium, Alloy), no GPUs, and less control.

## Consequences

- Nodes appear for load and disappear afterwards; spot keeps the demo cost near $1 an hour.
- Spot interruptions are part of normal operation and are tested.
- Karpenter is installed by Terraform and its NodePools by Argo CD, so both repos change when node settings change.

## When to revisit

- EKS Auto Mode's fees and flexibility change, or the cluster grows enough that its managed upgrades are worth more than the visible configuration.

## Open items

- Phase 3 step 1.5: Karpenter's infrastructure; step 2.3: the NodePools; step 6.4: scaling behavior under load.
