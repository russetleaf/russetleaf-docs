# ADR 2005: Fine-tuning on a rented spot GPU, with drift-triggered retraining

- **Status:** Accepted; supersedes [ADR 3002](../../phase-3-russetleaf-com/adr/3002-fine-tuning-on-eks-gpu.md)
- **Date:** 2026-11-02
- **Applies to:** `russetleaf-llm-summarizer/training/`, the russetleaf-home AWS account, the home MLflow registry and llama.cpp
- **Phase:** 2. Phase 3 can run the same training on the EKS GPU node pool instead.

## Context

[ADR 2001](2001-mlops-lifecycle.md) defines the MLOps lifecycle; [ADR 3002](../../phase-3-russetleaf-com/adr/3002-fine-tuning-on-eks-gpu.md) put fine-tuning on the EKS GPU node pool, because the home lab has no GPU. That left Phase 2, if built without Phase 3, with no model training at all: evaluation, registry, serving and monitoring, but no training step and no retraining loop. Training and drift-triggered retraining are central to MLOps, and a review against a common MLOps curriculum (KodeKloud's 100 Days of MLOps: data versioning, experiment tracking, training, GPU training, registry, serving, canary deploys, drift-triggered retraining, GitOps) found this the one significant gap.

## Decision

- **Fine-tuning moves into Phase 2**, run on **one rented spot GPU instance** in the russetleaf-home account (e.g. a g6.xlarge), created for a training run and destroyed afterwards.
- **How a run works:** a `train` workflow in `russetleaf-llm-summarizer` (on the home runners) assumes a narrow **training-launcher role** and starts an instance from a Terraform-managed **launch template** (a GPU-ready image, an instance profile limited to reading the DVC training data and writing to the MLflow artifact bucket, outbound-only networking, a maximum run time). The instance runs the **same training container** the pipeline uses everywhere: fetch the DVC-versioned dataset, **LoRA** fine-tune the 3B base model, **evaluate against the base** (including the adversarial cases), convert to GGUF, and **register** the result in the home MLflow as a `local-summarizer` version with its scores and lineage. It then **terminates itself**; the workflow checks it is gone.
- **The challenger at home:** a version that beats the base becomes the **challenger** on `rl-home-cp02`, gets a canary share through the gateway, and is promoted only if online evaluation holds up for a week ([ADR 2003](2003-self-hosted-model-on-cp02.md)).
- **Drift-triggered retraining:** a sustained `InputDriftDetected` or `SummaryQualityDegraded`, or enough new feedback, **opens a retraining pull request** with the drift report and the proposed dataset version; merging it starts a training run. A person decides; nothing retrains on its own.
- **Drift reports with Evidently:** the online evaluation's drift checks use **Evidently**, a widely used open-source drift tool, rather than custom code.
- **Cost controls:** the GPU quota request is made early (Phase 2 step 1.2); the instance's maximum run time, the account budget and a `TrainingInstanceRunningLong` alert stop a forgotten instance; a run costs a few dollars.
- **Training data and teachers:** curated summaries from the feedback loop and the evaluation set, plus a stronger teacher model's outputs only where the provider's terms allow; otherwise an open-weights teacher.

## Alternatives considered

- **Fine-tuning on the EKS GPU node pool** ([ADR 3002](../../phase-3-russetleaf-com/adr/3002-fine-tuning-on-eks-gpu.md)): runs inside a cluster with its policies and monitoring, but only exists if Phase 3 is built; kept as an option for Phase 3.
- **A hosted notebook (Google Colab, SageMaker Studio Lab):** cheaper or free, but manual and outside infrastructure as code.
- **Amazon SageMaker training jobs:** managed and capable, but a separate platform from the home registry, at more cost and setup than one instance.
- **Fine-tuning on CPU at home:** impractically slow for a 3B model on these CPUs.
- **Fully automatic retraining on drift:** the textbook end state, but it spends money and changes production without review; a pull request keeps a person in the loop.

## Consequences

- Phase 2 covers the whole lifecycle on its own: data, training, evaluation, registry, deployment, monitoring and retraining.
- Phase 2 grows by about 25–40 hours and Phase 3 shrinks by about 20–35; the project as a whole grows by about 5.
- One more AWS pattern to secure: a launch template, a launcher role and an instance profile, all narrow, and a GPU quota to request.

## When to revisit

- A GPU at home: run the same container locally and drop the rented instance.
- Phase 3 is built: run the training on the EKS GPU node pool if that is cheaper or simpler at the time.

## Open items

- Phase 2 step 1.2: the GPU quota request; step 4.6: Evidently drift reports; steps 4.8–4.10: the training pipeline, the challenger and drift-triggered retraining.
- Confirm the teacher model's terms before generating training data.
