---
name: bundle-analyze
description: One-shot mobile bundle-size + cold-start analysis, reporting per-module sizes and quick-win recommendations. Run before and after a dependency upgrade to see the size delta, during PR review when a new dep lands, and as a pre-release check. Report only — `/optimize-bundle` is what runs this plus the full audit and applies recommendations.
---

# Skill: bundle-analyze

## Premise

Real signals only. Every size number comes from the actual release-mode build artifact — `bundle.js` from Metro, `app.apk` from gradle, `.ipa` from Xcode archive. "Top 5 modules" cites the visualizer output (file + KB), not a hunch. Quick wins reference a real dependency in `package.json` / `pubspec.yaml` / `Podfile.lock` with the specific replacement named. Comparisons cite the baseline commit / tag explicitly.

## Halt conditions

- Refuse to report sizes from a dev / debug build — they include source maps and dev tools.
- Refuse to claim a saving without the size delta from a measured before/after.
- Halt if the visualizer / size-analyze command failed — fix the build first.
- Don't propose removing a dep without grepping its actual import sites.

A focused analysis tool. Smaller scope than `/optimize-bundle` (which is a full audit + recommendations) — this is a fast inventory.

## When to use

- Before / after a dependency upgrade — see size delta.
- Quick check during PR review when a new dep is added.
- Pre-release sanity check.

## Procedure

### 1. Detect bundler + runtime, then measure

**One toolchain table, shared with `/optimize-bundle` § Phase 3.** That command runs this skill; two divergent lists is how one of them goes stale. Edit both together, or edit neither.

| Stack | Size artifact | Command |
|---|---|---|
| React Native (Metro) | JS bundle map | `npx react-native-bundle-visualizer` · `npx metro-source-map-explorer ./bundle.js ./bundle.js.map` |
| React Native (webpack-based) | bundle stats | the analyzer your bundler ships — for **Re.Pack** that is the webpack/Rspack analyzer it wraps. (`bundle-buddy` is a different, older tool; confirm what the project actually uses before naming one in a report.) |
| Expo | build + dependency health | `npx expo-doctor` for version mismatches; EAS build output for the shipped artifact |
| Flutter | per-arch size breakdown | `flutter build apk --analyze-size --target-platform=android-arm64` (and the iOS equivalent) |
| Android | APK / AAB contents | `./gradlew :app:bundleRelease`, then Android Studio → Build → Analyze APK |
| iOS | **App Thinning Size Report** | Archive → Distribute → App Thinning Size Report. This is the per-device download and install size. `xcrun altool` uploads and validates a build; it produces **no** size analysis — do not cite it as a measurement. |
| Assets | per-file re-encode | `ImageOptim` / `pngquant` / `cwebp` for images; `ffprobe` for video |

### 2. Categorize

- **Application code** — src/.
- **Direct dependencies** — top 10 by size.
- **Transitive dependencies** — common bloat sources (moment.js → moment-timezone full DB, lodash full).
- **Polyfills** — core-js, regenerator-runtime if present.
- **Assets** — images, fonts, video, JSON.
- **Native modules** — iOS: Pod sizes. Android: AAR sizes.
- **Locales** — Android language resources, iOS .lproj folders.

### 3. Identify quick wins

| Pattern | Quick win |
|---|---|
| moment.js / moment-timezone | Replace with date-fns or Intl.DateTimeFormat |
| lodash (full) | `lodash-es` + selective imports |
| Icon library (full set) | Tree-shake or `@expo/vector-icons` selective |
| PNG assets | Re-encode (WebP / AVIF) at the lowest quality that survives review. **State no expected percentage** — the saving depends entirely on the source image, and the only number that belongs in the report is the measured before → after for these files. |
| Splash video | Replace with Lottie animation |
| Multiple state libs | Consolidate (don't ship Redux + Zustand + MobX) |
| Hermes off (RN) | Enable in release config |
| ProGuard / R8 off (Android) | Enable in release config |
| Dead screens | Remove; verify with grep/ts-prune |

### 4. Report

```
## Bundle analysis — <platform> — <date>

App size: <MB>
JS/Dart bundle: <MB>
Native code: <MB>
Assets: <MB>

Top 5 heaviest modules:
1. <name> — <KB>
2. ...

Quick wins:
- <recommendation> — est saving <KB>

Compared to <previous-version-or-baseline>:
- size delta: <+/-KB>
- cold-start delta: <+/-ms, measured by `@device-performance-auditor` on a named device — omit the row rather than estimating it from the size delta>
```

## Inputs

- Platform (iOS / Android).
- Comparison baseline (previous release tag or "main" branch's last build).
- Scope (full app / per-module / per-feature).

## Outputs

- `ai/runtime/bundle-analysis-<date>.md` — the report.
- (Optional) `ai/runtime/bundle-trend.csv` — historical row appended for trending.

## Failure modes

- Analyzed the dev bundle (with source maps + dev server) instead of release build → numbers wrong.
- Missed transitive native deps (Pods within Pods).
- Assets folder size inflated by intermediate build artifacts (clean before measuring).
- Compared bundle sizes across different RN / Flutter versions — minor version bumps can change baseline; note this.

## Related

- `/optimize-bundle` — runs this skill plus full audit + recommendations.
- `@app-store-reviewer` — **does not treat size as an engineering problem**; its own anti-trigger routes that here. What it owns is the published *store* limit and its consequence (Play's non-blocking mobile-data dialog above 200MB, the hard base-module and Apple caps). Ask it "will this upload be accepted"; ask this skill "why is it this big".
- `@device-performance-auditor` — owns **cold start** as a measured cost. Hand it the build and the named device; do not derive a startup verdict from a size number here.
- `/optimize-bundle` § the published-limits table — the only place in this pack that states a store size figure.
