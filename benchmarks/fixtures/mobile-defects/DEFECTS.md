# Seeded defects — `mobile-defects`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `Pantry Go` — Expo SDK 57 / React Native 0.87 customer app with prebuilt `android/` + `ios/`, a bare React Native 0.82 store-picker app, a Flutter 3.47 driver app, and a Kotlin + Compose (targetSdk 35) / SwiftUI merchant tablet pair.
Lifecycle, native accessibility, performance, offline sync, store compliance, device security, platform conventions,
native bridge and app size defects — the mobile counterpart of `a11y-states` and `frontend-correctness` — seeded across
five mobile roots, plus decoys: correct siblings that look like a seeded defect and must NOT be reported.

Invocation: /mobile-audit --whole-repo
Invocation[/security-audit]: /security-audit
Stage with: --git — `/mobile-audit` reads the history for its context map, and a whole-repo run on a copy with no base
branch says so with the flag instead of leaving the diff lookup to fail.

Eval source: Track A batch 3, item 49 (FX-3). Classes follow the owning skills' own § numbering (`templates/packs/mobile/
skills/*/SKILL.md`, `templates/packs/security/skills/mobile-security-scan/SKILL.md`). FX-3 asks for lifecycle §1–§7, a11y
§1–§6, perf §1–§7, offline §1–§3, store §1–§4 + §7 and MSEC 6 × 2; this key also covers `platform-conventions-audit`
(§8, §10–§12), `native-bridge-audit` (§1–§3, §6), `app-size-scan` (§1, §2, §4, §5) and store §6, so every mobile
detector on disk owns at least two seeds. Departures, stated so a reader can audit them: the roots are `app/` (Expo),
`picker/` (bare RN — FX-3 has none), `driver/` (Flutter) and `native/android` + `native/ios`; the MSEC seeds are
configuration-level only (§2 cleartext/ATS, §3 exported components, §4 links, §5 WebView settings, §6 debuggable and
backup, §7 canary secrets) — MSEC §1 storage has a decoy (MD-DECOY-03) and no seed; app-size §3 (assets) is not
seeded because the scorer anchors on text lines and an asset seed would anchor in a binary file.

Ownership and scoring. Every row names the detector § that owns it. Two runs, two results rows, each staged in its
own copy. **`/mobile-audit`** (the `Invocation:` line) scores all 94 rows: it dispatches every mobile detector on a
whole-repo run, and its Device security row dispatches `mobile-security-scan` **when the security pack is installed** —
without it the twelve `MD-MS-*` rows are that row's `not run` and score as misses. **`/security-audit`** (the
`Invocation[/security-audit]:` line) scores the twelve `MD-MS-*` rows and the six decoys that imitate them
(`MD-DECOY-03`–`-06`, `-11`, `-20`): its whole-repo pass dispatches `mobile-security-scan` too, so those blocks name
both commands, and its findings on the other classes are UNMATCHED, never credited.

Secrets. The two secret-shaped values (`app/.env`, `native/android/app/build.gradle.kts`) are marked `CANARY` in the
file and in the value; neither has the shape of a real provider key, and the Firebase file's `API_KEY` is a
placeholder too short to be one. Nothing here is a credential.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in the
same file for their scoring windows to overlap. If you edit fixture source, re-run it.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| MD-ML-01a | `native/android/app/src/main/java/com/pantrygo/merchant/ui/NoteScreen.kt:21` | high | `/mobile-audit` | lifecycle/state-lost-on-process-death |
| MD-ML-01b | `driver/lib/main.dart:38` | medium | `/mobile-audit` | lifecycle/no-restoration-scope |
| MD-ML-02a | `native/android/app/src/main/java/com/pantrygo/merchant/sync/InventorySyncService.kt:30` | high | `/mobile-audit` | lifecycle/fgs-without-type |
| MD-ML-02b | `driver/lib/background/jobs.dart:8` | high | `/mobile-audit` | lifecycle/background-entry-not-annotated |
| MD-ML-03a | `native/ios/Merchant/ScanView.swift:25` | high | `/mobile-audit` | lifecycle/purpose-string-missing |
| MD-ML-03b | `picker/App.tsx:23` | medium | `/mobile-audit` | lifecycle/permission-at-launch-dead-end |
| MD-ML-04a | `picker/src/api/client.ts:7` | medium | `/mobile-audit` | lifecycle/network-no-timeout |
| MD-ML-04b | `driver/lib/api/api_client.dart:8` | medium | `/mobile-audit` | lifecycle/network-no-timeout |
| MD-ML-05a | `driver/lib/router.dart:23` | high | `/mobile-audit` | lifecycle/deep-link-payload-crash |
| MD-ML-05b | `native/android/app/src/main/java/com/pantrygo/merchant/MainActivity.kt:18` | high | `/mobile-audit` | lifecycle/deep-link-payload-crash |
| MD-ML-06a | `picker/src/push/notifications.ts:14` | high | `/mobile-audit` | lifecycle/push-cold-start-tap-lost |
| MD-ML-06b | `driver/lib/push/push_setup.dart:20` | medium | `/mobile-audit` | lifecycle/push-background-handler-anonymous |
| MD-ML-07a | `app/app.json:11` | critical | `/mobile-audit` | lifecycle/ota-unsigned-self-hosted |
| MD-ML-07b | `picker/package.json:21` | high | `/mobile-audit` | lifecycle/ota-retired-codepush |
| MD-MA-01a | `app/src/components/FavoriteButton.tsx:13` | medium | `/mobile-audit` | a11y/missing-name |
| MD-MA-01b | `driver/lib/screens/stop_screen.dart:22` | medium | `/mobile-audit` | a11y/missing-name |
| MD-MA-02a | `picker/src/screens/PickListRow.tsx:26` | medium | `/mobile-audit` | a11y/missing-role |
| MD-MA-02b | `native/android/app/src/main/java/com/pantrygo/merchant/ui/OrderCard.kt:16` | medium | `/mobile-audit` | a11y/missing-role |
| MD-MA-03a | `picker/src/screens/QtyStepper.tsx:37` | medium | `/mobile-audit` | a11y/target-size |
| MD-MA-03b | `driver/lib/widgets/stop_chip.dart:13` | medium | `/mobile-audit` | a11y/target-size |
| MD-MA-04a | `app/src/components/PriceTag.tsx:11` | medium | `/mobile-audit` | a11y/text-does-not-scale |
| MD-MA-04b | `native/ios/Merchant/OrderRowView.swift:12` | medium | `/mobile-audit` | a11y/text-does-not-scale |
| MD-MA-05a | `driver/lib/widgets/delivery_summary.dart:15` | high | `/mobile-audit` | a11y/interactive-child-hidden |
| MD-MA-05b | `picker/src/screens/SubstitutionToggle.tsx:10` | high | `/mobile-audit` | a11y/interactive-child-hidden |
| MD-MA-06a | `app/src/components/CartLineSwipe.tsx:13` | high | `/mobile-audit` | a11y/gesture-only-action |
| MD-MA-06b | `native/android/app/src/main/java/com/pantrygo/merchant/ui/InboxList.kt:33` | high | `/mobile-audit` | a11y/gesture-only-action |
| MD-MP-01a | `picker/src/screens/OrdersScreen.tsx:27` | high | `/mobile-audit` | perf/unvirtualized-list |
| MD-MP-01b | `native/ios/Merchant/OrdersListView.swift:9` | high | `/mobile-audit` | perf/unvirtualized-list |
| MD-MP-02a | `app/src/screens/OrderHistoryScreen.tsx:22` | medium | `/mobile-audit` | perf/list-identity |
| MD-MP-02b | `native/android/app/src/main/java/com/pantrygo/merchant/ui/OrderQueue.kt:15` | medium | `/mobile-audit` | perf/list-identity |
| MD-MP-03a | `picker/src/state/PickContext.tsx:14` | medium | `/mobile-audit` | perf/render-waste |
| MD-MP-03b | `native/android/app/src/main/java/com/pantrygo/merchant/ui/PickupBoard.kt:23` | medium | `/mobile-audit` | perf/recompose-waste |
| MD-MP-04a | `driver/lib/data/route_cache.dart:26` | medium | `/mobile-audit` | perf/main-thread-blocking |
| MD-MP-04b | `native/android/app/src/main/java/com/pantrygo/merchant/data/SettingsRepo.kt:12` | low | `/mobile-audit` | perf/main-thread-blocking |
| MD-MP-05a | `driver/lib/screens/stops_list.dart:30` | high | `/mobile-audit` | perf/full-resolution-decode |
| MD-MP-05b | `picker/src/components/ProductThumb.tsx:2` | medium | `/mobile-audit` | perf/image-library-unmaintained |
| MD-MP-06a | `native/android/app/src/main/java/com/pantrygo/merchant/MerchantApp.kt:13` | medium | `/mobile-audit` | perf/startup-work |
| MD-MP-06b | `picker/metro.config.js:12` | medium | `/mobile-audit` | perf/startup-work |
| MD-MP-07a | `app/src/screens/CheckoutScreen.tsx:17` | high | `/mobile-audit` | perf/leak-listener |
| MD-MP-07b | `driver/lib/screens/navigation_screen.dart:27` | high | `/mobile-audit` | perf/leak-timer |
| MD-OS-01a | `picker/src/offline/outbox.ts:14` | high | `/mobile-audit` | offline/ram-only-queue |
| MD-OS-01b | `driver/lib/offline/proof_outbox.dart:40` | high | `/mobile-audit` | offline/ack-before-persist |
| MD-OS-02a | `picker/src/offline/outbox.ts:32` | high | `/mobile-audit` | offline/unkeyed-replay |
| MD-OS-02b | `app/src/offline/sendOrder.ts:17` | critical | `/mobile-audit` | offline/key-regenerated-per-attempt |
| MD-OS-03a | `app/src/offline/drainOrders.ts:18` | high | `/mobile-audit` | offline/skip-on-failure-reorder |
| MD-OS-03b | `driver/lib/offline/photo_uploads.dart:31` | high | `/mobile-audit` | offline/parallel-drain |
| MD-ST-01a | `native/ios/Merchant/SessionClock.swift:5` | high | `/mobile-audit` | store/privacy-manifest-category-missing |
| MD-ST-01b | `picker/ios/Picker/AppDelegate.swift:18` | high | `/mobile-audit` | store/privacy-manifest-missing |
| MD-ST-02a | `driver/ios/Runner/Info.plist:23` | high | `/mobile-audit` | store/purpose-string-placeholder |
| MD-ST-02b | `native/android/app/src/main/AndroidManifest.xml:8` | high | `/mobile-audit` | store/restricted-permission |
| MD-ST-03a | `native/ios/Merchant/Attribution.swift:7` | high | `/mobile-audit` | store/idfa-without-att |
| MD-ST-03b | `app/src/analytics/tracking.ts:6` | high | `/mobile-audit` | store/att-without-usage-string |
| MD-ST-04a | `driver/lib/auth/onboarding.dart:16` | high | `/mobile-audit` | store/no-account-deletion |
| MD-ST-04b | `app/src/account/register.ts:12` | high | `/mobile-audit` | store/no-account-deletion |
| MD-ST-06a | `native/android/app/build.gradle.kts:15` | high | `/mobile-audit` | store/target-api-below-gate |
| MD-ST-06b | `driver/ios/Podfile:2` | high | `/mobile-audit` | store/deployment-target-below-gate |
| MD-ST-07a | `native/android/build.gradle.kts:2` | medium | `/mobile-audit` | store/16kb-agp-too-old |
| MD-ST-07b | `native/android/app/build.gradle.kts:10` | medium | `/mobile-audit` | store/16kb-ndk-flags |
| MD-MS-02a | `driver/android/app/src/main/res/xml/network_security_config.xml:4` | medium | `/mobile-audit` `/security-audit` | security/cleartext-permitted |
| MD-MS-02b | `native/ios/Merchant/Info.plist:23` | medium | `/mobile-audit` `/security-audit` | security/ats-disabled |
| MD-MS-03a | `native/android/app/src/main/AndroidManifest.xml:41` | high | `/mobile-audit` `/security-audit` | security/exported-component |
| MD-MS-03b | `picker/android/app/src/main/AndroidManifest.xml:36` | high | `/mobile-audit` `/security-audit` | security/exported-component |
| MD-MS-04a | `app/android/app/src/main/AndroidManifest.xml:34` | medium | `/mobile-audit` `/security-audit` | security/app-link-unverified |
| MD-MS-04b | `picker/src/auth/magicLink.ts:5` | high | `/mobile-audit` `/security-audit` | security/credential-on-custom-scheme |
| MD-MS-05a | `native/android/app/src/main/java/com/pantrygo/merchant/help/HelpActivity.kt:18` | high | `/mobile-audit` `/security-audit` | security/webview-file-access |
| MD-MS-05b | `app/src/screens/PromoWebView.tsx:21` | high | `/mobile-audit` `/security-audit` | security/webview-bridge-any-origin |
| MD-MS-06a | `native/android/app/src/main/AndroidManifest.xml:15` | high | `/mobile-audit` `/security-audit` | security/debuggable-release |
| MD-MS-06b | `picker/android/app/src/main/AndroidManifest.xml:10` | medium | `/mobile-audit` `/security-audit` | security/backup-without-rules |
| MD-MS-07a | `app/.env:5` | critical | `/mobile-audit` `/security-audit` | security/server-secret-in-bundle |
| MD-MS-07b | `native/android/app/build.gradle.kts:21` | critical | `/mobile-audit` `/security-audit` | security/server-secret-in-binary |
| MD-PC-08a | `picker/src/screens/PickListScreen.tsx:3` | medium | `/mobile-audit` | platform/core-safe-area-view |
| MD-PC-08b | `native/ios/Merchant/CheckoutPadView.swift:25` | high | `/mobile-audit` | platform/controls-under-safe-area |
| MD-PC-10a | `native/android/app/src/main/java/com/pantrygo/merchant/ui/EditOrderScreen.kt:24` | high | `/mobile-audit` | platform/navigate-in-composition |
| MD-PC-10b | `picker/src/auth/useSignIn.ts:12` | high | `/mobile-audit` | platform/sign-in-on-stack |
| MD-PC-11a | `native/android/app/src/main/java/com/pantrygo/merchant/ui/StockScreen.kt:16` | medium | `/mobile-audit` | platform/edge-to-edge-padding-dropped |
| MD-PC-11b | `driver/lib/screens/handover_screen.dart:33` | high | `/mobile-audit` | platform/edge-to-edge-bottom-inset |
| MD-PC-12a | `picker/android/app/src/main/java/com/pantrygo/picker/WeighBatchActivity.kt:24` | high | `/mobile-audit` | platform/predictive-back-dead-handler |
| MD-PC-12b | `driver/lib/screens/proof_screen.dart:53` | medium | `/mobile-audit` | platform/deprecated-back-api |
| MD-NB-01a | `picker/src/native/scale.ts:3` | medium | `/mobile-audit` | bridge/legacy-native-module |
| MD-NB-01b | `picker/ios/Podfile:12` | medium | `/mobile-audit` | bridge/dead-architecture-flag |
| MD-NB-02a | `picker/src/native/scale.ts:14` | high | `/mobile-audit` | bridge/contract-gap |
| MD-NB-02b | `driver/lib/native/scanner_channel.dart:12` | high | `/mobile-audit` | bridge/contract-gap |
| MD-NB-03a | `picker/android/app/src/main/java/com/pantrygo/picker/scale/ScaleBridgeModule.kt:24` | high | `/mobile-audit` | bridge/promise-never-settles |
| MD-NB-03b | `driver/ios/Runner/ScannerPlugin.swift:18` | high | `/mobile-audit` | bridge/unhandled-method-no-result |
| MD-NB-06a | `app/src/screens/OrderTrackingScreen.tsx:22` | high | `/mobile-audit` | bridge/removed-runtime-api |
| MD-NB-06b | `app/src/utils/layout.ts:2` | high | `/mobile-audit` | bridge/deep-import |
| MD-AZ-01a | `picker/android/app/build.gradle:44` | high | `/mobile-audit` | size/shrinking-off |
| MD-AZ-01b | `native/android/app/build.gradle.kts:42` | high | `/mobile-audit` | size/shrinking-off |
| MD-AZ-02a | `picker/android/app/build.gradle:30` | medium | `/mobile-audit` | size/emulator-abis-in-release |
| MD-AZ-02b | `native/android/app/build.gradle.kts:48` | medium | `/mobile-audit` | size/legacy-native-packaging |
| MD-AZ-04a | `app/src/utils/dates.ts:1` | medium | `/mobile-audit` | size/heavy-whole-library |
| MD-AZ-04b | `picker/src/utils/group.ts:1` | medium | `/mobile-audit` | size/heavy-whole-library |
| MD-AZ-05a | `picker/android/gradle.properties:13` | high | `/mobile-audit` | size/hermes-off |
| MD-AZ-05b | `driver/scripts/release.sh:12` | medium | `/mobile-audit` | size/flutter-symbols-in-binary |

Severity split: 4 critical · 52 high · 37 medium · 1 low. Total 94 seeded defects, 20 decoys. Store rows carry the store axis in their text (HARD-BLOCK / REJECTION → high, SCHEDULE → medium); the severity column is the engineering axis the scorer reads.

### Coverage by class

One row per detector §; every row carries at least two seeds.

| family | detector § | classes | seeded | ids |
|--------|------------|---------|--------|-----|
| lifecycle | `mobile-lifecycle-scan` §1 | lifecycle/state-lost-on-process-death, lifecycle/no-restoration-scope | 2 | MD-ML-01a, MD-ML-01b |
| lifecycle | `mobile-lifecycle-scan` §2 | lifecycle/fgs-without-type, lifecycle/background-entry-not-annotated | 2 | MD-ML-02a, MD-ML-02b |
| lifecycle | `mobile-lifecycle-scan` §3 | lifecycle/purpose-string-missing, lifecycle/permission-at-launch-dead-end | 2 | MD-ML-03a, MD-ML-03b |
| lifecycle | `mobile-lifecycle-scan` §4 | lifecycle/network-no-timeout | 2 | MD-ML-04a, MD-ML-04b |
| lifecycle | `mobile-lifecycle-scan` §5 | lifecycle/deep-link-payload-crash | 2 | MD-ML-05a, MD-ML-05b |
| lifecycle | `mobile-lifecycle-scan` §6 | lifecycle/push-cold-start-tap-lost, lifecycle/push-background-handler-anonymous | 2 | MD-ML-06a, MD-ML-06b |
| lifecycle | `mobile-lifecycle-scan` §7 | lifecycle/ota-unsigned-self-hosted, lifecycle/ota-retired-codepush | 2 | MD-ML-07a, MD-ML-07b |
| a11y | `mobile-a11y-scan` §1 | a11y/missing-name | 2 | MD-MA-01a, MD-MA-01b |
| a11y | `mobile-a11y-scan` §2 | a11y/missing-role | 2 | MD-MA-02a, MD-MA-02b |
| a11y | `mobile-a11y-scan` §3 | a11y/target-size | 2 | MD-MA-03a, MD-MA-03b |
| a11y | `mobile-a11y-scan` §4 | a11y/text-does-not-scale | 2 | MD-MA-04a, MD-MA-04b |
| a11y | `mobile-a11y-scan` §5 | a11y/interactive-child-hidden | 2 | MD-MA-05a, MD-MA-05b |
| a11y | `mobile-a11y-scan` §6 | a11y/gesture-only-action | 2 | MD-MA-06a, MD-MA-06b |
| perf | `mobile-perf-scan` §1 | perf/unvirtualized-list | 2 | MD-MP-01a, MD-MP-01b |
| perf | `mobile-perf-scan` §2 | perf/list-identity | 2 | MD-MP-02a, MD-MP-02b |
| perf | `mobile-perf-scan` §3 | perf/render-waste, perf/recompose-waste | 2 | MD-MP-03a, MD-MP-03b |
| perf | `mobile-perf-scan` §4 | perf/main-thread-blocking | 2 | MD-MP-04a, MD-MP-04b |
| perf | `mobile-perf-scan` §5 | perf/full-resolution-decode, perf/image-library-unmaintained | 2 | MD-MP-05a, MD-MP-05b |
| perf | `mobile-perf-scan` §6 | perf/startup-work | 2 | MD-MP-06a, MD-MP-06b |
| perf | `mobile-perf-scan` §7 | perf/leak-listener, perf/leak-timer | 2 | MD-MP-07a, MD-MP-07b |
| offline | `offline-sync-scan` §1 | offline/ram-only-queue, offline/ack-before-persist | 2 | MD-OS-01a, MD-OS-01b |
| offline | `offline-sync-scan` §2 | offline/unkeyed-replay, offline/key-regenerated-per-attempt | 2 | MD-OS-02a, MD-OS-02b |
| offline | `offline-sync-scan` §3 | offline/skip-on-failure-reorder, offline/parallel-drain | 2 | MD-OS-03a, MD-OS-03b |
| store | `store-compliance-scan` §1 | store/privacy-manifest-category-missing, store/privacy-manifest-missing | 2 | MD-ST-01a, MD-ST-01b |
| store | `store-compliance-scan` §2 | store/purpose-string-placeholder, store/restricted-permission | 2 | MD-ST-02a, MD-ST-02b |
| store | `store-compliance-scan` §3 | store/idfa-without-att, store/att-without-usage-string | 2 | MD-ST-03a, MD-ST-03b |
| store | `store-compliance-scan` §4 | store/no-account-deletion | 2 | MD-ST-04a, MD-ST-04b |
| store | `store-compliance-scan` §6 | store/target-api-below-gate, store/deployment-target-below-gate | 2 | MD-ST-06a, MD-ST-06b |
| store | `store-compliance-scan` §7 | store/16kb-agp-too-old, store/16kb-ndk-flags | 2 | MD-ST-07a, MD-ST-07b |
| security | `mobile-security-scan` §2 | security/cleartext-permitted, security/ats-disabled | 2 | MD-MS-02a, MD-MS-02b |
| security | `mobile-security-scan` §3 | security/exported-component | 2 | MD-MS-03a, MD-MS-03b |
| security | `mobile-security-scan` §4 | security/app-link-unverified, security/credential-on-custom-scheme | 2 | MD-MS-04a, MD-MS-04b |
| security | `mobile-security-scan` §5 | security/webview-file-access, security/webview-bridge-any-origin | 2 | MD-MS-05a, MD-MS-05b |
| security | `mobile-security-scan` §6 | security/debuggable-release, security/backup-without-rules | 2 | MD-MS-06a, MD-MS-06b |
| security | `mobile-security-scan` §7 | security/server-secret-in-bundle, security/server-secret-in-binary | 2 | MD-MS-07a, MD-MS-07b |
| platform | `platform-conventions-audit` §8 | platform/core-safe-area-view, platform/controls-under-safe-area | 2 | MD-PC-08a, MD-PC-08b |
| platform | `platform-conventions-audit` §10 | platform/navigate-in-composition, platform/sign-in-on-stack | 2 | MD-PC-10a, MD-PC-10b |
| platform | `platform-conventions-audit` §11 | platform/edge-to-edge-padding-dropped, platform/edge-to-edge-bottom-inset | 2 | MD-PC-11a, MD-PC-11b |
| platform | `platform-conventions-audit` §12 | platform/predictive-back-dead-handler, platform/deprecated-back-api | 2 | MD-PC-12a, MD-PC-12b |
| bridge | `native-bridge-audit` §1 | bridge/legacy-native-module, bridge/dead-architecture-flag | 2 | MD-NB-01a, MD-NB-01b |
| bridge | `native-bridge-audit` §2 | bridge/contract-gap | 2 | MD-NB-02a, MD-NB-02b |
| bridge | `native-bridge-audit` §3 | bridge/promise-never-settles, bridge/unhandled-method-no-result | 2 | MD-NB-03a, MD-NB-03b |
| bridge | `native-bridge-audit` §6 | bridge/removed-runtime-api, bridge/deep-import | 2 | MD-NB-06a, MD-NB-06b |
| size | `app-size-scan` §1 | size/shrinking-off | 2 | MD-AZ-01a, MD-AZ-01b |
| size | `app-size-scan` §2 | size/emulator-abis-in-release, size/legacy-native-packaging | 2 | MD-AZ-02a, MD-AZ-02b |
| size | `app-size-scan` §4 | size/heavy-whole-library | 2 | MD-AZ-04a, MD-AZ-04b |
| size | `app-size-scan` §5 | size/hermes-off, size/flutter-symbols-in-binary | 2 | MD-AZ-05a, MD-AZ-05b |
| **decoys (must not be reported)** | — | — | **20** | MD-DECOY-01 … MD-DECOY-20 |

---

## MD-ML-01a — The driver note is held in `remember`, lost on process death

```defect
id:       MD-ML-01a
file:     native/android/app/src/main/java/com/pantrygo/merchant/ui/NoteScreen.kt
line:     21
severity: high
command:  /mobile-audit
class:    lifecycle/state-lost-on-process-death
detector: mobile-lifecycle-scan §1
anchor:   var note by remember { mutableStateOf("") }
match:    process death|restor|rememberSaveable|saved.?state|killed|lost
```

A free-text note (gate codes, which door) is typed into state that lives only in composition: background the tablet, let the OS reclaim the process, come back from Recents, and the note is empty. Typed input is high (§1). Fix: `rememberSaveable { mutableStateOf("") }` (or a `SavedStateHandle`-backed field). Proof: the process-death restore (background, `adb shell am kill`, relaunch from Recents) — the text is gone before the fix and back after.

## MD-ML-01b — The driver app sets no `restorationScopeId`

```defect
id:       MD-ML-01b
file:     driver/lib/main.dart
line:     38
severity: medium
command:  /mobile-audit
class:    lifecycle/no-restoration-scope
detector: mobile-lifecycle-scan §1
anchor:   return MaterialApp.router(
match:    restor|process death|restorationScopeId|killed|state
```

`MaterialApp.router(…)` without `restorationScopeId`: no route, scroll position or `RestorableProperty` survives a process death, so a driver who switches to the phone dialer mid-proof and is reclaimed comes back to `/stops`. Medium: a flow position, not typed input (the proof screen's fields are their own story). Fix: `restorationScopeId: 'driver'` plus `RestorationMixin` on the multi-step screens. Proof: process-death restore.

## MD-ML-02a — `InventorySyncService` calls `startForeground` with no foreground-service type

```defect
id:       MD-ML-02a
file:     native/android/app/src/main/java/com/pantrygo/merchant/sync/InventorySyncService.kt
line:     30
severity: high
command:  /mobile-audit
class:    lifecycle/fgs-without-type
detector: mobile-lifecycle-scan §2
anchor:   startForeground(NOTIFICATION_ID, notification)
match:    foreground.?service|foregroundServiceType|FGS|type|startForeground|crash
```

The manifest declares `<service android:name=".sync.InventorySyncService" …/>` with no `foregroundServiceType`, and the app targets SDK 35: from target 34 `startForeground` throws `MissingForegroundServiceTypeException`, so every stock refresh crashes the merchant app. Fix: `foregroundServiceType="dataSync"` + `FOREGROUND_SERVICE_DATA_SYNC` + `onTimeout` (target 35 budget), or move the upload to WorkManager. Proof: tier A on the merged manifest, D — tap refresh on an API 34+ emulator.

## MD-ML-02b — The workmanager `callbackDispatcher` has no `@pragma('vm:entry-point')`

```defect
id:       MD-ML-02b
file:     driver/lib/background/jobs.dart
line:     8
severity: high
command:  /mobile-audit
class:    lifecycle/background-entry-not-annotated
detector: mobile-lifecycle-scan §2
anchor:   void callbackDispatcher() {
match:    pragma|entry.?point|vm:entry|tree.?shak|callbackDispatcher|background
```

Release builds tree-shake a top-level function nothing in Dart calls; workmanager invokes `callbackDispatcher` from native code, so without `@pragma('vm:entry-point')` the periodic proof sync never runs in release (precedents/mobile § 57). Fix: annotate it. Proof: `flutter run --release`, trigger the job (`adb shell cmd jobscheduler run -f …`) — no drain in the log before the fix.

## MD-ML-03a — The Scan tab opens the camera and `Info.plist` has no `NSCameraUsageDescription`

```defect
id:       MD-ML-03a
file:     native/ios/Merchant/ScanView.swift
line:     25
severity: high
command:  /mobile-audit
class:    lifecycle/purpose-string-missing
detector: mobile-lifecycle-scan §3
anchor:   AVCaptureDevice.default(
match:    NSCameraUsageDescription|purpose string|usage description|camera|crash|Info\.plist
```

iOS terminates the app on first camera access when the purpose string is missing: opening the Scan tab crashes the merchant iPad app. No `INFOPLIST_KEY_NSCameraUsageDescription` build setting supplies it either. High (crash on a primary tab); on the store axis it is also a rejection. Fix: a sentence naming the use. Proof: D — open Scan on a simulator or device.

## MD-ML-03b — Bluetooth permission requested at launch, with no way back from a permanent denial

```defect
id:       MD-ML-03b
file:     picker/App.tsx
line:     23
severity: medium
command:  /mobile-audit
class:    lifecycle/permission-at-launch-dead-end
detector: mobile-lifecycle-scan §3
anchor:   PermissionsAndroid.request(
match:    launch|permission|settings|BLUETOOTH|denied|request
```

The root component asks for `BLUETOOTH_CONNECT` on mount, before the picker has seen why (the scale is only used on loose-weight lines), and the picker root has no permanently-denied path anywhere (no `RESULTS.BLOCKED`, `shouldShowRequestPermissionRationale` or `openSettings`): after two denials the Weigh button fails silently. Medium (launch wall + dead end on a secondary feature). Fix: request on the Weigh tap; on permanent denial explain and deep-link to Settings. Proof: D — `launchApp: {permissions: {all: deny}}`, then weigh.

## MD-ML-04a — The staff API client has no timeout

```defect
id:       MD-ML-04a
file:     picker/src/api/client.ts
line:     7
severity: medium
command:  /mobile-audit
class:    lifecycle/network-no-timeout
detector: mobile-lifecycle-scan §4
anchor:   export const api = axios.create({
match:    timeout|hang|forever|axios|spinner
```

axios defaults to `timeout: 0`; every picker screen and the outbox flush go through this one instance, so a request into a store Wi-Fi black hole never settles and the screen spins until the app is killed. Fix: `timeout: 15_000`. Proof: I — a mock server that never answers; the call must reject within the bound.

## MD-ML-04b — The driver API client sets no connect or receive timeout

```defect
id:       MD-ML-04b
file:     driver/lib/api/api_client.dart
line:     8
severity: medium
command:  /mobile-audit
class:    lifecycle/network-no-timeout
detector: mobile-lifecycle-scan §4
anchor:   _dio = Dio(BaseOptions(
match:    timeout|connectTimeout|receiveTimeout|hang|dio
```

dio's timeouts default to none; a driver in a dead zone waits forever on the stop list and the ETA refresh. Fix: `connectTimeout` and `receiveTimeout` in `BaseOptions`. Proof: I — a test server that accepts and never answers.

## MD-ML-05a — A malformed stop link crashes the driver app

```defect
id:       MD-ML-05a
file:     driver/lib/router.dart
line:     23
severity: high
command:  /mobile-audit
class:    lifecycle/deep-link-payload-crash
detector: mobile-lifecycle-scan §5
anchor:   int.parse(state.pathParameters['id']!)
match:    parse|crash|malformed|link|tryParse|FormatException
```

`/stops/:id` comes from the dispatch SMS (an App Link); `int.parse` throws `FormatException` on `…/stops/12a` or a truncated link, and the route builder takes the app down at cold start. The hand-over route below already uses `int.tryParse` (MD-DECOY-16). Fix: `int.tryParse` and a not-found screen. Proof: D — `adb shell am start -W -a android.intent.action.VIEW -d https://drive.pantrygo.example/stops/x <pkg>`.

## MD-ML-05b — The merchant order link is parsed with `!!` and `toLong()`

```defect
id:       MD-ML-05b
file:     native/android/app/src/main/java/com/pantrygo/merchant/MainActivity.kt
line:     18
severity: high
command:  /mobile-audit
class:    lifecycle/deep-link-payload-crash
detector: mobile-lifecycle-scan §5
anchor:   getQueryParameter("order")!!.toLong()
match:    !!|toLong|crash|link|query|NumberFormat|NullPointer|parse
```

A VIEW intent without `?order=`, or with a non-numeric value, throws in `onCreate` — the verified App Link crashes the app before any UI. Fix: `getQueryParameter("order")?.toLongOrNull()` and open the board when it is null. Proof: D — `am start` with `…/orders`, `…/orders?order=abc`.

## MD-ML-06a — A tap on a pick-list push is lost when the app was not running

```defect
id:       MD-ML-06a
file:     picker/src/push/notifications.ts
line:     14
severity: high
command:  /mobile-audit
class:    lifecycle/push-cold-start-tap-lost
detector: mobile-lifecycle-scan §6
anchor:   messaging().onNotificationOpenedApp(
match:    getInitialNotification|cold.?start|killed|quit|tap|terminated
```

`onNotificationOpenedApp` only fires for a backgrounded app; with no `getInitialNotification()` the tap that launches a killed app opens the order list, not the pick list it named. High (a lost cold-start tap). Fix: read `getInitialNotification()` once at start and route it. Proof: D — the push matrix, terminated state.

## MD-ML-06b — The Firebase background handler is an anonymous closure

```defect
id:       MD-ML-06b
file:     driver/lib/push/push_setup.dart
line:     20
severity: medium
command:  /mobile-audit
class:    lifecycle/push-background-handler-anonymous
detector: mobile-lifecycle-scan §6
anchor:   FirebaseMessaging.onBackgroundMessage((message) async {
match:    background|top.?level|anonymous|entry.?point|pragma|onBackgroundMessage
```

`onBackgroundMessage` needs a top-level (or static) function annotated `@pragma('vm:entry-point')`; a closure is not invocable from the background isolate, so data-only route changes never reach the cache while the app is in the background. Fix: a top-level annotated handler. Proof: D — send a data-only message to a backgrounded release build.

## MD-ML-07a — Self-hosted Expo updates with no code signing

```defect
id:       MD-ML-07a
file:     app/app.json
line:     11
severity: critical
command:  /mobile-audit
class:    lifecycle/ota-unsigned-self-hosted
detector: mobile-lifecycle-scan §7
anchor:   "url": "https://updates.pantrygo.example/api/manifest",
match:    sign|codeSigning|certificate|OTA|update|unsigned
```

The update channel is a self-hosted server and `app.json` carries no `codeSigningCertificate` / `codeSigningMetadata`: whoever controls that server or its TLS edge can ship JavaScript that every installed customer app runs. Critical per the skill (unsigned code from a self-hosted server, CWE-494). Fix: generate a key pair, set `codeSigningCertificate` + `codeSigningMetadata`, sign on publish. Proof: D — a tampered update must be rejected.

## MD-ML-07b — The picker ships `react-native-code-push` with no self-hosted server

```defect
id:       MD-ML-07b
file:     picker/package.json
line:     21
severity: high
command:  /mobile-audit
class:    lifecycle/ota-retired-codepush
detector: mobile-lifecycle-scan §7
anchor:   "react-native-code-push": "9.0.1"
match:    CodePush|retired|App Center|server|OTA
```

App Center CodePush was retired on 2025-03-31 and no `CodePushServerURL` is configured, so `codePush(…)(App)` checks a service that no longer answers: no fix can reach the store devices over the air. Fix: a self-hosted CodePush server or EAS Update / hot-updater. Proof: D — a resume never fetches an update; the request fails in the log.

## MD-MA-01a — The favourite heart is an icon-only button with no label

```defect
id:       MD-MA-01a
file:     app/src/components/FavoriteButton.tsx
line:     13
severity: medium
command:  /mobile-audit
class:    a11y/missing-name
detector: mobile-a11y-scan §1
anchor:   <Pressable
match:    label|name|icon|heart|4\.1\.2|accessib
```

The `Pressable` has a role but its only child is an `Ionicons` heart: TalkBack and VoiceOver read "button" (4.1.2 A). Medium: favouriting is not a primary action. Fix: `accessibilityLabel={isFavorite ? 'Remove from favourites' : 'Add to favourites'}`. Proof: RNTL `getByRole('button', { name: /favourite/i })` fails.

## MD-MA-01b — The call-customer `IconButton` has no tooltip

```defect
id:       MD-MA-01b
file:     driver/lib/screens/stop_screen.dart
line:     22
severity: medium
command:  /mobile-audit
class:    a11y/missing-name
detector: mobile-a11y-scan §1
anchor:   IconButton(icon: const Icon(Icons.call), onPressed: _callCustomer)
match:    tooltip|label|name|semantic|call|4\.1\.2
```

A Flutter `IconButton` takes its accessible name from `tooltip`; without it the action is announced as "button" (4.1.2 A). The torch button next to it has one. Fix: `tooltip: 'Call customer'`. Proof: `meetsGuideline(labeledTapTargetGuideline)` fails.

## MD-MA-02a — The "Picked" touchable has a label and no role

```defect
id:       MD-MA-02a
file:     picker/src/screens/PickListRow.tsx
line:     26
severity: medium
command:  /mobile-audit
class:    a11y/missing-role
detector: mobile-a11y-scan §2
anchor:   <TouchableOpacity
match:    role|button|trait|4\.1\.2|accessibilityRole
```

Screen readers announce "Mark Bananas picked" with no "button", so pickers using TalkBack do not know it acts (4.1.2 A). Fix: `accessibilityRole="button"`. Proof: RNTL `getByRole('button', { name: /picked/ })` fails.

## MD-MA-02b — The pickup card is `clickable` with no role

```defect
id:       MD-MA-02b
file:     native/android/app/src/main/java/com/pantrygo/merchant/ui/OrderCard.kt
line:     16
severity: medium
command:  /mobile-audit
class:    a11y/missing-role
detector: mobile-a11y-scan §2
anchor:   .clickable { onOpen(order.id) }
match:    role|Role\.Button|button|clickable|4\.1\.2
```

`Modifier.clickable { … }` without `role = Role.Button` (or `onClickLabel`): TalkBack reads the card text with no hint that double-tap opens the order (4.1.2 A). Fix: `clickable(role = Role.Button, onClickLabel = "Open order") { … }`. Proof: Compose `assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))` fails.

## MD-MA-03a — The quantity stepper buttons are 32 × 32

```defect
id:       MD-MA-03a
file:     picker/src/screens/QtyStepper.tsx
line:     37
severity: medium
command:  /mobile-audit
class:    a11y/target-size
detector: mobile-a11y-scan §3
anchor:   step: { width: 32, height: 32
match:    target|touch|size|32|44|48|2\.5\.8
```

Both `−` and `+` use the 32 × 32 `step` style, below 48 dp / 44 pt (THR-A11Y), and they sit next to each other; pickers wear gloves. Medium. Fix: `minWidth: 48, minHeight: 48` (a `hitSlop` alone does not change the measured frame). Proof: ATF touch-target check on the pick list.

## MD-MA-03b — Stop tags shrink their tap target below 48 dp

```defect
id:       MD-MA-03b
file:     driver/lib/widgets/stop_chip.dart
line:     13
severity: medium
command:  /mobile-audit
class:    a11y/target-size
detector: mobile-a11y-scan §3
anchor:   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap
match:    target|shrinkWrap|touch|48|size|2\.5\.8
```

`MaterialTapTargetSize.shrinkWrap` with `VisualDensity.compact` drops the chips below Material's 48 dp padding. Fix: the default `padded`. Proof: `meetsGuideline(androidTapTargetGuideline)` fails.

## MD-MA-04a — Prices ignore the system text size

```defect
id:       MD-MA-04a
file:     app/src/components/PriceTag.tsx
line:     11
severity: medium
command:  /mobile-audit
class:    a11y/text-does-not-scale
detector: mobile-a11y-scan §4
anchor:   <Text style={styles.price} allowFontScaling={false}>
match:    font|scal|text size|dynamic type|1\.4\.4|allowFontScaling
```

`allowFontScaling={false}` on the price on every product card: at 200 % the name grows and the price stays 16 pt (1.4.4 AA). Unlike the monogram (MD-DECOY-09) a price is body text. Fix: drop the prop, or `maxFontSizeMultiplier={2}`. Proof: largest-size render.

## MD-MA-04b — The pickup row subtitle is a fixed 13 pt

```defect
id:       MD-MA-04b
file:     native/ios/Merchant/OrderRowView.swift
line:     12
severity: medium
command:  /mobile-audit
class:    a11y/text-does-not-scale
detector: mobile-a11y-scan §4
anchor:   .font(.system(size: 13))
match:    font|dynamic type|scal|size|1\.4\.4|text style
```

`.font(.system(size: 13))` does not follow Dynamic Type; the bag count and due time stay small at the accessibility sizes (1.4.4 AA). Fix: `.font(.footnote)` or `@ScaledMetric`. Proof: `performAccessibilityAudit(for: .dynamicType)`.

## MD-MA-05a — "Report a problem" is hidden from screen readers

```defect
id:       MD-MA-05a
file:     driver/lib/widgets/delivery_summary.dart
line:     15
severity: high
command:  /mobile-audit
class:    a11y/interactive-child-hidden
detector: mobile-a11y-scan §5
anchor:   child: ExcludeSemantics(
match:    ExcludeSemantics|hidden|unreachable|report|button|semantic
```

`ExcludeSemantics` wraps the whole row to read it as one label, and the row holds a `TextButton`: the report action is unreachable with TalkBack or VoiceOver (1.3.1, 4.1.2 A). High (a hidden control). Fix: merge only the text (`MergeSemantics` / `Semantics(label:)` on the `Text`), leave the button in the tree. Proof: Flutter semantics test finds no tap action for the button.

## MD-MA-05b — The substitution switch is swallowed by an `accessible` row

```defect
id:       MD-MA-05b
file:     picker/src/screens/SubstitutionToggle.tsx
line:     10
severity: high
command:  /mobile-audit
class:    a11y/interactive-child-hidden
detector: mobile-a11y-scan §5
anchor:   <View accessible style={styles.row}>
match:    accessible|switch|hidden|group|unreachable|nested
```

`<View accessible>` turns the row into one element; the `Switch` inside it can no longer be focused or toggled with a screen reader. Fix: drop `accessible` and give the `Switch` the label (`accessibilityLabel="Substitute if out of stock"`). Proof: RNTL `getByRole('switch')` fails; lint `no-nested-touchables`.

## MD-MA-06a — Removing a basket line is swipe-only

```defect
id:       MD-MA-06a
file:     app/src/components/CartLineSwipe.tsx
line:     13
severity: high
command:  /mobile-audit
class:    a11y/gesture-only-action
detector: mobile-a11y-scan §6
anchor:   <Swipeable
match:    swipe|gesture|accessibilityActions|action|2\.5\.1|remove
```

The basket row exposes Remove only behind a swipe and declares no `accessibilityActions`; the basket screen offers no other remove path. High (the only path; 2.5.1 A). The saved-address row does it right (MD-DECOY-19). Fix: `accessibilityActions={[{ name: 'delete', label: 'Remove' }]}` + `onAccessibilityAction`. Proof: RNTL fires the action and the line is removed.

## MD-MA-06b — Archiving a head-office message is swipe-only

```defect
id:       MD-MA-06b
file:     native/android/app/src/main/java/com/pantrygo/merchant/ui/InboxList.kt
line:     33
severity: high
command:  /mobile-audit
class:    a11y/gesture-only-action
detector: mobile-a11y-scan §6
anchor:   SwipeToDismissBox(state = state
match:    swipe|gesture|custom.?action|semantic|archive|2\.5\.1
```

`SwipeToDismissBox` with no `Modifier.semantics { customActions = … }`: TalkBack users cannot archive. Fix: a custom action "Archive". Proof: `performSemanticsAction` on `CustomActions` finds none.

## MD-MP-01a — Today's orders render in a `ScrollView` with `.map`

```defect
id:       MD-MP-01a
file:     picker/src/screens/OrdersScreen.tsx
line:     27
severity: high
command:  /mobile-audit
class:    perf/unvirtualized-list
detector: mobile-perf-scan §1
anchor:   <ScrollView contentContainerStyle={styles.list}>
match:    virtuali|ScrollView|FlatList|FlashList|unbounded|render.*all|list
```

The list comes from `/store/orders/today` — several hundred on a Saturday — and every card mounts at once. High (remote, unbounded). Fix: `FlatList` / FlashList with `keyExtractor`. Proof: Reassure mount time with 200 rows.

## MD-MP-01b — Pickups render in an eager `VStack` inside a `ScrollView`

```defect
id:       MD-MP-01b
file:     native/ios/Merchant/OrdersListView.swift
line:     9
severity: high
command:  /mobile-audit
class:    perf/unvirtualized-list
detector: mobile-perf-scan §1
anchor:   ScrollView {
match:    LazyVStack|List|virtuali|eager|VStack|ScrollView
```

`ScrollView { VStack { ForEach(store.orders) … } }` builds every row up front. Fix: `LazyVStack` or `List`. Proof: Instruments SwiftUI template, row body count with 300 orders.

## MD-MP-02a — Order history `FlatList` has no `keyExtractor`

```defect
id:       MD-MP-02a
file:     app/src/screens/OrderHistoryScreen.tsx
line:     22
severity: medium
command:  /mobile-audit
class:    perf/list-identity
detector: mobile-perf-scan §2
anchor:   <FlatList
match:    keyExtractor|key|identity|index
```

Without `keyExtractor` the list falls back to index keys; with infinite pages appended and a status that changes under the row, rows re-mount and pressed state lands on the wrong order. Fix: `keyExtractor={(o) => o.id}`. Proof: a test that prepends an order and asserts the row identity.

## MD-MP-02b — Stateful queue rows with no `key`

```defect
id:       MD-MP-02b
file:     native/android/app/src/main/java/com/pantrygo/merchant/ui/OrderQueue.kt
line:     15
severity: medium
command:  /mobile-audit
class:    perf/list-identity
detector: mobile-perf-scan §2
anchor:   items(orders) { order ->
match:    key|items|identity|remember|expanded|wrong
```

Each row keeps `expanded` in `remember`, and the queue is re-sorted as orders arrive; with no `key` the expanded state stays at the position, not the order. Fix: `items(orders, key = { it.id })`. Proof: insert an order above an expanded row; the wrong card is expanded.

## MD-MP-03a — The pick context value is a new object every render

```defect
id:       MD-MP-03a
file:     picker/src/state/PickContext.tsx
line:     14
severity: medium
command:  /mobile-audit
class:    perf/render-waste
detector: mobile-perf-scan §3
anchor:   <PickContext.Provider value={{ picked, markPicked }}>
match:    Provider|context|re.?render|memo|inline|value
```

React Native 0.82 with no React Compiler: `value={{ picked, markPicked }}` re-renders every consumer — every row of the pick list — on each provider render. Fix: `useMemo` / `useCallback`. Proof: Reassure `measureRenders` count.

## MD-MP-03b — The pickup board re-sorts every order on every clock tick

```defect
id:       MD-MP-03b
file:     native/android/app/src/main/java/com/pantrygo/merchant/ui/PickupBoard.kt
line:     23
severity: medium
command:  /mobile-audit
class:    perf/recompose-waste
detector: mobile-perf-scan §3
anchor:   val byDue = orders.sortedBy { it.dueAt }
match:    sort|remember|recompos|derived|allocation
```

The header clock recomposes the board every second and `orders.sortedBy` runs in composition each time, handing a new list to `OrderQueue`. Fix: `remember(orders) { orders.sortedBy { it.dueAt } }`, or move the clock into its own composable. Proof: a recomposition counter on `OrderQueue`.

## MD-MP-04a — The cached route is read and decoded synchronously on the UI isolate

```defect
id:       MD-MP-04a
file:     driver/lib/data/route_cache.dart
line:     26
severity: medium
command:  /mobile-audit
class:    perf/main-thread-blocking
detector: mobile-perf-scan §4
anchor:   final raw = file.readAsStringSync();
match:    sync|isolate|main|UI thread|block|jank|readAsString
```

`existsSync` + `readAsStringSync` + `jsonDecode` of 60–90 stops with geometry on the path that opens the stop list. Fix: `await file.readAsString()` and `Isolate.run(() => jsonDecode(raw))`. Proof: `flutter drive --profile` missed frames on open.

## MD-MP-04b — Printer choice saved with `commit()` from a click handler

```defect
id:       MD-MP-04b
file:     native/android/app/src/main/java/com/pantrygo/merchant/data/SettingsRepo.kt
line:     12
severity: low
command:  /mobile-audit
class:    perf/main-thread-blocking
detector: mobile-perf-scan §4
anchor:   prefs.edit().putString("default_printer", id).commit()
match:    commit|apply|main|disk|StrictMode|block
```

`commit()` writes to disk synchronously on the main thread. Low: one small write per settings change. Fix: `apply()` (or DataStore). Proof: StrictMode `detectDiskWrites().penaltyDeath()` in an instrumented test.

## MD-MP-05a — Door photos decode at full size in a 56 px list tile

```defect
id:       MD-MP-05a
file:     driver/lib/screens/stops_list.dart
line:     30
severity: high
command:  /mobile-audit
class:    perf/full-resolution-decode
detector: mobile-perf-scan §5
anchor:   leading: Image.network(
match:    cacheWidth|decode|resolution|memory|image|resize
```

`Image.network` with no `cacheWidth` / `cacheHeight` decodes each customer photo at camera resolution for a 56 px avatar, for every stop. High (a list). Fix: `cacheWidth: (56 * devicePixelRatio).round()`. Proof: `debugInvertOversizedImages = true`.

## MD-MP-05b — Pick-list thumbnails use the unmaintained `react-native-fast-image`

```defect
id:       MD-MP-05b
file:     picker/src/components/ProductThumb.tsx
line:     2
severity: medium
command:  /mobile-audit
class:    perf/image-library-unmaintained
detector: mobile-perf-scan §5
anchor:   import FastImage from 'react-native-fast-image';
match:    fast.?image|unmaintained|expo-image|image|decode
```

The library is unmaintained and its New-Architecture support comes from forks; the 1200 px supplier originals are decoded for a 56 px thumbnail on every row. Fix: `expo-image` (or a maintained fork, publisher verified) with a sized source. Proof: heap bitmap total before and after scrolling a 200-line pick list.

## MD-MP-06a — Five SDK starts run in `Application.onCreate`

```defect
id:       MD-MP-06a
file:     native/android/app/src/main/java/com/pantrygo/merchant/MerchantApp.kt
line:     13
severity: medium
command:  /mobile-audit
class:    perf/startup-work
detector: mobile-perf-scan §6
anchor:   class MerchantApp : Application()
match:    startup|Application|onCreate|init|launch|cold start
```

Firebase, Sentry, Datadog, RUM and a native library load all run before the first frame of the merchant app. Fix: App Startup / lazy holders, RUM after the first frame. Proof: Macrobenchmark `StartupTimingMetric`, `CompilationMode.Partial()`.

## MD-MP-06b — The picker bundle disables inline requires

```defect
id:       MD-MP-06b
file:     picker/metro.config.js
line:     12
severity: medium
command:  /mobile-audit
class:    perf/startup-work
detector: mobile-perf-scan §6
anchor:   inlineRequires: false,
match:    inlineRequires|inline|startup|require|metro
```

`inlineRequires: false` makes Metro evaluate every module at start-up, including the lodash and image modules the first screen never uses. Fix: `inlineRequires: true`. Proof: cold-start metric, release build.

## MD-MP-07a — Checkout adds two keyboard listeners and never removes them

```defect
id:       MD-MP-07a
file:     app/src/screens/CheckoutScreen.tsx
line:     17
severity: high
command:  /mobile-audit
class:    perf/leak-listener
detector: mobile-perf-scan §7
anchor:   Keyboard.addListener('keyboardDidShow'
match:    listener|remove|leak|cleanup|unmount|Keyboard
```

The effect returns no cleanup: each visit to checkout adds another pair of listeners that call `setState` on an unmounted screen. High (grows per navigation). Fix: keep the subscriptions and `return () => { show.remove(); hide.remove(); }`. Proof: Jest — listener count is zero after unmount.

## MD-MP-07b — The ETA timer is never cancelled

```defect
id:       MD-MP-07b
file:     driver/lib/screens/navigation_screen.dart
line:     27
severity: high
command:  /mobile-audit
class:    perf/leak-timer
detector: mobile-perf-scan §7
anchor:   _etaTimer = Timer.periodic(
match:    cancel|dispose|timer|leak|periodic
```

`Timer.periodic` keeps firing after the screen is popped — a GPS read and two API calls every 30 s per visit. Fix: `_etaTimer?.cancel()` in `dispose`. Proof: `LeakTesting.enable()` / a widget test that pops the route and counts calls.

## MD-OS-01a — Queued picks live only in memory

```defect
id:       MD-OS-01a
file:     picker/src/offline/outbox.ts
line:     14
severity: high
command:  /mobile-audit
class:    offline/ram-only-queue
detector: offline-sync-scan §1
anchor:   const pendingWrites: PickWrite[] = [];
match:    memory|durable|persist|lost|queue|outbox|kill
```

The row turns green as soon as a pick is queued, and the queue is a module-level array: if the OS kills the app during a Wi-Fi drop, the picks are gone and the customer is short. Fix: write-through to a durable store before the row turns green. Proof: offline kill — airplane mode, pick, background, `am kill`, relaunch, network on: 0 picks reach the server.

## MD-OS-01b — Proof of delivery is acknowledged before the write lands

```defect
id:       MD-OS-01b
file:     driver/lib/offline/proof_outbox.dart
line:     40
severity: high
command:  /mobile-audit
class:    offline/ack-before-persist
detector: offline-sync-scan §1
anchor:   _box.put(proof.id, proof.toJson());
match:    await|persist|acknowledg|put|before|durable
```

`_box.put` is not awaited and `onSaved()` (which shows "Delivered" and leaves the screen) runs right after it. Fix: `await _box.put(…)` and acknowledge after. Proof: offline kill with the process killed immediately after the tap.

## MD-OS-02a — Queued picks are replayed with no idempotency key

```defect
id:       MD-OS-02a
file:     picker/src/offline/outbox.ts
line:     32
severity: high
command:  /mobile-audit
class:    offline/unkeyed-replay
detector: offline-sync-scan §2
anchor:   await api.post(
match:    idempoten|key|replay|duplicate|twice|retry
```

Each pick adds its quantity to the line's total; when the response is lost the row stays at the head and is POSTed again, so the server counts it twice and the customer is charged for double. Fix: a key minted at enqueue (the write's `id`), stored with the row and sent as `Idempotency-Key`. Proof: lost-response replay — the server commits the first POST and drops the response.

## MD-OS-02b — Placing an order mints a new idempotency key on every retry

```defect
id:       MD-OS-02b
file:     app/src/offline/sendOrder.ts
line:     17
severity: critical
command:  /mobile-audit
class:    offline/key-regenerated-per-attempt
detector: offline-sync-scan §2
anchor:   'Idempotency-Key': uuid()
match:    idempoten|key|attempt|retry|duplicate|order
```

The key is created inside the retry loop, on the send line: a lost response followed by a retry sends a different key, and the server places a second order. Critical (orders and payment). The queued path does it right (MD-DECOY-10). Fix: mint the key once per checkout before the loop. Proof: lost-response replay — 2 orders before the fix, 1 after.

## MD-OS-03a — The order drain skips a failed row and sends the next one

```defect
id:       MD-OS-03a
file:     app/src/offline/drainOrders.ts
line:     18
severity: high
command:  /mobile-audit
class:    offline/skip-on-failure-reorder
detector: offline-sync-scan §3
anchor:   } catch (error) {
match:    skip|continue|order|depend|reorder|head
```

Rows for one order depend on each other (`create`, then `amend` or `cancel`), but a failure `continue`s to the next row: the amend is sent before the create exists, fails, and later the create succeeds without the amendment. Fix: strict order per order id — stop the drain for that order on failure. Proof: offline kill with a poisoned head (the mock answers 503 for row 1).

## MD-OS-03b — Door photos are uploaded in parallel, then the store is cleared

```defect
id:       MD-OS-03b
file:     driver/lib/offline/photo_uploads.dart
line:     31
severity: high
command:  /mobile-audit
class:    offline/parallel-drain
detector: offline-sync-scan §3
anchor:   await Future.wait(_uploadQueue.map(
match:    parallel|order|Future\.wait|concurren|sequen
```

The queue is sorted oldest first because support shows the last photo of a stop, then sent with `Future.wait`: the server receives them in any order, and one failure rejects the batch after others committed. Fix: upload in order, delete each row after its upload. Proof: a mock that delays the first upload — the server's last photo is wrong.

## MD-ST-01a — `systemUptime` is used and the privacy manifest declares only UserDefaults

```defect
id:       MD-ST-01a
file:     native/ios/Merchant/SessionClock.swift
line:     5
severity: high
command:  /mobile-audit
class:    store/privacy-manifest-category-missing
detector: store-compliance-scan §1
anchor:   private static var lastActivity = ProcessInfo.processInfo.systemUptime
match:    privacy manifest|SystemBootTime|required.?reason|xcprivacy|systemUptime
```

`ProcessInfo.systemUptime` is a required-reason API (SystemBootTime, 35F9.1 fits here); `PrivacyInfo.xcprivacy` lists only `NSPrivacyAccessedAPICategoryUserDefaults`. Axis: HARD-BLOCK (G4). Fix: add the category with 35F9.1. Probe: `plutil -p` the archived manifest; Organizer privacy report.

## MD-ST-01b — The picker iOS app ships no privacy manifest

```defect
id:       MD-ST-01b
file:     picker/ios/Picker/AppDelegate.swift
line:     18
severity: high
command:  /mobile-audit
class:    store/privacy-manifest-missing
detector: store-compliance-scan §1
anchor:   if UserDefaults.standard.bool(forKey: "resetOnNextLaunch")
match:    privacy manifest|PrivacyInfo|xcprivacy|UserDefaults|required.?reason
```

App code reads `UserDefaults` (and React Native itself uses required-reason APIs) and `ios/Picker/` has no `PrivacyInfo.xcprivacy` — the React Native template's file was removed. Axis: HARD-BLOCK (G4). Fix: restore the manifest with `CA92.1` and the reasons React Native needs. Probe: the archive has no manifest.

## MD-ST-02a — The location purpose string is `TODO`

```defect
id:       MD-ST-02a
file:     driver/ios/Runner/Info.plist
line:     23
severity: high
command:  /mobile-audit
class:    store/purpose-string-placeholder
detector: store-compliance-scan §2
anchor:   <key>NSLocationWhenInUseUsageDescription</key>
match:    purpose|TODO|placeholder|usage description|location|5\.1\.1
```

App Review rejects purpose strings that do not describe the use (5.1.1); the driver is shown "TODO" when the app asks for location. Axis: REJECTION. Fix: "Shares your location with dispatch while you are on a delivery route." Probe: `plutil -p` the built Info.plist.

## MD-ST-02b — The merchant app declares `QUERY_ALL_PACKAGES` to find one companion app

```defect
id:       MD-ST-02b
file:     native/android/app/src/main/AndroidManifest.xml
line:     8
severity: high
command:  /mobile-audit
class:    store/restricted-permission
detector: store-compliance-scan §2
anchor:   android.permission.QUERY_ALL_PACKAGES
match:    QUERY_ALL_PACKAGES|package visibility|queries|restricted|declaration
```

Play allows broad package visibility only for core use (G13); detecting the card-terminal companion app is a `<queries><package …/></queries>` case. Axis: REJECTION. Fix: a `<queries>` element naming the terminal packages. Probe: `aapt2 dump badging <apk> | rg uses-permission`.

## MD-ST-03a — The merchant app reads the IDFA with no App Tracking Transparency request

```defect
id:       MD-ST-03a
file:     native/ios/Merchant/Attribution.swift
line:     7
severity: high
command:  /mobile-audit
class:    store/idfa-without-att
detector: store-compliance-scan §3
anchor:   ASIdentifierManager.shared().advertisingIdentifier
match:    ATT|tracking|IDFA|advertisingIdentifier|AppTrackingTransparency|consent
```

The install is reported to a recruitment agency with the IDFA and no `ATTrackingManager` request anywhere in the root (5.1.2(i)); without consent the IDFA is zeros on iOS 14.5+, and reading it for tracking without asking is a rejection. Axis: REJECTION. Fix: request ATT first (with a usage string) or drop the IDFA. Probe: D — fresh install, tracking denied, proxy shows the request.

## MD-ST-03b — ATT is requested and the prebuilt `Info.plist` has no `NSUserTrackingUsageDescription`

```defect
id:       MD-ST-03b
file:     app/src/analytics/tracking.ts
line:     6
severity: high
command:  /mobile-audit
class:    store/att-without-usage-string
detector: store-compliance-scan §3
anchor:   await requestTrackingPermissionsAsync()
match:    NSUserTrackingUsageDescription|usage|purpose|ATT|tracking|crash
```

`expo-tracking-transparency` is not in `app.json` plugins and `ios/` is committed, so nothing adds the usage string: the request crashes on iOS and App Review rejects it. Axis: REJECTION (and a crash). Fix: the plugin with `userTrackingPermission`, then re-prebuild (or the key in `ios/PantryGo/Info.plist`). Probe: `plutil -p` the built Info.plist.

## MD-ST-04a — Drivers can create an account in the app and never delete it

```defect
id:       MD-ST-04a
file:     driver/lib/auth/onboarding.dart
line:     16
severity: high
command:  /mobile-audit
class:    store/no-account-deletion
detector: store-compliance-scan §4
anchor:   Future<void> signUpDriver(
match:    delet|account|5\.1\.1\(v\)|remove account|close account
```

Self-serve registration with no in-app deletion path (G7 5.1.1(v), G8 Play). Axis: REJECTION. Fix: Settings → Delete account → server delete of the account record; the web deletion link in Data safety. Probe: D — the store flow walk.

## MD-ST-04b — Customers can create an account in the app and never delete it

```defect
id:       MD-ST-04b
file:     app/src/account/register.ts
line:     12
severity: high
command:  /mobile-audit
class:    store/no-account-deletion
detector: store-compliance-scan §4
anchor:   export async function signUp(
match:    delet|account|5\.1\.1\(v\)|remove account|close account
```

Onboarding calls `POST /auth/register`; nothing in the customer app deletes an account. Axis: REJECTION (G7, G8). Fix: an in-app deletion flow. Probe: D — the store flow walk.

## MD-ST-06a — The merchant Android app targets API 35

```defect
id:       MD-ST-06a
file:     native/android/app/build.gradle.kts
line:     15
severity: high
command:  /mobile-audit
class:    store/target-api-below-gate
detector: store-compliance-scan §6
anchor:   targetSdk = 35
match:    targetSdk|target API|36|35|G1|API level
```

Play requires API 36 for new apps and updates since 2026-08-31 (extension on request to 2026-11-01, per store-compliance-scan's G1 row): updates to the merchant app are refused unless the extension was granted, and then from 2026-11-01. Axis: HARD-BLOCK. Fix: target 36 — and plan its Android 16 behaviour changes (precedents/mobile § 52). Probe: `aapt2 dump badging <apk> | rg targetSdkVersion`.

## MD-ST-06b — The driver Podfile pins iOS 12 for its pods

```defect
id:       MD-ST-06b
file:     driver/ios/Podfile
line:     2
severity: high
command:  /mobile-audit
class:    store/deployment-target-below-gate
detector: store-compliance-scan §6
anchor:   platform :ios, '12.0'
match:    deployment target|iOS 1[23]|platform|MinimumOSVersion|Podfile|G3
```

Uploads must target iOS 13 or later since 2026-09-09 (G3); the Podfile sets the pod targets to 12.0 while the app target says 13.0. Axis: HARD-BLOCK. Fix: `platform :ios, '13.0'` (Flutter 3.47 needs 13+). Probe: `plutil -p` the archive's frameworks for `MinimumOSVersion`.

## MD-ST-07a — AGP 8.3.2 cannot align native libraries for 16 KB pages

```defect
id:       MD-ST-07a
file:     native/android/build.gradle.kts
line:     2
severity: medium
command:  /mobile-audit
class:    store/16kb-agp-too-old
detector: store-compliance-scan §7
anchor:   id("com.android.application") version "8.3.2"
match:    16 ?KB|page size|AGP|8\.5|align
```

The merchant app ships native code (`labelprint`), and AGP below 8.5.1 does not zip-align uncompressed `.so` files at 16 KB. Axis: SCHEDULE → HARD-BLOCK on 2027-02-01 (G16). Fix: AGP ≥ 8.5.1. Probe: `zipalign -c -P 16 -v 4 <apk>`.

## MD-ST-07b — NDK r27 builds `labelprint` without the 16 KB page-size flag

```defect
id:       MD-ST-07b
file:     native/android/app/build.gradle.kts
line:     10
severity: medium
command:  /mobile-audit
class:    store/16kb-ndk-flags
detector: store-compliance-scan §7
anchor:   ndkVersion = "27.1.12297006"
match:    16 ?KB|page size|NDK|max-page-size|align|r28
```

NDK r28 aligns by default; r27 needs `-Wl,-z,max-page-size=16384`, and `CMakeLists.txt` does not pass it. Axis: SCHEDULE → HARD-BLOCK (G16). Fix: NDK r28+ or the linker flag. Probe: `llvm-objdump -p liblabelprint.so | rg LOAD` (`align 2**14`).

## MD-MS-02a — The driver app permits cleartext for every host

```defect
id:       MD-MS-02a
file:     driver/android/app/src/main/res/xml/network_security_config.xml
line:     4
severity: medium
command:  /mobile-audit /security-audit
class:    security/cleartext-permitted
detector: mobile-security-scan §2
anchor:   <base-config cleartextTrafficPermitted="true">
match:    cleartext|http|network.?security|TLS|plain
```

A `<base-config>` opening for one tile server lets every request in the app go over HTTP, including the API if a URL is ever mistyped; a network attacker on the same Wi-Fi reads and rewrites it. Medium (no credential observed over HTTP). Fix: a `<domain-config>` for the tile host only, or HTTPS tiles. Proof: D — mitmproxy with no CA installed.

## MD-MS-02b — App Transport Security is switched off globally on the merchant iPad

```defect
id:       MD-MS-02b
file:     native/ios/Merchant/Info.plist
line:     23
severity: medium
command:  /mobile-audit /security-audit
class:    security/ats-disabled
detector: mobile-security-scan §2
anchor:   <key>NSAllowsArbitraryLoads</key>
match:    ATS|App Transport|ArbitraryLoads|cleartext|http
```

`NSAllowsArbitraryLoads = YES` with no inert sibling key: every connection may use HTTP or weak TLS. Medium (no observed HTTP use; App Review also asks for a justification — store-compliance-scan's). Fix: remove it, or a per-domain `NSExceptionDomains` entry. Proof: D — mitmproxy with no CA.

## MD-MS-03a — Any app on the tablet can replace the back-office token

```defect
id:       MD-MS-03a
file:     native/android/app/src/main/AndroidManifest.xml
line:     41
severity: high
command:  /mobile-audit /security-audit
class:    security/exported-component
detector: mobile-security-scan §3
anchor:   android:name=".push.TokenRefreshReceiver"
match:    export|receiver|permission|broadcast|another app|token
```

`TokenRefreshReceiver` is exported with no permission and writes the token it receives: another app can broadcast `REFRESH_TOKEN` with its own token and the tablet starts acting under the attacker's back-office session. High. Fix: `android:exported="false"`, or a `signature`-level permission matching the MDM agent. Proof: D — `adb shell am broadcast -a com.pantrygo.merchant.action.REFRESH_TOKEN --es token canary`.

## MD-MS-03b — Any app can start a staff sync for any store

```defect
id:       MD-MS-03b
file:     picker/android/app/src/main/AndroidManifest.xml
line:     36
severity: high
command:  /mobile-audit /security-audit
class:    security/exported-component
detector: mobile-security-scan §3
anchor:   android:name=".sync.PickSyncService"
match:    export|service|permission|another app|intent
```

`PickSyncService` is exported with no permission and runs a sync with the signed-in picker's credentials for the `storeId` the caller passes. High. Fix: not exported, or a `signature` permission shared with the hand-over kiosk app. Proof: D — `adb shell am startservice -n …/.sync.PickSyncService --es storeId other`.

## MD-MS-04a — Order links are an unverified https filter

```defect
id:       MD-MS-04a
file:     app/android/app/src/main/AndroidManifest.xml
line:     34
severity: medium
command:  /mobile-audit /security-audit
class:    security/app-link-unverified
detector: mobile-security-scan §4
anchor:   android:label="order_links"
match:    autoVerify|App Link|verif|assetlinks|hijack|link
```

The `https://pantrygo.example/orders` filter has no `android:autoVerify="true"`: any app can claim the same links and a chooser appears. Medium (the links carry an order id, no credential). Fix: `autoVerify="true"` + `assetlinks.json` (the Expo config `intentFilters[].autoVerify`). Proof: D — `pm get-app-links` shows the domain unverified.

## MD-MS-04b — Staff invite links carry a sign-in token on a custom scheme

```defect
id:       MD-MS-04b
file:     picker/src/auth/magicLink.ts
line:     5
severity: high
command:  /mobile-audit /security-audit
class:    security/credential-on-custom-scheme
detector: mobile-security-scan §4
anchor:   'pantrypicker://login?token='
match:    scheme|token|magic|link|hijack|another app|universal|App Link
```

Any app can register `pantrypicker://` and receive the one-time sign-in token from the invite e-mail. High (a credential on a custom scheme). Fix: a verified https App Link / universal link for invites. Proof: D — a second test app claiming the scheme receives the canary token.

## MD-MS-05a — The help WebView gives file pages universal access while loading vendor content

```defect
id:       MD-MS-05a
file:     native/android/app/src/main/java/com/pantrygo/merchant/help/HelpActivity.kt
line:     18
severity: high
command:  /mobile-audit /security-audit
class:    security/webview-file-access
detector: mobile-security-scan §5
anchor:   web.settings.allowUniversalAccessFromFileURLs = true
match:    universal|file access|WebView|file://|allowFileAccess
```

`allowFileAccess` + `allowUniversalAccessFromFileURLs` on a `file:///android_asset` page that embeds articles from the vendor's site: script in that content can read local files and send them anywhere. High. Fix: `WebViewAssetLoader` over `https://appassets.androidplatform.net/` with both flags off. Proof: D — a page from a host the test controls reads a canary file.

## MD-MS-05b — The promo WebView applies account promotions for any origin

```defect
id:       MD-MS-05b
file:     app/src/screens/PromoWebView.tsx
line:     21
severity: high
command:  /mobile-audit /security-audit
class:    security/webview-bridge-any-origin
detector: mobile-security-scan §5
anchor:   originWhitelist={['*']}
match:    origin|onMessage|bridge|WebView|whitelist|nativeEvent\.url
```

`originWhitelist={['*']}` and an `onMessage` that calls `applyPromoCode` with no `nativeEvent.url` check: any page the agency CMS links to (or a redirect) can post `apply-promo` into the signed-in customer's account; `setSupportMultipleWindows={false}` re-exposes CVE-2020-6506. High. Fix: allow-list the offers origin, check `event.nativeEvent.url`. Proof: D — a page from a test host posts the message.

## MD-MS-06a — The merchant release build is debuggable

```defect
id:       MD-MS-06a
file:     native/android/app/src/main/AndroidManifest.xml
line:     15
severity: high
command:  /mobile-audit /security-audit
class:    security/debuggable-release
detector: mobile-security-scan §6
anchor:   android:debuggable="true"
match:    debuggable|debug|release
```

`android:debuggable="true"` in the main manifest overrides the build type: the release APK accepts `run-as` and a debugger. High (MASWE-0061/0063). Fix: remove the attribute. Proof: A — `apkanalyzer manifest debuggable <apk>`.

## MD-MS-06b — The picker app is backed up whole

```defect
id:       MD-MS-06b
file:     picker/android/app/src/main/AndroidManifest.xml
line:     10
severity: medium
command:  /mobile-audit /security-audit
class:    security/backup-without-rules
detector: mobile-security-scan §6
anchor:   android:allowBackup="true"
match:    backup|allowBackup|dataExtractionRules|extraction
```

`allowBackup="true"` with no `dataExtractionRules` / `fullBackupContent`: the sandbox goes into cloud backup and device-to-device transfer. Medium (user data, no credential on disk today). Fix: `allowBackup="false"` (the React Native template default) or rules that exclude everything but preferences. Proof: D — M4, a seeded canary survives backup → reinstall → restore.

## MD-MS-07a — The payments signing secret is an `EXPO_PUBLIC_` variable

```defect
id:       MD-MS-07a
file:     app/.env
line:     5
severity: critical
command:  /mobile-audit /security-audit
class:    security/server-secret-in-bundle
detector: mobile-security-scan §7
anchor:   EXPO_PUBLIC_PAYMENTS_SECRET=
match:    secret|EXPO_PUBLIC|bundle|server|inlined|key
```

Every `EXPO_PUBLIC_*` value is inlined into the JavaScript bundle; `paymentSession.ts` reads it to sign requests. Anyone with the IPA/APK can sign payment-session requests. Critical (MASWE-0004). The value here is a marked canary. Fix: sign on the server. Proof: A — M7, build with a canary value and find it in the bundle.

## MD-MS-07b — A shared admin API token is compiled into the merchant APK

```defect
id:       MD-MS-07b
file:     native/android/app/build.gradle.kts
line:     21
severity: critical
command:  /mobile-audit /security-audit
class:    security/server-secret-in-binary
detector: mobile-security-scan §7
anchor:   buildConfigField("String", "ADMIN_API_TOKEN"
match:    token|secret|BuildConfig|hard.?coded|admin|dex
```

`buildConfigField("String", "ADMIN_API_TOKEN", …)` lands in `BuildConfig` in the dex; whoever unzips the APK can call the back-office endpoints that skip staff sign-in. Critical (CWE-798). The value here is a marked canary. Fix: per-device credentials issued at enrolment. Proof: A — `jadx` / `strings` on the release APK finds the canary.

## MD-PC-08a — The pick list uses React Native's core `SafeAreaView`

```defect
id:       MD-PC-08a
file:     picker/src/screens/PickListScreen.tsx
line:     3
severity: medium
command:  /mobile-audit
class:    platform/core-safe-area-view
detector: platform-conventions-audit §8
anchor:   import { SafeAreaView, FlatList
match:    SafeAreaView|safe.?area|inset|edge.?to.?edge|deprecated
```

Core `SafeAreaView` is deprecated since 0.81 and iOS-only; with edge-to-edge on (target 36) the list runs under the Android status and gesture bars. The app already depends on `react-native-safe-area-context`. Fix: import `SafeAreaView` from it. Proof: D — screenshot on a gesture-navigation emulator.

## MD-PC-08b — The till ignores the safe area with the Charge button inside it

```defect
id:       MD-PC-08b
file:     native/ios/Merchant/CheckoutPadView.swift
line:     25
severity: high
command:  /mobile-audit
class:    platform/controls-under-safe-area
detector: platform-conventions-audit §8
anchor:   .edgesIgnoringSafeArea(.all)
match:    safe.?area|home indicator|edge|inset|ignore
```

`.edgesIgnoringSafeArea(.all)` on the container that holds the "Charge card on file" button: in landscape on an iPad with a home indicator the button sits under it. High (a control under the indicator). Fix: ignore the safe area on the background only. The receipt sheet does it right (MD-DECOY-18). Proof: D — screenshot on a notched simulator.

## MD-PC-10a — The edit screen navigates from the composable body

```defect
id:       MD-PC-10a
file:     native/android/app/src/main/java/com/pantrygo/merchant/ui/EditOrderScreen.kt
line:     24
severity: high
command:  /mobile-audit
class:    platform/navigate-in-composition
detector: platform-conventions-audit §10
anchor:   if (saved) navController.navigate("board")
match:    composition|recompos|LaunchedEffect|navigate|effect|loop
```

`if (saved) navController.navigate("board")` runs on every recomposition after Save, pushing "board" repeatedly. High (a push loop). Fix: `LaunchedEffect(saved) { if (saved) navController.navigate("board") { popUpTo("board") } }` or navigate from the click. Proof: D — save, then the back-stack depth.

## MD-PC-10b — Back from the picker home returns to the sign-in form

```defect
id:       MD-PC-10b
file:     picker/src/auth/useSignIn.ts
line:     12
severity: high
command:  /mobile-audit
class:    platform/sign-in-on-stack
detector: platform-conventions-audit §10
anchor:   navigation.navigate('Home');
match:    back|reset|replace|sign.?in|login|stack
```

Sign-in pushes `Home` on top of `SignIn`; Android back (and the iOS swipe) returns to the PIN form on a shared store device. High (back crosses the auth boundary). The invite path resets the root correctly. Fix: `navigation.reset({ index: 0, routes: [{ name: 'Home' }] })`. Proof: D — sign in, press back.

## MD-PC-11a — The stock screen drops the `Scaffold` content padding

```defect
id:       MD-PC-11a
file:     native/android/app/src/main/java/com/pantrygo/merchant/ui/StockScreen.kt
line:     16
severity: medium
command:  /mobile-audit
class:    platform/edge-to-edge-padding-dropped
detector: platform-conventions-audit §11
anchor:   Scaffold(topBar = {
match:    padding|inset|edge.?to.?edge|Scaffold|system bar|navigation bar
```

`Scaffold(…) { _ -> LazyColumn { … } }` at target 35 with `enableEdgeToEdge()`: the list starts under the top app bar and the last rows — the chilled aisle — sit under the navigation bar. Medium. Fix: `{ padding -> LazyColumn(contentPadding = padding) }`. Proof: D — API 35 emulator, gesture and 3-button navigation.

## MD-PC-11b — "Confirm hand-over" is pinned under the gesture bar

```defect
id:       MD-PC-11b
file:     driver/lib/screens/handover_screen.dart
line:     33
severity: high
command:  /mobile-audit
class:    platform/edge-to-edge-bottom-inset
detector: platform-conventions-audit §11
anchor:   Positioned(left: 16, right: 16, bottom: 0
match:    inset|safe.?area|gesture|bottom|edge.?to.?edge|navigation bar
```

Flutter 3.27+ draws edge-to-edge on Android 15+, and `Positioned(bottom: 0)` applies no inset: the primary button of the hand-over sits under the gesture navigation bar. High (a primary control). Fix: `bottom: MediaQuery.paddingOf(context).bottom` or `SafeArea`. Proof: D — API 35 emulator, gesture navigation.

## MD-PC-12a — The unsaved-readings guard is in `onBackPressed`

```defect
id:       MD-PC-12a
file:     picker/android/app/src/main/java/com/pantrygo/picker/WeighBatchActivity.kt
line:     24
severity: high
command:  /mobile-audit
class:    platform/predictive-back-dead-handler
detector: platform-conventions-audit §12
anchor:   override fun onBackPressed()
match:    onBackPressed|predictive back|OnBackPressedCallback|back|36|Android 16
```

The picker targets 36: on Android 16 `onBackPressed` is not called, so back leaves the batch screen and the weighings are lost without the dialog. High (guards input). Fix: `onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(readings.isNotEmpty()) { … })`. Proof: D — API 36 emulator on Android 16, back gesture with readings.

## MD-PC-12b — The proof screen guards back with `WillPopScope`

```defect
id:       MD-PC-12b
file:     driver/lib/screens/proof_screen.dart
line:     53
severity: medium
command:  /mobile-audit
class:    platform/deprecated-back-api
detector: platform-conventions-audit §12
anchor:   return WillPopScope(
match:    WillPopScope|PopScope|predictive|back|deprecated
```

`WillPopScope` / `onWillPop` are deprecated since Flutter 3.16 and incompatible with predictive back; the notes screen already uses `PopScope` (MD-DECOY-13). Medium. Fix: `PopScope(canPop: !_dirty, onPopInvokedWithResult: …)`. Proof: I — `tester.binding.handlePopRoute()` with a drawn signature.

## MD-NB-01a — The scale is reached through untyped `NativeModules`

```defect
id:       MD-NB-01a
file:     picker/src/native/scale.ts
line:     3
severity: medium
command:  /mobile-audit
class:    bridge/legacy-native-module
detector: native-bridge-audit §1
anchor:   const { ScaleBridge } = NativeModules;
match:    NativeModules|legacy|TurboModule|codegen|spec|untyped|New Architecture
```

On React Native 0.82 (New Architecture only) `ScaleBridge` runs through the legacy interop layer: no codegen spec, resolved at run time, `undefined` if absent; both native halves (`ScaleBridgeModule.kt`, `ScaleBridge.m`) have no spec. Medium. Fix: a `NativeScaleBridge.ts` TurboModule spec + `codegenConfig`. Proof: A — add the spec; the build fails on every mismatch.

## MD-NB-01b — `RCT_NEW_ARCH_ENABLED = 0` on React Native 0.82

```defect
id:       MD-NB-01b
file:     picker/ios/Podfile
line:     12
severity: medium
command:  /mobile-audit
class:    bridge/dead-architecture-flag
detector: native-bridge-audit §1
anchor:   ENV['RCT_NEW_ARCH_ENABLED'] = '0'
match:    RCT_NEW_ARCH_ENABLED|New Architecture|legacy|ignored|flag|0\.82
```

The comment says the old bridge is kept for the scale SDK, but 0.82 ignores the flag: the app runs the New Architecture regardless, and the team is reasoning about a mode that does not exist. Medium. Fix: delete the line; migrate the module (MD-NB-01a). Proof: A — the build log shows the New Architecture.

## MD-NB-02a — `ScaleBridge.tare()` is called from JS and not exported on Android

```defect
id:       MD-NB-02a
file:     picker/src/native/scale.ts
line:     14
severity: high
command:  /mobile-audit
class:    bridge/contract-gap
detector: native-bridge-audit §2
anchor:   return ScaleBridge.tare();
match:    tare|not exported|ReactMethod|Android|undefined|contract
```

`ScaleBridgeModule.kt` exports only `readWeight`; iOS exports both. On Android every Weigh tap throws `tare is not a function` before the weight is read. High. Fix: `@ReactMethod fun tare(promise: Promise)`. Proof: I — an instrumented contract test calls every method on Android.

## MD-NB-02b — `flashOn` is invoked from Dart and not handled on iOS

```defect
id:       MD-NB-02b
file:     driver/lib/native/scanner_channel.dart
line:     12
severity: high
command:  /mobile-audit
class:    bridge/contract-gap
detector: native-bridge-audit §2
anchor:   static Future<void> flashOn()
match:    flashOn|(?:not|n.t) handled|iOS|MissingPlugin|channel|contract|hang
```

The Android handler answers `start`, `stop`, `flashOn`; `ScannerPlugin.swift` answers only `start` and `stop`. On iPhone the torch button never completes (see MD-NB-03b). High. Fix: handle `flashOn` on iOS, or guard the call by platform. Proof: I — integration test invoking every method on an iOS simulator.

## MD-NB-03a — A failed scale read never rejects the promise

```defect
id:       MD-NB-03a
file:     picker/android/app/src/main/java/com/pantrygo/picker/scale/ScaleBridgeModule.kt
line:     24
severity: high
command:  /mobile-audit
class:    bridge/promise-never-settles
detector: native-bridge-audit §3
anchor:   } catch (e: Exception) {
match:    reject|promise|never|settle|catch|hang
```

The `catch` logs and returns: `await readWeight()` never settles and the Weigh button stays on "Weighing…". High. Fix: `promise.reject("E_SCALE", e.message, e)`. Proof: I — force `scale.read()` to throw; the promise neither resolves nor rejects within 5 s.

## MD-NB-03b — The iOS scanner handler falls through without `FlutterMethodNotImplemented`

```defect
id:       MD-NB-03b
file:     driver/ios/Runner/ScannerPlugin.swift
line:     18
severity: high
command:  /mobile-audit
class:    bridge/unhandled-method-no-result
detector: native-bridge-audit §3
anchor:   default:
match:    notImplemented|FlutterMethodNotImplemented|default|result|never|hang
```

`default: break` never calls `result`, so any method the handler does not know (today `flashOn`) leaves the Dart future pending forever instead of throwing `MissingPluginException`. High. Fix: `default: result(FlutterMethodNotImplemented)`. Proof: I — invoke an unknown method; the future completes with an error.

## MD-NB-06a — `InteractionManager` on React Native 0.87

```defect
id:       MD-NB-06a
file:     app/src/screens/OrderTrackingScreen.tsx
line:     22
severity: high
command:  /mobile-audit
class:    bridge/removed-runtime-api
detector: native-bridge-audit §6
anchor:   InteractionManager.runAfterInteractions(
match:    InteractionManager|removed|0\.87|requestIdleCallback|deprecated
```

The customer app pins 0.87, which removed `InteractionManager` (it stopped deferring in 0.80): the tracking screen breaks the build or throws at run time. High. Fix: `requestIdleCallback`, or scroll in `onContentSizeChange`. Proof: A — Metro bundle / `tsc` on 0.87.

## MD-NB-06b — A deep import into `react-native/Libraries` on 0.87

```defect
id:       MD-NB-06b
file:     app/src/utils/layout.ts
line:     2
severity: high
command:  /mobile-audit
class:    bridge/deep-import
detector: native-bridge-audit §6
anchor:   from 'react-native/Libraries/StyleSheet/flattenStyle'
match:    deep import|Libraries|Strict|0\.87|StyleSheet\.flatten|private
```

The Strict TypeScript API is the default in 0.87 and deep imports are inaccessible unless the legacy condition is set. High (build break). Fix: `StyleSheet.flatten` from `react-native`. Proof: A — `tsc` fails on the line.

## MD-AZ-01a — The picker release build is not shrunk

```defect
id:       MD-AZ-01a
file:     picker/android/app/build.gradle
line:     44
severity: high
command:  /mobile-audit
class:    size/shrinking-off
detector: app-size-scan §1
anchor:   minifyEnabled enableProguardInReleaseBuilds
match:    minif|R8|shrink|proguard|release
```

`minifyEnabled` is bound to `enableProguardInReleaseBuilds = false` (the React Native template default), and `proguard-android.txt` is the file AGP 9 drops. High (size, DEX vital). Fix: `true` + `proguard-android-optimize.txt`, with keep rules for the scale SDK. Proof: A — `bundleRelease` before and after; `bundletool get-size total`.

## MD-AZ-01b — The merchant release build type has no shrinking at all

```defect
id:       MD-AZ-01b
file:     native/android/app/build.gradle.kts
line:     42
severity: high
command:  /mobile-audit
class:    size/shrinking-off
detector: app-size-scan §1
anchor:   getByName("release") {
match:    minif|R8|shrink|isMinifyEnabled|optimization|release
```

An application module whose `release` block sets only the signing config: R8 never runs, and AGP 8.3 has no `optimization {}` DSL to fall back on. High. Fix: `isMinifyEnabled = true; isShrinkResources = true` with `proguard-android-optimize.txt`. Proof: A — release AAB size and DEX size before and after.

## MD-AZ-02a — Emulator ABIs ship in the picker release

```defect
id:       MD-AZ-02a
file:     picker/android/app/build.gradle
line:     30
severity: medium
command:  /mobile-audit
class:    size/emulator-abis-in-release
detector: app-size-scan §2
anchor:   abiFilters "armeabi-v7a", "arm64-v8a", "x86", "x86_64"
match:    ABI|x86|abiFilters|emulator|native
```

The store handsets are ARM; `x86` and `x86_64` copies of Hermes/JSC and every native library ship in release. Medium. Fix: release `abiFilters` of the ARM ABIs (x86 in a debug flavour). Proof: A — per-ABI APK sizes.

## MD-AZ-02b — Native libraries are packaged compressed (legacy packaging)

```defect
id:       MD-AZ-02b
file:     native/android/app/build.gradle.kts
line:     48
severity: medium
command:  /mobile-audit
class:    size/legacy-native-packaging
detector: app-size-scan §2
anchor:   jniLibs { useLegacyPackaging = true }
match:    useLegacyPackaging|compress|native|\.so|packaging|extract
```

`useLegacyPackaging = true` compresses `.so` files and extracts them at install: a bigger install footprint, and compressed libraries cannot be 16 KB-aligned in place. Medium. Fix: remove it. Proof: A — install size before and after.

## MD-AZ-04a — The whole of `moment` for one slot label

```defect
id:       MD-AZ-04a
file:     app/src/utils/dates.ts
line:     1
severity: medium
command:  /mobile-audit
class:    size/heavy-whole-library
detector: app-size-scan §4
anchor:   import moment from 'moment';
match:    moment|bundle|size|date-fns|Intl|library
```

One formatter pulls `moment` (and its locale machinery) into the bundle. Medium. Fix: `Intl.DateTimeFormat` or date-fns per function. Proof: A — Expo Atlas before and after.

## MD-AZ-04b — The whole of `lodash` for `groupBy` and `sortBy`

```defect
id:       MD-AZ-04b
file:     picker/src/utils/group.ts
line:     1
severity: medium
command:  /mobile-audit
class:    size/heavy-whole-library
detector: app-size-scan §4
anchor:   import _ from 'lodash';
match:    lodash|bundle|size|whole|import
```

`import _ from 'lodash'` bundles the full library (with `inlineRequires: false`, it is also evaluated at start-up — mobile-perf-scan §6 credits the same line). Medium. Fix: `lodash/groupBy` + `lodash/sortBy`, or native `Object.groupBy`. Proof: A — react-native-bundle-visualizer before and after.

## MD-AZ-05a — Hermes is switched off on React Native 0.82

```defect
id:       MD-AZ-05a
file:     picker/android/gradle.properties
line:     13
severity: high
command:  /mobile-audit
class:    size/hermes-off
detector: app-size-scan §5
anchor:   hermesEnabled=false
match:    Hermes|JSC|engine|bytecode
```

The picker ships JSC and plain JavaScript instead of Hermes bytecode — larger and slower to start, with JSC a third-party package from 0.84. High. Fix: remove the opt-out. Proof: A — release bundle size; cold start from `@device-performance-auditor`.

## MD-AZ-05b — The Android release keeps Dart symbols in the binary

```defect
id:       MD-AZ-05b
file:     driver/scripts/release.sh
line:     12
severity: medium
command:  /mobile-audit
class:    size/flutter-symbols-in-binary
detector: app-size-scan §5
anchor:   flutter build appbundle --release
match:    split-debug-info|symbol|obfuscate|debug info|size
```

`flutter build appbundle` without `--split-debug-info`; the iOS line below does it right (MD-DECOY-17). Medium. Fix: `--split-debug-info=build/symbols/android --obfuscate` and upload the symbols. Proof: A — `--analyze-size` before and after.

## Decoys — must NOT be reported

Each decoy is the correct sibling of a seeded defect — same app, same vocabulary, no defect. FX-3's eval list is
covered: a Material 3 `IconButton` (minimum size enforced), a `ScrollView` of six constant items, a token in
`expo-secure-store`, a `GoogleService-Info.plist` `API_KEY`, `usesCleartextTraffic` only in the debug manifest, an
exported launcher activity, a Compose lambda under strong skipping, an inline context value under the React Compiler,
`allowFontScaling={false}` on a fixed-size logo glyph, and a queued write whose idempotency key is minted at enqueue.
Added: emulator-only cleartext, `router.replace` after sign-in, `PopScope` with a handler, a `mounted` check after
`await`, a `fetch` with a deadline, `int.tryParse` on a link, `--split-debug-info` on the iOS build, a background-only
`ignoresSafeArea`, a swipe row with accessibility actions, and a verified App Link.

How they score (`score.py`, § DECOYS): a finding that names the decoy's file, cites a line within the tolerance window
of the decoy's line, and matches every one of the decoy's `match:` patterns is **pinned** to it, removed before defect
assignment, and reported as `DECOYS FLAGGED k/N`. Every decoy sits more than 12 lines from any defect in its file
(`--verify` enforces it).

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| MD-DECOY-01 | `native/android/app/src/main/java/com/pantrygo/merchant/ui/RefreshAction.kt:18` | MD-MA-03a | a 20 dp glyph inside a Material 3 `IconButton`, which enforces the 48 dp minimum (precedents/mobile § 37) |
| MD-DECOY-02 | `app/src/components/SortSheet.tsx:21` | MD-MP-01a | six constant sort options; a `ScrollView` is right for a bounded constant list (precedents/mobile § 36) |
| MD-DECOY-03 | `app/src/auth/session.ts:10` | MSEC §1 | `expo-secure-store` with `WHEN_UNLOCKED_THIS_DEVICE_ONLY` is the secure store the skill names as the fix |
| MD-DECOY-04 | `native/ios/Merchant/GoogleService-Info.plist:6` | MD-MS-07b | a Firebase config file is a project identifier, not a secret (precedents/mobile § 44); the value is a non-key placeholder |
| MD-DECOY-05 | `app/android/app/src/debug/AndroidManifest.xml:3` | MD-MS-02a | the `src/debug` manifest is merged into debug builds only (Metro over HTTP); release never sees it |
| MD-DECOY-06 | `driver/android/app/src/main/AndroidManifest.xml:14` | MD-MS-03a | the launcher activity must be exported (precedents/mobile § 46) |
| MD-DECOY-07 | `native/android/app/src/main/java/com/pantrygo/merchant/ui/ProductTile.kt:16` | MD-MP-03b | Kotlin 2.2 compiles Compose with strong skipping on: the caller's lambda is remembered and the tile still skips (precedents/mobile § 32) |
| MD-DECOY-08 | `app/src/state/BasketProvider.tsx:19` | MD-MP-03a | the customer app builds with the React Compiler (`experiments.reactCompiler`), which memoizes the value (precedents/mobile § 33) |
| MD-DECOY-09 | `app/src/components/BrandMark.tsx:12` | MD-MA-04a | a logo monogram inside a fixed 48 pt badge, hidden from the tree; the badge carries the name (mobile-a11y-scan § False positives b) |
| MD-DECOY-10 | `app/src/offline/orderQueue.ts:14` | MD-OS-02b | the key is minted once at enqueue, stored with the row and resent on every replay — the GOOD shape of offline-sync-scan § 2 |
| MD-DECOY-11 | `app/android/app/src/main/res/xml/network_security_config.xml:9` | MD-MS-02a | cleartext scoped to `10.0.2.2` and `localhost` (the emulator loopback); the base config forbids it |
| MD-DECOY-12 | `app/src/auth/useSignIn.ts:14` | MD-PC-10b | `router.replace` after sign-in: back cannot return to the form |
| MD-DECOY-13 | `driver/lib/screens/notes_screen.dart:43` | MD-PC-12b | `PopScope(canPop: !_dirty, onPopInvokedWithResult: …)` is the predictive-back API with a confirm dialog |
| MD-DECOY-14 | `driver/lib/screens/eta_card.dart:21` | mobile-lifecycle-scan §1 (1f) | the `mounted` check sits between the `await` and `setState` |
| MD-DECOY-15 | `app/src/api/http.ts:11` | MD-ML-04a | the shared client passes `AbortSignal.timeout(15_000)` unless the caller brings a signal |
| MD-DECOY-16 | `driver/lib/router.dart:40` | MD-ML-05a | `int.tryParse` with a not-found screen for a malformed hand-over link |
| MD-DECOY-17 | `driver/scripts/release.sh:26` | MD-AZ-05b | the iOS build already splits Dart symbols and uploads them |
| MD-DECOY-18 | `native/ios/Merchant/ReceiptView.swift:11` | MD-PC-08b | only the tinted `Color` ignores the safe area; the `VStack` with the Done button keeps it |
| MD-DECOY-19 | `app/src/components/SavedAddressRow.tsx:22` | MD-MA-06a | the swipe-to-delete row also exposes Edit and Delete as accessibility actions |
| MD-DECOY-20 | `driver/android/app/src/main/AndroidManifest.xml:29` | MD-MS-04a | the https stop links are verified (`autoVerify="true"`) |

```decoy
id:       MD-DECOY-01
file:     native/android/app/src/main/java/com/pantrygo/merchant/ui/RefreshAction.kt
line:     18
command:  /mobile-audit
class:    decoy/m3-iconbutton-min-target
anchor:   Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.refresh)
match:    target|touch|size|48
```

```decoy
id:       MD-DECOY-02
file:     app/src/components/SortSheet.tsx
line:     21
command:  /mobile-audit
class:    decoy/constant-scrollview
anchor:   {SORT_OPTIONS.map((option) => (
match:    virtuali|ScrollView|FlatList|unbounded
```

```decoy
id:       MD-DECOY-03
file:     app/src/auth/session.ts
line:     10
command:  /mobile-audit /security-audit
class:    decoy/secure-store-token
anchor:   await SecureStore.setItemAsync('refreshToken'
match:    plain|storage|token|secure|keychain
```

```decoy
id:       MD-DECOY-04
file:     native/ios/Merchant/GoogleService-Info.plist
line:     6
command:  /mobile-audit /security-audit
class:    decoy/firebase-config
anchor:   <string>AIza-CANARY-placeholder-not-a-key</string>
match:    secret|key|hard.?coded|API_KEY
```

```decoy
id:       MD-DECOY-05
file:     app/android/app/src/debug/AndroidManifest.xml
line:     3
command:  /mobile-audit /security-audit
class:    decoy/debug-only-cleartext
anchor:   android:usesCleartextTraffic="true"
match:    cleartext|http
```

```decoy
id:       MD-DECOY-06
file:     driver/android/app/src/main/AndroidManifest.xml
line:     14
command:  /mobile-audit /security-audit
class:    decoy/exported-launcher
anchor:   android:exported="true"
match:    export
```

```decoy
id:       MD-DECOY-07
file:     native/android/app/src/main/java/com/pantrygo/merchant/ui/ProductTile.kt
line:     16
command:  /mobile-audit
class:    decoy/strong-skipping-lambda
anchor:   fun ProductTile(item: StockItem, onAdjust: (Int) -> Unit
match:    recompos|stable|lambda|skip|remember
```

```decoy
id:       MD-DECOY-08
file:     app/src/state/BasketProvider.tsx
line:     19
command:  /mobile-audit
class:    decoy/react-compiler-provider
anchor:   <BasketContext.Provider value={{ lines, add, remove }}>
match:    Provider|context|re.?render|memo|inline
```

```decoy
id:       MD-DECOY-09
file:     app/src/components/BrandMark.tsx
line:     12
command:  /mobile-audit
class:    decoy/fixed-size-logo
anchor:   <Text style={styles.glyph} allowFontScaling={false}
match:    font|scal|text size|dynamic type
```

```decoy
id:       MD-DECOY-10
file:     app/src/offline/orderQueue.ts
line:     14
command:  /mobile-audit
class:    decoy/key-minted-at-enqueue
anchor:   const idempotencyKey = uuid();
match:    idempoten|key|replay|retry
```

```decoy
id:       MD-DECOY-11
file:     app/android/app/src/main/res/xml/network_security_config.xml
line:     9
command:  /mobile-audit /security-audit
class:    decoy/local-only-cleartext
anchor:   <domain-config cleartextTrafficPermitted="true">
match:    cleartext|http
```

```decoy
id:       MD-DECOY-12
file:     app/src/auth/useSignIn.ts
line:     14
command:  /mobile-audit
class:    decoy/sign-in-replaces-stack
anchor:   router.replace('/');
match:    back|stack|sign.?in|login|replace|navigat
```

```decoy
id:       MD-DECOY-13
file:     driver/lib/screens/notes_screen.dart
line:     43
command:  /mobile-audit
class:    decoy/popscope-with-handler
anchor:   return PopScope(
match:    back|pop|predictive|WillPop
```

```decoy
id:       MD-DECOY-14
file:     driver/lib/screens/eta_card.dart
line:     21
command:  /mobile-audit
class:    decoy/mounted-check-after-await
anchor:   if (!mounted) return;
match:    mounted|setState|await|async gap
```

```decoy
id:       MD-DECOY-15
file:     app/src/api/http.ts
line:     11
command:  /mobile-audit
class:    decoy/fetch-with-deadline
anchor:   const response = await fetch(
match:    timeout|signal|abort|hang
```

```decoy
id:       MD-DECOY-16
file:     driver/lib/router.dart
line:     40
command:  /mobile-audit
class:    decoy/tryparse-link-param
anchor:   final orderId = int.tryParse(
match:    parse|crash|malformed|link
```

```decoy
id:       MD-DECOY-17
file:     driver/scripts/release.sh
line:     26
command:  /mobile-audit
class:    decoy/split-debug-info
anchor:   flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios
match:    split-debug-info|symbol|obfuscate
```

```decoy
id:       MD-DECOY-18
file:     native/ios/Merchant/ReceiptView.swift
line:     11
command:  /mobile-audit
class:    decoy/background-ignores-safe-area
anchor:   .ignoresSafeArea()
match:    safe.?area|home indicator|inset|edge
```

```decoy
id:       MD-DECOY-19
file:     app/src/components/SavedAddressRow.tsx
line:     22
command:  /mobile-audit
class:    decoy/swipe-with-actions
anchor:   accessibilityActions={[
match:    swipe|gesture|action
```

```decoy
id:       MD-DECOY-20
file:     driver/android/app/src/main/AndroidManifest.xml
line:     29
command:  /mobile-audit /security-audit
class:    decoy/verified-app-link
anchor:   <intent-filter android:autoVerify="true">
match:    autoVerify|App Link|verif|hijack
```

## Detector measurement — the pre-flight greps run on this fixture

Measured 2026-10-10 with ripgrep 15.2.0 under `/bin/bash` 3.2.57 (stdin from `/dev/null` and piped give the same sorted
output), from this directory, each skill's pre-flight block copied verbatim from its `SKILL.md` as of that date:
`templates/packs/mobile/skills/{mobile-lifecycle-scan,mobile-a11y-scan,mobile-perf-scan,offline-sync-scan,
store-compliance-scan,platform-conventions-audit,native-bridge-audit,app-size-scan}/SKILL.md` and
`templates/packs/security/skills/mobile-security-scan/SKILL.md`. Every script finds the same five roots (`./app`,
`./driver`, `./native/android/app`, `./native/ios`, `./picker`) and writes nothing to stderr. A seed is **caught** when its
owner's script prints its file (file-level and set-difference lines) or a line within 6 of its anchor, or — for the
lines that name no file — the tagged line that names its module, channel, function or root (`2h callbackDispatcher`,
`6c ./picker`, `7d ./picker`, `3b ./app`, `2a ScaleBridge.tare`, `2b pantrygo/scanner.flashOn`). A decoy is **hit** when
a script prints it for the class it imitates; every decoy hit below is refuted by the read the skill already
prescribes, so the decoy produces **0 findings**. These are grep results, not a scored `/mobile-audit` run — no run is
recorded in `RESULTS.md` yet. Re-measured the same day after IR-1–IR-7 below were fixed in the skills: the five rows
marked *re-measured* changed (each first count in parentheses), the other four did not.

| detector | lines printed | seeds it owns | caught by its greps | decoys hit by the class they imitate → findings | other printed lines |
|----------|---------------|---------------|--------------------|-----------------------------------------------|---------------------|
| `mobile-lifecycle-scan` | 74 | 14 (§1–§7 × 2) | **14 / 14** — 1a, 1e, 2a, 2h, 3a, 3b, 4a, 4c, 5a × 2, 6c, 6d, 7b, 7d | DECOY-14 (1f), -15 (4b), -16 (5a): 0 hits | context only: 5 roots, 39 version lines; `3c ./picker` corroborates ML-03b; 5c link entry points (`picker/App.tsx` ×2); 5d routed rows — the `order_links` filter (= MS-04a) and the `pantrygo` / `pantrypicker` scheme declarations, which `mobile-security-scan` §4 owns |
| `mobile-a11y-scan` | 33 *re-measured* (39) | 12 (§1–§6 × 2) | **12 / 12** — 1a, 1b, 2a, 2c, 3b, 3c, 4a, 4e, 5a, 5b, 6 × 2 | DECOY-09 by 4a (`allowFontScaling={false}` on the monogram) → 0: a fixed-size logo in a 48 pt badge, § False positives b. DECOY-01, -19: 0 hits | none false. Before IR-1: 6 false 2a lines — multi-line `<Pressable` tags whose `accessibilityRole` sits on the next line (`FavoriteButton:13`, `OrdersScreen:29`, `QtyStepper:10`, `:22`, `SortSheet:22`, `AccountScreen:16`) |
| `mobile-perf-scan` | 44 *re-measured* (52) | 14 (§1–§7 × 2) | **14 / 14** — 1a, 1d, 2a, 2d, 3a, 3c, 4b, 4d, 5a, 5b, 6a, 6c, 7a, 7b | DECOY-08 by 3a (inline Provider value) → 0: the React Compiler is on in `app.json`, precedent § 33. DECOY-02, -07: 0 hits | none false. Before IR-2 / IR-3: 6 false 2a lines (multi-line `<FlatList` tags with `keyExtractor` on a later line, the generic in `useRef<FlatList<…>>`) and 2 false 7d lines (the template's `var reactNativeDelegate`). Corroboration: 4a `InteractionManager` (= NB-06a), 6c `lodash` / `moment` imports (= AZ-04b / AZ-04a) |
| `offline-sync-scan` | 23 *re-measured* (26) | 6 (§1–§3 × 2) | **6 / 6** — 1a (QD), 1c, 2a, 2b, 3a, 3b | DECOY-10 by 2b (`idempotencyKey = uuid()`) → 0: minted once at enqueue, stored with the row and resent on every replay | none false. Before IR-4: 3 false 3c lines on the drain *triggers* (`onStoreWifi.ts`, `onReconnect.ts`, `connectivity_trigger.dart`) — `void flush();` is the JS `void` operator and `drainOnNetworkChange` is a listener, not a drain |
| `store-compliance-scan` | 51 *re-measured* (47) | 12 (§1–§4, §6, §7 × 2) | **12 / 12** — 1a, 1b, 2a, 2c, 3a, 3b, 4a × 2, and the §6 / §7 version lines for ST-06a/b, ST-07a/b (the gate comparison against today is the read step, by design) | no decoy imitates a store row | context: 3 `4c` SCHEDULE rows (Restore Credentials, from April 2027), 5 `1c` listed-SDK lines, every §6 / §7 version line; 4 `8a` inventory lines — `react-native-appsflyer` and the merchant app's Firebase Analytics, Sentry and Datadog Gradle coordinates, which 8a missed before IR-7 |
| `mobile-security-scan` | 46 | 12 (§2–§7 × 2) | **12 / 12** — 2a (NSC), 2b (ATS), 3a × 2, 4a, 4b, 5a, 5b, 6a debuggable, 6a backup, 7b × 2 | DECOY-04 by 7a (Firebase config listed) → 0: precedent § 44. DECOY-03, -05, -06, -11, -20: 0 hits | context: 4 `manifest … source` lines, 5 §8 inventory lines + 8d (L1), 4c link entry points; the `pantrygo` scheme (manifest, plist, `app.json`) — a link scheme that carries no credential (precedent § 27); `pantrypicker` scheme lines and `paymentSession.ts:3` corroborate MS-04b / MS-07a; the picker `release {}` block (minify off — the R-profile inventory line, = AZ-01a) |
| `platform-conventions-audit` | 28 | 8 (§8, §10–§12 × 2) | **8 / 8** — 8a, 8b, 10a, 10b, 11c, 11d, 12 × 2 | DECOY-12 (`router.replace`), -13 (`PopScope` + handler), -18 (background-only `ignoresSafeArea`): 0 hits | context only (versions, `convention: haptics in 0 file(s)`) |
| `native-bridge-audit` | 20 | 8 (§1–§3, §6 × 2) | **8 / 8** — 0 (dead flag), 1a, 2a, 2b, 3a, 3b, 6 × 2 | no decoy imitates a bridge row | 2 `1b` lines (`ScaleBridgeModule.kt`, `ScaleBridge.m`: no spec) — the native halves of NB-01a |
| `app-size-scan` | 27 *re-measured* (34) | 8 (§1, §2, §4, §5 × 2) | **8 / 8** — 1 (file-level), 1 (bound variable), 2 × 2, 4 × 2, 5 × 2 | DECOY-17 (`flutter build ipa … --split-debug-info`) → 0: printed only by grep 0 as the release command; §5 skips it | none false, no duplicate. Before IR-5 / IR-6: 1 false §1 line (`native/android/build.gradle.kts`, a root `plugins { … apply false }` block read as an application module) and 6 duplicated lines (a root named `app` added `.` to `GROOTS`) |

Totals: **94 of 94** seeds are printed by their owner's pre-flight. **0 decoys** survive their owner's prescribed read;
the 5 decoy hits above (DECOY-04, -08, -09, -10, -17 as context) are the ones that read exists to refute. Unseeded
noise: **0 false lines** after IR-1–IR-7 (first measurement: 18 false lines across four scripts — a11y 6, perf 8,
offline 3, size 1 — plus 6 duplicates, all traced to the grep gaps below). Run from the repo root, the mobile scripts
find this fixture's five roots (until 2026-10-10 the benchmark fixtures held no mobile root); `mobile-security-scan`
still prints its `N/A` line there because its root computation excludes `fixtures/`, and the others' `X` array drops
`fixtures/` paths from their greps. `app-size-scan` printed 29 lines there before IR-5 (greps 0–2 without `X`, and
§ 6 listing every dependency of a root whose sources `X` hides); it now prints 4 — `not compared` for `app` and
`picker`, and two § 6 lines from `tests/stack-conformance/fixtures/flutter-app`.

### Integrator requests (skill gaps found by this fixture — the skills are other agents' files)

**Status 2026-10-10: all nine resolved.** IR-1–IR-7 are fixed in the skills (re-measured above; the program's
multi-stack sample prints the same lines as before each fix); IR-8 was already fixed in `mobile-audit.md`; IR-9 is
fixed in `run.sh` (`Invocation[/<command>]:` lines, multi-command `command:` blocks in `score.py`), which gives this key
its `/security-audit` row.

- **IR-1 — `mobile-a11y-scan` greps 2a and 3a:** both run without `-U`, so `TG` stops at the end of the `<Pressable` line:
  a multi-line tag whose `accessibilityRole` / `hitSlop` sits on a later line is printed (6 false here). Run them with
  `-U` and the JSX-aware `TB` body, as grep 1a already does.
- **IR-2 — `mobile-perf-scan` grep 2a:** same single-line limit for `<FlatList` / `<SectionList` (`keyExtractor` on a
  later line, 5 false), and `<FlatList\b` also matches the TypeScript generic `useRef<FlatList<Item>>` (1 false). Use
  `-U` with `TB`, and require the tag to start a JSX element (`(?<![\w.<])<FlatList\b` at a line start or after `(`/`>`).
- **IR-3 — `mobile-perf-scan` grep 7d:** the strong-delegate alternation matches the React Native / Expo template's
  `var reactNativeDelegate: …Delegate?` in `AppDelegate.swift` (an owned factory, no cycle). Exclude `reactNativeDelegate`
  or require a `delegate` property whose type is a protocol the class conforms to.
- **IR-4 — `offline-sync-scan` grep 3c:** the "drain definition" alternation accepts `void` as a declaration keyword, so
  JS `void flush();` (the void operator on a call) and a Dart trigger named `drainOnNetworkChange` are read as drain
  functions with no attempt ceiling. Drop `void` for JS/TS files (or require `\bvoid\s+\w+\s*\([^)]*\)\s*\{`), and skip
  names that end in a trigger word (`On\w+`).
- **IR-5 — `app-size-scan` root handling:** `case "$r" in */app)` also matches a top-level mobile root named `./app`
  (Expo's own default layout), adding `.` to `GROOTS`: grep 0–2 then print every hit twice and search the whole
  repository. Match `*/*/app` or compare with the root list. Separately, grep 0–2 and 4 search `GROOTS` / `.` without
  `"${X[@]}"`, so a run from this repository's root prints 29 lines from `benchmarks/fixtures/`.
- **IR-6 — `app-size-scan` grep 1:** `rg -l 'com\.android\.application'` lists a root `build.gradle(.kts)` whose
  `plugins {}` block declares the plugin with `apply false`; the file is then reported as "application module with no
  release shrinking". Require an applied plugin (`id("com.android.application")` without `apply false`, or
  `apply plugin:`).
- **IR-7 — `store-compliance-scan` grep 8a:** the SDK alternation must start right after a quote or a space, so Gradle
  coordinates (`"com.google.firebase:firebase-analytics:23.0.0"`, `"io.sentry:sentry-android:…"`,
  `"com.datadoghq:dd-sdk-android-rum:…"`) and npm wrappers (`"react-native-appsflyer"`) are not inventoried, and 8b's
  gate skips a root whose only SDKs are written that way. Allow `[:/-]` before the SDK id.
- **IR-8 — `/mobile-audit` (mobile pack):** the detector table and the Security cross-pack paragraph still call
  `mobile-security-scan` "planned (batch-3 item 46)" (`templates/packs/mobile/commands/mobile-audit.md:87`, `:95`); the
  skill is on disk. This key scores the `MD-MS-*` rows under `/mobile-audit` on the strength of that dispatch.
- **IR-9 — `benchmarks/run.sh`:** `fixture_invocation` returns the `Invocation:` override for every command of a
  two-command fixture, so a key cannot score `/mobile-audit` and `/security-audit` as two rows with their own
  invocations. Apply the override to the fixture's primary command only, or read `Invocation /<command>:` lines.
