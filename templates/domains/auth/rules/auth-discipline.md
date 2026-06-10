---
name: auth-discipline
description: Auth / identity discipline
kind: rule
---

# Auth / identity discipline

## Hard rule

AuthN (who you are) and AuthZ (what you may do) MUST be separated — identity is established once, authorization is enforced per object access. Every object access MUST verify ownership / tenant scope server-side; deny-by-default. Authorization decisions MUST NEVER be made on the client. Passwords MUST be stored with argon2id (or bcrypt cost ≥ 12) + per-user salt — plaintext / MD5 / SHA-* / unsalted hashes are FORBIDDEN. Access tokens MUST be short-lived; refresh tokens MUST rotate with reuse-detection. Tokens MUST NEVER be stored in `localStorage` / `sessionStorage` — only `httpOnly` `Secure` `SameSite` cookies. Login / password-reset / MFA endpoints MUST be rate-limited + return generic errors (no user enumeration). Session ids MUST rotate on privilege change (login / step-up); logout MUST revoke server-side. All secret comparisons MUST be constant-time.

A broken auth check is never just a bug — it is account takeover, a tenant data breach, a regulator notification, a headline. Review with paranoia.

## Must

- **Separate AuthN from AuthZ.** Identity established once (login / token verify); authorization enforced at every protected operation via a policy / guard layer. Mixing them (e.g. "logged in ⇒ allowed") is the root of broken access control.
- **Policy / guard pattern.** Every protected route resolves through a single authorization primitive — a guard, middleware, or `can(actor, action, resource)` policy function. No ad-hoc `if (user.role === 'admin')` scattered across controllers.
- **Deny-by-default.** The base posture is "denied"; access is granted only by an explicit matching rule. New endpoints are protected unless deliberately marked public.
- **Ownership / tenant scope on every object access.** Loading resource `id` from a route param requires `WHERE id = :id AND tenant_id = :ctxTenant` (or an equivalent ownership predicate). Never `findById(id)` then return without a scope check.
- **Least privilege.** Roles / permissions grant the minimum needed. Service accounts, API keys, and tokens carry the narrowest scope that works.
- **Password storage**: argon2id (memory ≥ 19 MiB, iterations ≥ 2) OR bcrypt cost ≥ 12 OR scrypt. Per-user random salt (the KDF handles this). Pepper optional, stored separately from the DB (env / KMS). Verify with the KDF's own constant-time verify.
- **Password policy + breach check.** Enforce length ≥ 12 (NIST: length over composition rules); screen against a breached-password list via HIBP range API (k-anonymity — send only the first 5 chars of the SHA-1 hash, never the password).
- **Sessions**: pick server-side session store OR stateless JWT deliberately and document the trade-off. Session cookies are `httpOnly` + `Secure` + `SameSite=Lax|Strict`. Rotate the session id on login (session-fixation defense). Enforce BOTH an absolute timeout (e.g. 12h) and an idle timeout (e.g. 30m). Logout deletes the server-side session / revokes the token — not just the cookie.
- **Tokens / JWT**: short-lived access token (5–15 min); rotating refresh token (single-use, new one issued on each refresh). Detect refresh-token reuse → revoke the whole token family + force re-auth. Pin `alg` to an allowlist (reject `none`, reject HS↔RS confusion). Validate `aud`, `iss`, `exp`, `nbf` on every verify. Maintain a revocation / blocklist (or short TTL + server-side session) so logout / compromise can invalidate.
- **MFA / 2FA**: support TOTP (RFC 6238) and/or WebAuthn / passkeys. Issue single-use backup codes (hashed at rest). Require step-up auth (re-prompt for a factor) before sensitive actions (change email / password, disable MFA, view secrets, admin ops).
- **OAuth2 / OIDC**: authorization-code flow with PKCE (never the implicit flow). Generate + verify a `state` parameter (CSRF defense) and a `nonce` (replay defense for OIDC id tokens). Redirect URIs validated against an exact allowlist. Validate the id-token signature + `aud` + `iss` + `exp`.
- **Brute-force / abuse**: rate-limit + progressive lockout on login, password-reset, and MFA-verify endpoints (per-account AND per-IP). Generic, identical error + timing on "bad username" vs "bad password" (no user enumeration). Constant-time compare for all secrets / tokens / MFA codes.
- **Account lifecycle**: password reset uses a single-use, short-expiry (≤ 1h), high-entropy token, stored hashed, invalidated after use AND on password change. Email change re-verifies the new address before it becomes the login identity. Invitation flows use single-use expiring tokens scoped to the inviting tenant.
- **CSRF defense** on any cookie-authenticated state-changing request — `SameSite` cookies plus a synchronizer / double-submit token; do not rely on `SameSite` alone for `Lax`-bypassable methods.

