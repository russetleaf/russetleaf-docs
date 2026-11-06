# ADR 1052: OpenTofu instead of Terraform

- **Status:** Accepted. It supersedes [ADR 1051](1051-terraform-for-infrastructure-as-code.md); updated by [ADR 1054](1054-opentofu-state-and-plan-encryption.md) (state and plan encryption).
- **Date:** 2026-11-06
- **Applies to:** both sites
- **Phase:** 1 (`russetleaf-infra`, steps 2.0 to 2.5). Phase 2 adds the AI pipeline's AWS resources; Phase 3 adds russetleaf.com's edge and demo stacks.

> **Update ([ADR 1054](1054-opentofu-state-and-plan-encryption.md)):** state and saved plans **are encrypted** by OpenTofu from the first apply, with a passphrase kept in Secrets Manager and the break-glass kit, so the Backup account's copies stay readable without the russetleaf-infra account. The deferral below no longer applies.

## Context

[ADR 1051](1051-terraform-for-infrastructure-as-code.md) chose Terraform for all infrastructure outside Kubernetes (AWS, Cloudflare, GitHub and the Talos cluster), and kept it over **OpenTofu**, its open-source fork, because Terraform is the better-known name and the checks target it first. A review of the project's tools the same day ([ADR 1053](1053-open-source-tools-by-default.md)) set a rule of **open-source tools by default**, and Terraform is not open source: since 2023 it is under HashiCorp's **Business Source License (BSL)**, and HashiCorp is now part of IBM.

No infrastructure code exists yet (`russetleaf-infra` is written from step 2.0), so a switch now costs only documentation. Checked before deciding (2026-11-06, OpenTofu 1.13.8):

- the four providers the project uses (`hashicorp/aws`, `cloudflare/cloudflare`, `integrations/github`, `siderolabs/talos`) install from **OpenTofu's registry**, signed;
- **ephemeral values and write-only arguments**, which keep Phase 3's database password and cache token out of state ([ADR 3007](../../phase-3-russetleaf-com/adr/3007-rds-mariadb-with-rds-proxy.md)), validate with the AWS provider;
- every check in the pipeline supports OpenTofu: tflint, Checkov, terraform-docs, Infracost, `pre-commit-terraform`, Renovate, `mise` and a GitHub Action (`opentofu/setup-opentofu`).

## Decision

- **OpenTofu** (1.13 or later, pinned per repo with `mise` as `opentofu`) replaces Terraform for everything [ADR 1051](1051-terraform-for-infrastructure-as-code.md) covered; its decision otherwise stands (one repo, a root module per environment, the gated pipeline, imports of anything made by hand).
- **Commands** are `tofu` (`tofu plan`, `tofu apply`, `tofu test`, ...). File names stay the same (`*.tf`, `.terraform.lock.hcl`), as does the `terraform { }` block in the configuration, which OpenTofu reads unchanged.
- **Providers** come from OpenTofu's registry (`registry.opentofu.org`), pinned with hashes for every platform in `.terraform.lock.hcl` (`tofu providers lock`).
- **State** stays in the S3 bucket in the russetleaf-infra account, with built-in S3 locking (`use_lockfile = true`).
- **The checks** run as before; the `pre-commit-terraform` hooks are pointed at `tofu` (`--hook-config=--tf-path=tofu`).
- **The `ManagedBy` tag** on every resource is `opentofu`, and the Checkov policy that requires it checks that value.
- **OpenTofu's state encryption** encrypts the state and saved plans ([ADR 1054](1054-opentofu-state-and-plan-encryption.md)).

## Alternatives considered

- **Keep Terraform** ([ADR 1051](1051-terraform-for-infrastructure-as-code.md)): the better-known name in job listings, HashiCorp's certification, and new features first. But it is not open source, which the project now prefers ([ADR 1053](1053-open-source-tools-by-default.md)); its license terms are set by one company and have changed once already; and nothing the project needs is missing from OpenTofu.
- **Switch later:** possible, since the two still read the same configuration, but every module, workflow and runbook written in the meantime would have to be checked and renamed; now there is none.

## Consequences

- **The project's infrastructure code is fully open source** (MPL 2.0, run by the Linux Foundation), like the rest of its tools.
- **The documentation names OpenTofu throughout,** including the earlier ADRs, whose decisions are unchanged; only [ADR 1051](1051-terraform-for-infrastructure-as-code.md) and the decision log keep the name Terraform, as a record.
- **Experience transfers:** OpenTofu uses the same language, workflow and providers as Terraform, so the work reads as Terraform experience too ("OpenTofu, Terraform-compatible"). HashiCorp's Terraform certification is not part of the project.
- **Features may diverge** over time. Using an OpenTofu-only feature (state encryption, for example) makes a move back to Terraform harder; that is accepted.
- **Documentation and examples** online are mostly written for Terraform; they apply to OpenTofu almost without change.

## When to revisit

- **OpenTofu's development slows** (fewer releases, security fixes late), or a provider the project needs stops being published to its registry.
- **Terraform returns to an open-source license.**

## Open items

- Phase 1 step 2.1: the `.mise.toml` pin, the backend with `use_lockfile`, and the `pre-commit-terraform` hooks set to `tofu`.
- Phase 1 step 2.4: the pipeline with `opentofu/setup-opentofu`, and the Checkov policy for `ManagedBy=opentofu`.
