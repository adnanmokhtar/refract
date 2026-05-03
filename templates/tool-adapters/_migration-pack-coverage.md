# Migration pack — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces the migration pack's artifacts when `--include=migration` is selected by `/setup-project`.

The migration pack is **non-negotiable** in the sense that its discipline rule (`migration-discipline.md`) is the contract every tool's setup must preserve. Adapters with low capability (Rules-only) translate the rule fully; adapters with full capability (R+A+S+C+H) get the full pack.

> **Why this file exists**: F039 (geography-mappings audit) shipped to production on Claude Code without enforcing the discipline because `/migration-phase` was a permissive shell. The fix made `migration-discipline.md` self-sufficient. This file documents how every other tool inherits that fix.

## Capability mapping per tool

| Tool | Full discipline via | Rule-only fallback |
|---|---|---|
| Claude Code | All artifacts (rule + agents + skills + commands + hooks) | n/a |
| OpenCode | All artifacts (rule + agents + skills + commands) | n/a |
| Cursor | rule + skills + commands + hooks (agents = convention only) | n/a |
| Copilot | rule + agents + skills + commands | n/a |
| Continue | rule + commands; agents/skills convention-based | partial — rule must self-suffice |
| Cline | rule + commands; no agents/skills | rule must self-suffice for agents/skills content |
| Windsurf | rule + commands; no agents/skills | rule must self-suffice for agents/skills content |
| Aider | rule only | full reliance on self-sufficient rule |
| Codex | rule only (+ agents convention) | full reliance on self-sufficient rule |
| Gemini | rule only | full reliance on self-sufficient rule |

**Conclusion**: every tool MUST receive a faithful translation of `migration-discipline.md` (the self-sufficient rule). The 9 contract sections, 10 hard halts, frontend audit axes, frontend anti-pattern catalogue, and tool-agnostic procedures are inlined in the rule precisely so rule-only tools have the full surface.

## Simple-surface entry — `/migrate` (top-level command)

Above the phased `/migration-scan` → `/migration-plan` → `/migration-fast` ceremony, the top-level `/migrate [<scope>]` command provides a one-shot entry point. Same discipline runs internally; user sees only the brief end-of-run summary.

- **Source**: `commands/migrate.md` (top-level, NOT in pack folder — installed alongside pack commands).
- **Progress tracking**: `ai/migrate/progress.md` (single source of truth across multi-day runs).
- **Flags**: `--status`, `--resume`, `--reset <area>`, `--refresh`, `--re-audit`, `--re-audit --include-superseded`, `--restart`, `--dry-run`, `--allow-dirty`, `--max-parallel=<N>`, `--exclude=<scope>`, `--include-dead`, `--surface-blockers`.

**`--re-audit` semantics** — discards `verified` / `done` verdicts in `ai/migration/ledger.md` AND ignores `final-report.md`'s authority to skip rows; re-dispatches the per-feature loop (DETECT → DECIDE → FIX → VERIFY → RECORD) on every row. Mirrors `/migration-fast --re-audit` from the pack. Use when: V1 / V2 changed since the original audit, detector improvements, suspected drift on a "complete" migration. `--include-superseded` adds superseded / deprecated rows back into the audit pool (rare; for verifying dead-V1 reachability claims still hold).

**`--ignore-ledger` semantics** — backs up `ai/migration/ledger.md` + `final-report.md` + `ai/migrate/progress.md` to timestamped `*.bak.md` files; treats ledger as empty for the run; re-discovers V1 features from V1 source; re-derives V1→V2 path mapping; re-pins V1 to HEAD; re-classifies tiers; runs full audit loop on every discovered feature; writes new ledger + final-report at end. KEEPS the ADR pre-check (accepted intentional V2 deviations are still preserved — no silent revert of user-decided improvements) and the 6-axis dead-V1 exclusion (no Zombie Port). IMPLIES `--re-audit`. Use when: absolute belt-and-braces re-verification; suspect original audit was incomplete; treat the project as fresh-from-zero. Cost: heavier than `--re-audit` by ~30-50% (re-discovery cost). Combinable with `<scope>`: `/migrate the inventory module --ignore-ledger`.

**`--refresh` semantics** — re-scans V1 + V2, merges with existing progress: newly-added V1 features → `pending`, removed V1 features → `archived`, existing rows preserved. Re-checks dead-V1 reachability for all rows; newly-dead rows flip to `deprecated`. NO port work. Auto-creates `progress.md` if missing.

