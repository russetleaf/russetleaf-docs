# ADR 1035: Platform security: admission resilience, cluster PKI, registry, observability access and VEX

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** both clusters, GHCR, the observability stack
- **Phase:** 1. Later: Phase 2 adds the summarizer's signing identity; Phase 3 adds the EKS checks.

## Context
The design was checked against the common platform security topics: supply chain security, the image repository, observability, service mesh, Kubernetes PKI, mutual TLS and admission controllers.

Supply chain security was strong (signed images with SBOM and SLSA provenance verified at admission, signed charts pinned by digest, mirrored upstream images). Service mesh and mTLS were covered by ADR 1001 (no mesh; WireGuard plus TLS on every sensitive connection, with the lack of per-service identity stated). The rest had gaps:
- **Admission controllers:** Kyverno's replica count, failure behavior and webhook timeouts weren't decided; if Kyverno was down or misconfigured, nothing built into Kubernetes backed up its most important rules; the enabled admission plugins weren't checked on EKS.
- **Kubernetes PKI:** Talos manages the cluster CAs and rotates leaf certificates, but the kubelets' **serving certificates are self-signed** by default, so metrics-server and Prometheus would skip verification (`--kubelet-insecure-tls`); there was no **CA rotation** procedure, no expiry alerts for Talos- and Kubernetes-managed certificates, and the **talosconfig client certificate expires after a year** with nothing to remind anyone.
- **Image repository:** GHCR package permissions and a cleanup policy weren't set down; a careless cleanup could delete an image needed for rollback.
- **Observability:** Loki holds the API audit log, Falco events and Argo CD audit events, and Grafana's free edition can't restrict data sources, so any Grafana user could read them. Loki, Prometheus, Tempo and Alertmanager have no authentication inside the cluster.
- **Supply chain (small):** accepted vulnerabilities were recorded only in `.trivyignore`, which other tools can't read.

## Decision
- **Admission controllers:**
  - Kyverno's **admission controller runs three replicas**, spread across the three nodes (topology spread constraints), with a PodDisruptionBudget; the background, reports and cleanup controllers stay at one replica each.
  - Security policies **fail closed** (`failurePolicy: Fail`): if Kyverno can't answer, the request is rejected rather than admitted unchecked. The existing namespace exclusions (`kube-system`, `kyverno`, `argocd`) and the emergency runbook keep recovery possible. Webhook timeouts are short (e.g. 5 seconds) so a slow Kyverno fails fast.
  - **Built-in backstop:** a few critical rules are also written as Kubernetes **ValidatingAdmissionPolicies** (CEL, evaluated in the API server, no webhook): images only from the allowed registries, no bindings to `cluster-admin` outside the allow-list, and no long-lived service-account token Secrets. They still apply if Kyverno is down or its webhooks are deleted in an emergency.
  - The **enabled admission plugins** are checked on both clusters (home: the API server's arguments through `talosctl`; EKS: AWS's documented list for the version) and recorded in `docs/talos-hardening.md` and the EKS security review: NodeRestriction, PodSecurity and the validating and mutating webhook plugins on; `AlwaysAdmit` off.
