---
name: form-handling
description: "Pattern: Form handling (server-validated, CSRF-safe, idempotent submission)"
kind: ai-pattern
---

# Pattern: Form handling (server-validated, CSRF-safe, idempotent submission)

> **Hard rule** — One shared validation schema runs on BOTH the client (UX) and the server (the trust boundary); the client result is never trusted. Every state-changing post verifies CSRF server-side. Submission is idempotent via a single-use token so a double-click / retry / replay yields ONE record. The handler binds an explicit field ALLOWLIST — never the whole body (mass-assignment). Rich input is sanitized on input and escaped on output. Public forms are rate-limited + bot-gated; payload size, field count, and array length are bounded. Errors map back to fields; PII never lands in logs.

**When to apply**
- Any form / action that CHANGES state: signup, profile edit, checkout, comment, settings, password change, admin actions.
- Server-rendered form posts AND SPA/API submissions (fetch/XHR to a JSON endpoint) — the server-side rules are identical.
- Public/unauthenticated forms (contact, signup, password-reset) — which additionally need rate-limit + bot-gating.

**When NOT to apply**
- A read-only `GET` filter/search form with no side effect — no CSRF/idempotency token needed (still validate + bound inputs).
- A purely local UI control (a client-side filter that never hits the server) — no server boundary to defend.
- A trusted server-to-server webhook — that's signature/HMAC verification, a different pattern, not a user form.

**Halt conditions / mandatory cites**
- Cite the SHARED schema imported by both client and server at `<path:line>` (both sides). A client-only validation with the server doing `repo.create(req.body)` = halt.
- Cite the CSRF verification on the state-changing route at `<path:line>`. A mutating post with no token/origin check = halt.
- Cite the idempotency token issue + atomic consume at `<path:line>`. A write with no double-submit guard = halt.
- Cite the explicit field-allowlist binding at `<path:line>`. `Object.assign(model, req.body)` / `{ ...req.body }` into a create = halt (mass-assignment).
- Cite the sanitize-on-input + escape-on-output for any rich/HTML field, the payload bounds, and (for public forms) the rate-limit + bot gate at `<path:line>` each.
- Grep ban: "the form is validated / safe / can't double-submit" without file:line for the server schema run, the CSRF check, the idempotency consume, and the allowlist bind.

## Why

A form is the place untrusted input becomes trusted state, so every form failure reaches users directly:

1. **It trusts the client** — validation enforced only in the component is bypassed by curl / devtools / a patched bundle. The server must re-validate against the SAME schema; the client copy is UX only.
2. **It gets replayed / forged** — without CSRF a cross-site page auto-submits the form under the victim's cookie; without an idempotency token a double-click charges twice. Both are submission-integrity failures.
3. **It overposts** — binding the whole body to the model lets the client set `role`/`tenantId`/`price`. The handler must bind a named allowlist and set privileged fields server-side.
4. **It stores a payload** — unsanitized HTML becomes stored XSS; an unbounded array becomes a DoS. Sanitize/escape and bound the payload.

The pattern: declare ONE schema, run it both sides, verify CSRF, consume a single-use submission token, bind an allowlist, sanitize/escape rich fields, bound the payload, map errors to fields — and hand file fields to the upload pipeline.

## Shared schema (the single source of truth)

```ts
// src/modules/account/profile.schema.ts  — imported by BOTH client and server

import { z } from 'zod';

export const ProfileForm = z.object({
  displayName: z.string().trim().min(1).max(80),
  bio:         z.string().max(2_000).optional(),            // rich text — sanitized below
  email:       z.string().trim().toLowerCase().email(),     // normalized at the edge
  phone:       z.string().regex(E164).optional(),
  tags:        z.array(z.string().max(40)).max(20),         // array length BOUNDED → no DoS
}).strict();                                                 // .strict() rejects unknown keys (overposting guard)

export type ProfileForm = z.infer<typeof ProfileForm>;
// NOTE: role, isAdmin, tenantId, plan are NOT in the schema — they are server-set, never client-bindable.
```

