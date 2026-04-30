---
name: dev-server-start
description: Start the project's local dev server in the background and wait for it to be ready. Detects pnpm/npm/yarn/bun + port from project config. Idempotent — reuses an already-running server when detected.
---

# dev-server-start

## Premise

Existing project conventions are the truth. Read `package.json`, the lockfile, and the framework config before guessing — never invent a start command. Mirror the script the project already ships with (`dev`, `start`, `serve`); if none exists, halt rather than fabricate one. Idempotency is non-negotiable: a re-run in the same session must detect an already-running server, not spawn a duplicate.

Refuse to start a server when `package.json` is absent at the chosen project root.

Boilerplate for "I need the app running locally before I can verify it." Used as a prerequisite by `verify-with-playwright`, `a11y-audit`, `visual-check`, `ssr-audit`, and any task that ends with "open the page and check."

## When to use

- Before invoking the Playwright MCP server's `navigate` tool against `http://localhost:<port>`.
- Before running an e2e test that hits `localhost`.
- Before a manual visual check — agent or human.

## When NOT to use

- The user already has the dev server running in another terminal — `lsof -iTCP:<port> -sTCP:LISTEN` should detect it; this skill is a no-op then.
- Static-only checks (lint, type-check, bundle analysis) — no server needed.
- Production / staging URL targets — point Playwright there directly.

## Inputs

- Working directory of the project (defaults to `$PWD`).
- Optional `port_override` (numeric) — when the project's default port is taken or a separate instance is needed (e.g., E2E parallel runs).

## Procedure

### Step 1 — Detect the runtime + start command

Read `package.json` `scripts.dev` (or `scripts.start` for Next/Nuxt). Detect package manager from lockfile:
- `pnpm-lock.yaml` → `pnpm dev`
- `yarn.lock` → `yarn dev`
- `bun.lockb` → `bun dev`
- `package-lock.json` → `npm run dev`

If no `dev` script and no recognizable framework config (`vite.config`, `next.config`, `nuxt.config`, `angular.json`, `svelte.config`), halt with `dev-server-not-applicable`.

### Step 2 — Detect the port

Order of precedence:
1. `port_override` input.
2. Explicit port in `vite.config.ts` `server.port` / `next.config.js` / `nuxt.config.ts`.
3. Framework default: Vite → 5173, Next → 3000, Nuxt → 3000, Angular → 4200, SvelteKit → 5173, Remix → 3000.
4. Fall back to 3000.

### Step 3 — Idempotency check

```bash
lsof -nP -iTCP:<port> -sTCP:LISTEN 2>/dev/null
```

If a process is already listening on that port AND it's a node/bun process (`lsof` output contains `node` or `bun`), assume it's the dev server. Probe `http://localhost:<port>` with a 2-second timeout — 200 / 304 / any 4xx other than 404 means it's serving. Return `already-running` with the URL.

If something else is listening (Postgres on 5432, etc.), choose `port_override = port + 1`, retry.

### Step 4 — Launch in background

```bash
( cd "$PROJECT_ROOT" && <pkg-manager> dev > .claude/dev-server.log 2>&1 & )
echo $! > .claude/dev-server.pid
```

Detach the process so it survives the agent's shell exit. Capture pid + stdout to `.claude/dev-server.{pid,log}` for later inspection.

### Step 5 — Wait for ready

Poll `http://localhost:<port>` every 500ms. Ready conditions:
- HTTP 200 / 304 / 304-equivalent.
- For SPAs: response body contains the root mount-point (`<div id="app">`, `<div id="__next">`, etc.) — guards against the framework still bundling.

Timeout: 60 seconds. On timeout, print last 30 lines of `.claude/dev-server.log` and halt with `dev-server-timeout`.

### Step 6 — Hand off

Return:
- `url` — `http://localhost:<port>` (or override).
- `pid` — for the caller to kill on cleanup if it owns lifecycle.
- `mode` — `started-fresh` or `already-running` (caller decides whether to kill on exit; never kill an already-running server).

## Output format

```
dev-server-start
  pkg-mgr: pnpm
  cmd: pnpm dev
  port: 5173
  mode: started-fresh
  pid: 84321
  url: http://localhost:5173
  log: .claude/dev-server.log
  ready-after: 4.2s
```

## Failure modes

- **Port collided with non-dev process** — detected (Postgres, system service); skill auto-bumps and retries on `port + 1`. If still colliding after 3 bumps, halt.
- **Bundler error** — dev server exits in <2s with non-zero code. Skill detects via pid recheck + log inspection. Surfaces last 30 log lines + halts.
- **Watcher exhausted** (Linux ENOSPC) — fs.inotify limit hit. Surface the precise error + suggest `sudo sysctl fs.inotify.max_user_watches=524288`.
- **Wrong project root** — `package.json` not found at `$PROJECT_ROOT`. Halt; do not start a server in the wrong dir.

## Related

- `verify-with-playwright` — typical caller; consumes the returned URL.
- `a11y-audit`, `visual-check`, `ssr-audit` — also depend on a running server.
- `dev-server-stop` (sibling skill, optional) — kill `.claude/dev-server.pid` if present, clear file.

## Hard rules

- **Idempotent.** Re-running this skill in a session must never spawn a duplicate server. The port-detection step is non-skippable.
- **Background only.** Never block the agent's main loop on the server's stdout. Tail the log on demand.
- **Never start a server in production / CI mode** — refuse if `NODE_ENV=production` or `CI=true` is set.
- **Project-root verified.** `package.json` must exist at the chosen `PROJECT_ROOT`. No fallback to `cwd`.

## Halt conditions

- Halt if `package.json` has no `dev` / `start` script and no recognised framework config — do not fabricate a start command.
- Halt if the lockfile + package manager don't match (e.g., `pnpm-lock.yaml` present but `npm` requested). Mirror what the project actually ships with.
- Halt if the port collides with a non-dev process after 3 bumps — stop guessing, surface the conflict.
- Halt if the server exits within 2s of launch — capture the last 30 log lines and refuse to declare success.
