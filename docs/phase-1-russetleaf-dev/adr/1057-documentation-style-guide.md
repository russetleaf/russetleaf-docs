# ADR 1057: One documentation style guide, based on Google's and enforced by Vale

- **Status:** Accepted
- **Date:** 2026-11-07
- **Applies to:** every Markdown file in every RussetLeaf repo, on GitHub and on the docs site
- **Phase:** 1 (this repo now; each code repo from step 1.1)

> **Update (2026-11-12):** setup guides give the full click path to each setting, with a standard note that consoles change, instead of naming only the setting ([style guide: setup guides](../../standards/documentation.md#setup-guides); decision log, 2026-11-12).

## Context

The documentation is the project's main output alongside the code: designs, plans, ADRs, setup guides and runbooks, published at docs.russetleaf.dev and read on GitHub. Its writing rules were spread across `AGENTS.md` and the [overview](../../overview.md) (third person, no contractions, references are links, the plan format), and only those few were checked. Headings, lists, code blocks, names, dates and units varied between documents, and nothing stopped the variation from growing as Claude and, from Phase 2, coding agents write more of them.

The same Markdown files render in two places, GitHub and Zensical, which do not accept exactly the same Markdown: Zensical needs four-space nested lists and blank lines around lists, and each has its own callout syntax that the other shows as plain text.

## Decision

- **One guide for every Markdown file:** the [documentation style guide](../../standards/documentation.md), published in the site's Standards section next to the [bash script standard](../../standards/bash.md). It adopts the **Google developer documentation style guide** as the base and lists the project's differences, each with its reason: third person instead of second, no contractions, no serial comma, punctuation outside quotation marks, and a capital after a numbered label in headings.
- **Only Markdown that renders the same on GitHub and Zensical,** with notes and warnings written as bold labels instead of either platform's callout syntax.
- **Checks enforce what they can,** with the reason for each rule in the guide:
    - **Vale** ([MIT license](https://github.com/errata-ai/vale/blob/v3/LICENSE)), the prose linter most documentation teams use, with the Google style package (pinned to v0.7.1) and a project vocabulary of product and tool names. Only error-level rules are reported, and each one fails the check. The Google rules that conflict with the project's differences are turned off in `.vale.ini`, each with its reason in the guide.
    - **markdownlint** gains the structural rules: heading levels, one H1, `-` bullets, ordered list numbering, code-block languages and emphasis style.
    - **`tools/check_doc_style.py`** also checks sentence-case headings, with the same vocabulary as Vale, because Vale's own heading check cannot apply the numbered-label rule.
- **Checks run at three points:** pre-commit (Vale and the Python checks), a Claude Code hook after every edit to a Markdown file (`tools/claude_doc_hook.py`), and CI (all of them, plus markdownlint and `zensical build --strict`).
- **Vale is pinned** to the same version in CI and on the workstation (installed by `scripts/workstation/setup-ubuntu.sh` through mise).
- **The existing documents were brought into line** in one sweep when the guide was adopted.

## Alternatives considered

- **The Microsoft Writing Style Guide as the base:** equally complete, and it also uses second person and contractions; Google's has a maintained Vale package and is the base for more open-source documentation projects (Kubernetes among them).
- **A house guide without a base:** every topic would have to be written from scratch, and gaps would be decided case by case.
- **Separate rules for the site and for files read only on GitHub:** two sets of rules for the same files, and a file could move between them.
- **Rules only, without Vale:** a guide that depends on memory drifts, the same reason [ADR 1048](1048-bash-script-standard.md) gives for the bash checks.
- **Vale for headings too:** its sentence-case check scores headings against a threshold and cannot express "a capital after a numbered label", so it flagged correct headings and missed incorrect ones.
- **Replacing `tools/check_doc_style.py` with Vale rules:** possible, but the Python check already handles quoted text and the allow comment, and it is needed for headings anyway.

## Consequences

- **One place to look** for how to write a document, linked from `AGENTS.md`, which Claude reads at the start of every session.
- **New documents start consistent,** and the hook reports a broken rule to Claude in the same session as the edit.
- **A new product or tool name** may need a line in the Vale vocabulary before a document using it passes; the guide says how.
- **markdownlint runs only in CI and through Docker,** because the workstation does not install Node.js.
- **Rules that no tool can check** (parallel list items, when to use a table, plain words) depend on review, as before.

## When to revisit

- Google changes its guide in a way the project does not want to follow, or the Vale package stops being maintained.
- A second writer joins, and the differences from Google's guide cause friction.
- Zensical or GitHub changes how either renders Markdown, for example by supporting the other's callout syntax.
