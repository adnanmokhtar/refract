---
name: document-generation-discipline
description: Document generation discipline (PDF / DOCX / print)
kind: rule
---

# Document generation discipline

## Hard rule

Any PDF / DOCX / print artifact (invoice, contract, statement, certificate) MUST be rendered in an ASYNCHRONOUS, idempotent job — NEVER on the request thread. A headless renderer (Puppeteer / Chromium / wkhtmltopdf / LibreOffice) is an UNTRUSTED, NETWORK-CAPABLE program: it MUST run sandboxed with NETWORK DISABLED and `file://` / local-path access BLOCKED, or it becomes an SSRF + local-file-read primitive. User data MUST be bound into an AUTOESCAPED template — never string-concatenated into the template source — or it is template injection (code exec) + XSS rendered into the document. Every render MUST carry resource, timeout, page-count, and asset caps or one document DoS-es the renderer. Legal/audit documents MUST be DETERMINISTIC and version + as-of stamped — the same inputs MUST produce the byte-identical (or content-identical) artifact, re-renderable years later. Stored documents MUST be tenant-scoped and delivered via SIGNED, short-lived URLs from a private bucket; idempotency keys on (data hash + template version) so a regenerate returns the existing artifact.

A document bug is a forged-looking invoice, a leaked contract, an SSRF into your private network, or a renderer pinned at 100% CPU — each erodes trust or breaches security far more than a failed request.

## Must

- **Async for every render**: a document render is enqueued as a job (see `<rules-path>/background-jobs`) that produces an artifact and notifies on completion (in-app / email / webhook). The HTTP request returns a `jobId` + status URL, never the bytes. Headless-browser startup + layout + paint is hundreds of ms to seconds; it NEVER blocks a request worker.
- **Sandboxed renderer, network DISABLED**: the headless renderer runs with outbound network blocked (`--disable-network` / egress-denied container / no-internet namespace) and `file://` + local-path navigation blocked. It can render only the HTML/template you hand it and the assets you explicitly resolve — it can NEVER fetch `http://169.254.169.254/`, `http://internal-service/`, or read `file:///etc/passwd`.
- **Autoescaped templating, data BOUND not concatenated**: user/tenant data is passed as bound template variables through an autoescaping engine (Handlebars/Nunjucks/Jinja/Liquid with HTML autoescape ON), never string-interpolated into the template source. The template is a fixed, version-controlled asset; the data is parameters. No `eval`, no `new Function`, no `{{{tripleStache}}}` / `|safe` over user data.
- **Resource + timeout + page + asset caps**: every render enforces a wall-clock timeout (kill the renderer process on overrun), a max page count, a max output byte size, a memory/CPU cap (container limits), and a cap on the number + size of embedded assets (images/fonts). A document that blows any cap fails the job — it does not hang the worker.
- **Deterministic, version + as-of stamped output**: legal/audit documents pin the template version, the data as-of instant, and a fixed locale/timezone/currency; volatile inputs (`now()`, random ids, auto-incrementing counters, font-hinting jitter) are frozen so a re-render of the same inputs yields the same content. The artifact embeds `template_version` + `as_of` + a content hash.
- **Tenant scope on storage + signed short-lived delivery**: artifacts live under a tenant-scoped key (`docs/<tenantId>/...`) in a PRIVATE bucket and are delivered via signed URLs with a short expiry (minutes–hours), mirroring `<rules-path>/reporting` signed delivery. Public buckets / permanent URLs / predictable-id public routes are FORBIDDEN.
- **Idempotency on (data hash + template version)**: the artifact key derives from `hash(canonical data) + template version`; a re-request with the same inputs returns the EXISTING artifact rather than re-rendering. Invoices/contracts are generated once and reused, not rebuilt on every download.
- **Access control on PII documents**: a document containing PII (names, addresses, balances, SSNs, card tails) is access-checked on issue AND on every fetch — the signed URL is scoped to the authorized actor + tenant; the audit log records who generated and who downloaded it.
- **Bounded, pinned fonts + assets**: fonts and images are resolved from a fixed, bundled, allowlisted set — never fetched from a user-supplied URL and never unbounded. Remote/user asset references in templates are blocked by the same sandbox that blocks SSRF.
- **Idempotent + resumable job semantics**: the render job is keyed (`doc:<type>:<tenant>:<dataHash>:<templateVersion>`); a re-run with the same key returns the existing artifact; a job that dies mid-render restarts cleanly (render is pure given inputs) and never emits a half-written document.

## Must not

