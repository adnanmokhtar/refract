# API conventions — Lumen Orders

The contract source for every service (P1). The committed spec is `openapi/openapi.yaml`.

## Status codes
- A POST that creates an addressable resource answers **201** with `Location: /v1/<collection>/<id>`.
- A POST that performs an action (search, preview, validate, verify, quote, refund, capture) answers **200**.
- A missing resource answers **404** with the envelope, never `200 null`.
- A conflict (duplicate number, illegal state) answers **409**; a stale `If-Match` answers **412**.
- Validation failures answer **400** with field errors (the Nest default; the whole API uses 400, never 422).
- A provider failure answers **502** (`UPSTREAM_*` codes) or **503** with `Retry-After`; a provider's
  own status is never handed to our caller.
- DELETE answers **204** with no body unless the spec documents a 200 body.

## Error envelope
Every error body, on every route and every service, is
`{"error": {"code": "<MACHINE_CODE>", "message": "<text>", "details": [...]}}` with
`Content-Type: application/json`. Exception: the `/v1/legacy/*` door keeps its documented
pre-2024 shape `{"error": "<sentence>"}` (see openapi `LegacyError`).

## Request bodies
- **Public API (`apps/api`, `services/edge-go` `/v1/*`): strict reader.** An unknown request field is
  rejected with 400 `UNKNOWN_FIELD`. Silent stripping is not allowed.
- **Inbound provider webhooks are tolerant readers** (forward compatibility): unknown fields are ignored.
- `null` and an absent field are different on PATCH: absent = unchanged, `null` = rejected unless
  the field is documented as clearable.

## Money and time
- Money leaves the API as a **decimal string with its scale** (`"10.10"`) plus an ISO 4217 currency.
- 64-bit identifiers leave as strings.
- Instants are RFC 3339 with an offset; calendar dates (`dueDate`, `birthDate`) are `YYYY-MM-DD` strings.
- Business schedules run in `Asia/Dubai` unless the job says UTC.

## Lists
- Every client-visible list goes through the pagination kernel (`common/pagination`): clamped
  page size (max 100), allow-listed sort, unique tiebreak (`id`).

## Deprecation
- `Deprecation: @<unix-seconds>` (RFC 9745) and `Sunset: <HTTP-date>` later than the deprecation date.
