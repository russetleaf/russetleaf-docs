# ADR 0022: Full MLOps lifecycle: tracking and registry, guardrails, online evaluation, fine-tuning, data versioning and feedback

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** `llm-summarizer`, the LLM gateway and the self-hosted model, on both sites

## Context
The summary pipeline already had strong **inference-side** practices (often called LLMOps): versioned prompts, a CI evaluation gate with an LLM-as-judge, a model gateway with fallback and canaries, a self-hosted model, cost and latency monitoring, tracing, a model card and a re-summarize job. Senior MLOps work is judged on the **whole lifecycle** (data → training → evaluation → registry → deployment → monitoring → retraining), and the design was missing:
- experiment tracking and a model registry (results lived in CI comments; no lineage)
- monitoring of quality and drift **in production**
- guardrails (post content went straight into prompts; no injection defence, output validation or personal-data redaction)
- any training or fine-tuning
- data versioning
- a feedback loop

## Decision
- **MLflow** (on the home cluster; MariaDB for metadata, S3 for artifacts) for experiment tracking and a **model registry**, with `summarizer-config` and `local-summarizer` registered models, `champion` and `challenger` aliases, and promotion through reviewed `wp-gitops` pull requests.
- **Guardrails** in the summarizer: injection-resistant prompting, output validation, personal-data redaction before calls leave the cluster, adversarial evaluation cases, and guardrail metrics and alerts.
- **Online evaluation and drift monitoring:** a daily sampled scoring job (Argo Workflows) logging to MLflow and Prometheus, with `SummaryQualityDegraded` and `InputDriftDetected` alerts.
- **A fine-tuning (distillation) pipeline** on **Argo Workflows**, run on the EKS spot GPU NodePool during AWS sessions: versioned data → LoRA fine-tune → evaluate against the base → GGUF → register → challenger in the gateway canary; retraining triggered by quality drops, new feedback or new base models. Teacher outputs are used only where the provider's terms allow; otherwise an open-weights teacher.
- **DVC** for the evaluation, adversarial and training datasets (S3 remote), recorded in every MLflow run.
- **An editor feedback loop** in WordPress, exported nightly into the datasets.

## Alternatives considered
- **Kubeflow (Pipelines, Katib, KServe):** the full ML platform, but heavy for the home cluster and more than this project needs; Argo Workflows (already in the Argo ecosystem) runs the pipelines, and llama.cpp serves the model.
- **Amazon SageMaker** (training jobs, model registry, pipelines): AWS-native and capable, but doesn't cover the home site and would split the lifecycle across two platforms.
- **Weights & Biases or other hosted tracking:** polished, but a third-party service and account; MLflow is open source and self-hosted.
- **No fine-tuning (inference only):** simpler, but leaves out the training half of the lifecycle that senior MLOps roles expect.
- **A heavyweight guardrail service** (e.g. Presidio, Llama Guard): more thorough, but adds memory and latency; rule-based guardrails plus adversarial evaluation cover this pipeline, with these as later options.

## Consequences
- Every result is traceable: which data, prompt, model and code produced it, and which version is in production.
- Quality is checked before release **and** monitored after it, with alerts on degradation.
- The pipeline resists injected instructions in posts and doesn't send personal data to external models.
- The self-hosted model can actually improve, with a measured, reversible path to production.
- More components (MLflow, Argo Workflows, the online-evaluation job) and about 45–75 hours of work; fine-tuning runs cost a few dollars each.

## When to revisit
- Many more models or teams: consider Kubeflow or a managed platform.
- Guardrail failures in practice: add Presidio or a guard model.
- A GPU at home: run fine-tuning locally instead of on EKS.

## Open items
- Home plan steps 9.4–9.8: MLflow, guardrails, online evaluation, feedback and DVC, and deploying a fine-tuned challenger.
- AWS plan step 4.5: the fine-tuning pipeline on the GPU NodePool; record the first run's cost and its scores against the base model.
- Confirm the teacher model's terms before generating training data.
