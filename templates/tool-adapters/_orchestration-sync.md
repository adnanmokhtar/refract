---
purpose: Adapter-facing sync for simple-surface commands (`/migrate`, `/optimize`, `/polish`, `/align`, `/refactor`), validators, hooks, and AGENTS discipline paths. Single pointer from each `templates/tool-adapters/<tool>/adapter.md` Cross-references section.
---

# Orchestration & validator sync (for adapters)

Use when translating pack bundles, CI hooks, or discipline blocks. Authoritative command prose: `commands/{migrate,optimize,polish,align,refactor}.md`. Validator sources: `scripts/validate-*-artifacts.sh`.

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

## Hook globs (when wiring PostToolUse / pre-commit)

Include edits under: `ai/migration/**`, `ai/optimize/**`, `ai/align/**`, `ai/polish/**`, `ai/refactor/**` (plus pack-specific paths per coverage docs).

## `/refactor` vs the four inventory commands

**`/refactor`** is scoped (default: git-changed paths); it does **not** implement `--refresh` / `--re-audit` / `--restart` / `--ignore-ledger` multi-area orchestration. Those flags apply to **`/migrate`**, **`/optimize`**, **`/align`**, **`/polish`** — see `docs/COMMANDS.md` and `commands/refactor.md`.

## See also

- `templates/tool-adapters/_migration-pack-coverage.md`
- `templates/tool-adapters/_optimize-pack-coverage.md`
- `templates/tool-adapters/_align-pack-coverage.md`
- `templates/tool-adapters/_polish-pack-coverage.md`
- `templates/tool-adapters/_refactor-pack-coverage.md`
- `templates/tool-adapters/_registry.md` § Top-level orchestration commands
