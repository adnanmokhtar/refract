# Align discipline — examples & anti-pattern catalogue

> Companion to `.claude/rules/align-discipline.md` (the always-loaded core). Loaded on demand during audits and reviews — NOT auto-loaded into every session.
> Rule-only tools: ships alongside the core rule in your adapter bundle.
> First relocated from the core rule on 2026-06-07; rewritten 2026-10-18 for declared-convention enforcement (AL ids, EQ / VC / FN, owner routing).

## Examples per concern

### The oracle — declared, not counted

```text
# ❌ A majority promoted to a rule
Candidate: 38 of 40 hooks return a tuple; useOrders.ts returns an object.
Closure: rewrite useOrders to return a tuple.

→ No lint rule, no human-written line, no ADR says hooks return tuples. 95% is a census, not a convention.
→ AL-02: the BIMODAL block prints "proposed canonical: tuple (38/40) — ratify?". 0 ledger rows.
→ A human writes the line in ai/conventions.md (outside the generated markers); the next scan enforces it.

# ✅ A declared convention
Candidate: apps/web/src/features/orders/api.ts:1  import ky from 'ky'
Oracle:    eslint.config.mjs:29  no-restricted-imports  "ky → use @acme/http"   (T1, error, CI lints apps/web)

→ AL-11. The quote resolves (AL-01 passes). Closure: replace-with-shared → apiClient from @acme/http.

# ❌ A generated line enforced
Oracle: ai/conventions.md:92 (inside <!-- refine-enriched --> markers) "Hooks live in camelCase files."
→ T2g. Its sites are one ratification line ("confirm ai/conventions.md:92 — unlocks 3 sites"), status pending-ratification.
```

### Behaviour preservation — EQ, VC, FN

```text
# ✅ EQ — exact
AL-05 apps/web/src/features/invoices/components/InvoiceStatusBadge.tsx:13  color: '#d92d20'
token-map.py --lookup=#d92d20 --prop=color --site=<file>  →  EXACT --color-danger eq=yes (light + dark)
→ replace-with-shared → var(--color-danger). Proof: zero computed-style diff per theme (V394), or (static EQ) with the probe.

# ❌ "Close enough" committed as EQ
AL-06 InvoiceTotals.tsx:8  padding: '13px'
token-map.py  →  NEAREST --space-3=12px (1px), xfam=--font-size-sm
→ Snapping changes pixels. VC: a visual diff at maxDiffPixels 0 and approval: <name>@<iso> by a human, or /polish.
→ The agent never writes approval:, and never re-records a snapshot to make the swap "pass" (halt #7).

# ✅ FN — a declared idiom added
AL-15 InvoiceActions.tsx:29  <Button variant="danger" onClick={deleteInvoice}> outside <Can action="invoices.delete">
Oracle: ai/conventions.md:27 "Destructive actions render inside <Can>."  (T2)
→ add-gate with the declared <Can>. Proof: a render test as a role without invoices.delete, failing first (V401). Tier heavy.
```

### Scope discipline

```text
# ❌ Mission creep
Phase 1 PR title: "Phase 1: raw imports + renames + token swaps + suppressions + a reordered import block"
→ Five classes and an untouched-function edit in one phase. The reordered imports are AL-34 (out-of-scope edit);
  the line-level scope check fails the row. Reviewer can't tell which class caused which delta.

# ✅ Atomic phases
Phase 1: regressions and suppressions (AL-30, AL-29; 6 rows).
Phase 2: imports through the declared wrapper (AL-11, AL-14, AL-22; 12 rows, all replace-with-shared).
Phase 3: auth pages — EQ token, element and key swaps (AL-05, AL-12, AL-26; 10 rows).
Phase 4: names and layout (AL-16, AL-17, AL-19; 9 rows, all rename).
```

### One way per pattern

```text
# ❌ The Two-Way Swap
A021  CreditNoteForm.tsx:38       '#d92d20' → var(--color-danger)
A024  admin/ErrorBanner.vue:7 '#d92d20' → var(--color-error)
→ Each hunk is right alone. align-sweep-gate.py consistency: one before-key, two afters → FAIL (AL-33).
→ Pick the token the oracle's role column names; revert the other row and re-run it.
```

### Reuse-before-create

```text
# ❌ Reinvented Wrapper (an alignment fix that itself reinvents)
AL-13: apps/web/src/features/cart/helpers.ts:2 defines formatMoney(amount)
Closure: extract to apps/web/src/lib/money.ts, import it in cart

→ packages/format already exports formatMoney, and the oracle names it. The "extract" is a new symbol (halt #9).

# ✅ Dedupe onto the named helper
AL-13: same site
Proof first: a differential test runs the copy and @acme/format's formatMoney on the copy's call-site inputs → equal (V403).
Closure: dedupe — delete the copy, import formatMoney from @acme/format.
→ Net-lines: negative. Had the outputs differed, the copy diverged: owner code-quality, /quality-fix.
```

