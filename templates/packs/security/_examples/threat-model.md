---
name: threat-model
description: Systematic threat modeling via STRIDE — identify threats per component before attackers do. Run at design time, not after incident. This skill is the dispatchable primitive; `/threat-model` is the session that makes its output durable.
---

# threat-model

## Premise

Find real threats, no hand-waves. Every threat cites the component + trust-boundary crossing (`<path:line>` for the entry handler, the auth check, the data store), the attacker persona ("anonymous internet rando" vs "authenticated tenant user" vs "disgruntled employee"), and a concrete mitigation ticket or `<path:line>` where the mitigation lives or must live. "Could be vulnerable to SQLi" is not a threat; "T1: `/orders` POST passes `req.body.price` into `OrderService.create` (`<path:line>`); attacker tampers price; mitigation: server recomputes from product_id (`<path:line>`)" is. Mitigations like "our WAF handles it" are halted unless cited with a configured rule.

## Halt conditions

- Halt on any threat row without component path + trust-boundary citation.
- Halt on impact/likelihood ratings without a one-line justification grounded in the attacker persona.
- Halt on mitigations recorded as prose ("we'll add rate limits") without a ticket id or `<path:line>` for where the control exists / must live.

These three are the canonical set — `/threat-model` Phase 6 enforces them by reference. Do not keep a second copy.

## STRIDE

- **S**poofing — impersonating someone else. (Auth bypass, forged JWT, session hijack.)
- **T**ampering — unauthorized modification. (SQL injection, CSRF, tampered payload.)
- **R**epudiation — deny having done it. (Missing audit log.)
- **I**nformation disclosure — leak data. (Verbose errors, cross-tenant data, unencrypted storage.)
- **D**enial of service — prevent legitimate use. (Resource exhaustion, slow POST attack.)
- **E**levation of privilege — gain more access than authorized. (Missing permission checks, IDOR.)

For PII features run **LINDDUN** alongside (Linkability, Identifiability, Non-repudiation, Detectability, Disclosure, Unawareness, Non-compliance). Model privacy threats here at design time; hand the built PII data-flow to `@data-privacy-reviewer` once the code exists.

## Flow

1. **Draw the system** — actors, services, data stores, trust boundaries.
2. **Identify trust boundaries** — where untrusted input enters trusted territory.
3. **Per component, per letter** — applicable? impact? mitigation?
4. **Rank** by impact × likelihood.
5. **Document** as `ai/audits/threat-model-<feature>-<date>.md`.
6. **Fix** high-rank threats before shipping.

## Output (per feature / system)

Each row must survive the Halt conditions: persona, `<path:line>`, and a mitigation that is code-that-exists or a ticket.

```
## Threat Model — Order Placement

Boundary 1: Client (anonymous / authenticated tenant user) → POST /orders
  entry: <orders controller:line>   authz: <auth guard:line>   store: <orders repo:line>

T-01  S  Caller replays a stolen session to order as another user.
         Persona: authenticated tenant user with a leaked token. Impact HIGH × Likelihood MED.
         Mitigation: EXISTS — token verified per request at <auth guard:line>; subject from
         the token, never the body, at <orders controller:line>.

T-02  T  Caller sends `price` in the body and the server trusts it.
         Persona: anonymous internet rando; trivial. Impact HIGH × Likelihood HIGH.
         Mitigation: MISSING — recompute from product_id. Ticket ORD-42.

T-03  I  Tenant A reads tenant B's order by id.
         Persona: authenticated tenant user. Impact CRITICAL × Likelihood MED.
         Mitigation: EXISTS — scope by construction at <base repository:line>; cross-tenant
         leak test at <test file:line>. Deep audit: @tenant-isolation-reviewer.

T-04  E  Regular user reaches admin refund management.
         Persona: authenticated tenant user probing routes. Impact HIGH × Likelihood MED.
         Mitigation: PARTIAL — role checked at <admin router:line>, no test asserts denial.
         Ticket SEC-17.

Boundary 2: API → payment provider — a real run covers every letter per boundary and
  writes `none — <why>` where a letter does not apply.

Open issues (rank-ordered): 1. T-02 (ORD-42, unmitigated).  2. T-04 (SEC-17, untested).
```

## When to run

- Any new public endpoint; any auth / authz change.
- Any new data store for sensitive data; any new external integration.
- Before every major release.

## False positives / gotchas

- **A letter with no threat still needs a row** — `none — <why>`. A skipped letter reads the same as an unexamined one.
- Include the attacker persona; likelihood is a property of the persona, not the code.
- Don't dismiss with "our WAF handles it" without citing the configured rule.
- **EXISTS is a claim about code** — it carries a `<path:line>` or it is MISSING. This models mitigations; only `/security-audit` verifies them.
- Revisit when the system changes.

## Related

`/threat-model` (durable session: actors, ADRs, residual risk, re-audit triggers) · `@data-privacy-reviewer` (LINDDUN half, once code exists) · `/security-audit` (turns planned into verified).
