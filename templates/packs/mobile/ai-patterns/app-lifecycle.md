---
name: app-lifecycle
description: Pattern — app lifecycle and background execution. The state machine including process death, why execution windows are budgeted rather than published, choosing between async work / deferrable scheduled work / foreground services, and state restoration after the OS kills you. Owns when the OS lets you run; offline-sync owns what you replay.
kind: ai-pattern
pack: mobile
---

# Pattern: App lifecycle

> **Hard rule:** Work that must survive the app leaving the foreground goes through the platform's **documented background mechanism** — never a foreground timer, a promise left in flight, or an in-memory task. Every screen whose state the user would be upset to lose persists a **minimal restoration key** that survives process death, and every background task assumes it may be **cancelled or never scheduled**. Coding against an assumed background duration, or treating "the app is in the background" as "the app is still running", is forbidden.

**When to apply**
- Work must continue, or resume, after the user leaves the app: an upload, a download, a sync, a location trace, a media session.
- A screen holds state the user would resent re-entering (a partly filled form, a scroll position deep in a list, a multi-step flow).
- Anything is scheduled to run while the app is not in the foreground.
- The app must react to being foregrounded — refreshing stale data, re-checking permissions, re-validating a session.

**When NOT to apply**
- Rebuild / re-render waste inside a screen that is *currently visible* — that is `render-discipline`, and it is a different problem with different detectors.
- The replay semantics of queued writes — what to send, in what order, and how to resolve a conflict — belongs to `offline-sync`. This pattern owns *whether the OS lets you run at all*; that pattern owns *what you do with the window*.
- Applying a downloaded JS bundle at the next safe restart — `ota-updates` owns the apply boundary.
- A short in-screen async call that the user is watching complete. That is ordinary async work, not background work.

