# Polish pack — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces **`/polish`** when the orchestration wiring includes polish (via `commands/polish.md`, the stack-conditional skill set, and **`scripts/validate-polish-artifacts.sh`**).

`/polish` is a **top-level orchestration command** (not a standalone pack folder like `templates/packs/migration/`). It is **stack-conditional** — the validator and skills routed at runtime depend on `PROJECT_KIND` (auto-detected from `.claude/_extracted-codebase.md`):

| `PROJECT_KIND` | Closure-verb spec | Detector skills | Evidence file |
|---|---|---|---|
| `frontend-*` | **`ui-design-sweep`** (ui-ux pack v1.1+) — closed 19-verb vocabulary | `a11y-quick-check`, `design-token-audit`, `motion-audit`; `design-iterate` for visual variants | `ai/polish/_visual-decisions.md` |
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
- Rejects any verb outside the closed 19-verb `ui-design-sweep` set: `consolidate-tokens`, `extract-token`, `unify-component`, `extract-pattern`, `normalize-hierarchy`, `apply-type-scale`, `tighten-rhythm`, `simplify-density`, `wire-empty-state`, `wire-loading-state`, `wire-error-state`, `lift-contrast`, `align-focus-ring`, `unify-iconography`, `normalize-motion`, `expand-tap-target`, `unify-cta-placement`, `clarify-affordance`, `normalize-surface`.
- The validator's `UI_DESIGN_SWEEP_VERBS` array is the authoritative count (19). Responsive / breakpoint + dark-mode / theme-mode drift are deliberately NOT verbs — they defer to `/enhance-ui`.
- Mirrors how `validate-refactor-artifacts.sh` enforces refactoring-sweep's 10 verbs.
- Active when `PROJECT_KIND` is `frontend-*` or `mobile-*`.

**Backend — `check_backend_verb_vocabulary`** (added; mirrors the frontend gate):

- Greps `ai/polish/ledger.md` + `ai/polish/_api-decisions.md` for `closure_verb:` lines.
- Rejects any verb outside the closed 15-verb `api-consistency-audit` set (`API_CONSISTENCY_VERBS`): `unify-envelope`, `unify-error-contract`, `unify-naming`, `unify-pagination`, `unify-versioning`, `unify-auth-header`, `add-idempotency-key`, `unify-rate-limit-headers`, `unify-log-fields`, `unify-metric-names`, `unify-trace-spans`, `unify-timeout-policy`, `unify-retry-policy`, `add-openapi-doc`, `add-endpoint-example`.
- Active when `PROJECT_KIND` is `backend-*`.

**Data — `check_data_verb_vocabulary`** (added; mirrors the frontend gate):

- Greps `ai/polish/ledger.md` + `ai/polish/_schema-decisions.md` for `closure_verb:` lines.
- Rejects any verb outside the closed 12-verb `schema-consistency-audit` set (`SCHEMA_CONSISTENCY_VERBS`): `unify-column-naming`, `unify-type-choice`, `unify-index-naming`, `unify-fk-naming`, `unify-migration-pattern`, `unify-timestamp-cols`, `add-soft-delete`, `add-audit-fields`, `unify-timezone`, `unify-charset`, `unify-collation`, `unify-nullable`.
- Active when `PROJECT_KIND` is `data-*`.

**Ledger** (when `ai/polish/ledger.md` exists) — rows parsed from fenced YAML (`id:`, `class:`, `status:`/`state:`, `gaps_in`, `gaps_closed`, `closure_verb`, `a11y_delta`/`openapi_delta`/`schema_delta`/`commits`/`diff`, `baseline`/`visual_baseline`/`review`):

- **`check_gaps_parity`** — any terminal row (`done` / `verified` / `fixed`) MUST have `gaps_in == gaps_closed` (mirrors migration/align row parsing). An unbalanced terminal row FAILS the gate.
- **`check_outcome_delta`** — a no-op polish (zero diff, identical a11y / OpenAPI / schema) must NOT be `done`. Every terminal row must show a non-empty delta (`a11y_delta` / `openapi_delta` / `schema_delta` / `commits > 0` / non-empty `diff`) OR be classed `no-change` (via `class: no-change` or `outcome: no-change`).
- **`check_visual_baseline`** (frontend / mobile only) — terminal frontend rows must carry a `baseline:` / `visual_baseline:` reference and must NOT be marked terminal while still `pending-review` (ui-design-sweep marks no-visual-verify rows `pending-review`, not `done`).
- Verb-vocabulary gates run per stack: frontend → `check_frontend_verb_vocabulary`; backend → `check_backend_verb_vocabulary`; data → `check_data_verb_vocabulary`.

Env / overrides: `QUIET=1`, `POLISH_DIR=ai/polish`, `PROJECT_KIND=…`. **The validator is env-var-only — there are NO CLI flags (no `--strict`).** Every failure is blocking; there is no soft/advisory tier to gate, so quieting (`QUIET=1`) is the only knob, and the same invocation works identically in a hook, in CI, and from a shell.

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
