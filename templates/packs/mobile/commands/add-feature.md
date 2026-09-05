---
description: End-to-end mobile feature — multi-screen flow + state + offline + deep-link + native bridge if needed + tests + docs. Mobile counterpart to backend's /add-feature.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses one stack as illustration; substitute your stack's primitives from `_extracted-idioms.md`.


# /add-feature

Mobile feature orchestration. Use when a feature touches more than one screen OR introduces native capabilities (camera, notifications, biometric).

Accepts **either** a bare `"<description>"` (the command derives requirements itself) **or** a `specs/<file>` path / `Spec-ID` produced by `/analyze-task` (the command consumes that spec as the requirements contract instead of re-deriving — see Phase 1).

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/add-feature <desc> --plan` plans the feature and exits before any edit; the plan lands in `.claude/plans/` — re-enter and execute it later with `/execute-plan <file>` (or hand the file to any tool). When planning from a spec, the saved plan carries a `Spec: <Spec-ID>` header so the plan stays traceable to its contract.

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
| **Trivial** (default) | New screen mirrors a sibling; no new permission; no native bridge; no new offline pattern. | Code + tests (widget/unit test mirroring the sibling's, green on iOS + Android). | None — sibling-mirror is its own audit. |
| **Standard** | New permission OR new offline pattern OR new native config entry (Info.plist key / AndroidManifest entry / Podfile dep). | Code + 1-paragraph plan + **bundle / cold-start delta check** against the Phase 2 budget (any new screen or heavy import). | `@accessibility-auditor` always; `@i18n-auditor` if any locale string lands. **No ADR.** |
| **Heavy** | New native bridge, biometric / Keychain / secrets touch, app-store-blocking change, write-path mutation, new push-notification class. | Code + ADR + full cascade. | Full serial cascade per § Phase 4 (mobile-architect → accessibility → i18n → app-store → security → ux), halt-on-blocker. |

Trivial is the default. Heavy is rare-by-design — match what `/find-and-fix` does for migration: most rows ship trivially.

**Spec-path tier seeding.** When Phase 1 consumed a spec, **seed** the tier from the spec's `Sizing signal` (the spec already classified the work). The audit may still **promote** if it finds heavier triggers (new native bridge, new permission class, biometric / keychain / secrets touch, write-path mutation, new push class, store-blocking change) — never **silently demote** below the spec's seed. If the derived tier ≠ the spec's `Sizing signal`, record the divergence + the trigger in the PR description (`Tier: <derived> (spec seeded <spec-tier>; promoted because <trigger>)`).

## Phases applied

Heavy tier runs all 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve). Trivial / standard tiers run the subset their ceremony requires (see closure-verb table) — skipping phases outside your tier's ceremony is sanctioned; skipping phases inside it is not.

## Invariants

- **Tests ship with the feature — every tier, no exceptions.** A sibling-mirrored screen inherits its sibling's test shape; trivial tier is not a test exemption. No untested feature code reaches Phase 6 (which gates on "tests pass on iOS + Android").
- **Online + offline behavior decided up front** — not bolted on.
- **iOS + Android parity decided up front** — feature works equivalently on both unless explicitly platform-only.
- **Deep-link entry registered.**
- **Push notification entry registered** if the feature should be reachable via notification.
- **A11y from the start.**
- **i18n from the start.**
- **No native bridge code without an ADR** — bridges are leaky abstractions.
- **New dependency is gated** — a JS package, Pod, or Gradle dep no sibling already uses halts for a dependency review (maintenance / license / bundle + binary-size / supply-chain / native-permission footprint) before it lands. No silent dep additions, any tier. See Phase 4 § New-dependency gate.
- **Battery + data usage considered** — long-running listeners, large image uploads, polling.
- **Spec backreference on every tier** — when the feature was built from a spec, a `Spec: <Spec-ID>` line ships with the deliverable on ALL tiers (trivial included), so even a sibling-mirrored screen traces back to its `/analyze-task` contract. See Phase 5 + Output.
- **Open-questions HALT (spec path only)** — unresolved spec `Open questions` HALT before Generate (Phase 4). Resolve or explicitly defer-out-of-scope first; never design around an open question.

## When to use / NOT to use

- USE: feature spanning ≥2 screens.
- USE: feature requiring local persistence (Realm, SQLite, AsyncStorage, MMKV, secure keychain).
- USE: feature with offline-first or sync semantics.
- USE: feature using a native capability (camera, location, biometric, push, NFC).
- NOT: a single new screen → `/add-screen`, which is a scope-narrowing overlay on this command and runs everything below at screen scope.
- NOT: a UI tweak → just edit + `/review-changes`.

## Phase 1 — Understand

### Spec-consumption branch (when given a `specs/` path or `Spec-ID`)

If the argument is a path under `specs/` (or a `Spec-ID`), **READ that spec and treat it as the requirements CONTRACT** — read the spec in full, not just the screen list. The contract carries:
- **User stories + acceptance criteria** (with AC-IDs) and the **traceability table** (AC-ID → screen/component/test).
- **Affected modules/screens**, **native-capability requirements + iOS/Android parity** (which platforms, which native API per capability).
- **NFR / performance budgets** — cold-start delta, time-to-interactive, **bundle / binary-size delta**, RAM delta.
- **Authorization & data-sensitivity** — which roles may reach the feature, per-screen/per-action authorization rules, and every declared **PII / sensitive field** (the data-sensitivity classification).
- **Observability** requirements — crash-reporting coverage, analytics / screen-view signals expected, offline-queue-failure telemetry.
- **Rollout** — staged-rollout plan (iOS phased release / Android staged %), store-release / store-metadata changes, feature-flag / remote-config kill-switch expectation.
- **Success metrics** — the instrumented outcomes the feature must move (and their measurement signal).
- **Sizing signal** — the spec's own tier classification.
- **Test plan** and explicit **Out-of-scope**.

**Do NOT re-derive requirements the spec already contains** — skip the consolidated-question block below and proceed straight to design/generate from the spec. Still run the **prior-art gate**, the **sibling-shape mechanical halt** (Phase 4), the **new-dependency gate** (Phase 4), and the **spec-conformance gate** (Phase 6) — the spec does not exempt a feature from those; it is what the conformance gate checks against. **Open-questions HALT**: if the spec carries unresolved **Open questions**, surface them and HALT before Generate (Phase 4) — do not design around an open question.

If the argument is a bare description (no `specs/` path / `Spec-ID`), use the prior-art gate + consolidated-question path below unchanged.

### Prior-art gate (mandatory, all tiers)

Sibling search finds a screen to copy. This gate asks first: **does the capability already exist** under another name? On mobile a duplicate is doubly expensive — a second offline queue, a second permission prompt, a second native-config block all drift independently.

1. Search by **behavior, not name** — existing screens, navigation entries, services, or native bridges that already cover the capability (a "scan receipt" feature may already have camera + upload wired in an existing flow).
2. **Near-duplicate found → HALT.** Surface the existing screen / flow (path + what it does) and ask: extend it, replace it, or ship a deliberate parallel (rare — record the rationale).
3. Nothing matches → continue.

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
- Screen-reader labels on every interactive element; rotor / TalkBack traversal order logical.
- Reduce motion respected (`UIAccessibility.isReduceMotionEnabled` / `Settings.Global.ANIMATOR_DURATION_SCALE`
  — `Settings.System` is the deprecated name for this key).
- Dynamic Type / font scaling exercised at the platform's largest accessibility size.
- **Touch-target and contrast figures are not this command's to state.** The minimums are 44×44 pt on
  Apple and 48×48 dp on Android (`rules/mobile-principles.md` [S3] / [S4]); contrast is the
  `contrast` axis and tap size is the `tap-target` axis, both owned by `ui-principles.md`
  § Axis catalog *(ui-ux pack, when co-installed)*. Absent that pack, apply the two platform figures
  and mark the lane `floor: not audited (ui-ux pack absent)`.

### Tests
| Layer | File |
|---|---|
| unit | <path> |
| component | <path> |
| integration | <path> |
| e2e (Detox / Maestro / XCUITest / Espresso) | <path> |

### Performance budget

**These are placeholders the project fills, not constants this command supplies.** A budget is only meaningful against a measured baseline on a named device; a number invented here would be enforced in Phase 6 against nothing. Read the budget from the spec's NFR section, from `ai/runtime/` baselines, or from the project's own conventions — and if none exists, say so and propose one from a measurement rather than adopting a default.

- Cold start delta: `<project budget>` measured on `<named device>`
- Time-to-interactive on the main feature screen: `<project budget>` on `<named device>`
- Bundle delta: `<project budget>`
- RAM delta: `<project budget>`

Where the project has no budget at all, `/optimize-bundle` establishes the baseline and the published store limits it must stay inside; `device-harness` supplies the named device the measurement is taken on.

### Open questions
<flag for user>
```

