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
| `ai/refactor/progress.md` | Session / area notes (optional; lighter than optimize) |
| `ai/refactor/ledger.md` | Row state machine for multi-step refactors |
| `ai/refactor/findings/<id>.md` | Per-row evidence |

## When to use

- Extract / rename / flatten / move-to-module for **one area** with a clear target.
- Align / optimize surfaced "route to `/refactor`" for mis-classified rows.

## When NOT to use

- Whole-project or multi-module quality sweep → **`/optimize`**.
- Convention drift only → **`/align`**.
- UI visual iteration → **`/enhance-ui`** / **`/polish`**.
- V1→V2 port → **`/migrate`**.
- New feature / bug fix → **`/add-feature`** / **`/fix-bug`**.

## Flags (optional; mirror optimize where applicable)

Support the same ergonomics as other simple-surface commands where they make sense: `--dry-run`, `--status`, `--resume`, `--allow-dirty`. Project-specific tuning stays in pack overlays.

## Output (brief)

Scope, verbs applied, commits, diff stat, test result, link to `ai/refactor/ledger.md`.