**Halt conditions / mandatory cites**
- Any claim that work "continues in the background" MUST cite the scheduling API at `<path:line>` — a `setTimeout`, an interval, or a bare async call is not background work; reject.
- Any background task MUST cite its **cancellation / expiration path**. A task with no path for "the system stopped us" is a bug; reject.
- Any restoration claim MUST cite the **persist site** AND the **restore site**, and they must survive a cold start after process death — an in-memory store is not restoration; reject.
- Any foreground service MUST cite its **declared type** and matching permission (see `permissions`); an untyped foreground service will not start on current Android.
- **A background duration stated as a number MUST cite the platform document that publishes it.** Android publishes several (below). Apple does not publish a fixed foreground-task duration in a form this pack can cite, so this pack states none — write what determines the window instead. An uncited "you get N seconds" is a fabrication; reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming lifecycle handling is complete.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Mobile`.
>
> - **Lifecycle observer entry point**: `<file path>`
> - **Background mechanism(s) in use**: `<deferrable scheduler / foreground service + type / platform background-task API / none>`
> - **Restoration strategy**: `<saved-state key + persistent store, per screen>`
> - **What is allowed to be lost**: `<explicit list — the states the product accepts re-entering>`
> - **Foreground-refresh policy**: `<what is re-fetched / re-checked on resume, and its staleness rule>`

## Why this pattern matters

Two opposite mistakes, both common, both expensive.

**Treating background as a continuation of foreground.** The upload keeps a promise alive, the sync runs on an interval, the timer counts down — and all of it works perfectly on a simulator with the app in front. In the field the process is suspended or killed and none of it happens. The bug reports say "sometimes it doesn't upload", which is the least actionable sentence in mobile engineering.

**Treating every state change as data loss.** The over-correction: serialise the whole view model on every transition, write it to disk, restore it verbatim. Now startup is slow, the saved blob desynchronises from the schema on the next release, and the restore path is itself a crash surface. Android's own guidance draws the line: "Don't use saved state to store large amounts of data, such as bitmaps, nor complex data structures that require lengthy serialization or deserialization. Instead, store only primitive types and simple, small objects such as `String`" — "use saved state to store a minimal amount of data necessary, such as an ID, to recreate the data" ([saving UI state](https://developer.android.com/topic/libraries/architecture/saving-states)).

The discipline in the middle: **persist the key, recompute the rest**, and let the OS schedule the work.

## The state machine

The two platforms agree on more than their vocabulary suggests. Where they read as different, it is usually the naming, not the capability.

| Phase | What the app can do | What you must have already done |
|---|---|---|
| **Foreground / active** | Everything. | Nothing pending — this is where you earn the right to run later. |
| **Inactive / paused** (a sheet, a call, a task switcher) | Still rendering, not receiving input. | Pause anything that assumes user attention: media, timers, camera. |
| **Background** | A brief, system-budgeted window to reach a stopping point. | Hand long work to a scheduler *before* you get here, not after. |
| **Suspended** | Nothing. In memory, not executing. | Everything that must survive is already persisted or scheduled. |
| **Terminated / process death** | Nothing. The process is gone. | The restoration key is on disk and the queued work is in the scheduler. |

**Both platforms publish a hand-back; only the vocabulary differs.** Android formalises *system-initiated process death with saved state* — "the system may destroy the application process while the user is away interacting with other apps", and the host activity is destroyed "along with any state stored in it", but a small saved-state bundle is handed back when the user returns. The platform's own survival table is unambiguous: a `ViewModel` does **not** survive process death; saved state (`SavedStateHandle`, `rememberSaveable`) and persistent storage **do** ([saving UI state](https://developer.android.com/topic/libraries/architecture/saving-states)). Apple ships the same shape under a different name: a scene delegate returns an `NSUserActivity` from `stateRestorationActivity(for:)`, and "When the user launches the app again, the sample's `scene(_:willConnectTo:options:)` method checks for the presence of an activity object" — the pre-scene `encodeRestorableState(with:)` path is documented alongside it, and SwiftUI adds `@SceneStorage` ([restoring your app's state](https://developer.apple.com/documentation/uikit/restoring-your-app-s-state)). **Do not write that one platform lacks a restoration API — both have one.**

What neither platform gives you is a *guarantee*. A user force-quit, a reboot, a restore-from-backup, or the system simply discarding what it saved all produce a plain cold start with nothing handed back, on either OS. So the hand-back is an optimisation on top of your own persistence, never a substitute for it.

Design for the stricter case and both platforms are covered: **assume you come back cold, and make coming back cold cheap.**

## Execution windows are budgeted, not published

This is where models invent numbers, so this section states only what the platforms publish and names what determines the rest.

**What Android publishes:**

- A `shortService` foreground service "must complete within 3 minutes" ([background tasks](https://developer.android.com/develop/background-work/background-tasks)).
- "If a background work task takes longer than 10 minutes to complete, it's highly likely to be interrupted. You should try to find ways to break tasks like that into smaller sub-tasks" (same source).
- "Beginning with Android 12, most foreground services do not show notifications to the user until they've been running for 10 seconds" (same source).
- Under Doze the system "suspends network access", "ignores wake locks", "defers standard `AlarmManager` alarms… to the next maintenance window", "doesn't let sync adapters run" and "doesn't let `JobScheduler` run" — and because the recommended scheduler uses `JobScheduler` internally, scheduled tasks do not run either ([Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby)). App Standby "defers background network activity for apps with no recent user activity."
- App Standby Buckets: "each app is placed in one of five priority buckets. The system limits the device resources available to each app based on which bucket the app is in" — Active, Working set, Frequent, Rare, Restricted. Placement is dynamic, may be driven by an on-device model of likely use, and "every manufacturer can set their own criteria" ([App Standby Buckets](https://developer.android.com/topic/performance/appstandby)).

**What Apple publishes:** the platform grants a background task an expiring window and hands you an expiration handler; the remaining time is readable at runtime. **Apple does not publish a fixed duration that this pack can cite, so this pack states none.** Read the remaining time from the API and always implement the expiration handler — code that branches on a hardcoded number is wrong on the day the budget changes, and it was never right on a device in Low Power Mode.

**What determines the window on both platforms** — this is the list to reason with, in place of a number:

- Recent user engagement with your app (both platforms weight this heavily; it is what the Standby buckets encode).
- Power state — battery level, charging, and low-power modes.
- Network availability and metering.
- Device idleness (Doze on one side, an equivalent idle policy on the other).
- What the user did last: force-quitting an app is a signal both platforms respect.
- Manufacturer policy on Android, which can be stricter than the platform baseline.

**The engineering consequence:** background execution is a *best-effort grant*, not a scheduled guarantee. Every background task needs (a) an expiration/cancellation path, (b) idempotent resumption, and (c) a foreground reconcile that repairs whatever never ran. A design whose correctness depends on a background task actually running is already broken.

## Choosing the mechanism

| The work is… | Use | Because |
|---|---|---|
| Only meaningful while the user is watching | Ordinary async work in the screen's scope | It is "not guaranteed to finish if the app stops being in a valid lifecycle stage" ([background tasks](https://developer.android.com/develop/background-work/background-tasks)) — which is fine, because nobody is waiting. |
| Must eventually happen; deferral is acceptable | The platform's deferrable work scheduler, with constraints (network, charging) | The system batches it into windows it was going to open anyway. This is the default and most work belongs here. |
| Must happen now, user-initiated, must not be interrupted | Foreground service with a declared type (Android) / the platform's user-visible task API | Visible to the user, and on Android each type carries its own permission and Play Console declaration (`permissions`). |
| Urgent but short | Expedited work / short-service type | Bounded by the platform: `shortService` "must complete within 3 minutes". |
| Triggered by the server | A push that wakes the app, treated as best-effort | `push-notifications` owns the delivery contract; delivery is not guaranteed, so back it with a foreground reconcile. |

Two rules that fall out: **a foreground timer is not background work**, and **a long task is a bug, not a configuration problem** — split it, because the platform tells you it will be interrupted.

## State restoration

The test is mechanical and every screen that holds user input must pass it: **cold-start after process death**, not "background then resume".

1. **Choose the key, not the state.** An entity id, a step index, a query string, a scroll anchor. Small, primitive, schema-stable.
2. **Persist on the transition, not on every keystroke.** Write when the screen leaves the foreground; that is the last moment you are guaranteed to run.
3. **Recompute the rest on restore.** Re-fetch the entity, re-derive the view state. A restored screen that shows stale data it never re-validated is worse than one that shows a spinner.
4. **Version the saved shape.** A restoration key written by the previous release lands in the next one. Unknown shape → discard and start clean, never crash.
5. **Declare what is allowed to be lost.** Not everything deserves restoration; a product decision that a filter selection resets is legitimate. An *undeclared* loss is the bug.

Restoration and the queued-write path are different problems: restoration puts the *user* back where they were; `offline-sync` gets the *data* where it was going.

## The seam with offline-sync

State the seam in both directions, because this is the pair that most often grows a duplicate implementation:

- **This pattern** owns: when the OS will let you execute, which mechanism to use, cancellation and expiration, and what survives process death.
- **`offline-sync`** owns: what sits in the mutation queue, idempotency keys, retry/backoff policy, conflict resolution, and the optimistic-UI rollback.
- **The handoff:** `offline-sync` declares *a queue exists and must be drained*; this pattern declares *how draining gets scheduled and what happens when the window closes mid-drain*. Neither should restate the other's half — if a document describes both a conflict policy and a scheduler, one of them is in the wrong file.

## Adapt to the codebase

| Stack | Lifecycle observation | Background mechanism | Restoration |
|---|---|---|---|
| **Cross-platform (JS runtime)** | App-state change subscription in one module | A background-task / background-fetch module bridging to each platform's native scheduler | Persisted key in the KV store chosen by `native-storage` |
| **Cross-platform (Dart runtime)** | Widget-binding lifecycle observer | A workmanager-style plugin bridging to each platform's native scheduler | Restoration mixin / persisted key |
| **Native iOS** | Scene / app delegate lifecycle callbacks | Platform background-task scheduler + expiring foreground-task API | State-restoration APIs plus a persisted key |
| **Native Android** | Lifecycle-aware components observing the process lifecycle | The platform deferrable scheduler, or a typed foreground service | `SavedStateHandle` / saveable state, plus a persistent store |

Whatever the stack, the shape is the same: **one** observer module, **one** scheduling entry point, **one** restoration convention. Three screens each inventing their own is how a project ends up with three different definitions of "backgrounded".

## Detectors (cite-or-halt)

1. **Timer or interval used as background work.**
   - BAD: a repeating interval, or a `setTimeout` chain, expected to keep running after the app leaves the foreground.
   - GOOD: the work is handed to the platform scheduler before backgrounding.
   - `grep -rniE "setInterval|setTimeout\(|Timer\.periodic|scheduleAtFixedRate" src/ app/ lib/` — read each site and ask whether it is expected to survive backgrounding.
2. **No lifecycle observer at all.**
   - BAD: nothing in the repo reacts to foreground/background transitions; stale data is never refreshed and nothing is persisted on the way out.
   - GOOD: a single observer module that fans out to refresh, persist, and re-check.
   - `grep -rniE "AppState|didEnterBackground|willEnterForeground|onResume|onPause|ProcessLifecycleOwner|didChangeAppLifecycleState" src/ app/ lib/ ios/ android/`
3. **Background task with no expiration path.**
   - BAD: the task body has no branch for "the system stopped us"; partial work is left inconsistent.
   - GOOD: an expiration/cancellation handler that leaves the work resumable and idempotent.
   - `grep -rniE "beginBackgroundTask|BGTask|WorkManager|CoroutineWorker|backgroundFetch" src/ app/ lib/ ios/ android/` — for each, find the cancellation branch or record its absence.
4. **A hardcoded background duration.**
   - BAD: any constant that encodes "how long we have" — a countdown against an assumed window.
   - GOOD: read the remaining time from the platform where it is exposed; otherwise treat the window as unknown and finish at the first safe point.
   - `grep -rniE "backgroundTimeRemaining|BACKGROUND_(TIME|WINDOW|LIMIT)|[0-9]+ ?(seconds|sec|s) ?(of )?background" src/ app/ lib/ ios/ android/`
5. **State held only in memory across a transition.**
   - BAD: a form or multi-step flow whose only home is a module-scoped store; cold start loses it silently.
   - GOOD: a restoration key persisted on the leaving-foreground transition.
   - Walk the screens that accept input; for each, name the persist site or record that loss is a declared product decision.
6. **Foreground service without a declared type.**
   - BAD: a foreground service with no `android:foregroundServiceType` and no matching permission — it will not start on current Android.
   - GOOD: type declared in the manifest, permission requested, type declared in the store console (`permissions` owns the declaration surface).
   - `grep -nE "foregroundServiceType|startForeground" android/app/src/main/AndroidManifest.xml android/app/src/main/java -r`
7. **No foreground reconcile.**
   - BAD: the app assumes the background sync ran; nothing repairs the state when it did not.
   - GOOD: on foreground, re-validate staleness and drain whatever the scheduler never got to.
   - Confirm the observer from detector 2 triggers a reconcile, not just a UI refresh.

## Closure verbs

- **Schedule** background work through the platform mechanism, never a timer.
- **Bound** every background task with an expiration / cancellation path.
- **Persist** a minimal restoration key on the leaving-foreground transition.
- **Recompute** the rest of the screen state on restore rather than serialising it.
- **Reconcile** on foreground whatever the background never completed.
- **Split** any task the platform says it will interrupt.
- **Declare** the foreground-service type alongside its permission.
- **Delete** every hardcoded background-duration constant.

## Testing

- **Cold start after process death** — the load-bearing test. Background the app, kill the process from the tooling (not from the task switcher, which is a different signal), relaunch, and confirm the screen restores from its key. `device-harness` runs this.
- **Airplane-mode transition mid-task** — the task should defer or fail cleanly, never hang.
- **Low-power / battery-saver mode** — confirm the app still reaches a consistent state, just later.
- **Force-quit then push** — a user-terminated app is treated differently by both platforms; verify the recovery path rather than assuming it.
- **Idle-device soak** — leave the device idle long enough for the platform's idle policy to engage, then confirm the foreground reconcile repairs the gap.
- **Restore across a release** — write a restoration key on the previous build, install the new one, confirm an unknown shape is discarded rather than crashing.

## Anti-patterns

- **"It works when I test it"** — every background bug is reproducible in the foreground and invisible there.
- **Awaiting a promise across backgrounding** — the continuation may never run; the UI waits forever on next launch.
- **Serialising the whole view model** — slow, fragile across releases, and a crash surface on restore.
- **A countdown against an assumed window** — wrong today or wrong after the next OS release.
- **Treating a delivered push as a guaranteed wake-up** — best-effort; back it with a foreground reconcile (`push-notifications`).
- **Non-idempotent resumption** — the task runs twice because the first window closed mid-write, and now there are two orders.
- **One scheduler per feature** — three features, three background mechanisms, no single place to reason about battery.
- **Using the task switcher swipe as the process-death test** — it is a user-initiated terminate, and it does not exercise the saved-state path.

## Boundary

This pattern owns **when the OS lets the app run and what survives when it does not**: the state machine, the choice of background mechanism, cancellation, and restoration.

It does not own: rebuild waste in a visible screen (`render-discipline`); queue contents, idempotency keys, and conflict policy (`offline-sync`); push delivery semantics (`push-notifications`); which storage primitive holds the restoration key (`native-storage`); the manifest/store declaration of a foreground-service type (`permissions`); applying a downloaded bundle at restart (`ota-updates`).

## Related

- `offline-sync.md` — owns the queue; this pattern owns the window in which it drains.
- `push-notifications.md` — a background push is a best-effort trigger, not a scheduling guarantee.
- `permissions.md` — foreground-service types, and the fact that a revoked permission can terminate the process.
- `native-storage.md` — where a restoration key is allowed to live.
- `render-discipline.md` (rule) — the visible-screen half of "why is this app slow"; this pattern is the invisible half.
- `device-harness` (skill) — boots a device and performs the cold-start-after-process-death test rather than asserting it.
- `@mobile-architect` — decides which work is background work before any of this applies.

## Sources

- Android, [background tasks overview](https://developer.android.com/develop/background-work/background-tasks) — mechanism choice, `shortService` 3-minute bound, the 10-minute interruption guidance, the Android 12 foreground-service notification delay.
- Android, [Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby) — what idle mode suspends, defers, and blocks.
- Android, [App Standby Buckets](https://developer.android.com/topic/performance/appstandby) — the five buckets and how placement is decided.
- Android, [save UI states](https://developer.android.com/topic/libraries/architecture/saving-states) — process death, what survives it, and the size guidance for saved state.
- Android, [foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types) — the type + permission requirement.
- Apple, [restoring your app's state](https://developer.apple.com/documentation/uikit/restoring-your-app-s-state) — `stateRestorationActivity(for:)`, the `NSUserActivity` handed back in `scene(_:willConnectTo:options:)`, and the pre-scene `encodeRestorableState(with:)` path. Verified 2026-08-21 through the JSON twin (`https://developer.apple.com/tutorials/data/documentation/uikit/restoring-your-app-s-state.json`); the canonical page is client-rendered and returns an empty body to a fetcher, which is why `references/swiftui.md` documents the twin.
- **Not sourced, deliberately:** any *duration* for a background execution window on either platform. None is published; see § Execution windows above.
