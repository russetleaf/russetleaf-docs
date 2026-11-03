# RussetLeaf

RussetLeaf is a portfolio project: a production-grade WordPress platform, designed, planned and built the way a platform team would do it. It covers infrastructure as code, GitOps, layered security, observability, tested delivery and operations, with every significant decision recorded. This site is the project's documentation: how the platform works, why it is built that way, and how the build is planned and tracked.

The live site it runs is **[russetleaf.dev](https://russetleaf.dev)**.

## The three phases

| Phase | What it builds | Status |
|---|---|---|
| **[1. russetleaf.dev](phase-1-russetleaf-dev/design.md)** | WordPress on a three-node, highly available Talos Kubernetes cluster at home, running 24/7, with the AWS Organization it uses | In progress ([roadmap](phase-1-russetleaf-dev/roadmap.md)) |
| **[2. AI summaries and MLOps](phase-2-ai-mlops/design.md)** | AI-generated post summaries with an LLM gateway, a self-hosted model and a full MLOps lifecycle | Planned (optional) |
| **[3. russetleaf.com](phase-3-russetleaf-com/design.md)** | The same site on the full AWS production design (EKS, RDS, CloudFront), brought up only for demos | Planned (optional) |

## Where to start

- **[Overview](overview.md):** the phases, how the two sites compare, defense in depth, the threat model, compliance, effort and the repositories.
- **[Phase 1 design](phase-1-russetleaf-dev/design.md):** the architecture of russetleaf.dev, with diagrams.
- **[Runbooks](runbooks.md):** every runbook in the project (incidents, security, recovery, rollback and alerts), with the step that writes it and how it is rehearsed.
- **[Architecture decision records](overview.md#architecture-decision-records):** every significant decision, with the alternatives considered and when it would be revisited.
- **[Phase 1 plan](phase-1-russetleaf-dev/plan.md)** and **[roadmap](phase-1-russetleaf-dev/roadmap.md):** the build steps, each with a test, estimates against actual hours, and milestones with target and actual dates.

## How this documentation is kept

- Written as Markdown in the [`russetleaf-docs`](https://github.com/smscully/russetleaf-docs) repo, reviewed in pull requests, and published here by GitHub Actions; the build fails on any broken link.
- Diagrams are written as code (Mermaid, following the C4 model) next to the text they illustrate.
- Each build step starts with a short spec and ends with its actual hours and what changed; each milestone ends with a short retro.
- Planned and built with the help of Claude (Anthropic's AI assistant); every decision is reviewed and owned by the author.
