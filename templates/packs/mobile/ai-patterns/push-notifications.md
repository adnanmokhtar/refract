---
name: push-notifications
description: Pattern — client-side push lifecycle (iOS APNs / Android FCM). Permission priming, device-token registration + server sync + invalidation, channels/categories, foreground presentation, and the three receipt states. Routing is delegated to deep-linking.
kind: ai-pattern
pack: mobile
---

# Pattern: Push notifications

> **Hard rule:** Push has a full lifecycle and every stage MUST be handled. Permission is requested at a justified in-context moment (never cold-start), the device token is registered on grant AND synced to the server with a user+device binding AND invalidated server-side on 410 / `NotRegistered` / logout, notifications are delivered through platform channels (Android O+) / categories (iOS), and receipt is handled in all three app states (foreground, background, killed). A bare token-request with no server sync, no channel setup, and no foreground-presentation handling is forbidden. The tap → screen navigation is NOT this pattern's job — it is delegated to `deep-linking`.

**When to apply**
- The app sends any push (alert, silent/background, rich, actionable) via APNs / FCM.
- Server-side campaigns, transactional alerts, or background data pushes target devices.
- A silent push must wake the app to trigger a sync (see `offline-sync`).

**When NOT to apply**
- A fully local app with no server and no remote-notification entitlement.
- Local-only reminders (calendar/alarm) that never touch APNs/FCM — those still need channels, but no token/server lifecycle.

