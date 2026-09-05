---
description: Run a structured threat-model session against a feature / system. STRIDE-based; outputs threat list + mitigations + residual risk + decisions.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
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

**The STRIDE letters and their halt conditions live in the `threat-model` skill — apply it, do not restate it.** This command's job starts where the letters end: the skill classifies one boundary; this command decides *which boundaries there are* and makes the result durable.

Per data-flow leg, in this order:

1. **Enumerate the legs first, then classify.** A leg is any hop where data crosses a trust level — edge→service, service→DB, service→third party, queue→consumer, admin console→service. Missing legs is how a threat model reads complete and is not; a leg omitted here can never surface a threat later.
2. **Run the skill's six letters against each leg.** Every letter gets a row, including `none — <why>`. A silently skipped letter is indistinguishable from an unexamined one.
3. **Carry the persona down the leg.** The same letter on the same component is a different threat for an anonymous caller than for an authenticated tenant user — likelihood is a property of the persona, not of the code.
4. **Mark each mitigation EXISTS / PARTIAL / MISSING**, never just "mitigated". EXISTS requires a `<path:line>`; MISSING requires a ticket id. This is what makes Phase 6's cite-or-halt decidable and what `/security-audit` later verifies.

## Phase 3 — Retrieve

- `ai/architecture.md` — trust boundaries, auth model.
- `ai/decisions/` — past ADRs about security choices.
- `ai/failures/` — past security incidents.
- `.claude/rules/security-principles.md` — applicable rules.
- **OWASP ASVS 5.0.0** (released 2025-05-30 — <https://owasp.org/www-project-application-security-verification-standard/>) at the level this feature is held to. Cite the chapter/requirement id you used; "per ASVS" with no id is a hand-wave. Do not cite pre-5.0 chapter numbers from memory — 5.0.0 restructured them.
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

Persona is part of the rating, and Mitigation is EXISTS `<path:line>` / PARTIAL / MISSING `<ticket>` — never bare prose. Phase 6 halts on any row that breaks either.

| ID | Class | Threat (persona) | L × I | Mitigation | Residual |
|---|---|---|---|---|---|
| T-01 | S | Forged request impersonating a user (anon; needs a stolen token) | M × H | EXISTS — signature+exp+iss+aud verified `<auth guard:line>`; refresh rotation `<refresh handler:line>` | Low |
| T-02 | T | Body modified in transit (network-position attacker) | L × M | EXISTS — TLS + HSTS `<ingress config:line>` | Low |
| T-03 | I | User ids enumerated via sequential ints (anon; trivial) | H × M | EXISTS — non-sequential ids `<migration:line>`; per-user scope `<repo:line>` | Low |
| T-04 | D | Login endpoint flooded (anon; trivial) | H × H | PARTIAL — per-IP limit `<rate limit config:line>`; per-account limit MISSING, ticket SEC-31 | Medium |
| T-05 | E | Admin role passed in the request body (authenticated tenant user) | H × C | EXISTS — role read from session `<auth guard:line>`; per-action check `<policy:line>` | Low |

### Boundary: API service → DB

| ID | Class | Threat (persona) | L × I | Mitigation | Residual |
|---|---|---|---|---|---|
| T-06 | T | Injection via a query the ORM does not parameterize — sort column, table/column identifier, `LIMIT` (anon) | M × C | PARTIAL — binds cover values `<repo:line>`; sort/identifier allow-list MISSING, ticket SEC-33 | Medium |
| T-07 | I | Cross-tenant read (authenticated tenant user; one forgotten predicate) | H × C | EXISTS — scope by construction `<base repository:line>` + leak test `<test:line>`. Second DB-enforced layer only where the engine has one — see `tenant-isolation.md § The below-app layer` | Low |
| T-08 | I | Backups readable (insider / misconfigured bucket) | L × C | EXISTS — encrypted at rest + IAM-gated `<IaC module:line>` | Low |

### Boundary: API service → external payment provider

| ID | Class | Threat (persona) | L × I | Mitigation | Residual |
|---|---|---|---|---|---|
| T-09 | S | Spoofed provider webhook (anon; endpoint is public) | H × C | EXISTS — signature verified before parsing `<webhook handler:line>`; unsigned rejected | Low |
| T-10 | T | Webhook replay (anon) | M × H | EXISTS — idempotency key + timestamp window `<webhook handler:line>` | Low |
| T-11 | R | "I didn't authorize this charge", no evidence (customer dispute) | M × H | EXISTS — append-only audit row (actor, time, IP, UA, request id) `<audit emitter:line>` | Low |

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
- `ai/failures/` — if a threat was realized in past incident, link from here.

## Phase 6 — Validate

**Cite-or-halt per threat row: apply the `threat-model` skill's `## Halt conditions` as written there.** They are not restated here on purpose — a second copy drifts, and the three checks (component-path citation, persona-grounded rating, mitigation as `<path:line>`-or-ticket) are the skill's contract, not this command's. Open the skill and run them against every row of the table Phase 4 produced.

This command adds one halt the skill cannot make, because it is a property of the whole document rather than of a row:

- **HALT on a data-flow leg with no rows at all.** Phase 2 enumerated the legs; a leg that produced zero rows was not analysed, and a threat model that silently omits a leg is worse than none — it will be cited as coverage.

Then:
- Every documented threat has a mitigation OR an explicit "accepted" with risk justification.
- Every mitigation cites concrete code path / config (not "we have rate limiting").
- ADRs cited exist in `ai/decisions/`.
- Cross-reference to relevant OWASP rules.
- **No agent sign-off is claimed here.** `/threat-model` produces the threat list + mitigation plan — it does not itself run the `security-auditor` agent, so it cannot assert that agent's verdict. Enforcement is the follow-up `/security-audit` run against the implemented mitigations; that command dispatches `security-auditor` (+ specialists) and emits the recorded GO/NO-GO. A threat model whose mitigations have not yet been through `/security-audit` is planned, not verified.

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

Enforcement: threat list produced — mitigations NOT yet verified. Run `/security-audit` against the implemented mitigations for the recorded GO/NO-GO (this command does not run the security-auditor agent).
Re-audit triggers: <list>
```

## Hard rules

- **Every threat has a mitigation OR an accepted-risk justification.** No silent omissions.
- **No "we have X" — cite the code/config.** "Auth required" → "controllers use `@RequireAuth()` decorator at line 12."
- **Threat model attached to the feature's PR.** Reviewable by anyone; not buried in a wiki.
- **Re-audit triggers documented.** Threat model goes stale; document when it expires.
- **Compliance overlap captured.** PCI / HIPAA / GDPR-relevant threats flag the regulation.

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the threats re-expressed as ONE ordered, numbered to-do — **MUST FIX** (high-likelihood × high-impact, unmitigated) → **SHOULD FIX** (medium risk) → **OPTIONAL** (low / accepted-with-note) — each step carrying the threat + the affected `<file:line>`/surface + **Fix** (the concrete mitigation) + **Verify** (the test/config that proves the mitigation is real, not just claimed), then the closing steps (re-run `/threat-model` after mitigations, `/learn-from-task`, then ship). A clean run collapses to a single line ("No unmitigated threats — clear to proceed"). The reader must never assemble the next steps themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Threat model done after launch. Cost is order-of-magnitude higher to mitigate.
- Mitigations claimed but not actually implemented (rate limit configured at 10 req/sec but the env config is 1000).
- Residual risk "accepted" without authority — the engineer accepted; the user / regulator wouldn't.
- Re-audit triggers vague ("when things change"). Be specific.
- Threats too generic ("attacker might attack"). Be specific to the data-flow leg.

## Related

- `threat-model` **skill** — the primitive this command applies: the six STRIDE letters, the LINDDUN privacy pass, and the three cite-or-halt conditions Phase 6 enforces. Agents dispatch the skill directly; this command is the session that makes its output durable (actor table, ADRs, residual risk, re-audit triggers).
- `@security-auditor` — the enforcement agent, dispatched by the follow-up `/security-audit` (not by this command); its recorded verdict is what verifies the mitigations this model plans.
- `@auth-reviewer` — overlap on auth-specific threats.
- `/secret-scan` — finds the leaked-credential class this model assumes away.
- `/dependency-vuln-check` — finds vulnerable deps that introduce new threats.
- **OWASP ASVS 5.0.0** — the formal requirement catalogue this session cites by requirement id: <https://owasp.org/www-project-application-security-verification-standard/>.
