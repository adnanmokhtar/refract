---
name: align-guardrails
description: "Pattern: Align guardrails (the eight realism guards + the named anti-pattern catalogue an audit cites by name)"
kind: ai-pattern
pack: align
---

# Pattern: Align guardrails (realism guards + named anti-patterns)

> **Hard rule:** A guard that fires is named in the output; an anti-pattern that is claimed is named from this catalogue. "Scope was reduced", "the tree was dirty so we adapted", "this looks like a refactor in disguise" are unciteable. Every guard below has a threshold and a required output line; every anti-pattern below has a fingerprint and the check that catches it. A verdict that uses one of these names without meeting its definition here is a bug in the audit.

**When to apply**
- Any `/align-scan` / `/align-phase` / `/align-fast` run on a real codebase — the guards are what keep a sweep from stalling on size, flake, or a dirty tree.
- Any audit output (`@align-evidence-auditor`, `@align-idiom-auditor`, `@align-gate-auditor`, `@align-ledger-auditor`) that reduces scope, skips a check, or names a failure.

**When NOT to apply**
- A 2-finding `/align-recheck <area>` spot fix — the guards are no-ops at that size and the ceremony exceeds the value.

**Halt conditions / mandatory cites**
- A guard fired but is not named in the output → the reduction is invisible; treat the report as incomplete.
- An anti-pattern name used that is not in the catalogue below → either add it here with a fingerprint and a catching check, or say what actually happened instead.
- A guard whose threshold comes from the project (`ai/conventions.md`) but the file is absent → use the default stated here and say which default you used.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md` + `ai/conventions.md`.
>
> - **Threshold overrides**: `ai/conventions.md § Align` (any guard default below may be overridden there; an override is cited by name when the guard fires).
> - **Skip list**: `<extracted>` (default: the project's lint/format ignore file — `.gitignore` plus `.eslintignore` / `.prettierignore` / `ruff.toml exclude` / equivalent).
> - **Test runner + flake retry**: `<extracted>` (default: the project's test command; retry once before quarantine).

Two things live here, and they are here rather than in the rule because both are consulted **when something fires**, not on every turn: the execution-time guards that make a sweep survivable, and the named vocabulary an audit uses to say what went wrong.

## The eight realism guards

Commands apply these silently; audits cite a guard **by name** when one fires. Each row states what it protects against, the default threshold, and the line the output must carry.

| # | Guard | Fires when | Default | Required output line |
|---|---|---|---|---|
| 1 | **Scope cap** | A single detector's hit count on one AL class exceeds the cap; the sweep would otherwise produce a ledger nobody phases | 200 rows per class per scan; `/align-scan --first-run` sets 20 | `GUARD scope-cap — <AL id>: <N> hits, capped at <cap>; remainder deferred to ai/align/_deferred.md and printed Live, unreviewed` |
| 2 | **Batch ceiling** | A phase would carry more rows than a reviewer can localise a regression inside | 12 rows per phase | `GUARD batch-ceiling — phase <N>: <N> rows, ceiling 12; excess routed to phase <N+1>` |
| 3 | **Skip-list honoring** | A detector hit lands in a path the project already excludes from lint/format/tests | the project's ignore files; vendored, generated and build output always excluded | `GUARD skip-list — <N> hits suppressed under <pattern>` |
| 4 | **Mechanical-red short-circuit** | Lint / typecheck / build / tests are already failing at HEAD before the sweep starts | any non-zero exit at pre-flight | `GUARD mechanical-red — <command> exits <code> at HEAD; sweep refuses to start` — this one **halts**, it does not reduce |
| 5 | **Oracle-absence fallback** | A detector needs an oracle input that is absent | the inventory falls back `_extracted-idioms.md` → `codebase-profile.md` → `ai/conventions.md`; a class with no declaration prints `N/A (no declared <x>)`; none at all and no T1 rule → every align class `N/A (no declared convention)`. **Never a halt.** A missing tool is `blocked (<tool>)` with its fallback grep | `GUARD oracle-absence — inventory <file used>; <AL ids> N/A (no declared <x>); <N> classes ran` |
| 6 | **Dirty-tree behaviour** | `git status --porcelain` is non-empty | scan may run and says so; `/align-phase`, `/align-fast` and `/align-gate` **refuse** | `GUARD dirty-tree — <N> modified paths; <scan: proceeding, evidence pinned at HEAD \| gate: REFUSE>` |
| 7 | **Flaky-test quarantine** | A test fails, then passes on retry, inside a fix's VERIFY step | one retry; a test that flips is quarantined for this row, never for the phase | `GUARD flaky-quarantine — <test-id> flipped on retry; row <id> verified excluding it; NOT a green suite` |
| 8 | **Large-file sampling** | A single file exceeds what a detector can read whole | 2,000 lines | `GUARD large-file-sampling — <path>: <N> lines, read <ranges>; rows from this file are marked partial-read` |

**Two properties the guards share, and they are the point:**
- **A guard reduces scope; it never converts a fail into a pass.** Guards 4 and 6 halt the fix commands. Guards 1, 2, 3, 5, 7 and 8 shrink what was examined and say so. None of them makes an examined-and-failing row acceptable.
- **A guard that fires silently is the failure mode.** A capped scan that reports "no further findings", or an AL class skipped without a line, is indistinguishable from a clean codebase — which is exactly the Trusted Summary anti-pattern with a mechanical cause instead of a lazy one. In the class ledger a reduced class prints `N/A`, `blocked`, `NOT RUN` or `Live, unreviewed`, never `checked (0)`.

## Supporting mechanisms

These six are not guards — a guard bounds what a sweep *examines*, and these decide whether an
examined result *counts*, who signs it off, and what happens when the oracle moves under it. Each
carries its own threshold and is cited by name from a command, an agent or the rule. They live here
rather than in `references/` for one reason: `references/` files install only when their
filename matches a **detected framework name** (`templates/phases/phase-4.2-apply.md:211-214`,
`:347-350` — `for fw in <detected-frameworks>; do cp .../references/${fw}.md ...`), so a project
never receives `align-discipline-procedures.md`. `ai-patterns/` copies unconditionally.

### Coverage tolerance

"Coverage non-decreasing" allows **±0.5%** by default, configurable per project in
`ai/conventions.md § Coverage`. Sample-based tools (jest-coverage, pytest-cov, `go test -cover`)
fluctuate ±0.1–0.3% on *identical* code — async test ordering changes which branches happened to be
exercised, instrumentation rounds, and test parallelism changes which fixtures load.

A drop **within** tolerance is sample fluctuation and passes. A drop **beyond** tolerance is a halt:
the closure removed a load-bearing branch. `check_test_coverage_nondecreasing` is **agent-side, not
script-enforced** — no gate catches a command that skips it.

### Parallel race serialization (per-file lock)

`/align-fast` and `/align-phase` dispatch rows in parallel waves. Two rows whose `scope` files
overlap MUST NOT run concurrently — they race on edits to the same file and the later write wins
silently.

The lock: the orchestrator keeps `in_progress_files = union(scope files of active rows)`; a row
dispatches only when `row.scope_files ∩ in_progress_files == ∅`; completing a row (fixed, halted, or
verified) releases its files. **Heavy-tier rows serialize across the whole phase** — their lock is
every file. Simplest correct implementation: walk rows in dependency order, wait until each row's
scope files are unlocked, acquire, run, release.

`check_parallel_consistency` is **agent-side, not script-enforced**: post-hoc it verifies no two
phase commits touched the same file at overlapping timestamps. Two commits modifying one file in the
same wave = halt.

### Baseline capture fallback (the perf / data carve-out only)

Performance and data rows belong to `/perf-fix` and `/db-fix`. Align closes one only under the carve-out: the owning pack is **not installed** and the fix applies an idiom the oracle already names (a declared batch loader, a declared cache wrapper). Such a row needs a baseline, and the baseline is a **test**:

1. **Test-suite baseline (required)** — a failing-first test that measures the cost at the pre-fix commit (a query-count scaling test, `proof-oracles.md` § Query-count scaling), committed before the fix; it fails on the pre-fix code and passes after.
2. **APM reading (context only)** — p95 or query count from the project's observability link in `_extracted-codebase.md § Observability` may accompany the test; it never replaces it.

A number in `notes` ("baseline: ~30ms (hand-timed)") is not a baseline. `check_perf_baseline_present` reads legacy `class: performance` rows for a figure; a row without its committed test is not a carve-out: `/align-gate` check 17 excepts only the **measured**-baseline carve-out, so it counts as an owner row closed here and refuses. With the owner pack installed the row is `routed` and none of this applies.

### Reviewer-approval mechanism (heavy-tier rows)

Heavy-tier rows pause for reviewer approval before they can flip to `verified`. This is a real protocol, not a soft suggestion:

**Ledger field**: every heavy-tier row has a `reviewer_approval:` field. Initially empty. Approval lands as `<reviewer-name>@<iso-timestamp>` (e.g., `reviewer_approval: alice@2026-05-02T18:30Z`).

**Halt behaviour**: when `/align-fast` / `/align-phase` reaches a heavy-tier row's RECORD step, it:
1. Applies the fix and runs VERIFY as normal.
2. Writes the row to ledger with `status: pending-review` (NOT `fixed`).
3. Writes `ai/align/halts/<id>-pending-review.md` with: who's the assigned reviewer, what to verify, and how to approve.
4. Continues to the next row (heavy rows do NOT block the rest of the phase).

**Approval flow**:
- Reviewer reads `ai/align/halts/<id>-pending-review.md` + the impact analysis at `ai/align/impact/<id>.md`.
- Reviewer manually adds `reviewer_approval: <name>@<iso>` to the ledger row + commits the ledger update.
- On next `/align-gate <N>` run, rows with non-empty `reviewer_approval` flip from `pending-review` → `verified`.

**Reviewer assignment**:
- Default: project's `CODEOWNERS` for the row's `scope` files OR the `default_reviewer:` field in `_anchors.md`.
- Override: pass `--reviewer=<name>` to `/align-fast` / `/align-phase` to assign explicitly.
- Fallback: if no reviewer is assignable, halt the row with "manual review required" (don't auto-approve).

**Timeout behaviour**:
- Default 7 days. After timeout, the row stays `pending-review` indefinitely; `/align-status --blockers` surfaces it.
- The user can override via `--review-timeout=<duration>` (e.g., `24h`, `30d`, `forever`).
- No auto-fail. No silent advance. The discipline is "wait until human signs off, however long that takes."

**Validator**: `validate-align-artifacts.sh` knows about `pending-review` status and treats it as terminal-non-fix (passes the row's checks; doesn't expect `verified`).

**Not the VC approval.** `reviewer_approval:` signs a heavy row's *impact*; `approval:` signs a VC row's *visible change* (a nearest-token snap, a wrapper with different defaults) after a human looked at the diff images (`find-and-align` L10b, V407). A VC row needs `approval:` whatever its tier; an agent never writes either field, and an approval written in the fix commit itself is refused (`check_vc_approval`, `/align-gate` check 13).

### Mid-sweep tier promotion

Sometimes mid-sweep the agent realizes a row's tier is wrong (e.g., scan classified it as standard but the fix actually touches > 10 files; or trivial dead-code turns out to remove a public API symbol). Procedure:

1. **Halt the row** — fix loop pauses at DECIDE; agent surfaces the promotion request.
2. **User decides** via `/align-promote-tier <id> <new-tier> [--reason="<text>"]`:
   - `<new-tier>` ∈ `{trivial, standard, heavy}`.
   - Promotions (trivial → standard → heavy) require no further justification.
   - Demotions (heavy → standard → trivial) require `--reason=` AND are forbidden below heavy for a row that adds or touches an auth / permission / tenant gate (an AL-15 gate row, severity HIGH) or a VC row on a shared component — the heavy triggers of `align-discipline.md § Tier classification`.
3. **Backfill artifacts** for the new tier:
   - Promote to standard → agent backfills the ≤ 200-char rationale in `notes`.
   - Promote to heavy → agent generates the impact analysis at `ai/align/impact/<id>.md`; reviewer-approval flow kicks in.
4. **Resume**: agent re-enters DECIDE → FIX → VERIFY → RECORD with the new tier's discipline.

The `/align-promote-tier` command writes a one-line entry to `ai/align/_history.md`: `<iso> promote-tier <id> <old-tier>→<new-tier> | reason: <text>`.

Demotion of a gate row below heavy fails with: `AL-15 gate rows cannot fall below heavy tier`. A legacy `class: security` row is not demoted at all: it is routed to `/security-fix` (`align-ledger.md § Legacy class names`).

### Idiom-drift propagation (oracle drift)

When an oracle file changes between scan and execution — `_extracted-idioms.md`, `ai/conventions.md`, an ADR, a lint config, the glossary — ledger rows that cite it may need re-evaluation. The scan + replan commands surface this:

**`/align-scan` detection** (its Phase 7): the command compares the hash of every file an `oracle:` or `idiom_cited` row points into against the hashes recorded in `ai/align/_session-digest.md` by the prior scan. For each changed file:
1. Scan runs as normal.
2. The report lists the rows whose `oracle:` or `idiom_cited` points into the changed file, with the recommended action: re-run `/align-recheck` for those rows OR `/align-replan --include-drifted`. They are re-verified, never auto-flipped.

**`/align-replan --include-drifted`**: re-phases rows whose cited line changed. A `verified` row flips to `detected` IF its oracle quote or idiom changed materially (removed, renamed, signature change); it stays `verified` if the change was cosmetic (agent decides per-row, with the line in `notes`).

**Checks**: `find-and-align` L0 re-resolves every row's `oracle:` quote before an edit (`oracle-gone` halt); the validator's `check_oracle_cited` re-resolves it at the gate (check 17); `check_added_lines_cite_idioms` re-resolves `idiom_cited` (check 16).

## Named anti-patterns

The names are load-bearing vocabulary: audits cite them, `/align-status` groups by them, `/align-final` counts them. Each carries a fingerprint and the check that catches it.

- **The Refactor in Disguise** — a row whose fix introduces a new abstraction (one no oracle names), renames a public API or a wire name, or changes observable behaviour where preservation was the contract. Looks like alignment in the ledger; ships as a redesign in PR review. Caught by: closure-verb vocabulary check + `check_no_new_symbols` + `/align-gate` checks 4 and 13.
- **The Trusted Summary** (inherited from migration) — agent says "looks reinvented" / "looks off-convention" / "no drift" without `<path:line>` evidence; executor echoes into the ledger. Caught by: `check_evidence_resolves` + audit halt #1; every candidate goes through a separate verifier (`refute-before-report.md` § 10).
- **The Invented Convention** — a row whose `oracle:` quote is paraphrased, cited from nowhere, or points at a file that does not hold it ("hooks should return objects"). Caught by: `convention-oracle` § 1 (AL-01, the row is dropped and counted), `find-and-align` L0, `check_oracle_cited`, audit halt #3, `/align-gate` check 17.
- **The Majority Vote** — a shape most files share, with no declaration, enforced as if it were a rule; or a generated (T2g) line enforced before a human ratified it. Caught by: AL-02 (the BIMODAL block, 0 ledger rows) and `pending-ratification`; `@align-evidence-auditor` rejects a row whose oracle tier is not T1/T2.
- **The Hand-waved Finding** (inherited) — `~8 raw imports`, `several reasonless disables`, `multiple deep imports`, `a few ungated delete buttons`. Caught by: `check_no_handwaves` + audit halt #2.
- **The Net-Positive Cleanup** (structural) — fix imports a shared helper but doesn't delete the local copy; OR introduces a wrapper "to make the swap easier"; OR adds a comment explaining the new shape. Net lines go up on a structural row. Caught by: `check_net_lines_structural` + audit halt #5.
- **The Bundled Phase** — phase PR mixes 5 AL classes; reviewer can't localise regressions. Caught by: review-checklist row "PR title = single-class-or-domain"; reviewer responsibility.
- **The Stale Ledger** — a phase merges without updating ledger rows to `fixed`. Code grep claims "no more raw ky imports" but ledger rows are still `in-progress`. Caught by: gate check 1; `/align-status` reports stalled rows; `@align-ledger-auditor` reconciliation 3.
- **The Oracle Drift** — alignment PR also modifies `_extracted-idioms.md` / `ai/conventions.md` / an ADR / a lint config to "explain" the fix. Caught by: `check_oracle_unmodified` + `find-and-align` L3 `lock-paths` + gate check 17.
- **The Two-Way Swap** — one before-value resolved to two after-values in one sweep (`#d92d20` → `--color-danger` in two files, `--color-error` in a third). Each hunk looks right alone. Caught by: `align-sweep-gate.py consistency` (AL-33, V393) per wave in `/align-fast`, at gate check 7, and across all phases in `/align-final`.
- **The Snapshot Re-record** — an EQ swap committed together with an updated snapshot, a weakened assertion, or a lint-config / baseline edit, so the "zero diff" was manufactured. Caught by: `find-and-align` L3 `lock-paths` and L12 `lock-count` (V408), gate check 8, audit halt #7.
- **The Self-Signed Visual** — a VC row (a nearest-token snap, a wrapper with different defaults) committed with `approval:` written by the agent, or in the same commit as the fix. Caught by: `check_vc_approval`, gate check 13, `align-ledger.md § Drift detection`.
- **The Vacuous Clean** — a rule or `detector_cmd` that matched 0 files reported as "0 hits, clean", or a row archived as aged out by a detector that never matched. Caught by: `find-and-align` L13 / DETECT (`re-detect-vacuous`), gate check 11; the class ledger prints `NOT RUN (rule matched 0 files)`.
- **The Eternal Phase** — phase opens, 30+ rows detected, phase never closes because new rows keep getting added. Caught by: the batch ceiling (guard 2, ≤ 12 rows); excess routes to phase N+1 via `/align-replan`.
- **The Re-Detection Skip** — porter applies the fix and marks `status: fixed` without re-running the detector to confirm the fingerprint is gone. The fingerprint sometimes lingers (the fix targeted the wrong line). Caught by: VERIFY's mandatory re-detect; `check_evidence_resolves` re-run at gate.
- **The Silent Coverage Drop** — fix removes a branch; tests pass; but the branch was the only path exercising a downstream code path. Coverage drops 0.3%; nobody notices in a 1500-test suite. Caught by: gate check 15 (`align-sweep-gate.py lock-count` + agent); any drop beyond tolerance is a halt.
- **The Reinvented Idiom in Functional Verb** — porter writes a new gate wrapper, barrel or constant inside an `add-gate` / `extract-to-shared` / `inline-magic-to-named-const` fix. The functional verbs are supposed to USE the project's declared idiom; inventing one is Reinvented Wrapper on the functional side. Caught by: `check_added_lines_cite_idioms` + `check_no_new_symbols` + audit halts #6, #9, #10.
- **The Absorbed Owner Row** — a security, performance, data or code-quality row closed inside align instead of routed to its owner's fix command, so it skips the owner's failing-first proof. Caught by: `find-and-align` Step 1 ROUTE, `check_owner_routed`, audit halt #11, gate check 17.
- **The Bare Security Fix** — the legacy form of the Absorbed Owner Row: a `class: security` row (an old ledger) closed with a gate / validator / escape and no test asserting it. Security rows are `/security-fix`'s now. Caught by: `check_owner_routed`; on old ledgers `check_security_assertion_present`.
- **The Hopeful Perf Fix** — a carve-out perf / data row (owner pack absent) closed without a committed failing-first baseline test, or with a hand-timed number in `notes`. Caught by: `check_perf_baseline_present` + gate check 17 (only a measured baseline earns the carve-out).
- **The Lockfile-Only Bump** — a `bump-dep` without the full test suite. Dependency bumps belong to `/upgrade-dep` and `/security-fix`; in align the verb survives only for a declared same-version migration step, and VERIFY's test run (L9, L12) is mandatory.
- **The Tier Demotion** — porter demotes an AL-15 gate row (or a VC row on a shared component) below heavy because "it's just one missing gate, easy fix". Caught by: `/align-promote-tier`'s refusal + gate check 16; on old ledgers `check_security_tier_minimum`.
- **The Behaviour Change Conflation** — an FN row (a declared gate added, which changes who sees an action) bundled with unrelated EQ swaps in one commit; the behaviour change becomes invisible in the diff. Caught by: review checklist + one-row-per-commit + `find-and-align` L4 scope.
- **The Cross-Class Phase** — phase PR mixes EQ swaps, FN gates and VC snaps. Their proofs differ and reviewer attention scatters. Caught by: `/align-plan`'s single-class-or-single-domain phasing.
- **The Frontend Regression Skip** — porter ignores a computed-style or visual difference "because the fix was mechanical". An EQ row with any difference is VC. Caught by: `find-and-align` L10a / L10b, gate check 13.
- **The Idiom Inventory Gap** — porter halts repeatedly because the idiom they need (a wrapper, a gate component, a helper) is declared nowhere. The right move is to declare it once via `/setup-project --refine`, then resume — not to invent the idiom inline. Symptom: `ai/align/halts/` full of `missing-idiom`. Caught by: `@align-ledger-auditor`'s systemic-halt SLA (same halt reason on ≥ 3 rows).
- **The Silent Park** — a row is parked and never comes back: no `unpark_after`, no SLA ageing it, and on a HIGH row (a permission, tenant or auth gate) the halted-row escalation clock stops the moment the status flips. Parking is deferral with a date, not closure. Caught by: `@align-ledger-auditor`'s parked SLA rows + `/align-final`'s per-severity `PARTIAL` breakdown.

