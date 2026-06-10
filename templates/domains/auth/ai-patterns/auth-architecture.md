---
name: auth-architecture
description: "Pattern: Auth / identity architecture (AuthN/AuthZ split + policy engine + token service)"
kind: ai-pattern
---

# Pattern: Auth / identity architecture (AuthN/AuthZ split + policy engine + token service)

> **Hard rule** — AuthN (who you are) and AuthZ (what you may do) are separate layers; every protected operation resolves through a single `can(actor, action, resource)` policy and every object load is scoped to its owner / tenant (deny-by-default). Passwords use a memory-hard KDF (argon2id / bcrypt≥12); access tokens are short-lived with rotating, reuse-detected refresh tokens; tokens live in `httpOnly` cookies, never `localStorage`. No authorization decision is ever trusted from the client.

**When to apply**
- Any product with user accounts, roles, sessions, or API tokens.
- Multi-tenant or multi-role products where object access must be scoped per actor.
- Anything integrating OAuth2 / OIDC, MFA, passkeys, or an external identity provider (Auth0 / Cognito / Keycloak / Clerk).

**When NOT to apply**
- Fully public, read-only services with no per-user data (the policy layer is overhead).
- Machine-to-machine only via mTLS / signed-request schemes where there is no interactive user identity (different model — see service-to-service auth).
- Single-user local tools with no network surface.

**Halt conditions / mandatory cites**
- Cite the password hashing call (`argon2.hash` / `bcrypt.hash` with cost ≥ 12) at `<path:line>`. Any `md5` / `sha*` / plaintext on the password path = halt.
- Cite the central authorization primitive (`can()` / guard / policy) at `<path:line>` and at least one object-load query showing the ownership / tenant predicate. Inline `role === 'admin'` scattered across controllers, or `findById` with no scope = halt.
- Cite the token store at `<path:line>` — `httpOnly` cookie set, NOT `localStorage.setItem`. Token in web storage = halt.
- Cite the JWT verify call at `<path:line>` showing a pinned `algorithms` allowlist + `aud` + `iss` + `exp` validation. `alg: none` accepted or missing allowlist = halt.
- Cite the login rate-limit / lockout at `<path:line>` and confirm login errors are generic. Per-attempt unbounded login or "no such user" message = halt.
- Grep ban: "auth is handled by the framework / Auth0" without file:line for the hashing call, the policy primitive, the token store, the JWT verify, and the login rate-limit.

## Why

Auth is interchangeable in the abstract, deeply different in detail (session-store vs JWT, RBAC vs ABAC, Auth0 vs Cognito vs in-house). The right pattern is two thin layers — an **authentication** layer that establishes identity once, and an **authorization** layer that decides access per operation — with the identity provider and token library behind a SMALL project-internal interface. Feature code never imports `jsonwebtoken` or `@auth0/*` directly and never hand-rolls a role check.

This isolates: the credential-verification path, the session / token contract, the permission model, the MFA / step-up flow, and the OAuth handshake — so each can change without rippling through controllers.

## Token / auth service interface

```ts
// src/modules/auth/core/interfaces/auth.interface.ts

export interface TokenService {
  /** Issue a short-lived access token + a rotating refresh token bound to a family. */
  issue(actor: Actor, sessionId: string): Promise<{ accessToken: string; refreshToken: string }>;

  /** Verify an access token: pinned alg, aud/iss/exp validated. Throws on any failure. */
  verifyAccess(token: string): Promise<Actor>;

  /** Rotate: verify refresh, detect reuse, issue a new pair, revoke the consumed one. */
  rotate(refreshToken: string): Promise<{ accessToken: string; refreshToken: string }>;

  /** Revoke a whole token family (logout / compromise). */
  revokeFamily(familyId: string): Promise<void>;
}

export interface AuthorizationPolicy {
  /** The ONLY authorization primitive. Deny-by-default. */
  can(actor: Actor, action: Action, resource: Resource): boolean;
}

export type Actor = {
  userId: string;
  tenantId: string;        // scope for every object access
  roles: Role[];
  mfaSatisfied: boolean;   // false until a second factor is presented this session
  sessionId: string;
};
```

Feature code depends on `TokenService` + `AuthorizationPolicy`. No `jwt.verify` or `if (user.role === 'admin')` leaks into controllers.

## Password hashing

