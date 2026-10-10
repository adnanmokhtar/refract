# Pantry Go

Grocery delivery in two hours: customers order on their phones, store staff pick the basket, drivers bring it, and
the store's own tablet tracks stock and hand-offs.

```
app/              customer app — Expo SDK 57 (React Native 0.87), Expo Router, prebuilt android/ and ios/ committed
picker/           store picker app — bare React Native 0.82, React Navigation, Bluetooth scale module
driver/           driver app — Flutter 3.47, go_router, dio, Firebase Messaging, workmanager
native/android/   merchant tablet app — Kotlin 2.2, Jetpack Compose, Views for the help screen
native/ios/       merchant iPad app — SwiftUI, iOS 17
```

## app

- `app/` — Expo Router routes; screens live in `src/screens/`, shared UI in `src/components/`.
- `src/api/` — the HTTP clients; `src/offline/` — the order outbox that survives a lost signal at the door.
- `src/push/` registers for notifications; `src/auth/` holds sign-in, logout and the session store.
- `android/` and `ios/` were prebuilt once for the payment SDK and are committed; `app.json` still drives the
  JavaScript side and the update channel.

## picker

Staff sign in with a store-issued account. `src/screens/` holds the pick list, the quantity stepper and the
substitution flow; `src/native/scale.ts` talks to the Bluetooth scale through a native module
(`android/app/src/main/java/com/pantrygo/picker/scale/`, `ios/Picker/ScaleBridge.m`). Picks are queued in
`src/offline/outbox.ts` and flushed when the store Wi-Fi comes back.

## driver

`lib/router.dart` is the route table, `lib/api/` the dio client, `lib/offline/` the proof-of-delivery outbox and the
photo upload queue, `lib/background/` the periodic sync, `lib/push/` Firebase Messaging. The scanner torch is a
platform channel (`android/app/src/main/kotlin/…/ScannerPlugin.kt`, `ios/Runner/ScannerPlugin.swift`).

## native

The merchant apps run on store-owned tablets. Android: `app/src/main/java/com/pantrygo/merchant/` (Compose screens in
`ui/`, the inventory sync service in `sync/`, the help WebView in `help/`). iOS: `Merchant/` (SwiftUI).

## Building

```bash
cd app && npx expo run:android --variant release
cd picker && npx react-native run-android --mode release
cd driver && ./scripts/release.sh
cd native/android && ./gradlew :app:bundleRelease
```
