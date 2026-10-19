#!/usr/bin/env bash
# Release builds for the driver app. CI runs this on tags; the artifacts go to Play and App Store Connect.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(grep '^version:' pubspec.yaml | cut -d' ' -f2)"
echo "Building driver ${VERSION}"

flutter pub get

# Android: the App Bundle Play receives.
flutter build appbundle --release \
  --dart-define=API_URL=https://driver-api.pantrygo.example

mkdir -p dist
cp build/app/outputs/bundle/release/app-release.aab "dist/driver-${VERSION}.aab"
shasum -a 256 "dist/driver-${VERSION}.aab" > "dist/driver-${VERSION}.aab.sha256"

# R8 mapping for the crash reporter, so Kotlin stack traces from the plugins stay readable.
if [ -f build/app/outputs/mapping/release/mapping.txt ]; then
  cp build/app/outputs/mapping/release/mapping.txt "dist/driver-${VERSION}-mapping.txt"
fi

# iOS: an IPA for App Store Connect. Dart symbols are split out and uploaded to the crash reporter below,
# so the stack traces stay readable while the binary stays small.
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios \
  --dart-define=API_URL=https://driver-api.pantrygo.example

./scripts/upload_symbols.sh build/symbols/ios
