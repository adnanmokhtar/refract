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
- [`/ui-sweep` — project-wide UI/UX specialist](#ui-sweep--project-wide-uiux-specialist)
- [`/ui-crawl` + `/ui-crawl-fix` — paired QA crawler + auto-fixer](#ui-crawl--ui-crawl-fix--paired-qa-crawler--auto-fixer-v12)
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
- `add-feature` — sibling-shape conformance check refuses new files that diverge from sibling shape without an ADR; heavy tier additionally gates on `reviewers_clean == reviewers_dispatched`, observability sign-off, and security + release pre-flights. Dispatched agents that aren't installed are performed inline against their pack/domain checklist (`inline:<agent-name>`), never silently skipped.
- `setup-project --refresh` (M35) — `run-preflight.sh` takes the Phase 0 backup deterministically; `audit-setup.sh` C2a refuses success without it, and C2k regenerates the study report post-apply and refuses success while any actionable row is neither APPLIED nor RECORDED in `.claude/_refresh-decisions.md` (`--reject` / `--keep-ours` / `--resolve` / `--keep` with rationale). Kept/resolved rows re-open automatically when the pack source changes (`pack@sha8` mismatch).

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

## The 6 simple commands — `/migrate`, `/optimize`, `/align`, `/polish`, `/audit`, `/unify-surfaces`

Top-level user surface above the detailed phased commands. Each takes optional `<scope>` (whole project if omitted, or natural-language description / explicit path) and runs deep multi-agent execution silently. NO phases / halts / ADRs / terminology surfaced — internal discipline (V1-parity, gap-count parity, idiom citation, no fabrication) is preserved but invisible.

| Command | Concern | Stack |
|---|---|---|
| `/migrate` | V1→V2 ports (V1 wins on behaviour; V2 wins on structure) | any |
| `/optimize` | architectural diagnosis FIRST (layer violations, god modules, missing abstractions) + tactical sweep (clean code, refactoring, SOLID, performance, render/rebuild waste for frontend-*/mobile-* per `mobile/rules/render-discipline.md` (mobile pack v1.2+), dead code, dedup, over-abstraction). Foundation-first ordering — architectural fixes cascade and dissolve tactical findings. Backed by `architectural-diagnosis` + `refactoring-sweep` skills (code-quality pack v1.1+). | any |
| `/align` | convention drift, structure enforcement, design-token / a11y / i18n / layering, silent catches + unhandled I/O (happy-path-only call sites — align pack v1.6+ `unhandled-io` class). Backed by `detect-drift` + `find-and-align` skills (align pack). | any |
| `/polish` | **Stack-conditional**: frontend-* → 18-verb closed vocabulary in `ui-design-sweep` (ui-ux pack v1.1+) — tokens / wrappers / hierarchy / type-scale / rhythm / density / states / contrast / focus / iconography / motion / tap-target / cta / affordance / surface — fed by `a11y-quick-check`, `design-iterate`, `design-token-audit`, `motion-audit`. backend-* → `api-consistency-audit` (backend pack v1.1+, 15 detectors). data-* → `schema-consistency-audit` (database pack v1.1+). mobile-* → `platform-conventions-audit` (mobile pack v1.1+) + frontend fallback. **Validator** `validate-polish-artifacts.sh § check_frontend_verb_vocabulary` rejects any `closure_verb:` outside the 18-verb set. | any (PROJECT_KIND must be set) |
| `/unify-surfaces` | **Surface-type unification across the entire frontend codebase.** Sibling to `/polish`, but typed by SURFACE CATEGORY (tables / forms / headers / tabs / filters / buttons / validation) instead of by axis. For each requested category: inventories every consumer across the codebase, decides the canonical wrapper (from `_extracted-idioms.md § Wrappers` or by promoting the most-used pattern), extracts or extends the shared wrapper, migrates every consumer in **one cascade-rewrite commit per category**, verifies (typecheck + lint + scoped tests + visual-regression on non-target surfaces). Validation extracts a **3-part pipeline** — frontend validator composable + `<ErrorList>` / `<FieldError>` + API-validation-error mapper — wired as a global response interceptor. Reuse-Before-Create enforced (extracting a duplicate where a shared wrapper exists fails the verify gate). Idioms updated in the same commit. Composable with `/polish` (run `/unify-surfaces` first to consolidate wrappers, then `/polish` to polish each canonical wrapper to spec). | `frontend-*`, `mobile-web`, `mobile-rn` (halts on backend / data / library / CLI / mobile-native) |
| `/audit` | **Full-stack engineering audit — universal across stacks.** Fans out across 8 specialist axes in one pass: architecture, SOLID + clean code, security (`security-auditor` + `auth-reviewer` + `secret-scan` + `deps-audit` + `threat-model`), database performance (`database-optimizer` + `query-optimizer` + `schema-reviewer`), runtime performance (`performance-optimizer` + `caching-architect` + `n-plus-one-scan`), **scalability + resilience (the differentiating axis — 13 scale-lens detectors stack-routed via `PROJECT_KIND`: hot-path, fan-out depth, sync I/O in critical path, single-instance bottleneck, lock contention, queue back-pressure, write amplification, tenant blast radius, capacity headroom, SLO delta, idempotency, statelessness, cold-start)** plus `system-architect` + `resilience-reviewer` agents and the **unhandled-I/O pass** (happy-path-only call sites with no error path / timeout / failure surfacing — ranks P1 correctness; same contract as align's `unhandled-io` class), infrastructure + capacity (`infra-architect` + `k8s-reviewer`), observability gaps (`observability-reviewer` + `telemetry-architect`). **Stack-agnostic by construction** — detectors are shape-based, not name-based. Same axis applies to backend (`every endpoint × RPS × cost`), frontend (`every route mount × visit-rate × LCP cost`), mobile (`every screen × open-rate × jank cost`), CLI / library / SDK (`every entry-point × invoke-rate × wallclock`), serverless (`every handler × invoke-rate × billed-ms`), data pipeline (`every step × per-batch row count × stage time`) — concrete fingerprint per `PROJECT_KIND`, full matrix in `commands/audit.md`. Polyglot monorepo support: per-subtree `PROJECT_KIND` drives routing; cross-stack fixes bundle into one plan row. **Cross-axis ranks** by `impact-at-target-scale × blast-radius × fix-cost`, NOT by axis. Tier order: P0 scale-blockers → P1 security/correctness → P2 high-leverage scale fixes → P3 architectural foundations → P4 tactical cleanup. Stack-appropriate target flags: `--target-rps=<N>` (backend/serverless/pipeline), `--target-p95=<ms>` (backend), `--target-vitals=<spec>` (frontend), `--target-cold-start=<ms>` (serverless/mobile), `--target-startup=<ms>` (CLI/library), `--target-bundle=<bytes>` (frontend/mobile). **Three output modes** (mutually exclusive): default (scan + rank + execute), `--plan-only` (writes `ai/audit/plan.md` — ranked P0–P4 fix-plan with closure verbs + `<file:line>` citations — executor handoff), `--assess` (writes `ai/audit/assessment.md` — 8-section senior-engineer narrative: what's good / improve / unify / extract / simplify / redesign / remove / optimize — reader handoff; stack-conditional rendering inlines Vue / React / NestJS / Rails / Django / etc. vocabulary from `_extracted-idioms.md`; closes with paste-ready `## Actionable next steps` routing to `/optimize` / `/polish` / `/unify-surfaces` / `/align` / `/security-audit`). Plus `--focus=<axes>`, `--skip-p4`. | any (any language, any framework, any shape — including monoliths, microservices, monorepos, polyglot) |

Progress tracking via `ai/{migrate,optimize,align,polish,audit,unify-surfaces}/progress.md` (single source of truth per command). First run builds the inventory; subsequent runs pick the next pending area automatically. Common flags shared by all five:

| Flag | Behaviour |
|---|---|
| `--status` | Read-only progress report; no work done. |
| `--resume` | Pick up the in-progress area. |
| `--reset <area>` | Mark one area pending; re-run from scratch. |
| `--refresh` | Re-scan codebase + merge into existing `progress.md`. New areas appended as `pending`; missing areas marked `archived`; existing rows (done / in-progress / blocked / pending) preserved untouched. Updates Summary counts. NO fix work performed — safe to run anytime. If `progress.md` is missing, builds it from scratch (same as first run). |
| `--re-audit` | IGNORE cached verdicts in the discipline ledger (`ai/{migration,align,polish}/ledger.md`) AND `final-report.md`. Re-dispatch the per-row loop on EVERY row (verified / done included). Rows that re-verify clean stay `verified` (no code change); rows where the fingerprint reappears flip to `halted` and are re-fixed in the same run. Use when: source changed since last audit, detector improvements, suspected drift. Combinable with `<scope>` to re-audit one area only. Combinable with `--restart` for "wipe progress AND ignore ledger AND re-audit everything". |
| `--ignore-ledger` | **TRULY FRESH SCAN.** Act as if no prior migration / optimize / align / polish was ever done. Backs up the discipline ledger + final-report + progress to `*-<iso>.bak.md`; re-discovers feature/module/surface inventory from source (NOT from ledger); re-derives V1→V2 paths (migrate); re-pins V1 to HEAD (migrate); re-classifies tiers; runs full audit loop on every discovered row; writes new ledger + final-report at end. **KEEPS** safety nets: ADR pre-check (so intentional V2 / V2-only deviations aren't silently reverted) + dead-code exclusion (no Zombie Port). **IMPLIES** `--re-audit` semantics. Use when: belt-and-braces re-verification, suspect original audit/sweep was incomplete, project structure / idioms / conventions changed materially. Cost: ~30-50% heavier wall-clock than `--re-audit` on the same scope (re-discovery cost). Combinable with `<scope>`. |
| `--restart` | WIPE progress entirely; back up to `ai/{cmd}/progress-<iso>.bak.md`; reset every area to pending; begin from the first area. Does NOT revert any commits already made (use `git` for that). Does NOT touch the discipline ledger by itself — pair with `--re-audit` for full reset. |
| `--dry-run` | Show what would change; no edits. |
| `--allow-dirty` | Proceed with uncommitted changes. |
| `--max-parallel=<N>` | Cap concurrent dispatch (default: 5–6). |
| `--exclude=<scope>` | Exclude areas. |
| `--surface-blockers` | Show halted findings explicitly. |

**End-of-run output**: brief block with findings closed, commits made, diff stats, test status. No phase numbers, no halt files, no ADR prompts. Genuine blockers (cross-repo, infra missing, user-must-decide) surface in a one-line "Blockers" section with resolution path.

For phase-by-phase or per-feature control, the detailed commands below still exist.

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

Single-codebase quality gate — drift, dead code, dups, silent catches, unhandled I/O (happy-path-only), SOLID, clean code, performance, security. Same parallel-dispatch + atomic-fix discipline as migration; turned inward. **Opt-in via `--include=align`**; never auto-loaded.

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

### Oracle provenance + human approval (2026-06-07)

The extraction artifacts (`_extracted-idioms.md`, `_extracted-codebase.md`, `_extracted-business.md`, `_refine-extract.md`) carry two trust layers (spec: `templates/phases/phase-2-profile.md § Provenance discipline` + `§ Oracle approval`):

- **Claim-level provenance**: every claim is `[found: <path:line>]` (a resolving citation counts as the marker), `[inferred: <basis>]`, or `[unconfirmed]` (`_extracted-business.md` uses the equivalent `[CONFIDENT]/[INFERRED]/[UNKNOWN]`). Phase 4 generators anchor rules only to `[found:]`; migration/align oracle readers treat `[inferred:]` rows as needs-source-check and never close an audit finding against an `[unconfirmed]` claim.
- **File-level approval stamp**: `approved_by:` / `approved_hash:` frontmatter — empty at generation, stamped by a human reviewer after reading. Regeneration preserves the lines; a body-hash mismatch flags "changed since approval". Surfaced by `/setup-project-health` check 9 (warn-only — advisory for solo projects, a visible review guarantee for teams).

**Why**: the oracle is what every generator and audit trusts — an inferred claim presented as found there is the Trusted Summary anti-pattern applied to our own pipeline.

### Plan-independent spot-check — `/align-recheck` and `/migration-recheck`

These are the bypass-the-ceremony commands. **No plan, no phase, no ledger required.**

- Take a **natural-language description** (`the sidebar`, `the orders module`, `customer tabs`) OR an explicit path. The agent reads `codebase-profile.md` + idioms + architecture and semantically resolves the description (same intent-interpretation model as `/add-feature` — not keyword matching).
- **Ignore the migration/alignment workflow entirely.** No phase number, no plan dependency, no required prior scan.
- **Scan source FRESH.** For migration: V1 + V2 parity audit. For align: dispatch the 12 universal detectors (+ stack-conditional UI/UX) directly against current source.
- Run the same per-feature / per-finding loop as `/find-and-fix` / `/align-phase`: DETECT → DECIDE → FIX → VERIFY → RECORD. One commit per fix.
- **Fix in place** when drift is found; pass `--re-detect-only` for read-only inspection.
- **Best-effort ledger update**: if a ledger exists, matching rows are updated; if not, the command leaves the ledger alone. Pass `--register-ledger` to register new findings into the ledger as part of the run.

Confirmation flow: confident → silent (with summary preamble); ambiguous → halt + ask which match you meant; nothing-found → halt + suggest narrowing.

Examples:
```
/migration-recheck the sidebar
/migration-recheck the page builder
/migration-recheck the customer tabs in the dashboard
/migration-recheck --phase=3                        # loop every feature in phase 3 (done rows included; status preserved unless drift surfaces; NO rollback)
/migration-recheck --phase=3 --re-detect-only       # phase-wide drift report, no edits
/align-recheck the orders module
/align-recheck the navigation header --re-detect-only
/align-recheck the auth pages --register-ledger     # also tracks findings
```

`/migration-recheck --phase=<N>` is the **non-rollback alternative** to `/migration-rollback <N>` + `/migration-fast <N>`. Reach for rollback+fast when you want a full re-port from scratch; reach for `--phase=<N>` when you want detect-and-fix-in-place that leaves clean done rows alone and only re-touches rows where fresh audit surfaces drift. Plan + ledger are required in this mode (it's the one mode where the command depends on the migration plan).

This is the user's manual override / safety check + the "I just want this area cleaned up" tool — independent of whether the formal migration/alignment workflow has been initialized for the project.

### When `/align-phase` runs

The 5-step per-finding loop (mirrors `find-and-fix` for migration):

1. **DETECT** — re-verify the fingerprint at evidence lines is still present. (Findings can age out.)
2. **DECIDE** — confirm closure verb is in the 21-verb vocabulary; confirm fix is appropriate to row's class; for functional verbs, confirm `idiom_cited` resolves.
3. **FIX** — apply the verb's edit. Touch only files in `scope`. Net-lines ≤ 0 for structural rows; small + budget for functional rows (added lines must cite the row's `idiom_cited`).
4. **VERIFY** — universal: lint + typecheck + scoped tests + re-detect + coverage non-decreasing. Class-specific: security assertion (gate denies / validator rejects / escape neutralises) for security rows; perf baseline + assertion for perf rows; a11y / visual / bundle-size for frontend UI/UX rows.
5. **RECORD** — update ledger row (`status: fixed`, `commit`, `gaps_closed`, `notes`); commit (one finding = one commit).

### Closure-verb vocabulary (21 verbs)

| Group | Verbs |
|---|---|
| Structural (5) | `remove`, `inline`, `dedupe`, `rename-comment-out`, `replace-with-shared` |
| Functional (16) | `add-gate`, `parameterize`, `escape`, `move-to-secrets`, `add-validator`, `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `extract-to-shared`, `split-extract`, `inline-magic-to-named-const`, `inline-filter-to-query`, `bump-dep`, `rename` |

A verb outside this list = NOT alignment. Route to [`/refactor`](../commands/refactor.md) / `/setup-project --refine` / a feature flow.

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

## `/ui-sweep` — project-wide UI/UX specialist

The deep UI/UX command. Goes beyond `/align-scan`'s mechanical drift detection — adds quantified coverage metrics, visual hierarchy analysis, cross-surface consistency, visual baselines + drift tracking, and a flow-based phasing strategy.

### What it covers vs `/align-scan`

| Capability | `/align-scan` | `/ui-sweep` |
|---|---|---|
| Drift detection (a11y, tokens, wrappers, i18n) | YES | YES (overlap + deeper) |
| Quantified coverage % per category | NO | YES (e.g., "73% color tokens, 62% component utilization") |
| Visual hierarchy analysis | NO | YES (per-page hierarchy score 0–100) |
| Cross-surface consistency (all list pages compared) | NO | YES |
| Visual baseline + drift screenshots | NO | YES |
| User-flow phasing (auth flow / checkout flow / etc.) | NO (phases by class) | YES |
| HTML visual report | NO (markdown) | YES |
| UI/UX-specific verbs (`consolidate-tokens`, `unify-component`, `normalize-hierarchy`, `wire-empty-state`) | NO | YES (12 specialist verbs) |

### Workflow — 4 commands

```
# Day 1 — set baseline + first sweep
/ui-sweep --baseline-only         # screenshots every page; no code change
/ui-sweep --first-run             # scans + plans + runs phase 1 (foundation: tokens + wrappers); HTML report

# Day 2+ — keep running until done
/ui-sweep                          # next pending phase (e.g., auth flow → checkout flow → dashboard)
/ui-sweep                          # ...
/ui-sweep                          # final cross-phase verification
```

The command figures out what step you're on automatically — just keep running `/ui-sweep`.

### Optional flags

- `--with-iterate` — after cleanup phase, dispatches `design-iterate` per page for visual polish (3 variants, you pick).
- `<phase>` — run a specific phase (e.g., `/ui-sweep 3`).
- `--scope=<path>` — restrict to a sub-tree.
- `--report-only` — re-generate HTML report from existing ledger; no scan.
- `--detector=<list>` — narrow detectors.

### Output

- `ai/ui-sweep/report-<date>.html` — interactive report: screenshots, hierarchy heatmaps, coverage dashboards, cross-surface matrix, top-10 worst surfaces, recommendations.
- `ai/ui-sweep/baseline/<iso>/*.png` — per-route screenshots at 360 / 768 / 1280 px.
- `ai/ui-sweep/ledger.md` — UI/UX-specific findings (separate from `ai/align/ledger.md`).

### Required project anchors

`_extracted-idioms.md` must declare:
- `§ Tokens` — design token system (colors, spacing, typography, radii, shadows).
- `§ Wrappers` — shared component inventory (the project's `AppButton`, `BaseDataTable`, etc.).
- `§ Surfaces` — prototypical examples per surface type (list-page, detail-page, form, modal).
- `§ Breakpoints` — responsive breakpoints (default: 360 / 768 / 1280).
- `§ Voice` (optional) — tone of voice guide for cross-page coherence detector.

If anchors missing → run `/setup-project --refine` first.

### Pre-requisites

- `PROJECT_KIND` is `frontend-*`.
- Playwright MCP wired (for screenshots + DOM analysis).
- Mechanical CI green at HEAD.
- Working tree clean.

## `/ui-crawl` + `/ui-crawl-fix` — paired QA crawler + auto-fixer (v1.2+)

**`/ui-crawl` is the cross-route QA crawler; `/ui-sweep`'s sibling, not its replacement.** `/ui-sweep` is the deep specialist with HTML report + visual baselines + flow-based phasing; `/ui-crawl` is the fast machine-readable crawler — log in once, hit every route, screenshot at 3 breakpoints + dark + RTL, run axe-core, walk tabs / dialogs / dropdowns, capture console + network errors, output ranked findings JSON + MD.

### When to use which

| Scenario | Command |
|---|---|
| Pre-release sweep, recurring CI, post-token-change regression scan | `/ui-crawl` |
| Quarterly UI/UX cadence, baseline + drift, hierarchy / coverage metrics, HTML report | `/ui-sweep` |
| Mechanical findings to mass-fix at the wrapper level | `/ui-crawl-fix` after `/ui-crawl` |
| Single-area visual polish | `/enhance-ui <description>` |
| Read-only UX audit | `/design-review` |

### Workflow — paired DETECT → FIX → VERIFY loop

```
/ui-crawl --smoke                    # ~5 min triage — 1 route per module
/ui-crawl                            # full crawl across all routes (~30–60 min)
/ui-crawl-fix --safe-only --verify   # auto-fix mechanical findings; re-crawl to confirm
/ui-crawl --filter=<area>            # spot-check after manual fixes
```

### What `/ui-crawl-fix` auto-fixes (8 safe-list classes)

`color-contrast` (token swap) · `button-name` (aria-label injection on icon-only buttons inside shared wrappers) · `label` (`for`/`id` wiring in `FormField`) · raw `<Dialog>` / `<Dropdown>` / `<MultiSelect>` in pages (swap to `<BaseModal>` / `<BaseDropdown>` / `<BaseMultiSelect>`) · `<v-html>` / `dangerouslySetInnerHTML` without sanitize wrapper · hardcoded `{ en: '', ar: '' }` translation refs · `<a target="_blank">` missing `rel="noopener noreferrer"` · empty `catch {}` swallows.

### What `/ui-crawl-fix` does NOT auto-fix (human triage)

Broken dialog triggers · horizontal overflow at any breakpoint · page didn't load / uncaught JS error · heading hierarchy skip · network 5xx · `aria-required-parent` / `aria-required-children` mismatches · color values not rooted in tokens.

### Output

- `ai/audits/ui-crawl-inventory.json` — route manifest (routes + dialogs + dropdowns + tabs counts).
- `ai/audits/ui-crawl-findings.json` — full machine-readable findings.
- `ai/audits/ui-crawl-findings.md` — human triage report, ranked by severity.
- `ai/audits/ui-crawl-fix-log.md` — append-only log of auto-fix runs.
- `tests/crawl/.screenshots/` — 5+ per route.
- `tests/crawl/.report/` — Playwright HTML report.

### Pre-requisites

- `PROJECT_KIND` is `frontend-*` (or `mobile-web`).
- Dev server running at a known URL (default `http://localhost:3000`).
- Test account with broad permissions; credentials in `tests/crawl/.env` (gitignored).
- `_extracted-idioms.md` populated (selectors + wrapper inventory).
- `@playwright/test` + `@axe-core/playwright` (auto-installed if missing).
- Playwright project at `tests/crawl/` (`auth.setup.ts` + `ui-crawl.spec.ts` + `aggregate.ts` + `lib/`).

### Hard rules

- **No fixes during `/ui-crawl`.** It's read-only against the running app.
- **One finding-class = one commit** (inherited from `align-discipline.md`).
- **No new abstractions.** If a fix needs a wrapper that doesn't exist in `_extracted-idioms.md`, halt; route to `/setup-project --refine`.
- **Re-detect mandatory.** `--verify` re-crawls affected modules; gap-count parity (closed == in-count) is the gate.
- **Halt on regression.** New findings after a fix → revert the commit and surface.

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
| `validate-optimize-artifacts.sh` | **`/optimize` gate** — Phase 0 (`ai/optimize/_architecture-decisions.md`): four non-empty evidence blocks, detector `Modules scanned ≥ 1`, each `### F-A-*` cites `<path:line>`, hand-wave grep, `.claude/_extracted-idioms.md` present (`--strict`: oracle referenced). **Ledger** (`ai/optimize/ledger.md`): fenced YAML `id:` rows; terminal rows `gaps_in == gaps_closed`; structural-class net-lines vs `--phase-base..HEAD` (warn if git/base missing); functional-style net-positive rows should cite idioms in `ai/optimize/findings/<id>.md`. Optional scan of `ai/optimize/findings/*.md` for hand-waves. |
| `validate-refactor-artifacts.sh` | **`/refactor` gate** — **Ledger** (`ai/refactor/ledger.md`): fenced YAML `id:` rows; `closure_verb` must be one of the 10 `refactoring-sweep` verbs; terminal rows `gaps_in == gaps_closed`; class `refactoring` net-lines vs `--phase-base..HEAD` (warn if git/base missing). Optional scan of `ai/refactor/findings/*.md` for hand-waves. `--self-test` smoke test (writes under `tmp/`). See [`templates/tool-adapters/_refactor-pack-coverage.md`](../templates/tool-adapters/_refactor-pack-coverage.md). |
| `validate-polish-artifacts.sh` | Per-surface artifacts for `/polish`: stack-conditional checks (frontend visual hierarchy / backend API consistency / data schema consistency / mobile platform conventions), no hand-waves, evidence-resolves. **Frontend-only**: `check_frontend_verb_vocabulary` rejects any `closure_verb:` outside the closed 18-verb `ui-design-sweep` set (mirrors how `validate-refactor-artifacts.sh` enforces refactoring-sweep's 10 verbs). |
| `migration-detect-existing.sh` | Phase 1 of `/port-feature`: detects whether V2 already implements a feature (none / partial / full). |
| `migration-validate-paths.sh` | Phase 4 of `/port-feature`: validates planned file paths against V2 module shape. |
| `audit-adapter-coverage.sh` | Per-pack adapter coverage: every pack rule has equivalent translations in Cursor / OpenCode / Aider / etc. |
| `audit-file-health.sh` | Heuristic risk scan: line count, hand-waves, MUSTs, phase-ladder count, inbound refs. Used to triage which files deserve attention. |
| `audit-stack-leakage.sh` | **Template pack hygiene** — scans `commands/` + universal/pack `templates/**` for single-stack-only wording; **FAIL** when diversity / `<TBD:...>` contract is violated; **WARN** on isolated tokens in pack-level files. Run from claude-config root; wired into `audit-setup.sh` as C2f. |
| `audit-command-dry.sh` | **Command DRY** — scans `commands/*.md` + `templates/packs/*/commands/*.md`. **FAIL** if `\bSOLID\b` / SOLID expansions / `solid-violation` / `clean code` appear without a `core-discipline.md` link; **FAIL** if all 7 canonical Phase 3 path markers appear without `phase-3-always-reads.md`; **WARN** if a `## Mechanical halt — hand-wave grep` section lacks `hand-wave-grep.md`. Wired into `audit-setup.sh` as **C2g** (after C2f). |
| `sync-to-global.sh` | Symlinks this repo's `commands/`, `templates/packs/migration/`, etc. into `~/.claude/`. |
| `verify-sync.sh` | Detects drift between this repo and `~/.claude/` symlinks. |

### Parallel orchestrators (close the gap for non-Claude tools)

The `/migrate`, `/align`, `/optimize`, `/polish`, `/security-audit`, `/perf-audit`, `/i18n-audit`, `/a11y-audit`, `/db-audit`, `/ui-sweep` commands all depend on **parallel sub-agent dispatch** (`/refactor` is targeted-only — no parallel orchestrator). — only Claude Code (and OpenCode) implement the primitive natively. For other headless-capable tools (Kimi / Aider / Codex), these orchestrator scripts fan out N parallel CLI processes, one per ledger row. Same discipline runs in each worker; coordination is via the ledger file with file locks.

| Script | Mirrors | Reads ledger |
|---|---|---|
| `parallel-fan-out.sh` | engine — generic xargs-based dispatcher (used by all wrappers below); pass **`--ledger=<path>`** so `flock` targets the correct pack ledger (default lock remains `ai/migration/ledger.md` when omitted) | n/a |
| `_parallel-tool-config.sh` | engine — tool→headless-invocation map (kimi / aider / opencode / codex / claude) | n/a |
| `migrate-parallel.sh` | `/migrate` | `ai/migration/ledger.md` |
| `align-parallel.sh` | `/align` | `ai/align/ledger.md` |
| `optimize-parallel.sh` | `/optimize` | `ai/optimize/ledger.md` |
| `polish-parallel.sh` | `/polish` | `ai/polish/ledger.md` |
| `audit-parallel.sh` | 6 pack-level audits via `--pack=<name>`: security, perf, i18n, a11y, db, ui-sweep | `ai/<pack>/ledger.md` |

**Workflow**: build the ledger once in Claude Code (`/migration-scan`, `/align-scan`, `/security-audit`, etc.), then run the parallel script with any tool to drive per-row execution:

```bash
# 4 simple-surface
~/.claude/scripts/migrate-parallel.sh   --tool=kimi --parallel=6
~/.claude/scripts/align-parallel.sh     --tool=kimi --parallel=6
~/.claude/scripts/optimize-parallel.sh  --tool=kimi --parallel=6
~/.claude/scripts/polish-parallel.sh    --tool=kimi --parallel=6

# 6 pack-level audits via single wrapper
~/.claude/scripts/audit-parallel.sh --pack=security --tool=kimi --parallel=6
~/.claude/scripts/audit-parallel.sh --pack=perf     --tool=aider --parallel=4
~/.claude/scripts/audit-parallel.sh --pack=i18n     --tool=opencode --parallel=8
```

Common flags (work on every wrapper): `--tool`, `--parallel`, `--max-tasks`, `--status`, `--ledger`, `--log-dir`, `--dry-run`. Per-worker logs land at `ai/_parallel-runs/<cmd>-<iso>/<row-id>.log`; failed rows surface at end.

**Tradeoffs vs Claude's native parallel**:
- Each worker is a separate tool process (independent context window — no shared scratchpad).
- Token cost ~30–50% higher (each process re-reads project files); offset by using cheaper models (Kimi K2 / DeepSeek).
- 2–3× slower than Claude's native dispatch, but way faster than serial.
- File locking on the ledger handles concurrent row updates cleanly.

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
