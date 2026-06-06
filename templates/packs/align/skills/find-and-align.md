---
description: Per-finding fix loop for codebase alignment. DETECT → DECIDE → FIX → VERIFY → RECORD. One commit per finding. Net-lines ≤ 0 for structural rows; small + budget for functional rows (added lines must cite idioms). Stack-agnostic. Used by /align-phase, /align-fast.
kind: skill
pack: align
---

# Skill: find-and-align

## Purpose

Drive a single finding through the 5-step fix loop: DETECT → DECIDE → FIX → VERIFY → RECORD. Behaviour-preserving for structural rows; behaviour-changing-but-tested for security / perf rows.

This skill is the **fix** half of alignment. The detect half is `detect-drift`.

## When to use

- Dispatched by `/align-phase` per row.
- Dispatched by `/align-fast` per row (in parallel waves).

## Inputs (precise contract)

| Input | Source | Required |
|---|---|---|
| `row` (single ledger row) | `ai/align/ledger.md` | YES |
| `shared_context_blob` (≤ 5K tokens; idioms summary + conventions summary + architecture summary) | Built by orchestrator; passed by reference | YES |
| `PROJECT_KIND` | `_extracted-codebase.md § Gold standards` | YES |
| Test runner / lint / typecheck commands | `_extracted-idioms.md` / `ai/stack.md` | YES |
| Coverage tolerance (default 0.5%) | `ai/conventions.md § Coverage` | NO (defaults applied) |
| Per-class detector tool | Project anchors | YES (for re-detect at VERIFY) |

Row schema (the input the orchestrator passes per dispatch):

```yaml
id: A047                                    # stable id from scan
class: security                             # one of 11 universal named classes + stack-specific
subclass: missing-auth-gate                 # optional sub-classification
severity: high                              # security only: low | medium | high | critical
scope: [src/routes/admin/export.ts]         # files the fix may touch (others = halt)
evidence: [src/routes/admin/export.ts:12]   # at least 1 <path:line>
closure_verb: add-gate                      # one of 21 verbs
idiom_cited: src/auth/gates.ts:7            # required for functional verbs that add lines
tier: standard                              # trivial | standard | heavy
status: detected | in-progress | halted     # entry states; loop transitions to fixed/halted/archived
notes: ""                                   # per-tier rationale
```

## Outputs (precise contract)

A row-update for the ledger (one of three terminal states):

```yaml
# Outcome A: fixed
id: A047
status: fixed
fixed_at: <iso-timestamp>
commit: <git-sha>
gaps_closed: <N>                            # MUST equal len(evidence)
notes: "<rationale per tier — security rows MUST cite threat + test added>"
# (security only): test_added_path: <path:line>
# (perf only): baseline + delta in notes
```

```yaml
# Outcome B: halted
id: A047
status: halted
halted_at: <iso-timestamp>
halt_reason: <one of: missing-idiom | shared-equivalent-missing | re-detect-failed | scope-creep |
              new-symbol | net-positive-structural | functional-no-citation | test-failure |
              coverage-drop | mis-classified | a11y-regression | visual-regression |
              bundle-regression | reviewer-pending | cross-repo>
halt_path: ai/align/halts/A047.md           # file with full remediation
```

```yaml
# Outcome C: archived (fingerprint absent)
id: A047
status: archived-pre-existing
archived_at: <iso-timestamp>
archived_reason: "fingerprint absent at re-detect" | "scope file deleted"
```

Plus side effects:
- One git commit per fixed row (subject: `align/<phase-N>/<id>: <description>`).
- On halt: `ai/align/halts/<id>.md` with structured remediation note.
- Heavy-tier row: pause for reviewer approval before flipping `fixed`; reviewer name + timestamp recorded in `notes`.

## The 5-step loop

### Step 1: DETECT — re-verify fingerprint

1. Re-read each `<path:line>` in the row's `evidence`. Confirm the fingerprint pattern still matches at that line.
2. Possible outcomes:
   - **Fingerprint present** at all evidence lines → proceed to step 2.
   - **Fingerprint gone** (another PR fixed it) → return `archived-pre-existing` outcome with note "fingerprint absent at re-detect".
   - **Fingerprint moved** (file refactored; same fingerprint at different line) → update `evidence` to new line; proceed.
   - **Evidence file deleted** → return `archived-pre-existing` with note "scope file deleted".

