# ADR 2002: Summary pipeline: event-driven summarizer behind an LLM gateway

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** `russetleaf-llm-summarizer`, `russetleaf-wordpress`'s summary-queue plugin, the LLM gateway, on russetleaf.dev
- **Phase:** 2 (russetleaf.dev only)

## Context

Each post gets a short AI-generated summary. Summaries must not slow down publishing, must survive model outages and throttling, must cost almost nothing when idle, and must be observable and testable like any other production service. The design described this pipeline, but the choice of its shape had no ADR.

## Decision

- **Event-driven:** a must-use plugin in WordPress sends the post ID to an **SQS queue** on publish or update (with the trace context); a separate **summarizer** service reads the post through the REST API, asks for a summary, validates it and writes it back. Failures retry and then land in a **dead-letter queue** with an alert; a daily sweep re-queues posts still missing a summary.
- **Scale to zero with KEDA:** the summarizer runs 0–N pods based on queue depth.
- **One LLM gateway (LiteLLM)** for every model call: one OpenAI-compatible API, routing and **fallback** (Bedrock first, the local model if Bedrock fails or throttles), **canary splits** for model changes, per-app **rate limits and budgets**, and metrics per model.
- **Models:** **Amazon Bedrock** (Claude Haiku by default, Amazon Nova Lite as the lower-cost option) and a **self-hosted model** ([ADR 2003](2003-self-hosted-model-on-cp02.md)).
- **Its own repo (`russetleaf-llm-summarizer`):** versioned prompts, the evaluation set and gate, the chart and the release pipeline, so it stands alone as an MLOps project; deployment config (routing, canary weights) stays in `russetleaf-gitops`.
- **Python** for the summarizer (boto3, the `openai` client, OpenTelemetry).

## Alternatives considered

- **Summarizing inside WordPress on publish (synchronous):** simplest, but slows publishing, ties model outages to the admin screen, and cannot scale or be tested separately.
- **WP-Cron or a Kubernetes CronJob polling for new posts:** no queue to manage, but adds latency and polling load, and gives no per-message retries or dead-letter queue.
- **Calling Bedrock directly from the summarizer:** one less component, but no fallback, canaries, budgets or uniform metrics across models.
- **A different gateway (for example, a cloud-hosted router):** capable, but a third-party service in the request path; LiteLLM is open source and in-cluster.

## Consequences

- Publishing is never slowed or broken by the AI pipeline; summaries arrive within minutes.
- Model changes go through the gateway's canary and the evaluation gate ([ADR 2001](2001-mlops-lifecycle.md)) like code changes.
- More moving parts (queue, KEDA, gateway) to monitor; covered by the LLM dashboards, alerts and end-to-end traces.
- Cost when idle is close to zero: no summarizer pods, SQS within the free tier.

## When to revisit

- Summaries become interactive (for example, on-demand rewriting): consider a synchronous path through the same gateway.
- Many more AI features: consider a shared inference platform rather than one gateway config.

## Open items

- Phase 2 steps 2.1–2.5: build and deploy the pipeline; step 2.6: set KEDA and gateway limits from the burst test.