## Anti-bloat merge gates

The migration discipline rule's Phase 7 lesson — "~95% docs / ~5% code on simple ports" — applies double here. Alignment is *by definition* small atomic edits. A doc-heavy alignment run is a category error.

- **Code edits are the deliverable.** A doc that doesn't enable a code change is waste. Rationales / notes exist when they unblock a code decision; they are not deliverables themselves.
- **The closure-verb vocabulary is finite.** Two semantic groups:
  - **Structural verbs** (net-lines ≤ 0): `remove`, `inline`, `dedupe`, `rename-comment-out`, `replace-with-shared`.
  - **Functional verbs** (small + budget): `add-gate`, `parameterize`, `escape`, `move-to-secrets`, `add-validator`, `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `extract-to-shared`, `split-extract`, `inline-magic-to-named-const`, `inline-filter-to-query`, `bump-dep`, `rename`. The security, perf and validation verbs serve only the owner carve-out (`align-discipline.md § Scope`); an owner row is routed, not closed with one of them.
  A row whose fix needs a verb outside this combined vocabulary IS NOT an alignment row. Route to `/refactor` or `/setup-project --refine` instead. **No verb introduces a NEW abstraction no oracle names.** A `split-extract` that creates a brand-new abstraction (rather than splitting into responsibilities the oracle already names) is forbidden.
- **Net-lines rule (split by verb group):**
  - **Structural verbs** — net-lines must be ≤ 0 per row (the first `replace-with-shared` import excepted) and per phase. A net-positive structural phase is a halt; the closure verb was applied wrong (likely a `replace-with-shared` that imported but didn't delete the local copy).
  - **Functional verbs** — small + budget allowed (typically + 2 to + 10 lines per row for a declared gate or barrel). The added lines MUST cite an idiom — every block of added lines references the `<path:line>` of the declared idiom it adds (the gate component, the barrel, the constant). Validator: `check_added_lines_cite_idioms` walks the diff hunks and refuses any added block that doesn't cite an idiom.
  - **Cumulative phase rule** — for phases that mix structural + functional rows, the structural rows must net ≤ 0 AND the functional rows must each cite idioms. The phase's overall diff may net positive when functional rows dominate (a phase that adds 8 declared `<Can>` gates is + 16 lines net; that's allowed).
- **Per-row enumeration is required at every tier.** Hand-waves (`etc.`, `...`, `and similar`, `N+ duplicates`, `several call sites`, `a few places`, `multiple endpoints`) HALT the gate. The validator's `check_no_handwaves` greps for these tokens. If 8 raw imports exist, the ledger lists 8 rows (or 1 row with 8 explicit `<path:line>` citations in `evidence`, one V393 group). Never `~8 raw imports`; never `several ungated delete buttons` — each site is enumerated.
- **Single-agent dispatch is the default.** Parallel sub-agents are heavy-tier-only AND require a deduplicated context blob (each sub-agent reading the project's full source independently is forbidden — same wasted-token pattern migration's Phase 7 fixed).
- **Rows cite source and oracle.** Every row has `evidence: <path:line>` for at least one fingerprint and an `oracle:` whose quote resolves. If you can't cite both, the row doesn't exist (Trusted Summary; Invented Convention).
- **Trivial-tier rows do not produce rationales.** The closure verb + the `<path:line>` evidence + the oracle quote is the rationale. A trivial row whose `notes` field is filled with prose is over-production; the validator flags `notes_excess_chars > 200` on trivial rows. An AL-15 gate row is never trivial (it is heavy: `align-discipline.md § Tier classification`).

## Enforcement — gate behaviour, SLA clocks, anti-pattern → check

- **`/align-gate <N>`** runs the 17-check matrix and REFUSES on any fail: ledger completeness (1), gap parity (2), net lines on structural rows (3), new symbols (4), line-level scope (5), re-detect zero (6), one way per pattern (7), tests locked (8), emitted names (9), value round-trip (10), non-vacuous (11), ratchet shrink-only (12), proof class and VC approval (13), mechanical + boot (14), coverage tolerance (15), per-tier artifacts + idiom citation (16), oracle cited and unmodified + owner rows routed (17). A step that printed `NOT RUN` for rows it applies to is a refusal.
- **`/align-status`** reports per-row state and flags rows older than the SLA (default: a row in `in-progress` for >7d is flagged stalled; a HIGH row — a permission, tenant or auth gate — halted for >24h is flagged escalated).
- **Two scripts carry the checks**; what neither runs is labelled `(agent-side)`:
  - `scripts/validate-align-artifacts.sh` — per row and per run:
    - "Hand-waved enumeration" → `check_no_handwaves`.
    - "Trusted Summary" → `check_evidence_resolves` (every `evidence` is a real `<path:line>` holding the fingerprint).
    - "Invented Convention" → `check_oracle_cited` (the `oracle:` quote resolves in the cited file, or the rule id is declared); `check_al_class` (an AL id, or a legacy class it maps).
    - "Reinvented Wrapper in fix" → `check_no_new_symbols` (new public exports no oracle names).
    - "Net-Positive Cleanup" → `check_net_lines_structural`.
    - "Functional add without idiom citation" → `check_added_lines_cite_idioms`.
    - "Closure verb" → `check_closure_verb_in_vocab`.
    - "Scope creep" (file level, every commit of the row) → `check_scope_boundary`.
    - "Oracle Drift" → `check_oracle_unmodified`.
    - "Self-Signed Visual" / unproven rows → `check_proof_class`, `check_vc_approval`.
    - "Absorbed Owner Row" → `check_owner_routed`; side-state fields → `check_side_state`.
    - Legacy rows only: `check_security_tier_minimum`, `check_security_assertion_present`, `check_perf_baseline_present`.
    - Run level: `check_scan_report_evidence` (all 34 AL rows carry a status line in `ai/align/scan-report.md`), `check_progress_ledger_reconciliation`, `check_actionable_next_steps`.
  - `find-and-align`'s `scripts/align-sweep-gate.py` — the run checks: `scope` (line level), `redetect`, `consistency`, `lock-paths`, `lock-count`, `names`, `roundtrip`, `ratchet`, `vacuous`, `oracle`, `approval`, `diffkind`.
  - **Agent-side:** ledger completeness (gate check 1), the mechanical run and boot (14), the zero computed-style / compiled-CSS evidence (13), the tier artifacts (16), and the parallel-consistency check of § Parallel race serialization.

## Automation hooks

- `/align-scan` applies guards 1, 3, 5, 6 (scan posture: proceeds, evidence pinned at HEAD), 8; writes deferred fingerprints to `ai/align/_deferred.md`. Guard 4 does not apply to the read-only audit.
- `/align-plan` and `/align-replan` apply guard 2.
- `/align-phase` and `/align-fast` apply guards 4, 6, 7.
- `/align-gate <N>` refuses on guards 4 and 6; reads guard lines from the phase's reports and requires each named guard to appear in the row's `notes` when it changed what was examined.
- `@align-ledger-auditor` groups halts by anti-pattern name; `/align-final` counts them and re-runs the run-level checks over the whole sweep.

## See also

- `align-discipline.md` — the rule these guards and names serve; the 11 per-finding halts and the tier floor live there.
- `align-ledger.md` (sibling pattern) — the row schema and state machine the guards annotate.
- `align-detect` skill — the AL-01…AL-34 class ledger and dispatcher whose detectors (`convention-oracle`, `wrapper-adoption-scan`, `naming-layout-scan`, `convention-ratchet-scan`, plus installed owner detectors) the scan guards bound.
- `find-and-align` skill — the proof ladder L0–L13 and `align-sweep-gate.py`.
- `/align-status` — surfaces guard-fired rows and parked-row ageing.
