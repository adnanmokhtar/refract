---
description: End-to-end frontend feature — pages + components + state + i18n + a11y + tests + docs. Detects framework signals, consults every relevant pattern, dispatches every applicable agent, runs every safety skill. Frontend counterpart to backend's /add-feature.
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses Vue 3 + PrimeVue + TypeScript for illustration; substitute your stack's primitives from `_extracted-idioms.md`.


# /add-feature

The frontend orchestration command. Delivers a UI feature end-to-end at best-practice quality the FIRST time. Use when a feature touches more than one component or screen.

**Accepts either** a bare `"<description>"` (re-derives requirements) **or** a `specs/<file>` path / `Spec-ID` produced by `/analyze-task` (consumes the spec as the requirements contract — see Phase 1).

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/add-feature <desc> --plan` plans the feature and exits before any edit. The plan is written to `.claude/plans/` and is executed later via `/execute-plan <file>`. When planning from a spec (`/add-feature <Spec-ID> --plan`), the emitted plan carries a `Spec: <Spec-ID>` header so the re-entry run rejoins the spec branch (full-depth ingestion, conformance gate, traceability rebuild) instead of re-deriving requirements.

## The Premise (read this first, internalize, do not deviate)

**Existing pages and components are the truth.** Real users ship against the project's existing surface every day. Every sibling page in the same module — every wrapper, composable, service, permission gate, lifecycle hook, locale-key shape — is the intentional pattern, unless explicitly deprecated.

**The agent's job is exactly this:**
1. Find a sibling page / component in the same module that does roughly the same thing (CRUD list, detail view, dialog, form).
2. Mirror its structure: shared wrappers (`<BaseModal>`, `<BaseForm>`, `<FormField>`, `<CrudActions>`, `<CrudPaginator>`), composables (`useCrud`, `useForm`), service layer (`BaseCrudService`), permission gates, lifecycle hooks (`onActivated` for KeepAlive caching), locale-key paths.
3. Add only the delta the new feature actually needs. Everything else: copy the sibling's shape silently.

**Why.** Most of any page in this project is scaffolding its siblings already settled — routing entry, layout import, fetch call site, loading/error/empty states, permission gate, locale-key path. A page that re-decides them produces one micro-divergence, and micro-divergences compound: nothing is shared, so nothing can be fixed once. The cost surfaces months later as a refactor budget nobody can fund. Measure the claim on THIS repo rather than quoting a ratio — diff two sibling pages and count what differs; that count is the real delta this command is allowed to add.

**The agent ONLY asks the user when:**
- **No sibling page exists** (truly new shape — first list page, first wizard, first chart panel).
- **Requirements need a new shared wrapper** that doesn't exist yet (e.g., `<BaseDateRangePicker>` when only `<BaseDatePicker>` exists).
- **Framework-level decision** (new state library, new router pattern, switch from CSR to SSR).

That's it. Three escalation triggers. Everything else — style, error handling, loading state shape, i18n key naming, focus management, empty-state copy — is silent sibling-mirror. No "do you want option A or B" prompts mid-run. Pick the sibling, mirror it, ship.

**Closure-verb table — feature complexity → ceremony:**

| Tier | Trigger | Ceremony | Default? |
|---|---|---|---|
| **Trivial** | New CRUD page that mirrors an existing one | Code only — page + service + types + locale keys (en + ar). Tests + i18n in both locales required. **No plan, no ADR.** | YES |
| **Standard** | New shape, requires 1 small composable OR 1 new shared wrapper | Trivial + 1-paragraph plan + sibling-shape note inline + **bundle-size delta check** (any new shared wrapper / lazy-route / heavy import) | NO |
| **Heavy** | New framework-level pattern, multi-route flow, new shared component family, accessibility-critical surface | Standard + ADR + reviewer dispatch (a11y-auditor at minimum) + visual snapshot tests + the 6-cascading-reviewer pattern below | NO |

**Lightweight default.** Trivial-tier is the default. The full reviewer cascade and the Phase 5 ADR draft only fire at heavy-tier. Asking for an ADR on a sibling-mirror CRUD page is the same anti-pattern as the migration pack's "ADR-as-closure" trap.

## Phases applied

Heavy tier runs all 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve). Trivial / standard tiers run the subset their ceremony requires (see closure-verb table) — skipping phases outside your tier's ceremony is sanctioned; skipping phases inside it is not.

## Invariants

- **Zero placeholders** in output. Every file has real content. No `<TODO>` comments.
- **New npm dependency is gated** — a package no sibling already imports halts for a dependency review (maintenance / license / bundle-size / supply-chain) before it lands. No silent `npm install`, any tier. See Phase 4 § New-dependency gate.
- **All relevant patterns consulted** — not just principles, specific pattern docs (`ai/patterns/forms.md`, `rendering-strategy.md`, `i18n.md`, etc.).
- **All applicable agents dispatched** — `ui-architect` designs; `ui-reviewer` reviews (carrying the framework-specific lens — Vue/React/Svelte/etc.); `accessibility-auditor` audits; `i18n-auditor` if i18n in scope.
- **Signal-aware** — RTL locale detected → RTL audit fires. SSR detected → ssr-safety pattern consulted. Multi-theme detected → `@design-system-guardian` *(ui-ux pack)* audits, or — when that pack is absent — the theme lane is graded inline against `rules/frontend-principles.md` § Must not (the design-token bullet) and reported as `theme: graded inline (ui-ux pack absent)`.
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

### Spec-driven branch (when given a spec path / Spec-ID)

If the argument is a path under `specs/` (or a `Spec-ID`), READ that spec **in full** and treat it as the requirements **CONTRACT**. Ingest every section, not just stories + AC:

- **User stories + acceptance criteria** — each AC carries an AC-ID; these drive the traceability rebuild (Phase 6).
- **Traceability table** — AC-ID → component/screen/test mapping; this is the seed for the Phase 6 AC→test map.
- **Affected modules, components/screens/state, API consumed, Test plan, Out-of-scope.**
- **a11y requirements** — each becomes a Phase 6 axe/keyboard conformance check.
- **i18n requirements** — each becomes a Phase 6 both-locale check.
- **NFR / perf-budget** — bundle-size ceilings, LCP/INP/CLS targets, route-timing budgets, **navigation budgets** (route prefetch on primary nav links, instant-loading route-change→paint target, streaming targets for SSR routes); each becomes a Phase 6 bundle-size/LCP/nav-speed gate.
- **Authorization & data-sensitivity** — per-role access rules + sensitive-field handling; each rule becomes a Phase 6 unauthorized-access test.
- **Observability** — required error/analytics/RUM signals; each must be matched by a wired signal in Phase 6.
- **Rollout** — flag strategy, staged exposure, rollback path; carried into the Phase 6 release note.
- **Success metrics** — each must be instrumented (event wired) or explicitly deferred in Phase 6.
- **Sizing signal** — the spec's own complexity estimate; seeds the closure-verb tier (see Phase 1 § Sizing-signal seeding).

Do NOT re-derive requirements the spec already contains; proceed to design/generate from the spec (skip the Standard-inputs re-interview below). Still run the prior-art gate, the sibling-shape halt (Phase 4), and the new-dependency gate (Phase 4).

**Sizing-signal seeding.** Seed the closure-verb tier from the spec's **Sizing signal** rather than re-estimating from scratch. The seed is **promotion-only**: a stronger local signal (heavy reviewer triggers met, accessibility-critical surface, framework-level decision) may promote the tier above the spec's seed, never demote below it. Record any divergence (`spec sized standard; promoted to heavy because <reason>`) inline and in the run summary.

**Open-questions HALT invariant.** If the spec carries unresolved **Open questions**, HALT before Phase 4 (Generate). Surface them and require resolution (answer recorded back to the spec, or an explicit accept-with-assumption from the user) before any code is generated. Unresolved open questions are a hard stop, not a warning.

Otherwise (bare description) proceed with the existing flow below.

### Intent gate (mandatory pre-step)

Before anything else, parse the user's description for **enhancement / fix / bug** keywords that indicate a different command is the right choice. Halt with a redirect message rather than start an add-feature flow on a request that's not actually adding a feature:

| User description contains | Right command | Action |
|---|---|---|
| "enhance" / "improve" / "polish" / "cleaner" / "better look" / "refine the design" / "redesign" / "match colors" / "fix padding" | `/enhance-ui` *(ui-ux pack)* | Halt; suggest `/enhance-ui <description>` — or `/polish` (core) if ui-ux is not installed |
| "align" / "convention" / "drift" / "cleanup" / "remove duplication" | `/align-recheck` *(align pack)* | Halt; suggest `/align-recheck <description>` — or `/align` (core) if that pack is not installed |
| "fix" + ("bug" / "broken" / "wrong" / "crash" / "error") — when the issue is incorrect behavior, NOT visual polish | `/fix-bug` | Halt; suggest `/fix-bug <description>` |
| "audit" / "review" / "inspect" — without intent to change code | `/a11y-audit` + `/i18n-audit` (this pack); `/design-review` *(ui-ux pack)* | Halt; suggest the right read-only audit |
| "iterate" / "try variants" / "few options" — visual exploration | `design-iterate` skill *(ui-ux pack)* | Halt; suggest "use design-iterate skill on <path>" — absent that pack, `/polish` (core) |
| "add" / "new" / "create" / "build" / "implement" — actually adding new feature work | `/add-feature` (this command) | Proceed |

If the description is ambiguous, ASK the user one clarifying question: "are you adding new functionality, or improving existing UI/UX?" Then route based on the answer.

If the user explicitly insists on `/add-feature` for an enhancement task (e.g., "no, run add-feature anyway"), proceed but flag in the run summary that a redirect was suggested but overridden.

### Prior-art gate (mandatory, all tiers)

The intent gate above routes the *request*. This gate checks the *capability*: **does the page / flow / component already exist** under another name? Sibling search finds a shape to copy — it does not tell you the feature is already shipped on another route.

1. Search by **behavior, not name** — existing routes, page components, composables, or services that already cover the user-facing capability (a "saved filters" feature may already live inside an existing list page's `useCrud` state).
2. **Near-duplicate found → HALT.** Surface the existing surface (route + what it does) and ask: extend it, replace it, or ship a deliberate parallel (rare — record the rationale inline).
3. Nothing matches → continue.

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

Otherwise default to the project's prior conventions (read `ai/business-domain.md`, `ai/users-and-personas.md`, and the sibling components themselves — the component-shape contract lives in the sibling-shape halt below and in `@ui-architect` § Component API, not in a pattern file).

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
5. `ai/patterns/forms.md`, `ai/patterns/i18n.md`, `ai/patterns/rendering-strategy.md`, `ai/patterns/ssr-safety.md` — applicable patterns.
6. `.claude/rules/frontend-principles.md` (a11y + styling MUSTs live inside it) and `.claude/rules/i18n.md`; plus `ui-principles.md` *(ui-ux pack, when co-installed)*.
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
- **Heavy-tier:** the full cascade — `@ui-reviewer`, `@accessibility-auditor`, `@i18n-auditor`, `@design-system-guardian`, `@security-auditor` (if auth/payment in scope). Run in parallel. `@ui-reviewer` carries the framework-specific lens (Vue/React/Svelte/etc.) — there is no separate per-framework reviewer agent.

If a named **agent, command, or skill** is not installed in this project, perform that review inline against the corresponding pack/domain checklist and label the lane accordingly (`<axis>: graded inline (<pack> absent)`) — never silently skip the axis, never claim a reviewer that did not run, and never halt into a redirect target the project does not have.

### New-dependency gate (all tiers)

If implementing the feature pulls in an npm package **no sibling already imports**, it never lands silently — the cost on frontend is paid by every user on every page load.

- **Confirm it's actually new** — check `package.json` + lockfile; a sibling may already ship an equivalent (date lib, form lib, icon set). Reuse it.
- **Run a dependency review** (dispatch `security-auditor`, or inline against the checklist): maintenance health, license, **bundle-size delta** (gzipped, and whether it tree-shakes), and whether a platform API or an already-installed primitive covers the need.
- **Record the decision** — one PR line (trivial / standard) or an ADR (heavy, or any auth / payment / crypto dep).

HALT on an unreviewed new dependency. Prefer the design-system / already-present primitive over a new package by default.

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

**When built from a spec — `Spec: <Spec-ID>` on ALL tiers.** The backreference is not gated by tier. Wherever this tier writes, the `Spec: <Spec-ID>` line goes with it:

- **Trivial-tier:** on the `ai/status.md` § Recent Changes one-line entry (and in the trivial output block — see Output format).
- **Standard-tier:** the above + on the `ai/modules.md` module entry.
- **Heavy-tier:** the above + on the `ai/dynamic/changelog.md` entry (and any ADR header it drafts).

The same `Spec: <Spec-ID>` line belongs in the PR description on every tier, so the shipped feature traces back to its source spec regardless of ceremony.

## Phase 6 — Validate (verify correctness)

- Lint + type-check pass on all touched files.
- Unit tests pass; e2e test passes against running dev server.
- Bundle-size delta acceptable — measured with the `bundle-analyze` skill (in-pack; it is a skill, not an agent). No analyzer available → report the delta as `bundle: unmeasured`, never as `acceptable`.
- **Navigation-speed / streaming / instant-loading MUSTs verified** on every new route (frontend-principles, not optional) — via the `navigation-speed` (prefetch / Speculation Rules / bfcache / View Transitions), `streaming-ssr` (stream-the-shell boundary scan), and `lcp-audit` (LCP-resource priority hints) skills; field INP via `web-vitals-field` (authoritative; lab INP is a proxy) with per-interaction budget from the `inp-responsiveness` pattern. Framework specifics come from `references/<framework>.md` + these skills — keep this stack-agnostic. A missing MUST HALTs (see Spec-conformance gate).
- **SEO + asset MUSTs verified** on every new PUBLIC route (frontend-principles, not optional) — unique metadata + self-referencing canonical + OG/Twitter + page-appropriate JSON-LD via the project's own primitive, reciprocal `hreflang` for localized routes, and SSR/SSG/prerender (never CSR-only) — via `seo-audit` + `@technical-seo`; content images via `image-optimization` (format / responsive / dimensions-CLS / lazy-below-fold); web fonts via `font-optimization` (font-display / self-host / size-adjust fallback). A missing MUST on a public route HALTs. Admin/authenticated-only routes report `seo: n/a` explicitly.
- A11y automated check passes (axe, Lighthouse a11y category ≥95).
- Locale completeness — no missing keys for declared locales.
- **Live browser verification (default for any user-visible feature):**
  1. `dev-server-start` skill — boot the running app (idempotent; reuses already-running server).
  2. `verify-with-playwright` skill — drive the new feature through the Playwright MCP server: navigate → assert visible → fill form → assert success → screenshot. Multi-locale + multi-viewport when `i18n`/breakpoints declared.
  3. Console-error pass — zero errors on load; warnings logged to report.
  - Skipping live verification is allowed only for backend-shaped changes (API contracts, types, store internals) where no rendered surface changed. Use `--no-verify-browser` to opt out explicitly with rationale.
- **Observability sign-off** (gated on what the project ships — check `.claude/codebase-profile.md` / `CLAUDE.md` for an error-tracker / analytics / RUM layer):
  - Error tracking (Sentry / Bugsnag / equivalent) captures errors from the new routes/components — error boundary or handler wired the same way siblings wire it.
  - Route-level performance signal exists if the project records one (web-vitals / RUM route timing) — new route reports like siblings do. **Nav-speed parity:** the new route prefetches its primary inbound links AND ships an instant loading state (skeleton / streamed shell) the same way its siblings do — a sibling that prefetches + has a loading boundary while the new route does neither is drift (HALT, per the Sibling-shape mechanical halt). Verify via the `navigation-speed` / `streaming-ssr` skills.
  - Product analytics events added if siblings of this surface emit them (same naming convention).
  - No console.* left as the only failure signal on any error path.
  - If the project ships NO observability layer: note `observability: none configured` in the report — explicit, never silent.
- **Release note (heavy tier only)**: one PR-description paragraph — feature flag or flagless-with-rationale, rollback path (flag off / revert), and what gets checked on staging/preview before production.

### Spec-conformance gate (spec-path only — HALT per unmet section)

When the feature was built from a spec (Phase 1 spec branch), every spec section ingested in Phase 1 gets a frontend-specialized conformance check. Walk the sections one by one; **HALT on the first unmet requirement** — do not aggregate-and-ship. Per requirement:

- **Each a11y requirement → axe + keyboard test.** The requirement is met only when an automated axe assertion AND a keyboard-reachability/focus test cover it. Missing either → HALT.
- **Each i18n requirement → both-locale check.** Every required string resolves in BOTH declared locales (en + ar) at the same key path, verified rendered. Any locale gap → HALT.
- **Each perf-budget / NFR → bundle-size / LCP check.** Measure the actual bundle-size delta against the spec's ceiling and the rendered LCP (and INP/CLS if the spec sets them) against the spec's target. Over budget → HALT. **ALSO enforce the frontend-principles navigation-speed / streaming / instant-loading MUSTs on every new route the feature adds — regardless of whether the spec names them (they are mandatory MUSTs):** primary inbound nav links prefetch the route (`navigation-speed` skill — Speculation Rules / prefetch / bfcache safety, no `unload`/`beforeunload`); SSR routes whose above-the-fold doesn't depend on a slow query stream the shell (`streaming-ssr` skill); data-dependent routes paint an instant layout-stable skeleton with no CLS (`lcp-audit` skill for LCP-resource priority hints). AUTHORITATIVE field INP via the `web-vitals-field` skill (lab/Lighthouse INP is a synthetic proxy only); per-interaction budget via the `inp-responsiveness` pattern. Missing any MUST → HALT, same as over-budget.
- **Each Authorization rule → unauthorized-access test.** For every per-role rule the spec states, there is a test asserting the surface is denied/hidden for a role that should NOT have access (not just allowed for the role that should). Missing the negative test → HALT.
- **Observability → matched signal.** Each required signal (error capture, analytics event, RUM/route timing) is wired the way siblings wire it and verified emitted. Unmatched signal → HALT.
- **Each Success metric → instrumented OR deferred.** The metric's event is wired and firing, OR it is explicitly deferred with a recorded reason. Silently-absent metric → HALT.

If a named agent, command, or skill (`@accessibility-auditor`, `@i18n-auditor`, `@security-auditor`, `/enhance-ui`, `web-vitals-field`, ...) is not installed, run the corresponding check inline against that pack's checklist and label it `graded inline (<pack> absent)` — never skip the section, never fabricate the output the missing artifact would have produced.

### Build-time traceability rebuild (spec-path only — HALT on any untested AC-ID)

Rebuild the AC→test map from the live test suite at build time — do not trust the spec's traceability table as-written; it predates the code. For every **acceptance-criterion AC-ID** in the spec:

1. Resolve it to a **named test** (file + test name) that actually asserts it.
2. **HALT if any AC-ID has no test** — an untested AC-ID is an unmet contract, not a follow-up.
3. **Emit the AC→test map in the run output** (see Output format § Traceability), so the shipped feature's coverage is auditable line-by-line.

## Phase 7 — Improve (feed the learning loop)

- If a new pattern emerged → `/learn-from-task` to promote.
- If a stale convention was caught → propose update to `ai/conventions.md`.
- If an a11y/i18n drift was found → log to `ai/dynamic/drift-log.md`.
- If the feature involved a new external dependency → it was already gated in Phase 4; promote to ADR here if it's load-bearing or touches auth/payment/crypto.
- **If the implementation diverged from the spec** (a requirement was changed, dropped, or satisfied differently than written) → close the loop three ways, do NOT invent a new file:
  1. **Annotate the spec in place** — append a `Deviation: <what changed and why>` line to the affected spec section; if the divergence was reconciled (spec updated to match reality), use `Resolved: <how>` instead.
  2. **Queue the learning** — append the divergence to `ai/dynamic/feedback-learned.md` so the next spec authored avoids the same gap.
  3. **Surface in the PR** — list each `Deviation:` / `Resolved:` in the PR description so the reviewer sees spec-vs-code drift explicitly.

## Output format

```
## /add-feature — <feature-name>

