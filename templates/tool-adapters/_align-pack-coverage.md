# Align pack — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces the align pack's artifacts when `--include=align` is selected by `/setup-project`.

The align pack is **non-negotiable** in the same sense the migration pack is — its discipline rule (`align-discipline.md`) is the contract every tool's setup must preserve. Adapters with low capability (Rules-only) translate the rule fully; adapters with full capability (R+A+S+C+H) get the full pack.

> **Why this file exists**: align is migration discipline turned inward. The same Trusted-Summary / Hand-waved-Enumeration / Reinvented-Wrapper / Silent-Catch failure modes that hit V1→V2 ports also hit single-codebase quality sweeps. The discipline rule (`align-discipline.md`) is self-sufficient precisely so rule-only tools (Aider, Codex, Gemini) get the full quality-gate floor without depending on agent / skill / command dispatch.

## Capability mapping per tool

| Tool | Full discipline via | Rule-only fallback |
|---|---|---|
| Claude Code | All artifacts (rule + skills + commands + hooks) | n/a |
| OpenCode | All artifacts (rule + skills + commands) | n/a |
| Cursor | rule + skills + commands + hooks | n/a |
| Copilot | rule + skills + commands | n/a |
| Continue | rule + commands; skills convention-based | partial — rule must self-suffice |
| Cline | rule + commands (workflows); no skills | rule must self-suffice for skill content |
| Windsurf | rule + commands (workflows); no skills | rule must self-suffice for skill content |
| Aider | rule only | full reliance on self-sufficient rule |
| Codex | rule only | full reliance on self-sufficient rule |
| Gemini | rule only | full reliance on self-sufficient rule |

**Conclusion**: every tool MUST receive a faithful translation of `align-discipline.md` (the self-sufficient rule). The 11 finding categories, 21-verb closure vocabulary, 11 per-finding audit halts, 14-check phase-exit gate, anti-pattern catalogue, and tool-agnostic procedures (scan / find-and-align / gate) are all inlined in the rule precisely so rule-only tools have the full surface.

The align pack ships **no agents** (unlike migration). All detection is delegated to the `detect-drift` skill (which itself dispatches existing agents from `code-quality/`, `security/`, `frontend/`, `ui-ux/` packs). This simplifies adapter coverage — every tool that supports rules + skills gets the full surface.

## Sibling top-level commands — `/optimize` and `/polish` (NOT in this pack)

`/optimize` and `/polish` are top-level orchestration commands (siblings to `/align`, NOT pack members). They dispatch different skill sets:

- **`/optimize`** is backed by `architectural-diagnosis` + `refactoring-sweep` (code-quality pack v1.1+) — Phase 0 architectural diagnosis runs FIRST, then tactical refactoring + SOLID + perf sweep. Foundation-first ordering means architectural fixes cascade and dissolve tactical findings (47 N+1 → 22 after fetching moves to right layer; etc.).
- **`/polish`** is stack-conditional, dispatching `a11y-quick-check`/`design-iterate`/`design-token-audit`/`motion-audit` (ui-ux pack) for `frontend-*`, `api-consistency-audit` (backend pack v1.1+) for `backend-*`, `schema-consistency-audit` (database pack v1.1+) for `data-*`, and `platform-conventions-audit` (mobile pack v1.1+) for `mobile-*`.

Adapters MUST surface all four top-level commands (`/migrate`, `/optimize`, `/align`, `/polish`) in their command surface; they are the recommended user entry-points above the pack-level phased commands.

## Simple-surface entry — `/align` (top-level command)

Above the phased `/align-scan` → `/align-plan` → `/align-fast` ceremony, the top-level `/align [<scope>]` command provides a one-shot entry point. Same discipline runs internally; user sees only the brief end-of-run summary.

- **Source**: `commands/align.md` (top-level, NOT in pack folder — installed alongside pack commands).
- **Progress tracking**: `ai/align/progress.md` (single source of truth across multi-day runs).
- **Flags**: `--status`, `--resume`, `--reset <area>`, `--refresh`, `--re-audit`, `--restart`, `--dry-run`, `--allow-dirty`, `--max-parallel=<N>`, `--focus=<list>`, `--exclude=<scope>`, `--surface-blockers`.

