---
description: Mobile bundle-size + cold-start optimization. Audits app size, identifies the heaviest modules, proposes targeted reductions. Reports before/after.
---

# /optimize-bundle

Reduces app size + cold-start time. Mobile users abandon downloads above ~150MB; cold-start over 2s erodes engagement. Use when:

## The Premise (read this first, internalize, do not deviate)

**The bottleneck is real, and the pattern repeats.** A bundle does not bloat from one freak module — it bloats from a **class of mistake** that lands many times: heavy import where a light one suffices, full-library import where named imports tree-shake, polyfill bundled for a target that no longer needs it, asset shipped at 3x when 2x is the device ceiling, native dep duplicated across two transitive deps. Find the class, you find every instance.

**The agent's job is exactly this:**
1. Measure first — actual bundle stats from `bundle-visualizer` / `--analyze-size` / APK analyzer. Never optimize on hunch.
2. Identify the **pattern class** of the heaviest finding (e.g., "moment-timezone-style heavy date lib", "lodash-style full-library import", "PNG-at-3x asset").
3. **Scan for siblings** of the same pattern across the codebase. One `moment-timezone` import almost always means three more. One unsplit `lodash` import means twenty.
4. Report all instances of the pattern, not just the first one found. Fixing one and missing four is a wasted release cycle.

**The agent does NOT:**
- Recommend an optimization without naming the measurement that proved it heavy. "I think X is big" is not a finding.
- Stop after finding the first instance of a pattern. The repeat scan is mandatory.
- Recommend a swap (date-fns for moment) without confirming the call sites are compatible. A blind swap breaks runtime.
- Drop a feature (language pack, screen, polyfill) without checking actual usage telemetry / call-site references.
- Trust release builds without re-measuring. Hermes / R8 / Flutter `--release` flags change everything; an audit on a debug bundle is fiction.

**Mechanical halt — similar-pattern scan (mandatory before recommendations):**

Before emitting any recommendation in Phase 4, for each heaviest-N finding the agent MUST:
- Name the pattern class (1 line).
- Run a repo-wide scan for the same pattern (e.g., `rg "from 'moment'" `, `rg "import _ from 'lodash'"`, `find assets -name "*@3x.png"`).
- Report **count of instances**, not just the heaviest one.
- If count > 1 — recommendation is "fix all N", not "fix the heaviest one."

A recommendation that addresses 1 of N pattern instances is rejected as partial.

- App size has crossed 100MB and trending up.
- First Contentful Paint on mid-tier device > 1.5s.
- Bundle CI budget exceeded.
- Pre-release optimization pass.

## Phases applied

1, 2, 3, 4, 6 (Understand → Organize → Retrieve → Generate → Validate). Skips Update / Improve since this is an audit + recommend, not a knowledge-base change.

## When to use / NOT to use

- USE: bundle size or cold start regressed.
- USE: pre-store-submission optimization.
- NOT: a single screen is slow → use `/profile-perf` (if available) or `@performance-optimizer` agent.
- NOT: server-side latency → backend pack.

## Phase 1 — Understand

Confirm:
- Platform: iOS / Android / both.
- Current bundle size (from last release or `xcodebuild -showBuildSettings` / Android `analyze APK`).
- Cold-start budget (e.g., < 1.5s on Pixel 4a / iPhone 12).
- Any features explicitly excluded from optimization (e.g., legal SDK).

## Phase 2 — Organize

Three audits in parallel:
1. **JavaScript / Dart bundle**: which modules are heaviest? Are they tree-shakable?
2. **Native dependencies**: which CocoaPods / Gradle deps are largest? Any duplicates?
3. **Assets**: which images / fonts / videos are unbundled-able?

## Phase 3 — Retrieve

- `package.json` / `Podfile.lock` / `build.gradle` / `pubspec.lock` — current dep graph.
- `metro.config.js` / `babel.config.js` / `vite.config` — bundler config.
- `assets/` directory — image + font + video inventory.
- Recent CI bundle-size reports (if any).

Tools:
- React Native: `npx react-native-bundle-visualizer`, `metro-source-map-explorer`.
- Expo: `npx expo-doctor`, `npx eas build --output-bundle-stats`.
- Flutter: `flutter build apk --analyze-size`, `flutter build ios --analyze-size`.
- Native iOS: Xcode → Show Build Folder → inspect `.app` size; `App Thinning Size Report`.
- Native Android: `./gradlew app:bundleRelease` then Android Studio → Build → Analyze APK.
- Asset audit: `ImageOptim` / `pngquant` / `cwebp` / `ffprobe` for video.

## Phase 4 — Generate (the audit report + recommendations)

Output structure:

