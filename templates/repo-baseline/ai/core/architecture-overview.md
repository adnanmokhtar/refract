# Architecture overview (one page)

High-level shape when `ai/architecture.md` is too long for a quick read. **Aligned** with `ai/architecture.md` after `/setup-project`.

Last updated: <YYYY-MM-DD>

## System in one paragraph

<3–5 sentences: major components, data flow, where state lives>

## Layering / boundaries

- **Presentation**: <...>
- **Application / domain**: <...>
- **Infrastructure**: <...>

## Critical integration points

- <API, queue, webhooks — one line each>

## Invariants (pointer)

Full list: `ai/core/invariants.md`. Top 3 for this project:

1. <invariant>
2. <invariant>
3. <invariant>

## See also

- `ai/architecture.md` — full architecture note
- `.claude/codebase-profile.md` — machine-oriented profile