### Tier escalation

```text
# Trivial → standard
A001: replace a local cn() helper with the declared clsx (oracle: ai/conventions.md:14)
Initial tier: trivial. The swap touches 18 files → promoter "3–10 files" exceeded.
→ /align-promote-tier A001 standard; 1-paragraph rationale: "18 components import the local cn(); clsx is API-equivalent."

# Standard → heavy
A012: rename useUserContext() → useAuth() per the naming rule
The hook is exported and used by 2 sibling packages → promoter "removes a symbol used outside the module".
→ heavy: impact analysis listing every consumer + reviewer_approval before merge.

# Forbidden demotion
A047: AL-15 add-gate on a destructive action → heavy by rule (an auth / permission gate).
→ /align-promote-tier A047 standard is refused: gate rows never fall below heavy.
```

### Owner rows — routed, not absorbed

```text
# ❌ Absorbed
A101: SQL built by string concat in /reports/orders (a legacy class: security row)
Closure in align: parameterize
→ Security rows are /security-fix's (always installed), with its failing-first proof. check_owner_routed refuses.

# ✅ Routed
A101: status routed · owner security · routed: /security-fix ai/audits/2026-10-18-align.md#F-07 · no commit.

# ✅ Carve-out (perf owner absent)
A legacy `class: performance` row: listOrders() N+1; the oracle names customersRepo.getByIds() as the batch loader.
The performance and database packs are not installed.
→ A query-count scaling test committed first (fails: 51 queries for 50 orders), then batch through getByIds (2 queries).
→ A number in notes ("~200ms → 35ms") is not a baseline.
```

## Anti-patterns (named)

**Moved.** The named catalogue — every anti-pattern with its fingerprint and the check that catches it — lives at `ai/patterns/align-guardrails.md § Named anti-patterns`, together with the eight realism guards.

It moved because the names are load-bearing at runtime: `@align-ledger-auditor` groups halts by them, `@align-gate-auditor` cites them in refusals, `/align-final` counts them. A vocabulary that audits must cite belongs in a file that installs with the pack, which `references/` does not — Phase 4.2 copies `references/<framework>.md` for detected frameworks only, so a reference file with a non-framework name reaches no project. Patterns install unconditionally. One copy, in the reachable place.

## References

These references are **convenience pointers for AI tools that support them**. The rule carries the contract; the procedures live in the six align `SKILL.md` files and `align-discipline-procedures.md`. If your tool doesn't expose these as commands/agents/skills, read them as documents.

### For tools with command + agent + skill dispatch

**Align's own agents — the four audit windows (1.9.0).** Detection is the detector skills below plus the owner packs' detectors; these four own the *verdicts*, split by when in a row's life the audit happens:

- `.claude/agents/align-evidence-auditor.md` — pre-fix. Audits a fresh scan's `detected` rows: evidence resolves at the pinned commit AND carries the claimed fingerprint, the oracle quote resolves (AL-01), enumerations explicit, class matches signal, owner and closer match `align-detect`, tier floor met. Halts #1–#4, #11. Dispatched by `/align-scan` (Phase 6), `/align-recheck` (TRIAGE), `/align-replan --include-drifted`.
- `.claude/agents/align-idiom-auditor.md` — per-fix. Decides whether one diff ENFORCED a declared idiom or INVENTED a new one; halts #6, #9, #10 plus the oracle-unmodified check. Dispatched by `find-and-align` at DECIDE and VERIFY, and therefore by every command that runs the loop.
- `.claude/agents/align-gate-auditor.md` — post-phase. The 17-check matrix and the PASS/REFUSE verdict. Dispatched by `/align-gate`, `/align-fast`'s auto-gate, and `/align-final`.
- `.claude/agents/align-ledger-auditor.md` — cross-phase. Ledger ↔ git ↔ halts ↔ impact ↔ plan ↔ gate-history reconciliation in both directions, plus state-machine legality (fourteen states) and SLA thresholds. Dispatched by `/align-status`, `/align-final`, `/align-replan`.

