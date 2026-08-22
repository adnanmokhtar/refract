---
name: auth-flow
description: Pattern: Auth Flow
kind: ai-pattern
pack: security
---

# Pattern: Auth Flow

> **Hard rule** — Refresh tokens rotate on every use, are stored hashed in DB with replay-detection that revokes the entire session family on reuse. Access tokens live in memory, refresh in HttpOnly Secure SameSite=Strict cookies. Storing refresh tokens unhashed or skipping rotation is forbidden.

**When to apply**
- Web app with multi-device sessions and a real session store (DB or Redis).
- Multi-tenant SaaS where token revocation must be immediate per session.
- Admin / privileged endpoints where MFA + step-up auth is required.

**When NOT to apply**
- CLI / machine-to-machine flows — use OAuth client_credentials or workload identity, not refresh rotation.
- Single-page demo with no real users — full rotation infrastructure is over-investment.
- Service-to-service inside a mesh — mTLS / SPIFFE is the right primitive, not user JWTs.

**Halt conditions / mandatory cites**
- Cite the password-hashing **parameters** as `<path:line>` — not the algorithm name. "We use bcrypt" is not a control; a work factor is. Absent or unpinned parameters is a halt. See § Password hashing for what to pin and where the numbers come from.
- Cite the refresh-rotation revocation handler as `<path:line>` proving session-family revocation on replay; without it, the rotation claim is hollow.
- Cite the session store schema as `<path:line>` (`auth_sessions` table or equivalent) showing token_hash + ip + user_agent + revoked_at.
- Cite the password-reset token schema + TTL as `<path:line>`; reset tokens without single-use enforcement are a halt.
- Hand-wave grep ban — never claim "no plaintext secrets in DB" without citing the migration file `<path:line>` or schema dump.

JWT-based auth with refresh rotation. Document the flow once — every endpoint follows it.

## Login

```
1. POST /auth/login { email, password }
2. Server: verify the password against the stored hash (§ Password hashing) — the library's own verify function, which is constant-time; never a hand-rolled string compare.
3. Server: issue access token (JWT, short TTL — 15m) + refresh token (opaque, longer TTL — 30d).
4. Server: store refresh token hash + metadata (user, issued_at, ip, user_agent) in DB.
5. Response: { accessToken, expiresIn } + refresh as HttpOnly Secure SameSite=Strict cookie.
```

## Access token

- JWT with `sub` (user id), `tenant_id` (if multi-tenant), `role`, `exp`.
- Signed with RS256 (asymmetric — services can verify without having the signing key) or HS256 for monolith.
- Short TTL — 15 minutes.
- Included in `Authorization: Bearer <token>` header.
- Verify on EVERY request: signature, expiry, issuer, audience.

## Refresh

```
1. POST /auth/refresh (refresh cookie sent automatically)
2. Server: look up refresh token hash in DB.
3. Server: verify not revoked, not expired.
4. Server: ROTATE — revoke the used refresh, issue new access + new refresh.
5. Server: if the same refresh token is used AGAIN after rotation → SECURITY INCIDENT. Revoke the entire user's session family, force re-login.
```

Refresh rotation + replay detection is the single biggest security win.

## Logout

```
1. POST /auth/logout
2. Server: revoke the current refresh token (mark in DB).
3. Client: delete access token from memory.
4. Cookie cleared via Set-Cookie with expired timestamp.
```

Access tokens remain valid until TTL expires — accept this or maintain a revocation list (extra cost).

## Password reset

```
1. POST /auth/forgot-password { email } → always returns 200 (don't leak "email exists").
2. If email exists: generate single-use token, store hash in DB (bound to user + timestamp, 1h TTL).
3. Email link: https://app/reset?token=<raw>.
4. POST /auth/reset-password { token, newPassword } → verify token, invalidate, set password, revoke all refresh tokens.
```

## Password hashing

**The algorithm name is not the control — the parameters are.** Pin them in configuration, cite that `<path:line>` in review, and record which revision of the source you took them from, because the recommended values move upward with hardware.

The source is the **OWASP Password Storage Cheat Sheet** — <https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html>. As of this writing it gives, for the two algorithms most projects choose:

- **Argon2id** (preferred) — a minimum configuration of `m=19456` (19 MiB), `t=2`, `p=1`, with several equivalent memory/time trade-offs listed alongside it. All three parameters are the control; a call with library defaults and no explicit m/t/p is the finding.
- **bcrypt** — *"The work factor should be as large as verification server performance will allow, with a minimum of 10."* Treat the cheat sheet's minimum as the floor and the number your verification budget allows as the target; a project standard above the floor is fine, below it is not.

