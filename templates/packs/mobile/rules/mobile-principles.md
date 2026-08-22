---
name: mobile-principles
description: Mobile Principles
kind: rule
pack: mobile
severity: must
applies-to: mobile-track, every-code-writing-task-in-mobile
---

# Mobile Principles

> **Hard rule.** Auth tokens, payment data, and health data MUST live in Keychain (iOS) / Keystore (Android) — never in plain `AsyncStorage` / `SharedPreferences` / `UserDefaults`. Permissions MUST be requested in-context with a pre-prompt; every network call MUST have a declared timeout + UI error path; crash reporting MUST be wired before first beta with `dSYM` / mapping file uploaded. Any platform threshold, limit, or window quoted anywhere MUST carry the URL that publishes it — where none is published, say so instead of inventing one.

Prevents the failures that get apps rejected, penalised, or 1-starred: the OS suspends you, kills you, denies you, throttles you, and keeps an old build installed on a phone you cannot reach.

## Must

- Tokens, passwords, encryption keys go to Keychain (iOS) / **the Android Keystore directly** — not `UserDefaults`, plain `AsyncStorage`, plain `SharedPreferences`, and not `EncryptedSharedPreferences`, deprecated in favour of direct Keystore use [S7]. Use the project's secure-store wrapper, and read what it wraps before trusting it. Placement per data class, and binding a secret to biometrics: `ai-patterns/native-storage.md`.
- Every network call has a timeout the project declares as a budget — no platform imposes one — and an error path that updates the UI.
- Permissions requested in context behind a pre-prompt, **because the dialog runs out, differently per platform, and the difference decides the recovery UI.** iOS: one shot, then Settings only. Android: the dialog stops appearing once the user taps Deny "for a specific permission more than once during your app's lifetime of installation on a device" [S8] — so a *first* denial is still recoverable, and `shouldShowRequestPermissionRationale()` tells you which case you are in. Denial degrades the feature, never crashes it; re-check on every use, because Settings can revoke mid-session. Four states: `ai-patterns/permissions.md`.
- State that must survive **process death** is persisted, not held in the view layer. The OS terminates backgrounded apps with no guaranteed callback.
- Background work goes through the platform's documented scheduler; on Android 14+ (API 34) a foreground service declares its service type plus the matching `FOREGROUND_SERVICE_*` permission [S2]. Never assume a window *duration* — no platform publishes one.
- Crash reporting wired before first beta, symbolication artifacts uploaded every release — Apple debug symbols, the Android R8 mapping file: R8 renames classes, fields and methods, so an unmapped trace is unreadable [S1].
- The a11y floor, both platforms: a screen-reader label on every interactive element (`accessibilityLabel` / `contentDescription`, smoke-tested with VoiceOver and TalkBack), and touch targets at **44×44 pt** on Apple [S3] / **48×48 dp** on Android [S4]. That axis is `tap-target` in `ui-principles.md` § Axis catalog *(ui-ux pack)*; absent that pack, apply both figures and mark the lane `floor: not audited` — never coin a mobile-only synonym.
- Deep-link payloads are untrusted input: validate before routing, never `eval` / `exec` / open a URL out of one.
- Push asks in context and never at cold start; the token is bound to user *and* device, invalidated on logout, and the tap routes through `deep-linking`. Full lifecycle: `ai-patterns/push-notifications.md`.
- Privacy declarations are an **upload gate**, not a submission task: Apple's privacy manifest blocks the upload without approved reasons for required-reason APIs [S5], and Play's Data safety form is required of every app, including apps that collect nothing [S6]. Schedule them before the release, not inside it.
- API base URL via build variants (`dev` / `staging` / `prod`) — never hardcoded.
- **Budgets are written down before the first measurement** — cold start, frame, memory, battery, size — each against a named device. A figure recorded after the run is a description, and a description can never be missed. `@device-performance-auditor` owns the measuring and the published ceilings.

## Must not

- **Assert a platform number you cannot cite.** Background-window durations, review turnaround times, crash-rate rejection thresholds, and install-base statistics are the four places this happens. Write what determines the value instead.
- **Quote a store policy figure from this file.** Every one is dated; `@app-store-reviewer` re-fetches them at review time, which is why this rule carries none.
- Poll the server in the foreground for updates. Use push or a socket.
- Test only on the flagship dev phone. Pick the lowest-spec device the install base contains — from the store console's device catalogue or the project's analytics, never a guessed population figure.
- Ignore screen orientation, dynamic type, dark mode — testers WILL toggle them.
- Block the UI thread with synchronous I/O (large file reads, parsing huge payloads).

## Enforcement

- Wrap secure storage in a project utility; lint to forbid direct plain-storage calls for credentials.
- E2E on real devices in CI (Detox / Maestro / Espresso / XCUITest via a device farm); a size budget blocking PRs that bloat startup; `gitleaks` for committed secrets.
- Each MUST is verified by naming the artifact that satisfies it: the secure-store call site, the permission state machine, the timeout constant, the CI symbol-upload step, the persisted-state test, the budget's device. A MUST with no `<file:line>` was not verified, and a checklist restating these lines would not change that.

## Where the depth lives

Loaded on every task, so this file carries only what changes the next line you write. For the subject you are actually in, read its on-demand artifact instead of restating it here.

- `render-discipline.md` + `references/<framework>.md` § Render-discipline fingerprints — 60fps, virtualization, the 8 detectors, and every framework-specific API, lint rule and profiler this pack has. Nothing framework-specific belongs in this file.
- `ai-patterns/` — one file per subject above, each in full, including the boundary this rule no longer restates: an OTA ships the JS/asset layer only, and a native or permission change needs a store build (`ota-updates.md`).
- `@mobile-architect` classifies each screen works / degrades / blocks · `@offline-sync-auditor` proves whether that classification is true · `@device-performance-auditor` measures the four costs · `@app-store-reviewer` owns every dated store gate.

## Sources

S1 https://developer.android.com/studio/build/shrink-code · S2 https://developer.android.com/develop/background-work/services/fgs/service-types · S3 https://developer.apple.com/design/tips/ · S4 https://developer.android.com/guide/topics/ui/accessibility/apps · S5 https://developer.apple.com/news/?id=3d8a9yyh · S6 https://support.google.com/googleplay/android-developer/answer/10787469 · S7 https://developer.android.com/jetpack/androidx/releases/security · S8 https://developer.android.com/training/permissions/requesting