- **Kubernetes PKI:**
  - **kubelet serving certificates** signed by the cluster CA: Talos's `rotate-server-certificates` kubelet setting plus a CSR approver for kubelet serving certificates (installed with the cluster), so metrics-server runs **without** `--kubelet-insecure-tls` and Prometheus verifies the kubelet's certificate. (EKS already signs them.)
  - **Expiry alerts:** kubelet client and serving certificate lifetimes (kubelet metrics) and the API server's client-certificate expiry alerts from kube-prometheus-stack, alongside cert-manager's alerts for the internal CA (ADR 1028).
  - **talosconfig renewal:** the day-to-day and break-glass talosconfigs are renewed every year, before their client certificates expire; a calendar reminder and a check in the 6-monthly break-glass kit review.
  - **CA rotation runbook** (`docs/runbooks/rotate-cluster-ca.md`): rotating the Talos and Kubernetes CAs with `talosctl rotate-ca`, rehearsed on a local Talos-in-Docker cluster and then once on the real cluster; the service-account signing key (Talos's documented procedure, if the version supports it; otherwise the manual steps); and the internal CA's intermediate and root (overlapping bundles through trust-manager). Used if a CA key may have been exposed, e.g. a lost break-glass kit.
  - On EKS, the cluster PKI is AWS's responsibility; this is stated in the security review.
- **Image repository (GHCR):**
  - Each package is **linked to its repo**, with write access only for that repo's Actions; no personal access tokens with `write:packages`; only the account owner can delete packages.
  - A monthly **cleanup workflow** deletes untagged versions older than 90 days, but **never** a digest referenced anywhere in `russetleaf-gitops` in the last 90 days or one of the last 10 releases; signatures and attestations are kept with their images. It runs in dry-run mode first.
  - The mirrored upstream images follow the same rules.
- **Observability access:**
  - Loki runs with **two tenants**: `apps` (application and platform logs) and `security` (API audit log, Argo CD audit events, Falco and Tetragon events). Grafana gets a separate **Security organization** holding the `security` data source and security dashboards; only the **platform-admin** group is a member (mapped from Dex groups).
  - Loki, Prometheus, Tempo and Alertmanager have no login inside the cluster; **network policies are their access control** (only Grafana, Alloy, Prometheus and the ruler can reach them), and none is exposed outside the cluster. Hubble UI is reachable only through Cloudflare Access (home) or port-forward (AWS).
- **Supply chain: VEX:** accepted vulnerabilities are recorded as **OpenVEX** statements (`.vex/` in `russetleaf-wordpress` and `russetleaf-llm-summarizer`), each with a justification and a review date, read by Trivy in CI (`--vex`) and attached to the image as a signed attestation; `.trivyignore` stays only for secret and misconfiguration findings.

## Alternatives considered
- **Kyverno fail-open:** keeps deployments flowing when Kyverno is down, but admits unchecked workloads; the exclusions and runbook already make fail-closed safe to recover from.
- **Replacing Kyverno with ValidatingAdmissionPolicies:** no webhook to fail, but CEL can't verify signatures or attestations, generate resources or mutate; used as a backstop only.
- **Grafana Enterprise data-source permissions:** solves observability access directly, but isn't free.
- **Authentication in front of Loki and Prometheus (an auth proxy):** stronger inside the cluster, but more moving parts; network policies already restrict who can connect.
- **Immutable tags in the registry:** GHCR doesn't offer them; digests in Git achieve the same for deployments.

## Consequences
- Kyverno is no longer a single point of failure for admission, and its most critical rules hold even without it.
- No component skips TLS verification to talk to the kubelet; CA compromise has a rehearsed answer.
- GHCR storage stays bounded without risking rollback images.
- Security logs are visible only to platform admins.
- About **200–300 MB** more memory for the extra Kyverno replicas, spread across nodes.
- About **9–12 hours** more across the two plans.

## When to revisit
- ValidatingAdmissionPolicy gains features that let it replace more Kyverno rules, or Kyverno generates them automatically for the rules used here.
- More people need Grafana: consider an auth proxy for Loki and Prometheus, or Grafana Enterprise features.
- GHCR adds tag immutability or retention policies.

## Open items
- Phase 1 step 2.2: kubelet serving certificates and the approver; metrics-server without insecure TLS.
- Phase 1 step 4.4: Prometheus verifies the kubelet's certificate; certificate expiry alerts.
- Phase 1 step 4.6: Loki tenants and the Grafana Security organization.
- Phase 1 step 5.1: GHCR package access, the cleanup workflow, VEX.
- Phase 1 step 6.1: Kyverno replicas, failure policy, timeouts, ValidatingAdmissionPolicy backstop.
- Phase 1 step 7.2: admission plugin check; CA rotation runbook and rehearsal.
- Phase 3 step 5.1: the same checks on EKS.
