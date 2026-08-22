---
name: native-storage
description: Pattern — secure + performant local storage on mobile. Pick the right primitive for the right data class.
kind: ai-pattern
pack: mobile
---

# Pattern: Native storage

> **Hard rule:** Each data class maps to exactly one storage primitive based on its security + size + query needs (Keychain on Apple platforms / the Android Keystore directly for secrets; MMKV/AsyncStorage/UserDefaults for KV preferences; SQLite/Realm/Room/Core Data for relational). Storing tokens in plaintext key-value, secrets in unencrypted DB, or large blobs in Keychain is forbidden.

**When to apply**
- The app stores any auth token, refresh token, biometric secret, or PII at rest.
- Local cache > 1MB or queryable structured data is needed (search, filter).
- A new data class is being added — pick the primitive with the security/perf tradeoff explicit.

**When NOT to apply**
- Ephemeral in-memory state cleared on app close — no persistence needed.
- A pure web wrapper where the WebView's storage is the system of record.

**Halt conditions / mandatory cites**
- Each storage call MUST cite the primitive + class at `<path:line>` AND the encryption guarantee.
- Secrets MUST cite the platform secure-enclave API (Keychain Services, Android Keystore) — never plain shared prefs / NSUserDefaults.
- A doc proposing AsyncStorage / UserDefaults for tokens is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is encrypted".
- If the chosen primitives + their encryption posture aren't extracted, halt.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Mobile`.
>
> - **Storage primitives in use**: `<MMKV / AsyncStorage / Keychain / Android Keystore / DataStore / Realm / SQLite / Core Data / Room>`
> - **Encryption strategy**: `<at-rest via system keychain / app-level encryption with key in keychain / none>`
> - **Multi-device sync layer**: `<iCloud / Firestore / Google Drive / none>`

## Decision matrix — pick the right primitive

| Data class | iOS native | Android native | RN cross | Flutter cross |
|---|---|---|---|---|
| Auth tokens, refresh tokens, biometric secrets | Keychain (kSecAttrAccessibleWhenUnlockedThisDeviceOnly) | Android Keystore directly (**not** `EncryptedSharedPreferences` — see below) | `react-native-keychain` | `flutter_secure_storage` |
| User preferences (theme, locale) | UserDefaults / NSUbiquitousKeyValueStore | SharedPreferences | MMKV | shared_preferences / hive |
| Cached API responses | NSCache / FileManager | LruCache / DataStore | TanStack Query persister + MMKV | dio_cache_interceptor |
| Structured local data (offline queue, drafts) | Core Data / SwiftData | Room | WatermelonDB / Realm / SQLite (op-sqlite) | drift / sqflite / hive |
| Large blobs (images, documents) | FileManager (Documents/Caches) | InternalStorage / ExternalFiles | RNFS / FileSystem | path_provider |
| Real-time / sync state | UserDefaults + iCloud / Firestore | DataStore + Firebase | Firestore / Realm Sync | Firestore / hive_flutter |

## Hard rules per data class

### Secrets (auth tokens, biometric, OAuth refresh)

