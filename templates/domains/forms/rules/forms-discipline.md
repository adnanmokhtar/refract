---
name: forms-discipline
description: Form handling & submission discipline
kind: rule
---

# Form handling & submission discipline

## Hard rule

Every form that changes state MUST be validated AGAIN on the server against a shared schema — the client validation is UX, the server validation is the trust boundary, and a CLIENT-ONLY validated handler is a security hole. State-changing submissions (`POST`/`PUT`/`PATCH`/`DELETE`) MUST carry CSRF protection (synchronizer token / double-submit cookie / `SameSite`-anchored origin check); a state-changing form post without it is a CSRF vulnerability. Submission MUST be idempotent — a per-submission token (or natural idempotency key) collapses double-clicks, retries, and back-button replays to ONE record. Server binding MUST be an explicit field ALLOWLIST — binding the whole request body to a model (mass-assignment / overposting) is a privilege-escalation hole. Rich/HTML input MUST be sanitized on input and ESCAPED on output (stored XSS otherwise). Public/unauthenticated forms MUST be rate-limited + bot-gated, and EVERY form MUST bound payload size, field count, and array length. Errors map BACK to fields; PII never lands in logs.

A form bug is a duplicated charge, an escalated privilege, a stored XSS that runs in every viewer's browser, or a spam flood — each one reaches users directly.

## Must

