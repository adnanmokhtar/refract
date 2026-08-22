---
name: visual-check
description: Playwright-based UI verification — captures screenshots across locales, themes, and viewports. Run after a visible change; compares against a baseline.
---

# visual-check

For frontend changes. Verifies the UI renders correctly across locales, themes, and viewport sizes before shipping.

## When to use

- After any change that touches a `.vue` / `.tsx` / `.svelte` template, CSS, or design tokens.
- After an i18n string update that may shift layout (Arabic / German / Japanese often do).
- After a Tailwind config change.
- Before a release candidate goes to QA.

## Premise

Real artifacts only. Every claim cites the baseline file path + the actual file path + the diff file path produced. "Looks the same" without a diff image is not verification. A run that updates baselines without explicit user confirmation is forbidden — `--update-snapshots` is a deliberate decision, not a workaround for a failing run.

Refuse to declare PASS unless every combo in the matrix produced a row with either "no diff" or a diff image path.

## Prerequisites

- Dev server running locally (or a built static preview).
- Playwright installed: `pnpm add -D @playwright/test && npx playwright install`.
- Baseline screenshots at `test/visual/baseline/` (generated on the first green run; commit them).
- A `test/visual/visual.spec.ts` that drives `page.goto` + `expect(page).toHaveScreenshot()`.

## Authenticated rendering (non-negotiable for auth-gated surfaces)

Most real app surfaces (dashboards, settings, anything behind a route guard) are **unreachable without a session**. Rendering them requires establishing auth FIRST — otherwise the guard bounces the render to `/login` and every screenshot is worthless.

**The harness contract (one convention, many consumers)** — three values are fixed and cited, never restated:

| Value | The one setting | Why it is fixed |
|---|---|---|
| Session state | `tests/.auth/user.json` | it is what the auth setup writes, what the config's `storageState` names, and what the MCP `--storage-state=` arg points at — three places that must agree or the render silently lands on `/login` |
| Artifact dir | `.playwright-mcp/` (gitignored) | a gitignored output dir needs no cleanup, so nobody reaches for `rm -rf` |
| Blocked render | `RENDER BLOCKED` = HALT, never `SKIPPED` | "no harness" and "authenticated but bounced to the login wall" are different failures with different fixes; collapsing them produces a false pass |

1. **Detect the gate** before rendering the route (router meta, a guard import, a redirect-to-login). If gated, authenticate before `page.goto`.
2. **Establish a session** by the cheapest means: reuse a saved `storageState` at `tests/.auth/user.json`; else log in once (credentials from env, never hardcoded) and persist it; else use the project's existing auth fixture.
3. **Point the browser at the session** — `--headless --isolated` with no auth ALWAYS lands on `/login`.
4. **Prove you landed on the surface, not the wall** — assert a surface-unique marker before screenshotting.

### Turning it on for the first time (this skill owns the scaffold)

Creds are a **secret** no generator can bake or guess, so the work splits: **this skill scaffolds the whole mechanism; the human supplies ONE secret, once.** When the app is detected auth-gated (a router guard, `requiresAuth` meta, a `/login` redirect, `<PrivateRoute>`, an auth interceptor): drop the file below as `tests/auth.setup.ts`, gitignore `tests/.auth/`, add the `.env` slot. The human then puts `E2E_EMAIL` / `E2E_PASSWORD` in the gitignored `.env` — never committed, never in a command, never pasted in chat.

**Do not delegate this.** No other artifact produces `tests/auth.setup.ts`. If this section does not deploy it, no one does.

```ts
import { test as setup, expect } from "@playwright/test";
import fs from "node:fs";
// Load .env into process.env — dependency-free. Playwright runs in Node, which does NOT
// auto-load .env the way Vite does, so without this the creds are undefined even though
// they are IN .env. Prefer `import "dotenv/config"` if the project already has dotenv.
try {
  for (const line of fs.readFileSync(".env", "utf8").split("\n")) {
    const m = line.match(/^\s*([\w.]+)\s*=\s*(.*?)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2].replace(/^(['"])(.*)\1$/, "$2");
  }
} catch { /* no .env file — rely on ambient env */ }
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

Both asserts are the point, not decoration: the missing-creds throw (an empty `E2E_EMAIL` otherwise submits a blank form and fails as "bad credentials"), and the token-landed assert (a login form that silently re-renders itself writes a `user.json` full of nothing, and every later render fails at the wall with a session file sitting on disk).

Then the ways this is wired correctly and still does not work — none guessable, each reads as "Playwright is broken":

1. **A `*.setup.ts` file does not match Playwright's default `testMatch`** (`*.spec` / `*.test`), so `npx playwright test tests/auth.setup.ts` returns **"No tests found"** — success-shaped output for a run that never happened. Register a `setup` project and depend on it:
   ```ts
   projects: [
     { name: "setup", testMatch: /.*\.setup\.ts/ },
     { name: "chromium", use: { ...devices["Desktop Chrome"] },
       dependencies: ["setup"], storageState: "tests/.auth/user.json" },
   ]
   ```
   Then, dev server up: `npx playwright test --project=setup` writes `tests/.auth/user.json`.
2. **`--storage-state=tests/.auth/user.json` is compatible with `--isolated`** on the Playwright MCP. The two are routinely assumed mutually exclusive, which is why gated renders get run isolated-with-no-session and land on `/login`.
3. **A stale `user.json` still redirects to `/login`** on session expiry with everything correctly wired. The symptom is identical to never having set it up; the fix is re-running the setup project, not re-scaffolding.

So a new project's first auth-gated render is gated on exactly one human action — dropping creds into `.env`.

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

  PASS  /products  en  light  mobile     no diff
  PASS  /products  en  light  desktop    no diff
  PASS  /products  en  dark   desktop    no diff
  FAIL  /products  ar  light  mobile     12.3% pixel diff
        Snapshot: test/visual/baseline/products-ar-light-mobile.png
        Diff:     test/visual/diffs/products-ar-light-mobile.png
  PASS  /products  ar  light  desktop    no diff

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
- Halt if RTL locales are declared but absent from the matrix — flipped layouts must be tested.