The client imports this for inline UX validation; the server imports the SAME module as the boundary. There is exactly one schema — two hand-kept copies drift and the drift is the bug.

## Server handler: re-validate, verify CSRF, consume token, bind allowlist

> The TypeScript below uses Express/Nest-style middleware + helpers for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the framework (Express / FastAPI / Rails / Spring), the CSRF middleware it ships, the schema lib (Zod / Pydantic / Yup), and the repository binding. The SHAPE — re-validate against the shared schema → verify CSRF → consume the idempotency token → bind a named allowlist → write → map errors to fields — is what's universal.

```ts
// src/modules/account/profile.controller.ts

@Post('/account/profile')
@UseGuards(CsrfGuard)                                    // ← CSRF verified server-side BEFORE the handler runs
async updateProfile(
  @Body() raw: unknown,
  @Headers('idempotency-key') idemKey: string,
  @Ctx() ctx: AuthContext,                              // tenant + permissions + userId come from HERE
  @Res() res,
) {
  // 1. RE-VALIDATE on the server against the shared schema. The client result is never trusted.
  const parsed = ProfileForm.safeParse(raw);
  if (!parsed.success) {
    return res.status(422).json({ fieldErrors: toFieldErrors(parsed.error) });   // per-field map
  }
  const input = parsed.data;                            // typed, normalized, unknown keys already stripped

  // 2. IDEMPOTENT submission — single-use token consumed atomically with the write.
  //    A double-click / retry / back-button replay collapses to ONE record.
  const claim = await this.idem.claim(idemKey, { user: ctx.userId, form: 'profile' });
  if (claim.replay) return res.status(200).json(claim.result);   // same token → return the prior result

  // 3. EXPLICIT field allowlist — bind named fields only. NEVER Object.assign(user, raw).
  //    role / isAdmin / tenantId / plan are server-set, never taken from input.
  const patch = {
    displayName: input.displayName,
    email:       input.email,
    phone:       input.phone,
    tags:        input.tags,
    bio:         sanitizeRichText(input.bio),           // 4. SANITIZE rich/HTML input on the way IN
    tenantId:    ctx.tenantId,                           // server-set from the auth context, not the body
  };

  const updated = await this.repo.updateProfile(ctx.userId, patch);   // named columns only
  const result  = { id: updated.id };
  await this.idem.complete(idemKey, result);            // consume the token transactionally
  return res.status(200).json(result);
}

/** Map a Zod error to { field: messages[] } so the UI can highlight inputs and preserve values. */
function toFieldErrors(err: z.ZodError): Record<string, string[]> {
  const out: Record<string, string[]> = {};
  for (const issue of err.issues) {
    const field = issue.path.join('.') || '_form';
    (out[field] ??= []).push(issue.message);            // codes/messages only — NEVER the submitted value
  }
  return out;
}
```

The server re-runs the schema, verifies CSRF, consumes a single-use token, and binds a named allowlist. No client trust, no replay, no overposting.

## CSRF verification (state-changing posts only)

```ts
// src/common/csrf.guard.ts  — double-submit cookie + SameSite-anchored origin check

@Injectable()
export class CsrfGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    if (SAFE_METHODS.has(req.method)) return true;       // GET/HEAD/OPTIONS are exempt

    // Double-submit: header token must equal the SameSite=strict cookie token.
    const header = req.headers['x-csrf-token'];
    const cookie = req.cookies['csrf'];
    if (!header || !cookie || !timingSafeEqual(header, cookie)) {
      throw new ForbiddenException('csrf_token_mismatch');
    }
    // Defense in depth: reject cross-site origins outright.
    const site = req.headers['sec-fetch-site'];
    if (site && site !== 'same-origin' && site !== 'same-site') {
      throw new ForbiddenException('cross_site_origin');
    }
    return true;
  }
}
```

