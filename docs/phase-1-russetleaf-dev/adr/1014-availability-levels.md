# ADR 1014: Availability levels: home lab without HA; AWS designed for HA but run as a demo

- **Status:** Accepted; updated by [ADR 1020](1020-three-node-ha-home-cluster.md)
- **Date:** 2026-11-01
- **Applies to:** both sites
- **Phase:** 1 (the home cluster). Later: Phase 3 adds russetleaf.com's availability while running.

> **Update ([ADR 1020](1020-three-node-ha-home-cluster.md)):** The home lab now has **three control-plane nodes** with a virtual IP, replicated MariaDB with automatic failover, and spread workloads, so it **survives any single node failure** (recovery point: seconds; recovery time: about a minute). Power and internet remain single points of failure; a UPS is recommended. The "Future changes" items 1, 3 and 4 for the home lab are now done; the table below describes the original two-node state.

## Context

High availability (HA) means a site keeps working when a single component (a node, a disk, a zone, a database instance) fails. It usually means running more than one of everything, which costs money and hardware. The two sites differ:

*[The table below describes the **original two-node** home lab. Current state ([ADR 1020](1020-three-node-ha-home-cluster.md)): three control-plane nodes with a virtual IP, MariaDB primary–replica replication with automatic failover, and WordPress, the ingress and cloudflared spread across nodes; the home lab now survives any single node failure, with power and internet still single points of failure.]*

| | russetleaf.dev (Talos, home) | russetleaf.com (EKS, AWS) |
|---|---|---|
| Kubernetes control plane | **Single node** (`rl-home-cp01`): if it fails, the cluster is down | **HA by default**: AWS runs the EKS control plane across three availability zones |
| Worker nodes | Two boxes with distinct roles; losing either loses its workloads | Karpenter nodes across three zones; WordPress has 3+ replicas spread across zones |
| Database | Single MariaDB on local disk; backups every 6 hours | **RDS Multi-AZ** behind RDS Proxy (failover in seconds) |
| Cache | Single Valkey | ElastiCache primary + replica in different zones |
| Storage | Local disks, no replication ([ADR 1010](1010-local-storage-no-ceph.md)) | EBS and S3 (replicated by AWS) |
| Network path | One home internet connection and power supply; cloudflared has 2 replicas, but on the same box | CloudFront and a multi-zone ALB |
| Deliberate demo cuts | — | **One NAT Gateway** instead of three |
| Availability over time | Up 24/7, with single points of failure everywhere | **Only during demos**; the always-on edge serves an offline page otherwise |
| Region | One home | One AWS region (us-east-1) |

## Decision

- ~~**russetleaf.dev: no high availability.**~~ **Superseded by [ADR 1020](1020-three-node-ha-home-cluster.md)** (highly available for a single node failure; the rest of this bullet describes the original lab). Single points of failure were accepted because the hardware (two 8 GB nodes) and the budget do not allow redundancy. Protection comes from **recovery**, not redundancy: everything is rebuilt from Git (OpenTofu, Argo CD), and the database is restored from S3 backups.
- **russetleaf.com: a highly available design, run in demo mode.** It is HA *within one region while running* (EKS control plane, nodes across zones, RDS Multi-AZ, ElastiCache replica, multi-zone ALB, CloudFront), with one deliberate demo cut (one NAT Gateway), and it is not always running.
- **Recovery targets** (recovery point = how much data can be lost; recovery time = how long until the site is back):

