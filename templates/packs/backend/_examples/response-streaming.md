---
name: response-streaming
description: 'Pattern: Response Streaming (large results, NDJSON / SSE / chunked, mid-stream errors & backpressure)'
kind: ai-pattern
pack: backend
---

# Pattern: Response Streaming

> **Hard rule:** A response whose size scales with user-controlled input (exports, reports, search-all, LLM tokens) MUST NOT be buffered fully in memory — stream it. Once the `200` + headers are flushed you can no longer send a `5xx`, so a streaming endpoint MUST define a terminal error mechanism, respect HTTP backpressure, and cancel work on client disconnect. Request-response large-result only; real-time PUSH is owned by `websocket-engineer.md`.

**When to apply** — an endpoint returns a result set bounded only by the data (export/report/download-all), token-by-token LLM output, or any handler doing `.toArray()`/`fetchall()`/`JSON.stringify(allRows)` on an unbounded query.

**Halt conditions / mandatory cites**
- Any unbounded full-result buffering MUST cite the row-count source `<path:line>` + the memory ceiling it can hit.
- A streaming handler with no per-record error sentinel is a bug — once flushed, a mid-stream failure cannot be a `500`.
- A streaming handler with no idle/total timeout OR no client-disconnect cancellation leaks a cursor/connection.
- An LLM token stream with no `max_tokens` cap and no token/cost logging is a runaway.

## Transport decision table

| Transport | Content-Type | Use when |
|---|---|---|
| **Paginate** (not streaming) | `application/json` | Bounded, cacheable, random-access |
| **NDJSON** | `application/x-ndjson` | Large homogeneous record sets |
| **SSE** | `text/event-stream` | Incremental events / LLM tokens over HTTP |
| **Chunked** | + `Transfer-Encoding: chunked` | Bytes whose total length isn't known upfront |

Stream when unbounded; paginate when bounded. NDJSON for records, SSE for events/tokens, chunked for opaque bytes.

## Mid-stream errors — the part everyone gets wrong

Once status + headers are flushed, the status line is committed; a later failure cannot become a `5xx`.

- **NDJSON:** emit a terminal error record (`{"error":{...}}` as the last line); the client treats a stream ending without the success sentinel as failed.
- **SSE:** send `event: error\ndata: {...}\n\n` then close.
- **Chunked:** use an HTTP trailer (`Trailer: X-Stream-Status` → trailing `X-Stream-Status: error`) or a documented terminal marker.
- Never end a partial stream silently — the client cannot distinguish "done" from "died".

## Backpressure (don't outrun the socket)

| Stack | Primitive |
|---|---|
| Node | `res.write()` → `false` ⇒ `await once(res,'drain')` |
| ASGI / FastAPI | `StreamingResponse(async_generator)` (awaits naturally) |
| Go | `http.Flusher.Flush()` + `r.Context().Done()` |
| Rails | `ActionController::Live` + `response.stream.write`/`.close` |
| Spring | `StreamingResponseBody` / `ResponseBodyEmitter` |
| Django | `StreamingHttpResponse` with a generator |
| .NET | `IAsyncEnumerable<T>` / `Results.Stream` |

Pair the source with a **server-side cursor / keyset iteration** (not deep `OFFSET`) so the DB streams too.

## Lifecycle requirements

1. **Idle timeout** AND **total timeout** — a stuck client must not pin a cursor forever.
2. **Cancel on disconnect** — propagate cancellation (`AbortSignal`/`context.Context`/`CancellationToken`) to the cursor + upstream.
3. **LLM streams:** cap `max_tokens`, log tokens + cost, abort upstream on disconnect — then answer the two questions a checklist leaves open. **Who owns the abort when your client is not a browser?** A proxy, gateway or BFF in between may hold the upstream open long after *its* client left, and you keep generating and paying into a socket nobody reads; either every hop forwards the cancellation (test it by killing a client and watching the provider's token counter stop) or the outermost hop is the only one that can cancel and every inner hop needs its own deadline as a backstop. **What happens to a half-generated completion you were still billed for?** Discard (log the tokens anyway), persist-and-mark-partial (the flag must be un-ignorable — a truncated summary stored as complete is worse than none), or persist-and-reuse (only for deterministic, non-user-specific requests). Whichever you pick, **write the token/cost record on the abort path too** — otherwise cancelled streams are exactly the spend your dashboard cannot see.

## Detectors (cite-or-halt)

- `JSON.stringify(rows)` / `res.json(allRows)` / `.toArray()` / `fetchall()` / `.to_a` on a user-controlled or absent limit → `stream-or-paginate` (cite row-count source + ceiling).
- Streaming handler with no idle/total timeout or no disconnect cancellation → `add-stream-lifecycle-guards`.
- Stream with no terminal success/error sentinel → `add-terminal-sentinel`.
- LLM endpoint streaming with no `max_tokens` / no token+cost log → `cap-and-meter-llm-stream`.
- LLM stream whose token/cost record is written only on the success path, so cancelled and errored streams are billed but unmetered → `cap-and-meter-llm-stream`.

**Closure verbs:** `stream-or-paginate`, `add-stream-lifecycle-guards`, `add-terminal-sentinel`, `cap-and-meter-llm-stream`.

Reference: **RFC 9112** (HTTP/1.1 message syntax — chunked + trailers). Cross-ref `parallel-io.md` (bounded concurrency feeding the stream) + `websocket-engineer.md` (real-time push sibling).

## Forbidden

- Buffering an unbounded result fully in memory (`fetchall` then serialize).
- A streamed response that ends silently on error (no terminal sentinel).
- Streaming without backpressure (ignoring `write()===false` / not flushing).
- A streaming cursor with no timeout and no disconnect cancellation.
- `OFFSET`-paging the source of a stream (keyset/cursor instead).
