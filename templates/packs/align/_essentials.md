---
track: align
purpose: Codebase quality gate — comprehensive sweep against the gold-standard inventory. Detects + fixes drift, dead code, duplicates, reinvented wrappers, silent catches, over-abstraction, SOLID violations, clean-code violations, performance issues, and security weaknesses. Stack-agnostic; frontend stacks dispatch UI/UX detectors (a11y, design tokens, i18n, motion) automatically. Phased + parallel dispatch like /migration-fast.
essentials:
  agents: []
  commands: [align-scan, align-plan, align-phase, align-gate, align-fast, align-status, align-final, align-rollback, align-park, align-replan, align-recheck, align-promote-tier]
  skills: [detect-drift, find-and-align]
  rules: [align-discipline]
  ai-patterns: [align-ledger]
---

# Align — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

This pack is loaded **on demand** via `--include=align` (no auto-load — alignment is a deliberate cadence, not a constant). It complements the migration pack (which handles V1→V2 ports) and the code-quality pack (which provides the underlying agents `dead-code-finder`, `refactorer`, `code-reviewer` and the `simplify` command's vocabulary). Align inherits closure-verb discipline from `simplify` and structural+phasing patterns from migration.

## What align covers

Align is the codebase's quality gate. The 11 universal detector classes (split into structural + functional groups) plus per-stack extensions:

- **Structural** (net-lines ≤ 0; entropy-reducing) — dead code, duplicated logic, reinvented wrappers, silent catches, over-abstraction, drift from gold standard.
- **Functional** (small + budget; added lines must cite idioms) — SOLID violations (SRP/OCP/LSP/ISP/DIP), clean-code (long functions / deep nesting / magic numbers / bad naming), performance (N+1 / sequential await / sync HTTP in hot path / missing cache / missing index / `SELECT *` / in-app filter), security (missing auth gate / SQL injection / XSS / secrets / unsafe deserialize / missing validator / vuln deps / tenant isolation / CSRF / rate-limit).
- **Frontend stack** — a11y violations, design-token drift, i18n key drift, raw library components in pages, missing UI states (loading/empty/error), motion drift, responsive drift, lifecycle hook on wrong child, default-true wrapper props, permission-gate drop.
- **Backend stack** — tenant-gate-missing, transaction-boundary, query-without-tenant-filter.
- **Data stack** — column-projection-mismatch, idempotency-key-missing, sync-http-in-batch.
- **Mobile stack** — native-bridge-audit findings.

## Rationale per category (one line each)

- **commands**: Run in order: `/align-scan` (deep codebase scan; fresh ledger), `/align-plan` (phased plan honoring gold standards). Then per phase EITHER the manual flow `/align-phase <N>` → `/align-gate <N>` (interactive, supervised) OR the fast flow `/align-fast <N>` (one-shot: per-finding loop in parallel + auto-gate, same discipline, no human-watch pauses). After the last phase's gate PASSes, `/align-final` (cross-phase verification + recommendations). **Sidecar commands**: `/align-status` (read-only progress), `/align-rollback <N>` (undo phase), `/align-park <id>` (defer hairy findings). Use `/align-fast <N>` for routine mechanical phases; manual flow when heavy-tier rows benefit from per-row supervision.
- **skills**: `detect-drift` runs the 11 universal detectors (parallel waves: structural / functional / stack-conditional); `find-and-align` is the per-finding fix loop (DETECT → DECIDE → FIX → VERIFY → RECORD; one commit per finding; net-lines ≤ 0 for structural / cite-idiom for functional).
- **rules**: `align-discipline` codifies the contract — closure-verb vocabulary (16 verbs across structural + functional groups); tier rules (trivial default for structural; security always ≥ standard; critical security always heavy); per-finding audit halts (11); phase-exit gate checks (14); anti-patterns (Trusted Summary, Hand-waved, Net-Positive Cleanup, Reinvented Idiom, Bare Security Fix, Hopeful Perf Fix, etc.).
- **ai-patterns**: `align-ledger` is the state-tracking convention (what's `detected` / `in-progress` / `fixed` / `verified` / `archived` / `parked` / `halted`).

## Phased flow vs fast flow — which command when

The pack offers two flows that compose. **`/align-phase <N>` dispatches `find-and-align` per finding in phase N.** The phased flow is the batch wrapper; `find-and-align` is the unit of work. Both end at the same gate: `/align-gate <N>` validates the 14-check matrix per `align-discipline.md`.

```
First time setup
  ↓
/align-scan ──→ ai/align/{ledger.md, scan-report.md, findings.md}
  ↓
/align-plan ──→ ai/align/plan.md
  ↓
─────── for each phase N ───────
│
│  EITHER fast flow (one command per phase, all rows in parallel — routine sweeps):
│    /align-fast <N>             ← per-finding loop in parallel + auto-gate
│      ↓ (internally, per row, in parallel waves)
│      • find-and-align skill    → DETECT → DECIDE → FIX → VERIFY → RECORD
│      • per tier:
│         trivial  → straight loop
│         standard → loop + 1-paragraph rationale
│         heavy    → loop + reviewer pause
│      • /align-gate <N>         → phase exit verdict
│
│  OR manual flow (interactive checkpoints, when heavy-tier rows benefit from supervision):
│    /align-phase <N>             ← per-finding loop, sequential by default
│    /align-gate <N>              ← phase exit verifier
│
│  Both flows produce the same artifacts and run the same 14 checks.
│  Fast adds: parallel dispatch + auto-routing per tier + no human-watch pauses.
│
│  PASS → continue to phase N+1
│  REFUSED → fix blockers; re-run /align-gate <N> (or /align-fast <N> for full re-pass)
│
─────── after the last phase's gate PASSes ───────
  ↓
/align-final ──→ ai/align/final-report-<date>.md
              + recommendations (next cadence, ADRs for hooks/lints, idiom gaps)
```

## Mirrors /migration-fast exactly

The align pack matches the migration pack's command surface 1:1. Both run scan + plan once, then per-phase fast (or manual), then a final sweep. There is no "all-in-one" command that does scan + plan + every phase — that's intentional. Each phase is a separate review window; bundling them into one command would hide regressions and conflate phases.

```
Migration:  /migration-scan → /migration-plan → /migration-fast 1 → /migration-fast 2 → ... → /migration-final
Align:      /align-scan      → /align-plan      → /align-fast 1     → /align-fast 2     → ... → /align-final
```

## Composition with other packs

- **code-quality** pack — align inherits the closure-verb vocabulary from `simplify` and dispatches `dead-code-finder` / `refactorer` / `code-reviewer` / `performance-optimizer` agents during scan.
- **security** pack — align dispatches `security-auditor` agent + `deps-audit` skill for the security finding class.
- **frontend** pack — align dispatches `accessibility-auditor` / `i18n-auditor` / `data-flow-auditor` for `frontend-*` projects, and applies `migration-frontend.md`'s fingerprint set.
- **ui-ux** pack — align dispatches `design-token-audit` + `motion-audit` skills for `frontend-*`.
- **migration** pack — sibling discipline; if both packs are active, alignment fixes never use V1's old shape (V2 gold standards win for align).
- **backend** pack — align applies backend-specific anti-patterns (tenant-gate, transaction-boundary).
- **mobile** pack — align dispatches `native-bridge-audit` for `mobile-*`.

## Preconditions

- `_extracted-idioms.md` MUST be populated. If empty, `/align-scan` halts and routes to `/setup-project --refine`. Without an oracle, "alignment" is just opinion.
- `ai/conventions.md` and `ai/architecture.md` SHOULD exist; missing files reduce drift detection accuracy but don't halt the scan.
- Mechanical CI (lint / typecheck / build / tests) MUST be green at HEAD; align fixes will be drowned by existing red.

## Cadence

- **One-time first sweep** — typically large; expect 5–12 phases on a mature codebase that hasn't been swept before.
- **Routine cadence** — monthly or quarterly, depending on team size + change velocity. `/schedule align-scan +4w` is a reasonable default for active projects.
- **Triggered cadence** — after major framework upgrades / dependency bumps / refactor sprints; alignment helps verify the upgrade didn't introduce drift.

## Failure modes (top-level)

- Empty oracle → `/setup-project --refine` first.
- Heavy churn during scan → re-run after the churn settles.
- Findings exceed cap (>200 across phases) → consider `--exclude-class=clean-code` for the first sweep; clean-code can dominate.
- Heavy-tier rows pile up → consider `--exclude-tier=heavy` for the first sweep; ship the trivial/standard wins first.
- Idiom inventory gaps surface repeatedly → halt-rate signal; queue `/setup-project --refine` priority.
