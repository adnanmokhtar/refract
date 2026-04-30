---
description: Run a structured threat-model session against a feature / system. STRIDE-based; outputs threat list + mitigations + residual risk + decisions.
---

# /threat-model

> **MVP / rapid-feature mode:** run a 5-minute STRIDE skim — list each STRIDE letter and one threat under each (or `none`). Skip the ASCII diagram + per-threat residual-risk paragraphs. The full template below is for systems with ≥3 trust boundaries OR auth/payment/PII. When in doubt, skim first; escalate to full only if the skim surfaces a real threat in the gated classes.

A formalized threat-modeling exercise. Use BEFORE shipping any feature touching auth, payments, PII, multi-tenant boundaries, or untrusted input. Output is a durable artifact that future audits can re-verify.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## When to use / NOT to use

- USE: new feature with auth / payment / PII / sensitive operations.
- USE: integrating a new third-party service (vendor SDK / OAuth provider / payment processor).
- USE: pre-release sweep on a high-stakes feature.
- USE: post-incident — verify root cause's threat-class is now modeled.
- NOT: routine code review.
- NOT: trivial UI changes.

## Phase 1 — Understand

Gather:
- **Asset list** — what's being protected? (User accounts, payment data, internal API keys, customer-uploaded files, audit logs, tenant data.)
- **Trust boundaries** — where does trusted system meet untrusted input? (HTTP edge, webhook receiver, message queue consumer, file upload, OAuth callback.)
- **Actors** — who interacts with the feature? (Authenticated user, anonymous user, admin, internal system, external partner, attacker.)
- **Data flow** — high-level diagram. What enters the boundary, what flows out.
- **Existing controls** — auth, encryption, validation, rate limit, audit log.

## Phase 2 — Organize (STRIDE per data-flow leg)

For each data-flow segment, walk STRIDE:

| Letter | Threat | Question |
|---|---|---|
| **S** | Spoofing | Can someone pretend to be another user / system? |
| **T** | Tampering | Can someone modify data in transit / at rest? |
| **R** | Repudiation | Can a user claim "I didn't do that" with no evidence? |
| **I** | Information disclosure | Can someone read data they shouldn't? |
| **D** | Denial of service | Can someone exhaust the resource? |
| **E** | Elevation of privilege | Can someone gain admin / cross-tenant / API access they don't have? |

For each YES answer: that's a threat. Document.

## Phase 3 — Retrieve

- `ai/architecture.md` — trust boundaries, auth model.
- `ai/decisions/` — past ADRs about security choices.
- `ai/_baseline/failures/` — past security incidents.
- `.claude/rules/security-principles.md` — applicable rules (A19+).
- OWASP ASVS for the relevant level (1/2/3).
- The feature's API surface + data schema.

## Phase 4 — Generate (the threat-model document)

Output to `ai/audits/threat-model-<feature>-<date>.md`:

