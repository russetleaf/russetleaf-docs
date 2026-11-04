#!/usr/bin/env python3
"""Claude Code PostToolUse hook: check a shell file right after Claude writes or edits it.

Reads the hook's JSON from stdin. If the file is a *.sh, *.bash or *.bats file in this
repo, it runs the same checks as pre-commit and CI on that file:
  - shellcheck -x, shfmt -d -i 2 -ci and tools/check_bash_style.py (*.sh and *.bash)
  - bats on the file's tests: the file itself for *.bats, or tests/<name>.bats next to
    a script
Any failure is written to stderr with exit code 2, which Claude Code passes back to
Claude, so a script that breaks the bash script standard is fixed in the same session.
Other files are ignored (exit 0).

Configured in .claude/settings.json. See docs/standards/bash.md.
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

SHELL_SUFFIXES = ('.sh', '.bash')


def run(command, cwd):
    """Run a command; return its output if it failed, otherwise None."""
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=180)
    if result.returncode == 0:
        return None
    return (result.stdout + result.stderr).strip() or f'{command[0]} exited with {result.returncode}'


def main():
    payload = json.load(sys.stdin)
    raw = (payload.get('tool_input') or {}).get('file_path') or (payload.get('tool_response') or {}).get('filePath')
    if not raw:
        return 0
    root = Path(os.environ.get('CLAUDE_PROJECT_DIR') or Path(__file__).resolve().parent.parent).resolve()
    path = Path(raw).resolve()
    try:
        relative = path.relative_to(root)
    except ValueError:
        return 0  # outside this repo
    if path.suffix not in SHELL_SUFFIXES + ('.bats',) or not path.exists():
        return 0

    missing = [tool for tool in ('shellcheck', 'shfmt', 'bats') if not shutil.which(tool)]
    if missing:
        print(f'bash checks skipped: {", ".join(missing)} not installed; '
              'run scripts/workstation/setup-ubuntu.sh', file=sys.stderr)
        return 2

    failures = []
    if path.suffix in SHELL_SUFFIXES:
        checks = [
            ('shellcheck', ['shellcheck', '-x', str(relative)]),
            ('shfmt (layout; fix with: shfmt -w -i 2 -ci <file>)', ['shfmt', '-d', '-i', '2', '-ci', str(relative)]),
            ('bash script standard', [sys.executable, 'tools/check_bash_style.py', str(relative)]),
        ]
        for name, command in checks:
            output = run(command, root)
            if output:
                failures.append(f'## {name}\n{output}')

    if path.suffix == '.bats':
        tests = path
    else:
        tests = path.parent / 'tests' / f'{path.stem}.bats'
    if tests.exists():
        output = run(['bats', str(tests.relative_to(root))], root)
        if output:
            failures.append(f'## bats ({tests.relative_to(root)})\n{output}')

    if failures:
        print(f'{relative} does not pass the bash checks (docs/standards/bash.md):\n\n'
              + '\n\n'.join(failures), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
