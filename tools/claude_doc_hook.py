#!/usr/bin/env python3
# This program is licensed under the terms of the GNU General Public License v3.0.
"""Claude Code PostToolUse hook: check a Markdown file right after Claude writes or edits it.

Reads the hook's JSON from stdin. If the file is a *.md file in this repo, it runs the same
documentation checks as pre-commit on that file:
  - vale (the prose rules, with .vale.ini and the project vocabulary)
  - tools/check_doc_style.py (second person, contractions, sentence-case headings)
  - tools/check_doc_links.py (references to ADRs and documents are links)
Any failure is written to stderr with exit code 2, which Claude Code passes back to Claude,
so a document that breaks the documentation style guide is fixed in the same session.
Other files are ignored (exit 0).

Configured in .claude/settings.json. See docs/standards/documentation.md.
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def run(command, cwd):
    """Run a command; return its output if it failed, otherwise None."""
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=120)
    if result.returncode == 0:
        return None
    return (result.stdout + result.stderr).strip() or f'{command[0]} exited with {result.returncode}'


def find_vale(root):
    """Return the path to vale: on the PATH, or through mise when its shell hook is not active."""
    found = shutil.which('vale')
    if found:
        return found
    if shutil.which('mise'):
        result = subprocess.run(['mise', 'which', 'vale'], cwd=root, capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    return None


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
    if path.suffix != '.md' or not path.exists() or relative.parts[0] in ('site', '.venv', '.vale'):
        return 0

    vale = find_vale(root)
    if not vale or not (root / '.vale/styles/Google').is_dir():
        print('documentation checks skipped: vale or its style package is missing; '
              'run scripts/workstation/setup-ubuntu.sh, then vale sync', file=sys.stderr)
        return 2

    failures = []
    checks = [
        ('vale', [vale, '--output=line', str(relative)]),
        ('writing style and headings', [sys.executable, 'tools/check_doc_style.py', str(relative)]),
        ('references are links', [sys.executable, 'tools/check_doc_links.py', str(relative)]),
    ]
    for name, command in checks:
        output = run(command, root)
        if output:
            failures.append(f'## {name}\n{output}')

    if failures:
        print(f'{relative} does not pass the documentation checks (docs/standards/documentation.md):\n\n'
              + '\n\n'.join(failures), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
