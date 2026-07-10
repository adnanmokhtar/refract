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

If description suggests a different intent, halt with redirect: "fix the auth bug" → `/fix-bug` (specific bug, not audit). "rotate secrets / credentials" → operational, not audit. "add auth gate" → `/add-feature` or `/add-endpoint`. Proceed for: full OWASP pass, scoped review, or staged-changes security review.

### Standard inputs

- Determine diff scope:
  ```bash
  git fetch origin
  git diff --name-only "origin/${BASE:-main}"...HEAD
  ```
- No diff → scan whole repo (longer, flag this to user before starting).
- Confirm intent: full OWASP pass, or scoped to detected sensitive areas.

## Phase 2 — Organize

The broad `security-auditor` pass is the OWASP-Top-10 net; the specialist reviewers below own deep detectors that pass does not. Route mechanically — name the grep signal on the changed surface → dispatch the reviewer that owns it. Each dispatched reviewer's verdict feeds the Phase 4 GO/NO-GO.

- Dispatch plan:
  - Always: `security-auditor` (OWASP Top 10 + Top 25 CWE).
  - If diff touches `auth/`, `session`, `jwt`, `password`, `oauth`, `2fa` → `auth-reviewer`.
  - If multi-tenant (detect via tenant-id columns / a request-scoped tenant context primitive / a tenant header) → `tenant-isolation-reviewer`.
  - **API surface** — if the diff adds/changes an API route, serializer/DTO, controller/handler, or GraphQL resolver (signal: files under `routes/`/`controllers/`/`resolvers/`/`serializers/`, or `@Get`/`@Post`/`router.<verb>`/`app.<verb>`/`type Query`/`type Mutation`/`class .*Serializer`) → dispatch `api-security-reviewer` (OWASP API Top 10 — BOLA/IDOR, BOPLA / mass-assignment + excessive data exposure, function-level authz, SSRF).
  - **PII / privacy surface** — if the diff touches a PII-collection form, a logger call, an analytics/marketing SDK, or a delete/export/DSAR path (signal: `email`/`phone`/`address`/`dob`/`ssn`/`national_id` bound in a form or model, `logger.<level>(` carrying user fields, an analytics SDK import — `segment`/`amplitude`/`mixpanel`/`gtag`/`fbq` — or a `delete`/`export`/`erasure`/`dsar` route/handler) → dispatch `data-privacy-reviewer` (PII data-flow: collection → store → log → analytics → third-party egress; erasure/DSAR reachability; consent gates; cross-border transfer).
  - **LLM / AI surface** — if the diff touches a prompt template, an LLM/tool-call, a RAG/embedding retrieval, or a model-output sink (signal: a prompt string / system-prompt constant, an SDK call — `anthropic`/`openai`/`chat.completions`/`messages.create`/`generateText`/`invoke_model` — a tool/function-calling definition, a vector-store/`embeddings`/retrieval call, or model output flowing into exec/eval/SQL/HTML/a shell) → dispatch `llm-security-reviewer` (prompt injection direct + indirect, improper output handling, excessive agency, RAG/embedding weaknesses).
  - If diff touches infra (container build files, K8s manifests, IaC modules) → container/runtime hardening cross-check.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Security-specific:
- `.claude/rules/multi-tenancy.md`, `.claude/rules/auth.md`, `.claude/rules/secrets.md` (whichever apply).
- `ai/patterns/auth-flow.md`, `ai/patterns/tenant-isolation.md`, `ai/patterns/zero-trust.md` (signal-driven). Payment-flow integrity is owned by the backend/domain pack, not security — dispatch there when a payment signal fires.
- Recent `ai/audits/<date>-security.md` — repeated findings = systemic issue.
- Any threat model doc.

## Phase 4 — Generate (findings + verdict)
- Run all dispatched reviewers in parallel.
- Consolidate into 3 buckets:
  - BLOCKERS — auth bypass, secret leak, injection, cross-tenant read, RCE.
  - REQUESTS — fixable in this PR but non-blocker (rate-limit gap, weaker cookie attr).
  - NITS — style / hygiene.

### Mitigation-Verification Gate (production-grade or GO-UNVERIFIED — do not skip)

A clean `GO` is the claim "this surface is production-grade", not "I found no obvious hole". Before emitting GO, this gate runs — it DEEPENS the reviewers' probe discipline into the verdict and is enforced by a **required output artifact**, not a claim:

