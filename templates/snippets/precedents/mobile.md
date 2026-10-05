# Precedents — mobile (lifecycle, background, permissions, links, push, OTA, rendering, device security, store)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 and § 10 for
every candidate a mobile detector raises: state lost on process death, background work, permissions,
network timeouts, deep-link payloads, push, OTA updates, render and list cost, native accessibility
and store gates, on React Native / Expo, Flutter, iOS (Swift, SwiftUI, UIKit) and Android (Kotlin,
Compose, Views). Device-security classes (storage, transport, IPC, WebView, release flags) are judged
by the security pack's [`finding-verification.md`](../finding-verification.md) when that pack is
installed; § 42–48 are the calibration it reads for them. The oracles are in
[`proof-oracles.md`](../proof-oracles.md) § Mobile. The three cross-domain precedents are in
`refute-before-report.md § 4`.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening**; the flip evidence makes it a candidate again.
A precedent applies only when its "must be true" clause is shown with a `file:line`, a lockfile line
or a recorded device run. Numbers are stable: detectors cite `precedents/mobile.md § <n>`.

## The claim, restated

§ 1 of the protocol takes this shape here. A candidate that cannot fill every bracket is not a finding.

> On **[platform + OS version, merged `targetSdk` / deployment target, a release build]**, when
> **[the OS event — process death while backgrounded, a permission denied twice, a cold-start link,
> a data-only push while terminated, a request that never answers, an OTA update on an older
> binary]**, **[the code or config at file:line]** produces **[lost input, a crash, a dead end, an
> endless spinner, work that never runs, a notification for the wrong account]** instead of
> **[the expected outcome]**, proven by **[the oracle, at tier D / I / A / S]**.

**Oracle tiers.** D = a device or emulator run (Maestro, Espresso / UiAutomator, XCUITest, Detox,
`integration_test`, or a platform shell command such as `adb shell am kill`); I = an instrumented
or widget test; A = inspection of the shipped artifact (merged manifest, signed entitlements, the
bundle); S = a static trace. Every class names the tier its proof needs. A candidate whose required
tier was not reached is **Unconfirmed** with the settling command, never a Finding and never
dropped. **No booted device or emulator means `SKIPPED`, never PASS**: host-only tests cannot prove
a lifecycle, permission, link, push or background fix.

## Reading the seven gates for mobile

| Gate | Mobile reading |
|---|---|
| 1 Reachability | The code ships in a **release** build: not under `__DEV__`, `kDebugMode`, `BuildConfig.DEBUG`, `#if DEBUG`, a `src/debug/` source set or a test target; a screen or entry point (launcher, link, push, job) reaches it |
| 2 Trigger condition | The OS event occurs in real use: the OS kills backgrounded processes on low-RAM devices and whenever a permission is revoked in Settings; users deny prompts; links arrive at cold start; networks hang |
| 3 Version | Read from the build and lock files, never from memory: merged `targetSdk` / `minSdk`, AGP, Kotlin, `react-native`, `expo` SDK, Flutter / Dart SDK, iOS deployment target, Swift language mode and default isolation (§ 50–59) |
| 4 No existing control | The **effective** config agrees with the source: the merged `AndroidManifest.xml` (libraries inject permissions, services and receivers), the signed entitlements, the Expo prebuild output and config plugins, `INFOPLIST_KEY_*` build settings. Then the neutralizers: a library default, a wrapper, R8 rules, a compiler mode |
| 5 Real impact | Lost user input or data, a crash or ANR, a feature with no way forward, work that silently never runs, a privacy leak across accounts, a store rejection (release-blocker axis, not a security severity) |
| 6 Proof | The class oracle at its required tier, failing first (`proof-oracles.md` § Mobile) |
| 7 Deployment and environment | The platforms and OS versions the product ships to (an iOS-only app has no Android class), the distribution (store, enterprise, kiosk), the update channel |

## Do not flag — posting rules the verifier applies

