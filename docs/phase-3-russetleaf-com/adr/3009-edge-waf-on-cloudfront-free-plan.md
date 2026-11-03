# ADR 3009: WAF at the edge on CloudFront's flat-rate Free plan, plus the full rule set on the ALB during demos

- **Status:** Accepted
- **Date:** 2026-11-03
- **Applies to:** russetleaf.com's CloudFront distribution (`envs/aws-edge`) and the ALB's web ACL (`envs/aws`)
- **Phase:** 3

## Context

AWS WAF sat only on the ALB, so it existed (and cost money) only during demos; the always-on CloudFront distribution, which serves the offline page and the media, had no WAF. On-demand WAF on CloudFront would cost about $15 a month around the clock. In late 2025 AWS introduced **CloudFront flat-rate pricing plans**, which bundle CloudFront, AWS WAF, DDoS protection, the Route 53 hosted zone, CloudWatch Logs ingestion and S3 storage credits into one monthly price per distribution, with no overage charges. From AWS's documentation at the time of writing:

| | Free ($0) | Pro ($15/month) |
|---|---|---|
| WAF rules (managed and custom together) | 5 | 25 |
| WordPress, PHP and SQL database protections | No | Yes |
| IP rate limiting | Yes | Yes |
| WAF request logs, CloudFront access logs | No | Yes |
| Cache behaviors | 5 | 10 |
| Custom origin-request and response-header policies | No (AWS's managed policies only) | No (Business tier) |
| Monthly requests and data transfer | 1 M, 100 GB | 10 M, 50 TB |

Requests blocked by WAF do not count toward the allowance; exceeding it never adds charges, but sustained excess can lead to slower delivery. A distribution on a plan must keep a web ACL associated, and plans do not support custom WAF rule groups or real-time logs. Pro would cover everything, but adds about $13 a month net, taking the always-on total above the $30–50 budget.

## Decision

- **Subscribe the CloudFront distribution to the flat-rate Free plan**, with a web ACL holding five rules that protect the edge around the clock:
    1. AWS managed **core rule set**
    2. AWS managed **known bad inputs**
    3. AWS managed **Amazon IP reputation list**
    4. a **rate-based rule** on `/wp-login.php`
    5. a rule **blocking `/xmlrpc.php`**
- **Keep the full web ACL on the ALB during demos** (on-demand, created and destroyed with the demo stack): the same groups plus **WordPress application**, **PHP application** and **SQL database**, and the **anonymous IP list** in count mode. The edge ACL filters first; the ALB ACL adds the application-specific rules only the paid tiers include at the edge.
- **Fit within five cache behaviors:** the **default behavior** (the ALB origin) is **uncached** (AWS's managed `CachingDisabled` cache policy) and uses AWS's managed **`AllViewerExceptHostHeader`** origin-request policy, so cookies and query strings reach WordPress on every path; separate behaviors for `/wp-admin/*`, `/wp-login.php` and the OIDC callback are no longer needed. The other behaviors are `/wp-content/uploads/*` (media, cached) and `/offline/*` (offline page), three in all.
- **Security headers** come from AWS's managed **`SecurityHeadersPolicy`** response-headers policy (HSTS, `X-Content-Type-Options`, `X-Frame-Options`, Referrer-Policy and others); WordPress's `security-headers` plugin still sets Content-Security-Policy and Permissions-Policy.
- **The Route 53 hosted zone is attached to the plan**, so its cost is covered.
- **Edge load tests** (Phase 3 step 5.4) stay small: they use the plan's 1 million-request allowance (a one-time spike up to three times the allowance is accommodated), and their temporary allow rule counts as one of the five rules, so one existing rule is switched to count mode for the test.
- **Terraform:** manage the web ACL and distribution in `envs/aws-edge`; if the AWS provider cannot yet manage the plan subscription, subscribe once with the CLI (the Pricing Plan Manager API) and record it in the decision log. Confirm the plan's current limits when building.

## Alternatives considered

- **The Pro plan ($15/month):** the WordPress, PHP and SQL rules, WAF logs and more cache behaviors at the edge, but about $13 a month more around the clock for a site that is mostly an offline page; rejected for now.
- **No WAF at the edge (the previous design):** cheapest, but the always-on distribution is unprotected between demos.
- **On-demand WAF on CloudFront:** about $15 a month always on, with no bundled benefits.
- **Moving all rules to the edge and removing the ALB web ACL:** not possible on the Free plan (five rules, no WordPress, PHP or SQL protections).

## Consequences

- The edge is protected 24/7 at no extra cost, and the Route 53 zone's cost is covered.
- During demos, requests pass two web ACLs: the edge's baseline and the ALB's application rules.
- No WAF or CloudFront access logs at the edge; the ALB's WAF logs cover demos.
- The default behavior caches nothing, so CloudFront does not take page load off WordPress; acceptable for demo traffic, and Valkey caches objects inside WordPress.
- The web ACL cannot be removed from the distribution while the plan is active.

## When to revisit

- russetleaf.com becomes always-on, or WAF logs are needed between demos: move to the Pro plan and the full rule set at the edge.
- AWS changes the Free plan's limits or features.

## Open items

- Phase 3 step 1.2: the Free plan subscription, the edge web ACL, the managed policies and the three cache behaviors.
- Phase 3 step 1.7: the ALB web ACL (full rule set).
- Phase 3 step 4.1: confirm both web ACLs in the security review.
