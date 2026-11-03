# Phase 2 build plan: AI post summaries and MLOps

This is the step-by-step plan for **Phase 2**, described in the [Phase 2 design](design.md): AI-generated post summaries on russetleaf.dev, with an LLM gateway, a self-hosted model on `rl-home-cp02`, and an MLOps lifecycle. It needs **Phase 1's Core tier** finished (the cluster, GitOps, platform services, WordPress, ci, staging and promotion, Kyverno and network policies). Fine-tuning runs on a rented spot GPU in AWS, since the home lab has none ([ADR 2005](adr/2005-fine-tuning-on-a-rented-gpu.md)).

Each step is sized for one or a few Claude sessions and ends with a **test** that must pass before moving on. Work the same way as in Phase 1 (see its [How to use this plan with Claude](../phase-1-russetleaf-dev/plan.md#how-to-use-this-plan-with-claude)): start each session by pointing Claude at this plan, the Phase 2 design and the overview; one step at a time; record actual hours; keep the plan and decision log current. Before starting, write this phase's `roadmap.md` (milestones and dates, in the format of Phase 1's [roadmap](../phase-1-russetleaf-dev/roadmap.md)), create its issues with `tools/plan_to_issues.py`, and write a spec per step from [`docs/specs/TEMPLATE.md`](../specs/TEMPLATE.md).

## Working with AI agents

This phase is built with **AI coding agents** under [ADR 2004](adr/2004-agentic-ai-delivery.md); Phase 1 was built without them, so its actual hours are the baseline.

- **One step per agent session.** Write or approve the step's spec first; its acceptance criteria are the agent's definition of done. The agent works on a branch and opens a pull request.
- **Sandbox first:** agents iterate against the Docker Compose demo, unit tests, kind with LocalStack and the mock LLM, and the evaluation harness, never against the production cluster or the live Bedrock budget.
- **Least privilege:** agents use the identities from step 1.1b: branch and pull-request access on GitHub, the cluster's read-only role, and no secrets or AWS credentials.
- **Review:** every agent pull request runs the same checks as any other; review IAM, policies, network rules and anything touching secrets line by line.
- **Record the results** in the progress checklist: **Done by** (agent, operator or both) and **Review findings** (problems caught in review or CI that the agent missed), alongside actual hours. Each milestone retro includes a short section on the agents.

## Priorities and time estimates

Every step in the [progress checklist](#progress-checklist) has a **tier** and an **estimate** in focused hours (with Claude's help); expect ±50%.

| Tier | What it means | Steps | Est. hours |
|---|---|---|---|
| **Core** | A working, evaluated and secured summary pipeline: the repo, the agents' workspace and guardrails, AWS resources, `rl-home-cp02` as the LLM node, the WordPress side, KEDA, the gateway, the summarizer, its release and monitoring, the evaluation set, runners and gate, security for the new components, and the docs. | 1.1–1.4, 2.1–2.5, 4.1–4.3, 5.1, 5.3 | **~50–86** |
| **Extended** | The full MLOps lifecycle: the AI burst test, the self-hosted model and gateway routing, MLflow tracking and registry, guardrails, online evaluation and drift, and observability and operations for the AI components. | 2.6, 3.1, 3.2, 4.4–4.6, 5.2 | **~32–53** |
| **Advanced** | The feedback loop and data versioning (DVC); fine-tuning on a rented GPU, the fine-tuned challenger, and drift-triggered retraining; the AI operations assistant (kagent), and AI diagnosis with remediation proposed as pull requests. | 4.7–4.10, 5.2b, 5.2c | **~64–104** |
| **Total** | | | **~146–243** |

**Calendar time:** about **7–12 weeks at ~20 hours a week** (2–3.5 months at ~10), after Phase 1's Core tier. Allow a few days for Bedrock model access.

**Recommended order:** Stage 1, then the Core steps of Stages 2 and 4 (a working, evaluated pipeline), then 5.1 and 5.3; add the Extended steps after that. The fine-tuning steps (4.8–4.10) come last; request the GPU quota early (step 1.2), since approval can take days.

## Decisions to make before writing code

| Decision | Recommendation | Why it matters |
|---|---|---|
| **Summarizer language** | **Python** (boto3 for SQS, the `openai` client for the gateway, OpenTelemetry SDK). | Fastest path; the most common language for MLOps work. |
| **Models** | **Claude Haiku** (default) and **Amazon Nova Lite** on Bedrock, plus a 4-bit **3B model** (e.g. Qwen2.5-3B or Llama 3.2 3B) on `rl-home-cp02` with llama.cpp. | Sets the budgets, the evaluation set and `rl-home-cp02`'s memory use. |
| **AWS access for the AI components** | Pod roles through the cluster's OIDC provider if Phase 1 step 9.1 (keyless AWS access) is done; otherwise scoped IAM keys, like the rest of Phase 1. | Avoids adding new static keys if they can be avoided. |

ADRs for this phase: 2001 (MLOps lifecycle), 2002 (summary pipeline architecture) and 2003 (self-hosted model on `rl-home-cp02`), in `adr/` (see the [overview's index](../overview.md#architecture-decision-records)).

## Stage 1: Foundations

### Step 1.1: The `russetleaf-llm-summarizer` repo

**Do:** create **`russetleaf-llm-summarizer`** the same way as the Phase 1 repos (Phase 1 step 1.1): README, `.gitignore`, license, branch protection, gitleaks with a full-history scan, then **make it public** with secret scanning and push protection; **OpenSSF Scorecard**, **zizmor**, **dependency review**, **Checkov** (workflows first) and **Renovate** (Python lock file, base images, GitHub Actions, `.mise.toml`). Add the GitHub organization settings for it in `russetleaf-infra/envs/github/`. Layout: `src/`, `prompts/`, `evals/`, `guardrails/`, `chart/`, `ci/`, `demo/`, `online-eval/` (see the [Phase 2 design](design.md#repository-russetleaf-llm-summarizer)).

**Test:** the repo is public with a clean history scan and push protection on; a test pull request runs the secret scan and Checkov; Renovate opens its onboarding pull request.

### Step 1.1b: Agent workspace and guardrails

**Do** ([ADR 2004](adr/2004-agentic-ai-delivery.md)):

- **Agent instructions:** an `AGENTS.md` in `russetleaf-llm-summarizer`, `russetleaf-gitops`, `russetleaf-wordpress` and `russetleaf-docs` (the project's conventions, how to run each repo's checks, and what an agent must not do), and a `CLAUDE.md` in each that imports it.
- **Claude Code** is the coding agent ([ADR 2004](adr/2004-agentic-ai-delivery.md)): install it on the workstation with the permission settings below, and add the **Claude Code GitHub Action** to `russetleaf-llm-summarizer` and `russetleaf-gitops` for small tasks that come back as pull requests (read-only token defaults; it can never merge).
- **Permission settings** for the agent tool: allow the repo's local tools and tests; deny reading `.env` files, kubeconfigs with write access, talosconfigs and credential files; deny `terraform apply`, `kubectl apply` against the home cluster, `git push` to `main`, and `gh pr merge`.
- **Identities:** a read-only kubeconfig for agents (the `read-only` role from Phase 1 step 4.7, short-lived), and no AWS credentials in agent sessions.
- **Sandbox:** a documented local environment per repo (Docker Compose demo, kind with LocalStack and the mock LLM) that an agent can create and destroy on its own.
- **Pull-request template** in each repo: a "Done by" field and a checklist for the reviewer (IAM, policies, network rules, secrets, new dependencies).
- Add the **Done by** and **Review findings** columns to this plan's progress checklist (done), and an agents section to the milestone retro notes.

**Test:** an agent session in `russetleaf-llm-summarizer` can run the unit tests and the Compose demo, but is refused when it tries to read a `.env` file, apply to the cluster or push to `main`; with the agent's kubeconfig, `kubectl get secrets` is forbidden; the pull-request template appears on a test pull request.

### Step 1.2: AWS resources for the AI pipeline

**Do:** in `russetleaf-infra`, add the **`sqs-queue`** (with dead-letter queue) and **`bedrock-access`** modules, then in `envs/home`: the **summary queue** and dead-letter queue (production and staging), the **model mirror bucket** (with `prevent_destroy`), the **Bedrock budget alert**, and credentials for WordPress (send to the queue), the summarizer (read from the queue) and LiteLLM (`bedrock:InvokeModel` on the chosen models only), each in Secrets Manager (or pod roles, if Phase 1 step 9.1 is done). Confirm access to Claude Haiku and Amazon Nova Lite in the chosen region (Anthropic models may need a one-time use-case form in the console). Extend the ci stand-ins with SQS (LocalStack, or **ElasticMQ** if LocalStack's terms do not suit). Request a **GPU quota** for G-family spot instances in russetleaf-home now if the fine-tuning steps (4.8–4.10) are planned; approval can take days.

**Test:** each credential's allowed action works and a disallowed one fails (e.g. the summarizer cannot send to the queue); `aws bedrock-runtime converse` with the LiteLLM credential returns a response; the budget alert exists; deleting the model mirror bucket is refused by the plan.

### Step 1.3: `rl-home-cp02` as the LLM node

**Do:** in `russetleaf-infra/envs/home`, label `rl-home-cp02` `workload=llm` and taint it `dedicated=llm:NoSchedule`; give the ARC runners a matching toleration so they keep running there, next to the model; move anything else that ran on `rl-home-cp02` in Phase 1 (e.g. Backstage overflow) back to `rl-home-cp01` and `rl-home-cp03`; recheck the kubelet PID limit against llama.cpp's process count. Update the memory budget in the Phase 2 design.

**Test:** `kubectl describe node <box2>` shows the label and taint; only the runners and node agents run on `rl-home-cp02`; every node stays under its memory budget.

### Step 1.4: WordPress side of the pipeline (`russetleaf-wordpress`)

**Do:**

- The **summary-queue must-use plugin**: on publish or update, send `{"post_id": ...}` to SQS, adding the current trace context (W3C `traceparent`) as a **message attribute** when tracing is on (AWS SDK for PHP, installed with Composer at build time); the queue URL from an environment variable. It does **nothing when no queue URL is configured**, so the same image runs unchanged on sites without the pipeline (such as russetleaf.com in Phase 3).
- The `wordpress_posts_without_summary` metric in the metrics must-use plugin, and the **`WordPressPostsMissingSummaries`** alert in the chart (turned on in step 2.4). The alert is enabled only where the pipeline runs (russetleaf.dev).
- The styled **AI summary** box on posts in the `russetleaf` theme (model and prompt version in small print), with new visual-regression baselines.
- A dedicated WordPress user for the summarizer with an **application password** (created in step 2.3).
- ci: publishing a post sends a message to the stand-in SQS queue; the staging smoke test checks that a published post gets a summary (turned on in step 2.4).
- The WordPress CiliumNetworkPolicy allows the SQS endpoint by DNS name.

**Test:** in ci, publishing a post puts a message on the stand-in queue with the trace context attribute; the metric reports posts without summaries; the summary box renders in the visual tests.

## Stage 2: AI post summaries

### Step 2.1: KEDA

**Do:** `platform/keda/`: KEDA, with AWS credentials for the SQS scaler from External Secrets.

**Test:** a test `ScaledObject` scales a dummy Deployment from 0 to 1 when a message is sent to a test queue, and back to 0 when the queue is empty.

### Step 2.2: LiteLLM gateway

**Do:** `platform/llm-gateway/`: LiteLLM (with its OpenTelemetry tracing configured but pointed at Alloy only when tracing is on, and message-content capture **off**) with Claude Haiku (default) and Amazon Nova Lite on Bedrock, using the scoped Bedrock key; per-app budgets and rate limits (a separate key and small budget for staging); metrics exposed to Prometheus; an internal API key for callers.

**Test:** from a test pod, an OpenAI-style chat request to the gateway returns answers from both models; requests over the rate limit are refused; the gateway's metrics appear in Prometheus.

### Step 2.3: Summarizer code (`russetleaf-llm-summarizer`)

**Do:**

- A dedicated WordPress user for the summarizer (role: editor or a custom role that can edit posts only), with an **application password** created by `wp-cli` and stored in Secrets Manager.
- `src/`: SQS consumer (long polling, delete only after success, retries then dead-letter queue), WordPress adapter (REST API with that application password, calling WordPress's in-cluster Service rather than going out through Cloudflare: read the post, write the summary to the excerpt or a custom field), OpenAI-compatible model client pointed at the gateway, prompt loading from `prompts/` with the version recorded alongside each summary.
- **OpenTelemetry tracing** with the Python SDK (auto-instrumentation for boto3 and HTTP clients), built in and off unless an OTLP endpoint is configured: read `traceparent` from each SQS message and continue the trace; spans for reading the post, calling the gateway and saving the summary; metadata attributes only (model, prompt version, tokens), **never post text, prompts or summaries**; trace IDs in log lines.
- Unit tests (adapter and consumer with mocks, including trace-context extraction).
- `demo/`: Docker Compose with sample posts and a small mock WordPress endpoint, calling Bedrock through a local LiteLLM, so anyone can run it without Kubernetes.

**Test:** unit tests pass; `docker compose up` in `demo/` produces summaries for the sample posts.

### Step 2.4: Summarizer chart, release and deployment

**Do:**

- `chart/`: Deployment (Rollout later), KEDA `ScaledObject` on the SQS queue (0–N), daily sweep CronJob, ServiceAccount, resources.
- **Image and dependencies:** a **multi-stage** build with a **distroless or slim** runtime base; uv's lock file **with hashes**; chart signing as for `russetleaf-wordpress`; Secrets as files.
- **Code and image checks** (as for `russetleaf-wordpress`, see Phase 1 step 5.1): **ruff**, **mypy**, **Semgrep**, **pip-audit**, dependency review, hadolint, Checkov, zizmor, `helm lint` / `ct lint`, container-structure-test, Trivy (vulnerability, secret and misconfiguration scanners).
- `ci/`: kind end-to-end tests on GitHub-hosted runners, with the AWS stand-ins (SQS) and a **mock LLM** (LiteLLM with mock responses): a queued post gets a summary written back to a test WordPress; a failing message reaches the dead-letter queue.
- **Checkov on the summarizer's Dockerfile and chart** in pull request CI.
- Release workflow: build, SBOM, scan, push by digest, sign, attach the SBOM as a signed attestation, add **SLSA build provenance**, verify all three, write release notes with digests and Rekor links, push the image and the chart (OCI) to GHCR, open a chart-bump pull request on `russetleaf-gitops` for **`overlays/home-staging`** (promoted to prod by the Phase 1 step 5.7 pipeline).
- `russetleaf-gitops/apps/post-summarizer/overlays/home` and `overlays/home-staging`: queue URL, gateway URL (staging uses its own LiteLLM key and budget), WordPress URL, credentials from External Secrets.
- Turn on the summarizer check in the staging smoke tests (added in step 1.4).
- A **re-summarize job** (a CLI in `russetleaf-llm-summarizer`, run as a Kubernetes Job): find posts whose stored summary metadata matches a given prompt version or model, and re-queue them through SQS so they are summarized again with the current version. Document it in `docs/runbooks/rollback-models.md`.

Then turn on the **`WordPressPostsMissingSummaries`** alert (from the custom metrics plugin), routed to `#rl-mlops`.

**Test (end to end):** the kind tests pass in CI; a release goes through staging and is promoted; then publish a post on russetleaf.dev → a summarizer pod starts → the summary appears on the post within a few minutes → the pod scales back to zero. A message that always fails ends up in the dead-letter queue.

### Step 2.5: LLM monitoring

**Do:** OpenTelemetry metrics in the summarizer (tokens, latency, errors, fallbacks, estimated cost, all labeled by model and prompt version); the Grafana LLM dashboard and `PrometheusRule` alerts shipped **in the summarizer chart** (error spike, dead-letter queue not empty, daily Bedrock spend over a limit, all labeled `team=mlops` so they go to `#rl-mlops`, with runbooks), plus the log-based `SummarizerExceptions` and `BedrockThrottling` alerts in Loki; SQS queue depth in Grafana.

**Test:** the dashboard shows real numbers after a few posts; temporarily lowering the spend limit makes the alert appear in `#rl-mlops`.

### Step 2.6: AI pipeline burst test

**Do:** in staging, queue **200–500 posts at once** (a script sending post IDs to the staging queue) and watch: KEDA scale-out up to its limit, Bedrock throttling and the gateway's fallback to llama.cpp, the dead-letter queue, time to drain the queue, guardrail outcomes and cost per burst (from the gateway's spend metrics). Set KEDA's maximum replicas, the gateway's rate limits and the Bedrock budget thresholds from the results; record them in `docs/performance/`.

**Test:** the queue drains completely within the expected time, nothing is lost (failures end up in the dead-letter queue with alerts), the summarizer scales back to zero, and the burst's cost is recorded.

## Stage 3: Self-hosted model (`rl-home-cp02`)

### Step 3.1: llama.cpp model server

**Do:** `platform/llm-serving/`: llama.cpp server (CPU build) with a toleration and node selector for `rl-home-cp02`; an init container that downloads a 4-bit **3B model** (e.g. Qwen2.5-3B or Llama 3.2 3B) into a local-path volume (mirror the file in S3 so rebuilds do not depend on Hugging Face); metrics enabled; memory limits leaving ~1 GB free on the node, and a **CPU limit leaving about one core free**, because `rl-home-cp02` is also an etcd member (watch etcd's latency metrics while summaries run).

**Test:** the pod runs **only** on `rl-home-cp02`; an OpenAI-style request returns a summary; record the time per summary and memory use in the decision log.

### Step 3.2: Gateway routing to the local model

**Do:** add the local model to LiteLLM: fallback (Bedrock first, local if Bedrock fails), and a canary split (e.g. 10% of summary requests to the local model); llama.cpp metrics and model-down alert in Grafana.

**Test:** with Bedrock blocked (e.g. a wrong model ID in a test config), requests fall back to the local model; with the split on, about 10% of summaries show the local model's name in the metrics.

## Stage 4: MLOps pipeline

### Step 4.1: Evaluation set and scorers

**Do** (`russetleaf-llm-summarizer/evals/`): 20–30 sample posts with reference notes; rule-based checks (length, required keywords, no made-up links); an LLM-as-judge prompt for faithfulness; a script that runs the set against each model through a gateway URL and writes a report (JSON + Markdown).

**Test:** running the script locally against the gateway (via `kubectl port-forward`) produces a report comparing Haiku, Nova Lite and the local model.

### Step 4.2: Runners for `russetleaf-llm-summarizer`

**Do:** add a second ARC runner scale set (Phase 1 step 5.5) registered to **`russetleaf-llm-summarizer`**, on `rl-home-cp02` next to the model, with the same protections (approval for fork pull requests, self-hosted label limited to the evaluation workflows).

**Test:** a test workflow runs on a self-hosted runner pod, which is deleted afterwards; a fork pull request waits for approval.

### Step 4.3: Evaluation gate and releases

**Do:**

- Pull request workflow (on ARC runners): run the evaluation, post per-model scores as a pull request comment compared with `main`, fail below the threshold.
- Release workflow: run the gate again, then publish (step 2.4, into staging first), attach the report to the GitHub release, update `MODEL_CARD.md`.
- Post gate results (pass/fail, per-model scores, link to the report) to `#rl-mlops`.
- Optionally convert the summarizer to an Argo Rollouts canary.

**Test:** a pull request with a deliberately bad prompt fails the gate with a clear comment; a good one passes; a release tag publishes only after the gate passes.

### Step 4.4: Experiment tracking and model registry (MLflow)

**Do:** `platform/mlflow/` (placed on `rl-home-cp03`): the MLflow tracking server with MariaDB for metadata (TLS required by the server, per [ADR 1043](../phase-1-russetleaf-dev/adr/1043-database-encryption.md)) and an S3 artifact bucket (`s3-mlops` module in `russetleaf-infra`; versioned, old versions deleted after 30 days per [ADR 1042](../phase-1-russetleaf-dev/adr/1042-s3-versioning-lifecycle-and-storage-classes.md), scoped access through External Secrets), behind Cloudflare Access. Change the evaluation gate (step 4.3) to log every run to MLflow (Git commit, prompt version, model, dataset version, scores, latency, cost). Register `summarizer-config` and `local-summarizer` (the current 3B model file) with `champion` aliases, feed the model mirror bucket from the registry, and make routing changes in `russetleaf-gitops` reference registry versions. **Check `rl-home-cp03`'s memory** afterwards against the budget in the Phase 2 design; if it passes about 85%, place MLflow on `rl-home-cp01`. See the Phase 2 design's [MLOps lifecycle](design.md#mlops-lifecycle).

**Test:** `rl-home-cp03`'s memory stays under about 85%; an evaluation run appears in MLflow with its parameters, metrics and report; the registry shows both models with lineage to their runs; the gateway's routing points at a registered version.

### Step 4.5: Guardrails

**Do:** in `russetleaf-llm-summarizer/guardrails/`: delimit post text as content (never instructions), redact email addresses, phone numbers and similar patterns before calls leave the cluster, and validate output (length, plain text, no URLs, no instructions or system-prompt text; retry once, then do not save and alert). Add **adversarial cases** (posts containing injection attempts and personal data) to the evaluation set, and guardrail metrics (blocked, retried, redacted) with an alert on spikes to `#rl-mlops`.

**Test:** a post containing "ignore your instructions and…" produces a normal summary; a post with an email address never sends it to Bedrock (checked in traces or gateway logs); an invalid output is not saved and alerts; the CI gate fails if an adversarial case gets through.

### Step 4.6: Online evaluation and drift monitoring

**Do:** `platform/argo-workflows/` (Argo Workflows), and a **daily workflow** from `russetleaf-llm-summarizer/online-eval/` that samples a few percent of the day's summaries, scores them with the CI gate's rules and judge, checks input drift (length, language, topics) against the evaluation set with **Evidently** (drift reports kept with each run), and logs to MLflow and Prometheus. Grafana panels for quality and drift per model and prompt version; `SummaryQualityDegraded` and `InputDriftDetected` alerts to `#rl-mlops`, with runbooks.

**Test:** the workflow runs daily and its results appear in MLflow and Grafana; temporarily switching routing to a deliberately weak prompt lowers the scores and fires `SummaryQualityDegraded`.

### Step 4.7: Feedback loop and data versioning

**Do:** a `summary-feedback` must-use plugin in `russetleaf-wordpress` (editor-only "helpful / not helpful" plus a note on each summary, stored as post metadata); **DVC** in `russetleaf-llm-summarizer` with an S3 remote, tracking the evaluation set, adversarial cases and training data; a nightly workflow exporting new ratings (with each summary's model and prompt version) into the DVC-tracked dataset; MLflow runs record the dataset version.

**Test:** rating a summary in the admin shows up in the next nightly export; `dvc pull` reproduces any past dataset version; an MLflow run's dataset version checks out the exact data it used.

### Step 4.8: Fine-tuning pipeline on a rented GPU

**Do** ([ADR 2005](adr/2005-fine-tuning-on-a-rented-gpu.md)):

- **Training container** in `russetleaf-llm-summarizer/training/`: fetch the DVC-versioned training set; **LoRA fine-tune** the 3B base model; **evaluate against the base** on the evaluation set (including the adversarial cases); convert to GGUF; **register** the result in MLflow as a `local-summarizer` version with its scores, dataset version and Git commit; propose it as **challenger** if it beats the base. Build, scan and sign it like the summarizer image.
- **Infrastructure** in `russetleaf-infra/envs/home`: a **launch template** for one spot GPU instance (e.g. g6.xlarge; a GPU-ready image; outbound-only security group; a **maximum run time** after which the instance shuts itself down), an **instance profile** that can only read the DVC training data and write to the MLflow artifact bucket, and a **training-launcher role** for the `train` workflow (GitHub OIDC; may start and stop instances from that template only). The instance reaches the home MLflow through Cloudflare Access with a service token kept in Secrets Manager.
- **`train` workflow** (on the home runners, started by hand or by a merged retraining pull request): assume the launcher role, start the instance with the dataset version and base model as parameters, wait for the run to register its result, then confirm the instance has terminated.
- **Cost alert:** `TrainingInstanceRunningLong` when a training instance has been running longer than expected, to `#rl-costs` and `#rl-mlops`.
- Before generating training data with a teacher model, **check the provider's terms**; use an open-weights teacher if in doubt.

**Test:** a complete run finishes on a spot GPU instance, registers a model version with its metrics, dataset version and Git commit in MLflow, produces an evaluation report against the base, and leaves no instance running; the launcher role cannot start any other instance type; the run's cost is recorded in the checklist and [ADR 2005](adr/2005-fine-tuning-on-a-rented-gpu.md).

### Step 4.9: Deploy a fine-tuned challenger

**Do:** once step 4.8 has registered a fine-tuned `local-summarizer` version that beats the base model, deploy it to `rl-home-cp02` as the **challenger**: llama.cpp loads it from the model mirror bucket (fed from the registry), the gateway sends it a canary share of summaries, and online evaluation compares it with the champion. Promote it (MLflow alias plus a `russetleaf-gitops` routing pull request) only if it holds up for a week; update `MODEL_CARD.md`.

**Test:** the challenger serves its canary share; online evaluation shows champion-versus-challenger scores side by side; promotion or rejection is recorded in MLflow, the model card and the decision log.

### Step 4.10: Drift-triggered retraining

**Do:** when `InputDriftDetected` or `SummaryQualityDegraded` stays firing for a set period, or enough new feedback has accumulated, an Argo Workflows job **opens a retraining pull request** in `russetleaf-llm-summarizer` with the Evidently drift report, the proposed DVC dataset version and the expected cost; merging it starts the `train` workflow (step 4.8). A person always decides; nothing retrains on its own.

**Test:** forcing drift (e.g. replaying a batch of unusually long or off-topic posts in staging) opens a retraining pull request with the report attached; merging it starts a training run; closing it starts nothing.

## Stage 5: Platform integration and finishing

### Step 5.1: Security for the AI components

**Do:** extend Phase 1's controls to the new workloads:

- **Kyverno:** add the `russetleaf-llm-summarizer` release workflow's signing identity to image verification (signature, SBOM and provenance); Pod Security Admission labels (`restricted`) and quotas on the summarizer, gateway and model namespaces; KEDA on the service-account token allow-list; a `PolicyException` for llama.cpp's image only if it genuinely cannot run read-only or as non-root.
- **CiliumNetworkPolicies:** summarizer → SQS, the gateway and WordPress's REST API (a **layer-7** rule: `GET`/`POST` on `/wp-json/*` only); gateway → llama.cpp and `bedrock-runtime`; llama.cpp's init container → the model mirror bucket only.
- **Falco:** process allow-lists for the summarizer and gateway (`python`) and llama.cpp (`llama-server`); a rule for unexpected outbound connections from `rl-home-cp02`.
- Optional: a recorded **custom seccomp profile** for the summarizer (as in Phase 1 step 7.7).

**Test:** an unsigned summarizer image is rejected; a non-REST-API request from the summarizer to WordPress is blocked at layer 7; `curl https://example.com` from the gateway is blocked while Bedrock calls work; starting an unlisted process in the summarizer raises a Falco alert; the summary pipeline still works end to end.

### Step 5.2: Observability and operations for the AI components

**Do:**

- **Tracing:** turn tracing on in the summarizer and gateway values, sampling 100% of summary jobs.
- **Cost:** OpenCost with `rl-home-cp02` attributed to the LLM namespace and the Bedrock spend shown alongside; the Bedrock row in the monthly cost review.
- **SLOs:** summary **freshness** (99% within 15 minutes) and daily **quality** (95%) in Sloth, with the error-budget policy covering summarizer releases (if Phase 1 step 8.1 is done).
- **Chaos:** latency injected into model calls with a **Toxiproxy** sidecar in front of the gateway's upstream calls (Chaos Mesh's network rules cannot reliably target AWS endpoints), if Phase 1 step 8.6 is done.
- **Rollback:** `docs/runbooks/rollback-models.md` (routing revert, re-summarize job) and a drill: roll back a prompt version and re-summarize the affected posts.
- **Drills:** include the summarizer in the node-failure drill (`rl-home-cp02` offline: the gateway falls back to Bedrock).

**Test:** publishing a post produces **one trace** covering WordPress → the queue message → the summarizer → the gateway → the model call → saving the summary, showing which model answered, with no post text, prompts or summaries in any span; OpenCost shows the LLM namespace's cost; the re-summarize drill restores the earlier summaries; with `rl-home-cp02` off, summaries still arrive through Bedrock.

### Step 5.2b: AI operations assistant (kagent)

**Do** ([ADR 2006](adr/2006-ai-operations-assistant.md)):

- `platform/kagent/`: kagent (version pinned) on `rl-home-cp01`, with its tool servers for Kubernetes, Prometheus, Loki, Argo CD and Cilium only; tools that change anything are not installed. Check the current resource names and tool list in kagent's documentation.
- **Model:** a model configuration pointing at the **LiteLLM gateway**, with its own key, a small daily budget and rate limits.
- **Permissions:** service accounts bound to the **read-only** role, with no access to Secrets; Kyverno, Pod Security and a default-deny network policy like any platform namespace (egress only to the API server, Prometheus, Loki, Argo CD and the gateway).
- **Alert triage:** an Alertmanager webhook receiver sends critical (and selected warning) alerts to an assistant agent, which posts a **triage note** (likely cause, evidence, suggested next steps from the runbook) in the alert's Slack thread, labeled as AI-generated.
- **Incident scenarios:** a small evaluation set replayed in staging (a crash-looping pod, an out-of-memory kill, a failing probe, a network-policy drop, a bad canary), with each diagnosis scored as correct, partly correct or wrong; repeated after model or prompt changes.

**Test:** each incident scenario produces a triage note in Slack; at least four of the five diagnoses are correct or partly correct; the assistant's service account cannot read a Secret or change any resource (checked with `kubectl auth can-i`); its requests appear in the audit log; its spend shows on the LLM dashboard and stops at the budget.

### Step 5.2c: AI diagnosis and remediation proposals

**Do** ([ADR 2007](adr/2007-ai-diagnosis-and-remediation-proposals.md)):

- **Knowledge base:** PostgreSQL with **pgvector** (CloudNativePG, on `rl-home-cp01`; reuse the operator from Phase 1 step 8.3 if it exists); an Argo Workflows job that chunks and embeds the `russetleaf-docs` repo, the runbooks, the postmortems and the repos' code and Helm values (embeddings through the gateway, with its own budget), nightly and after merges to `main`; a small MCP server for search that returns passages with source links.
- **Agents** (kagent): a **diagnosis agent** (read-only tools plus knowledge-base search) that writes a diagnosis citing its sources; a **remediation agent** that, when the runbook's fix is a Git change, opens an `ai-proposed` pull request in `russetleaf-gitops` with the evidence, the cited runbook, the expected effect and how to undo it; a **verification agent** that comments on the pull request after merge with whether the alert cleared and the SLIs recovered.
- **Limits:** a GitHub App for the agents limited to branches and pull requests in `russetleaf-gitops` (no merge, no settings); a CI check that **rejects `ai-proposed` pull requests touching protected paths** (RBAC, Kyverno and network policies, secrets, Argo CD and Cilium configuration); one open proposal per incident and a daily limit; a kill switch.
- **Evaluation:** run the incident scenarios and selected chaos experiments in staging; score each run (correct diagnosis, correct runbook cited, a proposal the operator would merge, any harmful proposal) and log the results to MLflow.

**Test:** for each scenario, the diagnosis cites the right runbook; at least three of five proposals are pull requests the operator would merge as written; no proposal touches a protected path (and a test pull request that does is rejected by CI); with the kill switch on, no pull requests are opened; after a merged proposal, the verification comment reports the alert cleared.

### Step 5.3: Documentation

**Do:** finish ADRs [2001](adr/2001-mlops-lifecycle.md), [2002](adr/2002-summary-pipeline-architecture.md), [2003](adr/2003-self-hosted-model-on-cp02.md), [2004](adr/2004-agentic-ai-delivery.md), [2005](adr/2005-fine-tuning-on-a-rented-gpu.md) , [2006](adr/2006-ai-operations-assistant.md) and [2007](adr/2007-ai-diagnosis-and-remediation-proposals.md) (resolve their open items); update the Phase 2 design wherever the build differed; add the LLM dashboard, an evaluation report and an MLflow run to the hub README's screenshots; add the AI pipeline to the hub README's architecture diagram; optionally an article on evaluation gates for LLMs.

Also write **an account of building Phase 2 with agents** (`docs/agentic-delivery-phase-2.md` in `russetleaf-docs`, and optionally an article): what agents did, the guardrails, the review findings, and actual hours compared with the estimates and with similar Phase 1 work, using the checklist's **Done by** and **Review findings** columns ([ADR 2004](adr/2004-agentic-ai-delivery.md)).

**Test:** every Phase 2 ADR's open items are resolved or moved to a later phase; the README shows the pipeline.

## Ongoing operations (Phase 2 additions)

| Task | How often | How |
|---|---|---|
| Review Bedrock spend and model quality | Monthly | The gateway's spend metrics, the Bedrock budget, MLflow's online-evaluation runs and the drift panels |
| Check Bedrock model deprecations | Monthly | AWS's Bedrock model lifecycle notices; plan a replacement through the evaluation gate before a model is retired |
| Refresh the evaluation set | Quarterly | Add recent posts and new adversarial cases; record the dataset version in DVC |
| Re-summarize drill | Quarterly | Roll back a prompt version in staging and re-summarize, timing it |

## Progress checklist

| Step | Tier | Est. hours | Done | Date | Actual hours | Done by | Review findings | Node memory after | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1.1 `russetleaf-llm-summarizer` repo | Core | 2–3 | ☐ | | | | | | |
| 1.1b Agent workspace and guardrails | Core | 3–5 | ☐ | | | | | | |
| 1.2 AWS resources for the AI pipeline | Core | 3–5 | ☐ | | | | | | |
| 1.3 `rl-home-cp02` as the LLM node | Core | 1–2 | ☐ | | | | | | |
| 1.4 WordPress side of the pipeline | Core | 4–7 | ☐ | | | | | | |
| 2.1 KEDA | Core | 1–3 | ☐ | | | | | | |
| 2.2 LiteLLM gateway | Core | 3–5 | ☐ | | | | | | |
| 2.3 Summarizer code | Core | 8–12 | ☐ | | | | | | |
| 2.4 Summarizer chart + deploy | Core | 6–10 | ☐ | | | | | | |
| 2.5 LLM monitoring | Core | 3–6 | ☐ | | | | | | |
| 2.6 AI pipeline burst test | Extended | 3–5 | ☐ | | | | | | |
| 3.1 llama.cpp on `rl-home-cp02` | Extended | 4–6 | ☐ | | | | | | |
| 3.2 Gateway routing to local model | Extended | 2–4 | ☐ | | | | | | |
| 4.1 Evaluation set | Core | 5–8 | ☐ | | | | | | |
| 4.2 Runners for `russetleaf-llm-summarizer` | Core | 1–2 | ☐ | | | | | | |
| 4.3 Evaluation gate + releases | Core | 4–7 | ☐ | | | | | | |
| 4.4 MLflow tracking + registry | Extended | 6–10 | ☐ | | | | | | |
| 4.5 Guardrails | Extended | 6–10 | ☐ | | | | | | |
| 4.6 Online evaluation + drift | Extended | 6–10 | ☐ | | | | | | |
| 4.7 Feedback loop + DVC | Advanced | 6–10 | ☐ | | | | | | |
| 4.8 Fine-tuning on a rented GPU | Advanced | 19–31 | ☐ | | | | | | |
| 4.9 Fine-tuned challenger | Advanced | 4–7 | ☐ | | | | | | |
| 4.10 Drift-triggered retraining | Advanced | 2–4 | ☐ | | | | | | |
| 5.1 Security for the AI components | Core | 4–7 | ☐ | | | | | | |
| 5.2 Observability and operations for AI | Extended | 5–8 | ☐ | | | | | | |
| 5.2b AI operations assistant (kagent) | Advanced | 8–12 | ☐ | | | | | | |
| 5.2c AI diagnosis and remediation proposals | Advanced | 25–40 | ☐ | | | | | | |
| 5.3 Documentation | Core | 2–4 | ☐ | | | | | | |

## Decision log

| Date | Decision | Why |
|---|---|---|
