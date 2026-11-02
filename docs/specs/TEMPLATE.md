# Spec: Phase N step X.Y <step title>

<!--
Write this with Claude at the start of the step, before any code, and keep it short (one or two screens).
Save it as docs/specs/phase-N/X.Y-<short-name>.md, link it from the step's GitHub issue, and update it in
the same pull request if the work turns out differently. Delete these comments.
-->

- **Issue:** #<number>
- **Plan:** <link to the step in the phase plan, e.g. `../../phase-1-russetleaf-dev/plan.md#step-41-storage`>
- **Tier / estimate:** <Core | Differentiator | Stretch | Staff> / <low–high> hours
- **Status:** Draft | In progress | Done
- **Dates:** started YYYY-MM-DD; finished YYYY-MM-DD

## Goal
One or two sentences: what exists when this step is done, and why it matters.

## Context
- Design: the sections of the phase design this step implements (links).
- Decisions: the ADRs it implements or depends on (e.g. ADR 1033), and any open items it resolves.
- Depends on: earlier steps that must be done, and anything to check first (versions, quotas, access).

## Scope
- **In:** what this step builds.
- **Out:** what it deliberately leaves for later steps or phases.

## Approach
How it will be built: the components, files and repos touched, key settings, and anything decided now
that isn't already in an ADR. If a decision is significant or hard to reverse, write or update an ADR
instead of deciding it here.

## Tasks
Small enough to finish and check in a sitting each (roughly 1–3 hours).
- [ ] ...
- [ ] ...

## Acceptance criteria
Copied from the step's **Test** in the plan, made specific (commands, expected output).
- [ ] ...

## Risks and rollback
- What could go wrong, and how to tell.
- How to undo it (see the rollback strategy and its runbooks).

## Outcome
Filled in when the step is done.
- **Actual hours:** <hours> (estimate <low–high>); why it differed, if it did.
- **What changed from this spec, and why.**
- **Follow-ups:** issues opened, ADRs or design sections updated, decision-log entries.
