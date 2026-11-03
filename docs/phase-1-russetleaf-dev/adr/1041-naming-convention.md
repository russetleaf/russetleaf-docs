# ADR 1041: Naming convention for hosts, nodes and clusters

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** physical machines, network devices, Kubernetes nodes and clusters, at home and in AWS
- **Phase:** 1 (the home lab). Phase 3 applies it to the EKS cluster, its node groups and EC2 instances.

## Context

The design referred to the home servers as "box 1", "box 2" and "box 3", which is not how they appear anywhere real: in Talos, Kubernetes, DHCP, monitoring labels or the physical machines. The lab is about to be built (Phase 1 step 2.2), and names become hard to change once they are in certificates, node objects, dashboards and runbooks. The convention also has to work for future machines and for cloud nodes, whose names AWS assigns.

## Decision

**Format:** `<project>-<site>-<role><nn>`, for example `rl-home-cp03`.

| Part | Meaning | Values |
|---|---|---|
| `project` | The project | `rl` (RussetLeaf) |
| `site` | Where the machine runs: a physical location, or a cloud region | `home` (the home lab); `use1` (AWS us-east-1), `usw2` (us-west-2) |
| `role` | What kind of machine it is, not what it runs | `cp` (Kubernetes node running the control plane; at home it also runs workloads), `wk` (worker-only node), `gpu` (GPU worker), `rt` (router or firewall), `sw` (switch), `nas` (storage), `ws` (workstation) |
| `nn` | Two-digit sequence per site and role | `01`, `02`, ... in the order machines join; **never reused** |

**Rules:**

- Lowercase letters, digits and hyphens only; at most 63 characters (a valid DNS label). Names here are 12–15 characters.
- **No hardware, workload or person names.** The name says what kind of machine it is, not what runs on it: workload placement uses Kubernetes labels (e.g. `role=main`, `workload=llm`), so a node keeps its name when its job changes (as `rl-home-cp02` does when it becomes the LLM node in Phase 2).
- **A replacement gets a new number.** If `rl-home-cp02` fails and is replaced, the new machine is `rl-home-cp04`; old names in logs, alerts and postmortems keep pointing at the old machine.
- **The inventory is the source of truth** for hardware, addresses and roles: the Phase 1 design's [Home hardware](../design.md#home-hardware) table.
- **Physical labels:** each machine carries a printed label with its hostname.
- **Local name resolution (optional):** under `home.arpa`, the domain reserved for home networks (RFC 8375), e.g. `rl-home-cp01.home.arpa` on the router's DNS. Internal names are never published in public DNS.

**Clusters** follow the same idea, without the role and number: **`rl-home`** (the Talos cluster) and **`rl-use1`** (the EKS cluster). The cluster name is also the kubeconfig context and the `cluster` label on metrics and logs. Local test clusters are `kind-ci` (kind adds the `kind-` prefix) and `rl-local` (Talos in Docker).

**The home lab today:**

| Hostname | Machine | Address |
|---|---|---|
| `rl-home-cp01` | Lenovo ThinkCentre M710q Tiny (i5-6400T, 8 GB) | `10.10.0.11` |
| `rl-home-cp02` | Dell OptiPlex 3040 Micro (i5-6500T, 8 GB) | `10.10.0.12` |
| `rl-home-cp03` | Dell OptiPlex 3060 Micro (i5-8500T, 16 GB) | `10.10.0.13` |
| `rl-home-rt01` | TP-Link ER605 v2 | `10.10.0.1` |
| `rl-home-sw01` | TP-Link TL-SG105 (5-port gigabit, unmanaged) | — |

The numbers follow the order the machines joined. Of the two 8 GB machines, the faster CPU (the OptiPlex 3040's i5-6500T) is `rl-home-cp02`, the node that runs the model in Phase 2.

**Cloud nodes (Phase 3):** EKS sets each node's Kubernetes name from its EC2 instance, so node names do not follow this convention. Use **resource-based names** (the instance ID, e.g. `i-0abc123def4567890.ec2.internal`) rather than IP-based ones, so a name never refers to a different node later. The convention applies where the project chooses the name: the EKS cluster (`rl-use1`), the managed node group (`rl-use1-sys`), the Karpenter NodePools (`general`, `gpu`), and the EC2 **`Name` tag** set through the node class (`rl-use1-wk` for general nodes, `rl-use1-gpu` for GPU nodes), alongside the existing `Project`, `Site` and `Env` tags.

**When names are applied:**

- **Phase 1 step 0.3 (Nov 3–4):** the router is named `rl-home-rt01`; address reservations for the nodes are created under their hostnames; hostname labels go on the machines.
- **Phase 1 step 2.2 (Nov 5):** each node's hostname is set in its Talos machine config (`machine.network.hostname`), which also becomes its Kubernetes node name; the cluster is named `rl-home`.
- **Phase 3 steps 1.4 and 2.3:** the EKS cluster, node group, NodePools and `Name` tags.

## Alternatives considered

- **Keep "box 1–3":** fine in planning, but it exists nowhere in the real system.
- **Themed names** (e.g. trees or planets): memorable, but carry no information and do not scale to cloud resources.
- **Names describing hardware or workload** (e.g. `rl-dell-16g`, `rl-llm-01`): stale as soon as hardware is replaced or the workload moves.
- **A longer project prefix** (`russetleaf-home-cp01`): clearer to outsiders, but longer in every command, dashboard and alert; the prefix is defined here once.
- **Forcing EKS node names to the convention:** possible only with custom bootstrapping that EKS and Karpenter do not support well; tags and node group names give the same traceability.

## Consequences

- One name for each machine everywhere: Talos, Kubernetes, the router, metrics and logs, runbooks and the label on the case.
- The documents use hostnames instead of "box 1–3".
- Cloud nodes stay traceable through tags and node group names, even though their Kubernetes names come from AWS.

## When to revisit

- A second home site, or more clusters per site: add a cluster identifier to the format (e.g. `rl-home-k2-cp01`).
- More device types join the lab: extend the role list here before naming them.

## Open items

- Phase 1 step 0.3: the router's name and the address reservations; step 2.2: the node hostnames and the cluster name.
- Phase 3 steps 1.4 and 2.3: the EKS cluster, node group, NodePools and `Name` tags.
