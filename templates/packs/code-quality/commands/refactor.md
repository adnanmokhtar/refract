---
description: Language-agnostic targeted refactor — behaviour-preserving structure changes using refactoring-sweep verbs only. Prefer when stack-specific packs are not loaded or for shared/library code.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /refactor [<scope>]

## Pack overlay — code-quality (always-applied baseline)

**Canonical orchestration** lives in Refract [`commands/refactor.md`](../../../../commands/refactor.md) (synced to `~/.claude/commands/refactor.md`). This overlay adds **language-agnostic** gates.

### Premise

- **Siblings win** — grep for an existing helper or a sibling module *before* writing a new one; if none exists, the Rule of Three is the bar for creating one: **≥3 concrete callers right now**, not 2. Two call sites duplicate; three establish a shape. (The owning agent states the same number and refuses 2 outright — [`refactorer.md`](../agents/refactorer.md) § "Safe refactors" → *Replace duplication*.)
- **No new public API** — exported signature changes halt unless user accepts breaking-change workflow (ADR + callers).

### Dispatch

1. Phase 3 MUST read [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md) + [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md).
2. Run [`templates/packs/code-quality/skills/refactoring-sweep/SKILL.md`](../skills/refactoring-sweep/SKILL.md) + [`templates/packs/code-quality/agents/refactorer.md`](../agents/refactorer.md).
3. Ledger / validator — [`templates/tool-adapters/_refactor-pack-coverage.md`](../../../tool-adapters/_refactor-pack-coverage.md).

### When this pack leads

Greenfield or polyglot repos where backend/frontend/mobile overlays are not primary; library packages; scripts.

### Boundary vs `/simplify`

`/simplify` is the entropy-reducer — it only **reuses an existing** helper (dedupe/inline) and refuses to introduce a new symbol. `/refactor` is where a fix is allowed to **create a new** helper / abstraction (Rule of Three — ≥3 concrete callers) and perform behaviour-preserving structure moves. If `/simplify` halts a candidate because it would add a new abstraction, that candidate belongs here.

### What this overlay adds that the global `/refactor` does not

This file is **not a second `/refactor`** — the canonical orchestration, the closed Fowler verb set, the git-changed default scope and the ledger contract all live in `commands/refactor.md` and are not restated here. Restating them would create two copies that drift, which is the failure the overlay form exists to avoid.

What the overlay contributes, and the only reason it exists:

| Gate | Why it is here and not in the canonical command |
|---|---|
| **Siblings win** — grep for an existing helper first; create one only at ≥3 concrete callers (Rule of Three) | Language-agnostic. The backend / frontend / mobile overlays each express "check for an existing helper" in their own stack's terms; this is the version that holds when none of those packs is loaded. |
| **No new public API** — an exported signature change halts pending ADR + caller migration | Same reason: "what counts as exported" is stack-specific, so the canonical command cannot state it mechanically. |
| **New symbols are extractions, not introductions** | The apply-engine's line, stated once in [`refactoring-sweep`](../skills/refactoring-sweep/SKILL.md) § Hard rules: a symbol holding code already present in the scope is permitted; a symbol introducing a concept that is not is `introduce-abstraction`, an architectural verb, and halts. |

**Anti-triggers — these are NOT this overlay:**
- A whole-project cleanup, a SOLID-level move, a dead-code or dedup sweep, or any perf work → **`/optimize`** (global). The word "refactor" used loosely for those is the most common mis-route.
- A subtraction-only pass that may not create a symbol → **`/simplify`** (see above).
- Applying an idiom the project already documents to a site that drifted → **`/align`** (global).

## Related

### Canonical command
- [`commands/refactor.md`](../../../../commands/refactor.md) — the orchestration, the verb vocabulary, the scope rule, the ledger. **Read it first; this file is additive.**

### Apply-engine
- [`refactoring-sweep`](../skills/refactoring-sweep/SKILL.md) — the 10 verbs, each with a fingerprint, a procedure and a verify step, plus the extraction-vs-introduction line.
- [`refactorer`](../agents/refactorer.md) — the abstraction gate on top, and the metric-delta + green-characterization evidence contract.

### Safety net
- [`test-shield`](../skills/test-shield/SKILL.md) — pins uncovered touched branches BEFORE the move, so "tests stayed green" means something.
- [`smoke-verify`](../skills/smoke-verify/SKILL.md) — after the last commit: a green suite does not prove the app still boots, and a module move is exactly what breaks boot.

### Sibling commands in code-quality pack
- `/simplify` — the subtraction-only half; the boundary is stated in both directions above.
- `/review-changes` — reviews the resulting diff; route its `refactor:`-class findings back here.

### Rules
- `.claude/rules/engineering-principles.md`
- `.claude/rules/quality-principles.md`
