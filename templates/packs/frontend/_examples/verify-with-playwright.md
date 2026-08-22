---
name: verify-with-playwright
description: Live-drive the running app via the Playwright MCP server — derive the flow from the diff (happy path + one validation failure + one unauthorised case), navigate, assert visible, fill forms, screenshot, capture console errors, and switch locale through the project's own mechanism rather than a guessed query parameter. Use after a UI feature change, before declaring "done." Distinct from @playwright/test (file-based suites, see visual-check).
kind: example
pack: frontend
---

# verify-with-playwright

Live-drives the running app through the Playwright **MCP** server — navigate, wait, interact, screenshot, read the console. Ad-hoc verification of the change you just made; not a file-based `.spec.ts` suite (that is `visual-check`).

## Premise

Real artifacts only. Every "works" cites the screenshot path + the URL + the selectors waited on. A 0-step run is a failure, not a pass. Console errors on load fail the run even when the screenshot looks fine. Selectors pin to roles + accessible names — a verification that breaks on the next styling change was never verification.

Minimum for PASS: 1 navigate + 1 wait_for_selector + 1 screenshot citation.

**And the flow is read out of the diff, not remembered.** A verification composed from memory drives what you remember building — the part that already works.

## Prerequisites

- Playwright MCP server in `.mcp.json`.
- Dev server running — invoke `dev-server-start` and consume its `url`.
- **The `visual-check` harness contract**: session state at `tests/.auth/user.json`, artifacts under the gitignored `.playwright-mcp/`, `RENDER BLOCKED` as a HALT (never a SKIP). Do not introduce a second convention.

## Procedure

1. **Acquire the URL** — if none was provided, invoke `dev-server-start` and take its `url` + `pid` + `mode`. If `mode == started-fresh`, take ownership of cleanup; if `already-running`, never kill on exit.
2. **Derive the flow from the change under test.** Read `git diff` over the touched UI files and take three things: the **route(s)** the changed components map to, the **mutation surfaces** added or changed, and the **guards** touched (permission checks, `disabled` conditions, schema rules). Then emit **three** flows, not one:
   - **Happy path** — ending on a success indicator that appears only after the server round-trip, not an optimistic toast.
   - **One validation failure** — submit with the field the new schema rule governs left invalid; assert the error is rendered **and** associated (`role="alert"` / `aria-describedby`), and that no mutation fired.
   - **One unauthorised case** — `navigate` directly at the route as an excluded role. A hidden button is not the test; the leak a route guard exists to stop is the direct URL.

   A change with genuinely no validation surface or no guard prints that lane as `n/a` with the reason — a dropped lane and an absent lane look identical in a report, and only one is honest. Then compose the MCP calls, pinned to user-visible behavior: navigate, `wait_for_selector` on the primary heading, screenshot the baseline frame, interact, `wait_for_selector` on the success indicator, screenshot, `console_messages()`. Selectors use roles + accessible names (`role=button[name=Save]`), not CSS classes.
3. **Execute + collect** — halt on the first failure. On a `wait_for_selector` timeout capture the current screenshot, the console messages, and the page's full HTML.
4. **Multi-locale / multi-viewport pass** — for projects with `i18n` declared, repeat the flow at each locale, **detecting the project's locale mechanism first**: path prefix (`[locale]` segment / `locales` config → `navigate(url + '/ar' + path)`); cookie or header (locale cookie in the i18n config or middleware → set the cookie, then navigate); in-app store with an unchanged URL (a `locale` ref/atom or a visible switcher → **drive the switcher**, which keeps the session); per-locale build (separate outputs → a server per locale, or report `locale pass: n/a`). **Never `eval_js("location.assign('/?lang=ar')")`** — it assumes a `?lang=` convention three of the four mechanisms do not have, and the hard reload discards an in-memory session, so the run logs itself out and screenshots the login page in Arabic. For projects with declared breakpoints, repeat at mobile / tablet / desktop widths via `set_viewport_size`.
5. **Cleanup** — if Step 1 returned `started-fresh`, kill the dev server and remove `.claude/dev-server.pid`; if `already-running`, leave it alone.

## Output format

```
verify-with-playwright — <feature/route>
  url:      http://localhost:5173/dashboard/brands
  flows:    3 (happy path + validation failure + unauthorised direct-URL)
  derived:  from diff a1b2c3d..HEAD -> src/pages/brands/* -> /dashboard/brands
  locale:   path-prefix detected (next-intl) -> navigated /ar/dashboard/brands
  steps: 22   failures: 0
  screenshots: .playwright-mcp/<ts>/brands-list-loaded.png ...
  console:  0 errors, 1 warning
  outcome:  PASS
```

## Failure modes

- **Selector not found** — common: framework still hydrating, or the selector points at a name that changed. Capture screenshot + HTML snapshot and surface it for a re-author of the selector. Don't loop forever.
- **Console error on load** — fail loudly. UI may render but throw; that is a regression even if the screenshot looks fine. Print the error stack in the report.
- **Auth required, no credentials** — surface the missing-credentials condition; halt. Never log or commit a fake credential.
- **Network request failure** (XHR 4xx/5xx) — log under `network_errors`. Don't auto-retry; that masks real backend issues.
- **Headless vs headed mismatch** — default to headless; if a step fails, surface the suggestion to re-run headed for human inspection.
- **Locale switch logged the run out** — a hard reload discarded an in-memory session and the "Arabic" screenshot is the login page. Detect the mechanism; if a reload is unavoidable, re-assert the surface marker after it.
- **Happy path only** — the run passes and keeps passing through every future regression in validation and authorisation, because it never drove either.

## Hard rules

- **Cite the URL + path in the output.** A reader must be able to navigate to the same page in their own browser.
- **Screenshots are ephemeral by default** — write to the gitignored `.playwright-mcp/<timestamp>/` per the `visual-check` contract. Promoting a frame to a baseline is a `visual-check` decision, not this skill's.
- **Never commit** `.claude/dev-server.{pid,log}` or screenshot dumps. They're per-developer.
- **Pinned selectors prefer roles + names** over CSS classes — the single thing that determines whether the verification survives a styling refactor.
- **Don't fake success.** A 0-step run is a fail, not a pass. Minimum 1 navigate + 1 wait_for_selector + 1 screenshot.

## Halt conditions

- No screenshot artifact → unverified.
- Console errors on load with a PASS verdict → contradiction; fail the run.
- Selectors targeting CSS classes instead of roles + names.
- Fewer than the three flow lanes, with the missing ones not printed as `n/a` and a reason.
- A flow composed without reading the diff — it drives the path that already works, not the change under test.
- A locale switch through a mechanism the project does not have (a `?lang=` parameter on a path-prefix app, a hard reload on an in-memory session). An untranslated or logged-out screenshot is a failed switch, not a locale result.
- Playwright MCP not configured → halt. If another instrumented browser MCP is configured, name it as the alternative the user may wire, then stop — choosing the harness is the user's call.
