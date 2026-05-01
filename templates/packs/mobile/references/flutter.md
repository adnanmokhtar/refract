# Flutter reference (3.19+)

> **Framework**: Flutter 3.19+ / 3.22 / 3.24 • Dart 3.3+
> **Official docs**: https://docs.flutter.dev/
> **Version-specific gotchas**: Flutter 3.22 made Material 3 the default theme; 3.24 added `Mixin Sliver` widgets + improved Impeller (default on iOS, opt-in Android); `WidgetsBinding.instance.platformDispatcher` replaces `window` (deprecated); `flutter_lints` 3.x stricter; null safety mandatory.
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
- Profile with DevTools — frame chart shows build + layout + paint times.

## Platform channels

- When Dart can't do it, call native via `MethodChannel`.
- Keep payloads serializable (no complex objects).
- Native code in `ios/Runner` (Swift) + `android/app/src/main` (Kotlin).

## Testing

- Widget tests for UI (`testWidgets`).
- Unit tests for providers / domain (`test`).
- Integration tests (`integration_test`) for end-to-end.
- Golden tests (pixel snapshots) for widget appearance regressions.

## Anti-patterns

- Monolithic StatefulWidget with 20 setState calls.
- Nested widget trees >5 levels without extraction.
- Building widgets inside `build()` without `const`.
- Using `BuildContext` across async gaps (classic Flutter footgun).
- Not disposing controllers / subscriptions.
- Using `print` — use `debugPrint` (stripped in release) or a logger.
