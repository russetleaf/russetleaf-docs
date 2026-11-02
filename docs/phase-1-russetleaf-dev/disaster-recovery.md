# Disaster Recovery Plan (russetleaf.dev, and russetleaf.com in Phase 3)

This plan covers recovering from losses bigger than a single bad change or failed component. Rolling back changes is covered by the [rollback strategy](design.md#rollback-strategy) (ADR 1016), and everyday availability by ADR 1014. The decisions behind this plan are recorded in `docs/phase-1-russetleaf-dev/adr/1018-disaster-recovery.md`.

**Principle:** everything that can be rebuilt is rebuilt from code (Terraform, GitOps, image builds). Everything that can't (data, secrets that can't be regenerated, account access) has a copy **outside the main AWS account and region**, in storage that can't be deleted or overwritten for 30 days, plus a **break-glass kit** for access.

## What exists, and where its copies are

| Asset | Primary location | Independent copy | Retention of the copy | Rebuildable instead? |
|---|---|---|---|---|
| Infrastructure | `wp-infra` (GitHub) | Repo mirror in the backup account | 90 days of daily bundles | Yes, from Terraform |
| Deployed configuration | `wp-gitops` (GitHub) | Repo mirror in the backup account | 90 days | Yes, from GitOps |
| Application code | `wp-image` (and `llm-summarizer` from Phase 2) (GitHub) | Repo mirrors in the backup account | 90 days | Yes |
| Images and charts | GHCR | None needed | — | Yes, rebuilt from the mirrored source |
| Terraform state | S3 state bucket (us-east-1, **russetleaf-infra** account) | **Replicated** to the backup account (us-west-2, Object Lock) | 30-day lock, versions kept 90 days | Partly (state can be re-imported, but slowly) |
| russetleaf.dev database | MariaDB backups in S3 (us-east-1), every 6 hours | **Replicated** to the backup account (Object Lock) | 30-day lock | No |
| russetleaf.com database *(Phase 3)* | RDS snapshots (us-east-1) | A **logical dump** taken at every `demo-down`, written to the russetleaf.com backup bucket and **replicated** to the backup account | 30-day lock | No (or re-seed from russetleaf.dev) |
| Media (both sites) | S3 media buckets (us-east-1) | **Replicated** to the backup account (Object Lock) | 30-day lock | No |
| CloudTrail logs | Organization trail in the **Log Archive** account's Object Lock bucket (separate from every workload account) | Already isolated; optionally replicated to us-west-2 | 30-day lock (longer retention by lifecycle) | No |
| Cluster state (etcd snapshots; contain every Secret) | Weekly snapshots in the KMS-encrypted backup bucket (russetleaf-home), readable only by the backup role | **Replicated** to the Backup account (Object Lock) | 30-day lock | Partly (GitOps rebuilds workloads; the snapshot speeds recovery) |
| Talos machine secrets, talosconfig (and the disk-encryption recovery procedure for each node's TPM) | Terraform state; your workstation | Break-glass kit | Until rotated | No (losing them means rebuilding the cluster from scratch) |
| Secrets in Secrets Manager | The workload accounts (russetleaf-home; russetleaf-com in Phase 3) | Most are **regenerated** rather than copied (see below) | — | Mostly yes |
| Account access (root logins, MFA recovery codes) | Password manager | Break-glass kit, including a printed copy | Until changed | No |
| Logs and traces (Loki, Tempo) | S3 | None (short-lived operational data) | — | Not needed |

**Secrets that are regenerated, not copied:** database passwords (MariaDB Operator generates new ones; RDS manages its own), the Cloudflare tunnel token, the Slack bot token, Google OAuth client secrets, scoped IAM keys, the WordPress application passwords. The break-glass kit holds only what can't be regenerated (account access and the Talos secrets bundle).

## Backup account and immutable copies
- A separate **Backup** account in the **Security OU** of the AWS Organization (whose **dedicated management account** runs nothing; see ADR 1019 and the Phase 1 design's [AWS account structure](design.md#aws-account-structure-and-best-practices-security-reference-architecture)). Nothing runs in it; it only holds copies.
- Its buckets are in a **second region (us-west-2)** with **S3 Object Lock** (30-day retention, governance mode at first, compliance mode once proven), versioning and encryption.
- Buckets in **russetleaf-home**, **russetleaf-infra** and (in Phase 3) **russetleaf-com** **replicate** into them (S3 replication with roles that can only write, not delete); SCPs stop any account from deleting or weakening them.
- Access to the backup account is through a separate login (IAM Identity Center permission set) that's part of the break-glass kit, so a compromise of a workload account doesn't reach it.
- **Cost:** a few cents a month at this data size, plus replication requests.

## Repo mirrors
A scheduled GitHub Actions workflow (daily) creates a `git bundle` of each of the four repos and uploads it to a bucket in the backup account, using an OIDC role that can only **write** new objects. Images and charts aren't copied: they're rebuilt from the mirrored source.

## Break-glass kit
Kept in your password manager, with a **printed copy** of the starred items stored somewhere safe at home and ideally a second location (e.g. with a family member).

- ★ AWS: the **management account's** root email, password and **MFA recovery** (member accounts have no root credentials: centralized root access management); the IAM Identity Center admin and break-glass logins
- ★ GitHub: account login and **recovery codes**
- ★ Cloudflare: account login and recovery codes
- ★ Google: account recovery (for the Google Cloud project and Google sign-in)
- ★ Domain registrar logins for russetleaf.com and russetleaf.dev
- ★ Password manager's own emergency kit
- Talos secrets bundle (`secrets.yaml`), the `os:admin` talosconfig, and the Talos-generated **break-glass admin kubeconfig** (use of it raises an alert)
- Where every backup is (this document's table), and the order of recovery (below)
- Slack workspace owner login

## Scenarios

| Scenario | Data lost (at most) | Time to recover | Procedure |
|---|---|---|---|
| **Any one box fails** (disk or hardware) | Seconds of database changes (replication lag) | About a minute for the site (failover); hours to replace the box | Nothing urgent: etcd keeps quorum, the virtual IP moves, MariaDB fails over to its replica, and WordPress, ingress and cloudflared keep running on the other nodes. If it was box 2, the gateway falls back to Bedrock. Repair or replace the box, re-apply `wp-infra/envs/home` for it, and let it rejoin; MariaDB rebuilds its replica. |
| **Two boxes fail at once** | Up to 6 hours of database changes, if the remaining box doesn't hold a current database copy | Hours to a day | etcd loses quorum, so the cluster stops. Repair one box to restore quorum (or, if two are lost for good, recover etcd from the latest snapshot with `talosctl` on the remaining node, then rejoin new boxes); restore MariaDB from replication or the latest S3 backup. |
| **Whole home lab destroyed** (fire, theft, flood) | 6 hours of database changes | 1–2 days (new hardware) | Using only the break-glass kit and the backups: get new hardware; follow the **bootstrap order** below. In Phase 3, russetleaf.com can be brought up as a temporary replacement in the meantime (`demo-up` and seed from the latest russetleaf.dev backup). |
| **Workstation lost** | None | Hours | Set up a new workstation ([workstation setup](plan.md#local-workstation-setup-ubuntu-2404)); restore talosconfig, kubeconfig and logins from the break-glass kit; rotate anything that was stored only on the old machine. |
| **A workload account compromised** (russetleaf-home or russetleaf-com) | Up to the last replicated copy | 1–3 days | From the management and Security Tooling accounts: restrict the account with an SCP, revoke its sessions and keys, review the organization CloudTrail (Log Archive) and GuardDuty/Security Hub findings. If data was deleted or encrypted, restore from the **Backup** account. Rotate every secret and key; re-create Secrets Manager entries; re-apply Terraform. The logs, backups and security tooling are in other accounts, so they're intact. |
| **A workload account lost** (closed, locked) | Up to the last replicated copy | Days | Create a replacement account in the Organization (`envs/org`); re-apply `bootstrap/` and the environment; restore data from the Backup account; regenerate secrets. |
| **Management account compromised or lost** | Up to the last replicated copy | Days | The worst case: recover access through AWS Support using the break-glass kit; the member accounts, logs and backups keep running meanwhile. If the Organization can't be recovered, create a new management account and move the member accounts into a new Organization. |
| **AWS region outage** (us-east-1) | None, or up to the last replicated copy | Hours to wait, or a day to move | Usually wait it out (russetleaf.dev keeps running at home, though S3 media, SQS and Bedrock calls fail). For a long outage, re-point the home site's buckets and queue to us-west-2 using the replicated copies. |
| **GitHub account or repos lost** | Commits since the last daily mirror | Hours | Restore the repos from the bundles in the backup account to a new GitHub account (or another Git host); update Argo CD's repo URLs, the OIDC trust (new repo identities) and Kyverno's signing identities; rebuild and re-sign images. |
| **Cloudflare account lost** | None | Hours | New account; re-apply the Cloudflare parts of `envs/home` (tunnel, DNS, Access, rules); move russetleaf.dev's name servers. |
| **Domain lost or expired** | None | Days (registrar process) | Recover through the registrar; keep auto-renew on and the registrar login in the break-glass kit to prevent this. |
| **Ransomware or malicious deletion of backups** | Up to the last locked copy | 1–2 days | The Object Lock copies can't be deleted or overwritten for 30 days; restore from them. |

## Bootstrap order from zero
1. **Access:** password manager → break-glass kit → AWS (management account, then IAM Identity Center into the others), GitHub, Cloudflare, Google, registrar.
2. **Code:** restore the four repos (from GitHub, or the mirrors in the backup account).
3. **Terraform state:** use the russetleaf-infra state bucket, or copy it back from the Backup account.
4. **Account foundations:** apply `wp-infra/envs/org/` (Organization, accounts, SCPs, Identity Center) and `envs/security/` (CloudTrail, GuardDuty, Security Hub, Config), then `bootstrap/` (state bucket, CI roles).
5. **Home infrastructure:** apply `wp-infra/envs/home` (Talos on all three boxes, Cloudflare, the AWS resources used from home).
6. **Secrets:** create or regenerate the entries in Secrets Manager; create the External Secrets bootstrap credential.
7. **GitOps:** install Argo CD and apply `wp-gitops/bootstrap/home`; let the platform come up in sync-wave order.
8. **Data:** restore MariaDB from the latest backup (from russetleaf-home or the Backup account); confirm media is present (or copy it back).
9. **Images:** if GHCR is unavailable, rebuild and re-sign the images from source, and update the version pins.
10. **Checks:** site, admin sign-in, the summarizer (Phase 2), monitoring and alerts, backups running again.
11. **russetleaf.com** (Phase 3, if needed): re-apply `envs/aws-edge`, then `demo-up` when wanted.

## Drills
| Drill | How often | What it proves |
|---|---|---|
| Restore a MariaDB backup into a scratch instance | Monthly | Backups are usable |
| Restore a MariaDB backup **from the backup account's copy** | Quarterly | The off-account copies are usable and access works |
| **Full "home lab destroyed" rebuild**, using only the break-glass kit and the backups (on a local Talos-in-Docker cluster, or the real boxes during a maintenance window) | Yearly | The whole plan works; record the actual time |
| *(Phase 3)* Restore russetleaf.com's database from the latest logical dump in the backup account | Once (then yearly) | The AWS-side copy works |
| Check the break-glass kit (logins work, recovery codes valid, printed copy current) | Every 6 months | Access can be recovered |

Each drill's result and time are recorded in the decision log; this document is updated whenever a drill finds something wrong.
