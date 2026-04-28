---
name: offline-sync
description: Pattern — offline-first / offline-tolerant data sync for mobile apps
kind: ai-pattern
pack: mobile
---

# Pattern: Offline sync

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
| **Multi-device sync of user's own data** (todo across phone + tablet) | Last-write-wins per field with timestamps; or event-sourced. |
| **Collaborative editing** (Google Docs / Notion-like) | CRDT (Y.js, Automerge) OR central authority via real-time channel (WebSocket / Firestore). |
| **Critical correctness** (banking, medical, legal) | Online-only OR queued + signed + idempotent + receipt-confirmed. |

## Components of an offline-first feature

### 1. Local cache (read path)

- TanStack Query persister (RN) / Hive (Flutter) / Core Data (iOS) / Room (Android).
- Cache KEY scoped per user + per resource.
- Cache TTL (time-to-live) explicit; background refresh on stale.
- UI shows cached data IMMEDIATELY on screen load. Refresh runs in background; user sees fresh data once it lands without blocking.

### 2. Mutation queue (write path)

- Mutation = `{ id, type, payload, attemptCount, lastError, createdAt }` rows in a local table.
- On submit: write to queue + apply optimistically to local cache → UI updates instantly.
- Background task replays the queue when online.
- On success: remove from queue; reconcile cache with server response.
- On failure: increment attemptCount; exponential backoff (1m, 5m, 30m); after N attempts, surface to user as "couldn't sync — retry?"

### 3. Conflict resolution

When a queued mutation lands on the server but the server's state has moved:

- **Server-wins**: server response overwrites local. User loses their change. Acceptable for low-stakes (e.g., notification preferences).
- **Client-wins**: server applies client's payload. Risk of clobbering server-side updates. Acceptable for personal data.
- **Version-vector / Lamport timestamps**: each entity has a version; server rejects writes against stale versions. Client must re-fetch + retry or merge.
- **Manual-merge**: surface conflict to user ("Your local copy and server copy differ. Pick one or merge.")

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
- **Sync ALL data on every reconnect** — incremental sync via timestamps / cursors.
- **Background sync without battery awareness** — drain accelerates uninstalls.
- **Push notifications as sync primitive** — unreliable; push delivery is best-effort, not guaranteed.

## Testing

- E2E: toggle airplane mode mid-flow. Submit mutation. Re-enable. Verify sync.
- Kill app mid-queue → relaunch → verify queue replays.
- Conflict test: device A and device B both edit same record offline → both come online → verify resolution.
- Battery / data: long-running offline session, then sync; measure delta.

## Project-specific anchors

(Phase 4.6 fills this with the project's actual queue table, helper functions, sync orchestrator name, conflict-resolution strategy chosen.)
