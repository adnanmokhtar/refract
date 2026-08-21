---
name: platform-conventions-audit
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
closure_verb: <one of the closed vocabulary below — OMIT THIS KEY ENTIRELY on a routed observation>
routed_to: <present INSTEAD of closure_verb on a routed observation: the rule, pack, or skill that owns the fix>
risk: low | medium | high
```

### The closure-verb vocabulary is closed

`/polish` registers exactly five mobile-extra verbs on top of the frontend set: **`apply-platform-spec` · `unify-platform-icon` · `apply-platform-typography` · `add-haptic-feedback` · `respect-safe-area`** (`commands/polish.md` § mobile). A detector that wants a sixth does not get one. It either reuses an existing verb — because the *act* is the same — or it emits `routed_to:` and **no verb at all**. Inventing a verb does not produce a richer finding; it produces a finding whose verb nothing downstream can execute.

Three detectors below are routed rather than closed here, and the reason is the scope line rather than bookkeeping. This skill owns **platform divergence** — the cases where iOS and Android genuinely disagree, which is a question the web has no analogue for. It does **not** own the usability and accessibility floor: that is the `ui-ux` pack's 16-axis catalog, co-run on every `mobile-*` `/polish` pass, and re-auditing it here under a near-identical name is the "seventeenth axis" failure, not extra coverage.

## The 10 detectors

### 1. ios-hig-drift

**Fingerprint** (any one):
- Touch targets below the project's declared iOS minimum (see detector 3 — this is evidence for a routed ui-ux finding, not an axis this skill closes).
- Navigation back chevron not on the leading edge.
- System fonts (San Francisco) replaced by custom font without justification.
- Tab bar items > 5 (HIG max).
- Modal presentation style violates HIG (e.g., full-screen modal where sheet would be canonical).
- iOS-specific affordances missing (swipe actions on rows, peek-and-pop, context menus).

**Detection**: per-component scan; cross-check against iOS HIG fingerprints declared in `_extracted-idioms.md § iOS conventions`.

**Closure verb**: `apply-platform-spec` (with `--platform=ios`).

### 2. material-spec-drift

**Fingerprint** (any one):
- Touch targets below Android's recommended 48dp×48dp (see detector 3 — routed, not closed here).
- Material 3 components replaced by custom equivalents without design system justification.
- FAB (Floating Action Button) misplaced (Material 3 puts it bottom-right or bottom-center).
- Bottom navigation has > 5 destinations (Material 3 max).
- Elevation tokens not from Material 3 scale (`elevation: 1 / 3 / 6 / 8 / 12` levels).
- Ripple state missing on tappable surfaces.

**Closure verb**: `apply-platform-spec` (with `--platform=android`).

### 3. touch-target-drift — ROUTED, no verb

**This axis belongs to `ui-ux`, not to this skill.** `ui-ux/rules/ui-principles.md` owns the `tap-target` axis with the verb `expand-tap-target`, and `/polish` co-runs the ui-ux floor on every `mobile-*` pass. This detector exists only to carry the *platform-specific minimum* as evidence into that finding — it never emits its own verb, and a run that emits `expand-touch-target` is emitting a verb nothing downstream recognises.

**Fingerprint**: any tappable element below the platform minimum. Commonly missed on icon-only buttons, row chevrons, and segmented controls.

Cited minimums, so the routed finding carries evidence rather than an assertion:

| Target | Minimum | Status |
|---|---|---|
| Android | "we recommend that each interactive UI element have a focusable area, or *touch target size*, of at least 48dp×48dp" | Primary-sourced: [Android accessibility](https://developer.android.com/guide/topics/ui/accessibility/apps) |
| Any pointer target | "The size of the target for pointer inputs is at least 24 by 24 CSS pixels", Level AA, with five exceptions | Primary-sourced: [WCAG 2.2 SC 2.5.8](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) |
| iOS | "Create controls that measure at least 44 points x 44 points so they can be accurately tapped with a finger" — published under a **Hit Targets** heading with a "44pt x 44pt minimum" graphic | Primary-sourced: [Apple design tips](https://developer.apple.com/design/tips/) (read 2026-08-21). Same figure `ui-ux/rules/ui-principles.md` encodes for the `tap-target` axis, and the same URL `agents/app-store-reviewer.md` § Sources and `rules/mobile-principles.md` [S3] cite. |

**Emits**: `routed_to: ui-ux/rules/ui-principles.md § tap-target (verb: expand-tap-target)`. **No `closure_verb:` key.**

### 4. platform-icon-drift

**Fingerprint**: the project's declared conventions call for per-platform icon sets (Cupertino on iOS, Material on Android) and a screen uses one set across both.

**This detector requires a declared convention.** A single cross-platform icon set is a legitimate, common, and often deliberate brand decision — not a spec violation. Neither platform's guidelines forbid it. So: if `_extracted-idioms.md § Mobile platforms` declares per-platform icons, drift from that declaration is a finding. If it declares a single set, a single set is **correct** and this detector emits nothing. If it declares nothing, emit a routed observation asking for the decision, not a verb.

**Detection**: scan icon imports; check whether per-platform branching exists; read the declared convention first.

**Closure verb**: `unify-platform-icon` — adds a per-platform icon resolution layer. **Only when a per-platform convention is declared**; otherwise `routed_to: /setup-project --refine (declare the icon convention)`.

### 5. platform-typography-drift

**Fingerprint**: the project's declared conventions call for platform system fonts and a screen ships a single custom font across both.

**Same qualification as detector 4.** Shipping one brand typeface on both platforms is a design decision, not a spec violation, and it is what most products with a design system actually do. The finding is *drift from the declared convention*, in either direction — a project that declared system fonts and ships a custom one, or a project that declared a brand typeface and has one screen falling back to the system default. Type **scale**, rhythm, and hierarchy are `ui-ux`'s axes and are not re-audited here.

**Closure verb**: `apply-platform-typography` — **only when a system-font convention is declared**; otherwise `routed_to: /setup-project --refine (declare the typography convention)`.

### 6. per-platform-surface-drift

**Fingerprint**: a screen renders identically across platforms when platform conventions diverge.

Examples:
- Date picker: iOS uses wheel picker; Android uses calendar grid.
- Action sheet: iOS uses bottom sheet with cancel; Android uses bottom sheet without cancel.
- Pull-to-refresh: iOS shows custom indicator above content; Android shows Material spinner.

**Closure verb**: `apply-platform-spec` (with `--platform=<target>`, scope=surface). *Not* `add-per-platform-surface` — that verb is not in `/polish`'s registered vocabulary, and a finding carrying it cannot be executed.

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
