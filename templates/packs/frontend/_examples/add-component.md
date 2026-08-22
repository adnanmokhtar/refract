---
description: Scaffold a reusable component with typed props, tests, and (optional) Storybook entry.
---

# /add-component <name>

Build command. Generates a presentational component matching the repo's framework, naming, and authoring style. All 7 phases apply.

## The Premise (read this first, internalize, do not deviate)

**Existing siblings are the truth.** Every shared primitive in `components/` is the intentional shape — its prop typing, its slot/children API, its style mechanism, its test layout. New components copy that shape silently.

**The agent's job is exactly this:** find ≥2 sibling components in the same folder; mirror their authoring style (script style, prop-types convention, slot/children naming, test-file layout, story shape); add only the delta the new component actually needs.

**The agent ONLY asks the user when:** no sibling exists in the target folder (truly new primitive); the name is generic (`Box`, `Wrapper`, `Container`) — reject and require a purpose-driven name; a new styling system would be needed. Everything else is silent sibling-mirror.

**Prior-art gate (all tiers):** before scaffolding, search by **behaviour, not name** — does a sibling primitive already cover this capability (an existing `<StatusChip>` when asked for a `<Badge>`)? Near-duplicate found → **HALT**: surface it and ask extend / replace / deliberate parallel.

**New-dependency gate (all tiers):** a package **no sibling already imports** needs justification + a **bundle-size delta** (gzipped, tree-shakeable?) before it lands — a platform API or design-system primitive is preferred by default. **HALT** on an unreviewed new dependency; no silent install.

**Dispatch fallback (all tiers).** If a named agent, command, or skill is not installed in this project, perform that review inline against the corresponding pack checklist and label it as such — never silently skip the axis, and never claim a reviewer that did not run.

**Lightweight default.** A new primitive that mirrors an existing sibling is code only (component + test + story if siblings have one, locale keys in BOTH locales). ADR drafts are heavy-tier opt-in only.

## When to use / NOT to use
- USE: new shared UI primitive used in ≥ 2 places.
- USE: replacing duplicated inline JSX/template across files (extracting a pattern).
- NOT: one-off page-internal markup — keep that inline; abstraction without reuse is debt.
- NOT: a container with data-fetching logic — those are page-level, not components. Use `/add-crud-page` or `/add-feature`.

## Phase 1 — Understand

### Intent gate

If the description suggests a different intent, halt with a redirect: "enhance / improve" → `/enhance-ui` *(ui-ux pack)*; if that pack is not installed, say so and offer `/polish` (core, always present) as the visual-finish route rather than halting into nothing. "fix" → `/fix-bug`. "test in isolation" → the `component-playground` skill. Proceed only for adding a new shared component.

**A redirect must land somewhere.** A halt that points at an uninstalled command is a dead end, not a redirect — name the pack, check it, and offer the installed alternative.
### Standard inputs

- Name in PascalCase (confirm with user if generic — `Box`, `Wrapper`, `Container` are blockers).
- Purpose: ONE sentence, what it presents, no business logic mention.

**Props, events, slots and call sites are NOT inputs — they are outputs of the Premise.** Prop typing convention, slot-vs-prop choice and default-true wrapper props are read from the ≥2 siblings in step 1; the call sites are what the prior-art gate already grepped for. Asking the user for them re-derives what this file just said is silent sibling-mirror, and the answer the user invents overrides the answer the codebase already gave. Print what was derived and from `<path:line>` (`props convention: derived from src/components/orders/Card.vue:8`), and ask ONLY on the three triggers in the Premise — no sibling, generic name, new styling system.

## Phase 2 — Organize
- Detect framework + component style:
  - `*.tsx` with `function Name(): JSX.Element` → React function components.
  - `*.vue` with `<script setup>` → Vue Composition setup.
  - `*.svelte` → Svelte.
  - `*.component.ts` with `@Component` → Angular.
- Decide target folder (`src/components/`, `components/`, `src/lib/components/`, `app/components/`) — mirror existing convention; never invent.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Component-specific:
- 1-2 sibling components in the same folder — mirror file structure, naming, prop typing.
- Repo's styling mechanism (CSS modules / Tailwind / scoped style / styled-components) — DO NOT introduce a new system.
- i18n setup (`vue-i18n`, `next-intl`, `react-i18next`, etc.) — every user-facing string passes through it.
- Test framework + Storybook/Histoire/Ladle presence.

