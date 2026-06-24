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
| **Chunked** | any + `Transfer-Encoding: chunked` | Bytes whose total length isn't known upfront (file/report build) | Streamed body |

Stream when the result is unbounded; paginate when it's bounded. NDJSON for records, SSE for events/tokens, chunked for opaque bytes.

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
3. **LLM streams:** cap `max_tokens`, log tokens + cost per stream, and abort the upstream when the client disconnects.

## Detectors (cite-or-halt)

- `JSON.stringify(rows)` / `res.json(allRows)` / `.toArray()` / `fetchall()` / `.to_a` on a query with a user-controlled or absent limit → `stream-or-paginate` (cite row-count source + memory ceiling).
- A streaming handler with no idle/total timeout or no disconnect cancellation → `add-stream-lifecycle-guards`.
- A stream with no terminal success/error sentinel → `add-terminal-sentinel`.
- An LLM endpoint streaming with no `max_tokens` / no token+cost log → `cap-and-meter-llm-stream`.

**Closure verbs:** `stream-or-paginate`, `add-stream-lifecycle-guards`, `add-terminal-sentinel`, `cap-and-meter-llm-stream`.

Reference: **RFC 9112** (HTTP/1.1 message syntax — chunked transfer + trailers). Cross-ref `parallel-io.md` (bounded concurrency feeding the stream) and `websocket-engineer.md` (the real-time push sibling).

## Forbidden

- Buffering an unbounded result fully in memory (`fetchall` then serialize).
- A streamed response that ends silently on error (no terminal sentinel).
- Streaming without backpressure (ignoring `write()===false` / not flushing).
- A streaming cursor with no timeout and no disconnect cancellation.
- `OFFSET`-paging the source of a stream (keyset/cursor instead).