## Phase 3 — Retrieve

Read in order:
1. `CLAUDE.md` — stack (RN / Flutter / native iOS / native Android).
2. `ai/architecture.md` — module boundaries.
3. `ai/business-domain.md` — what feature does in business terms.
4. `ai/patterns/offline-sync.md`, `native-storage.md`, `deep-linking.md`, `permissions.md`, `app-lifecycle.md`, `push-notifications.md` — this pack's patterns; read the ones the feature actually touches.
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
   - Mutations queued through **the platform's own scheduler** (iOS `BGTaskScheduler` / Android `WorkManager`, or the queueing layer the sibling already uses) and replayed. Do not reach for a community background-task shim without checking it is still maintained — read the queue the sibling ships before adding a dependency, and see `offline-sync.md` for what a replay must guarantee.
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
| `@offline-sync-auditor` | The diff adds or changes a **queue, cache, or optimistic-update path** — i.e. any tier whose trigger was `write-path mutation` | no |
| `@device-performance-auditor` | The tier required a **bundle / cold-start delta check** (Standard and above), or the feature adds a launch-path import, a long-running listener, or a background job | no |
| `@ux-reviewer` | Always | yes |

If a named agent is not installed in this project, perform that review inline against the corresponding pack/domain checklist — never silently skip the axis.

