---
name: threat-model
description: Systematic threat modeling via STRIDE — identify threats per component before attackers do. Run at design time, not after incident.
---

# threat-model

## STRIDE

Walk through each component, apply each threat category:

- **S**poofing — impersonating someone else. (Auth bypass, forged JWT, session hijack.)
- **T**ampering — unauthorized modification. (SQL injection, CSRF, tampered payload.)
- **R**epudiation — deny having done it. (Missing audit log.)
- **I**nformation disclosure — leak data. (Verbose errors, cross-tenant data, unencrypted storage.)
- **D**enial of service — prevent legitimate use. (Resource exhaustion, slow POST attack.)
- **E**levation of privilege — gain more access than authorized. (Missing permission checks, IDOR.)

## Flow

1. **Draw the system** — context diagram with external actors, services, data stores, trust boundaries.
2. **Identify trust boundaries** — where does untrusted input enter trusted territory?
3. **Per component, per threat category** — is this applicable? What's the impact? What's the mitigation?
4. **Rank** by impact × likelihood.
5. **Document** as a threat model file in `ai/decisions/` or `ai/audits/`.
6. **Fix** high-rank threats before shipping.

## Output (per feature / system)

```
## Threat Model — Order Placement

Components:
 - Client (web browser)
 - /orders POST endpoint
 - OrderService
 - PostgreSQL orders table
 - Stripe (external)

Trust boundaries:
 1. Client → /orders endpoint (untrusted input)
 2. OrderService → Stripe (we trust Stripe, but verify webhooks)

Threats:

S1 (Spoofing): Client impersonates another user to place orders on their behalf.
  Impact: HIGH — financial fraud.
  Likelihood: MEDIUM — requires stolen session.
  Mitigation: JWT verified on every request; user_id from token, never from body.

T1 (Tampering): Client tampers with price in request body.
  Impact: HIGH — revenue loss.
  Likelihood: HIGH — trivial to try.
  Mitigation: Server calculates price from product_id + quantity; ignore client-sent price.

I1 (Info disclosure): Customer A sees customer B's orders.
  Impact: CRITICAL — privacy breach, compliance violation.
  Likelihood: MEDIUM — any missing tenant/user filter.
  Mitigation: Every query filters by user_id + tenant_id. Cross-tenant test required.

D1 (DoS): Attacker POSTs thousands of large orders.
  Impact: MEDIUM — service degradation.
  Likelihood: HIGH — easy.
  Mitigation: Rate limit at ingress + per-user. Request size cap.

E1 (Elevation): Regular user accesses admin order management.
  Impact: HIGH — unauthorized refunds.
  Likelihood: MEDIUM — missing role check.
  Mitigation: Admin endpoints require role=admin; policy tested.

R1 (Repudiation): Customer claims they didn't place an order.
  Impact: MEDIUM — support burden, fraud disputes.
  Mitigation: Audit log with timestamp, IP, user agent, request id on every order.

Open issues (rank-ordered):
  1. T1 mitigation not yet verified (ticket ORD-42).
  2. Rate limits not yet configured (ticket INFRA-17).
```

## When to threat-model

- Any new public endpoint.
- Any authentication / authorization change.
- Any new data store for sensitive data.
- Any new external integration.
- Before every major release.

## Rules

- Include the attacker persona — "anonymous internet rando" vs "disgruntled employee" are different threats.
- Don't dismiss threats with "our WAF handles it" without verifying.
- File mitigations as tickets, not as "we'll do it later".
- Revisit when the system changes.
