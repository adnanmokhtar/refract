---
name: dev-server-start
description: Start the project's local dev server in the background and wait until it is ready, detecting pnpm/npm/yarn/bun and the port from project config. Idempotent — reuses an already-running server. Run before any skill that needs a live localhost (`verify-with-playwright`, `a11y-scan`, `visual-check`, `ssr-audit`); it starts a server and nothing else.
kind: example
pack: frontend
---

# dev-server-start

Boots the project's dev server **idempotently** and returns a `url` + `pid` + `mode` other skills consume. Never a second server on a second port while the first is still serving.

## Premise

Existing project conventions are the truth. Read `package.json`, the lockfile, and the framework config before guessing — never invent a start command. Mirror the script the project already ships with (`dev`, `start`, `serve`); if none exists, halt rather than fabricate one. Idempotency is non-negotiable: a re-run in the same session must detect an already-running server, not spawn a duplicate.

Refuse to start a server when `package.json` is absent at the chosen project root.

## Inputs

- Working directory of the project (defaults to `$PWD`).
- Optional `port_override` (numeric) — when the project's default port is taken or a separate instance is needed (e.g., E2E parallel runs).

## Procedure (abridged)

1. **Read the framework's own dev lock/manifest first, if it writes one** — it is authoritative for URL and PID, and no probing beats the source of truth. (Next.js 16 added a lockfile mechanism that prevents a second `next dev` on the same project; confirm the path against the installed version's docs before relying on it.)
2. Otherwise detect a running server: check the configured port, then confirm the response body actually looks like this app (a mount point / the app's title), not some other process squatting on the port.
3. Already running → `mode: already-running`. **Never kill it** — you did not start it, and the developer may be using it.
4. Not running → start with the project's own script (`dev` from `package.json`, via its package manager), wait for the ready line, return `mode: started-fresh` and take ownership of cleanup.

## Output format

```
dev-server-start
  url:   http://localhost:5173
  pid:   48213
  mode:  already-running   (or started-fresh)
```

## Failure modes

- Port occupied by a different app → report the mismatch; do not adopt it as this project's server.
- Ready line never appears → surface the last N log lines; do not claim a URL you never fetched.
- Started-fresh server left running after a failed caller → the caller that started it owns teardown.

## Hard rules

- **Idempotent.** Re-running this skill in a session must never spawn a duplicate server. The port-detection step is non-skippable.
- **Background only.** Never block the agent's main loop on the server's stdout. Tail the log on demand.
- **Never start a server in production / CI mode** — refuse if `NODE_ENV=production` or `CI=true` is set.
- **Project-root verified.** `package.json` must exist at the chosen `PROJECT_ROOT`. No fallback to `cwd`.

## Halt conditions

- Halt rather than starting a second instance of a server that is already up.
- Halt if the URL was never verified with a real request — an unverified URL is a guess.
