# Audit pack — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces **`/audit`** when the orchestration wiring includes audit (via `commands/audit.md`, the 8-axis specialist fan-out, the 13 scale-lens detectors, and **`scripts/validate-audit-artifacts.sh`**).

`/audit` is a **top-level orchestration command** (not a standalone pack folder like `templates/packs/migration/`). It is the **superset** sweep — it fans out to the same specialists `/optimize`, `/security-audit`, `/db-audit`, and `/perf-audit` dispatch individually, then **cross-axis ranks** every finding by `impact-at-target-scale × blast-radius × fix-cost` into P0–P4 tiers and executes them. Discipline is split across `commands/audit.md`, `templates/governance/core-discipline.md`, the specialist agents/skills (`architectural-diagnosis`, `security-auditor`, `database-optimizer`, `system-architect`, `resilience-reviewer`, `performance-optimizer`, …), and **`scripts/validate-audit-artifacts.sh`**.

`PROJECT_KIND` (auto-detected from `.claude/_extracted-codebase.md`) routes the 13 scale-lens detectors and the `--assess` narrative vocabulary, but — unlike `/polish` — `/audit` runs **all 8 axes on every stack** (only the per-axis fingerprint changes). See the command boundary table in `_orchestration-sync.md` for where `/audit` ends and `/optimize` / `/align` / `/polish` / `/refactor` begin.

## Capability mapping per tool

| Tool | Surface |
|------|---------|
| Claude Code | Full command + 8-axis specialist fan-out + scale-lens detectors + hooks |
| OpenCode / Cursor / Copilot / Qwen / Kimi | Native commands / prompts + hooks where supported |
| Continue / Cline / Windsurf | workflows / prompts |
| Aider / Codex / Gemini | rule-only — user runs validator from shell / CI |

## Simple-surface entry — `/audit`

- **Source**: [`commands/audit.md`](../../commands/audit.md).
- **Progress**: `ai/audit/progress.md` (single source of truth across multi-day runs — high-blast P0/P1 tiers land serial, then pauses).
- **Plan / assessment**: `ai/audit/plan.md` (`--plan-only`, ranked P0–P4 fix-plan) **or** `ai/audit/assessment.md` (`--assess`, 8-section senior-engineer narrative).
- **Targets** (anchor ranking): `--target-rps`, `--target-p95`, `--target-vitals`, `--target-cold-start`, `--target-startup`, `--target-bundle`.
- **Modes**: default (scan + rank + execute), `--plan-only` (executor handoff), `--assess` (reader handoff — read-only narrative). The honesty clause applies to the **execution** summary; `--plan-only` / `--assess` produce a report, not an execution summary, and are exempt.
- **Flags** (user-facing, mirror other simple-surface commands): `--dry-run`, `--strict`, `--quiet`, `--allow-dirty`, `--max-parallel`, `--focus`, `--exclude`, `--surface-blockers`, `--skip-p4`, `--refresh`, `--re-audit`, `--restart`, `--ignore-ledger`, `--status`, `--resume`, `--reset`.

## Canonical artifacts

| Path | Role |
|------|------|
| `ai/audit/plan.md` | Cross-axis ranked P0–P4 fix-plan — id, axis, summary, `<file:line>`, closure verb, dependency-on, tier, impact-at-target, blast-radius, fix-cost |
| `ai/audit/assessment.md` | `--assess` 8-section narrative (good / improve / unify / extract / simplify / redesign / remove / optimize) + `## Actionable next steps` |
| `ai/audit/progress.md` | Multi-day state — per-tier counts (done / pending / halted) + halted-finding blockers + next-steps |
| `ai/audit/_arch.md` `_quality.md` `_security.md` `_db.md` `_perf.md` `_scale.md` `_infra.md` `_obs.md` | Per-axis scan subfiles (the 8 fan-out emitters; merged by the cross-axis ranker) |
| `ai/audit/perf-wins.md` | Baseline + post-fix measurements for P2 scale/perf fixes |
| `ai/audit/final-report.md` | End-of-run report — ends with `## Actionable next steps` per the universal report contract |
| `.claude/_extracted-idioms.md` | Oracle — primitives the universal detectors run against (no hard-coded language tokens) |
| `.claude/_extracted-codebase.md` | Source of `PROJECT_KIND` for scale-lens + `--assess` routing |

## Validator — `validate-audit-artifacts.sh`

Mechanical checks (install to `~/.claude/scripts/`):

**Plan (`ai/audit/plan.md`, default / `--plan-only`)**

