# ADR 1006: Distributed tracing with Tempo and OpenTelemetry

- **Status:** Accepted; updated by [ADR 1020](1020-three-node-ha-home-cluster.md)
- **Date:** 2026-11-01
- **Applies to:** both sites (on for every aws.russetleaf.dev demo; always on, sampled, for russetleaf.dev)
- **Phase:** 1 (page traces, always on at home). Later: Phase 2 traces the summary pipeline end to end (100% of summary jobs); Phase 3 runs Tempo on every demo.

> **Update ([ADR 1020](1020-three-node-ha-home-cluster.md)):** The home cluster now has three nodes (`rl-home-cp03`: i5-8500T, 16 GB), so **Tempo runs always on at home** (sampled, 3-day retention), not on demand.

## Context

The design already has metrics (Prometheus), logs (Loki + Alloy), network flows (Hubble) and security events (Falco). Tracing was listed only as an optional WordPress-only extra, and the AWS plan had no step for it. The AI summary pipeline (WordPress → SQS → summarizer → LiteLLM gateway → Bedrock or llama.cpp) is asynchronous and crosses several services: when a summary is slow or fails, metrics and logs show *that* something went wrong, but not easily *where*.

Constraints: `rl-home-cp01` of the home lab has 8 GB of RAM and is close to its limit; EKS (demos only) has memory to spare; cost must stay near zero.

## Decision

- **Instrument with OpenTelemetry everywhere it matters**, built into the images and off unless an endpoint is configured:
    - WordPress: the OpenTelemetry PHP extension and Composer packages (auto-instrumentation for WordPress, database access and HTTP calls). **No WordPress plugin.**
    - The custom summary-queue must-use plugin adds the W3C `traceparent` to each SQS message's attributes.
    - The summarizer: the OpenTelemetry Python SDK, continuing the trace from the message.
    - The LiteLLM gateway: its built-in OpenTelemetry support.
- **Grafana Alloy** (already deployed for logs) receives traces over OTLP and forwards them to **Grafana Tempo** (single-binary mode, S3 storage).
- **aws.russetleaf.dev:** tracing **on for every demo**, 100% sampling, 7-day retention in a bucket that survives teardown.
- **russetleaf.dev:** tracing **always on** (since [ADR 1020](1020-three-node-ha-home-cluster.md)), ~10% sampling of page requests and 100% of summary jobs (Phase 2), 3-day retention.
- **Spans hold metadata only**: no post content, prompts or summaries.

## Alternatives considered

- **WordPress-only tracing (the previous plan):** misses the asynchronous AI pipeline, where tracing helps most.
- **Jaeger:** a well-known tracing backend, but a separate UI from Grafana, and its storage options are heavier for this setup; Tempo integrates directly with Grafana, Loki and Prometheus.
- **AWS X-Ray:** AWS-native, but does not cover the home site, and would split tracing between two tools.
- **A separate OpenTelemetry Collector:** unnecessary, since Alloy already runs on every node and handles OTLP.
- ~~**Always-on Tempo at home:** does not fit `rl-home-cp01`'s memory alongside everything else.~~ **Superseded by [ADR 1020](1020-three-node-ha-home-cluster.md):** with three nodes (`rl-home-cp03` has 16 GB), Tempo now runs always on at home.

## Consequences

- One trace shows a post's whole journey, including which model answered and how long each step took: useful for debugging and a strong demo.
- Trace IDs in logs link traces and logs in Grafana; exemplars link latency metrics to example traces.
- The summarizer and summary-queue plugin carry a little extra code for propagating trace context through SQS.
- Home tracing is sampled, so a rare slow request may need the sampling rate raised for a while to capture it.

## When to revisit

- Tempo's memory on `rl-home-cp03` grows too large: lower the sampling rate or retention.
- Trace volume growing beyond what single-binary Tempo handles: move to its scalable deployment mode.
- A move fully into AWS: reconsider X-Ray or AWS's managed options.

## Open items

- Phase 1 step 7.4: record Tempo's memory use and the sampling rates that work.
- Phase 3 step 2.4: Tempo on EKS, on for every demo; confirm a page request's trace and add a screenshot to the docs.
- Confirm the current OpenTelemetry PHP package names for WordPress, database and HTTP auto-instrumentation when building the image.