**`--re-audit` semantics** — discards `verified`/`done` verdicts in the discipline ledger; re-dispatches the per-row loop on every row. Rows that re-verify clean stay `verified`; rows with reappearing fingerprints flip to `halted` and re-fix in same run. Combinable with scope (re-audit one area only) and with `--restart` (full reset).

**`--ignore-ledger` semantics** — backs up `ai/align/*` (ledger, findings, scan-report, plan, progress) to timestamped `*.bak.md` files; re-discovers idiom inventory from source; re-runs all detectors against current state; re-creates the scan report + plan + ledger from scratch. KEEPS ADR pre-check (intentional convention exemptions preserved). IMPLIES `--re-audit`. Use when: idioms changed materially OR you suspect previous align was incomplete. Combinable with `<scope>`.

**`--refresh` semantics** — re-scans codebase, merges with existing progress: new areas → `pending`, missing → `archived`, existing rows preserved. NO fix work. Safe to run anytime; auto-creates `progress.md` if missing.

**`--restart` semantics** — backs up current progress to `ai/align/progress-<iso>.bak.md`, resets every area to pending, begins from the first area. Does NOT revert commits already made.

Adapter responsibility:
1. Every tool that exposes commands MUST surface `/align` in its native command surface (`.cursor/commands/`, `.opencode/commands/`, `.qwen/commands/`, `.github/prompts/`, `.clinerules/workflows/`, `.windsurf/workflows/`, `.continue/prompts/`).
2. The "no phases / halts / ADRs in user-facing output" contract MUST be preserved — adapters MUST NOT downgrade the simple command into the verbose phased flow.
3. Progress file location (`ai/align/progress.md`) MUST be honoured so multi-day runs survive across sessions.
4. For rule-only tools (Aider / Codex / Gemini), document as a manual procedure: "describe the area; agent reads project profile, scans source via universal detectors, fixes drift in parallel, brief end-of-run summary."

## Verification flow — `--re-audit`

`/align-fast <N> --re-audit` and `/align-final --re-audit` re-dispatch the detector for every row, including ones at `status: verified`. Mirrors `/migration-fast --re-audit`. Catches false-verified or drifted rows; re-fixes them in the same run.

Adapter responsibility: this flag MUST be exposed in tool-native command surfaces (Cursor `.cursor/commands/align-fast.md`, OpenCode `.opencode/commands/`, Qwen `.qwen/commands/`, Copilot `.github/prompts/`, Cline `.clinerules/workflows/`, Windsurf `.windsurf/workflows/`). For rule-only tools (Aider / Codex / Gemini), document the flag in the rule's "Tool-agnostic procedure" section so users can invoke the equivalent re-detection manually.

## Validator script — `validate-align-artifacts.sh` (v1.5+)

Now ships at `scripts/validate-align-artifacts.sh` (589 lines). Implements 7 of the 14 gate checks mechanically: evidence-resolves, no-handwaves, closure-verb-vocab, no-new-symbols (idiom-named exemption), structural-net-lines-non-positive, scope-boundary, security-tier-minimum.

Remaining 7 (test-coverage, frontend-regression, idiom-citation, security-assertion, perf-baseline, oracle-unmodified, ledger-completeness) stay agent-side until v2.

Adapter responsibility: install the script as a hook integration per tool (see Validator script — universal callable section).

## Reviewer-approval mechanism (v1.5+)

Heavy-tier rows pause for reviewer approval. Ledger field: `reviewer_approval: <name>@<iso>`. Status `pending-review` between fix and signoff. Default reviewer from `CODEOWNERS` or `ai/align/_anchors.md`. 7-day timeout; no auto-fail.

Adapter responsibility: surface pending-review halts to the user. Tools with native PR review surfaces MAY auto-populate `reviewer_approval` on merge.

## Mid-port tier promotion — `/align-promote-tier` (v1.5+)

`/align-promote-tier <id> <new-tier> [--reason="<text>"]`. Demotion of security rows is forbidden.

Adapter responsibility: surface in command surface.

## Idiom-drift propagation (v1.5+)

`/align-scan` compares oracle file hashes against prior scan; surfaces "Idiom drift detected" with affected ledger rows. `/align-replan --include-drifted` re-phases.

Adapter responsibility: include the drift section in the scan command's output template translation.

## Plan-independent ad-hoc spot-check — `/align-recheck`

