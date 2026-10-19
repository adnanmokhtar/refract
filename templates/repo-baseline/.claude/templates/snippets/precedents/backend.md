# Precedents — Backend (HTTP contract, validation boundary, edge error mapping, wire format, job lifecycle, state transitions)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in a **backend** class: the wiring between the HTTP framework and the domain — whether
validation runs and on what, what the transform and the serializer do to values, which status and
shape the edge emits, what framework and library defaults do at the edge, the HTTP contract (status,
method, pagination, batch, spec), a job's contract with time, deploys and its own result, and
FSM-library transition semantics. The oracles that prove them are in
[`proof-oracles.md`](../proof-oracles.md) § Backend (V328–V357). The detectors are
`http-contract-scan` (HC §1–§13), `validation-boundary-scan` (VB §1–§9), `edge-error-scan`
(EE §1–§8), `wire-format-scan` (WF §1–§8), `job-lifecycle-scan` (JL §1–§7) and
`state-transition-scan` (ST §1–§2) (backend pack), run by `/backend-audit` and closed by
`/backend-fix`. `@api-reviewer` judges every detector row in refute mode; every BLOCKER and HIGH it
keeps goes once to `@verifier` mode `refute`. The state graph ST reads comes from business
`lifecycle-scan` (`status-graph.py`'s `edges.tsv`, judged by `business/agents/workflow-integrity`) when
the business pack is installed.

**Owned elsewhere.** A neighbour that sees the same site lists it as corroboration, deduped by
`file:line`; without the owner's pack the row is tagged `<class> (owner pack <x> not installed)`
and listed, never graded as the owner would grade it. Error body *content*, debug modes and
over-returning are security `data-exposure-scan` §1/§2; operator objects and mass assignment are
`injection-scan`; Idempotency-Key semantics on money, credit, order, paid-send and webhook routes
are `logic-race-scan` §4 (HC §6 takes every other route that accepts a key); upload caps are
`file-access-scan` §2. Enqueue or publish inside a transaction, model-callback side effects and
unconditional transition writes are database `transaction-scan` §1/§8. Outbound timeouts and
once-per-fleet schedules are performance `request-path-scan` §12/§20. Arithmetic, minor units and
the clock **in code**, an unchecked outbound status, a cast of an outbound response and a local
catch are code-quality (`correctness-smell-scan` §4/§6, `error-handling-scan` §3/§6,
`type-safety-scan` §1). Retry eligibility, consumer idempotency, locks and cross-service event
contracts are distributed-systems. Lazy config, dev defaults, flag defaults and migrate-on-boot
are devops (`deploy-safety-scan` §1/§6, `progressive-delivery` §4/§8). Consistency across sibling
endpoints is `api-consistency-audit` (same pack); correctness of one endpoint is HC/EE.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening** (or Refuted, where the entry says so) unless the
flip evidence is shown with a `file:line`, a lockfile line, a config value or a recorded oracle
run. Ids are stable and lettered by family: detectors cite `precedents/backend.md § B-A3`,
`§ B-R8`, `§ B-G15`, `§ B-D4`, and the posting rules as `P1`…`P5`.

Index: the claim and the gates · posting rules P1–P5 · API, validation and edge B-A1–B-A18 ·
runtime, jobs, outbound and config B-R1–B-R16 · public API guidelines B-G1–B-G24 · real-repo
decoys B-D1–B-D17 · the incident record · rationalizations.

## The claim, restated

§ 1 of the protocol takes this shape here. A candidate that fits it with no concrete value is not a
finding.

> Through **[the real bootstrap: the app factory, its pipe, filter, adapter and serializer at the
> installed version]**, **[the request, job run or event]** reaching **[the handler, DTO, filter,
> serializer setting, processor or transition at file:line]** gets **[the status, body, value,
> run count or state]** where **[the contract source: the project's OpenAPI, `api-conventions.md`,
> an RFC MUST, the state graph]** says **[the expected one]**, proven by **[the V-number and its
> tier]**.

**Two parts, refuted separately.** Part A says *what the snippet is*: "this handler is mounted",
"this pipe is the one that runs", "this is a create, not an action", "this cron has side effects".
Part A is cheap to refute and is refuted first: a unit test that builds its own `ValidationPipe`
is not the pipe that ships (B-D7); a `@Get` that writes an audit row is not an unsafe GET (B-A6);
a route word inside a longer segment is not that word (B-D11).

**The proof rule.** A grep hit is a candidate. The class oracle in `proof-oracles.md` § Backend
at its tier is the proof: **U** (a request or job run through the project's real bootstrap — its
e2e harness when that imports the real app module, else the app factory driven by supertest,
`fastify.inject`, the DRF/Django test client, MockMvc, `httptest`), **T** (a tool's exit: oasdiff
with `--fail-on ERR`, Schemathesis with ≥ 1 stateful link, a linter rule that parsed the file), **S**
(a static fact with both ends cited: the setting and the code that depends on it) or **L** (a live,
non-production base URL under `--live`). A test that builds its own pipe, filter or `Fastify()`
proves nothing (P4). Without U, T or a two-ended S fact the row is **Unconfirmed** with the request
written out.

## Reading the seven gates for backend

| Gate | Backend |
|---|---|
| 1 Reachability | The route is mounted (its module imported by the app module the bootstrap uses), the processor registered, the scheduler entry enabled in a deployed process role. A controller no module imports is dead code |
| 2 Trigger | The input really reaches the edge: any client can send `null`, an unknown key, a wrong content type, a repeated query param, an enum key, a body above 2^53. A schedule really outlives its period only when its p99 run time or its data growth says so (B-R8) |
| 3 Version | The framework, adapter, validator, ORM, queue and scheduler versions **from the lockfile** (`UNREAD` when absent, never assumed). Defaults changed across the last major in a dozen places (Express 4→5, Nest Express→Fastify, pydantic v1→v2, Jackson 2→3, axum 0.7→0.8, Apollo 4→5): state the version or the row is Unconfirmed |
| 4 Existing control | **The wiring first** (P5): the `APP_PIPE`/`useGlobalPipes` pipe and its subclass, the `APP_FILTER` or error middleware, the response interceptor, the serializer config, the pagination kernel, the HTTP-client wrapper, the queue-producer wrapper, a scheduler base class or lease helper. Cross-file, never the matched line alone |
| 5 Impact | A client-visible status, body or value that differs from the contract; a 500 for client input; a lost or doubled job effect; a state change the graph forbids. Style, naming and "a stricter policy would be nicer" are Hardening |
| 6 Proof | The oracle fired failing first through the real bootstrap, or the S-tier two-ended fact. NOT-RUN tool exits (oasdiff without `--fail-on`, Schemathesis with 0 links) are never PASS and never proof |
| 7 Environment | The adapter in `main.ts`, the process `TZ` (image, manifests, JVM flag), the production database engine (B-R16), the proxy in front (its 413 and timeout pages), replica count for once-per-fleet rows (those are performance's) |

## Posting rules (lettered, never numbered)

- **P1 — Cite the contract.** A status, method or envelope finding names its contract source: the project's OpenAPI, `ai/api-conventions.md` / `_extracted-idioms.md § API conventions`, or an RFC MUST. Without one it is a style opinion → Hardening at most.
- **P2 — Show the payload that gets through.** A validation finding carries the request that passed the real pipe (the oracle line). "This DTO looks weak" is not a finding.
- **P3 — Route the attacker reading.** Any impact phrased "an attacker can…" goes to the security owner named above; backend reports the correctness half only.
- **P4 — Prove on the configuration that ships.** Adapter-, version- and engine-dependent behaviour is proven on the adapter in `main.ts`, the installed version and the production engine — never the one the auditor assumed.
- **P5 — One finding at the wrapper.** When every call goes through one helper (a global pipe, a global filter, a pagination kernel, an HTTP-client wrapper, a base processor), the finding is at the helper with N sites, not N findings.

## Settled questions — API, validation and edge

| § | Looks like a defect | Not a defect when (must be true) | Flips back when |
|---|---|---|---|
| B-A1 | 204 with a body | DELETE/PUT whose spec documents 204 and no client reads the returned value | the handler computes data a client is documented to receive (Node drops it silently) or the spec documents a 200 body |
| B-A2 | 200 with `{error}` / `{success:false}` | the API is documented RPC-over-HTTP, GraphQL or JSON-RPC, where 200 + an error object is the protocol (tRPC, GraphQL verified) | any client, cache, monitor or retry policy keys on the HTTP status (REST, practically always) |
| B-A3 | POST returns 201 | the operation creates an addressable resource and sets `Location` | it is an action endpoint (search, login, calculate, preview, verify) — then 201 is the defect (the Nest default) |
| B-A4 | PUT that merges | the API documents PUT as upsert/partial and has no PATCH → naming only, Low | consumers are generated from a spec that says "replace" |
| B-A5 | PATCH `null` ignored or written | the API documents its own patch dialect in which `null` is a value | `null` reaches a NOT NULL column (500) or the API claims RFC 7396 |
| B-A6 | GET with writes | the write is analytics, a view counter, an audit row, a cache warm, a lazy materialisation or an OAuth callback that must store the grant | business state changes (cancel, approve, unsubscribe without confirmation) |
| B-A7 | 400 vs 422 | the whole API uses one of them consistently (the Nest default 400 is legitimate) | an endpoint deviates from the declared convention (→ `api-consistency-audit` #2), or a syntax error is reported as 422 / a semantic one as 500 |
| B-A8 | 404 vs 403 for another user's resource | — never backend's | route to security; uniform 404 for unauthorised reads is often the intended policy |
| B-A9 | No 405 / `Allow` | a public API that uniformly answers 404 for an unknown method+path and documents it | the spec documents 405, or OPTIONS advertises `Allow` while the method 404s (Express auto-OPTIONS, verified) |
| B-A10 | Offset pagination | small admin tables, or an `asOf`/snapshot parameter pins the set | the list is appended to while paged (feeds, exports, sync) or the sort key is not unique |
| B-A11 | Unknown keys stripped | a documented tolerant reader (forward compatibility) | a client typo silently changes behaviour (a misspelled optional field falls back to its default with 200) |
| B-A12 | Fastify response schema drops fields | the projection hides internals on purpose — the reason to use response schemas | a field added in code is meant to ship (drift), or a value is *changed* (`12.7 → 12`) |
| B-A13 | `z.coerce.number()` / `coerce.boolean()` | env parsing at boot where an empty value cannot occur by deployment config | the field is optional, may be empty, or is a query filter |
| B-A14 | Idempotency key reused with a new body | the endpoint is naturally idempotent (PUT to a client-chosen id) and ignores the key by documented design | the server replays the first response and the client believes the second, different request succeeded |
| B-A15 | Express 4 `async` handler | every handler body is wrapped (`try/catch` + `next(e)`, or `express-async-errors`) | any `await` can reject with no wrapper → process crash on Node 22 (verified) |
| B-A16 | `req.body as Foo` | — never backend's class | route to code-quality `type-safety-scan`; backend's class is BV-01 (the pipe cannot see the type) |
| B-A17 | GraphQL answers 200 with `errors[]` | the GraphQL-over-HTTP norm with `application/json` | unmapped codes, unmasked messages (→ security), or alerting reads only the HTTP status |
| B-A18 | Spec-linter findings (Spectral, Redocly, OWASP ruleset) | — never a code finding | a spec-level rule backed by a runtime oracle failure (Schemathesis, Prism) |

## Settled questions — runtime, jobs, outbound, config

| § | Looks like a defect | Not a defect when (must be true) | Flips back when |
|---|---|---|---|
| B-R1 | A library default that *could* be unsafe | the default is safe on the installed version: urllib3 `Retry` does not retry POST; APScheduler `max_instances=1`; multer cleans up on its own limit errors and aborts; pydantic v2 serializes Decimal as a string; Go `json` into `int` rejects `19.99` (all verified) | configuration overrides the safe default — report the override, never the library |
| B-R2 | Float near money | a ratio, score or rate; or a documented `number` contract that the client parses with a decimal library | a client does arithmetic or string comparison on the value, or re-submits it to a charge |
| B-R3 | Naive datetime | a genuine wall-clock field (`LocalTime`, store opening hours) or a date-only value | the field is an instant (created, paid, expires) or a cursor key |
| B-R4 | Banker's rounding | chosen and written in the spec or an ADR | the rendered number is the charged number and the PSP rounds differently |
| B-R5 | State-machine "ignore" settings | UI statecharts, or server code that checks `can()` / the return value before responding | the handler **continues** to a side effect (response "refunded", PSP call, email) |
| B-R6 | Enqueue inside a transaction | **moved:** the class is database `transaction-scan` §1 (BJ-01). Settled in [`precedents/data.md`](data.md) § 6 (an outbox row in the same transaction is the fix) and [`precedents/distributed.md`](distributed.md) § 11 (after-commit helpers keep the loss window). Backend prints the row `→ database transaction-scan §1 (k)` and never grades it | — |
| B-R7 | Job signature changed | the queue is drained in an **enforced** deploy runbook, or payloads carry a `version` with a dispatcher for every version | the queue can hold messages across a deploy (delays, retries, scheduled jobs, ETA) |
| B-R8 | Scheduled job may overlap | idempotent, read-only, cheap (a process-local metrics sampler, a cache warm) | the job has side effects and can outlive its period |
| B-R9 | Schedule with no zone | a UTC schedule with a UTC business meaning in a UTC process (`TZ` unset or UTC in the image and manifests — `precedents/distributed.md` § 35) | the schedule hour is 00:00–03:59 in a DST zone, or it is a business cutoff |
| B-R10 | Missing `return` after `http.Error` | only a log line follows → Low | a write or side effect follows → High |
| B-R11 | Rails `return` inside `transaction do` | the app's Rails version is ≤ 6.1 or ≥ 7.2 **and** committing is the intent (class owned by database `transaction-scan`; backend cites this entry when it prints the routed row) | the version is 7.0/7.1 (rolls back), or the early return leaves a half-done unit committed — state the version either way |
| B-R12 | Outbound status unchecked | **moved:** the class is code-quality `error-handling-scan` §3 (BO-01); settled in [`precedents/code-quality.md`](code-quality.md). The wrapper rule (a shared client that checks status clears its callers) is P5 | — |
| B-R13 | POST retried by a library | **moved:** the class is distributed-systems `retry-deadline-scan` §5 (BO-02/BO-05); settled in [`precedents/distributed.md`](distributed.md) § 15 and § 17 (the same provider-honoured key on every attempt) | — |
| B-R14 | Lazy config read | an optional integration behind an explicit flag; a serverless handler that validates at module init (class owned by devops `deploy-safety-scan` §6; config validated inside a `load` function counts as validated) | a required key is read first inside a request |
| B-R15 | Repeated key in a non-HTTP loop | the producer's schema enforces unique keys (cite it) (class owned by security `logic-race-scan` §2) | the producer is a file, a partner or a stored request with no uniqueness |
| B-R16 | Tests on SQLite | production is SQLite | production is Postgres/MySQL and the class involves locking, ordering or isolation (`select_for_update` is a no-op on SQLite, verified) |

Migration-on-boot rows (the research's B-P20a–f: which runners lock, Prisma's 10 s wait, Rails
failing siblings, Laravel `--isolated` exiting 0, stuck lock rows, Drizzle's watermark) are not
backend's: the finding is devops `deploy-safety-scan` §1 and the settled table is
[`precedents/performance.md`](performance.md) § 77.

## Settled questions from public API guidelines

Google AIPs, the Microsoft/Azure REST API Guidelines and the Zalando RESTful API Guidelines are CC
BY 4.0: cite the rule id and paraphrase, never embed text. Stripe text is proprietary: link only.
Rows read 2026-10-14 from local copies unless tagged [K].

| § | Defect only when | Acceptable when | Cite | Classes |
|---|---|---|---|---|
| B-G1 | a PATCH handler writes every DTO field, so an omitted field is wiped | only present fields (merge patch) or an explicit update mask are applied; no mask = populated fields; `*` = full replace | AIP-134; Azure `rest-patch-use-merge-patch` | BA-09, BV-14 |
| B-G2 | PUT is documented as replace but keeps missing fields, or PATCH is the only verb and it replaces | PUT replaces and resets fields an older client does not know | AIP-134; Azure PUT | BA-09 |
| B-G3 | an Update writes a lifecycle field directly (`status: "shipped"` via PATCH) | state changes go through a custom method or an action endpoint | AIP-134 | BS-01/03 (security for the authz meaning) |
| B-G4 | a resource exposes an etag/version but Update ignores it, or a stale etag answers 200 | a mismatch fails (409 `ABORTED`, or 412 on `If-Match`) | AIP-134, AIP-154; Azure conditional requests | BA-05/09 |
| B-G5 | a non-idempotent POST has no dedupe key **and** clients or SDKs retry it | the key is optional; the window is stated (Azure ≥ 5 min, Stripe v1 ≥ 24 h); the key lives on the request, never on the resource | AIP-155; Azure `Repeatability-Request-ID`; Zalando #229–231 | BA-10 (absence → `api-consistency-audit` #7) |
| B-G6 | a replay re-executes or returns a different success (a new id) | the stored first response is replayed; AIP-155 allows the **current** resource state when history was not kept | AIP-155; Zalando #230 | BA-10 |
| B-G7 | the same key with a different body is silently honoured | any 4xx on mismatch — sources disagree on the code (409, 422 in the IETF draft, a generic error at Stripe): consistency within the API is the rule, not the number | Stripe docs; IETF draft-07 [K] | BA-10 |
| B-G8 | the key is stored before validation (a fixed retry is wrongly refused), or a 5xx is never stored and the retry repeats a half-done effect | Stripe v1 stores once execution begins (500s included) and not on validation failure or concurrent conflict; Stripe v2 drives the work to completion on retry — either, documented | Stripe idempotent requests | BA-10, BJ-10 |
| B-G9 | a list endpoint returns an unbounded array | a collection bounded by construction — AIP still advises paginating at the outset because adding it later is breaking | AIP-158 | BA-11 |
| B-G10 | an over-max `page_size` → 400, a missing one → 400, or there is no server max | over-max is **coerced down**; negative → invalid argument; fewer than asked (even 0 with a token) is legal | AIP-158 | BA-11 |
| B-G11 | a token reused with changed filters or order silently mixes result sets | changed arguments with a token → invalid argument (page size excepted); `nextLink` carries all query params | AIP-158; Azure collections | BA-11 |
| B-G12 | the token is parseable (`base64({offset})`, a raw id) or is treated as authorization | opaque and URL-safe; may expire; never grants access | AIP-158 "Opacity" | BA-11 (authz → security) |
| B-G13 | `next` is present on the last page, or `nextLink: null` | absence signals the end | AIP-158; Azure `nextlink-value-never-null` | BA-11 |
| B-G14 | offset pagination on a large or insert-hot collection that clients iterate to completion | offset on small admin lists; Zalando cursors are SHOULD; `total` optional and may be an estimate | Zalando #160, #161, #254; AIP-158 | BA-11 (= B-A10) |
| B-G15 | a synchronous batch commits partially and answers one status | sync batch atomic (AIP-233/234/235), or 207 with a per-item status (Zalando #152); async batches may be partial with per-item status | AIP-231–235; Zalando #152 | BA-12 |
| B-G16 | error bodies differ per route or carry only free text clients must parse | one envelope with a stable machine code (`ErrorInfo.reason`; Azure `x-ms-error-code` == body code; problem+json) | AIP-193; Azure error rules; Zalando #176/#177 | BA-14, BE-08 |
| B-G17 | one route strips unknown fields and another 400s, undocumented | **two settled stances** — Azure rejects unknown fields with 400; Zalando #108/#111 keep schemas open and clients tolerant: pick one per API and state it | Azure create/update; Zalando #108, #111 | BV-06 (= B-A11) |
| B-G18 | a field is renamed, removed or retyped, a required request field is added, a format is tightened, or an enum changes in place | additive optional fields; new enum values only where declared extensible | AIP-180; Zalando #106/#107/#109/#112; Azure extensible enums | BA-15 |
| B-G19 | minor versions are exposed, or the version drops out of `nextLink` / `Operation-Location` | **URL versioning is not itself a defect**: AIP-185 and Azure allow it, Zalando #115 forbids it — guidelines disagree | AIP-185; Azure versioning; Zalando #113–115 | BA-13 (`/v1`-`/v2` mix → `api-consistency-audit` #5) |
| B-G20 | 200 with `{error}`; 500 for client input; an upstream 4xx/5xx proxied unchanged | the most specific code; 429 with `Retry-After`; downstream errors mapped to our own semantics | Zalando #243, #220, #153 | BA-05, BO-07 |
| B-G21 | validation errors with no field-level detail | GitHub-style 422 with `errors[]` of `{resource, field, code}`, 400 for unparseable JSON | GitHub REST docs [K] | BA-14, BX-04 |
| B-G22 | a long operation is held on the request thread, or 202 has no status URL | 202 + `Operation-Location` to a status monitor | Azure LRO; AIP-151 | BA-01 (async create) |
| B-G23 | `null` means "clear" on one route and "unchanged" on another | null and absent mean the same — except merge patch, where null **is** delete: state which | Zalando #123; RFC 7396 | BA-09, BV-05 |
| B-G24 | money as a float, an amount without a currency, local-time strings | a money object (amount + ISO 4217 currency); RFC 3339 date-time | Zalando #169, #173 | BM-01/05/08 |

## Real-repo decoys (batch-5 eval, read-only run, 2026-10-14)

From a hardened NestJS 11 monorepo on `@nestjs/platform-fastify` with MikroORM 6.6, class-validator
0.15, BullMQ 6.3 and `@nestjs/schedule` 6 (partial copy: no lockfile, so every version-gated row
there was `UNREAD`). Each shape was a candidate that a read cleared; the clause in *must be true*
is what the verifier shows before it clears one, and *flips back* is what keeps it a finding.

- **B-D1 — A deliberate `@Body() body: unknown`** (VB §1). *Must be true:* the endpoint speaks a protocol that owns its error body (RFC 7591/6749 OAuth answering `{"error":"invalid_request"}`, a JSON-RPC dispatcher), and a hand parser cited by `file:line` bounds **every** field (type, length, enum) before use; a `Record<…>` query on a third-party OAuth callback is the same case. *Flips back:* one field reaches the domain unparsed, or the parser is not on every path.
- **B-D2 — `@Res()` routes** (EE §5, BN-10). *Must be true:* every branch sends or throws (a throw reaches the global filter), and the reason for `@Res()` is written (webhook acks, file bodies, protocol bodies, redirects). Record the trade: these routes bypass the response, idempotency and deadline interceptors. *Flips back:* a branch returns a value with no send (a hang), or a route bypasses an interceptor its contract needs.
- **B-D3 — `reply.status(…)` and `res.redirect(url, 302)` on Fastify** (EE §3). *Must be true:* the adapter is Fastify — `.status()` is a valid `FastifyReply` alias of `.code()`, and `(url, code)` is the **v5** redirect order (v4 was `(code, url)`, so read the installed major). *Flips back:* an Express-only call (`.json(`, `.sendStatus(`, `.set(`, `.setHeader(`) on the Fastify reply.
- **B-D4 — An internal drain ordered by one non-unique key** (HC §7). *Must be true:* the query is an outbox relay, a retention sweep or a job picker whose processed rows leave the filter, so a tie is picked up on the next pass; no client pages through it. *Flips back:* a client-visible list, or an **unpaged query cut at a cap** (`limit: CAP + 1` on a date column) — that is a B-V8 variant, low.
- **B-D5 — A `bigint` column typed `number`** (WF §2). *Must be true:* every read goes through one mapper, and a unit test pins the set of such columns so a new one fails the build; values stay below 2^53 by construction (cite the generator). *Flips back:* one read outside the mapper reaches a response or a carrier.
- **B-D6 — A v1 door that documents its own error shape** (EE §7). *Must be true:* the controller-scoped filter emits the documented legacy shape (`{"error": "<sentence>"}`) and the spec or doc says so. *Flips back:* its mapping table lacks arms the global one has (unique, FK, optimistic lock, DB timeout) — those still become 500 there (a minor EE §2 finding).
- **B-D7 — A unit test that builds its own pipe** (VB, P4). *Must be true:* the e2e harness imports the real app module and its shared configure function, and the hand-built pipe in the unit test uses the same options. *Flips back:* the only harness builds its own pipe or `Fastify()`, so no test ever ran the shipped wiring.
- **B-D8 — `reply.send(…)` with no `return`** (EE §5). *Must be true:* the call is inside a Nest controller method or a Nest filter, where Nest does not need the return. *Flips back:* a raw Fastify handler or hook that sends without `return` and continues.
- **B-D9 — The pagination kernel** (HC §7, P5). *Must be true:* the kernel clamps the page size, allow-lists sort fields, appends a unique tiebreak and counts `total` under the same `where`; its callers are one decoy, not N rows. *Flips back:* a list that bypasses the kernel.
- **B-D10 — A named primitive param followed by a guard** (VB §7). *Must be true:* an `assert*()` helper, a registry lookup (unknown → 404) or an integer/range check runs before any use. *Flips back:* the raw value reaches a query builder (→ security `injection-scan`) or the domain.
- **B-D11 — A route word inside a longer segment** (HC §1/§4, filter rule). `marketer…` is not `mark`, `accounts`/`counts` are not `count`, `checkout`/`check-in` are not `check`, `cancellations` is not `cancel`. Route words match **whole path segments**; a substring hit is Refuted.
- **B-D12 — Dates kept as strings** (WF §6, BA-17). *Must be true:* no `@Type(() => Date)` / `z.coerce.date()`; date fields carry `@IsISO8601` / `@IsDateString` or a strict regex. *Flips back:* a field coerced to an instant before validation, or a calendar date typed as an instant.
- **B-D13 — Initialisers on query DTOs** (VB, BV-14). *Must be true:* the initialised fields (`page = 1`, `pageSize = 25`) sit on query DTOs or POST bodies, not on PATCH/Update DTOs. *Flips back:* an Update/Patch DTO field with an initialiser — an omitted field is reset.
- **B-D14 — The reference idempotency module** (HC §6). The shape HC §6 compares against: key unique per tenant and operation; the caller folded into the fingerprint (another principal's reuse → 422, never their stored answer); in-flight lease → 409; a lapsed lease → 409 `OUTCOME_UNKNOWN`, never re-run. A module that matches it clears the route; each missing part is its own B-V7 variant.
- **B-D15 — An error family translated by an application-layer mapper** (EE §2, 2c). *Must be true:* the family's classes (a domain `RefusalError` tree, a module's `LedgerError`) are caught and turned into an `HttpException` (or the project's envelope) by one mapper — a module's `toHttpError(err)`, a refusal mapper every use case returns through — and every path that can throw the family reaches it (cite the mapper and the call sites, or the base use case that wraps them all). The global filter never naming the family is then expected. *Flips back:* one path throws the family outside the mapper (a job, a webhook handler, a second controller), or the mapper has a default arm that answers 500 for a member the contract gives 404/409/422.
- **B-D16 — A body parsed by a project schema pipe** (VB §1/§8; dto-types bucket `custom-pipe(<Pipe>)`). *Must be true:* the param decorator (a wrapper such as `@ContractBody(schema)` that calls `Body(new SchemaPipe(schema))`) parses the **whole** body with a schema on every route that uses it, its refusal reaches the project's error envelope with the same status as the global pipe's, and its unknown-key and `null` behaviour is recorded once as a wiring row (P5). The global `ValidationPipe` skipping the `z.infer` type is then expected. *Flips back:* the pipe catches a parse failure and passes the raw value on, a route passes a permissive schema (`z.any()`, `.passthrough()`, `z.record(z.unknown())`) for a body the domain reads field by field, or a `createParamDecorator` returns `req.body` with no pipe (`custom-pipe(none)`).
- **B-D17 — A Nest catch-all on Fastify that never reads a non-HttpException `statusCode`** (EE §1, 1c; lab, 2026-10-14). *Must be true:* the adapter is Fastify, the catch-all keeps `instanceof HttpException ? getStatus()` before its 500, and the errors in question are Fastify's own refusals — malformed or empty JSON (400), over `bodyLimit` (413), an unparsed content type (415), an unknown route (404), a `FastifyError` thrown in a Fastify hook. Nest converts each to `HttpException` with Fastify's status before any filter runs (measured on Nest 11.2.6 with Fastify 5.12.3 and Nest 12.1.3 with 5.12.5: same status as with no filter). *Flips back:* a `statusCode`-carrying non-HttpException thrown inside the pipeline (`@fastify/multipart` limits read in a handler, an `http-errors` or `@fastify/error` object from a library) or a plain `Error` with `statusCode` thrown in a Fastify hook — measured 500 through that catch-all on both versions; or the Express adapter, where the 11.2.6 core converts only `SyntaxError`/`URIError`.

Two filter rules from the same run, not precedents: comment-only lines are dropped from every
pre-flight grep (5 of 761 `@Body()` and 7 of 106 `@ValidateNested` hits were doctrine comments);
a local validator such as `IsAbsentOr()` (`ValidateIf(v !== undefined)`: absent allowed, `null`
refused) is the BV-05 fix, not an optional field.

## The incident record

18 public incidents map to these classes (64-bit ids losing precision in JavaScript; leap-day and
two-digit-year arithmetic; config trusted at runtime; client retry storms; a validator that did not
check arity). Pagination drift, enqueue-before-commit, DST cron double runs, webhook double
processing and float-money rounding have **no** public postmortem: they rest on mechanism,
guidelines and practitioner precedent. A finding never invents an incident to raise its severity.

## Rationalizations to reject (backend)

**Wrongly dismissing:** "the validator is configured globally, so every route is validated" (BV-01
and BV-09 are routes the global pipe never sees; a union-typed body emits `Object` and validates
nothing) · "the serializer schema is the contract, so the response is correct" (Fastify and
Jackson serializers change values with a 200: BN-06, BM-02/03) · "the library retries, so it is
resilient" (and charges twice — B-R13) · "the job is idempotent" (show the reserve; a status
check on a copy is not one) · "we test it" (on SQLite, with an eager in-process queue, under
`TZ=UTC`, against a hand-built pipe — B-R16, B-D7) · "it's the framework default" (state the
version: defaults moved across the last major in a dozen places) · "`@IsOptional` only skips an
absent key" (it also skips `null`) · "the filter maps every error" (does it keep `getStatus()` for
the framework's own 400, 404, 413, 415 and 429?) · "oasdiff runs in CI" (with `--fail-on ERR`?).

**Wrongly accepting:** "POST should always be 201" (B-A3) · "GET must never write" for an audit
row or an OAuth callback (B-A6) · "422 is more correct than 400" (B-A7) · "no 405" on an API that
documents uniform 404 (B-A9) · "stripping unknown keys is unsafe" under a documented tolerant
reader (B-A11, B-G17) · "URL versioning is wrong" (B-G19) · a spec-linter warning (B-A18) ·
"`.status()` is Express API" on Fastify (B-D3) · "this `@Res()` will hang" when every branch sends
(B-D2) · "single-key `orderBy`" on an internal drain (B-D4) · "a cron without a zone" in a UTC
process (B-R9) · "it could overlap" for a read-only sampler (B-R8) · "an attacker can…" (P3).

---

Sources: the backend research catalog (2026-10-14) § 4 (posting rules P1–P5, B-A1–B-A18,
B-R1–B-R16, B-G1–B-G24, the incident record and the rationalizations) and its notes A (API
contract and validation, Node frameworks), B (runtime correctness per framework) and C (public API
guidelines — Google AIPs, the Azure and Zalando guidelines, CC BY 4.0, paraphrased — incidents and
property shapes); and the batch-5 backend eval (2026-10-14) § 3 and § 5.10, which moved B-R6,
B-R12 and B-R13 to their owners, sent B-P20a–f to `precedents/performance.md` § 77, and added
B-D1–B-D14 from a read-only real-repo run; B-D17 is from a scratch lab on the versions that run locks (Nest 11.2.6, Fastify 5.12.3), repeated on Nest 12.1.3. Paraphrased; no text reproduced beyond short quoted
identifiers.
