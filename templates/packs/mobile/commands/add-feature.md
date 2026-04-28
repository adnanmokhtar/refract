---
description: End-to-end mobile feature — multi-screen flow + state + offline + deep-link + native bridge if needed + tests + docs. Mobile counterpart to backend's /add-feature.
---

# /add-feature

Mobile feature orchestration. Use when a feature touches more than one screen OR introduces native capabilities (camera, notifications, biometric).

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## Invariants

- **Online + offline behavior decided up front** — not bolted on.
- **iOS + Android parity decided up front** — feature works equivalently on both unless explicitly platform-only.
- **Deep-link entry registered.**
- **Push notification entry registered** if the feature should be reachable via notification.
- **A11y from the start.**
- **i18n from the start.**
- **No native bridge code without an ADR** — bridges are leaky abstractions.
- **Battery + data usage considered** — long-running listeners, large image uploads, polling.

## When to use / NOT to use

- USE: feature spanning ≥2 screens.
- USE: feature requiring local persistence (Realm, SQLite, AsyncStorage, MMKV, secure keychain).
- USE: feature with offline-first or sync semantics.
- USE: feature using a native capability (camera, location, biometric, push, NFC).
- NOT: a single new screen → `/add-screen`.
- NOT: a UI tweak → just edit + `/review-changes`.

## Phase 1 — Understand

Ask one consolidated question if any unknown:
- What user-facing capability?
- Which user roles?
- Online-only / offline-tolerant / offline-first?
- iOS only / Android only / both?
- Native capabilities? (camera/location/notifications/biometric/contacts/HealthKit/...)
- Tablet / foldable variants?
- Reachable via deep link / push notification / NFC tap?
- Persistence scope: per-device, per-user, per-tenant, encrypted?

If user provides Figma + spec, treat as authoritative.

## Phase 2 — Organize

Use `mobile-architect` to produce design:

```
## Feature: <name>

### Stack changes
- New stack? <yes/no>
- New tab? <yes/no>
- Modal layer? <yes/no>

### Screens (new + modified)
| Name | New/Modified | Path | Stack |
|---|---|---|---|

### Components (new)
| Name | Path | Used by |
|---|---|---|

### State
| Concern | Where | Persistence |
|---|---|---|

### Server interactions
| Action | Endpoint | Online behavior | Offline behavior |
|---|---|---|---|
| List items | GET /api/items | TanStack Query, stale-while-revalidate | last cached payload from MMKV |
| Submit | POST /api/items | mutation | queue → background sync |

### Native capabilities
| Capability | iOS API | Android API | Permission prompt timing |
|---|---|---|---|

### Deep links
- app://feature → opens FeatureLandingScreen
- universal://example.com/feature/:id → opens FeatureDetailScreen

### Push notifications
- Topic: feature-updates → handler routes to FeatureDetailScreen
- Foreground display: in-app banner / no-op
- Background: navigation on tap

### i18n keys (new)
<table>

### A11y notes
- Touch targets ≥ 44x44.
- Screen-reader rotor entries logical.
- Color contrast ≥ 4.5:1 (text), 3:1 (UI).
- Reduce motion respected (`UIAccessibility.isReduceMotionEnabled` / `Settings.System.ANIMATOR_DURATION_SCALE`).

### Tests
| Layer | File |
|---|---|
| unit | <path> |
| component | <path> |
| integration | <path> |
| e2e (Detox / Maestro / XCUITest / Espresso) | <path> |

### Performance budget
- Cold start delta: ≤ +50ms
- Time-to-interactive on the main feature screen: ≤ 800ms on mid-tier device
- Bundle delta: ≤ +200KB JS
- RAM delta: ≤ +25MB

### Open questions
<flag for user>
```

## Phase 3 — Retrieve

Read in order:
1. `CLAUDE.md` — stack (RN / Flutter / native iOS / native Android).
2. `ai/architecture.md` — module boundaries.
3. `ai/business-domain.md` — what feature does in business terms.
4. `ai/patterns/navigation.md`, `data-fetching.md`, `offline-sync.md`, `native-storage.md`, `deep-linking.md`.
5. `.claude/rules/mobile-principles.md`.
6. Sibling feature module — mirror its shape.
7. Native config files: `Info.plist` / `AndroidManifest.xml` / `Podfile` / `build.gradle` — for permissions + entitlements + dependencies.
8. Linking config (React Navigation `linking` prop, Expo Router app.json scheme, Flutter `MaterialApp.routes` / GoRouter).
9. Push-notification setup (FCM / APNS / Expo Push).