`/align-recheck <description-or-path>` is the user's bypass-the-ceremony tool (v1.4.0). **NO plan / phase / ledger required.** Accepts natural-language descriptions OR paths. Semantic resolution via codebase-profile + idioms (same intent-interpretation model as `/add-feature`). Scans source FRESH via the 12 universal detectors directly — no cache lookup, no ledger-row dependency.

Adapter responsibility:
1. Every tool that exposes commands MUST surface `/align-recheck` in its native command surface (`.cursor/commands/`, `.opencode/commands/`, `.qwen/commands/`, `.github/prompts/`, `.clinerules/workflows/`, `.windsurf/workflows/`, `.continue/prompts/`).
2. The semantic resolution flow (read codebase-profile + idioms → understand intent → confirm-or-run) MUST be preserved. Adapters MUST NOT downgrade to keyword tokenization.
3. The plan-independence MUST be preserved. Adapters MUST NOT add a "ledger required" pre-flight check that wasn't in the source rule.
4. For rule-only tools (Aider / Codex / Gemini), document as a manual procedure: "describe the area you want re-checked; the agent reads the project profile, scans source via the universal detectors, fixes drift, optionally records into ledger if one exists."

## Required artifacts per project

Every adapter setup that includes `--include=align` MUST also propagate these elements:

1. **`_extracted-idioms.md` precondition** — align halts on empty oracle. Adapters that auto-load align MUST verify `_extracted-idioms.md` is non-empty (or surface the `/setup-project --refine` prompt).

2. **`PROJECT_KIND` anchor** — populated in `_extracted-codebase.md § Gold standards`. Switches stack-conditional detector dispatch (frontend / backend / data / mobile). The validator + skills read this so the detector set is project-shape-agnostic.

3. **`ai/align/` directory** — created by `/align-scan` on first run; contains `ledger.md`, `scan-report.md`, `findings.md`, `plan.md`, `halts/`, `runs/`, `gate-history.md`, `rollback-history.md`, `park-history.md`, `impact/` (heavy-tier), `final-report-<date>.md`.

4. **Validator script** `scripts/validate-align-artifacts.sh` — runs the 14 phase-exit checks. Universal callable from any tool's hook / CI / pre-commit.

5. **Per-class detector tools** — installed per `_extracted-codebase.md § Gold standards` (e.g., `jscpd` for duplicates, `ts-unused-exports` for dead code, `axe-core` for a11y, `semgrep` for security). Adapters surface install commands when tools are missing.

## Per-tool translation expectations

### Claude Code (`.claude/`)
- Full pack as-is.
- `align-discipline.md` → `.claude/rules/align-discipline.md`
- `detect-drift.md`, `find-and-align.md` → `.claude/skills/`
- All 9 commands → `.claude/commands/`
- `validate-align-artifacts.sh` → `~/.claude/scripts/` (user installs once globally)
- Hooks: `.claude/settings.json` PostToolUse hook on edits to `ai/align/**` runs the validator.

### OpenCode (`AGENTS.md` + `.opencode/`)
- Rule's contents inlined into `AGENTS.md` "Codebase alignment" section + linked from `.opencode/`.
- Skills → `.opencode/skills/detect-drift/SKILL.md`, `.opencode/skills/find-and-align/SKILL.md`.
- Commands → `.opencode/commands/align-scan.md`, `.opencode/commands/align-fast.md`, etc.

### Cursor (`.cursor/`)
- Rule → `.cursor/rules/align-discipline.mdc` (with frontmatter `globs: ai/align/**`)
- Skills → `.cursor/skills/detect-drift/SKILL.md`, `.cursor/skills/find-and-align/SKILL.md`
- Commands → `.cursor/commands/align-scan.md`, `.cursor/commands/align-fast.md`, etc.
- Hooks → `.cursor/hooks.json` triggering `validate-align-artifacts.sh` on file edits in `ai/align/`

### Copilot (`.github/`)
- Rule → `.github/instructions/align-discipline.instructions.md`
- Skills → `.github/skills/detect-drift/SKILL.md`, `.github/skills/find-and-align/SKILL.md`
- Commands → `.github/prompts/align-scan.prompt.md`, `.github/prompts/align-fast.prompt.md`, etc.
- Or `chatmodes/` for sub-agent-style chat modes for `/align-phase` (which dispatches per-finding sub-tasks).

