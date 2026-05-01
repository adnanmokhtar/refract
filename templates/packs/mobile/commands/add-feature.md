---
description: End-to-end mobile feature — multi-screen flow + state + offline + deep-link + native bridge if needed + tests + docs. Mobile counterpart to backend's /add-feature.
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses one stack as illustration; substitute your stack's primitives from `_extracted-idioms.md`.


# /add-feature

Mobile feature orchestration. Use when a feature touches more than one screen OR introduces native capabilities (camera, notifications, biometric).

## The Premise (read this first, internalize, do not deviate)

**Existing screens, native bridges, and offline patterns are the truth.** The app already ships. Sibling features in the same module already solved navigation, state placement, offline replay, permission timing, native config wiring, and locale coverage. Their shape is the intentional shape unless an ADR says otherwise.

**The agent's job is exactly this:**
1. **Find a sibling screen / feature in the same module.** Read it before writing anything.
2. **Mirror its shape**, specifically:
   - **Navigation registration** — linking config (React Navigation `linking`, Expo Router, GoRouter), deep-link handlers, push-notification handlers all wired the same way the sibling wires them.
   - **State pattern** — server data via TanStack Query, app state via Zustand/Redux, secrets via Keychain/Keystore. **Never mix.** Whatever the sibling uses for "list of items from the API," use the same.
   - **Offline plumbing** — cache strategy + mutation queue + replay-on-reconnect identical to the sibling. If sibling queues writes via WorkManager / Background Tasks, you queue via the same.
   - **Permission prompts in context** — right before the action that needs them, wording mirrored from the sibling's rationale strings. **Never at app launch.**
   - **Native config** — `Info.plist` Usage Descriptions, `AndroidManifest.xml` `<uses-permission>` + intent filters, `Podfile` deps, `build.gradle` deps — all touched in the same files the sibling touched.
   - **i18n keys** — every string keyed in **every** locale the sibling supports. Missing-locale = silent break.

**Why this matters more on mobile than web:** mobile features carry more cross-cutting platform concerns simultaneously — accessibility + i18n + native config + permissions + offline + push + deep links. Skipping any one because "the sibling has it covered" is the exact failure mode the cascading reviewers were designed to catch. The sibling is not magic; it's a checklist.

**The agent ONLY asks the user when:**
- **No sibling screen exists** in the module (genuinely new pattern — escalate to design + ADR).
- **Requirements need a new native bridge OR a new permission class** (camera-where-no-camera-existed, biometric-where-none-existed, background-location-where-none-existed).
- **Cross-platform behavior diverges** in a way that requires an ADR (iOS-only feature when project is universal, or vice versa).

That's it. Three escalation triggers. Everything else — i18n key naming, error-state copy, loading skeletons, offline strategy choice, permission rationale wording, native config block placement — is silent sibling-mirror, no questions, no chatter.

## Closure verb — feature complexity → ceremony

| Tier | Trigger | Deliverable | Reviewers |
|---|---|---|---|
| **Trivial** (default) | New screen mirrors a sibling; no new permission; no native bridge; no new offline pattern. | Code only. | None — sibling-mirror is its own audit. |
| **Standard** | New permission OR new offline pattern OR new native config entry (Info.plist key / AndroidManifest entry / Podfile dep). | Code + 1-paragraph plan. | `@accessibility-auditor` always; `@i18n-auditor` if any locale string lands. **No ADR.** |
| **Heavy** | New native bridge, biometric / Keychain / secrets touch, app-store-blocking change, write-path mutation, new push-notification class. | Code + ADR + full cascade. | Full serial cascade per § Phase 4 (mobile-architect → accessibility → i18n → app-store → security → ux), halt-on-blocker. |

Trivial is the default. Heavy is rare-by-design — match what `/find-and-fix` does for migration: most rows ship trivially.

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

After generation, dispatch reviewers **serially** (not parallel — each re-reads similar files; parallel = duplicate context cost). Gate each on scope: if the precondition isn't met, skip the dispatch entirely.

| Agent | Precondition (skip if false) | Always-on? |
|---|---|---|
| `@mobile-architect` | Always | yes |
| `@accessibility-auditor` | Always (a11y is non-optional) | yes |
| `@i18n-auditor` | `i18n_lib` detected in `.claude/codebase-profile.md` | no |
| `@app-store-reviewer` | Shipping a store update this change | no |
| `@security-auditor` | Diff touches biometric / keychain / secrets / auth | no |
| `@ux-reviewer` | Always | yes |

**Halt rule**: if ANY agent returns BLOCKER, stop the cascade. Do not run remaining reviewers on a blocked feature; fix the blocker, re-run from the failed agent. This is the `find-and-fix § 3.5 RE-DETECT` pattern from the migration pack — every blocker closes before advance, no silent partial-pass.

### Sibling-shape mechanical halt

Before any reviewer runs, the cascade's first dispatch (`@mobile-architect` in audit mode) compares the new feature against **≥2 sibling screens** in the same module. The audit halts mechanically — no judgment call — if any of these is true:

- **State pattern mixed.** Sibling uses TanStack Query for server data; new feature uses Redux for the same shape. Or vice versa. One pattern per concern across siblings.
- **Mutations not queued for offline replay** where siblings queue them. If sibling writes go through WorkManager / Background Tasks / mutation queue, the new feature's writes do too.
- **Permission prompted at app launch** instead of in-context. Mirror the sibling's prompt-just-before-action timing.
- **Native config / linking config / push handlers not registered.** If sibling registered a deep link in `linking.config`, an intent filter in `AndroidManifest.xml`, and a push topic handler — the new feature does all three or none, matching the sibling's surface.
- **Locale strings missing from one locale.** Every sibling-supported locale has the new keys. Missing `ar.ts` when `en.ts` has the key = halt.

These are mechanical (string-match / file-presence / config-presence checks), not opinion. Halt = the audit returns `BLOCKER` with the divergent axis named, and the cascade stops per the halt rule above.

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
