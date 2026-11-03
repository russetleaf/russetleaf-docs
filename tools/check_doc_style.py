#!/usr/bin/env python3
"""Check the documentation's writing style: no second person and no contractions.

Fails (exit 1) on "you", "your", "yours", "yourself" or "yourselves", and on contractions
such as "can't", "it's", "they're", "we'll", "I'd" or "you've".

Allowed: code blocks, inline code, link targets, HTML comments, and quoted text ("...") such as
commands, test inputs or sample prompts, which must stay verbatim. A line can also be exempted
by ending it with the comment <!-- style: allow -->.

Usage: tools/check_doc_style.py [files...]   (default: every Markdown file in the repo)
"""
import re
import subprocess
import sys
from pathlib import Path

SECOND_PERSON = re.compile(r"\b(you|your|yours|yourself|yourselves)\b", re.I)
CONTRACTION = re.compile(
    r"\b[a-z]+n['’]t\b"                                     # can't, doesn't, won't
    r"|\b[a-z]+['’](re|ll|ve|d|m)\b"                        # they're, we'll, you've, I'd, I'm
    r"|\b(it|that|there|here|what|who|where|let|he|she)['’]s\b",  # it's, that's, let's
    re.I)
PROTECT = re.compile(r"`[^`]*`|\]\([^)]*\)|https?://\S+|\"[^\"]*\"|“[^”]*”")
ALLOW = '<!-- style: allow -->'


def markdown_files():
    out = subprocess.run(['git', 'ls-files', '*.md'], capture_output=True, text=True, check=True).stdout
    return [Path(p) for p in out.split()]


def check(path):
    problems = []
    fence = comment = False
    for n, line in enumerate(path.read_text().splitlines(), 1):
        if line.lstrip().startswith('```'):
            fence = not fence
            continue
        if fence or line.rstrip().endswith(ALLOW):
            continue
        if comment:
            comment = '-->' not in line
            continue
        if '<!--' in line:
            before, after = line.split('<!--', 1)
            comment = '-->' not in after
            line = before + (after.split('-->', 1)[1] if '-->' in after else '')
        text = PROTECT.sub('', line)
        for m in SECOND_PERSON.finditer(text):
            problems.append((n, f'second person "{m.group(0)}"; use "the operator", the imperative, or rephrase'))
        for m in CONTRACTION.finditer(text):
            problems.append((n, f'contraction "{m.group(0)}"; write it out'))
    return problems


def main():
    files = [Path(a) for a in sys.argv[1:]] or markdown_files()
    total = 0
    for f in files:
        for n, msg in check(f):
            print(f'{f}:{n}: {msg}')
            total += 1
    if total:
        print(f'\n{total} style issue(s). See "Writing style" in docs/overview.md.')
        return 1
    print(f'Checked {len(files)} Markdown files: no second person or contractions.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
