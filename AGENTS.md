# Instructions for working in russetleaf-docs

This repo holds the RussetLeaf project's documentation (published at https://docs.russetleaf.dev), planning, ADRs and shared tooling. These instructions apply to anyone working here, people and coding agents alike; `CLAUDE.md` imports this file so Claude Code reads it at the start of every session. The rules for coding agents in later phases are in [ADR 2004](docs/phase-2-ai-mlops/adr/2004-agentic-ai-delivery.md).

## Working in the repo

- **Fix related gaps in the same piece of work.** When a change shows that other documents are now outdated, or reveals a small related gap, fix them in the same change rather than leaving them as suggestions for later. Ask first only when the fix needs a decision the operator has not made.
- **Record deferred work** in the phase's improvements list ([Phase 1](docs/phase-1-russetleaf-dev/improvements.md)) in the same change that puts it off: whenever a cheaper option is chosen for now, a feature is left for later, or a tool is not yet tested, add a row with the reason and its trigger. The list is reviewed after go-live (Phase 1 step 9.3) and quarterly.
- **Record decisions** in the phase plan's [decision log](docs/phase-1-russetleaf-dev/plan.md#decision-log) (date, decision, reason), and significant ones as ADRs.
- **Stage only the files the change touched** (`git add <paths>`, never `git add -A` or `git add .`), because another session or person may have unrelated work in progress in the same clone, and check `git diff --cached` before committing. Commits are signed; the commit message describes everything in it.
- **Open-source tools by default** ([ADR 1053](docs/phase-1-russetleaf-dev/adr/1053-open-source-tools-by-default.md)): when choosing a tool, prefer one under an OSI-approved open-source license. A tool that is not, or whose license changes, is either replaced by an open-source alternative or added to the ADR's exceptions with the reason it is kept.
- **Keep private details out of the repo:** it is public, so no secrets, AWS account or Organization IDs, personal email addresses or phone numbers. Write placeholders such as `<name>+rl-management@<domain>`, and keep real values in Bitwarden, the project's password manager.
- **Professional reasons only:** justify decisions on technical, operational, security, cost or compliance grounds, as industry documentation would. No personal or career reasons (job listings, certifications, what a tool shows on a résumé, "good for a portfolio").
- **No judgments of skill levels** (such as "junior", "intermediate" or "advanced") about people or their work in any file.

## Bash scripts

Every bash script follows the **[bash script standard](docs/standards/bash.md)** ([ADR 1048](docs/phase-1-russetleaf-dev/adr/1048-bash-script-standard.md)), without exception and without needing to be asked:

- Start from `scripts/templates/script-template.sh` and its test, `scripts/templates/tests/script-template.bats`.
- Source `scripts/lib/common.sh` for messages, colors, error and signal handling, and `--verbose` tracing. Change the library only here; other repos keep identical copies.
- Every script has a bats test at `tests/<name>.bats` next to it. Tests use the isolated PATH and stubs from `scripts/lib/bats-helpers.bash`, and never change the machine they run on.
- The checks (shellcheck, shfmt `-i 2 -ci`, `tools/check_bash_style.py`, bats) run in pre-commit, in the Claude Code hook after every edit to a shell file, and in CI. Fix what they report; do not disable a check to make it pass, except with a `# shellcheck disable=...` on the one line it applies to and a comment saying why.
- Anything that mainly processes data is written in Python instead (see `tools/`).

## Documentation

Every Markdown file follows the **[documentation style guide](docs/standards/documentation.md)** ([ADR 1057](docs/phase-1-russetleaf-dev/adr/1057-documentation-style-guide.md)), without exception and without needing to be asked. Read it before writing or revising a document. The rules most often needed:

