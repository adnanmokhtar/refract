---
name: deep-linking
description: Pattern — deep links + universal links + push-notification routing. Get every entry point to the app to land users on the right screen with the right state.
kind: ai-pattern
pack: mobile
---

# Pattern: Deep linking

> **Hard rule:** Every entry-point URL (custom scheme, universal/App Link, push payload) maps to ONE route resolver that validates auth state, locale, and parameters before navigating. Direct `navigation.navigate()` from a deep-link handler bypassing the resolver, or unsafe params (open-redirect-style URLs from a notification) is forbidden.

**When to apply**
- The app receives universal links / App Links and a marketing channel can craft URLs.
- Push notifications carry a `route` or `target` payload that opens specific screens.
- A new screen ships and needs to be reachable from outside the app (email, SMS, share sheet).

**When NOT to apply**
- An internal-only app with no external entry points beyond the launcher icon.
- A throwaway prototype where deep-link verification cost exceeds value.

**Halt conditions / mandatory cites**
- Each deep-link route MUST cite the resolver entry at `<path:line>` AND the platform manifest (Info.plist, AndroidManifest, AASA, assetlinks.json).
- Auth-gated routes MUST cite the auth check that precedes navigation.
- A doc proposing direct navigation from a notification handler without going through the resolver is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "all entry points are covered".
- If the universal-link domain verification (AASA, assetlinks.json) isn't extracted, halt.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Mobile`.
>
> - **Deep-link scheme**: `<app://>`
> - **Universal link domain**: `<https://example.com/>`
> - **iOS associated domains**: `<list>`
> - **Android App Links**: `<list of verified domains>`
> - **Linking config**: `<file path: linking.ts / app.json schemes / GoRouter>`
> - **Push notification handler**: `<file path>`

## Why this pattern matters

Every entry point that ISN'T the app icon needs deep-link handling:

- Push notification tap.
- Email link clicked.
- SMS link clicked.
- Sharing sheet (another app shares to yours).
- Web → app handoff (universal link).
- QR code scan.
- NFC tap (iOS NDEF / Android NFC).
- Voice assistant (iOS App Intents, Android Slices).

If any of these don't land the user on the right screen with the right state, the feature fails for that channel.

## Three layers

### 1. URL scheme (custom)

- iOS: `Info.plist` → `CFBundleURLTypes`.
- Android: `<intent-filter>` with `<data android:scheme="myapp" />`.
- RN: `app.json` `scheme` (Expo) or `react-native-deep-linking` config.
- Flutter: `flutter_app_links` / `uni_links` package + native config.

Use case: app-internal links (notifications opening specific screens). Browsers will warn before opening unknown schemes — not for cross-app sharing.

### 2. Universal links (iOS) / App Links (Android)

- Verified domain — server hosts `.well-known/apple-app-site-association` and `.well-known/assetlinks.json`.
- Same URL works in browser AND opens the app (if installed).
- iOS: `apple-app-site-association` JSON enumerates paths.
- Android: `assetlinks.json` declares the package + sha256 fingerprint.
- Test with `xcrun simctl openurl booted https://example.com/orders/123` and `adb shell am start -W -a android.intent.action.VIEW -d "https://example.com/orders/123"`.

Use case: every link you share publicly. Survives copy-paste, email forwarding.

### 3. Push notification routing

- Notification payload includes `screen` + params.
- Handler in app reads payload → navigates to the screen.
- Cold start: app launches AND lands on the deep-linked screen.
- Warm start (background): app resumes AND navigates.
- Foreground: usually shows in-app banner OR routes if user explicitly taps.

Common pitfall: navigation framework not yet initialized when push is delivered cold. Solution: queue the navigation intent until navigator is ready.

## Routing pattern

```
Push payload    →  parse  →  intent: { screen: 'OrderDetails', params: { id: '123' } }
Universal link  →  parse  →  intent: { screen: 'OrderDetails', params: { id: '123' } }
URL scheme      →  parse  →  intent: { screen: 'OrderDetails', params: { id: '123' } }
                                              ↓
                                    same intent shape
                                              ↓
                                       navigate(...)
```

Centralize parsing. ONE function that takes a URL or push payload and returns `{ screen, params }`. Every entry point calls it. Easier to test, easier to add new routes.

## Defensive patterns

### Auth-gated deep links

User taps deep link to an auth-required screen while logged out:
- Don't drop the link.
- Save the intent.
- Show login.
- After login → consume the saved intent → navigate.

### Stale deep links

Deep link to an entity that no longer exists (deleted / archived):
- Land on the entity's expected screen anyway.
- Show a "this is no longer available" state with a path back to the parent list.

### Permission-gated deep links

Deep link goes to a screen that requires camera permission. User has denied. Don't crash; show denial UX with path to settings.

### Outdated app version

Deep link from a new email mentions a feature that didn't exist in v1.0. App is on v1.0. Land somewhere reasonable + suggest update.

## Testing

| Channel | Test command |
|---|---|
| iOS scheme | `xcrun simctl openurl booted "myapp://orders/123"` |
| iOS universal link | `xcrun simctl openurl booted "https://example.com/orders/123"` |
| Android scheme | `adb shell am start -W -a android.intent.action.VIEW -d "myapp://orders/123" com.example.app` |
| Android App Link | `adb shell am start -W -a android.intent.action.VIEW -d "https://example.com/orders/123"` |
| Push (Expo) | `expo push --to <token> --data '{"screen":"OrderDetails","params":{"id":"123"}}'` |
| Push (FCM) | `curl -X POST "https://fcm.googleapis.com/v1/projects/<project-id>/messages:send" -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" -d '{"message":{"token":"<token>","data":{...}}}'` — HTTP v1 with an OAuth access token ([send a message](https://firebase.google.com/docs/cloud-messaging/send/v1-api)). The legacy `/fcm/send` endpoint with `Authorization: key=<server-key>` is retired; a test script still using it is a finding, not a working test. |

For each, test from cold start, warm start, foreground.

## Anti-patterns

- **String concatenation to build deep links** — use a builder; centralize URL construction.
- **Hardcoded screen names in payload parser** — refactor breaks deep links silently.
- **Universal link config that DOESN'T match server's `.well-known/apple-app-site-association`** — links open in browser instead of app.
- **Push handler that calls `navigation.navigate()` before the navigator is mounted** — silent failure on cold-start.
- **Notification opened, but UI loads with stale data** — refresh on land.
- **Universal link verifies on first install but degrades on update** — re-verify after every install / OS update.

## Project-specific anchors

(Phase 4.6 fills with the project's actual link parser function, navigation queue mechanism, push handler entry point, list of registered routes.)

## Related

- `push-notifications.md` (owns the push lifecycle; its tap handlers extract the payload and hand it to THIS pattern's route resolver — never navigate from the notification handler)
- `app-lifecycle.md` — a cold-start deep link races the navigator's readiness; that pattern owns what is ready when.
- `device-harness` (skill) — opens every row of the route table above on a real device instead of reading it off the config.
