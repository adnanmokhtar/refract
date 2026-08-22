---
description: Security audit — OWASP pass via security-auditor, plus auth + tenant reviews if relevant. Three-state verdict (GO / GO-UNVERIFIED / NO-GO) gated on probe-verified mitigations, not asserted ones.
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

### Intent gate

If the description suggests a different intent, halt with a redirect: "fix the auth bug" → `/fix-bug`; "rotate secrets / credentials" → operational, not audit; "add auth gate" → `/add-feature`. Proceed for: full OWASP pass, scoped review, or staged-changes security review.

### Standard inputs
- Determine diff scope:
  ```bash
  git fetch origin
  git diff --name-only "origin/${BASE:-main}"...HEAD
  ```
- No diff → scan whole repo (longer, flag this to user before starting).
- Confirm intent: full OWASP pass, or scoped to detected sensitive areas.

## Phase 2 — Organize

Route mechanically — name the grep signal on the changed surface, dispatch the owner. Each dispatched reviewer's verdict feeds the Phase 4 GO/NO-GO.

- Reviewers:
  - Always: `security-auditor` (OWASP Top 10 + Top 25 CWE).
  - `auth/`, `session`, `jwt`, `password`, `oauth`, `2fa` → `auth-reviewer`.
  - Multi-tenant (tenant-id columns / a request-scoped tenant context / a tenant header) → `tenant-isolation-reviewer`.
  - API route, serializer/DTO, controller/handler, GraphQL resolver → `api-security-reviewer` (OWASP API Top 10 — BOLA/IDOR, BOPLA/mass-assignment, function-level authz).
  - PII form, logger call carrying user fields, analytics SDK, delete/export/DSAR path → `data-privacy-reviewer` (PII flow, erasure reachability, consent, cross-border).
  - Prompt template, LLM/tool call, RAG/embedding retrieval, model-output sink → `llm-security-reviewer`.
  - Infra (container build files, K8s manifests, IaC modules) → container/runtime hardening cross-check.

- **Skills — detectors, not reviewers; they produce cited findings that feed Phase 4.** Phase 4's buckets promise secret, dependency and SSRF coverage; without these, nothing executes that promise and the promise is itself a `COVERAGE:` gap.
  - `secret-scan` — config / env / IaC / CI / client-bundle diffs, and always on a whole-repo run. Findings are BLOCKERS by default.
  - `deps-audit` — manifest or lockfile diffs; supplies advisory ids + reachability.
  - `ssrf-scan` — new outbound fetch / webhook / URL-import sink, or a redirect target read from input.
  - A skill triggered and not run forces at least `GO-UNVERIFIED`, exactly like a reviewer dispatched and not run.
  - **Run each skill once.** `security-auditor` also names these as the executors behind its own A0x rows; this dispatch guarantees they run on the diff's signal even when no auditor row fires. Consume an existing result rather than re-scanning.

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
- `ai/patterns/auth-flow.md`, `ai/patterns/tenant-isolation.md`, `ai/patterns/zero-trust.md` (signal-driven). Payment-flow integrity is owned by the backend/domain pack, not security.
- Recent `ai/audits/<date>-security.md` — repeated findings = systemic issue.
- Any threat model doc.

## Phase 4 — Generate (findings + verdict)
- Run all dispatched reviewers in parallel.
- Consolidate into 3 buckets:
  - BLOCKERS — auth bypass, secret leak, injection, cross-tenant read, RCE.
  - REQUESTS — fixable in this PR but non-blocker (rate-limit gap, weaker cookie attr).
  - NITS — style / hygiene.

### Mitigation-Verification Gate (production-grade or GO-UNVERIFIED — do not skip)

A clean `GO` is the claim "this surface is production-grade", not "I found no obvious hole". Before emitting GO, this gate runs — enforced by a **required output artifact**, not a claim:

