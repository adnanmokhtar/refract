---
description: Audit JS↔native bridge code for type safety, error propagation, performance, and lifecycle correctness. RN / Flutter / native bridges are leaky abstractions — most bugs live here.
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

Action: TypeScript types (RN) or generated classes (Pigeon) eliminate ~80% of bridge bugs.

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

Flutter: `MethodChannel` calls happen on the platform thread by default. Use isolates for heavy work.

### 5. Lifecycle correctness

- App backgrounded mid-call — what happens? (RN: native code keeps running unless cancelled.)
- App killed mid-call — promise never resolves on next launch. JS layer needs reconnection.
- Module unloaded (rare but happens with RN feature flags) — native references invalidated.
- Activity recreation on Android (config change) — listeners attached to the old activity.

### 6. Memory + retain cycles

- Native retains JS callback → JS object retained by native → cycle. Always weak-reference callbacks where the lib supports it.
- Background tasks holding references to dismissed UI.
- Notification listeners not removed on `componentWillUnmount` (RN) / `dispose` (Flutter).

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
**Critical (BLOCK release):**
- [Type mismatch] JS expects `{ id: number, name: string }`; iOS returns `id` as string in some path.
- [Lifecycle] Promise on `getLocation()` never resolves if app backgrounded during the GPS lock — verified by killing JS thread mid-call.

**High (fix soon):**
- [Threading] Camera capture handler runs on background thread; result delivered to main but consumer assumes already on main → race on `setState`.
- [Memory] FCM listener attached in module init; never removed → retain cycle.

**Medium:**
- [Types] No TypeScript declaration for `BridgeModule.recordCustomEvent(eventName, payload)`. Caller passing structured payload crashes.

**Nits:**
- [Logging] Native side logs `error.localizedDescription` only; `userInfo` dict contains the actual cause.

### Test gaps
- No mock for permission-denied path on iOS.
- No test for app-backgrounded-mid-call.

### Recommendations
1. Generate types via Pigeon (Flutter) / TurboModule spec (RN).
2. Add cancel hook for long-running operations.
3. Wrap promises with timeout.
4. Add JS-side reconnection logic for "module reloaded" cases.
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
