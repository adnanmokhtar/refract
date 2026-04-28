---
name: native-storage
description: Pattern — secure + performant local storage on mobile. Pick the right primitive for the right data class.
kind: ai-pattern
pack: mobile
---

# Pattern: Native storage

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Mobile`.
>
> - **Storage primitives in use**: `<MMKV / AsyncStorage / Keychain / EncryptedSharedPreferences / Realm / SQLite / Core Data / Room>`
> - **Encryption strategy**: `<at-rest via system keychain / app-level encryption with key in keychain / none>`
> - **Multi-device sync layer**: `<iCloud / Firestore / Google Drive / none>`

## Decision matrix — pick the right primitive

| Data class | iOS native | Android native | RN cross | Flutter cross |
|---|---|---|---|---|
| Auth tokens, refresh tokens, biometric secrets | Keychain (kSecAttrAccessibleWhenUnlockedThisDeviceOnly) | EncryptedSharedPreferences + Keystore | `react-native-keychain` | `flutter_secure_storage` |
| User preferences (theme, locale) | UserDefaults / NSUbiquitousKeyValueStore | SharedPreferences | MMKV | shared_preferences / hive |
| Cached API responses | NSCache / FileManager | LruCache / DataStore | TanStack Query persister + MMKV | dio_cache_interceptor |
| Structured local data (offline queue, drafts) | Core Data / SwiftData | Room | WatermelonDB / Realm / SQLite (op-sqlite) | drift / sqflite / hive |
| Large blobs (images, documents) | FileManager (Documents/Caches) | InternalStorage / ExternalFiles | RNFS / FileSystem | path_provider |
| Real-time / sync state | UserDefaults + iCloud / Firestore | DataStore + Firebase | Firestore / Realm Sync | Firestore / hive_flutter |

## Hard rules per data class

### Secrets (auth tokens, biometric, OAuth refresh)

- **Always** in keychain / Keystore. Never in `UserDefaults` / `SharedPreferences` / `AsyncStorage`.
- Access control: `WhenUnlockedThisDeviceOnly` (iOS) / hardware-backed when available (Android).
- Don't log secrets — even in dev. Don't include in crash reports.
- On logout: clear keychain entries (don't leave them).
- App reinstall: keychain MAY persist (iOS — depends on access control). Delete on app uninstall via Keychain Sharing entitlement if needed.

### User preferences (small KV)

- MMKV (RN / cross-platform) is faster than AsyncStorage by 10-30x for read-heavy workloads.
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
- Image thumbnails / processed copies: persistent cache with size cap (e.g., 100MB).

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
