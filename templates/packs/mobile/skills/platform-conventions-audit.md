---
description: Platform conventions audit for mobile apps. Detects iOS HIG / Material 3 / per-platform spec drift across screens. Covers touch target sizing, navigation patterns, system-font usage, platform-specific affordances, icon vocabulary (Cupertino vs Material), typography scale (San Francisco vs Roboto), elevation/shadow conventions, ripple states, haptic feedback coverage, safe-area handling. Emits findings with closure verbs that apply per-platform conformance. Used by /polish on mobile-* stacks. Co-runs with frontend skills (a11y-quick-check, design-token-audit, motion-audit) — frontend findings + platform findings combined.
kind: skill
pack: mobile
---

# Skill: platform-conventions-audit

## Purpose

Detect deviations from each target platform's design specification (iOS Human Interface Guidelines, Android Material 3, etc.) across the project's mobile screens. The skill operates on the live UI tree (per-platform builds) + the project's design conventions.

## When to use

- Dispatched by `/polish` on `mobile-*` stacks. Co-runs with reused frontend skills (`a11y-quick-check`, `design-iterate`, `design-token-audit`, `motion-audit`).
- Dispatched standalone for platform-specific audits.
- NOT for cross-platform business logic (use `/optimize` or `/align`).

## Inputs (precise contract)

| Input | Source | Required |
|---|---|---|
| Codebase root | Orchestrator | YES |
| `PROJECT_KIND` (must include `mobile`) | `_extracted-codebase.md § Gold standards` | YES |
| Target platforms | `_extracted-idioms.md § Mobile platforms` (e.g., `[ios, android]`) | YES |
| Per-platform build configs | Auto-detected (`ios/`, `android/`, `app.json`, `Info.plist`, `AndroidManifest.xml`) | YES |
| Screen registry | Auto-detected from navigation config | YES |
| Scope filter (optional) | Caller flag | NO (default: all screens) |

## Outputs

```yaml
class: platform-conventions
subclass: <one of: ios-hig-drift | material-spec-drift |
                   touch-target-drift | platform-icon-drift |
                   platform-typography-drift | per-platform-surface-drift |
                   haptic-feedback-coverage | safe-area-handling |
                   elevation-drift | navigation-pattern-drift>
platform: ios | android | both
screen: <screen-name>
file: <component-path:line>
canonical: <what the platform's spec says>
divergence: <what this screen/element does differently>
closure_verb: <one of the verbs below>
risk: low | medium | high
```

## The 10 detectors

### 1. ios-hig-drift

**Fingerprint** (any one):
- Touch targets < 44 × 44 pt.
- Navigation back chevron not on the leading edge.
- System fonts (San Francisco) replaced by custom font without justification.
- Tab bar items > 5 (HIG max).
- Modal presentation style violates HIG (e.g., full-screen modal where sheet would be canonical).
- iOS-specific affordances missing (swipe actions on rows, peek-and-pop, context menus).

**Detection**: per-component scan; cross-check against iOS HIG fingerprints declared in `_extracted-idioms.md § iOS conventions`.

**Closure verb**: `apply-platform-spec` (with `--platform=ios`).

### 2. material-spec-drift

**Fingerprint** (any one):
- Touch targets < 48 × 48 dp.
- Material 3 components replaced by custom equivalents without design system justification.
- FAB (Floating Action Button) misplaced (Material 3 puts it bottom-right or bottom-center).
- Bottom navigation has > 5 destinations (Material 3 max).
- Elevation tokens not from Material 3 scale (`elevation: 1 / 3 / 6 / 8 / 12` levels).
- Ripple state missing on tappable surfaces.

**Closure verb**: `apply-platform-spec` (with `--platform=android`).

### 3. touch-target-drift

**Fingerprint**: any tappable element below the minimum (iOS: 44×44 pt; Android: 48×48 dp). Often missed on icon-only buttons, table row chevrons, segmented controls.

**Closure verb**: `expand-touch-target`.

### 4. platform-icon-drift

**Fingerprint**: project uses a single icon set (e.g., FontAwesome, Material Icons) across BOTH iOS and Android instead of per-platform sets (Cupertino on iOS, Material on Android).

**Detection**: scan icon imports; check whether per-platform branching exists.

**Closure verb**: `unify-platform-icon` — adds per-platform icon resolution layer.

