# Session digest

derived_at: `0c23a5169e` from `.claude/codebase-profile.md` and `ai/conventions.md` — regenerate after either changes.

## The product

Order management for small wholesalers: place, price, ship and invoice, per tenant.

## Release

- Releases run three phases: build, contracts publish, deploy.
- The contracts publish phase pushes the schemas package before the apps deploy.

## Rules that bite

- Controllers stay thin; every query runs in the tenant scope; money is integer minor units.
- Pagination is by cursor; ids are strings on the wire.

## Corrections worth remembering

- Database: Postgres 16, not MySQL; ids are UUIDv7, not ULID.
- The web app is built with Vite, not Create React App.
