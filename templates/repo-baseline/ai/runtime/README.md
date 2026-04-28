# ai/runtime/

Live runtime context — gotchas, NEVER-do / ALWAYS-do rules, environment-dependent quirks. Read this before making changes.

## What goes here

- `context.md` — the "stuff a new contributor will trip on" list:
  - "NEVER touch migrations on main branch" (or whatever your rule is)
  - "ALWAYS run `pnpm dev` from /api, not workspace root"
  - "The webhook handler MUST ack within 5 seconds — Meta retries on timeout"
  - "Don't modify `tenants.id` — too many denormalized references"
- `domain-anti-patterns.md` — populated from `business-domains/<domain>/anti-patterns.md`. Domain-specific traps.
- `environment-quirks.md` — local-dev quirks (port conflicts, Docker memory, OAuth callback weirdness).
- `dependencies-with-traps.md` — third-party libs with known footguns ("Stripe SDK quietly retries — must be idempotent").

## Distinction from `.claude/rules/`

- `.claude/rules/` — generic + framework-level rules (DTOs, controllers, cache keys).
- `ai/runtime/context.md` — PROJECT-SPECIFIC quirks the rules don't capture.

## Format

Free-form markdown. Bullet lists work well. Date-stamp entries you expect to expire ("(2026-04: investigating; can remove after fix)").

## How to keep it useful

- Add to it when you find a footgun.
- Prune entries that no longer apply (don't let it become an archaeology dig).
- Surface critical entries in `CLAUDE.md` Top-of-File rules.

## Empty?

`/setup-project` populates `domain-anti-patterns.md` from the detected business domain. Other files start empty and grow as the project encounters specifics.