- **Re-validate on the server**: one schema (Zod / Yup / Valibot / Pydantic / a JSON-Schema doc) is the single source of truth, run on the client for UX AND on the server as the boundary. The server NEVER trusts that the client validated. See `<patterns-path>/form-handling.md § Shared schema`.
- **CSRF on every state-changing post**: synchronizer token, double-submit cookie, or an origin/`Sec-Fetch-Site` check anchored to `SameSite` cookies — verified server-side before the handler runs. Read-only `GET` is exempt; anything that mutates is not. (See `<rules-path>/auth`.)
- **Idempotent submission**: a server-issued submission token (or a natural key like `order:<cartId>`) is checked-and-consumed atomically so a double-click / retry / replay produces ONE record, not N. The token is single-use and scoped to the form instance + user.
- **Explicit field allowlist (no mass-assignment)**: the handler binds named, declared fields only — never `Object.assign(model, req.body)` / `Model(**request.data)` / `update(req.body)`. Fields like `role`, `isAdmin`, `tenantId`, `priceMinor`, `ownerId` are server-set, never client-bindable.
- **Sanitize in, escape out**: rich-text / HTML input is sanitized against an allowlist (DOMPurify / sanitize-html / bleach) on the way in, AND escaped at the rendering edge on the way out. Plain text is stored raw and escaped on output. Never `innerHTML`/`v-html`/`dangerouslySetInnerHTML` raw user input.
- **Bound the payload**: max body size, max field count, max string length per field, and max array length are enforced BEFORE the body is parsed/iterated. An unbounded array or a 10MB JSON blob is a DoS vector.
- **Rate-limit + bot-gate public forms**: unauthenticated forms (signup, contact, password-reset, comment) are rate-limited per IP + per identifier and gated by a CAPTCHA / proof-of-work / hidden-field heuristic. (See `<rules-path>/rate-limit`.)
- **Map errors back to fields**: validation failures return a structured per-field error map (`{ field: messages[] }`) the UI binds to inputs — not an opaque 400 / 500. The submission round-trips with values preserved.
- **File fields hand off to upload discipline**: a file input is NOT validated inline in the form handler — it is delegated to the upload pipeline (content-type allowlist, size cap, magic-byte sniff, off-origin storage, AV scan). See `<rules-path>/file-upload`.
- **Keep PII out of logs**: validation errors, rejected payloads, and stack traces are scrubbed of email / phone / SSN / card / password fields before they reach logs or error trackers. Log a field-name + error-code, never the value.
- **Format at the edge**: money is the integer-minor-unit type, dates/numbers are parsed per the org locale + timezone at the boundary — never trusted as the client formatted them. (See reporting's edge-format/escaping discipline.)

## Must not

- Validate only on the client and trust the result server-side — devtools / curl / a modified bundle bypasses it entirely.
- Accept a state-changing `POST`/`PUT`/`PATCH`/`DELETE` with no CSRF token / origin check.
- Write the record on every submit with no idempotency guard — double-click charges twice, the retry replays the order.
- Bind the request body wholesale to a model (`Object.assign`, spread, `Model(**body)`, `update(req.body)`) — overposting sets `isAdmin: true`.
- Store rich/HTML input unsanitized, or render any user input via `innerHTML` / `v-html` / `dangerouslySetInnerHTML` without escaping — stored XSS.
- Expose an unauthenticated form with no rate limit and no bot gate — spam, credential-stuffing, password-reset enumeration.
- Iterate or persist an unbounded array / unbounded-length string from the body — memory + DB blow-up.
- Return an opaque error with no field mapping, dropping the user's entered values on the floor.
- Validate file uploads inline (extension-only check, no magic-byte sniff, stored on the app origin).
- Echo the submitted email / phone / card / password into a log line or an error message.

## Should

- Wrap the submit path behind a project-internal `<FormHandler>` / `<validatedAction>` that derives validation, CSRF check, idempotency consumption, allowlist binding, and the per-field error envelope from a declared form spec — feature code declares fields, not raw `req.body` access.
- Co-locate the schema so the SAME module is imported by the client component and the server handler — divergence between two hand-kept copies is the bug.
- Issue the submission/idempotency token when the form is rendered (or on first `GET`), bound to the user + form instance, and consume it transactionally with the write.
- Preserve and re-render entered values on validation failure (server-rendered apps) so the user doesn't retype; never lose input to a 400.
- Normalize input at the edge (trim, lowercase email, E.164 phone, NFC unicode) inside the schema so equality + uniqueness checks are stable.
- Emit structured `{ formType, fieldErrors: [codes], tokenReused: bool, rateLimited: bool }` (codes/booleans, never values); alert on token-reuse spikes (replay attack) and rejection-rate spikes (probing).

## Review checklist (PRs touching forms / submit handlers / validation / actions)

- [ ] The submit handler is located at `<path:line>` and re-validates on the SERVER against the shared schema — not client-only.
- [ ] The same schema module is imported by both client and server (cite both `<path:line>`); no divergent hand-kept copy.
- [ ] State-changing posts verify CSRF (token / double-submit / origin) server-side at `<path:line>`.
- [ ] Submission is idempotent — a single-use token / natural key is checked-and-consumed atomically at `<path:line>`; double-submit yields one record.
- [ ] Binding is an explicit field allowlist at `<path:line>` — no whole-body bind; `role`/`tenantId`/`price`/`owner` are server-set.
- [ ] Rich/HTML input is sanitized on input AND escaped on output; no raw `innerHTML`/`v-html`/`dangerouslySetInnerHTML`.
- [ ] Payload is bounded — body size, field count, string length, array length capped before iteration.
- [ ] Public/unauthenticated forms are rate-limited + bot-gated.
- [ ] File fields delegate to the upload pipeline (allowlist + size + magic-byte + off-origin + scan), not inline checks.
- [ ] Errors map back to fields (`{ field: messages[] }`); entered values are preserved on failure.
- [ ] No PII (email/phone/card/password) in logs or error payloads.

## Anti-patterns

- **Client-only validation** — required/format/length enforced only in the React/Vue component; the API does `repo.create(req.body)`. curl skips every rule. Re-validate server-side against the shared schema — the server is the boundary.
- **No CSRF** — `POST /account/email` changes the login email with a cookie session and no token; a cross-site form auto-submits it. Verify a synchronizer/double-submit token or origin server-side.
- **Double-submit duplicate** — the pay button posts on every click; two clicks = two charges, the retry = a third. Issue a single-use submission token; consume it transactionally with the write.
- **Mass-assignment / overposting** — `Object.assign(user, req.body)` lets the client send `{ "role": "admin" }`. Bind a named allowlist; set privileged fields server-side from the auth context.
- **Stored XSS via rich text** — a comment body saved raw and rendered with `v-html` runs `<script>` in every viewer's browser. Sanitize on input against an allowlist; escape on output.
- **Open public form** — a contact/signup form with no rate limit + no captcha gets 50k spam submissions / a password-reset enumeration probe overnight. Rate-limit per IP + identifier; add a bot gate.
- **Unbounded array** — `{ "items": [ ...100k... ] }` iterated into 100k inserts. Cap array length + field count + body size before iterating.
- **Inline file validation** — `if (file.name.endsWith('.png'))` then stored on the app origin. Extension lies; no magic-byte sniff; served same-origin = XSS. Hand off to the upload pipeline.
- **Opaque failure** — the API returns `400 "Invalid"` with no field map; the form can't highlight the bad input and drops the user's values. Return `{ field: messages[] }`; preserve values.
- **PII in logs** — `logger.warn('bad signup', req.body)` writes the email + password into the log store. Log field names + error codes, never values.

## Enforcement

- `<commands-path>/audit-form-handling.md` (slash: `/audit-form-handling`) — locates a specific submit handler at `<path:line>` and checks server-side validation, CSRF, idempotency, mass-assignment, error-to-field mapping, rate-limit/captcha, file fields, and PII-in-logs — cite-or-halt, never an assumed handler.
- `<agents-path>/forms-reviewer.md` — review gate hard-failing on client-only validation, missing CSRF, non-idempotent submit, mass-assignment, stored-XSS sinks, ungated public forms, unbounded payloads, inline file validation, opaque errors, and PII in logs.
- CI lint MUST reject whole-body bind sinks in handlers (`Object.assign(model, req.body)`, `{ ...req.body }` into a create/update, `Model(**request.data)`) — AST heuristic; flag for review.
- CI lint MUST reject raw HTML sinks (`innerHTML`/`v-html`/`dangerouslySetInnerHTML`) fed by request/DB-sourced strings.
- CI MUST assert each state-changing route is covered by CSRF middleware (or an explicit, justified exemption).
- TODO: `scripts/validate-form-handlers.sh` to AST-walk submit handlers and assert each one (1) re-validates against a shared schema, (2) binds a named allowlist, and (3) consumes an idempotency token before the write.

## Cross-references

- `<patterns-path>/form-handling.md` — shared-schema + CSRF + idempotent-submit + allowlist-bind + per-field-error + sanitize/escape + rate-limit code shapes.
- `<rules-path>/file-upload` — file fields hand off here: content-type allowlist, size cap, magic-byte sniff, off-origin storage, AV scan.
- `<rules-path>/rate-limit` — per-IP / per-identifier limits + bot gate for public/unauthenticated forms.
- `<rules-path>/auth` — session/CSRF token issuance + verification + the auth context privileged fields are set from.
- `<patterns-path>/report-generation.md § edge formatting/escaping` — money integer-minor-unit + locale/timezone edge parsing + output-escaping discipline reused for form values.
- `<commands-path>/audit-form-handling.md` — per-handler diagnostic.
- `<agents-path>/forms-reviewer.md` — review gate.
- `<adr-path>/<NNN>-form-validation-strategy.md` — ADR pinning the shared-schema library, the CSRF strategy, and the idempotency-token mechanism.
