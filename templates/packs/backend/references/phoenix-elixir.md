# Phoenix (Elixir) reference

> **Framework**: Phoenix 1.7+ on Elixir 1.15+ / Erlang OTP 26+ • Ecto 3.10+
> **Official docs**: https://hexdocs.pm/phoenix/ • https://hexdocs.pm/phoenix_live_view/
> **Version-specific gotchas**: Phoenix 1.7 made LiveView the default (verified routes, `~p` sigil, function components); `Phoenix.Component` replaces `Phoenix.LiveComponent` for stateless; HEEx is the only template engine; `core_components.ex` is the new shared component shape; tailwind + esbuild are the bundled defaults.
> **Substitution markers**: Replace `MyApp` / `MyAppWeb` with the project's actual base modules.

Concurrency king. For real-time apps (LiveView, channels), high-throughput APIs, and chat/streaming workloads.

## Structure (umbrella or single app)

```
lib/
├── my_app/                  # Business domain (contexts)
│   ├── accounts/
│   ├── accounts.ex          # public API of the context
│   ├── orders/
│   └── orders.ex
├── my_app_web/              # Web layer
│   ├── controllers/
│   ├── live/                # LiveView components
│   ├── components/
│   ├── router.ex
│   └── endpoint.ex
└── my_app_web.ex            # imports, helpers
```

## Contexts (Phoenix's domain organization)

- A **context** is a module grouping related entities + behavior: `Accounts`, `Orders`, `Billing`.
- The context's public API (`Accounts.register_user/1`) is the boundary.
- Controllers / LiveViews / channels call into contexts, not into Ecto schemas directly.
- Rule: if a controller imports `Ecto.Query`, it's doing too much.

## Data (Ecto)

- **Schemas** = struct + schema definition.
- **Changesets** = validation + type casting + DB operation descriptor.
- `Ecto.Multi` for multi-step transactions.
- Migrations reversible (`up`/`down` OR `change` with reversible primitives).
- `Repo.preload` for explicit associations — default is NOT preloaded (no N+1 surprises).

## Controllers + views

- `use MyAppWeb, :controller`.
- `action_fallback` for consistent error handling.
- JSON views via Jason (or whatever's configured in endpoint).

## LiveView (real-time UI)

- Server-rendered HTML with stateful process per client.
- State in socket assigns.
- Events via `handle_event/3` (from pushed events on the client).
- Updates broadcast via `Phoenix.PubSub`.

```elixir
def mount(_params, _session, socket) do
  if connected?(socket), do: Phoenix.PubSub.subscribe(MyApp.PubSub, "orders:#{tenant_id}")
  {:ok, assign(socket, orders: Orders.list(tenant_id))}
end
```

## Channels (websockets)

- `Phoenix.Channel` for bidirectional sockets.
- Topics like `"rooms:lobby"`, `"tenant:42"`.
- `handle_in/3` for client messages, `broadcast!/3` to push back.

## Resilience, streaming, conditional requests & pagination

> Phoenix's real-time story is **Channels / LiveView** (stateful sockets — reach for these for browser push). The patterns below are the *HTTP-API* wiring for non-LiveView consumers (mobile, CLI, service-to-service); each maps to a sibling ai-pattern that owns the policy.

- **Rate limiting** — a `Plug` in the endpoint/pipeline: `PlugAttack` or `hammer` (`Hammer.check_rate/3`). `hammer`'s default ETS backend is **per-node** — in a multi-node cluster each node counts independently, so use `hammer_backend_redis` for a shared limit. On throttle, `put_resp_header/3` `retry-after` + the current draft's two quota fields (`ratelimit-policy` / `ratelimit`, e.g. `"default";q=100;w=60` and `"default";r=0;t=30` — `draft-ietf-httpapi-ratelimit-headers`, a DRAFT), then `send_resp(conn, 429, "")` and `halt/1`. Headers are manual here, so write the two-field form directly; the `ratelimit-limit/remaining/reset` triple is draft-05 legacy. → `ai-patterns/rate-limiting.md`.
- **Conditional requests** (RFC 9110) — no built-in ETag plug; do it on `Plug.Conn`. Reads: `put_resp_header(conn, "etag", tag)`, then `if tag in get_req_header(conn, "if-none-match"), do: send_resp(conn, 304, "")`. Writes: gate `if-match` against the row's `Ecto` `optimistic_lock` version → `412` on mismatch, `428` when absent on an unsafe method. → `ai-patterns/conditional-requests.md`.
- **Streaming** — HTTP chunked via `Phoenix.Controller`: `conn = send_chunked(conn, 200)`, then loop `chunk(conn, line)` (NDJSON one object + `\n` per row; SSE with `put_resp_content_type(conn, "text/event-stream")`). `reduce_while` over the Ecto stream and bail on `{:error, _}` from `chunk/2` (client gone). Use this for API/CLI consumers; for browser real-time prefer LiveView/Channels. End with a terminal sentinel — the `200` is already sent. → `ai-patterns/response-streaming.md`.
- **Async job offload** — `Oban` (Postgres-backed, durable): the controller inserts the job and returns `202 Accepted` + `Location: /jobs/:id`; `GET /jobs/:id` reads Oban's job state as the status machine (`available → executing → completed|discarded`, result + TTL). A bare `Task.async` is fire-and-forget — no durability, no retry, dies with the process; use it only for in-request fan-out. → `ai-patterns/async-job-offload.md`.
- **Pagination** — Ecto keyset by default: `from r in Row, where: {r.inserted_at, r.id} < ^{cursor_ts, cursor_id}, order_by: [desc: r.inserted_at, desc: r.id], limit: ^limit` — the tuple predicate matches the unique, tiebroken sort and stays cheap on deep pages. Apply a default limit + hard cap; fetch `limit + 1` for `has_more` instead of `Repo.aggregate(:count)`. `paginator` gives keyset out of the box; `scrivener` is offset — keep it off hot/growing tables. → `ai-patterns/pagination.md`.

## Concurrency

- Processes are CHEAP. Spawn millions. Supervise them.
- `Task.Supervisor` for short-lived parallel work.
- GenServer for stateful processes.
- `DynamicSupervisor` + `Registry` for worker pools per tenant / entity.

## OTP patterns

- Supervision tree = your app's shape.
- Let it crash — supervisor restarts.
- Don't rescue exceptions to "handle" them — propagate and let process die.
- `:transient` / `:temporary` / `:permanent` restart strategies per process kind.

## Telemetry

- `:telemetry` events everywhere (Phoenix emits for every request + Ecto query).
- Consumers: Prometheus (via `telemetry_metrics_prometheus`), AppSignal, Datadog.

## Testing

- ExUnit built in.
- `Phoenix.ConnTest` for controller tests.
- `Phoenix.LiveViewTest` for LiveView interaction tests.
- Ecto sandbox — parallel tests with isolated DB state.

## Anti-patterns

- Business logic in controllers / LiveViews.
- Direct `Repo` calls outside contexts.
- Forgetting to preload (N+1 at template render time).
- Rescuing exceptions to suppress them.
- Long-running work in LiveView `handle_event` (use `Task.async` + `handle_info`).
- Process state dependency — use `Ecto.Multi` or explicit process boundaries.