- **Always** in keychain / Keystore. Never in `UserDefaults` / `SharedPreferences` / `AsyncStorage`.
- **On Android, use the Keystore directly — `EncryptedSharedPreferences` is deprecated.** The `androidx.security:security-crypto` release notes for **1.1.0-beta01 (2025-06-04)** read "Deprecated all APIs in favour of existing platform APIs and direct use of Android Keystore", and that deprecation stands in **1.1.0 (2025-07-30)** (https://developer.android.com/jetpack/androidx/releases/security, read 2026-08-21). It covers `EncryptedSharedPreferences`, `EncryptedFile` and `MasterKeys` alike. Existing call sites in a project are not an emergency — the requirement is the threat model, not the artifact — but do not add a new one, and re-check that release page before prescribing either path, because this is a versioned status rather than a permanent fact. `references/jetpack-compose.md` § Core choices carries the migration note.
- Access control: `WhenUnlockedThisDeviceOnly` (iOS) / hardware-backed when available (Android).
- Don't log secrets — even in dev. Don't include in crash reports.
- On logout: clear keychain entries (don't leave them).
- **App uninstall does not clear the iOS keychain, and no entitlement makes it.** Keychain items written by an app have survived its removal on every shipping iOS release; Apple has never made that part of the API contract (a change in the iOS 10.3 beta to delete them was reverted before GM), and iOS exposes no uninstall hook at all. Expo documents the consequence for the wrapper most RN apps use: `expo-secure-store` data "will persist across app uninstallations" on iOS, while on Android it "will not be preserved upon app uninstallation" (https://docs.expo.dev/versions/latest/sdk/securestore/, read 2026-08-20). Keychain Sharing is an app-group *sharing* entitlement and has no bearing on deletion.
  **The remedy is a first-launch sweep.** Set a flag in a store that *is* removed at uninstall (`UserDefaults` / `SharedPreferences`) on first run; if the flag is absent, clear the app's keychain items before reading any of them. Without it, a reinstall — or a device resold and re-provisioned — resumes the previous user's session.

### Biometric-gated secrets

Biometrics do not *store* anything. The secret still lives in the Keychain / Keystore; what biometry adds is an **access-control constraint on the item or the key**, enforced by the secure hardware. A boolean the app checks after a `LAContext` / `BiometricPrompt` callback is not that — it is a UI gesture in front of an unprotected item, and it is the shape this pattern exists to reject. `add-feature` § Hard rules states the floor: **no biometric without secure-enclave / hardware-backed keystore.**

| Decision | iOS | Android |
|---|---|---|
| Bind the secret to biometry | `SecAccessControl` flag on the keychain item | Generate the key in the Keystore authorized only for an authenticated user, and set the mode with `setUserAuthenticationParameters()` |
| Invalidate when the enrolled set changes | `kSecAccessControlBiometryCurrentSet` — "The item is invalidated if fingers are added or removed for Touch ID, or if the user re-enrolls for Face ID" [B1] | Default behaviour: "If a key only supports biometric credentials, the key is invalidated by default whenever new biometric enrollments are added"; `setInvalidatedByBiometricEnrollment(false)` opts out [B2] |
| Allow passcode / device-credential fallback | `.biometryAny`/`.biometryCurrentSet` **or** `.devicePasscode` — picking one is a threat-model decision, not a default | Include the device-credential authenticator in the allowed set, or do not |

**Three decisions this forces, and none of them has a right answer this pack can supply:**

1. **Enrollment change = invalidation, or not?** Invalidating is the stronger posture and the platform default on Android; it also means *the user who adds a fingerprint is logged out and must re-authenticate from scratch.* Whichever you choose, the app needs a **re-provision path**: catch the invalidated-key / item-not-found error, clear the stale material, and send the user back through the full login. An uncaught invalidation reads to the user as "the app is broken".
2. **Passcode fallback, or biometry only?** Allowing device credential means anyone who knows the passcode reaches the secret; refusing it means a user with a wet thumb or a failed sensor has no route in. State the choice; do not inherit it from whichever sample you copied.
3. **What is actually behind the prompt?** Gating a *screen* while the token sits unprotected in the same keychain is theatre — the item is readable without the prompt. Gate the **item**, and let failure to unlock mean failure to read.

Also handle: no hardware enrolled, hardware present but locked out after repeated failures, and the user cancelling. Each is a distinct branch with distinct copy, and each must degrade to a working non-biometric route rather than a dead end.

### User preferences (small KV)

- A memory-mapped KV store (MMKV and equivalents) is materially faster than an async bridge-backed KV store for read-heavy workloads. **The commonly quoted speed multiple is a vendor benchmark, not a measured property of your app** — this pack states no figure. If the choice is load-bearing, measure it on the read pattern your app actually has, on a named device, and record the number in the project's own docs.
- Encrypted MMKV available; use it if preferences include sensitive choices.
- iCloud KVS (iOS) / DataStore + Backup (Android) for cross-device sync of small prefs.

### Structured local data

- Pick ONE per project. Mixing Realm + SQLite + Core Data = nightmare.
- Modern picks: Realm (cross-platform), Drift (Flutter SQLite), SwiftData (iOS 17+), Room (Android), op-sqlite or WatermelonDB (RN).
- Schema migrations are NOT optional — write them up front.
- Indexes on every query path. Audit slow queries with the lib's profiler.

### Large blobs

- Files belong in `Caches/` if reproducible (will be auto-cleared by OS under pressure) or `Documents/` if user-owned.
- iOS `Caches/` exclude from backup unless you want them in iCloud.
- Android: `getCacheDir()` for ephemeral; `getFilesDir()` for persistent.
- Never store blobs in SQLite / Realm — file storage is for files.
- Image thumbnails / processed copies: persistent cache with an explicit size cap and an eviction policy. **The cap is a project budget, not a platform limit** — set it from the device storage you are willing to consume and record it in the project-specific block; a cache with no cap is the finding, not a cache with the wrong number.

## Anti-patterns

- **Auth tokens in UserDefaults / AsyncStorage / SharedPreferences** — readable by any process with file access.
- **Plain SQLite for sensitive data** — encrypt the DB (SQLCipher) OR encrypt rows.
- **One store for everything** — separate concerns; preferences ≠ business data ≠ blobs.
- **Background-only writes** — write must succeed even if app is foregrounded for 1 second.
- **No migration path** — adding a column without migration plan crashes existing users.
- **Storing user data in `Documents/` then backing it up to iCloud without user opt-in** — privacy risk if data is sensitive.

## Encryption decision tree

| Data | Encrypt? | How |
|---|---|---|
| Auth tokens | Always | Keychain / Keystore |
| PII (names, emails, addresses) | Yes if regulated (HIPAA, GDPR sensitive categories) | Encrypted MMKV / SQLCipher |
| Drafts | Optional | Plain unless they contain PII |
| Cached server responses | Usually no | Already protected by app sandbox; encrypt if response carries secrets |
| Health / financial / minor's data | Always | Encrypted store; consider hardware-backed keys |

## Testing

- App reinstall path: which data persists, which doesn't?
- Multi-device path (when sync is enabled): write on device A, read on device B.
- Migration path: app on v1.0 → v1.1 with schema change → existing data still readable.
- Storage quota: what happens when local storage fills? Graceful degradation, not crash.
- Encrypted backup: verify encrypted-at-rest in iOS backup / Android cloud backup.

## Project-specific anchors

(Phase 4.6 fills with the project's actual storage helper class, keychain access group, MMKV instance name, ORM choice, and migration path.)

## Related

- `offline-sync.md` — the mutation queue this pattern's structured-data primitive holds.
- `app-lifecycle.md` — restoration keys live in one of these primitives; process death is what makes persisting them necessary.
- `permissions.md` — what may be collected before this pattern decides where it is allowed to live.
- cross-pack `security` — the threat model for data at rest; this pattern picks the primitive, that pack judges whether it is enough.

## Sources

- B1 — Apple, `biometryCurrentSet`: "Touch ID must be available and enrolled with at least one finger, or Face ID available and enrolled. The item is invalidated if fingers are added or removed for Touch ID, or if the user re-enrolls for Face ID." https://developer.apple.com/documentation/security/secaccesscontrolcreateflags/biometrycurrentset (read 2026-08-20 via the JSON twin documented in `references/swiftui.md`).
- B2 — Android, Keystore system: "If a key only supports biometric credentials, the key is invalidated by default whenever new biometric enrollments are added. You can configure the key to remain valid when new biometric enrollments are added. To do so, pass `false` into `setInvalidatedByBiometricEnrollment()`." https://developer.android.com/privacy-and-security/keystore (read 2026-08-20).
- iOS keychain persistence across uninstall + the Android contrast: https://docs.expo.dev/versions/latest/sdk/securestore/ (read 2026-08-20).
- `androidx.security:security-crypto` deprecation, quoted above: https://developer.android.com/jetpack/androidx/releases/security.
- **Deliberately absent** — each was looked for and is not published: a maximum keychain item size; a Keystore key-count limit; a documented iOS uninstall hook; a threshold at which biometric lockout releases. Where a project needs one of these, measure it and record it as a project budget.
