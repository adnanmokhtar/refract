# Jetpack Compose reference (native Android — API-level-scoped, not pinned)

> **Framework**: Jetpack Compose + Kotlin on Android. Four dials decide what compiles and what ships, and they move independently: `compileSdk`, `targetSdk`, `minSdk`, and the Kotlin version. Read all four from `build.gradle.kts` before writing code — most of the rules below are keyed to one of them.
> **Official docs**: https://developer.android.com/develop/ui/compose • Play requirements: https://developer.android.com/google/play/requirements/target-sdk • Android vitals: https://developer.android.com/topic/performance/vitals
> **Version-specific gotchas**: **`targetSdk` is a dated distribution gate, not a preference.** As of 2026-08-21 Google Play states: "New apps and app updates must target Android 16 (API level 36) or higher to be submitted to Google Play; except for Wear OS and Android Automotive OS apps, which must target Android 15 (API level 35) or higher, and Android TV and Android XR apps, which must target Android 14 (API level 34) or higher", effective **August 31, 2026**, with "an extension to November 1, 2026" available (https://developer.android.com/google/play/requirements/target-sdk). Raising `targetSdk` opts the app into behaviour changes — edge-to-edge and foreground-service types below are the two that break apps most often. The Compose compiler also moved: since **Kotlin 2.0** it ships in the Kotlin repository and is applied as the Gradle plugin `org.jetbrains.kotlin.plugin.compose` (https://developer.android.com/develop/ui/compose/compiler).
> **Substitution markers**: replace `<Name>` with the project's actual feature / screen names.

## Read the build files before you read this file

- **`targetSdk`** — decides which OS behaviour changes apply to this app *and* whether Play will accept the upload (see gotchas).
- **`minSdk`** — decides which APIs are reachable at all; every "available from API N" note is scoped by it.
- **Kotlin version** — decides the Compose compiler setup and several compiler defaults (strong skipping, below).
- **Compose BOM** — "lets you manage all of your Compose library versions by specifying only the BOM's version ... When using the BOM in your app, you don't need to add any version to the Compose library dependencies themselves" (https://developer.android.com/develop/ui/compose/bom). It is calendar-versioned `YYYY.MM.00` (`2026.08.00` was current on 2026-08-21). Declare `platform("androidx.compose:compose-bom:<version>")` once and leave every `androidx.compose.*` dependency unversioned; a hand-pinned Compose artifact alongside the BOM is how mismatched-runtime crashes get introduced.
- **Android CLI**, if the environment has it, is the fastest way to answer all of the above plus the docs: `android describe` analyses project structure, and `android docs search` / `android docs fetch` reach the Android Knowledge Base (https://developer.android.com/tools/agents/android-cli). See "Agent tooling".

## Structure

```
app/src/main/java/<pkg>/
├── MainActivity.kt            # single activity, enableEdgeToEdge(), setContent { }
├── feature/
│   └── <name>/
│       ├── <Name>Screen.kt    # stateless composables
│       ├── <Name>ViewModel.kt # state holder, exposes UiState
│       └── <Name>Repository.kt
├── core/
│   ├── designsystem/          # Theme.kt, Color.kt, Type.kt, components
│   ├── data/                  # Room, DataStore, network
│   └── navigation/
└── ui/theme/
app/src/main/AndroidManifest.xml
app/build.gradle.kts
```

## Core choices (opinionated)

- **State holding** — a `ViewModel` exposing one immutable `UiState` as `StateFlow`, collected in the composable with `collectAsStateWithLifecycle()`. One state object beats five independent flows: it makes impossible combinations unrepresentable.
- **State hoisting** — composables that render are stateless and take `(state, onEvent)`. `remember { mutableStateOf(...) }` is for state no one above needs, and it belongs at the lowest composable that reads it (`rules/render-discipline.md`, detector 1).
- **Navigation — check which library the project uses; there are now two, and both are stable.** `androidx.navigation:navigation-compose` (stable 2.9.8, released 2026-04-22 — https://developer.android.com/jetpack/androidx/releases/navigation) is the established one. **Navigation 3 is a separate, newer library that reached stable 1.1.6 on 2026-08-12** (`androidx.navigation3:navigation3-runtime` / `navigation3-ui` — https://developer.android.com/jetpack/androidx/releases/navigation3). It is "a new navigation library designed to work with Compose" that "Offers you full control of the back stack" and "Makes it possible to create layouts that can read more than one destination from the back stack at the same time" (https://developer.android.com/guide/navigation/navigation-3). Its API is *not* Navigation 2's `NavHost` — writing `NavHost` into a Navigation 3 project, or Nav3 back-stack code into a Nav2 project, does not compile. Read the dependency first.
- **Persistence** — Room for relational data; **DataStore, not `SharedPreferences`, for key-value**. "Jetpack DataStore is a data storage solution that lets you store key-value pairs or typed objects with protocol buffers. DataStore uses Kotlin coroutines and Flow to store data asynchronously, consistently, and transactionally", and "If you're using `SharedPreferences` to store data, consider migrating to DataStore instead" (https://developer.android.com/topic/libraries/architecture/datastore). The reason is concrete: `SharedPreferences` exposes synchronous, UI-thread-blocking calls; DataStore's `updateData` block "is treated as a single transaction".
- **Secrets — do not reach for `EncryptedSharedPreferences`.** As of `androidx.security:security-crypto` **1.1.0-beta01 (2025-06-04)**, the release notes read "Deprecated all APIs in favour of existing platform APIs and direct use of Android Keystore"; the deprecation covers `EncryptedSharedPreferences`, `EncryptedFile` and `MasterKeys`, and stands in the current 1.1.0 release (2025-07-30) (https://developer.android.com/jetpack/androidx/releases/security). Use the Android Keystore directly, or a wrapper the project already owns. Where existing project code or an older document names `EncryptedSharedPreferences`, read the intent as "Keystore-backed key storage" and satisfy it with a non-deprecated path — the requirement is the threat model, not the artifact.
- **DI** — Hilt where the project already uses it; plain constructor injection is fine and cheaper for a small app. Do not introduce a DI framework to satisfy a pattern.

## Behaviour changes that break apps when `targetSdk` rises

- **Edge-to-edge.** "Edge-to-edge is enforced on Android 15 (API level 35) and higher once your app targets SDK 35", and "If your app is not already edge-to-edge, portions of your app may be obscured and you must handle insets" (https://developer.android.com/develop/ui/views/layout/edge-to-edge). There is no opt-out documented for targeting SDK 35+. In Compose this means calling `enableEdgeToEdge()` in the activity and consuming `WindowInsets` (`Scaffold` handles the common cases; content inside a custom container does not get it for free). Symptom of getting it wrong: a button under the gesture bar, or a top app bar behind the status bar.
- **Foreground service types.** "Beginning with Android 14 (API level 34), you must declare an appropriate service type for each foreground service. That means you must declare the service type in your app manifest, and also request the appropriate foreground service permission for that type (in addition to requesting the `FOREGROUND_SERVICE` permission)." Fourteen types are defined — camera, connected device, data sync, health, location, media playback, media processing, media projection, microphone, phone call, remote messaging, short service, special use, system exempted — each with its own `FOREGROUND_SERVICE_*` permission. And it reaches the store listing: "If your app targets Android 14 or higher, you'll need to declare your app's foreground service types in the Play Console's app content page (**Policy > App content**)" (https://developer.android.com/develop/background-work/services/fgs/service-types). A sync feature that "just runs in the background" is a manifest change, a permission, *and* a Play Console declaration — plan it as three, not one. `ai-patterns/offline-sync.md`'s queue lands here on Android.

## Recomposition performance

- **Measure first.** Compose compiler metrics (`reportsDestination`) give the restartable/skippable ratio per composable; Layout Inspector shows live recomposition counts. `rules/render-discipline.md` requires a before/after number on every fix in this class — "feels smoother" is not evidence.
- **Strong skipping is on by default from Kotlin 2.0.20.** It "changes the compiler's behavior in two ways: Composables with unstable parameters become skippable [and] Lambdas with unstable captures are remembered" (https://developer.android.com/develop/ui/compose/performance/stability/strongskipping). Consequence for review: on Kotlin ≥ 2.0.20 the old advice to hand-wrap every lambda in `remember` and chase `@Stable` annotations is largely obsolete, and doing it anyway is over-memoization — itself a finding. On older Kotlin it was opt-in via `composeCompiler { enableStrongSkippingMode = true }`. Check the Kotlin version before prescribing either.
- `LazyColumn` / `LazyRow` / `LazyVerticalGrid` for unbounded lists, always with a stable `key` in `items(...)`. Without a key, an insert re-composes and loses scroll/animation identity for everything after it.
- `derivedStateOf` for state computed from other state that changes more often than the result does — the canonical case is `scrollState.firstVisibleItemIndex > 0`.
- Defer reads: pass a lambda (`{ state.value }`) rather than the value where the read can happen at layout or draw time instead of composition.
- **Baseline Profiles** are the highest-leverage startup lever and Google publishes the figure: they "improve code execution speed by about 30% from the first launch by avoiding interpretation and just-in-time (JIT) compilation steps for included code paths" (https://developer.android.com/topic/performance/baselineprofiles/overview). Generate them with the Macrobenchmark library and the Baseline Profile Gradle plugin. That 30% is Google's measured claim for their scenario, not a promise for your app — measure yours.

## Shrinking, and the stack traces you get back

- R8 "shortens the names of classes, fields, and methods (for example, `com.example.MyActivity` could become `a.b.a`)" (https://developer.android.com/studio/build/shrink-code). Release crash reports are unreadable without the mapping file, so uploading it is part of shipping, not an optional extra (`rules/mobile-principles.md`).
- **The DSL for enabling it changed.** On AGP 9.3 and higher the documented form is an `optimization { enable = true }` block inside the build type; the legacy DSL is `isMinifyEnabled` / `isShrinkResources` (Kotlin) or `minifyEnabled` / `shrinkResources` (Groovy) (same page). Read the AGP version before emitting either — this is exactly the class of drift where a confidently-written build file silently does nothing.

## Accessibility

Android publishes its numbers, so use them (all from https://developer.android.com/guide/topics/ui/accessibility/apps):

- Touch targets: "For touch interfaces, we recommend that each interactive UI element have a focusable area, or *touch target size*, of at least 48dpx48dp."
- Contrast: "If the text is smaller than 18sp, or if the text is bold and smaller than 14sp, use foreground and background colors that result in a color contrast ratio of at least 4.5:1. For all other text, set the color contrast ratio to at least 3:1."
- Labels describe purpose, not appearance, and must not restate the element type: "Use the `Role` semantics property (like `Role.Button` or `Role.Switch`) to expose a UI element's type", and "if selecting a button causes a 'submit' action to occur in your app, make the button's description `Submit`, not `Submit button`."
- In Compose these are `contentDescription`, the `semantics { }` modifier with `Role`, and merging/clearing semantics for composed controls. Test with TalkBack and with Switch Access, on a device.

## Testing

- Compose UI tests use `createComposeRule()` for composables with no activity dependency and `createAndroidComposeRule<YourActivity>()` "when you need access to an activity", with `androidTestImplementation("androidx.compose.ui:ui-test-junit4")` and `debugImplementation("androidx.compose.ui:ui-test-manifest")` (https://developer.android.com/develop/ui/compose/testing).
- **"The semantics tree is what tests query"** (same page). That is why accessibility work and testability are the same work here: a composable with no semantics is both unusable with TalkBack and unaddressable by `onNodeWithText(...)` / `assertIsDisplayed()`.
- Macrobenchmark for startup and scroll-frame measurement; it is also the generator for Baseline Profiles.

## What Play measures after you ship

Android vitals thresholds are published, enforced by ranking, and they are the only stability numbers in this pack that are platform facts rather than project budgets:

| Metric | Overall bad-behaviour threshold | Per-device-model | Source |
|---|---|---|---|
| User-perceived crash rate | "At least 1.09% of daily active users" | 8% | https://developer.android.com/topic/performance/vitals/crash |
| User-perceived ANR rate | "At least 0.47% of daily active users" | 8% | https://developer.android.com/topic/performance/vitals/anr |

The stated consequence is discoverability, not rejection: exceeding the overall threshold means the app "is likely to be less discoverable on all devices"; exceeding it per-device means "less discoverable on those devices, and a warning may be shown on your store listing".

ANR timeouts to design against (same ANR page): input dispatch **5 seconds**; broadcast of intent from a foreground activity **5 seconds**; `Service.startForeground` not called within **5 seconds**. Vitals also flags startup as excessive at "Cold startup takes 5 seconds or longer. Warm startup takes 2 seconds or longer. Hot startup takes 1.5 seconds or longer." (https://developer.android.com/topic/performance/vitals/launch-time). Treat those as the ceiling Play notices, and set a tighter project budget from a measured baseline — do not confuse the two.

**One release-schedule dependency to raise on day one, before any code:** with a **personal** (non-organization) Play developer account, production access requires a closed test "with a minimum of 12 testers who have been opted in continuously for at least 14 days", and "Testers who opt in, test for fewer than 14 days, and then opt out do not count toward the requirement" (https://support.google.com/googleplay/android-developer/answer/14151465). That is a two-week calendar dependency, not an engineering task.

## Agent tooling

Google ships an official CLI aimed at agents. "Android CLI is a command-line interface that enables you to more easily and efficiently build for Android using any tool of your choice ... It also gives your agents access to Android skills and the specialized Android Knowledge Base" (https://developer.android.com/tools/agents/android-cli). Useful surface when it is installed (`command -v android`; `android init` installs the `android-cli` skill): `android describe` (project structure), `android docs search` / `android docs fetch` (version-matched docs), `android emulator create|start|stop`, `android run`, `android screen capture`, `android screen resolve` (visual label to screen coordinates), `android layout` (UI layout as JSON), `android studio render-compose-preview`, `android skills add|find|list`. `android layout` + `android screen capture` are what turn "I changed the UI" into a verifiable claim. Where a fetched doc and this file disagree, the doc is version-matched and this file is a snapshot — the doc wins, and say so in the diff.

## Anti-patterns

- Emitting `NavHost` without checking whether the project uses Navigation 2 or Navigation 3.
- `SharedPreferences` for new key-value storage, and `EncryptedSharedPreferences` for secrets (deprecated — see Core choices).
- `LazyColumn` items with no stable `key`.
- Blanket `remember` / `@Stable` annotations added without a metrics report — over-memoization, and mostly obsolete under strong skipping.
- Reading a frequently-changing state value at composition time when the read could be deferred to layout or draw.
- Raising `targetSdk` without handling insets, or adding a foreground service without a type, permission, and Play Console declaration.
- Business logic in a composable instead of the ViewModel (`rules/render-discipline.md`, detector 8).
- Shipping a release build without uploading the R8 mapping file.
- Quoting the 1.09% / 0.47% vitals numbers as *rejection* thresholds. They affect discoverability; Play does not reject on them.

## Cross-references

- `rules/render-discipline.md` — the Jetpack Compose fingerprint column; compiler metrics are its evidence format.
- `rules/mobile-principles.md` — permissions, crash reporting, secret handling (see the Keystore correction above).
- `ai-patterns/native-storage.md` — DataStore vs Room vs Keystore, per data class.
- `ai-patterns/offline-sync.md` — the sync queue that becomes a typed foreground service or WorkManager job here.
- `agents/app-store-reviewer.md` — the Play-side submission audit that consumes the targetSdk, vitals and foreground-service items above.
