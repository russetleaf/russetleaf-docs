# ADR 1030: GitHub Actions for CI/CD, public repositories early, and the runner strategy

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** all four repos (and repos created from the golden-path template)
- **Phase:** 1. Later: Phase 2 adds `llm-summarizer`; Phase 3 runs the demo workflows on the home runners.

## Context
The project needs CI for Terraform, manifests, images, charts, evaluation and promotion, plus scheduled workflows (scans, reports, demos). The code lives on GitHub. The repos were planned to stay **private** until the end (Phase 1 step 9.2), but GitHub's free plan gives private repos only about **2,000 Actions minutes a month** (check current limits), which image builds, kind clusters, scans and integration tests across four repos would use up quickly. Some jobs also need to reach the home cluster or a restricted EKS API.

## Decision
- **GitHub Actions** is the CI/CD platform, with OIDC to AWS (no stored keys), GitHub Environments for approvals, and reusable workflows (including the SLSA build workflow, ADR 1013).
- **Make the repositories public early** (Phase 1 step 1.1, right after a `gitleaks` scan of their history). By design nothing secret is in Git, and public repos get **free GitHub-hosted runner minutes**, free code scanning and push protection, and public GHCR packages (no storage limit or pull secrets; ADR 1004).
- **Runner strategy:**
  - **GitHub-hosted runners** for most jobs (linting, scans, builds, kind tests).
  - **Self-hosted, ephemeral ARC runners** on the home cluster (under gVisor, ADR 1009) for jobs that must reach the home cluster: the evaluation gate, `staging-test`, home Terraform applies, and the **AWS demo workflows** (so the EKS API endpoint can be restricted to the home network's address).
  - Public-repo protections: approval required for workflows from fork pull requests, and the self-hosted label limited to specific trusted workflows.

## Alternatives considered
- **Private repos until the end:** hides work in progress, but runs into the minute limit (or costs a paid plan) and private-package limits.
- **GitLab CI or another platform:** capable, but the code, packages, attestations and code scanning are on GitHub; moving CI elsewhere adds integration work.
- **Self-hosted runners for everything:** no minute limits, but runs untrusted pull-request code at home for jobs that don't need to, and uses home-cluster capacity.
- **Jenkins, Tekton or Argo Workflows for CI:** more to run and maintain; Argo Workflows is used for ML pipelines (ADR 2001), not general CI.

## Consequences
- No CI minute or package-storage limits; work in progress is visible publicly (acceptable for a portfolio, and shows real history).
- Fork pull requests must be handled carefully on self-hosted runners (approval, label restrictions, ephemeral gVisor runners).
- The EKS API can be locked to the home address because demo workflows run at home.

## When to revisit
- The project needs private code: move to a paid plan, or run most CI on self-hosted runners.
- GitHub's free-tier terms change.

## Open items
- Phase 1 step 1.1: scan and make the repos public; step 5.5: runners; Phase 3 steps 1.4 and 6.1: the restricted endpoint and demo workflows on home runners.
