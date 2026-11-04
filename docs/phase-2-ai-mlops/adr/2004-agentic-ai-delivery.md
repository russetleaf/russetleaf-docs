# ADR 2004: Agentic AI delivery, with least-privilege access and measured results

- **Status:** Accepted; updated by [ADR 1048](../../phase-1-russetleaf-dev/adr/1048-bash-script-standard.md)
- **Date:** 2026-11-02
- **Applies to:** how Phases 2 and 3 are built: the repos, the home cluster, the AWS accounts and the GitHub organization
- **Phase:** 2 (first used here). Phase 3 applies it to AWS infrastructure.

> **Update ([ADR 1048](../../phase-1-russetleaf-dev/adr/1048-bash-script-standard.md)):** the `AGENTS.md` and `CLAUDE.md` files start in **Phase 1** (in `russetleaf-docs` now, and in each code repo from step 1.1), carrying the bash script standard, so every Claude Code session already starts with the project's rules.

## Context

Phase 1 is built with AI assistance in conversation (Claude answers, drafts and reviews; the operator runs every command and makes every change), not with autonomous agents. Phases 2 and 3 are built with **AI coding agents** (for example Claude Code): agents that read the repo, edit files, run tools and tests, and iterate on their own until a task's checks pass.

Agents speed up work that has fast, objective checks (code, Terraform, manifests, tests) and help less with hardware, waiting and debugging the live environment. They also bring risks a careful team manages: broad credentials, unreviewed changes, prompt injection through content the agent reads, and plausible-looking mistakes in security-sensitive configuration. Building Phases 2 and 3 this way, with Phase 1 as a baseline, shows how agents can be used safely on DevOps and MLOps work and what they change.

## Decision

- **Tools:** **Claude Code** as the coding agent, used interactively on the workstation, where its permission settings enforce the rules below; and the **Claude Code GitHub Action** for small, well-specified tasks that run in CI and return as pull requests. Instructions live in `AGENTS.md`, a format most coding agents read, so the choice of tool can change without rewriting them. Agents that **operate** the cluster, rather than build it, are a separate decision ([ADR 2006](2006-ai-operations-assistant.md)).
- **Scope:** agents may write and change code, Terraform, manifests, policies, tests and documentation, and run local tools and tests. They **may not** apply infrastructure changes, merge pull requests, change GitHub or AWS settings, or read secrets.
- **One step per agent session, with the step spec as the contract:** the operator writes or approves the step's spec ([`docs/specs/TEMPLATE.md`](../../specs/TEMPLATE.md)) first; its acceptance criteria tell the agent when it is done; the agent works on a branch and opens a pull request.
- **Sandbox first:** agents iterate against local environments (kind or Talos in Docker, LocalStack, the mock LLM, the Docker Compose demo), never against production.
- **Least-privilege identities for agents:**
    - **GitHub:** commits on branches and pull requests only; branch protection requires the operator's review; no admin or settings access.
    - **Kubernetes (home):** the **read-only** role ([ADR 1033](../../phase-1-russetleaf-dev/adr/1033-identity-and-access.md)), with no access to Secrets, through its own short-lived kubeconfig.
    - **AWS (Phase 3):** a **plan-only** role (read access plus the Terraform state lock), so an agent can run `terraform plan` but never `apply`; applies go through the human-approved `apply` environment.
    - **No secrets in the agent's context:** `.env` files, kubeconfigs with write access, talosconfigs and credentials are excluded through the agent's permission settings.
- **Agent instructions in every repo:** an **`AGENTS.md`** (the conventions, how to run the checks, what the agent must not do), with a `CLAUDE.md` that imports it, so instructions are versioned and reviewed like code.
- **Prompt-injection precautions:** agents do not fetch arbitrary web content while credentials are loaded; new dependencies, Actions and images an agent adds are reviewed and pinned like any other.
- **Review and CI as the safety net:** every agent pull request runs the same checks as human ones (tests, the evaluation gate, Checkov, Kyverno tests, the docs checks), and the operator reviews IAM, policies, network rules and anything touching secrets line by line.
- **Measurement:** the progress checklists record, per step, **who did the work** (agent, operator or both) and **review findings** (problems caught in review or CI that the agent missed); actual hours are compared with the estimates and with similar Phase 1 work; each milestone retro has a section on the agents; Phase 2 ends with a written account of the results.

## Alternatives considered

- **No agents (conversation only, as in Phase 1):** lowest risk, but slower on code-heavy work, and it does not build or show experience with agentic tooling.
- **A general personal-assistant agent** (e.g. OpenClaw): broad access to the machine it runs on and community skills, a poor fit for a workstation that holds cluster and AWS credentials.
- **Agents with broad access** (admin credentials, able to apply and merge): fastest, but one confused or injected agent can damage the cluster or the AWS accounts; not acceptable for infrastructure.
- **Agents only in CI** (e.g. bots that open pull requests): safe and auditable, but limited to narrow tasks; interactive agent sessions with local tools cover far more of the work.

## Consequences

- Faster code-heavy steps (a rough expectation is 10–30%; the checklists will show the actual effect), with the operator's review time as the main limit.
- One extra setup step per phase for the agents' identities, instructions and sandbox.
- A measurable record of what agents did, what review caught, and how the results compare with Phase 1.

## When to revisit

- Review findings stay high for a kind of work: stop using agents for it, or tighten its spec and checks.
- Agent tooling gains reliable, auditable permission controls for live environments: consider letting agents run read-only diagnostics on the cluster during incidents.

## Open items

- Phase 2 step 1.1b: also install the Claude Code GitHub Action in the Phase 2 repos, with the same read-only defaults and pull-request-only output.

- Phase 2 step 1.1b: agent workspace, identities and `AGENTS.md`; step 5.3: the write-up.
- Phase 3 step 0.3: the plan-only AWS role for agents.