Status: SHIPPED | NEEDS REVIEW | BLOCKED
Spec:   <Spec-ID>        (always present when built from a spec — every tier, including trivial)

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

Traceability (spec-path only — every AC-ID maps to a named test):
  - <AC-ID> → <test file>::<test name>
  - <AC-ID> → <test file>::<test name>
  - untested AC-IDs: <0 expected — any non-zero = HALT>

Knowledge updates:
  - ai/modules.md      ✓
  - ADR <NNNN>         (if applicable)
  - new pattern        (if extracted)

Spec divergences (if any):
  - Deviation: <section> — <what / why>   (annotated in spec + queued to ai/dynamic/feedback-learned.md)

Open follow-ups:
  - <thing flagged for next session>
```

The trivial-tier output is the same block minus the Traceability / Knowledge / divergence sections — but the `Spec: <Spec-ID>` line is still written whenever the feature was built from a spec.

## Failure modes

- **Untyped server response leaking into UI.** Always type the boundary; align with backend DTO.
- **Hardcoded strings in templates.** Caught by `@i18n-auditor`. Pre-empt by writing keys first.
- **Hand-rolled component when system primitive exists.** Caught by `@design-system-guardian` *(ui-ux pack)*; absent that pack, caught by the sibling-shape halt's raw-primitive row in this command.
- **State scattered.** State should have ONE home per concern; if it's drifting between component / store / URL, that's an architecture flag.
- **A11y added at the end.** Should be in Phase 1 invariants; if it's a Phase 6 patch, the design wasn't a11y-aware.
- **Server vs client boundary leak.** `"use client"` files importing server-only deps. Audit imports across the boundary.

## Hard rules

- **Sibling-mirror is the default closure.** New pages copy the shape of an existing sibling in the same module. Asking the user about cosmetic / wrapper-shape / lifecycle / i18n-key choices when a sibling answers them is a token-waste anti-pattern.
- **Trivial-tier is the default tier.** ADR / heavy reviewer cascade is opt-in via heavy-tier triggers. Drafting an ADR to legitimize a new CRUD page is forbidden.
- **Default-true wrapper props are explicit.** Removing handlers without setting `:show-*="false"` / `:can-*="false"` is a default-true bug.
- **i18n keys land in BOTH locales** (typically `en.ts` + `ar.ts`) at the same path. Missing-locale = silent break.
- **Match shared wrappers, not raw components.** No raw `<Dialog>` / `<Paginator>` / `<Dropdown>` / `<form>` where `<BaseModal>` / `<CrudPaginator>` / `<BaseDropdown>` / `<BaseForm>` exist. This gate is **creation-time only** — sweeping drift that already shipped is `ui-design-sweep`'s `unify-component` verb *(ui-ux pack)* or the core `/unify-surfaces`, not this command.
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
