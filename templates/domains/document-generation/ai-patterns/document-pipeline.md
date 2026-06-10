---
name: document-pipeline
description: "Pattern: Document generation (async, sandboxed render, template-injection-safe, signed delivery)"
kind: ai-pattern
---

# Pattern: Document generation (async, sandboxed render, template-injection-safe, signed delivery)

> **Hard rule** — A PDF/DOCX/print artifact is rendered in an idempotent ASYNC job, never on the request thread; the headless renderer runs SANDBOXED with network DISABLED and `file://`/local-path BLOCKED (no SSRF, no LFI); user data is BOUND into an AUTOESCAPED template, never concatenated into the template source (no injection, no XSS-in-PDF); every render enforces timeout + page + byte + asset caps; legal/audit output is DETERMINISTIC, version + as-of stamped; the artifact is tenant-scoped, delivered via a signed short-lived URL, and idempotent on `hash(data) + templateVersion`.

**When to apply**
- Any server-rendered legal/financial/transactional document — invoices, contracts, statements, certificates, receipts, shipping labels — built from tenant data via a headless browser (Puppeteer/Chromium), `wkhtmltopdf`, LibreOffice, or a PDF/DOCX library.
- Multi-tenant products where each document belongs to exactly one tenant and a document must never cross that line.
- Documents that must be reproducible (re-render the same invoice next year and get the same content) and/or are taken as a source of truth.

**When NOT to apply**
- A trivial, no-user-data, no-tenant-data static PDF (a fixed terms-of-service sheet) — the async + sandbox machinery is overhead; still pin the template version.
- Pure client-side print (`window.print()` of already-authorized, already-rendered DOM) where no server renderer and no untrusted-template surface exists.
- An export of tabular rows (CSV/XLSX) — that's `<rules-path>/reporting` (streamed, replica-routed); this pattern is for laid-out documents.

**Halt conditions / mandatory cites**
- Cite the async job enqueue + the render worker at `<path:line>`. A render computed inline in the request handler = halt.
- Cite the renderer launch with network DISABLED + `file://`/local-path BLOCKED at `<path:line>`. A renderer with default (network-on, file-on) settings = halt (SSRF/LFI primitive).
- Cite the template-render call binding data into an autoescaped engine at `<path:line>`. Any `compile(userString)` / string concat into the template / `{{{ }}}`/`|safe` over user data = halt (template injection / XSS).
- Cite the caps — timeout (process killed on overrun), max pages, max output bytes, asset cap — at `<path:line>`. No caps = halt (DoS).
- Cite the determinism stamp (template version + as-of + pinned locale/tz, frozen `now()`) for legal docs at `<path:line>`.
- Cite the tenant-scoped storage key + signed short-lived URL issuance + the idempotency key derivation at `<path:line>` each.
- Grep ban: "the renderer is sandboxed / safe / deterministic" without file:line for the sandbox flags, the autoescaped bind, the caps, and the idempotency key.

## Why

Server-side document generation is the rare workload that is simultaneously a remote-code/SSRF surface, a cross-tenant leak surface, a DoS surface, and a correctness/legal surface — all in one render call. Five failure modes recur:

1. **The renderer is an SSRF/LFI primitive** — Puppeteer and wkhtmltopdf are full browsers. Hand them template HTML containing `<img src="http://169.254.169.254/...">` or `<img src="file:///etc/passwd">` and they will fetch it and bake it into the document. The renderer MUST run with no network and no `file://`.
2. **The template is a code-exec surface** — concatenating user data into a template, or compiling a user-controlled template string, is server-side template injection. Bind data as autoescaped parameters into a fixed template.
3. **It blocks or melts** — a synchronous render holds a request worker for seconds; an uncapped render OOMs the box on a huge document. Render async, with hard caps, killed on overrun.
4. **It leaks across tenants** — a contract stored at a public, guessable URL with no tenant scope is read by incrementing an id. Tenant-scoped private storage + signed short-lived URLs (same spine as `<rules-path>/reporting`).
5. **It isn't reproducible** — a legal invoice that re-renders with a different timestamp / a different float total isn't the document the customer received. Pin the template version + as-of snapshot; freeze volatile inputs.