- Render a PDF/DOCX synchronously on the request thread — headless-browser launch + layout blocks the worker, times out the gateway, and lets one big document hold a worker hostage.
- Run the renderer with network access or `file://` enabled — Puppeteer/wkhtmltopdf will dutifully fetch `<img src="http://169.254.169.254/...">` (SSRF) or `<img src="file:///etc/passwd">` (LFI) embedded in template data.
- Concatenate user data into the template source (`html = "<h1>" + user.name + "</h1>"`, `Handlebars.compile(userControlledString)`) — template injection (SSTI → code exec) and XSS rendered into the document.
- Render without a timeout / page cap / output-size cap / asset cap — a 100,000-row invoice or a self-referential layout OOMs or pins the renderer.
- Store documents without a tenant predicate, or serve them from a public bucket / a guessable public URL — cross-tenant leak of contracts and statements.
- Produce non-deterministic legal documents — an invoice that re-renders with a different `now()`, a different counter, or a different float total than the one the customer received.
- Regenerate the same document on every download with no idempotency — wasted renderer cycles, and a risk of producing a DIFFERENT artifact than the one already issued.
- Put PII into a document with no access control on generation or fetch, or with no audit of who downloaded it.
- Resolve fonts/images from a user-supplied or remote URL, or embed an unbounded number/size of assets.

## Should

