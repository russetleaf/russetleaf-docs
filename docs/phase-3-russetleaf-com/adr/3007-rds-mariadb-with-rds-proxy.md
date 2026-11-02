# ADR 3007: RDS for MariaDB behind RDS Proxy, with IAM authentication

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** russetleaf.com's database, `wp-image`'s `db.php` drop-in, `wp-infra/envs/aws`
- **Phase:** 3

## Context
At home, MariaDB runs in the cluster with operator-generated passwords (Phase 1). The AWS design should show the managed equivalent and the cloud's stronger option: an application with **no database password at all**. WordPress opens a new connection on almost every request, and the site's backups must move between the two sites without conversion.

## Decision
- **RDS for MariaDB, Multi-AZ** (same engine as home, so russetleaf.dev's logical backups restore directly), in private subnets, TLS required, restored from the final snapshot each demo.
- **RDS Proxy** in front of it, with **IAM authentication required**: WordPress's `db.php` drop-in signs a 15-minute **IAM auth token** with its Pod Identity role (`rds-db:connect` on the proxy's `wordpress` user); the proxy logs in to RDS with a password from Secrets Manager that only the proxy can read. The proxy also pools connections and keeps failovers to seconds.
- **The master password** is managed and rotated by RDS (`manage_master_user_password`); a small `db-setup` Job creates the `wordpress` user.
- **Early test, with a fallback:** confirm PHP's MariaDB client can send IAM tokens to RDS Proxy before building on it (Phase 3 step 1.6). If it can't, use password login to the proxy with a **Secrets Manager-rotated** password (alternating users), synced by External Secrets; the chart's `database.auth` setting switches between the two.
- **ElastiCache Valkey** as the object cache, matching Valkey at home.

## Alternatives considered
- **Aurora MySQL:** Aurora doesn't offer MariaDB; switching engines would break the shared backups.
- **Direct IAM authentication to RDS, without a proxy:** AWS recommends it only for low connection rates; WordPress's connection pattern needs the proxy.
- **MariaDB in the EKS cluster** (as at home): cheaper, but hides the managed-database design the AWS site is meant to show.

## Consequences
- In the cloud, the application holds no database secret; at home, secrets are minimized, generated and isolated instead.
- RDS Proxy adds about $0.03 an hour during demos.
- The IAM token path is the one uncertain part of the design, with a tested fallback.

## When to revisit
- The early test fails: adopt the rotated-password fallback and record it here.
- russetleaf.com becomes always-on: review instance size, Multi-AZ cost and Reserved Instances.

## Open items
- Phase 3 step 1.6: the PHP IAM token test, RDS, RDS Proxy and Valkey; step 3.1: WordPress on the proxy; step 3.2: the seed and snapshot cycle.
