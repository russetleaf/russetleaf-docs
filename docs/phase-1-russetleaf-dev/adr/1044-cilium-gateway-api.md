# ADR 1044: Cilium's Gateway API for traffic into the home cluster (ingress-nginx is retired)

- **Status:** Accepted
- **Date:** 2026-11-03
- **Applies to:** russetleaf.dev (the home cluster's ingress, canaries, SLIs and CrowdSec). russetleaf.com keeps the ALB through the AWS Load Balancer Controller.
- **Phase:** 1

## Context

The design used **ingress-nginx** as the home cluster's ingress controller, between cloudflared and WordPress. The Kubernetes project announced ingress-nginx's retirement in late 2025, with best-effort maintenance ending in March 2026; after that it receives no releases or security fixes. (From the project's announcement as recalled at the time of writing; confirm its current status.) An internet-facing component without security fixes does not fit the design. Ingress-nginx also fed the Argo Rollouts canary analysis, the site's availability and latency SLIs, and CrowdSec.

The cluster already runs **Cilium** with kube-proxy replacement ([ADR 1027](1027-cilium-cni.md)), which implements the Kubernetes **Gateway API** with its built-in Envoy proxy.

## Decision

- **Cilium's Gateway API implementation** replaces ingress-nginx at home: the Gateway API CRDs (standard channel), `gatewayAPI.enabled` in the Cilium values, a `Gateway` for russetleaf.dev and the admin hostnames, and **`HTTPRoute`s** for WordPress and the admin tools. cloudflared sends traffic to the Gateway's in-cluster Service.
- **No LoadBalancer Service:** Kyverno blocks `LoadBalancer` Services, and nothing outside the cluster connects directly (cloudflared is inside it), so the Gateway's Service is `ClusterIP`. Check how the installed Cilium version sets the Gateway's Service type (for example a `CiliumGatewayClassConfig`); otherwise give it a narrow, named Kyverno exception.
- **Availability:** Cilium's Envoy runs on every node, so the gateway has no single replica to lose; cloudflared keeps two replicas spread across nodes.
- **Canaries:** Argo Rollouts' **Gateway API traffic-router plugin** shifts traffic by changing the `HTTPRoute`'s backend weights; the analysis queries Prometheus for the gateway's request metrics (Cilium's Envoy metrics, or Hubble's HTTP metrics for the WordPress Service). Confirm the metric names for the installed Cilium version.
- **SLIs:** availability and latency are measured at the gateway inside the cluster, as before ([ADR 1021](1021-slos-and-error-budgets.md)).
- **CrowdSec** reads WordPress's Apache access logs (with the visitor's address from Cloudflare's `CF-Connecting-IP` header) and the gateway's access logs; check the available CrowdSec parsers when building.
- **The WordPress chart** supports both an `HTTPRoute` (home) and an `Ingress` (AWS, for the ALB), chosen in the overlay.
- **Rollout:** Cilium's Gateway API is turned on in Phase 1 step 4.3 through Argo CD (the CRDs in the first sync wave, then the Cilium values change, synced by hand like every Cilium change).

## Alternatives considered

- **Keep ingress-nginx:** works today, but an unmaintained, internet-facing component; rejected.
- **Traefik:** a mature, maintained ingress controller with Gateway API support, but one more component and another set of metrics, alongside a Cilium that already includes a gateway.
- **NGINX Gateway Fabric or F5's NGINX Ingress Controller:** maintained NGINX-based options, but also additional components.
- **Envoy Gateway:** a full Gateway API implementation, but it duplicates the Envoy that Cilium already runs.
- **The Gateway API on AWS as well** (the AWS Load Balancer Controller's Gateway API support): would make both sites use the same route resources; kept as a later option, since the ALB Ingress path is well established.

## Consequences

- One component fewer at home: networking, policy, observability and ingress all come from Cilium.
- The Gateway API is the current Kubernetes standard for ingress; the Ingress API is frozen and receives no new features.
- Ingress at home now depends on Cilium, already the highest-risk component ([ADR 1016](1016-rollback-strategy.md)); its manual-sync and `helm rollback` recovery path covers this too.
- The two sites differ: `HTTPRoute`s at home, an `Ingress` on AWS; the chart handles both.

## When to revisit

- Cilium's Gateway API lacks a feature the site needs (for example, a specific rewrite or header rule): consider Envoy Gateway or Traefik.
- The AWS site moves to the Gateway API: use `HTTPRoute`s on both sites.

## Open items

- Phase 1 step 4.3: the Gateway API CRDs, Cilium's Gateway API, the Gateway and routes, the Service type.
- Phase 1 step 6.2: the Argo Rollouts Gateway API plugin and the analysis metrics.
- Phase 1 step 7.9: CrowdSec's log sources and parsers.
