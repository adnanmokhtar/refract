# Precedents — UI (accessibility, UI states, rendering, client data, routing, i18n, design system, motion, charts)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 and § 10 for
every candidate in a **UI** class: a WCAG 2.2 AA failure found in source or in a render, a UI state
that is missing or wrong (loading, empty, error, partial, forbidden, offline, stale, pending), a
render or hydration defect, a client data-flow or routing defect, locale presentation, design-token
or motion drift, chart encoding, or a render measurement. The oracles that
prove them are in [`proof-oracles.md`](../proof-oracles.md) § Accessibility and UI states. The three
cross-domain precedents are in `refute-before-report.md § 4`.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening**; the flip evidence makes it a candidate again.
A precedent applies only when its "must be true" clause is shown with a `file:line` or a recorded
render. Numbers are stable: detectors cite `precedents/ui.md § <n>`.

Index: posting rules § 1–10 · accessibility § 11–34 · UI states and client data § 35–41 · rendering,
hydration and i18n presentation § 42–48 · version precedents § 49–57 · a clean automated run § 58 ·
UI states (`ui-state-scan`) § 59–63 · client data (`client-data-scan`) § 64–69 · routing
(`routing-scan`) § 70–75 · i18n (`i18n-scan`) § 76–83 · design tokens, motion and charts § 84–97 ·
render measurement § 98–101. SEO has its own file, [`seo.md`](seo.md); native mobile UI is
[`mobile.md`](mobile.md).

## The claim, restated

§ 1 of the protocol takes one of three shapes here. A candidate that fits none is not a finding.

- **Accessibility:** "On **[route + state — the dialog open, the dark theme, 320 px, the RTL
  locale]**, a user of **[keyboard / screen reader / zoom / voice control]** meets **[the control
  rendered from file:line]**, which fails **WCAG 2.2 SC [n.n.n] ([level])** because **[the
  observable: no accessible name, Tab never reaches it, focus lands behind the header]**, proven by
  **[the axe rule id at that route-state / the recorded keyboard path / the role query that fails]**."
- **UI state:** "When **[the request for the surface at file:line]** answers **[pending, `[]`,
  500, a network error, 403, 404, a partial body, offline, a failed refetch]**, the surface renders
  **[blank / a crash / the wrong state / an endless spinner]** instead of **[the state the matrix or
  the sibling surface renders]**, proven by **[the state-matrix test]**."
