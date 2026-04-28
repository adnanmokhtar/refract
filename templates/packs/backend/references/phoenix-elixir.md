# Phoenix (Elixir) reference

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
