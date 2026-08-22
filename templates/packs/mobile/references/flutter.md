# Flutter reference (channel-scoped — read the installed SDK, this file is not pinned)

> **Framework**: Flutter + Dart. **Run `flutter --version` before writing anything here.** Read 2026-08-20, the stable channel is **3.47.1** with **Dart 3.13.1** (https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json → `current_release.stable`); the release-notes index lists 3.47 / 3.44 / 3.41 as the recent stables (https://docs.flutter.dev/release/release-notes). That moves roughly quarterly — read it, do not recall it.
> **Official docs**: https://docs.flutter.dev/ • API: https://api.flutter.dev/ • release notes: https://docs.flutter.dev/release/release-notes
> **Version-specific gotchas**: **Impeller** — "Impeller is available and enabled by default on Android API 29+" and is the only supported renderer on iOS; on older Android devices, or devices without Vulkan, it falls back to the legacy OpenGL renderer with no action required (https://docs.flutter.dev/perf/impeller, read 2026-08-20). Advice describing Impeller as "opt-in on Android" predates that default. Material 3 is the default theme; null safety is mandatory; `WidgetsBinding.instance.platformDispatcher` replaces the deprecated `window`.
> **Check the API before you emit it.** Every symbol has a page at `https://api.flutter.dev/flutter/<library>/<symbol>.html` carrying its deprecation state and its actual documented behaviour. This is the platform where "I remember what this does" is most often wrong about the *mechanism* rather than the name — see `debugPrint` under Anti-patterns.
> **Substitution markers**: Replace `<name>` with the project's actual feature names.

## Structure

```
lib/
├── main.dart
├── app/                   # App root, router, theme
├── features/
│   └── <name>/
│       ├── data/          # repositories, data sources
│       ├── domain/        # entities, use cases
│       ├── presentation/  # screens, widgets, state
│       └── <name>.dart
├── shared/
│   ├── widgets/
│   ├── theme/
│   └── lib/
└── core/                  # platform, DI, error handling
```

## Core choices (opinionated)

- **State management**: Riverpod 2 (preferred). Bloc for event-sourced / complex flows.
- **Navigation**: `go_router` with typed routes.
- **Networking**: `dio` + interceptors. `freezed` for DTOs + `json_serializable`.
- **Forms**: `reactive_forms` or `flutter_form_builder`.
- **Storage**: `shared_preferences` (KV), `drift` (SQLite with Dart types), `flutter_secure_storage` (tokens).
- **Dependency injection**: Riverpod providers (preferred) or `get_it`.
- **Async**: `Future` / `Stream` + Riverpod's `AsyncValue` for state.

## Rules

- Separate data / domain / presentation folders per feature.
- Widgets small + composable. Extract once a widget's build method exceeds ~50 lines.
- Use `const` constructors wherever possible — huge perf win via compile-time widgets.
- Prefer `StatelessWidget` + Riverpod `Consumer` to `StatefulWidget` with `setState`.
- Null safety: no `!` (bang) unless you've proven it's not null.

## Theming

- `ThemeData` with light + dark variants.
- `ColorScheme.fromSeed()` for Material 3 schemes.
- Custom typography via `TextTheme`.
- CSS-style tokens via `ThemeExtension` for custom values (spacing scale, radii, etc.).

## i18n

- `flutter_localizations` + ARB files per locale.
- `gen_l10n` generates typed Dart classes.
- RTL: Flutter handles it automatically via `Directionality`. Test in `dir: rtl`.

## Performance

- `const` everywhere. Widgets rebuild in sub-tree only.
- `ListView.builder` for long lists (lazy).
- Cache images: `cached_network_image`.
- Profile with DevTools — the frame chart shows build + layout + paint times; "Track widget rebuilds" is the evidence format for a render-discipline finding.

## Platform channels

- When Dart can't do it, call native via `MethodChannel`; prefer **Pigeon** for a typed channel — a bare `MethodChannel` returns `dynamic` and has no compile-time guard.
- Keep payloads serializable (no complex objects).
- Native code in `ios/Runner` (Swift) + `android/app/src/main` (Kotlin).
- **Handlers run on the platform main thread.** "This method is invoked on the main thread", and moving a handler off it is a documented, channel-side change: pass a background task queue from `makeBackgroundTaskQueue()` when constructing the channel — "In order for a channel's platform side handler to execute on a background thread on an Android app, you must use the Task Queue API" (https://docs.flutter.dev/platform-integration/platform-channels, read 2026-08-20). **Dart isolates do not help here**: they move work off the *Dart* thread, not off the platform main thread, so an ANR caused by a heavy `MethodChannel` handler survives an isolate.

## Testing

- Widget tests for UI (`testWidgets`).
- Unit tests for providers / domain (`test`).
- Integration tests (`integration_test`) for end-to-end.
- Golden tests (pixel snapshots) for widget appearance regressions.

## Biometrics

`local_auth` (3.0.2, 2026-07-09 — https://pub.dev/packages/local_auth) wraps `LAContext.evaluatePolicy` / `BiometricPrompt` and is therefore the **UI gate** only: a successful call does not make anything in `flutter_secure_storage` unreadable. Binding the secret to the key means reaching the platform's own access control — `SecAccessControl` on Apple, `setUserAuthenticationRequired` on Android — through the plugin's platform options or a `MethodChannel`. Which of the two the design needs is `agents/mobile-architect.md` § Biometric gates; the semantics are in `references/swiftui.md` and `references/jetpack-compose.md`, including the enrollment-change decision that neither plugin makes for you.

## Anti-patterns

- Monolithic StatefulWidget with 20 setState calls.
- Nested widget trees >5 levels without extraction.
- Building widgets inside `build()` without `const`.
- Using `BuildContext` across async gaps (classic Flutter footgun).
- Not disposing controllers / subscriptions.
- **Believing `debugPrint` is stripped in release.** It is not. Its documented property is throttling: `debugPrintThrottled` is "Implementation of `debugPrint` that throttles messages. This avoids dropping messages on platforms that rate-limit their logging (for example, Android)" (https://api.flutter.dev/flutter/foundation/debugPrintThrottled.html, read 2026-08-20). What actually removes a log from a release build is the **compile-time constant** `kDebugMode` — "Since this is a const value, it can be used to indicate to the compiler that a particular block of code will not be executed in debug mode, and hence can be removed" (https://api.flutter.dev/flutter/foundation/kDebugMode-constant.html) — or an `assert`, or a logger with a release-level filter. Swapping `print` for `debugPrint` and calling it done ships every one of those lines to production.

## Render-discipline fingerprints

`rules/render-discipline.md` names 8 shape-based detectors and their closure verbs; this is the Flutter signal for each. Cite the detector number + name in the finding, and quote the line you matched here.

| # | Detector | Flutter fingerprint |
|---|---|---|
| 1 | oversized-state-scope | `setState` in a `StatefulWidget` at screen root while only a leaf displays the value |
| 2 | side-effect-in-build | `fetch` / `Provider.of(listen:)` mutation / `Navigator.push` inside `build()` |
| 3 | missing-stable-subtree | missing `const` constructors (`prefer_const_constructors`) |
| 4 | unstable-list-item-props | closure built per item in `itemBuilder` capturing parent state |
| 5 | unvirtualized-list | `ListView(children: […])` / `Column` + `map` over unbounded data → `ListView.builder` |
| 6 | animation-rebuilds-subtree | `AnimationController` + `setState` per tick → `AnimatedBuilder` / `AnimatedWidget` with a scoped `child:` |
| 7 | store-overinvalidation | `ref.watch(provider)` for one field → `ref.watch(provider.select(…))`; `context.watch<T>()` for one getter |
| 8 | logic-in-view | parsing / error-mapping / business rules in `build()` instead of the controller / notifier / bloc |

**Enforcement.** `flutter_lints` with `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`, `avoid_unnecessary_containers`. Evidence format: DevTools "Track widget rebuilds" counts, before and after, on the hot screen.

## Cross-references

- `rules/render-discipline.md` — the 8 detectors these fingerprints close; this file carries the Flutter signal and its lint / profiler enforcement.
- `rules/mobile-principles.md` — secure storage, permissions, crash reporting, budgets.
- `ai-patterns/native-storage.md` — `flutter_secure_storage` vs `shared_preferences` vs `drift`, per data class.
- `ai-patterns/offline-sync.md` · `app-lifecycle.md` — the queue and the window it drains in.
- `agents/app-store-reviewer.md` — the submission audit; every dated store figure lives there, none here.
