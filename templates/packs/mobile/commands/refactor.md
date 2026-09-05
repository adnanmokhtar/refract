---
description: Mobile-targeted refactor — preserves navigation contracts, platform lifecycle, and bundle budgets. Behaviour-preserving only; uses refactoring-sweep verbs.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /refactor [<scope>]

## Pack overlay — mobile

**Canonical orchestration:** [`commands/refactor.md`](../../../../commands/refactor.md).

### Mobile-specific gates

- **Navigation** — routes / deep links / intent filters unchanged unless explicitly approved as breaking.
- **Lifecycle** — no refactors that break Activity/Fragment/SwiftUI/React-Native lifecycle ordering vs siblings.
- **Bundle size** — net bundle growth must be justified (extract-method extracting shared code may shrink duplicate strings — cite in findings).
- **Platform APIs** — mirror sibling usage for permissions, push, storage.

### Dispatch

Follow [`commands/refactor.md`](../../../../commands/refactor.md); [`templates/packs/code-quality/skills/refactoring-sweep/SKILL.md`](../../code-quality/skills/refactoring-sweep/SKILL.md); this pack's `STACK.md` + idioms.

### When NOT

New screen flow → `/add-screen` / `/add-feature`. Release/signing changes → DevOps pack commands.