| | Recovery point | Recovery time |
|---|---|---|
| russetleaf.dev, single node or disk loss (**current**, three nodes; [ADR 1020](1020-three-node-ha-home-cluster.md)) | Seconds (MariaDB replication lag) | About a minute (database failover; other workloads already on other nodes) |
| ~~russetleaf.dev, node or disk loss (original two-node lab)~~ | ~~≤ 6 hours (MariaDB backup interval); media, logs and traces are in S3~~ | ~~A few hours: rebuild the node or cluster from Git, restore the latest backup~~ |
| russetleaf.dev, disaster (data corrupted or home lab lost) | ≤ 6 hours (MariaDB backup interval) | 1–2 days with new hardware (see the [disaster recovery plan](../disaster-recovery.md)) |
| russetleaf.dev, home outage (power, internet) | None (data is intact) | Until power or internet returns; the external uptime check alerts |
| russetleaf.com, node, zone or database failure (while running) | Seconds (RDS Multi-AZ, synchronous replication) | Seconds to minutes (Kubernetes rescheduling, RDS failover, Karpenter replacing nodes) |
| russetleaf.com, between demos | Content kept in the final RDS snapshot and the media bucket | The next `demo-up` (about 20–30 minutes) |
| russetleaf.com, regional outage | Last snapshot or backup | Not covered: single region |

## Future changes that would enable HA

**Home (russetleaf.dev):**

1. ~~**A third node, and three control-plane nodes** (Talos supports control-plane nodes that also run workloads), with Talos's **shared virtual IP** for the Kubernetes API. Roughly **$150–300** for a used mini PC.~~ **Done ([ADR 1020](1020-three-node-ha-home-cluster.md)).**
2. **Replicated storage** (Rook-Ceph or Longhorn) once three nodes with spare disks and memory exist ([ADR 1010](1010-local-storage-no-ceph.md)).
3. ~~**MariaDB replication** (MariaDB Operator supports replicated and Galera clusters)~~ **Done ([ADR 1020](1020-three-node-ha-home-cluster.md)):** primary–replica replication with automatic failover. ~~and **Valkey with Sentinel**~~ Not planned: Valkey stays single, since it is a cache and WordPress falls back to the database ([ADR 1020](1020-three-node-ha-home-cluster.md)).
4. ~~**Spread workloads** (cloudflared, ingress-nginx, WordPress) across nodes with anti-affinity and PodDisruptionBudgets.~~ **Done ([ADR 1020](1020-three-node-ha-home-cluster.md)).**
5. A **UPS** for all three nodes and the router (roughly **$100–200**), and optionally a **backup internet connection** (a 4G/5G failover router, roughly **$15–30/month** for a data plan).

**AWS (russetleaf.com):**

1. **Three NAT Gateways** (one per zone): about **+$65/month** if running 24/7.
2. **Always-on operation:** the full **~$515–575/month** in the Phase 3 design's cost table.
3. **Multi-region disaster recovery:** cross-region copies of RDS snapshots and S3 data (backup-and-restore costs little more than storage), or a warm standby in a second region with **Route 53 failover** (roughly doubles the cost).

## Alternatives considered

- **Building HA at home now:** needs a third node, more memory and replicated storage; not affordable with the current hardware, and recovery from Git plus backups is adequate for a small site with no paying users.
- **Running russetleaf.com always-on with full HA:** about $515–575/month, far over the $30–50/month budget.
- **Removing the demo cut (three NAT Gateways) during demos:** adds cost for every demo hour, for resilience that a demo rarely needs; documented as "production would use three" instead.

## Consequences

- Both sites' limits are explicit, with numbers, rather than implied.
- russetleaf.dev will have outages when the home power or the internet fails (since [ADR 1020](1020-three-node-ha-home-cluster.md), not when a single node or disk fails); the uptime check and dead man's switch alert on them.
- russetleaf.com runs the full HA design only when it is needed, without paying for it around the clock.
- Recovery depends on the backups, OpenTofu and GitOps working, which makes the monthly restore test and occasional rebuild rehearsal important.

## When to revisit

- russetleaf.com starts serving real users, or must be always-on.
- A third home node (with spare disks and memory) becomes available.
- Home outages become frequent enough to justify a UPS or backup internet connection.
- A requirement for regional disaster recovery appears.

## Open items

- Phase 1 step 2.2: rehearse a full rebuild of the cluster from Git and record the actual recovery time.
- Phase 1 step 4.5: confirm the 6-hour recovery point with the backup schedule.
- Phase 3 step 3.1: test a forced RDS failover (already planned) and a node loss; record recovery times.
