---
purpose: Adapter-facing sync for simple-surface commands (`/migrate`, `/optimize`, `/polish`, `/align`, `/refactor`, `/audit`, `/unify-surfaces`), validators, hooks, and AGENTS discipline paths. Single pointer from each `templates/tool-adapters/<tool>/adapter.md` Cross-references section.
---

# Orchestration & validator sync (for adapters)

Use when translating pack bundles, CI hooks, or discipline blocks. Authoritative command prose: `commands/{migrate,optimize,polish,align,refactor,audit,unify-surfaces}.md`. Validator sources: `scripts/validate-*-artifacts.sh`.

**Honesty clause (2026-06-07, all simple-surface summaries)**: every run summary of `/migrate`, `/optimize`, `/align`, `/polish`, `/unify-surfaces` closes with three mandatory lines — `Not validated:` (what did NOT run + why, or `none — <what fully ran>`), `Risks:` (residual risk, or `none identified`), `Revert:` (exact git command for the run's commit range). Adapters that approximate these commands via pack commands or the parallel orchestrator scripts MUST carry the same three lines in their end-of-run report. `Tests: green` without the negative space is the Trusted Summary failure mode applied to the run report.

## Discipline enforcement (`AGENTS.md` inject)

Source: **`templates/tool-adapters/_discipline-enforcement.md`** (verbatim block between `<!-- discipline-enforcement:start/end -->`).

- **`ai/migrate/progress.md`** — **only** allowed file under `ai/migrate/` (simple-surface `/migrate` multi-day progress). All other migration workflow state stays under **`ai/migration/`**.

## Validator facts (machine contracts)

| Script | Oracle / prerequisites | Notable flags / env |
|--------|------------------------|---------------------|
| `validate-migration-artifacts.sh` | migration anchors + audits | (see `_migration-pack-coverage.md`) |
| `validate-optimize-artifacts.sh` | `.claude/_extracted-idioms.md` **or** `.claude/codebase-profile.md` **or** root `codebase-profile.md` | `--strict`: Phase 0 must cite oracle; **`ai/optimize/ledger.md`** required under strict |
| `validate-align-artifacts.sh` | `ai/align/ledger.md` format | `--strict` / `--quiet`; **21** closure verbs (5 structural + 16 functional) — see `align-discipline.md` + script |
| `validate-polish-artifacts.sh` | `PROJECT_KIND`, stack evidence files | Env **`QUIET=1`** for quieter logs; **no** `--strict` CLI (failures already exit non-zero). Env `POLISH_DIR`, `PROJECT_KIND` |
| `validate-refactor-artifacts.sh` | `ai/refactor/ledger.md` | `--strict`, `--quiet`, `--phase-base`, `--ledger`, `--findings-dir` |
| `validate-audit-artifacts.sh` | `ai/audit/plan.md` (`--plan-only`) **or** `ai/audit/assessment.md` (`--assess`) + ranked-tier ledger | Checks P0/P1/P2 citations + measured-or-estimated impact; `--strict` rejects hand-waves (`etc.`, `would be slow`, `several places`) and missing failure-mode citations on P0 rows. For `--assess`: validates 8 required sections (good / improve / unify / extract / simplify / redesign / remove / optimize) + `## Actionable next steps` block. |
| `validate-unify-surfaces-artifacts.sh` *(planned)* | `ai/unify-surfaces/progress.md` + per-category inventory | Will check per-category inventory completeness, canonical-wrapper-decision evidence, idioms-update co-commit (`_extracted-idioms.md § Wrappers`), `Reuse-Before-Create` violations (extracting a duplicate where a shared wrapper exists fails). Frontend-only — halts on `PROJECT_KIND` not in `frontend-* / mobile-web / mobile-rn`. |

## Hook globs (when wiring PostToolUse / pre-commit)

Include edits under: `ai/migration/**`, `ai/optimize/**`, `ai/align/**`, `ai/polish/**`, `ai/refactor/**`, `ai/audit/**`, `ai/unify-surfaces/**` (plus pack-specific paths per coverage docs).

## `/refactor` vs the five inventory commands

**`/refactor`** is scoped (default: git-changed paths); it does **not** implement `--refresh` / `--re-audit` / `--restart` / `--ignore-ledger` multi-area orchestration. Those flags apply to **`/migrate`**, **`/optimize`**, **`/align`**, **`/polish`**, **`/audit`** — see `docs/COMMANDS.md`, `commands/refactor.md`, and `commands/audit.md`.

## See also

- `templates/tool-adapters/_migration-pack-coverage.md`
- `templates/tool-adapters/_optimize-pack-coverage.md`
- `templates/tool-adapters/_align-pack-coverage.md`
- `templates/tool-adapters/_polish-pack-coverage.md`
- `templates/tool-adapters/_refactor-pack-coverage.md`
- `templates/tool-adapters/_task-integration-coverage.md` — `/task` (MCP-backed task executor: Trello / Jira / Linear / GitHub) per-tool primitive + the `/do`→native-dispatch substitution
- `templates/tool-adapters/_registry.md` § Top-level orchestration commands
