# ADR 3007: RDS for MariaDB behind RDS Proxy, with IAM authentication

- **Status:** Accepted; credential hardening added 2026-11-03
- **Date:** 2026-11-02
- **Applies to:** russetleaf.com's database, `russetleaf-wordpress`'s `db.php` drop-in, `russetleaf-infra/envs/aws`
- **Phase:** 3

## Context

At home, MariaDB runs in the cluster with operator-generated passwords (Phase 1). The AWS design should show the managed equivalent and the cloud's stronger option: an application with **no database password at all**. WordPress opens a new connection on almost every request, and the site's backups must move between the two sites without conversion.

## Decision

- **RDS for MariaDB, Multi-AZ** (same engine as home, so russetleaf.dev's logical backups restore directly), in private subnets, TLS required, restored from the final snapshot each demo.
- **RDS Proxy** in front of it, with **IAM authentication required**: WordPress's `db.php` drop-in signs a 15-minute **IAM auth token** with its Pod Identity role (`rds-db:connect` on the proxy's `wordpress` user); the proxy logs in to RDS with a password from Secrets Manager that only the proxy can read. The proxy also pools connections and keeps failovers to seconds.
- **The master password** is managed and rotated by RDS (`manage_master_user_password`); a small `db-setup` Job creates the `wordpress` user.
- **Early test, with a fallback:** confirm PHP's MariaDB client can send IAM tokens to RDS Proxy before building on it (Phase 3 step 1.6). If it cannot, use password login to the proxy with a **Secrets Manager-rotated** password (alternating users), synced by External Secrets; the chart's `database.auth` setting switches between the two.
- **ElastiCache Valkey** as the object cache, matching Valkey at home.

### Credential hardening

- **The proxy's `wordpress` password is rotated:** Secrets Manager automatic rotation for MariaDB (e.g. every 30 days). Only RDS Proxy uses this password, and the proxy reads the new value from the secret, so WordPress is unaffected.
- **No database password in Terraform state:** Terraform creates the `wordpress` secret with an **ephemeral** random password (the ephemeral `aws_secretsmanager_random_password` resource) written through the secret's **write-only** `secret_string_wo` argument, so the value is never saved in state or plan files; a version number is bumped to set a new value. Terraform never reads the secret back: the `db-setup` Job reads it from Secrets Manager when it runs. Letting Secrets Manager generate the value is not enough on its own, because a non-ephemeral data source or a read-back would still save it in state. (Ephemeral resources need Terraform 1.10 or later and write-only arguments 1.11 or later; confirm the versions and provider support when building.)
- **The `db-setup` Job is tightly scoped:** its own Pod Identity role may read only the master secret and the `wordpress` secret; a CiliumNetworkPolicy allows it to reach only the RDS endpoint; it is deleted after it succeeds (Argo CD hook delete policy `HookSucceeded`); it runs only during syncs, so the master credential is never held by a long-running pod.
- **Passwords as files, never environment variables:** wherever WordPress uses a password (the fallback on russetleaf.com and the home sites), it is mounted from a Kubernetes Secret as a file and read through `WORDPRESS_DB_PASSWORD_FILE`, not `WORDPRESS_DB_PASSWORD`, in line with the Kyverno rule from [ADR 1032](../../phase-1-russetleaf-dev/adr/1032-defense-in-depth.md).
- **The Valkey AUTH token is regenerated on every `demo-up`** (ephemeral, write-only, never in Terraform state), so it changes each demo without a rotation job.
- **The early PHP IAM token test stays first** (Phase 3 step 1.6): it is the one open risk in the design.

## Alternatives considered

- **Aurora MySQL:** Aurora does not offer MariaDB; switching engines would break the shared backups.
- **Direct IAM authentication to RDS, without a proxy:** AWS recommends it only for low connection rates; WordPress's connection pattern needs the proxy.
- **MariaDB in the EKS cluster** (as at home): cheaper, but hides the managed-database design the AWS site is meant to show.

## Consequences

- In the cloud, the application holds no database secret; at home, secrets are minimized, generated and isolated instead.
- RDS Proxy adds about $0.03 an hour during demos.
- The IAM token path is the one uncertain part of the design, with a tested fallback.
- Every remaining password is machine-generated, kept out of Git and Terraform state, readable only by the component that needs it, and rotated.

## When to revisit

- The early test fails: adopt the rotated-password fallback and record it here.
- russetleaf.com becomes always-on: review instance size, Multi-AZ cost and Reserved Instances.

## Open items

- Phase 3 step 1.6: the PHP IAM token test, RDS, RDS Proxy and Valkey; step 3.1: WordPress on the proxy; step 3.2: the seed and snapshot cycle.
