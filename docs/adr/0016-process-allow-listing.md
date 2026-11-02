# ADR 0016: Process allow-listing with Falco; AppArmor and SELinux not used; Tetragon and custom seccomp as stretch goals

- **Status:** Accepted; updated by ADR 0021
- **Date:** 2026-11-01
- **Applies to:** both sites


> **Update (ADR 0021):** With the three-node home cluster's extra memory, **Tetragon enforcement is realistic at home** after its EKS trial.
## Context
Process allow-listing means only expected programs may run in a container, so an attacker who gets code execution can't run shells, download tools or miners. On Linux it's usually built from mandatory access control profiles (**AppArmor** or **SELinux**), **seccomp** system-call filters, or runtime tools that watch or block process execution.

The project already has: seccomp `RuntimeDefault` required by Kyverno (ADR 0009), a read-only root filesystem and non-root user for its own workloads, gVisor for CI runners, Falco runtime detection (including shells in pods and writes to WordPress code), and Cilium on both clusters.

Platform constraints:
- **Talos** doesn't ship AppArmor, and its SELinux support is limited.
- **EKS** nodes run Amazon Linux 2023, which doesn't use AppArmor and typically runs SELinux in permissive mode; the control plane is AWS-managed.

## Decision
- **Keep seccomp `RuntimeDefault`** everywhere (already enforced).
- **Add Falco process allow-list rules** per workload: WordPress (`apache2`, `php`), the summarizer (`python`), the LiteLLM gateway (`python`), llama.cpp (`llama-server`); any other process alerts `#rl-security`. The lists live in Git and are tested.
- **Keep the images lean:** no download tools or package managers in final images where practical (the official WordPress image's startup script still needs its shell), checked by container-structure-test.
- **Don't use AppArmor or custom SELinux policies.**
- **Stretch goals:**
  - **Tetragon** enforcement (kill unlisted processes), tried on EKS during a demo first, and at home only if memory allows.
  - **Custom seccomp profiles** recorded with the **Security Profiles Operator** for WordPress and the summarizer.

## Alternatives considered
- **AppArmor profiles:** not available on Talos or the EKS nodes used here.
- **Custom SELinux policies:** large effort, limited Talos support, and AL2023's default permissive mode; little gain over seccomp, Falco and the read-only, non-root containers.
- **KubeArmor:** enforcement through AppArmor, SELinux or BPF-LSM; depends on kernel features not guaranteed on Talos, and duplicates Tetragon, which fits the existing Cilium stack.
- **Tetragon enforcement everywhere now:** blocks rather than detects, but costs memory on box 1 and can break workloads if an allow-list is wrong; better proven on EKS first.
- **Detection only through the existing "shell in pod" rule:** catches shells but not other unexpected programs (e.g. `curl`, a miner).

## Consequences
- Any unexpected program in a project workload is reported within seconds, on both sites, at no extra memory cost.
- Detection, not prevention: a short-lived malicious process may run before the alert is acted on (Tetragon would close that gap).
- Allow-lists must be updated when images legitimately add a program; the release pull request does this, and the tests catch omissions.
- AppArmor and SELinux are explicitly out of scope, with the reasons recorded.

## When to revisit
- Tetragon proves stable on EKS: consider enforcement for WordPress at home too.
- Talos adds AppArmor or full SELinux support, or the EKS nodes move to Bottlerocket (which enforces SELinux).
- A compliance requirement mandates mandatory access control profiles.

## Open items
- Home plan step 10.1: write and test the allow-list rules.
- Home plan step 10.7 (optional): Security Profiles Operator recordings for WordPress and the summarizer.
- AWS plan step 5.4 (optional): Tetragon enforcement trial during a demo; record memory use and any false blocks.
