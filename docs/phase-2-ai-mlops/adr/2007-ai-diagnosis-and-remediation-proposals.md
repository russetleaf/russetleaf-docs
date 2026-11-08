# ADR 2007: AI diagnosis with a project knowledge base, and remediation proposed as pull requests

- **Status:** Accepted; extends [ADR 2006](2006-ai-operations-assistant.md)
- **Date:** 2026-11-03
- **Applies to:** the home cluster's operations, `russetleaf-gitops`, the project documentation
- **Phase:** 2

## Context

[ADR 2006](2006-ai-operations-assistant.md) adds a read-only assistant that triages alerts. Its diagnoses rely on what it can see in the cluster; it knows nothing about the project's design, decisions, runbooks or past incidents, and it cannot propose a concrete fix. Agentic operations tools usually close both gaps with **retrieval-augmented generation (RAG)** over the system's own documentation and with **tools that act**. Acting directly on a GitOps-managed cluster is risky (Argo CD reverts direct changes, and an agent acting on untrusted log text can be manipulated), so the safe first step is for the agent to propose fixes through the same review path as any other change.

## Decision

- **Knowledge base (RAG):** the project's own text, indexed with embeddings: the `russetleaf-docs` repo (designs, plans, ADRs, postmortems, chaos results), the **runbooks** in `russetleaf-gitops/docs/runbooks/` (written to a consistent structure in Phase 1), and the code and Helm values of the repos. Embeddings come through the **LiteLLM gateway** (with its own budget); the index is stored in **PostgreSQL with pgvector** (a small instance run by the CloudNativePG operator, also used by Backstage), placed on `rl-home-cp01`, and rebuilt nightly and after merges to `main` by an Argo Workflows job. A small MCP server exposes search over it, returning passages with their source links.
- **Diagnosis:** for an alert, a **diagnosis agent** (kagent) gathers evidence with the read-only tools from [ADR 2006](2006-ai-operations-assistant.md), retrieves the matching runbook and related decisions, and writes a diagnosis that **cites its sources**.
- **Remediation as a pull request:** when the runbook has a fix that is a change in Git (revert the last version bump, adjust a resource limit or replica count, roll back a values change), a **remediation agent** opens a pull request in `russetleaf-gitops`, labeled `ai-proposed`, containing the evidence, the cited runbook, the expected effect and how to undo it. It never merges; the operator reviews and merges, and Argo CD applies the change as usual.
- **Verification:** after a proposal is merged, a **verification agent** checks that the alert cleared and the affected SLIs recovered, and comments on the pull request with the result.
- **Limits:**
    - The agents' GitHub identity can create branches and pull requests in `russetleaf-gitops` only, with no merge or settings rights.
    - A CI check **rejects `ai-proposed` pull requests that touch protected paths**: RBAC, Kyverno policies, network policies, secrets, the Argo CD and Cilium configuration, and anything in `russetleaf-infra`.
    - At most one open proposal per incident and a daily limit; a single setting (the **kill switch**) turns proposals off.
    - Retrieved documentation is the project's own and reviewed; logs and events are untrusted text and are never treated as instructions.
- **Evaluation:** the incident scenarios from [ADR 2006](2006-ai-operations-assistant.md) and Phase 1's chaos experiments, run in staging, score each run: correct diagnosis, correct runbook cited, whether the proposed pull request is one the operator would merge, and **any harmful proposal (target: none)**. Results are tracked in MLflow, like model evaluations.
- **Not in this decision (a documented later extension):** direct actions (for example, restarting a Deployment, aborting a canary, scaling within quota) after an operator approves them in Slack, and automatic actions for a few reversible cases. They need their own decision, based on the evaluation results.

## Alternatives considered

- **Diagnosis without a knowledge base:** simpler, but diagnoses miss the project's own context and decisions, and cannot point to the runbook.
- **Direct actions from the start:** faster recovery in theory, but bypasses review and conflicts with GitOps; pull requests keep every change reviewed, auditable and reversible.
- **A hosted vector database:** less to run, but another external service and account; pgvector on the existing PostgreSQL operator is enough for a few thousand passages.
- **A local model for reasoning:** cheaper per call, but the 3B model on `rl-home-cp02` is not reliable for multi-step diagnosis and tool use; reasoning goes through the gateway to Bedrock, with costs capped by its budget.

## Consequences

- Diagnoses grounded in the project's own documentation, with citations a reviewer can check.
- Fixes arrive as reviewable pull requests, so the operator's role shifts from investigating to reviewing.
- A measured record of how often the agents are right, and whether they ever propose something harmful.
- More components (a pgvector database of about 0.3 GB, the indexing job, an MCP search server) and about 25–40 hours of work.
- The runbooks become part of the system's behavior, so keeping them accurate matters more.

## When to revisit

- Proposals are consistently correct over months, with no harmful ones: decide on approval-gated direct actions (the later extension).
- The documentation grows large enough that search quality drops: tune chunking and ranking, or add a reranker.

## Open items

- Phase 1 step 4.4: runbooks written to the structure in `docs/runbooks/TEMPLATE.md`.
- Phase 2 step 5.2c: the knowledge base, the agents, the protected-path check and the evaluation.
