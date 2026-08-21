---
name: mobile-principles
kind: example
pack: mobile
---

# Mobile Principles

Prevents the failures that get apps rejected, penalised, or 1-starred: the OS suspends you, kills you, denies you, throttles you, and keeps an old build installed on a phone you cannot reach.

> **Hard rule.** Auth tokens, payment data, and health data MUST live in Keychain (iOS) / Keystore (Android) — never in plain `AsyncStorage` / `SharedPreferences` / `UserDefaults`. Permissions MUST be requested in-context with a pre-prompt; every network call MUST have a declared timeout + UI error path; crash reporting MUST be wired before first beta with `dSYM` / mapping file uploaded. Any platform threshold, limit, or window quoted anywhere MUST carry the URL that publishes it — where none is published, say so instead of inventing one.

## Must

- Tokens, passwords, encryption keys go to Keychain (iOS) / **the Android Keystore directly** — never `UserDefaults`, plain `AsyncStorage`, plain `SharedPreferences`, and **not `EncryptedSharedPreferences`**: `androidx.security:security-crypto` 1.1.0-beta01 (2025-06-04) "Deprecated all APIs in favour of existing platform APIs and direct use of Android Keystore", and that deprecation stands in 1.1.0 (2025-07-30) [S9]. That is a *versioned* status — re-read [S9] and the project's own dependency before writing either path. Use the project's secure-store wrapper; add one if none exists, and read what it wraps before trusting it.
- Every network call has a timeout the project declares as a budget (no platform imposes one) and an error path that updates the UI.
- Permissions requested in context with a pre-prompt, **because the system dialog is one-shot**: a denial is durable and cannot be re-prompted in-app.
- Denial degrades the feature, never crashes it — and permission is re-checked on every relevant action, since a grant can be revoked in Settings at any time.
- Crash reporting wired before first beta, symbolication artifacts uploaded every release: debug symbols on Apple platforms, the R8 mapping file on Android — R8 renames classes/fields/methods, so an unmapped trace is unreadable [S1].
- State that must survive **process death** is persisted, not held in the view layer. The OS terminates backgrounded apps without warning.
- Background work goes through the platform's documented scheduler; on Android 14+ (API 34) a foreground service declares its service type in the manifest plus the matching `FOREGROUND_SERVICE_*` permission [S2]. Never assume a window *duration* — no platform publishes one.
- Screen-reader labels on every interactive element. iOS: `accessibilityLabel`. Android: `contentDescription`. Test with VoiceOver / TalkBack.
- Touch targets meet the platform minimum: **44×44 pt** on Apple [S3], **48×48 dp** on Android [S4]. The axis is `tap-target`, owned by `ui-principles.md` § Axis catalog *(ui-ux pack, when co-installed)*; absent that pack apply the two figures and mark the lane `floor: not audited (ui-ux pack absent)`.
- Deep links handled defensively: validate the URL, never `eval` / `exec` / open arbitrary URLs from a deep-link payload.
- Push follows the full lifecycle: in-context permission (never cold-start), token synced with a user+device binding AND invalidated on 410 / `NotRegistered` / logout, channels + categories created up front, foreground presentation handled, tap → screen routing delegated to `deep-linking`.
- Over-the-air updates ship ONLY the JS/asset layer — a native code, native dependency, or permission change (`Info.plist` / `AndroidManifest`) needs a store build (Guideline **2.5.2**, the downloaded-code clause — the Guidelines have no § 3.3 [S5]). Every rollout MUST be staged and rollback-able; a mandatory update MUST sit behind a min-supported-version gate with a store escape hatch.
- Privacy declarations are an **upload gate**, not a submission task: Apple requires approved reasons for required-reason APIs in the privacy manifest to upload [S6]; every Play app must complete the Data safety form, including apps that collect nothing [S7].
- API base URL via build variants (`dev` / `staging` / `prod`) — never hardcoded.

## Must not

- Store auth tokens / payment data / health data in plain `AsyncStorage` / `SharedPreferences` / `localStorage` (web view).
- Request permissions on first launch without context. Users deny by default — and you do not get a second system prompt.
- **Assert a platform number you cannot cite.** Background-window durations, review turnaround times, crash-rate rejection thresholds, and install-base statistics are the four places this happens. Write what determines the value instead.
- Poll the server in the foreground for updates. Use push or a socket.
- Ship without crash reporting. The first prod crash you cannot symbolicate is the hardest one.
- Test only on the flagship dev phone. Pick the lowest-spec device the install base contains — from the store console's device catalogue or the project's analytics, never a guessed population figure.
- Use an external payment link for digital goods without checking the storefront: 3.1.1 requires in-app purchase, and 3.1.1(a) exempts **United States storefront** apps from the external-link prohibition that still applies in every other storefront [S5].
- Ignore screen orientation, dynamic type, dark mode — testers WILL toggle them.
- Block the UI thread with synchronous I/O (large file reads, parsing huge payloads).

## Should

- Offline-first for core flows: every screen classified works / degrades / blocks, optimistic writes queued with idempotency keys, one declared conflict policy.
- Connectivity indicator when offline; pending-sync badge when actions are queued; biometric / PIN app-lock on sensitive screens.
- Set a cold-start budget, record it as a budget, measure it on a named device. Android vitals flags startup *excessive* at 5s cold / 2s warm / 1.5s hot [S8] — a store-visible ceiling, not a target.
- Hit 60fps scroll — virtualize with the framework's lazy/recycling primitive. Detectors + the measure-before/after contract live in `render-discipline.md`.
- Support Dynamic Type / font scaling — test at the platform's largest accessibility text size, not just the default.
- Keep server contracts additive while an old build is installed, and state a min-supported-version policy before an incident forces one.

## Review checklist

- [ ] Secrets / tokens in Keychain / Keystore.
- [ ] Permissions in-context with pre-prompt; denial path exists; re-checked at use.
- [ ] Network calls have a declared timeout + error UI.
- [ ] Screen state survives process death (persist / recompute / refetch per field).
- [ ] Crash reporting initialized + symbolication artifacts uploaded.
- [ ] Accessibility labels on new UI; VoiceOver / TalkBack smoke-tested.
- [ ] Privacy manifest / Data safety form updated if data collection changed.
- [ ] Every quoted platform number carries its source.
- [ ] Tested on a low-end device + throttled network.

## Enforcement

- Wrap secure storage in a project utility; lint to forbid direct plain-storage calls for credentials.
- E2E on real devices in CI (Detox / Maestro / Espresso / XCUITest via a device-farm service); bundle-size budget blocking PRs that bloat startup; `gitleaks` for committed secrets.
- `@app-store-reviewer` (this pack) owns the store verdict and re-fetches every policy figure at review time; this rule carries only the nine below.

## Sources

S1 https://developer.android.com/studio/build/shrink-code · S2 https://developer.android.com/develop/background-work/services/fgs/service-types · S3 https://developer.apple.com/design/tips/ · S4 https://developer.android.com/guide/topics/ui/accessibility/apps · S5 https://developer.apple.com/app-store/review/guidelines/ · S6 https://developer.apple.com/news/?id=3d8a9yyh · S7 https://support.google.com/googleplay/android-developer/answer/10787469 · S8 https://developer.android.com/topic/performance/vitals/launch-time · S9 https://developer.android.com/jetpack/androidx/releases/security
