# 6. UUIDv7 primary keys

Status: Accepted
Date: 2026-06-15

## Context

Postgres has a native `uuid` type and time-ordered UUIDs index as well as the earlier scheme.

## Decision

Entities use UUIDv7 strings from the `uuidv7` package, generated in the constructor through `newId()`.

## Consequences

Columns are `uuid`; older rows were re-keyed by the June migration.
