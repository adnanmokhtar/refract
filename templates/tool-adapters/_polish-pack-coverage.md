# Polish pack — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces **`/polish`** when the orchestration wiring includes polish (via `commands/polish.md`, the stack-conditional skill set, and **`scripts/validate-polish-artifacts.sh`**).

`/polish` is a **top-level orchestration command** (not a standalone pack folder like `templates/packs/migration/`). It is **stack-conditional** — the validator and skills routed at runtime depend on `PROJECT_KIND` (auto-detected from `.claude/_extracted-codebase.md`):

| `PROJECT_KIND` | Closure-verb spec | Detector skills | Evidence file |
|---|---|---|---|
| `frontend-*` | **`ui-design-sweep`** (ui-ux pack v1.1+) — closed 18-verb vocabulary | `a11y-quick-check`, `design-token-audit`, `motion-audit`; `design-iterate` for visual variants | `ai/polish/_visual-decisions.md` |
| `backend-*` | `api-consistency-audit` (backend pack v1.1+) — 15 detectors | (skill is its own detector) | `ai/polish/_api-decisions.md` |
| `data-*` | `schema-consistency-audit` (database pack v1.1+) | (skill is its own detector) | `ai/polish/_schema-decisions.md` |
| `mobile-*` | `platform-conventions-audit` (mobile pack v1.1+) + falls back to `ui-design-sweep` for shared frontend axes | reuses frontend detector skills | `ai/polish/_platform-decisions.md` |

## Capability mapping per tool

| Tool | Surface |
|------|---------|
| Claude Code | Full command + skills + hooks |
| OpenCode / Cursor / Copilot / Qwen / Kimi | Native commands / prompts + hooks where supported |
| Continue / Cline / Windsurf | workflows / prompts |
| Aider / Codex / Gemini | rule-only — user runs validator from shell / CI |

## Simple-surface entry — `/polish`

- **Source**: [`commands/polish.md`](../../commands/polish.md).
- **Progress**: `ai/polish/progress.md` (single source of truth across multi-day runs).
- **Ledger**: `ai/polish/ledger.md`.
- **Flags** (user-facing, mirror other simple-surface commands): `--dry-run`, `--allow-dirty`, `--max-parallel`, `--focus`, `--exclude`, `--surface-blockers`, `--refresh`, `--re-audit`, `--restart`, `--ignore-ledger`, `--status`, `--resume`, `--reset`.

## Canonical artifacts

| Path | Role |
|------|------|
| `ai/polish/ledger.md` | Row state machine — fenced YAML rows with `id: <token>` + `status:` or `state:` |
| `ai/polish/_visual-decisions.md` | `frontend-*` evidence — visual baseline + a11y + design-token comparisons |
| `ai/polish/_api-decisions.md` | `backend-*` evidence — envelope / error / pagination / naming / log / metric / trace |
| `ai/polish/_schema-decisions.md` | `data-*` evidence — column / type / index / FK / migration |
| `ai/polish/_platform-decisions.md` | `mobile-*` evidence — per-platform UI tree + HIG / Material compliance |
| `ai/polish/findings/<id>.md` | Per-row notes (optional) |
| `.claude/_extracted-codebase.md` | Source of `PROJECT_KIND` for stack routing |

## Validator — `validate-polish-artifacts.sh`

Mechanical checks (install to `~/.claude/scripts/`):

**Stack-conditional evidence** — chosen by `PROJECT_KIND`:

- For each evidence file: 4 named blocks present (e.g. `Visual baseline evidence`, `a11y audit evidence`, `Design-token usage evidence`, `Per-surface findings` for frontend).
- ≥1 `<path:line>` or `` `path:line` `` citation in the evidence file.
- Hand-wave grep on the evidence file (no `etc.`, `…`, `N+ items`, `and so on`).
- Anti-Trusted-Summary discipline mirrors migration's `check_section_0_evidence`.

**Frontend-only — `check_frontend_verb_vocabulary`** (added v1.1, 2026-05):

- Greps `ai/polish/ledger.md` + `ai/polish/_visual-decisions.md` for `closure_verb:` lines.
- Rejects any verb outside the closed 18-verb `ui-design-sweep` set: `consolidate-tokens`, `extract-token`, `unify-component`, `extract-pattern`, `normalize-hierarchy`, `apply-type-scale`, `tighten-rhythm`, `simplify-density`, `wire-empty-state`, `wire-loading-state`, `wire-error-state`, `lift-contrast`, `align-focus-ring`, `unify-iconography`, `normalize-motion`, `expand-tap-target`, `unify-cta-placement`, `clarify-affordance`, `normalize-surface`.
- Mirrors how `validate-refactor-artifacts.sh` enforces refactoring-sweep's 10 verbs.
- Active when `PROJECT_KIND` is `frontend-*` or `mobile-*`.

**Ledger** (when `ai/polish/ledger.md` exists)

- Rows parsed from fenced YAML: `id:`, `class:`, `status:`/`state:`, `gaps_in`, `gaps_closed`, `closure_verb`.
- Terminal statuses (`verified` / `done` / `fixed`): `gaps_in == gaps_closed`.
- Frontend rows additionally pass `check_frontend_verb_vocabulary`.

Flags: `--strict`, `--quiet`, `--ledger=`, `--polish-dir=`.

## Companion scripts (2026-05) — install the **full** bundle

| Script | Role |
|--------|------|
| `validate-polish-artifacts.sh` | Primary gate for stack-conditional evidence + ledger |
| `polish-parallel.sh` | Headless dispatch; parses **`id:`** rows + `status:`/`state:` like `migrate-parallel.sh` |
| `parallel-fan-out.sh` | Worker engine; pass **`--ledger=ai/polish/ledger.md`** so `flock` targets the polish ledger (not the migration default) |

**Parallel runners MUST pass `--ledger=`** — wrappers (`polish-parallel.sh`, `optimize-parallel.sh`, `align-parallel.sh`, `migrate-parallel.sh`, `audit-parallel.sh`) forward their ledger path to `parallel-fan-out.sh`.

## Hook integration

Same pattern as migration / optimize: PostToolUse / pre-commit on edits under `ai/polish/**` invoking `validate-polish-artifacts.sh`. Rule-only tools document manual CI.

## Adapter responsibilities

1. Surface `/polish` in the native command surface when orchestration packs are selected (same translation rules as other `.claude/commands/*.md` files — Phase 4.8.0).
2. Document **`templates/tool-adapters/_polish-pack-coverage.md`** (this file) so users install the **bundle**, not only the validator script.
3. Preserve **stack-conditional** routing in translations — never collapse all stacks into a single skill set.

## See also

- [`templates/tool-adapters/_registry.md`](_registry.md) — simple-surface vs setup-family split
- [`commands/polish.md`](../../commands/polish.md) — user-facing `/polish` contract
- [`scripts/validate-polish-artifacts.sh`](../../scripts/validate-polish-artifacts.sh) — validator source