### 5. platform-typography-drift

**Fingerprint**: typography uses a single font across platforms instead of system defaults (San Francisco on iOS, Roboto on Android).

**Closure verb**: `apply-platform-typography`.

### 6. per-platform-surface-drift

**Fingerprint**: a screen renders identically across platforms when platform conventions diverge.

Examples:
- Date picker: iOS uses wheel picker; Android uses calendar grid.
- Action sheet: iOS uses bottom sheet with cancel; Android uses bottom sheet without cancel.
- Pull-to-refresh: iOS shows custom indicator above content; Android shows Material spinner.

**Closure verb**: `add-per-platform-surface`.

### 7. haptic-feedback-coverage

**Fingerprint**: tappable confirmations / errors / state changes don't trigger haptic feedback where the project's convention requires it.

Common gaps:
- Successful submission with no haptic.
- Error state with no haptic.
- Long-press context menu with no haptic.
- Pull-to-refresh release with no haptic.

**Closure verb**: `add-haptic-feedback`.

### 8. safe-area-handling

**Fingerprint**: content extends into the safe-area regions (notch / Dynamic Island on iOS; navigation gestures area on Android).

**Detection**: scan layout components; check for `SafeAreaView` (iOS / RN) or `WindowInsets` handling (Android).

**Closure verb**: `respect-safe-area`.

### 9. elevation-drift

**Fingerprint**: elevation/shadow values not from the platform's scale.
- iOS: blurred shadows with platform-specific opacity.
- Android: Material 3 elevation levels (0, 1, 3, 6, 8, 12 dp).

**Closure verb**: `apply-platform-spec` (with `--platform=<target>`, scope=elevation).

### 10. navigation-pattern-drift

**Fingerprint**: navigation pattern doesn't match the platform's expected idiom.
- iOS: tab bar at bottom; back chevron at top-leading.
- Android: bottom nav OR navigation drawer; up arrow at top-leading; system back gesture supported.

**Closure verb**: `apply-platform-spec` (scope=navigation).

## Procedure

1. **Pre-flight**:
   - `PROJECT_KIND` includes `mobile-*`. Halt otherwise.
   - Per-platform builds exist (iOS / Android folders OR Expo / RN configuration).
   - `_extracted-idioms.md § Mobile platforms` exists with canonical conventions.
2. **Build screen registry** — walk navigation config; emit one row per screen.
3. **For each platform** (iOS / Android):
   - Build the platform-specific UI tree (introspect via component traversal).
   - Run the 10 detectors against the tree.
4. **Cross-platform aggregation** — group findings by screen; mark each as `ios-only`, `android-only`, or `both`.
5. **Co-run frontend skills** (a11y-quick-check, design-token-audit, motion-audit) — frontend findings and platform findings combine into the same artifact.
6. **Write `ai/polish/_platform-decisions.md`** with all findings.

## Hard rules

- **Per-platform fix per finding** — a finding marked `both` must produce per-platform code paths (or a cross-platform abstraction that handles both internally).
- **No "iOS-styled Android"** — adapting iOS aesthetic to Android (e.g., bottom sheets that look like UIAlertController) is a violation. Each platform looks like itself.
- **Behaviour preserved** — visual + interaction adjustments don't alter business logic.
- **Per-platform build smoke** — every closure verb's commit must pass per-platform smoke tests (iOS simulator + Android emulator).
- **System defaults preferred** — overriding system fonts / icons / patterns requires explicit ADR.

## Failure modes

- **Mobile conventions missing** → halt; "/setup-project --refine to declare mobile platform conventions first".
- **Per-platform build missing** → halt; project must build for at least one of the declared platforms.
- **Conflict with frontend findings** (rare) → frontend wins for cross-platform concerns; platform wins for platform-specific. Surface for user when ambiguous.

## References

- `_extracted-idioms.md § Mobile platforms`.
- `align-discipline.md` — closed-vocabulary discipline.
- `polish` command — dispatches this skill on mobile stacks (alongside reused frontend skills).
- `ui-principles.md` (ui-ux pack) — frontend a11y / contrast / focus rules co-applied.
- iOS HIG: https://developer.apple.com/design/human-interface-guidelines/ (canonical reference for iOS detectors).
- Android Material 3: https://m3.material.io/ (canonical reference for Android detectors).
