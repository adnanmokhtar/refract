# REFERENCE

The manual you read when something refuses, surprises, or fails. Companion to `README.md` (install + commands) and `docs/COMMANDS.md` (full flag list). This doc covers the *why*, the *halts*, and the *recovery* paths.

## When to read this doc

- A command refused with `REFUSED — N mandatory check(s) failed`.
- You see `<TBD>` markers in generated files and don't know if they're a bug or by design.
- The migration pack asked you a question you didn't expect, OR didn't ask one you did.
- An agent emitted `etc.` / `...` / `several` / `appears` and you want to know why the validator caught it.
- You moved to a new device and need the full restoration path.
- You want to understand the discipline patterns every command + agent + skill follows.

## Table of contents

- [The four discipline patterns](#the-four-discipline-patterns)
- [`<TBD>` lifecycle](#tbd-lifecycle)
- [Phase 5 audit failure modes](#phase-5-audit-failure-modes)
- [Migration end-to-end](#migration-end-to-end)
- [Align (codebase quality sweep) end-to-end](#align-codebase-quality-sweep-end-to-end)
- [Universal commands (`/do`, intent gates, gap-fill commands)](#universal-commands)
- [Memory system](#memory-system)
- [Validator scripts](#validator-scripts)
- [Common pitfalls](#common-pitfalls)
- [New device setup](#new-device-setup)

---

## The four discipline patterns

Every command, agent, skill, and ai-pattern in this repo follows the same shape. If you understand these four patterns, you understand why things halt, why questions are or aren't asked, and why ceremony scales with risk.

### 1. Premise (top of file)

The first thing the LLM reads in any command/agent/skill. A 4-6 line bolded statement that anchors the file's truth-source. Examples:

| File type | Premise truth-anchor |
|---|---|
| `find-and-fix.md` (migration) | **V1 is production. V1 wins.** |
| `add-feature.md` (any pack) | **Existing siblings are the truth. Match before innovating.** |
| `fix-bug.md` | **The bug is real. The fix is small. The pattern almost always exists elsewhere.** |
| `parity-auditor.md` | **V1 is production. Default closure is `code-edit` toward V1.** |
| Audit commands (a11y-audit, security-audit, etc.) | **Find real issues, no hand-waves. Cite `<path:line>`.** |
| Refresh commands (refresh-knowledge, doc-refresh) | **Source code is the truth. Refresh = re-derive, never invent.** |

The premise is **the first instruction the agent absorbs**, before phase descriptions or methodology. This is deliberate — we tested putting it later, agents balanced it against other rules and the discipline leaked.

### 2. Closure-verb table

Maps risk/complexity to ceremony level. Default is **trivial-tier** (just do it). Heavy ceremony is opt-in.

```
| Tier      | Trigger                                  | Required output     |
|-----------|------------------------------------------|---------------------|
| Trivial   | (default — no promoter triggers)         | Code edit only      |
| Standard  | 1-3 P1 gaps OR API contract divergence   | + 1-paragraph plan  |
| Heavy     | P0 / cross-repo / write-path / security  | Full ceremony       |
```

This is why `/find-and-fix F014` doesn't ask you 10 questions — most rows are trivial-tier and ship with one summary at the end. It's also why `/port-feature --heavy` is rare-by-design.

### 3. Mechanical halt

Every command has at least one halt rule **enforced by a validator script** (not just rule-text the agent must remember). Examples:

- `find-and-fix` — `gaps_in == gaps_closed` enforced by `check_gap_count_parity` in `validate-migration-artifacts.sh`.
- `migration-gate` — refuses PASS if any feature row in the phase has missing artifacts.
- `align-gate` — 14-check matrix in `validate-align-artifacts.sh` (gap-count parity, net-lines on structural ≤ 0, no new symbols except idioms-named, idiom-citation for functional adds, security assertion present, perf baseline present, security tier minimum, oracle unmodified, frontend regressions for `frontend-*`).
- All audit commands — hand-wave grep refuses outputs containing `etc.` / `...` / `N+ items` / `appears to` / `several places` / `multiple endpoints`.
- `add-feature` — sibling-shape conformance check refuses new files that diverge from sibling shape without an ADR.

The pattern: **mechanical enforcement beats agent self-policing**. If the agent forgets the rule, the script catches it.

### 4. Lightweight default

The 7-phase ceremony (Understand → Organize → Retrieve → Generate → Update → Validate → Improve) is **opt-in for genuinely heavy work**. Most commands ship with explicit notes that trivial cases skip phases 5+7 (or 4.6+4.8) entirely.

`canonical-command-template.md` was flipped to make skipping the **default**, not the exception. Every command derived from it inherits this.

---

## `<TBD>` lifecycle

`<TBD>` markers in scaffold files are **deliberate placeholders**, not bugs. They appear in 2 specific files:

- `.claude/_codebase-scan.md` — sections 8-15 (module map, architecture pattern, conventions, drift findings, structural recommendations)
- `.claude/_refresh-extract.md` — sections 2-9 (ADRs preserved, project intent, custom rules, custom agents, etc.)

### The flow

```
Phase 0.0 / 0.2  (script)
  scripts/deep-codebase-scan.sh  →  writes _codebase-scan.md
                                    mechanical sections filled
                                    prose sections = <TBD>
  Phase 0.2 internal              →  writes _refresh-extract.md
                                    8 prose sections = <TBD>

Phase 4.6-DEEP / 4.7-DEEP / 4.8-DEEP  (LLM)
  Dispatches extraction skills:
    extract-architecture-deeply  →  fills "Architecture pattern"
    extract-conventions-emerging →  fills "Conventions visible"
    extract-base-class-idiom     →  fills "Patterns repeated 3+ times"
    extract-codebase-overview    →  fills "Module map"
    extract-failures-from-history →  fills "Architecture decisions implicit"
  
  All <TBD> become real, project-specific content.

Phase 5 audit
  scripts/audit-setup.sh  →  greps for any remaining <TBD>
  If found  →  REFUSED. The run is incomplete.
```

### What to do when you see `<TBD>`

1. If it's the freshly-generated state, **let `/setup-project` continue** — Phase 4.6/4.7/4.8 DEEP fills them.
2. If `/setup-project` already exited and they're still `<TBD>`, **the run was incomplete**. Common causes:
   - You used `--include=<pack>` — this scopes the run and may skip deep extraction. Re-run **without `--include`** to trigger full Phase 4 deep-fill.
   - You used `--minimal` — by design skips deep extraction.
   - The session was interrupted before Phase 4 finished.
3. If you re-run and they STILL don't fill, that's a real bug — the orchestrator isn't dispatching the extraction skills.

### Vue/React mustache syntax is NOT `<TBD>`

A grep for `{{...}}` will match Vue template interpolation in code examples. Those are real code, not placeholders. Only `<TBD>` (literal angle-brackets-T-B-D-angle-brackets) is the placeholder marker.

---

## Phase 5 audit failure modes

`scripts/audit-setup.sh "$TARGET" --mode=<MODE>` is the gate that refuses to ship a half-complete run. Output starts with `=== Phase 5 audit ===` and ends with one of:

- `summary: pass: N  warn: M` — clean.
- `REFUSED — N mandatory check(s) failed` — must fix.

### Common failures and fixes

#### `_refresh-extract.md § "<section>" is still <TBD>`

A required prose section in the refresh-extract scaffold wasn't filled. **Fix:** dispatch the corresponding extraction skill, or re-run `/setup-project --refresh` (without `--include`).

| TBD section | Fill via |
|---|---|
| ADRs preserved | Read `ai/decisions/` directly, list ADR titles + status |
| Validated user corrections | Read `ai/dynamic/feedback-learned.md` |
| Project intent | Read `CLAUDE.md` + `ai/project-goals.md` |
| Custom rules | List `.claude/rules/*.md` that aren't from any pack |
| Custom agents/skills/commands | List `.claude/{agents,skills,commands}/*.md` not from packs |
| Architecture decisions implicit in code | `extract-failures-from-history` skill |
| Detected stack + version | `extract-codebase-overview` skill |
| Migration / V1↔V2 mapping | If `--include=migration`, dispatch `extract-v1-contract` |

#### `_codebase-scan.md § "<section>" is <TBD>`

Same shape, fills via:

| TBD section | Fill via |
|---|---|
| Module map | `extract-codebase-overview` |
| Architecture pattern | `extract-architecture-deeply` |
| Conventions visible | `extract-conventions-emerging` |
| Patterns repeated 3+ times | `extract-base-class-idiom` |
| Decisions implicit | Read git log + commit messages, summarize |
| Drift between rules and code | Diff each `.claude/rules/*.md` claim vs actual code |
| Stale references | Grep `ai/*.md` + `.claude/*.md` for paths that no longer exist |
| Recommended structural improvements | LLM judgment from sections 8-14 (≥3 required on ≥1000 LOC codebases) |

#### `Section 15 has 0 structural recommendations; minimum 3 required`

The codebase is large enough that the audit demands ≥3 structural improvement proposals. Read sections 8-14 of `_codebase-scan.md` and propose concrete improvements (extracting service layer, adding pattern docs for repeated code, fixing convention drift, etc.). Each must include What/Why/Where/Effort/Risk.

#### `pack coverage — Missing rows addressed` ERR

A pack file in `_pack-coverage-report.md` is marked `Missing` and was not addressed. **Fix:** for each missing row, either (a) write the file, (b) add a `Skipped: <reason>` note, or (c) explicitly remove the pack.

#### `audit-setup.sh: command not found`

`~/.claude/scripts/audit-setup.sh` symlink missing. Re-run `./scripts/sync-to-global.sh --apply` from this repo.

---

## Migration end-to-end

The complete V1 → V2 migration workflow, with every halt and gate.

### Setup (once per project)

```
cd /path/to/v2-project
/setup-project --refresh --include=migration
```

This:
1. Scans V2 codebase, fills `_codebase-scan.md` and `_refresh-extract.md`.
2. Installs the migration pack files into `.claude/{commands,rules,agents,skills}/`.
3. Creates `ai/migration/` directory with placeholder `ledger.md` and `plan.md`.

### Bootstrap the ledger (once)

```
/migration-scan
```

Walks V1 + V2, builds `ai/migration/ledger.md` with one row per portable feature. Pairs V1 paths with V2 destination paths.

### Plan the phases (once, can replan later)

```
/migration-plan
```

Reads ledger + scan-report, produces `ai/migration/plan.md` with phased execution plan. Default: auto-phases by dependency + domain. Optional flags: `--phases=N`, `--max-features-per-phase=N`.

### Per-phase execution (repeat for each phase)

This is the tightest loop. **Audit first, chain second.**

#### Step 1 — Audit the phase (you watch)

```
/migration-phase 1 --audit-only
```

Per-feature audit only. No code changes. Output: per-feature audit docs + `ai/migration/audits/phase-1.md` summary. Reveals every gap (ADD / DELETE / CHANGE) in V2 vs V1.

#### Step 2 — Read the audit

Open `ai/migration/audits/phase-1.md`. Note flags:
- **P0 / cross-repo / contract-break / write-path-mutation / security-sensitive** → ADRs needed (continue to step 3).
- **No flags** → skip step 3, go to step 4.

#### Step 3 — Draft ADRs (only if step 2 flagged anything)

```
/draft-phase-adrs 1
```

Produces ADR drafts in `ai/decisions/_phase-1-decisions.md`. Each starts as `Status: proposed`.

#### Step 4 — Review and accept ADRs

Open each drafted ADR. Edit if needed. **Change `Status: proposed` → `Status: accepted`**. The chain refuses to start while any ADR is still proposed.

#### Step 5 — Verify clean working tree

```bash
git status   # must be clean before --chain
git stash    # if anything is uncommitted
```

#### Step 6 — Run the chain (walk away)

```
/migration-phase 1 --chain
```

For every feature in dependency order:
1. Dispatch `/find-and-fix <id>` (default — light) or `/port-feature <id> --heavy --unattended` (only if audit flagged heavy triggers).
2. Pre-advance gate: re-run `parity-auditor` in verify-only mode. Verdict must be `parity-clean` (`gaps_in == gaps_closed`, no regressions, no new gaps). Else HALT.
3. On verified success: commit with `gaps_in` / `gaps_closed` recorded.
4. On halt: write `ai/migration/halts/<feature>-<iso>.md`. With `--stop-on-halt` (default), abort. With `--no-stop-on-halt`, log + continue.

After last feature, auto-invokes `/migration-gate <N>`.

#### Step 7 — If chain halted

Read `ai/migration/halts/<feature>-<iso>.md`. Fix the cause. Resume:

```
/migration-phase 1 --chain    # resumes from where it stopped
```

Or fix one feature manually:

```
/find-and-fix <feature-id>
```

#### Step 8 — Confirm phase exit

```
/migration-gate 1
```

Auto-invoked at end of chain. Re-runnable manually. Returns PASS or REFUSED with the missing artifacts list.

### Repeat for every phase

```
/migration-phase 2 --audit-only
... (steps 2-8)
/migration-phase 3 --audit-only
... (steps 2-8)
```

### When `/find-and-fix` runs

The 6-step internal loop:

1. **DETECT** — `parity-auditor` agent reads V1 + V2 line-by-line, returns gap list with ADD/DELETE/CHANGE labels.
2. **DECIDE** — V1-parity by default. Surface to user ONLY for: P0 cross-repo / security regression / V1-source undeterminable. Cosmetic / locale / V2-only-extras → silent code-edit.
3. **FIX** — apply edits. Includes ADR pre-check: scan `ai/decisions/` for accepted ADRs documenting V2 deviations; if found, preserve V2 (don't revert).
4. **RE-DETECT** — re-dispatch auditor in verify mode against the original gap list. HALT unless `gaps_in == gaps_closed`.
5. **VERIFY** — run project's typecheck + lint + parity tests.
6. **RECORD** — update ledger row with `gaps_in` / `gaps_closed`, write audit verdict.

### What `find-and-fix` does NOT ask

- Cosmetic deviations (empty cell text, swatch vs picker)
- Locale key drift (rename to V1 keys silently)
- V2-only extras (remove silently unless ADR exists)
- Permission-gate divergence where V2 matches V1's intent

It only asks for:
- Cross-repo blockers (V2 fix needs API change)
- Security/privacy/legal regressions in V1 that V2 fixed (rare)
- V1 source genuinely undeterminable (file missing, no caller)

---

## Align (codebase quality sweep) end-to-end

Single-codebase quality gate — drift, dead code, dups, silent catches, SOLID, clean code, performance, security. Same parallel-dispatch + atomic-fix discipline as migration; turned inward. **Opt-in via `--include=align`**; never auto-loaded.

For the full step-by-step workflow + commands + flags, see `docs/COMMANDS.md` § "Codebase alignment — the comprehensive quality sweep". This section covers the load-bearing internals.

### Setup (once per project)

```
/setup-project --refine                  # if _extracted-idioms.md is empty (precondition)
/setup-project --include=align
```

What this does:
1. Confirms `_extracted-idioms.md` is non-empty + identifies `PROJECT_KIND`.
2. Installs the align pack into `.claude/{commands,rules,skills}/`.
3. Auto-includes detector packs: `code-quality` (always), `security` (always), `frontend` + `ui-ux` (for `frontend-*`), `backend/database` (for `backend-*`), `mobile` (for `mobile-*`).
4. Creates `ai/align/` with empty placeholders.

### The phased loop

```
/align-scan            → ai/align/{ledger.md, scan-report.md, findings.md}
/align-plan            → ai/align/plan.md
─── per phase N ───
/align-phase N         → per-finding loop (manual)
/align-gate N          → 14-check exit gate
─── after last phase ───
/align-final           → ai/align/final-report-<date>.md
```

Or per-phase fast flow (mirrors `/migration-fast` — one phase per command, scan + plan must have run already):

```
/align-scan
/align-plan
/align-fast 1          # phase 1: per-finding loop in parallel + auto-gate
/align-fast 2
/align-fast 3
... (per phase from plan)
/align-final
```

### Verification re-runs — `--re-audit`

`/align-fast <N> --re-audit` and `/align-final --re-audit` mirror migration's `--re-audit`. Discards cached `status: verified` verdicts and re-dispatches the detector on every row including verified ones. Use it to verify done work is still correct — catches false-verified rows, drift since the gate, or detector improvements that surface previously-missed gaps. Re-detected rows whose fingerprint reappears flip to `halted` and fast re-fixes them in the same run; rows that stay clean stay `verified` (no code change).

### Heavy-tier reviewer-approval (v1.5+)

Heavy-tier rows pause for reviewer approval before they can flip to `done` / `verified`. Real protocol:

- **Ledger field**: `reviewer_approval: <name>@<iso>`. Empty = pending.
- **Status**: row enters `pending-review` after fix + verify; stays there until field is populated.
- **Halt file**: `ai/{migration,align}/halts/<id>-pending-review.md` — what to verify, who's the reviewer, how to approve.
- **Default reviewer**: `CODEOWNERS` for the row's scope OR `default_reviewer:` in `ai/{migration,align}/_anchors.md`.
- **Override**: `--reviewer=<name>` on `/migration-fast` / `/align-fast` / `/port-feature`.
- **Timeout**: 7 days default; row stays pending-review past timeout (no auto-fail). `/migration-status --blockers` surfaces stalled rows.
- **Approval**: reviewer adds `reviewer_approval: <name>@<iso>` to ledger row + commits.
- **Gate behavior**: rows with non-empty `reviewer_approval` flip from `pending-review` → `done`/`verified` on next `/migration-gate` / `/align-gate` run.

### Mid-port tier promotion (v1.5+)

`/migration-promote-tier <id> <new-tier> [--reason=]` and `/align-promote-tier <id> <new-tier>` change a row's tier mid-fix. Used when the agent realizes scan classified the row wrong.

- **Promotions** (trivial → standard → heavy) backfill required artifacts automatically.
- **Demotions** require `--reason=`. Forbidden for: P0 rows, cross-repo blockers, contract breaks, write-path mutations, security rows below standard, critical-severity rows below heavy.
- **History**: every promotion/demotion writes to `ai/{migration,align}/_history.md`.

### Cross-repo task tracking (v1.5+, migration-only)

`/cross-repo-task` registers + tracks + drains cross-repo blockers. Subcommands: `register`, `list`, `update`, `close`, `drain`. Registry at `ai/migration/cross-repo-tasks.md`.

- `register <feature-id> "<description>"` — creates task ID, links blocked feature, sets row to halted with cross-repo reason.
- `drain` — re-runs `/find-and-fix` on rows whose blockers landed.

Use when a port halts because a sibling repo needs to ship something first. Without this, cross-repo halts orphan rows in the ledger indefinitely.

### Oracle / idiom drift detection (v1.5+)

`/migration-scan` and `/align-scan` now compare oracle file hashes (`_extracted-idioms.md`, `ai/conventions.md`, `ai/architecture.md`) against the prior scan's recorded hashes. If anything changed:

- Scan-report includes "Oracle drift detected" section listing changed entries + affected ledger rows.
- `/migration-replan --include-drifted` / `/align-replan --include-drifted` re-phases affected rows.
- `verified` / `done` rows flip back to active states ONLY if the change materially affects them (signature change, primitive replaced, architectural rename); cosmetic changes leave them alone.

### Plan-independent spot-check — `/align-recheck` and `/migration-recheck`

These are the bypass-the-ceremony commands. **No plan, no phase, no ledger required.**

- Take a **natural-language description** (`the sidebar`, `the orders module`, `customer tabs`) OR an explicit path. The agent reads `codebase-profile.md` + idioms + architecture and semantically resolves the description (same intent-interpretation model as `/add-feature` — not keyword matching).
- **Ignore the migration/alignment workflow entirely.** No phase number, no plan dependency, no required prior scan.
- **Scan source FRESH.** For migration: V1 + V2 parity audit. For align: dispatch the 11 universal detectors (+ stack-conditional UI/UX) directly against current source.
- Run the same per-feature / per-finding loop as `/find-and-fix` / `/align-phase`: DETECT → DECIDE → FIX → VERIFY → RECORD. One commit per fix.
- **Fix in place** when drift is found; pass `--re-detect-only` for read-only inspection.
- **Best-effort ledger update**: if a ledger exists, matching rows are updated; if not, the command leaves the ledger alone. Pass `--register-ledger` to register new findings into the ledger as part of the run.

Confirmation flow: confident → silent (with summary preamble); ambiguous → halt + ask which match you meant; nothing-found → halt + suggest narrowing.

Examples:
```
/migration-recheck the sidebar
/migration-recheck the page builder
/migration-recheck the customer tabs in the dashboard
/align-recheck the orders module
/align-recheck the navigation header --re-detect-only
/align-recheck the auth pages --register-ledger     # also tracks findings
```

This is the user's manual override / safety check + the "I just want this area cleaned up" tool — independent of whether the formal migration/alignment workflow has been initialized for the project.

### When `/align-phase` runs

The 5-step per-finding loop (mirrors `find-and-fix` for migration):

1. **DETECT** — re-verify the fingerprint at evidence lines is still present. (Findings can age out.)
2. **DECIDE** — confirm closure verb is in the 16-verb vocabulary; confirm fix is appropriate to row's class; for functional verbs, confirm `idiom_cited` resolves.
3. **FIX** — apply the verb's edit. Touch only files in `scope`. Net-lines ≤ 0 for structural rows; small + budget for functional rows (added lines must cite the row's `idiom_cited`).
4. **VERIFY** — universal: lint + typecheck + scoped tests + re-detect + coverage non-decreasing. Class-specific: security assertion (gate denies / validator rejects / escape neutralises) for security rows; perf baseline + assertion for perf rows; a11y / visual / bundle-size for frontend UI/UX rows.
5. **RECORD** — update ledger row (`status: fixed`, `commit`, `gaps_closed`, `notes`); commit (one finding = one commit).

### Closure-verb vocabulary (16 verbs)

| Group | Verbs |
|---|---|
| Structural (5) | `remove`, `inline`, `dedupe`, `rename-comment-out`, `replace-with-shared` |
| Functional (11) | `add-gate`, `parameterize`, `escape`, `move-to-secrets`, `add-validator`, `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `extract-to-shared`, `split-extract`, `inline-magic-to-named-const`, `inline-filter-to-query`, `bump-dep`, `rename` |

A verb outside this list = NOT alignment. Route to `/refactor` / `/setup-project --refine` / a feature flow.

**Functional verbs USE existing idioms.** A `add-gate` uses the project's auth gate from `_extracted-idioms.md`; a `cache-with-explicit-ttl` uses the project's cache primitive. Inventing a NEW gate / cache / validator is forbidden — the validator's `check_added_lines_cite_idioms` halts the gate.

### What `/align-phase` does NOT ask

- Cosmetic deviations from convention (closure verb is decided at scan time)
- Whether to fix dead code (the closure verb is `remove`)
- Whether to keep a reinvented wrapper (the closure verb is `replace-with-shared`)

It only halts on:
- The fix would change observable behaviour where preservation was the contract → re-classify as `/refactor`.
- The shared equivalent in `_extracted-idioms.md` doesn't exist → route to `/setup-project --refine`.
- A heavy-tier finding's impact analysis surfaces a consumer the planner missed.

### Validator script — `validate-align-artifacts.sh`

**Status: `[v1.5.0 — 7 of 14 checks shipped]`**. The script (`scripts/validate-align-artifacts.sh`) ships 7 mechanical checks; the remaining 7 stay agent-side until v2. Universal callable from any tool's hook system, CI, or pre-commit.

**Shipped checks (mechanical)**:
1. `check_evidence_resolves` — every row's `<path:line>` resolves at the cited line.
2. `check_no_handwaves` — refuses `etc.` / `...` / `several` / `multiple endpoints` / `N+ items`.
3. `check_closure_verb_in_vocab` — verb in 21-verb closed list.
4. `check_no_new_symbols` — `git diff --diff-filter=A` shows no new exports unless named in idioms.
5. `check_net_lines_structural` — git stat for row's commit; structural rows ≤ 0 net.
6. `check_scope_boundary` — `git show --name-only` for row's commit; touched files ⊂ row.scope.
7. `check_security_tier_minimum` — security ≥ standard; critical → heavy.

**Remaining 7 (agent-side)**: test-coverage, frontend-regression, idiom-citation, security-assertion, perf-baseline, oracle-unmodified, ledger-completeness.

Usage:
```
scripts/validate-align-artifacts.sh --phase=<N>
scripts/validate-align-artifacts.sh --finding=<id>
scripts/validate-align-artifacts.sh --all
scripts/validate-align-artifacts.sh --strict
scripts/validate-align-artifacts.sh --check=<name>
```

The 14 checks (see `align-gate.md`):

1. Ledger completeness — every phase row in `{fixed, archived-pre-existing, parked}`.
2. Gap-count parity — `gaps_closed == len(evidence)`.
3. Net-lines on structural rows ≤ 0.
4. No new symbols (with idioms-named exemption).
5. No scope creep.
6. Mechanical green at HEAD.
7. Coverage non-decreasing.
8. Frontend regressions green (`frontend-*`).
9. Oracle unmodified.
10. Per-tier artifacts complete.
11. Functional adds cite idiom.
12. Security assertion present.
13. Perf baseline + assertion present.
14. Security tier minimum.

Returns non-zero on any fail. Wire into pre-commit / CI / tool-specific hook (Claude Code: `.claude/settings.json`; Cursor: `.cursor/hooks.json`; Copilot: GitHub Actions; Aider/Codex/Gemini: `.git/hooks/pre-commit`).

### Idiom-gap recovery

If `/align-phase` halts repeatedly with "missing idiom" reasons (e.g., the project has no named cache primitive but several findings need `cache-with-explicit-ttl`), the right move is NOT to invent the idiom inline — it's to update the gold-standard inventory:

```
/align-park <id> --blocker=idiom-missing
... (close current phase if other rows are fixable)
/setup-project --refine                   # add the missing idiom to _extracted-idioms.md
... (review the refined idioms)
/align-unpark <id>                        # revive the parked finding
/align-phase <N> --start-from=<id>        # retry
```

This keeps the alignment effort honest: the inventory is the oracle; gaps in the oracle surface as parked findings, not silently-invented abstractions.

---

## Universal commands

### `/do <description>` — meta-router

Single entry point. Take any natural-language description; agent picks the right specialized command via intent + stack + available-commands; dispatches.

- **High confidence** → silent dispatch with 1-line preamble.
- **Medium confidence** (ambiguous target) → ask one clarifying question.
- **Low confidence** → halt; list available commands matching keywords.

Forwards the user's description verbatim to the picked command. Logs every dispatch to `ai/_history.md`.

Use cases:
```
/do enhance the sidebar           → /enhance-ui
/do add a refund button           → /add-feature
/do fix the order list crash      → /fix-bug
/do clean up the auth module      → asks: align? enhance? migration-recheck?
/do audit security                → /security-audit
```

### Intent gates (on specialized commands)

Major commands now have a Phase 1 "Intent gate" that detects when the user's description doesn't match the command's scope, halts, and suggests the right alternative:

| Command | Halts when description suggests | Suggests |
|---|---|---|
| `/add-feature` | "enhance / improve / polish / cleaner" | `/enhance-ui` |
| `/add-feature` | "fix / broken / wrong" | `/fix-bug` |
| `/enhance-ui` | "add / new / create / build" | `/add-feature` |
| `/fix-bug` | "enhance / improve / polish" | `/enhance-ui` |
| `/add-page` | similar | similar |
| `/add-component` | "test in isolation" | `component-playground` skill |
| `/add-endpoint` | "fix / broken" | `/fix-bug` |
| `/optimize-query` | "add / new" | `/add-endpoint` or `/add-migration` |
| `/security-audit` | "fix the auth bug" | `/fix-bug` |

User can override ("no, run /add-feature anyway") — the run summary flags the override.

### Gap-fill commands (v1.5+)

| Command | Pack | Purpose |
|---|---|---|
| `/run-tests [<scope>]` | testing | Detects runner; runs scoped or full suite; reports pass/fail/coverage. Called by `/align-phase` and `/migration-fast` VERIFY steps. |
| `/deploy-stage` | devops | Deploy to staging. Pre-flight + detect mechanism + monitor 5min + halt on red. |
| `/add-runbook <name>` | documentation | Author ops runbook with mandatory verify-after-each-step + rollback section. |
| `/migration-promote-tier <id> <tier>` | migration | Mid-port tier change. Backfills artifacts on promotion. Demotion forbidden for security/P0/cross-repo. |
| `/align-promote-tier <id> <tier>` | align | Same as above for align findings. |
| `/cross-repo-task` | migration | Register / list / drain cross-repo blockers when ports halt due to upstream changes. |

## Memory system

Three layers, each per-project:

### 1. CLAUDE.md (loaded into every conversation)

- Project root: `<project>/CLAUDE.md`
- Subtree-scoped: `<project>/some/dir/CLAUDE.md` (loaded when working in that subtree)
- Global: `~/.claude/CLAUDE.md` (loaded everywhere)

Static text. You edit; Claude reads. Best for "always remember X about this project" rules.

### 2. Auto-memory (file-based, per-project)

Path: `~/.claude/projects/<encoded-project-path>/memory/`

Encoded path = absolute project path with slashes replaced by dashes. Example:
- `<absolute-project-path>` (e.g. `/Users/<you>/projects/<your-app>`) →
- `~/.claude/projects/<encoded-project-path>/memory/` (slashes → dashes)

Each memory is a `.md` file with frontmatter (`name`, `description`, `type`) plus an entry in `MEMORY.md` (the index). Different projects = different memories.

Types of memory:
- `user` — your role, preferences, knowledge
- `feedback` — corrections + validated approaches
- `project` — ongoing work, deadlines, constraints
- `reference` — pointers to external systems (Linear, Slack, dashboards)

### 3. Conversation history (per-project)

`~/.claude/sessions/` and `~/.claude/projects/<hash>/`. Used for `/resume` and `/continue`.

---

## Validator scripts

All under `scripts/` in this repo, symlinked into `~/.claude/scripts/`:

| Script | What it checks |
|---|---|
| `audit-setup.sh` | Phase 5 audit for `/setup-project` runs. TBDs filled, pack coverage, anchoring, adapter coverage. |
| `validate-migration-artifacts.sh` | Per-feature migration artifacts: contract sections, parity tests, audit provenance, V2-structure conformance, gap-count parity, hand-wave detection. |
| `validate-align-artifacts.sh` | **v1.5.0 — 7 of 14 checks shipped (589 lines)**: evidence-resolves, no-handwaves, closure-verb-vocab, no-new-symbols (idiom-named exemption), structural-net-lines-non-positive, scope-boundary, security-tier-minimum. Remaining 7 (test-coverage, frontend-regression, idiom-citation, security-assertion, perf-baseline, oracle-unmodified, ledger-completeness) stay agent-side until v2. |
| `migration-detect-existing.sh` | Phase 1 of `/port-feature`: detects whether V2 already implements a feature (none / partial / full). |
| `migration-validate-paths.sh` | Phase 4 of `/port-feature`: validates planned file paths against V2 module shape. |
| `audit-adapter-coverage.sh` | Per-pack adapter coverage: every pack rule has equivalent translations in Cursor / OpenCode / Aider / etc. |
| `audit-file-health.sh` | Heuristic risk scan: line count, hand-waves, MUSTs, phase-ladder count, inbound refs. Used to triage which files deserve attention. |
| `sync-to-global.sh` | Symlinks this repo's `commands/`, `templates/packs/migration/`, etc. into `~/.claude/`. |
| `verify-sync.sh` | Detects drift between this repo and `~/.claude/` symlinks. |

### Reading audit failures

Every `ERR` line is anchored to a specific check function in the script. If you grep the script for the failing check name (e.g., `check_audit`, `check_v2_structure`, `check_gap_count_parity`), you'll see the exact regex / condition that triggered.

---

## Common pitfalls

### `--include=<pack>` skips deep extraction

`/setup-project --refresh --include=frontend,migration` only refreshes those packs. It does NOT trigger Phase 4.6/4.7/4.8 DEEP extraction. Result: `<TBD>` markers remain in `_codebase-scan.md` + `_refresh-extract.md`, Phase 5 refuses.

**Fix:** drop `--include`. Use `/setup-project --refresh` for full deep-fill.

### `--minimal` skips deep ceremony

By design. Use only for the lightest existing-project enhancement.

### Mid-run interruption leaves `<TBD>`

If you Ctrl-C or the session ends before Phase 4 completes, `_codebase-scan.md` + `_refresh-extract.md` remain with placeholders. Phase 5 will refuse on next audit. **Fix:** re-run `/setup-project --refresh` to retrigger Phase 4 deep-fill.

### Working tree dirty before `--chain`

Migration `--chain` refuses on dirty working tree (pre-flight check 3). **Fix:** commit or stash before chaining.

### ADR still `Status: proposed`

Migration `--chain` refuses if any phase ADR is `proposed`. **Fix:** review each ADR in `ai/decisions/_phase-N-decisions.md`, edit if needed, change `proposed` → `accepted`.

### Adapter sync stale

After editing this repo's pack files, `<frontend-v2>/.claude/` doesn't auto-sync (unlike `~/.claude/` which is symlinked). **Fix:** re-run `/setup-project-adapters` from inside the target project, OR manually `cp` the pack files (the migration-pack pattern we did this session).

### Phase 5 demands ≥3 structural recommendations

On any codebase ≥1000 LOC. Section 15 of `_codebase-scan.md` must list ≥3 concrete proposals (not minor isolated changes). The audit refuses on fewer.

---

## New device setup

Full restoration after `git clone` on a new machine:

```bash
# 1. Clone the repo to a stable location (NOT at ~/.claude/)
git clone <remote> ~/Workspace/Projects/claude-config

# 2. Create the global symlinks
cd ~/Workspace/Projects/claude-config
./scripts/sync-to-global.sh            # dry-run first
./scripts/sync-to-global.sh --apply

# 3. Restore ~/.claude/settings.json from backup
#    (NOT auto-synced — user-managed)

# 4. Verify the symlink farm
./scripts/verify-sync.sh
```

Per-target-project setup:
```bash
cd /path/to/some/project
/setup-project --refresh    # pulls latest pack content into <project>/.claude/
```

Target-project `.claude/` files are **copies, not symlinks** — they need re-sync after pack edits via `/setup-project --refresh`.

---

## See also

- `README.md` — install + commands index + workflow examples
- `docs/COMMANDS.md` — every command, every flag, full reference
- `docs/setup-project-cheatsheet.md` — quick flag lookup
- `templates/critical-execution-rules.md` — the rules every `/setup-project` run obeys
- `templates/decision-engine.md` — how the orchestrator decides what to do per-mode
- `templates/phases/` — every phase's responsibilities and contracts
