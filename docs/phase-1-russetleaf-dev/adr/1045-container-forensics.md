# ADR 1045: Preserve evidence from a compromised container before containing and rebuilding it

- **Status:** Accepted
- **Date:** 2026-11-03
- **Applies to:** both sites (one shared runbook, with a section for each)
- **Phase:** 1 (the runbook, toolkit, quarantine policy and evidence bucket; a drill at home). Later: Phase 3 adds the EKS node steps, a forensic hold in the demo workflows, and a drill on EKS.

## Context

The design detects a compromised container in several ways: Falco's process allow-lists and shell rules ([ADR 1015](1015-process-allow-listing.md)), the Kubernetes audit alerts and GuardDuty ([ADR 1017](1017-intrusion-detection-and-prevention.md)), Hubble's DNS records, and the persistence alerts ([ADR 1034](1034-kubernetes-threat-model-coverage.md)). It also has a personal-data breach runbook ([ADR 1036](1036-compliance-frameworks-and-privacy.md)), a Suspended OU for containing an AWS account ([ADR 1019](1019-aws-multi-account-sra.md)), and rollback runbooks for every layer ([ADR 1016](1016-rollback-strategy.md)). Nothing says what to do between "Falco alerted" and "rebuild from Git".

Without that step, both the operator's first instinct and the platform's own automation destroy the evidence:

- **Deleting or restarting the pod** loses its memory, its processes and its writable layer.
- **Argo CD self-heal** reverts any manual change to the workload, such as a quarantine label or a changed selector.
- **Karpenter consolidation** can remove an EKS node on its own, and a **spot interruption** removes it with two minutes' warning.
- **`demo-down`** and the **demo safety net** destroy the whole EKS stack; rebuilding it is the documented rollback path.
- **Log retention** is short: Loki keeps 7 days at home and 14 on EKS, and the Hubble DNS records keep 7.

Each platform also limits what can be collected:

- **Talos** has no SSH and no shell, enforces signed kernel modules (so memory-capture modules such as LiME cannot be loaded), and encrypts its disks with keys sealed to each node's TPM, so a disk image is unreadable away from its node.
- **gVisor** pods (the CI runners, and WordPress if its trial passes; [ADR 1009](1009-gvisor-sandboxing.md)) run their processes inside gVisor's user-space kernel, so the host's normal process tools do not see into them.
- **Kyverno** admits only signed images and enforces Pod Security ([ADR 1013](1013-image-supply-chain.md), [ADR 1031](1031-kubernetes-component-hardening.md)), so forensic tools cannot be pulled in on the day. On EKS, the DNS Firewall allow-list also blocks downloads from unknown domains.
- The account structure has **no forensics account** and no bucket meant for evidence.

## Decision

**One runbook for both sites**, `docs/runbooks/compromised-container.md` in `russetleaf-gitops`, linked from every Falco, audit and GuardDuty runbook that can mean a compromised container. It has shared steps and a short section for each site. The order is **freeze, contain, capture, export, hand off**, collecting the most volatile evidence first:

