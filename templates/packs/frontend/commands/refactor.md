---
description: Frontend-targeted refactor — preserves render output, props contracts, and hydration safety. Behaviour-preserving only; uses refactoring-sweep verbs.
---

# /refactor [<scope>]

## Pack overlay — frontend

**Canonical orchestration:** [`commands/refactor.md`](../../../../commands/refactor.md).

### Frontend-specific gates

- **Render parity** — refactors must not change DOM semantics or user-visible text unintentionally; snapshot/a11y tests if present must stay green. **When none are present the gate is not waived, it changes instrument:** run `visual-check` on the touched routes before and after. A refactor with no test and no render evidence is unverified, and the run summary must say `render parity: unverified` rather than claiming behaviour was preserved.
- **Props / emits** — public component contracts unchanged unless breaking-change path explicitly accepted.
- **Hydration** — no refactors that introduce browser-only state during SSR initial render (mirror sibling patterns). Detector: the `ssr-audit` skill on the touched files; `ssr-safety.md` carries the per-framework guard primitive and the fix wording.
- **State** — prefer composables/stores matching siblings; no new global state primitive without sibling precedent.

### Dispatch

Follow [`commands/refactor.md`](../../../../commands/refactor.md); [`templates/packs/code-quality/skills/refactoring-sweep/SKILL.md`](../../code-quality/skills/refactoring-sweep/SKILL.md); read this pack's `STACK.md` + idioms.

### When NOT

Visual redesign → `/enhance-ui` *(ui-ux pack)* or `/polish` *(core, always present)*. Bundle perf → `/optimize` *(core)* or `/bundle-perf` *(performance pack)*. Name the owner before you route: a redirect into an uninstalled pack is a dead end. Absent the pack, use the core command on the same line.
