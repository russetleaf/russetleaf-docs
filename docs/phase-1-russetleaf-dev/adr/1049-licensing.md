# ADR 1049: GPL v3.0 for code and documentation; the RussetLeaf name and logo reserved

- **Status:** Accepted
- **Date:** 2026-11-04
- **Applies to:** every RussetLeaf repo, and the brand assets of both sites
- **Phase:** 1 (`russetleaf-docs` now; each code repo from step 1.1; the brand assets in step 5.10)

## Context

The repos are public ([ADR 1030](1030-github-actions-ci.md)). The project's scripts already carried a GPL v3.0 license line, and `russetleaf-docs` now has the GPL v3.0 `LICENSE` they refer to. The GPL lets anyone copy, change and redistribute what it covers, which suits code, configuration and documentation: it is a portfolio meant to be read and reused.

It suits the brand less. The logo and the name identify the project and its author. If they were GPL, a copy of the site or a fork could present itself as RussetLeaf, with the same logo, and that would be allowed. The logo (with its icons and share image) will live in `russetleaf-wordpress/brand/` ([ADR 1025](1025-site-design-in-git.md)), inside a repo that is otherwise GPL.

## Decision

- **GPL v3.0 for everything else:** all code, configuration and documentation in every repo, with the same `LICENSE` text in each, and the license line in the header of every script, library, test and tool (enforced by the style checker; [ADR 1048](1048-bash-script-standard.md)).
- **Reserved, not GPL:** the RussetLeaf **logo** (the mark and the wordmark) and every file **derived from it** (the favicon set, the site and touch icons, the Open Graph share image), together with the **RussetLeaf name** as the project's identity. Copyright Steven Scully, all rights reserved.
- **Kept apart, so the line is clear:**
    - Brand assets exist only in **`brand/`** folders: `russetleaf-wordpress/brand/` holds the sources; any other repo that uses the logo (for example the docs site) keeps its copy in its own `brand/`.
    - Each `brand/` folder has a **`README.md`** stating the reservation, and each repo's README names the exception in its License section.
    - The WordPress image build **copies** the icons from `brand/` into the theme; the theme **refers to the logo file and never inlines its SVG** in templates or patterns, so the GPL theme never contains the logo.
- **Still GPL:** the color palette and the theme itself (`theme.json`, templates, patterns), which are code; colors on their own are not a brand asset.
- **Forks:** may use all the GPL code and documentation, and must replace the name and the logo.
- **Third-party material keeps its own license:** WordPress (GPLv2 or later, which allows the project's theme and plugins to be GPL v3), third-party plugins, fonts (usually the SIL Open Font License, whose notices stay with them), and in Phase 2 the models.

## Alternatives considered

- **Everything under the GPL, logo included:** the simplest rule, but any copy may use the name and logo, so a fork can pass as the project.
- **A Creative Commons license for the brand** (such as CC BY-ND, no derivatives): allows sharing the logo unchanged with credit, which still lets a copy of the site keep it; "all rights reserved" is clearer for an identity.
- **Creative Commons (CC BY 4.0) for the documentation,** the usual license for prose: a common choice, but one license for code and documentation keeps the rule and the headers simple, and the documentation contains code and configuration throughout.
- **A separate brand repo:** a clean boundary, but one more repo for a few files; a `brand/` folder with its own notice gives the same clarity.
- **A registered trademark:** the strongest protection of the name, but it costs money and time out of proportion for a portfolio project; revisited below.

## Consequences

- Anyone can reuse the project's code and documentation; nobody can present a copy as RussetLeaf.
- The theme must refer to the logo by file, not inline it; a logo pasted into a template would put a reserved asset inside GPL code.
- Brand files must stay in `brand/` folders; exports placed elsewhere would blur the line.
- **A limit:** a logo generated entirely by AI may not be protectable by copyright in some jurisdictions (the design's checks before publishing the logo). The reservation then rests mainly on the name, and on the trademark search done in step 5.10.

## When to revisit

- RussetLeaf becomes more than a portfolio (users, contributors, revenue): register the name as a trademark, and consider a contributor agreement.
- Contributors outside the project appear: decide whether their contributions need a sign-off (for example the Developer Certificate of Origin).

## Open items

- Phase 1 step 1.1: the same GPL v3.0 `LICENSE` in each code repo, with the brand exception in each README's License section.
- Phase 1 step 5.10: `russetleaf-wordpress/brand/README.md` with the reservation; the image build copies the icons from `brand/`; the theme refers to the logo file.
