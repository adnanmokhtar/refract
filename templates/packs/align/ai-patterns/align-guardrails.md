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
| 1 | **Scope cap** | A single detector's hit count on one class exceeds the cap; the sweep would otherwise produce a ledger nobody phases | 200 findings per class per scan | `GUARD scope-cap — <class>: <N> hits, capped at <cap>; remainder deferred to ai/align/_deferred.md` |
| 2 | **Batch ceiling** | A phase would carry more rows than a reviewer can localise a regression inside | 12 rows per phase | `GUARD batch-ceiling — phase <N>: <N> rows, ceiling 12; excess routed to phase <N+1>` |
| 3 | **Skip-list honoring** | A detector hit lands in a path the project already excludes from lint/format/tests | the project's ignore files; vendored, generated and build output always excluded | `GUARD skip-list — <N> hits suppressed under <pattern>` |
| 4 | **Mechanical-red short-circuit** | Lint / typecheck / build / tests are already failing at HEAD before the sweep starts | any non-zero exit at pre-flight | `GUARD mechanical-red — <command> exits <code> at HEAD; sweep refuses to start` — this one **halts**, it does not reduce |
| 5 | **Oracle-absence fallback** | A class's detector needs an oracle input that is absent | `_extracted-idioms.md` absent → **halt** the whole sweep; `ai/conventions.md` / `ai/architecture.md` absent → skip the `drift` class only | `GUARD oracle-absence — drift class NOT RUN (no ai/conventions.md); <N> classes ran` |
| 6 | **Dirty-tree behaviour** | `git status --porcelain` is non-empty | scan may run and says so; `/align-phase`, `/align-fast` and `/align-gate` **refuse** | `GUARD dirty-tree — <N> modified paths; <scan: proceeding, evidence pinned at HEAD \| gate: REFUSE>` |
| 7 | **Flaky-test quarantine** | A test fails, then passes on retry, inside a fix's VERIFY step | one retry; a test that flips is quarantined for this row, never for the phase | `GUARD flaky-quarantine — <test-id> flipped on retry; row <id> verified excluding it; NOT a green suite` |
| 8 | **Large-file sampling** | A single file exceeds what a detector can read whole | 2,000 lines | `GUARD large-file-sampling — <path>: <N> lines, read <ranges>; rows from this file are marked partial-read` |

**Two properties the guards share, and they are the point:**
- **A guard reduces scope; it never converts a fail into a pass.** Guards 4 and 6 halt. Guards 1, 2, 3, 5, 7 and 8 shrink what was examined and say so. None of them makes an examined-and-failing row acceptable.
- **A guard that fires silently is the failure mode.** A capped scan that reports "no further findings", or a drift class skipped without a line, is indistinguishable from a clean codebase — which is exactly the Trusted Summary anti-pattern with a mechanical cause instead of a lazy one.

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

### Baseline capture fallback (no-observability projects)

Performance findings require a baseline (queries / latency / HTTP / wall-clock). Many projects don't have Grafana / Datadog / APM. Fallback hierarchy:

1. **APM dashboard** (preferred) — read latency p95 / query count from the project's observability link captured in `_extracted-codebase.md § Observability`.
2. **Test-suite baseline** — capture in a benchmark test that runs at HEAD pre-fix; assertion threshold = baseline + tolerance. Post-fix re-runs the test with new threshold = baseline_post_fix + tolerance.
3. **Manual measurement** — run the relevant code path against representative input; record wall-clock + query count via the project's logger or a one-off script. Document in `notes` with timestamp + input description.

Path 3 is acceptable for non-critical perf rows but discouraged for hot-path rows (subjective; not reproducible by reviewers). Path 1 or 2 preferred.

A perf row whose `notes` says "baseline: ~30ms (hand-timed)" is suspect; the validator's `check_perf_baseline_present` allows it but flags as `low-confidence`. Reviewers should escalate to path 1 or 2 before merging hot-path rows.

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

### Mid-sweep tier promotion

Sometimes mid-sweep the agent realizes a row's tier is wrong (e.g., scan classified it as standard but the fix actually touches > 10 files; or trivial dead-code turns out to remove a public API symbol). Procedure:

1. **Halt the row** — fix loop pauses at DECIDE; agent surfaces the promotion request.
2. **User decides** via `/align-promote-tier <id> <new-tier> [--reason="<text>"]`:
   - `<new-tier>` ∈ `{trivial, standard, heavy}`.
   - Promotions (trivial → standard → heavy) require no further justification.
   - Demotions (heavy → standard → trivial) require `--reason=` AND, for security rows, are forbidden (security never below standard).
3. **Backfill artifacts** for the new tier:
   - Promote to standard → agent backfills the ≤ 200-char rationale in `notes`.
   - Promote to heavy → agent generates the impact analysis at `ai/align/impact/<id>.md`; reviewer-approval flow kicks in.