**Halt conditions / mandatory cites**
- The permission request MUST cite the priming prompt + the in-context trigger at `<path:line>` — a cold-start request is a bug; reject.
- The device token MUST cite BOTH the registration handler AND the server-sync call (with user+device binding) at `<path:line>`.
- Token invalidation MUST cite the logout path AND the server-side 410/`NotRegistered` handling — an obtained-but-never-invalidated token is a bug; reject.
- Every Android O+ notification MUST cite its channel creation; a channelless notification is silently dropped — reject.
- Foreground-presentation handling MUST be cited (iOS `willPresent` opt-in; Android channel) or notifications vanish in-app.
- A doc that navigates directly from the tap handler instead of delegating to `deep-linking` is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "push is wired end-to-end".

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Mobile`.
>
> - **Push provider**: `<APNs direct / FCM / OneSignal / Expo push>`
> - **Token registration entry**: `<file path>`
> - **Server sync endpoint**: `<POST /devices — user+device+token+platform>`
> - **Invalidation path**: `<logout handler + 410/NotRegistered webhook consumer>`
> - **Android channels**: `<list: id + importance>`
> - **iOS categories/actions**: `<list>`
> - **Foreground presentation policy**: `<file path>`

## Permission UX

- **Prime before the OS dialog.** The system permission prompt is one-shot; a denial can't be re-requested in-app. Show a pre-permission priming screen that states the value ("Get notified when your order ships") AFTER the user has seen the feature's value — never at launch.
- **Timing.** Request at the moment the notification becomes meaningful (first order placed, first message thread), not on the splash screen.
- **iOS provisional authorization** (`provisional: true`) delivers quietly to Notification Center with no dialog — a low-friction path to earn trust, then upgrade to full alerts.
- **Denied path.** Once denied, the only route back is Settings. Detect denial, degrade the feature, and offer a deep link to the OS settings screen (`Linking.openSettings()` / `UIApplication.openSettingsURLString` / `Settings.ACTION_APP_NOTIFICATION_SETTINGS`).

## Token lifecycle

- **Register on grant.** Obtain the device token only after permission is granted (`getToken()` / `didRegisterForRemoteNotificationsWithDeviceToken`).
- **Sync to server.** POST the token with a user + device binding. The server addresses sends by user; the device id lets you replace a rotated token for the same device instead of accumulating duplicates.
- **Refresh on rotation.** Tokens rotate (reinstall, restore, OS refresh). Subscribe to the rotation callback (`onTokenRefresh` / `messaging().onTokenRefresh` / `didRegisterForRemoteNotifications`) and re-sync every time.
- **Invalidate.** On logout, unbind the token server-side. When APNs/FCM returns **410 Unregistered** / `NotRegistered`, delete the token server-side. Stale tokens waste send quota and — worse — leak notifications to a device that has been wiped and reassigned to another user.

## Channels (Android) & categories (iOS)

- **Android O+ channels are mandatory.** A notification posted with no channel is silently dropped on API 26+. Importance (urgent / high / default / low) is **per channel** and the user, not you, controls it after creation — you cannot re-prompt. Get the channel taxonomy right up front (e.g. `orders`, `chat`, `promos`) so users can mute promos without losing transactional alerts.
- **iOS categories + actions.** Register `UNNotificationCategory` with `UNNotificationAction`s to attach actionable buttons (Reply, Mark done) that fire without opening the app.

## Foreground presentation

- **iOS suppresses banners in the foreground by default.** You must opt in via `UNUserNotificationCenterDelegate.willPresent` (return `.banner`/`.list`/`.sound`) or the notification silently vanishes while the app is open.
- **Android** shows a foreground notification only if the channel's importance allows a heads-up display; low-importance channels post silently to the tray.

## Receipt states — payload arrives differently in each

| App state | Entry point | Payload delivered via |
|---|---|---|
| **Killed (cold start)** | user taps notification | initial-notification API (`getInitialNotification` / `launchOptions` / intent extras) — read once on launch |
| **Background (warm)** | user taps notification | notification-opened callback (`onNotificationOpenedApp` / `didReceiveResponse`) |
| **Foreground (in-app)** | notification arrives | foreground message/present handler — you decide whether to show it |

Handle all three. A tap-only handler misses the foreground case; a foreground-only handler misses cold-start deep entries.

## Payload types

- **Alert.** User-visible, wakes the tray. Default for transactional/marketing.
- **Silent / background** (`content-available: 1` iOS / `data`-only FCM). Wakes the app briefly to fetch — the trigger for `offline-sync`. Budget-limited and throttled by the OS. **Neither platform publishes a delivery rate**, so do not code against one — what determines whether a silent push wakes you is the same set of signals that governs any background execution: recent user engagement with the app, power state and low-power mode, network availability, and device idleness (see `app-lifecycle` for the sourced Android side of that list). Treat delivery as best-effort, do no heavy work per push, and back it with a foreground reconcile.
- **Rich media.** Image/video via a Notification Service Extension (iOS) / `NotificationCompat` big-picture style (Android).
- **Actionable.** Buttons wired to the iOS category / Android action.

## Badge, quiet hours & preferences

- **Badge management.** Reset the app icon badge when the user reads the content (`setBadgeCount(0)`); a badge count that never clears is a top complaint. Drive it from server-computed unread count, not local increment.
- **Quiet hours / preferences.** Honor per-category user preferences (persist via `native-storage`) and quiet-hours windows; prefer server-side suppression so a muted category never leaves the send side.

## Delivery diagnostics

- Read APNs/FCM response codes per token: **400** bad token, **410** unregistered (delete it), **429/`Unavailable`** back off, **200/`success`** delivered-to-provider (not to device — push is best-effort). Log per-token failures and feed 410s into the invalidation path.

## Routing hand-off

Parsing the tapped payload into a `{ screen, params }` intent and navigating — including cold-start navigator readiness, auth gating, and stale-entity handling — is owned entirely by **`deep-linking`**. This pattern's tap handlers extract the payload and pass it to the deep-linking route resolver. Do NOT call `navigation.navigate()` here.

## Adapt to the codebase

| Stack | Token API | Channel / category API |
|---|---|---|
| **React Native** (`@react-native-firebase/messaging` + notifee) | `messaging().getToken()` / `onTokenRefresh` | notifee `createChannel()` (Android) / `setNotificationCategories()` (iOS) |
| **React Native (Expo)** | `Notifications.getExpoPushTokenAsync()` / `getDevicePushTokenAsync()` | `Notifications.setNotificationChannelAsync()` / `setNotificationCategoryAsync()` |
| **Flutter** (`firebase_messaging` + `flutter_local_notifications`) | `FirebaseMessaging.instance.getToken()` / `onTokenRefresh` | `AndroidNotificationChannel` via plugin / `DarwinNotificationCategory` |
| **Native iOS** (`UNUserNotificationCenter` + APNs) | `registerForRemoteNotifications` → `didRegisterForRemoteNotificationsWithDeviceToken` | `setNotificationCategories(_:)` |
| **Native Android** (`FirebaseMessaging` + `NotificationManager`) | `FirebaseMessaging.getInstance().getToken()` / `onNewToken` | `NotificationManager.createNotificationChannel()` |

## Detectors (cite-or-halt)

1. **Permission at cold-start / no priming.**
   - BAD: `requestPermission()` in `App` mount / `AppDelegate.didFinishLaunching`.
   - GOOD: priming screen gates the request, fired from an in-context feature entry.
   - `grep -rniE "requestPermission|requestAuthorization|POST_NOTIFICATIONS" app/ src/ ios/ android/` — inspect the call site's trigger.
2. **Token obtained but never synced / never invalidated.**
   - BAD: `getToken()` result logged or held in state only; no `/devices` POST; no logout/410 unbind.
   - GOOD: token POSTed with user+device binding; logout + 410/`NotRegistered` delete it.
   - `grep -rniE "getToken|getExpoPushToken|deviceToken" src/ | ...` then confirm a server-sync + invalidation call exists.
3. **Android O+ notification with no channel.**
   - BAD: `NotificationCompat.Builder(ctx, ...)` posted with a channel id that was never created.
   - GOOD: `createNotificationChannel()` runs at startup for every channel id used.
   - `grep -rniE "NotificationCompat.Builder|createChannel|createNotificationChannel|setNotificationChannel" android/ src/`
4. **No foreground-presentation handling.**
   - BAD: no `willPresent` / `onMessage` / foreground handler — pushes vanish while app is open.
   - GOOD: foreground handler present and (iOS) returns a presentation option.
   - `grep -rniE "willPresent|onMessage|setForegroundPresentationOptions|onForegroundMessage" src/ ios/`
5. **Silent/background push with no budget/throttle awareness.**
   - BAD: `content-available` / data-only push assumed to always deliver and sync.
   - GOOD: silent push treated as best-effort, backed by a foreground reconcile; no per-push heavy work.
   - `grep -rniE "content-available|contentAvailable|setBackgroundMessageHandler|data-only" src/`
6. **Tap handler duplicating routing.**
   - BAD: `onNotificationOpenedApp(() => navigation.navigate(...))` — routing logic inline.
   - GOOD: tap handler passes the payload to the deep-linking resolver.
   - `grep -rniE "onNotificationOpenedApp|getInitialNotification|didReceive.*response" src/ ios/` — confirm delegation.
7. **No badge reset / stale badge.**
   - BAD: badge incremented, never cleared; icon shows a phantom count.
   - GOOD: `setBadgeCount(0)` on read, driven by server unread count.
   - `grep -rniE "setBadgeCount|applicationIconBadgeNumber|setBadge" src/ ios/`

## Closure verbs

- **Prime** the permission request at a justified in-context moment.
- **Register + sync** the token with a user+device binding; **refresh** on rotation.
- **Invalidate** the token on logout and on 410 / `NotRegistered`.
- **Create** every Android channel and iOS category up front.
- **Present** foreground notifications explicitly.
- **Handle** all three receipt states; **reset** the badge on read.
- **Delegate** tap → screen routing to `deep-linking`.

## Related

- `deep-linking.md` (owns tap → screen routing; this pattern hands the payload off — state the boundary)
- `offline-sync.md` (silent/background push as a best-effort sync trigger)
- `app-lifecycle.md` (what determines whether a background wake-up is granted at all; the foreground reconcile that repairs what never ran)
- `permissions.md` (every OS permission that is NOT the notification one — this pattern keeps notification priming)
- `native-storage.md` (token + notification-preference storage)
- `@mobile-architect` (design-level lifecycle — §6)
- `@app-store-reviewer` (permission-policy + notification-disclosure compliance)
- cross-pack `backend` `webhook-flow` (the server SEND side: APNs/FCM dispatch + 410 consumption)
