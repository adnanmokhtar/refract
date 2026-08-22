---
name: auth-flow
kind: example
pack: security
---

# Pattern: Auth Flow

> **Hard rule** — Refresh tokens rotate on every use, are stored hashed in DB with replay-detection that revokes the entire session family on reuse. Access tokens live in memory, refresh in HttpOnly Secure SameSite=Strict cookies. Storing refresh tokens unhashed or skipping rotation is forbidden.

**Halt conditions / mandatory cites**
- Cite the password-hashing **parameters** as `<path:line>` — not the algorithm name. "We use bcrypt" is not a control; a work factor is. Absent or unpinned parameters is a halt. See § Password hashing.
- Cite the refresh-rotation revocation handler as `<path:line>` proving session-family revocation on replay; without it, the rotation claim is hollow.
- Cite the session store schema as `<path:line>` (`auth_sessions` table or equivalent) showing token_hash + ip + user_agent + revoked_at.
- Cite the password-reset token schema + TTL as `<path:line>`; reset tokens without single-use enforcement are a halt.
- Hand-wave grep ban — never claim "no plaintext secrets in DB" without citing the migration file `<path:line>` or schema dump.

JWT-based auth with refresh rotation. Document the flow once — every endpoint follows it.

## Login

```
1. POST /auth/login { email, password }
2. Server: verify against the stored hash (§ Password hashing) using the library's verify function — never a hand-rolled compare.
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

**The algorithm name is not the control — the parameters are.** Pin them in configuration, cite that `<path:line>`, and record which revision of the source you took them from; the recommended values move upward with hardware.

Source: the **OWASP Password Storage Cheat Sheet** — <https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html>. As of this writing:

- **Argon2id** (preferred) — minimum configuration `m=19456` (19 MiB), `t=2`, `p=1`, with equivalent memory/time trade-offs listed alongside. Library defaults with no explicit m/t/p is the finding.
- **bcrypt** — *"The work factor should be as large as verification server performance will allow, with a minimum of 10."* The cheat sheet's minimum is the floor; your verification budget sets the target.
- **bcrypt's 72-byte input limit is a correctness trap.** Most implementations accept at most 72 bytes, so *"enforce a maximum password length of 72 bytes"* — otherwise the tail of a long passphrase is silently ignored and two different passwords verify against one hash.

Re-read the source when you implement; a number copied out of a pattern file ages badly. The shape does not age: parameters pinned in config, cited in review, at or above the current published floor.

## MFA (for admin)

- **Passkeys / WebAuthn are the phishing-resistant baseline** — prefer them over TOTP.
- TOTP (RFC 6238) with QR code enrollment where passkeys aren't available.
- Backup codes (10, one-time-use, hashed in DB).
- Required for admin / owner roles — recommended for all.

## Passkeys / WebAuthn

```
Registration: server issues a single-use challenge → authenticator creates a credential →
  server verifies challenge + origin + RP ID + attestation, then stores
  (credential_id, public_key, sign_counter) bound to the user.
Login:        server issues a single-use challenge → authenticator signs it → server verifies
  challenge + origin + RP ID + user-verification flag, checks the sign counter advanced
  (a non-increasing counter ⇒ cloned authenticator ⇒ reject), and that the credential_id
  belongs to the claimed user.
```

The public key is not a secret; the private key never leaves the device.

## Session store

- Refresh tokens: DB table `auth_sessions` with user_id, token_hash, issued_at, expires_at, revoked_at, ip, user_agent.
- Prune expired > 30 days.
- Audit trail — who logged in when, from where.

## CSRF

Applies to **cookie-authenticated state-changing requests** — a cookie the browser attaches automatically on every non-idempotent method. Bearer-header auth is not in scope.

Pick one control, never "we set `SameSite`, we're covered":

- **Synchronizer token** — the framework's built-in; server-stored, compared on submit. OWASP: "one of the most popular and recommended methods to mitigate CSRF".
- **Signed double-submit** — HMAC over the session id with a server-side secret, sent as cookie + header. The session binding is the control: "signing tokens without session binding provides minimal protection".

**The naive double-submit is bypassable** "by an attacker who can write cookies on the target domain (e.g., via a vulnerable sibling subdomain, DNS takeover, or plaintext-HTTP cookie injection on a non-`__Host-` cookie)" — and on subdomain-per-tenant SaaS a sibling subdomain is the ordinary deployment.

**`SameSite` / `Origin` are defence-in-depth.** OWASP: `SameSite` "does not replace a proper CSRF defense in most deployments" — the `Lax` default only blocks unsafe methods and its scope is the registrable domain, so it does not separate sibling subdomains. Never fail open when `Origin` is absent.

Source: OWASP *Cross-Site Request Forgery Prevention Cheat Sheet* — <https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html>.

## Forbidden

- Storing refresh tokens unhashed.
- Access tokens in localStorage (use memory + HttpOnly cookie for refresh).
- Passwords stored with a fast/general-purpose hash (MD5, SHA-1, plain SHA-256), or a password hash left at library defaults — see § Password hashing. Prefer argon2id.
- Reusing refresh tokens (replay attack).
- Generic error messages that leak account existence.
- MFA bypass with `rememberMe` without proper device binding.
- Revealing password complexity errors to the client (attackers learn your rules).

## Related

`@auth-reviewer` (audits this flow against source: JWT, refresh rotation, passkeys, OAuth 2.1) · `security-principles.md` (the MUSTs this implements) · `zero-trust.md` (the surrounding boundary model).
