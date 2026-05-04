---
description: Targeted behaviour-preserving refactor. Applies only the closed refactoring vocabulary from refactoring-sweep — no architectural moves, no perf work, no dead-code sweeps. Optional scope defaults to current git changes (HEAD + dirty tree). Stack-agnostic; routes pack-specific gates via templates/packs/<track>/commands/refactor.md when applicable.
kind: command
pack: orchestration
---

# /refactor [<scope>]

## What this does

**Single focused command: change structure, not behaviour.** Dispatches [`templates/packs/code-quality/skills/refactoring-sweep.md`](../templates/packs/code-quality/skills/refactoring-sweep.md) (10 closure verbs) plus [`templates/packs/code-quality/agents/refactorer.md`](../templates/packs/code-quality/agents/refactorer.md) for SOLID / naming discipline. Reads Phase 3 MUST-list via [`templates/snippets/phase-3-always-reads.md`](../templates/snippets/phase-3-always-reads.md) and [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md).

**Not** `/optimize` — no Phase 0 architectural diagnosis, no god-module splits, no perf (`parallelize`, `add-index`), no dead-code / dedup project sweeps. If the work needs those → `/optimize [<scope>]`.

## The premise

**Existing siblings are the truth.** Before extracting or renaming, read ≥2 sibling files in the same module and mirror path layout, naming, DI, error envelopes, and test layout.

**Behaviour-preserving is mandatory.** Observable outputs unchanged; public API shape unchanged unless the user explicitly accepts a breaking refactor + ADR (then it is no longer a pure `/refactor` — halt and split the PR).

## Closure verbs (closed vocabulary)

Only these verbs may appear in `ai/refactor/ledger.md` as `closure_verb:` (same set as `refactoring-sweep`):

| Verb | Notes |
|------|--------|
| `extract-method` | |
| `extract-class` | |
| `extract-param-object` | |
| `flatten-conditional` | |
| `move-to-module` | Same-layer or idioms-approved moves only — not cross-tier architectural moves |
| `replace-magic-with-constant` | |
| `replace-temp-with-query` | |
| `replace-loop-with-pipeline` | |
| `rename` | Symbol-aware; grep all call sites |
| `encapsulate` | |

Any other verb (e.g. `parallelize`, `split-god-module`, `centralize-cross-cutting`) → **mis-classified** — route to `/optimize` or `/align` per finding class.

## Args

- **`<scope>`** (optional) — path, module name, symbol, or natural-language target (e.g. `src/orders/service.ts`, `the checkout composable`).  
  If omitted: **default scope = current git changes** — union of `git diff --name-only HEAD` and `git diff --name-only --cached` plus unstaged; if that set is empty, **halt** and ask for an explicit scope (whole-repo refactor is `/optimize`, not `/refactor`).

## What happens internally (silent)

1. Resolve scope to concrete paths; infer primary pack (`backend` / `frontend` / `mobile` / other) from [`templates/packs/_registry.md`](../templates/packs/_registry.md) signals and `.claude/_extracted-codebase.md`.
2. Read pack overlay when present: `templates/packs/<pack>/commands/refactor.md` (after `/setup-project`, under `.claude/commands/` from the same pack copy).
3. Dispatch **`refactoring-sweep`** with `--target=<resolved-paths>` and allowed verbs = table above.
4. **`refactorer`** agent validates no new abstraction without Rule-of-Three / sibling precedent.
5. After each discrete edit: lint + typecheck + **scoped tests**; coverage must not drop.
6. Record rows in **`ai/refactor/ledger.md`** (fenced YAML: `id`, `class: refactoring`, `status`/`state`, `gaps_in`, `gaps_closed`, `closure_verb`).
7. Optional per-row notes in **`ai/refactor/findings/<id>.md`**.
8. Mechanical gate: **`scripts/validate-refactor-artifacts.sh`** (install to `~/.claude/scripts/`). See [`templates/tool-adapters/_refactor-pack-coverage.md`](../templates/tool-adapters/_refactor-pack-coverage.md).

## Progress tracking

| File | Role |
|------|------|
| `ai/refactor/progress.md` | Session / area notes (optional; lighter than `/optimize`) |
| `ai/refactor/ledger.md` | Row state machine for multi-step refactors |
| `ai/refactor/findings/<id>.md` | Per-row evidence |

