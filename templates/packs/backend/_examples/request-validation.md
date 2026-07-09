---
name: request-validation
kind: example
pack: backend
---

# Pattern: Request Validation

> **Hard rule:** Every inbound request is validated at ONE declared boundary before any use-case logic runs — `decode → validate (types / bounds / format) → normalize / canonicalize → authorize` — and writes bind through an explicit allow-list of writable fields. `save(req.body)`, `Object.assign(entity, body)`, or validating deep inside business logic is forbidden. This pattern owns WHAT / WHERE / HOW to validate; the error *envelope* on failure is owned by `error-handling.md`.

**When to apply** — any handler reading attacker-controlled input (body / query / path / headers / cookies), any write path (over-posting is a privilege-escalation write), retrofitting untyped `req.body.x` handlers.

## Rules

1. Validate ONCE at the edge; the boundary emits a typed value object (DTO / command) — services never re-check "is this a string?".
2. Order is load-bearing: canonicalize AFTER validate, so normalization can't manufacture a valid value from an invalid one.
3. Allow-list writable fields (`whitelist` / `.strict()` / `extra="forbid"`); server-set fields (`id`, `role`, `tenant_id`, `ownerId`, `price`) never come from the body.
4. Bounds on everything: `@MaxLength` / `@ArrayMaxSize` / `@Min`/`@Max` / nesting depth — nothing unbounded.
5. Content-Type allow-list (`415`) + max body size (`413`) BEFORE parsing.
6. Failure → structured `422` field-error map with stable machine codes (envelope shape owned by `error-handling.md`).

## Adapt to the codebase

| Stack | Boundary primitive | Allow-list + bounds |
|---|---|---|
| **NestJS** | class-validator DTO + `ValidationPipe` | `whitelist` / `forbidNonWhitelisted`; `@MaxLength`/`@ArrayMaxSize`/`@Min`/`@Max` |
| **Express** | `zod` / `joi` middleware | `z.object({}).strict()`; `.max()`/`.min()`/`.length()` |
| **FastAPI** | Pydantic model | `ConfigDict(extra="forbid")`; `Field(max_length=, ge=, le=)` |
| **Spring** | Bean Validation `@Valid` DTO record | DTO declares only writable fields; `@Size`/`@Max`/`@Min` |
| **Rails** | strong params | `params.require(:user).permit(:name, :email)` + model bounds |

## Detectors (cite-or-halt)

1. Whole body bound onto a model (`Object.assign(entity, body)` / `save(req.body)` / `.update(params)`) → name the escalatable fields → `report-with-fix` (OWASP API3 / BOPLA).
2. Untyped `req.body.*` read with no boundary schema → `add-boundary-schema`.
3. String/array/number DTO field with no `@MaxLength`/`@ArrayMaxSize`/`@Min`/`@Max` → `add-bounds`.
4. Body-parsing endpoint with no Content-Type allow-list or max-body-size → `add-body-limit`.
5. `.trim()`/`.toLowerCase()`/`normalize()` applied BEFORE validation → `fix-validate-order`.

Closure verbs: `report-with-fix` / `report-flagged` (shared `422` envelope / trust boundary — ADR) / `dismiss` (already-validated internal payload behind a trust boundary).

## Related

`error-handling.md` (error envelope — boundary), `api-contract.md` (tightening input is a breaking change), `file-upload.md` (upload-stream validation hands off here), `api-consistency-audit` (skill — `422` consistency), security pack + `security-principles` (mass-assignment = OWASP API3 / BOPLA).
