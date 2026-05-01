---
name: mobile-principles
kind: example
pack: mobile
---

# Mobile Principles

Prevents the failures that get apps rejected from stores or 1-starred: bad networks crash the app, tokens leak, permissions feel hostile, store policies miss.

## Must

- Tokens, passwords, encryption keys go to Keychain (iOS) / Keystore (Android, with `EncryptedSharedPreferences`) — never `UserDefaults`, plain `AsyncStorage`, plain `SharedPreferences`. React Native: `react-native-keychain`. Flutter: `flutter_secure_storage`.
- Every network call has a timeout (≤ 15s for foreground, ≤ 60s for background) and an error path that updates UI.
- Permissions requested in context (when user invokes the feature), not on launch. Explain WHY in a pre-prompt screen, then trigger the system dialog.
- Handle permission denial gracefully — feature degrades, doesn't crash. Re-check on every relevant action (user can revoke in Settings later).
- Crash + error reporting integrated before first beta: Crashlytics, Sentry, Bugsnag, or BugSnag. `dSYM` / `mappings.txt` uploaded for symbolication.
- Screen reader labels on every interactive element. iOS: `accessibilityLabel`. Android: `contentDescription`. Test with VoiceOver / TalkBack.
- Touch targets ≥ 44×44 pt (iOS HIG) / 48×48 dp (Android Material).
- Deep links handled defensively: validate the URL, never `eval` / `exec` / open arbitrary URLs from a deep link payload.
- Privacy manifest (iOS `PrivacyInfo.xcprivacy`) and Play Console data safety form filled out accurately. Lying gets you removed.
- API base URL via build variants (`dev` / `staging` / `prod`) — never hardcoded.

## Must not

- Store auth tokens / payment data / health data in plain `AsyncStorage` / `SharedPreferences` / `localStorage` (web view).
- Request permissions on first launch without context. Users deny by default — you don't get a second prompt without going to Settings.
- Poll the server in the foreground for updates. Use FCM / APNs push or websockets.
- Ship without crash reporting wired in. The first prod crash you can't symbolicate is the hardest one.
- Skip Android testing on low-end devices. Pixel-only QA misses the 80% of users on slower hardware.
- Use external payment links for digital goods on iOS — Apple rejects. Use IAP (StoreKit / Play Billing).
- Ignore screen orientation, dynamic type, dark mode — testers WILL toggle them.
- Block the UI thread with synchronous I/O (large file reads, JSON parse of huge payloads). Move to background.

## Should

- Offline-first for core flows: optimistic writes + sync queue with conflict resolution policy (last-writer-wins, server-wins, merge).
- Connectivity indicator visible when offline; pending-sync badge when actions are queued.
- App launch < 2s cold on a 3-year-old mid-range device. Defer heavy initialization until after first paint.
- 60fps scroll on lists — virtualize (`FlatList` with `getItemLayout`, `RecyclerView`, lazy `ListView`).
- Biometric / PIN as an additional app-level lock for sensitive screens (banking, health, vault).
- Dynamic Type (iOS) and font scaling (Android) supported — test up to 200%.
- Test on the lowest-spec device in your install base, not just the flagship dev phone.

## Review checklist

- [ ] Secrets / tokens stored in Keychain / Keystore.
- [ ] Permissions are in-context with pre-prompt explanation.
- [ ] Network calls have timeout + error UI.
- [ ] Crash reporting initialized + symbolication artifacts uploaded.
- [ ] Accessibility labels on new UI elements; VoiceOver / TalkBack smoke-tested.
- [ ] Privacy manifest / data safety form updated if data collection changed.
- [ ] No hardcoded URLs / API keys.
- [ ] Tested on a low-end device + slow network (Network Link Conditioner / Chrome DevTools throttling).

## Enforcement

- `react-native-mmkv` or `react-native-keychain` (RN), `flutter_secure_storage` (Flutter), `EncryptedSharedPreferences` (Android), `KeychainAccess` (iOS) — wrap with a project utility, lint to forbid direct `AsyncStorage`/`SharedPreferences` calls.
- Detox / Maestro / Espresso / XCUITest for E2E on real devices in CI (Firebase Test Lab / BrowserStack / SauceLabs).
- Bundle size budget (`bundlesize` / build flags) blocking PRs that bloat startup.
- `gitleaks` for committed secrets. Store credentials in CI secrets manager, not in repo.