The pattern: declare a DOCUMENT SPEC, enqueue an async render job keyed on `hash(data)+templateVersion`, render a FIXED autoescaped template with BOUND data in a SANDBOXED (network-off, file-off, capped) renderer, stamp determinism metadata, store under a tenant-scoped key, and deliver a signed short-lived URL.

## Document spec (declarative)

```ts
// src/modules/documents/core/document-spec.ts

export interface DocumentSpec<Data> {
  type: string;                       // 'invoice', 'contract', 'statement'
  /** Version-controlled template id. The template is a FIXED asset, never user/DB-supplied. */
  templateId: string;
  templateVersion: string;            // bumped on any template change; stamped into the artifact
  format: 'pdf' | 'docx';
  /** Whether this is a legal/audit document that MUST be deterministic + reproducible. */
  legal: boolean;
  /** Render caps — every render enforces these or fails the job. */
  caps: {
    timeoutMs: number;                // wall-clock; renderer process is KILLED on overrun
    maxPages: number;
    maxBytes: number;
    maxAssets: number;                // images/fonts referenced
  };
  /** PII columns in this doc — gate generation + fetch + audit on these. */
  pii: ReadonlyArray<keyof Data>;
}
```

The spec — not raw renderer calls in a controller — is what feature code authors. Sandbox, caps, autoescape, determinism, scoping, and delivery are derived from it.

## Request handler: enqueue, never render

> The TypeScript below uses NestJS-style decorators + helpers for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the framework decorators (Express / FastAPI / Spring / Rails), the queue + repo your project exposes, the DI mechanism. The SHAPE — validate -> derive an idempotent key on `hash(data)+templateVersion` -> return the existing artifact if present -> else enqueue -> return a `jobId` — is what's universal.

```ts
// src/modules/documents/documents.controller.ts

@Controller('/documents')
export class DocumentsController {
  constructor(
    @Inject(QUEUE) private queue: Queue,
    @Inject(DOC_JOBS) private jobs: DocumentJobsRepo,
    @Inject(DOC_DATA) private data: DocumentDataSource,
  ) {}

  @Post('/:type')
  async requestDocument(
    @Param('type') type: string,
    @Body() body: { entityId: string },
    @Ctx() ctx: AuthContext,                 // tenant + permissions from HERE, never the body
  ): Promise<{ jobId: string; statusUrl: string }> {
    const spec = SPECS[type];

    // Authorize on the underlying entity in the caller's tenant — endpoint auth is not enough.
    const snapshot = await this.data.snapshotForTenant(spec, body.entityId, ctx.tenantId);
    if (!snapshot) throw new NotFoundError();              // wrong tenant => not found, no leak

    // Idempotency: key on canonical data hash + template version. Same inputs => same artifact.
    const dataHash = sha256(canonicalize(snapshot.data));
    const docKey = `doc:${type}:${ctx.tenantId}:${dataHash}:${spec.templateVersion}`;

    const existing = await this.jobs.findByKey(docKey);
    if (existing && existing.status === 'ready') {
      return { jobId: existing.id, statusUrl: `/documents/jobs/${existing.id}` };  // reuse, don't re-render
    }

    const job = await this.jobs.create({
      key: docKey, type, status: 'queued', tenantId: ctx.tenantId,
      templateVersion: spec.templateVersion, dataHash, asOf: snapshot.asOf,
    });
    await this.queue.add('render-document', {
      jobId: job.id, type, tenantId: ctx.tenantId, requestedBy: ctx.userId,
      data: snapshot.data, asOf: snapshot.asOf,           // immutable snapshot — reproducible
    });
    return { jobId: job.id, statusUrl: `/documents/jobs/${job.id}` };
  }
}
```

The request returns in milliseconds with a `jobId`. It NEVER launches a renderer and NEVER returns the bytes. A re-request with identical inputs returns the already-rendered artifact.

## Autoescaped template render: BIND data, never concatenate