- Wrap rendering behind a project-internal `<DocumentRenderer>` / `<RenderJob>` interface so the sandbox flags, caps, autoescape, determinism stamps, tenant-scoped storage, and audit are enforced in ONE place — feature code declares a document spec (template id + data), not raw renderer calls.
- Keep templates as version-controlled, reviewed assets with a `template_version`; never load a template from the database or from user input at render time.
- Render from an immutable data snapshot captured at issue time (the invoice's line items as-of that instant) so a re-render years later reproduces the original document, not today's data.
- Run the renderer in a dedicated, locked-down container/pool (egress-denied, read-only FS, dropped capabilities, seccomp) separate from the app — a renderer escape can't reach app secrets or the network.
- Sign / hash the artifact (content hash, optional digital signature) so tampering is detectable and the issued document is verifiable.
- Localize via `<rules-path>/i18n` (locale, timezone, currency, RTL) at the edge with explicit locale + tz pinned into the deterministic stamp — never the server's ambient locale.
- Emit structured `{ docType, tenantId, templateVersion, pages, bytes, renderMs, dataHash, asOf }` per render; alert on renders that exceed the timeout, the page cap, or the asset cap.

## Review checklist (PRs touching PDF / DOCX / print / document rendering)

- [ ] Render runs as an async job returning a `jobId`, not inline bytes; job key is deterministic + idempotent. Cite the enqueue at `<path:line>`.
- [ ] Renderer is sandboxed: network DISABLED + `file://`/local-path BLOCKED. Cite the launch flags / container config at `<path:line>`.
- [ ] User data is BOUND into an autoescaped template — no concatenation, no `compile(userString)`, no `|safe`/`{{{ }}}` over user data. Cite the render call at `<path:line>`.
- [ ] Caps enforced: wall-clock timeout (process killed on overrun), max pages, max output bytes, asset count/size cap, container CPU/mem limit. Cite at `<path:line>`.
- [ ] Output is deterministic for legal/audit docs: template version + as-of + locale/tz/currency pinned; volatile inputs frozen; content hash embedded. Cite the stamp at `<path:line>`.
- [ ] Stored artifact is tenant-scoped (`docs/<tenantId>/...`) in a PRIVATE bucket; delivered via signed short-lived URL. Cite the storage key + URL issuance at `<path:line>`.
- [ ] Idempotency on `hash(data) + templateVersion` — a re-request returns the existing artifact. Cite the key derivation at `<path:line>`.
- [ ] PII documents are access-checked on generate AND fetch; download is audited.
- [ ] Fonts/images come from a bundled allowlist — no user-supplied/remote asset URLs.

## Anti-patterns

- **Sync render on the request** — `GET /invoices/:id/pdf` launches Puppeteer inline -> 4s request -> gateway timeout -> user retries -> three Chromium processes fighting for the worker -> the box falls over. Enqueue a job; return a `jobId`; render in a worker.
- **SSRF via the renderer** — template data includes `<img src="http://169.254.169.254/latest/meta-data/iam/...">`; Puppeteer fetches it and bakes the cloud credentials into the PDF (or just leaks the response). Disable network in the renderer; block `file://` + non-allowlisted hosts.
- **LFI via the renderer** — `<img src="file:///etc/passwd">` / `<link href="file:///app/.env">` in user-controlled content; wkhtmltopdf reads the local file into the document. Block `file://` and local paths at the sandbox.
- **Template injection** — `Handlebars.compile("<h1>Invoice for " + customer.name + "</h1>")` where `customer.name` is `{{constructor.constructor('return process')()...}}` -> SSTI -> code exec. Compile a FIXED template; bind `{ customer }` as autoescaped data.
- **XSS-in-PDF** — `customer.name` of `<img src=x onerror=...>` / `<script>` concatenated unescaped into the HTML -> active content rendered into the document (and into any HTML preview). Autoescape; never `{{{ }}}`/`|safe` over user data.
- **No caps -> DoS** — a customer with 200,000 line items, or a CSS `height: 100000000px`, makes the renderer allocate gigabytes and hang forever. Cap pages, bytes, assets, wall-clock; kill on overrun; fail the job.
- **Cross-tenant doc leak** — contracts stored at `s3://public-docs/contract-<sequentialId>.pdf` with a guessable id and no tenant scope -> tenant A reads tenant B's contract by incrementing the id. Private bucket, tenant-scoped key, signed short-lived URL (see `<rules-path>/reporting`).
- **Non-deterministic legal doc** — the invoice PDF stamps `Generated: ${new Date()}` and re-sums a float total, so a re-render shows a different timestamp and a one-cent-different total than the customer's copy. Freeze `now()`, pin the as-of snapshot, sum integer minor units, stamp the template version.
- **Regenerate-on-every-download** — every `GET .../download` re-renders from scratch -> wasted CPU and a risk of producing a doc that differs from the one already issued. Idempotency key on `hash(data)+templateVersion`; return the stored artifact.
- **PII with no access control** — a statement PDF served from a signed URL that any logged-in user can mint for any account id -> account-balance leak. Scope the URL to the authorized actor + tenant; audit the download.
- **Unbounded / remote fonts** — `@font-face { src: url('https://user-controlled/...') }` -> the renderer fetches an attacker URL (SSRF) or a 50MB font -> bloat + egress. Bundle + allowlist fonts; block remote `@font-face`.

## Enforcement

- `<commands-path>/audit-document-pipeline.md` (slash: `/audit-document-pipeline`) — cite-or-halt diagnostic of a specific document pipeline: where the renderer is invoked at `<path:line>`, sync vs. async, renderer network/file access (SSRF/LFI), template injection surface, resource/page/timeout caps, determinism + version stamp, tenant scope + signed-vs-public delivery, idempotency — never an assumed flow.
- `<agents-path>/document-generation-reviewer.md` — review gate hard-failing on sync render, SSRF/LFI via the renderer, template injection, missing caps, cross-tenant/public document delivery, non-deterministic legal output, missing idempotency, and unprotected PII.
- CI MUST reject `Handlebars.compile(` / `new Function(` / `eval(` / `nunjucks.renderString(` over a non-constant (AST heuristic; flag for review) in document templating code.
- CI MUST assert the renderer is launched with network disabled (`--disable-network` / egress-denied container) and `file://` blocked — a renderer config without these fails the check.
- CI MUST reject document storage keys with no tenant segment and document delivery from a public bucket base (heuristic; flag for review).
- TODO: `scripts/validate-render-sandbox.sh` to assert every renderer launch site sets the sandbox flags (no network, no `file://`), a timeout, and a page/byte cap before producing an artifact.

## Cross-references

- `<patterns-path>/document-pipeline.md` — async render job + sandboxed renderer + autoescaped templating + caps + determinism stamp + tenant-scoped signed delivery + idempotency code shapes.
- `<rules-path>/reporting` — same async-job + signed short-lived private-bucket delivery spine; reports and documents share the artifact-delivery contract.
- `<rules-path>/background-jobs` — queued render job semantics (idempotency, resumability, DLQ, observability).
- `<rules-path>/media-processing` — sandboxed-renderer / untrusted-input hardening parallels (resource caps, egress denial, dropped capabilities).
- `<rules-path>/i18n` — locale / timezone / currency / RTL handling inside generated documents, pinned into the deterministic stamp.
- `<rules-path>/audit-log-integrity.md` — document generation + download is an audited event; what to record per document.
- `<adr-path>/<NNN>-document-rendering-stack.md` — ADR pinning the renderer (Puppeteer / wkhtmltopdf / LibreOffice / native), the sandbox model, and the determinism + retention contract.
