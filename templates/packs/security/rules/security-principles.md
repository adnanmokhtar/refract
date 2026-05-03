---
name: security-principles
description: Security Principles
kind: rule
pack: security
---

# Security Principles

> **Hard rule.** Auth MUST be on every endpoint by default (public routes are explicitly opted-in). Authorization MUST be checked AFTER authentication, not collapsed with it. Parameterized queries only — string-interpolated SQL, `eval` / `exec` on user input, plaintext secrets in code or logs, and `alg: none` JWTs are forbidden.

Prevents the OWASP Top 10 patterns most likely to actually hit you: injection, broken auth, broken access control, secret leak, vulnerable dependency.

## Must

- Auth on every endpoint by default. Public endpoints are explicitly opted-in via the project's public-route marker (per the project's auth conventions) and reviewed.
- Authorization (who can do this) is checked AFTER authentication (who is this) — they're different layers. Never collapse them.
- Parameterized queries / prepared statements / ORM bind parameters only. String interpolation into SQL is a CVE waiting to ship.
- Validate every input at every trust boundary: HTTP request, webhook, queue consumer, file upload, IPC. Don't trust "the previous service already validated".
- Passwords hashed with `argon2id` (preferred) or `bcrypt` cost ≥ 12. Never fast hashes (`md5`, `sha1`, `sha256`) — brute-forceable.
- JWTs verify signature + `exp` + `iss` + `aud` on every request. Reject `alg: none`. Pin the algorithm allowlist.
- Sessions: `HttpOnly`, `Secure`, `SameSite=Lax` (or `Strict` for sensitive flows). Rotate session ID on login / privilege change.
- Secrets in a manager + rotated on suspected compromise. Environment / dotenv files in `.gitignore` and never committed.
- Tenant isolation enforced at the data layer (auto-applied filter on every query) — not as an opt-in per query.
- TLS everywhere, including service-to-service. HSTS header with `max-age >= 31536000; includeSubDomains`.
- CSP header set with no `'unsafe-inline'` / `'unsafe-eval'` in production scripts.

## Must not

- Dynamic code evaluation (`eval`, function constructors, shell-true subprocess invocation, etc.) on any input that could come from a user.
- Shell command interpolation of user input. Use the language's array-arg / safe-spawn API, never string concatenation into a shell.
- Log passwords, full tokens, full credit cards, full national IDs, full health data. Mask: last 4 digits or hash.
- Store API keys / OAuth tokens / payment credentials in plain DB columns. Encrypt at rest with KMS-managed keys.
- Catch-all error swallowing (empty catch / rescue blocks) — hides security failures (auth bypass, decryption error).
- `admin=true` / `bypass=true` flags that work in production. Dev shortcuts in prod are how breaches happen.
- Trust the `Origin` / `Referer` / `User-Agent` headers for security decisions — all are client-set.
- Rely on client-side validation for security. The server is the source of truth.

## Should

- Enforce MFA on admin accounts; offer it to all users — TOTP (RFC 6238) or WebAuthn / passkeys.
- Rate-limit per IP + per user + per tenant on auth, password reset, and expensive endpoints.
- Apply CSRF protection on cookie-authenticated forms (double-submit cookie or `SameSite=Strict` + `Origin` check).
- Write an audit log on every privileged action: role changes, payment changes, data exports. Include actor, target, before/after, IP, timestamp.
- Block on critical CVEs in dependency scans using the project's package-manager-native auditor (e.g., `npm audit`, `pip-audit`, `bundler-audit`, `cargo audit`, `composer audit`, `mix deps.audit`, `govulncheck`) plus a cross-language scanner (Snyk, Dependabot, Trivy).
- Threat-model every new feature touching auth, payments, or PII before code is written — short doc, named threats, mitigations.

## Review checklist

- [ ] Authorization check on every new endpoint.
- [ ] Input validated with the project's schema validator (per the project's stack).
- [ ] No raw SQL with interpolation. No shell calls with user input.
- [ ] No new secret in code. No log line printing a credential, token, or full PII.
- [ ] Tenant filter applied (multi-tenant projects).
- [ ] Errors don't leak stack traces, query SQL, or file paths to clients.
- [ ] Security headers present on new HTTP responses (CSP, HSTS, X-Frame-Options, X-Content-Type-Options).

## Enforcement

- `gitleaks` / `trufflehog` / `detect-secrets` block committed secrets (any of these — they're language-agnostic).
- `semgrep` rules for dynamic-code-eval, shell-injection, raw SQL concatenation, broken regex, crypto misuse — semgrep is multi-language out of the box.
- Dependency audit in CI using the project's package-manager-native tool (e.g., `npm audit --audit-level=high`, `pip-audit`, `bundler-audit`, `cargo audit`, `composer audit`, `govulncheck`) plus a cross-language scanner (`trivy fs`, Snyk, OSV-Scanner).
- Security headers verified via an HTTP-header analyser (e.g., `securityheaders.com`, Mozilla Observatory); checked in CI for production builds.
- Pen-test / bug bounty for high-stakes products.
