# Bash script standard

Every bash script in every RussetLeaf repo follows this standard, whoever writes it: the operator, Claude, or a Phase 2 coding agent. It is enforced by checks, not by memory: a script that does not follow it fails at commit time, right after Claude edits it, and in CI. The reasoning is recorded in [ADR 1048](../phase-1-russetleaf-dev/adr/1048-bash-script-standard.md).

**To start a new script,** copy the template, `scripts/templates/script-template.sh`, to `scripts/<area>/<name>.sh`, and its test, `scripts/templates/tests/script-template.bats`, to `scripts/<area>/tests/<name>.bats`. Both run and pass every check as they are, so a new script starts out compliant. The workstation scripts, `scripts/workstation/setup-ubuntu.sh` and `check-tools.sh`, are full examples.

## Structure

The style follows the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html), with the additions below. A script is laid out in this order:

```bash
#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
set -Eeuo pipefail

# name.sh
#
# What the script does, and anything a reader needs before running it.
#
# This program is licensed under the terms of the GNU General Public License v3.0.

########################################
# Initialize constants, exit codes and global variables
# Arguments:
#   None
########################################
function init_script() { ...; }

function parse_params() { ...; }   # each with its own header block
function usage() { ...; }
function <step>() { ...; }         # one function per step of the work
function main() { ...; }

########################################
# Invoke main function
########################################
main "$@"
```

| Rule | Why |
|---|---|
| `#!/usr/bin/env bash` on line 1, never `#!/bin/bash -i` | An interactive shell loads `~/.bashrc` and aliases, and behaves differently under cron and systemd |
| `set -Eeuo pipefail` | Stop on a failed command, an unset variable or a failed pipeline, with the ERR trap inherited by functions |
| A file header: the file name, a description, and the GPL v3.0 license line (the repo's `LICENSE`) | Says what the file is before anyone reads the code |
| Every function written as `function name() {`, directly below a header block (`########################################`, a description, then `Globals:`, `Arguments:`, `Outputs:` and `Returns:` as they apply) | One look at any function shows what it reads, changes and prints |
| `init_script` first: constants (`readonly`, uppercase), named exit codes (`ERR_*`), then the global variables (lowercase) | Every value the script depends on is in one place |
| `parse_params` with `-h`/`--help`, `-n`/`--no-color` and `-v`/`--verbose`, and any unknown option rejected with exit code 64 | Every script can be explored safely, and a typo never runs as if it were valid |
| `usage` with an `Exit codes:` section | Callers (CI, other scripts, runbooks) can act on the code |
| One function per step, called from `main`, and `main "$@"` as the last line | The flow reads top to bottom in `main` |
| Two-space indents and indented `case` items (shfmt `-i 2 -ci`) | One layout everywhere, applied by a tool |
| Each `# shellcheck disable=...` on the line it applies to, with a comment saying why | Exceptions stay visible and justified |

**Exit codes:** 0 for success; 1 for "a check found a problem" in scripts that check things; **64** for an invalid option or a missing argument; **69** for an unsupported system; **77** for the wrong user or permissions; **78** for a configuration problem; any other non-zero code is that of the command that failed.

## The shared library

Every script sources **`scripts/lib/common.sh`** right after `init_script`, then calls `install_traps`:

| Function | What it does |
|---|---|
| `log_step`, `log_ok`, `log_warn`, `log_error` | Messages with fixed formats (a `%` in a message is printed as text); warnings and errors go to stderr |
| `die CODE MESSAGE` | Print an error and exit with the given code |
| `init_colors "${no_color}"` | Colors only on a terminal, and never with `--no-color` or the `NO_COLOR` environment variable |
| `install_traps` | A failed command is reported with its line number and exit code; Ctrl+C and `kill` stop the script (exit codes 130 and 143) instead of letting it carry on |
| `enable_trace` | `--verbose`: trace every command with the file name and line number |

The library is kept in `russetleaf-docs`. Other repos keep identical copies of `scripts/lib/` and of the two tools the local checks run (`tools/check_bash_style.py` and `tools/claude_bash_hook.py`), and CI fails if any copy differs: they are changed here first, then copied.

## Tests

- **Every script has a bats test** at `tests/<name>.bats` next to it, covering at least `--help`, an unknown option, and the script's own behavior, including its failure paths.
- **Tests never change the machine they run on.** Scripts that install or change things are tested with an isolated PATH of stub commands (`make_isolated_bin`, `run_isolated` and `stub` in `scripts/lib/bats-helpers.bash`), so a failing test hits "command not found", not a real `sudo` or `apt-get`.
- **A script that installs or changes a system** also gets an **end-to-end test** in a throwaway container or VM, run twice to prove a second run changes nothing (as `scripts/workstation/tests/fresh-ubuntu-test.sh` does).

## Where it is checked

| Check | What it catches | Pre-commit | Claude Code hook | CI |
|---|---|---|---|---|
| **shellcheck** | Bugs: quoting, unset variables, format strings, unreachable code | Yes | Yes | Yes |
| **shfmt** `-i 2 -ci` | Layout | Yes | Yes | Yes |
| **`tools/check_bash_style.py`** | The structure above: header blocks, required functions and options, exit codes, the shared library, a test for every script | Yes | Yes | Yes |
| **bats** | Behavior | No (CI and the hook run them) | The edited script's tests | Yes |
| **Shared files drift** | A repo's copy of `scripts/lib/` or the two tools differs from `russetleaf-docs` | No | No | Yes |

- **Pre-commit:** `.pre-commit-config.yaml` in every repo; `pre-commit install` once per clone. The tools come from the [workstation setup script](../phase-1-russetleaf-dev/plan.md#local-workstation-setup-ubuntu-2404).
- **Claude Code hook:** `.claude/settings.json` in every repo runs `tools/claude_bash_hook.py` after Claude writes or edits a shell file, and hands any failure back to Claude, so it is fixed in the same session.
- **CI:** the reusable `bash-checks.yml` workflow in `russetleaf-docs`, called by every repo, pinned to a commit.
- **Agent instructions:** each repo's `AGENTS.md` (imported by its `CLAUDE.md`) points to this page, so every session starts with the rule in front of it.

## When not to use bash

Bash is for scripts that mostly run other commands: installing tools, calling CLIs, gluing steps together. Anything that mainly **processes data** (parsing JSON or YAML beyond a `jq` one-liner, building reports, talking to APIs) is written in **Python**, as this repo's `tools/` are.
