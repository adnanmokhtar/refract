---
name: security-principles
kind: example
pack: security
---

# Security Principles

The always-on floor for code being written. Depth lives in `ai/patterns/auth-flow.md`, `tenant-isolation.md`, `zero-trust.md` and in the six security reviewers.

## Must

- Auth on every endpoint by default. Public endpoints are explicitly opted-in via the project's public-route marker and reviewed.
- Authorization (who can do this) is checked AFTER authentication (who is this) — they're different layers. Never collapse them.
- Parameterized queries / prepared statements / ORM bind parameters only. String interpolation into SQL is a CVE waiting to ship.
- **The carve-out that breaks that rule.** Bind parameters cannot carry a table/column identifier, a sort column, `ASC`/`DESC`, or (in most drivers) `LIMIT`/`OFFSET`. Map those through a server-side allow-list — `{"newest": "created_at"}` → the mapped value, else reject — never through the request string. Every `?sort=` endpoint lands here. (OWASP *SQL Injection Prevention* § "Defense Option 3: Allow-list Input Validation" — https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- Validate every input at every trust boundary: HTTP request, webhook, queue consumer, file upload, IPC. Don't trust "the previous service already validated".
- Encode output by context — never interpolate user input into an HTML / JS / attribute / URL sink. Auto-escape by default; `innerHTML`, `v-html`, `| safe` / `{{{ }}}` are forbidden with user-influenced data. Untrusted *sources* are wider than the request body: URL fragment, `Referer` / `User-Agent`, a third-party API field, a WebSocket frame, a `postMessage` payload, anything read back out of storage.
- Bind request payloads through an explicit field allow-list (DTO / schema with named fields). Never mass-assign a whole body onto a persisted entity — over-posting lets a client set `role`, `tenant_id`, `price`.
- File uploads: validate type by magic bytes (not the client-sent extension / MIME), cap size, store outside the webroot with a generated name — never serve or execute an upload from a path the server interprets.
- Any path built from user input is **canonicalized, then re-checked against the allowed base directory before the file is opened** — on the read/serve side, not only the store side. `?name=../`, an absolute path, a symlink, an encoded separator: all path traversal (CWE-22, under A01:2025). Stripping `../` from a string is not the check.
- Passwords hashed with `argon2id` (preferred) or `bcrypt` (cost ≥ 12). The algorithm name is not the control — **the parameters are** (Argon2id `m`/`t`/`p`; bcrypt work factor). Set them explicitly and take current minimums from the OWASP *Password Storage Cheat Sheet* (https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), not from memory. Never fast hashes (`md5`, `sha1`, `sha256`).
- Session ids, security/reset/verification tokens, nonces and salts come from the platform CSPRNG — never `Math.random`, a timestamp, or a counter.
- JWTs verify signature + `exp` + `iss` + `aud` on every request. Reject `alg: none`. Pin the algorithm allowlist.
- Sessions: `HttpOnly`, `Secure`, `SameSite=Lax` (or `Strict` for sensitive flows). Rotate session ID on login / privilege change.
- Secrets in a manager + rotated on suspected compromise. Environment / dotenv files in `.gitignore` and never committed.
- Tenant isolation enforced at the data layer (auto-applied filter on every query) — not as an opt-in per query.
- Where the app collects PII/PHI: every field's sinks (store → log → analytics → third-party egress) are known and consented, erasure/DSAR reaches **every** sink not just the primary row, and cross-border transfer is checked against the *configured* regime, never a defaulted one.
- TLS everywhere, including service-to-service. HSTS header with `max-age >= 31536000; includeSubDomains`.
- CSP header set with no `'unsafe-inline'` / `'unsafe-eval'` in production scripts.

## Must not

- Dynamic code evaluation (`eval`, function constructors, shell-true subprocess invocation) on any input that could come from a user.
- Shell command interpolation of user input. Use the language's array-arg / safe-spawn API, never string concatenation into a shell.
- Redirect the browser to a location taken from a request parameter. A `?next=` / `?returnUrl=` / `?redirect=` accepting an arbitrary URL is an open redirector (CWE-601, under A01:2025) — it launders phishing through your domain and on an OAuth client can exfiltrate authorization codes (OAuth 2.1 § 2.3.1). Accept a validated relative path, or an index into a server-side allow-list.
- Log passwords, full tokens, full credit cards, full national IDs, full health data. Mask: last 4 digits or hash.
- Store API keys / OAuth tokens / payment credentials in plain DB columns. Encrypt at rest with KMS-managed keys.
- Catch-all error swallowing (empty catch / rescue) — it hides auth-bypass and decryption failures. Fail closed: a permission check that throws denies.
- `admin=true` / `bypass=true` flags that work in production.
- Trust `Origin` / `Referer` / `User-Agent` as a *sufficient* control — all are client-set. (`Origin` is a valid defence-in-depth signal, since page JS cannot forge it — never the only gate.)

## Should

- Enforce MFA on admin accounts; offer it to all users — TOTP (RFC 6238) or WebAuthn / passkeys.
- Rate-limit per IP + per user + per tenant on auth, password reset, and expensive endpoints.
- Guard the *flow*, not only the route: a multi-step flow enforces its own ordering server-side (no skipping payment, no replaying a completed step), and a step that is harmful when scripted needs anti-automation beyond a generic limiter.
- CSRF on cookie-authenticated state-changing requests: a **synchronizer token** (the framework's built-in) or a **signed double-submit** HMAC-bound to the session. `SameSite` + `Origin` are defence-in-depth, never the control — OWASP rules the naive double-submit "bypassable by an attacker who can write cookies on the target domain" (a sibling subdomain suffices, so on subdomain-per-tenant SaaS this is the ordinary case) and says `SameSite` "does not replace a proper CSRF defense in most deployments" (https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html).
- Write an audit log on every privileged action: role changes, payment changes, data exports. Include actor, target, before/after, IP, timestamp.
- Block on critical CVEs using the project's package-manager-native auditor plus a cross-language scanner. Triage by CVSS **+ EPSS + CISA KEV**, not CVSS alone.
- Threat-model any new feature touching auth, payments, or PII before code is written.

CI enforcement is configured and verified by `/security-audit` and `/dependency-vuln-check`. This rule governs the code, not the pipeline that checks it.
