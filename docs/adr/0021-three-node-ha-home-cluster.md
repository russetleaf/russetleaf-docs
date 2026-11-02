# ADR 0021: Three-node home cluster with a highly available control plane

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** russetleaf.dev (home lab)
- **Updates:** ADR 0006 (Tempo always on at home), ADR 0010 (database HA from replication), ADR 0015 (home availability), ADR 0016 (Tetragon feasible at home), ADR 0018 (CrowdSec feasible at home)

## Context
The home lab had two nodes with 8 GB of RAM each: box 1 (single control plane, all workloads, about 6–7 GB in use) and box 2 (worker dedicated to the LLM). Memory ruled out several useful tools (always-on tracing, Tetragon, CrowdSec), and the cluster had single points of failure everywhere (ADR 0015). A third machine was bought: an **Intel i5-8500T (6 cores, 35 W) with 16 GB of RAM and an NVMe SSD**.

## Decision
- **Three control-plane nodes**, each also running workloads, so etcd keeps quorum when any one node fails, with **Talos's shared virtual IP** for the Kubernetes API:

| Node | Hardware | Roles |
|---|---|---|
| **Box 3** (new) | i5-8500T, 16 GB, NVMe | Control plane + **main workloads**: Argo CD, monitoring, Loki, Tempo, platform services, a WordPress replica, the **MariaDB primary** |
| **Box 1** | i3, 8 GB | Control plane + **secondary workloads**: a WordPress replica, the **MariaDB replica**, second ingress-nginx and cloudflared replicas, staging runs |
| **Box 2** | i3, 8 GB | Control plane + **dedicated LLM** (label `workload=llm`, taint `dedicated=llm:NoSchedule`) and the CI runners |

- **Protect etcd on box 2:** llama.cpp gets a **CPU limit leaving about one core free**, and every node sets Talos's **system and kubelet reservations** (CPU and memory), so the model can't starve etcd or the kubelet. **All three nodes must use SSD or NVMe storage** (etcd now runs on every node and is sensitive to disk latency); check boxes 1 and 2, and replace a spinning disk with an inexpensive SATA SSD before installing Talos.
- **Database HA through replication, not distributed storage:** MariaDB Operator **primary–replica replication** (primary on box 3, replica on box 1) with **automatic failover**; the 6-hourly S3 backups stay for disasters. Valkey stays single (it's a cache; WordPress falls back to the database).
- **Spread the stateless workloads:** WordPress (2–3 replicas), ingress-nginx and cloudflared (2 replicas each) across nodes with anti-affinity or topology spread, and PodDisruptionBudgets.
- **Memory budget per node** (estimates with every tier installed): box 3 about **11–14 GB of 16**, box 1 about **4.5–5 GB of 8**, box 2 about **6.5–7 GB of 8** (with a 3B model). If box 3 passes about **85%**, move MLflow or Backstage to box 1, or upgrade box 3 to 32 GB (these mini PCs take up to 64 GB). Memory is checked in the plan steps that add large components (9.4, 12.3, 12.6).
- **Use the extra memory** (about 32 GB in total): Tempo **always on** at home; **CrowdSec** and **Tetragon enforcement** become realistic at home (after the EKS trial); longer Prometheus retention (e.g. 15 days).
- **Real failure drills:** take a node offline (and unplug its power) and confirm the API, the site and the database keep working.
- **BIOS settings** on every node: power on after AC loss, virtualization enabled, current BIOS.
- **Still not HA:** one home power supply and one internet connection; a **UPS** is recommended now that the cluster survives a node loss.

## Alternatives considered
- **One control plane (box 3) plus two workers:** simpler, but no control-plane HA; losing box 3 would stop the cluster.
- **Two control planes:** worse than one, since etcd needs a majority (2 of 2) and so tolerates no failures.
- **Moving the LLM to box 3** (6 cores, more memory): a 7–8B model would run faster, but crowds the main workloads; kept as a later experiment.
- **Longhorn or Rook-Ceph for replicated volumes:** Ceph still doesn't fit (memory per storage daemon); Longhorn is now possible but unnecessary, since the only important in-cluster state (MariaDB) is replicated at the application level.
- **MariaDB Galera (multi-primary):** needs three database members, but box 2 is reserved for the LLM; primary–replica replication with automatic failover covers a single-node loss.

## Consequences
- The home site survives the loss of any one node; Talos and Kubernetes upgrades become **rolling, with no downtime**.
- Database recovery point for a node loss drops from **≤ 6 hours** to **seconds** (replication lag); recovery time from **hours** to **about a minute** (failover).
- Memory pressure is gone; tools previously ruled out become possible.
- Roughly 10–20 hours of extra work (VIP, three-node etcd, replication, spreading, drills), offset by time no longer spent working around memory limits.
- Box 3 adds about $3–5/month in electricity.
- Power and internet remain single points of failure.

## When to revisit
- Summary quality matters more: move the model to box 3, or add a fourth node for workloads.
- A UPS and backup internet are added: update ADR 0015's home targets again.
- More nodes with spare disks: reconsider replicated storage (Longhorn) for volumes other than the database.

## Open items
- Home plan step 2.2: the three-node Talos configuration with the virtual IP and reservations; record etcd health under LLM load.
- Home plan step 4.5: MariaDB replication and a failover test.
- Home plan step 10.11: the first node-failure drills; record timings in ADR 0015.
