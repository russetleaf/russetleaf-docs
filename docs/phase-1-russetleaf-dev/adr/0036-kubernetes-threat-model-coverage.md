# ADR 0036: Kubernetes threat model coverage

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** both clusters

## Context
The design was checked against the common Kubernetes threat model, which groups threats into eight areas: trust boundaries and data flow, persistence, denial of service, malicious code execution, compromised applications in containers, attacker on the network, access to sensitive data, and privilege escalation.

Four areas were well covered: malicious code execution (signed images, Falco, gVisor, seccomp), compromised applications (non-root, read-only, no service-account token, Pod Security `restricted`, default-deny networking), attacker on the network (Cilium policies, WireGuard, internal TLS, lab VLAN) and access to sensitive data (encryption at rest, Secret access limited and alerted).

Four had gaps:
- **Trust boundaries and data flow:** described only in the Staff-tier threat model (home step 12.5), late in the build and not mapped to these areas.
- **Persistence:** nodes can't be changed (Talos), and Argo CD self-heal reverts changes to what it manages, but nothing flagged **new** objects created outside Argo CD (a CronJob, DaemonSet or admission webhook left behind by an attacker), and long-lived service-account token Secrets weren't blocked.
- **Denial of service:** quotas, memory limits and edge rate limits existed, but there was **no per-pod process (PID) limit** (a fork bomb could exhaust a node), no explicit eviction thresholds, no ephemeral-storage limits, and nothing watched the API server's request throttling.
- **Privilege escalation through RBAC:** Pod Security blocks container-based escalation, but nothing checked roles for **risky permissions** (`escalate`, `bind`, `impersonate`, `nodes/proxy`, wildcards, or `create pods` where powerful service accounts run), especially in third-party charts.

## Decision
- **Trust boundaries and data flows** are drawn now in `aws-wp.md` ([Kubernetes threat model coverage](../../aws-wp.md#kubernetes-threat-model-coverage)), with a table mapping each of the eight areas to its controls and tests. The STRIDE threat model (home step 12.5) adds a cross-check against the eight areas.
- **Persistence:**
  - Argo CD **AppProjects warn about orphaned resources** (objects in managed namespaces that Argo CD doesn't own), shown in the UI and sent to `#rl-security` through Argo CD Notifications.
  - New audit alerts: **`KubeWorkloadCreatedOutsideArgoCD`** (Pods, Deployments, DaemonSets, StatefulSets, Jobs or CronJobs created in production or platform namespaces by anyone other than Argo CD and the expected controllers), **`KubeAdmissionWebhookChanged`** (validating or mutating webhook configurations created, changed or deleted by anyone other than Argo CD and the components that manage their own webhooks, such as Kyverno and cert-manager's CA injector) and **`KubeTokenSecretCreated`** (a long-lived service-account token Secret).
  - Kyverno **blocks** Secrets of type `kubernetes.io/service-account-token` outside an allow-list (none expected).
- **Denial of service:**
  - **kubelet limits** on every node: `podPidsLimit` (e.g. 4096; tuned after measuring), and **hard eviction thresholds** for memory, disk and inodes, alongside the existing `systemReserved` and `kubeReserved`.
  - **Ephemeral storage:** the namespace LimitRange sets default ephemeral-storage requests and limits, and the ResourceQuota caps the namespace total.
  - **API server throttling:** keep Kubernetes' **API Priority and Fairness** defaults, and alert (`KubeAPIRequestsRejected`) when the API server rejects requests because of it.
- **Privilege escalation through RBAC:**
  - A Kyverno policy **rejects** Roles and ClusterRoles that grant `escalate`, `bind` or `impersonate`, access to `nodes/proxy`, or wildcard verbs or resources, and bindings to `cluster-admin`, except for a named allow-list (Kubernetes' own roles, Argo CD, the `platform-admin` role, and third-party components that genuinely need them, each with a reason).
  - **CI:** `wp-gitops` runs Kubescape's RBAC controls on the rendered manifests, so a chart upgrade that adds a risky permission fails the pull request or needs an accepted-finding entry.
  - **Live review:** the monthly Kubescape scan lists who can create pods, read Secrets or reach nodes in each namespace; accepted findings are recorded in `docs/security/rbac-accepted.yaml`.
- **Exfiltration test:** the network-policy tests include trying to send data from each application pod to an unlisted destination (blocked, and visible in Hubble).

## Alternatives considered
- **Leave it to the Staff-tier threat model:** the gaps are small, cheap controls; waiting until the end leaves them open for most of the build.
- **OPA Gatekeeper for RBAC rules:** works, but adds a second policy engine; Kyverno already validates any resource kind.
- **Blocking all objects not created by Argo CD:** strongest against persistence, but breaks controllers (operators, KEDA, the HPA) that create objects legitimately; detecting and alerting is enough here.
- **Custom API Priority and Fairness levels:** not needed at this scale; the defaults already protect the API server from one noisy client.

## Consequences
- Each of the eight threat areas has named controls, a detection, and a test.
- A few more audit alerts to tune: controllers that create objects (operators, KEDA, Argo Rollouts, the MariaDB Operator) go on the expected-identity list.
- Third-party charts with broad RBAC need allow-list entries with reasons; some upgrades will need a review.
- The PID limit must be high enough for PHP-FPM or Apache workers and the model server; it's measured before enforcing.
- About **8–9 hours** more across the two plans.

## When to revisit
- A workload legitimately needs more processes than the PID limit allows.
- Kubernetes adds built-in protections that make a custom rule redundant (e.g. stricter defaults for token Secrets).
- The cluster gets other users or tenants: consider custom API Priority and Fairness levels per tenant.

## Open items
- Home plan step 2.2: kubelet PID limit and eviction thresholds.
- Home plan step 3.1: orphaned-resource warnings in Argo CD AppProjects.
- Home plan step 4.6: the three persistence alerts.
- Home plan step 4.4: `KubeAPIRequestsRejected`.
- Home plan step 6.1: RBAC policy, token-Secret block, ephemeral-storage defaults, Kubescape RBAC check in CI.
- Home plan steps 6.3 and 10.2: exfiltration test; RBAC review and accepted findings.
- Home plan step 12.5: map the threat model to the eight areas.
- AWS plan steps 1.4 and 2.3: kubelet limits on EKS nodes; the persistence alerts from the EKS audit log; step 5.1 checks.
