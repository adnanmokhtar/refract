---
description: Audit a specific document (PDF / DOCX / print) pipeline — where the renderer is invoked, sync vs. async, renderer network/file access (SSRF/LFI), template injection, resource/page/timeout caps, determinism + version stamp, tenant scope + signed-vs-public delivery, idempotency — from the real code, never an assumed flow.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /audit-document-pipeline

Diagnose whether a specific document pipeline is safe + correct: where the renderer runs, whether it blocks the request thread, whether it can be turned into an SSRF/LFI primitive, whether user data can inject the template, whether it is capped, deterministic, tenant-scoped, signed, and idempotent — from the REAL code, not a guess.

## Premise

Real signals only. Cite the renderer invocation at `<path:line>`, the enqueue (or its absence) at `<path:line>`, the renderer launch flags / sandbox config at `<path:line>`, the template-render call at `<path:line>`, the caps at `<path:line>`, the determinism stamp at `<path:line>`, the storage key + delivery URL at `<path:line>`, and the idempotency key at `<path:line>` — never narrate a pipeline you didn't read. Read before judging: locate the renderer call in source and trace BACK to the request handler and FORWARD to storage + delivery BEFORE issuing any verdict.

## Mechanical halt

Cite-or-halt: every run MUST print, each from real source at `<path:line>` (or the explicit verdict):

1. **Renderer invocation** — where Puppeteer/Chromium/wkhtmltopdf/LibreOffice/PDF-lib is actually called.
2. **Sync vs. async** — is it on the request thread, or enqueued as a job returning a `jobId`? (`SYNC — BLOCKER` if inline.)
3. **Renderer network/file access** — is network DISABLED and `file://`/local-path BLOCKED at launch + request interception? (`OPEN — SSRF/LFI BLOCKER` if not.)
4. **Template injection** — is user data BOUND into an autoescaped template, or concatenated / `compile(userString)` / `{{{ }}}`/`|safe`? (`CONCATENATED/COMPILED — BLOCKER` if so.)
5. **Caps** — wall-clock timeout (kills the process), max pages, max bytes, asset cap. (`NONE — DoS BLOCKER` if absent.)
6. **Determinism + version stamp** — for legal docs: template version + as-of + pinned locale/tz, frozen `now()`. (`NON-DETERMINISTIC — finding` if `new Date()`/float totals/unpinned.)
7. **Tenant scope + delivery** — tenant-scoped storage key + signed short-lived URL vs. public bucket / guessable id. (`PUBLIC/UNSCOPED — cross-tenant BLOCKER` if so.)
8. **Idempotency** — key on `hash(data)+templateVersion`, reuse the existing artifact. (`REGENERATE-EVERY-REQUEST — finding` if absent.)

If any of these cannot be produced from real source, HALT and say which — never an assumed sandbox, never an assumed enqueue, never an assumed signed URL.

This command is READ-ONLY. It does NOT execute the renderer, does NOT submit untrusted template input, and does NOT fetch any `file://`/internal URL it finds — it reads the code and reports.

## What it does

1. **Locate the renderer** — cite `<path:line>` and the exact call (`page.pdf()`, `wkhtmltopdf(...)`, `libreoffice --convert-to`, `PDFDocument`).
2. **Trace to the request** — is the render reached synchronously from an HTTP handler, or via a queued job? Cite the enqueue + the worker `<path:line>`, or flag SYNC.
3. **Inspect the sandbox** — read the launch flags / container config / request interceptor. Is page-content network denied? Is `file://`/`chrome:`/`blob:` aborted? Is there a host allowlist? Cite `<path:line>`; flag SSRF/LFI if open.
4. **Inspect the template render** — is the template a fixed, version-controlled asset with data BOUND through an autoescaping engine, or is user data concatenated / compiled / marked safe? Cite `<path:line>`; flag template injection / XSS.
5. **Inspect the caps** — wall-clock timeout (and whether the process is actually killed), max pages, max output bytes, asset count/size cap, container CPU/mem limit. Cite `<path:line>`; flag DoS if missing.
6. **Inspect determinism** — for legal/audit docs, is `now()` frozen to an as-of snapshot, the template version + locale/tz/currency pinned, money summed as integer minor units? Cite the stamp `<path:line>`.
7. **Inspect storage + delivery** — tenant segment in the key? Private bucket? Signed + short-expiry URL, or public/guessable? Cite `<path:line>`; flag cross-tenant leak.
8. **Inspect idempotency** — key derived from `hash(canonical data)+templateVersion`; existing-artifact reuse. Cite `<path:line>`.
9. **Report** — the eight verdicts, the BLOCKERs first, and the top fix.

