# ADR 1054: OpenTofu state and plan encryption, with a passphrase kept in Secrets Manager and the break-glass kit

- **Status:** Accepted
- **Date:** 2026-11-06
- **Applies to:** every OpenTofu root module in `russetleaf-infra` (both sites)
- **Phase:** 1 (from the first apply in step 2.0; the pipeline in step 2.4). Phase 3's environments use the same setup.

## Context

OpenTofu state holds secret values in plain text: the **Talos machine secrets** (which can rebuild the cluster's certificate authorities), generated passwords where a resource returns them, and every attribute of every resource. Saved plan files, which the pipeline keeps as short-lived workflow artifacts so the reviewed plan is the one applied ([ADR 1030](1030-github-actions-ci.md)), hold the same values.

The state bucket is already encrypted with KMS, private, limited to the CI roles' own keys, and replicated to the Backup account ([ADR 1018](1018-disaster-recovery.md)). But that is **storage** encryption: anyone who can read the objects and use the bucket's key reads the contents, and several roles can read state copies (the plan and apply roles, the replication and monthly-copy roles, the freshness check, break-glass access). Plan artifacts are protected only by GitHub's access to the run.

OpenTofu can encrypt the state and plan files itself, before they are written ([ADR 1052](1052-opentofu-instead-of-terraform.md)). The constraint is recovery: the state copies in the Backup account must stay readable **without the russetleaf-infra account or its keys**, because that is what they protect against ([ADR 1018](1018-disaster-recovery.md)).

## Decision

- **Every root module encrypts its state and its saved plans** with OpenTofu's `encryption` block: the **`pbkdf2` key provider** (a key derived from a passphrase) and the **`aes_gcm`** method, with **`enforced = true`** on both `state` and `plan`, so OpenTofu refuses to write either unencrypted.
- **The passphrase** is a random string of 64 characters, generated in Bitwarden, and passed in a sensitive variable, `state_passphrase`; it is never in Git or in a file in the repo.
- **Where it lives:**
    - **AWS Secrets Manager** in the russetleaf-infra account (`rl/opentofu/state-passphrase`), readable only by the plan and apply roles; `bootstrap/` creates the secret with a **write-only** value, so the passphrase is not stored in `bootstrap/`'s own state.
    - **The break-glass kit:** Bitwarden, the printed copy and the encrypted cloud copies ([break-glass kit setup guide](../setup/break-glass-kit.md)).
- **How each run gets it:**
    - **CI:** the job reads it with its OIDC role (`aws secretsmanager get-secret-value`), masks it in the log (`::add-mask::`), and exports it as `TF_VAR_state_passphrase`; no GitHub secret holds it.
    - **The workstation:** each environment's `.envrc` (direnv, not committed) reads it from Secrets Manager with the operator's Identity Center profile. Before step 2.1 (when `envs/org` still uses local state), it comes from Bitwarden.
- **Key names are generations** (`v1`, `v2`, …), because the state records the name of the key that encrypted it, and decryption looks that name up.
- **Rotation** (yearly, and at once if the passphrase may have leaked): add the new key as the primary (`v2`) with the old one (`v1`) as the `fallback`, run `tofu apply -refresh-only` in every root module (each state is read with the old key and written with the new one), confirm each module plans cleanly with the new passphrase alone, then remove the old key from the configuration and from Secrets Manager. **Keep each old passphrase in the break-glass kit for 12 months**, until the last monthly state copy made with it has expired.
- **Recovery:** a state copy from the Backup account is decrypted with the passphrase from the break-glass kit, with no access to the russetleaf-infra account or any of its keys; the twice-yearly restore drill does exactly that.

## Alternatives considered

- **No client-side encryption** (the bucket's KMS encryption only): nothing more to manage, but every role that can read a state copy reads the Talos machine secrets, and saved plans sit in GitHub in plain text.
- **The `aws_kms` key provider with a key in the russetleaf-infra account:** no passphrase to handle, and each use is logged by CloudTrail; but losing or compromising that account makes every state copy unreadable, which breaks the point of the off-account copies.
- **An `aws_kms` key in the Backup account,** shared with the CI roles: survives the loss of russetleaf-infra, but makes the Backup account part of every plan and apply, and the key still cannot be exported, so losing the Backup account (or a scheduled deletion of the key) would lose every state at once.
- **A passphrase stored as a GitHub secret:** simple, but a long-lived secret in GitHub, where the project keeps none ([ADR 1030](1030-github-actions-ci.md)); Secrets Manager with OIDC gives the same result with access control and CloudTrail records of every read.
- **A KMS key with a passphrase fallback:** OpenTofu's `fallback` only decrypts data that was encrypted with the fallback method, so it does not give a second way to open state written with the primary key.

## Consequences

- **Reading a state or plan file needs the passphrase** as well as access to the file: copies in the Backup account, the monthly copies and plan artifacts are useless without it.
- **One passphrase protects all state.** Losing every copy of it would make the state unreadable, and the infrastructure would have to be re-imported into new state; it is therefore in Secrets Manager and in all three copies of the break-glass kit.
- **The passphrase becomes a credential to manage:** it joins the credential inventory and leak runbook (step 4.2), is rotated yearly, and its old values stay in the kit for 12 months.
- **Tools that read plans** (Checkov, Infracost, IAM Access Analyzer's checks) read them through `tofu show -json` in the same job, which decrypts with the passphrase; nothing else changes in the pipeline.
- **Moving back to Terraform** becomes harder, since Terraform cannot read encrypted state; it would first need a decrypting migration ([ADR 1052](1052-opentofu-instead-of-terraform.md) accepts this).

## When to revisit

- **AWS KMS** gains a way to keep a key usable after its account is lost (or the project adopts a multi-account key design it trusts): consider the `aws_kms` key provider instead of a passphrase.
- **OpenTofu adds a way to encrypt with two keys at once** (so either opens the state): use a KMS key for daily runs and the passphrase only for recovery.

## Open items

- Phase 1 step 2.0: generate the passphrase in Bitwarden, add it to the break-glass kit, and use encryption from the first `envs/org` apply.
- Phase 1 step 2.1: the Secrets Manager secret (write-only value) and the CI roles' access to it.
- Phase 1 step 2.4: the CI steps that read and mask it, and the checks that state and plan files are encrypted.
- Phase 1 step 2.5: the restore drill decrypting a Backup-account copy with the passphrase from the kit.
