# ADR 0010: Local storage with S3 backups; no Ceph (Rook) or Longhorn

- **Status:** Accepted; updated by ADR 0021
- **Date:** 2026-11-01
- **Applies to:** russetleaf.dev (home lab). russetleaf.com uses AWS's managed EBS and S3.


> **Update (ADR 0021):** The home cluster now has three nodes. Still no Ceph (memory per storage daemon) and no Longhorn (unnecessary): **database availability now comes from MariaDB primary–replica replication with automatic failover** (primary on box 3, replica on box 1), so a node or disk loss costs seconds of data, not hours. The 6-hourly S3 backups remain for disasters.
## Context
**Ceph** is a distributed storage system that pools several servers' disks into replicated block, file and S3-compatible object storage, healing itself when a disk or server fails. **Rook** is the Kubernetes operator that runs Ceph inside a cluster, and Rook-Ceph is a standard choice for on-premises Kubernetes needing resilient storage. **Longhorn** is a lighter distributed block storage system for Kubernetes. Earlier versions of the design listed "local-path-provisioner or Longhorn" for home storage.

The home cluster has two nodes with 8 GB of RAM each (box 1 already uses about 6–7 GB; box 2 is dedicated to the LLM), and probably one disk per node, used by Talos. The design keeps state **out of the cluster** on purpose: media, logs, traces and database backups are in S3, and code is in the image. Only MariaDB, Valkey and a few caches use local disk.

## Decision
- Use **local-path-provisioner** for all home persistent volumes.
- Protect the one important piece of in-cluster state, the **MariaDB database**, with **logical backups to S3 every 6 hours** (instead of daily), giving a **recovery point of at most 6 hours** of lost posts and settings, and an alert if the last successful backup is more than 7 hours old.
- Recover from a lost node by rebuilding from Git (Terraform, Argo CD) and restoring MariaDB from the latest backup.
- **Don't use Ceph (Rook) or Longhorn.**

## Alternatives considered
- **Rook-Ceph:** needs at least three nodes for a healthy cluster (monitor quorum, three data copies), spare disks for Ceph to manage, and a lot of memory: each storage daemon (OSD) defaults to about 4 GB, plus monitors and a manager at roughly 1–2 GB each. The home cluster has none of this to spare.
- **Longhorn:** lighter than Ceph, but also wants three nodes to replicate volumes, and still adds memory and disk overhead on box 1.
- **Daily backups only (the previous plan):** simpler, but up to a day of posts could be lost.
- **MariaDB replication to a second instance:** would need box 2's memory, which is reserved for the model.

## Consequences
- No storage system to run, upgrade or debug; no memory spent on storage daemons.
- A failure of box 1's disk means rebuilding the cluster and restoring the database, losing up to **6 hours** of changes, with some downtime while restoring. Acceptable for a portfolio site.
- Backup storage grows (four backups a day, kept 14 days); still only a few MB each, so cost stays under $1/month.
- Rook-Ceph experience isn't shown by this project; it can be learned in a separate, throwaway lab.

## When to revisit
- A third node (or more) with spare disks and enough memory (e.g. three mini PCs with 32 GB each): Rook-Ceph or Longhorn becomes realistic and worth showing.
- A requirement for a recovery point of minutes rather than hours: add MariaDB binary-log shipping to S3 (point-in-time recovery) or replication.
- Workloads that need shared (read-write-many) volumes in the cluster.

## Open items
- Home plan step 4.5: confirm the 6-hourly backups run within their window and record the backup size.
- Home plan step 4.1: confirm local-path-provisioner is the only StorageClass.
