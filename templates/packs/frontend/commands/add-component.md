---
description: Scaffold a reusable component with typed props, tests, and (optional) Storybook entry.
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

**Closure-verb table — component complexity → ceremony:**

| Tier | Trigger | Ceremony | Default? |
|---|---|---|---|
| **Trivial** | New primitive that mirrors an existing sibling (card, badge, chip, button variant) | Code only — component + test + (Storybook entry if siblings have one). Locale keys land in BOTH locales. **No plan, no ADR.** | YES |
| **Standard** | New shape with 1 new prop convention or new slot pattern | Trivial + 1-paragraph sibling-shape note inline | NO |
| **Heavy** | New shared-primitive family (first dialog, first datepicker, first dropdown wrapper) | Standard + ADR + `@design-system-guardian` + `@accessibility-auditor` dispatch | NO |

**Lightweight default.** Trivial-tier is the default. ADR drafts are heavy-tier opt-in only — drafting an ADR to legitimize a new card variant is the same anti-pattern as the migration pack's "ADR-as-closure" trap.

## When to use / NOT to use
- USE: new shared UI primitive used in ≥ 2 places.
- USE: replacing duplicated inline JSX/template across files (extracting a pattern).
- NOT: one-off page-internal markup — keep that inline; abstraction without reuse is debt.
- NOT: a container with data-fetching logic — those are page-level, not components. Use `/add-crud-page` or `/add-feature`.

## Phase 1 — Understand

### Intent gate

If description suggests a different intent, halt with redirect: "enhance / improve" → `/enhance-ui`. "fix" → `/fix-bug`. "test in isolation" → `component-playground` skill. Proceed only for adding a new shared component.

### Standard inputs

- Name in PascalCase (confirm with user if generic — `Box`, `Wrapper`, `Container` are blockers).
- Purpose: ONE sentence, what it presents, no business logic mention.
- Props with types, events emitted, slots/children.
- Confirm caller surface — name 2 expected call sites.

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

Before declaring success, compare the new component against ≥2 sibling files in the same folder. For each gap, return one of: `closed` (matches sibling shape), `still-open` (divergent), `regressed` (introduced a new break on an unrelated axis).

**Halt if any of:**

- Uses raw framework primitives where Base*-wrappers exist — raw `<button>` instead of `<BaseButton>`, raw `<input>` instead of `<FormField>`, raw `<dialog>` instead of `<BaseModal>`.
- Lifecycle divergent from sibling — `onMounted` where siblings use `onActivated` (KeepAlive), or class-component where siblings are `<script setup>` / function components.
- Locale keys present in `en.ts` but missing from `ar.ts` (or any other declared locale) — silent break in the alt locale.
- Default-true wrapper props left implicit — a wrapper exposing `:show-header="true"` by default must be passed `:show-header="false"` explicitly when the affordance is hidden; same for `:can-close`, `:show-footer`.
- New file placed outside the folder's existing path convention (e.g., `src/components/cards/OrderCard.vue` when siblings live at `src/components/orders/Card.vue`).
- New styling system introduced (CSS Modules in a Tailwind repo; styled-components where siblings use scoped CSS).

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
- Test file references a fake i18n stub when project has a real provider → use real provider in tests.

## Related

### Sibling commands in frontend pack
- `/a11y-audit` — sibling command in frontend pack
- `/add-crud-page` — sibling command in frontend pack
- `/add-page` — sibling command in frontend pack
- `/i18n-audit` — sibling command in frontend pack

### Patterns
- `ai/patterns/forms.md`
- `ai/patterns/i18n.md`
- `ai/patterns/rendering-strategy.md`
- `ai/patterns/ssr-safety.md`

### Rules
- `.claude/rules/frontend-principles.md`