**Halt rule**: if ANY agent returns BLOCKER, stop the cascade. Do not run remaining reviewers on a blocked feature; fix the blocker, re-run from the failed agent. This is the `find-and-fix § 3.5 RE-DETECT` pattern from the migration pack — every blocker closes before advance, no silent partial-pass.

### New-dependency gate (all tiers)

If the feature pulls in a JS package, CocoaPod, or Gradle dependency **no sibling already uses**, it never lands silently. On mobile a dependency costs binary size, can drag in extra native permissions (store-review risk), and may break one platform.

- **Confirm it's actually new** — check `package.json` + lockfile, `Podfile.lock`, `build.gradle`. A sibling may already ship an equivalent. Reuse it.
- **Run a dependency review** (dispatch `security-auditor`, or inline against the checklist): maintenance health, license, **bundle + binary-size delta**, **new native permissions the dep forces** (extra `Info.plist` / `AndroidManifest` entries trigger store review), iOS + Android support parity, and whether a native API or already-present lib covers the need.
- **Record the decision** — one PR line (trivial / standard) or an ADR (heavy, native bridge, or any auth / biometric / keychain dep).

HALT on an unreviewed new dependency, and on any dep that silently adds a permission not in the feature's declared native surface.

### Sibling-shape mechanical halt

Before any reviewer runs, the cascade's first dispatch (`@mobile-architect` in audit mode) compares the new feature against **≥2 sibling screens** in the same module. The audit halts mechanically — no judgment call — if any of these is true:

- **State pattern mixed.** Sibling uses TanStack Query for server data; new feature uses Redux for the same shape. Or vice versa. One pattern per concern across siblings.
- **Mutations not queued for offline replay** where siblings queue them. If sibling writes go through WorkManager / Background Tasks / mutation queue, the new feature's writes do too.
- **Permission prompted at app launch** instead of in-context. Mirror the sibling's prompt-just-before-action timing.
- **Native config / linking config / push handlers not registered.** If sibling registered a deep link in `linking.config`, an intent filter in `AndroidManifest.xml`, and a push topic handler — the new feature does all three or none, matching the sibling's surface.
- **Locale strings missing from one locale.** Every sibling-supported locale has the new keys. Missing `ar.ts` when `en.ts` has the key = halt.

These are mechanical (string-match / file-presence / config-presence checks), not opinion. The criteria above are mobile-specific; the **verdict vocabulary is the shared one** in [`templates/snippets/sibling-shape-halt.md`](../../../snippets/sibling-shape-halt.md): a clean compare is `aligned`, any divergent axis is `drifted` (the `BLOCKER:<axis>` output maps onto `drifted`), and a module with no sibling screen is `no-siblings` (escalate). Any `drifted` halts the cascade per the rule above.

## Phase 5 — Update

- `ai/modules.md` — feature module entry.
- `ai/patterns/<new>.md` — only if new pattern.
- `ai/decisions/<NNNN>-*.md` — for architectural choices (offline strategy, state placement, native bridge introduction).
- `ai/status.md` § Recent Changes.
- `app-store-metadata/` — privacy disclosure + permission rationale strings (if relevant).
- **Spec backreference (only when built from a spec — ALL tiers, trivial included)** — add a `Spec: <Spec-ID>` line to the changelog entry, the `ai/status.md` § Recent Changes entry, the PR description, **and the command's own output** (see Output format — including the trivial-tier output), so the shipped feature traces back to its `/analyze-task` spec on every closure path. A trivial sibling-mirror that skips Phase 5 docs still emits the `Spec:` line in its output.

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
- **Observability sign-off** (gated on what the project ships — check `.claude/codebase-profile.md` / `CLAUDE.md`):
  - Crash reporting (Crashlytics / Sentry / equivalent) covers the new screens — error boundaries / handlers wired the same way siblings wire them.
  - Screen-view / performance signal recorded if siblings record one (screen TTI, cold-start contribution, analytics screen events) — same naming convention.
  - Offline queue failures surface to telemetry, not just local logs — a silently-dropped sync is the worst mobile failure mode.
  - If the project ships NO observability layer: note `observability: none configured` in the report — explicit, never silent.
