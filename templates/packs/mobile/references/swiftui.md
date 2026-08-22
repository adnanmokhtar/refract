# SwiftUI reference (native iOS — deployment-target-scoped, not pinned)

> **Framework**: SwiftUI + Swift on Apple platforms. Xcode / SDK, deployment target and Swift language mode are three separate dials and every rule below depends on which one you mean. Read all three from the project before writing code: the Xcode version, `IPHONEOS_DEPLOYMENT_TARGET` (or `Package.swift` platforms), and `SWIFT_VERSION` / `swiftLanguageMode`.
> **Official docs**: https://developer.apple.com/documentation/swiftui/ • Observation: https://developer.apple.com/documentation/observation • App Review: https://developer.apple.com/app-store/review/guidelines/
> **Version-specific gotchas**: **Uploads are toolchain-gated.** Since **April 28, 2026**, "Apps uploaded to App Store Connect must be built with Xcode 26 or later using an SDK for iOS 26, iPadOS 26, tvOS 26, visionOS 26, or watchOS 26" (https://developer.apple.com/news/upcoming-requirements/). Building against a newer SDK also surfaces newer deprecations. Two that a model emits by reflex, each read from its JSON twin on 2026-08-21 and quoted verbatim: `NavigationView` is **deprecated at 27.0 on every platform** (iOS, iPadOS, Mac Catalyst, macOS, tvOS, visionOS, watchOS) — "Use NavigationStack and NavigationSplitView instead. For more information, see Migrating to New Navigation Types." (https://developer.apple.com/tutorials/data/documentation/swiftui/navigationview.json); and `foregroundColor(_:)` is **deprecated at 27.0 on every platform** — "Use `foregroundStyle(_:)` instead." (https://developer.apple.com/tutorials/data/documentation/swiftui/view/foregroundcolor(_:).json). Emitting either is code that compiles with a warning today and is a migration debt on arrival.
> **Substitution markers**: replace `<Name>` with the project's actual feature / view names.

## Check the API before you emit it — the mechanism, not a memory test

This is the platform where a model most reliably writes code that *compiles* and is two or three API generations stale. Apple publishes machine-readable deprecation data, so the check is cheap and there is no excuse for guessing:

- Any symbol page has a JSON twin at `https://developer.apple.com/tutorials/data/documentation/<framework>/<symbol>.json`, carrying `deprecated`, the per-platform version, and the replacement text. Example, fetched 2026-08-21: `.../swiftui/view/onchange(of:perform:).json` returns "Use `onChange(of:initial:_:)` ... instead", deprecated iOS 17.0. Use the JSON twin, not the human page: the documentation site is client-rendered, so a fetcher gets an empty body from the canonical URL. Every Apple deprecation quoted in this file was verified through the JSON twin of the URL cited beside it.
- **The twin covers framework symbols, not design guidance.** `/tutorials/data/documentation/<framework>/<symbol>.json` resolves; the same transform on a Human Interface Guidelines page does not — `.../documentation/design/human-interface-guidelines/tab-bars.json` returned **404** on 2026-08-22 while `.../documentation/localauthentication/lacontext.json` returned 200. So HIG figures cannot be verified this way, and a failed fetch is not licence to write the number from memory: say no citable figure was retrieved, per `rules/mobile-principles.md`.
- The compiler is the second check: build with warnings visible and treat a deprecation warning as a finding, not noise.
- **Do not infer deprecation from a house style guide.** Two examples that a popular agent-facing Swift ruleset gets wrong, both checked against Apple's own metadata on 2026-08-21: `@StateObject` is **not deprecated** (introduced iOS 14.0, `"deprecated": false` on every platform — https://developer.apple.com/documentation/swiftui/stateobject), and `ObservableObject` is **not deprecated** (Combine, iOS 13.0+ — https://developer.apple.com/documentation/combine/observableobject). Prefer Observation in new code for the reasons below; do not tell a project its working code is deprecated when Apple has not said so.

## Structure

```
<App>/
├── <Name>App.swift            # @main entry, root scene
├── Features/
│   └── <Name>/
│       ├── Views/             # SwiftUI views, one per file
│       ├── Model/             # @Observable model types
│       └── <Name>Service.swift
├── Shared/
│   ├── DesignSystem/          # Color/Font/Spacing extensions, ViewModifiers
│   └── Extensions/
├── Resources/
│   ├── Assets.xcassets
│   └── Localizable.xcstrings
└── PrivacyInfo.xcprivacy      # required — see "Privacy manifest"
```

## State and model data

- **Observation is the current path.** The Observation framework is available from **iOS 17.0 / macOS 14.0 / watchOS 10.0 / visionOS 1.0** (https://developer.apple.com/documentation/observation). "To declare a type as observable, attach the `@Observable` macro to the type declaration. This macro declares and implements conformance to the `Observable` protocol to the type at compile time." Its stated benefit is scoping — observers are notified of "specific or general state changes" rather than every publish.
- With Observation, the property wrapper for a stored reference-type model is `@State`, not `@StateObject`: use `State` "if you need to store a reference type that conforms to the `Observable()` protocol" (https://developer.apple.com/documentation/swiftui/stateobject). Mixing `@Observable` with `@StateObject` is the classic half-migration and it silently stops updates.
- **If the deployment target is below iOS 17, Observation is unavailable** — `ObservableObject` + `@Published` + `@StateObject` / `@ObservedObject` is then the correct and only choice. Read the deployment target before choosing; this is not a taste question.
- `@State` is private to the view; `@Binding` passes write access down; `@Environment` carries app-wide values. Never make `@State` `var` public API of a view.
- Model types own business logic. A view's `body` is a description, not a place to parse, map errors, or decide policy — see detector 8 in `rules/render-discipline.md`.

## Concurrency — decide the mode, then write to it

Swift's concurrency rules are a per-module *setting*, and code written for the wrong setting either fails to build or silently keeps data races. Read it first (all flags verbatim from https://github.com/swiftlang/swift-migration-guide, `Guide.docc/EnableDataRaceSafety.md`, read 2026-08-21):

| What | Xcode build setting | xcconfig / SwiftPM |
|---|---|---|
| Swift 6 language mode | "Swift Language Version" = "6" | `SWIFT_VERSION = 6;` • `swiftLanguageMode(.v6)` or `swift-tools-version: 6.0` |
| Complete checking as warnings | "Strict Concurrency Checking" = "Complete" | `SWIFT_STRICT_CONCURRENCY = complete;` • `.enableUpcomingFeature("StrictConcurrency")` (Swift 6.0+ tools) |

"By default, Swift 6 enables full data race safety checking" (same source). Migration order that works: turn on complete checking as *warnings* in Swift 5 mode, clear them, then flip the language mode — flipping first converts an unknown number of warnings into build errors at once.

Also read `-default-isolation`: SE-0466 "introduces a new compiler setting for inferring `@MainActor` isolation by default within the module to mitigate false-positive data-race safety errors in sequential code"; "The only valid arguments to `-default-isolation` are `MainActor` and `nonisolated`", implemented in **Swift 6.2** (https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md). Under `MainActor` default isolation, sprinkling `@MainActor` by hand is redundant; under `nonisolated`, omitting it on UI-touching types is a bug. Same code, opposite verdicts — so check the setting.

- `async`/`await` throughout. Start view-scoped async work in `.task { }`, which cancels on disappear, rather than `.onAppear` + a detached `Task`.
- No `DispatchQueue.main.async` in new code — express main-actor work as `@MainActor` isolation.

## Views

- Extract subviews into new `View` structs, not computed properties: a struct gives SwiftUI an identity it can diff and skip; a computed property is re-evaluated with the parent's `body`.
- `List` / `LazyVStack` / `LazyHStack` for unbounded data. A plain `VStack` + `ForEach` inside a `ScrollView` builds every row eagerly (`rules/render-discipline.md`, detector 5).
- `ForEach` needs stable identity — `Identifiable` with a real id, never array index, for a collection that mutates.
- Prefer semantic modifiers to hard-coded values: `foregroundStyle` (not the 27.0-deprecated `foregroundColor`, cited above), `.font(.body)` over fixed point sizes so Dynamic Type works.
- **`onChange` signature changed in iOS 17** and the change is behavioural, not cosmetic. Apple: "The trailing closure in each case takes either zero or two input parameters, compared to this method which takes one. Be aware that the replacements have slightly different behavior. This modifier's closure captures values that represent the state before the change. The new modifiers capture values that correspond to the new state." (https://developer.apple.com/documentation/swiftui/view/onchange(of:perform:)). Porting the old closure body unchanged inverts which value you are reading.

## Accessibility

- `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityValue`; `.accessibilityElement(children: .combine)` for a composed control; `.accessibilityHidden(true)` for pure decoration. Test with VoiceOver on device, not only the inspector.
- Dynamic Type: support it by using text styles, and verify at the largest accessibility sizes — layout that only survives the default size is untested, not accessible.
- **Touch targets: 44 × 44 points.** Apple states it directly — "Create controls that measure at least 44 points x 44 points so they can be accurately tapped with a finger" (https://developer.apple.com/design/tips/, read 2026-08-21). Note that a `Button` whose *label* is small still needs the tappable area enlarged — pad the control, do not rely on the glyph. The cross-platform floors, for a project that must satisfy both: Android publishes 48dp × 48dp (`references/jetpack-compose.md`), and WCAG 2.2 SC 2.5.8 (Level AA) requires "at least 24 by 24 CSS pixels" with five named exceptions — Spacing, Equivalent, Inline, User Agent Control, Essential (https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html). Design to the largest applicable figure and the question stops recurring.

## Background execution

**Apple publishes no fixed number of background seconds, and any code that assumes one is wrong.** `UIApplication.backgroundTimeRemaining` is "The maximum amount of time remaining for the app to run in the background"; "The value is valid only after the app enters the background and has started at least one task using `beginBackgroundTask(expirationHandler:)` in the foreground"; and "System conditions may end background execution earlier, either by calling the expiration handler, or by terminating the app." (https://developer.apple.com/documentation/uikit/uiapplication/backgroundtimeremaining).

So: wrap background work in `beginBackgroundTask(expirationHandler:)`, **always implement the expiration handler** to checkpoint and end the task, and read the remaining time rather than budgeting against a constant. For work that must survive suspension — sync, refresh, long processing — schedule it with `BGTaskScheduler` and treat execution time as system-granted, never guaranteed. `ai-patterns/offline-sync.md`'s queue must be resumable for exactly this reason.

## Privacy manifest — required, and it is a file in the app

- The manifest "is a property list that records ... The types of data collected by your app or third-party SDK" and "The required reasons APIs your app or third-party SDK uses"; "By default, the file is named `PrivacyInfo.xcprivacy`; this is the required file name for bundled privacy manifests" (https://developer.apple.com/documentation/bundleresources/privacy-manifest-files). Top-level keys: `NSPrivacyTracking`, `NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes`, `NSPrivacyAccessedAPITypes`.
- Why the required-reason list exists, verbatim: "Some APIs that your app uses to deliver its core functionality — in code you write or included in a third-party SDK — have the potential of being misused to access device signals to try to identify the device or user, also known as fingerprinting. Regardless of whether a user gives your app permission to track, fingerprinting is not allowed." (https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api). The categories and their permitted reasons are defined per dictionary key on that page — read them there rather than reproducing a list that rots.
- Third-party SDKs carry the obligation with them: "You must include the privacy manifest for any SDK listed below when you submit new apps in App Store Connect that include those SDKs, or when you submit an app update that adds one of the listed SDKs as part of the update. Signatures are also required in these cases where the listed SDKs are used as binary dependencies. Any version of a listed SDK, as well as any SDKs that repackage those on the list, are included in the requirement." (https://developer.apple.com/support/third-party-SDK-requirements/, read 2026-08-21). The list is not Swift-only — **Flutter, Capacitor, Cordova, `connectivity_plus`, `device_info_plus`, `flutter_local_notifications`, `image_picker_ios` and `UnityFramework` are all on it**, so this section applies to every iOS build in this pack, not just native ones. Audit dependencies, not only your own code.
- Purpose strings in `Info.plist` are a separate obligation from the manifest, and they are reviewed: guideline 5.1.1(ii) — "Ensure your purpose strings clearly and completely describe your use of the data" — and 5.1.1(iii) — "Apps should only request access to data relevant to the core functionality of the app and should only collect and use data that is required to accomplish the relevant task. Where possible, use the out-of-process picker or a share sheet rather than requesting full access to protected resources like Photos or Contacts." (https://developer.apple.com/app-store/review/guidelines/, read 2026-08-21). A purpose string that names the API ("needs photo access") rather than the user-facing reason is the version that gets rejected.

## Crash reporting and symbolication

An unsymbolicated crash is an unfixable crash. Set **Debug Information Format** to **DWARF with dSYM File** "for all your build types", and expect a "Missing dSYM" alert in the Firebase console when an upload fails (https://firebase.google.com/docs/crashlytics/get-deobfuscated-reports). Wire this before the first TestFlight build, not after the first crash — `rules/mobile-principles.md` requires it pre-beta.

## Testing and beta distribution

- Unit-test model types and services; they are plain Swift and need no host app. Use the Swift Testing macros (`@Test`, `#expect`) or XCTest as the project already does — do not mix styles in one target without reason.
- XCUITest for critical journeys only; snapshot tests for design-system components.
- **TestFlight limits** (https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview): internal testing covers "up to 100 App Store Connect users with access to your content"; external "up to 10,000 people"; "You can test a build for up to 90 days." Plan for the review step — "When you add the first build of your app to a group, the build gets sent to App Review to make sure it follows the App Review Guidelines. A review is required only for the first build."
- **Binary size ceilings** (iOS 9.0 and later, https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes): maximum uncompressed app size **4 GB**; maximum executable **80 MB**, "For the total of all `__TEXT` sections in the binary". watchOS is 75 MB; tvOS and visionOS are 4 GB / 500 MB. These are hard upload limits, not performance budgets — a startup or download budget is a project decision and must be measured, not inherited from here.

## Anti-patterns

- `NavigationView` in new code — deprecated 27.0 on every platform; use `NavigationStack` / `NavigationSplitView` (https://developer.apple.com/tutorials/data/documentation/swiftui/navigationview.json).
- `foregroundColor(_:)` in new code — deprecated 27.0 on every platform; use `foregroundStyle(_:)` (https://developer.apple.com/tutorials/data/documentation/swiftui/view/foregroundcolor(_:).json).
- The one-parameter `onChange(of:perform:)` — deprecated iOS 17.0, and the replacement reads the *new* value where the old one read the previous.
- `DispatchQueue.main.async` as the way to reach the main thread; use main-actor isolation.
- Breaking a large `body` into computed properties instead of `View` structs.
- Network calls, mutations or navigation inside `body`; start them in `.task`.
- Assuming a fixed number of background seconds.
- Shipping without `PrivacyInfo.xcprivacy`, or with purpose strings that describe the API rather than the user-facing reason.
- Force-unwrapping (`!`) and `try!` outside tests and genuinely impossible states.

## Render-discipline fingerprints

`rules/render-discipline.md` names 8 shape-based detectors and their closure verbs; this is the SwiftUI signal for each. Cite the detector number + name in the finding, and quote the line you matched here.

| # | Detector | SwiftUI fingerprint |
|---|---|---|
| 1 | oversized-state-scope | `@State` / `@StateObject` on a container view feeding a single leaf |
| 2 | side-effect-in-build | a network call or mutation inside `body` |
| 3 | missing-stable-subtree | a non-`Equatable` model forcing `body` re-evaluation |
| 4 | unstable-list-item-props | a per-row closure capturing the whole parent |
| 5 | unvirtualized-list | `VStack` + `ForEach` over unbounded data inside `ScrollView` → `List` / `LazyVStack` |
| 6 | animation-rebuilds-subtree | timer-driven `@State` per frame instead of `withAnimation` / `TimelineView` |
| 7 | store-overinvalidation | observing a whole `ObservableObject` where one published field is read |
| 8 | logic-in-view | parsing / error-mapping / business rules in the view instead of the model / store |

**Enforcement.** `Self._printChanges()` on hot views during review; the Instruments "SwiftUI" template for frame-time evidence. Evidence format: body re-eval counts, before and after.

## Biometrics — LocalAuthentication and the keychain flag

`agents/mobile-architect.md` § Biometric gates decides *what* biometry protects; this is how each answer is written on Apple platforms. The two are different APIs, and reaching for the first when you needed the second is the standard error.

- **Gating the UI** is `LAContext.evaluatePolicy`. `LAPolicy.deviceOwnerAuthenticationWithBiometrics` is biometry only — evaluation "fails if Touch ID or Face ID is unavailable or not enrolled"; `LAPolicy.deviceOwnerAuthentication` is "User authentication with biometry, Apple Watch, or the device passcode" and falls back on its own. Read `LAContext.biometryType` before writing any prompt copy — it "is set only after you call the `canEvaluatePolicy` method", so a string naming Touch ID on a Face ID device is a sequencing bug, not a copy bug.
- **Gating the secret** is a `SecAccessControl` flag on the keychain item, evaluated by the Secure Enclave rather than by your code. This is the only one of the two that protects a token, a payment method, or health data.

The flag choice is the enrollment-change decision, and the two options are documented in one sentence each (verified 2026-08-22 through the JSON twins of https://developer.apple.com/documentation/security/secaccesscontrolcreateflags):

| Flag | Documented behaviour | What it means for the user |
|---|---|---|
| `.biometryCurrentSet` | "The item is invalidated if fingers are added or removed for Touch ID, or if the user re-enrolls for Face ID." | Enrolling a new finger or face logs them out. The secure default for auth tokens. |
| `.biometryAny` | "The item is still accessible by Touch ID if fingers are added or removed, or by Face ID if the user is re-enrolled." | Convenient — and a newly enrolled biometric opens the app. |

Design the lockout path, because the system takes biometry away without asking: both Touch ID and Face ID are "disabled system-wide after too many consecutive unsuccessful attempts, even when the attempts span multiple evaluation calls", after which "the system requires the user to enter the device passcode to reenable biometry". Your app sees `LAError.biometryLockout` — "Biometry is locked because there were too many failed attempts. A passcode is now required to unlock biometry." Apple publishes no attempt count; do not write one.

**The uninstall asymmetry is a real design input.** Apple documents no uninstall hook, and keychain items survive reinstall under the same bundle ID (https://docs.expo.dev/versions/latest/sdk/securestore/ states the behaviour most plainly, contrasting it with Android where the data "will not be preserved upon app uninstallation"). Consequence: a reinstalled app with biometric unlock can open the previous user's session. The remedy is app code — a first-launch flag in `UserDefaults`, which *is* cleared on uninstall, and clearing the keychain when it is absent.

## Cross-references

- `rules/render-discipline.md` — the SwiftUI fingerprint column (`Self._printChanges()`, Instruments "SwiftUI" template) is the enforcement arm of the Views section here.
- `rules/mobile-principles.md` — Keychain, permissions, crash reporting, store compliance.
- `ai-patterns/native-storage.md` — Keychain vs `UserDefaults` vs a database, per data class.
- `agents/mobile-architect.md` § Biometric gates — whether biometry gates the UI or the key, and the enrollment-change decision this file implements.
- `ai-patterns/offline-sync.md` — why the sync queue must be resumable under background termination.
- `agents/app-store-reviewer.md` — the submission audit that consumes the privacy-manifest and review-guideline items above.
