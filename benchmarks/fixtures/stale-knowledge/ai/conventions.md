# Conventions

Project conventions with their MUST level. `ai/_convention-cheatsheet.md` is derived from this file.

## API

- MUST keep controllers thin: input parsing, one call, response mapping.
- MUST page list endpoints by cursor (ADR-0008).
- MUST read the tenant from the request scope, not from the request body.
- Services throw `DomainError` subclasses, never Nest's `HttpException` family; `HttpErrorFilter` maps them.
- Errors use the problem+json envelope of ADR-0011.

## Events

- MUST publish domain events through the outbox: follow `ai/patterns/outbox.md`.
- Handlers MUST be idempotent; the relay retries.

## Web

- HTTP calls go through `apps/web/src/lib/ApiClient.ts`; features do not create their own client.
- MUST keep server state in TanStack Query.

## Money

- MUST store amounts as integer minor units in `bigint` columns.
- MUST wrap every money write in one `em.transactional()` call.

## Naming

- Files are kebab-case with a role suffix.
- Classes are PascalCase; functions and variables camelCase.
- Database columns are snake_case.

## Tests

- Specs sit beside the code.
- A spec names the behaviour, not the method.

## Layout

- A new module follows `apps/api/src/modules/<module>/<module>.service.ts` for its service.
- Responses: map entities with `toResponse` through `ResponseMapper` (`apps/api/src/shared/http/response.mapper.ts:6`).