- **Release note (heavy tier only)**: one PR-description paragraph — feature flag / remote-config kill switch decision (store review takes days; a flag is the only same-day rollback), staged rollout plan (iOS phased release / Android staged %), store-metadata changes (privacy disclosures, permission strings), and rollback path.

### Spec-conformance gate (spec path only — skip when built from a bare description)

When Phase 1 consumed a spec, the feature is not done until it is **conformant to the contract**. Walk the spec section-by-section; each section is a **per-section HALT-on-unmet** — any unmet requirement HALTS the ship (no aggregate pass, no "mostly met"). Each check is mobile-specialized:

- **Native-capability / iOS+Android parity** — each native-capability or parity requirement is verified on **both** platforms (iOS check AND Android check). A capability working on one platform when the spec says universal = HALT.
- **NFR / performance** — each NFR is **measured, not asserted**: cold-start delta measured against baseline, **bundle / binary-size delta** measured, TTI + RAM where the spec set a budget. Over budget with no waiver = HALT.
- **Authorization** — each authorization rule gets an **unauthorized-access test** (a role/state the spec forbids is exercised and proven blocked on both platforms). No negative test = HALT.
- **Data-sensitivity / PII** — each declared PII / sensitive field has a **secure-storage check** (Keychain / Keystore / hardware-backed, never plaintext / AsyncStorage) and a **redaction check** (absent from logs, crash payloads, and analytics). Plaintext or leaked field = HALT.
- **Observability** — each Observability requirement is matched to a real signal: crash-reporting covers the new screens, the declared analytics / screen-view signal fires, offline-queue failures reach telemetry. A declared signal with no wiring = HALT. (If the project ships no observability layer, the spec requirement is unmeetable → HALT and surface, do not silently pass.)
- **Success metrics** — each success metric is **instrumented** (the measurement signal is wired) **or explicitly deferred** in the report with a reason. Silently un-instrumented = HALT.

Record `spec_sections_checked=N / spec_sections_met=N` in the report; ship only when met == checked.

### Build-time traceability rebuild (spec path only)

Rebuild the spec's traceability table from the actual code at ship time — do not trust the design-time table:

- **Every spec AC-ID → a named test.** Resolve each acceptance-criterion ID to the concrete test(s) that exercise it, **green on iOS AND Android**.
- **HALT if any AC-ID is untested** (no test, or a test that is red / skipped / single-platform).
- **Emit the AC→test map** in the report (`AC-3 → FeatureFlow.itemSubmit.test [iOS ✓ Android ✓]`), so the shipped feature's coverage is auditable against the contract.

## Phase 7 — Improve

- Run `/learn-from-task` to capture: sibling mirrored, native surface touched, offline strategy, corrections, follow-ups.
- New offline strategy → propose pattern.
- New native bridge → ADR proposed.
- Recurring permission-denial UX → propose pattern.
- Battery/data drain detected → flag for follow-up.
- **Spec-drift learning (spec path only)** — if the shipped feature diverged from the spec (a deferred success metric, a parity exception, a tier promotion, a budget waiver, a native API the spec didn't anticipate): **annotate the spec** with the divergence + rationale, **queue the learning** to `ai/dynamic/feedback-learned.md`, and surface it in the PR description. Reuse the existing learning file — do not create a new one. Spec drift that ships unrecorded is the worst case: the contract and the code silently disagree.

## Output format

```
## /add-feature — <feature-name>

Status: SHIPPED | NEEDS REVIEW | BLOCKED
Spec: <Spec-ID>            (only when built from a spec — present on EVERY tier, trivial included; omit the line entirely when built from a bare description)

Platforms verified: iOS <v>, Android <v>
Files written: <count>
Tests: unit/comp/integration/e2e all passing
Bundle delta: +<KB>
Cold-start delta: +<ms>
A11y score: <number>
i18n: <count> new keys per locale, no missing

Spec conformance:          (spec path only)
  Sections met:           <met>/<checked>   (HALT if not all met)
  AC → test map:
    AC-1 → <test> [iOS ✓ Android ✓]
    AC-2 → <test> [iOS ✓ Android ✓]
  Success metrics:        <instrumented | deferred: reason>

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

- `/add-screen` — the single-screen overlay on this command (same gates, same cascade, narrower ask).
- `/optimize-bundle` — when bundle delta exceeds budget.
- `@mobile-architect` — design.
- `@app-store-reviewer` — pre-release review.
- `ai/patterns/offline-sync.md`, `native-storage.md`, `deep-linking.md`.
- Backend's `/add-feature` — counterpart for backend; usually paired in cross-stack mobile features.