`/refactor` does **not** run the multi-day “inventory → pending areas → pick next” workflow used by `/migrate`, `/optimize`, `/align`, and `/polish`. Default scope is **git-changed paths**; whole-repo structural work belongs to **`/optimize`**.

## Pre-requisites

- `_extracted-idioms.md` OR `codebase-profile.md` populated (sibling patterns + oracle).
- Mechanical CI green (lint, typecheck, tests) before starting.
- Working tree: prefer clean; **`--allow-dirty`** to proceed with local edits.

## When to use

- Extract / rename / flatten / move-to-module for **one area** with a clear target.
- Align / optimize surfaced "route to `/refactor`" for mis-classified rows.

## When NOT to use

- Whole-project or multi-module quality sweep → **`/optimize`**.
- Convention drift only → **`/align`**.
- UI visual iteration → **`/enhance-ui`** / **`/polish`**.
- V1→V2 port → **`/migrate`**.
- New feature / bug fix → **`/add-feature`** / **`/fix-bug`**.

## Optional flags

**User-facing**

- `--dry-run` — show planned edits; no writes.
- `--allow-dirty` — proceed with uncommitted changes.
- `--status` — read-only session / ledger summary when supported by the runner.
- `--resume` — continue an in-progress refactor when supported by the runner.

**Validator / CI** (passed through to `validate-refactor-artifacts.sh` when invoking the gate)

- `--strict` — treat warnings as failures where applicable.
- `--quiet` / `-q` — minimal output.
- `--phase-base=<git-ref>` — git range for net-lines checks on `refactoring` rows.
- `--ledger=<path>` / `--findings-dir=<path>` — override default `ai/refactor/ledger.md` and `ai/refactor/findings/`.

**Not supported on `/refactor`** (multi-area orchestration belongs to **`/optimize`** / **`/align`** / **`/polish`** / **`/migrate`): `--refresh`, `--re-audit`, `--ignore-ledger`, `--restart`, `--reset`, `--max-parallel`, `--exclude`, `--surface-blockers`. Pack overlays may document extra toggles.

## What you see (output)

```
Refactor complete

Scope:               src/orders/service.ts (or git-changed paths)
Verbs:               extract-method ×2, rename ×1
Commits:             3
Diff:                +42 / -38 = +4 lines
Tests:               84/84 passing
Ledger:              ai/refactor/ledger.md

Next: review commits  OR  /optimize the module if architectural work surfaced
```

## Failure modes

- **Empty default scope** (no git-changed files and no `<scope>`) → halt; pass an explicit path or use `/optimize` for broad sweeps.
- **Validator failure** → fix ledger / findings / final-report per script output; re-run gate.
- **Breaking API change required** → halt; split to a dedicated PR + ADR — not a pure `/refactor`.

## Hard rules (internal)

Applied silently:

- **Validator gate is mandatory.** After edits, run `~/.claude/scripts/validate-refactor-artifacts.sh`. Enforces `closure_verb` ∈ 10 refactoring-sweep verbs, gap-count parity for terminal rows, optional net-lines check with `--phase-base`, hand-wave scan on findings, and **`## Actionable next steps`** in `ai/refactor/final-report.md` when that file exists.
- **Only refactoring-sweep verbs** in `ai/refactor/ledger.md` — route architectural / perf / convention classes to `/optimize` or `/align`.
- **Behaviour-preserving** unless user explicitly accepts breaking change + ADR.
- **One discrete edit cluster per commit** where practical; tests stay green; coverage must not drop.

## Final report contract

When `/refactor` writes `ai/refactor/final-report.md` (typically after multi-file runs), the report MUST end with an **`## Actionable next steps`** section per `~/.claude/templates/snippets/actionable-next-steps.md`. Every halted row, every refactor that surfaced an out-of-scope concern (architectural move → `/optimize`, visual concern → `/polish`, missing test → `/add-test`), and every "needs follow-up" gets one paste-ready follow-up command — comment line (WHAT + WHY + scope) + exact command + sorted by leverage. The validator's `check_actionable_next_steps` halts when the section is missing OR when a deferral is described without a paste-ready command line.

## Related (advanced)

- **`/optimize`** — architectural diagnosis + tactical sweep + whole-repo quality; use when `/refactor` is too narrow or work spans modules.
- **`/align`** — convention / idiom drift only (align closure verbs), not extract/rename focused refactors.
- **Pack overlays** — `templates/packs/<track>/commands/refactor.md` after `/setup-project`.
- **`refactoring-sweep`** skill — full procedure for the 10 verbs.
