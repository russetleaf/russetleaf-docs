# ADR 1042: S3 versioning, lifecycle rules and storage classes

- **Status:** Accepted
- **Date:** 2026-11-03
- **Applies to:** every S3 bucket in `russetleaf-infra` (the shared `s3-*` modules, `envs/security`, `envs/dr`, `envs/home`, `envs/aws-edge`)
- **Phase:** 1. Phase 2 applies it to the MLflow and DVC buckets; Phase 3 applies it to russetleaf.com's buckets.

## Context

The buckets had versioning where it mattered and lifecycle rules that delete short-lived data, but no rule ever moved data to a cheaper storage class, and some buckets had no lifecycle rule at all: old versions of media files were kept forever, and the one-year audit-log archive stayed in S3 Standard. Cheaper classes are not free, though. Standard-IA and Glacier Instant Retrieval charge for at least 30 and 90 days of storage, Glacier Flexible Retrieval for 90 days and Deep Archive for 180, and Intelligent-Tiering does not tier objects under 128 KB. Moving data that is deleted soon, or that is small, can cost more than leaving it in Standard. (Minimum durations and sizes are from AWS's documentation at the time of writing; confirm them when building.)

## Decision

- **Versioning** on every bucket whose data cannot be rebuilt: Terraform state, media, database backups, the Log Archive and Backup account buckets (Object Lock requires it), and the MLflow and DVC buckets. **Not** on buckets of short-lived, rebuildable data: Loki logs, Tempo traces, the offline page (kept in Git) and, in Phase 2, the model mirror bucket (refilled from the MLflow registry).
- **Every versioned bucket expires old versions**, so versioning protects against mistakes without keeping every overwrite forever:

| Bucket | Current objects | Old (noncurrent) versions | Storage class |
|---|---|---|---|
| Terraform state | Kept | Deleted after 90 days | Standard |
| Media (both sites) | Kept | Deleted after **90 days** | Standard |
| Database backups | Deleted after 30 days | Deleted after 30 days | Standard |
| Backup account copies (Object Lock, 30 days) | Deleted after **35 days** (after the lock ends) | Deleted after 1 day, once unlocked | Standard |
| Backup account monthly copies (Object Lock, 365 days; [ADR 1018](1018-disaster-recovery.md)) | Deleted after **366 days** (after the lock ends) | Deleted after 1 day, once unlocked | **Glacier Instant Retrieval** from the start |
| Log Archive (CloudTrail, Config, Kubernetes audit logs, VPC flow logs, Route 53 Resolver query logs; Object Lock) | **Glacier Instant Retrieval after 30 days**; deleted after **1 year** (CloudTrail kept longer only if a requirement appears) | Deleted after 1 day, once unlocked | Standard, then **Glacier Instant Retrieval** |
| MLflow artifacts and DVC data | Kept | Deleted after 30 days | Standard |
| Loki and Tempo | Deleted when their retention ends (3–14 days) | n/a | Standard |

- **Every bucket** also has a rule **aborting incomplete multipart uploads after 7 days**, so the parts of failed large uploads (backups, model files, datasets) are not billed indefinitely.
- **Glacier Instant Retrieval for the Log Archive only:** the logs are kept a year and rarely read, but must stay readable at once for investigations and Athena queries, which the Flexible Retrieval and Deep Archive classes do not allow without a restore. Lifecycle transitions work on Object Lock objects and do not shorten their retention.
- **Glacier Instant Retrieval for the monthly copies too:** they are kept a year and almost never read, well past the 90-day minimum, and stay readable at once when a restore is needed.
- **No Glacier where it costs more:** the daily backups and their copies live 30–35 days, less than Glacier's 90-day minimum; media is small, frequently served through the CDN, and mostly under Intelligent-Tiering's 128 KB threshold; logs, traces and ML data are deleted quickly or used actively.
- **In the modules:** the `s3-*` modules take the retention periods as inputs with these defaults; Checkov's S3 checks (versioning and lifecycle configuration) run in CI.

## Alternatives considered

- **Intelligent-Tiering everywhere:** convenient, but adds a per-object monitoring charge and does nothing for small objects; the access patterns here are known, so explicit rules are clearer.
- **Glacier Deep Archive for the Log Archive:** the cheapest storage, but restores take hours and the 180-day minimum applies; the one-year archive is small, so the saving over Instant Retrieval is pennies.
- **Standard-IA for backups:** the 30-day minimum equals their whole life, so there is no saving, only retrieval charges on restore.
- **Keeping old versions forever:** simplest, but costs grow with every overwrite and deleted data is never really gone, which matters for privacy ([ADR 1036](1036-compliance-frameworks-and-privacy.md)).

## Consequences

- Storage costs stay flat as data accumulates; at this data size the saving is cents a month, but the rules show deliberate choices of storage class.
- Deleted media can be recovered for 90 days, not indefinitely.
- Reading Log Archive objects after 30 days costs a small retrieval charge per GB.

## When to revisit

- Data grows to tens of GB or more: review Standard-IA for older media and Intelligent-Tiering for large files.
- A compliance requirement asks for longer log retention: extend the Log Archive rule, moving older logs to Deep Archive.

## Open items

- Phase 1 step 2.0b: the Log Archive rules; step 2.1: the state bucket rules; step 2.3: the russetleaf.dev bucket rules; step 2.5: the Backup account rules.
- Phase 2 step 4.4: the MLflow and DVC bucket rules.
- Phase 3 step 1.2: the russetleaf.com bucket rules.
