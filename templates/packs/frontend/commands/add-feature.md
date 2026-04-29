---
description: End-to-end frontend feature — pages + components + state + i18n + a11y + tests + docs. Detects framework signals, consults every relevant pattern, dispatches every applicable agent, runs every safety skill. Frontend counterpart to backend's /add-feature.
---

# /add-feature

The frontend orchestration command. Delivers a UI feature end-to-end at best-practice quality the FIRST time. Use when a feature touches more than one component or screen.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## Invariants

- **Zero placeholders** in output. Every file has real content. No `<TODO>` comments.
- **All relevant patterns consulted** — not just principles, specific pattern docs (`ai/patterns/forms.md`, `rendering-strategy.md`, `i18n.md`, etc.).
- **All applicable agents dispatched** — `ui-architect` designs; `ui-reviewer` reviews; `accessibility-auditor` audits; `i18n-auditor` if i18n in scope; framework-specific reviewer if detected.
- **Signal-aware** — RTL locale detected → RTL audit fires. SSR detected → ssr-safety pattern consulted. Multi-theme detected → design-system-guardian audits.
- **Zero unverified UI ships.** Real Playwright/Cypress test or, at minimum, manual checklist with screenshots.
- **Accessibility from the start, not retrofitted.** WCAG 2.2 AA is the floor.
- **i18n from the start, not retrofitted.** No hardcoded user-facing strings.

## When to use / NOT to use

- USE: new feature touching ≥2 components or pages.
- USE: feature with state management beyond one component.
- USE: feature requiring auth-gated routing.
- USE: feature with form submission + error recovery.
- NOT: a new single component → use `/add-component`.
- NOT: a new single page → use `/add-page`.
- NOT: a CRUD UI on an existing entity → use `/add-crud-page`.
- NOT: a backend feature → use the backend pack's `/add-feature`.

## Phase 1 — Understand (the ask)

Ask (one consolidated question if any of these unknown):

- **What is the user-facing feature?** Describe in plain language: what does the user see / do / accomplish?
- **What user roles use it?** (admin, customer, tenant member, anonymous, etc.)
- **What entry points?** New route? Existing route + new section? Modal/drawer over existing page?
- **What state lives where?** (component-local / store / URL / server)
- **What backend endpoints does it consume?** (existing or to-be-built)
- **Locales supported?** (en only, en+ar+RTL, ...)
- **Theme variants?** (light/dark/per-tenant brand)
- **Browser/device targets?** (mobile-first? desktop-first? PWA?)

If user provides a design (Figma link, screenshot) or written spec, treat it as authoritative.

Otherwise default to the project's prior conventions (read `ai/business-domain.md`, `ai/users-and-personas.md`, `ai/patterns/components.md`).

## Phase 2 — Organize (decompose the work)

Use `ui-architect` agent to produce the design. Output:

```
## Feature: <name>

### Routes
| Path | Component | Layout | Auth | Roles |
|---|---|---|---|---|
| /orders/new | NewOrderPage | DefaultLayout | required | tenant_member |

### Components (new)
| Name | Path | Type | Props | Used by |
|---|---|---|---|---|
| OrderForm | components/orders/OrderForm.* | client | initialValues, onSubmit | NewOrderPage |
| OrderSummary | components/orders/OrderSummary.* | server (where applicable) | order | NewOrderPage |
| ProductPicker | components/orders/ProductPicker.* | client | onPick | OrderForm |

### State
| Concern | Where |
|---|---|
| Form values | useForm in OrderForm (component-local) |
| Selected products | OrderForm parent state |
| Submitted order | server response → routed to /orders/<id> |

### Server interactions
| Action | Endpoint | Mode | Cache strategy |
|---|---|---|---|
| List products | GET /api/products | server-component fetch | next.revalidate=60 |
| Submit order | POST /api/orders | server action / client mutation | invalidate /orders list on success |

### i18n keys (new)
| Key | en | ar |
|---|---|---|
| orders.new.title | New order | طلب جديد |
| orders.new.submit | Place order | إرسال الطلب |
| orders.new.error.product_required | Select at least one product | اختر منتجًا واحدًا على الأقل |

### A11y notes
- Form fields: associated `<label>`, `aria-describedby` for errors, `aria-invalid` on validation fail.
- Submit button: disable + aria-busy during submit; restore + announce result via live region.
- Modal/drawer (if used): focus trap; restore focus on close.
- Keyboard: every interactive element reachable via Tab; visible focus indicator.

### Tests
| Layer | File | Cases |
|---|---|---|
| unit | OrderForm.test.tsx | empty submit, valid submit, validation errors, currency formatting |
| component | OrderForm.spec.ts (Vitest+Testing Library) | render, interaction, submit handler invoked |
| e2e | orders/new.e2e.ts (Playwright) | full flow: arrive → fill → submit → land on /orders/<id> |
| visual | <if visual-regression in scope> | snapshot pre/post-fill, error state |

### Open questions
<anything you had to assume — flag for the user>
```

