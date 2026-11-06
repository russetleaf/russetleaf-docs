# ADR 1030: GitHub Actions for CI/CD, public repositories early, and the runner strategy

- **Status:** Accepted; Jenkins alternative expanded 2026-11-06
- **Date:** 2026-11-01
- **Applies to:** all four repos (and repos created from the golden-path template)
- **Phase:** 1. Later: Phase 2 adds `russetleaf-llm-summarizer`; Phase 3 runs the demo workflows on the home runners.

## Context

The project needs CI for OpenTofu, manifests, images, charts, evaluation and promotion, plus scheduled workflows (scans, reports, demos). The code lives on GitHub. The repos were planned to stay **private** until the end (Phase 1 step 9.2), but GitHub's free plan gives private repos only about **2,000 Actions minutes a month** (check current limits), which image builds, kind clusters, scans and integration tests across four repos would use up quickly. Some jobs also need to reach the home cluster or a restricted EKS API.

## Decision

- **GitHub Actions** is the CI/CD platform, with OIDC to AWS (no stored keys), GitHub Environments for approvals, and reusable workflows (including the SLSA build workflow, [ADR 1013](1013-image-supply-chain.md)).
- **Make the repositories public early** (Phase 1 step 1.1, right after a `gitleaks` scan of their history). By design nothing secret is in Git, and public repos get **free GitHub-hosted runner minutes**, free code scanning and push protection, and public GHCR packages (no storage limit or pull secrets; [ADR 1004](1004-ghcr-not-ecr.md)).
- **Runner strategy:**
    - **GitHub-hosted runners** for most jobs (linting, scans, builds, kind tests).
    - **Self-hosted, ephemeral ARC runners** on the home cluster (under gVisor, [ADR 1009](1009-gvisor-sandboxing.md)) for jobs that must reach the home cluster: the evaluation gate, `staging-test`, home OpenTofu applies, and the **AWS demo workflows** (so the EKS API endpoint can be restricted to the home network's address).
    - Public-repo protections: approval required for workflows from fork pull requests, and the self-hosted label limited to specific trusted workflows.

## Alternatives considered

- **Private repos until the end:** hides work in progress, but runs into the minute limit (or costs a paid plan) and private-package limits.
- **GitLab CI or another platform:** capable, but the code, packages, attestations and code scanning are on GitHub; moving CI elsewhere adds integration work.
- **Self-hosted runners for everything:** no minute limits, but runs untrusted pull-request code at home for jobs that do not need to, and uses home-cluster capacity.
- **Jenkins:** the most widely used self-hosted CI server, with full control over pipelines, no dependence on a CI vendor, and a plugin for almost anything. Against it here:
    - **A server to run:** the Jenkins controller would need memory on the three-node home cluster ([ADR 1020](1020-three-node-ha-home-cluster.md)), backups of its configuration and job history, upgrades, and a way to recover it, and it would become one more thing that has to work before anything can be released.
    - **Plugins:** most of its features (Git, Kubernetes agents, credentials, pipelines) come from plugins, which are the source of most of its security advisories and need to be kept current and compatible with each other.
    - **Stored credentials:** Jenkins keeps its own credential store, so it would hold long-lived AWS keys and tokens, where GitHub Actions signs in to AWS with **OIDC** and holds none.
    - **Integration the project relies on:** pull request checks and required reviews, GitHub Environments for approvals, GHCR, signed build provenance (`actions/attest-build-provenance`, [ADR 1013](1013-image-supply-chain.md)), code scanning, and free runner minutes for public repos all come with GitHub Actions; with Jenkins each would be a plugin or custom work, and its agents would run untrusted pull-request code at home.
- **Tekton or Argo Workflows for CI:** Kubernetes-native, but they share Jenkins' running cost on the home cluster and have less of GitHub's integration; Argo Workflows is used for ML pipelines ([ADR 2001](../../phase-2-ai-mlops/adr/2001-mlops-lifecycle.md)), not general CI.

## Consequences

- No CI minute or package-storage limits; work in progress is visible publicly (acceptable for a portfolio, and shows real history).
- Fork pull requests must be handled carefully on self-hosted runners (approval, label restrictions, ephemeral gVisor runners).
- The EKS API can be locked to the home address because demo workflows run at home.

## When to revisit

- The project needs private code: move to a paid plan, or run most CI on self-hosted runners.
- GitHub's free-tier terms change.
- The code moves off GitHub, or pipelines need control that GitHub Actions cannot give (for example, builds that must run entirely on the project's own hardware): reconsider a self-hosted server such as Jenkins, or the CI of the new code host.

## Open items

- Phase 1 step 1.1: scan and make the repos public; step 5.5: runners; Phase 3 steps 1.4 and 5.1: the restricted endpoint and demo workflows on home runners.
