# ADR 1038: Separate documentation repo, published as a docs site

- **Status:** Accepted; updated by [ADR 1046](1046-incident-response-and-runbook-index.md) and [ADR 1053](1053-open-source-tools-by-default.md)
- **Date:** 2026-11-02
- **Applies to:** the project documentation and planning, across all repos
- **Phase:** 1 (all phases add their documents here)

> **Update ([ADR 1046](1046-incident-response-and-runbook-index.md)):** runbooks still live with their code, but the docs site's [Runbooks](../../runbooks.md) page is the **one index** of every runbook in every repo; `russetleaf-gitops/docs/runbooks/README.md` points to it.

> **Update ([ADR 1053](1053-open-source-tools-by-default.md)):** the site is built with **Zensical** (MIT), the successor to MkDocs and Material for MkDocs from the same team, because Material for MkDocs reaches end of life on May 5, 2027. Zensical reads the same `mkdocs.yml`, and `zensical build --strict` fails on broken pages and anchors as before.

## Context

The documentation (overview, phase designs, plans and roadmaps, the ADRs, step specs) describes the whole system across four code repos and three phases, and is published so the design and its decisions can be read without the code. It was going to move into `russetleaf-gitops`, which would make one code repo the owner of documents about all of them, mix documentation commits with deployment config, and leave readers to find the design among Kubernetes manifests. Planning issues and milestones also span all repos. The repo holding the documents (`private-test-wordpress`) no longer held anything else.

## Decision

- **A dedicated documentation repo, `russetleaf-docs`** (the former `private-test-wordpress`, renamed on 2026-11-02, history kept), public, holding the project-level documents: the overview, phase designs, plans and roadmaps, all ADRs, step specs, the threat model and control matrix, strategy documents and postmortems.
- **Operational docs stay with their code:** runbooks (linked from alerts), SLO definitions, chaos and performance results, security reports and the Talos hardening notes live in `docs/` of the repo that produces or uses them, mostly `russetleaf-gitops`; the docs site links to them.
- **Planning lives here too:** the milestones, one issue per step (created by `tools/plan_to_issues.py`) and the public GitHub Projects board.
- **A docs site:** **MkDocs** with the **Material** theme, built by GitHub Actions and published on **GitHub Pages** at **`docs.russetleaf.dev`** (a CNAME in Cloudflare, DNS only, with the domain verified in the GitHub account to prevent subdomain takeover). The build runs in **strict mode** on every pull request, so a broken link or anchor fails it, a **reference check** fails on any ADR or document mentioned without a link, a **style check** fails on second person or contractions, and **markdownlint** checks the formatting MkDocs is stricter about than GitHub (blank lines around lists, tables and headings; 4-space nested lists).
- **Diagrams as code:** **Mermaid**, following the **C4 model** (system context, then containers) for each phase, kept in the same Markdown so they change in the same pull request.
- **Keeping docs current:** each code repo's pull-request template asks whether the docs need updating; each step's spec is written here before the code.

## Alternatives considered

- **Docs in `russetleaf-gitops`** (the earlier plan): one fewer repo and docs nearer the manifests, but one code repo owns documents about all of them, and readers land in deployment config.
- **Docs in each code repo:** closest to the code, but the cross-cutting design and ADRs have no natural home and get duplicated or scattered.
- **A wiki (GitHub Wiki, Confluence, Notion):** easy to edit, but outside pull-request review and CI, so no link checking and no history tied to the work.
- **Other site generators (Docusaurus, Hugo, Backstage TechDocs):** all capable; MkDocs Material needs only Markdown and a small config, renders Mermaid, and is widely used for infrastructure projects. Backstage TechDocs (Phase 1 step 8.3) can render the same Markdown later.

## Consequences

- One entry point for readers: the repo README and the docs site.
- A risk of docs drifting from code, reduced by the pull-request template checkbox, specs written before each step, and the strict build.
- One more repo to secure (branch protection, Scorecard, Renovate for the pinned MkDocs and Actions versions).
- References to `docs/...` paths now mean either this repo's `docs/` (project documents) or a code repo's `docs/` (operational documents); the overview's repository section says which goes where.

## When to revisit

- The docs and code drift apart in practice: move more documents next to the code.
- Backstage becomes the main portal (Phase 1 step 8.3): consider serving these docs through TechDocs as well.

## Open items

- ~~Set up `docs.russetleaf.dev`~~: done 2026-11-02 (records added by hand; imported into OpenTofu in Phase 1 step 2.3).
- Phase 1 step 1.1: add the README links and pull-request templates in the code repos, and create the issues and Projects board here.
