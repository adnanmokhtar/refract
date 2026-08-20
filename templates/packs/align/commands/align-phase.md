---
description: Executes one alignment phase. For each finding in the phase: DETECT (re-verify fingerprint) → DECIDE (closure verb) → FIX (apply edit) → VERIFY (lint + typecheck + tests + re-detect) → RECORD (update ledger). One commit per finding. Net-lines ≤ 0 per phase. Stack-agnostic.
kind: command
pack: align
---

# /align-phase <N>

## The Premise (read this first, internalize, do not deviate)

**Discipline pointer:** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) — SOLID / clean-code closure vocabulary (single source of truth).

**The gold-standard inventory is the truth.** `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md` define the intended shape of the codebase. Every finding is a deviation; every fix moves toward the intended shape. The closure verbs are mechanical (`remove` / `inline` / `dedupe` / `rename-comment-out` / `replace-with-shared`) — alignment is an entropy reducer, not a designer.

**The agent's job is exactly this:**
1. For each finding in phase N, re-verify the fingerprint is still present (it can age out — another PR may have already fixed it).
2. Apply the closure verb mechanically. No new abstractions. Net-lines ≤ 0.
3. Verify: lint + typecheck + scoped tests + re-detect — all four must pass before the row flips to `fixed`.
4. Record one commit per finding; update the ledger row.

**The agent does NOT:**
- Ask the user to validate whether the convention is correct. **The oracle (`_extracted-idioms.md`) IS the validation.**
- Ask the user about cosmetic deviations. The closure verb is in the ledger; apply it.
- Surface "do you want option A, B, or C" prompts mid-run. The closure verb is decided at scan time.
- Draft an ADR to legitimize a deviation that should be aligned. The fix is the alignment.

**The agent ONLY asks the user when:**
- The fix would change observable behaviour (re-categorise as refactor; route elsewhere).
- The shared equivalent named in `_extracted-idioms.md` doesn't exist (oracle drift; halt).
- A heavy-tier finding's impact analysis surfaces a consumer the planner missed.

That's it. Three escalation triggers. Everything else is silent mechanical edits, batched into one end-of-phase summary.

**Heavy-tier rows are different.** Heavy findings (cross-package boundary, public API change, > 10 files, auth/data/billing/migration touch) require reviewer approval before merge AND a single-finding-per-commit-per-PR review window. The phase batches trivial + standard rows into one PR; heavy rows ship as separate PRs within the phase, each with its own impact analysis.

## When to use

- Default for executing a single phase from `/align-plan`.
- After `/align-rollback <N>` if you want to manually re-run rather than auto-resume.
- For supervision-required phases (heavy-tier rows; user wants to review per-row).

Use `/align-fast <N>` instead when you want one command to drive the whole phase + gate without human-watch pauses. Mirrors `/migration-fast` — runs one phase per invocation; scan + plan must have run already.

## The loop (5 steps per finding)

For each ledger row in phase N (in dependency order — helper-introduce before consumer-swap; remove-callers before remove-wrapper):

### 1. DETECT — re-verify the fingerprint

Re-read the row's `evidence` lines. Confirm the fingerprint pattern still matches at the cited `<path:line>`. Possible outcomes:

- **Fingerprint present** → proceed to step 2.
- **Fingerprint gone** (another PR already fixed it) → mark `status: archived-pre-existing`; record `archived_at` + `archived_reason: "fingerprint absent at re-detect"`; skip to next row.
- **Fingerprint moved** (file refactored; same fingerprint at a different line) → update `evidence` to the new line; proceed to step 2.
- **Evidence file deleted** → mark `status: archived-pre-existing`; record `archived_reason: "scope file deleted"`; skip.

Halts:
- Any row's `evidence` cites a `shared_equivalent` that doesn't exist (oracle drift) → halt; route to `/setup-project --refine`; mark row `status: halted`.
- Any row whose tier was promoted between scan and execution (e.g., `evidence` count grew) without a justification → halt; demand 1-line `notes` then resume.

### 2. DECIDE — confirm closure verb is mechanical

**Dispatch `@align-idiom-auditor` before applying the edit, and again at VERIFY once the diff exists.** It is the artifact that owns the invention boundary — the DECIDE call answers "is the idiom this verb needs actually in the oracle?", the VERIFY call answers "did the diff route through it, or write a new one?". A `HALT — idiom inventory gap` at DECIDE stops the row before any edit lands, which is the cheap end of the halt; catching the same thing at VERIFY costs a revert. Where agent dispatch is unavailable, run the four checks inline — they are `align-discipline.md` audit halts #6, #9, #10 plus the oracle-unmodified check.

