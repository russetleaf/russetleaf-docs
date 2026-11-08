#!/usr/bin/env python3
# This program is licensed under the terms of the GNU General Public License v3.0.
"""Check that references to ADRs and other documents are links.

Fails (exit 1) on:
  - a plain "ADR 1032" or "ADRs 1004 and 1030" that is not a Markdown link
  - a repo path to an existing document in code formatting, e.g. `docs/phase-1-.../adr/1032-....md`
    or `docs/phase-1-russetleaf-dev/disaster-recovery.md`, instead of a link

Allowed: an ADR's title and mentions of its own number, headings, code blocks, HTML comments, and
paths to files that do not exist yet (such as future runbooks).

Usage: tools/check_doc_links.py [files...]   (default: every Markdown file in the repo)
"""
import re
import subprocess
import sys
from pathlib import Path

LINK = re.compile(r'\[[^\]]*\]\([^)]*\)')
PLAIN_ADR = re.compile(r'\bADRs? (\d{4})((?:(?:, and |, | and |–)\d{4})*)')
DOC_PATH = re.compile(r'`(docs/[A-Za-z0-9_./-]+\.md)`')


def markdown_files():
    out = subprocess.run(['git', 'ls-files', '*.md'], capture_output=True, text=True, check=True).stdout
    return [Path(p) for p in out.split()]


def check(path):
    own = path.name[:4] if path.parent.name == 'adr' else None
    problems = []
    fence = comment = False
    for n, line in enumerate(path.read_text().splitlines(), 1):
        stripped = line.lstrip()
        if stripped.startswith('```'):
            fence = not fence
            continue
        if '<!--' in line:
            comment = '-->' not in line.split('<!--', 1)[1]
            continue
        if comment:
            comment = '-->' not in line
            continue
        if fence or stripped.startswith('#'):
            continue
        text = LINK.sub('', line)
        for m in PLAIN_ADR.finditer(text):
            nums = re.findall(r'\d{4}', m.group(0))
            if any(num != own for num in nums):
                problems.append((n, f'unlinked ADR reference "{m.group(0)}"; write it as [ADR {nums[0]}](relative/path.md)'))
        for m in DOC_PATH.finditer(text):
            if Path(m.group(1)).exists():
                problems.append((n, f'repo path `{m.group(1)}` to an existing document; make it a link'))
    return problems


def main():
    files = [Path(a) for a in sys.argv[1:]] or markdown_files()
    total = 0
    for f in files:
        for n, msg in check(f):
            print(f'{f}:{n}: {msg}')
            total += 1
    if total:
        print(f'\n{total} reference(s) to fix. See "Links and references" in docs/standards/documentation.md.')
        return 1
    print(f'Checked {len(files)} Markdown files: all ADR and document references are links.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