- **Rendering / data:** "When **[the interaction or navigation]** happens, **[the code at
  file:line]** produces **[a hydration error, a leaked listener, state on the wrong row, the
  previous request's data]**, proven by **[the console, balance, identity or request-order test]**."

**The proof rule.** A static hit (a lint rule id, a grep) is a candidate. A **static-fact** class
whose failure is fully visible in source — `user-scalable=no`, a positive `tabindex`, `<img>` with no
`alt` on a rendered path, paste blocked on a credential field — passes gate 6 with the two-ended
trace (the source line and the route that renders it). Every other class needs its oracle to fire:
an axe rule at the route-state, a keyboard path, a role or label query, a geometry probe, a
state-matrix test. Without a harness the candidate is **Unconfirmed** with the settling test
written out, never dropped and never promoted on reading alone.

## Reading the seven gates for UI

| Gate | Accessibility | UI state, rendering, data |
|---|---|---|
| 1 Reachability | The component renders on a real route, in a state a user reaches; a Storybook-only, dead or design-system-internal file is not reached until a route imports it | A route or screen mounts the surface; the request or interaction occurs in real use |
| 2 Trigger condition | A real user meets it: keyboard only, a screen reader, zoom 200 % or 320 px, forced colours, the dark theme | The response really occurs: the API can answer `[]`, 4xx, 5xx, slowly, or not at all; the list really reorders |
| 3 Version | The framework, router, component-library and lint-plugin versions read from the lockfile (§ 49–57) | React / Vue / Svelte / Angular, router, data library and their defaults, from the lockfile |
| 4 No existing control | The design-system primitive or headless library already provides the role, name, focus or keyboard model (§ 12–14); a wrapper wires the label or error | A boundary, a global error handler, a query-client default, a shared state component already renders it |
| 5 Real impact | A **measured** WCAG 2.2 A/AA failure; AAA and house rules are Hardening unless the project declares them | A user sees nothing, the wrong thing, or loses input or data |
| 6 Proof | axe output at the route-state, a recorded keyboard path, a failing role or label query, a geometry or focus-delta probe | The failing-first oracle from `proof-oracles.md § Accessibility and UI states` |
| 7 Deployment and environment | The platforms and viewports the product ships to (a desktop-only internal tool still has keyboard and zoom users) | SSR vs CSR as deployed; the browsers the product supports |

## Do not flag — posting rules the verifier applies

1. **Pre-existing lines.** On a diff run, a defect on lines the change neither touched nor copied is Pre-existing (`refute-before-report.md § 5`).
2. **What a configured a11y linter already fails in CI at error level.** The tool owns it; the finding, if any, is that the rule is off, at warn, suppressed, or not run in CI.
3. **Rule-of-thumb advice with no failing SC**: "prefer `<output>` to `role="status"`", "use semantic HTML" where the semantics are already right. `jsx-a11y/prefer-tag-over-role` is advice: on a real React 19 app on 2026-10-05 it was 77 of 182 strict-preset messages, every one a `role="status"` / `role="group"` / `role="img"` suggestion.
4. **AAA criteria and house targets reported as AA failures.** 2.4.13 Focus Appearance, 2.3.3 Animation from Interactions, 2.5.5 Target Size (Enhanced, 44×44) are AAA. A house rule (44 px targets) is reported as the house rule it is, citing where the project declares it.
5. **Alt-text quality, heading wording, link wording** are judgement rows for the human pass, not detector findings.
6. **Speculation about assistive-technology behaviour** with no recorded output ("NVDA probably reads this twice").
7. **Security classes** — XSS through `dangerouslySetInnerHTML` / `v-html`, token storage, client-only authorization — go to the security pack when installed; framework auto-escaping is never a UI finding.
8. **Performance classes** (re-render cost, bundle bytes, LCP) go to the performance pack when installed; without it they are reported here, tagged `performance-class (owner pack not installed)`.
9. **Duplicates.** One finding per root cause: a defect in a shared wrapper is one finding with N call sites, fixed at the wrapper.
10. **Generated, vendored and story-only code**, and test fixtures.

## Not a finding — accessibility

11. **`alt=""` on a decorative image** is correct and required; so is `aria-hidden="true"` (or `role="presentation"`) on an icon beside visible text. *Flips back:* the image is the only content of a link or button, or it carries information the text does not.
12. **Headless libraries own the role, state and keyboard model** — Radix, React Aria, Headless UI, Ark, Bits UI, Reka / Radix-Vue, Melt, Angular CDK and Material. A consumer file with no `aria-*` and no `onKeyDown` is not a finding; the runtime arbiter is axe plus the keyboard path at the route. *Flips back:* the consumer overrides the primitive (`asChild` onto a `div`, a custom `onKeyDown` that swallows keys) or renders the trigger as a non-focusable element.
13. **Native elements need no ARIA.** `<dialog>` opened with `showModal()` is modal, inert behind and closes on Escape; `<details>/<summary>` exposes expanded state; `<select>`, `<input type="checkbox">` and `<input type="range">` carry their own role, state and keyboard. *Flips back:* `<dialog>` opened with `show()` (non-modal) used as a modal, or focus not returned to the trigger on close.
14. **A shared field wrapper that wires the label and error** — a `Field` / `FormField` / `mat-form-field` whose source sets `id`, `htmlFor`, `aria-invalid` and `aria-describedby` from context — closes the label and error-association classes for every consumer that renders through it. Cite the wrapper's line. *Flips back:* the consumer renders its own error text beside the wrapper.
15. **Modal focus containment is required behaviour**, not a 2.1.2 trap, when Escape or a close control works.
16. **Backdrop click-to-close is a mouse convenience** when the dialog also closes on Escape and has a named close button. A wrapper whose only handler is `e.stopPropagation()` is not a control. A `div` whose click forwards focus to the input inside it (a tag input, a search box) is not a control either: the input is the keyboard path.
17. **A clickable card or row that also contains a real link or button** for the same action is an enhancement; the fix, when one is wanted, is a stretched link, never `role="button"` on the card.
18. **`outline: none` / `outline-none` with a visible replacement** on the same element (`:focus-visible` rule, `focus-visible:ring-*`, a `box-shadow` or border change), or under `:focus:not(:focus-visible)`, passes 2.4.7. A box-shadow-only ring vanishes in forced-colours mode: report that as Low, not as a 2.4.7 failure.
19. **Contrast exemptions** (1.4.3, 1.4.11): disabled or inactive controls, pure decoration, logotypes and brand names, incidental text in images. Placeholder text is **not** exempt.
20. **Target-size exceptions** (2.5.8): inline links in a sentence, user-agent default controls not restyled, an equivalent control of 24×24 elsewhere on the page, essential presentation (map pins), and the 24 px spacing circle. axe's `target-size` already excludes inline links.
21. **2-D scrolling at 320 px** is allowed for content that needs two dimensions — data tables, maps, diagrams, code blocks, toolbars — inside their own scroll container (1.4.10).
22. **`tabindex="-1"`** on programmatic focus targets (the heading after a route change, a dialog container, a skip-link target) and **`tabindex="0"`** on a custom widget that has a role are correct. Only a positive `tabindex` is the 2.4.3 class.
23. **`autoFocus` on the first field of a dialog** or on a dedicated search page is acceptable; `no-autofocus` hits there are noise (27 of 182 strict-preset messages on the measured React app).
24. **`aria-label` on a landmark** (`nav`, `section`, `aside`, `form`, `region`) is correct. On a generic `div` / `span` trust axe's `aria-prohibited-attr` verdict over the grep: axe 4.13 relaxed which elements may be named.
25. **`role="alert"` inserted together with its text** is announced on insertion in practice; a conditional `role="status"` / `aria-live="polite"` region mounted with its content is the 4.1.3 candidate. Report the alert shape Low at most.
26. **Toast libraries that mount a persistent live region** — sonner, react-hot-toast, react-toastify, vue-sonner, vue-toastification, ngx-toastr, svelte-french-toast, Radix Toast — own 4.1.3 for messages sent through them.
27. **Route-change announcement is built in** on the Next.js App Router (the announcer reads `document.title`, then the `<h1>`, then the pathname; Next.js docs, *Accessibility*, fetched 2026-10-05) and SvelteKit (a live region reads the new `<title>`; focus moves to `<body>` after each navigation; SvelteKit docs, *Accessibility*, fetched 2026-10-05). Do not report 2.4.3 / 4.1.3 route-change rows there unless titles are missing or identical across routes. **Nuxt** ships `<NuxtRouteAnnouncer>` from 3.12, but it is optional: it must be placed in `app.vue` or a layout (Nuxt docs, fetched 2026-10-05). **React Router** states it makes no assumption and leaves focus management and live announcements to the app (React Router docs, *Accessibility*, fetched 2026-10-05). Vue Router and the Angular Router: treat as no announcer unless the repo adds one.
28. **A visual reorder used for RTL mirroring** (`flex-row-reverse` under `[dir=rtl]` / `rtl:`), or on content with no focusables, is not a 2.4.3 focus-order defect.
29. **Native constraint validation** (`required`, `type="email"` with the browser bubble) satisfies 3.3.1 in current user agents; an error summary with links to the fields is a valid association pattern.
30. **Autocomplete scope** (1.3.5): the purpose tokens are required only on fields that collect information **about the user**. A gift recipient, a search box, an admin form editing someone else's record, and an OTP field with `autocomplete="one-time-code"` are not candidates.
31. **Accessible-authentication exceptions** (3.3.8 AA): object-recognition and personal-content CAPTCHAs, passkeys / WebAuthn, magic links and non-interactive challenges pass at AA. Password confirmation on a new-password form is excepted from 3.3.7.
32. **Muted autoplay of five seconds or less**, or a video with `controls`, does not fail 1.4.2 / 2.2.2.
33. **A hover handler that only prefetches or highlights** (`onMouseEnter` warming a route, setting the active row in a listbox that also follows the keyboard) shows no content, so 1.4.13 does not apply.
34. **Event delegation**: a click listener on a container whose children are real buttons or links is keyboard-operable through the children.

## Not a finding — UI states and client data

35. **Suspense-mode data hooks** (`useSuspenseQuery`, Apollo `useSuspenseQuery`, `throwOnError`) render loading and error through a Suspense boundary and an error boundary. *Must be true:* both boundaries wrap the route; without the error boundary it is the missing-boundary class, not this one.
36. **A pure presenter** fed by a parent that branches on status, or a data hook defined in one file and consumed elsewhere: follow the import to the consumer before calling a state missing.
37. **Optimistic updates that revert by construction** — TanStack "optimistic via UI" (`variables` while `isPending`), React `useOptimistic`, Apollo `optimisticResponse`, SWR `optimisticData` with the default `rollbackOnError` — are not missing-rollback findings. Only a cache write with no restore is.
38. **TanStack Query defaults are a design choice**: identical keys in flight are deduplicated; queries retry 3 times and mutations 0. *Flips back:* a 403 or 404 retried with backoff behind a spinner, so the forbidden state appears only after every retry's backoff — that is the permission-state class.
39. **Idempotent submits** (PUT of the same body, a toggle that sets an absolute value), GET search forms, and forms with a server-side idempotency key **and** a visible pending state are not double-submit findings.
40. **Undo instead of confirm.** A soft delete with an undo toast satisfies the destructive-action class; removing an unsaved local row or a filter chip is not destructive. Autosaved and draft-persisted forms need no unsaved-changes guard.
41. **SPAs served with a history fallback answer 200 for unknown paths**: assert the not-found content, not the HTTP status.

## Not a finding — rendering, hydration and i18n presentation

42. **`key={index}` on a static list** that is never added to, removed from, sorted or filtered, and holds no inputs or focus, is fine. An Angular `@for` with `track item.id` is the correct shape.
43. **A `Date` or `Math.random()` in an effect or an event handler** is not a hydration source; only render-time reads are.
44. **`suppressHydrationWarning` on a timestamp leaf** is a deliberate, scoped opt-out (React's suppression is one level deep). *Flips back:* it sits on an element with element children.
45. **A hydration error that disappears in a clean browser profile** came from an extension or third-party DOM, not the app.
46. **Framework-managed cleanup** — VueUse `useEventListener` / `useIntervalFn`, template listeners (`@click`, `(click)`, `onclick`), Angular `async` pipe, `takeUntilDestroyed`, `toSignal`, `@HostListener` — is not a leaked-listener finding.
47. **Clipping that appears only under the pseudo-locale on a fixed-width brand mark**, logo or code-like value is not an expansion finding.
48. **Physical CSS inside a `[dir]`-scoped override** (`[dir=rtl] .x { margin-left }`, Tailwind `rtl:` / `ltr:` variants) is the mirroring, not the RTL defect. Phone numbers, code editors and numerals that must stay LTR are exempt.

## Version precedents — read the installed version before reporting

49. **axe-core 4.13.0 ships `target-size` disabled.** It runs only under a tag list containing `wcag22aa` (`withTags([... 'wcag22aa'])`) or an explicit rule enable; a plain `analyze()` never runs it. "axe clean" without that tag says nothing about 2.5.8. Experimental rules (`css-orientation-lock`) need the `experimental` tag (axe 4.13.0 source, 2026-10-05).
50. **`@axe-core/playwright` 4.13.0:** `.options()` replaces the whole option object (including `runOnly`), `.withTags()` and `.withRules()` overwrite each other, and `.disableRules()` wipes rules enabled earlier through `.options()` — a second `.disableRules()` drops the first. A gate that chains them in the wrong order is neutered, not clean.
51. **Lighthouse 13.5.0 is not axe.** Its accessibility category disables `nested-interactive`, `scrollable-region-focusable`, `role-img-alt`, `aria-tab-name` and others, and does not score `incomplete`. A Lighthouse score of 100 is not a conformance claim and not "axe clean". `@lhci/cli` 0.15.1 still bundles Lighthouse 12.6.1.
52. **Lint presets omit rules.** eslint-plugin-jsx-a11y 6.10.2 `recommended` turns `control-has-associated-label` off and omits `no-aria-hidden-on-focusable`; it sees through design-system components only when `settings['jsx-a11y'].components` maps them. eslint-plugin-vuejs-accessibility 2.6.0 `recommended` omits `no-aria-hidden-on-focusable` and `no-role-presentation-on-focusable`. The angular-eslint 22.5.0 `templateAccessibility` preset (11 rules) does not include `no-positive-tabindex`. "The plugin is installed" is not gate 4 for those classes.
53. **eslint-plugin-jsx-a11y 6.10.2 peers on ESLint ≤ 9** (`peerDependencies.eslint` ends at `^9`; last published 2024-10-26) while ESLint 10.12.0 is current (npm, 2026-10-05). On an ESLint-10 project the React lane runs in a scratch ESLint 9 install; a project config that silently drops the plugin is gate-4 evidence of nothing.
54. **Svelte 5 warning codes use underscores** (`a11y_click_events_have_key_events`); a Svelte 4 `<!-- svelte-ignore a11y-… -->` comment with hyphens suppresses nothing in Svelte 5. eslint-plugin-svelte 3.23.0 has no a11y rules of its own: the compiler is the lint lane.
55. **Tailwind v4 changed `outline-none`.** It now sets `outline-style: none`; the v3 behaviour (an invisible outline that still shows in forced-colours mode) is renamed `outline-hidden` (Tailwind docs, *Upgrade guide*, fetched 2026-10-05). On v3, `outline-none` without a ring is still a 2.4.7 candidate; on v4 it is the same, and `outline-hidden` is the forced-colours-safe reset.
56. **Playwright 1.63 removed `page.accessibility`.** Oracles use `ariaSnapshot()` / `toMatchAriaSnapshot`, `toHaveAccessibleName`, `toHaveAccessibleDescription`, `toHaveAccessibleErrorMessage` and `page.emulateMedia({ reducedMotion, forcedColors, contrast, colorScheme })`. A test still calling `page.accessibility.snapshot()` does not run.
57. **iOS Safari ignores `user-scalable=no` since iOS 10**; Android browsers and desktop PWAs honour it. The finding stands.

## What a clean automated run means

58. **Automation finds part of the problem, by any measure.** Deque's 2021 study (>2,000 audits, ~300,000 issues) found 57 % of issues **by volume** with axe-based automation, a share dominated by colour contrast; the UK GDS 2017 test of 143 barriers found the best single tool caught 41 % and all ten tools together 71 %. These measure different things — issue volume and barrier coverage — and neither is the share of success criteria. A clean detector run and a clean axe run are a floor: no report says "accessible", "WCAG compliant" or "a11y ✓" without the manual pass (keyboard walk, screen reader, zoom, content judgement) recorded beside it.

## Not a finding — UI states (`ui-state-scan`)

59. **A gate hook** (permissions, feature flags, the current principal) that defaults safely while it loads renders no data view, so it needs no loading state of its own. *Flips back:* the default while loading lets the guarded view render.
60. **`catch → null` followed by a branch that tells the user** (a toast, a fallback label) is a handled error, not the error-rendered-as-empty class.
61. **An inline refetch indicator beside the data** (`isFetching ? <Spinner/> : null`) is the correct stale-data shape; only a refetch that blanks the data is the class.
62. **Live validation** of password strength, availability or a character counter is intended, not the validation-while-typing class.
63. **Router loaders discard stale navigations by themselves** — React Router, SvelteKit and Next server-component loaders drop the superseded navigation — so an out-of-order or navigation-race row does not apply to data they load.

## Not a finding — client data (`client-data-scan`)

64. **Keyed caches are race-safe.** TanStack Query and SWR discard a stale response by key; Nuxt `useFetch` with a reactive key refetches per key; identical keys in flight are deduplicated (§ 38). The out-of-order class does not apply to them.
65. **A key factory that takes the whole params object**, or a key built from the same input the fetch derives its arguments from (a day count → from / to dates), carries every input even when `exhaustive-deps` flags it — 5 of 6 measured lint hits on a real React app. *Flips back:* the fetch reads a value the key does not contain (the tenant, the user, a filter).
66. **A dependent second read is not a waterfall**, and **a chunked fan-out** (pages of ids at the API's max page size) is the client twin of a chunked `IN (…)`: Hardening, not the N-requests class.
67. **Writes that change no cached view** — sign-in, OTP, password reset, an export job, a message send — need no invalidation.
68. **A sign-out that calls `queryClient.clear()`** refutes the sign-out half of the identity class, never a key that misses an input.
69. **Polling that pauses in the background by default** is correct: TanStack `refetchIntervalInBackground` defaults to `false` (query-core 5.104.1 types, 2026-10-05). A poll that stops itself when the job completes is correct too.

## Not a finding — routing (`routing-scan`)

70. **Click navigation that is not a link's job:** a button that does work and then navigates; `navigate(-1)` / `router.back()`; drag, select and map-marker interactions. A row or card that also holds a real link is § 17.
71. **View state that should stay out of the URL:** dialog, picker and combobox search; wizard steps not meant to be deep-linked; filters that carry personal data (privacy wins over shareability); state already mirrored through `nuqs`, `useSearchParams` or `router.replace({ query })`.
72. **A param already validated:** parsed by a schema (`safeParse`, `validateSearch`, nuqs parsers) or checked before use; a param that only selects a tab and has a default.
73. **Built-in not-found handling:** Next, Nuxt and SvelteKit answer unmatched paths with their own 404; a React Router data router whose root `errorElement` renders the 404 response; SvelteKit's plain `<a>` is client-routed (not the click-navigation class).
74. **A guard that renders a fallback until the session is known** and redirects before rendering the protected outlet passes the protected-flash class (measured on a real app: refuted on reading the guard); so do server-side redirects in middleware, loaders, `hooks.server.ts` or `canActivate`.
75. **Navigation races already closed:** router loaders (§ 63), keyed queries (§ 64), and an RxJS `switchMap` that cancels the previous inner request.

## Not a finding — i18n (`i18n-scan`)

76. **A single-locale product with no i18n library:** every i18n row is `N/A`, unless the brief names a second market.
77. **Not copy:** text in `<code>`, `<pre>`, `<kbd>` and the project's code or LTR wrappers; `<Trans>`-family children; Angular `i18n`-marked elements; `alt=""` on a decorative image (§ 11); brand, product and standard names on a documented allow-list; units and symbols; data (user content, API values, SKUs); example-format placeholders (`john@example.com`, `https://…`, `01xxxxxxxxx`); developer text (`console.*`, logger calls, a `throw new Error` that never renders); routes the product declares single-language.
78. **Machine formats:** `toISOString()`, `YYYY-MM-DD` built for an input or an API, `toFixed` on a non-money value, sorting ids, enum codes or ISO dates, `toLowerCase()` on ASCII protocol tokens.
79. **A project wrapper owns the locale:** a `formatDate()`, `formatMoney()` or `Trans` wrapper that injects the active locale makes its call sites clean. Read the wrapper once and cite its line.
80. **RTL exemptions** beyond § 48: symmetric pairs; content that must stay LTR (code, phone numbers, charts, maps, media timelines); vertical properties; React Native `marginLeft` under the default auto-swap; icons that must not mirror (play, clock, check, a two-way swap).
81. **A server that localizes its messages by `Accept-Language`**, with the client sending the header: the raw-server-text row is Hardening.
82. **SwiftUI `Text("literal")` is a `LocalizedStringKey`;** only `Text(verbatim:)` and `Text(stringVariable)` are hard-coded.
83. **Charts that stay LTR in an RTL locale** (time axes, numeric scales) are an intended exception, not an RTL defect.

## Not a finding — design system, motion and charts

Design tokens (`design-token-audit`):

84. **Definitions, not uses:** token files, `@theme` / `@theme inline`, DTCG JSON, a Tailwind config, and the design system's own primitives that define the scale.
85. **Contexts that must carry literals:** SVG illustrations and brand logos, email templates (inline styles are required), print / receipt / label templates written into another document, web-manifest `theme_color`, third-party widget overrides.
86. **Data, not design:** a user- or merchant-chosen colour stored with its default, a colour picker's swatch list or a legend's swatch list, an order or ticket number such as `#1234`.
87. **A token through arbitrary syntax:** `bg-[var(--brand)]`, Tailwind v4 `bg-(--brand)`, `style={{ '--progress': x }}`.
88. **Layout and dynamic geometry:** `w-[calc(100%-2rem)]`, `grid-cols-[1fr_auto]`, `max-h-[88vh]`, `width: ${pct}%`, a virtualised row's `top`.
89. **Native elements inside the design system, Radix `asChild` / `Slot`, and headless-library hosts** are not re-implemented components (§ 12).
90. **The reduced-motion reset and `.sr-only`** are the documented `!important` exceptions.

Motion (`motion-audit`):

91. **The reduced-motion reset itself** (`animation-duration: 0.01ms !important` under `prefers-reduced-motion: reduce`) and its essential-spinner exception.
92. **The autofill-background workaround** (`transition: background-color 5000s`) is not motion.
93. **A toast's `duration`** (sonner, react-hot-toast) is display time, not an animation.
94. **Essential motion** — a progress spinner inside a loading branch — is not content that moves on its own; it still respects reduce where the reset reaches it.
95. **Height animations a design-system accordion owns** (Radix's measured content-height variable) are one review row at the primitive, not one per consumer.

Charts (`chart-encoding-audit`):

96. **A zoomed line axis that prints its range** is the rule, not a baseline breach: the zero baseline binds length marks (bars, columns, areas).
97. **A real zero plotted as zero is correct** (a store open with no sales); only a *missing* reading drawn as zero is the class. An emptiness check (`(d.value ?? 0) > 0` deciding whether to render) is not a plotted value. Read the source.

## Not a finding — render measurement (`ui-design-sweep`, `measure.ts`)

98. **A container whose computed fill equals its nearest painted ancestor's is a layout box, not a surface**, and is never a floating-surface finding. The pair is measured against the nearest painted ancestor, never the page (measured: comparing every container against `body` reported 28 false floating surfaces on seven screens), and a box that fills the viewport (≥ 95 % of the width, ≥ 90 % of the height) is the page itself.
99. **A height difference across control classes is not a finding.** A switch, a checkbox or an icon-only button beside a text input keeps its intrinsic size; across classes only the vertical centres are compared. A declared size variant (a large primary CTA beside small actions) is a decision, not drift.
100. **Not a control row:** controls in different landmark regions (a sidebar entry beside a content tab — measured as a false pair on a real app), buttons and badges inside a table row (`td` / `th`, graded as table density), a brand mark rendered as a button, and a composite control's inner field (a tag input, combobox or date picker is measured at its wrapper).
101. **A difference under 2 px** is sub-pixel rounding or a 1 px border at some zoom levels, not a size or centre finding.

## Rationalizations to reject (UI)

**Wrongly accepting:** "axe flagged it" (at which route-state, and is it `incomplete`?) · "a linter
flagged it" (prefer-tag-over-role, no-autofocus) · "it has no ARIA" (native elements need none) ·
"screen readers can't read this" with no recorded output · "44 px is the WCAG minimum" (that is
AAA 2.5.5; AA is 24 px) · "it could be empty" (does the API ever answer `[]` for this view?) ·
"best practice says to add `aria-label`" (to a control that already has visible text).

**Wrongly dismissing:** "the design system handles it" (show the primitive's line and the render) ·
"axe is clean" (axe has no rule for keyboard operability, focus order, live regions or state
changes) · "Lighthouse is 100" · "nobody uses a keyboard on this admin page" · "it works with a
mouse" · "the API never fails" · "it's a spinner, that's a loading state" (does it end on error?) ·
"the error is shown in red" (colour alone, and is it announced?) · "it's only on mobile" (that is a
real viewport).

---

Sources (accessed 2026-10-05): the frontend research notes for this batch — accessibility
(axe-core 4.13.0 and `@axe-core/playwright` 4.13.0 source; eslint-plugin-jsx-a11y 6.10.2,
eslint-plugin-vuejs-accessibility 2.6.0, angular-eslint 22.5.0, svelte 5.57.1 rule lists; Lighthouse
13.5.0 accessibility gatherer; Playwright 1.63.0 types; Deque, *Automated testing study identifies
57 percent of digital accessibility issues* (2021-03-10); GDS accessibility blog (2017-02-24)) and
UX states (TanStack Query 5.104, SWR 2.5, Apollo Client 4.3, MSW 3.0.2) — plus the Next.js,
SvelteKit, Nuxt and React Router accessibility pages and the Tailwind CSS upgrade guide, each
fetched 2026-10-05, and an npm registry read of eslint-plugin-jsx-a11y's peer range and ESLint's
current version. The prefer-tag-over-role and no-autofocus counts were measured on a read-only real
React 19 + Vite application. Paraphrased; no text reproduced beyond short quoted identifiers.

§ 59–101 were moved on 2026-10-10 from the False positives sections of `ui-state-scan`,
`client-data-scan`, `routing-scan`, `i18n-scan`, `design-token-audit`, `motion-audit` and
`chart-encoding-audit` (written 2026-10-05 from the same research notes; the TanStack default read from
query-core 5.104.1 types; the lint and guard measurements from a read-only real React application) and
from `ui-design-sweep/references/measured-from-the-render.md` (§ 98–101, each exclusion measured after
a false positive on a real app).