## Flow

```text
locate renderer call (<path:line>)
  -> trace to request handler            [SYNC on request thread => BLOCKER]
  -> read launch flags + interceptor     [network on / file:// allowed => SSRF/LFI BLOCKER]
  -> read template render call           [concat / compile(userString) / {{{ }}} => injection BLOCKER]
  -> read caps                           [no timeout/page/byte/asset cap => DoS BLOCKER]
  -> read determinism stamp              [new Date()/float/unpinned on legal doc => finding]
  -> read storage key + delivery URL     [public bucket / no tenant scope => cross-tenant BLOCKER]
  -> read idempotency key                [regenerate-every-request => finding]
  -> report: 8 verdicts + BLOCKERs first + top fix
```

## Output

```
/audit-document-pipeline — <doc type> @ <path:line>

Renderer:        page.pdf() (puppeteer) @ documents/render-document.worker.ts:38
Sync/async:      ASYNC — enqueued @ documents.controller.ts:41, worker @ render-document.worker.ts:14
                   [or: SYNC on request thread @ invoices.controller.ts:22 — BLOCKER]
Sandbox:         network DENIED + file://+host-allowlist @ sandboxed-renderer.ts:27
                   [or: default launch, page content can fetch any URL — SSRF/LFI BLOCKER]
Templating:      bound + autoescaped (nunjucks, autoescape:true) @ render-template.ts:18
                   [or: renderString('...'+user.name) @ x.ts:9 — template injection / XSS BLOCKER]
Caps:            timeout=15s(kill) pages<=50 bytes<=20MB assets<=40 @ sandboxed-renderer.ts:44
                   [or: NONE — DoS BLOCKER]
Determinism:     templateVersion+asOf+locale/tz pinned, now() frozen @ determinism.ts:21
                   [or: stamps new Date(), sums float total — NON-DETERMINISTIC — finding]
Storage/delivery: docs/<tenantId>/... private bucket, signedUrl expiresIn:1h @ worker.ts:55
                   [or: public bucket, contract-<seqId>.pdf — cross-tenant BLOCKER]
Idempotency:     key hash(data)+templateVersion, reuse existing @ documents.controller.ts:33
                   [or: re-renders on every download — finding]

Verdict: OK | NEEDS-SANDBOX | NEEDS-ASYNC | BLOCKER(ssrf) | BLOCKER(injection) | BLOCKER(leak)

Top recommendation:
  - <e.g. enqueue the render + return jobId; or disable renderer network + block file://;
     or bind data into a fixed autoescaped template; or move storage under docs/<tenantId>/ + sign>
```

## Rules

- READ-ONLY audit. Never execute the renderer, never submit untrusted template input, never fetch a `file://`/internal URL discovered in the code.
- Cite-or-halt: real renderer call, real enqueue, real sandbox flags, real template render, real caps, real storage key, real idempotency key — or halt naming what's missing.
- A synchronous render on the request thread is a BLOCKER, reported as such — not an aside.
- A renderer with network enabled or `file://` reachable from page content is an SSRF/LFI BLOCKER even if "we control the template" — template DATA is user-controlled.
- User data concatenated/compiled into the template is a BLOCKER (injection + XSS) until the autoescaped bind is shown.
- A public/guessable/unscoped document URL is a cross-tenant BLOCKER; report it first alongside SSRF.
- Never report a sandbox, a cap, or a signed URL you didn't read in source.

## Cross-references

- `.claude/rules/document-generation-discipline.md` — the hard-rule list this command enforces (async, sandbox, autoescape, caps, determinism, tenant scope, signed delivery, idempotency).
- `ai/patterns/document-pipeline.md` — the async render job + sandboxed renderer + autoescaped bind + caps + determinism stamp + signed delivery + idempotency shapes.
- `<rules-path>/reporting` — the shared async-job + signed short-lived private-bucket delivery spine.
- `<agents-path>/document-generation-reviewer.md` — review gate that consumes these findings.