## Phase 4 — Generate

1. **Pre-flight injection** in every new file (read pattern + sibling).
2. **Use the project's actual primitives** — UI lib, nav lib, state lib, persistence lib.
3. **One state pattern per concern** — server data via TanStack Query, app state via Zustand/Redux, secrets via Keychain/Keystore. Never mix.
4. **Loading + error + empty + content states** on every data-driven screen.
5. **Offline plumbing**:
   - GET requests cached + replayed from cache when offline (TanStack Query persister or RTK Query).
   - Mutations queued (Background Tasks / WorkManager / `react-native-background-task`) and replayed.
   - User feedback: "saved locally — will sync when online."
6. **Permission prompts in context** (right before the action that needs them, not at app launch).
7. **Native bridge code** (if any): typed at JS↔native boundary; error path when native returns failure.
8. **Deep links** registered in linking config + native project.
9. **Push handlers** routed to the new screen.
10. **Locale strings** keyed.

After generation, dispatch:
- `@mobile-architect` — design review.
- `@accessibility-auditor` — a11y.
- `@i18n-auditor` — locale completeness.
- `@app-store-reviewer` (if shipping a store update) — privacy disclosures, permission rationales, screenshots.
- `@security-auditor` if biometric/keychain/secrets touched.
- `@ux-reviewer` — flow + content + edge cases.

## Phase 5 — Update

- `ai/modules.md` — feature module entry.
- `ai/patterns/<new>.md` — only if new pattern.
- `ai/decisions/<NNNN>-*.md` — for architectural choices (offline strategy, state placement, native bridge introduction).
- `ai/status.md` § Recent Changes.
- `app-store-metadata/` — privacy disclosure + permission rationale strings (if relevant).

## Phase 6 — Validate

- Lint + type-check + tests pass on iOS + Android.
- Cold-start regression check (compare baseline).
- Bundle-size delta acceptable.
- A11y check pass on both platforms.
- Locale completeness.
- Deep-link manual test (open from cold + warm states).
- Push-notification manual test (cold tap, warm tap, foreground display).
- Offline mode manual test (toggle airplane mode mid-flow).
- Permission denial handling — if user denies camera, the flow has a graceful path.

## Phase 7 — Improve

- New offline strategy → propose pattern.
- New native bridge → ADR proposed.
- Recurring permission-denial UX → propose pattern.
- Battery/data drain detected → flag for follow-up.

## Output format

```
## /add-feature — <feature-name>

Status: SHIPPED | NEEDS REVIEW | BLOCKED

Platforms verified: iOS <v>, Android <v>
Files written: <count>
Tests: unit/comp/integration/e2e all passing
Bundle delta: +<KB>
Cold-start delta: +<ms>
A11y score: <number>
i18n: <count> new keys per locale, no missing

Native:
  Permissions added:        <list>
  Native modules touched:   <list, or 'none'>
  Deep links registered:    <list>
  Push handlers added:      <list>

Knowledge updates:
  - ai/modules.md       ✓
  - ADR <NNNN>          (if applicable)
  - new pattern         (if extracted)

Open follow-ups:
  - <flagged>
```

## Hard rules

- **Online AND offline behavior** is part of design — not retrofit.
- **iOS + Android parity** unless explicitly platform-only.
- **Permission rationale strings** required for every requested permission (Info.plist Usage Description, Android `<uses-permission>` rationale).
- **No biometric without secure-enclave / hardware-backed keystore.** Soft-stored auth = not auth.
- **No location collection** outside an active task. Background location only with explicit user opt-in + visible UI.
- **No PII in logs.**

## Failure modes

- Mutation succeeded online but offline queue is silently dropped on app reinstall — no recovery.
- Deep link works in dev but native config not updated → fails after store release.
- Permissions requested at app launch (before user understands why) → high denial rate.
- Background task quota exhausted → sync stalls; no user feedback.
- Push handler doesn't navigate when app is in background-killed state on Android (different lifecycle).
- iPhone notch / Android cutout / foldable hinge ignored → UI clipped.
- Battery drain from misconfigured location accuracy / always-on listener.

## Related

- `/add-screen` — single-screen variant.
- `/optimize-bundle` — when bundle delta exceeds budget.
- `@mobile-architect` — design.
- `@app-store-reviewer` — pre-release review.
- `ai/patterns/offline-sync.md`, `native-storage.md`, `deep-linking.md`.
- Backend's `/add-feature` — counterpart for backend; usually paired in cross-stack mobile features.