4. **Resume**: agent re-enters DECIDE → FIX → VERIFY → RECORD with the new tier's discipline.

The `/align-promote-tier` command writes a one-line entry to `ai/align/_history.md`: `<iso> promote-tier <id> <old-tier>→<new-tier> | reason: <text>`.

Demotion of security rows below standard fails with: `security findings cannot fall below standard tier`.

### Idiom-drift propagation

When `_extracted-idioms.md` is modified between scan and execution, ledger rows that referenced the changed idioms may need re-evaluation. The scan + replan commands surface this:

**`/align-scan` detection**: at the end of every scan, the command compares `_extracted-idioms.md`'s git hash against the hash recorded in the prior scan's metadata (stored in `ai/align/_session-digest.md`). If the hash changed:
1. Scan runs as normal.
2. Output report includes a "Idiom drift detected" section listing:
   - Which idioms were added/removed/modified since last scan.
   - Which ledger rows cite those idioms (read `idiom_cited` field across the prior ledger).
   - Recommended action: re-run `/align-recheck` for affected rows OR `/align-replan --include-drifted`.

**`/align-replan --include-drifted`**: re-phases rows whose `idiom_cited` references a modified idiom. Rows whose status was `verified` flip to `detected` IF the cited idiom changed materially (renamed / signature change / removed); they stay `verified` if the change was cosmetic (rename of a comment, etc. — agent decides per-row).

**Validator**: `check_idiom_citation` (agent-side) compares the row's `idiom_cited` `<path:line>` against the current `_extracted-idioms.md`. A citation that no longer resolves halts the row at the next gate.

## Named anti-patterns

The names are load-bearing vocabulary: audits cite them, `/align-status` groups by them, `/align-final` counts them. Each carries a fingerprint and the check that catches it.

- **The Refactor in Disguise** — a finding whose fix introduces a new abstraction (not in `_extracted-idioms.md`), renames a public API, or changes observable behaviour where preservation was the contract. Looks like alignment in the ledger; ships as a redesign in PR review. Caught by: closure-verb vocabulary check + `check_no_new_symbols` (with idioms exemption) + coverage non-decrease (agent-side — not script-enforced).
- **The Trusted Summary** (inherited from migration) — agent says "looks duplicated" / "looks dead" / "looks reinvented" / "no security issues" without `<path:line>` evidence; executor echoes into the ledger. Caught by: `check_evidence_resolves` + audit halt #1.
- **The Hand-waved Finding** (inherited) — `~8 dead exports`, `several silent catches`, `multiple reinvented wrappers`, `a few missing auth gates`. Caught by: `check_no_handwaves` + audit halt #2.
- **The Net-Positive Cleanup** (structural) — fix imports a shared helper but doesn't delete the local copy; OR introduces a wrapper "to make the swap easier"; OR adds a comment explaining the new shape. Net lines go up on a structural row. Caught by: `check_net_lines_structural` + audit halt #5.
- **The Bundled Phase** — phase PR mixes 5 finding classes; reviewer can't localise regressions. Caught by: review-checklist row "PR title = single-class-or-domain"; reviewer responsibility.
- **The Stale Ledger** — a phase merges without updating ledger rows to `fixed`. Code grep claims "no more silent catches" but ledger rows are still `in-progress`. Caught by: gate check 1; `/align-status` reports stalled rows; `@align-ledger-auditor` reconciliation 3.
- **The Oracle Drift** — alignment PR also modifies `_extracted-idioms.md` / `ai/conventions.md` to "explain" the fix. Caught by: `check_oracle_unmodified` (the PR diff against the three oracle files must be empty) + gate check 9.
- **The Eternal Phase** — phase opens, 30+ findings detected, phase never closes because new findings keep getting added. Caught by: the batch ceiling (guard 2, ≤ 12 rows); excess routes to phase N+1 via `/align-replan`.
- **The Re-Detection Skip** — porter applies the fix and marks `status: fixed` without re-running the detector to confirm the fingerprint is gone. The fingerprint sometimes lingers (the fix targeted the wrong line). Caught by: VERIFY's mandatory re-detect; `check_evidence_resolves` re-run at gate.
- **The Silent Coverage Drop** — fix removes a branch; tests pass; but the branch was the only path exercising a downstream code path. Coverage drops 0.3%; nobody notices in a 1500-test suite. Caught by: gate check 7 (agent-side — not script-enforced); any drop beyond tolerance is a halt.
- **The Reinvented Idiom in Functional Verb** — porter writes a new validator schema, cache helper, escape function or gate wrapper inside an `add-validator` / `cache-with-explicit-ttl` / `escape` / `add-gate` fix. The functional verbs are supposed to USE the project's existing idiom; inventing one is Reinvented Wrapper on the functional side. Caught by: `check_added_lines_cite_idioms` + `check_no_new_symbols` + audit halts #6, #9, #10.
- **The Bare Security Fix** — porter adds a gate / validator / escape but no test asserting it works. Six months later a refactor removes the gate and nothing catches it. Caught by: `check_security_assertion_present` + gate check 12.
- **The Hopeful Perf Fix** — porter parallelises / batches / caches without measuring before or after. The fix may be a regression (`Promise.all` overwhelming a downstream service) and nobody knows, because there is no baseline. Caught by: `check_perf_baseline_present` + gate check 13.
- **The Lockfile-Only Bump** — `bump-dep` for a vulnerable dependency without running the test suite. The bump may carry a breaking change; the tests would catch it but nobody ran them. Caught by: VERIFY's mandatory test run.
- **The Tier Demotion** — porter sets a security row to trivial because "it's just one missing gate, easy fix". Caught by: audit halt #11 + `check_security_tier_minimum` + gate check 14.
- **The Behaviour Change Conflation** — a security gate that changes behaviour (denies unauth) bundled with an unrelated alignment fix in one commit; the security change becomes invisible in the diff. Caught by: review checklist + one-finding-per-commit.
- **The Cross-Class Phase** — phase PR mixes structural + security + perf rows. The net-lines rule is ambiguous across them and reviewer attention scatters. Caught by: `/align-plan`'s single-class-or-single-domain phasing.
- **The Frontend Regression Skip** — porter ignores an a11y / visual / bundle-size regression "because the fix was mechanical". Caught by: gate check 8 (agent-side — not script-enforced).
- **The Idiom Inventory Gap** — porter halts repeatedly because the idiom they need (validator, cache helper, gate wrapper) is absent from `_extracted-idioms.md`. The right move is to update the oracle once via `/setup-project --refine`, then resume — not to invent the idiom inline. Symptom: `ai/align/halts/` full of "missing idiom: X". Caught by: `@align-ledger-auditor`'s systemic-halt SLA (same halt reason on ≥ 3 rows).
- **The Silent Park** — a row is parked and never comes back: no `unpark_after`, no SLA ageing it, and on a `class: security` row the halted-row escalation clock stops the moment the status flips. Parking is deferral with a date, not closure. Caught by: `@align-ledger-auditor`'s parked SLA rows + `/align-final`'s per-class `PARTIAL` breakdown.