## Must not

- Store passwords as plaintext, MD5, SHA-1/256 (unsalted or single-pass), or any non-KDF hash.
- Make any authorization decision on the client (hiding a button is UX, not access control — the API MUST re-check).
- `findById(id)` and return the resource without an ownership / tenant-scope predicate (IDOR).
- Store access or refresh tokens in `localStorage` / `sessionStorage` / non-`httpOnly` cookies — XSS then exfiltrates them.
- Accept a JWT with `alg: none`, or verify an RS256-issued token with the public key fed as an HMAC secret (key-confusion).
- Issue long-lived, non-rotating access tokens, or refresh tokens that never rotate / never expire.
- Skip `aud` / `iss` / `exp` validation ("it's our own token") — a token minted for another service / replayed after expiry then passes.
- Return distinct errors / status codes / timings for "no such user" vs "wrong password" vs "account locked" (user enumeration).
- Compare passwords / tokens / MFA codes with `===` / `==` / variable-time string compare.
- Reuse a session id across the unauthenticated → authenticated boundary (session fixation).
- Logout that only clears the cookie client-side while the server session / refresh token stays valid.
- Send the raw password (or full hash) to any third party for breach-checking — HIBP k-anonymity sends 5 hash chars only.
- Trust `role` / `tenant_id` / `is_admin` from a request body, query param, or a JWT claim that the client can mint.

## Should

- Wrap the identity provider / token library behind a project-internal `<AuthProvider>` / `<TokenService>` interface so a provider swap (Auth0 ↔ Cognito ↔ in-house) is a single-file refactor.
- Prefer WebAuthn / passkeys over TOTP where the platform allows (phishing-resistant, no shared secret).
- Centralize the permission model (RBAC roles → permissions map, or ABAC policy table) in one module; never inline role strings in controllers.
- Bind refresh tokens to a device / client fingerprint and surface active sessions to the user with per-session revoke.
- Log structured auth events (`{ event, actorId, ip, ua, outcome, mfaUsed, correlationId }`) for login, logout, failed-login, lockout, password-change, MFA-enroll, token-refresh, reuse-detected — never log the password, token, or code.
- Alert on auth anomalies: spike in failed logins, refresh-reuse detections, lockouts, impossible-travel logins.
- Re-verify (step-up) before showing or changing security-sensitive data even within an active session.

## Review checklist (PRs touching auth / sessions / tokens / protected routes)

- [ ] New protected route resolves through the central guard / policy; not an inline role check.
- [ ] Every object load by id includes an ownership / tenant-scope predicate (cite the `WHERE`).
- [ ] No authorization decision is made client-side that the API does not independently re-enforce.
- [ ] Passwords hashed with argon2id / bcrypt≥12 / scrypt; verify uses the KDF's constant-time compare.
- [ ] New-password path screens against HIBP (k-anonymity range query) and enforces length ≥ 12.
- [ ] Session id rotates on login; absolute + idle timeouts enforced; logout revokes server-side.
- [ ] Tokens are not in `localStorage`; access token TTL ≤ 15m; refresh rotates with reuse-detection.
- [ ] JWT verify pins `alg`, validates `aud` / `iss` / `exp`; no `none`, no HS/RS confusion.
- [ ] Login / reset / MFA endpoints are rate-limited + lockout; errors are generic (no enumeration).
- [ ] All secret / token / code comparisons are constant-time.
- [ ] OAuth flows use auth-code + PKCE + `state`; redirect URIs allowlisted.
- [ ] Password-reset token is single-use, short-expiry, hashed at rest, invalidated on use + on password change.
- [ ] Sensitive actions require step-up / re-auth.