> The TypeScript example below uses argon2 + a NestJS-style service for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the KDF binding your stack ships (`argon2` / `bcrypt` / `passlib.argon2` / Spring `Argon2PasswordEncoder`), the DI mechanism, the config source for the pepper. The SHAPE — memory-hard KDF + per-user salt + optional pepper + constant-time verify + breach screen — is what's universal, not the specific library.

```ts
// src/modules/auth/core/services/password.service.ts

import * as argon2 from 'argon2';
import { createHash } from 'node:crypto';

@Injectable()
export class PasswordService {
  // Pepper lives in KMS / env — NOT the DB. Compromised DB alone can't crack hashes.
  private readonly pepper = env.PASSWORD_PEPPER;

  async hash(plain: string): Promise<string> {
    await this.assertNotBreached(plain);
    // argon2id: salt is generated + embedded by the lib; memoryCost ≥ 19 MiB.
    return argon2.hash(plain + this.pepper, {
      type: argon2.argon2id, memoryCost: 19_456, timeCost: 2, parallelism: 1,
    });
  }

  /** Constant-time verify is internal to argon2.verify — never compare hashes with ===. */
  verify(hash: string, plain: string): Promise<boolean> {
    return argon2.verify(hash, plain + this.pepper);
  }

  /** HIBP k-anonymity: send only the first 5 SHA-1 chars; never the password. */
  private async assertNotBreached(plain: string): Promise<void> {
    const sha1 = createHash('sha1').update(plain).digest('hex').toUpperCase();
    const [prefix, suffix] = [sha1.slice(0, 5), sha1.slice(5)];
    const res = await fetch(`https://api.pwnedpasswords.com/range/${prefix}`, {
      headers: { 'Add-Padding': 'true' },
    });
    const found = (await res.text()).split('\n').some(line => line.split(':')[0] === suffix);
    if (found) throw new BreachedPasswordError();
  }
}
```

The password never leaves the server in cleartext, and only 5 hash characters reach HIBP. Verification is the KDF's own constant-time routine — application code never compares hashes itself.

## Authorization policy (deny-by-default)

```ts
// src/modules/auth/core/services/policy.service.ts

@Injectable()
export class PolicyService implements AuthorizationPolicy {
  can(actor: Actor, action: Action, resource: Resource): boolean {
    // RBAC base: role → permitted actions.
    if (!this.roleGrants(actor.roles, action)) return false;          // deny-by-default

    // ABAC overlay: ownership / tenant scope. Identity ≠ authorization.
    if ('tenantId' in resource && resource.tenantId !== actor.tenantId) return false;
    if ('ownerId' in resource && action.requiresOwnership && resource.ownerId !== actor.userId) {
      return this.roleGrants(actor.roles, 'admin:override');          // explicit, not implicit
    }

    // Step-up: sensitive actions require a satisfied second factor this session.
    if (action.sensitive && !actor.mfaSatisfied) return false;

    return true;
  }
}
```

Every controller asks the SAME `can()` — there is one place to audit, one place to fix. The check fuses RBAC (role → action) with ABAC (tenant + ownership) and step-up, and defaults to denied.

## Guard + scoped object load (IDOR defense)

```ts
// src/modules/invoices/invoice.controller.ts

@Controller('/invoices')
@UseGuards(AuthGuard)                         // establishes Actor from the verified session/token
export class InvoiceController {
  constructor(
    @Inject(POLICY) private policy: AuthorizationPolicy,
    @Inject(INVOICE_REPO) private invoices: InvoiceRepository,
  ) {}

