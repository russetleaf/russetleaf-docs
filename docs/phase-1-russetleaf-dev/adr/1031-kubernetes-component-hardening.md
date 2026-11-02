# ADR 1031: Kubernetes component hardening

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** both clusters (the EKS-specific parts are tracked in ADR 3004)
- **Phase:** 1. EKS: ADR 3004 (Phase 3).

> **Update (ADR 3004):** the project is now built in three phases (ADR 1037). This ADR is Phase 1's: the Talos cluster and the controls shared by both clusters. The **EKS-specific controls** (envelope encryption with a customer-managed key, API endpoint access, kube-bench on the nodes, the checks in the AWS security review) are recorded in ADR 3004 (Phase 3). The EKS entries in the table below are kept for comparison.

## Context
A review of the design against the Kubernetes components (API server, controller-manager, scheduler, kubelet, container runtime, kube-proxy, etcd, Pod Security Admission and Standards, network and storage) found strong coverage for the network, runtime, admission and kubelet layers, but gaps in: per-namespace **Pod Security Admission**; the full **`restricted`** Pod Security Standard for application namespaces; **encryption at rest** (Secrets in etcd, the home disks, etcd snapshots); **verification** of the control-plane components' settings; **service-account tokens** mounted in every pod; and access to the Talos and Kubernetes API ports on the home network.

On the home cluster, Talos manages the control-plane components and their settings; on EKS, AWS manages the control plane (shared responsibility), and the project controls the nodes, add-ons and workloads.

## Decision

| Component | Controls | How it's checked |
|---|---|---|
| **kube-apiserver** | Node and RBAC authorization only; audit logging with alert rules; NodeRestriction and PodSecurity admission plugins; **Secrets encrypted at rest** (Talos's built-in encryption at home; EKS **envelope encryption** with a **customer-managed KMS key**); API reachable only on the LAN and virtual IP (home) or from the home address (EKS); a **Talos host firewall** limiting ports 6443 and 50000 to the LAN and the workstation | `talosctl` reads of the API server arguments and authorization config; an EKS `describe-cluster` check of encryption and endpoint access; a firewall test from outside the allowed range |
| **kube-controller-manager** | Profiling off; listening only locally (secure port); per-controller service-account credentials; kubelet server-certificate rotation | `talosctl` read of its arguments; kube-bench on EKS nodes; AWS-managed control plane on EKS |
| **kube-scheduler** | Profiling off; listening only locally | `talosctl` read of its arguments |
| **kubelet** | Anonymous access off; webhook authorization; **read-only port (10255) off**; certificate rotation; **`seccompDefault: true`** (RuntimeDefault for every pod even if it doesn't ask); system and kubelet reservations | `talosctl` read of `kubelet.yaml`; anonymous request to 10250 returns 401; connection to 10255 refused; kube-bench on EKS |
| **Container runtime** | containerd on immutable Talos (or the EKS AMI); no access to the containerd socket (host paths blocked by Pod Security and Kyverno); seccomp RuntimeDefault; gVisor for CI runners; signed, attested images pinned by digest | Kyverno policy tests; Falco rules |
| **kube-proxy** | Replaced by Cilium on Talos; AWS-managed on EKS | `cilium status` (kube-proxy replacement) at home |
| **etcd** | Mutual TLS between members and clients (Talos default); three members; Secrets encrypted at rest; **snapshots stored only in the KMS-encrypted backup bucket** (and its Object Lock copy), readable only by the backup role and break-glass access; health alerts | `talosctl etcd members` and status; bucket policy review; Security Hub and Prowler bucket checks |
| **Pod Security Admission** | Per-namespace labels on **both clusters** (EKS doesn't enforce by default): **`restricted`** for application namespaces (WordPress, summarizer, gateway, model server, staging, tenants), **`baseline`** for most platform services, **`privileged`** only for node agents (Cilium, Falco, Alloy, the storage provisioner, the NVIDIA device plugin); `warn` and `audit` set to `restricted` everywhere | A pod violating `restricted` is rejected in an application namespace; namespace labels checked by a Kyverno rule |
| **Pod Security Standards** | Kyverno's **`restricted`** policy set for application namespaces (non-root, no privilege escalation, all capabilities dropped, seccomp, read-only root filesystem) and `baseline` elsewhere, alongside PSA (two independent enforcement points) | Kyverno CLI tests in CI; Policy Reporter |
| **Service accounts** | **Token mounting off by default** (`automountServiceAccountToken: false`, Kyverno mutate rule), enabled only for workloads that call the Kubernetes API (operators, Argo CD, KEDA, External Secrets); least-privilege RBAC for those | Kubescape RBAC review; a test pod has no token mounted |
| **Container network** | Cilium default-deny CiliumNetworkPolicies, DNS-name egress, layer-7 rules, WireGuard, Hubble (ADR 1027) | Connectivity and policy tests; Hubble drop alerts |
| **Storage** | **Talos disk encryption** for the system-state and data partitions on every node, **sealed to the TPM** (TPM 2.0 required); host paths only for the storage provisioner; EBS, RDS and S3 encrypted on AWS; S3 TLS-only; Object Lock backups | `talosctl get volumestatus` (or equivalent) shows encrypted partitions; Security Hub checks on AWS |

## Alternatives considered

- **Relying on Talos and EKS defaults without verification:** the defaults are good, but unverified claims don't hold up in an audit or interview; the checks make them evidence.
- **Kyverno only (no PSA labels):** one enforcement point; adding PSA gives a second, built-in one at almost no cost.
- **PSA only (no Kyverno restricted set):** the built-in controller can't produce reports or CI tests, and can't express project-specific rules.
- **Disk encryption with a static key or node ID instead of the TPM:** works on hardware without a TPM, but the key is less protected; TPM sealing is preferred where available.

## Consequences

- Every component has explicit controls and a repeatable check, recorded in the Talos hardening document and the security review.
- Workloads that need API access must opt in to a token, and anything new must meet `restricted` in application namespaces.
- Disk encryption depends on each node's TPM; replacing a node's TPM or motherboard needs the documented recovery procedure.

## When to revisit

- A node lacks TPM 2.0: use Talos's static-key option and record the weaker protection.
- Talos or EKS defaults change (re-run the checks after upgrades).

## Open items

- Phase 1 step 2.2: disk encryption, host firewall, `seccompDefault`, PSA defaults.
- Phase 1 step 6.1: PSA namespace labels, Kyverno `restricted` set, service-account token default.
- Phase 1 step 7.2: the verification checks, recorded in `docs/talos-hardening.md`.
- EKS: see ADR 3004.