- **Production bar (name the unmet items, never assume).** (1) **threat-class coverage** — every sensitive surface the diff touches is mapped to a real class (authz/IDOR, injection, SSRF, secret exposure, deserialization, tenant isolation); an unmapped surface is a `COVERAGE:` gap. (2) **defense-in-depth** — each critical control has ≥2 independent layers; a single point is a `DEPTH:` finding (REQUEST min). **Engine/platform-conditional:** a second layer the platform cannot provide is not a `DEPTH:` gap — record the capability (`below-app layer: unavailable (<engine>)`, per `tenant-isolation.md § The below-app layer`) and re-aim the finding at what the remaining layer must guarantee. A gap no fix can close is a permanent NO-GO, which is how a verdict stops being read. (3) **least-privilege** — no wildcard scope / admin-by-default / any-host egress / `SELECT *` over PII / over-long TTL; an over-grant is a `LEASTPRIV:` finding.
- **Mitigation verification (probe-or-UNVERIFIED).** Every control the GO depends on carries an Evidence token — a **Probe** (crafted input + observed denied/sanitized response), a named **Test** result, or a **Traced enforcement** `<file:line>` from untrusted entry to sink. A control read-but-not-exercised, or one whose probe harness is absent, is **UNVERIFIED / SKIPPED** — never a checkmark. Count the UNVERIFIED controls.
- **Verdict (three states, not two):**
  - **NO-GO** — any blocker in any dispatched reviewer's output.
  - **GO-UNVERIFIED (N unproven)** — no blocker, but ≥1 production-bar gap open OR ≥1 GO-critical control still UNVERIFIED/SKIPPED. Each unmet item is listed; the caller proves or explicitly accepts each before ship. A GO-UNVERIFIED is NOT a GO.
  - **GO** — no blocker, all three production dimensions clear, 0 UNVERIFIED GO-critical controls.
  - A reviewer that was dispatched but whose result is missing = incomplete audit → at least GO-UNVERIFIED, never a clean GO.
- **Wiring [required artifact + self-policed]:** the mechanical half is the **Mitigation Verification table + production-bar block** this run MUST write into `ai/audits/<date>-security.md` (Phase 5). A clean `GO` printed without that table in the artifact is a defective run.

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

  Production bar:
    Coverage:      /export mapped→A01, /webhook mapped→A08 — all surfaces mapped
    Depth:         DEPTH single-point — auth on /export is route-guard only, no ownership check
    Least-priv:    LEASTPRIV — service token carries wildcard scope; flow needs read:reports only

  Mitigation verification (GO-critical):
    | Control                    | Evidence            | Status     |
    | tenant filter on list qry  | Test: A reads B→403 | VERIFIED   |
    | webhook HMAC check         | (no staging replay) | UNVERIFIED |
    Unverified: 1

  Verdict: NO-GO. 2 blockers must be fixed and re-audited before merge.
  ```
  (Had the 2 blockers been absent, the UNVERIFIED webhook check + the DEPTH/LEASTPRIV gaps would still make this `GO-UNVERIFIED (3 unmet)`, not a clean GO.)

### RE-DETECT (re-run discipline)
- This command is a read-only audit — the discipline below is a procedure the operator follows, not an automated check.
- After the developer fixes blockers, re-run `/security-audit` against the patched code; list each first-pass blocker by `<file:line>` and re-run the same detection there. A blocker is closed only when it no longer reproduces.
- If any first-pass blocker still reproduces on re-audit → verdict stays NO-GO; do not advance.

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-security.md` — append timestamped report. **MUST include the production-bar block (coverage / depth / least-priv) AND the Mitigation Verification table (one row per GO-critical control, each with an Evidence token or UNVERIFIED/SKIPPED)** — this is the checkable artifact the gate is wired to. A report emitting `GO` without it is a defective run.
- `ai/dynamic/changelog.md` — one-line: `Security audit on <scope>: B blockers, R requests, verdict <GO|GO-UNVERIFIED|NO-GO>`.
- If blockers found → `ai/status.md` `## Recent Changes` bullet (visible across sessions).