```ts
// src/modules/documents/core/render-template.ts

import nunjucks from 'nunjucks';

// The template environment autoescapes by default. Templates are loaded from a FIXED,
// version-controlled directory — NEVER from the database, request, or user input.
const env = nunjucks.configure(TEMPLATE_DIR, {
  autoescape: true,                  // HTML-escape every interpolation by default
  throwOnUndefined: true,            // fail loud on a missing field, never render "undefined"
});

export function renderDocumentHtml<Data>(spec: DocumentSpec<Data>, data: Data, stamp: DeterminismStamp): string {
  // Data is BOUND as template parameters and autoescaped. There is NO string concatenation
  // into the template source and NO compile() of a user-controlled string. The template
  // ('invoice.njk') is fixed; { doc, stamp } are escaped parameters.
  return env.render(`${spec.templateId}.njk`, { doc: data, stamp });
}

// ANTI-PATTERN (do NOT do this) — both are template injection / XSS:
//   nunjucks.renderString(`<h1>Invoice for ${customer.name}</h1>`, {});   // compiles user data as template
//   const html = '<h1>Invoice for ' + customer.name + '</h1>';            // concatenated, unescaped
// customer.name = '<img src=x onerror=fetch(...)>' or '{{ range.constructor(...) }}' => XSS / SSTI.
```

The template is a reviewed asset; the data is parameters. Autoescape neutralizes `<script>` / `onerror` in tenant data; binding (not compiling) neutralizes SSTI.

## Sandboxed renderer: network DISABLED, `file://` BLOCKED, capped

```ts
// src/modules/documents/core/sandboxed-renderer.ts

import puppeteer, { Browser, HTTPRequest } from 'puppeteer';

const ASSET_ALLOWLIST = /^https:\/\/cdn\.internal-static\.example\/(fonts|img)\//;  // bundled assets only

export class SandboxedRenderer {
  private browser: Browser | null = null;

  /** Launch with NO sandbox-bypass, NO network from page content, isolated profile. */
  private async launch(): Promise<Browser> {
    return puppeteer.launch({
      headless: true,
      args: [
        '--no-sandbox', '--disable-setuid-sandbox',  // (only if the CONTAINER is already locked down)
        '--disable-dev-shm-usage',
        '--disable-extensions',
        '--disable-background-networking',
        '--no-first-run',
      ],
      // The container itself runs egress-denied, read-only FS, dropped caps, seccomp — see media-processing.
    });
  }

  async renderPdf(html: string, spec: DocumentSpec<any>): Promise<Buffer> {
    const browser = (this.browser ??= await this.launch());
    const page = await browser.newPage();

    let assetCount = 0;
    await page.setRequestInterception(true);
    page.on('request', (req: HTTPRequest) => {
      const url = req.url();
      // BLOCK file:// + local schemes (LFI) and any non-allowlisted host (SSRF). Allow only:
      //  - the document itself (data:/about:blank/the injected html)
      //  - bundled assets from the internal static allowlist, capped in count.
      if (url.startsWith('file:') || url.startsWith('chrome:') || url.startsWith('blob:')) return req.abort();
      if (url.startsWith('http') && !ASSET_ALLOWLIST.test(url)) return req.abort();   // SSRF blocked
      if (++assetCount > spec.caps.maxAssets) return req.abort();                      // asset DoS cap
      return req.continue();
    });

    // Set the HTML directly (no navigation to a URL); wait only for the bundled assets.
    await page.setContent(html, { waitUntil: 'networkidle0', timeout: spec.caps.timeoutMs });

    // Wall-clock cap: race the render against a hard timeout; KILL the page/process on overrun.
    const pdf = await withTimeout(
      page.pdf({ format: 'A4', printBackground: true, timeout: spec.caps.timeoutMs }),
      spec.caps.timeoutMs,
      async () => { await page.close(); throw new RenderTimeoutError(spec.type, spec.caps.timeoutMs); },
    );

    await page.close();

    if (pdf.byteLength > spec.caps.maxBytes) throw new RenderTooLargeError(spec.type, pdf.byteLength);
    const pages = await countPdfPages(pdf);
    if (pages > spec.caps.maxPages) throw new RenderTooManyPagesError(spec.type, pages);

    return pdf;
  }
}
```

