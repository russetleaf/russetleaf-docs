# Phase 3 build plan: russetleaf.com on EKS

This is the step-by-step plan for **Phase 3**, described in the [Phase 3 design](design.md): russetleaf.com on the full AWS design, brought up only for demos. It **starts after Phase 1's Core tier is built**: it reuses Phase 1's repos, OpenTofu modules, base manifests, images, charts and CI, and adds only what is specific to AWS. It is **independent of Phase 2**: russetleaf.com runs WordPress only. Posts seeded from russetleaf.dev keep the AI summaries Phase 2 generated there, but russetleaf.com generates none of its own; the WordPress image's summary-queue plugin does nothing when no queue is configured.

Each step ends with a **test** that must pass before moving on. Unlike the home lab, most of this stack costs money while it runs (about **$0.70 an hour**), so the plan builds it in layers and tears each layer down between sessions until the demo workflows (Stage 5) automate it.

## How to use this plan with Claude

- **Start each session** with something like: *"Read the overview, the Phase 3 design and plan, and the Phase 1 design. We are working on Phase 3 step 2.3. Here is where I left off: ..."* (the [overview](../overview.md), [Phase 3 design](design.md) and [Phase 1 design](../phase-1-russetleaf-dev/design.md)).
- **Same workflow as Phase 1:** a roadmap with milestones (write `roadmap.md` in this folder before starting, in the format of Phase 1's [roadmap](../phase-1-russetleaf-dev/roadmap.md)), GitHub issues created with `tools/plan_to_issues.py`, and a spec per step from [`docs/specs/TEMPLATE.md`](../specs/TEMPLATE.md).
- **One step at a time.** Build it, run the step's test, fix, commit, and **tear down** anything expensive before ending the session.
- **Check for leftovers after every session.** Every resource is tagged (see step 0.2); search by tag (AWS Resource Explorer or the Tag Editor) to confirm nothing from `envs/aws` is still running. Check the AWS Budget the next day.
- **Change the AWS overlay only.** Put AWS-specific settings in `overlays/aws`. If the base needs changing, send the change through Phase 1's environments first (local → ci → staging → russetleaf.dev), so russetleaf.dev never breaks. Application versions reach `overlays/aws` through the same `promote-to-prod` pull requests as russetleaf.dev.
- **Keep the plan current.** Check off steps in the [progress checklist](#progress-checklist), record actual costs, and add to the [decision log](#decision-log).

## Working with AI agents

This phase is built with **AI coding agents** under [ADR 2004](../phase-2-ai-mlops/adr/2004-agentic-ai-delivery.md); Phase 1 was built without them, so its actual hours are the baseline.

- **One step per agent session.** Write or approve the step's spec first; its acceptance criteria are the agent's definition of done. The agent works on a branch and opens a pull request.
- **Sandbox first:** agents iterate on `tofu validate`, tflint, Checkov, `tofu plan`, Infracost and local clusters; they never apply, and repeated applies against the demo stack (about $0.70 an hour) are avoided.
- **Least privilege:** agents use the plan-only AWS role from step 0.3 and the other agent identities and settings from that step; applies go through the human-approved `apply` environment.
- **Review:** every agent pull request runs the same checks as any other; review IAM, policies, network rules and anything touching secrets line by line.
- **Record the results** in the progress checklist: **Done by** (agent, operator or both) and **Review findings** (problems caught in review or CI that the agent missed), alongside actual hours. Each milestone retro includes a short section on the agents.

## Workstation

Use the same Ubuntu 24.04 setup as the home lab ([Local workstation setup](../phase-1-russetleaf-dev/plan.md#local-workstation-setup-ubuntu-2404)). Additions for AWS:

- An AWS SSO profile for the russetleaf-com account, and `aws eks update-kubeconfig --name <cluster> --alias rl-use1 --profile <profile>` after each `demo-up`, so the kubeconfig context is clearly named.
- Nothing else to install: `tofu`, `kubectl`, `helm`, `argocd` and the AWS CLI from the home lab setup cover EKS. Pin the `kubectl` version in `russetleaf-infra`'s `.mise.toml` within one minor version of the EKS version.

## Priorities and time estimates

Every step in the [progress checklist](#progress-checklist) has a **tier** and an **estimate** in focused hours (with Claude's help); expect ±50%, and record **actual hours** (and the stack cost) per session.

| Tier | What it means | Steps | Est. hours |
|---|---|---|---|
| **Core** | russetleaf.com working end to end in its own account: the always-on edge with the offline page, network, EKS with Karpenter, RDS for MariaDB with RDS Proxy, Valkey, the platform on EKS, WordPress, the demo workflows, one rehearsed and **recorded demo**, and the docs. | 0.1–2.4, 3.1, 3.2, 5.1, 5.2, 5.3 | **~74–123** |
| **Extended** | kube-bench and Kubescape on EKS, the security and cost reviews, and the EKS rollback and forensics drills. | 2.5, 4.1, 4.2, 5.1b, 5.1c | **~14–22** |
| **Advanced** | Load, stress and spike tests for the capacity plan, EKS as a second spoke of the Argo CD hub, and the Istio ambient and Tetragon experiments. | 4.3, 4.4, 5.4, 5.5 | **~16–25** |
| **Total** | | | **~104–170** |

**Calendar time:** about **5–9 weeks at ~20 hours a week** for the whole plan, after Phase 1's Core tier is done (this plan depends on it). Allow for waiting: **SES production access** in the new account.

**Money:** the stack costs about **$0.70 an hour** while running, so batch work into focused sessions and run `demo-down` at the end of each; record each session's cost in the checklist.

**Recommended order:** do the Core tier in plan order, with **3.1 → 5.1 → 5.2** (WordPress, demo workflows, recorded demo) as the first milestone; add the reviews next; the experiments last.

## Prerequisites from Phase 1

These steps must be done first, because this plan builds on them:

| Earlier step | What this plan reuses |
|---|---|
| Phase 1 step 1.1 Repos | The repos, branch protection, Renovate, secret scanning |
| Phase 1 step 2.1 OpenTofu bootstrap | State bucket, GitHub OIDC provider, CI role pattern |
| Phase 1 step 2.3 AWS + Cloudflare resources | The shared modules (`s3-media`, `s3-backups`, `secrets`) |
| Phase 1 step 2.4 `russetleaf-infra` CI | OpenTofu checks and plan comments |
| Phase 1 step 3.1 GitOps structure | The `base/` + `overlays/` layout, app of apps, sync waves, manifest CI |
| Phase 1 stage 4 Platform services | Base manifests for External Secrets, monitoring, Kyverno, Argo Rollouts, Falco, Trivy Operator, OpenCost |
| Phase 1 step 4.5 MariaDB backups | The russetleaf.dev backups used to seed russetleaf.com |
| Phase 1 steps 5.1–5.3 WordPress | The image, the chart and image promotion |
| Phase 1 steps 5.4–5.7 Environments | ci test clusters, ARC runners, on-demand staging and the promotion pipeline (which also bumps `overlays/aws`) |
| Phase 1 steps 6.1–6.2 Policy and rollouts | Kyverno policies, the Rollout definition |

## Stage 0: Preparation

### Step 0.1: Long-lead items and guardrails

**Do:**

- **All of russetleaf.com lives in its own account, `russetleaf-com`** (Workloads OU), created in this step by adding it to `russetleaf-infra/envs/org` (the Organization itself is from Phase 1 step 2.0; see the Phase 1 design's [AWS account structure](../phase-1-russetleaf-dev/design.md#aws-account-structure-and-best-practices-security-reference-architecture) and [ADR 1019](../phase-1-russetleaf-dev/adr/1019-aws-multi-account-sra.md)). Quotas and SES sandbox status are **per account**, so the items below apply to `russetleaf-com`.
- **SES production access** (or a verified test address) for russetleaf.com.
- **Backup account:** the disaster-recovery backup account and replication (Phase 1 step 2.5) must exist first; add the russetleaf.com media and backup buckets to its replication in step 1.2.
- **russetleaf.com DNS:** if the domain is registered outside Route 53, plan to move its name servers to Route 53 in step 1.2.
- **AWS Config for the new account** (`envs/security`): the organization's focused recording, with **daily recording** for the high-churn demo resource types (EC2 instances, network interfaces, security groups, volumes) and continuous recording for IAM, S3 and KMS ([ADR 1019](../phase-1-russetleaf-dev/adr/1019-aws-multi-account-sra.md)).
- **Budget guardrails:** the **russetleaf-com** account's budget (from `envs/org`, e.g. alerts at $20 and $40 per month), and a **Cost Anomaly Detection** monitor. Send both to an **SNS topic** connected to Slack `#rl-costs` through **Amazon Q Developer in chat applications** (formerly AWS Chatbot), as well as by email. (Created by hand here; OpenTofu's `alerting` module takes over in step 1.7.)

**Test:** the russetleaf-com account exists in the Workloads OU; a test budget notification arrives by email and in `#rl-costs`.

### Step 0.2: Decisions to make before writing code

Record each answer in the [decision log](#decision-log).

| Decision | Recommendation | Why it matters |
|---|---|---|
| **Region** | **us-east-1** for everything. | CloudFront certificates must be in us-east-1 anyway; one region keeps OpenTofu simple. |
| **Pod AWS access** | **EKS Pod Identity** (the newer, simpler option) instead of IRSA, unless a component only supports IRSA. | Decides how every service account gets AWS permissions. Both avoid stored keys. |
| **Image registry** | Keep **GHCR** for both sites (one registry, one Kyverno policy). Optional: an ECR pull-through cache for GHCR, so EKS pulls stay inside AWS. If the GHCR packages are still **private** (their visibility is separate from the repos'), EKS also needs the image pull secret and Argo CD GHCR credentials described in Phase 1 step 5.1. | One registry for both sites; see [ADR 1004](../phase-1-russetleaf-dev/adr/1004-ghcr-not-ecr.md) (record the pull-through cache decision there). |
| **NAT Gateways** | **One** NAT Gateway for demos (saves about $65/month-equivalent while running), documented as "three in production". | Cost while the demo runs vs showing full AZ redundancy. The one deliberate demo cut to high availability recorded in [ADR 1014](../phase-1-russetleaf-dev/adr/1014-availability-levels.md). |
| **Networking** | **Decided: Cilium in chaining mode** with the Amazon VPC CNI (the VPC CNI assigns pod IPs; Cilium enforces **CiliumNetworkPolicies** and provides Hubble), matching the home lab's Cilium. | Same policies, dashboards and alerts on both clusters; staying on the VPC CNI for IP addressing keeps EKS close to its defaults. |
| **Node OS** | **Amazon Linux 2023** EKS AMIs. | Falco's modern eBPF driver and Karpenter both support it. |
| **Monitoring on AWS** | The same **kube-prometheus-stack** as the home lab, plus **CloudWatch** for things Prometheus cannot see (ALB, RDS, ElastiCache metrics, via the CloudWatch exporter or Grafana's CloudWatch data source). Skip **Container Insights**: Prometheus, kube-state-metrics and the Grafana dashboards already cover node, pod and container metrics, the same as at home, and Container Insights would add per-metric and log costs for a duplicate view. Turn on **Database Insights (Standard)** for RDS. | The Argo Rollouts analysis needs request metrics, which come from the ALB (CloudWatch) on AWS, not from the home Cilium Gateway. |
| **Tagging** | Every resource gets `Project=russetleaf`, `Site=com`, `Stack=edge|demo`, `ManagedBy=opentofu`. Set as provider `default_tags`. | Makes leftover checks and cost reports possible. |

### Step 0.3: Agent workspace and AWS access

**Do** ([ADR 2004](../phase-2-ai-mlops/adr/2004-agentic-ai-delivery.md)): an IAM Identity Center permission set **`rl-com-agent-plan`** for agent sessions: read-only access to russetleaf-com, read access to the OpenTofu state and its lock in russetleaf-infra, and **no** permission to change resources. Set up the agent workspace for this phase's repos as [ADR 2004](../phase-2-ai-mlops/adr/2004-agentic-ai-delivery.md) describes: an `AGENTS.md` (with the cost rules) and a `CLAUDE.md` that imports it in `russetleaf-infra` and `russetleaf-gitops`; permission settings that allow `tofu plan` and local tools, and deny reading credential files, `tofu apply`, `tofu state` changes, `kubectl apply` and merging; a read-only kubeconfig for the EKS cluster; and the pull-request template with **Done by** and a reviewer checklist.

**Test:** with the agent's role, `tofu plan` in `envs/aws` works and `tofu apply` fails with an access error; IAM Access Analyzer's policy check shows no write actions in the permission set.

## Stage 1: Infrastructure (`russetleaf-infra`)

### Step 1.1: CI roles for the AWS environments

**Do:** extend `russetleaf-infra/bootstrap/` to the **russetleaf-com** account (GitHub OIDC provider, audit role) with plan and apply roles for `envs/aws-edge` and `envs/aws`, with access to their own keys in the russetleaf-infra state bucket, limited to what each environment manages (the demo-stack apply role cannot touch the edge stack's resources, and vice versa, where IAM conditions allow).

**Test:** a pull request touching `envs/aws-edge` gets a plan comment using the plan role; the apply role can be assumed only from `main`.

### Step 1.2: Always-on edge (`envs/aws-edge`)

**Do:**

- Route 53 hosted zone for russetleaf.com (point the registrar's name servers at it if needed), with **DNSSEC signing** (an asymmetric KMS key in us-east-1, about $1/month) and the **DS record** added at the registrar.
- ACM certificates: `russetleaf.com` + `www` in us-east-1 (CloudFront), and `origin.russetleaf.com` in the ALB's region (the same region if us-east-1 is the chosen region).
- S3 offline-page bucket with the offline page ("The AWS demo is offline. Visit russetleaf.dev."), the russetleaf.com **media bucket** (versioned; old versions deleted after 90 days), a **Loki log bucket** (14-day lifecycle) and a **Tempo trace bucket** (7-day lifecycle), both kept in the always-on stack so demo logs and traces can be reviewed after teardown. Every bucket aborts incomplete multipart uploads after 7 days ([ADR 1042](../phase-1-russetleaf-dev/adr/1042-s3-versioning-lifecycle-and-storage-classes.md)). **Origin Access Control** on the two buckets CloudFront serves (the offline page and media); Loki and Tempo are reached through scoped IAM roles, never through CloudFront.
- CloudFront's managed **`SecurityHeadersPolicy`** response-headers policy adding HSTS and the other security headers (custom policies are not part of the Free plan; the WordPress `security-headers` plugin supplies Content-Security-Policy and Permissions-Policy) ([ADR 1032](../phase-1-russetleaf-dev/adr/1032-defense-in-depth.md)).
- CloudFront distribution on the **flat-rate Free plan** ([ADR 3009](adr/3009-edge-waf-on-cloudfront-free-plan.md); subscribe with OpenTofu if the AWS provider supports it, otherwise once with the CLI, recorded in the decision log), with the Route 53 hosted zone attached to the plan and an **edge web ACL** of five rules: the AWS managed core rule set, known bad inputs and Amazon IP reputation list, a rate-based rule on `/wp-login.php`, and a rule blocking `/xmlrpc.php`. Behaviors: default → `origin.russetleaf.com` (all methods, HTTPS only, the `X-Origin-Verify` secret header, **uncached** with the managed `CachingDisabled` cache policy and the managed `AllViewerExceptHostHeader` origin-request policy, so Host is not forwarded but cookies and query strings are); `/wp-content/uploads/*` → media bucket; `/offline/*` → offline bucket; custom error responses 502/503/504 → `/offline/index.html` with status 503; 10-second error caching; origin timeout 2 s, 1 attempt.
- The secret header value in Secrets Manager.
- SES domain identity for russetleaf.com, with DKIM records in Route 53.
- **`prevent_destroy`** on the hosted zone, CloudFront distribution, the media, log and trace buckets, and Secrets Manager entries, so no plan (including a revert's) can delete them without a deliberate change (see the Phase 1 design's [Rollback strategy](../phase-1-russetleaf-dev/design.md#rollback-strategy)).
- A **russetleaf.com backup bucket** for the logical dumps taken at `demo-down`, and **replication** of it and the media bucket to the backup account (`envs/dr`).
- Outputs for `envs/aws` (zone ID, certificate ARNs, secret ARN, bucket names).

**Test:** the distribution shows the Free plan with the edge web ACL attached; a request to `/xmlrpc.php` is blocked at CloudFront even with the demo stack down; `curl -I https://russetleaf.com` returns **503** with the offline page; the page links to russetleaf.dev; the SES identity shows "verified". Add the russetleaf.com **external uptime check** (expects 200 or the 503 offline page) and confirm it is green and posts to `#rl-com-alerts` and `#rl-critical` when it fails (test by pointing it at a wrong URL). Leave this stack running from now on (about $1/month).

### Step 1.3: Network (`envs/aws`)

**Do:** VPC across three AZs (in russetleaf-com): public and private subnets, Internet Gateway, the NAT Gateway(s) decided in step 0.2, an S3 gateway endpoint (free), **interface VPC endpoints** for STS, SQS (Karpenter's interruption queue) and Secrets Manager (private traffic, lower NAT costs; check their hourly cost against demo hours), **VPC flow logs** delivered to the **Log Archive** account, the **default security group with no rules**, the **default VPCs removed** in the allowed regions, and **Route 53 Resolver DNS Firewall** on the VPC with an **allow-list** of the domains the stack needs (AWS service endpoints, GitHub and GHCR, Google sign-in, Slack and the heartbeat service) and everything else blocked, so even a compromised node cannot look up a command-and-control or data-exfiltration domain (first one demo in alert mode to complete the list, then block; [ADR 1017](../phase-1-russetleaf-dev/adr/1017-intrusion-detection-and-prevention.md)); **Route 53 Resolver query logging** for the VPC, delivered to the **Log Archive** account's bucket (1-year retention, Object Lock), for forensics and for reviewing DNS Firewall's blocked lookups (GuardDuty already analyzes the VPC's DNS queries for command-and-control, generated domains and DNS tunneling through its own feed); subnet tags for the Load Balancer Controller and Karpenter discovery.

**Test:** `tofu apply` then `destroy` cleanly; subnets carry the right tags; flow logs arrive in Log Archive; from the test instance, `dig example.com` is blocked by DNS Firewall while AWS endpoints resolve, and both lookups (with the firewall's action) appear in the Resolver query logs in Log Archive; traffic to SQS and STS from a test instance goes through the endpoints (no NAT bytes); (Cost while up: mainly the NAT Gateway.)

### Step 1.4: EKS cluster

**Do:**

- EKS cluster with a small **managed node group** (2 nodes, e.g. t3.medium) for Karpenter, CoreDNS and other system pods.
- **Names** ([ADR 1041](../phase-1-russetleaf-dev/adr/1041-naming-convention.md)): the cluster **`rl-use1`** (also the kubeconfig context and the `cluster` label), the managed node group **`rl-use1-sys`**, and **resource-based node names** (the instance ID rather than the IP address) for every node.
- **Secrets envelope encryption** with a **customer-managed KMS key** ([ADR 1031](../phase-1-russetleaf-dev/adr/1031-kubernetes-component-hardening.md)), and kubelet `seccompDefault` on the nodes, plus a **per-pod PID limit** and **hard eviction thresholds** ([ADR 1034](../phase-1-russetleaf-dev/adr/1034-kubernetes-threat-model-coverage.md)), through the managed node group's launch template (AL2023 node configuration) and Karpenter's node configuration (step 2.3).
- Add-ons: VPC CNI (with its own network policy enforcement **off**, since Cilium enforces policies), CoreDNS, kube-proxy, **EBS CSI driver**, **Pod Identity agent**.
- **Cilium in chaining mode**, installed by OpenTofu's Helm provider right after the cluster and managed node group exist: `cni.chainingMode: aws-cni`, `cni.exclusive: false`, `enableIPv4Masquerade: false`, `routingMode: native`; Hubble and Hubble Relay on; **WireGuard transparent encryption** on, **if** the installed Cilium version supports it in chaining mode with the VPC CNI (check Cilium's documentation; if it does not, leave it off and record that in the open items of [ADR 1001](../phase-1-russetleaf-dev/adr/1001-no-service-mesh.md), relying on the TLS already on every sensitive connection); ServiceMonitors **off** until monitoring exists (step 2.4); `lifecycle { ignore_changes }` so Argo CD manages it afterwards from `platform/cilium/overlays/aws`. Restart any pods that started before Cilium (e.g. CoreDNS) so Cilium manages them.
- A Kubernetes version within **standard support**. EKS charges about six times more per hour for clusters on versions in extended support.
- **API endpoint:** public but **restricted to the home network's address** (private access also on, for the nodes). The demo workflows run on the **home ARC runners** (step 5.1), so they reach it from that address; the workstation does too ([ADR 1030](../phase-1-russetleaf-dev/adr/1030-github-actions-ci.md)).
- **Add-on versions pinned** in OpenTofu; the monthly version-age workflow (Phase 1 step 7.6) checks `aws eks describe-addon-versions` and opens a pull request when newer compatible versions exist.
- **Access entries ([ADR 1033](../phase-1-russetleaf-dev/adr/1033-identity-and-access.md)):** IAM Identity Center permission-set roles mapped with EKS access policies: **view** (`AmazonEKSViewPolicy`) for day-to-day, **edit** (`AmazonEKSEditPolicy`) for operating, **cluster-admin** (`AmazonEKSClusterAdminPolicy`) only through a separate permission set; plus the CI apply role. Authentication mode **API only** (no `aws-auth` ConfigMap), and the cluster creator's automatic admin access turned off.
- Control plane logging: audit logs only, short CloudWatch retention (they are the useful ones and cost little), with a **subscription filter → Firehose → the Log Archive account's Object Lock bucket**, kept **1 year** ([ADR 1033](../phase-1-russetleaf-dev/adr/1033-identity-and-access.md)). **CloudWatch Logs metric filters** on the audit log for the persistence alerts (`KubeWorkloadCreatedOutsideArgoCD`, `KubeAdmissionWebhookChanged`, `KubeTokenSecretCreated`; [ADR 1034](../phase-1-russetleaf-dev/adr/1034-kubernetes-threat-model-coverage.md)) feed CloudWatch alarms to `#rl-security` through the `alerting` module's SNS topic, created and destroyed with the demo stack. **GuardDuty's EKS audit-log monitoring** (turned on organization-wide in Phase 1 step 2.0b) starts watching the cluster automatically.

**Test:** `kubectl get nodes` shows the managed nodes; `cilium status` is green and `cilium connectivity test` passes; if WireGuard is on, `cilium encrypt status` lists the other nodes as peers; a gp3 PersistentVolumeClaim binds; signing in with the view permission set can list pods but not read Secrets or delete anything; audit-log objects appear in the Log Archive bucket; tear down.

### Step 1.5: Karpenter infrastructure

**Do:** Karpenter's IAM (controller role via Pod Identity, node role and instance profile), the **interruption SQS queue** with EventBridge rules (spot interruption, rebalance, instance state change), and the Karpenter Helm release installed by OpenTofu (NodePools come from GitOps in step 2.3).

**Test:** the Karpenter controller is running and reports no errors.

### Step 1.6: Database and cache

**Do:**

- **RDS for MariaDB**, the same major version as the home lab (e.g. 11.4), Multi-AZ, private subnets, **`manage_master_user_password = true`** (RDS generates, stores and rotates the master password in Secrets Manager), security group allowing only the EKS nodes/pods, parameter group with `require_secure_transport = ON` and TLS 1.2 or later, automated backups (7 days), **CloudWatch Database Insights in Standard mode** (free, 7 days of history: database load and the top SQL statements; the successor to Performance Insights, confirm the current offering when building), **`storage_encrypted = true` with a customer-managed KMS key** (snapshots and restored instances use it too; [ADR 1043](../phase-1-russetleaf-dev/adr/1043-database-encryption.md)), `deletion_protection = false` (demo), `skip_final_snapshot = false` with a timestamped final snapshot name.
- **RDS Proxy** in front of it (engine family `MYSQL`, which covers MariaDB): `require_tls = true`; an auth entry for the `wordpress` user with **`iam_auth = REQUIRED`**, backed by a Secrets Manager secret whose password OpenTofu sets with an ephemeral value through a write-only argument (never in state); a proxy IAM role that can read only that secret; security groups allowing EKS pods → proxy → RDS only; **Secrets Manager rotation** on the `wordpress` secret ([ADR 3007](adr/3007-rds-mariadb-with-rds-proxy.md)).
- **Spike early (do this first in this step, and record the result in the decision log):** bring up a minimal RDS for MariaDB (single-AZ, smallest instance) with an RDS Proxy (`iam_auth = REQUIRED`), then from a test pod running the WordPress image, use a short PHP script to log in to the proxy with an IAM token over TLS. Costs a few cents for an hour. This decides between:
    - **Pass →** finish the `iam` mode of the `db.php` drop-in in `russetleaf-wordpress` (released through ci → staging → prod like any change), and continue with IAM auth as designed.
    - **Fail →** use the **fallback** from the Phase 3 design ([Risk: confirm IAM tokens work from PHP first](design.md#risk-confirm-iam-tokens-work-from-php-first-with-a-fallback)): set the proxy's auth to `iam_auth = DISABLED`; create the `wordpress` secret with **Secrets Manager automatic rotation** using the **alternating-users** strategy (`wordpress_a` / `wordpress_b`, e.g. every 30 days); sync it into the cluster with External Secrets; install **Reloader** (or use Rollouts restarts) so WordPress restarts on a new password; set `database.auth: password` in `overlays/aws`; drop `rds-db:connect` from the WordPress and seed-Job roles and grant them read access to the secret through External Secrets instead. Update steps 1.7, 3.1 and 3.2 accordingly.
- **Restore logic:** look up the most recent `russetleaf-com-final-*` snapshot; if one exists, restore from it, otherwise create an empty database.
- **ElastiCache Valkey** replication group (primary + replica, Multi-AZ), TLS in transit, and an **AUTH token generated fresh on every `demo-up`** (a OpenTofu ephemeral random value written through a write-only argument to Secrets Manager and the replication group, never in state), so the token changes every demo without a rotation job ([ADR 3007](adr/3007-rds-mariadb-with-rds-proxy.md)).
- Snapshot housekeeping: keep the last 3 final snapshots (a small Lambda or a scheduled GitHub Action deletes older ones).

**Test:** the spike's result is recorded in the decision log. **IAM path:** from a test pod, generate a token (`aws rds generate-db-auth-token --hostname <proxy-endpoint> --port 3306 --username wordpress`) and log in to the **proxy** over TLS with it (the MariaDB client needs its cleartext plugin enabled to send the token); confirm a plain password and a non-TLS connection are refused, and that a non-TLS connection straight to the RDS instance is refused too; `SHOW STATUS LIKE 'Ssl_cipher'` is non-empty for the proxy's sessions; the `db-setup` Job connects with TLS, verifying the RDS CA bundle; Security Hub's RDS encryption check passes. **Fallback path:** log in to the proxy with the synced password, trigger a rotation by hand (`aws secretsmanager rotate-secret`), and confirm the old password keeps working until the next rotation and WordPress picks up the new one after its restart. Either way: confirm the master password exists only in Secrets Manager; connect to Valkey with TLS and the token, and confirm the token differs from the previous demo's; destroy creates a final snapshot; the next apply restores from it (create a test table to prove it).

### Step 1.7: russetleaf.com app resources and permissions

**Do:**

- Using the shared modules: Secrets Manager entries for russetleaf.com.
- **WAF web ACL** for the ALB: AWS managed rule groups **core rule set**, **known bad inputs**, **WordPress application**, **PHP application**, **SQL database** and **Amazon IP reputation list** (blocking), plus the **anonymous IP list** in **count mode** only (it would also block real visitors on VPNs and hosting providers; its counts are reviewed after a few demos); a rate-based rule on `/wp-login.php` and a rule blocking `/xmlrpc.php`. Check that the rule groups' capacity (WCUs) stays within the web ACL's included 1,500.
- **Pod Identity associations** (one IAM role per service account, least privilege): WordPress (media bucket, SES send, **`rds-db:connect` on the proxy's `wordpress` user**), External Secrets (russetleaf.com secrets), ExternalDNS (the russetleaf.com zone), Load Balancer Controller, seed Job (read russetleaf.dev's backup and media buckets **in the russetleaf-home account**, granted by bucket policies there (and KMS key policies if those buckets use customer-managed keys), write russetleaf.com media bucket, `rds-db:connect` through the proxy), `db-setup` Job (read the RDS-managed master secret and the `wordpress` secret), Falcosidekick/OpenCost if they need AWS APIs.
- SES SMTP credentials (or an IAM role for an SES API plugin) in Secrets Manager, the **Google OAuth client** secret for russetleaf.com (a separate client from russetleaf.dev's, redirect URL `https://russetleaf.com/...`, created in the Google Cloud console), and the **Slack bot token** entry for russetleaf.com (same bot, separate entry so the sites stay independent).
- **`alerting` module:** SNS topics; CloudWatch alarms for the ALB (5xx rate, target response time), RDS (CPU, free storage, connections, replica lag) and ElastiCache (memory, evictions), created and destroyed with the demo stack; Amazon Q Developer channel configurations for `#rl-com-alerts`, `#rl-critical` and `#rl-costs` (the Slack workspace is authorized once in the AWS console, then managed in OpenTofu).

**Test:** with `aws iam simulate-principal-policy`, each role allows exactly what it should and nothing else; forcing a CloudWatch alarm into ALARM state (`aws cloudwatch set-alarm-state`) posts to `#rl-com-alerts`.

### Step 1.8: Argo CD on EKS

**Do:** OpenTofu installs Argo CD with Helm and applies the root Application pointing at `russetleaf-gitops/bootstrap/aws`. (In the Advanced tier, step 5.5 replaces this with management from the home Argo CD hub; this per-cluster setup stays as the fallback.) Argo CD's UI is reached by `kubectl port-forward` only (no public endpoint for demos). **Argo CD Notifications** post to `#rl-deploys`, prefixed `[com]`.

**Test:** Argo CD lists the AWS root app (it will show missing components until Stage 2), and its first sync appears in `#rl-deploys`.

### Step 1.9: `russetleaf-infra` CI for AWS

**Do:** extend the home lab's OpenTofu pipeline (Phase 1 step 2.4) to `envs/aws-edge` and `envs/aws`: tflint with the AWS ruleset, **Checkov** with the custom policies on the source and saved plans (results in GitHub code scanning), **Infracost** comments (especially useful here: they show the monthly cost of the always-on edge and of the demo stack if left running), and **`tofu test`** (with mocked providers where possible) for the AWS-specific modules (`alerting`, the CloudFront edge, RDS restore logic). `envs/aws-edge` applies go through the `apply` GitHub Environment after merge, like `envs/home`. `envs/aws` applies are done only by the demo workflows (Stage 5), which also require approval in the `apply` environment, never automatically on merge, so merging never starts a paid stack.

**Test:** a pull request shows plans and Infracost comments for all three environments; `tofu test` passes (and fails on a deliberately broken module input); a resource outside `us-east-1` (`us-west-2` is allowed only in `envs/dr`) or using an unapproved instance family fails the custom Checkov policies.

## Stage 2: AWS platform (`russetleaf-gitops`)

### Step 2.1: AWS root app and sync waves

**Do:** `bootstrap/aws/` root app with sync waves: Karpenter NodePools and storage first; then External Secrets, Load Balancer Controller, ExternalDNS, Kyverno; then monitoring and Argo Rollouts; then WordPress. Exclude home-only components (cloudflared, the Cilium Gateway and its routes, local-path, MariaDB, Valkey, ARC).

**Test:** Argo CD syncs the root app; the order of creation matches the waves.

### Step 2.2: AWS-only platform components

**Do:**

- `platform/ingress/overlays/aws`: AWS Load Balancer Controller (Pod Identity).
- `platform/external-dns/`: ExternalDNS for the russetleaf.com zone, `--policy=sync`, a domain filter limited to `origin.russetleaf.com`, TXT ownership records.
- `platform/storage/overlays/aws`: gp3 StorageClass as default.

**Test:** a test Ingress creates an ALB and an `origin` DNS record; deleting it removes both.

### Step 2.3: Karpenter NodePool

**Do:** `platform/karpenter/`: `EC2NodeClass` (a **`Name` tag** of `rl-use1-wk`, per [ADR 1041](../phase-1-russetleaf-dev/adr/1041-naming-convention.md); AL2023 with a **pinned AMI version**, tracked by Renovate rather than "latest", so node images only change through a reviewed pull request; subnets and security groups by tag, encrypted gp3 root volume, **IMDSv2 required with a hop limit of 1** so pods cannot reach the node's instance credentials; kubelet settings for `systemReserved`, `kubeReserved`, hard eviction thresholds and the **per-pod PID limit** from [ADR 1034](../phase-1-russetleaf-dev/adr/1034-kubernetes-threat-model-coverage.md), set through the EC2NodeClass's kubelet settings or AL2023 node configuration, whichever the installed Karpenter version supports); **general NodePool** (spot + on-demand, several instance families, consolidation on, disruption budget). The NodePool adds the **startup taint** `node.cilium.io/agent-not-ready=true:NoExecute`, so no pod is scheduled on a new node until Cilium is running there.

**Test:** scaling a test Deployment up adds nodes, scaling down removes them; new nodes only accept pods once Cilium is ready (the startup taint is removed); simulate a spot interruption (e.g. AWS FIS or by hand) and watch Karpenter replace the node.

### Step 2.4: Shared platform services on AWS

**Do:** add `overlays/aws` for each shared component, changing only what AWS needs:

- External Secrets: Pod Identity instead of the bootstrap key.
- Monitoring: same stack; add CloudWatch metrics (ALB, RDS, RDS Proxy, ElastiCache) per the step 0.2 decision, in place of the home lab's MariaDB and Valkey exporters. The WordPress chart's apache_exporter, custom metrics and alerts work unchanged; point the blackbox_exporter probes at WordPress's in-cluster Service. Grafana is reached by `kubectl port-forward` only (there is no Cloudflare Access on this site). Alertmanager overlay: external labels `site=com`, `cluster=rl-use1`; receivers for `#rl-com-alerts` and `#rl-critical`, plus the shared `#rl-security`, `#rl-mlops` and `#rl-costs` routes; the `Watchdog` heartbeat goes to its **own** heartbeat check, which is paused when the demo stack is down.
- **CiliumNetworkPolicies:** the same cluster-wide baseline and per-component policies from each component's `base/` (Phase 1 step 6.3), with AWS-specific destinations in `overlays/aws`: WordPress → the **RDS Proxy** and **ElastiCache** endpoints **by DNS name** instead of in-cluster MariaDB and Valkey; inbound to WordPress from the ALB (target-type `ip`, so traffic arrives from the VPC; allow the VPC's CIDR or the ALB's subnets); no cloudflared policy.
- **Cilium and Hubble metrics:** the same `platform/cilium/` monitoring values as home (ServiceMonitors, Hubble metric set, dashboards, alert rules), now that the Prometheus Operator exists; Hubble UI by `kubectl port-forward`.
- The same **Secrets Not From Env Vars**, user-namespace (if supported) and **mirrored-image** settings as home: EKS pulls the critical third-party images from the GHCR mirror.
- **Pod Security Admission labels** on every namespace, as at home (EKS does not enforce Pod Security by default), plus Kyverno's `restricted` set for application namespaces and the service-account token default.
- Kyverno: the same policy set as home, including SBOM and **SLSA provenance** attestations, upstream signature checks and **seccomp `RuntimeDefault`** (but not the gVisor rule: gVisor is home-only, so the WordPress AWS overlay leaves `runtimeClassName` unset; see [ADR 1009](../phase-1-russetleaf-dev/adr/1009-gvisor-sandboxing.md)) (AWS's own add-on images are not signed with cosign, so they stay covered by the registry allow-list and digest pinning); add AWS's add-on registries (the EKS add-on ECR registries and `public.ecr.aws`) to the **Restrict Image Registries** allow-list, and narrow **`PolicyException`s** for AWS-managed `kube-system` components that need privileged or host access or do not meet the label, probe, non-root or read-only rules (the VPC CNI's `aws-node`, `kube-proxy`, the EBS CSI node agent, the Pod Identity agent), plus Cilium and Falco. The project's own workloads get no exceptions.
- Argo Rollouts: an `AnalysisTemplate` variant using **CloudWatch** (ALB 5xx rate and target response time) instead of the home Cilium Gateway's metrics.
- **Logging:** `platform/logging/overlays/aws`: Loki (S3 via a Pod Identity role on the russetleaf.com log bucket, 14-day retention) and Alloy with `site=com`; no Talos log receiver; the EKS control-plane audit logs stay in CloudWatch. Alloy gets the same narrow Kyverno exception as at home.
- **Tracing:** `platform/tracing/overlays/aws`: Tempo (S3 via a Pod Identity role on the trace bucket, 7-day retention), **always on**; Alloy's OTLP receiver forwards to it; tracing turned on in the WordPress values with **100% sampling**.
- Falco: modern eBPF on AL2023, same custom rules (including the **process allow-lists**); Falcosidekick to `#rl-security`; the same health alerts as home (`FalcoNotRunning`, `FalcosidekickOutputErrors`, `FalcoEventsDropped`). On EKS, `FalcoNotRunning` also catches a new Karpenter node where Falco has not started.
- Kyverno's Policy Reporter and Argo Rollouts notifications: same Slack setup as home, prefixed `[com]`.
- cert-manager and trust-manager with the internal CA (as at home, [ADR 1028](../phase-1-russetleaf-dev/adr/1028-internal-pki.md)); namespace LimitRanges and ResourceQuotas from the Kyverno generate rule; the `ArgoCDAppOutOfSync` alert.
- Trivy Operator and OpenCost (with AWS on-demand/spot pricing).

**Test:** each component is healthy; russetleaf.com's logs are searchable in Grafana and remain in the log bucket after `demo-down`; the home lab's Kyverno rejection tests (unsigned image, unlisted registry, `:latest`, missing labels or memory limit, privileged, root, writable root filesystem, no probes, NodePort/LoadBalancer Service, duplicate Ingress host) all still fail on EKS; OpenCost shows EC2 costs for the nodes.

### Step 2.5: kube-bench and Kubescape scan

**Do:**

- **kube-bench** (see [ADR 3001](adr/3001-kube-bench-eks-only.md)): `platform/kube-bench/` holds **Job templates, one per node pool** (the managed node group and the Karpenter general pool), using the **EKS CIS benchmark** profile, writing **JSON and text** output, with `ttlSecondsAfterFinished` so they clean up. They are applied by the `demo-up` workflow (step 5.1), not synced by Argo CD. For now, run them by hand:
    - the JSON output reaches **Loki** through Alloy; add a Grafana panel (pass/fail/warn counts per node pool, per run) using Loki's JSON parsing
    - commit a summary to `docs/security/kube-bench-eks-<date>.md`, and create `docs/security/kube-bench-accepted.yaml` listing accepted findings with reasons
    - the summary covers each node pool, with any failures and why they are accepted or fixed. The summary states that the **control plane is AWS-managed** (shared-responsibility model): EKS enables only Node and RBAC authorization plus AWS's access-entry webhook, and ABAC cannot be enabled; kube-bench's node-side checks (kubelet anonymous access off, webhook authorization) must pass. As a direct check, from a test pod an anonymous request to a node's kubelet API (`curl -sk -o /dev/null -w '%{http_code}' https://<node-ip>:10250/pods`) must return `401`, for a managed node-group node and a Karpenter-created node alike.
- A **Kubescape CLI** scan of the EKS cluster from the workstation (NSA-CISA and MITRE ATT&CK frameworks, plus RBAC analysis; nothing installed in the cluster), saved in `docs/security/` with a summary, and compared with the home cluster's scores. Fill in the EKS open item in [ADR 1003](../phase-1-russetleaf-dev/adr/1003-kubescape-cli-not-operator.md).

**Test:** a kube-bench Job runs on each node pool and completes; its results appear in the Grafana panel (from Loki); the summary and accepted-findings file are committed; the Kubescape report is committed; the Compliance dashboard shows EKS next to the home cluster (Trivy Operator metrics); any differences between the home and EKS Kubescape scores are explained (e.g. AWS-managed components).

## Stage 3: WordPress on russetleaf.com

### Step 3.1: WordPress AWS overlay

**Do:** `apps/wordpress/overlays/aws`:

- `WP_HOME`/`WP_SITEURL` = `https://russetleaf.com`; the HTTPS-behind-proxy setting.
- 3 replicas, HPA (3–10), PDB, **topology spread** across AZs.
- **`database.auth: iam`** with the **RDS Proxy endpoint**, region and the RDS CA bundle (no database password Secret at all); Valkey endpoint (TLS);
- `apps/db-setup/`: an idempotent **PreSync Job** that reads the master and `wordpress` secrets and runs `CREATE USER IF NOT EXISTS` / `GRANT` for the `wordpress` user (real work only on the first demo; the user survives in the final snapshot); russetleaf.com media bucket with the **CloudFront domain** as the media URL in the offload plugin, SES for email.
- Ingress for the ALB: `origin.russetleaf.com`, the ACM certificate, the WAF ACL, a listener rule requiring the `X-Origin-Verify` header (requests without it get 403), and a security group allowing only the CloudFront origin-facing prefix list.
- **Admin sign-in:** the same Google OIDC plugin configuration as home, with russetleaf.com's client; a **second Ingress in the same ALB group** for `/wp-admin/*` and `/wp-login.php` with the ALB's **OIDC authentication** (Google) in front; no extra CloudFront behaviors are needed, since the default behavior is already uncached and forwards cookies and query strings ([ADR 3009](adr/3009-edge-waf-on-cloudfront-free-plan.md)).
- The Rollout using the CloudWatch analysis template.

**Test:** after sync, russetleaf.com switches from the offline page to the live site on its own; WordPress's custom metrics and apache_exporter are scraped, and the metrics port is **not** reachable through CloudFront or the ALB; the WordPress pods have **no database password** in their environment or Secrets; a forced Multi-AZ failover (`aws rds reboot-db-instance --force-failover`) causes only a few seconds of errors, and terminating a WordPress node lets Karpenter replace it with the site staying up (record both recovery times in [ADR 1014](../phase-1-russetleaf-dev/adr/1014-availability-levels.md)); requesting the ALB directly (without CloudFront) returns 403; media loads from CloudFront; a test SQL-injection request and a PHP injection probe are blocked by WAF, and a request from an anonymizing proxy is counted but not blocked; the password-reset email arrives (SES sandbox: send to a verified address, or request production access). `/wp-admin` requires a Google login at the ALB, then signs in to WordPress with Google and no password; a password login attempt is rejected; a REST API request with an application password still works.

### Step 3.2: Content

**Do:**

- `apps/seed-from-dev/`: the one-off seed Job (manual sync): download the latest russetleaf.dev backup, import into RDS **through RDS Proxy with an IAM token**, `wp search-replace 'russetleaf.dev' 'russetleaf.com' --all-tables`, `aws s3 sync` the media.
- Run it once for the first demo.

**Test:** russetleaf.com shows the same posts and images as russetleaf.dev; destroy and re-create the demo stack, and the content is still there (restored from the final snapshot).

## Stage 4: Security and cost review

### Step 4.1: Security review

**Do:** run an OWASP **ZAP baseline scan** against russetleaf.com (through CloudFront) and check the **security headers** (e.g. with `curl -I` and a header-checking tool); confirm and document the **component hardening checks** for EKS ([ADR 1031](../phase-1-russetleaf-dev/adr/1031-kubernetes-component-hardening.md): envelope encryption with the customer-managed key and endpoint access in `aws eks describe-cluster`, PSA labels with pinned versions on every namespace, no service-account token on WordPress pods, kubelet read-only port refused); **Security Hub** shows russetleaf-com with no unexplained critical or high findings (record the score; optionally turn on **Inspector** for the EKS nodes during this demo); no instance allows IMDSv1; the ALB rejects non-CloudFront traffic; RDS, RDS Proxy and Valkey are not reachable from outside the VPC; DNS Firewall's blocked lookups are reviewed in the Resolver query logs (only expected blocks); no application holds a database password (IAM tokens through the proxy), and the master password is RDS-managed and rotating; no pod has an AWS key (Pod Identity everywhere); the [ADR 1034](../phase-1-russetleaf-dev/adr/1034-kubernetes-threat-model-coverage.md) checks pass on EKS (a fork bomb stops at the PID limit, a CronJob created by hand raises the persistence alarm, Kyverno rejects a Role with `impersonate`, the exfiltration test is blocked); the [ADR 1036](../phase-1-russetleaf-dev/adr/1036-compliance-frameworks-and-privacy.md) checks pass on russetleaf.com (the privacy notice is linked, the no-cookies check passes, and GuardDuty's EKS finding types are in the ATT&CK map); the [ADR 1035](../phase-1-russetleaf-dev/adr/1035-platform-security.md) checks pass on EKS (Kyverno's three admission replicas spread across zones, the ValidatingAdmissionPolicy backstops present, metrics-server and Prometheus verifying the kubelets' certificates, the enabled admission plugins recorded from AWS's documentation for the version, and the cluster PKI noted as AWS's responsibility); access entries match [ADR 1033](../phase-1-russetleaf-dev/adr/1033-identity-and-access.md) (no unexpected cluster-admin, authentication mode API only) and the demo's audit logs reached the Log Archive bucket; platform namespaces are default-deny; GuardDuty shows the EKS cluster under audit-log monitoring, with any findings explained (and `aws guardduty create-sample-findings` for EKS reaching `#rl-security`); AWS WAF blocks requests to `/xmlrpc.php` and rate-limits `/wp-login.php`, at both the edge (Free plan web ACL) and the ALB; the edge ACL is attached and the Route 53 zone shows under the plan ([ADR 3009](adr/3009-edge-waf-on-cloudfront-free-plan.md)); pod traffic between nodes is encrypted (WireGuard), or the ADR explains why not; CiliumNetworkPolicies enforce (from a WordPress pod, `curl https://example.com` is blocked; `hubble observe --verdict DROPPED` shows only expected drops); Kyverno enforces; Falco alerts fire on EKS (repeat the home lab's `kubectl exec` test); Trivy Operator reports; kube-bench and Kubescape reports committed for this demo; a **Prowler** run (the `russetleaf-infra` workflow from Phase 1 step 7.5, triggered by hand) with the demo stack up, covering EKS, RDS, ElastiCache, the ALB and the rest of `envs/aws`, with findings fixed in OpenTofu or explained (fill in the AWS open item in [ADR 1007](../phase-1-russetleaf-dev/adr/1007-prowler-not-threatmapper.md)).

Also add the **AWS WAF steps** to the `under-attack.md` and `emergency-vulnerability.md` runbooks from Phase 1 step 7.14 ([ADR 1046](../phase-1-russetleaf-dev/adr/1046-incident-response-and-runbook-index.md)): a tighter rate-based rule and a custom block rule on the edge and ALB web ACLs, made through a OpenTofu change, or in an emergency through the console, recorded in the incident thread and brought back into OpenTofu the same day.

**Test:** a written checklist in `docs/` with each item checked; during this demo, a custom block rule added by following the emergency-vulnerability runbook blocks a test request at the edge, and is then removed through OpenTofu.

### Step 4.2: Cost review

**Do:** a **daily scheduled workflow** in `russetleaf-infra` (Cost Explorer data lags about 24 hours) that checks for recent demo usage, queries **Cost Explorer** grouped by the `Site` and `Stack` tags (the cost allocation tags activated in Phase 1 step 2.0), and posts "Last demo: $X for Y hours ($Z/hour)" to `#rl-costs`, compared with the ~$0.70/hour estimate. After the first full demo, also compare it with OpenCost's estimate for the same demo (captured before `demo-down`), and record both in [ADR 1012](../phase-1-russetleaf-dev/adr/1012-opencost-and-aws-billing.md).

**Test:** the day after a demo, the cost report appears in `#rl-costs` with the right hours; actual cost per demo hour is recorded in the decision log, and the Phase 3 design is updated if the estimates were off.

### Step 4.3 (optional): Istio ambient experiment on EKS

**Do:** during a demo session, install **Istio ambient mode** alongside Cilium on the EKS cluster (Istio's instructions for running with Cilium), add the WordPress namespace to the mesh, and try mTLS plus one layer-7 authorization policy. Measure the extra memory and latency, note any conflicts with Cilium's policies, then remove it before `demo-down`. Add the findings to [ADR 1001](../phase-1-russetleaf-dev/adr/1001-no-service-mesh.md). Nothing in the site depends on it.

**Test:** the ADR includes the EKS findings (resource use, latency, setup issues, what it added), and Istio is fully removed afterwards.

### Step 4.4 (optional): Tetragon process enforcement on EKS

**Do:** during a demo session, install **Tetragon** (Cilium's runtime-security tool) and add a tracing policy that **kills any process** in the WordPress pods that is not on its allow-list (`apache2`, `php`). Check that normal traffic and uploads still work, then try running an unlisted program. Measure Tetragon's memory use per node, remove it before `demo-down`, and record the findings in [ADR 1015](../phase-1-russetleaf-dev/adr/1015-process-allow-listing.md) (including whether it is worth trying at home).

**Test:** an unlisted process in a WordPress pod is killed immediately (and reported); the site keeps working; Tetragon is fully removed afterwards.

## Stage 5: Demo operations

### Step 5.1: Demo workflows

**Do:** GitHub Actions in `russetleaf-infra`, started by hand (`workflow_dispatch`), running on the **home ARC runners** (Phase 1 step 5.5), so the restricted EKS API endpoint accepts them:

- **`demo-up`:** `tofu apply` in `envs/aws`; wait for Argo CD to sync; wait until russetleaf.com returns 200; resume the russetleaf.com heartbeat check; **run the kube-bench Jobs** (one per node pool), wait for them to finish, collect their JSON and text output as workflow artifacts, compare with `docs/security/kube-bench-accepted.yaml`, commit the summary to `docs/security/` (through a pull request on `russetleaf-gitops`), and post pass/fail/warn counts to `#rl-security`, flagging new failures; post the start time (e.g. as a tag on the VPC) and "russetleaf.com demo started" to `#rl-com-alerts`.
- **`demo-down`:** take a **logical dump** of the RDS database (a one-off Job through RDS Proxy) into the russetleaf.com backup bucket, which replicates to the backup account (see the [disaster recovery plan](../phase-1-russetleaf-dev/disaster-recovery.md)); create an Alertmanager **silence** for `site=com` and pause the russetleaf.com heartbeat check; suspend Argo CD auto-sync; delete the Applications in reverse order; wait until the ALB, the `origin` record and the Karpenter nodes are gone (with timeouts); `tofu destroy` in `envs/aws`; confirm russetleaf.com returns the 503 offline page and no tagged demo resources remain; post "russetleaf.com demo stopped" (with the run time) to `#rl-com-alerts`.
- **Safety net:** a scheduled workflow (hourly) that alerts `#rl-costs` and `#rl-critical` (and optionally runs `demo-down`) if the demo stack has been up longer than a set limit (e.g. 6 hours).
- **Runbook** `docs/runbooks/demo-teardown-stuck.md` in `russetleaf-infra` ([ADR 1046](../phase-1-russetleaf-dev/adr/1046-incident-response-and-runbook-index.md)): what `demo-down` waits for and why it hangs (an ALB or target groups left by the Load Balancer Controller, network interfaces left by the VPC CNI, Karpenter nodes not terminating, finalizers on Ingresses or NodeClaims, security groups still referenced); finding leftovers by the `Stack` tag (the Resource Groups Tagging API) and deleting them in dependency order; when to re-run `tofu destroy`; and confirming the cost has stopped. Add it to the [runbook index](../runbooks.md).

**Test:** run `demo-up` and `demo-down` end to end twice without manual steps (each `demo-up` producing a kube-bench summary pull request and a `#rl-security` message), and confirm the teardown produces **no** alert noise in Slack (only the "stopped" message); force the safety net by lowering the limit; a tagged test resource left outside OpenTofu before `demo-down` is reported by the workflow's final check, then found and removed by following the stuck-teardown runbook.

### Step 5.1b: Rollback drill on EKS

**Do:** during one demo, run the AWS rollback paths from the rollback runbooks: deploy a deliberately broken WordPress version and let the **Argo Rollouts canary (CloudWatch analysis) roll it back**; take a manual RDS snapshot, then do a **point-in-time restore** of RDS to a moment before a test change, and flush the ElastiCache object cache as `rollback-data.md` requires; and for a `schema-change` release, confirm the manual RDS snapshot is taken before the demo uses it. Record the times in the decision log.

Also restore russetleaf.com's database **from the latest logical dump in the backup account** into the fresh RDS instance (the disaster-recovery path when snapshots are unavailable).

**Test:** the broken version is rolled back automatically; the point-in-time restore recovers the earlier data; the restore from the backup account's dump works; the timings are recorded.

### Step 5.1c: Forensic hold and forensics drill on EKS

**Do:** add the EKS steps to the compromised-container runbook from Phase 1 step 7.13 ([ADR 1045](../phase-1-russetleaf-dev/adr/1045-container-forensics.md)), and the infrastructure they need:

- **Forensic hold** in the demo workflows (step 5.1): `demo-down` stops with a clear message, and the safety net alerts but does not run `demo-down`, while any resource in the demo stack is tagged `ForensicHold=true`. A `forensic-hold` workflow (`workflow_dispatch`, with `set` and `release` inputs) adds or removes the tag on the VPC and posts to `#rl-security`.
- **In `envs/aws`:** an **isolation security group** with no rules; a policy granting **SSM Session Manager** access, kept detached from the node roles and attached only during an incident (by the runbook, through the break-glass permission set); session logging to the Log Archive account.
- **Runbook, EKS section:** annotate the node `karpenter.sh/do-not-disrupt: "true"` and set the forensic hold; run the shared freeze, contain and capture steps with the toolkit pod; capture whole-node memory with **AVML** through SSM, uploaded to the evidence bucket with a presigned URL; take an **EBS snapshot** of the node's volume tagged `ForensicHold=true`; swap the instance's security groups for the isolation group and turn on termination protection; record the VPC flow log and Resolver query log time ranges. Note that a **spot** node can be reclaimed with two minutes' warning, so memory comes first.
- Check whether the kubelet's **checkpoint API** works on the EKS nodes, and record the result in [ADR 1045](../phase-1-russetleaf-dev/adr/1045-container-forensics.md).

**Test:** during one demo, repeat the Phase 1 drill on a russetleaf.com WordPress pod (the marker string found in the captured memory, the quarantined pod cut off while a replacement serves the site); the AVML image and EBS snapshot exist, and the hashes in the evidence bucket match; Karpenter does not remove the held node during the drill; `demo-down` refuses to run while the hold is set, and the safety net (with its limit lowered) alerts without tearing down; after the runbook's release steps (termination protection off, then `forensic-hold release`), `demo-down` completes; the SSM policy is detached again. Record the time from alert to evidence uploaded in the decision log.

### Step 5.2: Full rehearsal and demo script

**Do:** write `docs/demo-script.md`: what to show and in what order (offline page → `demo-up` → live site → a page request's trace in Tempo → Argo Rollouts canary → Kyverno rejecting an unsigned image → Falco alert → OpenCost → `demo-down` → offline page). Rehearse, then record a walkthrough.

**Test:** a complete demo runs in under an hour of stack time, and the recording is linked from the hub README.

### Step 5.3: Documentation

**Do:** add the russetleaf.com architecture diagram and demo recording to the hub README; update the Phase 3 design wherever the build differed from it.

**Test:** the hub README explains both sites, with links to the recording, reports and dashboards.

### Step 5.4: Load, stress and spike tests (capacity data)

**Do:** during a demo, using the k6 Operator on EKS (the same `russetleaf-gitops/perf/` scripts as home), run a **load** test, a **stress / breakpoint** test (ramp until failure, and check it recovers on its own), a **spike** test (about 10× suddenly, to time HPA and Karpenter scale-up); for edge tests through CloudFront, keep them small (they count toward the Free plan's 1 million monthly requests) and apply a temporary allow rule for the test source to **both** web ACLs through OpenTofu (on the edge ACL, switch one rule to count mode for the test to stay within five rules), then remove it afterwards. Run the tests at increasing traffic levels; record how the HPA and Karpenter respond (scale-up time, nodes added), where latency or errors start to rise, the bottleneck (PHP workers, RDS Proxy connections, the top SQL statements in **Database Insights**, Valkey, CloudFront cache hit rate), and the cost per hour at each level. These numbers feed the capacity and cost plan (Phase 1 step 8.7).

**Test:** results for at least three traffic levels, the breaking point and recovery, spike scale-up times and cost per hour are recorded in `docs/performance/`, with the bottleneck identified, **cost per 1,000 visitors** calculated, and the temporary WAF rule removed.

### Step 5.5: Register EKS with the home Argo CD hub

**Do:** extend `demo-up` to register the EKS cluster with the home Argo CD (an Argo CD cluster secret using IAM authentication; the EKS API endpoint public but restricted to the home network's address), so the hub's ApplicationSets deploy the AWS overlays; extend `demo-down` to remove the registration first. Keep the per-cluster Argo CD path (step 1.8) as a documented fallback. See [ADR 1022](../phase-1-russetleaf-dev/adr/1022-internal-developer-platform.md).

**Test:** a demo run managed entirely from the home hub: both clusters visible, the AWS overlays synced, and the registration removed cleanly by `demo-down`.

## Ongoing operations (after the build)

| Task | How often | How |
|---|---|---|
| Run a demo (or at least `demo-up` / `demo-down`) | Monthly | Catches broken versions, expired assumptions and drift before a demo does |
| Check versions before the demo | Before each demo | Review the latest version-age report and Renovate's pending updates for `envs/aws` (EKS, add-ons, AMI, RDS and ElastiCache engine versions); keep RDS's MariaDB version matched to the home MariaDB |
| Keep the EKS version in standard support | Before each demo, if a new version is out | Bump the version in `envs/aws`; the stack is rebuilt each demo, so there is no in-place upgrade |
| Clean up old final snapshots | Automatic (step 1.6) | Check that only the last 3 remain |
| Check the always-on edge for drift | Weekly | Scheduled `tofu plan` for `envs/aws-edge` in `russetleaf-infra` CI |
| Check for leftovers | After each demo | Search for resources tagged `Stack=demo`; the Budget and Cost Anomaly alerts in `#rl-costs` are the backstop |
| Review russetleaf.com alert noise | After each demo | Anything that fired during the demo should have been real; tune or remove alerts that were not |
| Rotate the CloudFront-to-ALB secret header | Every few months | Change the value in `envs/aws-edge`; the next demo picks it up |
| Prowler AWS scan with the stack up | Once per demo | Trigger the `russetleaf-infra` Prowler workflow during the demo; review findings for the demo resources |
| kube-bench scan | Every demo (automatic, in `demo-up`) | Review the summary pull request and any new failures flagged in `#rl-security`; fix in OpenTofu or the node class, or add to the accepted-findings file with a reason |
| Kubescape posture scan | Once per demo | Run the Kubescape CLI against EKS during the demo; save the report in `docs/security/` |
| Review the per-demo cost report | The day after each demo (automatic) | Check the `#rl-costs` report; investigate if cost per hour is well above the ~$0.70 estimate |
| Review costs | After each demo | Cost Explorer filtered by `Site=com`, compared with the demo hours recorded |

## Progress checklist

| Step | Tier | Est. hours | Done | Date | Actual hours | Done by | Review findings | Stack cost this session | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 0.1 Account, DNS and guardrails | Core | 2–3 | ☐ | | | | | | |
| 0.2 Decisions | Core | 1–2 | ☐ | | | | | | |
| 0.3 Agent workspace and AWS access | Core | 3–5 | ☐ | | | | | | |
| 1.1 CI roles | Core | 2–3 | ☐ | | | | | | |
| 1.2 Always-on edge | Core | 7–10 | ☐ | | | | | | |
| 1.3 Network | Core | 3–5 | ☐ | | | | | | |
| 1.4 EKS cluster | Core | 8–12 | ☐ | | | | | | |
| 1.5 Karpenter infrastructure | Core | 3–5 | ☐ | | | | | | |
| 1.6 RDS for MariaDB + Valkey | Core | 6–10 | ☐ | | | | | | |
| 1.7 App resources + permissions | Core | 4–7 | ☐ | | | | | | |
| 1.8 Argo CD on EKS | Core | 2–3 | ☐ | | | | | | |
| 1.9 CI for AWS environments | Core | 2–4 | ☐ | | | | | | |
| 2.1 AWS root app | Core | 2–3 | ☐ | | | | | | |
| 2.2 Load Balancer Controller, ExternalDNS, storage | Core | 3–5 | ☐ | | | | | | |
| 2.3 Karpenter NodePools | Core | 3–6 | ☐ | | | | | | |
| 2.4 Shared platform overlays | Core | 4–8 | ☐ | | | | | | |
| 2.5 kube-bench + Kubescape scan | Extended | 2–3 | ☐ | | | | | | |
| 3.1 WordPress AWS overlay | Core | 5–9 | ☐ | | | | | | |
| 3.2 Seed + snapshot cycle | Core | 3–5 | ☐ | | | | | | |
| 4.1 Security review | Extended | 5–7 | ☐ | | | | | | |
| 4.2 Cost review | Extended | 2–3 | ☐ | | | | | | |
| 4.3 Istio ambient experiment (optional) | Advanced | 3–5 | ☐ | | | | | | |
| 4.4 Tetragon enforcement (optional) | Advanced | 3–5 | ☐ | | | | | | |
| 5.1 Demo workflows | Core | 6–10 | ☐ | | | | | | |
| 5.1b Rollback drill on EKS | Extended | 2–4 | ☐ | | | | | | |
| 5.1c Forensic hold + forensics drill on EKS | Extended | 3–5 | ☐ | | | | | | |
| 5.2 Rehearsal + recording | Core | 3–5 | ☐ | | | | | | |
| 5.3 Documentation | Core | 2–3 | ☐ | | | | | | |
| 5.4 Load, stress and spike tests | Advanced | 6–9 | ☐ | | | | | | |
| 5.5 Register EKS with the Argo CD hub | Advanced | 4–6 | ☐ | | | | | | |

## Decision log

| Date | Decision | Reason |
|---|---|---|
| | | |
