# ADR 1060: The repos in a GitHub organization and a GitLab group

- **Status:** Accepted
- **Date:** 2026-11-10
- **Applies to:** every RussetLeaf repo and its GitLab mirror
- **Phase:** 1 (step 1.1)

## Context

The repos were planned under the operator's personal GitHub account, with their mirrors under the personal GitLab account. Several parts of the design already assume an organization: the GitHub provider's organization settings in `russetleaf-infra/envs/github` ([ADR 1032](1032-defense-in-depth.md)), the GitHub App installed only on `russetleaf-gitops` for version-bump pull requests (decision log, 2026-11-07), and coding agents limited to the project's repos ([ADR 2004](../../phase-2-ai-mlops/adr/2004-agentic-ai-delivery.md)). GitHub's terms allow one free personal account per person, so a second personal account for the project is not an option.

## Decision

- **A free GitHub organization, `russetleaf`,** owned by the operator's personal account, holds every repo; `russetleaf-docs` is transferred into it and the code repos are created there in step 1.1.
- **Organization settings:** two-factor authentication **required**, with **only secure methods** allowed; russetleaf.dev as a **verified domain**; the organization's contact email on the project domain ([ADR 1059](1059-google-workspace-identity.md)); base permissions read-only, default workflow token read-only, and Actions limited to pinned actions, managed in `envs/github`.
- **The docs site** is served from the organization: Pages for `russetleaf-docs` keeps the custom domain `docs.russetleaf.dev`, with its CNAME pointing at `russetleaf.github.io` and the domain verified for the organization.
- **A GitLab group, `russetleaf`,** holds the mirrors; the existing mirror project is transferred into it, and the sync workflow's secrets point at the group's path.
- **The operator's personal accounts** remain the owners and sign in as before ([account sign-in setup guide](../setup/account-sign-in.md)); commits keep the operator's identity and signature.

## Alternatives considered

- **Repos under the personal accounts:** simplest, but organization-wide rules (required two-factor authentication, rulesets, base permissions, an audit log) and a verified domain are not available, and the project's repos are mixed with personal ones.
- **A second personal account for the project:** against GitHub's terms (one free personal account per person) and a second set of credentials to secure.
- **GitHub Enterprise Cloud** (SAML single sign-on through Google Workspace): about $21 per user per month, for features one operator does not need.

## Consequences

- One place for the project's repos, with rules applied to all of them and an audit log of changes.
- The transfer redirects the old repo URLs, but not GitHub Pages: the docs site's CNAME and domain verification are redone, and the links in the documents move to the organization's URLs.
- The organization's settings are code from step 2.4 (`envs/github`), so a manual change shows as drift.
- As the organization's only owner, the operator cannot turn off two-factor authentication on the personal account while the organization requires it.

## When to revisit

- A second person joins: teams, and per-repo roles.
- The project needs single sign-on for GitHub: GitHub Enterprise Cloud.

## Open items

- Phase 1 step 1.1: create the organization and group, transfer the repo and the mirror, redo the docs site's domain, and move the documents' links.
