#!/usr/bin/env python3
"""Check bash scripts against the RussetLeaf bash script standard (docs/standards/bash.md).

Checks what shellcheck (correctness) and shfmt (layout) do not:

Every script and library:
  - a file header naming the file ("# <file name>") and the GPL v3.0 license line
  - every function written as `function name() {`, directly below a header block
    (a "########################################" line, comment lines, another one)

Scripts (*.sh outside lib/):
  - line 1 is `#!/usr/bin/env bash`, and `set -Eeuo pipefail` is in the first 3 lines
  - the functions init_script, parse_params, usage and main, and `main "$@"` last
  - the options -h|--help, -n|--no-color and -v|--verbose, and an "Exit codes:" section
  - lib/common.sh sourced and install_traps called
  - executable, with a test at tests/<name>.bats next to it (scripts inside a tests/
    directory are tests themselves, and are exempt)

Libraries (*.bash, and *.sh inside a lib/ directory):
  - line 1 is `# shellcheck shell=bash`, and no main

Usage: tools/check_bash_style.py [files...]   (default: every tracked *.sh and *.bash file)
"""
import os
import re
import subprocess
import sys
from pathlib import Path

RULE = '#' * 40
LICENSE = '# This program is licensed under the terms of the GNU General Public License v3.0.'
FUNCTION_DEF = re.compile(r'^\s*function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{')
BARE_FUNCTION_DEF = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{')
REQUIRED_FUNCTIONS = ('init_script', 'parse_params', 'usage', 'main')
REQUIRED_OPTIONS = {
    '-h | --help)': '-h|--help',
    '-n | --no-color)': '-n|--no-color',
    '-v | --verbose)': '-v|--verbose',
}


def shell_files():
    out = subprocess.run(['git', 'ls-files', '*.sh', '*.bash'], capture_output=True, text=True, check=True).stdout
    return [Path(p) for p in out.split()]


def is_library(path):
    return path.suffix == '.bash' or 'lib' in path.parts


def is_test(path):
    return 'tests' in path.parts


def check_header_blocks(lines):
    """Every function is `function name() {`, directly below a complete header block."""
    problems = []
    for n, line in enumerate(lines, 1):
        if BARE_FUNCTION_DEF.match(line) and not FUNCTION_DEF.match(line):
            problems.append((n, 'write functions as `function name() {`'))
            continue
        match = FUNCTION_DEF.match(line)
        if not match:
            continue
        above = n - 2  # index of the line directly above
        if above < 0 or lines[above].strip() != RULE:
            problems.append((n, f'function {match.group(1)} has no header block directly above it'))
            continue
        top = above - 1
        while top >= 0 and lines[top].startswith('#') and lines[top].strip() != RULE:
            top -= 1
        if top < 0 or lines[top].strip() != RULE or top == above - 1:
            problems.append((n, f'function {match.group(1)}: the header block needs an opening '
                                f'"{RULE[:8]}..." line and a description'))
    return problems


def check_file_header(path, lines):
    problems = []
    if not any(line.strip() == f'# {path.name}' for line in lines[:12]):
        problems.append((1, f'the file header must name the file ("# {path.name}")'))
    if not any(line.strip() == LICENSE for line in lines[:40]):
        problems.append((1, f'the file header must include the license line: "{LICENSE}"'))
    return problems


def check_script(path, lines, text):
    problems = []
    if not lines or lines[0] != '#!/usr/bin/env bash':
        problems.append((1, 'line 1 must be `#!/usr/bin/env bash`'))
    if not any(line.strip() == 'set -Eeuo pipefail' for line in lines[:3]):
        problems.append((1, '`set -Eeuo pipefail` must be in the first 3 lines'))

    defined = {m.group(1) for line in lines if (m := FUNCTION_DEF.match(line))}
    for name in REQUIRED_FUNCTIONS:
        if name not in defined:
            problems.append((1, f'missing the {name} function'))
    last = next((line.strip() for line in reversed(lines) if line.strip()), '')
    if last != 'main "$@"':
        problems.append((len(lines), 'the last line must be `main "$@"`'))

    for pattern, option in REQUIRED_OPTIONS.items():
        if pattern not in text:
            problems.append((1, f'parse_params must handle {option}'))
    if 'Exit codes:' not in text:
        problems.append((1, 'usage must list the exit codes ("Exit codes:")'))

    if not re.search(r'^\s*source\s+"[^"]*lib/common\.sh"', text, re.M):
        problems.append((1, 'must source lib/common.sh'))
    if not re.search(r'^\s*install_traps\s*$', text, re.M):
        problems.append((1, 'must call install_traps'))

    if not os.access(path, os.X_OK):
        problems.append((1, 'must be executable (git update-index --chmod=+x)'))
    if not is_test(path):
        test = path.parent / 'tests' / f'{path.stem}.bats'
        if not test.exists():
            problems.append((1, f'needs a test: {test}'))
    return problems


def check_library(lines, text):
    problems = []
    if not lines or lines[0] != '# shellcheck shell=bash':
        problems.append((1, 'line 1 of a library must be `# shellcheck shell=bash`'))
    if re.search(r'^\s*main\s+"\$@"\s*$', text, re.M):
        problems.append((1, 'a library is sourced, so it must not call main'))
    return problems


def check(path):
    text = path.read_text()
    lines = text.splitlines()
    problems = check_file_header(path, lines) + check_header_blocks(lines)
    if is_library(path):
        problems += check_library(lines, text)
    else:
        problems += check_script(path, lines, text)
    return sorted(problems)


def main():
    files = [Path(a) for a in sys.argv[1:]] or shell_files()
    files = [f for f in files if f.suffix in ('.sh', '.bash')]
    total = 0
    for f in files:
        for n, msg in check(f):
            print(f'{f}:{n}: {msg}')
            total += 1
    if total:
        print(f'\n{total} issue(s). See docs/standards/bash.md (and scripts/templates/script-template.sh).')
        return 1
    print(f'Checked {len(files)} shell files: all follow the bash script standard.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