Skills:
- `.claude/skills/align-detect/SKILL.md` — the AL-01…AL-34 class ledger (detector, owner, closer), the legacy class map, and the dispatcher.
- `.claude/skills/convention-oracle/SKILL.md` — § 0 the oracle map (`oracle-map.py`); AL-01–04.
- `.claude/skills/wrapper-adoption-scan/SKILL.md` — AL-11, 13, 14, 15, 22.
- `.claude/skills/naming-layout-scan/SKILL.md` — AL-16–19 (`name-check.py`).
- `.claude/skills/convention-ratchet-scan/SKILL.md` — AL-29–32.
- `.claude/skills/find-and-align/SKILL.md` — the per-row proof ladder L0–L13 (`align-sweep-gate.py`); AL-33/34.

Commands:
- `.claude/commands/align-scan.md` — the read-only audit; writes `ai/audits/<date>-align.md` + `ai/align/scan-report.md` and ledger rows at `detected`.
- `.claude/commands/align-plan.md` — phase grouper (consumes the ledger and the report).
- `.claude/commands/align-phase.md` — per-phase orchestrator (runs find-and-align per row).
- `.claude/commands/align-gate.md` — phase exit verifier (the 17 checks).
- `.claude/commands/align-fast.md` — one-shot per-phase runner (waves + sweep gate per wave + auto-gate).
- `.claude/commands/align-status.md` — read-only ledger reader.
- `.claude/commands/align-final.md` — final sweep across all phases.
- `.claude/commands/align-rollback.md` — undo a phase.
- `.claude/commands/align-park.md` / `align-unpark.md` — defer / restore a row.
- `.claude/commands/align-recheck.md` — the audit and fix on one area, no plan required.

### Cross-pack references

Each owner is dispatched "when the <pack> pack is installed"; without it, its classes print `N/A (owner pack <x> not installed)`.

- `code-quality/commands/simplify.md` — structural closure-verb vocabulary inherited from this command.
- `code-quality/commands/check-health.md` — pre-flight mechanical check; run before a fix phase.
- `code-quality/skills/architectural-diagnosis/` — AL-20/21 (layer direction, private import).
- `code-quality/skills/duplication-scan/` — decides an AL-13 copy that diverged (→ `/quality-fix`).
- `code-quality/skills/suppression-scan/` — correctness-rule suppressions; convention-rule ones are AL-29.
- `ui-ux/skills/design-token-audit/` and its `scripts/token-map.py` — AL-05–10, AL-12; the EQ / VC classifier behind `find-and-align` L8.
- `frontend/skills/i18n-scan/`, `frontend/skills/a11y-code-scan/` — AL-26/27, AL-28.
- `backend/skills/edge-error-scan/`, `backend/skills/api-consistency-audit/` — AL-23, AL-24/25.
- `security/commands/security-audit.md`, `/security-fix` — every security class (owner line only in align).
- `performance` / `database` packs — `/perf-audit`, `/db-audit`, `/perf-fix`, `/db-fix` for perf and data classes.
- `learning/commands/detect-drift.md` — the read-only conventions-vs-code report; dispatches `convention-oracle` when align is installed.
- `migration/rules/migration-discipline.md` — sibling discipline; align is migration turned inward.

### Snippets

- `templates/snippets/precedents/align.md` — the precedents a verifier reads before arguing a candidate (P-01…P-31).
- `templates/snippets/proof-oracles.md § Align` — the proof oracles V389–V408.
- `templates/snippets/refute-before-report.md` § 10 — the verification protocol (conventions column).

### Patterns (read by all tools as ai/ knowledge)

- `ai/patterns/align-ledger.md` — ledger record format + the fourteen-state machine.
- `ai/patterns/align-guardrails.md` — the eight guards, supporting mechanisms, anti-patterns, enforcement.

### Validator and sweep gate

- `scripts/validate-align-artifacts.sh` — per row: evidence resolves, no hand-waves, AL class, oracle cited, closure-verb vocabulary, net lines on structural rows, file-level scope on every row commit, no new symbols, proof class, VC approval, owner routed, side-state fields, idiom citation, oracle unmodified (legacy rows: security tier, security assertion, perf baseline); per run: scan-report evidence for all 34 AL rows, progress/ledger reconciliation, actionable next steps. Tool-agnostic.
- `find-and-align/scripts/align-sweep-gate.py` — line-level scope, re-detect zero, one way per pattern, test lock, emitted names, value round-trip, ratchet, non-vacuous, coverage. Stdlib Python, `python3 -I`, writes only under `$TMPDIR`.
- **Agent-side:** ledger completeness, the mechanical run and boot, the zero computed-style evidence, the tier artifacts — run by `@align-gate-auditor` and labelled as such in its report.

### For rule-only tools (Aider, Codex, Gemini, partial: Cline, Windsurf)