### Continue (`.continue/`)
- Rule → `.continue/rules/align-discipline.md`
- Skills → expressed as prompts in `.continue/prompts/detect-drift.md`, `.continue/prompts/find-and-align.md` (Continue treats skills as prompt templates)
- Commands → `.continue/prompts/align-scan.md`, `.continue/prompts/align-fast.md`, etc.

### Cline (`.clinerules/`)
- Rule → `.clinerules/align-discipline.md`
- Commands → `.clinerules/workflows/align-scan.md`, `.clinerules/workflows/align-fast.md`, etc.
- **Skills NOT supported natively.** The skill content (detect-drift's procedure, find-and-align's 5-step loop) is inlined into the rule. The self-sufficient rule already does this — the "Tool-agnostic procedure" section covers scan / find-and-align / gate end-to-end.

### Windsurf (`.windsurf/`)
- Rule → `.windsurf/rules/align-discipline.md`
- Commands → `.windsurf/workflows/align-scan.md`, `.windsurf/workflows/align-fast.md`, etc.
- Same skill-inlining as Cline.

### Aider (`CONVENTIONS.md`)
- Rule → appended to `CONVENTIONS.md` under a `## Codebase alignment` section.
- **No commands, no skills.** Aider relies entirely on the rule for alignment discipline.
- Aider users invoke procedures by reading the rule's "Tool-agnostic procedure" section (scan + find-and-align + gate are all inlined) and following them manually.
- The validator script `validate-align-artifacts.sh` is the only callable verifier — Aider users run it from the shell or as a pre-commit hook.

### Codex (`AGENTS.md` + `~/.codex/config.toml`)
- Rule → `AGENTS.md` "Codebase alignment" section.
- Same rule-only fallback as Aider for the procedural surface.

### Gemini CLI (`GEMINI.md`)
- Rule → `GEMINI.md` "Codebase alignment" section.
- **Rule-only tool.** Same as Aider/Codex.

### Qwen Code (`QWEN.md` + `.qwen/`)
- Rule → `.claude/rules/align-discipline.md` content mirrored into `QWEN.md` § `## Codebase alignment`.
- Skills → `.qwen/skills/detect-drift/SKILL.md`, `.qwen/skills/find-and-align/SKILL.md`.
- Commands → `.qwen/commands/align-scan.md`, `.qwen/commands/align-fast.md`, etc. (one file per align command).
- Hooks → `.qwen/settings.json` `hooks.PostToolUse` triggering `validate-align-artifacts.sh` on edits to `ai/align/**`.

## Validator script — universal callable

`scripts/validate-align-artifacts.sh` is callable from any tool's hook system or directly from the shell. Setup per tool:

| Tool | Hook integration |
|---|---|
| Claude Code | `.claude/settings.json` PostToolUse hook on edits to `ai/align/**` |
| Cursor | `.cursor/hooks.json` `onSave` for `ai/align/**` |
| Copilot | GitHub Actions workflow (no native pre-commit) |
| Continue | (no native hook) — manual pre-commit hook or CI workflow |
| Cline / Windsurf | (no native hook) — manual pre-commit or CI |
| Qwen Code | `.qwen/settings.json` `hooks.PostToolUse` matcher on edits to `ai/align/**` |
| Aider / Codex / Gemini | Pre-commit hook in `.git/hooks/pre-commit` (manual install) OR CI workflow |

The script returns non-zero on any failure; tool integrations should treat that as a blocking error.

The script implements 14 checks:
1. Ledger completeness — every phase row in `{fixed, archived-pre-existing, parked}`.
2. Gap-count parity — `gaps_closed == len(evidence)` for every fixed row.
3. Net-lines on structural rows ≤ 0.
4. No new symbols (with idioms-named exemption).
5. No scope creep — every commit's files ⊂ row.scope.
6. Mechanical (lint + typecheck + tests) at HEAD.
7. Coverage non-decreasing.
8. Frontend regressions (a11y, visual, bundle-size) for `frontend-*`.
9. Oracle unmodified (`_extracted-idioms.md` / `ai/conventions.md` / `ai/architecture.md`).
10. Per-tier artifact set complete.
11. Functional adds cite idiom — `check_added_lines_cite_idioms`.
12. Security assertion present — for every security row.
13. Perf baseline + assertion present — for every perf row.
14. Security tier minimum — no security row at trivial; critical at heavy.

## Adapter responsibilities

When an adapter ships the align pack:

