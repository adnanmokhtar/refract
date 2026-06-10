---
description: Audit a specific form / submit handler — server-side validation, CSRF, idempotency, mass-assignment, error-to-field mapping, rate-limit/captcha, file fields, and PII-in-logs — against the REAL handler code, never an assumed one.
---

# /audit-form-handling

Diagnose whether a specific form submission path is safe: does the server re-validate, is the post CSRF-protected, is it idempotent, does it bind an allowlist (not the whole body), do errors map to fields — read from the REAL handler, not a guess.

## Premise

Real signals only. Cite the actual submit handler at `<path:line>`, the shared schema import on BOTH client and server `<path:line>`, the CSRF check `<path:line>`, the idempotency consume `<path:line>`, the binding site `<path:line>`, and any rich-HTML / file / log sink `<path:line>` — never narrate a handler you didn't open. Read before auditing: locate the route, the handler, and the schema in source and confirm the request shape BEFORE issuing a verdict.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the handler at `<path:line>`, (2) the server-side validation verdict with the schema at `<path:line>` (or "CLIENT-ONLY — finding"), (3) the CSRF verdict at `<path:line>` (or "MISSING — CSRF hole"), (4) the idempotency verdict at `<path:line>` (or "NON-IDEMPOTENT — double-submit"), (5) the binding verdict at `<path:line>` (allowlist vs. whole-body mass-assignment), and (6) the error-to-field, rate-limit/captcha, file-field, and PII-in-logs verdicts. If any cannot be produced from real code, HALT and say which — never an assumed handler, never an assumed schema.

This audit is READ-ONLY. It does not submit the form, does not mutate state, and does not fix code — it locates, reads, and reports.

## What it does

1. **Locate** the route + handler in source — cite `<path:line>` and the exact handler signature.
2. **Server-side validation** — is the body re-validated against a schema on the SERVER? Cite the schema run `<path:line>`. Confirm the SAME schema module is imported client-side too (`<path:line>`). If validation is client-only and the server does `repo.create(req.body)` → CLIENT-ONLY finding (the server is the boundary).
3. **CSRF** — for a state-changing method, is there a token / double-submit / origin check verified server-side before the handler? Cite `<path:line>`; if absent → CSRF hole.
4. **Idempotency / double-submit** — is a single-use token / natural key checked-and-consumed atomically with the write? Cite `<path:line>`; if the write fires on every submit → NON-IDEMPOTENT finding (double-click duplicates).
5. **Mass-assignment** — is binding a named allowlist, or `Object.assign(model, req.body)` / `{ ...req.body }` / `Model(**data)` / `update(req.body)`? Cite the binding `<path:line>`; whole-body bind → mass-assignment finding (overposting `role`/`tenantId`/`price`).
6. **Error-to-field mapping** — does a validation failure return `{ field: messages[] }` the UI can bind, or an opaque 400/500? Cite `<path:line>`.
7. **Rate-limit / captcha** — for a public/unauthenticated form, is there a per-IP + per-identifier rate limit and a bot gate? Cite `<path:line>`; if absent → abuse finding.
8. **File fields** — does a file input delegate to the upload pipeline (allowlist + size + magic-byte + off-origin + scan), or validate inline? Cite `<path:line>`.
9. **Payload bounds** — body size, field count, string length, array length capped before iteration? Cite `<path:line>`.
10. **PII in logs** — is the raw body / email / password echoed into a log line or error? Cite `<path:line>`.
11. **Report** — per-check verdict, the top fix, and an overall verdict.

## Flow

```text
locate route + handler (<path:line>)
  -> server re-validates against shared schema?    [CLIENT-ONLY finding if not]
  -> CSRF verified server-side (state-changing)?   [BLOCKER if missing]
  -> idempotent (single-use token consumed)?       [BLOCKER if writes every submit]
  -> binds a named allowlist (not whole body)?     [BLOCKER if mass-assignment]
  -> rich/HTML input sanitized + escaped?          [BLOCKER if raw sink]
  -> errors map back to fields?                    [finding if opaque]
  -> public form rate-limited + bot-gated?         [finding if ungated]
  -> payload bounded (size/fields/strings/arrays)? [finding if unbounded]
  -> file fields delegate to upload pipeline?      [finding if inline]
  -> PII kept out of logs/errors?                  [finding if echoed]
  -> report: per-check verdict + top fix
```

## Output

```
/audit-form-handling — <form type> @ <path:line>

Handler (<path:line>):
  @Post('/account/profile') updateProfile(@Body() raw, @Ctx() ctx)

Server validation:  re-validated  ProfileForm.safeParse @ controller.ts:22   [or: CLIENT-ONLY — finding]
Shared schema:      same module imported client @ form.tsx:14 + server @ controller.ts:3   [or: DIVERGENT copies]
CSRF:               CsrfGuard double-submit + origin @ csrf.guard.ts:9        [or: MISSING — CSRF hole]
Idempotency:        single-use token, INSERT ON CONFLICT @ idem.ts:11         [or: NON-IDEMPOTENT — double-submit]
Binding:            named allowlist @ controller.ts:34                        [or: Object.assign(user, raw) — mass-assignment]
Rich input:         sanitizeRichText on bio @ controller.ts:31 + escaped out  [or: raw v-html — stored XSS]
Error mapping:      { fieldErrors } 422 @ controller.ts:24                    [or: opaque 400 — finding]
Rate limit/captcha: n/a (authenticated)                                       [or: PUBLIC + UNGATED — abuse]
Payload bounds:     body 64kb, .max() per field, tags.max(20) @ schema.ts     [or: UNBOUNDED array — finding]
File fields:        none                                                      [or: inline ext check — finding]
PII in logs:        none                                                      [or: logger.warn(req.body) — finding]

Verdict: OK | NEEDS-CSRF | NEEDS-IDEMPOTENCY | MASS-ASSIGNMENT | CLIENT-ONLY | BLOCKER

Top recommendation:
  - <e.g. add CsrfGuard to the route; bind a named allowlist; consume a single-use token before the write>
```

## Rules

- READ-ONLY. Never submit the form, never mutate state, never edit code — locate, read, report.
- Cite-or-halt: real handler, real schema, real CSRF check, real binding site, real log sink — or halt naming what's missing.
- Always print the server-validation verdict first; CLIENT-ONLY validation is a security hole, not a style nit.
- A whole-body bind is mass-assignment even if "the model only has safe fields today" — fields get added; the allowlist is the boundary.
- A state-changing post with no CSRF check is a BLOCKER even if "it's behind login" — the cookie is what the attack rides.
- Never report a verdict you didn't read from the actual handler.

## Cross-references

- `.claude/rules/forms-discipline.md` — the hard-rule list this command enforces (server re-validate, CSRF, idempotency, allowlist, sanitize/escape, bounds, rate-limit, error-to-field, PII).
- `ai/patterns/form-handling.md` — the shared-schema + CSRF + idempotent-submit + allowlist-bind + per-field-error code shapes.
- `<rules-path>/file-upload` — where file fields must delegate.
- `<rules-path>/rate-limit` — per-IP/identifier limits + bot gate for public forms.
- `<agents-path>/forms-reviewer.md` — review gate that consumes these findings.
