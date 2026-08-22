---
name: native-bridge-audit
description: Audit JS↔native bridge code for type safety, error propagation, performance, and lifecycle correctness — RN / Flutter bridges are leaky abstractions where most bugs live. Run when adding a native module (TurboModule / NativeModule / MethodChannel / Pigeon), before a release, or when investigating a flaky bridge bug. Bridge boundary only, not general native or JS code review.
---

# Skill: native-bridge-audit

JS↔native bridge code is where mobile bugs cluster. Type mismatches between sides, dropped promises on app backgrounding, threads where you didn't expect, retain cycles. This skill walks a bridge module systematically.

## Premise

Find real issues. Every finding cites `<path:line>` on both sides of the bridge — JS/TS file + native iOS file + native Android file. "Type mismatch" requires both signatures quoted. "Promise hangs on background" requires either a reproducer or the specific code path where neither resolve nor reject is called. "Retain cycle" requires the listener-attach line + the missing-detach call site. No accusation without coordinates.

## Halt conditions

- Refuse to flag a "type mismatch" without quoting both signatures.
- Refuse to call a promise leak "critical" without naming the file/line that fails to resolve.
- Halt if you've audited only one platform — iOS-only audit is incomplete; same for Android.
- Don't propose Pigeon / TurboModule migration without auditing what the current bridge actually does.

## When to use

- Adding a new native module (RN: TurboModule / legacy NativeModule. Flutter: MethodChannel / Pigeon).
- Auditing an existing native module before a release.
- Investigating a flaky bridge-related bug.
- Reviewing a third-party SDK with a thin JS wrapper.

## Procedure

### 1. Inventory the bridge surface

For each method/property crossing the bridge:
- Direction: JS → native (call), native → JS (event), both.
- Arguments: types on JS side AND native side. Document mismatches.
- Return / event payload shape.
- Async or sync? (Sync is dangerous on RN — blocks the JS thread.)

### 2. Type-safety check

| Side | Issue |
|---|---|
| JS / TS | Types accurately reflect what native returns? Often `any` after `.then(...)` because nobody typed the result. |
| iOS Swift | NSDictionary keys handled as Optional. Force-unwraps that crash on missing key. |
| iOS Obj-C | Implicit casts (e.g., NSString → NSNumber) that succeed silently. |
| Android Kotlin | Nullability handled. Default values for missing keys. |
| Android Java | NullPointerException possible on `getString` etc. |
| Flutter Dart | `MethodChannel` returns `dynamic` — no compile-time guard. Use Pigeon for typed channels. |

Action: generate the boundary rather than hand-writing it — a TurboModule spec (RN) or Pigeon (Flutter) makes the two sides fail at build time instead of at runtime. **No figure is stated for how much this helps**: none is published, and the claim you can actually make in a finding is structural — an ungenerated boundary has no compile-time check, so every mismatch in it is found by a user.

### 3. Error propagation

- Native success → JS resolve. Always.
- Native error → JS reject with structured payload (code + message + userInfo). NOT an opaque string.
- Unhandled native exceptions → catch + reject; don't crash the bridge.
- Timeouts on native side for long-running calls.

Common bug: native catches error, logs it, never invokes resolve OR reject — JS promise hangs forever.

### 4. Threading

- Which thread does the native handler run on?
- Which thread does the result fire on (JS thread? native main thread?)?
- Are there UI-thread requirements (e.g., camera, certain UIKit calls)?
- Are there long-running operations on the wrong thread (blocking main = ANR)?

RN: `NativeModules` callbacks fire on JS thread. UI-thread work needs explicit dispatch (`dispatch_async(dispatch_get_main_queue(), ...)` / `runOnUiThread { ... }`).

