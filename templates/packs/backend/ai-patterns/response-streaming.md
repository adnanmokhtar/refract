---
name: response-streaming
description: 'Pattern: Response Streaming (large results, NDJSON / SSE / chunked, mid-stream errors & backpressure)'
kind: ai-pattern
pack: backend
---

# Pattern: Response Streaming

> **Hard rule:** A response whose size scales with user-controlled input (exports, reports, search-all, LLM tokens) MUST NOT be buffered fully in memory — stream it. Once the `200` + headers are flushed you can no longer send a `5xx`, so a streaming endpoint MUST define a terminal error mechanism, respect HTTP backpressure, and cancel work on client disconnect. This pattern owns the request-response large-result case; real-time PUSH (chat, presence) is owned by `websocket-engineer.md`.

**When to apply**
- An endpoint returns a result set whose row count is bounded only by the data (CSV/JSON export, "download all", analytics report).
- Token-by-token LLM/inference output the client renders incrementally.
- Any handler that currently does `.toArray()` / `fetchall()` / `JSON.stringify(allRows)` on a query with a user-controlled or unbounded limit.

**When NOT to apply**
- A small, bounded result (a page of ≤ N rows) — paginate, don't stream; pagination is simpler and cacheable.
- A result the client needs atomically (it can't act on partial data) — buffer with an explicit size cap, or offload to a job (`async-job-offload.md`).
- Real-time bidirectional/push — use WebSocket/SSE-push via `websocket-engineer.md`.

**Halt conditions / mandatory cites**
- Any unbounded full-result buffering MUST cite the row-count source `<path:line>` + the memory ceiling it can hit — "should be fine" is not acceptable.
- A streaming handler with no per-record error sentinel is a bug — once flushed, a mid-stream failure cannot be a `500`.
- A streaming handler with no idle/total timeout OR no client-disconnect cancellation MUST be cited — it leaks a DB cursor / goroutine / connection.
- An LLM token stream with no `max_tokens` cap and no token/cost logging is a runaway — cite it.

## Transport decision table

| Transport | Content-Type | Use when | Client |
|---|---|---|---|
| **Paginate** (not streaming) | `application/json` | Bounded, cacheable, random-access | Standard fetch + `next` cursor |
| **NDJSON** | `application/x-ndjson` | Large homogeneous record sets (export, bulk read) | Read line-by-line |
| **SSE** | `text/event-stream` | Server→client incremental events / LLM tokens over HTTP | `EventSource` / fetch reader |
| **Chunked** | any + `Transfer-Encoding: chunked` **(HTTP/1.1 only — see below)** | Bytes whose total length isn't known upfront (file/report build) | Streamed body |

Stream when the result is unbounded; paginate when it's bounded. NDJSON for records, SSE for events/tokens, chunked for opaque bytes.

**`Transfer-Encoding: chunked` is HTTP/1.1 framing, not a portable instruction.** RFC 9113 §8.2.2 (Connection-Specific Header Fields) prohibits connection-specific fields in HTTP/2: "an endpoint that receives any of these fields MUST treat the receipt as a connection error of type PROTOCOL_ERROR", and `Transfer-Encoding` is among them (the sole carve-out is a `TE` field whose single value is `trailers`). So a handler that *explicitly sets* `Transfer-Encoding: chunked` is a protocol error the moment it is served over H2 or H3 — which, behind almost any modern load balancer, it will be. On H2/H3 the framework streams natively over DATA frames and you set nothing. Write to the framework's stream primitive and let it choose the framing; reach for the header only when you know the hop is H1. The trailer advice below inherits the same caveat: trailers are native on H2, but on H1 they must be announced with a `Trailer:` header and only work when the peer advertised `TE: trailers`.

## Mid-stream errors — the part everyone gets wrong

Once status + headers are flushed, the status line is committed. A failure halfway through cannot become a `5xx`. So:

- **NDJSON:** emit a terminal error record — `{"error":{"code":"...","message":"..."}}` as the last line — and document that the client MUST treat a stream that ends without the success sentinel as failed.
- **SSE:** send `event: error\ndata: {...}\n\n` then close; clients listen for the `error` event distinctly from `message`.
- **Chunked:** use an HTTP **trailer** (`Trailer: X-Stream-Status` then a trailing `X-Stream-Status: error`) where supported, or a documented terminal marker.
- Never end a partial stream silently — the client cannot distinguish "done" from "died".

## Backpressure (don't outrun the socket)

Write at the rate the client reads, or you buffer the whole result in the server's socket buffer anyway:

| Stack | Backpressure primitive |
|---|---|
| Node | `res.write()` returns `false` → `await once(res, 'drain')` before continuing |
| ASGI / Starlette / FastAPI | `StreamingResponse(async_generator)` — the generator awaits naturally |
| Go | `http.Flusher.Flush()` per chunk; check `r.Context().Done()` |
| Rails | `ActionController::Live` + `response.stream.write` / `.close` in an ensure |
| Spring | `StreamingResponseBody` / `ResponseBodyEmitter` |
| Django | `StreamingHttpResponse` with a generator |
| .NET | `await foreach` + `IAsyncEnumerable<T>` from a minimal API / `Results.Stream` |

Pair the source with a **server-side cursor / keyset iteration** (not `OFFSET` deep-paging) so the DB streams too — buffering rows out of the DB just moves the memory blow-up.

## Lifecycle requirements

1. Set an **idle timeout** AND a **total timeout** — a stuck client must not pin a cursor forever.
2. **Cancel on disconnect** — propagate the request's cancellation (`AbortSignal` / `context.Context` / `CancellationToken`) to the DB cursor and any upstream so a closed connection stops the work.
3. **LLM streams** — the majority case, and the one where the generic lifecycle rules above are not enough. Cap `max_tokens`, log tokens + cost per stream, and then answer the two questions the checklist version leaves open:

   **Who owns the abort when your client is not the browser?** Cancellation propagates only as far as something is watching for it. A browser closing a `fetch` aborts your handler's signal; a *proxy* in between (a gateway, a BFF, another service of yours) may hold the upstream connection open long after its own client left, and you will keep generating — and paying — into a socket nobody reads. Decide explicitly: either every hop forwards the cancellation (the signal is a contract each layer must honour, and you should test it by killing a client and watching the provider's token counter stop), or the outermost hop is the *only* one that can cancel and every inner hop needs its own deadline as a backstop. **Assuming the first while shipping the second is the default state, and it is invisible until the bill arrives.**

   **What happens to a half-generated completion you are still billed for?** You are charged for tokens generated before the abort, so a cancelled stream is not a free stream. Three positions, and picking none is picking the worst one:
   - **Discard.** Simplest, and correct when the partial output is worthless (a chat turn nobody saw). Still log the token count — the cost is real and it belongs in the per-stream record whether or not anyone reads the words.
   - **Persist the partial and mark it partial.** Correct when the client may reconnect and resume, or when a human will review it. Requires a `partial` flag the reader cannot ignore — a truncated summary stored as if complete is worse than no summary.
   - **Persist and reuse as a cache entry.** Only when the request is deterministic enough that the same prompt would be answered the same way, and never for anything user-specific. This is the one that quietly becomes a correctness bug.

   Whichever you pick, the **token/cost record is written on the abort path too**, not only on the success path — otherwise the cancelled streams are exactly the spend your dashboard cannot see.

   Deeper cost attribution, model routing and prompt-level budgeting are owned by the **ai-engineering** pack; this pattern owns only what crosses the HTTP boundary.

