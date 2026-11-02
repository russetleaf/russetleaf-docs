# ADR 2001: Full MLOps lifecycle: tracking and registry, guardrails, online evaluation, data versioning and feedback

- **Status:** Accepted; fine-tuning split out to ADR 3002
- **Date:** 2026-11-01
- **Applies to:** `russetleaf-llm-summarizer`, the LLM gateway and the self-hosted model, on both sites
- **Phase:** 2. Fine-tuning is in Phase 3 (ADR 3002).

> **Update (ADR 3002):** the project is now built in three phases (ADR 1037). This ADR is Phase 2's. **Fine-tuning** (the distillation pipeline and deploying a fine-tuned challenger) needs a GPU, so it moved to Phase 3 and is recorded in ADR 3002; the rest of the lifecycle below runs at home in Phase 2.

## Context
The summary pipeline already had strong **inference-side** practices (often called LLMOps): versioned prompts, a CI evaluation gate with an LLM-as-judge, a model gateway with fallback and canaries, a self-hosted model, cost and latency monitoring, tracing, a model card and a re-summarize job. Senior MLOps work is judged on the **whole lifecycle** (data → training → evaluation → registry → deployment → monitoring → retraining), and the design was missing:
- experiment tracking and a model registry (results lived in CI comments; no lineage)
- monitoring of quality and drift **in production**
- guardrails (post content went straight into prompts; no injection defense, output validation or personal-data redaction)
- any training or fine-tuning
- data versioning
- a feedback loop

## Decision
- **MLflow** (on the home cluster; MariaDB for metadata, S3 for artifacts) for experiment tracking and a **model registry**, with `summarizer-config` and `local-summarizer` registered models, `champion` and `challenger` aliases, and promotion through reviewed `russetleaf-gitops` pull requests.
- **Guardrails** in the summarizer: injection-resistant prompting, output validation, personal-data redaction before calls leave the cluster, adversarial evaluation cases, and guardrail metrics and alerts.
- **Online evaluation and drift monitoring:** a daily sampled scoring job (Argo Workflows) logging to MLflow and Prometheus, with `SummaryQualityDegraded` and `InputDriftDetected` alerts.
- **Argo Workflows** as the workflow engine for the online evaluation and the nightly data export (and, in Phase 3, the fine-tuning pipeline; ADR 3002): Kubernetes-native (each step a pod, so it uses the cluster's scheduling, GPU node pool, policies and monitoring), defined as YAML in Git and synced by Argo CD, light (a controller and a server, about 0.2–0.3 GB), and part of the Argo family the project already uses.
- ~~A fine-tuning (distillation) pipeline on the EKS GPU node pool~~: moved to ADR 3002 (Phase 3).
- **DVC** for the evaluation, adversarial and training datasets (S3 remote), recorded in every MLflow run.
- **An editor feedback loop** in WordPress, exported nightly into the datasets.

## Alternatives considered
- **Kubeflow (Pipelines, Katib, KServe):** the full ML platform, but heavy for the home cluster and more than this project needs; Argo Workflows (already in the Argo ecosystem) runs the pipelines, and llama.cpp serves the model. (Kubeflow Pipelines itself runs on Argo Workflows underneath.)
- **Tekton:** Kubernetes-native pipelines aimed mainly at CI/CD; weaker support for data and ML workflows (artifacts, parameters between steps, retries per step, DAG visualization) than Argo Workflows.
- **Apache Airflow:** the standard for data pipelines, but a heavier, Python-centric scheduler with its own database and web server, and less natural for running each step as a GPU pod.
- **Plain Kubernetes CronJobs and Jobs:** enough for the daily online evaluation alone, but no multi-step pipelines with artifacts, retries per step, or a view of each run.
- **Amazon SageMaker** (training jobs, model registry, pipelines): AWS-native and capable, but doesn't cover the home site and would split the lifecycle across two platforms.
- **Weights & Biases or other hosted tracking:** polished, but a third-party service and account; MLflow is open source and self-hosted.
- **No fine-tuning (inference only):** simpler, but leaves out the training half of the lifecycle that senior MLOps roles expect; fine-tuning is kept, in Phase 3 (ADR 3002).
- **A heavyweight guardrail service** (e.g. Presidio, Llama Guard): more thorough, but adds memory and latency; rule-based guardrails plus adversarial evaluation cover this pipeline, with these as later options.

## Consequences
- Every result is traceable: which data, prompt, model and code produced it, and which version is in production.
- Quality is checked before release **and** monitored after it, with alerts on degradation.
- The pipeline resists injected instructions in posts and doesn't send personal data to external models.
- The self-hosted model's registry, canary and online evaluation are ready for a fine-tuned challenger from Phase 3 (ADR 3002).
- More components (MLflow, Argo Workflows, the online-evaluation job) and about 45–75 hours of work.

## When to revisit
- Many more models or teams: consider Kubeflow or a managed platform.
- Guardrail failures in practice: add Presidio or a guard model.
- A GPU at home: see ADR 3002.

## Open items
- Phase 2 steps 4.4–4.7: MLflow, guardrails, online evaluation, feedback and DVC.
- Fine-tuning and the challenger: see ADR 3002 (Phase 3 steps 4.5 and 4.6).
