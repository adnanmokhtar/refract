---
name: threat-model
description: Systematic threat modeling via STRIDE — identify threats per component before attackers do. Run at design time, not after incident.
---

# threat-model

## Premise

Find real threats, no hand-waves. Every threat cites the component + trust-boundary crossing (`<path:line>` for the entry handler, the auth check, the data store), the attacker persona ("anonymous internet rando" vs "authenticated tenant user" vs "disgruntled employee"), and a concrete mitigation ticket or `<path:line>` where the mitigation lives or must live. "Could be vulnerable to SQLi" is not a threat; "T1: `/orders` POST passes `req.body.price` into `OrderService.create` (`<path:line>`); attacker tampers price; mitigation: server recomputes from product_id (`<path:line>`)" is. Mitigations like "our WAF handles it" are halted unless cited with a configured rule.

## Halt conditions

- Halt on any threat row without component path + trust-boundary citation.
- Halt on impact/likelihood ratings without a one-line justification grounded in the attacker persona.
- Halt on mitigations recorded as prose ("we'll add rate limits") without a ticket id or `<path:line>` for where the control exists / must live.

## STRIDE

Walk through each component, apply each threat category:

- **S**poofing — impersonating someone else. (Auth bypass, forged JWT, session hijack.)
- **T**ampering — unauthorized modification. (SQL injection, CSRF, tampered payload.)
- **R**epudiation — deny having done it. (Missing audit log.)
- **I**nformation disclosure — leak data. (Verbose errors, cross-tenant data, unencrypted storage.)
- **D**enial of service — prevent legitimate use. (Resource exhaustion, slow POST attack.)
- **E**levation of privilege — gain more access than authorized. (Missing permission checks, IDOR.)

For features that handle PII, run **LINDDUN** alongside STRIDE — it covers the privacy threats STRIDE misses: Linkability, Identifiability, Non-repudiation, Detectability, Disclosure of information, Unawareness, Non-compliance (e.g., over-collection, re-identification, missing consent/retention controls).

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
 - relational-DB orders table
 - payment provider (external)

Trust boundaries:
 1. Client → /orders endpoint (untrusted input)
 2. OrderService → payment provider (we trust the provider, but verify its webhooks)

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

## When to run

- Any new public endpoint.
- Any authentication / authorization change.
- Any new data store for sensitive data.
- Any new external integration.
- Before every major release.

## False positives / gotchas

- Include the attacker persona — "anonymous internet rando" vs "disgruntled employee" are different threats.
- Don't dismiss threats with "our WAF handles it" without verifying.
- File mitigations as tickets, not as "we'll do it later".
- Revisit when the system changes.
