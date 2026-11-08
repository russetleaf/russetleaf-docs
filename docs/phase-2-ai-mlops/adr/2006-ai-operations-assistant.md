# ADR 2006: A read-only AI operations assistant with kagent

- **Status:** Accepted; extended by [ADR 2007](2007-ai-diagnosis-and-remediation-proposals.md)
- **Date:** 2026-11-02
- **Applies to:** the home cluster's operations: alert triage and troubleshooting
- **Phase:** 2

> **Update ([ADR 2007](2007-ai-diagnosis-and-remediation-proposals.md)):** the assistant gains a knowledge base of the project's documentation and can propose fixes as pull requests for the operator to review; it still makes no direct changes.

## Context

[ADR 2004](2004-agentic-ai-delivery.md) covers AI agents that help **build** the project. A different and increasingly common use of agents is in **operations**: an agent with access to the cluster's state, metrics and logs investigates a problem and explains what it finds. Phase 2 already provides most of what such an agent needs: an LLM gateway with budgets, rate limits and monitoring ([ADR 2002](2002-summary-pipeline-architecture.md)), and a habit of evaluating model output before trusting it ([ADR 2001](2001-mlops-lifecycle.md)).

## Decision

- **kagent** (a CNCF sandbox project) runs in the home cluster as an **AI operations assistant**: agents defined as Kubernetes resources, using tools for Kubernetes, Prometheus, Loki, Argo CD and Cilium (through MCP tool servers).
- **Models through the gateway:** kagent's model configuration points at the **LiteLLM gateway**, with its own key, a small daily budget and rate limits, so its cost and usage appear on the existing LLM dashboards.
- **Read-only by design:** its service accounts are bound to the **read-only** role ([ADR 1033](../../phase-1-russetleaf-dev/adr/1033-identity-and-access.md)), with no access to Secrets; tools that change anything (apply, delete, scale, exec) are not installed; its API requests appear in the audit log under its own identity. It **suggests**; the operator decides and acts.
- **Alert triage:** critical and selected warning alerts are also sent from Alertmanager to the assistant, which investigates (events, logs, metrics, recent Argo CD syncs and network drops) and posts a **triage note** in the alert's Slack thread: likely cause, evidence, and suggested next steps from the runbook.
- **Evaluated like any model output:** a small set of **incident scenarios** (a crash-looping pod, an out-of-memory kill, a failing probe, a network-policy drop, a bad canary), replayed in staging, checks that its diagnoses are correct and useful before it is trusted, and again after model or prompt changes.
- **Prompt-injection awareness:** logs and events are untrusted text, so the assistant has no tools that act on what it reads, and its notes are labeled as AI-generated.

## Alternatives considered

- **k8sgpt or HolmesGPT:** focused troubleshooting tools that also work well; kagent is Kubernetes-native (agents and tools as resources managed by Argo CD), part of the CNCF, and extensible with the same tools across Prometheus, Argo CD and Cilium.
- **A general personal-assistant agent (for example, OpenClaw):** broad access to the machine it runs on and third-party skills, without the scoped, cluster-native permissions this needs.
- **No operations agent:** simpler, but leaves out a widely discussed use of agentic AI in operations, which this project can show safely.
- **Letting the agent fix problems:** faster in theory, but an agent acting on untrusted log text with write access is too risky; suggestions keep a person in control.

## Consequences

- Faster first look at incidents, with evidence gathered in one place.
- A few more components (the controller, UI and tool servers, roughly 0.3–0.6 GB; check current figures when installing), placed on `rl-home-cp01`, which has the headroom.
- A small, bounded LLM cost through the gateway's budget.
- kagent is young; resource names and tools may change between versions, so pin the version and check its documentation when building.

## When to revisit

- Diagnoses prove reliable over months: consider allowing low-risk actions (for example, restarting a pod) behind explicit approval.
- kagent stops being maintained: replace it with k8sgpt or HolmesGPT behind the same gateway and permissions.

## Open items

- Phase 2 step 5.2b: install, permissions, alert triage and the incident scenarios.
