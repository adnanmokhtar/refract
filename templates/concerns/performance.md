---
name: performance
description: Cross-cutting cost-per-invocation rules, applied to surfaces the perf pack never reaches
kind: rule
concern: C2
---

# Performance

## Hard rule

Every surface MUST know its **cost per invocation** and its **growth term** — what the cost is
multiplied by as the system grows. A surface whose cost is unknown is not "fast"; it is
unmeasured. Optimisation without a measured before/after is not a fix, it is a change.

The `performance` pack and the 13 scale-lens detectors already cover request paths, queries and
render trees well. This concern exists for the **17 surfaces the matrix found empty** — places
where cost accrues without ever crossing a route handler or a component render.

## Per-surface fingerprints

| Surface | The growth term | Typical finding |
|---|---|---|
| `ab-testing` | experiments × users | assignment recomputed per request instead of cached per session; exposure logged synchronously on the hot path |
| `admin` | rows × admins | back-office list pages with no pagination — fine at 100 rows, fatal at 100k |
| `ai` | tokens × calls × retries | whole documents sent where a chunk would do; no caching of identical prompts; retries multiply spend, not just latency |
| `auth` | logins × hash cost | password hash cost tuned for a laptop, not the prod CPU; session lookup uncached on every request |
| `compliance` | subjects × data sources | a data-subject export scans every table serially with no time budget |
| `feature-flags` | flags × evaluations | flag evaluated inside a loop instead of hoisted; remote evaluation on the request path with no local cache |
| `file-upload` | file size × concurrency | whole file buffered in memory rather than streamed; AV scan blocking the response |
| `i18n` | locales × keys | the full catalog for every locale shipped to every client |
| `ledger` | entries × accounts | balance computed by summing all history on every read instead of maintaining a running balance |
| `moderation` | items × scanners | every item scanned by every provider synchronously before serving |
| `multi-tenant` | tenants × queries | one shared connection pool with no per-tenant partition, so one slow tenant stalls all |
| `notifications` | recipients × channels | fan-out rendered per recipient instead of templated once; provider called serially |
| `payment` | transactions × PSP round-trips | reconciliation re-fetches the full history rather than paging from the last cursor |
| `scheduling` | slots × horizon × attendees | availability expanded across the full horizon on every query instead of windowed |
| `settings` | reads × layers | layered settings resolved from source on every access, with no memoised merge |
| `subscriptions` | subscribers × renewal batch | renewals processed in one unbounded batch; proration recomputed for untouched subscriptions |
| `webhook` | deliveries × retries × endpoints | deliveries sent serially per endpoint; a slow consumer backs up the whole queue |

## Per-`project_kind` rendering

| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **Unit of cost** | ms and allocations per request | ms of main-thread time and KB shipped | frame time, battery, cold-launch ms | wallclock per invocation and peak RSS |
| **The growth term** | RPS | routes mounted × payload | screens × list length | invocations × input size |
| **The classic miss** | work inside a loop that could be batched | a library imported for one function | work on the UI thread that could be off it | re-reading a file per iteration |

Every fix ships a measured before/after. Speculative optimisation is itself a finding — blanket
memoisation on a cold path is over-abstraction, not performance work.

## Closure verbs

`batch` · `stream-not-buffer` · `hoist-out-of-loop` · `cache-with-bound` · `paginate` ·
`maintain-running-total` · `move-off-hot-path` · `partition-pool`
