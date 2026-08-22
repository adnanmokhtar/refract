# React Native reference (version-scoped — read the installed version, this file is not pinned)

> **Framework**: React Native + React + TypeScript. **Read `react-native` from `package.json` before writing anything here.** Checked 2026-08-11, the latest release is **0.87.0** (https://api.github.com/repos/facebook/react-native/releases/latest); the Expo pairing on that date was SDK 57 ↔ RN 0.86 (`references/expo.md`). Neither is stable across releases — read them, do not recall them.
> **Official docs**: https://reactnative.dev/docs/getting-started • https://reactnative.dev/blog (release notes) • Expo: https://docs.expo.dev/
> **Check a component before you emit it.** The docs site is versioned: `https://reactnative.dev/docs/<version>/<component>` renders the page as it stood at that release, deprecation banner included. Use it the way `references/swiftui.md` uses Apple's JSON twin — the failure mode here is identical, code that compiles and is several releases stale. Worked example, read 2026-08-21: `https://reactnative.dev/docs/0.81/safeareaview` carries "Deprecated. Use [react-native-safe-area-context] instead." — so `SafeAreaView` from `react-native` is a deprecated import, not the good signal it reads as.
> **Substitution markers**: Replace `<name>` with the project's actual feature/screen names.

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

Check each against `package.json` and the installed RN version before adding one; the ecosystem moves faster than this file.

- `react-native-mmkv` — memory-mapped key-value, materially faster than the async bridge-backed store for read-heavy work. **State no speed multiple**: the commonly quoted figure is a vendor benchmark, not a property of your app (`ai-patterns/native-storage.md` § User preferences).
- `react-native-keychain` / `expo-secure-store` — tokens and other secrets. Never `AsyncStorage`.
- `react-native-reanimated` — animations driven off the JS thread (detector 6).
- `react-native-gesture-handler` — native-thread gestures.
- `@shopify/flash-list` — recycling list. **There is no published item-count threshold** at which it becomes correct: the trigger is unbounded data plus a measured drop, not a number. Detector 5 is the finding; measure before and after.
- `react-native-safe-area-context` — the supported safe-area primitive. `SafeAreaView` from `react-native` core is deprecated (see the header).
- Image caching: use the project's existing choice. `expo-image` is the maintained cross-platform option; `react-native-fast-image` has published nothing since **8.6.3 on 2022-10-31** (https://registry.npmjs.org/react-native-fast-image) — do not introduce it into a new project.

## Rules

- NEVER `fetch()` from a component. Use a service + TanStack Query hook.
- Tokens / secrets → Keychain / SecureStore (NOT AsyncStorage).
- Heavy work off JS thread — use Reanimated worklets or native modules.
- Test on both iOS AND Android for every feature (they differ in subtle ways).
- Unbounded lists use a recycling primitive (`FlatList` / `FlashList`), not `ScrollView` + `.map()` — detector 5. Give it a stable `keyExtractor`.
- Images: explicit width + height so layout does not thrash on load; a caching image component for remote URLs.

## Performance

- Profile with the **Hermes sampling profiler** and React DevTools Profiler. **Not Flipper** — it was decoupled from React Native core and removed from the app template (https://github.com/react-native-community/discussions-and-proposals/blob/main/proposals/0641-decoupling-flipper-from-react-native-core.md); advice naming it is several years stale.
- Confirm Hermes is on in the release config before measuring anything — a JSC release build has a different startup profile entirely.
- Avoid anonymous functions in render when they become props (memo invalidation) — detector 4.
- `useCallback` / `useMemo` where the profiler shows waste. Blanket memoization is itself a finding (`rules/render-discipline.md` § Must not).

## Biometrics

The decision — does biometry gate the UI or the key — is `agents/mobile-architect.md` § Biometric gates; the semantics you are binding to are the platform's, in `references/swiftui.md` (`SecAccessControl`, `LAError.biometryLockout`) and `references/jetpack-compose.md` (`setUserAuthenticationRequired`, `setInvalidatedByBiometricEnrollment`). Read one of those before choosing a package, because the package names decide which mechanism you get:

- `expo-local-authentication` (57.0.2, 2026-07-22 — https://registry.npmjs.org/expo-local-authentication) and equivalent wrappers expose `evaluatePolicy` only. That is the **UI gate**. It proves a person authenticated; it does not make a stored token unreadable.
- `react-native-keychain` (10.0.0, 2025-03-23 — https://registry.npmjs.org/react-native-keychain) exposes the access-control constants, which is what binds the secret to the key. Check which constant the call site passes: the enrollment-change decision is that argument, and defaulting it is how a project ships "survive re-enrollment" without deciding to.

Verify a version and its access-control surface against the registry before writing either — this is the class of claim that goes stale silently.

## Anti-patterns

- Class components (function components only).
- Legacy Bridge modules when a Turbo equivalent exists.
- AsyncStorage for sensitive data.
- `ScrollView` with many items (use FlatList / FlashList).
- Synchronous native calls in render.
- `SafeAreaView` imported from `react-native` (deprecated) instead of `react-native-safe-area-context`.

## Render-discipline fingerprints

`rules/render-discipline.md` names 8 shape-based detectors and their closure verbs; this is the React Native signal for each. Cite the detector number + name in the finding, and quote the line you matched here.

| # | Detector | React Native fingerprint |
|---|---|---|
| 1 | oversized-state-scope | `useState` in the screen component passed N levels down; a context value rebuilt per render |
| 2 | side-effect-in-build | fetch or `setState` in the render body, outside `useEffect` |
| 3 | missing-stable-subtree | missing `React.memo` / `useMemo` on a pure hot child |
| 4 | unstable-list-item-props | inline `renderItem={() => …}` and inline style literals in `FlatList` |
| 5 | unvirtualized-list | `ScrollView` + `.map()` over unbounded data → `FlatList` / `SectionList` / `FlashList` (stable `keyExtractor`) |
| 6 | animation-rebuilds-subtree | JS-driven animation per frame → `useNativeDriver: true` or a Reanimated worklet |
| 7 | store-overinvalidation | `useSelector(s => s)` or a whole-context consumer where a narrow selector exists |
| 8 | logic-in-view | parsing / error-mapping / business rules in the component instead of the hook or service layer |

**Enforcement.** `eslint-plugin-react-hooks` (`exhaustive-deps`) and `eslint-plugin-react-perf` (`jsx-no-new-object-as-prop`, `jsx-no-new-function-as-prop`). Evidence format: React DevTools Profiler flamegraph / commit counts, before and after, on the hot list.

## Cross-references

- `rules/render-discipline.md` — the 8 detectors these fingerprints close; this file carries the RN signal and its lint / profiler enforcement.
- `rules/mobile-principles.md` — Keychain, permissions, crash reporting, budgets.
- `references/expo.md` — read it *in addition* to this file on any Expo project: config plugins, EAS build/submit/update, and the CNG-vs-ejected fork.
- `ai-patterns/native-storage.md` — which primitive holds which data class, and why no speed multiple is stated here.
- `ai-patterns/offline-sync.md` · `app-lifecycle.md` — the queue and the window it drains in.
- `agents/app-store-reviewer.md` — the submission audit; every dated store figure lives there, none here.