3. Halt conditions:
   - Row's `class` is functional AND `idiom_cited` doesn't resolve → halt with reason "missing idiom"; route to `/setup-project --refine`.
   - Row's `class` is `replace-with-shared` AND `shared_equivalent` doesn't resolve → halt with reason "missing shared equivalent".
   - Row's tier was promoted between scan and execution (e.g., evidence count grew) without justification in `notes` → halt; demand 1-line `notes` then resume.

### Step 2: DECIDE — confirm closure verb is mechanical-or-tested

1. Confirm closure verb ∈ vocabulary (21 verbs across structural + functional groups).
2. Confirm fix is appropriate to row's class:
   - Structural classes (dead-code, dups, reinvented, silent-catch, over-abstraction, drift) use structural verbs (`remove`, `inline`, `dedupe`, `rename-comment-out`, `replace-with-shared`); behaviour MUST be preserved.
   - Functional classes (SOLID, clean-code, performance, security) use functional verbs; behaviour may change intentionally for security / perf — the change is documented + tested in the same commit.
3. For `replace-with-shared`: re-confirm `shared_equivalent` exists in `_extracted-idioms.md` (not just in the codebase — the inventory must name it).
4. For `inline`: re-grep call sites; if 2+ found, the row was mis-classified; halt and route to `/refactor`.
5. For `remove` on exported symbol: re-grep inbound imports; if any found, the row was mis-classified; halt.
6. For functional verbs that add lines: confirm `idiom_cited` resolves AND covers the planned added lines.

### Step 3: FIX — apply the closure-verb edit

Apply the verb-specific procedure (see `align-discipline.md § Closure-verb procedures`). Summary by verb:

#### Structural verbs (net-lines ≤ 0 per row)

```
remove                  → delete cited lines / export
inline                  → substitute wrapper body inline; delete wrapper
dedupe                  → replace non-canonical copies with canonical from idioms
rename-comment-out      → delete cited comment line(s)
replace-with-shared     → replace local fingerprint with named shared_equivalent
```

#### Functional verbs (small + budget; cite idiom)

```
add-gate                → wrap with project's auth gate; add gate-deny test
parameterize            → convert string concat SQL to parameterized
escape                  → wrap user output with project's escape helper
move-to-secrets         → replace inline secret with config/env reference
add-validator           → wrap input handler with project's validator; add reject test
parallelize             → replace sequential await with Promise.all/gather
batch                   → replace per-item query with batch query
project-columns         → replace SELECT * with explicit column list
add-index               → add reversible migration; capture EXPLAIN ANALYZE
cache-with-explicit-ttl → wrap lookup with project's caching primitive
extract-to-shared       → move duplicated block to PRE-NAMED idiom
split-extract           → split multi-responsibility class into PRE-NAMED responsibilities
inline-magic-to-named-const → replace magic with named const
inline-filter-to-query  → push in-app filter to database WHERE
bump-dep                → update version per security advisory; run lockfile + tests
rename                  → apply project's naming convention
```

