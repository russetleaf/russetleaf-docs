# Runbooks

Every runbook in the project, in one place: what each one is for, the build step that writes it, and how it is rehearsed. Runbooks are step-by-step procedures for when something is wrong. The reasons behind them are in the [architecture decision records](overview.md#architecture-decision-records), and this index is defined in [ADR 1046](phase-1-russetleaf-dev/adr/1046-incident-response-and-runbook-index.md).

!!! tip "In an incident"
    Start with **`incident-response.md`**: set the severity, open the incident thread in `#rl-critical`, and follow the runbook listed below for the situation. For anything security-related, preserve evidence before deleting or rebuilding anything.

## How runbooks are kept

- **Where they live:** with the code they operate, mostly in `russetleaf-gitops/docs/runbooks/` ([ADR 1038](phase-1-russetleaf-dev/adr/1038-documentation-repo-and-site.md)). That folder's `README.md` points back to this page, which is the only list.
- **Format:** every runbook follows `docs/runbooks/TEMPLATE.md` in `russetleaf-gitops`: Summary, Symptoms, Impact, Checks, Likely causes, Fixes, Escalation and Related ([Phase 1 step 4.4](phase-1-russetleaf-dev/plan.md#step-44-monitoring)).
- **Status:** **Planned** runbooks appear as plain paths. The step that writes a runbook turns its path into a link, sets its status to **Written**, and records the date of its first rehearsal; later drills update that date.
- **Alert runbooks** are named after their alert (`docs/runbooks/<alert>.md`) and linked from the alert's `runbook_url`. They are listed [by group](#alert-runbooks) rather than one by one.
- **Review:** quarterly, check this page against the runbooks folders, and check that every alert has a runbook ([Ongoing operations](phase-1-russetleaf-dev/plan.md#ongoing-operations-after-the-build)).

All paths below are in `russetleaf-gitops` unless stated otherwise.

## Start here

| Runbook | Use it when | Sites | Written in | Rehearsed | Status |
|---|---|---|---|---|---|
| `docs/runbooks/incident-response.md` | Anything is wrong: sets the severity (SEV1–3), the incident thread, the order of work and the hand-offs | Both | [Phase 1 step 4.4](phase-1-russetleaf-dev/plan.md#step-44-monitoring) | Tabletop twice a year | Planned |
| `docs/runbooks/emergency-change.md` | A SEV1 needs a cluster change and GitHub or Argo CD is down, or too slow to contain an attack | Both | [Phase 1 step 7.14](phase-1-russetleaf-dev/plan.md#step-714-incident-runbooks-and-tabletop-drills) | In staging, step 7.14; tabletop yearly | Planned |

## Security incidents

| Runbook | Use it when | Sites | Written in | Rehearsed | Status |
|---|---|---|---|---|---|
| `docs/runbooks/compromised-container.md` | A container is suspected compromised: freeze, contain, capture memory and files, export logs | Both | [Phase 1 step 7.13](phase-1-russetleaf-dev/plan.md#step-713-compromised-container-runbook-and-forensics-drill); EKS section in [Phase 3 step 5.1c](phase-3-russetleaf-com/plan.md#step-51c-forensic-hold-and-forensics-drill-on-eks) | Drill in staging, then yearly; once on EKS | Planned |
| `docs/runbooks/wordpress-compromise.md` | A rogue admin account, injected content or defacement: a compromise in the database (and the object cache), not the container | Both | [Phase 1 step 7.14](phase-1-russetleaf-dev/plan.md#step-714-incident-runbooks-and-tabletop-drills) | In staging, step 7.14 | Planned |
| `docs/runbooks/emergency-vulnerability.md` | A vulnerability is being exploited and no fix exists yet: a WAF rule to block it, remove the plugin, maintenance mode | Both | [Phase 1 step 7.14](phase-1-russetleaf-dev/plan.md#step-714-incident-runbooks-and-tabletop-drills); AWS WAF steps in [Phase 3 step 4.1](phase-3-russetleaf-com/plan.md#step-41-security-review) | In staging, step 7.14; once on EKS | Planned |
| `docs/runbooks/credential-leak.md` | A credential (token, key, kubeconfig) may have leaked: the credential inventory, then revoke, replace and check for use | Both | [Phase 1 step 4.2](phase-1-russetleaf-dev/plan.md#step-42-secrets-and-internal-certificates); LiteLLM keys added in [Phase 2 step 2.2](phase-2-ai-mlops/plan.md#step-22-litellm-gateway) | One credential revoked and replaced yearly | Planned |
| `docs/runbooks/supply-chain-compromise.md` | A CI workflow, runner, dependency or the signing identity may be compromised | Both | [Phase 1 step 7.14](phase-1-russetleaf-dev/plan.md#step-714-incident-runbooks-and-tabletop-drills) | Tabletop, step 7.14 | Planned |
| `docs/runbooks/under-attack.md` | A bot flood or DDoS: Cloudflare's "I'm Under Attack" level, tighter rate limits, CrowdSec, AWS WAF | Both | [Phase 1 step 7.14](phase-1-russetleaf-dev/plan.md#step-714-incident-runbooks-and-tabletop-drills); AWS WAF steps in [Phase 3 step 4.1](phase-3-russetleaf-com/plan.md#step-41-security-review) | In staging, step 7.14 | Planned |
| `docs/runbooks/personal-data-breach.md` | Personal data may have been exposed: assess, contain, record, notify within 72 hours if required | Both | [Phase 1 step 5.12](phase-1-russetleaf-dev/plan.md#step-512-compliance-scope-and-privacy-gdpr-basics) | Tabletop with the incident tabletops | Planned |

## Access

| Runbook | Use it when | Sites | Written in | Rehearsed | Status |
|---|---|---|---|---|---|
| `docs/runbooks/lost-access.md` | Sign-in fails (Dex, Google or Cloudflare Access down): using break-glass, and what to rotate afterwards | Home | [Phase 1 step 4.7](phase-1-russetleaf-dev/plan.md#step-47-cluster-access-oidc-sign-in-roles-and-sso) | Step 4.7, then with the break-glass kit check every 6 months | Planned |
| `docs/runbooks/wordpress-admin-access.md` | No one can sign in to WordPress's admin area: recover access with a one-off `wp-cli` Job, without passwords | Both | [Phase 1 step 5.8](phase-1-russetleaf-dev/plan.md#step-58-google-sign-in-for-admins) | Step 5.8 | Planned |
| `docs/runbooks/rotate-cluster-ca.md` | The Talos or Kubernetes CAs, the service-account key or the internal CA must be replaced (including after a break-glass credential leaks) | Home | [Phase 1 step 7.2](phase-1-russetleaf-dev/plan.md#step-72-trivy-operator-kubescape-scan-and-talos-hardening-notes) | Locally, then once on the real cluster | Planned |

## Recovery and maintenance

| Runbook | Use it when | Sites | Written in | Rehearsed | Status |
|---|---|---|---|---|---|
| `docs/runbooks/etcd-recovery.md` | etcd has lost quorum (two control-plane nodes down for good): recover from a snapshot | Home | [Phase 1 step 7.10](phase-1-russetleaf-dev/plan.md#step-710-first-full-disaster-drill) | Talos-in-Docker, step 7.10, then yearly | Planned |
| `docs/runbooks/replace-node.md` | A node must be repaired, reset or replaced, and rejoined to the cluster | Home | [Phase 1 step 7.11](phase-1-russetleaf-dev/plan.md#step-711-node-failure-drills) | Step 7.11 | Planned |
| `docs/runbooks/cold-start.md` | All three nodes lost power, or are being shut down for planned power work | Home | [Phase 1 step 7.11](phase-1-russetleaf-dev/plan.md#step-711-node-failure-drills) | Full power cut, step 7.11, then yearly | Planned |
| `docs/runbooks/upgrade-talos-kubernetes.md` | Upgrading Talos or Kubernetes: backups, rehearsal, one node at a time, when to stop | Home | [Phase 1 step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | Every upgrade | Planned |
| `docs/runbooks/terraform-state.md` (in `russetleaf-infra`) | A state lock is stuck, drift is found, or an earlier state version must be restored | Both | [Phase 1 step 2.4](phase-1-russetleaf-dev/plan.md#step-24-russetleaf-infra-ci) | Step 2.4 | Planned |

The scenarios these runbooks recover from, with data-loss and recovery-time targets, are in the [disaster recovery plan](phase-1-russetleaf-dev/disaster-recovery.md), which also has the bootstrap order for a rebuild from nothing.

## Rollback

One runbook per layer, from the [rollback strategy](phase-1-russetleaf-dev/design.md#rollback-strategy) ([ADR 1016](phase-1-russetleaf-dev/adr/1016-rollback-strategy.md)).

| Runbook | Layer | Written in | Rehearsed | Status |
|---|---|---|---|---|
| `docs/runbooks/rollback-applications.md` | WordPress and, from Phase 2, the summarizer | [Phase 1 step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | Monthly in staging | Planned |
| `docs/runbooks/rollback-platform.md` | Platform components (Loki, Argo CD, ...) | [Phase 1 step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | Monthly in staging | Planned |
| `docs/runbooks/rollback-configuration.md` | Overlays, policies, routing | [Phase 1 step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | Monthly in staging | Planned |
| `docs/runbooks/rollback-terraform.md` | Terraform changes | [Phase 1 step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | Monthly in staging | Planned |
| `docs/runbooks/rollback-talos.md` | Talos upgrades | [Phase 1 step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | Quarterly, locally | Planned |
| `docs/runbooks/rollback-kubernetes.md` | Kubernetes upgrades (restore from the pre-upgrade etcd snapshot) | [Phase 1 step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | Quarterly, locally | Planned |
| `docs/runbooks/rollback-secrets.md` | A rotation broke a service (`AWSPREVIOUS`) | [Phase 1 step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | Monthly in staging | Planned |
| `docs/runbooks/rollback-data.md` | Data loss or corruption: MariaDB, RDS and S3 restores, each followed by an object cache flush | [Phase 1 step 7.8](phase-1-russetleaf-dev/plan.md#step-78-rollback-runbooks-and-drills) | Monthly restore test | Planned |
| `docs/runbooks/rollback-cilium.md` | A broken Cilium upgrade (`helm rollback` from the workstation) | [Phase 1 step 3.1](phase-1-russetleaf-dev/plan.md#step-31-structure-and-argo-cd-bootstrap) | Quarterly, locally | Planned |
| `docs/runbooks/rollback-kyverno.md` | Kyverno blocking deployments (emergency webhook removal) | [Phase 1 step 6.1](phase-1-russetleaf-dev/plan.md#step-61-kyverno) | Quarterly, locally | Planned |
| `docs/runbooks/rollback-models.md` | A bad prompt or model (routing revert, re-summarize job) | [Phase 2 step 5.2](phase-2-ai-mlops/plan.md#step-52-observability-and-operations-for-the-ai-components) | With the Phase 2 drills | Planned |

## Privacy

| Runbook | Use it when | Written in | Status |
|---|---|---|---|
| `docs/runbooks/data-subject-request.md` | Someone asks for a copy of their data, or for it to be erased | [Phase 1 step 5.12](phase-1-russetleaf-dev/plan.md#step-512-compliance-scope-and-privacy-gdpr-basics) | Planned |

A personal-data breach is handled by `docs/runbooks/personal-data-breach.md`, listed under [security incidents](#security-incidents).

## russetleaf.com demo

| Runbook | Use it when | Written in | Rehearsed | Status |
|---|---|---|---|---|
| `docs/runbooks/demo-teardown-stuck.md` (in `russetleaf-infra`) | `demo-down` hangs or leaves resources behind (and costs) | [Phase 3 step 5.1](phase-3-russetleaf-com/plan.md#step-51-demo-workflows) | Step 5.1 | Planned |

The shared runbooks above gain EKS sections where russetleaf.com differs (forensics, AWS WAF).

## Alert runbooks

One runbook per alert, named after it. Each group is written in the step that adds its alerts:

| Group | Examples | Written in |
|---|---|---|
| Platform health, Cilium and Hubble | etcd, `ArgoCDAppOutOfSync`, certificate expiry, `CiliumAgentNotReady`, `HubblePolicyDropsSpike`, site down | [Phase 1 step 4.4](phase-1-russetleaf-dev/plan.md#step-44-monitoring) |
| Database, cache and backups | Database down, replication, backup older than expected, Valkey memory near its limit | [Phase 1 step 4.5](phase-1-russetleaf-dev/plan.md#step-45-database-and-cache) |
| Logging and Kubernetes audit | `LokiIngestionErrors`, `KubeExecIntoProdPod`, `KubeUnexpectedSecretRead`, `KubeAuditLogMissing` | [Phase 1 step 4.6](phase-1-russetleaf-dev/plan.md#step-46-logging-loki--alloy) |
| Break-glass | `KubeBreakGlassAdminUsed` | [Phase 1 step 4.7](phase-1-russetleaf-dev/plan.md#step-47-cluster-access-oidc-sign-in-roles-and-sso) |
| WordPress | `WordPressCronBacklog` and the chart's other alerts | [Phase 1 step 5.2](phase-1-russetleaf-dev/plan.md#step-52-wordpress-chart-and-deployment-russetleaf-gitopsappswordpress) |
| Runtime security | Falco allow-list and shell alerts, `FalcoNotRunning`, `FalcosidekickOutputErrors` | [Phase 1 step 7.1](phase-1-russetleaf-dev/plan.md#step-71-falco) |
| Compliance | `ComplianceFailuresIncreased` | [Phase 1 step 7.2](phase-1-russetleaf-dev/plan.md#step-72-trivy-operator-kubescape-scan-and-talos-hardening-notes) |
| Cost | `NamespaceDailyCostSpike` | [Phase 1 step 7.3](phase-1-russetleaf-dev/plan.md#step-73-opencost) |
| AI components | Summarizer, gateway and model alerts | [Phase 2 step 5.2](phase-2-ai-mlops/plan.md#step-52-observability-and-operations-for-the-ai-components) |
| EKS and AWS | The persistence alarms from the EKS audit log, the demo safety net | [Phase 3 step 1.4](phase-3-russetleaf-com/plan.md#step-14-eks-cluster), [Phase 3 step 5.1](phase-3-russetleaf-com/plan.md#step-51-demo-workflows) |
