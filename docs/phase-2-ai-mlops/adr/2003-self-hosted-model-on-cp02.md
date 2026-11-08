# ADR 2003: Self-hosted model on rl-home-cp02 (CPU llama.cpp), dedicated by taint

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** the home cluster's `rl-home-cp02`, the LLM gateway, the model mirror bucket
- **Phase:** 2

## Context

The gateway ([ADR 2002](2002-summary-pipeline-architecture.md)) needs a fallback that does not depend on Bedrock, and the project should show model serving on Kubernetes, not only API calls. The home lab has no GPU. `rl-home-cp02` (a Dell OptiPlex 3040 with a 4-core i5-6500T and 8 GB) is an etcd member and control-plane node, so anything heavy on it risks the cluster's stability.

## Decision

- **llama.cpp (CPU build)** serving a 4-bit **3B model** (for example, Qwen2.5-3B or Llama 3.2 3B) through its OpenAI-compatible server, behind the gateway as the fallback and canary target.
- **`rl-home-cp02` becomes the dedicated LLM node** in Phase 2: label `workload=llm`, taint `dedicated=llm:NoSchedule`; only the model server (plus node agents and the CI runners, which tolerate the taint) runs there. In Phase 1, `rl-home-cp02` is an ordinary third node.
- **Protect etcd:** a **CPU limit** on llama.cpp (and the runners) that leaves about one core free, memory limits leaving about 1 GB free, and etcd latency watched while summaries run ([ADR 1026](../../phase-1-russetleaf-dev/adr/1026-cpu-limits.md)).
- **Model files from a mirror bucket** in S3, fed from the MLflow registry ([ADR 2001](2001-mlops-lifecycle.md)), so rebuilds do not depend on Hugging Face and every file in use has a registry entry.
- **The model stays loaded**; KEDA scales only the summarizer.

## Alternatives considered

- **Bedrock only:** simpler and better quality, but no fallback during Bedrock outages or throttling, and a dependence on one provider for every summary.
- **Running the model on `rl-home-cp03`:** more CPU and memory, but `rl-home-cp03` already carries most of the platform; mixing them makes both less predictable.
- **Ollama:** friendlier, but less control over the server and metrics than llama.cpp directly.
- **A cheap GPU card or a GPU mini PC at home:** much faster, but extra hardware cost and power; revisit if the AI work grows.

## Consequences

- Summaries from the local model are slow (seconds to tens of seconds each) but fine for a queue-based pipeline.
- `rl-home-cp02`'s memory use rises to about 6.5–7 GB, so it can no longer take overflow from `rl-home-cp03`.
- The fallback path is exercised in the burst test and in the node-failure drill (`rl-home-cp02` offline: the gateway uses Bedrock only).

## When to revisit

- A GPU at home: move the model to it, and run fine-tuning locally ([ADR 2005](2005-fine-tuning-on-a-rented-gpu.md)).
- etcd latency alerts while summaries run: lower llama.cpp's CPU limit or move the model off a control-plane node.

## Open items

- Phase 2 step 1.3: label and taint `rl-home-cp02`; step 3.1: deploy llama.cpp and record time per summary and memory use; step 3.2: gateway routing.
