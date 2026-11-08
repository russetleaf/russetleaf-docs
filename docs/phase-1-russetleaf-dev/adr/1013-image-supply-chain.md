# ADR 1013: Image supply chain: SLSA provenance, Opengrep for SAST, and the build pipeline's tools

- **Status:** Accepted; updated by [ADR 1053](1053-open-source-tools-by-default.md) (Opengrep instead of Semgrep, 2026-11-06)
- **Date:** 2026-11-01
- **Applies to:** `russetleaf-wordpress` and `russetleaf-llm-summarizer` (and Scorecard on all four repos)
- **Phase:** 1 (`russetleaf-wordpress`). Later: Phase 2 builds `russetleaf-llm-summarizer` through the same pipeline.

> **Update ([ADR 1053](1053-open-source-tools-by-default.md)):** SAST uses **Opengrep**, the open-source fork of Semgrep's engine, with the same rule syntax, because Semgrep moved features and its maintained rules away from open source. The rules are the project's own plus open rule sets. The reasoning below for Semgrep over CodeQL applies to Opengrep unchanged.

## Context

The image pipelines already had gitleaks, Checkov, Trivy (critical vulnerabilities), WPScan, Syft SBOMs, cosign keyless signing, signed SBOM attestations and Rekor transparency-log entries, with Kyverno verifying signatures and SBOM attestations at admission. Missing were: language linting and application security analysis (SAST) for the project's own Python and PHP; dependency checks before the build; Dockerfile linting; deeper workflow security analysis; checks on the built image's properties; secrets baked into image layers; **build provenance** (how and where an image was built); in-pipeline verification of signatures; and an audit of the repos' own security practices.

## Decision

- **SLSA build provenance** with GitHub's `actions/attest-build-provenance` on every release, with the image build run as a **reusable workflow** (a shared build workflow called by each repo's release workflow), so the provenance meets **SLSA Build Level 3** as GitHub documents it (Level 2 without the reusable workflow); Kyverno verifies the reusable workflow's identity: a signed record of the repo, commit, workflow and runner that built each image, stored with the image and recorded in Rekor (public repos). **Kyverno requires** the provenance attestation, alongside the signature and the SBOM attestation.
- **Semgrep Community Edition** for SAST across Python and PHP, rather than CodeQL.
- **Linters:** hadolint (Dockerfiles); ruff and mypy (Python); PHP_CodeSniffer with the WordPress Coding Standards, and PHPStan (PHP).
- **Dependency checks before build:** `composer audit`, pip-audit, and GitHub's dependency-review action.
- **zizmor** for GitHub Actions workflow security, alongside Checkov's workflow checks.
- **Trivy** with its secret and misconfiguration scanners as well as vulnerabilities; accepted findings in `.trivyignore` with reasons and expiry dates.
- **container-structure-test** for the built image's properties.
- **Verify in the pipeline** (`cosign verify`, `cosign verify-attestation`, `gh attestation verify`) before opening the version-bump pull request; record digests and Rekor links in release notes.
- **OpenSSF Scorecard** weekly on all four repos.

## Alternatives considered

- **CodeQL instead of Semgrep:** deeper analysis and free on public repos, but does not support PHP; running both would duplicate Python coverage. CodeQL could be added for Python later.
- **BuildKit's built-in provenance and SBOM attestations** (`docker buildx --provenance --sbom`): stored in the registry, but not signed with the same keyless identity the rest of the pipeline and Kyverno already use; GitHub's attestations integrate with `gh attestation verify` and Sigstore.
- **SLSA Build Level 3 with the SLSA GitHub generator:** a stronger isolation guarantee, but more workflow complexity. *[Corrected:]* GitHub's artifact attestations on their own provide **SLSA Build Level 2** provenance; GitHub documents reaching **Build Level 3** by running the build in a **reusable workflow**, which isolates the build definition from the calling repository. This project adopts that (see Decision), rather than the separate SLSA generator.
- **Docker Scout, Snyk Container, Grype:** overlap with Trivy.
- **Chainguard or Wolfi base images:** smaller attack surface, but the free tier offers only `latest` tags, conflicting with pinned versions.

## Consequences

- Every released image carries three verifiable, Rekor-logged records (signature, SBOM, provenance), all checked in the pipeline and again by Kyverno at admission.
- The project's own code is linted and security-scanned in both languages before any image is built.
- More CI time per pull request (roughly a few minutes), and more tools to keep updated (Renovate and `.mise.toml` cover them).
- PHP tools run inside a container in CI (and locally), so no PHP is needed on the workstation.
- Scorecard results are public on each repo, which motivates keeping practices tidy.

## When to revisit

- Kyverno's support for verifying GitHub attestation bundles changes, or GitHub's attestation format changes.
- The project needs SLSA Build Level 3 guarantees explicitly (for example, for a customer requirement).
- Chainguard or Wolfi offers pinned versions on a free tier.

## Open items

- Phase 1 step 5.1 and Phase 2 step 2.4: implement the pipeline in both repos; record the first release's Rekor links.
- Phase 1 step 6.1: confirm Kyverno can verify the GitHub provenance attestation with the release workflow's identity, and enforce it.
- Record the initial OpenSSF Scorecard scores in the decision log.
