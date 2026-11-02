# Home Lab Build Plan (russetleaf.dev)

This is the step-by-step plan for writing and testing all the code for the **russetleaf.dev home lab** described in [`aws-wp.md`](aws-wp.md). The AWS EKS site (russetleaf.com) is **out of scope** for now; see [Deferred to the AWS phase](#deferred-to-the-aws-phase).

Each step is sized for one or a few Claude sessions, and ends with a **test** that must pass before moving on. Steps are ordered so that everything a component depends on already exists and works.

## How to use this plan with Claude

- **Start each session** with something like: *"Read `aws-wp.md` and `homelab-plan.md`. We're working on step 7. Here's where I left off: ..."*. Claude has no memory of earlier sessions, so these two files are the shared context.
- **One step at a time.** Build it, run the step's test, fix, commit. Don't start the next step until the test passes.
- **Core first.** Each step has a tier (Core, Differentiator, Stretch) and an hour estimate; see [Priorities and time estimates](#priorities-and-time-estimates). Record actual hours in the checklist.
- **Keep the plan current.** Tick the [progress checklist](#progress-checklist) and add to the [decision log](#decision-log) whenever something is decided or differs from `aws-wp.md`. Ask Claude to update this file at the end of each session.
- **Watch node memory.** After every step that adds something to the cluster, run `kubectl top nodes` and note the result in the checklist. The three nodes have about 32 GB in total (box 3: 16 GB; boxes 1 and 2: 8 GB each); keep the main workloads on box 3 and box 2 for the LLM.
- **Build the home overlays only, but keep the base clean.** Put anything environment-specific (domain, hostnames, endpoints, credentials) in `overlays/home` (prod), `overlays/home-staging` or `overlays/ci`, never in `base`, so `overlays/aws` can be added later without rework.
- **Use the environments.** Try changes **locally** first (Docker Compose or a local kind/Talos cluster); once step 5.4 exists, every pull request is tested in a **ci** kind cluster; once step 5.6 exists, new versions go through **staging** before production. See [Environments and promotion](aws-wp.md#environments-and-promotion).
- **Never commit secrets.** Secrets go in AWS Secrets Manager and reach the cluster through External Secrets. Terraform state (which can contain secrets) lives in an encrypted S3 bucket. kubeconfig and talosconfig files stay outside Git.

## Priorities and time estimates

Every step in the [progress checklist](#progress-checklist) has a **tier** and an **estimate** in focused hours (with Claude's help). Estimates are rough (expect ±50%); record **actual hours** in the checklist and re-estimate after phase 2.

| Tier | What it means | Steps | Est. hours |
|---|---|---|---|
| **Core** | A complete, demonstrable home lab: infrastructure as code (including the AWS Organization), a three-node highly available Talos cluster with Cilium, GitOps, platform services, monitoring and alerting, backups, the WordPress image and chart with its supply-chain pipeline, ci, staging and promotion, Kyverno and network policies, and the docs. **Finished on its own, this reads as strong intermediate work.** | 0.1–2.4, 3.1, 4.1–4.6, 5.1–5.7, 6.1, 6.3, 11.2 | **~120–208** |
| **Differentiator** | What moves it to senior: the AI summary pipeline and MLOps (evaluation gate, local model, MLflow tracking and registry, guardrails, online evaluation and drift monitoring), progressive delivery, sandboxing, runtime security and compliance, cost monitoring, disaster-recovery copies, Google sign-in, always-on tracing, CrowdSec, and **evidence of operating it** (rollback, node-failure and disaster drills). | 2.5, 5.8, 6.2, 6.4, 6.5, 7.1–9.6, 10.1–10.6, 10.8–10.11 | **~103–182** |
| **Stretch** | Extras: the rest of the MLOps lifecycle (feedback loop, DVC, deploying a fine-tuned model; valuable for MLOps roles specifically), custom seccomp profiles, keyless AWS access. | 9.7, 9.8, 10.7, 11.1 | **~19–35** |
| **Staff** | Beyond senior: SLOs and error budgets gating promotions, DORA metrics, an internal developer platform (Backstage, a golden path proven with a second service, multi-tenancy), fleet management, chaos experiments and postmortems, a threat model and control matrix, strategy documents, and public writing. Shows staff-level judgement; staff roles also expect evidence of leading people. | 12.1–12.9 | **~81–132** |
| **Total** | | | **~323–557** |

**Calendar time** (home lab only):

| Hours per week | Core | + Differentiators | + Stretch | + Staff (everything) |
|---|---|---|---|---|
| ~10 | 3–5 months | 5–9 months | 6–10 months | 8–13 months |
| ~20 | 6–10 weeks | 11–20 weeks | 12–21 weeks | 16–28 weeks |
| ~40 | 3–5 weeks | 6–10 weeks | 6–11 weeks | 8–14 weeks |

Add the AWS plan (~111–192 hours; see [`aws-eks-plan.md`](aws-eks-plan.md#priorities-and-time-estimates)) for the full project: **~434–749 hours** (about **345–605** without the Staff tier).

**Where the time really goes:** Claude makes writing code, configuration and documents much faster, but the calendar is dominated by **debugging environment-specific problems** (Talos and Cilium networking, Kyverno blocking something, OIDC trust policies, tunnel routing), **waiting** (CI runs, quota approvals, DNS), and **learning each tool well enough to explain it in an interview**.

**Recommended order:** finish **all Core steps first** (in plan order), and publish them; then add Differentiators, starting with the AI pipeline (phases 7–9) and the drills (10.8, 10.10, 10.11), which give the most interview material; leave Stretch and Staff steps until Core and Differentiators are done (for staff-level roles, the Staff tier matters more than Stretch). A finished subset is worth more than an unfinished whole.

## Starting point (as of 2026-10-31)

- One Talos node (box 1, `192.168.1.6`, Talos v1.14.4, Kubernetes v1.37.1), control plane, no taints.
- Argo CD installed in the `argocd` namespace.
- This repo (`private-test-wordpress`) holds an Argo CD Application that deploys the Bitnami WordPress chart into `wordpress-test`. Its pods are stuck in `Pending` because the cluster has no storage provisioner. This test deployment will be replaced.
- russetleaf.dev is a Cloudflare zone.
- Box 2 (Intel i3, 8 GB) is available, and **box 3 (Intel i5-8500T, 6 cores, 16 GB, NVMe SSD)** is being added, giving a **three-node, highly available cluster** (see `docs/adr/0021-three-node-ha-home-cluster.md`). Before installing Talos on box 3: update its BIOS, turn on **power on after AC loss** and virtualization, and set Secure Boot to match the Talos image. Do the same on boxes 1 and 2.

## Local workstation setup (Ubuntu 24.04)

Everything is built and tested from your Ubuntu 24.04 machine, which is also the **local** environment (see [Environments and promotion](aws-wp.md#environments-and-promotion)). Do this before step 0.1's test.

**Hardware:** 16 GB of RAM or more is recommended; a local kind or Talos-in-Docker cluster plus LocalStack and WordPress use about 4–6 GB. At least 40 GB of free disk for container images.

### 1. Base packages

```bash
sudo apt update
sudo apt install -y git curl wget unzip jq make ca-certificates gnupg lsb-release \
  python3 python3-venv shellcheck direnv
```

### 2. Docker Engine (from Docker's own repository, not the snap)

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"     # then log out and back in
```

**kind needs higher file-watch limits** on Ubuntu (otherwise pods fail with "too many open files"):

```bash
echo -e "fs.inotify.max_user_watches=524288\nfs.inotify.max_user_instances=512" \
  | sudo tee /etc/sysctl.d/99-kind.conf
sudo sysctl --system
```

### 3. CLI tools, pinned per repo with mise

Use **mise** to install the command-line tools, with the versions pinned in a `.mise.toml` file in each repo. The same file is used by CI (the `jdx/mise-action` GitHub Action), so your machine and CI always run the same versions, and Renovate can keep them updated.

```bash
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
source ~/.bashrc
```

Tools to pin (check each name with `mise registry | grep <tool>`; pin `kubectl` and `talosctl` to your cluster's versions):

| Tool | Used for |
|---|---|
| `terraform` (1.10+), `tflint` (with `tflint-ruleset-aws`), `terraform-docs`, `infracost` | Infrastructure (`wp-infra`) |
| `talosctl` | Talos clusters (home and local Talos-in-Docker) |
| `kubectl`, `helm`, `kustomize` | Kubernetes and charts |
| `kind` | Local and ci test clusters |
| `argocd` | Argo CD CLI (staging workflow, debugging) |
| `k9s`, `stern`, `kubectx` | Day-to-day cluster work (optional but very useful) |
| `kubeconform`, `chart-testing` (`ct`) | Manifest and chart validation |
| `k6` | Load tests (e.g. WordPress with and without gVisor, step 6.5) |
| `cilium`, `hubble` | Cilium status and connectivity tests; Hubble flow queries |
| `kyverno` | Policy tests |
| `cosign`, `syft`, `trivy`, `rekor-cli` | Image signing, SBOMs, scanning, transparency-log lookups |
| `hadolint`, `container-structure-test`, `zizmor` | Dockerfile linting, built-image checks, GitHub Actions workflow security |
| `kubescape` | On-demand cluster posture scans (NSA-CISA, MITRE ATT&CK, RBAC) |
| `prowler` (installed with `uv`) | AWS account posture scans (CIS AWS Foundations); also runs in CI |
| `gh` | GitHub CLI |
| `awscli` (v2) | AWS |
| `uv` | Python tooling (the summarizer, Checkov, pre-commit, LocalStack CLI) |
| `promtool` (from Prometheus) | Testing alert rules |

Python-based tools, installed with uv:

```bash
uv tool install pre-commit
uv tool install checkov
uv tool install semgrep
uv tool install zizmor        # if not installed with mise
uv tool install ruff
uv tool install pip-audit
uv tool install localstack      # optional: LocalStack CLI (LocalStack itself runs in Docker)
```

PHP and Composer aren't needed locally: the WordPress image installs plugins inside its Docker build, and the PHP linters (PHP_CodeSniffer with the WordPress Coding Standards, PHPStan) run in a container, locally and in CI.

### 4. Configuration

- **Git:** set your name and email; authenticate with `gh auth login` (SSH); turn on **commit signing** with your SSH key (`git config --global gpg.format ssh` and `user.signingkey`), and upload the key to GitHub as a signing key.
- **AWS:** after step 2.0, sign in through **IAM Identity Center (SSO)**, with one profile per account and permission set (e.g. `rl-mgmt-admin`, `rl-security-admin`, `rl-home-admin`, `rl-com-admin`, `rl-infra-admin`, and read-only variants), created with `aws configure sso`; sign in with `aws sso login --sso-session russetleaf`. Until then, use the existing account's admin login. Keep **no long-lived AWS access keys** on the workstation.
- **Cloudflare and Slack tokens:** don't put them in `~/.bashrc`. Use per-repo **direnv** files (`.envrc`, listed in `.gitignore`) that load them from a password manager CLI or from AWS Secrets Manager when you enter the repo folder.
- **Cluster access files:** keep kubeconfig contexts named clearly (`talos-home`, `kind-ci`, `talos-local`) and talosconfig at `~/.talos/config`, both with `chmod 600`. Back them up in your password manager. (If they're lost, they can be regenerated from the Talos machine secrets in Terraform state.)
- **Pre-commit hooks:** run `pre-commit install` in each repo after cloning (secret scan, YAML checks; in `wp-infra`, the **pre-commit-terraform** hooks: fmt, validate, tflint, terraform-docs, Checkov).
- **Editor (optional):** VS Code with the HashiCorp Terraform, YAML (Red Hat), Kubernetes and Docker extensions.

### 5. Check the setup

Add a `scripts/check-tools.sh` to `wp-gitops` that prints every tool's version and fails if one is missing. Then:

```bash
docker run --rm hello-world
kind create cluster --name smoke && kubectl get nodes && kind delete cluster --name smoke
talosctl cluster create --name local-smoke          # Talos in Docker
talosctl cluster destroy --name local-smoke
aws sts get-caller-identity --profile russetleaf-admin
gh auth status
```

**Test:** all of the above succeed, and `scripts/check-tools.sh` reports every tool.

## Phase 0: Prerequisites and decisions

### Step 0.1: Accounts, tools and budget alert
**Do:**
- Accounts: AWS: your **existing account** (which becomes `russetleaf-home`) plus a **new, dedicated management account** (its own email address, root MFA on) for the AWS Organization in step 2.0; GitHub; Cloudflare (russetleaf.dev zone).
- Set up the workstation: see [Local workstation setup](#local-workstation-setup-ubuntu-2404).
- Create an **AWS Budget** with an email alert at about $25/month (by hand in the console is fine; Terraform takes over in step 2.1).
- Pick an AWS region for the home lab's AWS resources (e.g. `us-east-1`) and use it everywhere.

- **Break-glass kit** (see `docs/disaster-recovery.md`): in your password manager, record the AWS root login and **MFA recovery**, GitHub, Cloudflare and Google recovery codes, and the domain registrar logins; print the essentials and store the printed copy safely (ideally a second copy elsewhere). Add the Talos secrets bundle after step 2.2.
- **Slack:** create the project workspace and the channels from `aws-wp.md` ([Alerting and notifications](aws-wp.md#alerting-and-notifications-slack)): `#rl-critical`, `#rl-dev-alerts`, `#rl-com-alerts`, `#rl-deploys`, `#rl-security`, `#rl-mlops`, `#rl-costs`, `#rl-staging`. Create the custom Slack app ("russetleaf-bot") with a bot token allowed to post to those channels, and install the **GitHub** app for Slack. Turn on phone notifications for `#rl-critical` only.
- **Outside monitoring accounts** (free plans): a heartbeat service (e.g. healthchecks.io) and an uptime checker (e.g. UptimeRobot or Better Stack), both posting to Slack.

**Test:** the workstation checks pass; a test message from the bot token (`curl` to Slack's `chat.postMessage`) appears in `#rl-dev-alerts`.

### Step 0.2: Decisions to make before writing code
Record each answer in the [decision log](#decision-log).

| Decision | Recommendation | Why it matters |
|---|---|---|
| **WordPress Helm chart** | Write a **small chart of your own** (Deployment/Rollout, Service, Ingress, HPA, PDB, CronJob for WP-Cron), kept in `wp-image/chart/` and released together with the image, for an image built on the **official `wordpress` image**. (`aws-wp.md` already assumes this.) | The Bitnami chart only works with Bitnami-format images (their startup scripts and environment variables). Since Bitnami cut back its free images in 2025, the alternatives are building Bitnami's image yourself from their open-source `bitnami/containers` repo, or your own chart. Your own chart is simpler to reason about, removes the Bitnami dependency, and is a portfolio piece. |
| **Container registry** | **GHCR** (GitHub Container Registry): free for public images, and cosign keyless signing works with GitHub Actions out of the box. Note that **GHCR packages have their own visibility, separate from the repo's**, and start private. | Kyverno policies and image references depend on it. |
| **Repos public or private** | Private while building; make public once each repo has been scanned for secrets (`gitleaks`). | Self-hosted runners on public repos need extra care (step 9.2). |
| **Summarizer language** | **Python** (boto3 for SQS, the `openai` client for the gateway, OpenTelemetry SDK). | Fastest path; the most common language for MLOps work. |
| **Existing Talos node** | **Rebuild it with Terraform** in step 2.2, rather than adopting the hand-built config. | Nothing on the cluster is worth keeping, and a Terraform-built cluster is reproducible. Adopting it means importing its existing machine secrets, which is fiddly. |
| **Bot for version-bump pull requests** | A **GitHub App** installed only on `wp-gitops`. | Narrower and longer-lived than a personal access token. |
| **Networking (CNI)** | **Decided: Cilium**, as the full CNI replacing Talos's default Flannel **and kube-proxy**, with Hubble. EKS also runs Cilium (chaining mode), so both clusters use **CiliumNetworkPolicies**. See [Networking: Cilium and Hubble](aws-wp.md#networking-cilium-and-hubble). | Changing the CNI later means rebuilding the cluster. Flannel doesn't enforce network policies at all, so without Cilium any pod could reach any other pod (e.g. the database). |
| **Database credentials** | Home: passwords **generated by MariaDB Operator** into Kubernetes Secrets (never typed, never in Git or Secrets Manager), rotated on a schedule, TLS required. AWS (later): IAM auth through RDS Proxy. See [Database access and credentials](aws-wp.md#database-access-and-credentials). | Decides how WordPress gets its database login on each site; the chart must support both. |
| **Staging** | **On-demand, scale-to-zero** staging on the home cluster (created for each promotion, deleted afterwards). Promotion with plain **GitHub Actions** workflows; consider **Kargo** later only if memory allows. | Box 1 has no memory to spare for an always-on staging copy. |
| **AWS stand-ins for ci tests** | **LocalStack** (S3, SQS, Secrets Manager), if its current free-tier terms suit; otherwise **MinIO** (S3) + **ElasticMQ** (SQS) + plain Kubernetes Secrets. | ci tests must run without an AWS account. |
| **Resource tagging** | Every AWS resource gets `Project=russetleaf`, `Site=dev`, `Env=prod|staging`, `ManagedBy=terraform`, set as the AWS provider's `default_tags`. | Lets you find leftovers and see costs per site in Cost Explorer. The AWS plan uses the same scheme with `Site=com`. |

## Phase 1: Repositories

### Step 1.1: Create the four repos
**Do:**
- Rename this repo to **`wp-gitops`**. Create **`wp-infra`**, **`wp-image`** and **`llm-summarizer`**.
- In each: a README stub, `.gitignore` (Terraform state, `.terraform/`, kubeconfig, talosconfig, `.env`), a `LICENSE` if public, branch protection on `main` (pull requests and passing checks required).
- In `wp-gitops`: a `docs/adr/` folder for **architecture decision records**, with a short template (context, decision, alternatives, consequences, when to revisit). Record the big step 0.2 decisions there as ADRs, and link them from the decision log. The template (`0000-template.md`) and three ADRs already exist as drafts in this repo's `docs/adr/`: `0001-no-service-mesh.md` (finish in step 6.4), `0002-s3-media-not-efs.md` (finish in step 5.1) and `0003-kubescape-cli-not-operator.md` (finish in step 10.2) and `0004-ghcr-not-ecr.md` (finish in step 5.1) `0005-loki-alloy-for-logs.md` (finish in step 4.6) and `0006-tempo-tracing.md` (finish in step 10.4) and `0007-prowler-not-threatmapper.md` (finish in step 10.5) and `0008-google-sign-in-for-admins.md` (finish in step 5.8) and `0009-gvisor-sandboxing.md` (finish in step 6.5) and `0010-local-storage-no-ceph.md` (finish in step 4.5) `0011-update-strategy.md` (finish in steps 1.1, 5.1 and 10.6) `0012-kube-bench-eks-only.md` (finish in home step 10.2 and AWS step 2.5) `0013-opencost-and-aws-billing.md` (finish in home steps 2.1 and 10.3 and AWS step 5.2) and `0014-image-supply-chain.md` (finish in steps 5.1, 6.1 and 7.4) and `0015-availability-levels.md` (finish in steps 2.2 and 4.5 and AWS step 3.1) `0016-process-allow-listing.md` (finish in step 10.1) and `0017-rollback-strategy.md` (finish in steps 3.1, 5.7, 6.1, 7.4 and 10.8) and `0018-intrusion-detection-and-prevention.md` (finish in steps 2.1, 2.2, 2.3, 4.6 and 10.9) and `0019-disaster-recovery.md` (finish in steps 0.1, 2.5 and 10.10) and `0020-aws-multi-account-sra.md` (finish in steps 2.0, 2.0b and 2.4) and `0021-three-node-ha-home-cluster.md` (finish in steps 2.2, 4.5 and 10.11) and `0022-mlops-lifecycle.md` (finish in steps 9.4–9.8 and AWS step 4.5), and `0023`–`0025` (SLOs, the developer platform, reliability practice; finish in phase 12); move them, and `docs/disaster-recovery.md`, with the other docs.
- Add a pre-commit or CI secret scan (`gitleaks`) to every repo.
- Add **OpenSSF Scorecard** (weekly scheduled workflow) and **zizmor** (on workflow changes) to every repo, and GitHub's **dependency-review action** to the repos with dependencies (`wp-image`, `llm-summarizer`).
- Add **Checkov** to every repo's CI from the start, scanning the **GitHub Actions workflows** (unpinned actions, over-broad `permissions`, script injection), with a `.checkov.yaml` per repo. Later steps add each repo's other targets (Terraform, manifests, Dockerfiles, charts). Skips must carry a reason. See [Infrastructure and configuration scanning](aws-wp.md#infrastructure-and-configuration-scanning-checkov).
- Add **Renovate** to every repo (Helm charts, Terraform providers, base images, GitHub Actions, `.mise.toml`, and later Composer and Python lock files), with a shared configuration following `aws-wp.md`'s [Update strategy](aws-wp.md#update-strategy): a weekly schedule (security updates immediately), grouping per platform component, **auto-merge for patch updates** of platform charts, CLI tools and GitHub Actions once CI passes, the **Dependency Dashboard**, and custom version rules for Talos and Kubernetes versions in Terraform.
- In `wp-gitops`: move `aws-wp.md` and this file to `docs/`, and write the hub README (what the project is, links to all four repos).

**Test:** each repo has protected `main`, the secret scan and Checkov run on a test pull request (a workflow with `permissions: write-all` fails Checkov), and Renovate opens its onboarding pull request.

## Phase 2: Infrastructure (`wp-infra`)

### Step 2.0: AWS Organization and accounts (Security Reference Architecture)
**Do** (`wp-infra/envs/org/`, applied locally with the new management account), following `aws-wp.md`'s [AWS account structure](aws-wp.md#aws-account-structure-and-best-practices-security-reference-architecture) and ADR 0020:
- Create the **Organization** from the dedicated management account; **OUs**: Security, Infrastructure, Workloads.
- **Accounts:** create **Security Tooling**, **Log Archive** and **Backup** (Security OU), **russetleaf-infra** (Infrastructure OU) and **russetleaf-com** (Workloads OU); **invite the existing account** and move it into Workloads as **russetleaf-home**.
- **IAM Identity Center:** permission sets for admin, read-only and break-glass, MFA required; assign yourself per account.
- **SCPs** (start by attaching them to a test OU, then to the real OUs): deny leaving the Organization; deny disabling CloudTrail, GuardDuty, Config, Security Hub and Access Analyzer; allow only us-east-1 and us-west-2 (global services excepted); deny member-account root actions; deny IAM users and access keys except a named exception for the home cluster's scoped-key users in russetleaf-home; protect the Log Archive and Backup buckets.
- **Centralised root access management** (remove member accounts' root credentials), **tag policies**, **alternate security contacts** on every account, **delegated administrators** (Security Tooling for GuardDuty, Security Hub, Config, Access Analyzer).
- **Budgets:** a consolidated one in the management account plus one per workload account; **activate the cost allocation tags** (`Project`, `Site`, `Env`, `Stack`, `ManagedBy`) here, in the management account, where they apply organisation-wide (a tag must exist on a resource first, so re-run after step 2.3 if needed; activation can take up to a day).
- Update the break-glass kit: the management account's root access and the Identity Center logins (member accounts no longer have root credentials).

**Test:** you can sign in to every account through Identity Center with MFA; a test action blocked by an SCP fails (e.g. creating a resource in eu-west-1, or disabling GuardDuty in russetleaf-home); member accounts show no root credentials; an untagged resource is flagged by the tag policy.

### Step 2.0b: Organisation security services
**Do** (`wp-infra/envs/security/`, applied with Security Tooling and Log Archive access):
- **Log Archive:** S3 Object Lock buckets with **KMS customer-managed keys** for the **organisation CloudTrail trail** (management events, all accounts and regions, log-file validation), Config history and (later) VPC flow logs.
- **Security Tooling:** organisation-wide **GuardDuty** (with EKS audit-log monitoring, auto-enabled for new accounts), **Security Hub** (AWS Foundational Security Best Practices and CIS standards in every account), **AWS Config** with **focused recording** (IAM, S3, security groups, KMS, EKS, RDS and other key types) and a **CIS conformance pack**, aggregated here, and **IAM Access Analyzer** (organisation external-access analyzer).
- **Findings to Slack:** EventBridge rules for GuardDuty findings (medium and above) and Security Hub findings (critical and high) to SNS topics connected through **Amazon Q Developer in chat applications** (authorise the Slack workspace once) to `#rl-security` (critical also to `#rl-critical`).
- **Account-level settings in every account:** S3 Block Public Access, EBS encryption by default, EBS snapshot and AMI public-access blocks.

**Test:** GuardDuty sample findings (`aws guardduty create-sample-findings`) appear in `#rl-security`; CloudTrail log-file validation passes (`aws cloudtrail validate-logs`) for an event from each account; Security Hub shows every account with both standards enabled, and the first scores are recorded in the decision log; a deliberately public test bucket is blocked by Block Public Access and flagged by Access Analyzer.

### Step 2.1: Bootstrap (state bucket and CI roles)
**Do** (`wp-infra/bootstrap/`, applied locally):
- In **russetleaf-infra**: the S3 bucket for Terraform state (versioning, KMS encryption, public access blocked, TLS required, `prevent_destroy`). Backends use `use_lockfile = true`. Bucket policy granting each account's CI roles access to their own state keys only.
- In **each account** that CI deploys to (russetleaf-home, russetleaf-infra, and later russetleaf-com and the security accounts): the GitHub OIDC provider, a read-only **plan** role (pull requests), an **apply** role (only from the `apply` GitHub Environment), and a read-only **audit** role for Prowler (AWS's `SecurityAudit` and `ViewOnlyAccess` managed policies; used in step 10.5).

**Test:** a scratch root module with the S3 backend runs `terraform init` and `plan`; a GitHub Actions job in `wp-infra` assumes the plan role in russetleaf-home and runs `aws sts get-caller-identity`; the same job can't read another account's state key.

### Step 2.2: Talos cluster (three control-plane nodes)
**Do** (`wp-infra/envs/home/`, applied locally; uses the `siderolabs/talos` provider):
- Generate machine secrets; machine configs for **three control-plane nodes**, all schedulable: **box 3** (main workloads), **box 1** (secondary workloads) and **box 2** (LLM). Give each a fixed IP (DHCP reservations or static addresses).
- **Shared virtual IP** for the Kubernetes API (Talos's `vip` setting on the nodes' network interface), on a free address in your LAN; kubeconfig and Talos endpoints point at it.
- **Reservations on every node** (kubelet `systemReserved` and `kubeReserved` for CPU and memory), so workloads can't starve etcd, the API server or the kubelet.
- Box 2: node label `workload=llm`, taint `dedicated=llm:NoSchedule`.
- Box 3 and box 1: labels for the workload roles (e.g. `role=main`, `role=secondary`), used for placement (e.g. the MariaDB primary on box 3).
- All nodes: the Talos image includes the **gVisor system extension** (built through Talos's Image Factory and referenced in the machine config), used in step 6.5.
- All nodes: kubelet extra mount for `/var/local-path-provisioner` (needed in step 4.1).
- **API server audit logging:** a focused Talos audit policy (metadata for most requests; request details for Secrets, RBAC, `exec` and `attach`), writing to the audit log on each control-plane node (collected in step 4.6).
- **Cilium:** in the machine config, set `cluster.network.cni.name: none` and `cluster.proxy.disabled: true` (Cilium replaces kube-proxy). Install Cilium with Terraform's Helm provider right after bootstrap (nothing else can run without a CNI), using Talos's documented Cilium values: `kubeProxyReplacement: true`, `k8sServiceHost: localhost`, `k8sServicePort: 7445` (KubePrism), and the cgroup and capability settings Talos requires. Turn on Hubble and Hubble Relay, and **WireGuard transparent encryption** (`encryption.enabled: true`, `encryption.type: wireguard`). Keep Cilium's ServiceMonitors **off** here (the Prometheus Operator doesn't exist yet; step 4.4 turns them on). Use `lifecycle { ignore_changes }` so Terraform installs Cilium once and Argo CD manages it afterwards (step 3.1).
- Apply configs, bootstrap etcd, output kubeconfig and talosconfig (save them outside Git).
- Install **metrics-server** here or in step 4.1, so `kubectl top` works.

The cluster is **highly available for a single node failure** (three etcd members, the virtual IP); see `docs/adr/0021-three-node-ha-home-cluster.md` and `docs/adr/0015-availability-levels.md`.

**Test:** `kubectl get nodes` shows all three nodes `Ready`; `kubectl describe node <box2>` shows the label and taint; `talosctl health` passes; `cilium status` is all green and `cilium connectivity test` passes; `etcd` has **three healthy members** (`talosctl etcd members`); the API answers on the virtual IP, and still answers after shutting down whichever node holds it; `cilium encrypt status` shows WireGuard on with the other two nodes as peers on each node; there's no kube-proxy DaemonSet. Rebuild once from scratch to prove it's reproducible, and **record how long the rebuild took** as the recovery time in `docs/adr/0015-availability-levels.md`.

### Step 2.3: AWS and Cloudflare resources for the home lab
**Do** (`wp-infra/modules/` + `envs/home/`; all AWS resources in the **russetleaf-home** account):
- Modules: `s3-media`, `s3-backups`, `sqs-queue` (with dead-letter queue), `secrets`, `bedrock-access`.
- russetleaf.dev resources: media bucket, database-backup bucket (lifecycle: expire after 30 days), **model mirror bucket** (for the self-hosted model's file, used in step 8.1), **Loki log bucket** (lifecycle: expire after 7 days, used in step 4.6, plus a scoped IAM key for Loki), **Tempo trace bucket** (lifecycle: expire after 3 days, used in step 10.4, with its own scoped key), summary queue + dead-letter queue, Secrets Manager entries (empty placeholders; values set by hand or generated), Bedrock budget alert.
- **`prevent_destroy`** on every stateful resource (the state bucket, media, backup, log, trace and model mirror buckets, and Secrets Manager entries), so no plan, including a revert's, can delete them without a deliberate code change (see `aws-wp.md`'s [Rollback strategy](aws-wp.md#rollback-strategy)).
- **Staging resources** (a second, smaller set of the same modules, tagged `Env=staging`): staging media bucket, summary queue + dead-letter queue, Secrets Manager entries, and a scoped IAM key that can **read** the production backup bucket but write only to staging resources. Used from step 5.6.
- **Email:** an SES domain identity for russetleaf.dev, with its DKIM and SPF records created in Cloudflare, and SES SMTP credentials stored in Secrets Manager. (New SES accounts are in the "sandbox" and can only send to verified addresses; verify your own address for testing, or request production access.)
- Scoped IAM users and keys for the home cluster, one per job: External Secrets (read the russetleaf.dev secrets only), WordPress (media bucket + send to queue), MariaDB backups (backup bucket), summarizer (read from queue), LiteLLM (`bedrock:InvokeModel` on the chosen models only). Store each key in Secrets Manager.
- Cloudflare (Cloudflare provider): the tunnel, its token (stored in Secrets Manager), DNS records for `russetleaf.dev` and `www`, basic WAF/security settings plus Cloudflare's free **managed rule set**, a **rate-limiting rule** on `/wp-login.php`, and a rule **blocking `/xmlrpc.php`**, **Cloudflare Access** policies for admin UIs (Argo CD, Grafana) so they're never public, with **Google** configured as Cloudflare Access's login provider (used for WordPress admin paths in step 5.8), **Cloudflare notifications** (tunnel health, security events) to a Slack webhook for `#rl-dev-alerts`, and a `staging.russetleaf.dev` hostname behind Cloudflare Access (used from step 5.6).
- The Slack bot token in Secrets Manager (set by hand; Terraform creates the empty entry).
- Bedrock: confirm access to Claude Haiku and Amazon Nova Lite in the chosen region (Anthropic models may need a one-time use-case form in the console).

**Test:** with each scoped key, the allowed action works and a disallowed one fails (e.g. the WordPress key can't read the backup bucket); `aws bedrock-runtime converse` with the LiteLLM key returns a response; the tunnel shows as created in Cloudflare; requests to `/xmlrpc.php` are blocked at Cloudflare, and rapid repeated requests to `/wp-login.php` are rate-limited.

### Step 2.4: `wp-infra` CI
**Do:** the pipeline described in `aws-wp.md` ([Terraform pipeline](aws-wp.md#terraform-pipeline-wp-infra)):
- **Pull requests:** `terraform fmt -check` → `validate` → **tflint** with **`tflint-ruleset-aws`** → **Checkov** on the source with **custom policies** in `.checkov/` (required `Project`/`Site`/`Env` tags, `us-east-1` only, approved instance families, S3 Block Public Access) → **`terraform test`** for the modules → `terraform plan -out` (saved as a private workflow artifact with short retention) → **Checkov on the plan** → **IAM Access Analyzer** policy checks (`validate-policy`, and its custom checks for new public or cross-account access) → **Infracost** cost-difference comment → plan comment → gitleaks.
- **After merge:** a GitHub Environment **`apply`** with required reviewers (you), limited to `main`; the OIDC apply role trusts only that environment; the job applies **the saved plan from the pull request**, not a fresh plan.
- **Weekly scheduled** drift-check plan.
- **Repo hygiene:** `.pre-commit-config.yaml` with the **pre-commit-terraform** hooks plus gitleaks; **terraform-docs** generating module READMEs; `.terraform.lock.hcl` with hashes for Linux and your workstation (`terraform providers lock -platform=...`); turn on **GitHub secret scanning with push protection** when the repo goes public.
- Applies to `envs/home` stay **local** for now (the Talos provider needs your home network); they can move to in-cluster runners after step 5.5.

**Test:** a pull request with a harmless change shows passing checks, a plan comment and an Infracost comment; a deliberately insecure change (e.g. a public bucket) fails Checkov; an untagged resource fails the custom tag policy; an invalid instance type fails tflint; after merge, the apply waits for approval in the `apply` environment and applies the saved plan.

### Step 2.5: Disaster recovery copies
**Do:** as described in `docs/disaster-recovery.md` and ADR 0019:
- The **Backup** account already exists (step 2.0).
- `wp-infra/envs/dr/`: in the Backup account, **S3 Object Lock** buckets in **us-west-2** (30-day retention, governance mode at first), versioned and **KMS-encrypted**; **replication** rules (with write-only roles) from the Terraform state bucket (russetleaf-infra) and the MariaDB backup and media buckets (russetleaf-home). (CloudTrail logs are already isolated in the Log Archive account.)
- A **daily repo-mirror** workflow (`git bundle` of each repo) uploading to the backup account through a write-only OIDC role.
- Add the **Talos secrets bundle** and talosconfig (from step 2.2) to the break-glass kit.

**Test:** a new MariaDB backup appears in the backup account within minutes; deleting or overwriting it there **fails** (Object Lock); restoring a MariaDB backup **from the backup account's copy** into a scratch instance works; a repo can be cloned from its latest bundle.

## Phase 3: GitOps foundation (`wp-gitops`)

### Step 3.1: Structure and Argo CD bootstrap
**Do:**
- Create the layout from `aws-wp.md`: `bootstrap/home/`, `apps/`, `platform/`, each component with `base/` and `overlays/home/`.
- Install Argo CD with Helm on the new cluster, then add Argo CD itself to `platform/argocd/` so it manages its own upgrades. Add **`platform/cilium/`** with the **same values** Terraform used, so Argo CD adopts Cilium without changing it. Set the Cilium Application to **manual sync** (a broken networking upgrade would stop Argo CD from syncing a revert), and write `docs/runbooks/rollback-cilium.md`: recover with `helm rollback cilium` from the workstation (the API server runs on the host network, so it stays reachable), then revert in Git. Test the procedure on a local kind or Talos-in-Docker cluster.
- `bootstrap/home/`: the root "app of apps" that creates one Argo CD Application per component, with **sync waves** (Cilium and the `prometheus-operator-crds` chart first, then storage and secrets, then ingress, monitoring, operators, then apps).
- Expose the Argo CD UI only through Cloudflare Access (after step 4.3), or use `kubectl port-forward` until then.
- **Argo CD Notifications** to `#rl-deploys` (sync succeeded, sync failed, app degraded), using the Slack bot token. Until External Secrets exists (step 4.2), create the token Secret by hand; switch it to an `ExternalSecret` afterwards.
- CI: render every component's home overlay (Helm/Kustomize), validate with `kubeconform`, and run **Checkov on the rendered manifests** (what Argo CD would actually apply).

**Test:** apply the root app; Argo CD shows it `Synced`/`Healthy` with a trivial test component; a sync posts to `#rl-deploys`; a pull request that breaks a manifest fails CI.

## Phase 4: Platform services (`wp-gitops/platform/`)

Check `kubectl top nodes` after each step.

### Step 4.1: Storage
**Do:** `platform/storage/`: local-path-provisioner as the default (and only) StorageClass, using `/var/local-path-provisioner`, its namespace labelled for privileged pod security (Talos enforces "baseline" by default). No Ceph (Rook) or Longhorn: the design keeps important state in S3, and the database is replicated by MariaDB itself (step 4.5); see `docs/adr/0010-local-storage-no-ceph.md`.

**Test:** a test PersistentVolumeClaim binds and a pod writes to it; the data survives the pod being deleted.

### Step 4.2: Secrets
**Do:** `platform/external-secrets/`: External Secrets Operator plus a `ClusterSecretStore` for AWS Secrets Manager.
- **Bootstrap credential:** External Secrets needs one AWS key to start. Create it once by hand as a Kubernetes Secret from the Terraform output (document the exact command in the README, never commit it). Everything else comes from Secrets Manager.

**Test:** an `ExternalSecret` for a test value creates a Kubernetes Secret; changing the value in Secrets Manager updates it within the refresh interval.

### Step 4.3: Ingress and the Cloudflare Tunnel
**Do:**
- `platform/ingress/`: ingress-nginx (**2 replicas** spread across box 3 and box 1, with a PodDisruptionBudget), with its **Prometheus metrics enabled** (the Argo Rollouts analysis in step 6.2 uses them).
- `platform/cloudflared/`: cloudflared Deployment (2 replicas, **spread across nodes**) using the tunnel token from External Secrets, routing `russetleaf.dev` and the admin hostnames to ingress-nginx.
- Put the Argo CD, Grafana and **Hubble UI** hostnames behind Cloudflare Access.

**Test:** a hello-world app at `https://russetleaf.dev` loads from outside your network (e.g. on mobile data); your router has no open ports; the Argo CD hostname asks for a Cloudflare Access login.

### Step 4.4: Monitoring
**Do:** `platform/monitoring/`: kube-prometheus-stack (placed on box 3): 15-day retention, 30 s scrape interval, resource limits on every part. Grafana behind Cloudflare Access. Then the alerting setup from `aws-wp.md`:
- Prometheus external labels `site=dev`, `cluster=talos-home`; `serviceMonitorSelectorNilUsesHelmValues: false` (and the PodMonitor and rule equivalents) so Prometheus finds ServiceMonitors in every namespace.
- **Cilium and Hubble metrics:** in `platform/cilium/` values, turn on the agent, operator and Hubble metrics and their **ServiceMonitors**, the Hubble metric set (`dns`, `drop`, `tcp`, `flow`, `port-distribution`, `httpV2` with a small label set), and the Cilium and Hubble **Grafana dashboards** (written to the `monitoring` namespace for Grafana's sidecar). Add the Cilium alert rules (`CiliumAgentNotReady`, `HubblePolicyDropsSpike`, `CiliumEndpointRegenerationFailing`, `HubbleDNSErrors`) with runbooks. Exact values are in `aws-wp.md` ([Hubble and Cilium metrics in Prometheus](aws-wp.md#hubble-and-cilium-metrics-in-prometheus)).
- **Alertmanager → Slack** with the bot token from External Secrets: criticals to `#rl-critical` and `#rl-dev-alerts`; warnings to `#rl-dev-alerts`; `team=security|mlops|cost` alerts to their channels; `env=staging` alerts to `#rl-staging` only; grouping and repeat intervals; **inhibition rules** (site down suppresses its downstream alerts).
- **Dead man's switch:** route the always-firing `Watchdog` alert to the heartbeat service's URL; the heartbeat service alerts `#rl-critical` if pings stop.
- **blackbox_exporter** (in `platform/monitoring/`) with probes for key URLs inside the cluster; start with a test target, then add `/`, `/wp-login.php` and `/wp-json/` once WordPress exists (step 5.2).
- **External uptime check** for `https://russetleaf.dev` (and, once the AWS edge exists, russetleaf.com expecting 200 or the 503 offline page).
- **Alerts as code:** a starter set of `PrometheusRule`s (site down, pod crash-looping, node memory high, disk filling, certificate/tunnel down), each with `severity`, `summary`, `description` and `runbook_url`; a runbook for each in `docs/runbooks/`; `promtool test rules` in `wp-gitops` CI.

**Test:** Grafana shows node and pod dashboards for all three nodes, plus the Cilium and Hubble dashboards with live data; Prometheus' targets page lists the Cilium agent, operator and Hubble endpoints as up; a test critical alert appears in both `#rl-critical` and `#rl-dev-alerts` with a working runbook link; stopping Alertmanager for longer than the heartbeat period makes the heartbeat service post to `#rl-critical`; a broken alert rule fails `promtool` in CI.

### Step 4.5: Database and cache
**Do:**
- `platform/mariadb/`: MariaDB Operator; a `MariaDB` instance pinned to the **same major version RDS offers** (e.g. 11.4 LTS), a `Database`, `User` and `Grant` for WordPress, with the password **generated by the operator** into a Kubernetes Secret (no External Secrets for the database). Same for the backup user and root.
- **Replication:** two MariaDB members with **primary–replica replication** and **automatic failover** (MariaDB Operator's replication mode), the primary preferring box 3 and the replica on box 1 (anti-affinity), a PodDisruptionBudget, and a Service that always points at the current primary. Backups run from the replica where the operator supports it.
- **TLS** turned on in MariaDB (operator- or cert-manager-issued certificates) and **required** for the `wordpress` user.
- The **`Backup`** to the backup bucket **every 6 hours** (logical, gzip, 14-day retention), and an alert (`severity=critical`, with a runbook) if the last successful backup is more than **7 hours** old. Replication covers a node failure; these backups cover disasters (data deleted or corrupted, or the home lab lost), with a recovery point of at most 6 hours.
- `platform/valkey/`: Valkey (single instance, no persistence needed for an object cache), with a **redis_exporter** sidecar and ServiceMonitor.
- **Database and cache metrics:** turn on MariaDB Operator's built-in metrics (mysqld-exporter sidecar and ServiceMonitor), and add alerts with runbooks (database down, connections near the limit, slow queries rising, Valkey memory near its limit).

**Test:** shut down the node running the MariaDB primary: the replica is promoted within about a minute and WordPress (once deployed) keeps working; when the node returns, it rejoins as a replica. Connect with a MariaDB client from a test pod using the generated Secret, and confirm a connection **without TLS is refused**; no database password appears in Git or Secrets Manager; trigger a backup by hand and see the file in S3; **restore it into a scratch MariaDB instance** and compare; `valkey-cli ping` returns `PONG`; MariaDB and Valkey metrics appear in Prometheus and on Grafana dashboards.

### Step 4.6: Logging (Loki + Alloy)
**Do:** `platform/logging/`, as described in `aws-wp.md` ([Logging](aws-wp.md#logging-loki--alloy)):
- **Loki** in single-binary mode, storing data in the Loki S3 bucket (scoped key from External Secrets), a small local cache volume, **7-day retention**, the **ruler** sending alerts to Alertmanager.
- **Kubernetes audit logs:** Alloy also collects the **API server audit log** from box 1 (label `job=kube-audit`), and Loki's ruler gets the audit alerts from `aws-wp.md` (`KubeExecIntoProdPod`, `KubeUnexpectedSecretRead`, `KubeRBACChangedOutsideArgoCD`, `KubeAnonymousOrForbiddenSpike`, `KubeAuditLogMissing`), routed to `#rl-security` with runbooks. Argo CD's service account is the expected source of production changes.
- **Grafana Alloy** DaemonSet: an **OTLP receiver** for traces (forwarding to Tempo once it exists; until then traces are dropped); collect all container logs; labels `site=dev`, `env`, `cluster`, `namespace`, `app`, `container` only; drop debug lines and health-check access logs; mask tokens and passwords in query strings; a host port receiving **Talos system logs**.
- In `wp-infra/envs/home`, point Talos's machine logging at Alloy's host port on each node.
- A narrow Kyverno **`PolicyException`** for Alloy (host paths for log files, the host port).
- Loki as a Grafana data source, with links from dashboards to logs; starter log-based alerts (`LokiIngestionErrors` now; the WordPress, summarizer and Bedrock ones are added in steps 5.2 and 7.5) with runbooks.
- Record memory use in the checklist, and daily log volume and memory after a week in `docs/adr/0005-loki-alloy-for-logs.md`.

**Test:** in Grafana, logs from every namespace and from the Talos nodes (kubelet, etcd) are searchable by `namespace` and `app`; `kubectl exec` into a production pod fires `KubeExecIntoProdPod`, and editing a RoleBinding by hand fires `KubeRBACChangedOutsideArgoCD`; a deleted pod's logs are still there; a secret in a test log line is masked; stopping Loki fires `LokiIngestionErrors` in `#rl-dev-alerts`; objects older than the retention period are removed from the bucket.

## Phase 5: WordPress

### Step 5.1: The WordPress image (`wp-image`)
**Do:**
- `Dockerfile` based on the official `wordpress` image (pinned version), with plugins and themes pinned in **`composer.json` through WPackagist** (so Renovate can update them) and installed with Composer at build time: an S3 media offload plugin (see the comparison below), Redis Object Cache, an SMTP plugin (configured for Amazon SES). WordPress code is copied into `/var/www/html` **at build time**, so the image's startup script has nothing to copy at runtime.
- **WPScan:** run it in CI (free API token stored as a GitHub secret) against the plugins and themes in `composer.json`, failing the build on a known vulnerability, plus a **weekly scheduled run** that alerts `#rl-security`. Also schedule a **weekly rebuild** of the image so base-image OS patches are picked up even without code changes.
- **Choose the S3 offload plugin** (see [Media storage: S3, not EFS](aws-wp.md#media-storage-s3-not-efs-by-decision)). Try both in the Compose setup against LocalStack (or MinIO) and record the choice in the decision log:
  - **S3-Uploads** (Human Made, open source): uploads go **directly to S3**, so no writable uploads directory is needed. Preferred if it works with a custom S3 endpoint (for the ci stand-ins) and with CloudFront as the media URL.
  - **WP Offload Media Lite**: writes locally first, then copies to S3; needs a writable uploads `emptyDir`.
  - Check for both: upload, image resizing (thumbnails), deleting media, and the media URL pointing at the right place (S3 at home, CloudFront on AWS).
- **Finish `docs/adr/0002-s3-media-not-efs.md`** (already drafted): fill in its open item with the plugin chosen and why, and whether the uploads `emptyDir` is needed.
- **Lean final image:** no download tools (`curl`, `wget`) or package managers in the final image where practical (keep what the official image's startup script needs); container-structure-test checks they're absent.
- **Built to pass the Kyverno policies from step 6.1:** Apache runs as **`www-data`** listening on **port 8080** (non-root can't use port 80), and the container works with a **read-only root filesystem** given writable `emptyDir` volumes for `/tmp`, Apache's run and lock directories, PHP sessions, and the uploads directory only if the chosen plugin needs it. Test both in the Compose smoke test.
- `wp-config` settings read from environment variables (database, Valkey, S3, queue URL, `WP_HOME`/`WP_SITEURL`, `DISALLOW_FILE_MODS`, `DISABLE_WP_CRON`), with **TLS to the database** turned on.
- A **`db.php` drop-in** whose behaviour is chosen by the chart setting **`database.auth`**. Build only the **`password`** mode now (reads the password from a Secret, connects over TLS); it's what the home lab uses, and it's the AWS fallback too. Leave a clear extension point for an **`iam`** mode, which is written **only after** the AWS plan's early test (step 1.6) shows that PHP can log in to RDS Proxy with an IAM token. That way no work is wasted if the test fails. Add the **RDS CA certificate bundle** to the image now (harmless at home, needed on AWS).
- The **metrics must-use plugin** (`mu-plugins/metrics/`), as described in `aws-wp.md` ([WordPress monitoring](aws-wp.md#wordpress-monitoring)): `wordpress_posts_without_summary`, `wordpress_cron_overdue_events`, `wordpress_object_cache_hit_ratio`, `wordpress_info`, and simple counts, served on a **separate internal port** (a second Apache listener, e.g. 9117), cached for about a minute. Also turn on Apache's `mod_status`, reachable from localhost only (for the apache_exporter sidecar). Unit-test the output format.
- **OpenTelemetry tracing, built in but off by default:** the OpenTelemetry **PHP extension** and **Composer packages** (SDK, OTLP exporter, and auto-instrumentation for WordPress, database access and HTTP calls; check current package names in the OpenTelemetry PHP contrib project). **No WordPress plugin** is needed; it's switched on by environment variables (`OTEL_PHP_AUTOLOAD_ENABLED`, `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT`, sampler settings) set in the chart values. Include trace IDs in WordPress's log lines.
- **XML-RPC disabled** inside WordPress (a must-use plugin returning `false` from the `xmlrpc_enabled` filter), as well as being blocked at the edge.
- The **summary-queue must-use plugin**: on publish or update, send `{"post_id": ...}` to SQS, adding the current trace context (W3C `traceparent`) as a **message attribute** when tracing is on (AWS SDK for PHP, installed with Composer at build time).
- `tests/`: a smoke test (Docker Compose with MariaDB: the container starts, plugins are active, health check passes).
- `chart/`: the WordPress Helm chart (see step 5.2 for what it deploys), versioned with the image.
- CI, following `aws-wp.md`'s [Image build pipeline](aws-wp.md#image-build-pipeline-wp-image-llm-summarizer): **pull requests:** gitleaks, **hadolint**, **PHP_CodeSniffer with the WordPress Coding Standards** and **PHPStan** (for the must-use plugins and `db.php`), **Semgrep**, `composer audit`, dependency review, **Checkov** (Dockerfile, chart), **zizmor**, `helm lint` / `ct lint`, build, **container-structure-test** (non-root, port 8080, expected files), **Trivy** (vulnerability, secret and misconfiguration scanners; failing on critical vulnerabilities and any secret; `.trivyignore` with reasons and expiry dates); **release:** push the image and chart (OCI) to GHCR **by digest** with an immutable version, sign (cosign keyless), **attach the SBOM as a signed attestation** (`cosign attest`, SPDX JSON), add **SLSA build provenance** (`actions/attest-build-provenance`), **verify** all three on the pushed digest (`cosign verify`, `cosign verify-attestation`, `gh attestation verify`), and write release notes with the digests and **Rekor** log links.

- **Pulling private packages:** GHCR packages start **private** (even in a public repo), so until they're made public (step 11.2), the cluster needs credentials. Create a GitHub token with **`read:packages` only**, store it in Secrets Manager, and sync it with External Secrets into an **image pull secret** for the WordPress namespace (and, from step 7.4, the summarizer's), and into Argo CD's **OCI repository credentials** so it can pull the charts.
- **Watch the private-package storage limit:** GitHub's free plan allows roughly 500 MB for private packages (check current figures), which a few WordPress image versions can exceed. Either **make the GHCR packages public at first push** (they contain no secrets, even while the repos are private; this also removes the need for the pull secret above), or add a **retention step** to the release workflow that deletes old untagged versions and keeps tagged releases. Record the choice in `docs/adr/0004-ghcr-not-ecr.md`.

**Test:** the smoke test passes locally and in CI; `cosign verify` succeeds for the pushed image, and `cosign verify-attestation --type spdxjson` returns its SBOM; `gh attestation verify` confirms its provenance; the release notes link to the Rekor entries (check one with `rekor-cli`); a deliberately vulnerable PHP snippet (e.g. unescaped output) fails PHPCS or Semgrep; a secret written into an image layer fails Trivy; the cluster can pull the image and Argo CD can pull the chart (with credentials if the packages are private); the package's storage use is well under the free limit, or old untagged versions are being deleted; publishing a post in the local Compose setup sends a message to the real SQS queue.

### Step 5.2: WordPress chart and deployment (`wp-gitops/apps/wordpress/`)
**Do:**
- The `wp-image` chart, which sets the pod security context (non-root user, read-only root filesystem, no privilege escalation, dropped capabilities, **seccomp `RuntimeDefault`**, and an optional `runtimeClassName` used in step 6.5), the `emptyDir` volumes above, **readiness and liveness probes**, the required labels (`app.kubernetes.io/name`, `app.kubernetes.io/part-of`, `env`) and **CPU/memory requests with a memory limit (no CPU limit)**, deployed from `wp-gitops` with the home overlay (values only): russetleaf.dev hostname, MariaDB and Valkey hosts, `database.auth: password` pointing at the **MariaDB Operator-generated Secret**, media bucket and queue settings, other credentials from External Secrets, resources, `persistence` off, WP-Cron as a Kubernetes CronJob.
- **Replicas and spreading:** WordPress runs **2–3 replicas** spread across box 3 and box 1 (topology spread or anti-affinity) with a PodDisruptionBudget, so a node failure or a rolling upgrade never takes the site down.
- Remove the old test Application and the `wordpress-test` namespace.
- First-run setup (admin user, plugin settings) done by a one-off `wp-cli` Job or wp-config constants, so a rebuild needs no clicking.

- **Monitoring in the chart:** an **apache_exporter** sidecar; a `ServiceMonitor` for the exporter and the metrics port; `PrometheusRule` alerts with runbooks (`WordPressCronBacklog`, `WordPressObjectCacheHitRatioLow`, `WordPressApacheWorkersSaturated`, `WordPressSyntheticProbeFailing`; `WordPressPostsMissingSummaries` is added in step 7.4), plus the log-based `WordPressPHPFatalErrors` alert in Loki; a CiliumNetworkPolicy rule letting only Prometheus reach the metrics port. Add the WordPress URLs to the blackbox_exporter probes.

**Test:** `https://russetleaf.dev` serves WordPress; an uploaded image lands in the S3 bucket and displays; the Redis Object Cache plugin shows "connected"; killing the WordPress pod loses nothing; WP-Cron jobs run from the CronJob; a password-reset email arrives through SES; Prometheus scrapes the apache_exporter and the custom metrics; the metrics port is **not** reachable through `https://russetleaf.dev` or from a non-Prometheus pod; the blackbox probes are green.

### Step 5.3: Image promotion
**Do:** create the GitHub App; the `wp-image` release workflow opens a pull request on `wp-gitops` that changes only the chart and image version in `apps/wordpress/overlays/home`, linking the release notes. (Step 5.7 later points this at staging first.)

**Test:** merge a trivial change in `wp-image` → a signed image is pushed → a bump pull request appears in `wp-gitops` → merging it rolls out the new image, and the rollout appears in `#rl-deploys`. Subscribe `#rl-deploys` to the four repos' releases and merged pull requests with the GitHub Slack app.

### Step 5.4: ci test clusters (kind + AWS stand-ins)
**Do:**
- `wp-image/ci/`: a kind cluster config and `ci` chart values (LocalStack, or MinIO + ElasticMQ, per step 0.2; a MariaDB and Valkey installed into the kind cluster; test credentials).
- Integration tests (e.g. a shell or Python test script run after `helm install`): the site installs and loads; an upload lands in the stand-in S3 bucket; publishing a post sends a message to the stand-in SQS queue.
- A pull request workflow on **GitHub-hosted** runners: create the kind cluster (`helm/kind-action`), load the freshly built image, install the chart with `ct install` or `helm install`, run the tests, collect logs on failure.
- `compose.yaml` for the **local** environment: WordPress + MariaDB + Valkey + LocalStack, so the same checks can be run by hand.
- In `wp-gitops` CI: install changed **platform** components into a kind cluster to check they start (where they can run without the real cluster's dependencies).

**Test:** a pull request in `wp-image` runs the kind tests and passes; a deliberately broken change (e.g. a wrong S3 setting) fails them; `docker compose up` gives a working local site.

### Step 5.5: Self-hosted runners (ARC)
**Do:** `platform/actions-runner-controller/`: ARC with **ephemeral** runners, tolerating box 2's taint so they run next to the model, off the main nodes. Start with a runner scale set for **`wp-gitops`** (used by the staging workflow); `llm-summarizer` gets its own in step 9.2. Before any repo goes public: require approval for workflows from fork pull requests, and limit which workflows can use the self-hosted label.

**Test:** a test workflow in `wp-gitops` runs on a self-hosted runner pod, which is deleted afterwards; a fork pull request waits for approval.

### Step 5.6: On-demand staging
**Do:**
- `overlays/home-staging` for WordPress (1 replica, `staging.russetleaf.dev`, no Valkey), a small staging **MariaDB** (MariaDB Operator, with its own generated passwords), and the staging AWS resources and secrets from step 2.3. Label everything `env=staging`.
- Staging Argo CD Applications in their own **Argo CD project**, with **auto-sync off**, so nothing runs until a test starts.
- `apps/staging-data/`: a Job that downloads the latest russetleaf.dev production backup from S3, imports it into the staging MariaDB, and **scrubs personal data** (user emails replaced with `user<ID>@example.invalid`, commenter names/emails/IPs cleared, application passwords and sessions deleted), then runs `wp search-replace 'russetleaf.dev' 'staging.russetleaf.dev'`.
- `apps/smoke-tests/`: a Job that checks the home page and sample posts load, an upload goes to the staging bucket, and a published post gets a summary (once Phase 7 exists; skip that check until then).
- An Argo CD account with RBAC limited to the staging project (sync and delete only); its token in Secrets Manager.
- The **`staging-test`** workflow (on the ARC runners): sync staging → wait for healthy → run `staging-data` → run `smoke-tests` → soak ~30 minutes checking Prometheus for errors and restarts → record results → **delete** the staging Applications with cascade (volumes included) → post results to `#rl-staging`.

**Test:** run `staging-test` by hand: staging comes up at `staging.russetleaf.dev` (behind Cloudflare Access), shows production posts with **no real email addresses** in the database, passes the smoke tests, and is fully removed afterwards (`kubectl get all,pvc -n <staging namespaces>` is empty). Record the nodes' peak memory during the run in the checklist.

### Step 5.7: Promotion pipeline (staging → prod)
**Do:**
- Change the `wp-image` release bot (step 5.3) to bump **`overlays/home-staging`** instead of prod, with **auto-merge** once `wp-gitops` CI passes.
- Trigger `staging-test` on pushes to `main` that change a staging version.
- **Schema changes:** CI in `wp-image` compares WordPress's database version (`$wp_db_version`) between the old and new images (and plugin release notes flag schema changes), labelling such releases **`schema-change`**. For those, the promotion workflow runs an **on-demand MariaDB backup** and waits for it to succeed before the prod pull request can be merged; the rollback runbook explains restore-and-roll-back versus fix-forward.
- On a pass, a **`promote-to-prod`** job opens a pull request bumping the same version in `overlays/home` (and `overlays/aws` once it exists), with the staging results attached. On a failure, post to `#rl-staging` and `#rl-deploys` and promote nothing.

**Test:** a release that changes `$wp_db_version` is labelled `schema-change` and its prod pull request is blocked until the pre-release backup succeeds; release a trivial `wp-image` change → it auto-merges to staging → `staging-test` passes → a promotion pull request appears with results → merging it rolls out to russetleaf.dev. Release a deliberately broken version → staging fails → no promotion pull request, and `#rl-staging` shows why.

### Step 5.8: Google sign-in for admins
**Do:** as described in `aws-wp.md` ([Admin sign-in with Google](aws-wp.md#admin-sign-in-with-google)):
- **Google Cloud:** a project with an OAuth consent screen (basic scopes only: `openid`, `email`, `profile`), and OAuth clients for **russetleaf.dev** (with staging.russetleaf.dev as a second redirect URL) and **local testing**. Document them in `wp-infra`'s README; store the client secrets in Secrets Manager.
- **`wp-image`:** add an OIDC client plugin (e.g. "OpenID Connect Generic Client"; check it's maintained and can be configured entirely from constants or environment variables) to `composer.json` (WPackagist). Configure it from chart values: Google's endpoints, client ID and secret (External Secrets), the **allow-list** of email addresses, and automatic account linking for allowed emails only.
- **Turn off password logins for people**, while keeping **application passwords** for the REST API (the summarizer and the staging smoke tests depend on them).
- **Edge layer:** a Cloudflare Access application covering `/wp-admin/*` and `/wp-login.php` on russetleaf.dev and staging, using Google.
- **CiliumNetworkPolicy:** allow WordPress → Google's login endpoints by DNS name.
- **ci:** a mock OIDC provider (e.g. Dex) in the kind cluster, with a test that signs in through it.
- **Break-glass:** a documented `wp-cli` procedure (a one-off Job) to recover admin access without re-enabling passwords; add it to `docs/runbooks/`.
- Finish `docs/adr/0008-google-sign-in-for-admins.md` with the plugin chosen.

**Test:** visiting `/wp-admin` from outside first requires a Cloudflare Access Google login; an allowed Google account then signs in to WordPress with no password; a Google account not on the allow-list is refused; a username/password login attempt is rejected; the summarizer still saves summaries through the REST API with its application password; the ci sign-in test passes; the break-glass procedure works in staging.

## Phase 6: Policy and progressive delivery

### Step 6.1: Kyverno
**Do:** `platform/kyverno/`: Kyverno plus the policy set from `aws-wp.md` ([Supply chain and policy](aws-wp.md#supply-chain-and-policy)), all in **audit mode** first:
- **Signed images** (`verifyImages`): images signed by the `wp-image` and `llm-summarizer` release workflows (cosign keyless, GitHub OIDC issuer, subject matching each repo's workflow), with **`mutateDigest`** so tags are pinned to digests at admission
- **SBOM attestations:** the project's own images must also carry a signed SBOM attestation from the same workflow
- **Build provenance:** they must also carry the **SLSA provenance** attestation from GitHub's attestation action, issued to the same release workflow (confirm Kyverno's support for GitHub attestation bundles; start in audit mode)
- **Signed upstream images:** for each third-party publisher that signs its images with cosign (check Kyverno, Cilium and the others in the stack; record which do in the decision log), verify the signature against **that publisher's** release identity. Start each in audit mode. **Exclude Kyverno's own namespace** from image verification so Kyverno can always start.
- **Restrict Image Registries:** `ghcr.io/<you>/*` plus an explicit list of the upstream registries the platform charts use (include init and ephemeral containers)
- **Disallow Latest Tag**
- **Require Labels** (`app.kubernetes.io/name`, `app.kubernetes.io/part-of`, `env`), plus a **mutate** rule that adds `env` from the namespace
- **Require Requests and Limits:** CPU and memory requests and a memory limit; **no CPU limit required**
- **Pod Security Standards `baseline`** (includes Disallow Privileged Containers, host paths and host namespaces)
- **Restrict Seccomp (Strict):** every container must use `seccompProfile: RuntimeDefault` (exceptions only for third-party components that genuinely need another profile)
- **Require Run As Non-Root**
- **Require Read-Only Root Filesystem**
- **Require Pod Probes** (readiness and liveness on long-running workloads)
- **Disallow NodePort**, plus blocking `LoadBalancer` Services
- **Unique Ingress Host and Path**
- **Webhook exclusions and recovery:** Kyverno's webhooks exclude `kube-system`, `kyverno` and `argocd`, so Argo CD and Kyverno itself can always be repaired; write `docs/runbooks/rollback-kyverno.md` (revert in Git; in an emergency, delete Kyverno's webhook configurations so deployments go through, and let Kyverno recreate them once healthy).
- **`PolicyException`s**, each naming the exact namespace and workload, only where needed: Cilium, Falco, local-path-provisioner (privileged/host access); upstream images that can't run read-only or as non-root (e.g. some operators or llama.cpp's image, if so). The project's own workloads get **no** exceptions.
- Policy tests with `kyverno test` (a passing and a failing example per policy), run in `wp-gitops` CI.

- **Policy Reporter** (Kyverno's reporting add-on) sending new policy violations to `#rl-security`.

Review the policy reports, fix violations, then switch to **enforce**.

**Test:** in enforce mode, each of these is rejected: an unsigned image, a project image that's signed but has **no SBOM attestation** or **no provenance attestation**, an image from a verified upstream registry that **isn't signed by that publisher** (e.g. a different project's image under the same registry), an image from an unlisted registry, a `:latest` image, a pod without the required labels (where the mutate rule can't fill them), a container without a memory limit, a privileged pod, a root container, a writable root filesystem, a Deployment without probes, a NodePort Service, and an Ingress reusing an existing host and path. Running pods show image digests rather than tags. The existing workloads keep running; Policy Reporter shows no unexplained violations; a pull request that violates a policy fails CI.

### Step 6.2: Argo Rollouts
**Do:** `platform/argo-rollouts/`; convert WordPress to a `Rollout` with canary steps (e.g. 20% → 50% → 100%) and an `AnalysisTemplate` that queries Prometheus (ingress-nginx error rate and latency for the WordPress service). Argo Rollouts notifications post canary steps, aborts and rollbacks to `#rl-deploys`.

**Test:** a good image rolls out step by step; a deliberately broken image (e.g. one that returns 500s) is **rolled back automatically**, and the rollback is announced in `#rl-deploys`.

### Step 6.3: CiliumNetworkPolicies
**Do:** use **CiliumNetworkPolicies**, not plain NetworkPolicies (see [Policies](aws-wp.md#policies-ciliumnetworkpolicies-not-plain-networkpolicies) in `aws-wp.md`):
- A **`CiliumClusterwideNetworkPolicy`** baseline: default-deny for application namespaces, DNS to CoreDNS allowed with Cilium's **DNS proxy** on (needed for DNS-name rules), Prometheus scraping allowed.
- Per-component **CiliumNetworkPolicies** in each component's `base/` (shared with the AWS site), with site-specific destinations in the overlays. Outbound traffic to AWS is allowed **by DNS name** (`toFQDNs`): WordPress → S3, SQS, SES and STS endpoints; summarizer → SQS, the gateway and WordPress's REST API (a **layer-7** rule: `GET`/`POST` on `/wp-json/*` only); gateway → llama.cpp and `bedrock-runtime`; llama.cpp's init container → the model mirror bucket only; MariaDB → S3 for backups; cloudflared → Cloudflare's tunnel endpoints.
- A **Kyverno generate rule** that gives every new application namespace the baseline allowances, so none is ever left open.
- CI: validate the policies against the Cilium CRD schemas, and exercise them in the ci kind cluster (install Cilium there too).
- Roll out one namespace at a time, watching `hubble observe --verdict DROPPED` for anything legitimate being blocked.

**Test:** from a test pod in another namespace, MariaDB is unreachable; from a WordPress pod, `curl https://example.com` is **blocked** while uploads to S3 still work; a non-REST-API request from the summarizer to WordPress is blocked at layer 7; a burst of blocked requests triggers `HubblePolicyDropsSpike` in `#rl-security`; the site, the summarizer, backups and monitoring all still work.

### Step 6.4: Service mesh decision (ADR) and optional Istio experiment
**Do:**
- Finish `docs/adr/0001-no-service-mesh.md` (already drafted; review it and resolve its open items as they're done): what a mesh like Istio would add, how Cilium (WireGuard, layer-7 policies, Hubble), Argo Rollouts and LiteLLM already cover it, the memory and complexity cost on a small cluster, and **when you'd revisit** (many more services, a requirement to verify service identity on every connection, multi-cluster traffic). See [Service mesh (Istio): not used, by decision](aws-wp.md#service-mesh-istio-not-used-by-decision).
- **Optional experiment (local only):** in a kind cluster on your workstation running Cilium, install **Istio ambient mode** (following Istio's instructions for running alongside Cilium), deploy the WordPress chart with test values, and enable mTLS and one layer-7 authorization policy. Record memory use, setup issues and what it added in the ADR. Delete the cluster afterwards; nothing in either site depends on it.

**Test:** the ADR is reviewed and linked from the hub README and the decision log; if the experiment was run, its findings are in the ADR.

### Step 6.5: Sandboxed runtime (gVisor)
**Do:** as described in `aws-wp.md` ([Sandboxed runtimes](aws-wp.md#sandboxed-runtimes-gvisor)):
- Confirm the gVisor extension is active on all three nodes (step 2.2), and add `platform/runtime-classes/` with a **`gvisor` RuntimeClass**.
- **ARC runners:** set `runtimeClassName: gvisor` on the runner pods, and add a Kyverno rule requiring it in the runners' namespace. Run every workflow that uses the runners (evaluation gate, staging test) and fix anything that doesn't work under gVisor.
- **WordPress trial:** load-test russetleaf.dev's WordPress in **staging** with `k6` (home page, a post, the REST API) with and without `runtimeClassName: gvisor`. Keep gVisor for WordPress only if response times and error rates stay within an agreed margin (e.g. 95th-percentile latency no more than 20% worse); record the numbers and decision in `docs/adr/0009-gvisor-sandboxing.md`.
- Note for step 10.1: Falco needs its **gVisor event source** turned on for sandboxed pods.

**Test:** a runner pod shows `runtimeClassName: gvisor` and the evaluation and staging workflows pass on it; a runner pod without the RuntimeClass is rejected by Kyverno; `dmesg` inside a gVisor pod shows gVisor's own kernel messages rather than the host's; the WordPress load-test results and decision are recorded in the ADR.

## Phase 7: AI post summaries

### Step 7.1: KEDA
**Do:** `platform/keda/`: KEDA, with AWS credentials for the SQS scaler from External Secrets.

**Test:** a test `ScaledObject` scales a dummy Deployment from 0 to 1 when a message is sent to a test queue, and back to 0 when the queue is empty.

### Step 7.2: LiteLLM gateway
**Do:** `platform/llm-gateway/`: LiteLLM (with its OpenTelemetry tracing configured but pointed at Alloy only when tracing is on, and message-content capture **off**) with Claude Haiku (default) and Amazon Nova Lite on Bedrock, using the scoped Bedrock key; per-app budgets and rate limits (a separate key and small budget for staging); metrics exposed to Prometheus; an internal API key for callers.

**Test:** from a test pod, an OpenAI-style chat request to the gateway returns answers from both models; requests over the rate limit are refused; the gateway's metrics appear in Prometheus.

### Step 7.3: Summarizer code (`llm-summarizer`)
**Do:**
- A dedicated WordPress user for the summarizer (role: editor or a custom role that can edit posts only), with an **application password** created by `wp-cli` and stored in Secrets Manager.
- `src/`: SQS consumer (long polling, delete only after success, retries then dead-letter queue), WordPress adapter (REST API with that application password, calling WordPress's in-cluster Service rather than going out through Cloudflare: read the post, write the summary to the excerpt or a custom field), OpenAI-compatible model client pointed at the gateway, prompt loading from `prompts/` with the version recorded alongside each summary.
- **OpenTelemetry tracing** with the Python SDK (auto-instrumentation for boto3 and HTTP clients), built in and off unless an OTLP endpoint is configured: read `traceparent` from each SQS message and continue the trace; spans for reading the post, calling the gateway and saving the summary; metadata attributes only (model, prompt version, tokens), **never post text, prompts or summaries**; trace IDs in log lines.
- Unit tests (adapter and consumer with mocks, including trace-context extraction).
- `demo/`: Docker Compose with sample posts and a small mock WordPress endpoint, calling Bedrock through a local LiteLLM, so anyone can run it without Kubernetes.

**Test:** unit tests pass; `docker compose up` in `demo/` produces summaries for the sample posts.

### Step 7.4: Summarizer chart, release and deployment
**Do:**
- `chart/`: Deployment (Rollout later), KEDA `ScaledObject` on the SQS queue (0–N), daily sweep CronJob, ServiceAccount, resources.
- **Code and image checks** (as for `wp-image`, see step 5.1): **ruff**, **mypy**, **Semgrep**, **pip-audit**, dependency review, hadolint, Checkov, zizmor, `helm lint` / `ct lint`, container-structure-test, Trivy (vulnerability, secret and misconfiguration scanners).
- `ci/`: kind end-to-end tests on GitHub-hosted runners, with the AWS stand-ins (SQS) and a **mock LLM** (LiteLLM with mock responses): a queued post gets a summary written back to a test WordPress; a failing message reaches the dead-letter queue.
- **Checkov on the summarizer's Dockerfile and chart** in pull request CI.
- Release workflow: build, SBOM, scan, push by digest, sign, attach the SBOM as a signed attestation, add **SLSA build provenance**, verify all three, write release notes with digests and Rekor links, push the image and the chart (OCI) to GHCR, open a chart-bump pull request on `wp-gitops` for **`overlays/home-staging`** (promoted to prod by the step 5.7 pipeline).
- `wp-gitops/apps/post-summarizer/overlays/home` and `overlays/home-staging`: queue URL, gateway URL (staging uses its own LiteLLM key and budget), WordPress URL, credentials from External Secrets.
- Turn on the summarizer check in the staging smoke tests (step 5.6).
- A **re-summarize job** (a CLI in `llm-summarizer`, run as a Kubernetes Job): find posts whose stored summary metadata matches a given prompt version or model, and re-queue them through SQS so they're summarized again with the current version. Document it in `docs/runbooks/rollback-models.md`.

Then turn on the **`WordPressPostsMissingSummaries`** alert (from the custom metrics plugin), routed to `#rl-mlops`.

**Test (end to end):** the kind tests pass in CI; a release goes through staging and is promoted; then publish a post on russetleaf.dev → a summarizer pod starts → the summary appears on the post within a few minutes → the pod scales back to zero. A message that always fails ends up in the dead-letter queue.

### Step 7.5: LLM monitoring
**Do:** OpenTelemetry metrics in the summarizer (tokens, latency, errors, fallbacks, estimated cost, all labelled by model and prompt version); the Grafana LLM dashboard and `PrometheusRule` alerts shipped **in the summarizer chart** (error spike, dead-letter queue not empty, daily Bedrock spend over a limit, all labelled `team=mlops` so they go to `#rl-mlops`, with runbooks), plus the log-based `SummarizerExceptions` and `BedrockThrottling` alerts in Loki; SQS queue depth in Grafana.

**Test:** the dashboard shows real numbers after a few posts; temporarily lowering the spend limit makes the alert appear in `#rl-mlops`.

## Phase 8: Self-hosted model (box 2)

### Step 8.1: llama.cpp model server
**Do:** `platform/llm-serving/`: llama.cpp server (CPU build) with a toleration and node selector for box 2; an init container that downloads a 4-bit **3B model** (e.g. Qwen2.5-3B or Llama 3.2 3B) into a local-path volume (mirror the file in S3 so rebuilds don't depend on Hugging Face); metrics enabled; memory limits leaving ~1 GB free on the node, and a **CPU limit leaving about one core free**, because box 2 is also an etcd member (watch etcd's latency metrics while summaries run).

**Test:** the pod runs **only** on box 2; an OpenAI-style request returns a summary; record the time per summary and memory use in the decision log.

### Step 8.2: Gateway routing to the local model
**Do:** add the local model to LiteLLM: fallback (Bedrock first, local if Bedrock fails), and a canary split (e.g. 10% of summary requests to the local model); llama.cpp metrics and model-down alert in Grafana.

**Test:** with Bedrock blocked (e.g. a wrong model ID in a test config), requests fall back to the local model; with the split on, about 10% of summaries show the local model's name in the metrics.

## Phase 9: MLOps pipeline

### Step 9.1: Evaluation set and scorers
**Do** (`llm-summarizer/evals/`): 20–30 sample posts with reference notes; rule-based checks (length, required keywords, no made-up links); an LLM-as-judge prompt for faithfulness; a script that runs the set against each model through a gateway URL and writes a report (JSON + Markdown).

**Test:** running the script locally against the gateway (via `kubectl port-forward`) produces a report comparing Haiku, Nova Lite and the local model.

### Step 9.2: Runners for `llm-summarizer`
**Do:** add a second ARC runner scale set (step 5.5) registered to **`llm-summarizer`**, on box 2 next to the model, with the same protections (approval for fork pull requests, self-hosted label limited to the evaluation workflows).

**Test:** a test workflow runs on a self-hosted runner pod, which is deleted afterwards; a fork pull request waits for approval.

### Step 9.3: Evaluation gate and releases
**Do:**
- Pull request workflow (on ARC runners): run the evaluation, post per-model scores as a pull request comment compared with `main`, fail below the threshold.
- Release workflow: run the gate again, then publish (step 7.4, into staging first), attach the report to the GitHub release, update `MODEL_CARD.md`.
- Post gate results (pass/fail, per-model scores, link to the report) to `#rl-mlops`.
- Optionally convert the summarizer to an Argo Rollouts canary.

**Test:** a pull request with a deliberately bad prompt fails the gate with a clear comment; a good one passes; a release tag publishes only after the gate passes.

### Step 9.4: Experiment tracking and model registry (MLflow)
**Do:** `platform/mlflow/` (placed on box 3): the MLflow tracking server with MariaDB for metadata and an S3 artifact bucket (`s3-mlops` module in `wp-infra`, scoped access through External Secrets), behind Cloudflare Access. Change the evaluation gate (step 9.3) to log every run to MLflow (Git commit, prompt version, model, dataset version, scores, latency, cost). Register `summarizer-config` and `local-summarizer` (the current 3B model file) with `champion` aliases, feed the model mirror bucket from the registry, and make routing changes in `wp-gitops` reference registry versions. See `aws-wp.md`'s [MLOps lifecycle](aws-wp.md#mlops-lifecycle).

**Test:** an evaluation run appears in MLflow with its parameters, metrics and report; the registry shows both models with lineage to their runs; the gateway's routing points at a registered version.

### Step 9.5: Guardrails
**Do:** in `llm-summarizer/guardrails/`: delimit post text as content (never instructions), redact email addresses, phone numbers and similar patterns before calls leave the cluster, and validate output (length, plain text, no URLs, no instructions or system-prompt text; retry once, then don't save and alert). Add **adversarial cases** (posts containing injection attempts and personal data) to the evaluation set, and guardrail metrics (blocked, retried, redacted) with an alert on spikes to `#rl-mlops`.

**Test:** a post containing "ignore your instructions and…" produces a normal summary; a post with an email address never sends it to Bedrock (checked in traces or gateway logs); an invalid output isn't saved and alerts; the CI gate fails if an adversarial case gets through.

### Step 9.6: Online evaluation and drift monitoring
**Do:** `platform/argo-workflows/` (Argo Workflows), and a **daily workflow** from `llm-summarizer/online-eval/` that samples a few percent of the day's summaries, scores them with the CI gate's rules and judge, checks input drift (length, language, topics) against the evaluation set, and logs to MLflow and Prometheus. Grafana panels for quality and drift per model and prompt version; `SummaryQualityDegraded` and `InputDriftDetected` alerts to `#rl-mlops`, with runbooks.

**Test:** the workflow runs daily and its results appear in MLflow and Grafana; temporarily switching routing to a deliberately weak prompt lowers the scores and fires `SummaryQualityDegraded`.

### Step 9.7: Feedback loop and data versioning
**Do:** a `summary-feedback` must-use plugin in `wp-image` (editor-only "helpful / not helpful" plus a note on each summary, stored as post metadata); **DVC** in `llm-summarizer` with an S3 remote, tracking the evaluation set, adversarial cases and training data; a nightly workflow exporting new ratings (with each summary's model and prompt version) into the DVC-tracked dataset; MLflow runs record the dataset version.

**Test:** rating a summary in the admin shows up in the next nightly export; `dvc pull` reproduces any past dataset version; an MLflow run's dataset version checks out the exact data it used.

### Step 9.8: Deploy a fine-tuned challenger
**Do:** after AWS plan step 4.5 has produced a registered fine-tuned `local-summarizer` version that beats the base model, deploy it to box 2 as the **challenger**: llama.cpp loads it from the model mirror bucket (fed from the registry), the gateway sends it a canary share of summaries, and online evaluation compares it with the champion. Promote it (MLflow alias plus a `wp-gitops` routing pull request) only if it holds up for a week; update `MODEL_CARD.md`.

**Test:** the challenger serves its canary share; online evaluation shows champion-versus-challenger scores side by side; promotion or rejection is recorded in MLflow, the model card and the decision log.

## Phase 10: Runtime security, compliance and cost

### Step 10.1: Falco
**Do:** `platform/falco/`: Falco with the **modern eBPF** driver (Talos doesn't allow kernel modules) and its **gVisor event source** for pods running under gVisor (step 6.5), Falcosidekick to Alertmanager, Grafana and Slack (`#rl-security`, warning priority and above), and custom rules: shell in WordPress, summarizer or gateway pods; writes under `/var/www/html`; unexpected outbound connections from box 2; and **process allow-lists** per workload (WordPress: `apache2`, `php`; summarizer and gateway: `python`; llama.cpp: `llama-server`), alerting on any other process (see `aws-wp.md`'s [Process allow-listing](aws-wp.md#process-allow-listing) and `docs/adr/0016-process-allow-listing.md`).
- **Falco's own health:** Falco and Falcosidekick metrics with ServiceMonitors, and the alerts `FalcoNotRunning` (fewer ready Falco pods than nodes for 10 minutes; to `#rl-security` and `#rl-critical`), `FalcosidekickOutputErrors` and `FalcoEventsDropped` (to `#rl-security`), each with a runbook.

**Test:** starting an unlisted process in each workload (e.g. `kubectl exec <pod> -- curl --version`, or `sleep` where a shell exists) raises a process allow-list alert in `#rl-security`, while normal traffic raises none; `kubectl exec` into a WordPress pod triggers an alert in Grafana and `#rl-security` (and the same in a gVisor runner pod, through the gVisor event source); creating a file under `/var/www/html` triggers another; deleting the Falco pod on one node (or temporarily preventing it from scheduling there) fires `FalcoNotRunning` in `#rl-security` and `#rl-critical`; pointing Falcosidekick at a wrong Slack destination fires `FalcosidekickOutputErrors`.

### Step 10.2: Trivy Operator, Kubescape scan and Talos hardening notes
**Do:** `platform/trivy-operator/` with modest scan concurrency (scans are memory hungry; keep them off box 2), with its **CIS compliance results published as Prometheus metrics** (turn on the operator's cluster-compliance metrics; check the exact setting for your version) and a ServiceMonitor; a **Grafana "Compliance" dashboard** (built to show both clusters once EKS exists) and a `ComplianceFailuresIncreased` alert to `#rl-security`; write `docs/talos-hardening.md` explaining how Talos meets the CIS benchmark (no shell or SSH, read-only system, API-only management, default pod security), including **API server authorization**: only the **Node** and **RBAC** authorizers (no ABAC, no `AlwaysAllow`), checked with `talosctl -n <control-plane-ip> read /system/config/kubernetes/kube-apiserver/authorization-config.yaml`, and the kubelet's anonymous access off with webhook authorization, checked on **each node** with `talosctl -n <node-ip> read /etc/kubernetes/kubelet.yaml` (must show `authentication.anonymous.enabled: false` and `authorization.mode: Webhook`) and an anonymous request, `curl -sk -o /dev/null -w '%{http_code}' https://<node-ip>:10250/pods` (must return `401`). Add a note in `wp-infra/envs/home` that the machine config must never override the authorization config. Run the first **Kubescape CLI** scan of the home cluster from the workstation (NSA-CISA and MITRE ATT&CK frameworks, plus RBAC analysis; nothing installed in the cluster), save the report and a short summary of accepted findings in `docs/security/`, and fill in the baseline in `docs/adr/0003-kubescape-cli-not-operator.md`.

**Test:** vulnerability and compliance reports exist for the running workloads; compliance metrics appear in Prometheus and on the Compliance dashboard, and temporarily adding a non-compliant workload raises the failing-controls count and fires the alert; the hardening doc is reviewed, and the `talosctl read` check shows only `Node` and `RBAC`; on **all three nodes**, the kubelet config shows anonymous access off and webhook authorization, and the anonymous `curl` to port 10250 returns `401`; the Kubescape report is committed, and any high-risk RBAC findings (e.g. a service account that can read all Secrets cluster-wide) are fixed or explained.

### Step 10.3: OpenCost
**Do:** `platform/opencost/` using the existing Prometheus, with custom prices for the home hardware (electricity per node) and the Bedrock spend shown alongside. Then, as in `aws-wp.md` ([Cost monitoring and alerts](aws-wp.md#cost-monitoring-and-alerts)):
- `PrometheusRule` cost alerts from OpenCost's metrics, labelled `team=cost` (to `#rl-costs`), with runbooks: `NamespaceDailyCostSpike` now, and `GPUNodeRunningLong` in the AWS overlay later.
- A **weekly summary** workflow (scheduled GitHub Actions on the in-cluster runners) that queries OpenCost's API for the last 7 days, grouped by namespace, and posts the top items to `#rl-costs`.
- Record the decisions in `docs/adr/0013-opencost-and-aws-billing.md`.

**Test:** OpenCost shows cost per namespace, with box 2 attributed to the LLM namespace; the weekly summary appears in `#rl-costs` (run it by hand once); temporarily lowering the spike threshold fires `NamespaceDailyCostSpike` in `#rl-costs`; Cost Explorer can filter by the activated `Site` tag.


### Step 10.4: Tracing with Tempo (always on)
**Do:** `platform/tracing/`: **Grafana Tempo** in single-binary mode, storing traces in the Tempo bucket (scoped key from External Secrets), **3-day retention**; Tempo as a Grafana data source with links to Loki (trace ID in log lines) and exemplars on latency graphs. Point Alloy's OTLP receiver at Tempo, and turn tracing on in the WordPress, summarizer and gateway values: parent-based sampling of ~10% for page requests, 100% for summary jobs. Tempo runs **always on**, placed on box 3. See `aws-wp.md` ([Tracing](aws-wp.md#tracing-tempo--opentelemetry)). Record memory use and the sampling rates in `docs/adr/0006-tempo-tracing.md`.

**Test:** publishing a post produces **one trace** in Grafana covering WordPress → the queue message → the summarizer → the gateway → the model call → saving the summary, showing which model answered; a slow page's trace shows its database queries; clicking a trace opens its logs in Loki; no span contains post text, prompts or summaries; with tracing off, nothing is sent and there's no measurable overhead.

### Step 10.5: AWS account posture (Prowler)
**Do:** a GitHub Actions workflow in `wp-infra`, **scheduled monthly** and runnable by hand, that assumes the read-only **audit role** (step 2.1) through GitHub OIDC and runs **Prowler** against **every account** in turn (assuming the audit role in each), with CIS AWS Foundations and AWS Foundational Security Best Practices, as a free **second opinion** to Security Hub's continuous checks (step 2.0b). Keep the full report as a workflow artifact, commit a summary to `wp-gitops/docs/security/` (failed checks by severity, plus accepted findings with reasons), and post the counts of failed high and critical checks to `#rl-security`. Fix what's worth fixing in Terraform (not by hand). Record the first run's baseline in `docs/adr/0007-prowler-not-threatmapper.md`. See `aws-wp.md` ([Runtime security and compliance](aws-wp.md#runtime-security-and-compliance)).

**Test:** the workflow runs without stored AWS keys; a deliberately weakened setting (e.g. turning off S3 Block Public Access on a test bucket) shows up as a failed check, then passes once reverted; the summary and Slack message appear.

### Step 10.6: Version-age report
**Do:** a monthly scheduled GitHub Actions workflow in `wp-gitops` that reads the versions actually running (Talos and Kubernetes from the cluster, MariaDB, Valkey and the major platform charts from `wp-gitops`, and EKS and RDS versions from `wp-infra`), compares them with their **end-of-life dates** (e.g. the endoflife.date API), and posts anything within **90 days of end of support** to `#rl-deploys`. Link it from ADR 0011.

**Test:** the workflow runs on schedule and by hand; temporarily lowering the threshold makes it report something; the message lists each component, its version and its end-of-support date.

### Step 10.7 (optional): Custom seccomp profiles
**Do:** install the **Security Profiles Operator** temporarily, record the system calls WordPress and the summarizer actually make during a full test run (page loads, uploads, the REST API, a summary job), and turn the recordings into **custom seccomp profiles** referenced by each chart's values (`seccompProfile: Localhost`). Keep the profiles in Git, apply them in staging first, and update Kyverno's seccomp rule to allow these named profiles. Record the outcome in `docs/adr/0016-process-allow-listing.md`.

**Test:** both workloads pass the staging smoke tests with their custom profiles; a system call outside the profile (e.g. from a test binary) is blocked; a failed run after an image update is caught in staging, not production.

### Step 10.8: Rollback runbooks and drills
**Do:** write `docs/runbooks/rollback-<layer>.md` for each layer in `aws-wp.md`'s [Rollback strategy](aws-wp.md#rollback-strategy) (applications, platform, configuration, models, Terraform, Talos, Kubernetes, secrets, data; Cilium and Kyverno already exist), then run the first **drills**:
- in staging: roll back a release with a Git revert, abort a canary, and restore a MariaDB backup
- locally: a `talosctl rollback` on a Talos-in-Docker cluster, and the Cilium and Kyverno recovery paths in a kind cluster
- a secret rollback to `AWSPREVIOUS`, and a re-summarize run for one prompt version

Record each drill's time in the decision log and compare it with the expected times.

**Test:** every runbook has been followed at least once in a drill; each rollback restored a working state within its expected time (or the runbook was corrected).

### Step 10.9: CrowdSec
**Do:** install **CrowdSec** reading ingress-nginx's logs, with its **Cloudflare bouncer** so abusive IP addresses (repeated login failures, scanners) are blocked at Cloudflare's edge; alerts and decisions to `#rl-security`. Record memory use.

**Test:** a simulated brute-force from a test address (in staging) gets that address banned at Cloudflare, and the ban expires as configured; normal visitors aren't affected.

### Step 10.10: First full disaster drill
**Do:** simulate "the home lab is destroyed": using **only** the break-glass kit, the GitHub repos (or their mirrors) and the backups in the backup account, rebuild russetleaf.dev on a local Talos-in-Docker cluster (or on the real boxes during a maintenance window), following the bootstrap order in `docs/disaster-recovery.md`. Time each step, and fix the plan wherever it was wrong or incomplete.

**Test:** russetleaf.dev's content (posts, summaries, media) is fully restored from the off-account copies; the total time is recorded in `docs/disaster-recovery.md` and ADR 0019.

## Phase 12: Staff-level practices

(Placed before Phase 11 in this document because Phase 11's final documentation step should come last.) These steps are the **Staff** tier; see `aws-wp.md`'s [Staff-level practices](aws-wp.md#staff-level-practices). Do them after Core and most Differentiators.

### Step 12.1: SLOs and error budgets
**Do:** SLO definitions in `wp-gitops/docs/slos/` and `platform/sloth/` (site availability and latency, summary freshness and quality, home Kubernetes API); **Sloth** generating recording rules and multi-window, multi-burn-rate alerts (fast burn to `#rl-critical`, slow burn to the site channel); Grafana SLO dashboards; retire the threshold alerts they replace. Write the **error-budget policy** and enforce it: `promote-to-prod` (step 5.7) checks the remaining budgets and blocks promotions, except changes labelled `fix` or `reliability`, when a budget is exhausted. See `docs/adr/0023-slos-and-error-budgets.md`.

**Test:** the SLO dashboards show real budgets; injecting errors in staging (or lowering a target temporarily) burns the budget, fires the burn-rate alert, and blocks a normal promotion while a `fix` promotion still goes through.

### Step 12.2: DORA metrics
**Do:** a scheduled workflow that computes **deployment frequency**, **lead time for changes**, **change failure rate** and **time to restore** from GitHub (pull requests, releases), Argo CD (syncs) and the rollback and incident records, publishes them to Prometheus, and feeds a Grafana dashboard with monthly trends.

**Test:** the dashboard shows the four metrics over the last 30 days, and each can be traced back to its source records.

### Step 12.3: Developer portal and golden path (Backstage)
**Do:** `platform/backstage/` (on box 3, PostgreSQL by the CloudNativePG operator, behind Cloudflare Access with Google sign-in): a **catalogue** of every component with owners, links to dashboards, runbooks and SLOs; **TechDocs** from the repos' documentation; and a **software template** that creates a complete new service: repo with the full CI and supply-chain pipeline, a Kyverno-compliant chart, CiliumNetworkPolicies, SLO definitions, a dashboard and alerts, a runbook stub, and Argo CD registration through an **ApplicationSet**. See `docs/adr/0024-internal-developer-platform.md`.

**Test:** the catalogue lists every component with its owner and links; the template produces a repo whose CI passes on the first run and whose manifests pass the Kyverno CLI tests.

### Step 12.4: Second service and multi-tenancy
**Do:** create a **second, different service** from the template (e.g. a small Go API serving summary statistics from WordPress), and take it through ci, staging and promotion to production. Add **multi-tenancy** in `platform/tenants/`: a namespace and **Argo CD project** per tenant, **resource quotas and limit ranges**, scoped **RBAC**, per-tenant Kyverno policies, and **cost showback** per tenant in OpenCost. Measure and publish the **time from template to first production deploy**.

**Test:** the second service runs in production with its own SLOs, dashboard and alerts; it can't exceed its quota or deploy outside its namespace; OpenCost shows its cost separately; the onboarding time is recorded.

### Step 12.5: Threat model and control matrix
**Do:** `docs/security/threat-model.md`: a **STRIDE** analysis of the whole system (trust boundaries, data flows, threats, mitigations), linked to the ADRs. `docs/security/controls-matrix.md`: every implemented control mapped to the **CIS Controls** (and SOC 2-style criteria), each with its evidence (policy, configuration, report or test).

**Test:** every trust boundary has its threats and mitigations listed; every control in the matrix links to evidence that exists.

### Step 12.6: Chaos experiments and postmortems
**Do:** `platform/chaos-mesh/` with scheduled experiments, each with a written hypothesis, expected outcome, blast radius and abort condition (kill the MariaDB primary; add latency to Bedrock calls; kill a WordPress pod mid-canary; fill a node's disk; partition box 2), run in staging first, then in production at quiet times; results in `docs/chaos/`. A **blameless postmortem template** in `docs/postmortems/`, and postmortems for at least two real incidents or notable drills from the build. See `docs/adr/0025-reliability-practice.md`.

**Test:** each experiment's outcome is recorded against its hypothesis; any surprise produced an action item; two postmortems exist with completed or scheduled action items.

### Step 12.7: Strategy documents
**Do:** in `docs/strategy/`: a **technical roadmap**; a **capacity and cost plan** (using the EKS load-test results from AWS plan step 6.4: how the HPA and Karpenter respond, the limits found, **cost per 1,000 visitors** at several traffic levels); a **migration plan** (e.g. moving russetleaf.dev fully into AWS, or going multi-region: phases, risks, rollback points); and a **build-vs-buy analysis** (the self-hosted stack against managed alternatives, with costs and trade-offs).

**Test:** each document states its recommendations and the evidence behind them, and is linked from the hub README.

### Step 12.8: Fleet management (hub-and-spoke Argo CD)
**Do:** make the home Argo CD the **hub**: **ApplicationSets with cluster generators** for the AWS overlays, a scoped AWS identity for Argo CD to authenticate to EKS (IAM), and documentation for `demo-up` to register the EKS cluster (AWS plan step 6.5). Keep the per-cluster Argo CD as a documented fallback.

**Test:** with a demo running, the hub shows both clusters and syncs the AWS overlays to EKS; after `demo-down`, the EKS cluster is gone from the hub with no errors left behind.

### Step 12.9: Public writing
**Do:** a series of **articles on russetleaf.dev** explaining the main design decisions (from the ADRs): e.g. S3 rather than EFS, no service mesh, the SRA account structure, evaluation gates for LLMs, error-budget-gated promotion. Link them from the hub README and your CV.

**Test:** at least four articles published, each linking to the relevant ADRs and code.

## Phase 11: Optional and finishing

### Step 10.11: Node-failure drills
**Do:** with the site under light load (e.g. a `k6` script), take each node offline in turn: first a clean shutdown, then **pulling its power cable**. Watch the API (virtual IP), the site (uptime check and Grafana), the database (MariaDB failover), the summarizer, and the alerts in Slack; bring the node back and confirm it rejoins cleanly. Record the impact and timings in `docs/adr/0015-availability-levels.md` and the decision log.

**Test:** with any one node down, the site keeps serving (brief errors at most during failover), the API stays reachable, the database fails over and rebuilds its replica afterwards, and the expected alerts fire and clear.

### Step 11.1 (optional): Keyless AWS access for pods
**Do:** publish the Talos cluster's service-account OIDC discovery files (public S3 bucket), register it as an IAM OIDC provider in `wp-infra`, switch pods from scoped keys to IAM roles one at a time, then delete the keys.

**Test:** each pod works with no AWS key in its Secrets; the old keys are deleted from IAM.

### Step 11.2: Documentation and polish
**Do:** run an **AWS Well-Architected review** of the design in the free Well-Architected Tool (Security pillar first, then the others), save the report in `docs/`, and fix or record the high-risk items; hub README with the russetleaf.dev architecture diagram and links to all repos; screenshots of Grafana (site, LLM, cost), Argo CD and an evaluation report; update `aws-wp.md` wherever the build differed from the design; check every repo with `gitleaks`, then make them public; **also make each GHCR package public** in its package settings (a repo going public doesn't change its packages), then remove the image pull secrets and Argo CD's GHCR credentials and confirm everything still pulls; add each repo's **OpenSSF Scorecard** badge to its README (record the scores in the decision log), and switch on **SARIF upload** of Checkov's results to GitHub code scanning in each (free for public repos), so findings appear on pull requests and in the Security tab.

**Test:** someone unfamiliar with the project can follow the README to understand it in five minutes.

## Ongoing operations (after the build)

These keep russetleaf.dev healthy once it's running. Add each as a calendar reminder or a scheduled job.

| Task | How often | How |
|---|---|---|
| Node-failure drill | Quarterly | Take one node offline (alternating nodes); confirm failover and record the timings |
| Rollback drill | Monthly (staging); quarterly (Talos, Cilium, Kyverno locally) | Follow a rollback runbook end to end and time it; fix the runbook if anything differed |
| Restore from the backup account | Quarterly | Restore a MariaDB backup from the backup account's locked copy into a scratch instance |
| Full disaster drill | Yearly | Rebuild russetleaf.dev using only the break-glass kit and off-account backups; record the time |
| Check the break-glass kit | Every 6 months | Logins work, recovery codes are valid, the printed copy is current |
| Test a database restore | Monthly | Restore the latest backup into a scratch MariaDB instance and check the post count (step 4.5) |
| Merge Renovate pull requests | Weekly | Review the Dependency Dashboard and pull requests; patches auto-merge; read changelogs for minors and majors and rehearse platform ones on a local Talos-in-Docker cluster; Argo Rollouts and the CI checks catch bad application updates |
| Security releases | Within 48 hours of a WPScan, Trivy Operator or Renovate security alert | Fast-track through ci and staging; promote as soon as staging passes |
| Version-age report | Monthly (automatic) | Plan upgrades for anything within 90 days of end of support |
| Talos and Kubernetes upgrades | Talos patches monthly; Kubernetes minor versions quarterly | Take an etcd snapshot and an on-demand MariaDB backup; rehearse on a local Talos-in-Docker cluster; check Cilium and platform components support the new Kubernetes version; bump versions in `wp-infra/envs/home` and apply **one node at a time** (box 2, box 1, then box 3), checking etcd health and the site between nodes (**no downtime expected**), then `talosctl upgrade-k8s`; roll back with `talosctl rollback` if needed; note timings in the decision log |
| Back up cluster state (etcd) | Weekly | `talosctl etcd snapshot` to the backup bucket (a scheduled job on your machine or a CronJob using a Talos API key). GitOps can rebuild everything else, but this speeds up recovery. |
| Check for Terraform drift | Weekly | A scheduled `terraform plan` in `wp-infra` CI for the AWS and Cloudflare resources (alerts if anything changed outside Terraform) |
| Check staging still works | Monthly, if nothing has been promoted | Run `staging-test` by hand, so a broken staging setup is found before it blocks a real release |
| Check the staging scrub | After any plugin that stores personal data is added | Confirm the `staging-data` Job also clears that plugin's tables |
| Review GuardDuty findings and audit alerts | Weekly (findings also alert in real time) | Check GuardDuty's console for low-severity findings not sent to Slack; tune audit alert rules that fire on expected activity |
| Review Security Hub | Weekly | Check new failed controls and findings across accounts; fix in Terraform or suppress with a recorded reason |
| Well-Architected review | Yearly | Update the review in the free Well-Architected Tool; keep the report in `docs/` |
| Prowler AWS account scan | Monthly (automatic) | Review the workflow's summary and Slack message; fix new failures in Terraform or record why they're accepted |
| Kubescape posture scan | Monthly | Run the Kubescape CLI against the home cluster; save the report in `docs/security/`; compare scores with the previous run and investigate any drop |
| Review the admin allow-list | Quarterly | Remove people who no longer need access, in the plugin's allow-list and the Cloudflare Access policy |
| Rotate the Google OAuth client secrets | Yearly | Create a new secret in the Google Cloud console, update Secrets Manager, let External Secrets sync it, delete the old one |
| Rotate MariaDB passwords | Quarterly | Regenerate the operator-managed Secret (or use the operator's rotation feature), then restart WordPress through its Rollout; check the backup user still works |
| Rotate scoped IAM keys | Every 90 days, until step 11.1 removes them | Create a new key in Terraform, update Secrets Manager, let External Secrets sync it, delete the old key |
| Review alerts, costs and Bedrock spend | Monthly | Grafana, OpenCost, the AWS Budget and Cost Explorer (filter by `Site=dev`) |
| Review log volume | Monthly | Check Loki's daily ingestion and box 3's memory; drop or shorten noisy sources at Alloy |
| Review alert noise | Monthly | Look at what fired in the Slack channels: remove or tune alerts nobody acted on, and update runbooks that didn't help |
| Test the outside monitoring | Quarterly | Pause the heartbeat or block the uptime check and confirm `#rl-critical` is notified |

## Deferred to the AWS phase

Not part of this plan; built later for russetleaf.com (see [`aws-eks-plan.md`](aws-eks-plan.md)):
- `wp-infra/envs/aws-edge` (Route 53, CloudFront, offline page, russetleaf.com media bucket) and `envs/aws` (VPC, EKS, RDS for MariaDB, ElastiCache, WAF)
- `overlays/aws` for every component
- Karpenter, AWS Load Balancer Controller, ExternalDNS, EBS CSI, kube-bench
- llama.cpp CUDA build and the GPU NodePool
- The `seed-from-dev` Job
- IRSA / Pod Identity roles

The home lab already builds most of what these need: the shared Terraform modules, the base manifests, the images and charts, and the CI.

## Progress checklist

| Step | Tier | Est. hours | Done | Date | Actual hours | Node memory after | Notes |
|---|---|---|---|---|---|---|---|
| 0.1 Accounts, tools, budget | Core | 4–8 | ☐ | | | | |
| 0.2 Decisions | Core | 1–2 | ☐ | | | | |
| 1.1 Four repos | Core | 3–5 | ☐ | | | | |
| 2.0 AWS Organization and accounts (SRA) | Core | 6–10 | ☐ | | | | |
| 2.0b Organisation security services | Core | 4–8 | ☐ | | | | |
| 2.1 Terraform bootstrap | Core | 3–5 | ☐ | | | | |
| 2.2 Talos cluster | Core | 8–14 | ☐ | | | | |
| 2.3 AWS + Cloudflare resources | Core | 5–8 | ☐ | | | | |
| 2.4 `wp-infra` CI | Core | 4–6 | ☐ | | | | |
| 2.5 Disaster recovery copies | Differentiator | 3–6 | ☐ | | | | |
| 3.1 GitOps structure + Argo CD | Core | 4–8 | ☐ | | | | |
| 4.1 Storage | Core | 1–2 | ☐ | | | | |
| 4.2 Secrets | Core | 2–4 | ☐ | | | | |
| 4.3 Ingress + tunnel | Core | 3–6 | ☐ | | | | |
| 4.4 Monitoring + Slack alerting | Core | 6–10 | ☐ | | | | |
| 4.5 MariaDB + backups + Valkey | Core | 6–10 | ☐ | | | | |
| 4.6 Logging (Loki + Alloy) | Core | 4–7 | ☐ | | | | |
| 5.1 WordPress image | Core | 12–20 | ☐ | | | | |
| 5.2 WordPress deployment | Core | 8–14 | ☐ | | | | |
| 5.3 Image promotion | Core | 2–4 | ☐ | | | | |
| 5.4 ci test clusters | Core | 5–8 | ☐ | | | | |
| 5.5 Self-hosted runners (ARC) | Core | 2–4 | ☐ | | | | |
| 5.6 On-demand staging | Core | 6–10 | ☐ | | | | |
| 5.7 Promotion pipeline | Core | 4–7 | ☐ | | | | |
| 5.8 Google sign-in for admins | Differentiator | 4–7 | ☐ | | | | |
| 6.1 Kyverno | Core | 6–10 | ☐ | | | | |
| 6.2 Argo Rollouts | Differentiator | 4–7 | ☐ | | | | |
| 6.3 CiliumNetworkPolicies | Core | 5–8 | ☐ | | | | |
| 6.4 Service mesh ADR (+ optional Istio experiment) | Differentiator | 2–6 | ☐ | | | | |
| 6.5 Sandboxed runtime (gVisor) | Differentiator | 4–7 | ☐ | | | | |
| 7.1 KEDA | Differentiator | 1–3 | ☐ | | | | |
| 7.2 LiteLLM gateway | Differentiator | 3–5 | ☐ | | | | |
| 7.3 Summarizer code | Differentiator | 8–12 | ☐ | | | | |
| 7.4 Summarizer chart + deploy | Differentiator | 5–9 | ☐ | | | | |
| 7.5 LLM monitoring | Differentiator | 3–6 | ☐ | | | | |
| 8.1 llama.cpp on box 2 | Differentiator | 4–6 | ☐ | | | | |
| 8.2 Gateway routing to local model | Differentiator | 2–4 | ☐ | | | | |
| 9.1 Evaluation set | Differentiator | 5–8 | ☐ | | | | |
| 9.2 Runners for `llm-summarizer` | Differentiator | 1–2 | ☐ | | | | |
| 9.3 Evaluation gate + releases | Differentiator | 4–7 | ☐ | | | | |
| 9.4 MLflow tracking + registry | Differentiator | 6–10 | ☐ | | | | |
| 9.5 Guardrails | Differentiator | 6–10 | ☐ | | | | |
| 9.6 Online evaluation + drift | Differentiator | 6–10 | ☐ | | | | |
| 9.7 Feedback loop + DVC | Stretch | 6–10 | ☐ | | | | |
| 9.8 Fine-tuned challenger | Stretch | 4–7 | ☐ | | | | |
| 10.1 Falco | Differentiator | 3–6 | ☐ | | | | |
| 10.2 Trivy Operator, Kubescape scan, Talos notes | Differentiator | 3–5 | ☐ | | | | |
| 10.3 OpenCost | Differentiator | 2–4 | ☐ | | | | |
| 10.4 Tracing with Tempo (always on) | Differentiator | 3–6 | ☐ | | | | |
| 10.5 AWS account posture (Prowler) | Differentiator | 2–4 | ☐ | | | | |
| 10.6 Version-age report | Differentiator | 2–3 | ☐ | | | | |
| 10.7 Custom seccomp profiles (optional) | Stretch | 4–8 | ☐ | | | | |
| 10.8 Rollback runbooks and drills | Differentiator | 5–8 | ☐ | | | | |
| 10.9 CrowdSec | Differentiator | 3–5 | ☐ | | | | |
| 10.10 First full disaster drill | Differentiator | 6–10 | ☐ | | | | |
| 10.11 Node-failure drills | Differentiator | 3–6 | ☐ | | | | |
| 11.1 Keyless AWS access (optional) | Stretch | 5–10 | ☐ | | | | |
| 11.2 Docs + go public | Core | 6–10 | ☐ | | | | |
| 12.1 SLOs and error budgets | Staff | 10–15 | ☐ | | | | |
| 12.2 DORA metrics | Staff | 6–10 | ☐ | | | | |
| 12.3 Backstage and golden path | Staff | 15–25 | ☐ | | | | |
| 12.4 Second service + multi-tenancy | Staff | 10–15 | ☐ | | | | |
| 12.5 Threat model + control matrix | Staff | 8–12 | ☐ | | | | |
| 12.6 Chaos experiments + postmortems | Staff | 10–15 | ☐ | | | | |
| 12.7 Strategy documents | Staff | 6–10 | ☐ | | | | |
| 12.8 Fleet management (hub) | Staff | 6–10 | ☐ | | | | |
| 12.9 Public writing | Staff | 10–20 | ☐ | | | | |

## Decision log

| Date | Decision | Reason |
|---|---|---|
| | | |