**`--restart` semantics** — backs up current progress to `ai/migrate/progress-<iso>.bak.md`, resets every area to pending, begins from the first area. Does NOT revert commits already made.

Adapter responsibility:
1. Every tool that exposes commands MUST surface `/migrate` in its native command surface (`.cursor/commands/`, `.opencode/commands/`, `.qwen/commands/`, `.github/prompts/`, `.clinerules/workflows/`, `.windsurf/workflows/`, `.continue/prompts/`).
2. The "no phases / halts / ADRs in user-facing output" contract MUST be preserved — adapters MUST NOT downgrade the simple command into the verbose phased flow.
3. The internal CORE PHILOSOPHY (V1 wins on behaviour; V2 wins on structure; no V1-verification halts) MUST flow into the simple command's silent execution.
4. Progress file location (`ai/migrate/progress.md`) MUST be honoured so multi-day runs survive across sessions.
5. Genuine blockers (cross-repo dependency, V1 source unreadable, security-sensitive contract break) surface in a one-line "Blockers" section, NOT as multi-page halt files.
6. For rule-only tools (Aider / Codex / Gemini), document as a manual procedure: "describe the area; agent reads V1 + V2 sources, ports each feature with V2 structure + V1 behaviour, brief end-of-run summary."

## NEW (2026-04-29 hardening) — required artifacts per project

Every adapter setup that includes `--include=migration` MUST also propagate these new elements:

1. **`ai/migration/_v2-anchors.md`** — per-project anchor file declaring `project_kind` (frontend-vue3 / frontend-react / backend-nest / etc.), `v1_root`, `v2_root`, gold-standard files, shared-component map, layering rules, forbidden V1 fingerprints. Schema: `templates/packs/migration/_v2-anchors-schema.md`. The validator + agents read this so checks are project-shape-agnostic.

2. **Audit doc frontmatter** — every audit at `ai/migration/audits/<feature>.md` MUST start with:
   ```yaml
   ---
   auditor_agent_id: <agent run ID OR rule-only-mode/<tool>/<UTC>>
   auditor_mode: agent | rule-only-mode/<tool>
   audit_date: <UTC ISO>
   v1_commit_pinned: <SHA>
   v2_commit: <SHA>
   ---
   ```
   `validate-migration-artifacts.sh § check_audit_provenance` HALTs without it. For rule-only tools (Aider/Codex/Gemini), the sentinel `auditor_agent_id: rule-only-mode/<tool>/<ISO>` is accepted; the trade-off is logged.

3. **`/migration-doctor`** workspace command — for multi-repo workspaces. Backed by `claude-config/scripts/migration-doctor.sh`. Walks every registered repo with a ledger, runs validator, surfaces cross-repo dependency drift + stale audits.

4. **Baseline validator checks** (script-shipped — no per-adapter code change needed; install the script bundle — see **§ Companion scripts (2026-05)** below):
   `check_audit_provenance`, `check_audit_freshness`, `check_audit_body_consistency`, `check_intentional_break_adr`, `check_porter_vs_auditor`, `check_corpus_distribution`, `check_tolerance_coverage`, `check_parity_run_v1_commit`, `check_v2_structure` (frontend + backend dispatch via `project_kind`), `check_composable_reuse`, `check_service_shape`, `check_lifecycle_keepalive`, `check_permission_gate_divergence`.

5. **Additional mechanical gates (2026-05 accuracy audit)** — same script bundle; no per-adapter code: Section 0 navigation inventory (`check_section_0_evidence`), 6-axis reachability doc (`check_migration_reachability_axes` + `migration-reachability.sh`), cutover JSON evidence for shadow/canary/V2-only rows, strict corpus / gap-marker enforcement (`--strict`), trivial-tier primitive gate fix, `mixed` / strict `project_kind`, tolerance YAML drift vs ADR warnings, PR scope vs `v2_path` warnings, forms-bearing aggregation across cited leaves, backend-only bypass for inventory primitives. Details: repo root `CHANGELOG.md` **[Unreleased]** → Migration cycle accuracy.

### Companion scripts (2026-05) — install the **full** bundle

**Every adapter** that ships migration MUST document this: enforcement is **not** only `validate-migration-artifacts.sh`. Users (and CI) should symlink or copy **all** of these from `claude-config/scripts/` into `~/.claude/scripts/` (or add that directory to `PATH`):