1. **MUST translate the rule** (`align-discipline.md`) faithfully — including the inlined 11 finding categories, 21-verb closure vocabulary, 11 per-finding audit halts, 14 phase-exit checks, anti-pattern catalogue, and tool-agnostic procedures (scan / find-and-align / gate). Do NOT abridge.
2. **MUST translate or document skills** (`detect-drift`, `find-and-align`) to the tool's native format if supported. If not supported, document in the rule's "Tool-agnostic procedure" that the procedural detail is inlined.
3. **MUST install or document `validate-align-artifacts.sh`** as a pre-commit / CI / hook integration.
4. **MUST translate all 9 commands** (`align-scan`, `align-plan`, `align-phase`, `align-gate`, `align-fast`, `align-status`, `align-final`, `align-rollback`, `align-park`) — or for rule-only tools, document them as procedural recipes in the rule.
5. **MUST verify `_extracted-idioms.md` precondition** — align halts on empty oracle. Adapter setup surfaces a recommendation to run `/setup-project --refine` first if the oracle is missing.
6. **MUST NOT silently drop the align pack on tools with limited capability.** A rule-only tool gets the rule (which is sufficient — the self-sufficient rule has the full surface inlined).

## Failure mode protections

The same anti-patterns that hit migration ports also hit alignment sweeps. The validator script pattern-recognises:

- **Trusted Summary** — `check_evidence_resolves` validates every row's `evidence` is a real `<path:line>` containing the claimed fingerprint.
- **Hand-waved Finding** — `check_no_handwaves` greps for hand-wave tokens (`etc.`, `...`, `several`, `multiple`, `~N`).
- **Net-Positive Cleanup** — `check_net_lines_structural` measures structural-row diffs.
- **Reinvented Idiom in Functional Verb** — `check_added_lines_cite_idioms` enforces idiom citation for functional adds.
- **Silent Coverage Drop** — `check_test_coverage_nondecreasing`.
- **Bare Security Fix** — `check_security_assertion_present` fails if a security row's commit lacks a co-committed assertion test.
- **Hopeful Perf Fix** — `check_perf_baseline_present` fails if a perf row lacks baseline + assertion.
- **Tier Demotion** — `check_security_tier_minimum` fails if a security row is set to trivial.
- **Oracle Drift** — `check_oracle_unmodified` fails on any modification of the gold-standard files.
- **Scope creep** — `check_scope_boundary` fails if touched files are outside any row's `scope`.

This means: a Cursor user, a Copilot user, an Aider user, and a Claude Code user all get the same enforcement floor when they run the validator. The discipline is universal; the tool surface is per-adapter convenience.

## Composition with other packs

Align dispatches detectors from other packs at scan time:

| Detector | Source pack | Used by class |
|---|---|---|
| `dead-code-finder` agent | `code-quality/agents/` | dead-code |
| `refactorer` agent | `code-quality/agents/` | over-abstraction, SOLID |
| `code-reviewer` agent | `code-quality/agents/` | clean-code |
| `performance-optimizer` agent (or pack equivalent) | `code-quality/agents/` | performance |
| `security-auditor` agent | `security/agents/` | security |
| `deps-audit` skill | `security/skills/` | security (vuln-deps subclass) |
| `accessibility-auditor` agent | `frontend/agents/` | a11y (frontend stacks) |
| `i18n-auditor` agent | `frontend/agents/` | i18n (frontend stacks) |
| `data-flow-auditor` agent | `frontend/agents/` | UI state coverage (frontend stacks) |
| `design-token-audit` skill | `ui-ux/skills/` | design-token drift (frontend stacks) |
| `motion-audit` skill | `ui-ux/skills/` | motion drift (frontend stacks) |

When `/setup-project --include=align` runs, it auto-includes the source packs above (code-quality + security baseline; frontend + ui-ux for `frontend-*` projects).

## Selection rules

`/setup-project --include=align` is **opt-in only**. The align pack does NOT auto-load — alignment is a deliberate cadence, not a constant. Auto-loading would conflict with feature work.

Auto-detection signals that surface a recommendation (but don't auto-include):
- An existing `ai/align/ledger.md` (prior alignment effort exists).
- `_extracted-idioms.md` populated AND no recent `/align-scan` run (eligible for first sweep).
- A scheduled cron job pointing to `/align-scan` (recurring sweep).

When a signal is detected, `/setup-project` surfaces: "Detected potential alignment workflow. Add `--include=align`? [y/N]".
