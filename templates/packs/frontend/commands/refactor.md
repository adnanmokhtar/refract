---
description: Frontend-targeted refactor — preserves render output, props contracts, and hydration safety. Behaviour-preserving only; uses refactoring-sweep verbs.
---

# /refactor [<scope>]

## Pack overlay — frontend

**Canonical orchestration:** [`commands/refactor.md`](../../../../commands/refactor.md).

### Frontend-specific gates

- **Render parity** — refactors must not change DOM semantics or user-visible text unintentionally; snapshot/a11y tests if present must stay green.
- **Props / emits** — public component contracts unchanged unless breaking-change path explicitly accepted.
- **Hydration** — no refactors that introduce browser-only state during SSR initial render (mirror sibling patterns).
- **State** — prefer composables/stores matching siblings; no new global state primitive without sibling precedent.

### Dispatch

Follow [`commands/refactor.md`](../../../../commands/refactor.md); [`templates/packs/code-quality/skills/refactoring-sweep.md`](../../code-quality/skills/refactoring-sweep.md); read this pack's `STACK.md` + idioms.

### When NOT

Visual redesign → `/enhance-ui` / `/polish`. Bundle perf → `/optimize` or `/bundle-perf`.
