# Phase 1 improvements after go-live

Every piece of Phase 1 work that was deliberately put off, in one place: what it is, why it waited, what should trigger it, and what became of it. Whenever a change defers something (a cheaper option chosen for now, a feature left for later, a tool not yet tested), the same change adds it here. This list is reviewed in [step 9.3](plan.md#step-93-post-go-live-improvements), once the Core tier is published, and quarterly after that ([Ongoing operations](plan.md#ongoing-operations-after-the-build)).

## How the list is kept

- **One row per improvement,** with a short ID (`I1-<n>`, numbered in order and never reused), the reason it was put off, and its **trigger**: the event or date that makes it worth doing (for example "after go-live" or "when a YubiKey 5 is bought").
- **Estimate** in focused hours, like the plan's steps. An item larger than a few hours, or one that needs a design decision, becomes its own plan step or ADR when it is taken up.
- **Status:**
    - **Open:** waiting for its trigger or for the next review.
    - **Planned:** taken up, with a link to the step, ADR or issue that does it.
    - **Done:** finished, with the date.
    - **Dropped:** no longer worth doing, with the reason.
- **Rows are not deleted:** a finished or dropped item keeps its row, so the list also records what was decided.
- **Later phases** keep their own list in their phase folder, started when the phase begins.

## The list

| ID | Improvement | Why it was put off | Trigger | Est. hours | Status |
|---|---|---|---|---|---|
| I1-1 | **Move the GPG backup key onto a YubiKey 5** (for example a YubiKey 5 NFC, OpenPGP with firmware 5.2.3 or later), so every use of the key needs the YubiKey, a PIN and a touch ([setup guide](setup/break-glass-kit.md#moving-the-key-to-a-yubikey-later)). A YubiKey 5 can also hold authenticator codes (OATH, read with Yubico Authenticator), which could replace Google Authenticator for the services that need codes ([account sign-in setup guide](setup/account-sign-in.md#the-rule)) | Both of the operator's YubiKeys are Security Key NFC, which have no OpenPGP function; the key is used only for restores and the quarterly drill, so a passphrase-protected file in the break-glass kit is enough for now (decision log, 2026-11-05) | A YubiKey 5 series key is bought; or by the step 9.3 review | 1–2 (plus buying the key) | Open |
| I1-2 | **Try Bitwarden's SSH agent** for the commit signing key, so the key lives in the vault instead of a passphrase-protected file ([workstation configuration](plan.md#4-configuration)) | Not yet tested with the Bitwarden snap, whose confinement may block the agent's socket | By the step 9.3 review | 1 | Open |
| I1-3 | **Encrypt the OpenTofu state** | The state copies in the Backup account had to stay readable without the russetleaf-infra account's keys (decision log, 2026-11-06) | — | — | Dropped (2026-11-06): designed and built from the first apply instead ([ADR 1054](adr/1054-opentofu-state-and-plan-encryption.md)) |
| I1-4 | **Adopt a full SIEM,** for example OpenSearch Security Analytics fed by AWS Security Lake, running the same Sigma rules, with case management and correlation across sources ([ADR 1058](adr/1058-security-detections-as-code.md)) | Sigma rules on Loki, with 90-day security logs, cover detection, correlation and retention for one operator, without the memory of an indexer at home or about $25 a month or more on AWS | A second operator or a security team; a compliance audit that requires a SIEM or longer searchable security logs; the `security` tenant too slow to query in Loki | 15–30 | Open |
| I1-5 | **Tighten DMARC for russetleaf.dev** from `p=none` to `quarantine`, then `reject` ([Google Workspace setup guide](setup/google-workspace.md#part-2-mail-records)) | A new policy starts at `none` so that legitimate senders missing from SPF or DKIM show up in the reports before mail is rejected | Two weeks of reports showing only Google and SES as senders; or by the step 9.3 review | 1 | Open |
| I1-6 | **A second Google Workspace super administrator,** an account used only for emergencies, as Google recommends ([ADR 1059](adr/1059-google-workspace-identity.md)) | One operator: the administrator-generated backup codes in the break-glass kit cover a lost-keys lockout, and a second account costs a license | A second operator joins; or a lockout drill shows the backup codes are not enough | 1 (plus a license) | Open |
| I1-7 | **A scheduled check of the external links** (for example lychee, open source, in a weekly GitHub Actions workflow), opening an issue for any reference that no longer loads | The references were added and read on 2026-11-12, and the doc checks cover only internal links; a weekly run against about 100 vendor pages adds a workflow to maintain | The first reference found broken by hand; or by the step 9.3 review | 1–2 | Open |
