---
name: offline-sync
description: Pattern — offline-first / offline-tolerant data sync for mobile apps
kind: ai-pattern
pack: mobile
---

# Pattern: Offline sync

> **Hard rule:** Every offline-tolerant write goes through a persistent mutation queue with a documented conflict-resolution policy (server-wins, client-wins, version-vector, manual-merge); reads serve the local cache first, then revalidate. Fire-and-forget writes that lose state on app kill, or "we'll just retry on reconnect" without idempotency keys, are forbidden.

**When to apply**
- The product promises offline use (field service, travel, transit, low-connectivity markets).
- Mutation latency is user-visible and the network is unreliable.
- The same record can be edited by multiple devices and conflicts are real.

**When NOT to apply**
- A pure-online app behind a captive auth flow where offline is unsupported by product.
- A read-only catalog where stale data is acceptable and a simple cache suffices.

**Halt conditions / mandatory cites**
- Each queued mutation MUST cite the queue persistence + idempotency key at `<path:line>`.
- The conflict-resolution policy MUST be cited explicitly per entity — no global default by accident.
- A doc proposing in-memory-only queues or unkeyed retries is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this works offline".
- If the persistence layer + background-sync mechanism aren't extracted, halt.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Mobile`.
>
> - **Offline strategy in use**: `<extracted: cache-only | last-write-wins | event-sourced | CRDT>`
> - **Persistence layer**: `<MMKV / AsyncStorage / Realm / SQLite (sqflite/SQLite.swift) / Core Data / Room>`
> - **Mutation queue**: `<Background Tasks (iOS) / WorkManager (Android) / react-native-background-fetch / queueing layer in code>`
> - **Conflict resolution**: `<server-wins / client-wins / version-vector / manual-merge>`
> - **Network primitive**: `<NetInfo (RN) / connectivity_plus (Flutter) / NWPathMonitor (iOS native) / ConnectivityManager (Android native)>`

## Problem

Mobile networks are unreliable. Users:
- Lose connectivity unpredictably.
- Open the app on subway / tunnel / plane / poor signal.
- Background the app mid-mutation.
- Have apps killed by the OS while a sync is queued.

If the app freezes / loses data / shows blank screens / fails actions silently → user trust drops.

## Decision tree — pick a strategy

| Use case | Strategy |
|---|---|
| **Read-only catalog** (products, articles) | Cache-only. Stale read OK. Background refresh. |
| **User's own data, single device** (personal notes) | Last-write-wins. Local mutations replayed when online. |
| **Multi-device sync of user's own data** (todo across phone + tablet) | Last-write-wins per field, ordered by a **server-issued** version or sequence (never a device clock — see below); or event-sourced. |
| **Collaborative editing** (Google Docs / Notion-like) | CRDT (Y.js, Automerge) OR central authority via real-time channel (WebSocket / Firestore). |
| **Critical correctness** (banking, medical, legal) | Online-only OR queued + signed + idempotent + receipt-confirmed. |

## Components of an offline-first feature

### 1. Local cache (read path)

- TanStack Query persister (RN) / Hive (Flutter) / Core Data (iOS) / Room (Android).
- Cache KEY scoped per user + per resource.
- Cache TTL (time-to-live) explicit; background refresh on stale.
- UI shows cached data IMMEDIATELY on screen load. Refresh runs in background; user sees fresh data once it lands without blocking.

### 2. Mutation queue (write path)

- Mutation = `{ id, clientId, entity, type, payload, envelopeVersion, attemptCount, lastError, createdAt }` rows in a **persistent** local table — in-memory is not a queue, it is a delay.
- Every row carries an **idempotency key** the server honours, and every payload carries an **envelope version** the next app release can still decode (`schema-lock`).
- Keys — cache keys, queue rows, cursors — are scoped to the **account identity** and cleared or partitioned on sign-out (`identity-bleed`).
- On submit: write to queue + apply optimistically to local cache → UI updates instantly.
- Background task replays the queue when online, in the **ordering contract you declared per entity** — strict, or independent. Only rows declared independent may be skipped past a failure (`skip-on-failure-reorder`).
- On success: remove from queue; reconcile cache with the server response. A background refetch must be **pending-aware** — a locally-queued field wins over the refetch until it is confirmed (`revalidate-clobbers-pending`).
- On failure: increment `attemptCount` and back off. **This pack states no retry count, backoff curve, TTL or queue cap** — no platform publishes one, and a number written here is a number `@offline-sync-auditor` HALTs on. What the design must state instead is *structural*: that backoff exists and grows, that there is a **terminal state** (so one permanently-failing row cannot block the queue head forever — `poison-head`), and that every terminal state reaches a surface a human sees (`silent-drop`). Pick the actual values from this project's traffic and record them in the project-specific block above.

