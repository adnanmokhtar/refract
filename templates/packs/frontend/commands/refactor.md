---
description: Frontend-targeted refactor — preserves render output, props contracts, and hydration safety. Behaviour-preserving only; uses refactoring-sweep verbs.
---

# /refactor [<scope>]

## Pack overlay — frontend

**Canonical orchestration:** [`commands/refactor.md`](../../../../commands/refactor.md).

This overlay is deliberately two rules long. Typed props/emits/slots, one styling system, sibling-mirrored state placement and "no new global store" are already **MUSTs** in `.claude/rules/frontend-principles.md`, which is always loaded whenever this command runs; "public API shape unchanged" is already the canonical command's own contract. Restating any of them here would buy nothing and cost budget. What follows is only what the universal `/refactor` cannot know.

### 1. No test does not mean no gate — it means a different instrument

The canonical contract is "behaviour-preserving", and on most stacks the test suite is what proves it. On a UI the suite frequently does not cover the thing that broke: snapshot, story and a11y suites are optional in most repos, and the ones that exist often stop at the component the refactor moved *out* of.

So the gate does not waive when the instrument is missing — it switches:

| What the touched files have | The evidence | Recorded as |
|---|---|---|
| Snapshot / story / a11y suite covering them | A green run **that was not re-recorded** | `render parity: verified (<suite>)` |
| A dev server but no suite | `visual-check` on the touched routes, before **and** after | `render parity: verified (visual-check, N routes)` |
| Neither | Nothing was proven | `render parity: unverified` |

Two rules attach to that table. **Re-recording snapshots so a refactor goes green is not evidence** — a snapshot diff is acceptable only where the extraction is provably behaviour-neutral, and "provably" means the diff is whitespace or attribute order, not a changed node. And the run summary prints the third row verbatim when it applies: `render parity: unverified` is a legitimate outcome of this command, but claiming behaviour was preserved on no evidence is not.

### 2. An extraction can move code across the server/client boundary without changing a line of it

This is the frontend's version of the wire: **where a component renders is part of its behaviour, and the closed verb set moves code between files, which is exactly what changes it.** The rendered DOM can be byte-identical on the client and the refactor still be a defect, because the boundary is not in the markup.

Three moves that look clean and are not:

| Move | What silently changed |
|---|---|
| `extract-class` / `extract-method` pulls a subtree out of a `"use client"` file into a new one | The new file has no directive. It is now a server component: hooks, handlers and browser reads in it are a build error or a boundary leak — and `import`ing a server-only module into the old file is now a bundle leak the other way. |
| `move-to-module` relocates a helper that read `window` behind an `onMounted` / `browser` / `isPlatformBrowser` guard | The guard stayed in the old file. The helper now runs at module scope on the server. |
| `extract-param-object` / `replace-temp-with-query` hoists a value computed inside an effect up into render | Deterministic on the client, non-deterministic across the boundary — the classic `Date.now()` / `localStorage` hydration mismatch, introduced by a refactor that touched no logic. |

The test that decides it: *does every moved symbol still render on the same side of the boundary it rendered on before?* If the answer needs checking rather than asserting, run the `ssr-audit` skill on the touched files — it greps exactly these three shapes — and cite the guard primitive it names. `ssr-safety.md` carries the per-framework guard and the fix wording; do not re-derive either here. On a pure-CSR SPA this rule is inert: record `hydration boundary: n/a (no SSR)` rather than skipping it silently.

### Dispatch

Follow [`commands/refactor.md`](../../../../commands/refactor.md); the `refactoring-sweep` skill *(code-quality pack, when co-installed)* supplies the closed verb set. Absent that pack → the verbs come from the canonical `commands/refactor.md` alone and the run summary records `verb source: canonical command (code-quality pack absent)`; never claim a sweep the skill did not run. Read this pack's `STACK.md` + idioms either way.

### When NOT

Visual redesign → `/enhance-ui` *(ui-ux pack)* or `/polish` *(core, always present)*. Bundle perf → `/optimize` *(core)* or `/bundle-perf` *(performance pack)*. Name the owner before you route: a redirect into an uninstalled pack is a dead end. Absent the pack, use the core command on the same line.
