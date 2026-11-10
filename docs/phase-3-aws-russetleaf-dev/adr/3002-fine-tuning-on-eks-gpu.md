# ADR 3002: Fine-tuning on the EKS GPU node pool, with the challenger served at home

- **Status:** Superseded by [ADR 2005](../../phase-2-ai-mlops/adr/2005-fine-tuning-on-a-rented-gpu.md) (fine-tuning moved to Phase 2, on a rented spot GPU)
- **Date:** 2026-11-02
- **Applies to:** `russetleaf-llm-summarizer/training/`, the EKS GPU NodePool, the home MLflow registry and llama.cpp
- **Phase:** 3 (needs Phase 2)

## Context

[ADR 2001](../../phase-2-ai-mlops/adr/2001-mlops-lifecycle.md) defines the MLOps lifecycle. Its training half, fine-tuning the small self-hosted model, needs a GPU, which only exists on EKS's spot GPU node pool. With the project in three phases ([ADR 1037](../../phase-1-russetleaf-dev/adr/1037-project-phases.md)), fine-tuning can only happen once both Phase 2 (the lifecycle, registry and datasets) and Phase 3 (the GPU) exist.

## Decision

- **A fine-tuning (distillation) pipeline** defined as an **Argo Workflows** template in `russetleaf-llm-summarizer/training/`, run on the EKS **spot GPU NodePool** during an AWS session: fetch the DVC-versioned dataset → **LoRA** fine-tune the 3B base model → **evaluate against the base** (including the adversarial cases) → convert to GGUF → **register** in the home MLflow as a `local-summarizer` version with its scores and lineage → propose it as **challenger** if it beats the base.
- **Cross-account access:** the training role in russetleaf-aws gets a narrow grant to write to the MLflow artifact and DVC buckets in russetleaf-home.
- **Serving at home:** the challenger is deployed to `rl-home-cp02`'s llama.cpp, gets a canary share through the gateway, is compared with the champion by online evaluation, and is promoted only if it holds up for a week.
- **Training data:** curated summaries from the feedback loop and the evaluation set, plus a stronger **teacher** model's outputs only where the provider's terms allow; otherwise an open-weights teacher.
- **Retraining triggers:** online quality dropping, enough new feedback, or a new base model.

## Alternatives considered

- **Fine-tuning on CPU at home:** possible for tiny models, but impractically slow for a 3B model on these 4- and 6-core mobile-class CPUs.
- **A one-off rented GPU (a single EC2 spot instance, or a hosted notebook) without EKS:** cheaper to set up and possible without Phase 3, but outside the cluster's scheduling, policies and monitoring; kept as the fallback if Phase 3 is not built.
- **Amazon SageMaker training jobs:** managed and capable, but a separate platform from the cluster and the home registry.
- **No fine-tuning:** leaves out the training half of the lifecycle ([ADR 2001](../../phase-2-ai-mlops/adr/2001-mlops-lifecycle.md)).

## Consequences

- The full MLOps lifecycle (data → training → evaluation → registry → deployment → monitoring → retraining) exists only when Phases 2 and 3 are both built.
- A few dollars of spot GPU time per run, plus the GPU quota request (days) in Phase 3 step 0.1.
- One cross-account grant to keep narrow and reviewed.

## When to revisit

- A GPU at home: run the same workflow locally and drop the cross-account grant.
- Phase 3 is not going to be built: use the rented-GPU alternative.

## Open items

- ~~Phase 3 steps 4.5 and 4.6~~: moved to Phase 2 steps 4.8–4.10 ([ADR 2005](../../phase-2-ai-mlops/adr/2005-fine-tuning-on-a-rented-gpu.md)).
- Confirm the teacher model's terms before generating training data.