1. **Pre-existing lines.** On a diff run, a defect on lines the change neither touched nor copied is Pre-existing (`refute-before-report.md § 5`).
2. **Debug-only paths** (gate 1 above): debug menus, Flipper and dev-client wiring, `src/debug/`, test hosts.
3. **A location in generated native folders of an Expo CNG project.** When `ios/` and `android/` are git-ignored or absent, `expo prebuild` rewrites them and a fix there is lost: re-locate the finding to `app.json` / `app.config.*` or a config plugin, never report the generated file.
4. **What a configured lint already fails in CI at error level** (Android lint, detekt, SwiftLint, `flutter analyze`, ESLint). The finding, if any, is that the rule is off, at warning, baselined or not run.
5. **A scanner hit with no read** (MobSF, mobsfscan): input to triage, never a verdict.
6. **Store-text quality** — the wording of a purpose string, a Data safety answer — is `@app-store-reviewer`'s judgement, not a detector finding.
7. **Duplicates.** One finding per root cause: a defect in a shared client, base screen or wrapper is one finding with N call sites.
8. **Security classes** (token storage, cleartext, link hijack, exported components, WebView bridges, shipped secrets) go to the security pack when installed; without it they are reported by the mobile detector, tagged `security-class (owner pack not installed)`.

## Not a finding — process death and lifecycle

9. **`am force-stop`, Maestro `stopApp`, Android Studio Stop, a swipe from Recents and XCUITest `terminate()` are not process death.** Force-stop enters the stopped state (alarms, jobs and, on Android 15, all pending intents are cancelled) and saved state is discarded by design; `terminate()` + `launch()` is a cold start. State lost after them is not a restoration finding unless the data was promised durable (a draft, an outbox). *Flips back:* a test or a claim uses one of them **as** process-death proof — that is a proof defect.
10. **"Don't keep activities" and `ActivityScenario.recreate()` passing does not mean restoration works.** Singletons survive the first and the ViewModel survives the second; process death (background, then `adb shell am kill`, then relaunch from Recents) is the mandatory variant and they are additional ones.
11. **Transient UI state** in `remember`, `@State` or a plain field — a menu expanded, an animation flag, a hover — may be lost on process death. *Flips back:* user-typed text, a position in a multi-step flow, a selection the user made, a scroll position the product promises.
12. **ViewModel state that is a cache of a repository or database** and is re-read on restore is correct design.
13. **React Native `MainActivity`**: `supportFragmentManager.fragmentFactory = RNScreensFragmentFactory()` before `super.onCreate(...)` is the current react-native-screens restoration fix; `super.onCreate(null)` is the older documented workaround. Neither is a finding.
14. **App-lifetime work and listeners**: a listener registered once at module scope (`index.js`), `ProcessLifecycleOwner` scope, `GlobalScope` under `@OptIn(DelicateCoroutinesApi::class)` with a stated app-lifetime reason.
15. **Selector-based `NotificationCenter` observers** are removed automatically (iOS 9+); only a discarded **block-based** observer token leaks.
16. **`[weak self]` is not needed** in non-escaping closures (`map`, `forEach`, `UIView.animate`), in SwiftUI `struct` views, or in a short-lived `Task {}` that is not stored on `self`.
17. **Flutter `setState` after `await`** guarded by `if (!mounted) return;` (or `context.mounted` outside a `State`) is correct.

## Not a finding — background work

18. **Legitimate special access**: `USE_EXACT_ALARM` in an alarm-clock or calendar app, a `mediaPlayback` foreground service in a player, the `location` background mode in a navigation app.
19. **Bounded resources**: `WakeLock.acquire(timeout)`; a `shortService` foreground service for work under its ~3-minute limit.
20. **BGTask identifiers matched through a constant** (`static let refreshID = "…"`) or a `$(PRODUCT_BUNDLE_IDENTIFIER)` expansion: resolve them before the plist set-difference; a raw-string diff is noise.
21. **Off-main blocking**: `runBlocking` inside `Worker.doWork`, `.execute()` inside `withContext(Dispatchers.IO)`.
22. **Periodic work enqueued with `enqueueUniquePeriodicWork` elsewhere** (a library module, an initializer) is not a duplicate-work finding.

## Not a finding — permissions

