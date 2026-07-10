---
name: visual-check
description: Playwright-based UI verification — captures screenshots across locales, themes, and viewports. Run after a visible change; compares against a baseline.
---

# visual-check

## Premise

Real artifacts only. Every claim cites the baseline file path + the actual file path + the diff file path produced. "Looks the same" without a diff image is not verification. A run that updates baselines without explicit user confirmation is forbidden — `--update-snapshots` is a deliberate decision, not a workaround for a failing run.

Refuse to declare PASS unless every combo in the matrix produced a row with either "no diff" or a diff image path.

For frontend changes. Verifies the UI renders correctly across locales, themes, and viewport sizes before shipping.

## When to use

- After any change that touches a `.vue` / `.tsx` / `.svelte` template, CSS, or design tokens.
- After an i18n string update that may shift layout (Arabic / German / Japanese often do).
- After a Tailwind config change.
- Before a release candidate goes to QA.

## Prerequisites

- Dev server running locally (or a built static preview).
- Playwright installed: `pnpm add -D @playwright/test && npx playwright install`.
- Baseline screenshots at `test/visual/baseline/` (generated on the first green run; commit them).
- A `test/visual/visual.spec.ts` that drives `page.goto` + `expect(page).toHaveScreenshot()`.
- **An authenticated session when the target surface is auth-gated** (see below). A headless/isolated browser has NO cookies or tokens, so any route behind an auth guard redirects to `/login` and you screenshot the login page, not the surface.

## Authenticated rendering (non-negotiable for auth-gated surfaces)

Most real app surfaces (dashboards, settings, anything behind `meta: { requiresAuth }` / a route guard / a `<PrivateRoute>`) are **unreachable without a session**. Rendering them requires establishing auth FIRST — otherwise the guard bounces the render to `/login` and every screenshot is worthless.

1. **Detect the gate.** Before rendering `$TARGET`'s route, check whether it is auth-gated (router `meta.requiresAuth`, a guard import, a redirect-to-login). If it is, you MUST authenticate before `page.goto` to the surface.
2. **Establish a session** by the cheapest available means, in order:
   - Reuse a saved **`storageState`** (`test/visual/.auth/state.json`) if present and still valid.
   - Otherwise perform a **login step once** and persist it: `page.goto('/login')` → fill the dev/test credentials (from an env var / `.env.test`, never hardcoded) → submit → `page.context().storageState({ path: 'test/visual/.auth/state.json' })`. Reuse it for every subsequent shot.
   - If the project already has a Playwright auth fixture / `globalSetup`, use that.
3. **Point the MCP/browser at the session.** For the Playwright MCP, this means it must NOT run `--isolated` with no session for gated routes — load the `storageState`, or drive the login step in-session. `--headless --isolated` with no auth ALWAYS lands on `/login`.
4. **Prove you landed on the surface, not the wall** (see the blocked-render halt): after `goto`, assert a surface-unique marker is present (a heading/testid that only the target renders) before you screenshot.

### Setting this up on a new / auth-gated project (where the creds come from)

Creds are a **secret** — `/setup-project` can never bake or guess them. So the work splits: **the machine scaffolds the whole mechanism; the human supplies ONE secret, once.**