Flutter: platform-channel handlers run on the **platform main thread** — "This method is invoked on the main thread". **Isolates do not fix this**: they move work off the *Dart* thread, so an ANR caused by a heavy handler survives one. The documented remedy is channel-side: construct the channel with a background task queue from `makeBackgroundTaskQueue()` — "In order for a channel's platform side handler to execute on a background thread on an Android app, you must use the Task Queue API" (https://docs.flutter.dev/platform-integration/platform-channels, read 2026-08-20). Reach for an isolate for heavy **Dart** work; reach for the task queue for heavy **platform** work.

### 5. Lifecycle correctness

- App backgrounded mid-call — what happens? (RN: native code keeps running unless cancelled.)
- App killed mid-call — promise never resolves on next launch. JS layer needs reconnection.
- Module unloaded (rare but happens with RN feature flags) — native references invalidated.
- Activity recreation on Android (config change) — listeners attached to the old activity.

### 6. Memory + retain cycles

- Native retains JS callback → JS object retained by native → cycle. Always weak-reference callbacks where the lib supports it.
- Background tasks holding references to dismissed UI.
- Listeners attached and never removed — RN: the cleanup return of the `useEffect` that attached it (`componentWillUnmount` only applies to legacy class components). Flutter: `dispose()`. A subscription with no matching teardown is the finding; name both call sites.

### 7. Permissions

If the bridge calls APIs needing permission (camera, location, photos, microphone), confirm:
- Permission check before the API call.
- Graceful failure when denied.
- Permission rationale strings present in `Info.plist` / `AndroidManifest.xml`.

### 8. Versioning

- Native module API version pinned (e.g., a TurboModule spec).
- Backward-compat guards for older OS versions (`if #available(iOS 14.0, *)`).
- Feature detection rather than version detection where possible.

### 9. Tests

- Unit tests on JS side mocking the native module — happy path, error path, timeout.
- Native side: XCTest / JUnit / Espresso tests for the native code.
- E2E test (Detox / Maestro) covering one path end-to-end.

## Output format

```
## Native bridge audit — <module-name>

### Bridge surface
| Method | Direction | Sync/async | Tested? |
|---|---|---|---|

### Findings
**Every row below is a placeholder filled from a read file.** This skill ships no worked example,
for the reason `/optimize-bundle` states about its own template: a report pre-populated with
plausible findings is the single easiest thing to reproduce as if it were real. A finding with no
`<path:line>` on **both** sides of the bridge is not a finding — write `none found` instead.

| Severity | Class | JS/Dart `<path:line>` | Native `<path:line>` | Evidence |
|---|---|---|---|---|
| Critical / High / Medium / Nit | one of: Type mismatch · Error propagation · Threading · Lifecycle · Memory · Permissions · Versioning | `<path:line>` | `<path:line>` | the quoted signature pair, the non-resolving branch, or the attach-without-detach pair |

Severity is decided by consequence, not by class: **Critical** = crashes, hangs the JS thread, or
loses user data; **High** = wrong behaviour on one platform; **Medium** = untyped or unguarded but
currently working; **Nit** = diagnosability only.

### Test gaps
`<the audited paths with no test, named>` — or `none`.

### Recommendations
Ordered by severity, each naming the exact call site it changes. Generic advice ("add types",
"wrap in a timeout") with no call site is not a recommendation.
```

## Inputs

- Module path (JS side + native iOS + native Android).
- Recent crash reports if any.

## Outputs

- `ai/audits/bridge-audit-<module>-<date>.md`.

## Hard rules

- No native bridge without a typed JS surface.
- No promise without explicit timeout when crossing the bridge.
- No native module without lifecycle teardown documented.
- No bridge call from a constructor — initialization happens after the runtime is ready.

## Failure modes (your own work)

- Audited the JS side; missed that the native side has a different API surface in a transitive SDK update.
- Missed iOS/Android divergence (works on iOS, broken on Android same module).
- Tested in dev build with hot reload — production behavior differs.

## Related

- `rules/mobile-principles.md` — the UI-thread and cite-the-number rules this skill enforces at the bridge.
- `references/flutter.md` § Platform channels — the task-queue mechanics and the Pigeon recommendation.
- `references/react-native.md` — New Architecture / TurboModule context for the JS side.
- `ai-patterns/permissions.md` — a bridge that calls a permission-gated API inherits that pattern's four-state model; do not re-derive it here.
- `ai-patterns/app-lifecycle.md` — what "app backgrounded mid-call" actually means, and which callbacks are still allowed to run.
- `@device-performance-auditor` — a blocking bridge call is a responsiveness cost; hand it the call site rather than asserting a frame number here.
- `@mobile-architect` — whether the bridge should exist at all is a design question, not an audit finding.

## Sources

- Flutter, [platform channels](https://docs.flutter.dev/platform-integration/platform-channels) (read 2026-08-20) — handlers run on the main thread; `makeBackgroundTaskQueue()` is the documented way off it.
- **Deliberately absent** — each was looked for and is not published: a bridge-call latency budget, a maximum serialisable payload size, a share of bugs attributable to the bridge, and a timeout value for a cross-bridge promise. The last one is a **project** budget: pick it from the slowest legitimate call you measured, and record it beside the call site.
