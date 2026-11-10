# RussetLeaf documentation

Design, plans, roadmap and architecture decisions for **RussetLeaf**, an open-source reference implementation of a production-grade WordPress platform, built the way a platform team would build it: a highly available Talos Kubernetes cluster at home running [russetleaf.dev](https://russetleaf.dev) (Phase 1), AI post summaries with an MLOps lifecycle (Phase 2), and the same site on the full AWS production design for demos (Phase 3).

**Read it as a website:** https://docs.russetleaf.dev

## Contents

- [`docs/index.md`](docs/index.md): start here
- [`docs/overview.md`](docs/overview.md): the phases, shared design, security, compliance, effort, repositories and the index of all ADRs
- [`docs/runbooks.md`](docs/runbooks.md): the index of every runbook ([on the site](https://docs.russetleaf.dev/runbooks/))
- `docs/phase-1-russetleaf-dev/`, `docs/phase-2-ai-mlops/`, `docs/phase-3-aws-russetleaf-dev/`: each phase's `design.md`, `plan.md`, roadmap and `adr/`
- [`docs/specs/TEMPLATE.md`](docs/specs/TEMPLATE.md): the short spec written before each build step
- [`tools/plan_to_issues.py`](tools/plan_to_issues.py): creates the GitHub milestones and one issue per step from a phase's plan and roadmap
- [`docs/standards/bash.md`](docs/standards/bash.md): the bash script standard every repo follows, with [`AGENTS.md`](AGENTS.md) (read by every Claude Code session through `CLAUDE.md`)
- [`scripts/workstation/`](scripts/workstation/): `setup-ubuntu.sh` sets up an Ubuntu 24.04 workstation for the project, and `check-tools.sh` reports every tool's version (see the plan's workstation setup)

## The repositories

| Repo | Purpose |
|---|---|
| `russetleaf-docs` (this repo) | Project documentation, planning issues and the docs site |
| `russetleaf-gitops` | What runs on the clusters (Argo CD's source of truth), plus runbooks and operational docs |
| `russetleaf-infra` | OpenTofu for AWS, Cloudflare and the Talos cluster |
| `russetleaf-wordpress` | The custom WordPress image and its Helm chart |
| `russetleaf-llm-summarizer` | The AI summarizer and its MLOps pipeline (Phase 2) |

The code repos are created in Phase 1 step 1.1 (and Phase 2 step 1.1).

## Building the docs site locally

```sh
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements-docs.txt
zensical serve          # http://localhost:8000
zensical build --strict # what CI runs: fails on broken links and anchors
```

Planned and built with the help of Claude (Anthropic's AI assistant); every decision is reviewed and owned by the project's maintainer.

## License

Licensed under the GNU General Public License v3.0: see [`LICENSE`](LICENSE). It covers everything in this repo: the documentation, the scripts and the tools. The one exception is the RussetLeaf **name and logo**, which are reserved (copyright Steven Scully, all rights reserved) and kept only in `brand/` folders; forks may use everything else, under a name and logo of their own ([ADR 1049](docs/phase-1-russetleaf-dev/adr/1049-licensing.md)).
