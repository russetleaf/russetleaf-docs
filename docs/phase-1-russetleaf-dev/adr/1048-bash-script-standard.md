# ADR 1048: One bash script standard for every repo, enforced by checks and agent instructions

- **Status:** Accepted
- **Date:** 2026-11-04
- **Applies to:** every bash script in every RussetLeaf repo
- **Phase:** 1 (this repo now; each code repo from step 1.1). Updates [ADR 2004](../../phase-2-ai-mlops/adr/2004-agentic-ai-delivery.md) by bringing the `AGENTS.md` and `CLAUDE.md` files forward from Phase 2.

## Context

The workstation scripts (`scripts/workstation/setup-ubuntu.sh` and `check-tools.sh`) set the format the project wants for bash: a header block on every function, a fixed layout (`init_script`, `parse_params`, `usage`, the steps, `main`), named exit codes, `--help`, `--verbose` and `--no-color`, a shared library for messages and for error and signal handling, and bats tests plus an end-to-end test in CI. Writing them found real bugs that only tests and a real run caught: a setup script that failed on every second run, and a `sudo` check that failed for a common sudoers setup.

More scripts will follow in every repo: CI helpers, CronJob and Job scripts in `russetleaf-gitops`, Terraform wrappers in `russetleaf-infra`, runbook automation. Two things would let them drift from the format:

- **Nothing checked the format.** shellcheck finds bugs and shfmt fixes layout, but neither checks the structure (header blocks, required functions and options, exit codes, tests), and nothing ran on commit.
- **Claude does not carry instructions between sessions.** Its memory is tied to the folder a session starts in, so a session in `russetleaf-gitops` would not know about a preference recorded while working in `russetleaf-docs`; and memory is a reminder, not a check.

## Decision

**A written standard and a template:** the [bash script standard](../../standards/bash.md) (the rules and the reasons for each, published on the docs site), and a starter script and test, `scripts/templates/script-template.sh` and `scripts/templates/tests/script-template.bats`, which run and pass every check as they are.

**One shared library, kept here:** `scripts/lib/common.sh` (messages with fixed formats, colors only on a terminal, an ERR trap that reports the failed command, INT and TERM handlers that stop the script, tracing) and `scripts/lib/bats-helpers.bash` (the isolated PATH and stubs for tests). Other repos keep **identical copies** of these, and of the style checker and the hook script (`tools/check_bash_style.py` and `tools/claude_bash_hook.py`, which pre-commit and the hook run locally); CI fails if any copy differs.

**Automatic checks, at three points:**

| Check | Pre-commit | Claude Code hook | CI |
|---|---|---|---|
| shellcheck | Yes | Yes | Yes |
| shfmt `-i 2 -ci` | Yes | Yes | Yes |
| `tools/check_bash_style.py`: the file header, a header block on every function, the required functions and options, an `Exit codes:` section, the shared library, executable, a test for every script | Yes | Yes | Yes |
| bats | No | The edited file's tests | Yes |
| Shared files' copies unchanged (the library, the checker, the hook) | No | No | Yes |

- **Pre-commit:** `.pre-commit-config.yaml` in every repo, with local hooks that use the tools the workstation setup script installs (now including shfmt and bats), so nothing is downloaded.
- **Claude Code hook:** `.claude/settings.json` in every repo runs `tools/claude_bash_hook.py` after Claude writes or edits a shell file. A failure is handed back to Claude (exit code 2) with the exact problem, so it is fixed in the same session.
- **CI:** a **reusable workflow**, `.github/workflows/bash-checks.yml` in this repo, called by every repo and pinned to a commit. One definition, so the checks cannot differ between repos.

**Agent instructions, brought forward from Phase 2:** an `AGENTS.md` in every repo, with a `CLAUDE.md` that imports it. Claude Code loads `CLAUDE.md` at the start of every session in a repo, so the rule ("bash scripts follow the standard, start from the template, pass the checks, have tests") is present without being repeated. [ADR 2004](../../phase-2-ai-mlops/adr/2004-agentic-ai-delivery.md) planned these files for Phase 2's coding agents; they now start in Phase 1.

**Bash only where it fits:** scripts that mostly run other commands are bash; anything that mainly processes data is Python, as the repo's `tools/` are.

## Alternatives considered

- **The written standard alone:** cheapest, but nothing stops drift, and a reviewer has to remember every rule.
- **shellcheck and shfmt only:** catch bugs and layout, but not the structure, which is most of what makes these scripts consistent.
- **bashate** (OpenStack's bash style checker): checks indentation and some style rules, but not this project's structure, and duplicates shfmt for the rest.
- **A shared library as a git submodule:** one copy instead of identical ones, but submodules complicate cloning, CI and every checkout; a small file copied with a drift check is simpler and fails just as loudly.
- **Publishing the library as a package** (a `.deb` or a release asset fetched at runtime): versioned, but a network dependency for every script, and more machinery than two small files need.
- **Relying on Claude's memory:** works within this repo's folder only, and checks nothing.
- **A Backstage software template** (Phase 1 step 8.3) to scaffold new scripts: a good addition later for new services, but an Advanced step that may not be built; the template file works without it.
- **Following the Google style guide's limit** (rewrite any script over about 100 lines in another language): the workstation setup script is longer, but it is almost entirely calls to apt, curl and other commands, which bash does best. The rule here is about what a script does (running commands, or processing data), not its length.

## Consequences

- Every script in every repo has the same shape, options, exit codes, error handling and tests, and a new one starts compliant from the template.
- Drift is caught three times: at commit, right after an edit by Claude, and in CI.
- A new or changed check reaches every repo through one reusable workflow; each repo picks it up by updating its pin.
- The shared library's copies must be updated together; the drift check makes a forgotten copy fail rather than diverge.
- More checks to maintain: the style checker is a small Python file in this repo, tested by running it against the template and the workstation scripts in CI.
- Committing in any repo now needs the workstation tools (shellcheck, shfmt, bats), which the setup script installs.

## When to revisit

- The style checker's rules start blocking reasonable scripts: change the standard and the checker together.
- More than a handful of repos carry the library: consider publishing it as a versioned package instead of copies.
- Scripts in some repo are mostly data processing: move them to Python rather than bending the standard.

## Open items

- Phase 1 step 1.1: in each code repo, an `AGENTS.md` (with this bash section), a `CLAUDE.md` importing it, `.pre-commit-config.yaml`, `.claude/settings.json` with the hook, copies of `scripts/lib/`, `tools/check_bash_style.py` and `tools/claude_bash_hook.py`, and a call to the reusable workflow.
