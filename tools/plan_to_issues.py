#!/usr/bin/env python3
"""Create GitHub milestones, labels and one issue per step from a phase's plan and roadmap.

Reads a phase's `plan.md` (steps, tiers, estimates, tests) and `roadmap.md`
(milestones and the steps in each), then creates, in the given repo:
  - one milestone per roadmap milestone, due on its "Latest" date
  - labels: phase, tier and stage
  - one issue per step, with the step's work as a checklist and its test as
    acceptance criteria, in the right milestone

It is a dry run unless --apply is given, and it is safe to run again: milestones,
labels and issues that already exist (matched by title) are left alone.
Needs the GitHub CLI (`gh`), signed in with access to the repo.

Usage:
  tools/plan_to_issues.py --phase-dir docs/phase-1-russetleaf-dev --repo smscully/russetleaf-docs
  tools/plan_to_issues.py --phase-dir docs/phase-1-russetleaf-dev --repo smscully/russetleaf-docs --apply
"""
import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path

TIER_COLOURS = {'Core': '0e8a16', 'Extended': '1d76db', 'Advanced': '5319e7'}


def slug(heading):
    h = re.sub(r'[^\w\- ]', '', heading.strip().lower())
    return h.replace(' ', '-')


def parse_plan(text):
    """Return steps in plan order: number, title, anchor, do, test, tier, estimate."""
    steps = []
    for m in re.finditer(r'^### (Step (\d+\.\d+[a-z]?)(?: \(optional\))?: (.+))$', text, re.M):
        start = m.end()
        nxt = re.search(r'^#{2,3} ', text[start:], re.M)
        body = text[start:start + nxt.start()] if nxt else text[start:]
        do = re.search(r'\*\*Do(?:[^*]*)?:?\*\*:?(.*?)(?=^\*\*Test:\*\*|\Z)', body, re.S | re.M)
        test = re.search(r'^\*\*Test:\*\*(.*)', body, re.S | re.M)
        steps.append({'num': m.group(2), 'title': m.group(3).strip(), 'anchor': slug(m.group(1)),
                      'do': do.group(1).strip() if do else body.strip(),
                      'test': test.group(1).strip() if test else ''})
    checklist = text.split('## Progress checklist', 1)[1] if '## Progress checklist' in text else ''
    rows = {m.group(1): (m.group(2), m.group(3)) for m in
            re.finditer(r'^\| (\d+\.\d+[a-z]?) [^|]*\| (\w+) \| (\d+–\d+) \|', checklist, re.M)}
    for s in steps:
        s['tier'], s['estimate'] = rows.get(s['num'], ('Unknown', '?'))
    return steps


def expand(spec, order):
    """'0.1–1.1, 5.10' -> the steps in plan order covered by each item."""
    out = []
    for part in [p.strip() for p in spec.split(',') if p.strip()]:
        if '–' in part:
            a, b = [x.strip() for x in part.split('–')]
            out += order[order.index(a):order.index(b) + 1]
        else:
            out.append(part)
    return out


def parse_roadmap(text, order):
    milestones = []
    for line in text.splitlines():
        m = re.match(r'^\| \*\*(M\d+ [^*]+)\*\* \| ([^|]+) \| [^|]+ \| ([^|]+) \| ([^|]+) \|', line)
        if m:
            latest = dt.datetime.strptime(m.group(4).strip(), '%a, %b %d, %Y').date()
            milestones.append({'title': m.group(1).strip(), 'steps': expand(m.group(2), order),
                               'target': m.group(3).strip(), 'due': latest})
    return milestones


def checklist(text, prefix='- [ ] '):
    bullets = re.findall(r'^- (.+)$', text, re.M)
    if bullets:
        return '\n'.join(prefix + b for b in bullets)
    return prefix + 'Complete the work described above.'


def issue_body(step, phase_name, plan_url):
    criteria = [c.strip().rstrip('.') for c in re.split(r';\s+', step['test']) if c.strip()]
    lines = [
        f"**{phase_name}, step {step['num']}** · tier: **{step['tier']}** · estimate: **{step['estimate']} h**",
        f"Plan: {plan_url}#{step['anchor']}" if plan_url else '',
        '', '## Work', '', '\n'.join(l for l in step['do'].splitlines() if not l.startswith('- ')).strip(), '', '## Tasks', '',
        checklist(step['do']),
        '- [ ] Write the step spec from `docs/specs/TEMPLATE.md` before starting',
        '- [ ] Record actual hours (and node memory, where relevant) in the plan\'s checklist',
        '', '## Acceptance criteria (the step\'s test)', '',
        '\n'.join(f'- [ ] {c}' for c in criteria) or '- [ ] See the plan',
    ]
    return '\n'.join(lines).strip() + '\n'