```markdown
# Threat model — <feature> — <date>

## Scope
- Feature: <name>
- Trust boundaries: <list>
- Assets in scope: <list>

## Data flow

[ASCII or Mermaid diagram with trust boundaries marked]

## Actors

| Actor | Trust level | Capability |
|---|---|---|
| Anonymous user | UNTRUSTED | Read public; sign up |
| Authenticated tenant member | LIMITED | Read+Write own tenant data |
| Tenant admin | ELEVATED | Manage own tenant + members |
| Internal system | SEMI-TRUSTED | Service-to-service via signed tokens |
| Attacker | UNTRUSTED | Try anything |

## Threats (per STRIDE per data-flow leg)

### Boundary: HTTP edge → API service

| ID | Class | Threat | Likelihood | Impact | Mitigation | Residual |
|---|---|---|---|---|---|---|
| T-01 | S | Attacker forges request impersonating user | High | High | JWT signed + verified; refresh-token rotation; CSRF token | Low |
| T-02 | T | Attacker modifies request body in transit | Low | Medium | TLS 1.2+ enforced; HSTS | Low |
| T-03 | I | Attacker enumerates user IDs via sequential ints | High | Medium | UUIDs, not sequential ints; per-user data scoped | Low |
| T-04 | D | Attacker floods login endpoint | High | High | Rate limit per IP + per user; CAPTCHA on threshold; account lockout | Medium |
| T-05 | E | User passes admin role in request body | High | Critical | Role from session, never request body; role check on every action | Low |

### Boundary: API service → DB

| ID | Class | Threat | Likelihood | Impact | Mitigation | Residual |
|---|---|---|---|---|---|---|
| T-06 | T | SQL injection via untyped query | Medium | Critical | Parameterized queries enforced by ORM; no string interpolation | Low |
| T-07 | I | Cross-tenant data read | High | Critical | Auto-applied tenant filter via RLS or middleware | Low |
| T-08 | I | Backup files exposed | Low | Critical | Backups encrypted at rest; access via IAM with audit log | Low |

### Boundary: API service → Stripe

| ID | Class | Threat | Likelihood | Impact | Mitigation | Residual |
|---|---|---|---|---|---|---|
| T-09 | S | Webhook from spoofed Stripe | High | Critical | Webhook signature verification (`Stripe-Signature` header); reject unsigned | Low |
| T-10 | T | Replay attack on webhook | Medium | High | Idempotency keys + timestamp window check | Low |
| T-11 | R | "I didn't authorize this charge" with no evidence | Medium | High | Audit log: who initiated, when, IP, user-agent, signed; immutable store | Low |

## High-level mitigations adopted

- All requests authenticated unless explicitly marked public.
- Tenant filter auto-applied at the data-access layer.
- Audit log on all sensitive actions (mutations, role changes, exports).
- Rate limit per IP and per user.
- Webhook signature verification.
- Secrets in vault, not in env files.
- TLS 1.2+ enforced; HSTS header.

## Decisions made

| ADR | Decision |
|---|---|
| ADR-0042 | Use UUID v7 for entity IDs (sortable + non-enumerable) |
| ADR-0043 | Audit log to append-only S3 bucket with object lock |
| ADR-0044 | JWT lifetime: 15 min access, 7 day refresh, rotation on every refresh |

## Residual risk

After mitigations:
- T-04 residual MEDIUM: rate limits + CAPTCHA mitigate but not eliminate. Bot operators may pay to bypass CAPTCHAs. Accepted because cost-of-attack vs value-of-account is unfavorable for attacker at our scale; revisit at 10× user base.
- T-08 residual LOW: backups encrypted; key rotation quarterly; IAM minimal access.
- All other threats: residual LOW.

## Open questions

- Vendor SDK X collects data — confirm with their privacy team that GDPR right-to-delete is implementable.
- Plan for handling a stolen JWT (revocation infrastructure) — currently stateless; would need session table to revoke.

## Re-audit triggers

This threat model invalidates if:
- Auth method changes.
- New trust boundary added (new third-party integration).
- New actor type introduced.
- Compliance scope changes (e.g., enter HIPAA scope).
- Major attack class disclosed in vendor's domain.
```

## Phase 5 — Update

- `ai/audits/threat-model-<feature>-<date>.md` — the document.
- `ai/decisions/<NNNN>-*.md` — ADRs for any architectural choice.
- `ai/architecture.md` — update if trust boundaries shifted.
- `ai/_baseline/failures/` — if a threat was realized in past incident, link from here.

## Phase 6 — Validate

- Every documented threat has a mitigation OR an explicit "accepted" with risk justification.
- Every mitigation cites concrete code path / config (not "we have rate limiting").
- ADRs cited exist in `ai/decisions/`.
- Cross-reference to relevant OWASP rules.
- Security-auditor agent reviews + signs off.

## Phase 7 — Improve

- New threat class observed → propose addition to standard STRIDE template.
- Mitigation that worked exceptionally → propose pattern.
- Residual risk that grew unexpectedly → flag for re-modeling.

## Output format

```
## /threat-model — <feature>

Document: ai/audits/threat-model-<feature>-<date>.md
Threats identified: <C critical / H high / M med / L low>
Mitigations adopted: <count>
Residual risks (high+): <count> with explicit acceptance rationale
ADRs created: <list>

Sign-off: @security-auditor
Re-audit triggers: <list>
```

## Hard rules

- **Every threat has a mitigation OR an accepted-risk justification.** No silent omissions.
- **No "we have X" — cite the code/config.** "Auth required" → "controllers use `@RequireAuth()` decorator at line 12."
- **Threat model attached to the feature's PR.** Reviewable by anyone; not buried in a wiki.
- **Re-audit triggers documented.** Threat model goes stale; document when it expires.
- **Compliance overlap captured.** PCI / HIPAA / GDPR-relevant threats flag the regulation.

## Failure modes

- Threat model done after launch. Cost is order-of-magnitude higher to mitigate.
- Mitigations claimed but not actually implemented (rate limit configured at 10 req/sec but the env config is 1000).
- Residual risk "accepted" without authority — the engineer accepted; the user / regulator wouldn't.
- Re-audit triggers vague ("when things change"). Be specific.
- Threats too generic ("attacker might attack"). Be specific to the data-flow leg.

## Related

- `@security-auditor` — sign-off authority.
- `@auth-reviewer` — overlap on auth-specific threats.
- `secret-scan` command — finds the leak class T-08 enables.
- `dependency-vuln-check` command — finds vulnerable deps that introduce new threats.
- OWASP ASVS — formal checklist this informally covers.
