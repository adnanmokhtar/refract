---
description: Language-agnostic targeted refactor — behaviour-preserving structure changes using refactoring-sweep verbs only. Prefer when stack-specific packs are not loaded or for shared/library code.
---

# /refactor [<scope>]

## Pack overlay — code-quality (always-applied baseline)

**Canonical orchestration** lives in claude-config [`commands/refactor.md`](../../../../commands/refactor.md) (synced to `~/.claude/commands/refactor.md`). This overlay adds **language-agnostic** gates.

### Premise

- **Siblings win** — grep for ≥2 call sites or sibling modules before introducing a shared helper; Rule of Three applies.
- **No new public API** — exported signature changes halt unless user accepts breaking-change workflow (ADR + callers).

### Dispatch

1. Phase 3 MUST read [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md) + [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md).
2. Run [`templates/packs/code-quality/skills/refactoring-sweep.md`](../skills/refactoring-sweep.md) + [`templates/packs/code-quality/agents/refactorer.md`](../agents/refactorer.md).
3. Ledger / validator — [`templates/tool-adapters/_refactor-pack-coverage.md`](../../../tool-adapters/_refactor-pack-coverage.md).

### When this pack leads

Greenfield or polyglot repos where backend/frontend/mobile overlays are not primary; library packages; scripts.
