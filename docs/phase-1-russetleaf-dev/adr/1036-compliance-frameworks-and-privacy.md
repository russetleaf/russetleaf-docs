# ADR 1036: Compliance frameworks and privacy

- **Status:** Accepted
- **Date:** 2026-11-02
- **Applies to:** both sites, the clusters, the build pipeline and the security documents
- **Phase:** 1. Later: Phase 2's guardrails redact personal data; Phase 3 adds GuardDuty's EKS findings to the ATT&CK map and the privacy notice on russetleaf.com.

## Context

The design was checked against common compliance frameworks: MITRE ATT&CK, GDPR, HIPAA, PCI DSS, NIST and the CIS Benchmarks.

- **CIS** was well covered: the CIS Kubernetes Benchmark (kube-bench on EKS, Trivy Operator compliance reports, Talos hardening notes), CIS AWS Foundations through Security Hub, and the CIS Controls in the control matrix (Phase 1 step 8.5). But the image build had no CIS Docker Benchmark check, and the benchmark results were not linked to the control matrix.
- **MITRE ATT&CK** was used only as a Kubescape posture score; nothing showed which attack techniques the detections (Falco, audit alerts, GuardDuty, Hubble) cover and which they miss.
- **GDPR** was not addressed, although the sites are public and hold personal data: commenters' names and email addresses, visitors' IP addresses in logs, and admins' Google Accounts. There was no privacy notice, no record of processing or processor list, no retention schedule, no procedure for access or deletion requests, and no breach-notification runbook. The 30-day locked backups ([ADR 1018](1018-disaster-recovery.md)) cannot be erased early, which needs to be stated.
- **NIST** was not referenced. Many controls match NIST guidance, but none were mapped.
- **HIPAA** and **PCI DSS** do not apply (no health data, no card payments), but the documents did not say so.

## Decision

- **Compliance scope** (`docs/security/compliance.md`): which frameworks apply and how.
    - **Apply:** GDPR (lightly: a small public site), CIS Benchmarks, NIST guidance (as a reference, not a certification), MITRE ATT&CK (for detection coverage).
    - **Out of scope, with reasons:** HIPAA (no health data; if it ever applied, the encryption, audit logging and access controls carry over, AWS's Business Associate Agreement would be needed, and only HIPAA-eligible AWS services could be used) and PCI DSS (no card data; if a shop is ever added, a **hosted payment page** such as Stripe Checkout keeps card data off the site, so the site stays in PCI's smallest self-assessment category, SAQ A).
- **GDPR basics** (Core, since they apply from the day the site is public):
    - A **privacy notice** page in the theme (who runs the site, what is collected, why, how long, which processors, how to make a request), linked from every page footer and the comment form.
    - **Record of processing** (`docs/privacy/record-of-processing.md`): each kind of personal data, where it is stored (database, logs, backups, Slack alerts), why, and for how long.
    - **Processors list:** Cloudflare, AWS, Google, GitHub and Slack, each with its data processing terms linked.
    - **Retention schedule:** logs 7–14 days; database backups 30 days locked plus the lifecycle period, and monthly copies for 12 months ([ADR 1018](1018-disaster-recovery.md)); audit logs 1 year ([ADR 1033](1033-identity-and-access.md)); unapproved comments deleted after 30 days.
    - **Request runbook** (`docs/runbooks/data-subject-request.md`): find and export or delete a person's data with WordPress's built-in **personal data export and erasure tools**; locked backups expire on their own within the retention period (up to 12 months for the monthly copies), and a restore re-applies past erasures (kept in an erasure log).
    - **Personal data breach runbook** (`docs/runbooks/personal-data-breach.md`): assess, contain, record, and notify the supervisory authority within **72 hours** if required (and affected people if the risk is high); linked from the security alerts' runbooks.
    - **No tracking cookies:** no analytics or third-party scripts that set cookies, so no consent banner is needed; a CI check (Playwright) confirms anonymous page views set no cookies and load no third-party scripts. Adding analytics later means choosing a cookieless tool or adding consent.
- **MITRE ATT&CK detection map** (`docs/security/attack-coverage.md`): each detection (Falco rules, Kubernetes audit alerts, GuardDuty finding types, Hubble drops, CrowdSec) mapped to the **ATT&CK for Containers** techniques it covers, with the uncovered techniques listed and either accepted or planned. Falco rules keep their MITRE tags, and a Grafana panel shows Falco alerts by technique.
- **NIST mapping:** the control matrix (Phase 1 step 8.5) is organized by **Cybersecurity Framework 2.0** functions (Govern, Identify, Protect, Detect, Respond, Recover), with two checklists as appendices: **SP 800-190** (application container security) and **SP 800-218** (Secure Software Development Framework, SSDF), which the SLSA provenance and the CI checks map onto.
- **CIS:** the image build runs Trivy's **CIS Docker Benchmark** compliance check on each image; the CIS Kubernetes (kube-bench, Trivy Operator), CIS AWS Foundations (Security Hub) and CIS Docker results are linked from the control matrix as evidence.

## Alternatives considered

- **A consent-management platform:** unnecessary without tracking cookies; adds a third-party script.
- **Mapping to NIST SP 800-53:** far more detail than a project this size needs; CSF 2.0 plus the container and SSDF guidance fit better.
- **Treating GDPR as out of scope** (a personal, non-commercial site): GDPR's household exemption does not cover a public website, and the basics are cheap.
- **AWS Audit Manager** (collects evidence from Config, CloudTrail and Security Hub automatically and maps it to frameworks such as CIS, NIST CSF, SOC 2 and PCI DSS): it only sees AWS, while most of the controls live in Kubernetes, CI and the home cluster; it charges per evidence item; and no audit is planned. The control matrix (Phase 1 step 8.5) maps every control to its evidence instead. Revisit for a real audit of an always-on russetleaf.com.
- **Formal certification (SOC 2, ISO 27001):** not meaningful without customers or contracts that require it; the control matrix applies the same controls without the audit.

## Consequences

- The project can say clearly which frameworks it follows and why the others do not apply.
- The sites have a privacy notice and documented handling of personal data from launch.
- Detection coverage is measurable, and its gaps are explicit.
- A little ongoing work: keeping the record of processing and the ATT&CK map current when components change.
- About **10–14 hours** more, mostly in Phase 1.

## When to revisit

- Analytics, a newsletter, user accounts or anything else that collects more personal data.
- Payments or health data, ever: PCI DSS or HIPAA come into scope.
- New detections or components: update the ATT&CK map.

## Open items

- Phase 1 step 5.12: compliance scope document and GDPR basics.
- Phase 1 step 5.1: CIS Docker Benchmark check.
- Phase 1 step 7.1: ATT&CK detection map and Grafana panel.
- Phase 1 step 8.5: NIST CSF 2.0 organization, SP 800-190 and SSDF checklists, CIS evidence links.
- Phase 3 step 4.1: GuardDuty's EKS findings in the ATT&CK map; the privacy notice and cookie check on russetleaf.com.
