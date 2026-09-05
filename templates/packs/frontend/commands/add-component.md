---
description: Scaffold a reusable component with typed props, tests, and (optional) Storybook entry.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses Vue 3 + PrimeVue + TypeScript for illustration; substitute your stack's primitives from `_extracted-idioms.md`.


# /add-component <name>

Build command. Generates a presentational component matching the repo's framework, naming, and authoring style. All 7 phases apply.

## The Premise (read this first, internalize, do not deviate)

**Existing siblings are the truth.** Every shared primitive in `components/` is the intentional shape — its prop typing, its slot/children API, its style mechanism, its test layout. New components copy that shape silently.

**The agent's job is exactly this:**
1. Find ≥2 sibling components in the same folder.
2. Mirror their authoring style: `<script setup>` vs Options API, `function Foo(): JSX.Element` vs `forwardRef`, prop-types convention, default-true wrapper-prop convention, slot/children naming, test-file layout, Storybook story shape.
3. Add only the delta the new component actually needs. Everything else: copy the sibling shape silently.

**The agent ONLY asks the user when:**
- **No sibling exists** in the target folder (truly new primitive — first card, first dialog, first picker).
- **Generic name** (`Box`, `Wrapper`, `Container`) — reject and require a purpose-driven name.
- **New styling system** would be needed (the repo uses Tailwind; component requires CSS-in-JS).

Everything else — prop default-true vs default-false, slot vs prop for header, locale-key path, test-file naming — is silent sibling-mirror.

**Prior-art gate (all tiers):** before scaffolding, search by **behaviour, not name** — does a sibling primitive already cover this capability (an existing `<StatusChip>` when asked for a `<Badge>`)? Near-duplicate found → **HALT**: surface it and ask extend / replace / deliberate parallel. (Inherited from `/add-feature` when invoked via it; runs mechanically when called standalone.)

**New-dependency gate (all tiers):** a package **no sibling already imports** needs justification + **bundle-size delta** (gzipped, tree-shakeable?) before it lands — a platform API or design-system primitive is preferred by default. **HALT** on an unreviewed new dependency; no silent `npm install`.

**Closure-verb table — component complexity → ceremony:**

| Tier | Trigger | Ceremony | Default? |
|---|---|---|---|
| **Trivial** | New primitive that mirrors an existing sibling (card, badge, chip, button variant) | Code only — component + test + (Storybook entry if siblings have one). Locale keys land in BOTH locales. **No plan, no ADR.** | YES |
| **Standard** | New shape with 1 new prop convention or new slot pattern | Trivial + 1-paragraph sibling-shape note inline | NO |
| **Heavy** | New shared-primitive family (first dialog, first datepicker, first dropdown wrapper) | Standard + ADR + `@design-system-guardian` *(ui-ux pack)* + `@accessibility-auditor` dispatch | NO |

**Dispatch fallback (all tiers).** If a named agent, command, or skill is not installed in this project, perform that review inline against the corresponding pack/domain checklist and label it as such in the report — never silently skip the axis, and never claim a reviewer that did not run.

**Lightweight default.** Trivial-tier is the default. ADR drafts are heavy-tier opt-in only — drafting an ADR to legitimize a new card variant is the same anti-pattern as the migration pack's "ADR-as-closure" trap.

## When to use / NOT to use
- USE: new shared UI primitive used in ≥ 2 places.
- USE: replacing duplicated inline JSX/template across files (extracting a pattern).
- NOT: one-off page-internal markup — keep that inline; abstraction without reuse is debt.
- NOT: a container with data-fetching logic — those are page-level, not components. Use `/add-crud-page` or `/add-feature`.

## Phase 1 — Understand

### Intent gate

If description suggests a different intent, halt with redirect: "enhance / improve" → `/enhance-ui` *(ui-ux pack)*; if that pack is not installed, say so and offer `/polish` (core, always present) as the visual-finish route rather than halting into nothing. "fix" → `/fix-bug`. "test in isolation" → `component-playground` skill (which itself halts if the repo already has Storybook / Histoire / Ladle). Proceed only for adding a new shared component.

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

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

**MUST read** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) before generating code.

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

Before declaring success, compare the new component against ≥2 sibling files in the same folder. For each gap, return one of: `closed` (matches sibling shape), `still-open` (divergent), `regressed` (introduced a new break on an unrelated axis).

**Halt if any of:**

- Uses raw framework primitives where Base*-wrappers exist — raw `<button>` instead of `<BaseButton>`, raw `<input>` instead of `<FormField>`, raw `<dialog>` instead of `<BaseModal>`.
- Lifecycle divergent from sibling — `onMounted` where siblings use `onActivated` (KeepAlive), or class-component where siblings are `<script setup>` / function components.
- Locale keys present in `en.ts` but missing from `ar.ts` (or any other declared locale) — silent break in the alt locale.
- Default-true wrapper props left implicit — a wrapper exposing `:show-header="true"` by default must be passed `:show-header="false"` explicitly when the affordance is hidden; same for `:can-close`, `:show-footer`.
- New file placed outside the folder's existing path convention (e.g., `src/components/cards/OrderCard.vue` when siblings live at `src/components/orders/Card.vue`).
- New styling system introduced (CSS Modules in a Tailwind repo; styled-components where siblings use scoped CSS).
- Above-the-fold / hero / heavy-media component whose LCP-relevant image omits the framework priority hint that siblings set (the `lcp-audit` skill owns the detectors) — missing `fetchpriority`/`priority`/eager-hero parity.
- High-frequency or expensive interaction handler (typing, filtering a large list, drag) that runs unbounded per-interaction work — must stay under the INP budget per the `inp-responsiveness` pattern *(performance pack, when co-installed)*; absent that pack, grade it inline (yield / transition / debounce the handler) and record `inp: graded inline (performance pack absent)`.
- Component that renders content images: images use the framework image component with modern format, responsive `srcset`/`sizes`, and explicit `width`/`height` (no CLS) — mirror siblings (the `image-optimization` skill owns the detectors).

