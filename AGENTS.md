# Instructions for working in russetleaf-docs

This repo holds the RussetLeaf project's documentation (published at https://docs.russetleaf.dev), planning, ADRs and shared tooling. These instructions apply to anyone working here, people and coding agents alike; `CLAUDE.md` imports this file so Claude Code reads it at the start of every session. The rules for coding agents in later phases are in [ADR 2004](docs/phase-2-ai-mlops/adr/2004-agentic-ai-delivery.md).

## Bash scripts

Every bash script follows the **[bash script standard](docs/standards/bash.md)** ([ADR 1048](docs/phase-1-russetleaf-dev/adr/1048-bash-script-standard.md)), without exception and without needing to be asked:

- Start from `scripts/templates/script-template.sh` and its test, `scripts/templates/tests/script-template.bats`.
- Source `scripts/lib/common.sh` for messages, colors, error and signal handling, and `--verbose` tracing. Change the library only here; other repos keep identical copies.
- Every script has a bats test at `tests/<name>.bats` next to it. Tests use the isolated PATH and stubs from `scripts/lib/bats-helpers.bash`, and never change the machine they run on.
- The checks (shellcheck, shfmt `-i 2 -ci`, `tools/check_bash_style.py`, bats) run in pre-commit, in the Claude Code hook after every edit to a shell file, and in CI. Fix what they report; do not disable a check to make it pass, except with a `# shellcheck disable=...` on the one line it applies to and a comment saying why.
- Anything that mainly processes data is written in Python instead (see `tools/`).

## Documentation

- **Writing style:** third person ("the operator"), no second person, no contractions; instructions in the imperative. See "Writing style" and "References are links" in the [overview](docs/overview.md).
- **References are links:** every mention of an ADR or an existing document is a Markdown link; files that do not exist yet appear as plain paths.
- **ADRs:** take the next free number in the phase, start from the [ADR template](docs/adr/0000-template.md), and add the ADR to the index in the [overview](docs/overview.md), the `nav` in `mkdocs.yml` and the ADR table in the [Phase 1 plan](docs/phase-1-russetleaf-dev/plan.md). An ADR that changes an earlier one adds an "Update" note to it.
- **Plan estimates:** when a step's hours change, update its checklist row, the tier totals and calendar figures in the plan, the totals in the [overview](docs/overview.md) and [ADR 1037](docs/phase-1-russetleaf-dev/adr/1037-project-phases.md), and recompute the roadmap's milestone dates.
- **Runbooks** are listed in the [runbook index](docs/runbooks.md), the only index ([ADR 1046](docs/phase-1-russetleaf-dev/adr/1046-incident-response-and-runbook-index.md)). The step that writes a runbook turns its entry into a link.

## License

Everything in the repo is licensed under the GNU General Public License v3.0 (`LICENSE`). Every script, library, test and tool carries the line `# This program is licensed under the terms of the GNU General Public License v3.0.` in its header. The exception is the RussetLeaf **name and logo** ([ADR 1049](docs/phase-1-russetleaf-dev/adr/1049-licensing.md)): reserved, kept only in `brand/` folders, and never copied or inlined (for example as SVG in a template) anywhere else.

## Checks before finishing

Run these, and fix anything they report:

```bash
pre-commit run --all-files     # shellcheck, shfmt, bash standard, doc references, writing style
bats -r scripts                # the scripts' tests
mkdocs build --strict          # broken links and anchors (in a venv with requirements-docs.txt)
```

Install the hooks once per clone with `pre-commit install`. The tools come from `scripts/workstation/setup-ubuntu.sh`.
