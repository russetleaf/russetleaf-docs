# Phase 1 build plan: russetleaf.dev on Talos

This is the step-by-step plan for **Phase 1**, described in the [Phase 1 design](design.md): russetleaf.dev, WordPress on a three-node, highly available Talos cluster at home. Phase 1 is a complete project on its own; the AI summaries ([Phase 2](../phase-2-ai-mlops/plan.md)) and russetleaf.com on EKS ([Phase 3](../phase-3-russetleaf-com/plan.md)) are optional later phases; see [Later phases](#later-phases). The phases are explained in the [overview](../overview.md).

Each step is sized for one or a few Claude sessions, and ends with a **test** that must pass before moving on. Steps are ordered so that everything a component depends on already exists and works. Steps are grouped into **stages** (Stage 0 to Stage 9); "Phase" always means one of the project's three phases.

## How to use this plan with Claude

- **Start each session** with something like: *"Read the overview, the Phase 1 design and the Phase 1 plan. We are working on step 4.3. Here is where I left off: ..."* (the [overview](../overview.md), [design](design.md) and this plan). Claude has no memory of earlier sessions, so these files are the shared context.
- **AI assistance, not agents.** Phase 1 is built with Claude in conversation (answers, drafts and reviews), with the operator running every command and making every change. Phases 2 and 3 use AI coding agents ([ADR 2004](../phase-2-ai-mlops/adr/2004-agentic-ai-delivery.md)), and this phase's actual hours are the baseline for comparing them, so record them carefully.
- **Track the work on GitHub.** Each step is a GitHub issue in a milestone from the [roadmap](roadmap.md) (created in step 1.1 by `tools/plan_to_issues.py`); move it across the Projects board as work progresses, and update the roadmap's **Actual** columns when a milestone closes.
- **Start each step with a spec.** Ask Claude to write the step's spec from [`docs/specs/TEMPLATE.md`](../specs/TEMPLATE.md) (goal, context, scope, approach, tasks of 1–3 hours, acceptance criteria from the step's test, risks), save it as `docs/specs/phase-1/<step>-<name>.md`, review it, then build against it. The pull request links the issue and the spec, and the spec's **Outcome** records actual hours and what changed.
- **One step at a time.** Build it, run the step's test, fix, commit. Do not start the next step until the test passes.
- **Core first.** Each step has a tier (Core, Extended, Advanced) and an hour estimate; see [Priorities and time estimates](#priorities-and-time-estimates). Record actual hours in the checklist.
- **Keep the plan current.** Check off steps in the [progress checklist](#progress-checklist) and add to the [decision log](#decision-log) whenever something is decided or differs from the Phase 1 design. Ask Claude to update this file at the end of each session.
- **Watch node memory.** After every step that adds something to the cluster, run `kubectl top nodes` and note the result in the checklist. The three nodes have about 32 GB in total (`rl-home-cp03`: 16 GB; `rl-home-cp01` and `rl-home-cp02`: 8 GB each); keep the main workloads on `rl-home-cp03` (`rl-home-cp02` becomes the LLM node in Phase 2).
- **Build the home overlays only, but keep the base clean.** Put anything environment-specific (domain, hostnames, endpoints, credentials) in `overlays/home` (prod), `overlays/home-staging` or `overlays/ci`, never in `base`, so `overlays/aws` can be added later without rework.
- **Use the environments.** Try changes **locally** first (Docker Compose or a local kind/Talos cluster); once step 5.4 exists, every pull request is tested in a **ci** kind cluster; once step 5.6 exists, new versions go through **staging** before production. See [Environments and promotion](design.md#environments-and-promotion).
- **Never commit secrets.** Secrets go in AWS Secrets Manager and reach the cluster through External Secrets. Terraform state (which can contain secrets) lives in an encrypted S3 bucket. kubeconfig and talosconfig files stay outside Git.

## Priorities and time estimates

Every step in the [progress checklist](#progress-checklist) has a **tier** and an **estimate** in focused hours (with Claude's help). Estimates are rough (expect ±50%); record **actual hours** in the checklist and re-estimate after Stage 2.

| Tier | What it means | Steps | Est. hours |
|---|---|---|---|
| **Core** | A complete, demonstrable home lab: infrastructure as code (including the AWS Organization), a three-node highly available Talos cluster with Cilium, GitOps, platform services, monitoring and alerting, backups, the WordPress image and chart with its supply-chain pipeline, ci, staging and promotion, Kyverno and network policies, single sign-on with least-privilege cluster roles, the custom site design and logo, privacy basics (GDPR), and the docs. Finished on its own, this is a complete platform. | 0.1–2.4, 3.1, 4.1–4.7, 5.1–5.7, 5.10, 5.12, 6.1, 6.3, 9.2 | **~169–275** |
| **Extended** | Hardening, operations and evidence: progressive delivery, sandboxing, runtime security and compliance, cost monitoring, disaster-recovery copies, keyless AWS access, Google sign-in, always-on tracing, CrowdSec, performance and stress testing with a regression gate, and **evidence of operating it** (rollback, node-failure and disaster drills). | 2.5, 5.8, 5.9, 5.11, 6.2, 6.4, 6.5, 7.1–7.6, 7.8–7.12, 9.1 | **~72–127** |
| **Advanced** | Reliability and platform practices: SLOs and error budgets gating promotions, DORA metrics, an internal developer platform (Backstage, a golden path proven with a second service, multi-tenancy), fleet management with a local spoke cluster, chaos experiments and postmortems, a threat model and control matrix, strategy documents, public writing, and a custom seccomp profile for WordPress. | 7.7, 8.1–8.9 | **~89–144** |
| **Total** | | | **~330–546** |

**Calendar time** (Phase 1 only):

| Hours per week | Core | + Extended | + Advanced (everything) |
|---|---|---|---|
| ~10 | 4–7 months | 6–9 months | 8–13 months |
| ~20 | 9–14 weeks | 12–20 weeks | 17–27 weeks |
| ~40 | 4–7 weeks | 6–10 weeks | 8–14 weeks |

The optional later phases add about **85–144 hours** (Phase 2) and **125–210 hours** (Phase 3, or 97–158 without its AI steps); see the [overview](../overview.md#build-plans-priorities-and-effort).

**Where the time really goes:** Claude makes writing code, configuration and documents much faster, but the calendar is dominated by **debugging environment-specific problems** (Talos and Cilium networking, Kyverno blocking something, OIDC trust policies, tunnel routing), **waiting** (CI runs, quota approvals, DNS), and **learning each tool well enough to explain its trade-offs**.

**Recommended order:** finish **all Core steps first** (in plan order), and publish them; then add the Extended steps, starting with the drills (7.8, 7.10, 7.11), which show the system being operated; leave the Advanced steps until Core and Extended are done. A finished subset is worth more than an unfinished whole. Start Phase 2 or Phase 3 only once Phase 1's Core tier is published.

## Local workstation setup (Ubuntu 24.04)

Everything is built and tested from the operator's Ubuntu 24.04 workstation, which is also the **local** environment (see [Environments and promotion](design.md#environments-and-promotion)). Do this before step 0.1's test.

**Hardware:** 16 GB of RAM or more is recommended; a local kind or Talos-in-Docker cluster plus LocalStack and WordPress use about 4–6 GB. At least 40 GB of free disk for container images.

### 1. Base packages

```bash
sudo apt update
sudo apt install -y git curl wget unzip jq make ca-certificates gnupg lsb-release \
  python3 python3-venv shellcheck direnv wireguard-tools
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

Use **mise** to install the command-line tools, with the versions pinned in a `.mise.toml` file in each repo. The same file is used by CI (the `jdx/mise-action` GitHub Action), so the workstation and CI always run the same versions, and Renovate can keep them updated.

```bash
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
source ~/.bashrc
```

Tools to pin (check each name with `mise registry | grep <tool>`; pin `kubectl` and `talosctl` to the cluster's versions):

| Tool | Used for |
|---|---|
| `terraform` (1.10+), `tflint` (with `tflint-ruleset-aws`), `terraform-docs`, `infracost` | Infrastructure (`russetleaf-infra`) |
| `talosctl` | Talos clusters (home and local Talos-in-Docker) |
| `kubectl`, `helm`, `kustomize` | Kubernetes and charts |
| `kind` | Local and ci test clusters |
| `argocd` | Argo CD CLI (staging workflow, debugging) |
| `k9s`, `stern`, `kubectx` | Day-to-day cluster work (optional but very useful) |
| `kubeconform`, `chart-testing` (`ct`) | Manifest and chart validation |
| `k6` | Load, stress, spike and soak tests (scripts in `russetleaf-gitops/perf/`; run locally or through the k6 Operator) |
| `cilium`, `hubble` | Cilium status and connectivity tests; Hubble flow queries |
| `kyverno` | Policy tests |
| `cosign`, `syft`, `trivy`, `rekor-cli` | Image signing, SBOMs, scanning, transparency-log lookups |
| `hadolint`, `container-structure-test`, `zizmor` | Dockerfile linting, built-image checks, GitHub Actions workflow security |
| `kubescape` | On-demand cluster posture scans (NSA-CISA, MITRE ATT&CK, RBAC) |
| `prowler` (installed with `uv`) | AWS account posture scans (CIS AWS Foundations); also runs in CI |
| `gh` | GitHub CLI |
| `awscli` (v2) | AWS |
| `uv` | Python tooling (Checkov, pre-commit, LocalStack CLI; the summarizer in Phase 2) |
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

PHP and Composer are not needed locally: the WordPress image installs plugins inside its Docker build, and the PHP linters (PHP_CodeSniffer with the WordPress Coding Standards, PHPStan) run in a container, locally and in CI.

### 4. Configuration

- **Git:** set the Git user name and email; authenticate with `gh auth login` (SSH); turn on **commit signing** with the SSH key (`git config --global gpg.format ssh` and `user.signingkey`), and upload the key to GitHub as a signing key.
- **AWS:** after step 2.0, sign in through **IAM Identity Center (SSO)**, with one profile per account and permission set (e.g. `rl-mgmt-admin`, `rl-security-admin`, `rl-home-admin`, `rl-com-admin`, `rl-infra-admin`, and read-only variants), created with `aws configure sso`; sign in with `aws sso login --sso-session russetleaf`. Until then, use the existing account's admin login. Keep **no long-lived AWS access keys** on the workstation.
- **Cloudflare and Slack tokens:** do not put them in `~/.bashrc`. Use per-repo **direnv** files (`.envrc`, listed in `.gitignore`) that load them from a password manager CLI or from AWS Secrets Manager on entering the repo folder.
- **WireGuard to the lab** (after step 0.3): import the client profile exported from the ER605 into NetworkManager (`nmcli connection import type wireguard file rl-lab.conf`, or Settings → Network → VPN), with **AllowedIPs `10.10.0.0/24`** only, so only lab traffic goes through the tunnel and other internet use does not. Bring it up with `nmcli connection up rl-lab` when working on the cluster; `kubectl` and `talosctl` reach the cluster's virtual IP (`10.10.0.10`) through it.
- **Cluster access files:** keep kubeconfig contexts named clearly (`rl-home`, `kind-ci`, `rl-local`) and talosconfig at `~/.talos/config`, both with `chmod 600`. Back them up in the password manager. (If they are lost, they can be regenerated from the Talos machine secrets in Terraform state.)
- **Pre-commit hooks:** run `pre-commit install` in each repo after cloning (secret scan, YAML checks; in `russetleaf-infra`, the **pre-commit-terraform** hooks: fmt, validate, tflint, terraform-docs, Checkov).
- **Editor (optional):** VS Code with the HashiCorp Terraform, YAML (Red Hat), Kubernetes and Docker extensions.

### 5. Check the setup

Add a `scripts/check-tools.sh` to `russetleaf-gitops` that prints every tool's version and fails if one is missing. Then:

```bash
docker run --rm hello-world
kind create cluster --name smoke && kubectl get nodes && kind delete cluster --name smoke
talosctl cluster create --name local-smoke          # Talos in Docker
talosctl cluster destroy --name local-smoke
aws sts get-caller-identity --profile russetleaf-admin
gh auth status
```

**Test:** all of the above succeed, and `scripts/check-tools.sh` reports every tool.

## Stage 0: Prerequisites and decisions

### Step 0.1: Accounts, tools and budget alert

**Do:**

- Accounts: AWS: the **existing account** (which becomes `russetleaf-home`) plus a **new, dedicated management account** (its own email address, root MFA on) for the AWS Organization in step 2.0; GitHub; Cloudflare (russetleaf.dev zone).
- Set up the workstation: see [Local workstation setup](#local-workstation-setup-ubuntu-2404).
- Create an **AWS Budget** with an email alert at about $25/month (by hand in the console is fine; Terraform takes over in step 2.1).
- Pick an AWS region for the home lab's AWS resources (e.g. `us-east-1`) and use it everywhere.

- **SaaS account hardening** ([ADR 1032](adr/1032-defense-in-depth.md)): **passkeys or hardware security keys** on GitHub, Cloudflare, Google, Slack, the registrars and AWS Identity Center; **registrar lock** on russetleaf.com and russetleaf.dev; Cloudflare **API tokens scoped** to the zones and permissions each job needs.
- **Break-glass kit** (see the [disaster recovery plan](disaster-recovery.md)): in the password manager, record the AWS root login and **MFA recovery**, GitHub, Cloudflare and Google recovery codes, and the domain registrar logins; print the essentials and store the printed copy safely (ideally a second copy elsewhere). Add the Talos secrets bundle after step 2.2.
- **Slack:** create the project workspace and the channels from the Phase 1 design ([Alerting and notifications](design.md#alerting-and-notifications-slack)): `#rl-critical`, `#rl-dev-alerts`, `#rl-com-alerts`, `#rl-deploys`, `#rl-security`, `#rl-mlops`, `#rl-costs`, `#rl-staging`. Create the custom Slack app ("russetleaf-bot") with a bot token allowed to post to those channels, and install the **GitHub** app for Slack. Turn on phone notifications for `#rl-critical` only.
- **Outside monitoring accounts** (free plans): a heartbeat service (e.g. healthchecks.io) and an uptime checker (e.g. UptimeRobot or Better Stack), both posting to Slack.

**Test:** the workstation checks pass; a test message from the bot token (`curl` to Slack's `chat.postMessage`) appears in `#rl-dev-alerts`.

### Step 0.2: Decisions to make before writing code

Record each answer in the [decision log](#decision-log).

| Decision | Recommendation | Why it matters |
|---|---|---|
| **WordPress Helm chart** | Write a **small, project-owned chart** (Deployment/Rollout, Service, Ingress, HPA, PDB, CronJob for WP-Cron), kept in `russetleaf-wordpress/chart/` and released together with the image, for an image built on the **official `wordpress` image**. (the Phase 1 design already assumes this.) | The Bitnami chart only works with Bitnami-format images (their startup scripts and environment variables). Since Bitnami cut back its free images in 2025, the alternatives are building Bitnami's image from their open-source `bitnami/containers` repo, or a project-owned chart. A project-owned chart is simpler to reason about, removes the Bitnami dependency, and is a portfolio piece. |
| **Container registry** | **GHCR** (GitHub Container Registry): free for public images, and cosign keyless signing works with GitHub Actions out of the box. Note that **GHCR packages have their own visibility, separate from the repo's**, and start private. | Kyverno policies and image references depend on it. |
| **Repos public or private** | **Public early** (step 1.1, right after a `gitleaks` scan); GHCR packages public at first push. See [ADR 1030](adr/1030-github-actions-ci.md). | Private repos get only about 2,000 free Actions minutes a month (check current limits), which builds, kind tests and scans would exhaust; public repos get free hosted-runner minutes, code scanning and push protection. Self-hosted runners on public repos need the protections in step 5.5. |
| **Existing Talos node** | **Rebuild it with Terraform** in step 2.2, rather than adopting the hand-built config. | Nothing on the cluster is worth keeping, and a Terraform-built cluster is reproducible. Adopting it means importing its existing machine secrets, which is fiddly. |
| **Bot for version-bump pull requests** | A **GitHub App** installed only on `russetleaf-gitops`. | Narrower and longer-lived than a personal access token. |
| **Networking (CNI)** | **Decided: Cilium**, as the full CNI replacing Talos's default Flannel **and kube-proxy**, with Hubble. In Phase 3, EKS also runs Cilium (chaining mode), so both clusters use **CiliumNetworkPolicies**. See [Networking: Cilium and Hubble](design.md#networking-cilium-and-hubble). | Changing the CNI later means rebuilding the cluster. Flannel does not enforce network policies at all, so without Cilium any pod could reach any other pod (e.g. the database). |
| **Database credentials** | Home: passwords **generated by MariaDB Operator** into Kubernetes Secrets (never typed, never in Git or Secrets Manager), rotated on a schedule, TLS required. AWS (later): IAM auth through RDS Proxy. See [Database access and credentials](design.md#database-access-and-credentials). | Decides how WordPress gets its database login on each site; the chart must support both. |
| **Staging** | **On-demand, scale-to-zero** staging on the home cluster (created for each promotion, deleted afterwards). Promotion with plain **GitHub Actions** workflows; consider **Kargo** later only if memory allows. | `rl-home-cp01` has no memory to spare for an always-on staging copy. |
| **AWS stand-ins for ci tests** | **LocalStack** (S3, Secrets Manager; SQS from Phase 2), if its current free-tier terms suit; otherwise **MinIO** (S3) + plain Kubernetes Secrets (and **ElasticMQ** for SQS in Phase 2). | ci tests must run without an AWS account. |
| **Resource tagging** | Every AWS resource gets `Project=russetleaf`, `Site=dev`, `Env=prod|staging`, `ManagedBy=terraform`, set as the AWS provider's `default_tags`. | Makes leftovers easy to find, and costs visible per site in Cost Explorer. Phase 3 uses the same scheme with `Site=com`. |

### Step 0.3: Home network segmentation

**Do:** a separate lab network behind its own router, a **TP-Link ER605 (v2)**, reached from the workstation over **WireGuard** ([ADR 1040](adr/1040-lab-network-and-wireguard.md)):

```
Workstation (Wi-Fi, 192.168.1.x) ──WireGuard──┐
                                              ▼
Spectrum router ── mesh extender ── ER605 WAN (192.168.1.y) │ ER605 LAN (10.10.0.1) ── switch ── the three nodes
```

- **Wiring:** the ER605's WAN port to the mesh extender, its LAN port to the switch; the three boxes stay on the switch.
- **ER605 setup** (standalone mode, its own web interface; no Omada controller): update to the latest **v2 firmware** (WireGuard needs it); change the admin password; set the LAN to `10.10.0.0/24`; give the ER605 a **DHCP reservation on the Spectrum router** so its WAN address (the WireGuard endpoint) does not change.
- **Addresses and names:** lab subnet `10.10.0.0/24` (gateway `10.10.0.1`), cluster virtual IP `10.10.0.10`, `rl-home-cp01` `10.10.0.11`, `rl-home-cp02` `10.10.0.12`, `rl-home-cp03` `10.10.0.13`, WireGuard clients `10.10.99.0/24`; name the router **`rl-home-rt01`** ([ADR 1041](adr/1041-naming-convention.md)); reserve the nodes' addresses on the ER605 under their hostnames, matched by MAC address (Talos also sets them statically in step 2.2) and keep `.10` free for the virtual IP.
- **Firewall (access control rules):** the lab may reach the internet and the ER605; it **may not** reach `192.168.1.0/24` (household devices); nothing comes in from outside (the Cloudflare Tunnel is outbound-only, so no port forwards anywhere). Household devices cannot reach the lab, because the ER605's NAT blocks unrequested inbound traffic.
- **WireGuard server** on the ER605: clients `10.10.99.0/24`, one peer for the workstation; export its profile and import it on the workstation ([Local workstation setup](#4-configuration)). The tunnel listens on the ER605's WAN address on the household network, so it works from anywhere in the house without port forwarding on the Spectrum router.
- **Back up** the ER605's configuration and keep its admin login in the break-glass kit.
- Set **BIOS passwords** on all three boxes. See the overview's [Defense in depth](../overview.md#defense-in-depth).

**Test:** from a laptop plugged into the lab switch, the internet works and a household device (e.g. the Spectrum router's admin page at `192.168.1.1`) is unreachable; from the workstation with WireGuard up, `10.10.0.1` answers, and with it down, the lab is not reachable; from another household device, the lab is not reachable. (Step 2.2 repeats these checks from a pod.)

## Stage 1: Repositories

### Step 1.1: Create the repos

**Do:**

- Create **`russetleaf-gitops`**, **`russetleaf-infra`** and **`russetleaf-wordpress`** (`russetleaf-llm-summarizer` is created in Phase 2). The project documentation stays in this repo, **`russetleaf-docs`** ([ADR 1038](adr/1038-documentation-repo-and-site.md)).
- In each: a README stub, `.gitignore` (Terraform state, `.terraform/`, kubeconfig, talosconfig, `.env`), a `LICENSE` if public, branch protection on `main` (pull requests and passing checks required).
- In `russetleaf-docs`: the design, plans, roadmap, ADRs and spec template already exist (ADR template in the [ADR template](../adr/0000-template.md)). Record the big step 0.2 decisions as ADRs (the next number in the phase, e.g. 1042) and link them from the decision log. Operational docs (runbooks, SLO definitions, performance and security reports, Talos hardening notes) go in `docs/` of the repo that produces or uses them, mostly `russetleaf-gitops`. Each ADR's **Open items** are finished in these steps:

| ADR | Phase 1 steps | Phase 2 steps | Phase 3 steps |
|---|---|---|---|
| [1001 No service mesh](adr/1001-no-service-mesh.md) | 6.4 | — | 1.4, 4.3 |
| [1002 S3 media, not EFS](adr/1002-s3-media-not-efs.md) | 5.1 | — | — |
| [1003 Kubescape CLI, not operator](adr/1003-kubescape-cli-not-operator.md) | 7.2 | — | 2.5 |
| [1004 GHCR, not ECR](adr/1004-ghcr-not-ecr.md) | 5.1 | — | 0.2 |
| [1005 Loki and Alloy](adr/1005-loki-alloy-for-logs.md) | 4.6 | — | — |
| [1006 Tempo tracing](adr/1006-tempo-tracing.md) | 7.4 | 5.2 | 2.4 |
| [1007 Prowler, not ThreatMapper](adr/1007-prowler-not-threatmapper.md) | 7.5 | — | 4.1 |
| [1008 Google sign-in for admins](adr/1008-google-sign-in-for-admins.md) | 5.8 | — | 3.1 |
| [1009 gVisor sandboxing](adr/1009-gvisor-sandboxing.md) | 6.5, 7.1 | 4.2 | — |
| [1010 Local storage, no Ceph](adr/1010-local-storage-no-ceph.md) | 4.1, 4.5 | — | — |
| [1011 Update strategy](adr/1011-update-strategy.md) | 1.1, 5.1, 7.6 | — | — |
| [1012 OpenCost and AWS billing](adr/1012-opencost-and-aws-billing.md) | 2.0, 7.3 | 5.2 | 4.2 |
| [1013 Image supply chain](adr/1013-image-supply-chain.md) | 5.1, 6.1 | 2.4 | — |
| [1014 Availability levels](adr/1014-availability-levels.md) | 2.2, 4.5, 7.11 | — | 3.1 |
| [1015 Process allow-listing](adr/1015-process-allow-listing.md) | 7.1, 7.7 | 5.1 | 4.4 |
| [1016 Rollback strategy](adr/1016-rollback-strategy.md) | 3.1, 5.7, 6.1, 7.8 | 2.4, 5.2 | — |
| [1017 Intrusion detection and prevention](adr/1017-intrusion-detection-and-prevention.md) | 2.0b, 2.2, 2.3, 4.6, 7.9 | — | — |
| [1018 Disaster recovery](adr/1018-disaster-recovery.md) | 0.1, 2.0, 2.5, 7.10 | — | 5.1 |
| [1019 AWS multi-account (SRA)](adr/1019-aws-multi-account-sra.md) | 2.0, 2.0b, 2.4 | — | 0.1 |
| [1020 Three-node HA home cluster](adr/1020-three-node-ha-home-cluster.md) | 2.2, 4.5, 7.11 | — | — |
| [1021 SLOs and error budgets](adr/1021-slos-and-error-budgets.md) | 8.1, 8.2 | 5.2 | — |
| [1022 Internal developer platform](adr/1022-internal-developer-platform.md) | 8.3, 8.4, 8.8 | — | 5.5 |
| [1023 Reliability practice](adr/1023-reliability-practice.md) | 8.6 | 5.2 | — |
| [1024 Performance and stress testing](adr/1024-performance-and-stress-testing.md) | 5.9, 7.12 | 2.6 | 5.4 |
| [1025 Site design in Git](adr/1025-site-design-in-git.md) | 5.10, 5.11 | — | — |
| [1026 CPU limits](adr/1026-cpu-limits.md) | 4.4, 5.5 | 3.1 | — |
| [1027 Cilium as the CNI](adr/1027-cilium-cni.md) | 2.2 | — | 1.4 |
| [1028 Internal PKI (cert-manager)](adr/1028-internal-pki.md) | 4.2 | — | — |
| [1029 On-demand staging](adr/1029-on-demand-staging.md) | 5.6, 5.7 | — | — |
| [1030 GitHub Actions and public repos](adr/1030-github-actions-ci.md) | 1.1, 5.5 | — | 1.4, 5.1 |
| [1031 Kubernetes component hardening](adr/1031-kubernetes-component-hardening.md) | 2.2, 6.1, 7.2 | — | 1.4, 4.1 |
| [1032 Defense in depth](adr/1032-defense-in-depth.md) | 0.1, 0.3, 1.1, 2.2, 2.3, 5.1, 5.2, 5.6, 5.7, 6.1, 8.5 | 2.4, 5.1 | 1.2, 2.4, 4.1 |
| [1033 Identity and access](adr/1033-identity-and-access.md) | 4.6, 4.7, 6.1, 6.3, 9.1 | — | 1.4, 1.7 |
| [1034 Kubernetes threat model coverage](adr/1034-kubernetes-threat-model-coverage.md) | 2.2, 3.1, 4.4, 4.6, 6.1, 6.3, 7.2, 8.5 | 5.1 | 1.4, 2.3, 4.1 |
| [1035 Platform security](adr/1035-platform-security.md) | 2.2, 4.4, 4.6, 5.1, 6.1, 7.2 | — | 4.1 |
| [1036 Compliance frameworks and privacy](adr/1036-compliance-frameworks-and-privacy.md) | 5.1, 5.12, 7.1, 8.5 | 4.5 | 4.1 |
| [1037 Project phases](adr/1037-project-phases.md) | 1.1 | — | — |
| [1038 Separate documentation repo and docs site](adr/1038-documentation-repo-and-site.md) | 1.1 | — | — |
| [1039 Bootstrap through Talos inline manifests](adr/1039-bootstrap-through-talos-inline-manifests.md) | 2.2, 3.1 | — | — |
| [1040 Lab network and WireGuard](adr/1040-lab-network-and-wireguard.md) | 0.3, 2.2 | — | — |
| [1041 Naming convention](adr/1041-naming-convention.md) | 0.3, 2.2 | — | 1.4, 2.3 |
| [2001 MLOps lifecycle](../phase-2-ai-mlops/adr/2001-mlops-lifecycle.md) | — | 4.4–4.10 | — |
| [2002 Summary pipeline architecture](../phase-2-ai-mlops/adr/2002-summary-pipeline-architecture.md) | — | 2.1–2.5 | — |
| [2003 Self-hosted model on `rl-home-cp02`](../phase-2-ai-mlops/adr/2003-self-hosted-model-on-cp02.md) | — | 1.3, 3.1, 3.2 | — |
| [2004 Agentic AI delivery](../phase-2-ai-mlops/adr/2004-agentic-ai-delivery.md) | — | 1.1b, 5.3 | 0.3 |
| [2005 Fine-tuning on a rented GPU](../phase-2-ai-mlops/adr/2005-fine-tuning-on-a-rented-gpu.md) | — | 1.2, 4.6, 4.8–4.10 | — |
| [2006 AI operations assistant](../phase-2-ai-mlops/adr/2006-ai-operations-assistant.md) | — | 5.2b | — |
| [2007 AI diagnosis and remediation proposals](../phase-2-ai-mlops/adr/2007-ai-diagnosis-and-remediation-proposals.md) | 4.4 | 5.2c | — |
| [3001 kube-bench on EKS only](../phase-3-russetleaf-com/adr/3001-kube-bench-eks-only.md) | 7.2 | — | 2.5 |
| [3002 Fine-tuning on the EKS GPU pool (superseded by 2005)](../phase-3-russetleaf-com/adr/3002-fine-tuning-on-eks-gpu.md) | — | — | — |
| [3003 Cilium chaining on EKS](../phase-3-russetleaf-com/adr/3003-cilium-chaining-on-eks.md) | — | — | 1.4 |
| [3004 EKS component hardening](../phase-3-russetleaf-com/adr/3004-eks-component-hardening.md) | — | — | 1.4, 2.5, 4.1 |
| [3005 EKS access and audit logs](../phase-3-russetleaf-com/adr/3005-eks-access-and-audit-logs.md) | — | — | 1.4, 1.7 |
| [3006 On-demand demo stack and always-on edge](../phase-3-russetleaf-com/adr/3006-on-demand-demo-stack.md) | — | — | 1.2, 5.1 |
| [3007 RDS for MariaDB behind RDS Proxy](../phase-3-russetleaf-com/adr/3007-rds-mariadb-with-rds-proxy.md) | — | — | 1.6, 3.1 |
| [3008 Karpenter node pools](../phase-3-russetleaf-com/adr/3008-karpenter-node-pools.md) | — | — | 1.5, 2.3 |

- Add a pre-commit or CI secret scan (`gitleaks`) to every repo, scan each repo's **full history**, and then **make the repos public** ([ADR 1030](adr/1030-github-actions-ci.md)); turn on **secret scanning with push protection**.
- **GitHub organization settings** in `russetleaf-infra/envs/github/` (Terraform's GitHub provider): default workflow token **read-only**, only verified or allow-listed Actions, branch protection and required reviews, environments, secret scanning with push protection.
- Add **OpenSSF Scorecard** (weekly scheduled workflow) and **zizmor** (on workflow changes) to every repo, and GitHub's **dependency-review action** to the repos with dependencies (`russetleaf-wordpress`; `russetleaf-llm-summarizer` in Phase 2).
- Add **Checkov** to every repo's CI from the start, scanning the **GitHub Actions workflows** (unpinned actions, over-broad `permissions`, script injection), with a `.checkov.yaml` per repo. Later steps add each repo's other targets (Terraform, manifests, Dockerfiles, charts). Skips must carry a reason. See [Infrastructure and configuration scanning](design.md#infrastructure-and-configuration-scanning-checkov).
- Add **Renovate** to every repo (Helm charts, Terraform providers, base images, GitHub Actions, `.mise.toml`, and later Composer and Python lock files), with a shared configuration following the Phase 1 design's [Update strategy](design.md#update-strategy): a weekly schedule (security updates immediately), grouping per platform component, **auto-merge for patch updates** of platform charts, CLI tools and GitHub Actions once CI passes, the **Dependency Dashboard**, and custom version rules for Talos and Kubernetes versions in Terraform.
- In `russetleaf-docs`: confirm the **docs site** builds and publishes (GitHub Pages, from the `docs` workflow), at **`docs.russetleaf.dev`** (set up on 2026-11-02 with hand-made Cloudflare records; step 2.3 imports them into Terraform); keep its README as the project hub (what the project is, the phases, links to the site and all repos). Give each code repo a README linking to the site, and a pull-request template with a "docs updated?" checkbox.

- **Track the plan on GitHub:** run `tools/plan_to_issues.py --phase-dir docs/phase-1-russetleaf-dev --repo <owner>/russetleaf-docs` (a dry run), check its output, then run it again with `--apply` to create the roadmap's milestones, the labels and one issue per step. Create a public **GitHub Projects** board with these issues (and later issues from the code repos), a **Roadmap** view grouped by milestone, and fields for estimate and actual hours.

**Test:** each repo is public with a clean `gitleaks` history scan and push protection on; each repo has protected `main`, the secret scan and Checkov run on a test pull request (a workflow with `permissions: write-all` fails Checkov), and Renovate opens its onboarding pull request. The Projects board shows one issue per step in the roadmap's milestones, and running the script again creates nothing new.

## Stage 2: Infrastructure (`russetleaf-infra`)

### Step 2.0: AWS Organization and accounts (Security Reference Architecture)

**Do** (`russetleaf-infra/envs/org/`, applied locally with the new management account), following the Phase 1 design's [AWS account structure](design.md#aws-account-structure-and-best-practices-security-reference-architecture) and [ADR 1019](adr/1019-aws-multi-account-sra.md):

- Create the **Organization** from the dedicated management account; **OUs**: Security, Infrastructure, Workloads.
- **Accounts:** create **Security Tooling**, **Log Archive** and **Backup** (Security OU), and **russetleaf-infra** (Infrastructure OU); **invite the existing account** and move it into Workloads as **russetleaf-home**. (russetleaf-com is created in Phase 3.)
- **IAM Identity Center:** permission sets for admin, read-only and break-glass, MFA required; assign the operator per account.
- **SCPs** (start by attaching them to a test OU, then to the real OUs): deny leaving the Organization; deny disabling CloudTrail, GuardDuty, Config, Security Hub and Access Analyzer; allow only us-east-1 and us-west-2 (global services excepted); deny member-account root actions; deny IAM users and access keys except a named exception for the home cluster's scoped-key users in russetleaf-home; protect the Log Archive and Backup buckets.
- **Centralized root access management** (remove member accounts' root credentials), **tag policies**, **alternate security contacts** on every account, **delegated administrators** (Security Tooling for GuardDuty, Security Hub, Config, Access Analyzer).
- **Budgets:** a consolidated one in the management account plus one per workload account; **activate the cost allocation tags** (`Project`, `Site`, `Env`, `Stack`, `ManagedBy`) here, in the management account, where they apply organization-wide (a tag must exist on a resource first, so re-run after step 2.3 if needed; activation can take up to a day).
- Update the break-glass kit: the management account's root access and the Identity Center logins (member accounts no longer have root credentials).

**Test:** sign-in to every account through Identity Center works with MFA; a test action blocked by an SCP fails (e.g. creating a resource in eu-west-1, or disabling GuardDuty in russetleaf-home); member accounts show no root credentials; an untagged resource is flagged by the tag policy.

### Step 2.0b: Organization security services

*Can follow step 2.2: the cluster does not depend on it ([roadmap](roadmap.md)).*

**Do** (`russetleaf-infra/envs/security/`, applied with Security Tooling and Log Archive access):

- **Log Archive:** S3 Object Lock buckets with **KMS customer-managed keys** for the **organization CloudTrail trail** (management events, all accounts and regions, log-file validation), Config history and (later) VPC flow logs.
- **Security Tooling:** organization-wide **GuardDuty** (with EKS audit-log monitoring, auto-enabled for new accounts), **Security Hub** (AWS Foundational Security Best Practices and CIS standards in every account), **AWS Config** with **focused recording** (IAM, S3, security groups, KMS, EKS, RDS and other key types) and a **CIS conformance pack**, aggregated here, and **IAM Access Analyzer** (organization external-access analyzer).
- **Findings to Slack:** EventBridge rules for GuardDuty findings (medium and above) and Security Hub findings (critical and high) to SNS topics connected through **Amazon Q Developer in chat applications** (authorize the Slack workspace once) to `#rl-security` (critical also to `#rl-critical`).
- **Account-level settings in every account:** S3 Block Public Access, EBS encryption by default, EBS snapshot and AMI public-access blocks.

**Test:** GuardDuty sample findings (`aws guardduty create-sample-findings`) appear in `#rl-security`; CloudTrail log-file validation passes (`aws cloudtrail validate-logs`) for an event from each account; Security Hub shows every account with both standards enabled, and the first scores are recorded in the decision log; a deliberately public test bucket is blocked by Block Public Access and flagged by Access Analyzer.

### Step 2.1: Bootstrap (state bucket and CI roles)

**Do** (`russetleaf-infra/bootstrap/`, applied locally):

- In **russetleaf-infra**: the S3 bucket for Terraform state (versioning, KMS encryption, public access blocked, TLS required, `prevent_destroy`). Backends use `use_lockfile = true`. Bucket policy granting each account's CI roles access to their own state keys only.
- In **each account** that CI deploys to (russetleaf-home, russetleaf-infra and the security accounts; russetleaf-com in Phase 3): the GitHub OIDC provider, a read-only **plan** role (pull requests), an **apply** role (only from the `apply` GitHub Environment), and a read-only **audit** role for Prowler (AWS's `SecurityAudit` and `ViewOnlyAccess` managed policies; used in step 7.5).

**Test:** a scratch root module with the S3 backend runs `terraform init` and `plan`; a GitHub Actions job in `russetleaf-infra` assumes the plan role in russetleaf-home and runs `aws sts get-caller-identity`; the same job cannot read another account's state key.

### Step 2.2: Talos cluster (three control-plane nodes)

**Schedule:** the [roadmap](roadmap.md) splits this step over two days: **getting the cluster up** (Talos on all three boxes, etcd, the virtual IP, Cilium and Argo CD) on the first, and **hardening and testing** on the second.

**Before starting (hardware):** the hardware is listed in the Phase 1 design's [Home hardware](design.md#home-hardware). On each node, update the BIOS; turn on **power on after AC loss**, virtualization and **TPM 2.0** (all three nodes have it); and put Secure Boot into **setup mode** so the Talos keys can be enrolled. Put a printed **hostname label** on each machine. The current single-node Talos install (and the old test Argo CD Application on it) is wiped and replaced.

**Do** (`russetleaf-infra/envs/home/`, applied locally over WireGuard; uses the `siderolabs/talos` provider):

- **Talos image:** one Image Factory **schematic**, managed in Terraform (`talos_image_factory_schematic`) and used for all three boxes, with the system extensions **`siderolabs/gvisor`** (sandboxed runners, step 6.5), and **`siderolabs/intel-ucode`** (CPU microcode security fixes). No network firmware extension is needed: all three nodes have Intel network cards. Install from the schematic's **Secure Boot** ISO, and use its installer image for upgrades, with the Talos version pinned. (Kubernetes applications such as Cilium and Argo CD cannot go in the image; they come from the machine config below.)
- **Hostnames and addresses:** set each node's hostname in its machine config (`machine.network.hostname`), which also becomes its Kubernetes node name: `rl-home-cp01` `10.10.0.11`, `rl-home-cp02` `10.10.0.12`, `rl-home-cp03` `10.10.0.13` ([ADR 1041](adr/1041-naming-convention.md)), with gateway and DNS `10.10.0.1`. Name the Talos cluster **`rl-home`** (also the kubeconfig context and the `cluster` label on metrics and logs).

- Generate machine secrets; machine configs for **three control-plane nodes**, all schedulable: **`rl-home-cp03`** (main workloads), **`rl-home-cp01`** (secondary workloads) and **`rl-home-cp02`** (general workloads and CI runners; it becomes the LLM node in Phase 2). Each gets its fixed address from step 0.3.
- **Shared virtual IP** for the Kubernetes API (Talos's `vip` setting on the nodes' network interface), on **`10.10.0.10`**; kubeconfig and Talos endpoints point at it.
- **Reservations on every node** (kubelet `systemReserved` and `kubeReserved` for CPU and memory), so workloads cannot starve etcd, the API server or the kubelet; plus a **per-pod PID limit** (`podPidsLimit`, e.g. 4096; check WordPress's process counts first; Phase 2 rechecks it for llama.cpp) and **hard eviction thresholds** for memory, disk and inodes ([ADR 1034](adr/1034-kubernetes-threat-model-coverage.md)).
- **Secure Boot:** install Talos from its **Secure Boot images** (Image Factory), with the keys enrolled in each node's firmware, so the TPM-sealed disk encryption only unlocks on an untampered boot chain ([ADR 1032](adr/1032-defense-in-depth.md)).
- **User namespaces:** confirm the Kubernetes and Talos versions support pods with `hostUsers: false`; record the result (step 6.1 enforces it if so).
- **Hardening** ([ADR 1031](adr/1031-kubernetes-component-hardening.md)): **disk encryption** of the system-state and data partitions, **sealed to the TPM** (all three nodes have TPM 2.0; confirm it is enabled in the BIOS); a **host firewall** (Talos ingress rules) allowing ports 6443 and 50000 only from the lab subnet (`10.10.0.0/24`) and WireGuard clients (`10.10.99.0/24`); kubelet **`seccompDefault: true`**; the API server's **Pod Security Admission defaults** (`baseline` enforced cluster-wide, `restricted` for warn and audit), with per-namespace labels set in step 6.1.
- `rl-home-cp03` and `rl-home-cp01`: labels for the workload roles (e.g. `role=main`, `role=secondary`), used for placement (e.g. the MariaDB primary on `rl-home-cp03`).
- All nodes: kubelet extra mount for `/var/local-path-provisioner` (needed in step 4.1).
- **API server audit logging:** a focused Talos audit policy (metadata for most requests; request details for Secrets, RBAC, `exec` and `attach`), writing to the audit log on each control-plane node (collected in step 4.6).
- **Cilium and Argo CD at bootstrap** ([ADR 1039](adr/1039-bootstrap-through-talos-inline-manifests.md)): in the machine config, set `cluster.network.cni.name: none` and `cluster.proxy.disabled: true` (Cilium replaces kube-proxy). Terraform renders the **Cilium** chart (pinned version; Talos's documented values: `kubeProxyReplacement: true`, `k8sServiceHost: localhost`, `k8sServicePort: 7445` (KubePrism), and the cgroup and capability settings Talos requires; Hubble and Hubble Relay on; **WireGuard transparent encryption** on; ServiceMonitors **off** until step 4.4), the **Argo CD** chart, a root **Application** pointing at `russetleaf-gitops/bootstrap/home`, and the kubelet serving-certificate approver (below) with its Helm provider's template function, and puts them in the machine config's **`cluster.inlineManifests`**. Talos applies them while bootstrapping, so the cluster comes up with networking and GitOps already running. Step 3.1 hands Cilium and Argo CD over to Argo CD and removes them from the inline manifests.
- Apply configs, bootstrap etcd, output kubeconfig and talosconfig (save them outside Git).
- **kubelet serving certificates ([ADR 1035](adr/1035-platform-security.md)):** set the kubelet's `rotate-server-certificates` option in the machine config and install a CSR approver for kubelet serving certificates (Talos's documented approach; one of the inline manifests above), so each kubelet's certificate is signed by the cluster CA.
- Install **metrics-server** here or in step 4.1, so `kubectl top` works, **without** `--kubelet-insecure-tls`.

The cluster is **highly available for a single node failure** (three etcd members, the virtual IP); see [ADR 1020](adr/1020-three-node-ha-home-cluster.md) and [ADR 1014](adr/1014-availability-levels.md).

**Test:** from the workstation over WireGuard, `kubectl get nodes` shows all three nodes `Ready` and `talosctl health` passes; the Argo CD pods are running and the root Application exists; `talosctl get extensions` on each node lists gVisor and the Intel microcode; each kubelet's serving certificate is issued by the cluster CA (`openssl s_client -connect <node-ip>:10250`) and `kubectl top nodes` works with metrics-server verifying TLS; a fork bomb in a throwaway pod stops at the PID limit while the node stays `Ready`; the partitions show as encrypted; ports 6443 and 50000 are refused from a household device without the VPN; a test pod can reach the internet but not `192.168.1.0/24`; `cilium status` is all green and `cilium connectivity test` passes; `etcd` has **three healthy members** (`talosctl etcd members`); the API answers on the virtual IP, and still answers after shutting down whichever node holds it; `cilium encrypt status` shows WireGuard on with the other two nodes as peers on each node; there is no kube-proxy DaemonSet. Rebuild once from scratch to prove it is reproducible, and **record how long the rebuild took** as the recovery time in [ADR 1014](adr/1014-availability-levels.md).

### Step 2.3: AWS and Cloudflare resources for the home lab

**Do** (`russetleaf-infra/modules/` + `envs/home/`; all AWS resources in the **russetleaf-home** account):

- Modules: `s3-media`, `s3-backups`, `secrets` (Phase 2 adds `sqs-queue` and `bedrock-access`).
- russetleaf.dev resources: media bucket, database-backup bucket (lifecycle: expire after 30 days), **Loki log bucket** (lifecycle: expire after 7 days, used in step 4.6, plus a scoped IAM key for Loki), **Tempo trace bucket** (lifecycle: expire after 3 days, used in step 7.4, with its own scoped key), Secrets Manager entries (empty placeholders; values set by hand or generated).
- **`prevent_destroy`** on every stateful resource (the state bucket, media, backup, log, trace and model mirror buckets, and Secrets Manager entries), so no plan, including a revert's, can delete them without a deliberate code change (see the Phase 1 design's [Rollback strategy](design.md#rollback-strategy)).
- **Staging resources** (a second, smaller set of the same modules, tagged `Env=staging`): staging media bucket, Secrets Manager entries, and a scoped IAM key that can **read** the production backup bucket but write only to staging resources. Used from step 5.6.
- **Email:** an SES domain identity for russetleaf.dev, with its DKIM and SPF records created in Cloudflare, and SES SMTP credentials stored in Secrets Manager. (New SES accounts are in the "sandbox" and can only send to verified addresses; verify a test address, or request production access.)
- Scoped IAM users and keys for the home cluster, one per job: External Secrets (read the russetleaf.dev secrets only), WordPress (media bucket), MariaDB backups (backup bucket). (Phase 2 adds keys for the summarizer and LiteLLM.) Store each key in Secrets Manager.
- Cloudflare (Cloudflare provider): the tunnel, its token (stored in Secrets Manager), DNS records for `russetleaf.dev` and `www`, **DNSSEC** for russetleaf.dev (Cloudflare's one-click setting, plus the DS record at the registrar), **HSTS** and security-header transform rules at Cloudflare, basic WAF/security settings plus Cloudflare's free **managed rule set**, a **rate-limiting rule** on `/wp-login.php`, and a rule **blocking `/xmlrpc.php`**, **Cloudflare Access** policies for admin UIs (Argo CD, Grafana) so they are never public, with **Google** configured as Cloudflare Access's login provider (used for WordPress admin paths in step 5.8), **Cloudflare notifications** (tunnel health, security events) to a Slack webhook for `#rl-dev-alerts`, and a `staging.russetleaf.dev` hostname behind Cloudflare Access (used from step 5.6).
- **Import the hand-made docs-site records** into `envs/home` with Terraform `import` blocks, so the plan shows no changes: the `docs` CNAME (→ `smscully.github.io`, **DNS only**) and the `_github-pages-challenge-smscully.docs` TXT record that verifies the domain with GitHub ([ADR 1038](adr/1038-documentation-repo-and-site.md)).
- The Slack bot token in Secrets Manager (set by hand; Terraform creates the empty entry).

**Test:** with each scoped key, the allowed action works and a disallowed one fails (e.g. the WordPress key cannot read the backup bucket); the tunnel shows as created in Cloudflare; requests to `/xmlrpc.php` are blocked at Cloudflare, and rapid repeated requests to `/wp-login.php` are rate-limited. `terraform plan` shows the imported docs-site records with no changes, and https://docs.russetleaf.dev still loads.

### Step 2.4: `russetleaf-infra` CI

**Do:** the pipeline described in the Phase 1 design ([Terraform pipeline](design.md#terraform-pipeline-russetleaf-infra)):

- **Pull requests:** `terraform fmt -check` → `validate` → **tflint** with **`tflint-ruleset-aws`** → **Checkov** on the source with **custom policies** in `.checkov/` (required `Project`/`Site`/`Env` tags, `us-east-1` only, approved instance families, S3 Block Public Access) → **`terraform test`** for the modules → `terraform plan -out` (saved as a private workflow artifact with short retention) → **Checkov on the plan** → **IAM Access Analyzer** policy checks (`validate-policy`, and its custom checks for new public or cross-account access) → **Infracost** cost-difference comment → plan comment → gitleaks.
- **After merge:** a GitHub Environment **`apply`** with required reviewers (the operator), limited to `main`; the OIDC apply role trusts only that environment; the job applies **the saved plan from the pull request**, not a fresh plan.
- **Weekly scheduled** drift-check plan.
- **Repo hygiene:** `.pre-commit-config.yaml` with the **pre-commit-terraform** hooks plus gitleaks; **terraform-docs** generating module READMEs; `.terraform.lock.hcl` with hashes for Linux and the workstation (`terraform providers lock -platform=...`); **GitHub secret scanning with push protection** on (the repo is public from step 1.1).
- Applies to `envs/home` stay **local** for now (the Talos provider needs the home network); they can move to in-cluster runners after step 5.5.

**Test:** a pull request with a harmless change shows passing checks, a plan comment and an Infracost comment; a deliberately insecure change (e.g. a public bucket) fails Checkov; an untagged resource fails the custom tag policy; an invalid instance type fails tflint; after merge, the apply waits for approval in the `apply` environment and applies the saved plan.

### Step 2.5: Disaster recovery copies

**Do:** as described in the [disaster recovery plan](disaster-recovery.md) and [ADR 1018](adr/1018-disaster-recovery.md):

- The **Backup** account already exists (step 2.0).
- `russetleaf-infra/envs/dr/`: in the Backup account, **S3 Object Lock** buckets in **us-west-2** (30-day retention, governance mode at first), versioned and **KMS-encrypted**; **replication** rules (with write-only roles) from the Terraform state bucket (russetleaf-infra) and the MariaDB backup and media buckets (russetleaf-home). (CloudTrail logs are already isolated in the Log Archive account.)
- A **daily repo-mirror** workflow (`git bundle` of each repo) uploading to the backup account through a write-only OIDC role.
- Add the **Talos secrets bundle** and talosconfig (from step 2.2) to the break-glass kit.

**Test:** a new MariaDB backup appears in the backup account within minutes; deleting or overwriting it there **fails** (Object Lock); restoring a MariaDB backup **from the backup account's copy** into a scratch instance works; a repo can be cloned from its latest bundle.

## Stage 3: GitOps foundation (`russetleaf-gitops`)

### Step 3.1: Structure and Argo CD bootstrap

**Do:**

- Create the layout from the Phase 1 design: `bootstrap/home/`, `apps/`, `platform/`, each component with `base/` and `overlays/home/`.
- **Hand over from Talos to Argo CD** ([ADR 1039](adr/1039-bootstrap-through-talos-inline-manifests.md)): Argo CD is already running from step 2.2's inline manifests. Add **`platform/argocd/`** with the **same chart version and values**, so Argo CD adopts itself and manages its own upgrades. Applications use **auto-sync with self-heal** by default (Cilium and staging excepted), with **`ignoreDifferences`** for replica counts set by HPAs and KEDA. Add **`platform/cilium/`** with the **same values** as the inline manifest, so Argo CD adopts Cilium without changing it. Once both show `Synced` with no changes, **remove the Cilium and Argo CD inline manifests** from the machine config in `russetleaf-infra` (check first, in a local Talos-in-Docker cluster, that removing an inline manifest leaves its resources in place), so Talos's Kubernetes upgrades never roll them back. Set the Cilium Application to **manual sync** (a broken networking upgrade would stop Argo CD from syncing a revert), and write `docs/runbooks/rollback-cilium.md`: recover with `helm rollback cilium` from the workstation (the API server runs on the host network, so it stays reachable), then revert in Git. Test the procedure on a local kind or Talos-in-Docker cluster.
- `bootstrap/home/`: the root "app of apps" that creates one Argo CD Application per component, with **sync waves** (Cilium and the `prometheus-operator-crds` chart, from the prometheus-community Helm repository, first, then storage and secrets, then ingress, monitoring, operators, then apps).
- Expose the Argo CD UI only through Cloudflare Access (after step 4.3), or use `kubectl port-forward` until then.
- **Argo CD Notifications** to `#rl-deploys` (sync succeeded, sync failed, app degraded), using the Slack bot token. Until External Secrets exists (step 4.2), create the token Secret by hand; switch it to an `ExternalSecret` afterwards.
- **AppProjects** (platform, apps, staging) restricting each to its repos, namespaces and resource kinds, with **orphaned-resource warnings** on, so objects Argo CD does not own are flagged ([ADR 1034](adr/1034-kubernetes-threat-model-coverage.md)); Argo CD Notifications sends them to `#rl-security` once that channel's routing exists.
- CI: render every component's home overlay (Helm/Kustomize), validate with `kubeconform`, and run **Checkov on the rendered manifests** (what Argo CD would actually apply).

**Test:** after removing the inline manifests, Cilium and Argo CD are unchanged and still `Synced`, and `talosctl upgrade-k8s --dry-run` plans no changes to them; Argo CD shows the root app `Synced`/`Healthy` with a trivial test component; a sync posts to `#rl-deploys`; a ConfigMap created by hand in a managed namespace shows as orphaned; a pull request that breaks a manifest fails CI.

## Stage 4: Platform services (`russetleaf-gitops/platform/`)

Check `kubectl top nodes` after each step.

### Step 4.1: Storage

**Do:** `platform/storage/`: local-path-provisioner as the default (and only) StorageClass, using `/var/local-path-provisioner`, its namespace labeled for privileged pod security (Talos enforces "baseline" by default). No Ceph (Rook) or Longhorn: the design keeps important state in S3, and the database is replicated by MariaDB itself (step 4.5); see [ADR 1010](adr/1010-local-storage-no-ceph.md).

**Test:** a test PersistentVolumeClaim binds and a pod writes to it; the data survives the pod being deleted.

### Step 4.2: Secrets and internal certificates

**Do:** `platform/external-secrets/`: External Secrets Operator plus a `ClusterSecretStore` for AWS Secrets Manager.

- `platform/cert-manager/`: **cert-manager** and **trust-manager**, with an **internal CA** (a self-signed root issuing an intermediate, used by a ClusterIssuer); copy the root to the break-glass kit; trust-manager distributes the CA bundle to namespaces that need it. See [ADR 1028](adr/1028-internal-pki.md).
- **Bootstrap credential:** External Secrets needs one AWS key to start. Create it once by hand as a Kubernetes Secret from the Terraform output (document the exact command in the README, never commit it). Everything else comes from Secrets Manager.

**Test:** an `ExternalSecret` for a test value creates a Kubernetes Secret; changing the value in Secrets Manager updates it within the refresh interval; a test `Certificate` is issued by the internal CA and verifies against the distributed bundle.

### Step 4.3: Ingress and the Cloudflare Tunnel

**Do:**

- `platform/ingress/`: ingress-nginx (**2 replicas** spread across `rl-home-cp03` and `rl-home-cp01`, with a PodDisruptionBudget), with its **Prometheus metrics enabled** (the Argo Rollouts analysis in step 6.2 uses them).
- `platform/cloudflared/`: cloudflared Deployment (2 replicas, **spread across nodes**) using the tunnel token from External Secrets, routing `russetleaf.dev` and the admin hostnames to ingress-nginx.
- Put the Argo CD, Grafana and **Hubble UI** hostnames behind Cloudflare Access.

**Test:** a hello-world app at `https://russetleaf.dev` loads from outside the home network (e.g. on mobile data); the home routers have no open ports; the Argo CD hostname asks for a Cloudflare Access login.

### Step 4.4: Monitoring

**Do:** `platform/monitoring/`: kube-prometheus-stack (placed on `rl-home-cp03`): 15-day retention, 30 s scrape interval, resource limits on every part. Grafana behind Cloudflare Access. Then the alerting setup from the Phase 1 design:

- **Platform health alerts:** **etcd** (disk sync latency, leader changes, proposal failures; important on small nodes, and more so once `rl-home-cp02` runs the model in Phase 2; [ADR 1026](adr/1026-cpu-limits.md)), **`ArgoCDAppOutOfSync`** (an app out of sync or degraded for 15 minutes, from Argo CD's metrics), and **certificate expiry** (cert-manager), each with a runbook.
- **Kubelet scraping verifies TLS** against the cluster CA (no `insecureSkipVerify`, now that the kubelets have CA-signed serving certificates), and the **certificate expiry alerts** are on: kubelet client and serving certificate lifetimes, and kube-prometheus-stack's API server client-certificate expiry alerts ([ADR 1035](adr/1035-platform-security.md)).
- Prometheus external labels `site=dev`, `cluster=rl-home`; `serviceMonitorSelectorNilUsesHelmValues: false` (and the PodMonitor and rule equivalents) so Prometheus finds ServiceMonitors in every namespace.
- **Cilium and Hubble metrics:** in `platform/cilium/` values, turn on the agent, operator and Hubble metrics and their **ServiceMonitors**, the Hubble metric set (`dns`, `drop`, `tcp`, `flow`, `port-distribution`, `httpV2` with a small label set), and the Cilium and Hubble **Grafana dashboards** (written to the `monitoring` namespace for Grafana's sidecar). Add the Cilium alert rules (`CiliumAgentNotReady`, `HubblePolicyDropsSpike`, `CiliumEndpointRegenerationFailing`, `HubbleDNSErrors`) with runbooks. Exact values are in the Phase 1 design ([Hubble and Cilium metrics in Prometheus](design.md#hubble-and-cilium-metrics-in-prometheus)).
- **Alertmanager → Slack** with the bot token from External Secrets: criticals to `#rl-critical` and `#rl-dev-alerts`; warnings to `#rl-dev-alerts`; `team=security|mlops|cost` alerts to their channels; `env=staging` alerts to `#rl-staging` only; grouping and repeat intervals; **inhibition rules** (site down suppresses its downstream alerts).
- **Dead man's switch:** route the always-firing `Watchdog` alert to the heartbeat service's URL; the heartbeat service alerts `#rl-critical` if pings stop.
- **blackbox_exporter** (in `platform/monitoring/`) with probes for key URLs inside the cluster; start with a test target, then add `/`, `/wp-login.php` and `/wp-json/` once WordPress exists (step 5.2).
- **External uptime check** for `https://russetleaf.dev` (Phase 3 adds russetleaf.com, expecting 200 or the 503 offline page).
- **Alerts as code:** a starter set of `PrometheusRule`s (site down, pod crash-looping, node memory high, disk filling, certificate/tunnel down, and **`KubeAPIRequestsRejected`** when the API server's Priority and Fairness rejects requests; [ADR 1034](adr/1034-kubernetes-threat-model-coverage.md)), each with `severity`, `summary`, `description` and `runbook_url`; a runbook for each in `docs/runbooks/`, written from `docs/runbooks/TEMPLATE.md`; `promtool test rules` in `russetleaf-gitops` CI.
- **Runbook structure:** every runbook follows `docs/runbooks/TEMPLATE.md` in `russetleaf-gitops`: a short header (alert name, severity, components, related ADRs), then **Summary**, **Symptoms**, **Impact**, **Checks** (the exact commands and queries), **Likely causes**, **Fixes** (each with its risk, whether it is reversible, and whether it is a Git change or a command), **Escalation** and **Related** (dashboards, postmortems). The consistent structure makes runbooks quick to follow under pressure, and lets Phase 2's AI assistant find and cite the right fix ([ADR 2007](../phase-2-ai-mlops/adr/2007-ai-diagnosis-and-remediation-proposals.md)).

**Test:** Grafana shows node and pod dashboards for all three nodes, plus the Cilium and Hubble dashboards with live data; Prometheus' targets page lists the Cilium agent, operator and Hubble endpoints as up; a test critical alert appears in both `#rl-critical` and `#rl-dev-alerts` with a working runbook link; stopping Alertmanager for longer than the heartbeat period makes the heartbeat service post to `#rl-critical`; a broken alert rule fails `promtool` in CI.

### Step 4.5: Database and cache

**Do:**

- `platform/mariadb/`: MariaDB Operator; a `MariaDB` instance pinned to the **same major version RDS offers** (e.g. 9.4 LTS), a `Database`, `User` and `Grant` for WordPress, with the password **generated by the operator** into a Kubernetes Secret (no External Secrets for the database). Same for the backup user and root.
- **Replication:** two MariaDB members with **primary–replica replication** and **automatic failover** (MariaDB Operator's replication mode), the primary preferring `rl-home-cp03` and the replica on `rl-home-cp01` (anti-affinity), a PodDisruptionBudget, and a Service that always points at the current primary. Backups run from the replica where the operator supports it.
- **TLS** turned on in MariaDB (certificates from the **internal CA**, step 4.2) and **required** for the `wordpress` user.
- The **`Backup`** to the backup bucket **every 6 hours** (logical, gzip, 14-day retention), and an alert (`severity=critical`, with a runbook) if the last successful backup is more than **7 hours** old. Replication covers a node failure; these backups cover disasters (data deleted or corrupted, or the home lab lost), with a recovery point of at most 6 hours.
- `platform/valkey/`: Valkey (single instance, no persistence needed for an object cache), with a **redis_exporter** sidecar and ServiceMonitor.
- **Database and cache metrics:** turn on MariaDB Operator's built-in metrics (mysqld-exporter sidecar and ServiceMonitor), and add alerts with runbooks (database down, connections near the limit, slow queries rising, Valkey memory near its limit).

**Test:** shut down the node running the MariaDB primary: the replica is promoted within about a minute and WordPress (once deployed) keeps working; when the node returns, it rejoins as a replica. Connect with a MariaDB client from a test pod using the generated Secret, and confirm a connection **without TLS is refused**; no database password appears in Git or Secrets Manager; trigger a backup by hand and see the file in S3; **restore it into a scratch MariaDB instance** and compare; `valkey-cli ping` returns `PONG`; MariaDB and Valkey metrics appear in Prometheus and on Grafana dashboards.

### Step 4.6: Logging (Loki + Alloy)

**Do:** `platform/logging/`, as described in the Phase 1 design ([Logging](design.md#logging-loki--alloy)):

- **Loki** in single-binary mode, storing data in the Loki S3 bucket (scoped key from External Secrets), a small local cache volume, **7-day retention**, the **ruler** sending alerts to Alertmanager.
- **Kubernetes audit logs:** Alloy also collects the **API server audit log** from `rl-home-cp01` (label `job=kube-audit`), and Loki's ruler gets the audit alerts from the Phase 1 design (`KubeExecIntoProdPod`, `KubeUnexpectedSecretRead`, `KubeRBACChangedOutsideArgoCD`, `KubeAnonymousOrForbiddenSpike`, `KubeAuditLogMissing`, and the persistence alerts `KubeWorkloadCreatedOutsideArgoCD`, `KubeAdmissionWebhookChanged` and `KubeTokenSecretCreated` from [ADR 1034](adr/1034-kubernetes-threat-model-coverage.md), with the controllers that create objects legitimately (operators, KEDA, Argo Rollouts, the HPA) on the expected-identity list), routed to `#rl-security` with runbooks. Argo CD's service account is the expected source of production changes.
- **Grafana Alloy** DaemonSet: an **OTLP receiver** for traces (forwarding to Tempo once it exists; until then traces are dropped); collect all container logs; labels `site=dev`, `env`, `cluster`, `namespace`, `app`, `container` only; drop debug lines and health-check access logs; mask tokens and passwords in query strings; a host port receiving **Talos system logs**.
- In `russetleaf-infra/envs/home`, point Talos's machine logging at Alloy's host port on each node.
- A narrow Kyverno **`PolicyException`** for Alloy (host paths for log files, the host port).
- **Two Loki tenants ([ADR 1035](adr/1035-platform-security.md)):** `apps` (application and platform logs) and `security` (API audit log, Argo CD audit events, and later Falco and Tetragon events), set by Alloy per log source. Grafana gets a separate **Security organization** holding the `security` data source and security dashboards, with only the **platform-admin** group as members (mapped from Dex groups once step 4.7 is done). Network policies allow only Grafana, Alloy and the ruler to reach Loki.
- Loki as a Grafana data source, with links from dashboards to logs; starter log-based alerts (`LokiIngestionErrors` now; the WordPress ones are added in step 5.2; Phase 2 adds the summarizer and Bedrock ones) with runbooks.
- **Audit-log archive ([ADR 1033](adr/1033-identity-and-access.md)):** Alloy also writes the API server audit log to the **Log Archive** account's Object Lock bucket (a write-only role), kept **1 year**, so the audit trail outlives Loki's 7 days and cannot be changed from the home cluster.
- **Argo CD audit events:** collect Argo CD's API server logs (who synced, changed or deleted which Application) with the label `job=argocd-audit`.
- Record memory use in the checklist, and daily log volume and memory after a week in [ADR 1005](adr/1005-loki-alloy-for-logs.md).

**Test:** in Grafana, logs from every namespace and from the Talos nodes (kubelet, etcd) are searchable by `namespace` and `app`; `kubectl exec` into a production pod fires `KubeExecIntoProdPod`, editing a RoleBinding by hand fires `KubeRBACChangedOutsideArgoCD`, and a CronJob created by hand in a production namespace fires `KubeWorkloadCreatedOutsideArgoCD`; a deleted pod's logs are still there; signed in as operator, Grafana shows application logs but not the audit log; a secret in a test log line is masked; the day's audit log appears in the Log Archive bucket and cannot be deleted; a manual sync in Argo CD shows up with the user's name; stopping Loki fires `LokiIngestionErrors` in `#rl-dev-alerts`; objects older than the retention period are removed from the bucket.

### Step 4.7: Cluster access: OIDC sign-in, roles and SSO

**Do:** as described in the Phase 1 design's [Identity and access to the clusters](design.md#identity-and-access-to-the-clusters) ([ADR 1033](adr/1033-identity-and-access.md)):

- **Dex** in `platform/dex/` with the **Google connector** (a separate Google OAuth client from the WordPress one), its client secret from External Secrets, behind the tunnel with Cloudflare Access in front.
- **API server OIDC:** in `russetleaf-infra/envs/home`, a Talos patch adding a **structured authentication configuration** that trusts Dex (issuer, audience, username and group claims with an `oidc:` prefix); install **kubelogin** on the workstation (pinned in `.mise.toml`) and switch the daily kubeconfig to it.
- **Roles** in `platform/rbac/`: ClusterRoles **platform-admin**, **operator** (read everything, restart and scale workloads, no Secrets) and **read-only** (no Secrets), bound to Dex groups; the daily login is **operator**, platform-admin only when needed.
- **Break-glass:** the Talos-generated admin kubeconfig goes into the break-glass kit only and is removed from the workstation; a Loki rule **`KubeBreakGlassAdminUsed`** fires in `#rl-security` whenever the admin certificate's identity appears in the audit log.
- **Talos access:** a day-to-day talosconfig with the **`os:reader`** role; the `os:admin` talosconfig moves to the break-glass kit.
- **SSO** through Dex for **Argo CD** (its RBAC mapped to the same groups; local admin disabled) and **Grafana** (roles mapped from groups); Backstage uses it when added in step 8.3.

**Test:** `kubectl` prompts for Google sign-in and the operator login can restart a Deployment but cannot read a Secret or change a ClusterRole; a Google account outside the allowed group is refused; Argo CD and Grafana sign in through Dex with the right role and their local admin logins are off; using the break-glass kubeconfig works and fires `KubeBreakGlassAdminUsed`; `talosctl` with the daily talosconfig can read logs but not reboot a node.

## Stage 5: WordPress

### Step 5.1: The WordPress image (`russetleaf-wordpress`)

**Do:**

- `Dockerfile` based on the official `wordpress` image (pinned version), with plugins and themes pinned in **`composer.json` through WPackagist** (so Renovate can update them) and installed with Composer at build time: an S3 media offload plugin (see the comparison below), Redis Object Cache, an SMTP plugin (configured for Amazon SES). WordPress code is copied into `/var/www/html` **at build time**, so the image's startup script has nothing to copy at runtime.
- **WPScan:** run it in CI (free API token stored as a GitHub secret) against the plugins and themes in `composer.json`, failing the build on a known vulnerability, plus a **weekly scheduled run** that alerts `#rl-security`. Also schedule a **weekly rebuild** of the image so base-image OS patches are picked up even without code changes.
- **Choose the S3 offload plugin** (see [Media storage: S3, not EFS](design.md#media-storage-s3-not-efs-by-decision)). Try both in the Compose setup against LocalStack (or MinIO) and record the choice in the decision log:
    - **S3-Uploads** (Human Made, open source): uploads go **directly to S3**, so no writable uploads directory is needed. Preferred if it works with a custom S3 endpoint (for the ci stand-ins) and with CloudFront as the media URL.
    - **WP Offload Media Lite**: writes locally first, then copies to S3; needs a writable uploads `emptyDir`.
    - Check for both: upload, image resizing (thumbnails), deleting media, and the media URL pointing at the right place (S3 at home, CloudFront on AWS).
- **Finish [ADR 1002](adr/1002-s3-media-not-efs.md)** (already drafted): fill in its open item with the plugin chosen and why, and whether the uploads `emptyDir` is needed.
- **Lean final image:** no download tools (`curl`, `wget`) or package managers in the final image where practical (keep what the official image's startup script needs); container-structure-test checks they are absent.
- **Built to pass the Kyverno policies from step 6.1:** Apache runs as **`www-data`** listening on **port 8080** (non-root cannot use port 80), and the container works with a **read-only root filesystem** given writable `emptyDir` volumes for `/tmp`, Apache's run and lock directories, PHP sessions, and the uploads directory only if the chosen plugin needs it. Test both in the Compose smoke test.
- `wp-config` settings read from environment variables (database, Valkey, S3, `WP_HOME`/`WP_SITEURL`, `DISALLOW_FILE_MODS`, `DISABLE_WP_CRON`), with **TLS to the database** turned on.
- A **`db.php` drop-in** whose behavior is chosen by the chart setting **`database.auth`**. Build only the **`password`** mode now (reads the password from a Secret, connects over TLS); it is what the home lab uses, and it is the AWS fallback too. Leave a clear extension point for an **`iam`** mode, which is written in Phase 3, **only after** its early test (Phase 3 step 1.6) shows that PHP can log in to RDS Proxy with an IAM token. That way no work is wasted if the test fails. Add the **RDS CA certificate bundle** to the image now (harmless at home, needed on AWS).
- The **metrics must-use plugin** (`mu-plugins/metrics/`), as described in the Phase 1 design ([WordPress monitoring](design.md#wordpress-monitoring)): `wordpress_cron_overdue_events`, `wordpress_object_cache_hit_ratio`, `wordpress_info`, and simple counts, served on a **separate internal port** (a second Apache listener, e.g. 9117), cached for about a minute. Also turn on Apache's `mod_status`, reachable from localhost only (for the apache_exporter sidecar). Unit-test the output format.
- **OpenTelemetry tracing, built in but off by default:** the OpenTelemetry **PHP extension** and **Composer packages** (SDK, OTLP exporter, and auto-instrumentation for WordPress, database access and HTTP calls; check current package names in the OpenTelemetry PHP contrib project). **No WordPress plugin** is needed; it is switched on by environment variables (`OTEL_PHP_AUTOLOAD_ENABLED`, `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT`, sampler settings) set in the chart values. Include trace IDs in WordPress's log lines.
- **WordPress hardening must-use plugins:** `harden-users` (block anonymous user enumeration through author archives and the REST `users` endpoint) and `security-headers` (Content-Security-Policy in **report-only** mode at first, plus headers not set at the edge); **auth keys and salts** read from Secrets Manager (via environment-free files), with a documented rotation.
- **Hash-pinned dependencies:** `composer.lock` committed and installed with `composer install` (never `update`) in the build.
- **Chart signing:** the release workflow signs the chart (OCI) with cosign and verifies it; `packages: write` and signing permissions only in the release job.
- **XML-RPC disabled** inside WordPress (a must-use plugin returning `false` from the `xmlrpc_enabled` filter), as well as being blocked at the edge.
- `tests/`: a smoke test (Docker Compose with MariaDB: the container starts, plugins are active, health check passes).
- `chart/`: the WordPress Helm chart (see step 5.2 for what it deploys), versioned with the image.
- CI, following the Phase 1 design's [Image build pipeline](design.md#image-build-pipeline-russetleaf-wordpress-russetleaf-llm-summarizer): **pull requests:** gitleaks, **hadolint**, **PHP_CodeSniffer with the WordPress Coding Standards** and **PHPStan** (for the must-use plugins and `db.php`), **Semgrep**, `composer audit`, dependency review, **Checkov** (Dockerfile, chart), **zizmor**, `helm lint` / `ct lint`, build, **container-structure-test** (non-root, port 8080, expected files), **Trivy** (vulnerability, secret and misconfiguration scanners; failing on critical vulnerabilities and any secret; `.trivyignore` with reasons and expiry dates), Trivy's **CIS Docker Benchmark** compliance check on the built image ([ADR 1036](adr/1036-compliance-frameworks-and-privacy.md)); **release:** push the image and chart (OCI) to GHCR **by digest** with an immutable version, sign (cosign keyless), **attach the SBOM as a signed attestation** (`cosign attest`, SPDX JSON), add **SLSA build provenance** (`actions/attest-build-provenance`), with the build running in a **reusable workflow** (a shared build workflow the release workflow calls) so the provenance reaches SLSA Build Level 3 as GitHub documents it (Level 2 otherwise), **verify** all three on the pushed digest (`cosign verify`, `cosign verify-attestation`, `gh attestation verify`), and write release notes with the digests and **Rekor** log links.

- **GHCR package settings ([ADR 1035](adr/1035-platform-security.md)):** each package linked to its repo, with write access only for that repo's Actions; no personal access tokens with `write:packages`. A monthly **cleanup workflow** deletes untagged versions older than 90 days, but never a digest referenced in `russetleaf-gitops` in the last 90 days or one of the last 10 releases, keeping signatures and attestations with their images (dry run first).
- **VEX:** accepted vulnerabilities go in **OpenVEX** statements in `.vex/` (justification and review date each), read by Trivy in CI (`--vex`) and attached to the image as a signed attestation; `.trivyignore` holds only secret and misconfiguration findings.
- **Make each GHCR package public at first push** (package visibility is separate from the repo's, and starts private): no pull secrets, no private-package storage limit (ADRs [1004](adr/1004-ghcr-not-ecr.md) and [1030](adr/1030-github-actions-ci.md)). Only if a package must stay private: a `read:packages` GitHub token in Secrets Manager, synced into an image pull secret and Argo CD's OCI credentials, plus a retention step deleting old untagged versions.

**Test:** the smoke test passes locally and in CI; `cosign verify` succeeds for the pushed image, and `cosign verify-attestation --type spdxjson` returns its SBOM; `gh attestation verify` confirms its provenance; a CVE listed as `not_affected` in `.vex/` no longer fails Trivy, and `cosign verify-attestation --type openvex` returns the VEX document; the cleanup workflow's dry run lists only unreferenced versions; the release notes link to the Rekor entries (check one with `rekor-cli`); a deliberately vulnerable PHP snippet (e.g. unescaped output) fails PHPCS or Semgrep; a secret written into an image layer fails Trivy; the cluster can pull the image and Argo CD can pull the chart (with credentials if the packages are private); the package's storage use is well under the free limit, or old untagged versions are being deleted; publishing a post in the local Compose setup sends a message to the real SQS queue.

### Step 5.2: WordPress chart and deployment (`russetleaf-gitops/apps/wordpress/`)

**Do:**

- The `russetleaf-wordpress` chart, which sets the pod security context (non-root user, read-only root filesystem, no privilege escalation, dropped capabilities, **seccomp `RuntimeDefault`**, and an optional `runtimeClassName` used in step 6.5), the `emptyDir` volumes above, **readiness and liveness probes**, the required labels (`app.kubernetes.io/name`, `app.kubernetes.io/part-of`, `env`) and **CPU/memory requests with a memory limit (no CPU limit)**, deployed from `russetleaf-gitops` with the home overlay (values only): russetleaf.dev hostname, MariaDB and Valkey hosts, `database.auth: password` pointing at the **MariaDB Operator-generated Secret**, media bucket and queue settings, other credentials from External Secrets, resources, `persistence` off, WP-Cron as a Kubernetes CronJob.
- **Secrets as files:** database, SMTP and other credentials mounted as files, not environment variables; **user namespaces** (`hostUsers: false`) on the WordPress pods if step 2.2 confirmed support.
- **Replicas and spreading:** WordPress runs **2–3 replicas** spread across `rl-home-cp03` and `rl-home-cp01` (topology spread or anti-affinity) with a PodDisruptionBudget, so a node failure or a rolling upgrade never takes the site down.
- Remove the old test Application and the `wordpress-test` namespace.
- First-run setup (admin user, plugin settings) done by a one-off `wp-cli` Job or wp-config constants, so a rebuild needs no clicking.

- **Monitoring in the chart:** an **apache_exporter** sidecar; a `ServiceMonitor` for the exporter and the metrics port; `PrometheusRule` alerts with runbooks (`WordPressCronBacklog`, `WordPressObjectCacheHitRatioLow`, `WordPressApacheWorkersSaturated`, `WordPressSyntheticProbeFailing`; Phase 2 adds `WordPressPostsMissingSummaries`), plus the log-based `WordPressPHPFatalErrors` alert in Loki; a CiliumNetworkPolicy rule letting only Prometheus reach the metrics port. Add the WordPress URLs to the blackbox_exporter probes.

**Test:** `https://russetleaf.dev` serves WordPress; an uploaded image lands in the S3 bucket and displays; the Redis Object Cache plugin shows "connected"; killing the WordPress pod loses nothing; WP-Cron jobs run from the CronJob; a password-reset email arrives through SES; Prometheus scrapes the apache_exporter and the custom metrics; the metrics port is **not** reachable through `https://russetleaf.dev` or from a non-Prometheus pod; the blackbox probes are green.

### Step 5.3: Image promotion

**Do:** create the GitHub App; the `russetleaf-wordpress` release workflow opens a pull request on `russetleaf-gitops` that changes only the chart and image version in `apps/wordpress/overlays/home`, linking the release notes. (Step 5.7 later points this at staging first.)

**Test:** merge a trivial change in `russetleaf-wordpress` → a signed image is pushed → a bump pull request appears in `russetleaf-gitops` → merging it rolls out the new image, and the rollout appears in `#rl-deploys`. Subscribe `#rl-deploys` to the four repos' releases and merged pull requests with the GitHub Slack app.

### Step 5.4: ci test clusters (kind + AWS stand-ins)

**Do:**

- `russetleaf-wordpress/ci/`: a kind cluster config and `ci` chart values (LocalStack, or MinIO + ElasticMQ, per step 0.2; a MariaDB and Valkey installed into the kind cluster; test credentials).
- Integration tests (e.g. a shell or Python test script run after `helm install`): the site installs and loads; an upload lands in the stand-in S3 bucket.
- A pull request workflow on **GitHub-hosted** runners: create the kind cluster (`helm/kind-action`), load the freshly built image, install the chart with `ct install` or `helm install`, run the tests, collect logs on failure.
- `compose.yaml` for the **local** environment: WordPress + MariaDB + Valkey + LocalStack, so the same checks can be run by hand.
- In `russetleaf-gitops` CI: install changed **platform** components into a kind cluster to check they start (where they can run without the real cluster's dependencies).

**Test:** a pull request in `russetleaf-wordpress` runs the kind tests and passes; a deliberately broken change (e.g. a wrong S3 setting) fails them; `docker compose up` gives a working local site.

### Step 5.5: Self-hosted runners (ARC)

**Do:** `platform/actions-runner-controller/`: ARC with **ephemeral** runners, placed on `rl-home-cp02`, off the main nodes (in Phase 2 they tolerate `rl-home-cp02`'s LLM taint and run next to the model). Start with runner scale sets for **`russetleaf-gitops`** (the staging workflow) and **`russetleaf-infra`** (home Terraform applies, and later the AWS demo workflows, so the EKS API can be restricted to the home address; [ADR 1030](adr/1030-github-actions-ci.md)); `russetleaf-llm-summarizer` gets its own in Phase 2. Give the runners **CPU limits** so they always leave at least one core free for etcd on `rl-home-cp02` ([ADR 1026](adr/1026-cpu-limits.md)). Because the repos are public: require approval for workflows from fork pull requests, and limit which workflows can use the self-hosted label.

**Test:** a test workflow in `russetleaf-gitops` runs on a self-hosted runner pod, which is deleted afterwards; a fork pull request waits for approval.

### Step 5.6: On-demand staging

**Do:**

- `overlays/home-staging` for WordPress (1 replica, `staging.russetleaf.dev`, no Valkey), a small staging **MariaDB** (MariaDB Operator, with its own generated passwords), and the staging AWS resources and secrets from step 2.3. Label everything `env=staging`.
- Staging Argo CD Applications in their own **Argo CD project**, with **auto-sync off**, so nothing runs until a test starts.
- `apps/staging-data/`: a Job that downloads the latest russetleaf.dev production backup from S3, imports it into the staging MariaDB, and **scrubs personal data** (user emails replaced with `user<ID>@example.invalid`, commenter names/emails/IPs cleared, application passwords and sessions deleted), then runs `wp search-replace 'russetleaf.dev' 'staging.russetleaf.dev'`.
- **DAST:** an OWASP **ZAP baseline scan** of staging, failing the staging test on high-risk findings (and reporting the Content-Security-Policy violations collected so far).
- `apps/smoke-tests/`: a Job that checks the home page and sample posts load, an upload goes to the staging bucket (Phase 2 adds a check that a published post gets a summary).
- An Argo CD account with RBAC limited to the staging project (sync and delete only); its token in Secrets Manager.
- The **`staging-test`** workflow (on the ARC runners): sync staging → wait for healthy → run `staging-data` → run `smoke-tests` → soak ~30 minutes checking Prometheus for errors and restarts → record results → **delete** the staging Applications with cascade (volumes included) → post results to `#rl-staging`.

**Test:** run `staging-test` by hand: staging comes up at `staging.russetleaf.dev` (behind Cloudflare Access), shows production posts with **no real email addresses** in the database, passes the smoke tests, and is fully removed afterwards (`kubectl get all,pvc -n <staging namespaces>` is empty). Record the nodes' peak memory during the run in the checklist.

### Step 5.7: Promotion pipeline (staging → prod)

**Do:**

- Change the `russetleaf-wordpress` release bot (step 5.3) to bump **`overlays/home-staging`** instead of prod, with **auto-merge** once `russetleaf-gitops` CI passes.
- Trigger `staging-test` on pushes to `main` that change a staging version.
- **Schema changes:** CI in `russetleaf-wordpress` compares WordPress's database version (`$wp_db_version`) between the old and new images (and plugin release notes flag schema changes), labeling such releases **`schema-change`**. For those, the promotion workflow runs an **on-demand MariaDB backup** and waits for it to succeed before the prod pull request can be merged; the rollback runbook explains restore-and-roll-back versus fix-forward.
- Version bumps pin **charts by digest** (not just version), and CI **verifies the chart's signature** before the pull request is opened.
- On a pass, a **`promote-to-prod`** job opens a pull request bumping the same version in `overlays/home` (and `overlays/aws` once it exists), with the staging results attached. On a failure, post to `#rl-staging` and `#rl-deploys` and promote nothing.

**Test:** a release that changes `$wp_db_version` is labeled `schema-change` and its prod pull request is blocked until the pre-release backup succeeds; release a trivial `russetleaf-wordpress` change → it auto-merges to staging → `staging-test` passes → a promotion pull request appears with results → merging it rolls out to russetleaf.dev. Release a deliberately broken version → staging fails → no promotion pull request, and `#rl-staging` shows why.

### Step 5.8: Google sign-in for admins

**Do:** as described in the Phase 1 design ([Admin sign-in with Google](design.md#admin-sign-in-with-google)):

- **Google Cloud:** a project with an OAuth consent screen (basic scopes only: `openid`, `email`, `profile`), and OAuth clients for **russetleaf.dev** (with staging.russetleaf.dev as a second redirect URL) and **local testing**. Document them in `russetleaf-infra`'s README; store the client secrets in Secrets Manager.
- **`russetleaf-wordpress`:** add an OIDC client plugin (e.g. "OpenID Connect Generic Client"; check it is maintained and can be configured entirely from constants or environment variables) to `composer.json` (WPackagist). Configure it from chart values: Google's endpoints, client ID and secret (External Secrets), the **allow-list** of email addresses, and automatic account linking for allowed emails only.
- **Turn off password logins for people**, while keeping **application passwords** for the REST API (the staging smoke tests, and from Phase 2 the summarizer, depend on them).
- **Edge layer:** a Cloudflare Access application covering `/wp-admin/*` and `/wp-login.php` on russetleaf.dev and staging, using Google.
- **CiliumNetworkPolicy:** allow WordPress → Google's login endpoints by DNS name.
- **ci:** a mock OIDC provider (e.g. Dex) in the kind cluster, with a test that signs in through it.
- **Break-glass:** a documented `wp-cli` procedure (a one-off Job) to recover admin access without re-enabling passwords; add it to `docs/runbooks/`.
- Finish [ADR 1008](adr/1008-google-sign-in-for-admins.md) with the plugin chosen.

**Test:** visiting `/wp-admin` from outside first requires a Cloudflare Access Google login; an allowed Google account then signs in to WordPress with no password; a Google account not on the allow-list is refused; a username/password login attempt is rejected; a REST API request with an application password still works; the ci sign-in test passes; the break-glass procedure works in staging.

### Step 5.9: Performance testing and regression gate

**Do:** as described in the Phase 1 design's [Performance and stress testing](design.md#performance-and-stress-testing): k6 scripts in `russetleaf-gitops/perf/` (home page, posts, search, REST API, admin sign-in through the test identity provider) with thresholds in code; `platform/k6-operator/` for distributed in-cluster tests against the ingress (CiliumNetworkPolicy limiting targets to the ingress; images on the Kyverno allow-list); k6 results to Prometheus and a Grafana dashboard beside system metrics. Run a **load test** against production at a quiet time and record the **baseline** in `docs/performance/` (for trends and the capacity plan). Add the **regression gate** to `staging-test`: load-test the **current production version and the candidate back to back in staging**, three runs each, comparing **medians**; fail promotion if the candidate is more than about 20% slower or over the error threshold; **wait** while `rl-home-cp02` is busy with a summarization burst or a stress test is running, to avoid false failures. See [ADR 1024](adr/1024-performance-and-stress-testing.md).

**Test:** the baseline exists; a deliberately slowed release (e.g. an artificial delay in a must-use plugin) fails the staging gate with the comparison in the promotion pull request; a normal release passes.

### Step 5.10: Site design and brand

**Do:** as described in the Phase 1 design's [Site design and branding](design.md#site-design-and-branding) and [ADR 1025](adr/1025-site-design-in-git.md):

- Write a short **design brief** (audience, tone, colors, the russet-leaf idea, a few reference sites).
- **Logo design:** create the RussetLeaf logo (a mark plus wordmark) as **SVG**, with Claude writing the SVG directly or an image generator for concepts followed by vectorizing; derive the **favicon set**, site icon, Apple touch icon and **Open Graph image**, and a color **palette** from it; store them in `russetleaf-wordpress/brand/`. Check generator terms, AI-image copyright limits and a quick trademark search for "RussetLeaf" before publishing.
- With Claude, generate the **`russetleaf` block theme** from the brief: `theme.json` (palette from the logo, typography, spacing, dark-mode variant), templates (home, post, page, archive, 404) and patterns (hero, post cards, "about this project" linking the repos and ADRs). Iterate locally (Docker Compose) with screenshots.
- **Export** with the Create Block Theme plugin (locally only) into `russetleaf-wordpress/themes/russetleaf/`, and make it the active theme in the chart values.
- A **`lock-site-editor`** must-use plugin removing template and global-style editing in production.

**Test:** russetleaf.dev and staging show the custom theme, logo, icons and share image (check a link preview); in production, the Site Editor cannot change templates or styles; the theme comes entirely from the image (no design data in the database).

### Step 5.11: Front-end quality gates

**Do:** in `russetleaf-wordpress` CI and the staging gate: **Playwright** visual regression tests of key pages (home, a post, an archive, light and dark mode, mobile and desktop) against approved baselines; **axe-core** accessibility checks on the same pages (fail on serious issues); **Lighthouse CI** budgets (page weight, Largest Contentful Paint, total blocking time).

**Test:** a deliberate layout change fails visual regression until its new baseline is approved; removing an image's alt text fails accessibility; adding a large unoptimized image fails the Lighthouse budget.

### Step 5.12: Compliance scope and privacy (GDPR basics)

**Do:** as described in the overview's [Compliance and privacy](../overview.md#compliance-and-privacy) ([ADR 1036](adr/1036-compliance-frameworks-and-privacy.md)):

- `docs/security/compliance.md`: which frameworks apply (GDPR lightly, CIS, NIST guidance, MITRE ATT&CK) and which do not, with reasons (HIPAA: no health data; PCI DSS: no card data, and a hosted payment page if a shop is ever added).
- A **privacy notice** page in the `russetleaf` theme (who runs the site, what is collected, why, how long, which processors, how to make a request), linked from every footer and the comment form.
- `docs/privacy/record-of-processing.md`: each kind of personal data (commenters' names and emails, visitors' IPs in logs, admins' Google accounts, anything in Slack alerts), where it is stored, why, and for how long; the **processors list** (Cloudflare, AWS, Google, GitHub, Slack) with their data processing terms; the **retention schedule** (logs 7–14 days, backups 30 days locked plus lifecycle, audit logs 1 year, unapproved comments deleted after 30 days by a scheduled WP-Cron task).
- Runbooks: `docs/runbooks/data-subject-request.md` (WordPress's built-in **personal data export and erasure tools**; locked backups expire on their own; an **erasure log** re-applied after any restore) and `docs/runbooks/personal-data-breach.md` (assess, contain, record; notify the supervisory authority within **72 hours** if required), linked from the security alerts' runbooks.
- **No tracking cookies:** a Playwright check in `russetleaf-wordpress` CI and the staging gate that anonymous views of the home page and a post set **no cookies** and load **no third-party scripts**.

**Test:** the privacy notice is linked from every page and the comment form; an export request for a test commenter returns their data, and an erasure removes it (and the erasure log has the entry); adding a script that sets a cookie fails CI.

## Stage 6: Policy and progressive delivery

### Step 6.1: Kyverno

**Do:** `platform/kyverno/`: Kyverno plus the policy set from the Phase 1 design ([Supply chain and policy](design.md#supply-chain-and-policy)), all in **audit mode** first:

- **Signed images** (`verifyImages`): images signed by the `russetleaf-wordpress` release workflow (cosign keyless, GitHub OIDC issuer, subject matching the repo's workflow; Phase 2 adds `russetleaf-llm-summarizer`'s identity), with **`mutateDigest`** so tags are pinned to digests at admission
- **SBOM attestations:** the project's own images must also carry a signed SBOM attestation from the same workflow
- **Build provenance:** they must also carry the **SLSA provenance** attestation from GitHub's attestation action, issued to the project's **reusable build workflow** (confirm Kyverno's support for GitHub attestation bundles; start in audit mode)
- **Signed upstream images:** for each third-party publisher that signs its images with cosign (check Kyverno, Cilium and the others in the stack; record which do in the decision log), verify the signature against **that publisher's** release identity. Start each in audit mode. **Exclude Kyverno's own namespace** from image verification so Kyverno can always start.
- **Restrict Image Registries:** `ghcr.io/<owner>/*` plus an explicit list of the upstream registries the platform charts use (include init and ephemeral containers)
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
- **Secrets Not From Env Vars** and (if supported) a **`hostUsers: false`** requirement for application namespaces.
- **Mirrored third-party images:** a scheduled `mirror-images` workflow in `russetleaf-gitops` copying the critical upstream images by digest into GHCR (verifying publishers' signatures where they exist, then re-signing); the registry allow-list and image references point at the mirror.
- **Pod Security Admission labels** on every namespace (`restricted` for application namespaces; `baseline` for platform services; `privileged` only for Cilium, Falco, Alloy and the storage provisioner), set in each namespace's manifest with **`enforce-version` pinned** to the cluster's Kubernetes minor version (bumped deliberately during upgrades), and a Kyverno rule requiring the labels.
- **Kyverno's Pod Security `restricted` set** for application namespaces (alongside PSA), and a **mutate rule turning off service-account token mounting** by default (`automountServiceAccountToken: false`), with an allow-list for workloads that call the Kubernetes API (operators, Argo CD, External Secrets; KEDA in Phase 2).
- **Namespace quotas:** a generate rule giving every application namespace a **LimitRange** (default requests and memory limits, and default **ephemeral-storage** requests and limits) and a **ResourceQuota** (total CPU requests, memory, ephemeral storage, pod count); HPAs and KEDA objects set maximum replicas.
- **Kyverno resilience ([ADR 1035](adr/1035-platform-security.md)):** the **admission controller runs three replicas** spread across the nodes, with a PodDisruptionBudget; security policies **fail closed** (`failurePolicy: Fail`) with short webhook timeouts (e.g. 5 seconds).
- **ValidatingAdmissionPolicy backstop:** built-in Kubernetes policies (CEL, no webhook) for images only from the allowed registries, no `cluster-admin` bindings outside the allow-list, and no long-lived token Secrets, so these hold even if Kyverno is down.
- **Webhook exclusions and recovery:** Kyverno's webhooks exclude `kube-system`, `kyverno` and `argocd`, so Argo CD and Kyverno itself can always be repaired; write `docs/runbooks/rollback-kyverno.md` (revert in Git; in an emergency, delete Kyverno's webhook configurations so deployments go through, and let Kyverno recreate them once healthy).
- **`PolicyException`s**, each naming the exact namespace and workload, only where needed: Cilium, Falco, local-path-provisioner (privileged/host access); upstream images that cannot run read-only or as non-root (e.g. some operators, if so). The project's own workloads get **no** exceptions.
- **No risky RBAC ([ADR 1034](adr/1034-kubernetes-threat-model-coverage.md)):** a validate rule rejecting Roles and ClusterRoles with `escalate`, `bind` or `impersonate`, access to `nodes/proxy`, or wildcard verbs or resources, and bindings to `cluster-admin`, except a named allow-list (Kubernetes' own roles, Argo CD, `platform-admin`, and third-party components that need them, each with a reason); and a rule rejecting **long-lived service-account token Secrets**. Start in audit mode: third-party charts are the likely violations.
- **Kubescape RBAC check in CI:** `russetleaf-gitops` CI runs Kubescape's RBAC controls on the rendered manifests, so a chart upgrade that adds a risky permission fails the pull request or needs an entry in `docs/security/rbac-accepted.yaml`.
- Policy tests with `kyverno test` (a passing and a failing example per policy), run in `russetleaf-gitops` CI.

- **Policy Reporter** (Kyverno's reporting add-on) sending new policy violations to `#rl-security`.

Review the policy reports, fix violations, then switch to **enforce**.

**Test:** a pod requesting extra capabilities or privilege escalation is rejected in an application namespace (by both PSA and Kyverno); a WordPress pod has no service-account token mounted; a new application namespace automatically gets its LimitRange and ResourceQuota, and a Deployment scaled beyond the quota stops at the limit; in enforce mode, each of these is rejected: an unsigned image, a project image that is signed but has **no SBOM attestation** or **no provenance attestation**, an image from a verified upstream registry that **is not signed by that publisher** (e.g. a different project's image under the same registry), an image from an unlisted registry, a `:latest` image, a pod without the required labels (where the mutate rule cannot fill them), a container without a memory limit, a privileged pod, a root container, a writable root filesystem, a Deployment without probes, a NodePort Service, an Ingress reusing an existing host and path, a Role granting `impersonate`, and a `kubernetes.io/service-account-token` Secret. Running pods show image digests rather than tags. With Kyverno scaled to zero, a pod from an unlisted registry is still rejected by the ValidatingAdmissionPolicy; draining one node leaves Kyverno answering. The existing workloads keep running; Policy Reporter shows no unexplained violations; a pull request that violates a policy fails CI.

### Step 6.2: Argo Rollouts

**Do:** `platform/argo-rollouts/`; convert WordPress to a `Rollout` with canary steps (e.g. 20% → 50% → 100%) and an `AnalysisTemplate` that queries Prometheus (ingress-nginx error rate and latency for the WordPress service). Argo Rollouts notifications post canary steps, aborts and rollbacks to `#rl-deploys`.

**Test:** a good image rolls out step by step; a deliberately broken image (e.g. one that returns 500s) is **rolled back automatically**, and the rollback is announced in `#rl-deploys`.

### Step 6.3: CiliumNetworkPolicies

**Do:** use **CiliumNetworkPolicies**, not plain NetworkPolicies (see [Policies](design.md#policies-ciliumnetworkpolicies-not-plain-networkpolicies) in the Phase 1 design):

- A **`CiliumClusterwideNetworkPolicy`** baseline: default-deny for application namespaces, DNS to CoreDNS allowed with Cilium's **DNS proxy** on (needed for DNS-name rules), Prometheus scraping allowed.
- Per-component **CiliumNetworkPolicies** in each component's `base/` (shared with the AWS site), with site-specific destinations in the overlays. Outbound traffic to AWS is allowed **by DNS name** (`toFQDNs`): WordPress → S3, SES and STS endpoints; MariaDB → S3 for backups; cloudflared → Cloudflare's tunnel endpoints. (Phase 2 adds the summarizer, gateway and llama.cpp policies, including a **layer-7** rule.)
- A **Kyverno generate rule** that gives every new application namespace the baseline allowances, so none is ever left open.
- **Platform namespaces too ([ADR 1033](adr/1033-identity-and-access.md)):** default-deny for `argocd`, `external-secrets`, `kyverno`, `monitoring`, `dex` and the operators, with least-privilege egress: Argo CD → GitHub and GHCR plus the API server; External Secrets → Secrets Manager and STS; operators → the API server only.
- CI: validate the policies against the Cilium CRD schemas, and exercise them in the ci kind cluster (install Cilium there too).
- Roll out one namespace at a time, watching `hubble observe --verdict DROPPED` for anything legitimate being blocked.

**Test:** from a test pod in another namespace, MariaDB is unreachable; from a WordPress pod, `curl https://example.com` is **blocked** while uploads to S3 still work; an **exfiltration test** (posting a file from each application pod to an unlisted destination) is blocked and shows in `hubble observe --verdict DROPPED`; from a pod in `argocd`, a request to an unlisted site is blocked while syncs still work; a burst of blocked requests triggers `HubblePolicyDropsSpike` in `#rl-security`; the site, backups and monitoring all still work.

### Step 6.4: Service mesh decision (ADR) and optional Istio experiment

**Do:**

- Finish [ADR 1001](adr/1001-no-service-mesh.md) (already drafted; review it and resolve its open items as they are done): what a mesh like Istio would add, how Cilium (WireGuard, layer-7 policies, Hubble), Argo Rollouts and LiteLLM already cover it, the memory and complexity cost on a small cluster, and **when it would be revisited** (many more services, a requirement to verify service identity on every connection, multi-cluster traffic). See [Service mesh (Istio): not used, by decision](design.md#service-mesh-istio-not-used-by-decision).
- **Optional experiment (local only):** in a kind cluster on the workstation running Cilium, install **Istio ambient mode** (following Istio's instructions for running alongside Cilium), deploy the WordPress chart with test values, and enable mTLS and one layer-7 authorization policy. Record memory use, setup issues and what it added in the ADR. Delete the cluster afterwards; nothing in either site depends on it.

**Test:** the ADR is reviewed and linked from the hub README and the decision log; if the experiment was run, its findings are in the ADR.

### Step 6.5: Sandboxed runtime (gVisor)

**Do:** as described in the Phase 1 design ([Sandboxed runtimes](design.md#sandboxed-runtimes-gvisor)):

- Confirm the gVisor extension is active on all three nodes (step 2.2), and add `platform/runtime-classes/` with a **`gvisor` RuntimeClass**.
- **ARC runners:** set `runtimeClassName: gvisor` on the runner pods, and add a Kyverno rule requiring it in the runners' namespace. Run every workflow that uses the runners (evaluation gate, staging test) and fix anything that does not work under gVisor.
- **WordPress trial:** load-test russetleaf.dev's WordPress in **staging** with `k6` (home page, a post, the REST API) with and without `runtimeClassName: gvisor`. Keep gVisor for WordPress only if response times and error rates stay within an agreed margin (e.g. 95th-percentile latency no more than 20% worse); record the numbers and decision in [ADR 1009](adr/1009-gvisor-sandboxing.md).
- Note for step 7.1: Falco needs its **gVisor event source** turned on for sandboxed pods.

**Test:** a runner pod shows `runtimeClassName: gvisor` and the evaluation and staging workflows pass on it; a runner pod without the RuntimeClass is rejected by Kyverno; `dmesg` inside a gVisor pod shows gVisor's own kernel messages rather than the host's; the WordPress load-test results and decision are recorded in the ADR.

## Stage 7: Runtime security, compliance and cost

### Step 7.1: Falco

**Do:** `platform/falco/`: Falco with the **modern eBPF** driver (Talos does not allow kernel modules) and its **gVisor event source** for pods running under gVisor (step 6.5), Falcosidekick to Alertmanager, Grafana and Slack (`#rl-security`, warning priority and above), and custom rules: shell in WordPress pods; writes under `/var/www/html`; and **process allow-lists** per workload (WordPress: `apache2`, `php`, and `bash` **only as the container's first process running the entrypoint scripts** `docker-entrypoint.sh` and `apache2-foreground`; Phase 2 adds the summarizer, gateway and llama.cpp lists and a `rl-home-cp02` egress rule), alerting on any other process (see the Phase 1 design's [Process allow-listing](design.md#process-allow-listing) and [ADR 1015](adr/1015-process-allow-listing.md)).

- **MITRE ATT&CK detection map ([ADR 1036](adr/1036-compliance-frameworks-and-privacy.md)):** `docs/security/attack-coverage.md` mapping each detection (Falco rules with their MITRE tags, the Kubernetes audit alerts, GuardDuty finding types, Hubble drops, CrowdSec) to the **ATT&CK for Containers** techniques it covers, listing the uncovered techniques as accepted or planned; a Grafana panel of Falco alerts by technique.
- **Falco's own health:** Falco and Falcosidekick metrics with ServiceMonitors, and the alerts `FalcoNotRunning` (fewer ready Falco pods than nodes for 10 minutes; to `#rl-security` and `#rl-critical`), `FalcosidekickOutputErrors` and `FalcoEventsDropped` (to `#rl-security`), each with a runbook.

**Test:** a WordPress pod restart raises **no** allow-list alert (the entrypoint shell is allowed), while starting an unlisted process in each workload (e.g. `kubectl exec <pod> -- curl --version`, or `sleep` where a shell exists) raises a process allow-list alert in `#rl-security`, while normal traffic raises none; `kubectl exec` into a WordPress pod triggers an alert in Grafana and `#rl-security` (and the same in a gVisor runner pod, through the gVisor event source); creating a file under `/var/www/html` triggers another; deleting the Falco pod on one node (or temporarily preventing it from scheduling there) fires `FalcoNotRunning` in `#rl-security` and `#rl-critical`; pointing Falcosidekick at a wrong Slack destination fires `FalcosidekickOutputErrors`.

### Step 7.2: Trivy Operator, Kubescape scan and Talos hardening notes

**Do:** add the **component hardening checks** from [ADR 1031](adr/1031-kubernetes-component-hardening.md) to `docs/talos-hardening.md`: `talosctl` reads of the API server, controller-manager and scheduler arguments (profiling off, local-only binding, NodeRestriction and PodSecurity admission, per-controller service-account credentials, kubelet certificate rotation); confirmation that **Secrets are encrypted at rest** in etcd; the kubelet's **read-only port (10255) refused** on every node; disk encryption status; the firewall test. Then `platform/trivy-operator/` with modest scan concurrency (scans are memory hungry; keep them off `rl-home-cp02`), with its **CIS compliance results published as Prometheus metrics** (turn on the operator's cluster-compliance metrics; check the exact setting for the installed version) and a ServiceMonitor; a **Grafana "Compliance" dashboard** (built to show both clusters once EKS exists) and a `ComplianceFailuresIncreased` alert to `#rl-security`; write `docs/talos-hardening.md` explaining how Talos meets the CIS benchmark (no shell or SSH, read-only system, API-only management, default pod security), including **API server authorization**: only the **Node** and **RBAC** authorizers (no ABAC, no `AlwaysAllow`), checked with `talosctl -n <control-plane-ip> read /system/config/kubernetes/kube-apiserver/authorization-config.yaml`, and the kubelet's anonymous access off with webhook authorization, checked on **each node** with `talosctl -n <node-ip> read /etc/kubernetes/kubelet.yaml` (must show `authentication.anonymous.enabled: false` and `authorization.mode: Webhook`) and an anonymous request, `curl -sk -o /dev/null -w '%{http_code}' https://<node-ip>:10250/pods` (must return `401`). Add a note in `russetleaf-infra/envs/home` that the machine config must never override the authorization config. Record the **enabled admission plugins** from the API server's arguments (NodeRestriction, PodSecurity and the webhook plugins on; `AlwaysAdmit` off). Write `docs/runbooks/rotate-cluster-ca.md` (Talos and Kubernetes CAs with `talosctl rotate-ca`; the service-account signing key, by Talos's procedure if supported, otherwise manual steps; the internal CA's intermediate and root with overlapping bundles through trust-manager) and **rehearse it** on a local Talos-in-Docker cluster, then once on the real cluster ([ADR 1035](adr/1035-platform-security.md)). Run the first **Kubescape CLI** scan of the home cluster from the workstation (NSA-CISA and MITRE ATT&CK frameworks, plus RBAC analysis; nothing installed in the cluster), save the report and a short summary of accepted findings in `docs/security/`, and fill in the baseline in [ADR 1003](adr/1003-kubescape-cli-not-operator.md).

**Test:** vulnerability and compliance reports exist for the running workloads; compliance metrics appear in Prometheus and on the Compliance dashboard, and temporarily adding a non-compliant workload raises the failing-controls count and fires the alert; the hardening doc is reviewed, and the `talosctl read` check shows only `Node` and `RBAC`; on **all three nodes**, the kubelet config shows anonymous access off and webhook authorization, and the anonymous `curl` to port 10250 returns `401`; the admission plugin list is recorded; the CA rotation rehearsal succeeds on both the local and real clusters with the site staying up (time it); the Kubescape report is committed, and any high-risk RBAC findings (e.g. a service account that can read all Secrets cluster-wide) are fixed or explained; an **RBAC review** listing, per namespace, who can create pods, read Secrets or reach nodes is committed, with accepted findings in `docs/security/rbac-accepted.yaml` (repeated with each monthly scan; [ADR 1034](adr/1034-kubernetes-threat-model-coverage.md)).

### Step 7.3: OpenCost

**Do:** `platform/opencost/` using the existing Prometheus, with custom prices for the home hardware (electricity per node). Then, as in the Phase 1 design ([Cost monitoring and alerts](design.md#cost-monitoring-and-alerts)):

- `PrometheusRule` cost alerts from OpenCost's metrics, labeled `team=cost` (to `#rl-costs`), with runbooks: `NamespaceDailyCostSpike` now, and `GPUNodeRunningLong` in the AWS overlay later.
- A **weekly summary** workflow (scheduled GitHub Actions on the in-cluster runners) that queries OpenCost's API for the last 7 days, grouped by namespace, and posts the top items to `#rl-costs`.
- Record the decisions in [ADR 1012](adr/1012-opencost-and-aws-billing.md).

**Test:** OpenCost shows cost per namespace; the weekly summary appears in `#rl-costs` (run it by hand once); temporarily lowering the spike threshold fires `NamespaceDailyCostSpike` in `#rl-costs`; Cost Explorer can filter by the activated `Site` tag.

### Step 7.4: Tracing with Tempo (always on)

**Do:** `platform/tracing/`: **Grafana Tempo** in single-binary mode, storing traces in the Tempo bucket (scoped key from External Secrets), **3-day retention**; Tempo as a Grafana data source with links to Loki (trace ID in log lines) and exemplars on latency graphs. Point Alloy's OTLP receiver at Tempo, and turn tracing on in the WordPress values: parent-based sampling of ~10% for page requests (Phase 2 adds the summarizer and gateway, sampling 100% of summary jobs). Tempo runs **always on**, placed on `rl-home-cp03`. See the Phase 1 design ([Tracing](design.md#tracing-tempo--opentelemetry)). Record memory use and the sampling rates in [ADR 1006](adr/1006-tempo-tracing.md).

**Test:** a page request produces **one trace** in Grafana covering WordPress and its database and cache calls; a slow page's trace shows its database queries; clicking a trace opens its logs in Loki; no span contains post text or personal data; with tracing off, nothing is sent and there is no measurable overhead.

### Step 7.5: AWS account posture (Prowler)

**Do:** a GitHub Actions workflow in `russetleaf-infra`, **scheduled monthly** and runnable by hand, that assumes the read-only **audit role** (step 2.1) through GitHub OIDC and runs **Prowler** against **every account** in turn (assuming the audit role in each), with CIS AWS Foundations and AWS Foundational Security Best Practices, as a free **second opinion** to Security Hub's continuous checks (step 2.0b). Keep the full report as a workflow artifact, commit a summary to `russetleaf-gitops/docs/security/` (failed checks by severity, plus accepted findings with reasons), and post the counts of failed high and critical checks to `#rl-security`. Fix what is worth fixing in Terraform (not by hand). Record the first run's baseline in [ADR 1007](adr/1007-prowler-not-threatmapper.md). See the Phase 1 design ([Runtime security and compliance](design.md#runtime-security-and-compliance)).

**Test:** the workflow runs without stored AWS keys; a deliberately weakened setting (e.g. turning off S3 Block Public Access on a test bucket) shows up as a failed check, then passes once reverted; the summary and Slack message appear.

### Step 7.6: Version-age report

**Do:** a monthly scheduled GitHub Actions workflow in `russetleaf-gitops` that reads the versions actually running (Talos and Kubernetes from the cluster, MariaDB, Valkey and the major platform charts from `russetleaf-gitops`; Phase 3 adds EKS, RDS and EKS add-on versions), compares them with their **end-of-life dates** (e.g. the endoflife.date API), and posts anything within **90 days of end of support** to `#rl-deploys`. Link it from [ADR 1011](adr/1011-update-strategy.md).

**Test:** the workflow runs on schedule and by hand; temporarily lowering the threshold makes it report something; the message lists each component, its version and its end-of-support date.

### Step 7.7 (optional): Custom seccomp profiles

**Do:** install the **Security Profiles Operator** temporarily, record the system calls WordPress actually makes during a full test run (page loads, uploads, the REST API), and turn the recordings into a **custom seccomp profile** referenced by the chart's values (Phase 2 repeats this for the summarizer) (`seccompProfile: Localhost`). Keep the profiles in Git, apply them in staging first, and update Kyverno's seccomp rule to allow these named profiles. Record the outcome in [ADR 1015](adr/1015-process-allow-listing.md).

**Test:** both workloads pass the staging smoke tests with their custom profiles; a system call outside the profile (e.g. from a test binary) is blocked; a failed run after an image update is caught in staging, not production.

### Step 7.8: Rollback runbooks and drills

**Do:** write `docs/runbooks/rollback-<layer>.md` for each layer in the Phase 1 design's [Rollback strategy](design.md#rollback-strategy) (applications, platform, configuration, Terraform, Talos, Kubernetes, secrets, data; Cilium and Kyverno already exist), then run the first **drills**:

- in staging: roll back a release with a Git revert, abort a canary, and restore a MariaDB backup
- locally: a `talosctl rollback` on a Talos-in-Docker cluster, and the Cilium and Kyverno recovery paths in a kind cluster
- a secret rollback to `AWSPREVIOUS`

Record each drill's time in the decision log and compare it with the expected times.

**Test:** every runbook has been followed at least once in a drill; each rollback restored a working state within its expected time (or the runbook was corrected).

### Step 7.9: CrowdSec

**Do:** install **CrowdSec** reading ingress-nginx's logs, with its **Cloudflare bouncer** so abusive IP addresses (repeated login failures, scanners) are blocked at Cloudflare's edge; alerts and decisions to `#rl-security`. Record memory use.

**Test:** a simulated brute-force from a test address (in staging) gets that address banned at Cloudflare, and the ban expires as configured; normal visitors are not affected.

### Step 7.10: First full disaster drill

**Do:** simulate "the home lab is destroyed": using **only** the break-glass kit, the GitHub repos (or their mirrors) and the backups in the backup account, rebuild russetleaf.dev on a local Talos-in-Docker cluster (or on the real boxes during a maintenance window), following the bootstrap order in the [disaster recovery plan](disaster-recovery.md). Time each step, and fix the plan wherever it was wrong or incomplete.

**Test:** russetleaf.dev's content (posts and media) is fully restored from the off-account copies; the total time is recorded in the [disaster recovery plan](disaster-recovery.md) and [ADR 1018](adr/1018-disaster-recovery.md).

### Step 7.11: Node-failure drills

**Do:** with the site under light load (e.g. a `k6` script), take each node offline in turn: first a clean shutdown, then **pulling its power cable**. Watch the API (virtual IP), the site (uptime check and Grafana), the database (MariaDB failover) and the alerts in Slack; bring the node back and confirm it rejoins cleanly. Record the impact and timings in [ADR 1014](adr/1014-availability-levels.md) and the decision log.

**Test:** with any one node down, the site keeps serving (brief errors at most during failover), the API stays reachable, the database fails over and rebuilds its replica afterwards, and the expected alerts fire and clear.

### Step 7.12: Stress, spike and soak tests (home)

**Do:** with the k6 Operator, in staging first and then production at quiet times: a **stress / breakpoint** test ramping until the latency or error thresholds are passed (record the breaking point, the first bottleneck, how it fails, and whether it recovers on its own); a **spike** test (about 10× normal traffic suddenly); and an overnight **soak** test (moderate load for 4–8 hours, watching memory, connection pools and queues). Record results and action items in `docs/performance/`, and use them to set or adjust the SLO targets (step 8.1).

**Test:** each test's results are recorded with graphs; the first bottleneck has an action item or an explanation; the soak shows no steadily growing memory or connections (or a fix is planned).

## Stage 8: Engineering practices

These steps are most of the **Advanced** tier; see the Phase 1 design's [Engineering practices](design.md#engineering-practices). Do them after the Core and most Extended steps.

### Step 8.1: SLOs and error budgets

**Do:** SLO definitions in `russetleaf-gitops/docs/slos/` and `platform/sloth/`, with availability and latency **measured at the ingress inside the cluster** (so home internet outages do not burn the budget; the external uptime check still alerts on them), and an **exclusion process** in the policy for documented external incidents (ISP outages) (site availability and latency, home Kubernetes API; Phase 2 adds summary freshness and quality); **Sloth** generating recording rules and multi-window, multi-burn-rate alerts (fast burn to `#rl-critical`, slow burn to the site channel); Grafana SLO dashboards; retire the threshold alerts they replace. Write the **error-budget policy** and enforce it: `promote-to-prod` (step 5.7) checks the remaining budgets and blocks promotions, except changes labeled `fix` or `reliability`, when a budget is exhausted. See [ADR 1021](adr/1021-slos-and-error-budgets.md).

**Test:** the SLO dashboards show real budgets; injecting errors in staging (or lowering a target temporarily) burns the budget, fires the burn-rate alert, and blocks a normal promotion while a `fix` promotion still goes through.

### Step 8.2: DORA metrics

**Do:** a scheduled workflow that computes **deployment frequency**, **lead time for changes**, **change failure rate** and **time to restore** from GitHub (pull requests, releases), Argo CD (syncs) and the rollback and incident records, publishes them to Prometheus, and feeds a Grafana dashboard with monthly trends.

**Test:** the dashboard shows the four metrics over the last 30 days, and each can be traced back to its source records.

### Step 8.3: Developer portal and golden path (Backstage)

**Do:** `platform/backstage/` (on `rl-home-cp03`, PostgreSQL by the CloudNativePG operator, behind Cloudflare Access with Google sign-in): a **catalog** of every component with owners, links to dashboards, runbooks and SLOs; **TechDocs** from the repos' documentation; and a **software template** that creates a complete new service: repo with the full CI and supply-chain pipeline, a Kyverno-compliant chart, CiliumNetworkPolicies, SLO definitions, a dashboard and alerts, a runbook stub, and Argo CD registration through an **ApplicationSet**. See [ADR 1022](adr/1022-internal-developer-platform.md).

**Test:** `rl-home-cp03`'s memory stays under about 85% (otherwise move Backstage and its database to `rl-home-cp01`, or upgrade `rl-home-cp03` to 32 GB); the catalog lists every component with its owner and links; the template produces a repo whose CI passes on the first run and whose manifests pass the Kyverno CLI tests.

### Step 8.4: Second service and multi-tenancy

**Do:** create a **second, different service** from the template (e.g. a small Go API serving post statistics from WordPress's REST API, or a broken-link checker), and take it through ci, staging and promotion to production. Add **multi-tenancy** in `platform/tenants/`: a namespace and **Argo CD project** per tenant, **resource quotas and limit ranges**, scoped **RBAC**, per-tenant Kyverno policies, and **cost showback** per tenant in OpenCost. Measure and publish the **time from template to first production deploy**.

**Test:** the second service runs in production with its own SLOs, dashboard and alerts; it cannot exceed its quota or deploy outside its namespace; OpenCost shows its cost separately; the onboarding time is recorded.

### Step 8.5: Threat model and control matrix

**Do:** `docs/security/threat-model.md`: a **STRIDE** analysis of the whole system (trust boundaries, data flows, threats, mitigations), **organized by layer** (cloud, cluster, container, code; see the overview's defense in depth section), linked to the ADRs, building on the trust boundaries in the overview's [Kubernetes threat model coverage](../overview.md#kubernetes-threat-model-coverage) and **cross-checked against the Kubernetes threat model's eight areas** ([ADR 1034](adr/1034-kubernetes-threat-model-coverage.md)). The control matrix is **organized by NIST Cybersecurity Framework 2.0** functions (Govern, Identify, Protect, Detect, Respond, Recover), with **NIST SP 800-190** (container security) and **SP 800-218 (SSDF)** checklists as appendices, and links to the **CIS** results (kube-bench, Trivy Operator, Security Hub's CIS AWS Foundations, the CIS Docker check) and the ATT&CK map as evidence ([ADR 1036](adr/1036-compliance-frameworks-and-privacy.md)). `docs/security/controls-matrix.md`: every implemented control mapped to the **CIS Controls** (and SOC 2-style criteria), plus an **OWASP ASVS** mapping for the web application, each with its evidence (policy, configuration, report or test).

**Test:** every trust boundary has its threats and mitigations listed, and each of the eight threat areas maps to controls with evidence; every CSF 2.0 function, SP 800-190 item and SSDF practice is marked met, partly met (with a reason) or not applicable; every control in the matrix links to evidence that exists.

### Step 8.6: Chaos experiments and postmortems

**Do:** `platform/chaos-mesh/` with scheduled experiments, each with a written hypothesis, expected outcome, blast radius and abort condition (kill the MariaDB primary; kill a WordPress pod mid-canary; fill a node's disk; partition `rl-home-cp02`; Phase 2 adds latency injected into model calls), run in staging first, then in production at quiet times; results in `docs/chaos/`. A **blameless postmortem template** in `docs/postmortems/`, and postmortems for at least two real incidents or notable drills from the build. See [ADR 1023](adr/1023-reliability-practice.md).

**Test:** `rl-home-cp03`'s memory stays under about 85% with Chaos Mesh installed; each experiment's outcome is recorded against its hypothesis; any surprise produced an action item; two postmortems exist with completed or scheduled action items.

### Step 8.7: Strategy documents

**Do:** in `docs/strategy/`: a **technical roadmap**; a **capacity and cost plan** (using the home load-test results from step 7.12: how the HPA responds on fixed nodes, the limits found, and an estimated **cost per 1,000 visitors** on AWS at several traffic levels; Phase 3 replaces the estimate with EKS measurements); a **migration plan** (e.g. moving russetleaf.dev fully into AWS, or going multi-region: phases, risks, rollback points); and a **build-vs-buy analysis** (the self-hosted stack against managed alternatives, with costs and trade-offs).

**Test:** each document states its recommendations and the evidence behind them, and is linked from the hub README.

### Step 8.8: Fleet management (hub-and-spoke Argo CD)

**Do:** make the home Argo CD the **hub** for other clusters, with a **local Talos-in-Docker cluster** on the workstation (`talosctl cluster create`) as the first **spoke**: register it with an Argo CD cluster secret using a scoped service account, add an **ApplicationSet with a cluster generator** that deploys a small overlay (e.g. a test namespace with a policy and a demo app) to every registered spoke, and document registering and removing a spoke. Keep the per-cluster Argo CD as a documented fallback. In Phase 3, `demo-up` registers EKS the same way as a second spoke (Phase 3 step 5.5).

**Test:** with the local spoke running, the hub shows both clusters and the ApplicationSet syncs the overlay to the spoke; deleting the spoke's registration removes its Applications with no errors left behind; the spoke's credentials cannot change anything outside the namespaces the hub manages.

### Step 8.9: Public writing

**Do:** a series of **articles on russetleaf.dev** explaining the main design decisions (from the ADRs): e.g. S3 rather than EFS, no service mesh, the SRA account structure, error-budget-gated promotion (and, after Phase 2, evaluation gates for LLMs). Link them from the hub README.

**Test:** at least four articles published, each linking to the relevant ADRs and code.

## Stage 9: Finishing

### Step 9.1: Keyless AWS access for pods

**Do:** publish the Talos cluster's service-account OIDC discovery files (public S3 bucket), register it as an IAM OIDC provider in `russetleaf-infra`, switch pods from scoped keys to IAM roles one at a time, then delete the keys.

**Test:** each pod works with no AWS key in its Secrets; the old keys are deleted from IAM.

### Step 9.2: Documentation and polish

**Do:** run an **AWS Well-Architected review** of the design in the free Well-Architected Tool (Security pillar first, then the others), save the report in `docs/`, and fix or record the high-risk items; hub README with the russetleaf.dev architecture diagram and links to all repos; screenshots of Grafana (site, cost) and Argo CD; update the Phase 1 design wherever the build differed from it; re-run `gitleaks` on every repo and confirm the repos and GHCR packages are still public (they were made public in steps 1.1 and 5.1); add each repo's **OpenSSF Scorecard** badge to its README (record the scores in the decision log), and confirm **SARIF upload** of Checkov's results to GitHub code scanning is on in each repo (it can be turned on from step 1.1, since the repos are public).

**Test:** someone unfamiliar with the project can follow the README to understand it in five minutes.

## Ongoing operations (after the build)

The tables below are the **full cadence**. When time is short, use the **minimum cadence** from the overview's [Operations budget](../overview.md#operations-budget): one monthly 2–4 hour maintenance window, with automation and Slack doing the rest. Record operations time monthly in the decision log.

These keep russetleaf.dev healthy once it is running. Add each as a calendar reminder or a scheduled job.

| Task | How often | How |
|---|---|---|
| Node-failure drill | Quarterly | Take one node offline (alternating nodes); confirm failover and record the timings |
| Rollback drill | Monthly (staging); quarterly (Talos, Cilium, Kyverno locally) | Follow a rollback runbook end to end and time it; fix the runbook if anything differed |
| Restore from the backup account | Quarterly | Restore a MariaDB backup from the backup account's locked copy into a scratch instance |
| Full disaster drill | Yearly | Rebuild russetleaf.dev using only the break-glass kit and off-account backups; record the time |
| Check the break-glass kit | Every 6 months | Logins work, recovery codes are valid, the printed copy is current; the talosconfigs' client certificates are not near expiry |
| Renew talosconfigs | Yearly (their client certificates last a year) | Generate new day-to-day and break-glass talosconfigs; update the kit ([ADR 1035](adr/1035-platform-security.md)) |
| Review the record of processing and ATT&CK map | Quarterly, and when a component or plugin is added | Update `docs/privacy/record-of-processing.md`, the processors list and `docs/security/attack-coverage.md` ([ADR 1036](adr/1036-compliance-frameworks-and-privacy.md)) |
| Review VEX statements | Quarterly, and at each statement's review date | Confirm each `not_affected` justification still holds; remove statements for fixed packages |
| Test a database restore | Monthly | Restore the latest backup into a scratch MariaDB instance and check the post count (step 4.5) |
| Merge Renovate pull requests | Weekly | Review the Dependency Dashboard and pull requests; patches auto-merge; read changelogs for minors and majors and rehearse platform ones on a local Talos-in-Docker cluster; Argo Rollouts and the CI checks catch bad application updates |
| Security releases | Within 48 hours of a WPScan, Trivy Operator or Renovate security alert | Fast-track through ci and staging; promote as soon as staging passes |
| Version-age report | Monthly (automatic) | Plan upgrades for anything within 90 days of end of support |
| Talos and Kubernetes upgrades | Talos patches monthly; Kubernetes minor versions quarterly | Take an etcd snapshot and an on-demand MariaDB backup; rehearse on a local Talos-in-Docker cluster; check Cilium and platform components support the new Kubernetes version; bump versions in `russetleaf-infra/envs/home` and apply **one node at a time** (`rl-home-cp02`, `rl-home-cp01`, then `rl-home-cp03`), checking etcd health and the site between nodes (**no downtime expected**), then `talosctl upgrade-k8s`; roll back with `talosctl rollback` if needed; note timings in the decision log |
| Back up cluster state (etcd) | Weekly | `talosctl etcd snapshot` to the KMS-encrypted backup bucket (replicated to the Backup account), readable only by the backup role and break-glass access, since **snapshots contain every Secret** (a scheduled job on the workstation or a CronJob using a Talos API key). GitOps can rebuild everything else, but this speeds up recovery. |
| Check for Terraform drift | Weekly | A scheduled `terraform plan` in `russetleaf-infra` CI for the AWS and Cloudflare resources (alerts if anything changed outside Terraform) |
| Check staging still works | Monthly, if nothing has been promoted | Run `staging-test` by hand, so a broken staging setup is found before it blocks a real release |
| Check the staging scrub | After any plugin that stores personal data is added | Confirm the `staging-data` Job also clears that plugin's tables |
| Review GuardDuty findings and audit alerts | Weekly (findings also alert in real time) | Check GuardDuty's console for low-severity findings not sent to Slack; tune audit alert rules that fire on expected activity |
| Review Security Hub | Weekly | Check new failed controls and findings across accounts; fix in Terraform or suppress with a recorded reason |
| Well-Architected review | Yearly | Update the review in the free Well-Architected Tool; keep the report in `docs/` |
| Prowler AWS account scan | Monthly (automatic) | Review the workflow's summary and Slack message; fix new failures in Terraform or record why they are accepted |
| Kubescape posture scan | Monthly | Run the Kubescape CLI against the home cluster; save the report in `docs/security/`; compare scores with the previous run and investigate any drop |
| Review the admin allow-list | Quarterly | Remove people who no longer need access, in the plugin's allow-list and the Cloudflare Access policy |
| Rotate the Google OAuth client secrets | Yearly | Create a new secret in the Google Cloud console, update Secrets Manager, let External Secrets sync it, delete the old one |
| SaaS access review | Quarterly | Review users, tokens, apps and keys in GitHub, Cloudflare, Google Cloud, Slack, AWS Identity Center and the registrars; remove anything unused |
| Enforce CSP / review CSP reports | Weekly until enforced, then monthly | Fix violations, then switch Content-Security-Policy from report-only to enforced |
| Rotate WordPress keys and salts | Quarterly | Update in Secrets Manager; signs everyone out |
| Rotate MariaDB passwords | Quarterly | Regenerate the operator-managed Secret (or use the operator's rotation feature), then restart WordPress through its Rollout; check the backup user still works |
| Rotate scoped IAM keys | Every 90 days, until step 9.1 removes them | Create a new key in Terraform, update Secrets Manager, let External Secrets sync it, delete the old key |
| Review alerts and costs | Monthly | Grafana, OpenCost, the AWS Budget and Cost Explorer (filter by `Site=dev`) |
| Review log volume | Monthly | Check Loki's daily ingestion and `rl-home-cp03`'s memory; drop or shorten noisy sources at Alloy |
| Review alert noise | Monthly | Look at what fired in the Slack channels: remove or tune alerts nobody acted on, and update runbooks that did not help |
| Test the outside monitoring | Quarterly | Pause the heartbeat or block the uptime check and confirm `#rl-critical` is notified |

## Later phases

Not part of this plan:

- **[Phase 2: AI summaries and MLOps](../phase-2-ai-mlops/plan.md)** (optional): the `russetleaf-llm-summarizer` repo, SQS and Bedrock, `rl-home-cp02` as the LLM node, the summarizer, the LLM gateway, the self-hosted model, the evaluation gate, MLflow, guardrails, online evaluation and the feedback loop.
- **[Phase 3: russetleaf.com on EKS](../phase-3-russetleaf-com/plan.md)** (optional): the russetleaf-com account, `russetleaf-infra/envs/aws-edge` and `envs/aws` (Route 53, CloudFront, the offline page, VPC, EKS, RDS for MariaDB, ElastiCache, WAF), `overlays/aws` for every component, Karpenter, the AWS Load Balancer Controller, ExternalDNS, the EBS CSI driver, kube-bench, Pod Identity roles, the `seed-from-dev` Job, and EKS as a second spoke of the Argo CD hub.

Phase 1 builds most of what these need: the shared Terraform modules, the base manifests, the images and charts, and the CI. Keep environment-specific settings in overlays so the later phases only add overlays.

## Progress checklist

| Step | Tier | Est. hours | Done | Date | Actual hours | Node memory after | Notes |
|---|---|---|---|---|---|---|---|
| 0.1 Accounts, tools, budget | Core | 4–8 | ☐ | | | | |
| 0.2 Decisions | Core | 1–2 | ☐ | | | | |
| 0.3 Home network segmentation | Core | 2–4 | ☐ | | | | |
| 1.1 Repos | Core | 4–7 | ☐ | | | | |
| 2.0 AWS Organization and accounts (SRA) | Core | 6–10 | ☐ | | | | |
| 2.0b Organization security services | Core | 4–8 | ☐ | | | | |
| 2.1 Terraform bootstrap | Core | 3–5 | ☐ | | | | |
| 2.2 Talos cluster | Core | 13–19 | ☐ | | | | |
| 2.3 AWS + Cloudflare resources | Core | 6–9 | ☐ | | | | |
| 2.4 `russetleaf-infra` CI | Core | 4–6 | ☐ | | | | |
| 2.5 Disaster recovery copies | Extended | 3–6 | ☐ | | | | |
| 3.1 GitOps structure + Argo CD | Core | 6–10 | ☐ | | | | |
| 4.1 Storage | Core | 1–2 | ☐ | | | | |
| 4.2 Secrets + internal certificates | Core | 4–6 | ☐ | | | | |
| 4.3 Ingress + tunnel | Core | 3–6 | ☐ | | | | |
| 4.4 Monitoring + Slack alerting | Core | 8–12 | ☐ | | | | |
| 4.5 MariaDB + backups + Valkey | Core | 6–10 | ☐ | | | | |
| 4.6 Logging (Loki + Alloy) | Core | 7–11 | ☐ | | | | |
| 4.7 Cluster access (OIDC, roles, SSO) | Core | 6–10 | ☐ | | | | |
| 5.1 WordPress image | Core | 15–23 | ☐ | | | | |
| 5.2 WordPress deployment | Core | 9–15 | ☐ | | | | |
| 5.3 Image promotion | Core | 2–4 | ☐ | | | | |
| 5.4 ci test clusters | Core | 5–8 | ☐ | | | | |
| 5.5 Self-hosted runners (ARC) | Core | 2–4 | ☐ | | | | |
| 5.6 On-demand staging | Core | 7–11 | ☐ | | | | |
| 5.7 Promotion pipeline | Core | 5–8 | ☐ | | | | |
| 5.8 Google sign-in for admins | Extended | 4–7 | ☐ | | | | |
| 5.9 Performance testing + regression gate | Extended | 5–8 | ☐ | | | | |
| 5.10 Site design and brand (incl. logo) | Core | 5–11 | ☐ | | | | |
| 5.11 Front-end quality gates | Extended | 4–6 | ☐ | | | | |
| 5.12 Compliance scope + privacy (GDPR) | Core | 4–7 | ☐ | | | | |
| 6.1 Kyverno | Core | 15–20 | ☐ | | | | |
| 6.2 Argo Rollouts | Extended | 4–7 | ☐ | | | | |
| 6.3 CiliumNetworkPolicies | Core | 6–9 | ☐ | | | | |
| 6.4 Service mesh ADR (+ optional Istio experiment) | Extended | 2–6 | ☐ | | | | |
| 6.5 Sandboxed runtime (gVisor) | Extended | 4–7 | ☐ | | | | |
| 7.1 Falco | Extended | 4–7 | ☐ | | | | |
| 7.2 Trivy Operator, Kubescape scan, Talos notes + component checks | Extended | 7–10 | ☐ | | | | |
| 7.3 OpenCost | Extended | 2–4 | ☐ | | | | |
| 7.4 Tracing with Tempo (always on) | Extended | 2–5 | ☐ | | | | |
| 7.5 AWS account posture (Prowler) | Extended | 2–4 | ☐ | | | | |
| 7.6 Version-age report | Extended | 2–3 | ☐ | | | | |
| 7.7 Custom seccomp profile (optional) | Advanced | 3–6 | ☐ | | | | |
| 7.8 Rollback runbooks and drills | Extended | 5–8 | ☐ | | | | |
| 7.9 CrowdSec | Extended | 3–5 | ☐ | | | | |
| 7.10 First full disaster drill | Extended | 6–10 | ☐ | | | | |
| 7.11 Node-failure drills | Extended | 3–6 | ☐ | | | | |
| 7.12 Stress, spike and soak tests | Extended | 5–8 | ☐ | | | | |
| 9.1 Keyless AWS access | Extended | 5–10 | ☐ | | | | |
| 9.2 Docs + go public | Core | 6–10 | ☐ | | | | |
| 8.1 SLOs and error budgets | Advanced | 10–15 | ☐ | | | | |
| 8.2 DORA metrics | Advanced | 6–10 | ☐ | | | | |
| 8.3 Backstage and golden path | Advanced | 15–25 | ☐ | | | | |
| 8.4 Second service + multi-tenancy | Advanced | 10–15 | ☐ | | | | |
| 8.5 Threat model + control matrix | Advanced | 13–18 | ☐ | | | | |
| 8.6 Chaos experiments + postmortems | Advanced | 10–15 | ☐ | | | | |
| 8.7 Strategy documents | Advanced | 6–10 | ☐ | | | | |
| 8.8 Fleet management (hub) | Advanced | 6–10 | ☐ | | | | |
| 8.9 Public writing | Advanced | 10–20 | ☐ | | | | |

## Decision log

| Date | Decision | Reason |
|---|---|---|
| | | |