**Creation-time only.** This gate compares the NEW component against its siblings. Consolidating raw-primitive drift that already shipped across many files is not this command's job — that is `ui-design-sweep`'s `unify-component` verb *(ui-ux pack)* or the core `/unify-surfaces`.

**Hard rule:** `gap_count_in != gap_count_closed` → HALT. Surface the open list and ask the user: refix, escalate to next tier, or accept. Any `regressed` → HALT.

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
- **LCP priority hint** (gated): if the component is above-the-fold / a hero / heavy media, its LCP image sets the framework priority hint — dispatch the `lcp-audit` skill. Not LCP-relevant → `lcp: n/a`.
- **INP budget** (gated): if the component owns a high-frequency or expensive handler (typing, filtering a large list, drag), per-interaction work stays under budget (yield / transition / debounce) — dispatch the `inp-responsiveness` pattern *(performance pack, when co-installed)*; if that pack is absent, grade the handler inline and report `inp: graded inline (performance pack absent)`. No such handler → `inp: n/a`.
- **Image delivery** (gated): if the component renders content images, they use the framework image component with modern format + responsive sizing + explicit `width`/`height` (no CLS) — dispatch the `image-optimization` skill. No images → `image: n/a`.
- **Observability sign-off** (gated on what the project ships — check `.claude/codebase-profile.md` / `CLAUDE.md`): error boundary / error-tracking wired the way siblings wire it; analytics events added if siblings of this primitive emit them. If the project ships NO observability layer: note `observability: none configured` in the report — explicit, never silent.

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

Status: COMPLETE | INCOMPLETE
        COMPLETE only when Phase 6 is green AND every gated row above reads MET or an explicit
        n/a with its reason (lcp / inp / image / i18n / observability). Otherwise INCOMPLETE,
        naming each unmet gate + the exact next action.
```

## Failure modes
- Hardcoded English / data-fetching inside component → presentational rule broken; refactor before merge.
- New styling system introduced (styled-components in a Tailwind repo) → reject; use repo convention.
- Generic name (`Box`, `Wrapper`) → reject; rename by purpose.
- Missing accessible defaults (`<button>` not `<div onClick>`, `<label htmlFor>`) → blocker.
- Test file references a fake i18n stub when project has a real provider → use real provider in tests.

## Related

### Sibling commands — where the boundary falls
- `/add-page` — a route, not a shared primitive. § When to use / NOT to use draws the line at data-fetching: a container that fetches is page-level.
- `/add-crud-page` — **consumes** the primitives this command produces (`<BaseModal>`, `<BaseForm>`, `<CrudPaginator>`); it never authors them. A missing wrapper is this command's job first.
- `/add-feature` — the caller. It invokes this command for the component step; the prior-art and new-dependency gates above are inherited from it.
- `/unify-surfaces` (core) — the sweep for raw-primitive drift that **already shipped**. This command's halt is creation-time only and says so at § Creation-time only; do not use one for the other's job.
- `/a11y-audit` · `/i18n-audit` — read-only passes over what shipped. The accessible-defaults blocker and the alt-locale halt here are the creation-time subsets of those two sweeps.

### Skills this command dispatches (and when)
- `lcp-audit` — Phase 4 halt + Phase 6, above-the-fold / hero / heavy-media components only. Not LCP-relevant → `lcp: n/a`.
- `image-optimization` — Phase 4 halt + Phase 6, components that render content images. No images → `image: n/a`.
- `component-playground` — the intent-gate destination for "test this component in isolation". It halts itself when the repo already has Storybook / Histoire / Ladle.
- `visual-check` — Phase 6 visual diff, when the project has it.
- `inp-responsiveness` *(performance pack, when co-installed)* — per-interaction main-thread INP budget. Absent that pack → grade the handler inline (yield / transition / debounce) and report `inp: graded inline (performance pack absent)`.

### Patterns actually read
- `i18n.md` — Phase 3 i18n setup, and the Phase 4 halt on keys present in the pivot locale but missing from a declared alt locale.
- `forms.md` — read only when the component wraps an input: its § Accessibility carries the label / `aria-describedby` / error-announcement contract behind § Failure modes' "missing accessible defaults" blocker.

`rendering-strategy.md` and `ssr-safety.md` are deliberately NOT here — a presentational primitive chooses no route strategy and owns no hydration boundary. Those belong to `/add-page` and `/refactor`.

### Rules
- `.claude/rules/frontend-principles.md`
