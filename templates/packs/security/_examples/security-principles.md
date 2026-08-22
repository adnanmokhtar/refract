---
name: security-principles
kind: example
pack: security
---

# Security Principles

The always-on floor for code being written. Depth lives in `ai/patterns/auth-flow.md`, `tenant-isolation.md`, `zero-trust.md` and the six security reviewers.

## Must

- Auth on every endpoint by default. Public endpoints are explicitly opted-in via the project's public-route marker and reviewed.
- Authorization (who can do this) is checked AFTER authentication (who is this) — they're different layers. Never collapse them.
- Parameterized queries / prepared statements / ORM bind parameters only. String interpolation into SQL is a CVE waiting to ship.
- **The carve-out.** Bind parameters cannot carry a table/column identifier, a sort column, `ASC`/`DESC`, or (most drivers) `LIMIT`/`OFFSET`. Map those through a server-side allow-list in the query helper — never the request string. Every `?sort=` endpoint lands here. (OWASP *SQL Injection Prevention* § Defense Option 3: https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- Validate every input at every trust boundary: HTTP request, webhook, queue consumer, file upload, IPC. Don't trust "the previous service already validated".
- Encode output by context — never interpolate user input into an HTML / JS / attribute / URL sink. `innerHTML` / `v-html` / `| safe` / `{{{ }}}` are forbidden with user-influenced data (vetted allow-list sanitizer if raw HTML is unavoidable). Untrusted *sources* are wider than the request body: URL fragment, `Referer` / `User-Agent`, a third-party API field, a WebSocket or `postMessage` payload, anything read back out of storage.
- Bind request payloads through an explicit field allow-list (DTO / schema with named fields). Never mass-assign a whole body onto a persisted entity — over-posting lets a client set `role`, `tenant_id`, `price`.
- File uploads: type by magic bytes (never the client-sent extension / MIME), size cap, stored outside the webroot under a generated name, never served from a path the server interprets.
- Any path built from user input is **canonicalized, then re-checked against the allowed base directory before the file is opened** — on the read/serve side, not only the store side. `?name=../`, an absolute path, a symlink, an encoded separator are all path traversal (CWE-22, A01:2025). Stripping `../` from a string is not the check.
- Passwords hashed with `argon2id` (preferred) or `bcrypt` — the algorithm name is not the control, **the parameters are**. Take current minimums from the OWASP *Password Storage Cheat Sheet* (https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), never from memory. Never fast hashes (`md5`, `sha1`, `sha256`).
- Session ids, security/reset/verification tokens, nonces and salts come from the platform CSPRNG — never `Math.random`, a timestamp, or a counter.
- JWTs verify signature + `exp` + `iss` + `aud` on every request. Reject `alg: none`. Pin the algorithm allowlist.
- Sessions: `HttpOnly`, `Secure`, `SameSite=Lax` (or `Strict` for sensitive flows). Rotate session ID on login / privilege change.
- Secrets in a manager + rotated on suspected compromise. Environment / dotenv files in `.gitignore` and never committed.
- Tenant isolation enforced at the data layer (auto-applied filter on every query) — not as an opt-in per query.
- Where the app collects PII/PHI: every field's sinks (store → log → analytics → third-party egress) are known and consented, erasure/DSAR reaches **every** sink not just the primary row, and cross-border transfer is checked against the *configured* regime.
- Transport and headers: TLS everywhere, service-to-service included; HSTS `max-age >= 31536000; includeSubDomains` (the one-year floor is the preload-list minimum, https://hstspreload.org) plus `preload`, without which HSTS does nothing on a first visit; CSP with no `'unsafe-inline'` / `'unsafe-eval'` on production scripts.

## Must not

- Dynamic code evaluation (`eval`, function constructors, shell-true subprocess invocation) on any input that could come from a user.
- Shell command interpolation of user input. Use the language's array-arg / safe-spawn API, never string concatenation into a shell.
- Redirect the browser to a location taken from a request parameter. `?next=` / `?returnUrl=` / `?redirect=` accepting an arbitrary URL is an open redirector (CWE-601, A01:2025) — it launders phishing through your domain and on an OAuth client exfiltrates authorization codes (OAuth 2.1 § 2.3.1). Accept a validated relative path, or an index into a server-side allow-list.
- Log passwords, full tokens, full credit cards, full national IDs, full health data. Mask: last 4 digits or hash.
- Store API keys / OAuth tokens / payment credentials in plain DB columns. Encrypt at rest with KMS-managed keys.
- Catch-all error swallowing (empty catch / rescue) — it hides auth-bypass and decryption failures. Fail closed: a permission check that throws denies.
- `admin=true` / `bypass=true` flags that work in production.
- Trust `Origin` / `Referer` / `User-Agent` as a *sufficient* control — all are client-set. (`Origin` is defence-in-depth, since page JS cannot forge it — never the only gate.)

## Should

- Enforce MFA on admin accounts; offer it to all users — TOTP (RFC 6238) or WebAuthn / passkeys.
- Rate-limit per IP + per user + per tenant on auth, password reset, and expensive endpoints. Guard the *flow* too, not only the route: a multi-step flow enforces its own ordering server-side (no skipping payment, no replaying a completed step), and a step that is harmful when scripted needs anti-automation beyond a generic limiter.
- CSRF on cookie-authenticated state-changing requests: a **synchronizer token** (the framework's built-in) or a **signed double-submit** HMAC-bound to the session — the naive double-submit is bypassable by anyone who can write a cookie on a sibling subdomain (https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html).
- Write an audit log on every privileged action: role changes, payment changes, data exports. Include actor, target, before/after, IP, timestamp.
- Block on critical CVEs using the project's package-manager-native auditor plus a cross-language scanner. Triage by CVSS **+ EPSS + CISA KEV**, not CVSS alone.
- Threat-model any new feature touching auth, payments, or PII before code is written.

CI enforcement belongs to `/security-audit` and `/dependency-vuln-check` — this rule governs the code, not the pipeline that checks it.
