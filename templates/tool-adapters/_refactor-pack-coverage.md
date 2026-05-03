# Refactor pack — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces **`/refactor`** when code-quality / orchestration wiring includes refactor (via `commands/refactor.md`, `refactoring-sweep`, `refactorer`, and validators).

`/refactor` is a **top-level orchestration command** (targeted, behaviour-preserving refactors only). Discipline is split across `commands/refactor.md`, [`templates/packs/code-quality/skills/refactoring-sweep.md`](../templates/packs/code-quality/skills/refactoring-sweep.md), [`templates/packs/code-quality/agents/refactorer.md`](../templates/packs/code-quality/agents/refactorer.md), pack overlays under `templates/packs/{backend,frontend,mobile,code-quality}/commands/refactor.md`, and **`scripts/validate-refactor-artifacts.sh`**.

There is **no** `refactor-parallel.sh` — `/refactor` is scoped to explicit targets; whole-project sweeps use `/optimize`.

## Capability mapping per tool

| Tool | Surface |
|------|---------|
| Claude Code | Full command + skills + hooks |
| OpenCode / Cursor / Copilot / Qwen / Kimi | Native commands / prompts + hooks where supported |
| Continue / Cline / Windsurf | workflows / prompts |
| Aider / Codex / Gemini | rule-only — user runs validator from shell / CI |

## Simple-surface entry — `/refactor`

- **Source**: [`commands/refactor.md`](../../commands/refactor.md).
- **Progress**: `ai/refactor/progress.md` (optional session notes).
- **Ledger**: `ai/refactor/ledger.md`.
- **Flags** (user-facing, mirror other simple-surface commands where applicable): `--dry-run`, `--status`, `--resume`, `--allow-dirty`.

## Canonical artifacts

| Path | Role |
|------|------|
| `ai/refactor/ledger.md` | Row state machine — fenced YAML rows with `id: <token>` + `status:` or `state:` |
| `ai/refactor/findings/<id>.md` | Per-row notes + idiom citations |
| `.claude/_extracted-idioms.md` | Oracle — sibling patterns |

## Validator — `validate-refactor-artifacts.sh`

Mechanical checks (install to `~/.claude/scripts/`):

**Ledger** (when `ai/refactor/ledger.md` exists)

- Rows parsed from fenced YAML: `id:`, `class:`, `status:`/`state:`, `gaps_in`, `gaps_closed`, `closure_verb`.
- **`closure_verb`** must be one of the 10 `refactoring-sweep` verbs (`extract-method`, `extract-class`, …). Any other verb → FAIL (`parallelize`, `split-god-module`, … route to `/optimize`).
- Terminal statuses (`verified` / `done` / `fixed`): `gaps_in == gaps_closed`.
- Class `refactoring`: net-lines ≤ 0 vs `--phase-base..HEAD` commits matching `<id>:` or `refactor/<id>:` (warn-only if git / base missing).

**Findings dir**: optional hand-wave scan on `ai/refactor/findings/*.md`.

Flags: `--strict`, `--quiet`, `--phase-base=<ref>`, `--ledger=`, `--findings-dir=`, `--self-test`.

## Adapter responsibilities

1. Surface `/refactor` in the native command surface when orchestration packs are selected (same translation rules as other `.claude/commands/*.md` files — Phase 4.8.0).
2. Document **`templates/tool-adapters/_refactor-pack-coverage.md`** (this file) so users install **`validate-refactor-artifacts.sh`**, not only narrative docs.
3. Preserve **behaviour-preserving** semantics in translations (no routing to perf or architectural moves).

## See also

- [`templates/tool-adapters/_registry.md`](_registry.md) — simple-surface vs setup-family split
- [`commands/refactor.md`](../../commands/refactor.md) — user-facing contract
- [`scripts/validate-refactor-artifacts.sh`](../../scripts/validate-refactor-artifacts.sh) — validator source
