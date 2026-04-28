# React Native reference (0.74+)

## Structure

```
src/
├── app/                   # App root, providers, navigation
├── features/
│   └── <name>/
│       ├── screens/       # route-level components
│       ├── components/
│       ├── hooks/
│       ├── services/      # API clients
│       ├── store/         # Zustand / Redux slice
│       └── types.ts
├── shared/
│   ├── components/
│   ├── lib/
│   └── theme/
├── navigation/
└── platform/              # iOS / Android native modules if any
```

## Core choices (opinionated)

- **New Architecture** — enable Fabric + TurboModules. Avoid legacy bridge issues.
- **Expo Modules / Expo SDK** — use even in bare workflow for common primitives (Image, SecureStore, Notifications).
- **Navigation** — React Navigation 7+.
- **State** — Zustand (or Redux Toolkit if team prefers).
- **Data fetching** — TanStack Query (caching + offline + retries).
- **Forms** — React Hook Form + Zod.
- **Styling** — StyleSheet + theme context, OR a styled-components equivalent (`@shopify/restyle`, `nativewind`).
- **Icons** — `@expo/vector-icons` or `react-native-svg` with custom.

## Key libraries

- `react-native-mmkv` — fast key-value (10x AsyncStorage).
- `react-native-keychain` / `expo-secure-store` — tokens.
- `react-native-reanimated` — 60fps animations on UI thread.
- `react-native-gesture-handler` — native-thread gestures.
- `@shopify/flash-list` — replacement for FlatList at scale.
- `react-native-fast-image` — better image caching.

## Rules

- NEVER `fetch()` from a component. Use a service + TanStack Query hook.
- Tokens / secrets → Keychain / SecureStore (NOT AsyncStorage).
- Heavy work off JS thread — use Reanimated worklets or native modules.
- Test on both iOS AND Android for every feature (they differ in subtle ways).
- Lists > 100 items = FlashList (not FlatList).
- Images: explicit width + height, use FastImage for remote URLs.

## Performance

- Profile with Flipper / Hermes sampling profiler.
- Enable Hermes engine (default on new RN projects).
- Avoid anonymous functions in render if they become props (memo invalidation).
- `useCallback` / `useMemo` carefully — unnecessary on cheap operations.

## Anti-patterns

- Class components (function components only).
- Legacy Bridge modules when a Turbo equivalent exists.
- AsyncStorage for sensitive data.
- `ScrollView` with many items (use FlatList / FlashList).
- Synchronous native calls in render.
- Ignoring the legacy → new arch migration when available.