## Phase 6 — Validate
- Each blocker has a concrete remediation (not just a finding).
- No fabricated findings — say "no blockers" plainly when clean.
- **Verdict integrity:** a clean `GO` is emitted ONLY when (a) no blocker, (b) all three production dimensions clear with no `COVERAGE:`/`DEPTH:`/`LEASTPRIV:` gap open, and (c) 0 GO-critical controls UNVERIFIED. Any open item forces `GO-UNVERIFIED (N)` with the items named. An asserted mitigation ("auth guard is there") with no probe / test / traced enforcement is UNVERIFIED, not a pass.
- Cross-tenant reads via raw SQL specifically scanned — the project's own raw-query / query-builder escape hatches — even on clean-looking files.
- **Interpolation that parameter binding cannot cover** specifically scanned: sort direction/column, table/column identifiers and `LIMIT`/`OFFSET` are not bindable in most drivers, so an otherwise fully parameterized codebase still concatenates them. The control is an allow-list of permitted identifiers, not an escape function.
- **File-serving paths specifically scanned** for traversal: the store side is the backend `file-upload` contract; the *read* side (`?file=` / `?name=` / a path segment resolved against a directory) is a separate sink. Resolve, then assert the resolved path is inside the intended root.
- Lint / static-analysis suppression pragmas applied to a security rule (any language) surfaced as blockers.

## Phase 7 — Improve
- `/learn-from-task` — capture each blocker class.
- If the same auth-bypass class is found in 2+ audits → queue an ADR: enforce the project's auth guard primitive on every route uniformly.
- If tenant leak in raw SQL recurs → queue lint rule + base-class refactor.
- If secret-in-log recurs → queue logger-level redaction enforcement.
- **Pattern-escalation enforcement:** if a finding's pattern has appeared ≥2 times across audits, promote it to an ADR proposal AND open a lint / static-analysis rule task. Patterns that repeat without escalation are themselves a finding (`META: pattern X recurred N times, no ADR/lint rule filed`).

## Output format
```
## /security-audit — verdict <GO | GO-UNVERIFIED (N) | NO-GO>

Phase 1 (Understand): scope = <diff | full repo>; sensitive areas = <auth|payments|tenant|infra>
Phase 3 (Retrieved): rules + patterns by signal; prior audits scanned
Phase 4 (Generated): findings table + production bar + mitigation-verification table (above)
Phase 5 (Updated): ai/audits/<date>-security.md (incl. verification table), changelog, status.md
Phase 6 (Validated): blockers have remediation; production bar clear or gaps named; 0 UNVERIFIED for a clean GO; raw SQL scanned; suppression pragmas surfaced
Phase 7 (Improved): N systemic patterns queued

Status: COMPLETE (GO) | UNVERIFIED on <N> unproven mitigations | BLOCKED on <B> blockers
```

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (blockers) → **SHOULD FIX** (medium) → **OPTIONAL** (hardening) — each step carrying `<file:line>` + **Fix** (concrete) + **Verify**, then the closing steps. On a `GO-UNVERIFIED` verdict the MUST-FIX list ALSO carries a **PROVE** section — each UNVERIFIED / SKIPPED GO-critical control named with the exact probe or test that would upgrade it to VERIFIED. A clean run collapses to a single line ("No findings — clear to proceed").

## Failure modes
- Auth + payment + secret findings deferred to "follow-up PR" → forbidden; always blockers.
- Fabricated findings to look thorough → say "no blockers" plainly when clean.
- Linters/SAST missing business-logic flaws (privilege escalation, IDOR) → agent review catches those; don't substitute one for the other.
- Lint / static-analysis suppression pragmas on security rules hidden → blockers; the agent must surface them.
- Raw SQL paths skipped because they "look fine" → #1 false-clean; explicitly scan the project's raw-query / query-builder escape hatches.
- Whole-repo scan launched without warning user → can run hours; flag before starting.

## Related

**Reviewers** (Phase 2, by signal): `@security-auditor` (always) · `@auth-reviewer` · `@tenant-isolation-reviewer` · `@api-security-reviewer` · `@data-privacy-reviewer` · `@llm-security-reviewer`.
**Skills** (Phase 2, the executors behind Phase 4's buckets): `secret-scan` · `deps-audit` · `ssrf-scan`.
**Patterns**: `ai/patterns/auth-flow.md` · `ai/patterns/tenant-isolation.md` · `ai/patterns/zero-trust.md`.
**Rules**: `.claude/rules/security-principles.md`.