### 3. Conflict resolution

When a queued mutation lands on the server but the server's state has moved:

- **Server-wins**: server response overwrites local. User loses their change. Acceptable for low-stakes (e.g., notification preferences).
- **Client-wins**: server applies client's payload. Risk of clobbering server-side updates. Acceptable for personal data.
- **Version-vector / server-issued version**: each entity has a version; the server rejects writes against a stale one. Client re-fetches and retries or merges.
- **Manual-merge**: surface conflict to user ("Your local copy and server copy differ. Pick one or merge.")

**Two rules that are not policy choices.** (1) **Resolve on a server-issued version, sequence or ETag — never a device timestamp.** The device clock is user-settable and skewed, so timestamp comparison is not conflict resolution (`clock-as-authority`); if the server issues no version, that is a requirement on the backend, recorded as such. (2) **Decide per entity, and write the decision down.** One policy inherited across every entity because it is what the client library does is `blanket-policy`; "server-wins for preferences, versioned-reject for orders" is the deliverable.

### 4. Connectivity awareness

- Subscribe to `NetInfo` / `connectivity_plus` / `NWPathMonitor` / `ConnectivityManager`.
- On reconnect → trigger queue replay.
- Status visible to user (subtle "Offline" badge or sync indicator).
- Don't poll for network — listen to events.

### 5. UI affordances

- Optimistic UI: action shows immediately even before network round-trip. Roll back on failure.
- Sync indicator: subtle badge or icon when there's pending work.
- Failed mutation banner: "1 item couldn't sync — retry / discard."
- Loading vs offline indistinguishable to user → bad. Show specifically "Working offline; changes will sync when reconnected."

## Anti-patterns

- **Polling for connectivity** — wastes battery; events are the right primitive.
- **Showing blank screen when offline** — should show cached content.
- **Silent data loss** — failed mutation that doesn't surface to user.
- **No queue persistence** — mutation queue in-memory, lost on app kill.
- **Optimistic apply but no rollback** — UI stays in success state even when server eventually rejected.
- **Sync ALL data on every reconnect** — sync from a cursor the server issues; a full resync is a battery and data finding as well as a latency one (`full-resync-on-reconnect`).
- **Treating the connectivity flag as proof of reachability** — captive portals, DNS failures and half-open links all report "online". The flag schedules; the request result is the truth (`reachability-as-truth`).
- **A queued update or delete that references an id the server has not issued yet**, because the create ahead of it is still unsent (`temp-id-orphan`). Declare the dependency or carry the client id through.
- **Background sync without battery awareness** — drain accelerates uninstalls.
- **Push notifications as sync primitive** — unreliable; push delivery is best-effort, not guaranteed.

## Testing

- E2E: toggle airplane mode mid-flow. Submit mutation. Re-enable. Verify sync.
- Kill app mid-queue → relaunch → verify queue replays.
- Conflict test: device A and device B both edit same record offline → both come online → verify resolution.
- Battery / data: long-running offline session, then sync; measure delta.

## Project-specific anchors

(Phase 4.6 fills this with the project's actual queue table, helper functions, sync orchestrator name, conflict-resolution strategy chosen.)

## Boundary

This pattern is **the design `@offline-sync-auditor` tests.** It owns *what* is replayed, in what order, and how conflicts resolve. The auditor owns the **verdict** — a per-entity `durable` / `lossy` / `unproven` judgement proved against the built code, with `<file:line>` for the persisted queue, the idempotency key and the conflict policy, tested through process death, duplicate delivery, reordering and a second account on the same device. The parenthesised labels above are its § Failure catalogue labels: use them, so the design and the audit speak one vocabulary.

Two things this pattern deliberately does not carry, because the auditor's premise forbids them: **any recommended numeric value** (see the write-path bullet above), and any claim that a write is durable that was not proved against a real process kill — the auditor caps that verdict at `unproven` without one, and `device-harness` § 7 is how the kill is performed.

## Related

- `push-notifications.md` (a silent/background push is a best-effort trigger to wake THIS sync — treat delivery as unreliable and back it with a foreground reconcile)
- `app-lifecycle.md` (owns WHEN the OS lets the queue drain — background windows, process death, foreground reconcile; this pattern owns WHAT is replayed and how conflicts resolve. State the seam; do not restate the other half.)
- `mobile-api-contract.md` (a mutation queued by an old client lands on a newer server — the additive-only rule is what makes replay survivable)
- `@offline-sync-auditor` (the audit this design is written to survive; `/add-feature` § Phase 4 dispatches it on any write-path change)
- `@device-performance-auditor` (a memory kill *is* process death — its kill measurement turns a `lossy` verdict into an active data-loss bug)