- **Production bar (name the unmet items, never assume).** Consolidate each dispatched reviewer's production-bar block: (1) **threat-class coverage** — every sensitive surface the diff touches is mapped to a real class (authz/IDOR, injection, SSRF, secret exposure, deserialization, tenant isolation); an unmapped surface is a `COVERAGE:` gap. (2) **defense-in-depth** — each critical control has ≥2 independent layers; a single point is a `DEPTH:` finding (REQUEST min). (3) **least-privilege** — no wildcard scope / admin-by-default / any-host egress / `SELECT *` over PII / over-long TTL; an over-grant is a `LEASTPRIV:` finding.
- **Mitigation verification (probe-or-UNVERIFIED).** Every control the GO depends on carries an Evidence token — a **Probe** (curl/crafted input + observed denied/sanitized response), a named **Test** result, or a **Traced enforcement** `<file:line>` from untrusted entry to sink. A control read-but-not-exercised, or one whose probe harness is absent, is **UNVERIFIED / SKIPPED** — never a checkmark. Count the UNVERIFIED controls.
- **Verdict (three states, not two):**
  - **NO-GO** — any blocker in any dispatched reviewer's output.
  - **GO-UNVERIFIED (N unproven)** — no blocker, but ≥1 production-bar gap unresolved OR ≥1 GO-critical control still UNVERIFIED/SKIPPED. Lists each unmet item; the caller must prove or explicitly accept each before ship. A GO-UNVERIFIED is NOT a GO.
  - **GO** — no blocker, all three production dimensions clear, 0 UNVERIFIED GO-critical controls.
  - A reviewer that was dispatched but whose result is missing = incomplete audit, forces at least GO-UNVERIFIED, never a clean GO.
- **Wiring [required artifact + self-policed]:** the mechanical half is the **Mitigation Verification table + production-bar block** this run MUST write into `ai/audits/<date>-security.md` (Phase 5) — a reader checks it exists, every row carries Evidence-or-UNVERIFIED, and the verdict state matches the UNVERIFIED count. No shell confirms a probe actually ran; the operator/agent self-polices the truth of each Evidence token. A clean `GO` printed without that table in the artifact is a defective run.
- Print (shape, not literal paths):
  ```
  Security audit  base=origin/main  files=24

  Blockers (2):
    - <admin/export route file:line>  No auth guard on privileged endpoint — tier-1 data exposure
    - <payments client file:line>  Logs full card token (PCI scope leak)
  Requests (3):
    - SQL string concatenation in <repo file> — switch to parameter binding
    - Rate limiter not applied to login route
    - Session cookie missing SameSite=Strict
  Nits (4): ...

  Production bar:
    Coverage:      /export mapped→A01, /webhook mapped→A08 — all surfaces mapped
    Depth:         DEPTH single-point — auth on /export is route-guard only, no server-side ownership check
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
- This command is a read-only audit — it does not persist a blocker ledger or wire a gate. The discipline below is a procedure the operator follows, not an automated check.
- After the developer fixes blockers, re-run `/security-audit` against the patched code.
- To confirm closure, list each first-pass blocker by its `<file:line>` and re-run the same detection on the patched lines; a blocker is closed only when it no longer reproduces there. Treat the prior audit report in `ai/audits/<date>-security.md` as the checklist for this second pass.
- This mirrors `find-and-fix § 3.5 RE-DETECT` in the migration pack as a workflow, not a wired gate.
- If any first-pass blocker still reproduces on re-audit → verdict stays NO-GO; do not advance.

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-security.md` — append timestamped report. **MUST include the production-bar block (coverage / depth / least-priv) AND the Mitigation Verification table (one row per GO-critical control, each with an Evidence token or UNVERIFIED/SKIPPED) — this is the checkable artifact the Mitigation-Verification Gate is wired to. A report emitting `GO` without this table present, or with a row lacking both Evidence and an UNVERIFIED mark, is a defective run to be re-done, not accepted.**
- `ai/dynamic/changelog.md` — one-line: `Security audit on <scope>: B blockers, R requests, verdict <GO|NO-GO>`.
- If blockers found → `ai/status.md` `## Recent Changes` bullet (visible across sessions).