## Phase 3 — Retrieve (read the right context)

Read, in this order:

1. `CLAUDE.md` — declared stack, conventions, anti-patterns.
2. `ai/business-domain.md` + `ai/business-flows.md` — what the feature is doing in business terms.
3. `ai/users-and-personas.md` — who uses it.
4. `ai/conventions.md` — naming, structure, imports.
5. `ai/patterns/components.md`, `ai/patterns/forms.md`, `ai/patterns/i18n.md`, `ai/patterns/rendering-strategy.md` — applicable patterns.
6. `.claude/rules/frontend-principles.md`, `a11y.md`, `i18n.md`, `styling.md` — applicable rules.
7. Sibling component folder (`components/<similar-feature>/`) — mirror its shape.
8. Framework reference: `references/<framework>.md` (next/nuxt/vue/svelte/angular).
9. Existing endpoints used: read controller signatures + DTOs to align types.

If `ai/_extracted-codebase.md` exists, read it for project-specific anchors (base components, design system primitives, store conventions).

## Phase 4 — Generate (produce the output)

For each component / page / route in the design:

1. **Pre-flight injection.** Every generated file gets the standard pre-flight comment:
   ```
   <!-- Pre-flight: read ai/conventions.md, the design system primitives, sibling components in this folder. -->
   ```
2. **Anchor to the project's actual primitives.** If the project uses a UI library (PrimeVue / shadcn / Material / Chakra / Radix Themes / etc.), use ITS components. Don't hand-roll.
3. **Use ONE styling system.** If Tailwind is in use, don't introduce CSS modules. If CSS modules, don't sneak in Tailwind classes.
4. **Locale strings via i18n key, never hardcoded user-facing text.**
5. **State at the right layer.** Component-local for ephemeral (open/closed); store (Pinia/Zustand/Redux) for cross-component; URL for deep-linkable; server for source-of-truth.
6. **Server data via the project's pattern** — TanStack Query / SWR / native `fetch` in Server Components / `useFetch`. Don't introduce a new pattern.
7. **Form validation at the schema level** (Zod/Yup/class-validator), not inline.
8. **Server action / client mutation discipline** — Next.js Server Action with `"use server"` and Zod validation; or client mutation with optimistic update + rollback on error.

After generation, dispatch:

- `@ui-reviewer` — convention adherence, layer cleanness, prop types, no business logic in templates.
- `@accessibility-auditor` — WCAG 2.2 AA across new components.
- `@i18n-auditor` (if i18n in scope) — every user-facing string keyed; RTL behavior if RTL locale present.
- `@design-system-guardian` (if design system in scope) — token use vs hardcoded values; primitive use vs hand-rolled.
- `@<framework>-reviewer` (e.g., `@vue-reviewer`, `@react-reviewer`) — framework idioms.
- `@security-auditor` (if auth/payment in scope) — XSS, CSRF, secret leak, untrusted HTML.