The rule is the contract: the oracle and its tiers, the AL class names and legacy map, the 21-verb vocabulary, the EQ / VC / FN proof classes, the 11 per-finding halts and the 17-check gate outline. The procedures (the detectors' pre-flight scripts, the proof ladder) are in the six `SKILL.md` files and `align-discipline-procedures.md`; ship them as documents with the rule and follow them as a checklist. The four align agents change nothing here: they are the checklist given an owner and a dispatch address. A rule-only tool that runs the halts inline reaches the same enforcement floor.

## Per-stack lanes and owner detectors

Align's detectors are stack-agnostic in what they ask (does the live site follow the declared convention?) and stack-specific in how they look: each detector skill carries a lane table — JS/TS (React, Vue, Svelte, Angular), Python, Go, Java/Kotlin, .NET, Ruby, PHP — with the tool, its version gate and a fallback grep (ESLint ≥ 10 flat config only; TypeScript 7 without the TS 6 API turns typed lanes `NOT RUN`; unicorn ≥ 65 checks directories; Ruff `--no-cache`). A missing tool is `blocked (<tool>)` and the detector falls back to its grep.

What changes per `PROJECT_KIND` is which **owner** detectors exist:
- `frontend-*` — ui-ux `design-token-audit` (tokens, AL-05–10, 12) and frontend `i18n-scan` / `a11y-code-scan` (AL-26–28). UI rows group by page or domain in the plan; EQ rows need a zero computed-style diff (or `(static EQ)`), VC rows a named approval.
- `backend-*` — backend `edge-error-scan` §6–§7 (AL-23, a **declared** contract → `/backend-fix`) and `api-consistency-audit` (AL-24/25 → `/polish`).
- `data-*`, `mobile-*` — no owner detector is dispatched; the align classes run on the declared conventions as on any stack.

Classes that are **not** align's on any stack: missing UI states and motion (ui-ux `ui-state-scan`, `motion-audit`; a site that bypasses a **declared** state or fetch wrapper is AL-11), responsive drift, tenant filters, transactions, N+1, `SELECT *`, idempotency keys. A legacy ledger row carrying one of those names is read through `align-detect` § The legacy class map and routed.

## Anti-bloat merge gates — moved

The merge-gate definitions, the closed 21-verb closure vocabulary and the net-lines rule live in
**`ai/patterns/align-guardrails.md` § Anti-bloat merge gates** — they are gates, and a gate has to
reach the project. `references/` files install only for a **detected framework name**
(`templates/phases/phase-4.2-apply.md:210-213`); `ai-patterns/` installs unconditionally.

## Should — full guidance

- **Order rows within a phase by dependency.** Re-route callers before removing a raw twin; move a copy's callers before `dedupe`; renames after the rows whose evidence sits in the renamed file.
- **Regressions first, then the lowest-blast-radius class.** AL-30 regressions and reasonless AL-29 suppressions in phase 1; EQ import swaps (AL-11, AL-14, AL-22) next; UI EQ swaps by domain; helper copies; names and layout; declared migrations; enforcement (AL-03, AL-31) last.
- **HIGH rows early, alone.** An AL-15 gate drop is the one HIGH align class; give it an early phase of its own, heavy tier, FN proof.
- **Rule first where expressible.** A lint or ast-grep rule with BAD / GOOD tests, run from a scratch folder on a sample, then the sweep; commit the rule only when the row's closure is "enable the rule".
- **Ratchet what is not fixed.** A class with debt and no shrink-only baseline is a production-bar gap; add the baseline after the fixes, never before.
- **Run `/align-fast` for routine sweeps** — most alignment rows are EQ swaps, parallelisable by disjoint scope, and the manual flow's pauses are wall-clock waste. Reach for `/align-phase` when a phase has heavy rows that benefit from per-row supervision.
- **Anchor a phase to a domain when possible.** A phase that aligns "the auth pages" reads better in PR review than one that aligns five classes across the repo.
- **Run `/check-health` before a fix phase** — red mechanical CI drowns alignment fixes. The audit itself is read-only and runs on any tree.
- **Stop at the declaration.** If a fix pushes past what the oracle names (a "better" wrapper than the declared one), halt; either the declaration is wrong (update via `/setup-project --refine` or an ADR) or the fix is over-reach.
- **Cap a phase at 12 rows.** Larger phases hide regressions in PR review and slow the gate.
- **Re-scan after every K phases.** `/align-scan --changed <base>` catches drift a phase introduced in a sibling file.
- **Ratify before you enforce.** A high Unconfirmed share means the oracle is mostly T2g; the ratification list is the first MUST.
- **Wire repeated classes into a T1 rule.** A class that ships > 50 rows with no rule at `error` will rot back; queue the rule and its baseline as an ADR (an AL-03 row).
