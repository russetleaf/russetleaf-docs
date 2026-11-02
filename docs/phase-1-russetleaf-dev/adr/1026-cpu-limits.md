# ADR 1026: No CPU limits by default; CPU limits only to protect a specific neighbor

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** both sites
- **Phase:** 1. Later: Phase 2 adds llama.cpp's CPU limit on box 2.

## Context
Kubernetes containers can have CPU **requests** (guaranteed share, used for scheduling) and CPU **limits** (a hard cap, enforced by throttling). Memory limits protect a node from running out of memory; CPU limits work differently: CPU is compressible, so a container that exceeds its limit is **throttled**, even when the node has idle CPU. Throttling commonly causes latency spikes (e.g. slow page loads in WordPress, slower model responses). On the other hand, without limits a busy container can use spare CPU that something critical needs.

On the home cluster, etcd runs on all three nodes (ADR 1020), and box 2 also runs llama.cpp (which uses every core it can) and the CI runners.

## Decision

- **Every container sets CPU and memory requests and a memory limit** (enforced by Kyverno).
- **CPU limits are not required by default.** CPU requests (proportional sharing under contention) protect workloads from each other well enough, without throttling.
- **CPU limits are used where a specific neighbor needs protecting:**
    - **llama.cpp** on box 2, leaving about one core free for etcd and the kubelet
    - **CI runners** on box 2, so the model and runners together can never take every core
    - load-test generators (k6), so tests can't starve the system under test on the same node
- **Talos system and kubelet reservations** on every node protect the control plane regardless.
- **etcd health alerts** (disk sync latency, leader changes, proposal failures) show whether the protection is enough.

## Alternatives considered

- **CPU limits on everything:** predictable, but throttles WordPress and other latency-sensitive workloads unnecessarily, even on idle nodes.
- **No CPU limits anywhere:** maximum performance, but llama.cpp or a CI build could starve etcd on box 2.
- **Dedicated nodes for etcd:** the cleanest isolation, but needs more hardware.

## Consequences

- WordPress and the platform services use spare CPU freely, with fewer latency spikes.
- The model and CI runners are capped on box 2; summaries and CI jobs run a little slower under contention.
- The exceptions are explicit and reviewed (Kyverno allows CPU limits; it only requires memory limits).

## When to revisit

- etcd alerts fire despite the limits: move the CI runners to box 1, or reduce llama.cpp's limit.
- A workload causes noisy-neighbor problems: give it a CPU limit and record why.

## Open items

- Phase 1 step 4.4 (etcd alerts), 5.5 (runner limits) and 8.1 (llama.cpp limit).
