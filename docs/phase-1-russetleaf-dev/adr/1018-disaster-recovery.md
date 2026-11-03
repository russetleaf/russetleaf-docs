# ADR 1018: Disaster recovery with off-account immutable copies and a break-glass kit

- **Status:** Accepted; updated by [ADR 1019](1019-aws-multi-account-sra.md)
- **Date:** 2026-11-01
- **Applies to:** both sites, the AWS accounts, and the supporting services (GitHub, Cloudflare, Google, domain registrars)
- **Phase:** 1. Later: Phase 3 adds russetleaf.com's logical dump at `demo-down` and its restore drill.

> **Update ([ADR 1019](1019-aws-multi-account-sra.md)):** The Organization now has a **dedicated management account** that runs nothing (rather than the workload account acting as management), and the Backup account sits in the **Security OU** alongside **Security Tooling** and **Log Archive**. CloudTrail logs are in the Log Archive account's locked buckets rather than replicated from a workload account. Member accounts have no root credentials (centralized root access management), so the break-glass kit holds only the management account's root access plus the Identity Center logins.

## Context

The design could already rebuild most things from code (Terraform, GitOps, image builds), back up the databases (MariaDB to S3 every 6 hours; RDS snapshots), version media, and roll back changes ([ADR 1016](1016-rollback-strategy.md)). But:

- **All recovery material was in one AWS account and one region**: backups, Terraform state, Secrets Manager, CloudTrail. An account compromise, a closed account, or a long regional outage could take the backups with it.
- **No scenarios were written down** beyond single-component failures.
- **Recovery depended on unbacked-up access**: AWS root and MFA recovery, GitHub and Cloudflare recovery codes, Google access, registrar logins, Talos secrets.
- **No bootstrap order from zero**, and no full-scale drill.

## Decision

- **A separate backup AWS account** (in an AWS Organization), holding **S3 Object Lock** buckets in **us-west-2** (30-day retention; governance mode first, compliance mode once proven), receiving **S3 replication** from the main account's backup, Terraform state, media and CloudTrail buckets through a write-only replication role. Access through a separate login kept in the break-glass kit.
- **russetleaf.com's database:** a logical dump at every `demo-down`, stored in its backup bucket and replicated (instead of cross-account snapshot copies, which would need KMS key sharing).
- **Daily repo mirrors** (`git bundle`) of every repo (the four code repos and `russetleaf-docs`) into the backup account, through a write-only OIDC role. Images and charts are rebuilt rather than copied.
- **A copy outside AWS:** a daily job on the home cluster encrypts the latest MariaDB dump and etcd snapshot with **`age`** (the cluster holds only the public key; the private key is in the break-glass kit) and uploads them with `rclone` to a **Cloudflare R2** bucket with a **bucket lock** rule of 30 days (objects deleted after 35). It covers the worst case, losing or compromising the AWS management account and with it the whole Organization. The project already has a Cloudflare account, R2 has no download charges, and data this small fits its free tier (check current terms); the bucket and its lock rule are managed with Terraform's Cloudflare provider where supported. The R2 token is limited to that bucket and kept in Secrets Manager.
- **Regenerate secrets rather than copy them**, except those that cannot be regenerated (account access, the Talos secrets bundle), which go in the **break-glass kit**: the password manager plus a printed copy of the essentials.
- **A written plan** (the [disaster recovery plan](../disaster-recovery.md)): an asset inventory, scenarios with data-loss and recovery-time targets and procedures, and the bootstrap order from zero.
- **Drills:** monthly restore; quarterly restore from the backup account; a yearly full "home lab destroyed" rebuild using only the kit and backups; a once-then-yearly russetleaf.com restore; a 6-monthly break-glass kit check.

## Alternatives considered

- **Cross-region copies in the same account:** protects against a regional outage, but not against an account compromise or loss.
- **AWS Backup with a logically air-gapped vault:** a managed option for immutable cross-account backups, but adds cost and setup for data that is mostly plain S3 objects; S3 replication with Object Lock achieves the same here.
- **Other providers for the off-AWS copy** (Backblaze B2 with Object Lock, Google Cloud Storage or Azure Blob with retention locks): equally suitable; R2 was chosen because the Cloudflare account already exists.
- **AWS DataSync to Azure or Google Cloud Storage:** supports those destinations, but is built for large migrations, charges per GB and, for some locations, needs an agent instance; heavy machinery for a few MB of dumps, and it runs inside the AWS account whose loss the copy is meant to survive.
- **Copying every secret:** simpler restores, but spreads secrets across more places; regenerating is safer and the plan lists what to regenerate.
- **Mirroring images to a second registry:** unnecessary, since images are reproducible from the mirrored source and re-signed on rebuild.

## Consequences

- Backups survive an account compromise, an account loss, and malicious deletion (for 30 days), not just hardware failures.
- One more AWS account to secure (root login with MFA, no day-to-day use), and an AWS Organization to manage.
- A few cents a month for storage and replication.
- **Security Hub backup findings:** AWS Backup is not used, so Security Hub may report resources (e.g. RDS instances, S3 buckets) as not covered by a backup plan. These findings are **suppressed with a recorded reason** pointing to this ADR (S3 replication with Object Lock, MariaDB Operator backups, RDS automated backups, final snapshots and logical dumps cover them), rather than left open; the weekly Security Hub review checks no new kind of backup finding appears.
- Recovery is documented and rehearsed; a full rebuild's real duration is known.
- The break-glass kit becomes critical: it must be kept current and its printed copy stored safely.

## When to revisit

- russetleaf.com becomes always-on or holds user data: consider a warm standby in us-west-2 and AWS Backup.
- The data grows enough that the off-AWS copy leaves R2's free tier, or more than the database and etcd need a copy outside AWS (e.g. the media).
- Data grows enough that replication or Object Lock costs matter.

## Open items

- Phase 1 steps 2.0 and 2.5: create the Organization and accounts, including the Backup account (2.0); create the locked buckets, replication and repo mirrors (2.5); test a restore from the backup account.
- Phase 1 step 0.1: assemble the break-glass kit.
- Phase 1 step 2.5: the encrypted R2 copy and its restore test; a quarterly restore from R2.
- Phase 1 step 7.10: the first full disaster drill; record the time in the [disaster recovery plan](../disaster-recovery.md).
- Phase 3 step 5.1: the logical dump at `demo-down`; restore it once from the backup account.