- Plan present + ranked into P0–P4 tiers; ordering by `impact-at-target × blast-radius × fix-cost`, **not** by axis (a per-axis "all security, then all DB" order is rejected — that is just running separate audits).
- Every **P0/P1/P2** finding cites `<file:line>` + a measured-or-explicitly-estimated impact (RPS × cost-per-call). `check_p0_failure_mode_cited` — every P0 row names the **scale failure mode** ("deadlocks at 50K RPS because lock held across HTTP call"), not "would be slow at scale".
- `check_no_handwaves_audit_plan` — greps `etc.`, `...`, `&...`, `N+ items`, `would be slow`, `at scale this is bad`, `several places`, `appears to`. Under **`--strict`** these fail the run; missing failure-mode citations on P0 rows also fail.

**Assessment (`ai/audit/assessment.md`, `--assess`)**

- Validates the **8 required sections** present in order: good / improve / unify / extract / simplify / redesign / remove / optimize.
- Validates the `## Actionable next steps` block (paste-ready follow-up commands).
- Same anti-hand-wave grep as the plan (rejects `etc.` / `several places` / `multiple endpoints` / `appears to`).

**Ledger / progress** (ranked-tier state)

- Tier rows parsed; terminal rows (`verified` / `done` / `fixed`) require `gaps_in == gaps_closed` (re-detect parity before a tier advances).

Flags: `--strict`, `--quiet` (`-q`, for hooks / CI), plus the artifact/ledger path overrides shared with the other validators.

## Companion scripts (2026-05) — install the **full** bundle

| Script | Role |
|--------|------|
| `validate-audit-artifacts.sh` | Primary gate for plan / assessment / ranked-tier ledger |
| `audit-parallel.sh` | Headless dispatch for P2/P4 parallel waves; parses **`id:`** rows + `status:`/`state:` like `optimize-parallel.sh` |
| `parallel-fan-out.sh` | Worker engine; pass **`--ledger=ai/audit/ledger.md`** so `flock` targets the audit ledger (not the migration default) |

**Parallel runners MUST pass `--ledger=`** — wrappers (`audit-parallel.sh`, `optimize-parallel.sh`, `align-parallel.sh`, `polish-parallel.sh`, `migrate-parallel.sh`) forward their ledger path to `parallel-fan-out.sh`. P0 + P1 tiers run **serial** (high blast radius); only P2 + P4 fan out.

## Hook integration

Same pattern as the other orchestration commands: PostToolUse / pre-commit on edits under `ai/audit/**` invoking `validate-audit-artifacts.sh` (use `-q` from hooks). The scale-lens detector pass and the cross-axis ranker are agent-side; the hook gates only the written artifacts (plan / assessment / ledger). Rule-only tools document manual CI invocation.

## Rule-only degradation (Aider / Codex / Gemini)

When a tool has no executable command surface, `/audit` degrades to **rule-only**. What survives:

- **`validate-audit-artifacts.sh`** — runs from shell / CI on a hand-authored or agent-authored `ai/audit/plan.md` / `assessment.md`. The mechanical contract (ranked-not-by-axis, `<file:line>` citations, P0 failure-mode citation, no hand-waves, 8 assessment sections) is fully preserved.
- **The discipline prose** — `commands/audit.md` + the boundary table in `_orchestration-sync.md` ship as injected rules so the model still ranks by impact-at-scale, runs the 13 scale-lens detectors conceptually, and writes the honesty clause into execution summaries.

What does **not** survive without an executable surface: the automatic 8-axis specialist fan-out, the parallel P2/P4 waves (`audit-parallel.sh`), and the re-detect-after-each-tier gating. The user drives those steps manually and runs the validator as the gate. Codex / Gemini are **native** (Agent Skills / TOML), not prose — see `_registry.md § Command translation per adapter` for the canonical per-adapter routing.

## Adapter responsibilities

1. Surface `/audit` in the native command surface when orchestration packs are selected.
2. Document **`templates/tool-adapters/_audit-pack-coverage.md`** (this file) so users install the **bundle** (validator + `audit-parallel.sh` + `parallel-fan-out.sh`), not only the validator script.
3. Preserve the **cross-axis ranking** semantics in translations — `/audit` ranks every finding by impact-at-scale across all 8 axes; a translation that runs the axes separately and never merges them has collapsed `/audit` into "`/optimize` + axis fan-out", which is not the contract.
4. Preserve the **honesty clause** on the execution summary (`Not validated:` / `Risks:` / `Revert:`) — `/audit` commits P0–P4 fixes, so the negative space is mandatory.

## See also

- [`templates/tool-adapters/_orchestration-sync.md`](_orchestration-sync.md) — honesty clause, command boundary table, afterburner sequence
- [`templates/tool-adapters/_registry.md`](_registry.md) — parallel orchestrator matrix + per-adapter command translation
- [`templates/tool-adapters/_optimize-pack-coverage.md`](_optimize-pack-coverage.md) — sibling coverage doc (`/optimize` dispatches the same specialists `/audit` fans out to)
- `commands/audit.md` — user-facing `/audit` contract
- `scripts/validate-audit-artifacts.sh` — validator source
