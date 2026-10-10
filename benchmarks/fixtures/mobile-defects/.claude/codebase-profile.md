# Codebase profile — Pantry Go

PROJECT_KIND: mobile
Languages: TypeScript, Dart, Kotlin, Swift, Objective-C
Customer app (`app/`): Expo SDK 57, React Native 0.87, Expo Router 7, TanStack Query 5, expo-sqlite, expo-notifications, react-native-webview; React Compiler on
Picker app (`picker/`): React Native 0.82 (bare), React Navigation 7, React Native Firebase Messaging, a legacy native module for the Bluetooth scale
Driver app (`driver/`): Flutter 3.47, go_router, dio, hive, firebase_messaging, workmanager, geolocator, connectivity_plus
Merchant apps (`native/`): Android — Kotlin 2.2, Jetpack Compose (BOM 2026.09), AGP 8.3, targetSdk 35; iOS — SwiftUI, iOS 17, Swift 6
Distribution: App Store and Play for `app/` and `driver/`; `picker/` and `native/` through managed Play and Apple Business Manager
Security posture: none declared (no MASVS level in the docs)
Users: customers on their own phones; store staff and drivers on company devices
