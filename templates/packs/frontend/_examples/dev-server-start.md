---
name: dev-server-start
kind: example
pack: frontend
---

# dev-server-start

Boots the project's dev server **idempotently** and returns a `url` + `pid` + `mode` other skills consume. Never a second server on a second port while the first is still serving.

## Procedure (abridged)

1. **Read the framework's own dev lock/manifest first, if it writes one** — it is authoritative for URL and PID, and no probing beats the source of truth. (Next.js 16 added a lockfile mechanism that prevents a second `next dev` on the same project; confirm the path against the installed version's docs before relying on it.)
2. Otherwise detect a running server: check the configured port, then confirm the response body actually looks like this app (a mount point / the app's title), not some other process squatting on the port.
3. Already running → `mode: already-running`. **Never kill it** — you did not start it, and the developer may be using it.
4. Not running → start with the project's own script (`dev` from `package.json`, via its package manager), wait for the ready line, return `mode: started-fresh` and take ownership of cleanup.

## Output

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

## Halt conditions

- Halt rather than starting a second instance of a server that is already up.
- Halt if the URL was never verified with a real request — an unverified URL is a guess.