1. **Freeze the automation:** turn off auto-sync and self-heal on the root Argo CD Application and then on the affected one (the root app would otherwise restore the child's sync policy). On EKS, also annotate the node `karpenter.sh/do-not-disrupt: "true"` and set the **forensic hold** (below).
2. **Contain without killing:**
    - Label the pod `rl/quarantine=true`. A **pre-staged `CiliumClusterwideNetworkPolicy` with `ingressDeny` and `egressDeny` rules** cuts off every pod with that label. Deny rules take precedence over the workload's existing allow rules.
    - Remove the label its ReplicaSet (or Rollout) selects on. This takes the pod out of its Service and orphans it, so a clean replacement starts and the site keeps serving.
    - Cordon the node. Do not drain it.
3. **Capture, most volatile first,** with a privileged **forensics toolkit pod** on the same node:
    - process memory (`gcore` on every process in the container's cgroup)
    - network state (sockets and connections from the container's network namespace; a short packet capture with `talosctl pcap` at home or `tcpdump` on EKS)
    - the process list with command lines, environment variables and open files
    - the container's writable layer (the overlay `upperdir`) and its `emptyDir` volumes, compared with the image
    - the pod's YAML, events and image digest, and the node's `dmesg`
    - a dump of the Valkey object cache (`valkey-cli --rdb`) if the pod could write to it, since a poisoned cache keeps serving the attacker's content after the database is clean
4. **Export the logs before they expire:** Falco's alerts, Hubble's flows and DNS records, and the workload's logs from Loki for the incident window. Write down the audit-log time range (the audit logs are already kept for 1 year), and on EKS the VPC flow log and Resolver query log ranges.
5. **Keep the chain of custody:** a SHA-256 hash for every file, a notes file (who did what, when, and from which machine), and everything uploaded from the workstation to the **evidence bucket**.
6. **Hand off:** to the personal-data breach runbook (its 72-hour clock may already have started), to credential rotation (the pod's Secrets and any keys it could reach, through the secret rollback runbook), and to a postmortem. Only then flush the object cache, delete the quarantined pod and turn automation back on.

**Prepared in advance**, because none of it can be built during an incident:

- **Forensics toolkit image** (`rl-forensics`): a minimal image with `gdb` (for `gcore`), `procps`, `iproute2`, `lsof`, `tcpdump`, `tar` and `coreutils`. It is built, signed and attested by the same supply-chain workflow as the WordPress image, so Kyverno admits it unchanged.
- **`forensics` namespace:** empty normally, labeled `privileged` for Pod Security. A **Kyverno `PolicyException`** allows only the toolkit image (pinned by digest) to run there with `hostPID`, `privileged` and a read-only `hostPath` mount of `/var`. Only `platform-admin` can create pods there ([ADR 1033](1033-identity-and-access.md)). Creating one raises `KubeWorkloadCreatedOutsideArgoCD`, which is intended: every use is recorded.
- **Quarantine policy:** the `CiliumClusterwideNetworkPolicy` above, deployed from Git and matching no pods until one is labeled.
- **Evidence bucket:** `rl-forensic-evidence` in the **Log Archive** account, with versioning, SSE-KMS and **S3 Object Lock** (governance mode at first, like the other locked buckets; [ADR 1042](1042-s3-versioning-lifecycle-and-storage-classes.md)), keeping evidence for **1 year**. Uploads come from the workstation through a write-only Identity Center permission set. Reading needs the security permission set. Nothing in either cluster holds credentials for it.

**Site-specific steps:**

| | Home (Talos) | EKS (aws.russetleaf.dev demo) |
|---|---|---|
| Node access | `talosctl` (`containers -k`, `logs`, `dmesg`, `processes`, `netstat`, `pcap`, `read`, `support`) plus the toolkit pod. No shell on the node | The toolkit pod, plus **SSM Session Manager** on the node. The SSM permission is attached to the node role only during an incident |
| Whole-node memory | **Not captured.** Signed modules rule out LiME. Container process memory is the scope | **AVML** through SSM, uploaded straight to the evidence bucket with a presigned URL |
| Disk | **Not imaged** (TPM-sealed). The writable layer and volumes are copied from the running node | **EBS snapshot** of the node's volume, tagged `ForensicHold=true`, kept in the russetleaf-aws account |
| Node isolation | If the node itself is suspected (a container escape): capture first, then disconnect its network cable. etcd keeps quorum with the other two nodes ([ADR 1020](1020-three-node-ha-home-cluster.md)) | Swap the instance's security groups for an **isolation security group** with no rules, and turn on **termination protection** |
| gVisor pods | Memory and process state through gVisor's own tools (`runsc debug`, `runsc checkpoint`), from the toolkit pod with access to the runtime's state directory | Not applicable (gVisor is home only) |
| Automation to hold | Argo CD | Argo CD, Karpenter, and the **forensic hold**: `demo-down` and the safety net refuse to destroy the stack while any resource in it is tagged `ForensicHold=true`; the safety net still alerts |

## Alternatives considered

- **No runbook; rebuild from Git and rely on the central logs:** the logs (audit, CloudTrail, Falco, Hubble DNS) show what happened around the container, but not what ran inside it: the attacker's payload, any credentials in memory, or files written to temporary volumes. Recovery would be just as fast without the evidence, but nothing would be learned for the postmortem or the threat model.
- **Kubernetes container checkpointing** (the kubelet's checkpoint API, with CRIU): captures memory and filesystem together in one call, and the result can be restored in a sandbox. Talos does not ship CRIU, so it cannot be relied on at home. Worth checking for EKS, and at home if a Talos extension appears.
- **Ephemeral debug containers** (`kubectl debug --target`): convenient, but they change the compromised pod's own spec, share its namespaces (a compromised process could interfere with them), and need Kyverno exceptions for every application namespace instead of one `forensics` namespace.
- **A dedicated Forensics account** (the SRA pattern, for analyzing evidence in isolation): cleaner separation, but another account to run for one operator. A locked bucket in Log Archive gives the same tamper resistance. Revisit if analysis ever needs its own compute.
- **GuardDuty Runtime Monitoring or a commercial tool** with built-in evidence collection: EKS only, extra cost per node, and duplicates Falco ([ADR 1017](1017-intrusion-detection-and-prevention.md)).
- **Separate runbooks for each site:** the freeze, contain, export and hand-off steps are identical on both sites. Two documents would drift apart.
- **Copying EKS snapshots to Log Archive:** better protected against a compromised russetleaf-aws account, but cross-account snapshot copies need the KMS key shared with Log Archive. A compromise of the account itself is handled by moving it to the Suspended OU, which also stops any deletion.

## Consequences

- An incident leaves evidence behind: process memory, network state, files written by the attacker, and a hashed, tamper-resistant record of it all.
- Containment no longer depends on deleting the pod. The site keeps serving from a clean replacement while the evidence is collected.
- A privileged toolkit and a `PolicyException` exist permanently. They are narrow (one namespace, one image digest, `platform-admin` only, an alert on every use) and are reviewed like any other exception.
- Memory dumps can contain personal data (commenters' email addresses, session cookies). The evidence bucket goes into the record of processing and the retention schedule, with access limited to the security permission set.
- The demo workflows gain a check that can block `demo-down`. A held stack keeps costing about $0.70 an hour, so the hold must be released once capture is done (the safety net keeps alerting until then).
- New work: the toolkit image and its tests, the quarantine policy, the evidence bucket and permission sets, the runbook, and a drill on each site.

## When to revisit

- Talos ships CRIU (or an extension for it), or the kubelet checkpoint API works on the home cluster: consider checkpointing as the main capture method.
- Evidence analysis needs its own compute, or aws.russetleaf.dev becomes always-on or holds user data: consider a dedicated Forensics account.
- Tetragon enforcement is adopted ([ADR 1015](1015-process-allow-listing.md)): an unlisted process would be killed before it could be captured, so decide whether Tetragon should alert only for some workloads.
- A real incident shows a gap in the runbook.

## Open items

- Phase 1 step 7.13: the toolkit image, `forensics` namespace and `PolicyException`, the quarantine policy, the evidence bucket and permission sets, the runbook, and the first drill at home (including a gVisor pod). Decide which repo builds the toolkit image.
- Phase 1 step 7.13: confirm that `gcore` works on a WordPress process from the toolkit pod under Talos, and whether `runsc checkpoint` can be run from a pod.
- Phase 1 step 7.13: add the evidence bucket to the record of processing and the retention schedule ([ADR 1036](1036-compliance-frameworks-and-privacy.md)).
- Phase 3 step 5.1c: SSM and AVML on the EKS nodes, the isolation security group, the forensic hold in `demo-down` and the safety net, and a drill on EKS. Check whether the kubelet checkpoint API works there.