Every mutating route is guarded; the token is issued on form render (see `<rules-path>/auth`) and verified before the handler body runs.

## Idempotent submission (no double-submit duplicates)

```ts
// src/common/idempotency.service.ts  — atomic check-and-claim, single-use, scoped to user + form

@Injectable()
export class IdempotencyService {
  async claim(key: string, scope: { user: string; form: string }) {
    if (!key) throw new BadRequestException('missing_idempotency_key');
    // INSERT ... ON CONFLICT DO NOTHING — the unique index makes the claim atomic across racing clicks.
    const row = await this.db.query(
      `INSERT INTO idempotency_keys (key, user_id, form, status)
       VALUES ($1, $2, $3, 'in_progress')
       ON CONFLICT (key) DO NOTHING
       RETURNING id`,
      [key, scope.user, scope.form],
    );
    if (row.length === 0) {
      // Key already exists → this is a replay. Return the stored result if the first call completed.
      const prior = await this.db.query(`SELECT status, result FROM idempotency_keys WHERE key = $1`, [key]);
      return { replay: true, result: prior[0]?.result ?? null };
    }
    return { replay: false };
  }

  async complete(key: string, result: unknown) {
    await this.db.query(
      `UPDATE idempotency_keys SET status = 'done', result = $2 WHERE key = $1`,
      [key, result],
    );
  }
}
```

The unique index on `key` is the lock: two simultaneous clicks race the `INSERT`; exactly one wins and writes the record, the loser gets `replay: true` and the same result. One submission, one record.

## Sanitize rich input on input; escape on output

```ts
// src/common/sanitize.ts

import createDOMPurify from 'dompurify';
import { JSDOM } from 'jsdom';
const DOMPurify = createDOMPurify(new JSDOM('').window);

/** Strip every tag/attr outside the allowlist BEFORE the value is stored. */
export function sanitizeRichText(html: string | undefined): string | undefined {
  if (html == null) return html;
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'ul', 'ol', 'li', 'br'],
    ALLOWED_ATTR: ['href'],
    ALLOWED_URI_REGEXP: /^https?:/,                      // no javascript: / data: URIs
  });
}
```

```tsx
// Output: escape by default; only render sanitized HTML, and even then via a guarded sink.
<p>{user.displayName}</p>                                {/* React escapes by default — safe */}
<div dangerouslySetInnerHTML={{ __html: sanitizeRichText(user.bio) }} />  {/* re-sanitized at the edge */}
// NEVER: <div dangerouslySetInnerHTML={{ __html: user.bio }} />  ← raw DB string = stored XSS
```

Sanitize on input AND escape/guard on output — input sanitization can be bypassed by a different write path, so the rendering edge is the last line of defense.

## Public form: rate-limit + bot gate + bounded payload

```ts
// src/modules/contact/contact.controller.ts  — UNAUTHENTICATED form

@Post('/contact')
@UseGuards(CsrfGuard)
@Throttle({ limit: 5, ttl: 60 })                         // per-IP rate limit — see <rules-path>/rate-limit
async submit(@Body() raw: unknown, @Ip() ip: string, @Req() req) {
  await this.limiter.consume(`contact:${normalizeEmail(raw)}`);   // also limit per-identifier

  // Bot gate: CAPTCHA token + honeypot hidden field. Both must pass before any work.
  if (!(await this.captcha.verify(req.headers['x-captcha-token'], ip))) {
    throw new ForbiddenException('captcha_failed');
  }
  if (raw && (raw as any).website) throw new ForbiddenException('honeypot');   // bots fill hidden fields

  const parsed = ContactForm.safeParse(raw);             // schema also BOUNDS sizes: .max() on every field
  if (!parsed.success) return { fieldErrors: toFieldErrors(parsed.error) };
  // ... enqueue / store ...
}
```

```ts
// Payload bounds enforced at the framework edge, BEFORE parsing the body:
app.use(express.json({ limit: '64kb' }));                // max body size
app.use(fieldCountLimit(50));                            // max field count
// + .max(N) on every string and .max(K) on every array in the schema → bounded length & array count
```