Network from page content is denied except for an allowlisted, count-capped set of bundled assets; `file://` is aborted; the render is timed-out, page-capped, byte-capped. The renderer cannot reach the metadata service, internal hosts, or local files.

## Determinism stamp: version + as-of, frozen volatile inputs

```ts
// src/modules/documents/core/determinism.ts

export interface DeterminismStamp {
  templateVersion: string;
  asOf: string;            // ISO instant the data was snapshotted at — NOT render time
  locale: string;          // pinned per spec/tenant, never the server ambient locale
  timezone: string;        // pinned; see i18n
  currency: string;
  generatedFrom: string;   // dataHash — ties the artifact to its exact inputs
}

export function buildStamp(spec: DocumentSpec<any>, snapshot: { asOf: string; dataHash: string },
                           loc: { locale: string; timezone: string; currency: string }): DeterminismStamp {
  // Volatile inputs are FROZEN. The document uses `asOf`, never `new Date()`; ids/counters come from
  // the snapshot, never live; money is summed in integer minor units and formatted with `currency`.
  return {
    templateVersion: spec.templateVersion,
    asOf: snapshot.asOf,
    locale: loc.locale, timezone: loc.timezone, currency: loc.currency,
    generatedFrom: snapshot.dataHash,
  };
}
```

A re-render of the same `dataHash` + `templateVersion` reproduces the document the customer received — same timestamp, same totals, same layout. The stamp is embedded in the artifact + recorded on the job.

## Worker: render, audit, store tenant-scoped, deliver signed

```ts
// src/modules/documents/workers/render-document.worker.ts

@Processor('render-document')
export class RenderDocumentWorker {
  constructor(
    @Inject(RENDERER) private renderer: SandboxedRenderer,
    @Inject(DOC_JOBS) private jobs: DocumentJobsRepo,
    @Inject(ARTIFACTS) private artifacts: ArtifactStore,
    @Inject(AUDIT_LOG) private audit: AuditLog,
    @Inject(NOTIFY) private notify: Notifier,
  ) {}

  @Process()
  async run(job: Job<RenderDocumentData>): Promise<void> {
    const { jobId, type, tenantId, requestedBy, data, asOf } = job.data;
    const spec = SPECS[type];

    const dataHash = sha256(canonicalize(data));
    const stamp = buildStamp(spec, { asOf, dataHash }, resolveLocale(tenantId));
    const html = renderDocumentHtml(spec, data, stamp);     // autoescaped, bound, fixed template

    const bytes = await this.renderer.renderPdf(html, spec); // sandboxed, capped, killed on overrun

    // Tenant-scoped key in a PRIVATE bucket — never public, never a guessable flat id.
    const key = `documents/${tenantId}/${type}/${dataHash}-${spec.templateVersion}.pdf`;
    const artifact = await this.artifacts.put(key, bytes, { contentHash: sha256(bytes), ttlDays: 365 });

    // Audit generation BEFORE issuing any link (PII docs are an audited event).
    await this.audit.record({
      action: 'document.generate', tenantId, actorId: requestedBy, docType: type,
      templateVersion: spec.templateVersion, dataHash, asOf, contentHash: artifact.contentHash,
      pages: artifact.pages, bytes: bytes.byteLength,
    });

    const url = await this.artifacts.signedUrl(key, { expiresIn: '1h' });  // short-lived, mirrors reporting
    await this.jobs.markReady(jobId, { artifactKey: key, contentHash: artifact.contentHash, stamp });
    await this.notify.documentReady(requestedBy, { jobId, url });
  }
}
```

Memory stays bounded; the renderer is sandboxed and capped; the artifact is tenant-scoped, content-hashed, audited, and delivered via a signed short-lived URL. A re-run with the same `dataHash` writes the same key (idempotent).

## Signed, access-controlled fetch (PII gating)