Constraints:
- Touch only files in `scope`. If the fix needs to touch a file not in `scope`, halt; the row was mis-scoped.
- For structural rows: cumulative diff ≤ 0 (with first `replace-with-shared` import exemption).
- For functional rows: every added line block cites `idiom_cited` (the cited idiom file appears in the diff's import lines OR the added block calls the named symbol).
- No new symbol introduced UNLESS the symbol is named in `_extracted-idioms.md`.

### Step 4: VERIFY — universal + class-specific assertions

**Universal (every row):**
1. Lint + typecheck on touched files. Any error = halt + revert.
2. Scoped tests (`<test-runner> <touched-files>`). Any failure = halt + revert.
3. Re-detect at evidence lines (re-run the detector that surfaced this row, scoped to row's `scope`). Detector MUST return 0 hits at cited evidence lines. Any remaining hit = the fix didn't close the fingerprint; halt + revert.
4. Coverage (scoped). Coverage % MUST NOT drop. Security rows: coverage may shift; absolute % must not drop.

**Class-specific:**

*Security rows* (5):
- Touched test files include an assertion exercising the security closure (gate denies, validator rejects, escape neutralises, parameterised query executes, secret literal is gone).
- Re-grep for the original fingerprint (e.g., the inline secret literal) confirms it's removed.

*Performance rows* (6):
- Touched test files include a perf assertion (query count, wall-clock, cache hit) OR `notes` references an observability dashboard annotation.
- Baseline captured pre-fix is in `notes`; post-fix delta is documented.
- For `add-index`: `EXPLAIN ANALYZE` output is in `notes`; query plan uses the new index.

*Frontend UI/UX rows (PROJECT_KIND=frontend-*):*
- a11y: scoped a11y check on touched routes — score MUST NOT drop.
- Visual: scoped snapshot diff — diffs reviewed and accepted (or auto-accepted for design-token swaps with allowance configured).
- Bundle-size: delta ≤ +1% per row.

*Functional rows that add lines:*
- Each added line block cites `idiom_cited` (validator: `check_added_lines_cite_idioms`).

### Step 5: RECORD — update ledger + commit

1. Update ledger row:
   - `status: fixed`
   - `fixed_at: <iso-timestamp>`
   - `commit: <git sha>` (one finding = one commit)
   - `gaps_closed: <N>` (= number of evidence lines actually closed; must equal `len(evidence)`)
   - `notes`:
     - Trivial structural: `""` (closure verb + evidence is sufficient).
     - Standard: 1-paragraph rationale (≤ 200 chars).
     - Heavy: full rationale + `impact_analysis_path: ai/align/impact/<id>.md`.
     - Security: rationale cites the threat addressed + the test added (mandatory).
     - Perf: rationale cites the baseline + delta (mandatory).

2. Commit format:
   - Subject: `align/<phase-N>/<row-id>: <one-line description>`
   - Body cites evidence + closure verb + (security only) test added + (perf only) baseline.

3. Halt rows: write `ai/align/halts/<id>.md` with:
   - The specific failure (which step failed).
   - The remediation (re-run the verb / re-classify / `/setup-project --refine` / `/align-park`).
   - DO NOT advance the row.

## Halt conditions (consolidated)

| Step | Halt | Remediation |
|---|---|---|
| DETECT | Fingerprint not present at evidence lines | Mark `archived-pre-existing` |
| DETECT | `idiom_cited` doesn't resolve | Route to `/setup-project --refine` |
| DETECT | `shared_equivalent` doesn't resolve | Route to `/setup-project --refine` |
| DECIDE | Closure verb not in vocabulary | Re-classify; route to `/refactor` |
| DECIDE | Inline target has > 1 consumer | Re-classify; route to `/refactor` |
| DECIDE | Remove target has inbound imports | Re-classify; row was mis-scoped |
| FIX | Diff touches files outside `scope` | Halt; row mis-scoped at scan |
| FIX | New symbol introduced (not in idioms) | Halt; route to `/setup-project --refine` OR re-classify |
| FIX | Structural row net-positive | Halt; revert; verb applied wrong |
| FIX | Functional row added lines without idiom citation | Halt; route to `/setup-project --refine` |
| VERIFY | Lint / typecheck error | Halt + revert |
| VERIFY | Test failure | Halt + revert |
| VERIFY | Re-detect still finds fingerprint | Halt + revert; verb didn't close |
| VERIFY | Coverage drop (non-security) | Halt + revert; "dead" code wasn't dead |
| VERIFY | Security row missing assertion | Halt; add assertion in same commit |
| VERIFY | Perf row missing baseline / assertion | Halt; capture baseline + assert |
| VERIFY | Frontend a11y / visual / bundle regression | Halt + revert; or accept diff |
| RECORD | `gaps_closed != len(evidence)` | Halt; row not done |

## Hard rules

- **One finding = one commit.** No bundling.
- **Closure verbs are the closed vocabulary of 16.** No invention.
- **No new abstractions.** Use idioms; if the idiom is missing, route to `/setup-project --refine`.
- **Net-lines ≤ 0 for structural; small + cite-idiom for functional.**
- **Re-detect after fix.** Re-running the detector is mandatory; the gap-count parity rule (`gaps_in == gaps_closed`) enforces this.
- **Tests must pass; coverage must not drop.**
- **Security and perf rows ship with assertions / baselines, in the same commit.**

## Notes

- This skill is **per-row**. Multi-row orchestration is the orchestrator's responsibility.
- This skill is **idempotent on halts**. Re-running on a halted row will re-attempt; if the underlying issue isn't resolved, it halts again.
- This skill respects `--dry-run` (DETECT only; no edits).
- For heavy-tier rows: this skill pauses at the RECORD step pending reviewer approval (or surfaces "needs approval" notification).

## Related

- `/align-phase` — primary dispatcher.
- `/align-fast` — also dispatches (per row in parallel waves).
- `detect-drift` skill — the detector half (sibling).
- `align-discipline.md` — the rule this skill enforces.
- `align-ledger.md` — the schema this skill updates.