## Detectors (cite-or-halt)

- `JSON.stringify(rows)` / `res.json(allRows)` / `.toArray()` / `fetchall()` / `.to_a` on a query with a user-controlled or absent limit → `stream-or-paginate` (cite row-count source + memory ceiling).
- A streaming handler with no idle/total timeout or no disconnect cancellation → `add-stream-lifecycle-guards`.
- A stream with no terminal success/error sentinel → `add-terminal-sentinel`.
- An LLM endpoint streaming with no `max_tokens` / no token+cost log → `cap-and-meter-llm-stream`.
- An LLM stream whose token/cost record is written only on the success path, so cancelled and errored streams are billed but unmetered → `cap-and-meter-llm-stream`. Cite the metering call and the abort path that bypasses it.

**Closure verbs:** `stream-or-paginate`, `add-stream-lifecycle-guards`, `add-terminal-sentinel`, `cap-and-meter-llm-stream`.

Reference: **RFC 9112** (HTTP/1.1 message syntax — chunked transfer + trailers). Cross-ref `parallel-io.md` (bounded concurrency feeding the stream) and `websocket-engineer.md` (the real-time push sibling).

## Forbidden

- Buffering an unbounded result fully in memory (`fetchall` then serialize).
- A streamed response that ends silently on error (no terminal sentinel).
- Streaming without backpressure (ignoring `write()===false` / not flushing).
- A streaming cursor with no timeout and no disconnect cancellation.
- `OFFSET`-paging the source of a stream (keyset/cursor instead).
