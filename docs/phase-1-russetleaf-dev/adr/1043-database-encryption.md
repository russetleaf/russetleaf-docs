# ADR 1043: Database encryption at rest and TLS on every connection

- **Status:** Accepted
- **Date:** 2026-11-03
- **Applies to:** every MariaDB database: russetleaf.dev production and staging (MariaDB Operator), MLflow's metadata (Phase 2), RDS for MariaDB and RDS Proxy (Phase 3), and the database backups
- **Phase:** 1. Phase 2 applies it to MLflow's database; Phase 3 applies it to RDS.

## Context

The databases were encrypted at rest (Talos disk encryption at home; RDS encryption on AWS) and TLS was required for WordPress's own connections, but several gaps remained:

- TLS was required **per user** (the `wordpress` user at home), not by the server, so other connections were not covered:
    - replication between the primary and the replica
    - the backup user
    - the `db-setup` Job's direct connection to RDS
    - MLflow's connection
- RDS encryption was mentioned without a key, and the database backups used S3's default encryption, although the dumps hold commenters' email addresses and the users' password hashes.

Cilium's WireGuard encryption already protects pod traffic between home nodes, but "always TLS" should be enforced by the database, not depend on each client's settings or on the network layer.

## Decision

**In transit: the server refuses anything but TLS.**

- **`require_secure_transport = ON`** on every MariaDB server: russetleaf.dev production and staging (in the `MariaDB` resource's configuration), the MLflow database, and the RDS parameter group. A connection without TLS is refused, whatever user or client makes it.
- **TLS 1.2 or later only** (`tls_version = TLSv1.2,TLSv1.3`).
- **Home certificates** from the internal CA (cert-manager), renewed automatically; clients verify the server certificate against that CA.
- **Replication over TLS:** MariaDB Operator's replication connections, and its own management connections, use TLS. Confirm that the installed operator version supports this for replication and backups; if a component cannot use TLS, record the exception here with its compensating control (Cilium WireGuard between nodes).
- **Users also require TLS** (`REQUIRE SSL` on the `wordpress`, backup and MLflow users), as a second layer if the server setting is ever lost.
- **AWS:**
    - RDS Proxy keeps `require_tls = true` for clients.
    - With `require_secure_transport` on the instance, the proxy's own connections to RDS must use TLS too.
    - The `db-setup` Job connects to RDS with TLS, verifying the server against the RDS CA bundle.

**At rest: encrypted everywhere, with keys under the project's control where the data leaves the cluster.**

- **Home:** the database volumes come from local-path-provisioner under `/var/local-path-provisioner`, which lies on Talos's **encrypted, TPM-sealed** partition ([ADR 1031](1031-kubernetes-component-hardening.md)). A test confirms this, so a volume cannot end up on an unencrypted disk.
- **RDS:** `storage_encrypted = true` with a **customer-managed KMS key** in russetleaf-com. Automated backups, final snapshots and instances restored from them are encrypted with the same key.
- **Database backups in S3:** **SSE-KMS with a customer-managed key** and an **S3 Bucket Key** (fewer KMS requests, lower cost). The key policy lets only the backup role (write), the restore and staging-data Jobs (read) and S3 replication use it. The Backup account's copies already use their own customer-managed key.

**Checks**

- A client with TLS turned off (`--ssl=0` or `--skip-ssl`, depending on the client) is refused, on every server.
- `SHOW STATUS LIKE 'Ssl_cipher'` is non-empty for WordPress, replication, backup and MLflow sessions.
- `talosctl` shows the partition holding `/var/local-path-provisioner` as encrypted.
- Security Hub's RDS encryption check passes.
- Reading a backup object with a role outside the key policy fails.

## Alternatives considered

- **TLS required per user only (the previous design):** misses replication, operator and tooling connections, and depends on each user being created correctly.
- **Relying on Cilium WireGuard instead of database TLS:** encrypts traffic between nodes but not between pods on the same node, and is a network-layer control that the database cannot verify.
- **Client-side encryption of backups** (e.g. `age` before upload): protects even against a compromised AWS account, but adds key handling to every restore and staging refresh; the customer-managed key, the separate Backup account and Object Lock cover the realistic threats.
- **S3-managed keys (SSE-S3) for backups:** free and automatic, but any identity with S3 read access can read the dumps; a customer-managed key adds a second, separately controlled permission.

## Consequences

- Every database connection on both sites is encrypted, enforced by the server.
- Backups and snapshots can only be read by roles the key policies name.
- About $1 a month per customer-managed key (the backup key at home; the RDS key in russetleaf-com, only while it exists).
- A slight TLS handshake cost on new connections, negligible at this scale, and absorbed by RDS Proxy's pooling on AWS.
- Certificate expiry becomes a failure mode; cert-manager renews the certificates, and its certificate-expiry alert covers them.

## When to revisit

- MariaDB Operator gains certificate-based users: consider passwordless `REQUIRE X509` at home (see the Phase 1 design's [Database access and credentials](../design.md#database-access-and-credentials)).
- A component cannot use TLS: record the exception and its compensating control here.

## Open items

- Phase 1 step 4.5: server-wide TLS, replication TLS, user requirements, the encrypted-volume check and the tests.
- Phase 1 step 4.5: whether the installed MariaDB Operator applies a changed generated password to the database by itself (otherwise the rotation job runs `ALTER USER`), and whether it can rotate the root password; see the design's [rotation job](../design.md#russetleafdev-the-rotation-job).
- Phase 1 step 2.3: the customer-managed key for the database backup bucket.
- Phase 2 step 4.4: TLS for MLflow's database.
- Phase 3 step 1.6: the RDS key, the TLS settings and the tests.