Confirm:
- Closure verb is in the closed **21-verb vocabulary** defined in `align-discipline.md` — **5 structural** `{remove, inline, dedupe, rename-comment-out, replace-with-shared}` OR **16 functional** (`add-gate`, `add-validator`, `parameterize`, `escape`, `move-to-secrets`, `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `extract-to-shared`, `split-extract`, `inline-magic-to-named-const`, `inline-filter-to-query`, `bump-dep`, `rename` — the security / performance / SOLID / clean-code / unhandled-io set). A verb in neither set → halt; the fix is a refactor / redesign / feature, route elsewhere.
- Net-lines rule **by group**: **structural** edits are behaviour-preserving with net-lines ≤ 0 (mechanical; touched files have test coverage). **functional** edits are small + line-budgeted — their added lines MUST cite an existing idiom from `_extracted-idioms.md` (never invent a new gate / validator / cache helper) and ship the required assertion (security gate → gating test; `parallelize` → perf assertion; `add-index` → EXPLAIN ANALYZE capture). The row's class must be in the universal or per-stack taxonomy — not "bug", not "feature" (those route to `/fix-bug` / `/add-feature`).
- For `replace-with-shared`: the `shared_equivalent` resolves to an existing file in `_extracted-idioms.md`'s named inventory. If not, halt (route to `/setup-project --refine`).
- For `inline`: confirm the wrapper has exactly one consumer site (re-grep at decide time). If 2+ consumers found, the row was mis-classified; route to `/refactor` instead.
- For `remove` on a class symbol: re-grep the entire repo for the symbol; if any inbound import found, the row was mis-classified; halt.

### 3. FIX — apply the closure-verb edit

The verb-specific procedures live in `.claude/references/align-discipline-procedures.md § Closure-verb procedures`. The 21 verbs split into structural (5) + functional (16). Summary:

**Structural verbs (net-lines ≤ 0 per row):**

| Verb | Procedure (one-line summary) |
|---|---|
| `remove` | Delete cited lines / export. Re-grep post-delete; any remaining inbound import = halt + revert. |
| `inline` | Substitute wrapper body inline at single call site; delete wrapper. Re-grep for wrapper symbol post-delete. |
| `dedupe` | Replace each non-canonical copy with the canonical from `_extracted-idioms.md`. Re-grep residual usage. |
| `rename-comment-out` | Delete cited comment line(s). No code change. |
| `replace-with-shared` | Replace local fingerprint with named `shared_equivalent` import + call. Preserve other props. |

**Functional verbs (small + budget; added lines must cite `idiom_cited`):**

| Verb | Procedure (one-line summary) | Class | Budget |
|---|---|---|---|
| `add-gate` | Wrap protected route/action with the project's auth gate (named in `_extracted-idioms.md`). + assertion test. | security | + 2–5 |
| `parameterize` | Convert string concat / template SQL to parameterized using the project's DB primitive. | security | ≈ 0 |
| `escape` | Wrap user output with the project's escape helper. | security | + 1–2 |
| `move-to-secrets` | Replace inline secret with config/env reference. **Rotate the leaked secret out-of-band** (separate ticket). | security | ≈ 0 |
| `add-validator` | Wrap input handler with the project's validator (Joi/Zod/etc. named in `_extracted-idioms.md`). + assertion test. | security | + 5–15 |
| `parallelize` | Replace sequential `await` loop with `Promise.all` / `gather`. Confirm independence + add the project's rate-limiter for external services. | performance | ≈ 0 or − |
| `batch` | Replace per-item query with batch query (`getByIds`). | performance | − |
| `project-columns` | Replace `SELECT *` with explicit column list. | performance | + per query, − bandwidth |
| `add-index` | Add reversible migration. Run `EXPLAIN ANALYZE`; record cost reduction in `notes`. | performance | + (migration) |
| `cache-with-explicit-ttl` | Wrap with project's caching primitive. Set TTL + invalidation rule. | performance | + 3–5 |
| `extract-to-shared` | Move duplicated block to PRE-NAMED idiom in `_extracted-idioms.md`. **Forbidden to extract to a new helper.** | clean-code, SOLID | − cumulative |
| `split-extract` | Split multi-responsibility class into PRE-NAMED responsibilities. **Forbidden to split into new abstractions.** | SOLID (SRP) | + first, − after |
| `inline-magic-to-named-const` | Replace magic with named const from project's constants module. | clean-code | + 1 (one-time const) |
| `inline-filter-to-query` | Push in-app `.filter()` to database `WHERE`. | performance | ≈ 0 |
| `bump-dep` | Update version per security advisory. Run lockfile + tests. | security (vuln-dep) | + 0 (lockfile only) |
| `rename` | Apply project's naming convention. Update consumers if public symbol. | clean-code | ≈ 0 |

**Touch only files in `scope`.** If the fix needs to touch a file not in `scope`, halt; the row was mis-scoped at scan time.

**Net-lines rule (split by class group):**
- **Structural row** — diff ≤ 0 (with one allowed exception: the FIRST `replace-with-shared` site in a multi-site row may net positive if it adds the shared import; subsequent sites must net negative; cumulative must be ≤ 0).
- **Functional row** — small + allowed; every block of added lines MUST cite the row's `idiom_cited` reference. Validator: `check_added_lines_cite_idioms` walks the diff hunks and refuses any added block that doesn't cite an idiom (the cited idiom file appears in the diff's import lines OR the added block calls the named symbol).

**No new abstractions.** Even functional verbs use the project's PRE-NAMED idioms — never invent a new validator schema, gate wrapper, cache helper, escape function, or service responsibility class. If the idiom needed doesn't exist, halt; route to `/setup-project --refine` to add it to `_extracted-idioms.md` first.

### 4. VERIFY — universal checks + class-specific assertions

**Universal (every row):**
1. **Lint + typecheck on touched files** — using project commands from `_extracted-idioms.md` / `ai/stack.md`. Any error = halt + revert.
2. **Scoped tests** — `<test-runner> <touched-files>` (or the project's test-by-file pattern). Any failure = halt + revert.
3. **Re-detect at evidence lines** — re-run the detector that surfaced this row, scoped to the row's `scope`. Detector MUST return 0 hits at the cited evidence lines. Any remaining hit = the fix didn't actually close the fingerprint; halt + revert.
4. **Coverage** — run scoped coverage; coverage % MUST NOT drop **beyond the tolerance threshold** (default: 0.5%; configurable per project in `ai/conventions.md § Coverage`). A drop within tolerance is sample fluctuation, not a real regression. A drop beyond tolerance is a halt — the closure removed a load-bearing branch. See `align-discipline.md § Realism guards § Coverage tolerance`.

**Class-specific (additional checks based on row's class):**

*For security rows:*
5. **Security assertion present** — touched test files include an assertion that exercises the new gate / validator / escape:
   - `add-gate` → test: unauth caller gets 401/403; auth caller gets 200.
   - `add-validator` → test: malformed input returns 400; valid input passes.
   - `escape` → test: known-XSS payload renders as escaped string.
   - `parameterize` → test: query log shows parameterised execution OR a known-injection payload returns 400.
   - `move-to-secrets` → test: env-var substitution works; the inline literal is gone (re-grep).
   - `bump-dep` → existing test suite still passes (lockfile bump should be transparent).

*For perf rows:*
6. **Perf assertion or observability annotation present** —
   - `parallelize` / `batch` → test: query count or wall-clock for a representative input is in expected range.
   - `cache-with-explicit-ttl` → test: cache hit on second call; TTL respected.
   - `add-index` → `EXPLAIN ANALYZE` output captured in `notes`; query plan uses the new index.
   - `project-columns` → test that asserts the response shape still matches the consumer's expectation.

*For frontend UI/UX rows:*
7. **a11y regression** — scoped a11y check (`axe` / `pa11y` on touched routes). a11y score MUST NOT drop.
8. **Visual regression** — scoped snapshot diff. Diffs reviewed and accepted before commit (or auto-accepted if the row's closure verb is `replace-with-shared` for a design-token swap and the snapshot config includes a token-swap allowance).
9. **Bundle-size delta** — for swaps that touch import paths, scoped bundle-size check. Size MUST NOT increase by > 1% per row.

*For functional rows that ADD lines:*
10. **Idiom citation** — the added line block(s) reference the row's `idiom_cited` value (the cited idiom file appears in the diff's import lines OR the added block calls the named symbol from the idiom). Validator: `check_added_lines_cite_idioms`.

### 5. RECORD — update the ledger row + commit

- Update ledger row:
  - `status: fixed`
  - `fixed_at: <iso-timestamp>`
  - `commit: <git sha>`
  - `gaps_closed: <N>` (must equal `len(evidence)` — gap-count parity rule)
  - `notes: ""` (trivial) OR `<≤200 char rationale>` (standard) OR full `impact_analysis_path: ai/align/impact/<id>.md` (heavy)
- Commit: `align/<phase-N>/<row-id>: <one-line description>` — one finding per commit. Body cites the evidence and closure verb.
- Halt rows are committed separately (or not at all) and surfaced in the end-of-phase summary; never bundled into "fixed" commits.

If any step fails: mark row `status: halted`; write `ai/align/halts/<row-id>.md` with the specific failure + remediation steps; do NOT advance the row.

## Phase-end batched summary

After all rows in phase N have been processed, surface ONE summary to the user:

```
Phase <N> — <theme> — complete

Findings processed:           <N>
  Fixed:                      <F>
  Archived (pre-existing):    <A>
  Halted:                     <H>
  Parked (via /align-park):   <P>

Cumulative diff:
  Lines added:                <added>
  Lines removed:              <removed>
  Net:                        <net> (must be ≤ 0)

Mechanical:
  Lint:                       PASS
  Typecheck:                  PASS
  Scoped tests:               PASS (<X> tests, <Y>ms)
  Coverage:                   <pre>% → <post>% (no drop)

(Frontend phases only)
  a11y regression:            PASS (score: <pre> → <post>)
  Visual regression:          <N> diffs accepted
  Bundle-size delta:          <pre>KB → <post>KB (Δ <%>)

Halts (require resolution before /align-gate):
  <row-id>: <reason>
  ...

Next:
  /align-gate <N>             (validates artifacts; advances phase)
  /align-park <id> <reason>   (park a halted row)
  /align-rollback <N>         (undo this phase if rethink needed)
```

## Project-specific anchors

> - **Test runner**: `<extracted>` (e.g., `vitest`, `pytest`)
> - **Lint command**: `<extracted>`
> - **Typecheck command**: `<extracted>`
> - **Coverage command**: `<extracted>`
> - **a11y check command** (frontend): `<extracted>`
> - **Visual regression command** (frontend): `<extracted>`
> - **Bundle-size command** (frontend): `<extracted>`
> - **Detector commands per class**: `<extracted from /align-scan's per-class dispatch>`

## Pre-flight checks (before starting the loop)

1. `/align-plan` has been run; `ai/align/plan.md` exists; phase N exists in plan.
2. Mechanical pass: `lint`, `typecheck`, `build`, `tests` — all green at HEAD. If red, halt; pre-existing red drowns alignment changes.
3. No uncommitted changes in working tree (`git status --porcelain` empty). If dirty, halt; user-error.
4. Current branch is NOT main / master (or is, with explicit `--allow-main` flag — risky default).
5. Findings ledger has rows with `phase: <N>` and `status: detected`. If 0 rows, halt; nothing to do.
6. Rows are listed in dependency order in the plan. The command processes rows in that order.

If any pre-flight fails → halt + report.

## Optional flags

- `--dry-run` — run DETECT only, report what would happen, no edits. Useful for sanity-checking before committing to the phase.
- `--start-from=<row-id>` — resume from a specific row (e.g., after manual halt resolution).
- `--stop-on-halt` — halt the entire phase on the first row halt. Default: continue with remaining rows; surface all halts at the end.
- `--heavy` — require single-finding-per-commit + reviewer approval prompt for every row in the phase (default: auto-applied to heavy-tier rows only; this flag forces it for all rows).
- `--max-parallel=<N>` — cap parallel row processing (default: 1 = sequential; for routine mechanical phases, the user may set 3–5 for parallelisable rows). Per-file lock: rows with overlapping `scope` files always serialise to prevent races. See `align-discipline.md § Realism guards § Parallel race serialization`.

## Mechanical halt — refuse to violate the closure-verb vocabulary

Forbidden in this command:
- Introducing any new symbol (function / class / type / interface / file). Validator `check_no_new_symbols` runs after each row's commit.
- Net-positive line count for any single row OR for the phase cumulative.
- Touching files outside the row's `scope`.
- Skipping VERIFY steps.
- Bundling multiple findings in one commit.
- Modifying gold-standard files (`_extracted-idioms.md`, `ai/conventions.md`, `ai/architecture.md`).
- Asking the user about cosmetic deviations (the closure verb is decided at scan time).
- Marking a row `fixed` when `gaps_closed != len(evidence)` (gap-count parity).
- Marking a row `fixed` without re-detect returning 0 hits.

Each halt writes `ai/align/halts/<row-id>.md` and surfaces in the end-of-phase summary. The phase cannot advance through `/align-gate` until every halt is resolved (fixed manually, parked via `/align-park`, or rolled back via `/align-rollback`).

## Hard rules

- **Closure verbs are mechanical-ish.** Structural verbs are pure mechanical (no behaviour change). Functional verbs may change behaviour intentionally (security gates deny unauth, perf changes wall-clock) — the change is documented + tested in the same commit.
- **No new abstractions.** Functional verbs USE the project's PRE-NAMED idioms; inventing new ones is forbidden.
- **Net-lines rule by class group:** structural ≤ 0 per row; functional small + with idiom citation.
- **One finding = one commit.** Bundling hides regressions and conflates intentional behaviour change with mechanical fixes.
- **Re-detect after every fix.** A fix that doesn't actually close the fingerprint is a halt.
- **Coverage non-decreasing.** A removed branch was either dead (coverage same) or load-bearing (coverage drops; halt). Security rows may shift coverage due to intentional change; absolute % must not drop.
- **Security and perf rows ship with assertions / baselines.** No bare gate; no hopeful parallelize.
- **For frontend phases: a11y, visual, bundle-size all green.** UI/UX regressions are user-visible regressions.
- **No oracle modification.** Gold standards stay read-only in this command.
- **Heavy-tier rows reviewed before merge.** The reviewer's name + timestamp goes in the ledger row's `notes`. Critical security ALWAYS heavy.
- **Idiom citation for functional adds.** Every added line block cites the row's `idiom_cited`.

## Failure modes

- **Pre-existing mechanical red** — fix mechanical first via `/check-health`.
- **Detector tool unavailable mid-run** — re-detect needs the tool; halt all remaining rows; surface install command.
- **Test suite is slow** — scoped tests preferred over full suite; if scoping isn't possible, halt and configure the project's test-by-file pattern.
- **Visual regression baseline drift** — scoped snapshot diffs surface unrelated diffs from a sibling PR; halt; baseline-refresh required first.
- **Mid-row commit hook fails** — pre-commit hook (lint / format / etc.) modifies files; treat as part of FIX (re-run VERIFY after hook); if hook fails non-deterministically, halt the row.
- **Heavy row needs cross-repo change** — halt; route to `/cross-repo-task`; mark `status: halted` with `reason: cross-repo`.
- **Reviewer not available for heavy row** — halt the heavy row only (continue trivial / standard rows); surface in end-of-phase summary.

## Related

### Agents
- `.claude/agents/align-idiom-auditor.md` — dispatched at DECIDE and again at VERIFY per row; owns audit halts #6, #9, #10 and the enforce-existing-vs-introduce-new boundary.
- `.claude/agents/align-gate-auditor.md` — runs after this command via `/align-gate <N>`; its 14-check matrix is what this command's rows are being prepared for.

### Sibling commands in align pack
- `/align-scan` — runs first; produces the inputs.
- `/align-plan` — runs before this command; produces the phased plan.
- `/align-gate <N>` — runs after this command; validates artifacts and advances the phase.
- `/align-fast <N>` — one-shot variant (this command + gate, no human-watch pauses).
- `/align-park <id> <reason>` — park a halted row.
- `/align-rollback <N>` — undo this phase.
- `/align-status` — read-only progress reader.

### Skills
- `.claude/skills/find-and-align/SKILL.md` — the per-finding loop dispatched per row.
- `.claude/skills/detect-drift/SKILL.md` — re-detect procedure.

### Cross-pack references
- `code-quality/commands/simplify.md` — closure-verb vocabulary inherited.
- `code-quality/agents/dead-code-finder.md` — re-detect dispatch for dead-code rows.
- `code-quality/agents/refactorer.md` — re-detect dispatch for over-abstraction rows.
- `frontend/agents/accessibility-auditor.md` — re-detect dispatch for a11y rows.
- `frontend/agents/i18n-auditor.md` — re-detect dispatch for i18n rows.
- `ui-ux/skills/design-token-audit/SKILL.md` — re-detect dispatch for token rows.

### Rules
- `.claude/rules/align-discipline.md` — the discipline this command enforces.

### Patterns
- `ai/patterns/align-ledger.md` — schema for the ledger this command updates.
