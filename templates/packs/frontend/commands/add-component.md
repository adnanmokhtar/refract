---
description: Scaffold a reusable component with typed props, tests, and (optional) Storybook entry.
---

# /add-component <name>

Build command. Generates a presentational component matching the repo's framework, naming, and authoring style. All 7 phases apply.

## When to use / NOT to use
- USE: new shared UI primitive used in ≥ 2 places.
- USE: replacing duplicated inline JSX/template across files (extracting a pattern).
- NOT: one-off page-internal markup — keep that inline; abstraction without reuse is debt.
- NOT: a container with data-fetching logic — those are page-level, not components. Use `/add-crud-page` or `/add-feature`.

## Phase 1 — Understand
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
