# Documentation style guide

Every Markdown file in the RussetLeaf repos follows this guide, whoever writes it: the operator, Claude, or a Phase 2 coding agent. That covers the pages published at docs.russetleaf.dev and the files read only on GitHub, such as `README.md` and `AGENTS.md`. Checks enforce every rule they can, at commit time, right after Claude edits a file, and in CI ([Checks](#checks)). The reasoning is recorded in [ADR 1057](../phase-1-russetleaf-dev/adr/1057-documentation-style-guide.md).

## The base guide and the differences

The project follows the [Google developer documentation style guide](https://developers.google.com/style) for anything this page does not cover. Where the two differ, this page wins:

| Topic | Google's guide | This project | Why |
|---|---|---|---|
| Person | Second person ("you") | **Third person:** "the operator" for the person who builds and runs the platform, and the imperative for instructions | The documents describe one operator's platform and are also read by coding agents; "the operator" stays clear in both cases |
| Contractions | Encouraged | **None**, except inside quoted text | A formal register suits design records and runbooks used during incidents |
| Serial (Oxford) comma | Required | **Not used**, unless a list item itself contains "and" | Matches the existing documents; a comma is still added where it prevents a misreading |
| Punctuation with quotation marks | Inside the quotation marks | **Outside**, unless it belongs to the quoted text | Quoted text is often a literal UI message or command that must be copied exactly |
| Capital after a colon in a heading | Lowercase | **Capital after a numbered label** (`Step 4.1: Storage`, `Part 2: Create the GPG key`); lowercase after any other colon | The label and number are a prefix to the title, which starts with a capital |
| Word list | "administrator", "app", "command-line tool" | **"admin"**, **"application"** and **"CLI"** are also fine; the [word list](#word-list) below is the project's | These are the terms the tools themselves use (WordPress admin, the AWS CLI) |

## Voice and tone

- **Third person.** Write "the operator", name Claude or the coding agent when one is meant, and never use "you", "we", "us" or "I", except inside quoted text such as a sample prompt.
- **The imperative for instructions:** "Install the hooks", not "The operator should install the hooks".
- **The present tense.** Write "the job deletes old copies", not "the job will delete old copies".
- **No contractions:** "cannot", "does not", "it is".
- **Professional reasons only.** Justify decisions on technical, operational, security, cost or compliance grounds, never on personal or career ones.
- **No judgments of skill levels** about people or their work ("junior", "advanced").
- **Plain, exact words.** Leave out "simply", "just", "easy" and "obviously"; state the number, the setting or the command instead of "some", "a few" or "properly".

## Page structure

- **One H1 per page:** the page title, on the first line. The file name is the title in lowercase with hyphens (`break-glass-kit.md`).
- **An opening paragraph** under the title says what the page is and when to use it.
- **Heading levels:** H2 for sections, H3 for subsections, H4 only when unavoidable. Never skip a level.
- **Sentence case:** capitalize the first word and names only (`Alerting and notifications`, not `Alerting And Notifications`). A numbered label is followed by a capital (`Part 2: Create the GPG key`); any other colon is followed by lowercase (`Availability levels: home lab without HA`).
- **No punctuation at the end of a heading,** and no links in headings.
- **Fixed heading formats** that tools read stay exactly as they are: plan steps as `### Step <n>: <title>`, with **Do:** and **Test:** paragraphs ([plan format](#document-types)), and ADR titles as `# ADR <number>: <title>`.
- **Changing a heading changes its anchor.** Search the repo for links to the old anchor and update them in the same change.

## Lists

- **Numbered lists** only for steps done in order. Number them `1.`, `2.`, `3.`.
- **Bulleted lists** (`-`) for everything else.
- **A bold lead-in** for items that start with a term or a label: `- **Term:** the explanation.` The text after the colon starts with a capital when it is a full sentence, and with lowercase otherwise; keep one form within a list.
- **Parallel items:** every item in a list has the same grammatical form, either all full sentences ending with a period or all fragments without one.
- **Nesting:** four spaces per level, at most two levels below the top.
- **A blank line** before and after every list. Without it, the site renders the list as part of the paragraph above.
- **More than about six items,** or items with several attributes each, usually read better as a table.

## Tables

- Use a table to compare several items across the same attributes. Prose that only happens to have two parts stays prose.
- Every table has a header row, and each cell holds a phrase or a short sentence, not paragraphs or lists.
- No `|` inside a table cell, even inside code: write the alternatives out (`Env=prod` or `Env=staging`).
- A blank line before and after every table.

## Code, commands and names

- **Fenced code blocks** always name their language: `bash`, `yaml`, `hcl`, `json`, `python`, or `text` for directory trees, diagrams drawn in characters and command output.
- **Commands are copyable:** no `$` prompt, one command per line, and output in a separate `text` block.
- **Placeholders** use angle brackets with lowercase words joined by hyphens: `<owner>`, `<account-id>`. Placeholders replace every private value ([private details](#private-details)).
- **Inline code** for commands, file names and paths, repo names, packages and tools whose names are written in lowercase (`kube-prometheus-stack`, `terraform-docs`, `apache_exporter`), settings and values, labels and tags (`Site=dev`), environment variables, AWS regions (`us-east-1`) and Slack channels (`#rl-critical`).
- **Product names** stay in plain text and are spelled as their makers spell them: OpenTofu, GitHub, Argo CD, YubiKey, Google Account, Cloudflare Tunnel. The [word list](#word-list) and the Vale vocabulary hold the project's spellings.
- **Bold** marks the few words a reader scanning the page needs: a decision, a setting's name, a warning. *Italics* are for a term being introduced, or a sample prompt.

## Links and references

- **References are links.** Every mention of an ADR or an existing document is a Markdown link, such as [ADR 1032](../phase-1-russetleaf-dev/adr/1032-defense-in-depth.md); a file that does not exist yet (a planned runbook, a file in another repo) appears as a plain path in code. `tools/check_doc_links.py` enforces this.
- **Relative links** between pages under `docs/`. Files outside `docs/` (scripts, `AGENTS.md`) are not on the site, so link to them with their full GitHub URL.
- **Link text names the target** ("the [lab network setup guide](../phase-1-russetleaf-dev/setup/lab-network.md)"), never "here" or "this link".
- **External links** use `https://` and point to the page that holds the fact, not a home page.

## Notes and warnings

Write a note or a warning as a paragraph that starts with a bold label: `**Note:**`, `**Warning:**` or `**Important:**`. Do not use Zensical's `!!! note` blocks or GitHub's `> [!NOTE]` alerts: each renders only on its own platform and shows as plain text on the other.

## Word list

| Use | Not | Notes |
|---|---|---|
| the operator | `you`, `the user` | The person who builds and runs the platform |
| break-glass kit | `emergency kit` | The offline copies of the credentials needed to recover the project |
| `ci` | `CI` (for the environment) | `ci` (lowercase) is the test environment and its kind clusters; CI is continuous integration |
| sign in (verb), sign-in (noun) | `log in`, `login` | A login name is still a "login" when it is the thing stored |
| set up (verb), setup (noun) | `setup` as a verb | "Set up the router"; "the router's setup" |
| email | `e-mail` | |
| Google Account | `Google account` | Google's own name for the account |
| open-source (before a noun), open source (after) | `opensource` | "an open-source tool"; "the tool is open source" |
| for example, that is, and so on | `e.g.`, `i.e.`, `etc.` | No Latin abbreviations |
| critical alerts | `criticals` | |
| security key | `passkey` (for a YubiKey) | A hardware key such as the operator's YubiKeys, whatever a service's menu calls it; name the menu as the service shows it |
| phone passkey | `passkey` (unqualified) | A passkey stored on a phone or in a password manager |
| Google sign-in (OIDC) | `Google route`, `Google path`, `Google login`, bare `OAuth` | Federated sign-in with a Google Account over OpenID Connect, the authentication layer on OAuth 2.0; write "(OIDC)" on first use in a document. OAuth 2.0 alone means authorization (an OAuth client, scopes, tokens) |
| password sign-in | `password route`, `password path` | A service's own username and password, with the service's own second factor |

## Numbers, dates and units

- **Numbers:** spell out zero to nine in running text ("three nodes"), and use numerals for 10 and above, and always with units, versions, steps and money ("4 hours", "step 2.0", "$50").
- **Units:** a space between the number and the unit: `16 GB`, `2.5 GHz`, `15 minutes`; no space before `%`.
- **Ranges** use an en dash with no spaces: `11–19 hours`, `November 3–4`.
- **Dates:** ISO format (`2026-11-07`) in tables, logs and ADR headers; written out in prose (`November 7, 2026`); with the weekday in the roadmap (`Tue, Nov 3, 2026`). No ordinals such as "the 5th".
- **Ellipses:** none in prose. End an example list with "and so on", or introduce it with "such as".

## Document types

Each kind of document has a fixed shape. Start a new one from its template or from an existing example.

| Document | Where | Starts from | Required parts |
|---|---|---|---|
| ADR | `docs/phase-<n>-<site>/adr/<number>-<slug>.md` | [ADR template](../adr/0000-template.md) | Status, date, scope and phase; context, decision, alternatives, consequences, when to revisit. Listed in the [overview](../overview.md)'s index, the `nav` in `mkdocs.yml` and the plan's ADR table |
| Plan step | The phase's `plan.md` | An existing step | `### Step <n>: <title>`, **Do:** and **Test:** paragraphs, and a matching progress-checklist row, which `tools/plan_to_issues.py` reads |
| Setup guide | `docs/phase-<n>-<site>/setup/<topic>.md` | [AWS management account setup guide](../phase-1-russetleaf-dev/setup/aws-management-account.md) | What to have ready, numbered steps that name each setting, checks that match the plan step's test, and what to do if something goes wrong |
| Runbook | The repo that runs the component | An existing runbook | Listed in the [runbook index](../runbooks.md), the only index |
| Spec | `docs/specs/` | [Spec template](../specs/TEMPLATE.md) | The template's sections |
| Standard | `docs/standards/` | The [bash script standard](bash.md) | The rules, a reason for each, the checks that enforce them, and its ADR |

## Markdown for GitHub and the docs site

The same files render on GitHub and on docs.russetleaf.dev (Zensical). Write only what renders correctly in both:

| Topic | Rule |
|---|---|
| Nested lists | Indent four spaces; Zensical needs four, GitHub accepts either |
| Lists and tables | A blank line before and after |
| Notes and warnings | A bold label in a paragraph ([Notes and warnings](#notes-and-warnings)) |
| Diagrams | Mermaid in a `mermaid` code block (both render it), or a `text` block |
| Task lists | `- [ ]` and `- [x]` (both render them) |
| Links outside `docs/` | Full GitHub URLs |
| HTML | None, except comments (`<!-- -->`) for instructions to the writer, as in the templates |

## Private details

The repos are public. Never write secrets, AWS account or Organization IDs, personal email addresses or phone numbers; write placeholders such as `<name>+rl-management@<domain>`, and keep the real values in Bitwarden, the project's password manager.

## Checks

| Check | What it enforces | Pre-commit | Claude Code hook | CI |
|---|---|---|---|---|
| **Vale** (`.vale.ini`, the Google style package and the project's vocabulary) | Spelling, the capitalization of product names, Latin abbreviations, first person, future tense, ellipses, units and ordinals | Yes | Yes | Yes |
| `tools/check_doc_style.py` | Second person, contractions and sentence-case headings | Yes | Yes | Yes |
| `tools/check_doc_links.py` | References to ADRs and documents are links | Yes | Yes | Yes |
| **markdownlint** (`.markdownlint-cli2.yaml`) | Heading levels and style, one H1, `-` bullets, list numbering and indentation, blank lines, code-block languages, emphasis style | No | No | Yes |
| `zensical build --strict` | Broken links and anchors on the site | No | No | Yes |

Run them locally before pushing:

```bash
pre-commit run --all-files
zensical build --strict
docker run --rm -v "$PWD":/workdir davidanson/markdownlint-cli2:v0.14.0
```

The markdownlint command uses Docker because the workstation does not install Node.js; its version matches the one CI runs. Vale needs its style package once per clone: run `vale sync`.

**When a check is wrong:**

- **A product or tool name that Vale flags as a spelling mistake:** add it to `.vale/styles/config/vocabularies/RussetLeaf/accept.txt`, one name per line, spelled exactly as it should appear. The heading check uses the same list.
- **A line that must break a rule,** such as a quoted command: end it with `<!-- style: allow -->` for `check_doc_style.py`, or put `<!-- vale off -->` and `<!-- vale on -->` around the passage for Vale, with a comment that says why.

## Changing this guide

A change to a rule changes this page, the checks that enforce it and the existing documents that break it, in one commit, and adds a row to the [decision log](../phase-1-russetleaf-dev/plan.md#decision-log); a change to the approach updates [ADR 1057](../phase-1-russetleaf-dev/adr/1057-documentation-style-guide.md).
