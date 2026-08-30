---
name: authorization
description: Cross-cutting authorization rules — at which layer the check lives, and whether every actor path crosses it
kind: rule
concern: C8
---

# Authorization

## Hard rule

Every path that reaches data on behalf of an actor MUST cross an authorization check, and **every
such check MUST live at the same layer**. Which layer is a project decision; having two is not.
Controller-layer in some modules and repository-layer in others is the single most common
architectural inconsistency in a codebase that has both — and it is invisible to any review that
looks at one module at a time, because each module is internally consistent.

This is distinct from **C1 Security**, which asks *is it exploitable*. Authorization asks
*at which layer is the check, and does every actor path cross it*. A codebase can pass a security
audit with an authorization architecture that guarantees a future IDOR: the check exists on every
route reviewed, and the one background job that bypasses routes entirely was never in scope.

## The blind spot this concern exists to close

Authorization was reviewed almost exclusively on request-shaped surfaces. The first matrix build
found it empty on **9 of 35 surfaces**, and the pattern in that list is the finding: the empty
ones are the surfaces where **no HTTP request carries the actor** — jobs, pipelines, event
streams, imports. Those are exactly the paths where a controller-layer guard cannot help, because
there is no controller.

`Authorization × background-jobs` was the one gap the plan predicted correctly before the matrix
existed. It predicted three others that turned out to be covered.

## Per-surface fingerprints

| Surface | Where the actor comes from | Typical finding |
|---|---|---|
| `background-jobs` | the enqueuing request, carried in the payload — or lost | job re-reads the target row with no tenant/owner filter because the guard lived on the route that enqueued it; a retry runs as nobody |
| `data-pipeline` | the pipeline's own service identity | pipeline reads across every tenant by design and writes derived rows with no scope; downstream consumers inherit unscoped data |
| `event-sourced` | the command that produced the event | projections rebuild without re-applying authorization; a replay grants access the original command denied |
| `file-upload` | the upload request | the upload is authorized, the **retrieval URL** is not — signed-URL absent, or the object key is guessable |
| `analytics` | the tracked user, not the querying user | anyone who can query the warehouse sees every tenant's events; `track()` call sites carry no scope |
| `notifications` | the recipient | send path trusts a caller-supplied recipient id; no check that the sender may address that recipient |
| `compliance` | the subject of the request | data-subject export/delete requests not verified against the requester's identity |
| `multi-tenant` | the tenant anchor | authorization and tenancy enforced at **different** layers, so a correct tenant scope still allows a wrong-role read |
| `i18n` | — | **N/A — no actor-scoped data.** Catalogs are global; a locale is a preference, not a permission. |

## The layer question

Record the answer once, in `ai/architecture.md`, and review against it — not against taste:

```
AUTHZ_LAYER: controller | service | repository | policy-object
```

Findings are **deviations from the recorded layer**, not opinions about which layer is best. A
project with no recorded layer has one finding, not N: *the layer is undeclared*, and every
inconsistency downstream is one consequence of it.

## Per-`project_kind` rendering

Phase 5. The concern's *logic* is universal; the *fingerprint* adapts to the shape of the project,
exactly as the 13 scale-lens detectors in [`commands/audit.md`](../../commands/audit.md) already
do. Columns are the closed set from [`packs/_project-kind.md`](../packs/_project-kind.md) —
`browser | server | mobile | cli`, never the `frontend-*` / `backend-*` prose families, which
nothing emits.
| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **Where the check lives** | the recorded `AUTHZ_LAYER` — one layer, everywhere | server is the boundary; client checks are UX only | same, plus on-device data scoped per signed-in account | the invoking OS user + file permissions |
| **The bypass path** | jobs / pipelines / replays that carry no request | a hidden button is not a permission; the endpoint is | deep links and push-notification payloads entering past the guard | `sudo`, world-readable config, a shared machine |
| **The classic miss** | guard on the route, none on the job that does the same write | client-side role check with an unguarded API behind it | screen hidden, underlying sync still pulls the data | secrets in a `0644` file in the user's home |

> `browser` and `mobile` are **never** the enforcement point. A finding there is always "the
> server does not check", rendered in client vocabulary — never "add a check to the client".

## Closure verbs

`hoist-check-to-layer` · `carry-actor-in-payload` · `scope-at-repository` · `sign-retrieval-url` ·
`declare-authz-layer` · `reapply-on-replay`

A fix that adds a second check at a second layer is not a closure — it is the finding, doubled.