- **Writing style:** third person ("the operator"), no second person, no contractions; instructions in the imperative; present tense.
- **Structure:** one H1; sentence-case headings, with a capital after a numbered label (`Part 2: Create the GPG key`); numbered lists only for ordered steps; a language on every code block; Markdown that renders the same on GitHub and the docs site.
- **References are links:** every mention of an ADR or an existing document is a Markdown link; files that do not exist yet appear as plain paths.
- **Checks:** Vale, `tools/check_doc_style.py` and `tools/check_doc_links.py` run in pre-commit, in the Claude Code hook after every edit to a Markdown file, and in CI, with markdownlint and the strict build. Fix what they report; a new product or tool name goes in the Vale vocabulary (`.vale/styles/config/vocabularies/RussetLeaf/accept.txt`).
- **ADRs:** take the next free number in the phase, start from the [ADR template](docs/adr/0000-template.md), and add the ADR to the index in the [overview](docs/overview.md), the `nav` in `mkdocs.yml` and the ADR table in the [Phase 1 plan](docs/phase-1-russetleaf-dev/plan.md). An ADR that changes an earlier one adds an "Update" note to it.
- **Plan format:** keep each step's heading as `### Step <n>: <title>`, with **Do:** and **Test:** paragraphs and a matching progress-checklist row (`| <n> <name> | <tier> | <low>–<high> | ...`), because `tools/plan_to_issues.py` builds the GitHub issues and milestones from them; after editing a plan, run it as a dry run (`tools/plan_to_issues.py --phase-dir docs/phase-1-russetleaf-dev --repo <owner>/russetleaf-docs`) to confirm it still parses.
- **Plan estimates:** when a step's hours change, update its checklist row, the tier totals and calendar figures in the plan, the totals in the [overview](docs/overview.md) and [ADR 1037](docs/phase-1-russetleaf-dev/adr/1037-project-phases.md), and recompute the roadmap's milestone dates.
- **Setup guides:** every procedure done by hand (console steps, accounts, hardware) gets a step-by-step guide in `docs/phase-<n>-<site>/setup/<topic>.md` before it is done, so the work is documented in the repo rather than only remembered. Each guide lists what to have ready, gives the **full click path** to each setting, starting from the service's home page or dashboard and using the labels the service shows, ends with checks that match the plan step's test, and is linked from that step and from the `Setup guides` section of the `nav` in `mkdocs.yml`. Each guide carries the standard click-path note (in the [documentation style guide](docs/standards/documentation.md#setup-guides)): providers change their consoles without notice, so a path can go out of date, and the provider's own documentation can lag behind its console too. Before following or giving a click path, check the provider's current documentation; where the screen still differs, follow what the screen shows and fix the guide to match it. The same applies to step-by-step instructions given in a chat session. Every guide cites the official pages its steps come from (see the style guide's [references](docs/standards/documentation.md#links-and-references)). When the real procedure differs from a guide, fix the guide. Examples: [AWS management account](docs/phase-1-russetleaf-dev/setup/aws-management-account.md), [Slack and outside monitoring](docs/phase-1-russetleaf-dev/setup/slack-and-monitoring.md), [lab network](docs/phase-1-russetleaf-dev/setup/lab-network.md).
- **Runbooks** are listed in the [runbook index](docs/runbooks.md), the only index ([ADR 1046](docs/phase-1-russetleaf-dev/adr/1046-incident-response-and-runbook-index.md)). A planned runbook appears there as a plain path with the status **Planned**; the step that writes it turns the path into a link, sets the status to **Written** and records the date of its first rehearsal, and later drills update that date. A new runbook gets an entry in the index in the same change that plans it.

## License

Everything in the repo is licensed under the GNU General Public License v3.0 (`LICENSE`). Every script, library, test and tool carries the line `# This program is licensed under the terms of the GNU General Public License v3.0.` in its header. The exception is the RussetLeaf **name and logo** ([ADR 1049](docs/phase-1-russetleaf-dev/adr/1049-licensing.md)): reserved, kept only in `brand/` folders, and never copied or inlined (for example as SVG in a template) anywhere else.

## Checks before finishing

Run these, and fix anything they report:

```bash
pre-commit run --all-files     # shellcheck, shfmt, bash standard, doc references, writing style, Vale
bats -r scripts                # the scripts' tests
zensical build --strict        # broken links and anchors (in a venv with requirements-docs.txt)
```

CI also runs **markdownlint** (`.markdownlint-cli2.yaml`: heading levels, one H1, `-` bullets, list numbering, blank lines around headings, lists, tables and code blocks, four-space nested lists, code-block languages). The workstation does not install Node.js, so run it through Docker: `docker run --rm -v "$PWD":/workdir davidanson/markdownlint-cli2:v0.14.0`.

Install the hooks once per clone with `pre-commit install`, and Vale's style package with `vale sync`. The tools come from `scripts/workstation/setup-ubuntu.sh`.
