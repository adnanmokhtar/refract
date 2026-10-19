# ADR-0011 — CSS Modules over styled-components in apps/web

- Status: Accepted
- Date: 2026-03-01

## Decision

From 2026-03-01, new and touched components in `apps/web` use CSS Modules with the `@acme/ui`
tokens. styled-components is removed from `apps/web`: a file that mixes the two is migrated the
next time it is touched, and `styled-components` leaves `apps/web/package.json` with its last
caller. `packages/legacy-reports` is out of scope (ADR-0009).
