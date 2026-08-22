# Mobile pack — stack assumption

This pack assumes one of: **React Native + TypeScript**, **Flutter + Dart**, **Swift / SwiftUI**, **Kotlin / Jetpack Compose**.

Inline examples lean **React Native + TypeScript** for illustration. Substitute per stack:

| RN + TS (illustrated) | Flutter | SwiftUI | Compose | Substitution source |
|---|---|---|---|---|
| `useState` / `useEffect` | `setState` / `initState` | `@State` / `.onAppear` | `remember` / `LaunchedEffect` | reactive state + lifecycle |
| FlatList | ListView.builder | List | LazyColumn | virtualised list |
| AsyncStorage | shared_preferences | UserDefaults | DataStore | local persistence |
| react-navigation | go_router / Navigator | NavigationStack | NavHost | navigation |

The project's `_extracted-idioms.md` declares the actual stack and primitives, and each stack has a
versioned reference that is the operative file for it: `references/react-native.md` ·
`references/flutter.md` · `references/swiftui.md` · `references/jetpack-compose.md`. **If
`package.json` declares `expo`, `references/expo.md` is operative and `react-native.md` is its base
layer** — reading only the second gets the native-directory rule backwards. Every framework-specific
API, version gate, lint rule and profiler in this pack lives in one of those five files, including
the § Render-discipline fingerprints that close `rules/render-discipline.md`'s 8 detectors.