```ts
// src/modules/documents/documents.download.controller.ts

@Get('/jobs/:jobId/download')
async download(@Param('jobId') jobId: string, @Ctx() ctx: AuthContext): Promise<{ url: string }> {
  const job = await this.jobs.findReadyForTenant(jobId, ctx.tenantId);   // tenant-scoped lookup
  if (!job) throw new NotFoundError();                                   // other tenant => not found

  // Re-authorize on the underlying entity + log every download of a PII document.
  await this.authz.assertCanDownload(ctx, job.docType, job.dataHash);
  await this.audit.record({ action: 'document.download', tenantId: ctx.tenantId,
    actorId: ctx.userId, docType: job.docType, contentHash: job.contentHash });

  return { url: await this.artifacts.signedUrl(job.artifactKey, { expiresIn: '5m' }) };  // fresh short URL
}
```

The signed URL is minted only for the authorized actor in the owning tenant, scoped per-download, short-lived, and audited.

## Common mistakes

### Synchronous render
`GET /invoices/:id/pdf` launches Puppeteer inline → 4s request → gateway timeout → retries spawn more Chromium → box falls over. Enqueue a job; return a `jobId`; render in a worker.

### SSRF via the renderer
Template data with `<img src="http://169.254.169.254/...">` → the renderer fetches it and leaks cloud creds into the PDF. Disable network from page content; allowlist hosts; abort everything else.

### LFI via the renderer
`<img src="file:///etc/passwd">` / `<link href="file:///app/.env">` → wkhtmltopdf reads the local file into the document. Abort `file:`/`chrome:`/`blob:` schemes at the request interceptor.

### Template injection / XSS-in-PDF
`renderString('<h1>' + customer.name + '</h1>')` or `{{{ customer.name }}}` → SSTI / active content in the document. Compile a FIXED template; bind `{ customer }` as autoescaped data.

### No caps → DoS
A 200,000-line invoice or `height: 1e8px` makes the renderer allocate gigabytes and hang. Cap timeout (kill on overrun), pages, bytes, assets; fail the job.

### Cross-tenant doc leak
`s3://public-docs/contract-<sequentialId>.pdf` → increment the id, read another tenant's contract. Tenant-scoped key in a private bucket; signed short-lived URL.

### Non-deterministic legal doc
The PDF stamps `new Date()` and re-sums a float, so a re-render differs from the issued copy. Freeze `now()` to `asOf`; sum integer minor units; pin template version + locale/tz.

### Regenerate-on-every-download
Every download re-renders → wasted CPU and a risk of producing a different artifact. Idempotency key on `hash(data)+templateVersion`; return the stored artifact.

### Unprotected PII document
A signed URL any user can mint for any account id → balance leak. Scope the URL to the authorized actor + tenant; audit the download.

### Unbounded / remote fonts
`@font-face { src: url('https://user-controlled/...') }` → SSRF + bloat. Bundle + allowlist fonts; block remote `@font-face` at the same interceptor.

## Cross-references

- `<rules-path>/document-generation-discipline.md` — the hard-rule list (async, sandboxed render, autoescaped templating, caps, determinism, tenant-scoped signed delivery, idempotency).
- `<rules-path>/reporting` — the same async-job + signed short-lived private-bucket delivery spine; documents and reports share the artifact-delivery contract.
- `<rules-path>/background-jobs` — queued render job semantics (idempotency, resumability, DLQ, observability).
- `<rules-path>/media-processing` — sandboxed-renderer / untrusted-input hardening (egress denial, read-only FS, dropped capabilities, seccomp) the renderer container reuses.
- `<rules-path>/i18n` — locale / timezone / currency / RTL inside documents, pinned into the determinism stamp.
- `<rules-path>/audit-log-integrity.md` — document generation + download is an audited event; what to record.
- `<commands-path>/audit-document-pipeline.md` — cite-or-halt diagnostic of a specific document pipeline.
- `<agents-path>/document-generation-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-document-rendering-stack.md` — ADR pinning the renderer + sandbox model + determinism/retention contract.