## Anti-patterns

- **Plaintext / fast-hash passwords** — `sha256(password)` "because it's hashed." GPUs crack unsalted fast hashes at billions/sec. Use a memory-hard KDF.
- **JWT in localStorage** — "the SPA needs it." Any XSS reads it instantly and exfiltrates a bearer token with no revocation. Use an `httpOnly` cookie + CSRF token.
- **IDOR** — `GET /api/invoices/:id` → `invoiceRepo.findById(id)` with no owner check. Change the id, read another tenant's invoice. Scope every query.
- **Client-side authorization** — hiding the "Delete" button for non-admins but leaving `DELETE /users/:id` unguarded. The button is UX; the endpoint is the control.
- **User enumeration** — login returns "no such email" vs "wrong password", or reset returns "email not found." Attackers harvest valid accounts. Return one generic message + uniform timing.
- **`alg: none` / key confusion** — verifier accepts the header's `alg`. Attacker re-signs with `none` or feeds the RS256 public key as an HMAC secret. Pin a fixed `alg` allowlist server-side.
- **Long-lived non-rotating tokens** — a 30-day access token with no rotation = a 30-day skeleton key if leaked, with no revocation. Short access + rotating refresh + reuse-detection.
- **No logout revocation** — "logout" clears the cookie but the JWT / session stays valid until expiry. Stolen token survives logout. Revoke server-side.
- **Session fixation** — the pre-login session id is kept after login; attacker who planted the id rides the authenticated session. Rotate the id on login.
- **No rate-limit on login** — credential-stuffing runs unbounded; one weak password = takeover. Per-account + per-IP limits + lockout.
- **Variable-time token compare** — `if (token === stored)` leaks the token byte-by-byte under timing measurement. Constant-time compare.
- **Trusting client-supplied role / tenant** — `POST /admin { role: 'admin' }` or a `tenant_id` from the body. Derive identity + scope from the verified session / token only.
- **Reset token not invalidated** — reset link works repeatedly / after the password already changed. Single-use, expiring, invalidated on use and on any password change.

## Enforcement

- `<commands-path>/audit-access-control.md` (slash: `/audit-access-control`) — IDOR / authorization-coverage audit: enumerates every endpoint × who-can-call-it × the ownership-check call site at `<path:line>`; halts on any endpoint lacking a cited scope check.
- `<agents-path>/auth-reviewer.md` — review gate hard-failing on plaintext/weak hashing, JWT in localStorage, missing CSRF, IDOR / missing ownership checks, no rate-limit on login, user-enumeration errors, long-lived non-rotating tokens, missing logout/revocation, and client-side authorization.
- CI lint MUST reject password fields hashed with `md5` / `sha1` / `sha256` / `crypto.createHash(` in the auth path.
- CI lint MUST reject `localStorage.setItem(`/`sessionStorage.setItem(` with an argument named like `token` / `jwt` / `accessToken` / `refreshToken`.
- CI lint MUST reject JWT verify calls that pass `algorithms` containing `none`, or that omit an `algorithms` allowlist.
- CI lint MUST reject `===` / `==` against a variable named like a `token` / `secret` / `otp` / `code` in auth code paths (heuristic; flag for review).
- TODO: `scripts/validate-auth-access.sh` to AST-walk controllers and assert every resource-loading route either declares `@Public()` or passes through the guard AND scopes its primary query by owner / tenant.

## Cross-references

- `<patterns-path>/auth-architecture.md` — AuthN/AuthZ split, policy engine, token service, session store, password hashing, MFA, OAuth/OIDC code shapes.
- `<rules-path>/webhook-signature-verification.md` — constant-time compare + secret hygiene (shared discipline for any inbound secret).
- `<patterns-path>/payment-integration.md` — server-computed-trust analogue (never trust client amount ↔ never trust client role/scope).
- `<commands-path>/audit-access-control.md` — IDOR / authorization-coverage audit tool.
- `<agents-path>/auth-reviewer.md` — review gate.
- `<adr-path>/<NNN>-auth-session-strategy.md` — ADR pinning session-store-vs-JWT choice, token TTLs, MFA policy, and the identity provider.
