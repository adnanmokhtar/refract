# Optimize pack — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces **`/optimize`** when the code-quality / orchestration wiring includes optimize (via `commands/optimize.md`, `architectural-diagnosis`, `refactoring-sweep`, and validators).

`/optimize` is a **top-level orchestration command** (not a standalone pack folder like `templates/packs/migration/`). Discipline is split across `commands/optimize.md`, `templates/packs/code-quality/skills/architectural-diagnosis/SKILL.md`, **`detect-drift`** (align pack — Phase 2 tactical rescan after foundations), `refactoring-sweep`, quality principles, and **`scripts/validate-optimize-artifacts.sh`**.

## Capability mapping per tool

| Tool | Surface |
|---|---|
| Claude Code | Full command + skills + hooks |
| OpenCode / Cursor / Copilot / Qwen / Kimi | Native commands / prompts + hooks where supported |
| Continue / Cline / Windsurf | workflows / prompts |
| Aider / Codex / Gemini | rule-only — user runs validator from shell / CI |

### What "rule-only" degradation means (Aider / Codex / Gemini)

These tools have no executable orchestration surface, so they get the **rule + validator only** — NOT the multi-agent pipeline. What survives vs what does not:

- **Survives** (mechanical, runs from shell / CI via `validate-optimize-artifacts.sh`): artifact hygiene only — Phase 0 evidence-block presence + non-emptiness, per-finding `<path:line>` citations, hand-wave grep, oracle presence, ledger re-detect parity (`gaps_in == gaps_closed`), structural net-lines (with `--phase-base`), the **perf measurement gate** (`baseline:`+`after:` on perf rows), the **coverage-not-dropped gate**, the **boot-check record gate**, and actionable-next-steps. These check that *artifacts are well-formed and honest* — they do NOT perform the optimization.
- **Does NOT survive** (agent-only — there is no automation to run it): the **Phase 0 architectural diagnosis itself** (dependency / responsibility / layer / cross-cutting mapping), foundation-first ordering, the tactical re-detect-after-fix loop, and the multi-agent parallel fix waves. On rule-only tools the *user* must author `_architecture-decisions.md` + the ledger by hand (or via the tool's own prompting); the validator then judges that hand-authored output. The validator catches an *empty* or *hand-waved* diagnosis but cannot produce a real one — so a rule-only user who skips the diagnosis gets artifact-hygiene feedback, never the architectural analysis Claude Code performs.

## Simple-surface entry — `/optimize`

- **Source**: [`commands/optimize.md`](../../commands/optimize.md).
- **Progress**: `ai/optimize/progress.md`.
- **Flags** (user-facing): `--dry-run`, `--allow-dirty`, `--max-parallel`, `--focus`, `--exclude`, `--surface-blockers`, `--refresh`, `--re-audit`, `--restart`, `--ignore-ledger`, `--status`, `--resume`, `--reset`.

## Canonical artifacts

| Path | Role |
|---|---|
| `ai/optimize/_architecture-decisions.md` | Phase 0 diagnosis — dependency / responsibility / layer / detector evidence |
| `ai/optimize/ledger.md` | Row state machine — fenced YAML rows with `id: <token>` + `status:` or `state:` |
| `ai/optimize/findings/<id>.md` | Per-row tactical notes (optional; used for idiom-citation + perf-measurement enforcement — perf rows need `baseline:`+`after:`) |
| `ai/optimize/_coverage-baseline` | Phase 0.5 coverage % baseline — validator compares the report's `Coverage:` line against it (coverage-not-dropped gate) |
| `ai/optimize/final-report.md` | Run summary — `boot-check:` record, perf claims, `Coverage:` line, actionable next steps |
| `.claude/_extracted-idioms.md` | Oracle — must exist for discipline |

## Validator — `validate-optimize-artifacts.sh`

Mechanical checks (install to `~/.claude/scripts/`):

**Phase 0**

- Four evidence blocks present **and non-empty** (Dependency / Responsibility / Layer / Detector runs).
- ≥1 detector line `Modules scanned: N` with N≥1.
- Each `### F-A-*` section cites ≥1 `<path:line>` or `` `path:line` ``.
- Hand-wave grep on architecture-decisions.
- Oracle file exists; under **`--strict`**, Phase 0 text must reference `_extracted-idioms`.

**Ledger** (MANDATORY when findings were fixed — `findings/*.md` present; **`--strict` requires** it even for no-fix runs)

- Rows parsed from fenced YAML: `id:`, `class:`, `status:`/`state:`, `gaps_in`, `gaps_closed`, `closure_verb`.
- Terminal statuses (`verified` / `done` / `fixed`): `gaps_in == gaps_closed` — re-detect parity runs **whenever the ledger exists**, not behind `--strict`.
- Structural classes: net-lines ≤ 0 vs `--phase-base..HEAD` commits matching `<id>:` or `optimize/<id>:` (warn-only if git / base missing).
- Non-structural classes with net line additions: findings file should cite idioms (heuristic grep).
- **Performance rows** (`class: performance` / `render-waste`): `findings/<id>.md` MUST carry a measured `baseline:` + `after:` pair (or an `N ms → M ms`-style measured pair). No perf claim without a measured pair.
- A non-empty ledger that parses to **zero rows** (e.g. indented YAML) warns instead of silently passing.

**Run summary** (`ai/optimize/final-report.md`, when present)

- **Coverage not dropped**: report `Coverage:` line ≥ `ai/optimize/_coverage-baseline` (warn-only if either surface missing).
- **Boot-check record**: a `boot-check: pass | skipped(<reason>)` line required; a skip must also appear under `Not validated:`.
- **Perf claims**: any `perf-win:` / `p95` / `latency` / `throughput` claim must carry a measured pair.

**Findings dir**: optional hand-wave scan on `ai/optimize/findings/*.md`.

Flags: `--strict`, `--quiet`, `--phase-base=<ref>`, `--artifact=`, `--ledger=`, `--findings-dir=`, `--report=`, `--coverage-baseline=`.

## Companion scripts (2026-05) — install the **full** bundle

| Script | Role |
|--------|------|
| `validate-optimize-artifacts.sh` | Primary gate for Phase 0 + ledger |
| `optimize-parallel.sh` | Headless dispatch; parses **`id:`** rows + `status:`/`state:` like `migrate-parallel.sh` |
| `parallel-fan-out.sh` | Worker engine; pass **`--ledger=ai/optimize/ledger.md`** so `flock` targets the optimize ledger (not the migration default) |

**Parallel runners MUST pass `--ledger=`** — wrappers (`optimize-parallel.sh`, `migrate-parallel.sh`, `align-parallel.sh`, `polish-parallel.sh`, `audit-parallel.sh`) forward their ledger path to `parallel-fan-out.sh`.

## Hook integration

Same pattern as migration: PostToolUse / pre-commit on edits under `ai/optimize/**` invoking `validate-optimize-artifacts.sh`. Rule-only tools document manual CI.

## Adapter responsibilities

1. Surface `/optimize` in the native command surface when orchestration packs are selected.
2. Document **`templates/tool-adapters/_optimize-pack-coverage.md`** (this file) so users install the **bundle**, not only the validator script.
3. Preserve foundation-first semantics in translations (architectural diagnosis before tactical sweep).

## See also

- [`templates/tool-adapters/_registry.md`](_registry.md) — parallel orchestrator matrix
- `commands/optimize.md` — user-facing `/optimize` contract
- `scripts/validate-optimize-artifacts.sh` — validator source
