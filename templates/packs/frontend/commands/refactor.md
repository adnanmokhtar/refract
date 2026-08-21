---
description: Frontend-targeted refactor — preserves render output, props contracts, and hydration safety. Behaviour-preserving only; uses refactoring-sweep verbs.
---

# /refactor [<scope>]

## Pack overlay — frontend

**Canonical orchestration:** [`commands/refactor.md`](../../../../commands/refactor.md).

### Frontend-specific gates

- **Render parity** — refactors must not change DOM semantics or user-visible text unintentionally; snapshot/a11y tests and any component-story suite (Storybook / Histoire / Ladle) if present must stay green. A snapshot diff is acceptable *only* when the extraction is provably behaviour-neutral; re-recording snapshots so a refactor goes green is how render regressions ship. **When none of those are present the gate is not waived, it changes instrument:** run `visual-check` on the touched routes before and after. A refactor with no test and no render evidence is unverified, and the run summary must say `render parity: unverified` rather than claiming behaviour was preserved.
- **Props / emits** — public component contracts unchanged unless breaking-change path explicitly accepted.
- **Hydration** — no refactors that introduce browser-only state during SSR initial render (mirror sibling patterns). Detector: the `ssr-audit` skill on the touched files; `ssr-safety.md` carries the per-framework guard primitive and the fix wording.
- **State** — prefer composables/stores matching siblings; no new global state primitive without sibling precedent. An extracted composable is *placed* where the siblings in its own folder place theirs — a correct extraction filed in the wrong directory is still drift.

### Dispatch

Follow [`commands/refactor.md`](../../../../commands/refactor.md); the `refactoring-sweep` skill *(code-quality pack, when co-installed)* supplies the closed verb set. Absent that pack → the verbs come from the canonical `commands/refactor.md` alone and the run summary records `verb source: canonical command (code-quality pack absent)`; never claim a sweep the skill did not run. Read this pack's `STACK.md` + idioms either way.

### When NOT

Visual redesign → `/enhance-ui` *(ui-ux pack)* or `/polish` *(core, always present)*. Bundle perf → `/optimize` *(core)* or `/bundle-perf` *(performance pack)*. Name the owner before you route: a redirect into an uninstalled pack is a dead end. Absent the pack, use the core command on the same line.
