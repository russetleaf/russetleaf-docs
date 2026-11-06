# ADR 1053: Open-source tools by default, and the recorded exceptions

- **Status:** Accepted
- **Date:** 2026-11-06
- **Applies to:** all repos, both sites, and the operator's workstation
- **Phase:** 1. Later phases apply the same rule to the tools they add.

## Context

The project's own code and documentation are GPL v3.0 ([ADR 1049](1049-licensing.md)), and it is published so others can read and reuse how the platform is built. Most of its tools are open source, but a review on 2026-11-06 found some that are not, or that have moved away from open source:

- **Terraform** moved to HashiCorp's source-available Business Source License in 2023; **OpenTofu** is the open-source fork.
- **Semgrep** moved features from its free Community Edition into its paid product in late 2024, and put its maintained rules under a license that is not open source; **Opengrep** is the open-source fork of the engine, maintained by several security companies.
- **LocalStack**, the planned AWS stand-in for tests, has changed its free-tier terms over time and moves features into paid tiers; the design's fallback, **MinIO**, cut back its free edition in 2025 (its web console removed, and free builds no longer published).
- **Material for MkDocs**, the theme of this documentation site, is open source (MIT) but reaches **end of life on May 5, 2027**; its team now builds **Zensical**, an open-source (MIT) successor that reads the same `mkdocs.yml`.

There was no rule for choosing between an open-source tool and one that is not, so these were found by chance.

## Decision

**The rule:** prefer tools under an **OSI-approved open-source license**. When a tool is not open source, or its license changes, either switch to an open-source alternative or add the tool to the exceptions below with the reason it is kept. A tool that is open source at its core but sells extra features (open core) is fine when only the open parts are used.

**Switches made now** (nothing that uses them has been built yet):

| Was | Now | Licence | Notes |
|---|---|---|---|
| Terraform | **OpenTofu** | MPL 2.0 | [ADR 1052](1052-opentofu-instead-of-terraform.md) |
| Semgrep Community Edition | **Opengrep** | LGPL 2.1 | The same engine and rule syntax, installed by the setup script with `mise`. Rules: the project's own, plus outside rule sets only where their license allows it (Semgrep's maintained rules are not open source). |
| LocalStack (with MinIO and ElasticMQ as the fallback) | **Moto** in server mode | Apache 2.0 | One container (`motoserver/moto`) stands in for S3, SQS and Secrets Manager in the ci tests and the local Compose environment; no account or token. The setup script no longer installs a LocalStack CLI. |
| Material for MkDocs (with MkDocs) | **Zensical** | MIT | Reads the existing `mkdocs.yml`; `zensical build --strict` fails on broken pages and anchors, as `mkdocs build --strict` did (checked on this site). Pinned in `requirements-docs.txt`. |

**Recorded exceptions:**

| Tool or service | Why it is not open source | Open-source alternative | Why it is kept |
|---|---|---|---|
| **GitHub** (repos, Actions, GHCR, code scanning) | A hosted service | Forgejo, GitLab Community Edition | Free for public repos and the integrations the pipeline relies on ([ADR 1030](1030-github-actions-ci.md)); the GitLab mirror of every repo limits the dependence |
| **AWS**, **Cloudflare**, **Google** (sign-in) | Hosted services | Self-hosted equivalents | The platform is built on them by design ([ADR 1019](1019-aws-multi-account-sra.md)); their free tiers cover most of it |
| **Slack**, and **Amazon Q Developer** (AWS notifications into Slack) | Hosted services | Mattermost, Zulip | Free, with phone notifications and the integrations already in use; a self-hosted chat server would be one more thing to keep running, and would be down when the cluster is |
| **Claude Code** and hosted models (Claude, Amazon Bedrock) | Proprietary | Open-weight models (Phase 2 runs one with llama.cpp) | How the project is built ([ADR 2004](../../phase-2-ai-mlops/adr/2004-agentic-ai-delivery.md)), and the Phase 2 summaries' main model |
| **Google Authenticator** (only for services that require codes: GitHub, and GitLab or the uptime checker if they do; not used for the AWS root user, [ADR 1056](1056-aws-root-mfa-two-security-keys.md)) | A proprietary app | **Aegis** (Android, GPL 3.0: no cloud sync, encrypted local backups) or **Ente Auth** (iOS, Android and desktop, AGPL 3.0: optional end-to-end-encrypted sync) | The operator's choice, with cloud sync on and the Google account under Advanced Protection. Either alternative is a drop-in replacement if it is changed later |
| **WPScan** (WordPress plugin vulnerabilities) | Its CLI is under its own source-available license, and its vulnerability data comes from a commercial service with a free daily limit | None with the same coverage; Wordfence Intelligence offers a free (not open-source) vulnerability feed | Non-commercial use like this project's is allowed, and the free limit covers a weekly scan; revisit if the limit or terms change |

**Open core, used only for the open parts:** Infracost (the CLI is Apache 2.0; prices come from its free hosted pricing service), CrowdSec (the engine is MIT; the console and paid blocklists are not used), LiteLLM (the MIT core; not its enterprise features). **Copyleft licenses** such as the AGPL (Grafana, Loki, Tempo, k6) are open source; running unmodified copies puts no obligations on the project.

## Alternatives considered

- **No rule; judge each tool when it is chosen:** less process, but it is how Terraform and Semgrep were picked without their licenses being weighed.
- **Open source only, with no exceptions:** consistent, but it would mean self-hosting the code host, chat and sign-in, and giving up the AWS services the design is built on.
- **Keep the switched tools until they cause a problem** (as improvements for after go-live): less work now, but every config, workflow and runbook written in the meantime would have to be changed later; nothing using them exists yet.

## Consequences

- The tools the project runs are open source, except the exceptions above, each with its reason in one place.
- **Zensical is young** (version 0.0.x, pinned): a release may change behaviour, so updates go through Renovate's pull requests and the docs CI, and Material for MkDocs remains a fallback until its end of life.
- **Opengrep does not get Semgrep's maintained rules,** so the SAST rules are the project's own plus open rule sets; coverage depends on keeping them current.
- **Moto covers fewer AWS details than LocalStack** in some services; the ci tests use only S3, SQS and Secrets Manager, which it supports well.
- Every new tool, in any phase, is checked against the rule, and a license change in an existing tool is handled the same way (switch, or add an exception).

## When to revisit

- A recorded exception gains a practical open-source replacement, or its terms change (for example, WPScan's free limit).
- A switched tool falls behind: Opengrep stops tracking new language versions, Moto lacks an AWS feature the tests need, or Zensical stalls before Material for MkDocs' end of life.

## Open items

- Phase 1 step 0.2: confirm the S3 offload plugin works against Moto's S3 endpoint (it replaces the LocalStack-or-MinIO choice).
- Phase 1 step 5.1: Opengrep in CI, with the project's rules and any outside rule set whose license allows it.
- Phase 1 step 5.4: the ci tests against Moto.
