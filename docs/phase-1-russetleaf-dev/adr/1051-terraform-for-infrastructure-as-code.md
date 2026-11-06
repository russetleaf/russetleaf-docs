# ADR 1051: Terraform for infrastructure as code (not CloudFormation, CDK, Pulumi or OpenTofu)

- **Status:** Accepted. It records a choice the [overview](../../overview.md#phase-1-russetleafdev) and the plan already made, with the alternatives behind it.
- **Date:** 2026-11-06
- **Applies to:** both sites
- **Phase:** 1 (`russetleaf-infra`, steps 2.0 to 2.5). Phase 2 adds the AI pipeline's AWS resources; Phase 3 adds russetleaf.com's edge and demo stacks.

## Context

Everything outside the Kubernetes manifests is built as code in one repo, `russetleaf-infra`: the AWS Organization and its accounts, guardrails and security services ([ADR 1019](1019-aws-multi-account-sra.md)); the AWS resources each site uses; Cloudflare's DNS, tunnel, WAF rules and R2 bucket; the GitHub repo settings and branch protection (`envs/github`); and the **Talos cluster itself**, whose machine configurations are rendered and applied through Terraform's Talos provider ([ADR 1039](1039-bootstrap-through-talos-inline-manifests.md)). The choice of tool was stated in the overview and the plan, but no ADR recorded it or the alternatives. **CloudFormation** is AWS's own tool, so the question of why it is not used deserves a written answer. The constraints:

- **Several providers, not only AWS:** AWS, Cloudflare, GitHub and Talos, with one workflow and one review process for all of them.
- **Both sites** share modules: the home lab's AWS pieces and russetleaf.com's stacks use the same ones.
- **A gated pipeline:** formatting, linting, policy checks, cost diffs, and applies of the exact reviewed plan through a GitHub Environment ([ADR 1030](1030-github-actions-ci.md)).
- **One operator:** the tool must be widely used and documented, with a large set of maintained providers and modules.

## Decision

- **Terraform** (1.10 or later, pinned per repo with `mise`) manages all infrastructure outside Kubernetes, in `russetleaf-infra`: shared modules, and one root module per environment (`bootstrap`, `org`, `home`, `github`, `dr`; Phase 3 adds `aws-edge` and `aws`).
- **State** is in the S3 bucket in the russetleaf-infra account, one key per environment, with Terraform's built-in S3 locking (`use_lockfile = true`, no DynamoDB table); each environment's CI roles can reach only their own keys.
- **Providers** are pinned in `.terraform.lock.hcl` with hashes for every platform, and Renovate keeps them current.
- **Checks** run in pre-commit and CI: `fmt`, `validate`, **tflint** with the AWS ruleset, **Checkov** with the project's own policies, **terraform-docs**, module tests and **Infracost**.
- **Resources made by hand** (the management account's console bootstrap) are **imported** into Terraform, so Terraform remains the source of truth ([AWS management account setup guide](../setup/aws-management-account.md#part-2-bootstrap-the-organization-and-identity-center-step-20)).

## Alternatives considered

- **AWS CloudFormation:** AWS's own tool, free, with state kept by AWS (no state bucket to protect), drift detection, StackSets for deploying to many accounts, and support for new AWS services from launch. But it manages **only AWS**: Cloudflare, GitHub and the Talos cluster would need a second tool, or custom resources backed by Lambda functions that the project would write and maintain. Its templates are YAML or JSON, which is verbose for the shared modules; its feedback on a change (change sets) is less readable than a Terraform plan; and a failed stack update can leave a stack stuck in a rollback state that must be fixed by hand.
- **AWS CDK:** infrastructure written in TypeScript or Python, with loops, types and reusable classes. It turns into CloudFormation, so it has the same AWS-only limit, and it adds a programming-language toolchain and a build step to every change.
- **Pulumi:** several providers (it can use Terraform's), written in a general programming language. A smaller community and fewer examples than Terraform; its state needs its own hosted service or a self-managed backend; and a general-purpose language makes infrastructure code harder to review than HCL's declarative files.
- **OpenTofu:** the open-source fork of Terraform, made after HashiCorp moved Terraform to the source-available Business Source License (BSL) in 2023, and now run by the Linux Foundation. It reads the same configuration and providers, and adds features of its own (such as state encryption). Terraform is kept because the BSL does not restrict using Terraform to manage the project's own infrastructure; Terraform is the better-known tool in job descriptions and documentation; and the checks used here (tflint, Checkov, terraform-docs, Infracost) are built and tested against it first. The switch stays cheap while the configuration uses only features both support.
- **Crossplane:** infrastructure managed by controllers inside Kubernetes, in the same GitOps flow as the applications. But the cluster would have to exist before it could create its own infrastructure, including the AWS accounts and the Talos nodes it runs on; it adds controllers to the home cluster's memory budget; and its providers for Cloudflare and Talos are less mature.
- **Ansible or scripts:** fine for configuring machines, but no plan before a change and no state, so they cannot show what a change will do or find drift; Talos has no shell or SSH for them to use anyway.

## Consequences

- One tool, one language and one review flow for AWS, Cloudflare, GitHub and the Talos cluster, with a readable plan on every pull request.
- The **state bucket must be protected:** state can hold secrets (the Talos machine secrets among them), so the bucket is encrypted, versioned, locked to the CI roles and replicated to the Backup account ([ADR 1018](1018-disaster-recovery.md)).
- **New AWS features** can arrive in Terraform's AWS provider later than in CloudFormation; when that matters, a small `aws_cloudformation_stack` or a short-lived manual step (imported later) bridges the gap.
- **Licensing:** Terraform is BSL, not open source; using it for the project's own infrastructure is allowed, and OpenTofu remains a close alternative.
- **Drift** is found by a weekly scheduled `terraform plan` ([Ongoing operations](../plan.md#ongoing-operations-after-the-build)), not by AWS.

## When to revisit

- **HashiCorp's license terms, or Terraform's pricing or availability, change** in a way that affects the project, or a needed tool starts to support only OpenTofu: switch to OpenTofu.
- **The infrastructure becomes AWS-only** (for example, the home site, Cloudflare and GitHub settings are no longer managed here): CloudFormation or CDK would become reasonable, though not worth a migration on its own.
- **The platform team grows** and wants infrastructure requested through Kubernetes resources: consider Crossplane for application-level resources, with Terraform keeping the foundations.
