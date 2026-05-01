# Mobile pack — stack assumption

This pack assumes one of: **React Native + TypeScript**, **Flutter + Dart**, **Swift / SwiftUI**, **Kotlin / Jetpack Compose**.

Inline examples lean **React Native + TypeScript** for illustration. Substitute per stack:

| RN + TS (illustrated) | Flutter | SwiftUI | Compose | Substitution source |
|---|---|---|---|---|
| `useState` / `useEffect` | `setState` / `initState` | `@State` / `.onAppear` | `remember` / `LaunchedEffect` | reactive state + lifecycle |
| FlatList | ListView.builder | List | LazyColumn | virtualised list |
| AsyncStorage | shared_preferences | UserDefaults | DataStore | local persistence |
| react-navigation | go_router / Navigator | NavigationStack | NavHost | navigation |

The project's `_extracted-idioms.md` declares the actual stack and primitives.
