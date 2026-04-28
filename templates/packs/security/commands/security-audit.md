---
description: Security audit — OWASP pass via security-auditor, plus auth + tenant reviews if relevant. GO/NO-GO verdict.
---

# /security-audit [base-branch]

Audit command. Multi-agent security review of the diff (or whole repo). Phases 1-3 + 6 dominate; Phase 4 produces ranked findings; Phase 5 logs the audit; Phase 7 surfaces systemic patterns.

## When to use / NOT to use
- USE: before shipping anything touching auth, payments, secrets, or PII.
- USE: before opening a PR to main on a security-sensitive feature.
- USE: as a follow-up if `/endpoint-test` flagged a tenant leak.
- NOT: pure formatting / lint-only PRs.
- NOT: as the only security check — pair with SAST tools and human review on sensitive paths.

## Phase 1 — Understand
- Determine diff scope:
  ```bash
  git fetch origin
  git diff --name-only "origin/${BASE:-main}"...HEAD
  ```
- No diff → scan whole repo (longer, flag this to user before starting).
- Confirm intent: full OWASP pass, or scoped to detected sensitive areas.

## Phase 2 — Organize
- Dispatch plan:
  - Always: `security-auditor` (OWASP Top 10 + Top 25 CWE).
  - If diff touches `auth/`, `session`, `jwt`, `password`, `oauth`, `2fa` → `auth-reviewer`.
  - If multi-tenant (detect via `tenantId` columns / `Context` service / `X-Tenant` header) → tenant-isolation pass.
  - If diff touches infra (`Dockerfile`, `k8s/`, `terraform/`) → container/runtime hardening cross-check.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Security-specific:
- `.claude/rules/multi-tenancy.md`, `.claude/rules/auth.md`, `.claude/rules/secrets.md` (whichever apply).
- `ai/patterns/auth-flow.md`, `ai/patterns/tenant-isolation.md`, `ai/patterns/payment-integration.md` (signal-driven).
- Recent `ai/audits/<date>-security.md` — repeated findings = systemic issue.
- Any threat model doc.

## Phase 4 — Generate (findings + verdict)
- Run all dispatched reviewers in parallel.
- Consolidate into 3 buckets:
  - BLOCKERS — auth bypass, secret leak, injection, cross-tenant read, RCE.
  - REQUESTS — fixable in this PR but non-blocker (rate-limit gap, weaker cookie attr).
  - NITS — style / hygiene.
- Verdict: NO-GO if ANY blocker exists; otherwise GO.
- Print:
  ```
  Security audit  base=origin/main  files=24

  Blockers (2):
    - apps/api/src/admin/export.controller.ts:18  No auth guard on GET /admin/export — tier-1 data exposure
    - libs/payments/src/stripe.service.ts:142  Logs full card token (PCI scope leak)
  Requests (3):
    - SQL string concat in OrderRepo.searchByName — switch to parameterized query
    - Rate limiter not applied to /auth/login
    - Cookie missing SameSite=Strict on session
  Nits (4): ...
  Verdict: NO-GO. 2 blockers must be fixed and re-audited before merge.
  ```

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-security.md` — append timestamped report.
- `ai/dynamic/changelog.md` — one-line: `Security audit on <scope>: B blockers, R requests, verdict <GO|NO-GO>`.
- If blockers found → `ai/status.md` `## Recent Changes` bullet (visible across sessions).

## Phase 6 — Validate
- Each blocker has a concrete remediation (not just a finding).
- No fabricated findings — say "no blockers" plainly when clean.
- Cross-tenant reads via raw SQL specifically scanned (`getRepository().createQueryBuilder()`, `datasource.query`) even on clean-looking files.
- `eslint-disable security/*` comments surfaced as blockers.

## Phase 7 — Improve
- `/learn-from-task` — capture each blocker class.
- If same auth bypass class found 2+ audits → queue ADR: enforce guard via decorator on every controller.
- If tenant leak in raw SQL recurs → queue lint rule + base-class refactor.
- If secret-in-log recurs → queue logger-level redaction enforcement.

## Output format
```
## /security-audit — verdict <GO | NO-GO>

Phase 1 (Understand): scope = <diff | full repo>; sensitive areas = <auth|payments|tenant|infra>
Phase 3 (Retrieved): rules + patterns by signal; prior audits scanned
Phase 4 (Generated): findings table (above)
Phase 5 (Updated): ai/audits/<date>-security.md, changelog, status.md
Phase 6 (Validated): blockers have remediation; raw SQL scanned; eslint-disables surfaced
Phase 7 (Improved): N systemic patterns queued

Status: COMPLETE | BLOCKED on <B> blockers
```

## Failure modes
- Auth + payment + secret findings deferred to "follow-up PR" → forbidden; always blockers.
- Fabricated findings to look thorough → say "no blockers" plainly when clean.
- Linters/SAST missing business-logic flaws (privilege escalation, IDOR) → agent review catches those; don't substitute one for the other.
- `eslint-disable security/*` comments hidden → blockers; agent must surface.
- Raw SQL paths skipped because they "look fine" → #1 false-clean; explicitly scan `createQueryBuilder` + `datasource.query`.
- Whole-repo scan launched without warning user → can run hours; flag before starting.

## Related

### Patterns
- `ai/patterns/auth-flow.md`
- `ai/patterns/zero-trust.md`

### Rules
- `.claude/rules/security-principles.md`
