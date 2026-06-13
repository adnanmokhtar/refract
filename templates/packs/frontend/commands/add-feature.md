---
description: End-to-end frontend feature — pages + components + state + i18n + a11y + tests + docs. Detects framework signals, consults every relevant pattern, dispatches every applicable agent, runs every safety skill. Frontend counterpart to backend's /add-feature.
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses Vue 3 + PrimeVue + TypeScript for illustration; substitute your stack's primitives from `_extracted-idioms.md`.


# /add-feature

The frontend orchestration command. Delivers a UI feature end-to-end at best-practice quality the FIRST time. Use when a feature touches more than one component or screen.

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/add-feature <desc> --plan` plans the feature and exits before any edit.

## The Premise (read this first, internalize, do not deviate)

**Existing pages and components are the truth.** Real users ship against the project's existing surface every day. Every sibling page in the same module — every wrapper, composable, service, permission gate, lifecycle hook, locale-key shape — is the intentional pattern, unless explicitly deprecated.

**The agent's job is exactly this:**
1. Find a sibling page / component in the same module that does roughly the same thing (CRUD list, detail view, dialog, form).
2. Mirror its structure: shared wrappers (`<BaseModal>`, `<BaseForm>`, `<FormField>`, `<CrudActions>`, `<CrudPaginator>`), composables (`useCrud`, `useForm`), service layer (`BaseCrudService`), permission gates, lifecycle hooks (`onActivated` for KeepAlive caching), locale-key paths.
3. Add only the delta the new feature actually needs. Everything else: copy the sibling's shape silently.

**Why.** Every page in a typical Vue/React project is ~80% identical scaffolding. New pages that don't mirror existing siblings produce drift that compounds: 50 pages, 50 micro-divergences, 0 shared affordances. The cost surfaces months later as a refactor budget that nobody can fund.

**The agent ONLY asks the user when:**
- **No sibling page exists** (truly new shape — first list page, first wizard, first chart panel).
- **Requirements need a new shared wrapper** that doesn't exist yet (e.g., `<BaseDateRangePicker>` when only `<BaseDatePicker>` exists).
- **Framework-level decision** (new state library, new router pattern, switch from CSR to SSR).

That's it. Three escalation triggers. Everything else — style, error handling, loading state shape, i18n key naming, focus management, empty-state copy — is silent sibling-mirror. No "do you want option A or B" prompts mid-run. Pick the sibling, mirror it, ship.

**Closure-verb table — feature complexity → ceremony:**

| Tier | Trigger | Ceremony | Default? |
|---|---|---|---|
| **Trivial** | New CRUD page that mirrors an existing one | Code only — page + service + types + locale keys (en + ar). Tests + i18n in both locales required. **No plan, no ADR.** | YES |
| **Standard** | New shape, requires 1 small composable OR 1 new shared wrapper | Trivial + 1-paragraph plan + sibling-shape note inline | NO |
| **Heavy** | New framework-level pattern, multi-route flow, new shared component family, accessibility-critical surface | Standard + ADR + reviewer dispatch (a11y-auditor at minimum) + visual snapshot tests + the 6-cascading-reviewer pattern below | NO |

**Lightweight default.** Trivial-tier is the default. The full reviewer cascade and the Phase 5 ADR draft only fire at heavy-tier. Asking for an ADR on a sibling-mirror CRUD page is the same anti-pattern as the migration pack's "ADR-as-closure" trap.

## Phases applied

Heavy tier runs all 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve). Trivial / standard tiers run the subset their ceremony requires (see closure-verb table) — skipping phases outside your tier's ceremony is sanctioned; skipping phases inside it is not.

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

### Intent gate (mandatory pre-step)

Before anything else, parse the user's description for **enhancement / fix / bug** keywords that indicate a different command is the right choice. Halt with a redirect message rather than start an add-feature flow on a request that's not actually adding a feature:

| User description contains | Right command | Action |
|---|---|---|
| "enhance" / "improve" / "polish" / "cleaner" / "better look" / "refine the design" / "redesign" / "match colors" / "fix padding" | `/enhance-ui` (frontend visual work) | Halt; suggest `/enhance-ui <description>` |
| "align" / "convention" / "drift" / "cleanup" / "remove duplication" | `/align-recheck` (codebase quality) | Halt; suggest `/align-recheck <description>` |
| "fix" + ("bug" / "broken" / "wrong" / "crash" / "error") — when the issue is incorrect behavior, NOT visual polish | `/fix-bug` | Halt; suggest `/fix-bug <description>` |
| "audit" / "review" / "inspect" — without intent to change code | `/design-review`, `/a11y-audit`, `/i18n-audit` | Halt; suggest the right read-only audit |
| "iterate" / "try variants" / "few options" — visual exploration | `design-iterate` skill | Halt; suggest "use design-iterate skill on <path>" |
| "add" / "new" / "create" / "build" / "implement" — actually adding new feature work | `/add-feature` (this command) | Proceed |

If the description is ambiguous, ASK the user one clarifying question: "are you adding new functionality, or improving existing UI/UX?" Then route based on the answer.

If the user explicitly insists on `/add-feature` for an enhancement task (e.g., "no, run add-feature anyway"), proceed but flag in the run summary that a redirect was suggested but overridden.

### Standard inputs

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

**MUST read** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) before generating code.

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

After generation, dispatch (gated by tier):

- **Trivial-tier (default):** `@ui-reviewer` only — convention adherence, prop types, no business logic in templates. The sibling-shape halt below is the primary gate.
- **Standard-tier:** add `@i18n-auditor` (if i18n in scope) and `@accessibility-auditor`.
- **Heavy-tier:** the full cascade — `@ui-reviewer`, `@accessibility-auditor`, `@i18n-auditor`, `@design-system-guardian`, `@<framework>-reviewer` (e.g., `@vue-reviewer`, `@react-reviewer`), `@security-auditor` (if auth/payment in scope). Run in parallel.

If a named agent is not installed in this project, perform that review inline against the corresponding pack/domain checklist — never silently skip the axis.

### Sibling-shape mechanical halt (mandatory, all tiers)

Before declaring success, the auditor compares the new page/component against ≥2 sibling files in the same module. Per gap, track `closed` (matches sibling shape) / `still-open` (divergent) / `regressed` (introduced a new break on an unrelated axis). The **per-file verdict** uses the shared vocabulary in [`templates/snippets/sibling-shape-halt.md`](../../../snippets/sibling-shape-halt.md): all gaps `closed` → `aligned`; any `still-open` or `regressed` → `drifted` (HALT); no sibling to compare → `no-siblings` (escalate).

**Halt if any of:**

- Uses raw framework components where Base*-wrappers exist — raw `<Dialog>` instead of `<BaseModal>`, raw `<Paginator>` instead of `<CrudPaginator>`, raw `<Dropdown>` instead of `<BaseDropdown>`, raw `<form>` instead of `<BaseForm>`.
- Uses `onMounted` instead of `onActivated` on a route page (KeepAlive cache divergence — the sibling page caches across navigation; the new page silently re-mounts).
- Has i18n keys missing from one locale (`en.ts` ✓, `ar.ts` ✗ — silent break in the alt locale).
- Doesn't use the project's gold-standard composable (e.g., `useCrud` for list pages, `useForm` for forms).
- Default-true wrapper props left implicit when affordances should be hidden — removing a `@delete-selected` handler does NOT hide the underlying button; pass `:show-delete="false"` / `:can-delete="false"` explicitly.
- New file placed outside the module's existing path convention (e.g., `pages/orders/NewOrder.vue` when sibling lives at `views/orders/Form.vue`).

**Hard rule:** `gap_count_in != gap_count_closed` → HALT. Do not advance to Phase 5. Surface the open list and ask the user: refix, escalate to next tier, or accept. Any `regressed` → HALT. Any NEW gap surfaced by the audit → HALT.

This is the same `regressed` mechanism from `parity-auditor.md` § V2-structure conformance. No silent advance.

## Phase 5 — Update (persist changes to the knowledge base)

Gated by tier. Trivial-tier writes only the bare minimum; ADR drafts are heavy-tier opt-in (avoiding the "ADR-as-closure" anti-pattern):

- **Trivial-tier:** `ai/status.md` § Recent Changes — one-line entry. Nothing else.
- **Standard-tier:** add `ai/modules.md` module entry + 1-paragraph sibling-shape note inline.
- **Heavy-tier:** add `ai/patterns/<new-pattern>.md` (only if new pattern has ≥3 callsites) + `ai/decisions/<NNNN>-<slug>.md` (only if a framework-level decision was made — new state library, new router pattern, CSR↔SSR switch). `ai/dynamic/changelog.md` entry.

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
- **Observability sign-off** (gated on what the project ships — check `.claude/codebase-profile.md` / `CLAUDE.md` for an error-tracker / analytics / RUM layer):
  - Error tracking (Sentry / Bugsnag / equivalent) captures errors from the new routes/components — error boundary or handler wired the same way siblings wire it.
  - Route-level performance signal exists if the project records one (web-vitals / RUM route timing) — new route reports like siblings do.
  - Product analytics events added if siblings of this surface emit them (same naming convention).
  - No console.* left as the only failure signal on any error path.
  - If the project ships NO observability layer: note `observability: none configured` in the report — explicit, never silent.
- **Release note (heavy tier only)**: one PR-description paragraph — feature flag or flagless-with-rationale, rollback path (flag off / revert), and what gets checked on staging/preview before production.

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

- **Sibling-mirror is the default closure.** New pages copy the shape of an existing sibling in the same module. Asking the user about cosmetic / wrapper-shape / lifecycle / i18n-key choices when a sibling answers them is a token-waste anti-pattern.
- **Trivial-tier is the default tier.** ADR / heavy reviewer cascade is opt-in via heavy-tier triggers. Drafting an ADR to legitimize a new CRUD page is forbidden.
- **Default-true wrapper props are explicit.** Removing handlers without setting `:show-*="false"` / `:can-*="false"` is a default-true bug.
- **i18n keys land in BOTH locales** (typically `en.ts` + `ar.ts`) at the same path. Missing-locale = silent break.
- **Match shared wrappers, not raw components.** No raw `<Dialog>` / `<Paginator>` / `<Dropdown>` / `<form>` where `<BaseModal>` / `<CrudPaginator>` / `<BaseDropdown>` / `<BaseForm>` exist.
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
