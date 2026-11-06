# ADR 1050: AWS Secrets Manager with External Secrets as the secrets store (not HashiCorp Vault)

- **Status:** Accepted. It records a choice the [Phase 1 design](../design.md#security) already made, with the alternatives behind it.
- **Date:** 2026-11-06
- **Applies to:** both sites
- **Phase:** 1 (the home cluster, step 4.2). Phase 2 adds the summarizer's secrets (such as its WordPress application password) to the same store; Phase 3 uses it on EKS, where External Secrets signs in with **EKS Pod Identity** and RDS keeps its **managed master password** there.

## Context

The clusters need secrets that come from outside them: API tokens (Cloudflare, Slack, Google OAuth, the Cloudflare R2 backup token), SMTP credentials, WordPress's keys and salts, and, until keyless access ([step 9.1](../plan.md#step-91-keyless-aws-access-for-pods)), the scoped IAM keys. Secrets created and used only inside a cluster are generated there instead ([ADR 1047](1047-in-cluster-credentials-and-rotation.md)), and nothing secret goes in Git.

The design has always kept these secrets in **AWS Secrets Manager** and synced them into the clusters with the **External Secrets Operator**, but no ADR recorded the choice or the alternatives. **HashiCorp Vault** is the best-known self-hosted secrets store in Kubernetes, so the question of why it is not used deserves a written answer. The constraints:

- **One operator,** a **three-node home cluster** with a fixed memory budget ([ADR 1020](1020-three-node-ha-home-cluster.md)), and a few dollars a month for anything that is not the site itself.
- **The project already depends on AWS:** the Organization, S3, SES, KMS, CloudTrail and the security services ([ADR 1019](1019-aws-multi-account-sra.md)), with IAM for access and CloudTrail alerts for unexpected use.
- **Both sites** should use the same mechanism, and Phase 3's russetleaf.com runs on AWS itself.
- **Recovery:** a secrets store is something every other service needs at startup, so it must not be hard to bring back after a cold start or a disaster ([disaster recovery plan](../disaster-recovery.md)).

## Decision

- **Secrets that come from outside the cluster live in AWS Secrets Manager,** in the account that uses them (russetleaf-home; russetleaf-com in Phase 3), encrypted with KMS, readable only by identities in the Organization ([ADR 1019](1019-aws-multi-account-sra.md)), with every read recorded by CloudTrail.
- **The External Secrets Operator** syncs them into Kubernetes Secrets through a `ClusterSecretStore`, with one `ExternalSecret` per application secret. If AWS or the operator is unavailable, the Secrets already in the cluster keep working; a bad value is rolled back by pointing at the previous version (`AWSPREVIOUS`).
- **How External Secrets signs in to AWS:** at home, a scoped IAM key created once by hand (step 4.2), the one static credential the cluster holds, until step 9.1 replaces it with keyless OIDC access; on EKS, Pod Identity.
- **Rotation:** automatic where AWS provides it (RDS's managed master password in Phase 3); third-party tokens on the manual schedules in the ongoing-operations tables ([ADR 1019](1019-aws-multi-account-sra.md)); in-cluster passwords by the rotation job ([ADR 1047](1047-in-cluster-credentials-and-rotation.md)).
- **No HashiCorp Vault (or OpenBao)** as the store, self-hosted or as HashiCorp's hosted service.

## Alternatives considered

- **HashiCorp Vault or OpenBao, self-hosted on the home cluster:** the most capable option: dynamic credentials (a short-lived database user per pod), leases, fine-grained policies, its own audit log, and PKI and encryption services. But running it properly means **three replicas** with Raft storage for high availability, on nodes whose memory is already allocated; **unsealing** after every restart (or auto-unseal, which at home would use AWS KMS anyway); its own **backups**, upgrades and monitoring; and it becomes something the whole cluster needs before anything else can start, which makes a cold start or a rebuild harder. Since HashiCorp's 2023 license change Vault is source-available (BSL) rather than open source; **OpenBao** is the open-source fork with the same design and the same operating work. Dynamic database credentials, its strongest feature, were already considered and left for later in [ADR 1047](1047-in-cluster-credentials-and-rotation.md).
- **HashiCorp's hosted Vault (HCP Vault Dedicated):** no servers or unsealing to run, but a paid service at a much higher monthly cost than Secrets Manager's few dollars for this many secrets (check current pricing), one more vendor and sign-in to secure, and the home cluster would still need a bootstrap credential to reach it.
- **Encrypted secrets in Git (SOPS, or Bitnami Sealed Secrets):** no external service, and secrets are versioned with the manifests. But every change and rotation is a manual commit; there is no read audit; a leaked decryption key exposes every secret in Git's history, including old ones; and Argo CD needs a plugin (for SOPS) or a controller (Sealed Secrets) whose key must itself be backed up.
- **AWS Systems Manager Parameter Store (SecureString):** standard parameters are free, and External Secrets supports it. But it has no built-in rotation; cross-account sharing needs the paid advanced tier; RDS's managed master password is stored only in Secrets Manager, which Phase 3 needs anyway; and [ADR 1019](1019-aws-multi-account-sra.md) already keeps Systems Manager out of the design. Secrets Manager's price, about **$0.40 per secret a month** plus API calls (about $2 a month in total here), is worth one service and its rotation support.
- **Bitwarden Secrets Manager** (a separate product from the password manager, with an External Secrets provider): one vendor for people and machines, but it would put the cluster's secrets with the same provider as the break-glass kit, needs its own machine token at home (the same bootstrap problem), and has none of the IAM, KMS and CloudTrail integration the security alerting relies on.
- **Plain Kubernetes Secrets created by hand:** nothing to run, but no source of truth outside the cluster, no audit, no history, and every rebuild means typing secrets in again.

## Consequences

- **Little to run:** Secrets Manager is managed, and External Secrets is one small operator; nothing has to be unsealed, backed up or upgraded beyond the operator's chart, and a rebuilt cluster gets its secrets back as soon as External Secrets starts.
- **Access and audit are the same as for every other AWS resource:** IAM policies per secret, KMS encryption, Organization-only access, and CloudTrail records of every read that GuardDuty and the audit alerts already watch.
- **The home cluster depends on AWS for new or changed secrets** (existing Secrets keep working during an outage), and holds one static IAM key until step 9.1.
- **No dynamic credentials:** secrets are long-lived values that are rotated, not short-lived ones issued per use; [ADR 1047](1047-in-cluster-credentials-and-rotation.md) narrows the gap for the database with two alternating users.
- **Cost** grows with the number of secrets (about $0.40 each a month), which matters only if the count grows a lot.

## When to revisit

- **Dynamic credentials become worth their cost:** more applications use the home database, or short-lived credentials are needed for other systems ([ADR 1047](1047-in-cluster-credentials-and-rotation.md)): consider OpenBao (or Vault).
- **The project moves away from AWS,** or the home site must work without it.
- **The number of secrets grows** to where Secrets Manager costs tens of dollars a month: move values that never rotate to Parameter Store.
- **Encryption or PKI services** beyond cert-manager's ([ADR 1028](1028-internal-pki.md)) are needed by applications.