```
## Bundle audit — <platform> — <date>

### Current state
- App size:            <MB>
- JS/Dart bundle:      <MB>
- Native code:         <MB>
- Assets:              <MB>
- Cold start (P50):    <ms>
- Cold start (P99):    <ms>

### Heaviest modules (JS/Dart)
| Module | Size | % of bundle | Notes |
|---|---|---|---|
| moment-timezone | 1.2 MB | 18% | Replace with date-fns or Intl |
| lodash (full) | 600 KB | 9% | Switch to lodash-es + selective imports |
| react-native-svg-icons (full set) | 400 KB | 6% | Tree-shake; only ~30 icons used |

### Heaviest native deps
| Pod / Gradle | Size | Notes |
|---|---|---|
| Firebase (core + analytics + crashlytics + perf + …) | 22 MB | Drop unused modules |
| Some-large-SDK | 8 MB | Vendor confirms 80% is unused features → request slim build |

### Heaviest assets
| Asset | Size | Notes |
|---|---|---|
| onboarding-1.png (3x) | 1.8 MB | Re-encode as WebP @ 80% quality → ~280 KB |
| splash-video.mp4 | 4.2 MB | Replace with Lottie animation (~200 KB) |
| Roboto.ttf (full) | 800 KB | Use only weights 400 + 600 |

### Recommendations (ordered by impact / effort)

| # | Recommendation | Estimated saving | Effort |
|---|---|---|---|
| 1 | Replace moment-timezone with Intl.DateTimeFormat | -1.2 MB JS | 4h |
| 2 | Audit & remove unused Firebase modules | -8 MB native | 1h |
| 3 | Convert onboarding PNGs to WebP | -1.5 MB assets | 30m |
| 4 | Replace splash video with Lottie | -4 MB assets | 2h |
| 5 | Tree-shake icon library | -350 KB JS | 1h |
| 6 | Hermes (RN) — confirm enabled in release | -200 KB JS, -150ms cold start | 15m |
| 7 | Code splitting — defer settings + admin screens | -800 KB initial JS | 6h |
| 8 | Drop subset of unused languages | -1.2 MB native | 30m |

### Cold-start recommendations
- App init currently doing N async tasks on launch; defer all but auth.
- Image preloading on launch — defer until after first interactive frame.
- Native modules eagerly registered — lazy-register the rare ones.

### Estimated end state (after applying all)
- App size:           <MB target>
- Cold start (P50):   <ms target>
- Effort:             <total hours>

### Out-of-scope
- <e.g., proprietary SDK we contractually can't replace>
```

## Phase 6 — Validate (after applying)

For each applied recommendation:
- Re-build release bundle.
- Re-measure: bundle size, cold start (P50 / P99).
- Functional regression check: features that depended on the removed/replaced module still work.
- A/B comparison: pre vs post cold-start traces.

If any regression detected → revert that change OR isolate the cause; do not bundle-revert the whole batch.

## Output format

```
## /optimize-bundle — audit complete

Audit report: ai/runtime/bundle-audit-<date>.md

Current vs target:
  size:        <MB now> → <MB target>
  cold start:  <ms now> → <ms target>

Recommendations: <count>
Quick wins (≤1h, large impact): <count>
Total estimated saving: <MB>

Next: pick recommendations to apply (often start with quick wins #2 + #3 + #6).
```

## Hard rules

- **Don't ship un-measured optimizations.** "I think this will help" is not a justification — re-measure.
- **One change per PR for >100KB optimizations.** Easier to revert if regression.
- **Don't drop user-visible features** (languages, screens) without explicit user direction.
- **Confirm Hermes / R8 / Flutter --release flags** before optimizing — common 30%+ improvement is just turning on the right flag.

## Failure modes

- Replaced moment-timezone with date-fns but missed a moment.tz call → date wrong in some flow.
- Tree-shaken icons broke when a runtime-loaded icon name doesn't exist in the new subset.
- Removed Firebase Performance — analytics dashboards now miss data.
- Lottie animation size on Android differs from iOS due to different rendering.
- Cold-start measurement included background-fetch tail → false positive improvement.

## Related

- `@mobile-architect` — sometimes recommends architectural changes (split app, deferred modules) that this command surfaces.
- `@performance-optimizer` (general) — for non-mobile-specific perf work.
- `@app-store-reviewer` — pre-release. Bundle size is a release-blocker if it exceeds the platform's recommended size.
- `ota-updates` — the OTA payload IS this JS bundle; a smaller bundle is a faster, safer over-the-air update. Size wins here directly shrink the OTA blast-radius/download.
- `ai/runtime/bundle-audits/` — historic audits for trend analysis.
