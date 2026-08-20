# Dependencies with traps

Third-party libraries this project uses that have KNOWN footguns. Adding a dep here means: "this isn't just `npm install` and forget — the docs hide a trap, behavior surprised us, or wrong version causes real bugs."

> **Read by:** bug fixes and any code that calls a listed library. **Load trigger:** debugging behavior that "should work", touching code that uses a trapped dependency, or a dependency upgrade.

## Format per entry

```
## <package@version-range>
Trap: <one-line summary>
Discovered: <YYYY-MM-DD> by <person / incident #>
Workaround: <what we do instead>
Sample location: `<file:line where the workaround lives>`
Tracking: <upstream issue link if relevant>
```

## Examples (delete these once you have real entries)

```
## stripe@^14
Trap: SDK auto-retries idempotent operations silently on network blips, including 5xx — your webhook may receive 2 events for one charge.
Discovered: 2025-08-14 by INC-203
Workaround: Always check `event.id` against a `processed_events` table before applying.
Sample: src/modules/billing/webhooks/stripe.handler.ts:42
Tracking: stripe/stripe-node#2104

## typeorm@^0.3
Trap: `@OneToOne` relations don't auto-load on `find()` even with `eager: true` if the relation is on the OWNED side (FK on the other table).
Discovered: 2025-09-02 in PR #847
Workaround: Use `relations: { name: true }` in `find()` options explicitly.
Sample: src/modules/orders/order.repository.ts:88

## bullmq@^5
Trap: Workers don't see jobs added DURING worker shutdown grace period (last 30s).
Discovered: 2025-11-10 in production deploy.
Workaround: Add `process.on('SIGTERM')` handler that waits for in-flight jobs but stops accepting new ones via `worker.pause()`.
Sample: src/main.ts:65
```

## How to keep this current

- Add an entry every time you debug an issue that turned out to be a library quirk (not your code).
- Update entry when upstream fixes the trap (mark RESOLVED with version that includes the fix).
- Periodic review during dependency upgrade: re-check each entry — many will be obsolete.

## See also

- `ai/runtime/context.md` — broader project gotchas.
- `ai/decisions/` — major dependency choices documented as ADRs.
- `package.json` — current dependency versions.
- `.claude/skills/deps-audit/SKILL.md` — periodic audit command.