| Script | Role |
|--------|------|
| `validate-migration-artifacts.sh` | Primary gate; hooks use `--hook-mode`. |
| `migration-doctor.sh` | Multi-repo workspace health walk; **non-zero exit** on validator failures, cross-repo dependency violations, or stale audits (do not rely on stdout alone). |
| `migration-reachability.sh` | Template + `--lint` for `ai/migration/reachability/<feature>.md` (cron / queue / route / admin / deploy / runbook axes). |
| `migration-detect-existing.sh` | Pre-port collision scoring; reads `v2_root` from `ai/migration/_v2-anchors.md` (not hard-coded `src/`). |
| `migrate-parallel.sh` | Headless ledger dispatch; parses rows with `## <feature-id>` headings and fenced YAML accepting **`state:`** or **`status:`**. |
| `parallel-fan-out.sh` | Parallel worker wrapper; **flocks** `ai/migration/ledger.md` by default — set `LEDGER_LOCK=""` only when serializing writes elsewhere. |

**New canonical artifact paths** (discipline + validators):

- `ai/migration/cutover-evidence/<feature>-<stage>.json` — cutover stage evidence when the ledger row advances through shadow / canary / V2-only (example shape: `templates/packs/migration/_examples/cutover-evidence-stage.json`).
- `ai/migration/reachability/<feature>.md` — per-feature 6-axis reachability matrix.

**Anchors:** When `ai/migration/_v2-anchors.md` exists, declare a valid **`project_kind`** (including **`mixed`** for monorepos). Schema: `templates/packs/migration/_v2-anchors-schema.md`.

**Recovery flags (`/migrate`):** `--restart` resets progress only; **`--ignore-ledger`** backs up and wipes ledger + related authority — see `commands/migrate.md` (recovery / symptom → flag table).

The validator script is location-agnostic — installed once at `~/.claude/scripts/validate-migration-artifacts.sh` (or shell-PATH equivalent) and invoked from any tool's hook system, CI, or pre-commit. **Hooks alone are insufficient** for workspace doctor + reachability lint + parallel coordination; install the bundle above.

## Per-tool translation expectations

### Claude Code (`.claude/`)
- Full pack as-is.
- `migration-discipline.md` → `.claude/rules/migration-discipline.md`
- `parity-auditor.md`, `migration-architect.md` → `.claude/agents/`
- `extract-v1-contract.md`, `parity-test-generate.md`, `perf-uplift-survey.md` → `.claude/skills/`
- All commands → `.claude/commands/`
- `validate-migration-artifacts.sh` → `~/.claude/scripts/` (user installs once globally)

### OpenCode (`AGENTS.md` + `.opencode/`)
- Rule's contents inlined into `AGENTS.md` migration section + linked from `.opencode/`
- Agents → `.opencode/agents/parity-auditor.md`, `.opencode/agents/migration-architect.md`
- Skills → `.opencode/skills/extract-v1-contract/SKILL.md`, etc.
- Commands → `.opencode/commands/migration-phase.md`, etc.

### Cursor (`.cursor/`)
- Rule → `.cursor/rules/migration-discipline.mdc` (with frontmatter `globs: ai/migration/**`)
- Skills → `.cursor/skills/extract-v1-contract/SKILL.md`, etc.
- Commands → `.cursor/commands/migration-phase.md`, etc.
- Hooks → `.cursor/hooks.json` triggering `validate-migration-artifacts.sh` on file edits in `ai/migration/`
- Agents are **convention-only** in Cursor; document them in the rule prose.

### Copilot (`.github/`)
- Rule → `.github/instructions/migration-discipline.instructions.md`
- Agents → `.github/agents/parity-auditor.agent.md`, `.github/agents/migration-architect.agent.md`
- Skills → `.github/skills/extract-v1-contract/SKILL.md`, etc.
- Commands → `.github/prompts/migration-phase.prompt.md`, etc.
- Or `chatmodes/` for sub-agent-style chat modes

### Continue (`.continue/`)
- Rule → `.continue/rules/migration-discipline.md`
- Skills → expressed as prompts in `.continue/prompts/extract-v1-contract.md` (Continue treats skills as prompt templates)
- Commands → `.continue/prompts/migration-phase.md`, etc.
- Agents → convention-only; document in rule prose