  @Get('/:id')
  async get(@Param('id') id: string, @CurrentActor() actor: Actor) {
    // Scope the QUERY by tenant — not a post-load if-check (which leaks existence via timing/404 shape).
    const invoice = await this.invoices.findScoped(id, actor.tenantId);
    if (!invoice) throw new NotFoundException();          // same shape for "not yours" and "absent"

    if (!this.policy.can(actor, READ_INVOICE, invoice)) throw new ForbiddenException();
    return invoice;
  }
}
```

```sql
-- The ownership predicate lives IN the query. No global findById on protected resources.
SELECT * FROM invoices WHERE id = :id AND tenant_id = :tenantId;
```

Changing the path id to another tenant's invoice returns the same `404` — no IDOR, no existence oracle.

## Session vs stateless JWT

| Axis | Server-side session store | Stateless JWT |
|---|---|---|
| Revocation | Instant (delete the row) | Hard — needs a blocklist or short TTL |
| Horizontal scale | Needs shared store (Redis) | No shared state for verify |
| Logout / compromise | Trivial | Requires revocation strategy |
| Payload size | Small cookie (session id) | Larger cookie / header (claims) |
| Best for | Web apps, "log out everywhere", admin | Service-to-service, short-lived API access |

Pick deliberately and record it in `ai/decisions/auth-session-strategy.md`. The common safe default for web: **server-side session id in an `httpOnly` cookie**, OR a short-lived JWT access token + rotating refresh token (below). Either way the cookie is `httpOnly` + `Secure` + `SameSite`.

```ts
// Session cookie — never readable by JS, never cross-site by default.
res.cookie('sid', sessionId, {
  httpOnly: true, secure: true, sameSite: 'lax', maxAge: IDLE_TIMEOUT_MS, signed: true,
});

// On login: ROTATE the session id (session-fixation defense) BEFORE marking authenticated.
await sessions.destroy(req.oldSessionId);
const sid = await sessions.create({ userId, tenantId, absoluteExpiry: now + ABSOLUTE_TTL });
```

## Rotating refresh tokens + reuse detection

```ts
// src/modules/auth/core/services/token.service.ts

async rotate(refreshToken: string): Promise<TokenPair> {
  const claims = await this.verifyRefresh(refreshToken);          // pinned alg, aud/iss/exp
  const stored = await this.refreshStore.find(claims.jti);

  // Reuse detection: a refresh token is single-use. Seeing a CONSUMED one = theft.
  if (!stored || stored.consumed) {
    await this.refreshStore.revokeFamily(claims.familyId);        // nuke the whole family
    throw new RefreshReuseDetectedError();                        // force full re-auth
  }

  await this.refreshStore.markConsumed(claims.jti);
  return this.issuePair(claims.actor, claims.familyId);           // new access + new refresh
}
```

A leaked refresh token is detected the moment either the legitimate client or the attacker uses the already-consumed token — the whole family is revoked and both must re-authenticate.

## JWT verify (pin alg, validate claims)

```ts
async verifyAccess(token: string): Promise<Actor> {
  const claims = jwt.verify(token, this.publicKey, {
    algorithms: ['RS256'],          // PIN it — never read alg from the header; rejects `none` + HS/RS confusion
    audience: env.JWT_AUDIENCE,     // this service only
    issuer: env.JWT_ISSUER,
    // exp / nbf validated by the lib when present; reject tokens missing exp
  });
  if (!claims.exp) throw new InvalidTokenError('missing_exp');
  if (await this.blocklist.has(claims.jti)) throw new RevokedTokenError();   // logout / compromise
  return this.toActor(claims);
}
```

## MFA / step-up

```ts
// TOTP enrol + verify; backup codes hashed at rest; step-up gates sensitive actions.
async verifyTotp(actor: Actor, code: string): Promise<void> {
  // Constant-time + small skew window; rate-limited like login.
  if (!totp.verify({ token: code, secret: await this.secretFor(actor), window: 1 })) {
    await this.rateLimiter.recordFailure(actor.userId);
    throw new InvalidMfaError();                    // generic — no "code expired" vs "wrong code" leak
  }
  await this.sessions.markMfaSatisfied(actor.sessionId);   // unlocks sensitive actions this session
}
```

Prefer WebAuthn / passkeys where the platform allows — phishing-resistant, no shared secret to steal. Backup codes are single-use and stored hashed (same KDF as passwords).

## OAuth2 / OIDC (auth-code + PKCE)

```ts
// Authorization-code flow with PKCE — never the implicit flow.
const verifier = randomString(64);
const challenge = base64url(sha256(verifier));
const state = randomString(32);                    // CSRF defense — verified on callback
session.set({ verifier, state });

redirect(`${provider.authorizeUrl}?response_type=code` +
  `&client_id=${CLIENT_ID}&redirect_uri=${ALLOWLISTED_REDIRECT}` +
  `&code_challenge=${challenge}&code_challenge_method=S256&state=${state}&nonce=${nonce}`);