23. **A request in context**: in `onCreate` or on appear of a screen the user opened for that purpose (a scanner, a map). The launch-wall class is a request at app start.
24. **No runtime `POST_NOTIFICATIONS` request on `targetSdk` ≤ 32** (the system prompts at first channel creation); normal permissions (`INTERNET`); a purpose string supplied by an `INFOPLIST_KEY_*` build setting or an Expo config plugin (plugins ship default strings — confirm in the prebuild output, and the wording is § 6's).
25. **A library-injected permission removed** in the app manifest with `tools:node="remove"` (confirm in the merged manifest).

## Not a finding — network, links, push and OTA

26. **Clients with a default timeout**: OkHttp's builder defaults are 10 s connect, read and write (`callTimeout` 0); `URLSession` defaults are a 60 s idle request timeout and a 7-day resource timeout; Ktor's CIO engine applies its own request and connect timeouts. A read timeout of 0 on a streaming client (SSE, a long poll) is deliberate when a heartbeat or a call timeout bounds it. *Flips back:* axios (default `timeout: 0`), dio (connect / receive / send timeouts default to null), Dart `package:http` (no timeout), and React Native's Android networking client (`OkHttpClientProvider` sets all three to 0) have **none** — sources read 2026-10-05 (axios `lib/defaults`, dio `options.dart`, react-native v0.87.1 `OkHttpClientProvider.kt`, Apple `URLSessionConfiguration` reference, okhttp `OkHttpClient.kt`).
27. **Deep links that need no gate**: a link to a public screen (a product page) without auth; a parameter that is an id used to build an allow-listed URL; a custom scheme used only for marketing "open the app" links; `?mode=developer` in a Debug-only entitlements file.
28. **`getInitialMessage()` / `getInitialNotification()` return the tap once**; a null on a second call is by design, not a lost tap.
29. **Push wiring that is already covered**: a token uploaded on every launch (idempotent) in place of a refresh listener; a channel created by a library (Expo's default channel, notifee); `aps-environment = development` in an entitlements file only the Debug configuration uses (`CODE_SIGN_ENTITLEMENTS` per configuration in the `.pbxproj`).
30. **OTA policy choices**: `checkAutomatically: NEVER` with an explicit `checkForUpdateAsync` early in launch; `fallbackToCacheTimeout` > 0 in a kiosk that must run the latest bundle; a manual `runtimeVersion` that CI bumps on every native change (read the CI script); a Shorebird patch that changes Dart only; `react-native-code-push` pointed at a self-hosted server (`CodePushServerURL` / `CodePushServerUrl`).
31. **An unsigned update from Expo's own update service** is a lower-severity row than one from a self-hosted server; EAS code signing needs a paid plan, so record the plan before calling it a defect.

## Not a finding — rendering, lists, accessibility and crash-prone code

32. **Compose strong skipping** (default since Kotlin 2.0.20): an "unstable parameter" is not a skippability finding unless strong skipping is disabled. The residual bug is a new instance on every recomposition (identity comparison fails) or a lambda capturing unstable state.
33. **React Compiler on** (`experiments.reactCompiler`, or the Babel plugin): a missing `React.memo` / `useCallback` / `useMemo` is not a finding.
34. **FlashList v2** removed `estimatedItemSize` (and other measuring props): its absence on v2 is correct; its presence is a dead prop; on v1 its absence is the finding. A `key` inside a FlashList item breaks recycling — that flips back.
35. **Hermes is the default engine** (Hermes V1 the default from RN 0.84): "enable Hermes" advice is noise unless the build opts out.
36. **A `ScrollView` / `Column` / `VStack` of about 20 static items**, or a bounded enum, needs no virtualization. *Flips back:* the items come from fetched or user-sized data.
37. **Compose Material components pad their touch target to 48 dp** (`minimumInteractiveComponentSize`): a small icon inside a Material `IconButton`, or inside any 48 dp box, is not a target-size finding. *Flips back:* a bare `Modifier.clickable` on a small `Box`, or the minimum overridden to 0 / `Dp.Unspecified`.
38. **RN `marginLeft` / `left` auto-swap in RTL** by default: Low at most. Transforms, directional icons and `textAlign` are real findings. SwiftUI `Text("Literal")` is a `LocalizedStringKey`; `Text(verbatim:)` and `Text(variable)` are not.
39. **Swift literal force-unwraps**: `URL(string: "https://…")!` and `UIImage(named: "literal")!` are deliberately skipped by SwiftLint's `force_unwrapping`; a force-unwrap detector must skip literal arguments. `try!` and `as!` need their own patterns.
40. **Kotlin and Dart non-findings**: `lateinit` on DI-injected, `@get:Rule` or first-line-of-`onCreate` fields; `as` after `is`; `!!` and `try!` in tests; Dart `late final x = expr` (a lazy initializer cannot throw `LateInitializationError`); `!` right after a local null check.
41. **Minify off in a library module**: the app module minifies with consumer rules.

## Device-security calibration (read by `finding-verification.md` for mobile rows)

42. **Token storage**: Keychain, Keystore-backed stores (expo-secure-store, react-native-keychain, flutter_secure_storage) and MMKV keyed from Keystore / Keychain are fine. A token in **app-private** plaintext storage is MASWE-0001, an L2 control: an advisory unless the project declares an L2 posture (fintech, health, government). The same value in external storage, logs or backups is L1, a defect for every app. EncryptedSharedPreferences is deprecated, not insecure: a migration advisory.
43. **No certificate pinning is not a finding for an L1 app** (MASWE-0028 is L2; Android's guidance discourages pinning). An **expired** `<pin-set>` means pinning is off — report it as absent, never as present.
44. **Not secrets**: Firebase `AIza…` keys, `google-services.json`, `GoogleService-Info.plist` `API_KEY` identify the project (check API restrictions and App Check) — except a Gemini Developer API key, which is critical. Publishable keys (`pk_live_`, a Supabase anon key behind RLS, a Sentry DSN, Mapbox `pk.`) are public by design, and **any** value read by client code is public whatever its EAS visibility.
45. **Transport exemptions**: `NSAllowsArbitraryLoads` is ignored when `…InWebContent`, `…ForMedia` or `NSAllowsLocalNetworking` is present; cleartext to `10.0.2.2` / `localhost` in a debug-only network config or inside `<debug-overrides>` is fine.
46. **IPC exemptions**: `exported="true"` on the launcher activity is required; exported behind a `signature` permission is fine; a mutable `PendingIntent` on an **explicit** intent for RemoteInput or bubbles is legitimate; StrandHogg is moot at `minSdk` ≥ 30.
47. **`FLAG_SECURE` / `.privacySensitive`** is a finding only on PIN, card, seed-phrase or OTP screens.
48. **The RN template `debug.keystore`** (password `android`) is fine unless the release `signingConfig` uses it.
49. **Store**: Stripe or web checkout for physical goods or services is allowed (Apple 3.1.5); guideline 4.8 asks for an *equivalent* privacy-preserving login, not Sign in with Apple specifically — report "verify", not a hard defect; a dated store gate is quoted "per the page as of <date>".

## Version precedents — read the installed version before reporting

50. **React Native New Architecture is the only architecture from 0.82**: `newArchEnabled=false` / `RCT_NEW_ARCH_ENABLED=0` are ignored; 0.81 (Expo SDK 54) was the last release that could run the legacy one (RN 0.82 release post, 2025-10-08). "Migrate to the New Architecture" on ≥ 0.82 is noise; a legacy-only dependency there is a real finding.
51. **`InteractionManager`** stopped deferring in RN 0.80 (setImmediate semantics), ignores interaction handles from 0.82 and was removed in 0.87 in favour of `requestIdleCallback` (RN CHANGELOG). Advice to use it is a defect, not a fix. **`AppState.removeEventListener`** was deprecated in 0.65 and is gone from 0.70: a call on ≥ 0.70 is a crash.
52. **Android `targetSdk` gates** — a rule fires only at or above its level, read from the **merged** `targetSdk` (or `flutter.targetSdkVersion`, `expo-build-properties`): 33 runtime `POST_NOTIFICATIONS`; 34 a foreground service without a declared type throws, exact alarms denied by default for new installs, partial photo access (`READ_MEDIA_VISUAL_USER_SELECTED`); 35 `dataSync` / `mediaProcessing` share a 6 h per 24 h budget ending in `Service.onTimeout`, and `BOOT_COMPLETED` receivers may not start several FGS types; 36 predictive back on (`onBackPressed` not called) and orientation locks ignored on displays ≥ sw600dp. Play requires target 36 for updates from 2026-08-31 (extension to 2026-11-01), so an app that ships an update meets every gate above.
53. **AGP 9.3** replaced `isMinifyEnabled` with `optimization { enable = true }`: "minify off" read from the absence of `isMinifyEnabled` on AGP ≥ 9.3 is a false positive.
54. **Expo**: `expo-background-fetch` is deprecated (2025-04-04, SDK 53 cycle) for `expo-background-task`; remote push on Android is unavailable in Expo Go from SDK 53 (a dev build is required); `shouldShowAlert` is deprecated for `shouldShowBanner` / `shouldShowList`.
55. **Retired services**: CodePush retired with App Center on 2025-03-31 (repository archived 2025-05-20, no New Architecture support); `@notifee/react-native` was archived on 2026-04-07, and notifee ≥ 7 swallows `getInitialNotification` / `onNotificationOpenedApp`.
56. **Firebase Cloud Messaging**: the legacy HTTP and XMPP APIs were shut down from 2024-07-22; the HTTP v1 API returns `UNREGISTERED` (HTTP 404) for a stale token (Firebase *ErrorCode* reference, updated 2026-02-03). Sender code that prunes only on the legacy `NotRegistered` never prunes.
57. **Flutter background entry points** (`onBackgroundMessage`, workmanager's dispatcher, background-service `onStart`) must be top-level functions annotated `@pragma('vm:entry-point')` (Flutter ≥ 3.3), or release builds tree-shake them; an anonymous closure is never invocable in the background.
58. **Swift 6.2 default MainActor isolation**, when the target enables it, runs unannotated functions on the main actor: read `SWIFT_DEFAULT_ACTOR_ISOLATION` before claiming code runs off main.
59. **`flutter_secure_storage` 11** removed `encryptedSharedPreferences`; a 9 → 11 jump without the migration path loses stored values.

## Rationalizations to reject (mobile)

**Wrongly accepting:** "MobSF flagged it" · "it crashes in debug" (release reachability?) · "the
emulator was slow" · "Don't keep activities passes, so restoration works" · "the force-stop test
passed" · "the agent added accessibility labels" (run the checker) · "the unit tests pass" (host
tests cannot prove lifecycle, permission, link, push or background behaviour).

**Wrongly dismissing:** "users never kill the app" (the OS does) · "we test on flagship phones" ·
"it is only in the JS bundle, which is compiled" (Hermes bytecode decompiles) · "the Keychain is
wiped on uninstall" (it is not, on iOS) · "the source manifest has no such permission" (read the
merged one) · "Expo handles that" (show the config plugin and the prebuild output).

---

Sources (accessed 2026-10-05): the Track A mobile research catalog and its lifecycle, performance
and security notes — developer.android.com (saving states, process and activity lifecycle, adb,
behaviour changes 14–16, foreground-service types, exact alarms, partial photo access, permissions,
strong skipping, Compose accessibility defaults), Apple developer documentation (BGTaskScheduler,
SceneStorage, URLSessionConfiguration, protected resources, aps-environment, App Review
Guidelines), docs.expo.dev (updates, background task, notifications, React Compiler), reactnative.dev
blog and CHANGELOG (0.82, 0.87), react-native-screens README, FlashList v2 changes, docs.flutter.dev
and firebase.google.com (FCM receive, ErrorCode, manage tokens, migration FAQ), Microsoft Learn App
Center retirement, OWASP MASVS 2.1.0 / MASWE (CC BY-SA 4.0, paraphrased), and library source read
the same day (axios, dio, dart-lang/http, okhttp, react-native v0.87.1). Paraphrased; no text
reproduced beyond short quoted identifiers.