### Cline (`.clinerules/`) and Windsurf (`.windsurf/`)
- Rule → `.clinerules/migration-discipline.md` / `.windsurf/rules/migration-discipline.md`
- Commands → `.clinerules/workflows/migration-phase.md` / `.windsurf/workflows/migration-phase.md`
- **Agents + skills NOT supported natively.** Their content (parity-auditor's hard halts, extract-v1-contract's procedure, etc.) MUST be inlined into the rule. The self-sufficient rule already does this.

### Aider (`CONVENTIONS.md`)
- Rule → appended to `CONVENTIONS.md` under a `## Migration discipline` section
- **No commands, no agents, no skills.** Aider relies entirely on the rule for migration discipline.
- Aider users invoke procedures by reading the rule's "Tool-agnostic procedure" section and following it manually.
- The validator script `validate-migration-artifacts.sh` is the only callable verifier — Aider users run it from the shell or as a pre-commit hook.

### Codex (`AGENTS.md` + `~/.codex/config.toml`)
- Rule → `AGENTS.md` migration section
- Agents are convention-only; document in `AGENTS.md`
- Same rule-only fallback as Aider for the procedural surface

### Gemini CLI (`GEMINI.md`)
- Rule → `GEMINI.md` migration section
- **Rule-only tool.** Same as Aider/Codex.

### Qwen Code (`QWEN.md` + `.qwen/`)
- Rule → `.claude/rules/migration-discipline.md` content mirrored into `QWEN.md` § `## Migration discipline` + cross-referenced from `AGENTS.md`.
- Agents → `.qwen/agents/parity-auditor.md`, `.qwen/agents/migration-architect.md` (Markdown + YAML frontmatter; `tools:` whitelist set per agent).
- Skills → `.qwen/skills/extract-v1-contract/SKILL.md`, `.qwen/skills/parity-test-generate/SKILL.md`, `.qwen/skills/perf-uplift-survey/SKILL.md`.
- Commands → `.qwen/commands/migration-phase.md`, `.qwen/commands/find-and-fix.md`, `.qwen/commands/port-feature.md`, `.qwen/commands/migration-gate.md`, etc. Nested-namespace form (`.qwen/commands/migration/phase.md` → `/migration:phase`) is acceptable when the project ships many migration commands.
- Hooks → `.qwen/settings.json` `hooks.PostToolUse` triggering `validate-migration-artifacts.sh` on edits to `ai/migration/**`.

## Validator script — universal callable

`scripts/validate-migration-artifacts.sh` is callable from any tool's hook system or directly from the shell. Setup per tool:

| Tool | Hook integration |
|---|---|
| Claude Code | `.claude/settings.json` PostToolUse hook on edits to `ai/migration/**` |
| Cursor | `.cursor/hooks.json` `onSave` for `ai/migration/**` |
| Copilot | GitHub Actions workflow (no native pre-commit) |
| Qwen Code | `.qwen/settings.json` `hooks.PostToolUse` matcher on edits to `ai/migration/**` |
| Other (Aider, Codex, Gemini, etc.) | Pre-commit hook in `.git/hooks/pre-commit` (manual install) OR CI workflow |

The script returns non-zero on any failure; tool integrations should treat that as a blocking error.

## Adapter responsibilities

When an adapter ships the migration pack:

1. **MUST translate the rule** (`migration-discipline.md`) faithfully — including the inlined 9 contract sections, 11 hard halts (including the dead-V1-code halt added 2026-05-02), 6-axis reachability check, frontend axes, anti-pattern catalogue (including "Zombie Port"), and tool-agnostic procedures. Do NOT abridge.
2. **MUST translate or document agents/skills/commands** to the tool's native format if supported. If not supported, document in the rule's "References" section that the procedural detail is inlined.
3. **MUST install or document `validate-migration-artifacts.sh`** as a pre-commit / CI / hook integration.
4. **MUST translate `port-feature.md`** as the per-feature orchestrator (or its 6-phase procedure inlined).
5. **MUST translate `migration-recheck.md`** as the user's focused ad-hoc verification command — accepts natural-language descriptions ("the sidebar", "the orders module") OR explicit paths. Semantic resolution via codebase-profile + ledger reads (intent interpretation, not keyword matching). MUST NOT downgrade to tokenization in the translation.
6. **MUST NOT silently drop the migration pack on tools with limited capability.** A rule-only tool gets the rule (which is sufficient).

## Cross-repo task workflow — `/cross-repo-task` (v1.5+)

`/cross-repo-task` registers + tracks + drains cross-repo blockers (when a V2 port halts because a sibling repo / upstream service must ship first). Subcommands: register / list / update / close / drain. Registry at `ai/migration/cross-repo-tasks.md`.

