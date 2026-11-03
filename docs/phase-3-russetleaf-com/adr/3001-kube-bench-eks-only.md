# ADR 3001: kube-bench on EKS only; Talos checked with its own hardening checks and Trivy Operator

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** both sites
- **Phase:** 3. In Phase 1, the home cluster relies on Trivy Operator, Kubescape and the Talos hardening checks ([ADR 1031](../../phase-1-russetleaf-dev/adr/1031-kubernetes-component-hardening.md)).

## Context

**kube-bench** checks a cluster against the **CIS Kubernetes Benchmark** by running on a node and inspecting configuration files, file permissions and process arguments (kubelet, API server, etcd) in the locations used by standard Linux distributions and kubeadm-style installs.

- **EKS (russetleaf.com):** AWS manages the control plane, and kube-bench has an **EKS profile** that checks the worker nodes (kubelet settings, file permissions) and some policy items; the control plane is AWS's responsibility under the shared-responsibility model.
- **Talos (russetleaf.dev):** Talos has no shell or SSH, an immutable read-only system, API-only management, and keeps its configuration in different locations. kube-bench's checks look for files and processes that do not exist there, so most fail or come back "not applicable", producing a noisy report that says little about Talos's real security. Talos is hardened by default (only Node and RBAC authorization, no anonymous kubelet access, webhook kubelet authorization, Pod Security `baseline`).

Both sites run **Trivy Operator**, which produces **CIS compliance reports** continuously from inside the cluster and can publish them as Prometheus metrics.

## Decision

- **EKS:** run kube-bench with the EKS profile on **every demo**, as a step in the `demo-up` workflow (not a CronJob or an Argo CD Application, since the cluster only exists for a few hours):
    - **one Job per node pool** (the managed node group and Karpenter's general pool), using node selectors and the GPU taint's toleration; each Job cleans itself up (`ttlSecondsAfterFinished`)
    - **JSON and text output**: the JSON lands in **Loki** automatically through Alloy (for a Grafana panel of pass/fail/warn counts per demo and node pool); both are kept as workflow artifacts
    - a summary committed to `docs/security/kube-bench-eks-<date>.md`, compared with an **accepted-findings file** (`docs/security/kube-bench-accepted.yaml`, each with a reason) so only new failures stand out
    - pass/fail/warn counts posted to `#rl-security`, flagging new failures
- **Talos:** do not run kube-bench. Instead:
    - `docs/talos-hardening.md` maps Talos's defaults to the relevant CIS controls, with **`talosctl` checks** (API server authorization config; kubelet configuration on each node) and an anonymous kubelet request that must return 401
    - **Trivy Operator's CIS compliance report**, reviewed monthly
- **Both sites:** Trivy Operator's **compliance metrics in Prometheus**, a **Grafana "Compliance" dashboard** covering both clusters, and an alert to `#rl-security` when the number of failing controls rises.

## Alternatives considered

- **kube-bench on Talos with custom path settings:** possible in principle, but Talos's layout and API-only design mean many checks still cannot be evaluated meaningfully; maintaining custom configuration for little real signal is not worth it.
- **Trivy Operator only, on both sites:** continuous and consistent, but less detailed on node-level configuration than kube-bench on EKS.
- **Kubescape's CIS framework:** reads the cluster through the Kubernetes API only, so it cannot inspect node files; used instead for NSA-CISA, MITRE ATT&CK and RBAC ([ADR 1003](../../phase-1-russetleaf-dev/adr/1003-kubescape-cli-not-operator.md)).
- **OpenSCAP for operating-system compliance (CIS or DISA STIG content):** it scans a conventional Linux host's packages and configuration files and does not cover the CIS Kubernetes Benchmark, so it would add to, not replace, the tools above. On **Talos** it has nothing to run on: there is no shell, SSH or package manager, the system is read-only, no SCAP content exists for Talos, and most checks (packages, PAM, sshd) do not apply. On the **EKS nodes** (Amazon Linux 2023) it could run, but the nodes are short-lived (Karpenter replaces them and the cluster is destroyed after each demo), so scanning the AMI before use would make more sense than scanning running nodes. Amazon Inspector's CIS scans are the AWS-native option if operating-system evidence is ever needed ([ADR 1019](../../phase-1-russetleaf-dev/adr/1019-aws-multi-account-sra.md) lists Inspector as a later addition; confirm its support for EKS nodes first). OpenSCAP fits clusters on RHEL or Ubuntu nodes, such as kubeadm or OpenShift (through its Compliance Operator), or work that requires STIG or FedRAMP evidence; neither applies here.
- **kube-bench results pushed to Prometheus (Pushgateway):** a once-per-demo result fits poorly in Prometheus, and the EKS Prometheus is destroyed at every `demo-down`; Loki (whose bucket survives teardown) and the committed summary hold the results instead.

## Consequences

- The two sites are checked by different tools; the reason is now documented rather than looking like an oversight.
- Node-level evidence at home is the `talosctl` checks plus Trivy Operator, partly manual.
- Every demo produces a kube-bench report per node pool automatically, with new failures highlighted.
- One Grafana dashboard shows continuous CIS compliance trends for both clusters.

## When to revisit

- kube-bench or the CIS project publishes Talos-specific checks.
- russetleaf.com moves to an always-on cluster: switch kube-bench to a scheduled CronJob with results also kept continuously.
- A compliance requirement demands the same tool on every cluster.

## Open items

- Phase 3 step 2.5: create the per-node-pool Job templates and the accepted-findings file; record the first results.
- Phase 1 step 7.2: confirm Trivy Operator's compliance metrics appear in Prometheus and the Compliance dashboard works.
