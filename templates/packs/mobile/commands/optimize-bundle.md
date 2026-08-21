---
description: Mobile bundle-size + cold-start optimization. Audits app size, identifies the heaviest modules, proposes targeted reductions. Reports before/after.
---

# /optimize-bundle

Reduces app size + cold-start time.

**The size numbers that are real, and the ones that are yours.** Both stores publish hard limits and one publishes a warning threshold; everything else in this command is a budget the project sets and measures, not a platform fact.

| Published limit | Value | Source |
|---|---|---|
| Play — non-blocking mobile-data dialog | "If your app is above 200MB in size, users on a mobile data connection will see a non-blocking dialog when installing the app from Google Play informing them of the app's large size" | [Play app size limits](https://support.google.com/googleplay/android-developer/answer/9859372) |
| Play — base module cap | 500MB | same |
| Play — legacy APK cap | "a maximum APK size of 100MB" for apps still publishing APKs rather than app bundles | same |
| Apple — total uncompressed app | 4 GB (iOS 9.0 and later) | [Apple maximum build file sizes](https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes) |
| Apple — all `__TEXT` sections | 80 MB | same |
| Android vitals — "excessive" startup | "Cold startup takes 5 seconds or longer. Warm startup takes 2 seconds or longer. Hot startup takes 1.5 seconds or longer." | [Android vitals launch time](https://developer.android.com/topic/performance/vitals/launch-time) |

The vitals row is a *floor of badness*, not a target — a project's own cold-start budget should be well under it, and it is the project's to set and to measure. This command states no other size or timing threshold as fact.

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

## Use when

- App size is trending toward a published limit or the project's own budget (see the table above).
- Startup on a named mid-tier device has regressed against the project's measured baseline, or is approaching the Android vitals "excessive" line.
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
- Cold-start budget — **the project's own**, stated as `<budget> on <named device>`. If the project has none, the first job of this run is to measure a baseline and propose one, not to assume a number.
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

**Every cell in the template below is a placeholder to be filled from a measurement.** This command deliberately ships no worked example with numbers in it: a report template containing plausible sizes is the single easiest thing for an agent to reproduce as if it were a finding. If a cell cannot be filled from the build artifact, write `not measured` — never a representative value.

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
| `<module>` | `<measured>` | `<measured>` | `<replacement, and why the call sites are compatible>` |

### Heaviest native deps
| Pod / Gradle | Size | Notes |
|---|---|---|
| `<dep>` | `<measured>` | `<which sub-modules are actually used>` |

### Heaviest assets
| Asset | Size | Notes |
|---|---|---|
| `<asset>` | `<measured>` | `<re-encode / replace / drop, with the measured post-size>` |

### Recommendations (ordered by impact / effort)

| # | Recommendation | Measured saving | Effort |
|---|---|---|---|
| 1 | `<recommendation>` | `<before → after, from a real build>` | `<estimate>` |

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
- **Confirm the release-mode toolchain flags** (JS engine, code shrinker, release build mode) before optimizing anything else — a disabled shrinker is the cheapest finding in this command, and it must be reported as a *measured* before/after like every other one, not as a rule of thumb.

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
- `release-pipeline` — binary size is checked against the store limits above before submission; symbol upload happens in the same build job.
- `device-harness` (skill) — installs the release build on a named device so a startup measurement means something.
- `ota-updates` — the OTA payload IS this JS bundle; a smaller bundle is a faster, safer over-the-air update. Size wins here directly shrink the OTA blast-radius/download.
- `ai/runtime/bundle-audits/` — historic audits for trend analysis.

## Sources

- Google Play, [app size limits](https://support.google.com/googleplay/android-developer/answer/9859372) — 200MB mobile-data dialog, 500MB base module, 100MB legacy APK.
- Apple, [maximum build file sizes](https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes) — 4 GB uncompressed, 80 MB `__TEXT`.
- Android, [vitals launch time](https://developer.android.com/topic/performance/vitals/launch-time) — the "excessive" cold / warm / hot thresholds.