// Callback:
if (query.state !== session.get('state')) throw new CsrfError();         // state mismatch
const tokens = await provider.exchange(query.code, session.get('verifier'));
const idClaims = jwt.verify(tokens.id_token, providerJwks, {
  algorithms: ['RS256'], audience: CLIENT_ID, issuer: provider.issuer,
});
if (idClaims.nonce !== session.get('nonce')) throw new ReplayError();
```

The `redirect_uri` is matched against an exact allowlist; `state` blocks login-CSRF; PKCE binds the code to the originating client; the id-token signature + `aud` + `iss` + `nonce` are all validated.

## Account lifecycle (secure reset)

```ts
async requestReset(email: string): Promise<void> {
  const user = await this.users.findByEmail(email);
  // ALWAYS the same response + timing — no enumeration. Only act if the user exists.
  if (user) {
    const raw = randomString(32);
    await this.resetTokens.create({
      userId: user.id, tokenHash: sha256(raw), expiresAt: now + ONE_HOUR, used: false,
    });
    await this.email.sendReset(email, raw);          // raw token only in the email, never stored
  }
  // (no else — return identically)
}

async consumeReset(rawToken: string, newPassword: string): Promise<void> {
  const row = await this.resetTokens.findValid(sha256(rawToken));   // unused + unexpired
  if (!row) throw new InvalidResetTokenError();
  await this.passwords.setForUser(row.userId, newPassword);          // hashes + breach-screens
  await this.resetTokens.markUsed(row.id);                           // single-use
  await this.tokens.revokeAllSessions(row.userId);                   // invalidate everything
}
```

Tokens are stored hashed, single-use, short-expiry; a password change revokes all sessions. Email change re-verifies the new address before it becomes the login identity.

## Common mistakes

### Plaintext / fast-hash passwords
`sha256(password)` "because it's hashed." GPUs crack unsalted fast hashes at billions/sec. Use argon2id / bcrypt≥12 with a per-user salt + optional pepper.

### JWT in localStorage
"The SPA reads it for the Authorization header." Any XSS reads `localStorage` and exfiltrates a bearer token with no revocation. Use an `httpOnly` cookie + CSRF token.

### IDOR / missing ownership check
`findById(id)` then return. Change the path id, read another tenant's data. Scope the QUERY (`WHERE id AND tenant_id`), don't post-load if-check.

### Client-side authorization
Hiding the admin button but leaving `DELETE /users/:id` unguarded. The button is UX; the endpoint is the control. Re-check on the server every time.

### User enumeration
Login says "no such email" vs "wrong password"; reset says "email not found." Attackers harvest valid accounts. One generic message + uniform timing.

### `alg: none` / key confusion
Verifier trusts the header's `alg`. Attacker re-signs with `none` or feeds the RS256 public key as an HMAC secret. Pin a fixed `algorithms` allowlist server-side.

### Long-lived non-rotating tokens
A 30-day access token = a 30-day skeleton key if leaked, with no revocation. Short access (5–15m) + rotating refresh + reuse-detection.

### No logout revocation
"Logout" clears the cookie but the JWT / session stays valid. Stolen token survives logout. Revoke server-side (delete session / blocklist jti / revoke family).

### Session fixation
Pre-login session id kept after login; an attacker who planted the id rides the authenticated session. Rotate the id on login.

### No rate-limit on login
Credential-stuffing runs unbounded; one weak password = takeover. Per-account + per-IP limits + progressive lockout.

### Reset token reuse
Reset link works repeatedly or after the password already changed. Single-use, expiring, hashed at rest, invalidated on use + on any password change.

### Trusting client role / tenant
`POST /admin { role: 'admin' }` or a `tenant_id` from the body. Derive identity + scope from the verified session / token only.

## Cross-references

- `<rules-path>/auth-discipline.md` — the hard-rule list (AuthN/AuthZ split, hashing, sessions, tokens, MFA, OAuth, rate-limit, IDOR, lifecycle).
- `<commands-path>/audit-access-control.md` — IDOR / authorization-coverage audit (endpoint × actor × ownership-check at `<path:line>`).
- `<agents-path>/auth-reviewer.md` — review gate enforcing this pattern.
- `<rules-path>/webhook-signature-verification.md` — constant-time compare + secret hygiene (shared discipline).
- `<patterns-path>/payment-integration.md` — server-as-source-of-truth analogue (never trust client amount ↔ never trust client role / scope).
- `<adr-path>/<NNN>-auth-session-strategy.md` — ADR pinning session-vs-JWT, token TTLs, MFA policy, identity provider.
