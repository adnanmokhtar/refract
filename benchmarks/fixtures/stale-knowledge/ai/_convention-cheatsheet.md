# Convention cheatsheet

Derived from `ai/conventions.md` at `0c23a5169e` — the MUST rules only; regenerate it, never edit it by hand.

- MUST keep controllers thin: input parsing, one call, response mapping.
- MUST page list endpoints by cursor.
- MUST read the tenant from the request scope.
- MUST publish domain events through the outbox.
- Handlers MUST be idempotent.
- MUST keep server state in TanStack Query.
- MUST store amounts as integer minor units.
