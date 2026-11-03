# ADR 1047: The home cluster's own passwords are generated in the cluster and rotated automatically

- **Status:** Accepted
- **Date:** 2026-11-03
- **Applies to:** russetleaf.dev. russetleaf.com has no equivalent passwords: WordPress uses IAM authentication through RDS Proxy, and the ElastiCache AUTH token is regenerated on every `demo-up` ([ADR 3007](../../phase-3-russetleaf-com/adr/3007-rds-mariadb-with-rds-proxy.md)).
- **Phase:** 1

## Context

The home cluster has passwords that are created and used only inside it: the MariaDB users (WordPress, backup, root) and, newly, Valkey's. Three problems were found:

- **Valkey had no authentication.** Only a CiliumNetworkPolicy kept other pods away from it. A policy mistake, or anything that got past it, would allow reading and rewriting cached posts and options, which WordPress would then serve.
- **MariaDB rotation was described two ways.** The design said the passwords were rotated by "a scheduled, tested procedure, not by hand"; the ongoing-operations table listed a quarterly manual task.
- **Either way, rotation caused errors.** MariaDB cannot give one user two valid passwords at once, so between changing the WordPress user's password and restarting WordPress, every database connection would fail.

[ADR 1019](1019-aws-multi-account-sra.md) set the rules for other secrets: third-party tokens (Cloudflare, Slack, Google) live in Secrets Manager and are rotated by hand on a schedule; automatic rotation is used where AWS provides it; short-lived credentials replace rotation elsewhere. It did not cover secrets that never leave the cluster.

## Decision

**The rule:** a secret that is created and used **only inside the cluster** is **generated there**, by an operator or by External Secrets' `Password` generator. It is never in Secrets Manager or Git, nobody types or sees it, and after a rebuild it is simply generated again (the disaster recovery plan's "regenerate rather than copy"). Secrets that come from **outside** providers stay in Secrets Manager under [ADR 1019](1019-aws-multi-account-sra.md)'s rules.

**Valkey gets ACL users:**

- the `default` user **disabled**
- **`wordpress`:** the data commands the object-cache plugin needs, including `FLUSHDB` (for `wp cache flush`), and no administrative commands (`CONFIG`, `DEBUG`, `MODULE`, `ACL`, replication)
- **`exporter`:** only the commands redis_exporter reads (`INFO`, `PING`, `SLOWLOG`, `LATENCY`, `CLIENT LIST` and similar)
- **`admin`:** everything, used only for recovery and forensics (such as the cache dump in the compromised-container runbook; [ADR 1045](1045-container-forensics.md))

The three passwords come from one `ExternalSecret` using the `Password` generator, with `refreshInterval: 0` so they change only when asked; its template also renders Valkey's ACL file. Each client reads only its own password. If authentication fails, the cache plugin's graceful mode falls back to the database, so the site slows down rather than failing.

**MariaDB gets two alternating WordPress users,** `wordpress_a` and `wordpress_b`, with identical grants and operator-generated passwords. WordPress reads whichever is active from a `wordpress-db-active` Secret. A valid login therefore exists at every moment of a rotation.

**A `secret-rotation` CronJob** (`platform/secret-rotation/`) rotates them **quarterly and automatically**:

1. **WordPress database user:** a new password for the inactive user; confirm it works; switch `wordpress-db-active` to it; restart WordPress and wait until healthy; confirm no sessions remain for the old user; then change the old user's password too.
2. **Backup user:** a new password; the next scheduled backup uses it.
3. **Valkey:** regenerate the passwords (the `ExternalSecret`'s `force-sync` annotation); restart Valkey, then WordPress. WordPress runs without the cache between the two restarts.
4. **Report:** the result goes to `#rl-deploys`. A failed run, or none successful for 100 days, fires **`SecretRotationFailed`** in `#rl-security`.

Supporting settings: the job's ServiceAccount may only read and update the named Secrets, annotate the one `ExternalSecret` and restart the named workloads, and it is on the expected-readers list of `KubeUnexpectedSecretRead`. Argo CD ignores the restart annotations, so self-heal does not undo a rotation. **Running the job by hand** is the first response to a leak of any of these passwords (`credential-leak.md`; [ADR 1046](1046-incident-response-and-runbook-index.md)). The MariaDB root password is managed by the operator, and rotated only if the installed version supports it.

## Alternatives considered

- **No Valkey password (network policy only):** nothing to manage, but a single layer; one policy mistake exposes the cache's contents and lets anyone rewrite them.
- **One shared Valkey password (`requirepass`):** simpler than ACL users, but the exporter would hold a password that can also rewrite the cache and run administrative commands.
- **Valkey with TLS and client certificates:** stronger, and cert-manager could issue them, but more to configure in WordPress's cache plugin; traffic between nodes is already encrypted by Cilium's WireGuard. Revisit if the cache ever holds more sensitive data.
- **These passwords in Secrets Manager, synced by External Secrets:** visible and backed up in AWS, but copies secrets outside the cluster that nothing outside needs, costs about $0.40 a month each, and still needs the same ordered restarts. Automatic rotation there would need a custom Lambda, which [ADR 1019](1019-aws-multi-account-sra.md) rejected.
- **Manual quarterly rotation from a runbook:** no job to maintain, but easy to postpone, and it does not remove the database error window.
- **One database user, rotated at a quiet time:** simpler, but every rotation causes a burst of failed requests; unacceptable for something that runs unattended.
- **Letting the generator refresh on its own** (`refreshInterval` set to 90 days): rotation with no job, but nothing restarts Valkey and WordPress in the right order, so they would disagree until the next restarts.
- **Stakater Reloader** (restart workloads when a Secret changes): automatic restarts, but no ordering between Valkey and WordPress, no alternating-user sequence, no report, and one more component. The job does all of that in one place.
- **Vault or OpenBao dynamic database credentials** (a short-lived user per pod): the strongest option, but a highly available Vault, its unsealing and its storage are far more than one WordPress site needs. Revisit if more applications use the database.
- **MariaDB client certificates (`REQUIRE X509`)** instead of passwords: passwordless and already listed as an optional later step in the design; depends on MariaDB Operator support.

## Consequences

- The cache has a second layer of protection, and every password the cluster owns is rotated every quarter without anyone remembering to.
- Rotating the database password causes no errors; rotating Valkey's costs a minute or two of cache misses, and the cache starts empty each quarter.
- Two database users and their grants to maintain, and a job with permission to read and change the most sensitive Secrets in the cluster; its permissions are narrow, and its reads are expected by the audit alert.
- A database **restore** can bring back old copies of the user accounts, whose passwords no longer match the current Secrets. The data-rollback runbook therefore ends by re-applying the current passwords (re-running the rotation job, or letting the operator reconcile the users), then flushing the cache.
- After a full rebuild, all these passwords are new; nothing outside the cluster depends on them, so nothing else changes.

## When to revisit

- More applications use the home database: consider Vault or OpenBao dynamic credentials.
- MariaDB Operator gains native rotation (with overlap), or certificate-based users: simplify the job, or drop passwords for the database.
- The cache starts holding sensitive data: add TLS to Valkey.

## Open items

- Phase 1 step 4.5: the ACL users, the two database users, the rotation job and its alert. Confirm whether the installed MariaDB Operator applies a changed generated password by itself (otherwise the job runs `ALTER USER`), whether it re-applies passwords after a restore, and whether it can rotate root ([ADR 1043](1043-database-encryption.md)).
- Phase 1 step 5.2: rotation under load with no database errors.
- Phase 1 step 7.8: the password step at the end of `rollback-data.md`, tested in the staging restore drill.