def gh(args, apply, stdin=None):
    if not apply:
        print('  would run: gh ' + ' '.join(a if ' ' not in a else repr(a) for a in args[:6]) + (' ...' if len(args) > 6 else ''))
        return ''
    res = subprocess.run(['gh'] + args, input=stdin, text=True, capture_output=True)
    if res.returncode != 0:
        sys.exit(f'gh failed: {res.stderr.strip()}')
    return res.stdout


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--phase-dir', required=True, help='e.g. docs/phase-1-russetleaf-dev')
    ap.add_argument('--repo', required=True, help='owner/name of the GitHub repo')
    ap.add_argument('--branch', default='main')
    ap.add_argument('--apply', action='store_true', help='actually create things (default: dry run)')
    a = ap.parse_args()

    phase_dir = Path(a.phase_dir)
    phase_num = re.search(r'phase-(\d)', phase_dir.name).group(1)
    phase_name = f'Phase {phase_num}'
    steps = parse_plan((phase_dir / 'plan.md').read_text())
    order = [s['num'] for s in steps]
    roadmap = phase_dir / 'roadmap.md'
    if not roadmap.exists():
        sys.exit(f'{roadmap} not found: write the phase roadmap (milestones and their steps) first')
    milestones = parse_roadmap(roadmap.read_text(), order)
    by_step = {s: m['title'] for m in milestones for s in m['steps']}
    missing = [s for s in order if s not in by_step]
    if missing:
        sys.exit(f'steps not in any roadmap milestone: {missing}')
    plan_url = f'https://github.com/{a.repo}/blob/{a.branch}/{phase_dir.as_posix()}/plan.md'
    print(f"{'Applying' if a.apply else 'Dry run'}: {len(milestones)} milestones, {len(steps)} issues for {a.repo}")

    existing_ms, existing_issues = set(), set()
    if a.apply:
        existing_ms = {m['title'] for m in json.loads(gh(['api', f'repos/{a.repo}/milestones?state=all&per_page=100'], True))}
        existing_issues = {i['title'] for i in json.loads(gh(['issue', 'list', '--repo', a.repo, '--state', 'all', '--limit', '1000', '--json', 'title'], True))}

    labels = [(f'phase-{phase_num}', 'fbca04', phase_name)]
    labels += [(f'tier:{t.lower()}', c, f'{t} tier') for t, c in TIER_COLOURS.items()]
    labels += [(f'stage:{n}', 'ededed', f'Stage {n}') for n in sorted({s.split('.')[0] for s in order}, key=int)]
    for name, color, desc in labels:
        gh(['label', 'create', name, '--repo', a.repo, '--color', color, '--description', desc, '--force'], a.apply)

    for m in milestones:
        if m['title'] in existing_ms:
            print(f"  milestone exists: {m['title']}")
            continue
        gh(['api', f'repos/{a.repo}/milestones', '-f', f"title={m['title']}",
            '-f', f"due_on={m['due'].isoformat()}T23:59:59Z",
            '-f', f"description={phase_name}. Target {m['target']}; latest {m['due']:%a, %b %-d, %Y}. Steps: {', '.join(m['steps'])}."], a.apply)

    for s in steps:
        title = f"[P{phase_num}] {s['num']} {s['title']}"
        if title in existing_issues:
            print(f'  issue exists: {title}')
            continue
        args = ['issue', 'create', '--repo', a.repo, '--title', title, '--body-file', '-',
                '--milestone', by_step[s['num']], '--label', f'phase-{phase_num}',
                '--label', f"tier:{s['tier'].lower()}", '--label', f"stage:{s['num'].split('.')[0]}"]
        gh(args, a.apply, stdin=issue_body(s, phase_name, plan_url))
    if not a.apply:
        sys.stdout.reconfigure(errors='replace')
        print('\nExample issue body:\n' + '-' * 60 + '\n' + issue_body(steps[min(7, len(steps) - 1)], phase_name, plan_url))


if __name__ == '__main__':
    main()
