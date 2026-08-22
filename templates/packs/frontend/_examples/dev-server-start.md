---
name: dev-server-start
description: Start the project's local dev server in the background and wait until it is ready, resolving the workspace member to run (pnpm/npm/yarn/bun workspaces, turbo, nx) before detecting the package manager and the port from project config. Idempotent — reuses an already-running server. Run before any skill that needs a live localhost (`verify-with-playwright`, `a11y-scan`, `visual-check`, `ssr-audit`); it starts a server and nothing else.
kind: example
pack: frontend
---

# dev-server-start

Boots the project's dev server **idempotently** and returns a `url` + `pid` + `mode` other skills consume. Never a second server on a second port while the first is still serving.

## Premise

Existing project conventions are the truth. Read `package.json`, the lockfile, and the framework config before guessing — never invent a start command. Mirror the script the project already ships with (`dev`, `start`, `serve`); if none exists, halt rather than fabricate one. Idempotency is non-negotiable: a re-run in the same session must detect an already-running server, not spawn a duplicate.

Refuse to start a server when `package.json` is absent at the chosen project root — and **choose that root deliberately**, because in a workspace the nearest `package.json` above `$PWD` belongs to the workspace, whose `dev` script starts N servers rather than one.

## Inputs

- Working directory of the project (defaults to `$PWD`).
- Optional `app_target` — the workspace member to start (`apps/web`, or its package name). Required, or the run halts, when the workspace holds more than one app member. Ignored in a single-package repo.
- Optional `port_override` (numeric) — when the project's default port is taken or a separate instance is needed (e.g., E2E parallel runs).

## Procedure (abridged)

0. **Resolve `PROJECT_ROOT` before anything else.** Walk up to the outermost `package.json`; it is a *workspace* root if `pnpm-workspace.yaml`, a `workspaces` key, `turbo.json`, `nx.json`, `lerna.json` or `rush.json` sits beside it. If the root `dev` script fans out (`turbo run dev`, `nx run-many`, `pnpm -r dev`, `npm run dev --workspaces`, `concurrently`), it starts **several** servers — enumerate the app members (own `scripts.dev` **and** a framework config beside it), then: `app_target` given → that member; exactly one app member → take it and say so; more than one and no `app_target` → **HALT `workspace-target-ambiguous`** listing each candidate with its dev script, framework and configured port. Never take the alphabetically-first member: a silently wrong URL makes `verify-with-playwright`, `a11y-scan`, `visual-check` and `ssr-audit` all report clean results about the wrong app. The member directory is `PROJECT_ROOT`; the package manager still comes from the workspace-root lockfile, and the launch goes through the workspace runner (`pnpm --filter <member> dev`, `npm run dev -w <member>`, `yarn workspace <member> dev`).
1. **Read the framework's own dev lock/manifest first, if it writes one** — it is authoritative for URL and PID, and no probing beats the source of truth. (Next.js 16 added a lockfile mechanism that prevents a second `next dev` on the same project; confirm the path against the installed version's docs before relying on it.)
2. Otherwise detect a running server: check the configured port, then confirm the response body actually looks like **this member's** app (a mount point / the app's title / a route only it serves), not a sibling workspace member or another repo squatting on the port. In a workspace this probe is not optional — two members can share a framework default, and the sibling answers 200 just as happily.
3. Already running → `mode: already-running`. **Never kill it** — you did not start it, and the developer may be using it.
4. Not running → start with the project's own script (`dev` from `package.json`, via its package manager), wait for the ready line, return `mode: started-fresh` and take ownership of cleanup.

## Output format

```
dev-server-start
  root:  apps/web        (workspace: pnpm + turbo; 2 app members, app_target given)
  url:   http://localhost:5173
  pid:   48213
  mode:  already-running   (or started-fresh)
```

## Failure modes

- Port occupied by a different app → report the mismatch; do not adopt it as this project's server.
- Workspace fan-out mistaken for one server → N servers boot and the probe adopts whichever won the default port. Prevented by step 0.
- Sibling member adopted as `already-running` because the body check was skipped → the run then verifies the wrong app and reports PASS.
- Ready line never appears → surface the last N log lines; do not claim a URL you never fetched.
- Started-fresh server left running after a failed caller → the caller that started it owns teardown.

## Hard rules

- **Idempotent.** Re-running this skill in a session must never spawn a duplicate server. The port-detection step is non-skippable.
- **Background only.** Never block the agent's main loop on the server's stdout. Tail the log on demand.
- **Never start a server in production / CI mode** — refuse if `NODE_ENV=production` or `CI=true` is set.
- **Project-root verified, and chosen rather than assumed.** Step 0 selects `PROJECT_ROOT`; `package.json` must exist there. No fallback to `cwd`, and no fallback to the workspace root when the target is a member.
- **One member per run.** Starting a workspace's whole app set is out of scope — run once per member with an explicit `app_target`.

## Halt conditions

- Halt rather than starting a second instance of a server that is already up.
- Halt if the URL was never verified with a real request — an unverified URL is a guess.
- Halt `workspace-target-ambiguous` when the repo is a workspace with more than one app member and no `app_target` was given; picking one is the caller's decision, not the run's.
- Halt if the resolved start command is a fan-out runner — that starts N servers and this skill returns one `url`.
