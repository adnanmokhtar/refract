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
- Cite the password-hashing config as `<path:line>` (bcrypt cost / argon2 params); cost <10 or absent params is a halt.
- Cite the refresh-rotation revocation handler as `<path:line>` proving session-family revocation on replay; without it, the rotation claim is hollow.
- Cite the session store schema as `<path:line>` (`auth_sessions` table or equivalent) showing token_hash + ip + user_agent + revoked_at.
- Cite the password-reset token schema + TTL as `<path:line>`; reset tokens without single-use enforcement are a halt.
- Hand-wave grep ban — never claim "no plaintext secrets in DB" without citing the migration file `<path:line>` or schema dump.

JWT-based auth with refresh rotation. Document the flow once — every endpoint follows it.

## Login

```
1. POST /auth/login { email, password }
2. Server: verify password (bcrypt/argon2) with constant-time compare.
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

## MFA (for admin)

- TOTP (RFC 6238) with QR code enrollment.
- Backup codes (10, one-time-use, hashed in DB).
- Required for admin / owner roles — recommended for all.

## Session store

- Refresh tokens: DB table `auth_sessions` with user_id, token_hash, issued_at, expires_at, revoked_at, ip, user_agent.
- Prune expired > 30 days.
- Audit trail — who logged in when, from where.

## Forbidden

- Storing refresh tokens unhashed.
- Access tokens in localStorage (use memory + HttpOnly cookie for refresh).
- Passwords stored with weak hashing (MD5, SHA1, bcrypt cost <10).
- Reusing refresh tokens (replay attack).
- Generic error messages that leak account existence.
- MFA bypass with `rememberMe` without proper device binding.
- Revealing password complexity errors to the client (attackers learn your rules).
