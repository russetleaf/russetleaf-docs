# ADR 3004: EKS component hardening

- **Status:** Accepted (split from ADR 1031)
- **Date:** 2026-11-02
- **Applies to:** the EKS cluster, its nodes and the russetleaf-com account
- **Phase:** 3

## Context

ADR 1031 sets explicit controls and checks for every Kubernetes component on the home Talos cluster, and the controls shared by both clusters (Pod Security Admission labels, Kyverno's `restricted` set, service-account tokens off by default, network policies). On EKS, AWS manages the control plane under the shared-responsibility model; the project controls encryption settings, endpoint access, the nodes, add-ons and workloads. EKS doesn't enforce Pod Security by default.

## Decision

- **Secrets envelope encryption** with a **customer-managed KMS key** (not the AWS-owned default).
- **API endpoint:** public but **restricted to the home network's address**, with private access on for the nodes; the demo workflows run on the home ARC runners so they come from that address.
- **Nodes:** AL2023 with a pinned AMI version; **IMDSv2 required with a hop limit of 1**; kubelet `seccompDefault`, system and kubelet reservations, hard eviction thresholds and a per-pod PID limit (ADR 1034) through the managed node group's launch template and Karpenter's node configuration; encrypted gp3 root volumes.
- **Pod Security Admission labels** on every namespace, as at home, with the version pinned.
- **Add-on versions pinned** in Terraform, checked monthly by the version-age workflow.
- **Checks:** kube-bench with the EKS profile on every demo (ADR 3001), `aws eks describe-cluster` for encryption and endpoint access, and the EKS items of the security review (Phase 3 step 5.1); the review states that the control plane is AWS's responsibility.

## Alternatives considered

- **AWS-owned keys for envelope encryption:** the default and free, but the SRA prefers customer-managed keys for control and audit.
- **A private-only API endpoint:** stronger, but needs a VPN or bastion for the workstation and the home runners; the home-address restriction is enough for a demo cluster.
- **Bottlerocket nodes:** a hardened, minimal OS like Talos; a good option, but AL2023 is simpler with Karpenter and the NVIDIA AMI.

## Consequences

- A KMS key (about $1/month while the account has it).
- The EKS hardening evidence matches the home cluster's: each control has a check and a recorded result per demo.

## When to revisit

- russetleaf.com becomes always-on: consider a private endpoint and Bottlerocket nodes.

## Open items

- Phase 3 step 1.4: envelope encryption, endpoint access, node settings; step 2.5: kube-bench; step 5.1: the review.
