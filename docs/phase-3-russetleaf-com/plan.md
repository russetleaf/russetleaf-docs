# Phase 3 build plan: russetleaf.com on EKS

This is the step-by-step plan for **Phase 3**, described in the [Phase 3 design](design.md): russetleaf.com on the full AWS design, brought up only for demos. It **starts after Phase 1's Core tier is built**: it reuses Phase 1's repos, Terraform modules, base manifests, images, charts and CI, and adds only what's specific to AWS. **Phase 2 is optional:** Stage 4 (AI post summaries on EKS, the GPU model, fine-tuning) and the AI items elsewhere, marked *(if Phase 2 is built)*, are skipped without it.

Each step ends with a **test** that must pass before moving on. Unlike the home lab, most of this stack costs money while it runs (about **$1/hour**), so the plan builds it in layers and tears each layer down between sessions until the demo workflows (Stage 6) automate it.

## How to use this plan with Claude

- **Start each session** with something like: *"Read `docs/overview.md`, the Phase 3 design and plan, and the Phase 1 design. We're working on Phase 3 step 2.3. Here's where I left off: ..."*.
- **One step at a time.** Build it, run the step's test, fix, commit, and **tear down** anything expensive before ending the session.
- **Check for leftovers after every session.** Every resource is tagged (see step 0.2); search by tag (AWS Resource Explorer or the Tag Editor) to confirm nothing from `envs/aws` is still running. Check the AWS Budget the next day.
- **Change the AWS overlay only.** Put AWS-specific settings in `overlays/aws`. If the base needs changing, send the change through Phase 1's environments first (local → ci → staging → russetleaf.dev), so russetleaf.dev never breaks. Application versions reach `overlays/aws` through the same `promote-to-prod` pull requests as russetleaf.dev.
- **Keep the plan current.** Tick the [progress checklist](#progress-checklist), record actual costs, and add to the [decision log](#decision-log).

## Workstation

Use the same Ubuntu 24.04 setup as the home lab ([Local workstation setup](../phase-1-russetleaf-dev/plan.md#local-workstation-setup-ubuntu-2404)). Additions for AWS:
- An AWS SSO profile for the demo account (or the same account), and `aws eks update-kubeconfig --name <cluster> --alias eks-com --profile <profile>` after each `demo-up`, so the kubeconfig context is clearly named.
- Nothing else to install: `terraform`, `kubectl`, `helm`, `argocd` and the AWS CLI from the home lab setup cover EKS. Pin the `kubectl` version in `wp-infra`'s `.mise.toml` within one minor version of the EKS version.

## Priorities and time estimates

Every step in the [progress checklist](#progress-checklist) has a **tier** and an **estimate** in focused hours (with Claude's help); expect ±50%, and record **actual hours** (and the stack cost) per session.

| Tier | What it means | Steps | Est. hours |
|---|---|---|---|
| **Core** | russetleaf.com working end to end in its own account: the always-on edge with the offline page, network, EKS with Karpenter, RDS for MariaDB with RDS Proxy, Valkey, the platform on EKS, WordPress, the demo workflows, one rehearsed and **recorded demo**, and the docs. | 0.1–2.4, 3.1, 3.2, 6.1, 6.2, 6.3 | **~71–117** |
| **Differentiator** | kube-bench and Kubescape on EKS, the security and cost reviews, and the EKS rollback drill. | 2.5, 5.1, 5.2, 6.1b | **~10–16** |
| **Stretch** | The Istio ambient and Tetragon experiments. | 5.3, 5.4 | **~6–10** |
| **Staff** | Load, stress and spike tests for the capacity plan, and EKS as a second spoke of the Argo CD hub. | 6.4, 6.5 | **~10–15** |
| **AI on EKS** *(if Phase 2 is built)* | The summarizer and gateway on EKS, the GPU model server, evaluation and tracing on AWS (Differentiator); the fine-tuning pipeline and the fine-tuned challenger (Stretch; valuable for MLOps roles specifically). | 4.1–4.4 (Differentiator), 4.5, 4.6 (Stretch) | **~28–52** |
| **Total** | | | **~125–210** (~97–158 without Phase 2) |

**Calendar time:** about **6–11 weeks at ~20 hours a week** for the whole plan (5–8 weeks without the AI steps), after Phase 1's Core tier is done (this plan depends on it). Allow for waiting: **SES production access**, and, if Phase 2 is built, the **GPU quota** request (days; submit it in step 0.1 well ahead) and **Bedrock model access** in the new account.

**Money:** the stack costs about **$1/hour** while running, so batch work into focused sessions and run `demo-down` at the end of each; record each session's cost in the checklist.

**Recommended order:** do the Core tier in plan order, with **3.1 → 6.1 → 6.2** (WordPress, demo workflows, recorded demo) as the first milestone; add the reviews next, then the AI steps if Phase 2 is built; the experiments last.

## Prerequisites from Phases 1 and 2

These steps must be done first, because this plan builds on them:

| Earlier step | What this plan reuses |
|---|---|
| Phase 1 step 1.1 Repos | The repos, branch protection, Renovate, secret scanning |
| Phase 1 step 2.1 Terraform bootstrap | State bucket, GitHub OIDC provider, CI role pattern |
| Phase 1 step 2.3 AWS + Cloudflare resources | The shared modules (`s3-media`, `s3-backups`, `secrets`; plus `sqs-queue` and `bedrock-access` from Phase 2 step 1.2) |
| Phase 1 step 2.4 `wp-infra` CI | Terraform checks and plan comments |
| Phase 1 step 3.1 GitOps structure | The `base/` + `overlays/` layout, app of apps, sync waves, manifest CI |
| Phase 1 stage 4 Platform services | Base manifests for External Secrets, monitoring, Kyverno, Argo Rollouts, Falco, Trivy Operator, OpenCost |
| Phase 1 step 4.5 MariaDB backups | The russetleaf.dev backups used to seed russetleaf.com |
| Phase 1 steps 5.1–5.3 WordPress | The image, the chart and image promotion |
| Phase 1 steps 5.4–5.7 Environments | ci test clusters, ARC runners, on-demand staging and the promotion pipeline (which also bumps `overlays/aws`) |
| Phase 1 steps 6.1–6.2 Policy and rollouts | Kyverno policies, the Rollout definition |
| *(If Phase 2 is built)* Phase 2 stages 1–3 | KEDA, the summarizer image and chart, gateway config, LLM dashboards and alerts |
| *(If Phase 2 is built)* Phase 2 stage 4 | The evaluation set and gate (they stay on the home lab's runners), MLflow and DVC |

## Stage 0: Preparation

### Step 0.1: Long-lead items and guardrails
**Do:**
- **All of russetleaf.com lives in its own account, `russetleaf-com`** (Workloads OU), created in this step by adding it to `wp-infra/envs/org` (the Organization itself is from Phase 1 step 2.0; see the Phase 1 design's [AWS account structure](../phase-1-russetleaf-dev/design.md#aws-account-structure-and-best-practices-security-reference-architecture) and ADR 0020). Quotas, SES sandbox status and Bedrock model access are **per account**, so the items below apply to `russetleaf-com`.
- *(If Phase 2 is built)* **Request a GPU quota increase** for G-family instances (both on-demand and spot) in **russetleaf-com**, in your region. New accounts usually start at 0 and approval can take days, so do this first.
- **SES production access** (or a verified test address) for russetleaf.com; *(if Phase 2 is built)* **Bedrock model access** for Claude Haiku and Nova Lite in russetleaf-com.
- **Backup account:** the disaster-recovery backup account and replication (Phase 1 step 2.5) must exist first; add the russetleaf.com media and backup buckets to its replication in step 1.2.
- **russetleaf.com DNS:** if the domain is registered outside Route 53, plan to move its name servers to Route 53 in step 1.2.
- **Budget guardrails:** the **russetleaf-com** account's budget (from `envs/org`, e.g. alerts at $20 and $40 per month), and a **Cost Anomaly Detection** monitor. Send both to an **SNS topic** connected to Slack `#rl-costs` through **Amazon Q Developer in chat applications** (formerly AWS Chatbot), as well as by email. (Created by hand here; Terraform's `alerting` module takes over in step 1.7.)

**Test:** the quota request is submitted; a test budget notification arrives by email and in `#rl-costs`.

### Step 0.2: Decisions to make before writing code
Record each answer in the [decision log](#decision-log).

| Decision | Recommendation | Why it matters |
|---|---|---|
| **Region** | **us-east-1** for everything. | CloudFront certificates must be in us-east-1 anyway; one region keeps Terraform simple. G6 spot availability is good there. |
| **Pod AWS access** | **EKS Pod Identity** (the newer, simpler option) instead of IRSA, unless a component only supports IRSA. | Decides how every service account gets AWS permissions. Both avoid stored keys. |
| **Image registry** | Keep **GHCR** for both sites (one registry, one Kyverno policy). Optional: an ECR pull-through cache for GHCR, so EKS pulls stay inside AWS. If the GHCR packages are still **private** (their visibility is separate from the repos'), EKS also needs the image pull secret and Argo CD GHCR credentials described in Phase 1 step 5.1. | One registry for both sites; see `docs/phase-1-russetleaf-dev/adr/0004-ghcr-not-ecr.md` (record the pull-through cache decision there). |
| **NAT Gateways** | **One** NAT Gateway for demos (saves about $65/month-equivalent while running), documented as "three in production". | Cost while the demo runs vs showing full AZ redundancy. One of the two deliberate demo cuts to high availability recorded in `docs/phase-1-russetleaf-dev/adr/0015-availability-levels.md`. |
| **Networking** | **Decided: Cilium in chaining mode** with the Amazon VPC CNI (the VPC CNI assigns pod IPs; Cilium enforces **CiliumNetworkPolicies** and provides Hubble), matching the home lab's Cilium. | Same policies, dashboards and alerts on both clusters; staying on the VPC CNI for IP addressing keeps EKS close to its defaults. |
| **Node OS** | **Amazon Linux 2023** EKS AMIs (with the NVIDIA variant for GPU nodes). | Falco's modern eBPF driver, the GPU drivers and Karpenter all support it. |
| **Monitoring on AWS** | The same **kube-prometheus-stack** as the home lab, plus **CloudWatch** for things Prometheus can't see (ALB, RDS, ElastiCache metrics, via the CloudWatch exporter or Grafana's CloudWatch data source). Skip Container Insights for demos. | The Argo Rollouts analysis needs request metrics, which come from the ALB (CloudWatch) on AWS, not from ingress-nginx. |
| **Self-hosted model size** | Start with the **same 3B model** as the home lab, so evaluation results are comparable; try a larger one on the GPU later. | The GPU (24 GB on a g6.xlarge) can run 7–8B models easily. |
| **Tagging** | Every resource gets `Project=russetleaf`, `Site=com`, `Stack=edge|demo`, `ManagedBy=terraform`. Set as provider `default_tags`. | Makes leftover checks and cost reports possible. |

## Stage 1: Infrastructure (`wp-infra`)

### Step 1.1: CI roles for the AWS environments
**Do:** extend `wp-infra/bootstrap/` to the **russetleaf-com** account (GitHub OIDC provider, audit role) with plan and apply roles for `envs/aws-edge` and `envs/aws`, with access to their own keys in the russetleaf-infra state bucket, limited to what each environment manages (the demo-stack apply role can't touch the edge stack's resources, and vice versa, where IAM conditions allow).

**Test:** a pull request touching `envs/aws-edge` gets a plan comment using the plan role; the apply role can be assumed only from `main`.

### Step 1.2: Always-on edge (`envs/aws-edge`)
**Do:**
- Route 53 hosted zone for russetleaf.com (point the registrar's name servers at it if needed), with **DNSSEC signing** (an asymmetric KMS key in us-east-1, about $1/month) and the **DS record** added at the registrar.
- ACM certificates: `russetleaf.com` + `www` in us-east-1 (CloudFront), and `origin.russetleaf.com` in the ALB's region (the same region if you chose us-east-1).
- S3 offline-page bucket with the offline page ("The AWS demo is offline. Visit russetleaf.dev."), the russetleaf.com **media bucket**, a **model mirror bucket** (the self-hosted model's file, so demo startup doesn't depend on Hugging Face), a **Loki log bucket** (14-day lifecycle) and a **Tempo trace bucket** (7-day lifecycle), both kept in the always-on stack so demo logs and traces can be reviewed after teardown. Origin Access Control on all of them.
- A CloudFront **response-headers policy** adding HSTS and the other security headers (the WordPress `security-headers` plugin supplies Content-Security-Policy) (ADR 0034).
- CloudFront distribution: default behavior → `origin.russetleaf.com` (all methods, HTTPS only, the `X-Origin-Verify` secret header, Host not forwarded); `/wp-content/uploads/*` → media bucket; `/offline/*` → offline bucket; custom error responses 502/503/504 → `/offline/index.html` with status 503; 10-second error caching; origin timeout 2 s, 1 attempt.
- The secret header value in Secrets Manager.
- SES domain identity for russetleaf.com, with DKIM records in Route 53.
- **`prevent_destroy`** on the hosted zone, CloudFront distribution, the media, log, trace and model mirror buckets, and Secrets Manager entries, so no plan (including a revert's) can delete them without a deliberate change (see the Phase 1 design's [Rollback strategy](../phase-1-russetleaf-dev/design.md#rollback-strategy)).
- A **russetleaf.com backup bucket** for the logical dumps taken at `demo-down`, and **replication** of it and the media bucket to the backup account (`envs/dr`).
- Outputs for `envs/aws` (zone ID, certificate ARNs, secret ARN, bucket names).

**Test:** `curl -I https://russetleaf.com` returns **503** with the offline page; the page links to russetleaf.dev; the SES identity shows "verified". Add the russetleaf.com **external uptime check** (expects 200 or the 503 offline page) and confirm it's green and posts to `#rl-com-alerts` and `#rl-critical` when it fails (test by pointing it at a wrong URL). Leave this stack running from now on (about $1/month).

### Step 1.3: Network (`envs/aws`)
**Do:** VPC across three AZs (in russetleaf-com): public and private subnets, Internet Gateway, the NAT Gateway(s) decided in step 0.2, an S3 gateway endpoint (free), **interface VPC endpoints** for STS, SQS, Secrets Manager and Bedrock (private traffic, lower NAT costs; check their hourly cost against demo hours), **VPC flow logs** delivered to the **Log Archive** account, the **default security group with no rules**, and the **default VPCs removed** in the allowed regions; subnet tags for the Load Balancer Controller and Karpenter discovery.

**Test:** `terraform apply` then `destroy` cleanly; subnets carry the right tags; flow logs arrive in Log Archive; traffic to SQS and STS from a test instance goes through the endpoints (no NAT bytes); (Cost while up: mainly the NAT Gateway.)

### Step 1.4: EKS cluster
**Do:**
- EKS cluster with a small **managed node group** (2 nodes, e.g. t3.medium) for Karpenter, CoreDNS and other system pods.
- **Secrets envelope encryption** with a **customer-managed KMS key** (ADR 0033), and kubelet `seccompDefault` on the nodes, plus a **per-pod PID limit** and **hard eviction thresholds** (ADR 0036), through the managed node group's launch template (AL2023 node configuration) and Karpenter's node configuration (step 2.3).
- Add-ons: VPC CNI (with its own network policy enforcement **off**, since Cilium enforces policies), CoreDNS, kube-proxy, **EBS CSI driver**, **Pod Identity agent**.
- **Cilium in chaining mode**, installed by Terraform's Helm provider right after the cluster and managed node group exist: `cni.chainingMode: aws-cni`, `cni.exclusive: false`, `enableIPv4Masquerade: false`, `routingMode: native`; Hubble and Hubble Relay on; **WireGuard transparent encryption** on, **if** the Cilium version you install supports it in chaining mode with the VPC CNI (check Cilium's documentation; if it doesn't, leave it off and record that in the open items of `docs/phase-1-russetleaf-dev/adr/0001-no-service-mesh.md`, relying on the TLS already on every sensitive connection); ServiceMonitors **off** until monitoring exists (step 2.4); `lifecycle { ignore_changes }` so Argo CD manages it afterwards from `platform/cilium/overlays/aws`. Restart any pods that started before Cilium (e.g. CoreDNS) so Cilium manages them.
- A Kubernetes version within **standard support**. EKS charges about six times more per hour for clusters on versions in extended support.
- **API endpoint:** public but **restricted to the home network's address** (private access also on, for the nodes). The demo workflows run on the **home ARC runners** (step 6.1), so they reach it from that address; your workstation does too (ADR 0032).
- **Add-on versions pinned** in Terraform; the monthly version-age workflow (Phase 1 step 7.6) checks `aws eks describe-addon-versions` and opens a pull request when newer compatible versions exist.
- **Access entries (ADR 0035):** IAM Identity Center permission-set roles mapped with EKS access policies: **view** (`AmazonEKSViewPolicy`) for day-to-day, **edit** (`AmazonEKSEditPolicy`) for operating, **cluster-admin** (`AmazonEKSClusterAdminPolicy`) only through a separate permission set; plus the CI apply role. Authentication mode **API only** (no `aws-auth` ConfigMap), and the cluster creator's automatic admin access turned off.
- Control plane logging: audit logs only, short CloudWatch retention (they're the useful ones and cost little), with a **subscription filter → Firehose → the Log Archive account's Object Lock bucket**, kept **1 year** (ADR 0035). **CloudWatch Logs metric filters** on the audit log for the persistence alerts (`KubeWorkloadCreatedOutsideArgoCD`, `KubeAdmissionWebhookChanged`, `KubeTokenSecretCreated`; ADR 0036) feed CloudWatch alarms to `#rl-security` through the `alerting` module's SNS topic, created and destroyed with the demo stack. **GuardDuty's EKS audit-log monitoring** (turned on account-wide in Phase 1 step 2.1) starts watching the cluster automatically.

**Test:** `kubectl get nodes` shows the managed nodes; `cilium status` is green and `cilium connectivity test` passes; if WireGuard is on, `cilium encrypt status` lists the other nodes as peers; a gp3 PersistentVolumeClaim binds; signing in with the view permission set can list pods but not read Secrets or delete anything; audit-log objects appear in the Log Archive bucket; tear down.

### Step 1.5: Karpenter infrastructure
**Do:** Karpenter's IAM (controller role via Pod Identity, node role and instance profile), the **interruption SQS queue** with EventBridge rules (spot interruption, rebalance, instance state change), and the Karpenter Helm release installed by Terraform (NodePools come from GitOps in step 2.3).

**Test:** the Karpenter controller is running and reports no errors.

### Step 1.6: Database and cache
**Do:**
- **RDS for MariaDB**, the same major version as the home lab (e.g. 11.4), Multi-AZ, private subnets, **`manage_master_user_password = true`** (RDS generates, stores and rotates the master password in Secrets Manager), security group allowing only the EKS nodes/pods, parameter group with `require_secure_transport = ON`, automated backups (7 days), encryption, `deletion_protection = false` (demo), `skip_final_snapshot = false` with a timestamped final snapshot name.
- **RDS Proxy** in front of it (engine family `MYSQL`, which covers MariaDB): `require_tls = true`; an auth entry for the `wordpress` user with **`iam_auth = REQUIRED`**, backed by a Secrets Manager secret holding a Terraform-generated password; a proxy IAM role that can read only that secret; security groups allowing EKS pods → proxy → RDS only. Optionally turn on Secrets Manager rotation for the `wordpress` secret.
- **Spike early (do this first in this step, and record the result in the decision log):** bring up a minimal RDS for MariaDB (single-AZ, smallest instance) with an RDS Proxy (`iam_auth = REQUIRED`), then from a test pod running the WordPress image, use a short PHP script to log in to the proxy with an IAM token over TLS. Costs a few cents for an hour. This decides between:
  - **Pass →** finish the `iam` mode of the `db.php` drop-in in `wp-image` (released through ci → staging → prod like any change), and continue with IAM auth as designed.
  - **Fail →** use the **fallback** from the Phase 3 design ([Risk: confirm IAM tokens work from PHP first](design.md#risk-confirm-iam-tokens-work-from-php-first-with-a-fallback)): set the proxy's auth to `iam_auth = DISABLED`; create the `wordpress` secret with **Secrets Manager automatic rotation** using the **alternating-users** strategy (`wordpress_a` / `wordpress_b`, e.g. every 30 days); sync it into the cluster with External Secrets; install **Reloader** (or use Rollouts restarts) so WordPress restarts on a new password; set `database.auth: password` in `overlays/aws`; drop `rds-db:connect` from the WordPress and seed-Job roles and grant them read access to the secret through External Secrets instead. Update steps 1.7, 3.1 and 3.2 accordingly.
- **Restore logic:** look up the most recent `russetleaf-com-final-*` snapshot; if one exists, restore from it, otherwise create an empty database.
- **ElastiCache Valkey** replication group (primary + replica, Multi-AZ), TLS in transit, AUTH token in Secrets Manager.
- Snapshot housekeeping: keep the last 3 final snapshots (a small Lambda or a scheduled GitHub Action deletes older ones).

**Test:** the spike's result is recorded in the decision log. **IAM path:** from a test pod, generate a token (`aws rds generate-db-auth-token --hostname <proxy-endpoint> --port 3306 --username wordpress`) and log in to the **proxy** over TLS with it (the MariaDB client needs its cleartext plugin enabled to send the token); confirm a plain password and a non-TLS connection are refused. **Fallback path:** log in to the proxy with the synced password, trigger a rotation by hand (`aws secretsmanager rotate-secret`), and confirm the old password keeps working until the next rotation and WordPress picks up the new one after its restart. Either way: confirm the master password exists only in Secrets Manager; connect to Valkey with TLS and the token; destroy creates a final snapshot; the next apply restores from it (create a test table to prove it).

### Step 1.7: russetleaf.com app resources and permissions
**Do:**
- Using the shared modules: Secrets Manager entries for russetleaf.com; *(if Phase 2 is built)* the summary SQS queue + dead-letter queue and Bedrock access (gateway role + budget alert).
- **WAF web ACL** for the ALB (AWS managed rule groups: core rule set, known bad inputs, WordPress, IP reputation; rate limiting on `/wp-login.php`).
- **Pod Identity associations** (one IAM role per service account, least privilege; the summarizer, LiteLLM, KEDA, llama.cpp and training roles only if Phase 2 is built): WordPress (media bucket, send to queue, SES send, **`rds-db:connect` on the proxy's `wordpress` user**), summarizer (read from queue), LiteLLM (Bedrock invoke on chosen models), External Secrets (russetleaf.com secrets), KEDA (queue attributes), ExternalDNS (the russetleaf.com zone), Load Balancer Controller, llama.cpp init container (model mirror bucket, read only), seed Job (read russetleaf.dev's backup and media buckets **in the russetleaf-home account**, granted by bucket policies there (and KMS key policies if those buckets use customer-managed keys), write russetleaf.com media bucket, `rds-db:connect` through the proxy), `db-setup` Job (read the RDS-managed master secret and the `wordpress` secret), **fine-tuning training role** (step 4.5: write to the MLflow artifact and DVC buckets in **russetleaf-home**, granted there by the `s3-mlops` module's cross-account bucket policy; read the training data), Falcosidekick/OpenCost if they need AWS APIs.
- SES SMTP credentials (or an IAM role for an SES API plugin) in Secrets Manager, the **Google OAuth client** secret for russetleaf.com (a separate client from russetleaf.dev's, redirect URL `https://russetleaf.com/...`, created in the Google Cloud console), and the **Slack bot token** entry for russetleaf.com (same bot, separate entry so the sites stay independent).
- **`alerting` module:** SNS topics; CloudWatch alarms for the ALB (5xx rate, target response time), RDS (CPU, free storage, connections, replica lag) and ElastiCache (memory, evictions), created and destroyed with the demo stack; Amazon Q Developer channel configurations for `#rl-com-alerts`, `#rl-critical` and `#rl-costs` (the Slack workspace is authorised once in the AWS console, then managed in Terraform).

**Test:** with `aws iam simulate-principal-policy`, each role allows exactly what it should and nothing else; forcing a CloudWatch alarm into ALARM state (`aws cloudwatch set-alarm-state`) posts to `#rl-com-alerts`.

### Step 1.8: Argo CD on EKS
**Do:** Terraform installs Argo CD with Helm and applies the root Application pointing at `wp-gitops/bootstrap/aws`. (In the Staff tier, step 6.5 replaces this with management from the home Argo CD hub; this per-cluster setup stays as the fallback.) Argo CD's UI is reached by `kubectl port-forward` only (no public endpoint for demos). **Argo CD Notifications** post to `#rl-deploys`, prefixed `[com]`.

**Test:** Argo CD lists the AWS root app (it will show missing components until Phase 2), and its first sync appears in `#rl-deploys`.

### Step 1.9: `wp-infra` CI for AWS
**Do:** extend the home lab's Terraform pipeline (Phase 1 step 2.4) to `envs/aws-edge` and `envs/aws`: tflint with the AWS ruleset, **Checkov** with the custom policies on the source and saved plans (results in GitHub code scanning), **Infracost** comments (especially useful here: they show the monthly cost of the always-on edge and of the demo stack if left running), and **`terraform test`** (with mocked providers where possible) for the AWS-specific modules (`alerting`, the CloudFront edge, RDS restore logic). `envs/aws-edge` applies go through the `apply` GitHub Environment after merge, like `envs/home`. `envs/aws` applies are done only by the demo workflows (Stage 6), which also require approval in the `apply` environment, never automatically on merge, so merging never starts a paid stack.

**Test:** a pull request shows plans and Infracost comments for all three environments; `terraform test` passes (and fails on a deliberately broken module input); a resource outside `us-east-1` or using an unapproved instance family fails the custom Checkov policies.

## Stage 2: AWS platform (`wp-gitops`)

### Step 2.1: AWS root app and sync waves
**Do:** `bootstrap/aws/` root app with sync waves: Karpenter NodePools and storage first; then External Secrets, Load Balancer Controller, ExternalDNS, Kyverno; then monitoring, KEDA, Argo Rollouts, gateway, model server; then WordPress and the summarizer. Exclude home-only components (cloudflared, ingress-nginx, local-path, MariaDB, Valkey, ARC).

**Test:** Argo CD syncs the root app; the order of creation matches the waves.

### Step 2.2: AWS-only platform components
**Do:**
- `platform/ingress/overlays/aws`: AWS Load Balancer Controller (Pod Identity).
- `platform/external-dns/`: ExternalDNS for the russetleaf.com zone, `--policy=sync`, a domain filter limited to `origin.russetleaf.com`, TXT ownership records.
- `platform/storage/overlays/aws`: gp3 StorageClass as default.

**Test:** a test Ingress creates an ALB and an `origin` DNS record; deleting it removes both.

### Step 2.3: Karpenter NodePools
**Do:** `platform/karpenter/`: `EC2NodeClass` (AL2023 with a **pinned AMI version**, tracked by Renovate rather than "latest", so node images only change through a reviewed pull request; subnets and security groups by tag, encrypted gp3 root volume, **IMDSv2 required with a hop limit of 1** so pods can't reach the node's instance credentials; kubelet settings for `systemReserved`, `kubeReserved`, hard eviction thresholds and the **per-pod PID limit** from ADR 0036, set through the EC2NodeClass's kubelet settings or AL2023 node configuration, whichever the installed Karpenter version supports); **general NodePool** (spot + on-demand, several instance families, consolidation on, disruption budget); **GPU NodePool** (g6 family, spot preferred, label `workload=llm`, taint `dedicated=llm:NoSchedule`, consolidation off or limited so the model isn't moved needlessly). Both NodePools add the **startup taint** `node.cilium.io/agent-not-ready=true:NoExecute`, so no pod is scheduled on a new node until Cilium is running there.
- **NVIDIA device plugin** (DaemonSet) so pods can request `nvidia.com/gpu`. (The AL2023 NVIDIA AMI includes the drivers.)

**Test:** scaling a test Deployment up adds nodes, scaling down removes them; a pod requesting a GPU gets a g6 node from the GPU pool; new nodes only accept pods once Cilium is ready (the startup taint is removed); simulate a spot interruption (e.g. AWS FIS or by hand) and watch Karpenter replace the node.

### Step 2.4: Shared platform services on AWS
**Do:** add `overlays/aws` for each shared component, changing only what AWS needs:
- External Secrets: Pod Identity instead of the bootstrap key.
- Monitoring: same stack; add CloudWatch metrics (ALB, RDS, RDS Proxy, ElastiCache) per the step 0.2 decision, in place of the home lab's MariaDB and Valkey exporters. The WordPress chart's apache_exporter, custom metrics and alerts work unchanged; point the blackbox_exporter probes at WordPress's in-cluster Service. Grafana is reached by `kubectl port-forward` only (there's no Cloudflare Access on this site). Alertmanager overlay: external labels `site=com`, `cluster=eks`; receivers for `#rl-com-alerts` and `#rl-critical`, plus the shared `#rl-security`, `#rl-mlops` and `#rl-costs` routes; the `Watchdog` heartbeat goes to its **own** heartbeat check, which is paused when the demo stack is down.
- **CiliumNetworkPolicies:** the same cluster-wide baseline and per-component policies from each component's `base/` (Phase 1 step 6.3), with AWS-specific destinations in `overlays/aws`: WordPress → the **RDS Proxy** and **ElastiCache** endpoints **by DNS name** instead of in-cluster MariaDB and Valkey; inbound to WordPress from the ALB (target-type `ip`, so traffic arrives from the VPC; allow the VPC's CIDR or the ALB's subnets); no cloudflared policy.
- **Cilium and Hubble metrics:** the same `platform/cilium/` monitoring values as home (ServiceMonitors, Hubble metric set, dashboards, alert rules), now that the Prometheus Operator exists; Hubble UI by `kubectl port-forward`.
- The same **Secrets Not From Env Vars**, user-namespace (if supported) and **mirrored-image** settings as home: EKS pulls the critical third-party images from the GHCR mirror.
- **Pod Security Admission labels** on every namespace, as at home (EKS doesn't enforce Pod Security by default), plus Kyverno's `restricted` set for application namespaces and the service-account token default.
- Kyverno: the same policy set as home, including SBOM and **SLSA provenance** attestations, upstream signature checks and **seccomp `RuntimeDefault`** (but not the gVisor rule: gVisor is home-only, so the WordPress AWS overlay leaves `runtimeClassName` unset; see `docs/phase-1-russetleaf-dev/adr/0009-gvisor-sandboxing.md`) (AWS's own add-on images aren't signed with cosign, so they stay covered by the registry allow-list and digest pinning); add AWS's add-on registries (the EKS add-on ECR registries and `public.ecr.aws`) to the **Restrict Image Registries** allow-list, and narrow **`PolicyException`s** for AWS-managed `kube-system` components that need privileged or host access or don't meet the label, probe, non-root or read-only rules (the VPC CNI's `aws-node`, `kube-proxy`, the EBS CSI node agent, the Pod Identity agent), plus Cilium, Falco and the NVIDIA device plugin. The project's own workloads get no exceptions.
- KEDA: Pod Identity for the SQS scaler.
- Argo Rollouts: an `AnalysisTemplate` variant using **CloudWatch** (ALB 5xx rate and target response time) instead of ingress-nginx metrics.
- **Logging:** `platform/logging/overlays/aws`: Loki (S3 via a Pod Identity role on the russetleaf.com log bucket, 14-day retention) and Alloy with `site=com`; no Talos log receiver; the EKS control-plane audit logs stay in CloudWatch. Alloy gets the same narrow Kyverno exception as at home.
- **Tracing:** `platform/tracing/overlays/aws`: Tempo (S3 via a Pod Identity role on the trace bucket, 7-day retention), **always on**; Alloy's OTLP receiver forwards to it; tracing turned on in the WordPress values (and the summarizer and gateway, if Phase 2 is built) with **100% sampling**.
- Falco: modern eBPF on AL2023, same custom rules (including the **process allow-lists**); Falcosidekick to `#rl-security`; the same health alerts as home (`FalcoNotRunning`, `FalcosidekickOutputErrors`, `FalcoEventsDropped`). On EKS, `FalcoNotRunning` also catches a new Karpenter node where Falco hasn't started.
- Kyverno's Policy Reporter and Argo Rollouts notifications: same Slack setup as home, prefixed `[com]`.
- cert-manager and trust-manager with the internal CA (as at home, ADR 0030); namespace LimitRanges and ResourceQuotas from the Kyverno generate rule; the `ArgoCDAppOutOfSync` alert.
- Trivy Operator, OpenCost (with AWS on-demand/spot pricing), and the AWS overlay's OpenCost alert **`GPUNodeRunningLong`** (to `#rl-costs`), an early warning before the demo safety net.

**Test:** each component is healthy; russetleaf.com's logs are searchable in Grafana and remain in the log bucket after `demo-down`; the home lab's Kyverno rejection tests (unsigned image, unlisted registry, `:latest`, missing labels or memory limit, privileged, root, writable root filesystem, no probes, NodePort/LoadBalancer Service, duplicate Ingress host) all still fail on EKS; OpenCost shows EC2 costs for the nodes.

### Step 2.5: kube-bench and Kubescape scan
**Do:**
- **kube-bench** (see `docs/phase-3-russetleaf-com/adr/0012-kube-bench-eks-only.md`): `platform/kube-bench/` holds **Job templates, one per node pool** (managed node group, Karpenter general pool, GPU pool with the `dedicated=llm` toleration), using the **EKS CIS benchmark** profile, writing **JSON and text** output, with `ttlSecondsAfterFinished` so they clean up. They're applied by the `demo-up` workflow (step 6.1), not synced by Argo CD. For now, run them by hand:
  - the JSON output reaches **Loki** through Alloy; add a Grafana panel (pass/fail/warn counts per node pool, per run) using Loki's JSON parsing
  - commit a summary to `docs/security/kube-bench-eks-<date>.md`, and create `docs/security/kube-bench-accepted.yaml` listing accepted findings with reasons
  - the summary covers each node pool, with any failures and why they're accepted or fixed. The summary states that the **control plane is AWS-managed** (shared-responsibility model): EKS enables only Node and RBAC authorization plus AWS's access-entry webhook, and ABAC can't be enabled; kube-bench's node-side checks (kubelet anonymous access off, webhook authorization) must pass. As a direct check, from a test pod an anonymous request to a node's kubelet API (`curl -sk -o /dev/null -w '%{http_code}' https://<node-ip>:10250/pods`) must return `401`, for a managed node-group node and a Karpenter-created node alike.
- A **Kubescape CLI** scan of the EKS cluster from the workstation (NSA-CISA and MITRE ATT&CK frameworks, plus RBAC analysis; nothing installed in the cluster), saved in `docs/security/` with a summary, and compared with the home cluster's scores. Fill in the EKS open item in `docs/phase-1-russetleaf-dev/adr/0003-kubescape-cli-not-operator.md`.

**Test:** a kube-bench Job runs on each node pool and completes; its results appear in the Grafana panel (from Loki); the summary and accepted-findings file are committed; the Kubescape report is committed; the Compliance dashboard shows EKS next to the home cluster (Trivy Operator metrics); any differences between the home and EKS Kubescape scores are explained (e.g. AWS-managed components).

## Stage 3: WordPress on russetleaf.com

### Step 3.1: WordPress AWS overlay
**Do:** `apps/wordpress/overlays/aws`:
- `WP_HOME`/`WP_SITEURL` = `https://russetleaf.com`; the HTTPS-behind-proxy setting.
- 3 replicas, HPA (3–10), PDB, **topology spread** across AZs.
- **`database.auth: iam`** with the **RDS Proxy endpoint**, region and the RDS CA bundle (no database password Secret at all); Valkey endpoint (TLS);
- `apps/db-setup/`: an idempotent **PreSync Job** that reads the master and `wordpress` secrets and runs `CREATE USER IF NOT EXISTS` / `GRANT` for the `wordpress` user (real work only on the first demo; the user survives in the final snapshot); russetleaf.com media bucket with the **CloudFront domain** as the media URL in the offload plugin, SQS queue URL, SES for email.
- Ingress for the ALB: `origin.russetleaf.com`, the ACM certificate, the WAF ACL, a listener rule requiring the `X-Origin-Verify` header (requests without it get 403), and a security group allowing only the CloudFront origin-facing prefix list.
- **Admin sign-in:** the same Google OIDC plugin configuration as home, with russetleaf.com's client; a **second Ingress in the same ALB group** for `/wp-admin/*` and `/wp-login.php` with the ALB's **OIDC authentication** (Google) in front; CloudFront behaviors for those paths and the OIDC callback that are **uncached** and forward cookies and query strings (update `envs/aws-edge`).
- The Rollout using the CloudWatch analysis template.

**Test:** after sync, russetleaf.com switches from the offline page to the live site on its own; WordPress's custom metrics and apache_exporter are scraped, and the metrics port is **not** reachable through CloudFront or the ALB; the WordPress pods have **no database password** in their environment or Secrets; a forced Multi-AZ failover (`aws rds reboot-db-instance --force-failover`) causes only a few seconds of errors, and terminating a WordPress node lets Karpenter replace it with the site staying up (record both recovery times in `docs/phase-1-russetleaf-dev/adr/0015-availability-levels.md`); requesting the ALB directly (without CloudFront) returns 403; media loads from CloudFront; a test SQL-injection request is blocked by WAF; the password-reset email arrives (SES sandbox: send to a verified address, or request production access). `/wp-admin` requires a Google login at the ALB, then signs in to WordPress with Google and no password; a password login attempt is rejected; the summarizer's application password still works.

### Step 3.2: Content
**Do:**
- `apps/seed-from-dev/`: the one-off seed Job (manual sync): download the latest russetleaf.dev backup, import into RDS **through RDS Proxy with an IAM token**, `wp search-replace 'russetleaf.dev' 'russetleaf.com' --all-tables`, `aws s3 sync` the media.
- Run it once for the first demo.

**Test:** russetleaf.com shows the same posts and images as russetleaf.dev; destroy and re-create the demo stack, and the content is still there (restored from the final snapshot).

## Stage 4: AI post summaries on EKS *(if Phase 2 is built)*

### Step 4.1: Summarizer and gateway
**Do:**
- `overlays/aws` for `post-summarizer` (russetleaf.com queue, Pod Identity, gateway URL, WordPress's in-cluster Service URL) and `llm-gateway` (Pod Identity for Bedrock, same routing config as home).
- A **russetleaf.com application password** for the summarizer's WordPress user, created with `wp-cli` and stored in russetleaf.com's Secrets Manager entries. (After a seed from russetleaf.dev, the user exists but the russetleaf.dev password shouldn't be reused; revoke it on russetleaf.com and create a new one.)

**Test:** publishing a post on russetleaf.com produces a summary; the summarizer scales back to zero; LLM dashboards show russetleaf.com traffic.

### Step 4.2: Self-hosted model on the GPU pool
**Do:** `platform/llm-serving/overlays/aws`: the llama.cpp **CUDA** server image (a third-party image: add a Kyverno exception for its exact digest, or rebuild and sign it in your own CI), `nvidia.com/gpu: 1` limit, tolerations and node selector for the GPU pool, the init container reading the model from the **model mirror bucket**; add it to the gateway's routing.

**Test:** the pod lands on a spot g6 node; tokens per second are recorded (compare with box 2 in the decision log); gateway fallback to the local model works.

### Step 4.3: Evaluation on AWS (once)
**Do:** run the `llm-summarizer` evaluation script against the EKS gateway (via `kubectl port-forward`), and save the report next to the home lab's report in `llm-summarizer/evals/reports/`.

**Test:** the report compares the same models on CPU (home) and GPU (AWS), including latency and cost per summary.


### Step 4.4: End-to-end tracing on EKS
**Do:** with Tempo running (step 2.4), publish a post on russetleaf.com and follow its trace in Grafana from WordPress through SQS, the summarizer and the gateway to the model call (Bedrock or the GPU model) and back. Save a screenshot for the docs and demo script, and fill in the AWS open item in `docs/phase-1-russetleaf-dev/adr/0006-tempo-tracing.md`.

**Test:** one trace covers the whole pipeline and shows which model answered and each step's duration; traces from a demo are still viewable after `demo-down` (they're in the always-on trace bucket); no span contains post text, prompts or summaries.
### Step 4.5: Fine-tuning pipeline (distillation) on the GPU NodePool
**Do:** install Argo Workflows on EKS (`platform/argo-workflows/overlays/aws`) and run the `llm-summarizer/training/` workflow on the **spot GPU NodePool** during an AWS session: pull the DVC-versioned training set; **LoRA fine-tune** the 3B base model; **evaluate against the base** on the evaluation set (including the adversarial cases); convert to GGUF; **register** the result in the home MLflow as a `local-summarizer` version with its scores and lineage (the training role gets a narrow cross-account write grant to the MLflow artifact and DVC buckets in russetleaf-home); propose it as **challenger** if it beats the base. Before generating training data with a teacher model, **check the provider's terms**; use an open-weights teacher if in doubt. See the Phase 2 design's [MLOps lifecycle](../phase-2-ai-mlops/design.md#mlops-lifecycle).

**Test:** a complete run finishes on a spot GPU node, registers a model version with its metrics, dataset version and Git commit in MLflow, and produces an evaluation report against the base; the run's cost is recorded in the checklist and ADR 0022.

### Step 4.6: Deploy a fine-tuned challenger (at home)
**Do:** after step 4.5 has produced a registered fine-tuned `local-summarizer` version that beats the base model, deploy it to box 2 as the **challenger**: llama.cpp loads it from the model mirror bucket (fed from the registry), the gateway sends it a canary share of summaries, and online evaluation compares it with the champion. Promote it (MLflow alias plus a `wp-gitops` routing pull request) only if it holds up for a week; update `MODEL_CARD.md`.

**Test:** the challenger serves its canary share; online evaluation shows champion-versus-challenger scores side by side; promotion or rejection is recorded in MLflow, the model card and the decision log.

## Stage 5: Security and cost review

### Step 5.1: Security review
**Do:** run an OWASP **ZAP baseline scan** against russetleaf.com (through CloudFront) and check the **security headers** (e.g. with `curl -I` and a header-checking tool); confirm and document the **component hardening checks** for EKS (ADR 0033: envelope encryption with the customer-managed key and endpoint access in `aws eks describe-cluster`, PSA labels with pinned versions on every namespace, no service-account token on WordPress pods, kubelet read-only port refused); **Security Hub** shows russetleaf-com with no unexplained critical or high findings (record the score; optionally turn on **Inspector** for the EKS nodes during this demo); no instance allows IMDSv1; the ALB rejects non-CloudFront traffic; RDS, RDS Proxy and Valkey aren't reachable from outside the VPC; no application holds a database password (IAM tokens through the proxy), and the master password is RDS-managed and rotating; no pod has an AWS key (Pod Identity everywhere); the ADR 0036 checks pass on EKS (a fork bomb stops at the PID limit, a CronJob created by hand raises the persistence alarm, Kyverno rejects a Role with `impersonate`, the exfiltration test is blocked); the ADR 0038 checks pass on russetleaf.com (the privacy notice is linked, the no-cookies check passes, and GuardDuty's EKS finding types are in the ATT&CK map); the ADR 0037 checks pass on EKS (Kyverno's three admission replicas spread across zones, the ValidatingAdmissionPolicy backstops present, metrics-server and Prometheus verifying the kubelets' certificates, the enabled admission plugins recorded from AWS's documentation for the version, and the cluster PKI noted as AWS's responsibility); access entries match ADR 0035 (no unexpected cluster-admin, authentication mode API only) and the demo's audit logs reached the Log Archive bucket; platform namespaces are default-deny; GuardDuty shows the EKS cluster under audit-log monitoring, with any findings explained (and `aws guardduty create-sample-findings` for EKS reaching `#rl-security`); AWS WAF blocks requests to `/xmlrpc.php` and rate-limits `/wp-login.php`; pod traffic between nodes is encrypted (WireGuard), or the ADR explains why not; CiliumNetworkPolicies enforce (from a WordPress pod, `curl https://example.com` is blocked; `hubble observe --verdict DROPPED` shows only expected drops); Kyverno enforces; Falco alerts fire on EKS (repeat the home lab's `kubectl exec` test); Trivy Operator reports; kube-bench and Kubescape reports committed for this demo; a **Prowler** run (the `wp-infra` workflow from Phase 1 step 7.5, triggered by hand) with the demo stack up, covering EKS, RDS, ElastiCache, the ALB and the rest of `envs/aws`, with findings fixed in Terraform or explained (fill in the AWS open item in `docs/phase-1-russetleaf-dev/adr/0007-prowler-not-threatmapper.md`).

**Test:** a written checklist in `docs/` with each item checked.

### Step 5.2: Cost review
**Do:** a **daily scheduled workflow** in `wp-infra` (Cost Explorer data lags about 24 hours) that checks for recent demo usage, queries **Cost Explorer** grouped by the `Site` and `Stack` tags (the cost allocation tags activated in Phase 1 step 2.1), and posts "Last demo: $X for Y hours ($Z/hour)" to `#rl-costs`, compared with the ~$1/hour estimate. After the first full demo, also compare it with OpenCost's estimate for the same demo (captured before `demo-down`), and record both in `docs/phase-1-russetleaf-dev/adr/0013-opencost-and-aws-billing.md`.

**Test:** the day after a demo, the cost report appears in `#rl-costs` with the right hours; actual cost per demo hour is recorded in the decision log, and the Phase 3 design is updated if the estimates were off.

### Step 5.3 (optional): Istio ambient experiment on EKS
**Do:** during a demo session, install **Istio ambient mode** alongside Cilium on the EKS cluster (Istio's instructions for running with Cilium), add the WordPress and summarizer namespaces to the mesh, and try mTLS plus one layer-7 authorization policy. Measure the extra memory and latency, note any conflicts with Cilium's policies, then remove it before `demo-down`. Add the findings to `docs/phase-1-russetleaf-dev/adr/0001-no-service-mesh.md`. Nothing in the site depends on it.

**Test:** the ADR includes the EKS findings (resource use, latency, setup issues, what it added), and Istio is fully removed afterwards.

### Step 5.4 (optional): Tetragon process enforcement on EKS
**Do:** during a demo session, install **Tetragon** (Cilium's runtime-security tool) and add a tracing policy that **kills any process** in the WordPress pods that isn't on its allow-list (`apache2`, `php`). Check that normal traffic, uploads and the summarizer still work, then try running an unlisted program. Measure Tetragon's memory use per node, remove it before `demo-down`, and record the findings in `docs/phase-1-russetleaf-dev/adr/0016-process-allow-listing.md` (including whether it's worth trying at home).

**Test:** an unlisted process in a WordPress pod is killed immediately (and reported); the site keeps working; Tetragon is fully removed afterwards.

## Stage 6: Demo operations

### Step 6.1: Demo workflows
**Do:** GitHub Actions in `wp-infra`, started by hand (`workflow_dispatch`), running on the **home ARC runners** (Phase 1 step 5.5), so the restricted EKS API endpoint accepts them:
- **`demo-up`:** `terraform apply` in `envs/aws`; wait for Argo CD to sync; wait until russetleaf.com returns 200; resume the russetleaf.com heartbeat check; **run the kube-bench Jobs** (one per node pool), wait for them to finish, collect their JSON and text output as workflow artifacts, compare with `docs/security/kube-bench-accepted.yaml`, commit the summary to `docs/security/` (through a pull request on `wp-gitops`), and post pass/fail/warn counts to `#rl-security`, flagging new failures; post the start time (e.g. as a tag on the VPC) and "russetleaf.com demo started" to `#rl-com-alerts`.
- **`demo-down`:** take a **logical dump** of the RDS database (a one-off Job through RDS Proxy) into the russetleaf.com backup bucket, which replicates to the backup account (see `docs/phase-1-russetleaf-dev/disaster-recovery.md`); create an Alertmanager **silence** for `site=com` and pause the russetleaf.com heartbeat check; suspend Argo CD auto-sync; delete the Applications in reverse order; wait until the ALB, the `origin` record and the Karpenter nodes are gone (with timeouts); `terraform destroy` in `envs/aws`; confirm russetleaf.com returns the 503 offline page and no tagged demo resources remain; post "russetleaf.com demo stopped" (with the run time) to `#rl-com-alerts`.
- **Safety net:** a scheduled workflow (hourly) that alerts `#rl-costs` and `#rl-critical` (and optionally runs `demo-down`) if the demo stack has been up longer than a set limit (e.g. 6 hours).

**Test:** run `demo-up` and `demo-down` end to end twice without manual steps (each `demo-up` producing a kube-bench summary pull request and a `#rl-security` message), and confirm the teardown produces **no** alert noise in Slack (only the "stopped" message); force the safety net by lowering the limit.

### Step 6.1b: Rollback drill on EKS
**Do:** during one demo, run the AWS rollback paths from the rollback runbooks: deploy a deliberately broken WordPress version and let the **Argo Rollouts canary (CloudWatch analysis) roll it back**; take a manual RDS snapshot, then do a **point-in-time restore** of RDS to a moment before a test change; and for a `schema-change` release, confirm the manual RDS snapshot is taken before the demo uses it. Record the times in the decision log.

Also restore russetleaf.com's database **from the latest logical dump in the backup account** into the fresh RDS instance (the disaster-recovery path when snapshots are unavailable).

**Test:** the broken version is rolled back automatically; the point-in-time restore recovers the earlier data; the restore from the backup account's dump works; the timings are recorded.

### Step 6.2: Full rehearsal and demo script
**Do:** write `docs/demo-script.md`: what to show and in what order (offline page → `demo-up` → live site → *(with Phase 2)* publish a post and watch the summary, its end-to-end trace in Tempo and the Grafana LLM dashboard → Argo Rollouts canary → Kyverno rejecting an unsigned image → Falco alert → OpenCost → `demo-down` → offline page). Rehearse, then record a walkthrough.

**Test:** a complete demo runs in under an hour of stack time, and the recording is linked from the hub README.

### Step 6.3: Documentation
**Do:** add the russetleaf.com architecture diagram and demo recording to the hub README; update the Phase 3 design wherever the build differed from it.

**Test:** the hub README explains both sites, with links to the recording, reports and dashboards.

### Step 6.4: Load, stress, spike and burst tests (capacity data)
**Do:** during a demo, using the k6 Operator on EKS (the same `wp-gitops/perf/` scripts as home), run a **load** test, a **stress / breakpoint** test (ramp until failure, and check it recovers on its own), a **spike** test (about 10× suddenly, to time HPA and Karpenter scale-up), and an **AI pipeline burst** (200–500 posts queued); for edge tests through CloudFront, apply a temporary AWS WAF allow rule for the test source through Terraform and remove it afterwards. Run the tests at increasing traffic levels; record how the HPA and Karpenter respond (scale-up time, nodes added), where latency or errors start to rise, the bottleneck (PHP workers, RDS Proxy connections, Valkey, CloudFront cache hit rate), and the cost per hour at each level. These numbers feed the capacity and cost plan (Phase 1 step 8.7).

**Test:** results for at least three traffic levels, the breaking point and recovery, spike scale-up times and the burst's drain time and cost are recorded in `docs/performance/`, with the bottleneck identified, **cost per 1,000 visitors** calculated, and the temporary WAF rule removed.

### Step 6.5: Register EKS with the home Argo CD hub
**Do:** extend `demo-up` to register the EKS cluster with the home Argo CD (an Argo CD cluster secret using IAM authentication; the EKS API endpoint public but restricted to the home network's address), so the hub's ApplicationSets deploy the AWS overlays; extend `demo-down` to remove the registration first. Keep the per-cluster Argo CD path (step 1.8) as a documented fallback. See `docs/phase-1-russetleaf-dev/adr/0024-internal-developer-platform.md`.

**Test:** a demo run managed entirely from the home hub: both clusters visible, the AWS overlays synced, and the registration removed cleanly by `demo-down`.

## Ongoing operations (after the build)

| Task | How often | How |
|---|---|---|
| Run a demo (or at least `demo-up` / `demo-down`) | Monthly | Catches broken versions, expired assumptions and drift before an interview does |
| Check versions before the demo | Before each demo | Review the latest version-age report and Renovate's pending updates for `envs/aws` (EKS, add-ons, AMI, RDS and ElastiCache engine versions); keep RDS's MariaDB version matched to the home MariaDB |
| Keep the EKS version in standard support | Before each demo, if a new version is out | Bump the version in `envs/aws`; the stack is rebuilt each demo, so there's no in-place upgrade |
| Clean up old final snapshots | Automatic (step 1.6) | Check that only the last 3 remain |
| Check the always-on edge for drift | Weekly | Scheduled `terraform plan` for `envs/aws-edge` in `wp-infra` CI |
| Check for leftovers | After each demo | Search for resources tagged `Stack=demo`; the Budget and Cost Anomaly alerts in `#rl-costs` are the backstop |
| Review russetleaf.com alert noise | After each demo | Anything that fired during the demo should have been real; tune or remove alerts that weren't |
| Rotate the CloudFront-to-ALB secret header | Every few months | Change the value in `envs/aws-edge`; the next demo picks it up |
| Prowler AWS scan with the stack up | Once per demo | Trigger the `wp-infra` Prowler workflow during the demo; review findings for the demo resources |
| kube-bench scan | Every demo (automatic, in `demo-up`) | Review the summary pull request and any new failures flagged in `#rl-security`; fix in Terraform or the node class, or add to the accepted-findings file with a reason |
| Kubescape posture scan | Once per demo | Run the Kubescape CLI against EKS during the demo; save the report in `docs/security/` |
| Review the per-demo cost report | The day after each demo (automatic) | Check the `#rl-costs` report; investigate if cost per hour is well above the ~$1 estimate |
| Review costs | After each demo | Cost Explorer filtered by `Site=com`, compared with the demo hours recorded |

## Progress checklist

| Step | Tier | Est. hours | Done | Date | Actual hours | Stack cost this session | Notes |
|---|---|---|---|---|---|---|---|
| 0.1 GPU quota, DNS, guardrails | Core | 2–3 | ☐ | | | | |
| 0.2 Decisions | Core | 1–2 | ☐ | | | | |
| 1.1 CI roles | Core | 2–3 | ☐ | | | | |
| 1.2 Always-on edge | Core | 7–10 | ☐ | | | | |
| 1.3 Network | Core | 3–5 | ☐ | | | | |
| 1.4 EKS cluster | Core | 8–12 | ☐ | | | | |
| 1.5 Karpenter infrastructure | Core | 3–5 | ☐ | | | | |
| 1.6 RDS for MariaDB + Valkey | Core | 6–10 | ☐ | | | | |
| 1.7 App resources + permissions | Core | 4–7 | ☐ | | | | |
| 1.8 Argo CD on EKS | Core | 2–3 | ☐ | | | | |
| 1.9 CI for AWS environments | Core | 2–4 | ☐ | | | | |
| 2.1 AWS root app | Core | 2–3 | ☐ | | | | |
| 2.2 Load Balancer Controller, ExternalDNS, storage | Core | 3–5 | ☐ | | | | |
| 2.3 Karpenter NodePools + NVIDIA plugin | Core | 4–7 | ☐ | | | | |
| 2.4 Shared platform overlays | Core | 4–8 | ☐ | | | | |
| 2.5 kube-bench + Kubescape scan | Differentiator | 2–3 | ☐ | | | | |
| 3.1 WordPress AWS overlay | Core | 5–9 | ☐ | | | | |
| 3.2 Seed + snapshot cycle | Core | 3–5 | ☐ | | | | |
| 4.1 Summarizer + gateway | Differentiator | 2–4 | ☐ | | | | |
| 4.2 GPU model server | Differentiator | 4–7 | ☐ | | | | |
| 4.3 Evaluation on AWS | Differentiator | 1–3 | ☐ | | | | |
| 4.4 End-to-end tracing | Differentiator | 1–3 | ☐ | | | | |
| 4.5 Fine-tuning pipeline | Stretch | 16–28 | ☐ | | | | |
| 4.6 Fine-tuned challenger (at home) | Stretch | 4–7 | ☐ | | | | |
| 5.1 Security review | Differentiator | 4–6 | ☐ | | | | |
| 5.2 Cost review | Differentiator | 2–3 | ☐ | | | | |
| 5.3 Istio ambient experiment (optional) | Stretch | 3–5 | ☐ | | | | |
| 5.4 Tetragon enforcement (optional) | Stretch | 3–5 | ☐ | | | | |
| 6.1 Demo workflows | Core | 5–8 | ☐ | | | | |
| 6.1b Rollback drill on EKS | Differentiator | 2–4 | ☐ | | | | |
| 6.2 Rehearsal + recording | Core | 3–5 | ☐ | | | | |
| 6.3 Documentation | Core | 2–3 | ☐ | | | | |
| 6.4 Load, stress, spike + burst tests | Staff | 6–9 | ☐ | | | | |
| 6.5 Register EKS with the Argo CD hub | Staff | 4–6 | ☐ | | | | |

## Decision log

| Date | Decision | Reason |
|---|---|---|
| | | |
