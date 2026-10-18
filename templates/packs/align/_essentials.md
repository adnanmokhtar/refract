---
track: align
purpose: Declared-convention enforcement — finds live sites that break a convention the project already declares (a lint rule at error, a human-written line in ai/conventions.md, an ADR, the glossary, the token set, a named wrapper), proves each against its oracle line, and closes the align-owned rows with EQ / VC / FN proof through a deterministic sweep gate. Classes another pack owns (security, performance, data, error handling, dead code, tokens, i18n, a11y, API contracts) are dispatched to that owner and routed to its fix command. Phased + parallel dispatch like /migration-fast.
essentials:
  agents: [align-gate-auditor, align-idiom-auditor, align-evidence-auditor, align-ledger-auditor]
  commands: [align-scan, align-plan, align-phase, align-gate, align-fast, align-status, align-final, align-rollback, align-park, align-unpark, align-replan, align-recheck, align-promote-tier]
  skills: [align-detect, convention-oracle, wrapper-adoption-scan, naming-layout-scan, convention-ratchet-scan, find-and-align]
  rules: [align-discipline]
  rule_references: [align-discipline-procedures, align-discipline-catalogue]   # references/ — PACK-SIDE ONLY; phase-4.2-apply.md:210-213 copies references/<name>.md only for a DETECTED FRAMEWORK NAME, so these never reach a project. Worked procedures + examples only; nothing enforceable.
  ai-patterns: [align-ledger, align-guardrails]
---

# Align — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

This pack is loaded **on demand** via `--include=align` (no auto-load — alignment is a deliberate cadence, not a constant). It complements the migration pack (V1→V2 ports: the oracle is a second codebase) and the code-quality pack (always installed; it owns error handling, dead code, duplication, SOLID and complexity, and its `/quality-fix` closes them). Align inherits the closure-verb discipline from `simplify` and the phased scan → plan → phase → gate → final shape from migration.

## What align covers

Align owns one question: **the project declares a convention, and a live site does not follow it.** The declaration is the **oracle** — a rule at `error` in the resolved lint config of a package CI lints (T1), a line a human wrote in `ai/conventions.md`, an ADR, CONTRIBUTING, the design-system docs or `ai/glossary.md` (T2), the token set, a named wrapper or helper. Every row cites it (`oracle:` + quote + `oracle_tier:`); a row whose quote does not resolve is AL-01 and is dropped. A majority with no declaration is a split for a human to ratify (AL-02, 0 ledger rows), and a generated line (T2g) waits at `pending-ratification`.

The 34 classes AL-01…AL-34, with detector, owner and closer, are tabled once in the `align-detect` skill. Align's own detectors:

- **`convention-oracle`** — § 0 builds the tiered oracle map every detector reads (`oracle-map.py`); AL-01 invented convention (run on every candidate), AL-02 split with no declared winner, AL-03 declared but unenforced, AL-04 doc contradicts current code.
- **`wrapper-adoption-scan`** — AL-11 raw primitive where a wrapper exists, AL-13 copy of a named helper, AL-14 deep import past a public entry, AL-15 wrapper without a required prop or gate, AL-22 forbidden library.
- **`naming-layout-scan`** — AL-16 file and directory names, AL-17 identifiers, AL-18 glossary synonyms, AL-19 placement and module skeleton (`name-check.py`).
- **`convention-ratchet-scan`** — AL-29 suppression of a convention rule, AL-30 ratchet regression, AL-31 per-package config drift, AL-32 half-finished declared migration.
- **`find-and-align`'s `align-sweep-gate.py`** — AL-33 one pattern resolved two ways in a sweep, AL-34 an out-of-scope edit (fix runs only).

**Owner classes**, detected by their pack and dispatched by `align-detect` when that pack is installed (otherwise `N/A (owner pack <x> not installed)`): tokens AL-05–10 and AL-12 (ui-ux `design-token-audit`), layers AL-20/21 (code-quality `architectural-diagnosis`), API contract AL-23–25 (backend), i18n and a11y AL-26–28 (frontend). Align closes an owner row only when its oracle is T1/T2 and the swap is exact (EQ). Security, performance, data, error handling, dead code, SOLID and complexity are never graded here: each prints one owner line and its rows are `routed` to the owner's fix command.

## Rationale per category (one line each)