- **Machine scaffolds** — when the app is detected auth-gated (a router guard, `requiresAuth` meta, a `/login` redirect, `<PrivateRoute>`, an auth interceptor): drop `tests/auth.setup.ts` (below), gitignore `tests/.auth/`, add the `.env` slot, and surface the 3-step turn-on in the setup report.
- **Human supplies** (once) — dev/test creds in the **gitignored `.env`**: `E2E_EMAIL` / `E2E_PASSWORD` (or the project's field names). Never committed, never in a command, never pasted in chat.

Scaffold — deploy as `tests/auth.setup.ts`, parameterizing the login route + the 3 selectors to the detected form:

```ts
import { test as setup, expect } from "@playwright/test";
import fs from "node:fs";
const authFile = "tests/.auth/user.json";
setup("authenticate", async ({ page }) => {
  const email = process.env.E2E_EMAIL, password = process.env.E2E_PASSWORD;
  if (!email || !password) throw new Error("Set E2E_EMAIL/E2E_PASSWORD in .env first.");
  await page.goto("/login");                          // ← detected login route
  await page.fill("#email", email);                   // ← detected email selector
  await page.fill("input[type=password]", password);  // ← detected password selector
  await page.click('button[type="submit"]');          // ← detected submit selector
  await page.waitForURL((u) => !u.pathname.includes("/login"), { timeout: 30_000 });
  // token-in-localStorage apps: prove a token landed; cookie apps: assert a session cookie
  const ok = await page.evaluate(() => Object.keys(localStorage).some((k) => /token/i.test(k)));
  expect(ok, "no auth token after login — check creds/selectors").toBeTruthy();
  fs.mkdirSync("tests/.auth", { recursive: true });
  await page.context().storageState({ path: authFile });
});
```

The 3-step turn-on (the setup report lists these; the render HALTS until done, never builds blind):

1. Put creds in `.env` (gitignored): `E2E_EMAIL=…` / `E2E_PASSWORD=…`.
2. `npx playwright test tests/auth.setup.ts` (dev server up) → writes `tests/.auth/user.json`.
3. Point the render at it — add `--storage-state=tests/.auth/user.json` to the Playwright MCP args (compatible with `--isolated`), or pass `storageState` to the harness. Regenerate on JWT/session expiry.

So a new project's first auth-gated redesign is gated on exactly one human action — dropping creds into `.env` — and everything else is scaffolded and reused.

## Procedure

1. Confirm the dev server URL (default `http://localhost:3000`) and that it serves all declared locales.
2. Run the visual suite — full or scoped:
   ```bash
   # All routes, all combos
   npx playwright test test/visual/
   # One route
   npx playwright test test/visual/ -g 'products'
   # Update baselines after an intentional change
   npx playwright test test/visual/ --update-snapshots
   ```
3. The matrix per route:
   - Locales: every entry in `i18n.config.ts` (`en`, `ar`, ...).
   - Themes: `light` + `dark` (if supported).
   - Viewports: mobile (375x667), tablet (768x1024), desktop (1280x800).
4. For each combo, Playwright compares pixel diff vs baseline; threshold from `playwright.config.ts` (`maxDiffPixelRatio`).
5. Inspect failures:
   ```bash
   npx playwright show-report   # opens HTML diff viewer with side-by-side baseline / actual / diff
   ```
6. After confirming the change is intentional, regenerate baselines and commit them with a message that explains the visual delta.

## Output

```
Running 18 tests using 4 workers

  PASS  /dashboard  en  light  mobile     no diff
  PASS  /dashboard  en  light  desktop    no diff
  PASS  /dashboard  en  dark   desktop    no diff
  FAIL  /dashboard  ar  light  mobile     12.3% pixel diff   (RTL layout shift)
        Snapshot: test/visual/baseline/dashboard-ar-light-mobile.png
        Diff:     test/visual/diffs/dashboard-ar-light-mobile.png
  PASS  /dashboard  ar  light  desktop    no diff

1 failed (1 of 18). Open report:  npx playwright show-report
```

## False positives / gotchas

- Fonts loading after the first paint cause pixel diff — wait for `document.fonts.ready` before screenshotting.
- Time-based content (countdowns, "5 minutes ago") — mock the clock with `page.clock.install()` or freeze with stable test data.
- Animations — disable via `page.emulateMedia({ reducedMotion: 'reduce' })` in setup.
- Image sources with cache-busted query strings produce different pixels per run — pin or stub.
- RTL (Arabic, Hebrew) layout MUST be in the matrix if the app serves those locales — flipped layouts catch real bugs.
- Never run against prod. Dev server only.

## Blocked render = HARD HALT (never a valid screenshot, never a silent SKIP)

A screenshot is only valid if it is **of the target surface**. The most common false-pass in a real app is rendering the **login/auth wall** (or an error/403 page) because the session was missing — and then treating that image as if the surface were verified. It never is.

- **After every `goto`, verify you are on the surface** — assert a surface-unique marker (a heading, a `data-testid`, a container class the target uniquely renders) is present. If it is absent, or the page shows login fields (`input[type=password]`, a "Login"/"Sign in" button), or the URL redirected to `/login` / `/auth`, the render is **BLOCKED**.
- **A blocked render HALTS the caller. It is NOT `SKIPPED (no harness)`** — that status is only for when no render harness exists at all. Harness-present-but-blocked is a *failure to authenticate*, and the run must stop with `RENDER BLOCKED — landed on <login/redirect>, surface not verified; establish an authenticated session (storageState / login step) and re-run` — never proceed as though the surface were audited, and never save the login screenshot as the surface baseline.
- The blocked frame MAY be saved for evidence (e.g. `login-blocked.png`) — but saving it is a HALT signal, not a pass. A caller that finds a `*-blocked.png` in its artifacts has an unverified surface.

## Halt conditions

- Halt unless every combo (locale × theme × viewport) produces a row in the report with the diff file path or "no diff".
- **Halt if the rendered page is the login/auth wall or a redirect off the target route** (blocked render, above) — authenticate and re-run; do NOT downgrade to SKIPPED or treat the login screenshot as the surface.
- Halt if `--update-snapshots` was used to "fix" a failing run without explicit user approval — that's masking a regression.
- Halt if no baseline exists yet AND the run claims PASS — the first run only generates baselines, it cannot verify them.
- Halt if RTL locales are declared in `i18n.config.ts` but absent from the matrix — flipped layouts must be tested.