## Phase 6 — Validate
- Each blocker has a concrete remediation (not just a finding).
- No fabricated findings — say "no blockers" plainly when clean.
- **Verdict integrity:** a clean `GO` is emitted ONLY when (a) no blocker, (b) all three production dimensions clear with no `COVERAGE:`/`DEPTH:`/`LEASTPRIV:` gap left open, and (c) 0 GO-critical controls UNVERIFIED. Any open item forces `GO-UNVERIFIED (N)` with the items named. An asserted mitigation ("auth guard is there") with no probe / test / traced enforcement is UNVERIFIED, not a pass — the defense side owes the same evidence a blocker owes.
- Cross-tenant reads via raw SQL specifically scanned (the project's raw-query / query-builder escape hatches) even on clean-looking files.
- Linter / SAST suppression comments that disable security rules (any language's `disable`/`ignore` pragma applied to a security check) surfaced as blockers.

## Phase 7 — Improve
- `/learn-from-task` — capture each blocker class.
- If same auth bypass class found 2+ audits → queue ADR: enforce the project's auth guard primitive on every route uniformly.
- If tenant leak in raw SQL recurs → queue lint / static-analysis rule + base-class refactor.
- If secret-in-log recurs → queue logger-level redaction enforcement.
- **Pattern-escalation enforcement:** if a finding's pattern has appeared ≥2 times across audits (check prior `ai/audits/<date>-security.md` reports), promote to `ai/decisions/` as an ADR proposal AND open a lint / static-analysis rule task in the project's stack-native linter. Patterns that repeat without escalation are themselves a finding (log under Phase 4 REQUESTS as `META: pattern X recurred N times, no ADR/lint rule filed`).

## Output format
```
## /security-audit — verdict <GO | GO-UNVERIFIED (N) | NO-GO>

Phase 1 (Understand): scope = <diff | full repo>; sensitive areas = <auth|payments|tenant|infra>
Phase 3 (Retrieved): rules + patterns by signal; prior audits scanned
Phase 4 (Generated): findings table + production bar + mitigation-verification table (above)
Phase 5 (Updated): ai/audits/<date>-security.md (incl. verification table), changelog, status.md
Phase 6 (Validated): blockers have remediation; production bar clear or gaps named; 0 UNVERIFIED for a clean GO; raw SQL scanned; eslint-disables surfaced
Phase 7 (Improved): N systemic patterns queued

Status: COMPLETE (GO) | UNVERIFIED on <N> unproven mitigations | BLOCKED on <B> blockers
```

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (critical + high / blockers) → **SHOULD FIX** (medium) → **OPTIONAL** (low / hardening) — each step carrying `<file:line>` + **Fix** (concrete) + **Verify**, then the closing steps (re-run `/security-audit` to confirm it comes back clean, `/learn-from-task`, then ship). On a `GO-UNVERIFIED` verdict, the MUST-FIX list ALSO carries a **PROVE** section — each UNVERIFIED / SKIPPED GO-critical control named with the exact probe or test to run (or the harness to stand up) that would upgrade it to VERIFIED; the verdict cannot become a clean GO until each is proven or explicitly accepted with rationale. A clean run collapses to a single line ("No findings — clear to proceed"). The reader must never assemble the next steps themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes
- **Asserted mitigation counted as a pass** → the #1 false-GO: "auth guard is there / tenant filter is applied / SSRF is blocked" claimed from a decorator seen or a middleware assumed, with no probe, test, or traced enforcement. A read control is UNVERIFIED, not VERIFIED — the verdict is GO-UNVERIFIED until proven.
- **Clean GO on a merely-functional surface** → single-layer control, an unmapped sensitive surface, or a wildcard/admin-by-default grant left unexamined. "No obvious bug" is the floor; the production bar (coverage · depth · least-priv) is the ceiling — clear it or name the gap.
- Auth + payment + secret findings deferred to "follow-up PR" → forbidden; always blockers.
- Fabricated findings to look thorough → say "no blockers" plainly when clean.
- Linters/SAST missing business-logic flaws (privilege escalation, IDOR) → agent review catches those; don't substitute one for the other.
- Lint / static-analysis suppression comments on security rules hidden → blockers; agent must surface.
- Raw SQL paths skipped because they "look fine" → #1 false-clean; explicitly scan the project's raw-query / query-builder escape hatches.
- Whole-repo scan launched without warning user → can run hours; flag before starting.

## Related

### Reviewers (dispatched by signal in Phase 2)
- `@security-auditor` — always; broad OWASP Top 10 + Top 25 CWE net.
- `@auth-reviewer` — auth / session / jwt / oauth / 2fa surface.
- `@tenant-isolation-reviewer` — multi-tenant boundary surface.
- `@api-security-reviewer` — API route / serializer / controller / resolver surface (OWASP API Top 10, BOLA/BOPLA).
- `@data-privacy-reviewer` — PII form / logger / analytics SDK / delete-or-export surface (PII flow, erasure reachability, cross-border).
- `@llm-security-reviewer` — prompt / tool-call / RAG / model-output-sink surface (prompt injection, output handling, excessive agency).

### Patterns
- `ai/patterns/auth-flow.md`
- `ai/patterns/zero-trust.md`

### Rules
- `.claude/rules/security-principles.md`