**bcrypt's 72-byte input limit is a correctness trap, not a footnote.** Most implementations accept a maximum input length of 72 bytes, so the cheat sheet's instruction is to *"enforce a maximum password length of 72 bytes"* — otherwise the tail of a long passphrase is silently ignored, and two different passwords can verify against the same hash. If you pre-hash to work around it, know that you are leaving the documented path and read the cheat sheet's treatment of it first.

Re-read the source when you implement, not from memory: this is a page whose recommended numbers change, and a hard-coded value copied out of a pattern file ages badly. What does not change is the shape — parameters pinned in config, cited in review, and above the current published floor.

## MFA (for admin)

- Passkeys / WebAuthn are the phishing-resistant baseline — prefer them over TOTP.
- TOTP (RFC 6238) with QR code enrollment where passkeys aren't available.
- Backup codes (10, one-time-use, hashed in DB).
- Required for admin / owner roles — recommended for all.

## Passkeys / WebAuthn (passwordless / MFA)

```
Registration: server issues a single-use challenge → authenticator creates a
  credential → server verifies challenge + origin + RP ID + attestation, then
  stores (credential_id, public_key, sign_counter) bound to the user.
Login:        server issues a single-use challenge → authenticator signs it →
  server verifies challenge + origin + RP ID + user-verification flag, checks the
  sign counter advanced (a non-increasing counter ⇒ cloned authenticator ⇒ reject),
  and that the credential_id belongs to the claimed user.
```

Passkeys replace the password entirely (passwordless) or stand as the second factor. The public key is not a secret; the private key never leaves the device.

## Session store

- Refresh tokens: DB table `auth_sessions` with user_id, token_hash, issued_at, expires_at, revoked_at, ip, user_agent.
- Prune expired > 30 days.
- Audit trail — who logged in when, from where.

## CSRF

Applies to **cookie-authenticated state-changing requests**. A request authenticated by an `Authorization` header the browser does not attach automatically is not in scope; a request authenticated by a cookie is, on every non-idempotent method.

Pick one of two controls — never "we set `SameSite`, we're covered":

- **Synchronizer token** — the framework's built-in. Server issues a per-session (or per-request) token, stores it server-side, and compares on submit. OWASP calls it "one of the most popular and recommended methods to mitigate CSRF".
- **Signed double-submit** — an HMAC over the session identifier with a server-side secret, sent as both a cookie and a header/field. The session binding is the whole control: OWASP warns that "signing tokens without session binding provides minimal protection".

**Why the naive double-submit fails.** Comparing a cookie to a header with no signature and no session binding is bypassable "by an attacker who can write cookies on the target domain (e.g., via a vulnerable sibling subdomain, DNS takeover, or plaintext-HTTP cookie injection on a non-`__Host-` cookie)". On subdomain-per-tenant SaaS a sibling subdomain is the ordinary deployment, not an exotic precondition — so treat this pattern as unavailable there unless the cookie is `__Host-` prefixed AND signed AND session-bound.

**`SameSite` and `Origin` are defence-in-depth, never the control.** OWASP: `SameSite` "is useful as a defense-in-depth control but it does not replace a proper CSRF defense in most deployments" — the `Lax` default only blocks unsafe methods, its scope is the registrable domain (so it does not separate sibling subdomains), and it does nothing against client-side CSRF. `Origin`/`Referer` verification is a second signal, not a first one: page JS cannot forge `Origin`, but the header can be absent or stripped, and a check that fails open when it is missing reopens the hole.

Source: OWASP *Cross-Site Request Forgery Prevention Cheat Sheet* — <https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html>. Re-read it when you implement; the recommended patterns have changed more than once.

## Forbidden

- Storing refresh tokens unhashed.
- Access tokens in localStorage (use memory + HttpOnly cookie for refresh).
- Passwords stored with a fast/general-purpose hash (MD5, SHA-1, plain SHA-256) or with a password hash left at library defaults — see § Password hashing. Prefer argon2id.
- Reusing refresh tokens (replay attack).
- Generic error messages that leak account existence.
- MFA bypass with `rememberMe` without proper device binding.
- Revealing password complexity errors to the client (attackers learn your rules).

## Related

- `@auth-reviewer` — the agent that audits this flow against source (JWT, refresh rotation, passkeys, OAuth 2.1).
- `.claude/rules/security-principles.md` — the MUSTs this pattern implements (password hashing, JWT verification, session flags).
- `ai/patterns/zero-trust.md` — the surrounding boundary model (short-lived tokens, MFA, session revocation).
