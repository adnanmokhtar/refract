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
- All audit commands — hand-wave grep refuses outputs containing `etc.` / `...` / `N+ items` / `appears to`.
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
- `/Users/mac/Workspace/Projects/sahlcart/tenant-portal-v2` →
- `~/.claude/projects/-Users-mac-Workspace-Projects-sahlcart-tenant-portal-v2/memory/`

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

After editing this repo's pack files, `tenant-portal-v2/.claude/` doesn't auto-sync (unlike `~/.claude/` which is symlinked). **Fix:** re-run `/setup-project-adapters` from inside the target project, OR manually `cp` the pack files (the migration-pack pattern we did this session).

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
