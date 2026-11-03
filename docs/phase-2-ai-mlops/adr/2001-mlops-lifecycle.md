# ADR 2001: Full MLOps lifecycle: tracking and registry, guardrails, online evaluation, data versioning and feedback

- **Status:** Accepted; fine-tuning split out to [ADR 3002](../../phase-3-russetleaf-com/adr/3002-fine-tuning-on-eks-gpu.md)
- **Date:** 2026-11-01
- **Applies to:** `russetleaf-llm-summarizer`, the LLM gateway and the self-hosted model, on both sites
- **Phase:** 2, including fine-tuning ([ADR 2005](2005-fine-tuning-on-a-rented-gpu.md)).

> **Update ([ADR 3002](../../phase-3-russetleaf-com/adr/3002-fine-tuning-on-eks-gpu.md)):** the project is now built in three phases ([ADR 1037](../../phase-1-russetleaf-dev/adr/1037-project-phases.md)). This ADR is Phase 2's. **Fine-tuning** (the distillation pipeline and deploying a fine-tuned challenger) needs a GPU, so it moved to Phase 3 and is recorded in [ADR 3002](../../phase-3-russetleaf-com/adr/3002-fine-tuning-on-eks-gpu.md); the rest of the lifecycle below runs at home in Phase 2.

> **Update ([ADR 2005](2005-fine-tuning-on-a-rented-gpu.md)):** fine-tuning is back in Phase 2, on a rented spot GPU in AWS, with drift-triggered retraining proposals; the note below about Phase 3 is superseded.

## Context

The summary pipeline already had strong **inference-side** practices (often called LLMOps): versioned prompts, a CI evaluation gate with an LLM-as-judge, a model gateway with fallback and canaries, a self-hosted model, cost and latency monitoring, tracing, a model card and a re-summarize job. A production ML system covers the **whole lifecycle** (data → training → evaluation → registry → deployment → monitoring → retraining), and the design was missing:

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
- **Argo Workflows** as the workflow engine for the in-cluster pipelines: the **daily online evaluation** (sample summaries → score them → Evidently drift report → log to MLflow and Prometheus → open a retraining pull request when needed), the **nightly feedback export** into DVC, and the **retraining proposals**. Each step runs as a pod (using the cluster's scheduling, policies and monitoring), with artifacts passed between steps, retries per step and a visible history of every run; workflows are YAML in Git, synced by Argo CD; it is light (a controller and a server, about 0.2–0.3 GB) and part of the Argo family the project already uses. Fine-tuning itself runs outside the cluster on a rented GPU, started by a GitHub Actions workflow ([ADR 2005](2005-fine-tuning-on-a-rented-gpu.md)).
- ~~A fine-tuning (distillation) pipeline on the EKS GPU node pool~~: moved to [ADR 3002](../../phase-3-russetleaf-com/adr/3002-fine-tuning-on-eks-gpu.md) (Phase 3).
- **DVC** for the evaluation, adversarial and training datasets (S3 remote), recorded in every MLflow run.
- **An editor feedback loop** in WordPress, exported nightly into the datasets.

## Alternatives considered

- **Kubeflow (Pipelines, Katib, KServe):** the full ML platform, but heavy for the home cluster and more than this project needs; Argo Workflows (already in the Argo ecosystem) runs the pipelines, and llama.cpp serves the model. (Kubeflow Pipelines itself runs on Argo Workflows underneath.)
- **Tekton:** Kubernetes-native pipelines aimed mainly at CI/CD; weaker support for data and ML workflows (artifacts, parameters between steps, retries per step, DAG visualization) than Argo Workflows.
- **Apache Airflow:** the standard for data pipelines, but a heavier, Python-centric scheduler with its own database and web server, and less natural for running each step as a Kubernetes pod.
- **Plain Kubernetes CronJobs and Jobs:** one fewer component and about 0.2–0.3 GB less memory, and enough for single-step jobs such as the nightly export; but the online evaluation is a multi-step pipeline with an artifact (the drift report) and a conditional final step, which CronJobs handle only with custom scripting, retries for the whole job, and no view of each run. Reconsidered after fine-tuning moved out of the cluster ([ADR 2005](2005-fine-tuning-on-a-rented-gpu.md)); Argo Workflows was kept for the online evaluation.
- **Argo Events** (event-driven triggers, usually starting Argo Workflows through an event bus): not used. Every trigger in this project already has a simpler mechanism: GitHub events start GitHub Actions, schedules use workflow schedules or CronJobs, alerts reach Alertmanager webhooks, and the summary queue scales through KEDA. Argo Events would add an event bus (e.g. NATS), more components and memory, and a second way of doing the same things; worth revisiting only if many event sources had to start in-cluster workflows.
- **Amazon SageMaker** (training jobs, model registry, pipelines): AWS-native and capable, but does not cover the home site and would split the lifecycle across two platforms.
- **Weights & Biases or other hosted tracking:** polished, but a third-party service and account; MLflow is open source and self-hosted.
- **No fine-tuning (inference only):** simpler, but leaves out the training half of the lifecycle; fine-tuning is kept, in Phase 3 ([ADR 3002](../../phase-3-russetleaf-com/adr/3002-fine-tuning-on-eks-gpu.md)).
- **A heavyweight guardrail service** (e.g. Presidio, Llama Guard): more thorough, but adds memory and latency; rule-based guardrails plus adversarial evaluation cover this pipeline, with these as later options.

## Consequences

- Every result is traceable: which data, prompt, model and code produced it, and which version is in production.
- Quality is checked before release **and** monitored after it, with alerts on degradation.
- The pipeline resists injected instructions in posts and does not send personal data to external models.
- The self-hosted model's registry, canary and online evaluation are ready for a fine-tuned challenger from Phase 3 ([ADR 3002](../../phase-3-russetleaf-com/adr/3002-fine-tuning-on-eks-gpu.md)).
- More components (MLflow, Argo Workflows, the online-evaluation job) and about 45–75 hours of work.

## When to revisit

- The online evaluation shrinks to a single step: replace Argo Workflows with CronJobs.
- Many more models or teams: consider Kubeflow or a managed platform.
- Guardrail failures in practice: add Presidio or a guard model.
- A GPU at home: see [ADR 3002](../../phase-3-russetleaf-com/adr/3002-fine-tuning-on-eks-gpu.md).

## Open items

- Phase 2 steps 4.4–4.7: MLflow, guardrails, online evaluation, feedback and DVC.
- Fine-tuning, the challenger and drift-triggered retraining: see [ADR 2005](2005-fine-tuning-on-a-rented-gpu.md) (Phase 2 steps 4.8–4.10).