Unauthenticated forms are rate-limited per IP AND per identifier, gated by CAPTCHA + honeypot, and the payload is bounded on every axis — size, field count, string length, array length.

## File fields hand off to the upload pipeline

```ts
// A form with a file field does NOT validate the file inline. It delegates to the upload pipeline.
const ticket = await this.uploads.issueTicket({       // see <rules-path>/file-upload
  userId: ctx.userId,
  field: 'avatar',
  contentTypeAllowlist: ['image/png', 'image/jpeg'],
  maxBytes: 5_000_000,
});
// Client uploads directly to the off-origin store with the ticket; the form stores only the returned key.
// The pipeline does: content-type allowlist + size cap + magic-byte sniff + off-origin storage + AV scan.
```

`if (file.name.endsWith('.png'))` is not validation — the extension lies, there's no magic-byte sniff, and app-origin storage turns an uploaded `.html` into stored XSS. Always hand off to `<rules-path>/file-upload`.

## Common mistakes

### Client-only validation
Required/format/length enforced only in the component; the API does `repo.create(req.body)`. curl bypasses everything. Run the SAME schema on the server — the server is the boundary.

### Missing CSRF
A cookie-session mutating post with no token; a cross-site page auto-submits it under the victim's session. Verify a double-submit token / synchronizer token + origin server-side on every mutating route.

### Non-idempotent submit
The pay button writes on every click → two clicks, two charges; the retry, a third. Issue a single-use token; consume it atomically (`INSERT ... ON CONFLICT`) with the write.

### Mass-assignment / overposting
`Object.assign(user, req.body)` / `{ ...req.body }` into a create lets the client send `{ "role": "admin" }`. Bind a named allowlist; set privileged fields from the auth context.

### Stored XSS via rich text
A comment saved raw and rendered with `dangerouslySetInnerHTML` / `v-html` runs `<script>` for every viewer. Sanitize against an allowlist on input; escape/guard on output.

### Ungated public form
A contact/signup form with no rate limit + no captcha gets flooded / enumerated overnight. Rate-limit per IP + identifier; add CAPTCHA + honeypot.

### Unbounded payload
`{ "items": [ ...100k... ] }` iterated into 100k inserts; a 10MB JSON blob OOMs the parser. Cap body size, field count, string length, array length before iterating.

### Inline file validation
Extension-only check, no magic-byte sniff, stored on the app origin. Delegate to the upload pipeline.

### Opaque error
`400 "Invalid"` with no field map → the UI can't highlight the bad input and drops the user's values. Return `{ field: messages[] }`; preserve entered values.

### PII in logs
`logger.warn('bad signup', req.body)` writes the email + password into the log store. Log field names + error codes, never the submitted values.

### Divergent schema copies
A client schema and a separately hand-kept server schema drift; a rule tightened on one side isn't on the other. Import ONE shared module on both sides.

## Cross-references

- `<rules-path>/forms-discipline.md` — the hard-rule list (server re-validate, CSRF, idempotency, allowlist, sanitize/escape, bounds, rate-limit, error-to-field, PII).
- `<rules-path>/file-upload` — file fields hand off here: content-type allowlist, size cap, magic-byte sniff, off-origin storage, AV scan.
- `<rules-path>/rate-limit` — per-IP / per-identifier limits + bot gate for public/unauthenticated forms.
- `<rules-path>/auth` — CSRF/session token issuance + verification + the auth context privileged fields are set from.
- `<patterns-path>/report-generation.md § edge formatting/escaping` — integer-minor-unit money + locale/timezone edge parsing + output-escaping discipline reused for form values.
- `<commands-path>/audit-form-handling.md` — per-handler diagnostic.
- `<agents-path>/forms-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-form-validation-strategy.md` — ADR pinning the shared-schema library, the CSRF strategy, and the idempotency mechanism.