- **agents**: The audit surface — four auditors, one per stage of a finding's life. `align-evidence-auditor` (pre-fix: do the scan's evidence and oracle quote resolve, and is the row align's?), `align-idiom-auditor` (per-fix: did this diff enforce an existing idiom or invent a new one?), `align-gate-auditor` (post-phase: the 17-check PASS/REFUSE verdict), `align-ledger-auditor` (cross-phase: ledger ↔ git ↔ halts ↔ plan reconciliation). Under `--minimal` all four ship, because dropping any one of them moves its checks back inline into the command that dispatches it — which is the state the pack was in before 1.9.0, and is exactly the enforcement-theatre failure the discipline names. Deliberately NOT here: a detector *agent*. Detection is the five detector skills; owner classes are detected by their packs' skills.
- **commands**: `/align-scan` is the read-only audit (oracle map, every detector dispatched, each candidate refuted, the 34-row AL class ledger, an ALIGNED / ALIGNED-UNVERIFIED / DRIFT verdict); it writes `ai/audits/<date>-align.md` and `ai/align/scan-report.md` and adds rows at `detected`. `/align-plan` phases the rows. Then per phase EITHER the manual flow `/align-phase <N>` → `/align-gate <N>` OR the fast flow `/align-fast <N>` (waves + auto-gate, same discipline). After the last gate PASSes, `/align-final`. **Sidecar commands**: `/align-status` (read-only progress), `/align-rollback <N>`, `/align-park <id>` / `/align-unpark <id>`, `/align-replan`, `/align-promote-tier`, `/align-recheck <area>` (the audit and fix on one area). The simple surface is the orchestration command `/align` (`/align --from-audit <report>` closes an audit's `## What to do next`).
- **skills**: `align-detect` is the class ledger and dispatcher (the four align detectors plus every installed owner detector; legacy class names mapped to AL ids; a missing input is a reduction, never a halt); `convention-oracle`, `wrapper-adoption-scan`, `naming-layout-scan` and `convention-ratchet-scan` are the detectors; `find-and-align` is the per-row fix as a proof ladder (ROUTE → DETECT → DECIDE EQ/VC/FN → FIX rule first → VERIFY L0–L13 → RECORD; one commit per row).
- **rules**: `align-discipline` codifies the contract — the oracle and its tiers, what align owns, closes for an owner, and routes; the 21-verb closure vocabulary; the tier floor; the EQ / VC / FN proof classes; 11 per-finding halts; the 17-check gate in outline.
- **ai-patterns**: `align-ledger` is the state-tracking convention — the fourteen-state machine (five main-path, nine side states including `routed`, `pending-approval`, `pending-ratification` and `refuted`), the AL row fields (`al_class`, `oracle`, `oracle_tier`, `owner`, `proof_class`, `approval`, `detector_cmd`, `routed`) the validator parses, and the fields each state requires. `align-guardrails` is the other half the audits depend on: the eight execution-time realism guards (with thresholds and the output line each must emit) and the named anti-pattern catalogue that agents cite by name. Both are patterns rather than rule sections because both are consulted **when something fires**, not on every turn — and because a pattern installs with the pack, which is what makes a guard citable inside a real project.

## Phased flow vs fast flow — which command when

The pack offers two flows that compose. **`/align-phase <N>` dispatches `find-and-align` per row in phase N.** The phased flow is the batch wrapper; `find-and-align` is the unit of work. Both end at the same gate: `/align-gate <N>` runs the 17-check matrix.

```
First time setup
  ↓
/align-scan ──→ ai/audits/<date>-align.md + ai/align/scan-report.md + ai/align/ledger.md (rows at detected)
  ↓
/align-plan ──→ ai/align/plan.md (routed / pending-* rows stay out of the phases)
  ↓
─────── for each phase N ───────
│
│  EITHER fast flow (one command per phase, rows in disjoint-scope waves — routine sweeps):
│    /align-fast <N>             ← per-row ladder in waves + auto-gate
│      ↓ (internally, per row)
│      • find-and-align skill    → ROUTE → DETECT → DECIDE → FIX → VERIFY (L0–L13) → RECORD
│      • per tier:
│         trivial  → straight ladder
│         standard → ladder + 1-paragraph rationale
│         heavy    → ladder + reviewer pause (pending-review)
│      • /align-gate <N>         → phase exit verdict
│
│  OR manual flow (interactive checkpoints, when heavy-tier rows benefit from supervision):
│    /align-phase <N>             ← per-row ladder, sequential by default
│    /align-gate <N>              ← phase exit verifier
│
│  Both flows produce the same artifacts and run the same 17 checks.
│  A VC row without a human approval stops at pending-approval in both; no flow fills `approval:`.
│
│  PASS → continue to phase N+1
│  REFUSED → fix blockers; re-run /align-gate <N> (or /align-fast <N> for full re-pass)
│
─────── after the last phase's gate PASSes ───────
  ↓
/align-final ──→ ai/align/final-report-<date>.md
              + recommendations (T1 rules to add, ratchet baselines, ratification lines, idiom gaps)
```

## Mirrors /migration-fast exactly

The align pack matches the migration pack's command surface 1:1. Both run scan + plan once, then per-phase fast (or manual), then a final sweep. Inside the pack there is no command that does scan + plan + every phase — that's intentional. Each phase is a separate review window; bundling them into one command would hide regressions and conflate phases. (`/align`, the orchestration command, is the unphased simple surface: one audit, then the fixes in the report's order.)

```
Migration:  /migration-scan → /migration-plan → /migration-fast 1 → /migration-fast 2 → ... → /migration-final
Align:      /align-scan      → /align-plan      → /align-fast 1     → /align-fast 2     → ... → /align-final
```

## Composition with other packs

Each owner below is dispatched "when the <pack> pack is installed"; without it, its classes print `N/A (owner pack <x> not installed)` in the class ledger and nothing is graded in its place.

- **code-quality** pack (always installed) — `architectural-diagnosis` §1–§2 detects AL-20/21; `duplication-scan` decides an AL-13 copy that diverged (→ `/quality-fix`); `error-handling-scan`, `dead-code-scan` and the SOLID / complexity detectors own those classes outright (`owner: code-quality → /quality-audit`). Its `suppression-scan` keeps correctness-rule suppressions; convention-rule ones are AL-29 here.
- **security** pack (always installed) — every security class is `/security-audit`'s to find and `/security-fix`'s to close; align prints the owner line.
- **ui-ux** pack — `design-token-audit` detects AL-05–10 and AL-12; its `token-map.py` is the token classifier behind the EQ / VC split and `find-and-align`'s round-trip step. Without it, token rows do not exist in align and the round-trip step prints `NOT RUN`.
- **frontend** pack — `i18n-scan` §1–§2 (AL-26/27) and `a11y-code-scan` (AL-28); align closes only the EQ-key and AL-15-form rows, the rest go to `/frontend-fix`.
- **backend** pack — `edge-error-scan` §6–§7 (AL-23, closer `/backend-fix` for a declared contract) and `api-consistency-audit` (AL-24/25, closer `/polish`).
- **performance** / **database** packs — own perf and data classes (`/perf-fix`, `/db-fix`). Without them, align may apply an idiom the oracle already names only with a baseline measured by a failing-first test.
- **learning** pack — `/detect-drift` is the read-only conventions-vs-code report; with align installed it dispatches `convention-oracle`.
- **migration** pack — sibling discipline; if both packs are active, alignment fixes never use V1's old shape (V2's declared conventions win for align).

## Preconditions

- A declared convention to enforce: a lint rule at `error`, a human-written line in `ai/conventions.md` / `ai/architecture.md` / `ai/modules.md`, an ADR, a glossary, a token set or a named wrapper. The inventory falls back `_extracted-idioms.md` → `codebase-profile.md` → `ai/conventions.md`; a missing file is a reduction with a printed line, never a halt. With no declaration at all, every align class prints `N/A (no declared convention)` — run `/setup-project` (or `--refine`) first.
- Mechanical CI (lint / typecheck / build / tests) green at HEAD for the fix commands; align fixes would be drowned by existing red. The audit itself is read-only and runs on any tree.

## Cadence

- **One-time first sweep** — typically large; expect 5–12 phases on a mature codebase that hasn't been swept before.
- **Routine cadence** — monthly or quarterly, depending on team size + change velocity. A human re-runs `/align-scan` on that cadence; the baseline ships no scheduler to do it for you.
- **Triggered cadence** — after a lint-config or convention change, a major framework upgrade or a refactor sprint; `/align-scan --changed <base>` keeps a branch from adding drift.

## Failure modes (top-level)

- No declared convention → every align class `N/A (no declared convention)`; `/setup-project --refine` first.
- Most of the ledger is T2g (generated lines) → the Unconfirmed share is high; ratify the lines (`/setup-project --refine` after a human confirms) before planning.
- Heavy churn during scan → re-run after the churn settles.
- Findings exceed cap (>200 across phases) → `/align-scan --first-run` caps each class at 20 and defers the rest as `Live, unreviewed`; ship the trivial / standard wins first (`/align-plan --exclude-tier=heavy`).
- A class with debt and no baseline → queue the ratchet (a shrink-only baseline) so it cannot grow while the sweep runs.
- Idiom inventory gaps surface repeatedly → halt-rate signal; queue `/setup-project --refine` priority.