Run dispatched agents in parallel.

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/modules.md` — append the new feature's module entry.
- `ai/patterns/<new-pattern>.md` — IF a new pattern was extracted (≥3 callsites). Otherwise skip.
- `ai/decisions/<NNNN>-<slug>.md` — IF an architectural choice was made (e.g., picked Server Action over client mutation; chose store over URL state).
- `ai/status.md` § Recent Changes — one-line entry.
- `ai/dynamic/changelog.md` — feature shipped entry.

## Phase 6 — Validate (verify correctness)

- Lint + type-check pass on all touched files.
- Unit tests pass; e2e test passes against running dev server.
- Bundle-size delta acceptable (`@bundle-analyzer` skill if present).
- A11y automated check passes (axe, Lighthouse a11y category ≥95).
- Locale completeness — no missing keys for declared locales.
- **Live browser verification (default for any user-visible feature):**
  1. `dev-server-start` skill — boot the running app (idempotent; reuses already-running server).
  2. `verify-with-playwright` skill — drive the new feature through the Playwright MCP server: navigate → assert visible → fill form → assert success → screenshot. Multi-locale + multi-viewport when `i18n`/breakpoints declared.
  3. Console-error pass — zero errors on load; warnings logged to report.
  - Skipping live verification is allowed only for backend-shaped changes (API contracts, types, store internals) where no rendered surface changed. Use `--no-verify-browser` to opt out explicitly with rationale.

## Phase 7 — Improve (feed the learning loop)

- If a new pattern emerged → `/learn-from-task` to promote.
- If a stale convention was caught → propose update to `ai/conventions.md`.
- If an a11y/i18n drift was found → log to `ai/dynamic/drift-log.md`.
- If the feature involved a new external dependency → ADR proposed.

## Output format

```
## /add-feature — <feature-name>

Status: SHIPPED | NEEDS REVIEW | BLOCKED

Files written:
  - <path>
  - <path>
  - ...

Tests:
  - unit:    <count> new, all passing
  - e2e:     <count> new, all passing
  - a11y:    <axe score>

i18n:
  - new keys: <count> per locale
  - missing:  <0 expected>

Knowledge updates:
  - ai/modules.md      ✓
  - ADR <NNNN>         (if applicable)
  - new pattern        (if extracted)

Open follow-ups:
  - <thing flagged for next session>
```

## Failure modes

- **Untyped server response leaking into UI.** Always type the boundary; align with backend DTO.
- **Hardcoded strings in templates.** Caught by `@i18n-auditor`. Pre-empt by writing keys first.
- **Hand-rolled component when system primitive exists.** Caught by `@design-system-guardian`.
- **State scattered.** State should have ONE home per concern; if it's drifting between component / store / URL, that's an architecture flag.
- **A11y added at the end.** Should be in Phase 1 invariants; if it's a Phase 6 patch, the design wasn't a11y-aware.
- **Server vs client boundary leak.** `"use client"` files importing server-only deps. Audit imports across the boundary.

## Hard rules

- **One styling system.** Pick at Phase 1; never mix.
- **Every user-facing string is a locale key.** No exceptions, even for "internal" tools.
- **Every form has schema validation at the boundary** (server action OR API endpoint), not just client-side.
- **Every Server Component fetch is explicit about cache.** `cache:` and `next.revalidate` set on every `fetch`.
- **Every Server Action validates input.** Zod or equivalent. Action is a public RPC surface.
- **Every interactive element keyboard-reachable + has visible focus.** A11y is a must.

## Related

- `/add-page` — single-page version of this command.
- `/add-component` — single-component version.
- `/add-crud-page` — CRUD UI on an existing entity.
- `/i18n-audit` + `/a11y-audit` — standalone audits invoked by this command's Phase 4.
- Backend's `/add-feature` — counterpart for backend work; usually paired in cross-stack features.