## Anti-bloat merge gates

The migration discipline rule's Phase 7 lesson — "~95% docs / ~5% code on simple ports" — applies double here. Alignment is *by definition* small atomic edits. A doc-heavy alignment run is a category error.

- **Code edits are the deliverable.** A doc that doesn't enable a code change is waste. Rationales / notes exist when they unblock a code decision; they are not deliverables themselves.
- **The closure-verb vocabulary is finite.** Two semantic groups:
  - **Structural verbs** (used by structural classes; net-lines ≤ 0): `remove`, `inline`, `dedupe`, `rename-comment-out`, `replace-with-shared`.
  - **Functional verbs** (used by functional classes; small + budget): `add-gate`, `parameterize`, `escape`, `move-to-secrets`, `add-validator`, `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `extract-to-shared`, `split-extract`, `inline-magic-to-named-const`, `inline-filter-to-query`, `bump-dep`, `rename`.
  A finding whose fix needs a verb outside this combined vocabulary IS NOT an alignment finding. Route to `/refactor` or `/setup-project --refine` instead. **No verb introduces a NEW abstraction not named in `_extracted-idioms.md`.** A `split-extract` that creates a brand-new abstraction (rather than splitting into responsibilities the project's idiom inventory already names) is forbidden.
- **Net-lines rule (split by class group):**
  - **Structural classes** — net-lines must be ≤ 0 per phase. Lines-removed ≥ lines-added across all structural findings, summed. A net-positive structural phase is a halt; the closure verb was applied wrong (likely a `replace-with-shared` that imported but didn't delete the local copy).
  - **Functional classes** — small + budget allowed (typically + 5 to + 30 lines per finding for security gates / validators / cache primitives / index migrations). The added lines MUST cite an idiom — every block of added lines references a `<path:line>` in `_extracted-idioms.md` (or the project's framework primitive) for what it's adding (the gate wrapper, the validator helper, the cache primitive, the safe deserializer). Validator: `check_added_lines_cite_idioms` walks the diff hunks and refuses any added block that doesn't cite an idiom.
  - **Cumulative phase rule** — for phases that mix structural + functional findings, the structural rows must net ≤ 0 AND the functional rows must each cite idioms. The phase's overall diff may net positive when functional findings dominate (a phase that adds 8 auth gates is + 16 lines net; that's allowed).
- **Per-finding enumeration is required at every tier.** Hand-waves (`etc.`, `...`, `and similar`, `N+ duplicates`, `several call sites`, `a few places`, `multiple endpoints`) HALT the gate. The validator's `check_no_handwaves` greps for these tokens. If 8 dead exports exist, the ledger lists 8 rows (or 1 row with 8 explicit `<path:line>` citations in `evidence`). Never `~8 dead exports`. Same applies to security findings: never `several missing auth gates` — each endpoint gets its own row.
- **Single-agent dispatch is the default.** Parallel sub-agents are heavy-tier-only AND require a deduplicated context blob (each sub-agent reading the project's full source independently is forbidden — same wasted-token pattern migration's Phase 7 fixed).
- **Findings cite source.** Every finding row has `evidence: <path:line>` for at least one fingerprint. If you can't cite source, the finding doesn't exist (Trusted-Summary failure mode).
- **Trivial-tier rows do not produce rationales.** The closure verb + the `<path:line>` evidence is the rationale. A trivial row whose `notes` field is filled with prose is over-production; the validator flags `notes_excess_chars > 200` on trivial rows. Note: security findings are NEVER trivial-tier — they always have rationale (≥ standard tier).

## Enforcement — gate behaviour, SLA clocks, anti-pattern → check

- **`/align-gate <N>`** halts on: any of the 14 phase-exit checks failing, any row's per-tier artifacts incomplete, any net-positive line count on structural rows, any functional row whose added lines don't cite an idiom, any `halted` row, any security row without an assertion, any perf row without a baseline / assertion.
- **`/align-status`** reports per-finding state and flags rows older than the SLA (default: a row in `in-progress` for >7d is flagged stalled; a security row halted for >24h is flagged escalated).
- **Validator script** `scripts/validate-align-artifacts.sh` operationalises the enforcement of the named anti-patterns (11 of 14 checks are script-enforced; the 3 tagged `(agent-side — not script-enforced)` below require runtime tooling and run agent-side):
  - "Hand-waved enumeration" → `check_no_handwaves` greps for hand-wave tokens.
  - "Reinvented Wrapper in fix" → `check_no_new_symbols` runs `git diff --diff-filter=A` against the alignment PR and fails on new public exports NOT named in `_extracted-idioms.md`.
  - "Net-positive line count on structural row" → `check_net_lines_structural` measures diff for structural-class rows and fails if `+>−`.
  - "Functional add without idiom citation" → `check_added_lines_cite_idioms` parses each added hunk and validates that the row's `idiom_cited` resolves AND covers the added lines (the cited idiom file appears in the diff's import lines OR the added block calls the named symbol).
  - "Behaviour change" → `check_test_coverage_nondecreasing` (agent-side — not script-enforced) runs the test suite + coverage, fails if either regresses (with security-row exception: coverage may shift; absolute % must not drop).
  - "Trusted Summary" → `check_evidence_resolves` validates every row's `evidence` is a real `<path:line>` containing the claimed fingerprint.
  - "Scope creep" → `check_scope_boundary` runs `git diff --name-only` and fails if touched files are outside any row's `scope`.
  - "Security row without assertion" → `check_security_assertion_present` for each security row, looks for a co-committed test file change that asserts the gate / validator / escape; fails if absent.
  - "Perf row without baseline" → `check_perf_baseline_present` for each perf row, looks for a `notes` field containing baseline numbers (latency / queries / HTTP) OR a co-committed observability annotation; fails if absent.
  - "Oracle modification" → `check_oracle_unmodified` runs `git diff` against `_extracted-idioms.md` / `ai/conventions.md` / `ai/architecture.md`; fails if non-empty.
  - "Frontend regression" → `check_frontend_regressions` (agent-side — not script-enforced) (when `PROJECT_KIND in {frontend-*}`) runs scoped a11y / visual / bundle-size; fails on regression.

## Automation hooks

- `/align-scan` applies guards 1, 3, 4, 5, 6 (scan posture), 8; writes deferred fingerprints to `ai/align/_deferred.md`.
- `/align-plan` and `/align-replan` apply guard 2.
- `/align-phase` and `/align-fast` apply guards 4, 6, 7.
- `/align-gate <N>` refuses on guards 4 and 6; reads guard lines from the phase's reports and requires each named guard to appear in the row's `notes` when it changed what was examined.
- `@align-ledger-auditor` groups halts by anti-pattern name; `/align-final` counts them.

## See also

- `align-discipline.md` — the rule these guards and names serve; the 11 per-finding halts and the tier floor live there.
- `align-ledger.md` (sibling pattern) — the row schema and state machine the guards annotate.
- `detect-drift` skill — the 11 universal detectors the scan guards bound.
- `/align-status` — surfaces guard-fired rows and parked-row ageing.