## Phase 4 — Generate
- Component file at the detected components root.
- Typed props interface / `defineProps`.
- Default styles via the repo's mechanism.
- Test file mirroring siblings: render + props variants + interaction + a11y assertion.
- Storybook / Histoire / Ladle entry IF those are present.
- Run lint + the component's tests; iterate to green.

### Sibling-shape mechanical halt (mandatory, all tiers)

Before declaring success, compare the new component against ≥2 sibling files in the same folder. For each gap, return one of: `closed` (matches sibling shape), `still-open` (divergent), `regressed` (a new break on an unrelated axis).

**Halt if any of:**

- Uses raw framework primitives where the project's shared wrappers exist (raw button/input/dialog instead of the shared equivalents).
- Lifecycle divergent from siblings — a different mount/activate hook, or a different component authoring style.
- Locale keys present in the pivot locale but missing from any other declared locale — a silent break in the alt locale.
- Default-true wrapper props left implicit — a wrapper whose affordance defaults to shown must be passed the explicit `false` when it should be hidden.
- New file placed outside the folder's existing path convention.
- A new styling system introduced where siblings use the project's existing one.
- An above-the-fold / hero / heavy-media component whose LCP-relevant image omits the framework priority hint that siblings set.
- A high-frequency or expensive interaction handler that runs unbounded per-interaction work — keep it inside the INP budget (yield / transition / debounce) and record how it was graded.

## Phase 5 — Update
- `ai/dynamic/changelog.md` — one-line: `Added <Component> at <path>`.
- `ai/modules.md` — if the component introduces a new shared primitive class, note it.
- Locale files (`locales/<lang>.json` × N locales) — every user-facing string added.

## Phase 6 — Validate
- Lint passes on new files.
- Tests green.
- Component file < 200 lines (warn if larger — likely doing too much).
- Visual diff via `visual-check` skill if present.
- Hardcoded English (untranslated string) → blocker.
- **INP budget** (gated): if the component owns a high-frequency or expensive handler, per-interaction work stays under budget (yield / transition / debounce) — dispatch the `inp-responsiveness` pattern *(performance pack, when co-installed)*; absent that pack, grade the handler inline and report `inp: graded inline (performance pack absent)`. No such handler → `inp: n/a`.

## Phase 7 — Improve
- `/learn-from-task` — capture pattern if a new prop convention or composition shape emerged.
- If 3+ similar primitives now exist (`OrderCard`, `ProductCard`, `UserCard`) → queue to `ai/dynamic/learned-patterns.md` for a generic `<EntityCard>` proposal.

## Output format
```
## /add-component — <Name> created

Phase 1 (Understand): purpose, props, events confirmed
Phase 3 (Retrieved): siblings mirrored at <path>; styling = <mechanism>
Phase 4 (Generated): <Component>.{tsx|vue|svelte}, .test, .stories (if Storybook)
Phase 5 (Updated): changelog, +N i18n keys × M locales
Phase 6 (Validated): lint OK, tests N/N green, file size <line-count>
Phase 7 (Improved): captured to /learn-from-task

Status: COMPLETE
```

## Failure modes
- Hardcoded English / data-fetching inside component → presentational rule broken; refactor before merge.
- New styling system introduced (styled-components in a Tailwind repo) → reject; use repo convention.
- Generic name (`Box`, `Wrapper`) → reject; rename by purpose.
- Missing accessible defaults (`<button>` not `<div onClick>`, `<label htmlFor>`) → blocker.
- High-frequency or expensive interaction handler (typing, filtering a large list, drag) running unbounded per-interaction work — must stay under the INP budget per the `inp-responsiveness` pattern *(performance pack, when co-installed)*. Absent that pack, grade it inline (yield / transition / debounce the handler) and record `inp: graded inline (performance pack absent)`; never leave the lane silent.
- Test file references a fake i18n stub when project has a real provider → use real provider in tests.
