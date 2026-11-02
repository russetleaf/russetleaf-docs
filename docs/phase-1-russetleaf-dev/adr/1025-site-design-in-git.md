# ADR 1025: A custom block theme built into the image; Site Editor locked in production

- **Status:** Accepted
- **Date:** 2026-11-01
- **Applies to:** both sites (the same WordPress image)
- **Phase:** 1. Later: Phase 2 adds the AI summary box.

## Context
russetleaf.dev is the project's public face, so it needs a custom design and a logo rather than a default theme. Modern WordPress **block themes** can be customized in the admin **Site Editor**, but those changes are stored **in the database**, not in files. That would let the live design drift from Git and bypass review, signing, staging and promotion, contradicting ADR 1002 (code in the image, nothing changed in production).

## Decision
- A project block theme, **`russetleaf`**, in `russetleaf-wordpress/themes/russetleaf/`, built into the image.
- **Design locally** (Docker Compose WordPress, Site Editor, AI assistance), then **export to files** with the **Create Block Theme** plugin and commit; the plugin is used only locally, not in the production image.
- **Lock the Site Editor in production** with a must-use plugin that removes the capability to change templates and global styles.
- **AI-assisted design:** Claude generates the theme from a brief and iterates from screenshots; the **logo** is an SVG (mark plus wordmark), preferably written directly as vector code, with derived icons, an Open Graph image and the theme palette; image generators only for concept exploration, followed by vectorizing. Check generator terms, copyright limits on AI-generated images, and trademarks before public use.
- **Front-end quality gates:** Playwright visual regression, axe-core accessibility checks and Lighthouse CI budgets in `russetleaf-wordpress` CI and the staging gate.

## Alternatives considered
- **A marketplace or third-party theme:** quick, but generic, often bundles page builders and its own update cycle, and rarely matches the read-only, minimal-plugin design.
- **Customizing in the production Site Editor:** fastest for small changes, but stores the design in the database, outside Git and the pipeline.
- **A classic (PHP-template) theme:** full control, but more code to maintain; block themes are WordPress's current direction and `theme.json` keeps styling declarative.
- **Raster-only logo from an image generator:** fast concepts, but blurry at some sizes and hard to edit; SVG is the right final format.

## Consequences
- The design is versioned, reviewed, tested and promoted like code; both sites look identical.
- Small visual changes take a pull request instead of a few clicks in production.
- Visual baselines must be updated deliberately when the design changes.
- The logo and palette are reusable across the site, docs, Backstage and social links.

## When to revisit
- Non-technical editors need to change layouts often: allow limited Site Editor use with a sync-back process, or a page-building approach.
- WordPress gains a native way to keep Site Editor changes in theme files.

## Open items
- Phase 1 step 5.10: the brief, theme, logo and brand assets, and the Site Editor lock.
- Phase 1 step 5.11: visual regression, accessibility and Lighthouse gates.
