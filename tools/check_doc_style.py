#!/usr/bin/env python3
# This program is licensed under the terms of the GNU General Public License v3.0.
"""Check the documentation's writing style: no second person, no contractions, and
sentence-case headings, as the documentation style guide (docs/standards/documentation.md) requires.

Fails (exit 1) on "you", "your", "yours", "yourself" or "yourselves"; on contractions
such as "can't", "it's", "they're", "we'll", "I'd" or "you've"; and on headings that are
not in sentence case:
  - A heading that starts with a numbered label ("Stage 2:", "Step 4.1:", "Part 3:", "ADR 1005:")
    continues with a capital, unless that word is a name written in lowercase ("Step 3.1: llama.cpp").
  - Other words start with a lowercase letter, unless they are names: acronyms, words with
    capitals inside (OpenTofu), or entries in the project vocabulary
    (.vale/styles/config/vocabularies/RussetLeaf/accept.txt), which Vale shares.

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
VOCAB = Path(__file__).resolve().parent.parent / '.vale/styles/config/vocabularies/RussetLeaf/accept.txt'
HEADING = re.compile(r'^(#{1,6})\s+(.*?)\s*#*\s*$')
LABEL = re.compile(r'^(?:Stage|Step|Part|ADR|Phase|Spec)(?:\s+[\w.]+)?(?:\s+\(optional\))?:\s+')
WORD = re.compile(r"[A-Za-z][\w.'’/+-]*")


def load_vocab():
    """Return (single-word patterns, multi-word patterns) from the shared Vale vocabulary."""
    single, multi = [], []
    for entry in VOCAB.read_text().splitlines():
        entry = entry.strip()
        if entry and not entry.startswith('#'):
            (multi if ' ' in entry else single).append(re.compile(entry))
    return single, multi


def is_name(word, single):
    """True for words that keep their capitals: acronyms, mixed case, or vocabulary names."""
    core = re.sub(r"['’]s$", '', word).split('-')[0]
    return (not core[:1].isupper() or core.isupper() or any(c.isupper() for c in core[1:])
            or any(ch.isdigit() for ch in core) or any(p.fullmatch(core) for p in single))


def check_heading(text, vocab):
    """Return a message if the heading is not in sentence case, else None."""
    single, multi = vocab
    text = re.sub(r'`[^`]*`', 'CODE', text)
    text = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', text)
    text = PROTECT.sub('QUOTED', text)
    for p in multi:
        text = p.sub('NAME', text)
    label = LABEL.match(text)
    rest = text[label.end():] if label else text
    words = WORD.findall(rest)
    if not words:
        return None
    first = words[0]
    if rest.startswith('<'):
        return None
    if label and first[0].islower() and not ('.' in first or any(p.fullmatch(first) for p in single)):
        return f'heading "{text}": start the title after "{label.group(0).strip()}" with a capital'
    wrong = [w for w in words[1:] if w[0].isupper() and not is_name(w, single)]
    if wrong:
        return f'heading "{text}": use sentence case ({", ".join(wrong)} in lowercase, or add the name to the vocabulary)'
    return None


def markdown_files():
    out = subprocess.run(['git', 'ls-files', '*.md'], capture_output=True, text=True, check=True).stdout
    return [Path(p) for p in out.split()]


def check(path, vocab):
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
        heading = HEADING.match(line)
        if heading:
            msg = check_heading(heading.group(2), vocab)
            if msg:
                problems.append((n, msg))
        text = PROTECT.sub('', line)
        for m in SECOND_PERSON.finditer(text):
            problems.append((n, f'second person "{m.group(0)}"; use "the operator", the imperative, or rephrase'))
        for m in CONTRACTION.finditer(text):
            problems.append((n, f'contraction "{m.group(0)}"; write it out'))
    return problems


def main():
    files = [Path(a) for a in sys.argv[1:]] or markdown_files()
    vocab = load_vocab()
    total = 0
    for f in files:
        for n, msg in check(f, vocab):
            print(f'{f}:{n}: {msg}')
            total += 1
    if total:
        print(f'\n{total} style issue(s). See docs/standards/documentation.md.')
        return 1
    print(f'Checked {len(files)} Markdown files: no second person, contractions or heading-case issues.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
