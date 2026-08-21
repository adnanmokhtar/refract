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
- App reinstall: keychain MAY persist (iOS — depends on access control). Delete on app uninstall via Keychain Sharing entitlement if needed.

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