Adapter responsibility: every tool with command surface MUST expose this command. Rule-only tools (Aider / Codex / Gemini) document the workflow as a manual procedure (track blockers in the registry file directly; manually update the ledger row's `cross_repo_task: <task-id>` field; re-run `/find-and-fix <id>` after blocker lands).

## Reviewer-approval mechanism (v1.5+)

Heavy-tier rows pause for reviewer approval. Ledger field: `reviewer_approval: <name>@<iso>`. Status `pending-review` between fix-applied and signoff. Default reviewer from `CODEOWNERS` or `ai/migration/_v2-anchors.md`'s `default_reviewer:` field. 7-day timeout; no auto-fail.

Adapter responsibility: every tool that runs `/migration-fast` or `/port-feature` MUST surface the pending-review halt to the user (file path + assigned reviewer). Tools with native review surfaces (GitHub PR review for Copilot, Cursor's review-mode) MAY auto-populate the `reviewer_approval` field on PR-merge events. Rule-only tools document the manual flow in the rule body.

## Mid-port tier promotion — `/migration-promote-tier` (v1.5+)

`/migration-promote-tier <id> <new-tier> [--reason="<text>"]`. Promotion backfills artifacts; demotion requires `--reason`; security-row demotion is forbidden.

Adapter responsibility: surface this command in every tool's native command surface.

## Idiom-drift propagation (v1.5+)

`/migration-scan` records oracle file hashes in `ai/migration/_session-digest.md`; subsequent scans compare and surface "Oracle drift detected" when changed. `/migration-replan --include-drifted` re-phases affected rows.

Adapter responsibility: this is a behavior change in `/migration-scan`'s output template. Every adapter that translates the scan command MUST include the "Oracle drift detected" section in its translation.

## Plan-independent ad-hoc spot-check — `/migration-recheck`

`/migration-recheck <description-or-path>` is the user's bypass-the-ceremony tool (v1.4.0). **NO plan / phase / ledger required.** Accepts natural-language descriptions OR paths. Semantic resolution via codebase-profile + idioms (same intent-interpretation model as `/add-feature`). Scans V1 + V2 source FRESH for the resolved area — no cache lookup, no ledger-row dependency, no required prior `/migration-scan`.

Adapter responsibility (in addition to surfacing the command):
1. Plan-independence MUST be preserved. Adapters MUST NOT add a "ledger required" / "scan required" pre-flight that isn't in the source rule.
2. Fresh-audit semantics MUST be preserved. Adapters MUST NOT cache audits for recheck runs (each recheck reads V1 + V2 source line-by-line).
3. Best-effort ledger updates: if a ledger exists, matching rows are updated. If not, leave alone (or create new rows if `--register-ledger` was passed).
4. For rule-only tools (Aider / Codex / Gemini), the rule body documents the manual procedure: "describe the area; agent reads the profile to find V1 + V2 source paths; agent reads V1 + V2 source line-by-line; agent fixes drift in V2 to match V1; commit; optionally record into ledger if one exists."

Per-tool surface:
- Claude Code: `.claude/commands/migration-recheck.md`
- Cursor: `.cursor/commands/migration-recheck.md`
- OpenCode: `.opencode/commands/migration-recheck.md`
- Copilot: `.github/prompts/migration-recheck.prompt.md`
- Cline: `.clinerules/workflows/migration-recheck.md`
- Windsurf: `.windsurf/workflows/migration-recheck.md`
- Continue: `.continue/prompts/migration-recheck.md`
- Qwen Code: `.qwen/commands/migration-recheck.md`
- Aider / Codex / Gemini: documented in `CONVENTIONS.md` / `AGENTS.md` / `GEMINI.md` as a manual procedure ("describe the area; agent reads the profile + ledger; confirms; runs the per-feature loop").

## Failure mode protections

The F039-class failures (Trusted Summary, Hand-waved Query Param, Optimistic Form Field Match, etc.) catalogued in `_examples/audit-failure-modes.md` are pattern-recognised by the validator script. The script flags hand-wave tokens in audit files, missing contract sections, undersized corpus, and missing artifacts — regardless of which tool produced the artifacts.

This means: a Cursor user, a Copilot user, an Aider user, and a Claude Code user all get the same enforcement floor when they run the validator. The discipline is universal; the tool surface is per-adapter convenience.
