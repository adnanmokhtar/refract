---
name: permissions
description: Pattern — OS permission lifecycle. The four-state model, the one-shot dialog and why priming exists, re-check-on-every-use, degrade-don't-crash, and the declaration surface (purpose strings, privacy manifest, data-safety form, foreground-service types). Notification permission is delegated to push-notifications.
kind: ai-pattern
pack: mobile
---

# Pattern: Permissions

> **Hard rule:** Every OS permission is requested at the moment the user asked for the capability, behind an in-app pre-prompt that states the value, and is **re-checked on every use** — never cached as a boolean at startup. Every requested permission MUST have a code path that works when it is denied, and a declaration (purpose string / manifest entry / store form) that matches what the code actually does. A permission requested at launch, a permission checked once and remembered, a permission with no denied path, or a permission declared but unreachable in code, is forbidden.

**When to apply**
- The feature needs any OS-gated capability: camera, microphone, photo library, location (foreground or background), contacts, calendar, health, motion, Bluetooth, local network, exact alarms, or a foreground service.
- A dependency is being added that requests a permission transitively (SDKs pull permissions in via manifest merge).
- Store metadata, a privacy manifest, or a data-safety declaration is being written or changed.

**When NOT to apply**
- Notification permission **alone** — `push-notifications` owns notification priming, the provisional-authorization path, and the channel/category taxonomy. Apply this pattern for notifications only when they land alongside other permissions.
- App-level authorization (roles, entitlements, feature flags). That is not an OS permission; the `security` pack owns it.
- A capability with no OS gate (reading your own app-container files, in-app camera roll you generated yourself).

**Halt conditions / mandatory cites**
- Every request site MUST cite the **in-context trigger** at `<path:line>` — a request fired from app start, a splash screen, an onboarding carousel, or a screen-mount effect is a bug; reject.
- Every request site MUST cite its **pre-prompt** at `<path:line>` and the **denied path** at `<path:line>`. A request with no denied branch is a crash waiting for a review build; reject.
- Every permission in the manifest / `Info.plist` MUST cite the code path that uses it. A declared-but-unreachable permission is a removal target, not a finding to defer.
- Every permission MUST cite its **declaration text** — the iOS purpose string, the Android rationale copy — and that text must describe the actual use. "Needed for app to work" is a rejection, not a purpose string.
- A claim that "the permission is handled" MUST cite the **re-check** call site, not the request site. Those are different lines and only one of them survives the user revoking access in Settings.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming a permission is wired end-to-end.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Mobile`.
>
> - **Permissions in use**: `<list: permission → feature that needs it → request site>`
> - **Permission wrapper**: `<the single module every request goes through, or "none — requests are scattered">`
> - **Purpose strings source**: `<Info.plist keys / config plugin / build-time template>`
> - **Android manifest source**: `<AndroidManifest.xml / config plugin / manifest merge from dependency>`
> - **Settings-deep-link helper**: `<file path>`
> - **Privacy manifest / data-safety declaration owner**: `<file path or store console>`

## Why this pattern matters

Permissions fail in two opposite directions and a codebase usually contains both.

**Asking too early** burns the one shot you get. On Android, "if the user taps Deny for a specific permission more than once during your app's lifetime of installation on a device, the user will no longer see the system permissions dialog if your app requests that permission again. The user's action implies 'don't ask again,' and is considered a permanent denial" ([developer.android.com/training/permissions/requesting](https://developer.android.com/training/permissions/requesting)). A permission requested on the splash screen — before the user has any idea what it buys them — converts a large share of installs into permanently denied ones, and the only route back is the Settings app.

**Asking for everything** is the other pole, and it costs you at review rather than at runtime. Apple's guideline 5.1.1(iii) is explicit: "Apps should only request access to data relevant to the core functionality of the app and should only collect and use data that is required to accomplish the relevant task. Where possible, use the out-of-process picker or a share sheet rather than requesting full access to protected resources like Photos or Contacts" ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)).

Between the two poles sits the failure that produces the actual support tickets: **treating a permission as a fact rather than a state**. It is revocable from Settings at any time, it is reset automatically after disuse, and on the one-time grant it expires while your app is still installed and still running.

## The four-state model

A permission is never a boolean. Model it as four states, because the correct UI differs in each.

| State | What it means | What the app does |
|---|---|---|
| **Not determined** | Never asked. The one-shot dialog is still available. | Show the pre-prompt. Only then request. |
| **Granted** | Access available *right now*. | Use it — and still handle failure, because it can be revoked mid-session. |
| **Denied (recoverable)** | Refused, but the system dialog is still reachable. | Degrade. Offer the pre-prompt again at the next genuine in-context moment. Do not nag. |
| **Permanently denied / restricted** | The dialog will not appear again (Android's implied "don't ask again"), or policy/parental controls block it outright. | Degrade permanently. Offer a deep link to the OS settings screen. Never show a dialog that cannot appear. |

Two states most codebases miss:

- **One-time grants.** From Android 11 (API 30) the dialog offers "Only this time" for location, microphone and camera. Access lasts while the activity is visible, and "if the user revokes the one-time permission, such as in system settings, your app cannot access the data, regardless of whether you launched a foreground service. As with any permission, if the user revokes your app's one-time permission, your app's process terminates" ([Android permissions](https://developer.android.com/training/permissions/requesting)). Your process ending is a supported outcome of a permission change — design for it.
- **Auto-reset after disuse.** When an unused app hibernates, "your app's runtime permissions are reset. This action has the same effect as if the user viewed a permission in system settings and changed your app's access level to Deny" ([app hibernation](https://developer.android.com/topic/performance/app-hibernation)). A returning user is a *not-determined* user again.

## The pre-prompt contract

The pre-prompt is an in-app screen you control, shown before the OS dialog you do not control. It exists because the OS dialog is one-shot; that causal link is the whole justification, and a pre-prompt that appears *after* the dialog is decoration.

The contract:

1. **Value before dialog.** State what the user gets, in the user's words, tied to the action they just took.
2. **A way out that is not "Deny".** Android's own guidance: "In this UI, include a 'cancel' or 'no thanks' button that lets the user continue using your app without granting the permission" ([Android permissions](https://developer.android.com/training/permissions/requesting)). Declining your pre-prompt costs nothing; declining the OS dialog can cost the capability forever.
3. **Triggered by the capability, not by the screen.** The camera pre-prompt belongs on the tap of "Take photo", not on the mount of the screen that contains the button.
4. **Consistent with the purpose string.** The pre-prompt copy and the platform purpose string describe the same use. A mismatch reads as a bait-and-switch to a reviewer and to a user.
5. **Shown at most once per genuine attempt.** Re-priming on every screen visit is nagging; the platform will not stop you, and users will.

The *visual* design of the pre-prompt — layout, type scale, contrast, button hierarchy — is not this pattern's call. That is the `ui-ux` pack's floor, and this pattern never re-audits it.

## Re-check on every use

Cache the *capability*, never the *permission*. Between two uses the user can revoke in Settings, the OS can auto-reset after disuse, a one-time grant can expire, and on Android a revocation terminates the process outright.

- Check immediately before the call that needs it — not at startup, not on navigation, not in a provider that runs once.
- Treat the check as cheap. It is a synchronous system query; the "optimisation" of caching it is how apps ship the "camera is black" bug.
- Re-check on foreground. The user may have just returned from Settings, which is exactly where you sent them.
- Never store a granted-flag in local storage. That flag is stale the moment the app is backgrounded.

## Degrade, don't crash

Every permission needs a designed denied path, and "show an error toast" is not one. The question to answer per capability: *what is the smaller product that still works?*

| Capability | Degraded path that still ships value |
|---|---|
| Camera | Fall back to the system photo picker (no permission needed on modern OS versions) or file import. |
| Photo library (full access) | Use the out-of-process picker — the user selects, you receive, no library permission is held. |
| Location (precise) | Accept coarse location; or ask for a manual place entry; or use the last known server-side region. |
| Location (background) | Foreground-only mode with an explicit "open the app to update" contract. Never silently do nothing. |
| Contacts | Manual entry plus an invite link. The feature narrows; it does not disappear. |
| Microphone | Text input path for the same intent. |
| Calendar | Generate a downloadable event file instead of writing directly. |
| Local network / Bluetooth | Manual pairing / manual address entry, plus a clear statement of what is unavailable. |

Two rules that fall out of the table: prefer the **picker over the permission** wherever the platform offers one (it is also what Apple's 5.1.1(iii) asks for), and make the degraded path reachable *without* first hitting a denial — a user who never grants must still be able to find it.

## The declaration surface

Permissions are half a runtime problem and half a paperwork problem, and the paperwork half is what blocks an upload. It belongs here because it must be written by whoever adds the permission, not discovered at submission.

| Declaration | What it is | Source |
|---|---|---|
| **iOS purpose strings** | A per-permission string shown inside the system dialog. "Ensure your purpose strings clearly and completely describe your use of the data." | [Guideline 5.1.1(ii)](https://developer.apple.com/app-store/review/guidelines/) |
| **Data minimisation** | Only request what core functionality needs; prefer pickers and share sheets to full access. | [Guideline 5.1.1(iii)](https://developer.apple.com/app-store/review/guidelines/) |
| **Privacy manifest — required-reason APIs** | Approved reasons for a listed set of APIs. Since **May 1, 2024**: "You'll need to include approved reasons for the listed APIs used by your app's code to upload a new or updated app to App Store Connect." | [Apple developer news](https://developer.apple.com/news/?id=3d8a9yyh) |
| **Third-party SDK manifests + signatures** | "You must include the privacy manifest for any SDK listed below when you submit new apps in App Store Connect that include those SDKs… Signatures are also required in these cases where the listed SDKs are used as binary dependencies. Any version of a listed SDK, as well as any SDKs that repackage those on the list, are included in the requirement." The list includes the major cross-platform frameworks and analytics/networking SDKs — so this applies to cross-platform apps, not only native ones. | [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) |
| **Play Data safety form** | "All developers must declare how they collect and handle user data for the apps they publish on Google Play… Even developers with apps that do not collect any user data must complete this form and provide a link to their privacy policy." Discrepancies draw "policy enforcement, like blocked updates or removal from Google Play." | [Play Data safety](https://support.google.com/googleplay/android-developer/answer/10787469) |
| **Android foreground-service types** | "Beginning with Android 14 (API level 34), you must declare an appropriate service type for each foreground service… you must declare the service type in your app manifest, and also request the appropriate foreground service permission for that type (in addition to requesting the `FOREGROUND_SERVICE` permission)." And: "If your app targets Android 14 or higher, you'll need to declare your app's foreground service types in the Play Console's app content page (Policy > App content)." | [FGS types](https://developer.android.com/develop/background-work/services/fgs/service-types) |

**The declaration is a claim about your code.** A manifest entry with no call site is a claim you cannot support; delete the entry. A call site with no declaration is an upload that fails or a review that pushes back. Keep them generated from, or checked against, one list.

## Permissions that draw extra scrutiny

These are not "harder to get" — they are the ones where a reviewer or the console will ask you to justify the use, and where a vague purpose string is the difference between a same-week release and a round trip. Have the justification written before you add the permission:

- **Background location** — needs a use that genuinely cannot work in the foreground.
- **Exact alarms** — needs a user-facing scheduling promise, not convenience.
- **Foreground-service types** — each type carries its own permission and its own Play Console declaration (see the table above).
- **Full photo-library access** where the picker would do — the guideline explicitly names the picker as the preferred route.
- **Accessibility / device-admin / usage-stats style APIs** — powerful, and treated as such.
- **Contacts, health, and anything a data-safety form classes as sensitive** — the store form and the purpose string must agree with each other and with the code.

This pattern deliberately publishes **no approval rates and no review-outcome numbers**. What determines the outcome is whether the justification, the purpose string, the declared data use and the code agree — not a percentage. `@app-store-reviewer` owns the review verdict.

## Adapt to the codebase

Route every request through one wrapper module, whatever the stack. Scattered request sites are how a project ends up with two different pre-prompts and one missing denied path.

| Stack | Check / request | Settings deep link |
|---|---|---|
| **Cross-platform (JS runtime)** | A permissions module exposing `check` / `request` returning a *state*, not a boolean | `Linking.openSettings()` or equivalent |
| **Cross-platform (Dart runtime)** | A permission-handler package exposing status objects with a permanently-denied case | The package's `openAppSettings()` |
| **Native iOS** | Per-framework authorization status APIs (capture, photos, location, contacts…) each with their own status enum | `UIApplication.openSettingsURLString` |
| **Native Android** | `ContextCompat.checkSelfPermission()` + `shouldShowRequestPermissionRationale()` + an `ActivityResultLauncher` | `ACTION_APPLICATION_DETAILS_SETTINGS` intent |

The names differ; the four states do not. If the stack's API returns a boolean, the wrapper's job is to widen it back into the four states before the UI ever sees it.

## Detectors (cite-or-halt)

1. **Request at launch / no in-context trigger.**
   - BAD: a request in an app-root mount, splash controller, or `didFinishLaunching`.
   - GOOD: the request is reached from the tap that needs the capability.
   - `grep -rniE "requestPermission|requestAuthorization|checkSelfPermission|ActivityResultLauncher|PermissionHandler" src/ app/ lib/ ios/ android/` — then read each call site's trigger.
2. **Permission cached as a boolean.**
   - BAD: `hasCamera` written to storage or held in a startup-scoped store.
   - GOOD: status queried immediately before use and on foreground.
   - `grep -rniE "hasPermission|permissionGranted|isGranted" src/ app/ lib/` — flag any that is persisted or module-scoped.
3. **No permanently-denied branch.**
   - BAD: `if (granted) {…} else { showToast() }` — two states for a four-state world.
   - GOOD: a switch over the four states, with a settings deep link on the permanent branch.
   - `grep -rniE "openSettings|openAppSettings|APPLICATION_DETAILS_SETTINGS|shouldShowRequestPermissionRationale"` — absence across the repo is the finding.
4. **Declared but unreachable.**
   - BAD: an `Info.plist` usage key or a `<uses-permission>` with no call site (often inherited via manifest merge from a dependency).
   - GOOD: every declared permission maps to a cited call site.
   - `grep -oE "NS[A-Za-z]+UsageDescription" ios/**/Info.plist; grep -oE 'uses-permission android:name="[^"]+"' android/app/src/main/AndroidManifest.xml` — diff that list against the request sites from detector 1.
5. **Purpose string is boilerplate.**
   - BAD: "This app requires access to your camera." — restates the API, describes no use.
   - GOOD: names the feature and the benefit.
   - `grep -A1 -E "NS[A-Za-z]+UsageDescription" ios/**/Info.plist` — read every string; flag any that would be true of every app on the store.
6. **Foreground service without a declared type.**
   - BAD: a foreground service declared with no `android:foregroundServiceType` and no matching `FOREGROUND_SERVICE_*` permission.
   - GOOD: type in the manifest, matching permission requested, and the type declared in the Play Console.
   - `grep -nE "foregroundServiceType|FOREGROUND_SERVICE" android/app/src/main/AndroidManifest.xml`
7. **No re-check after returning from Settings.**
   - BAD: the settings deep link is offered, but nothing re-evaluates on foreground, so the UI stays denied after the user grants.
   - GOOD: a foreground listener re-runs the check (see `app-lifecycle` for the listener itself).
   - `grep -rniE "AppState|addObserver|onResume|lifecycleScope|didBecomeActive" src/ app/ lib/` — confirm one of them re-checks permissions.

## Closure verbs

- **Prime** the request behind an in-context pre-prompt that states the value.
- **Widen** a boolean permission check into the four-state model.
- **Degrade** every capability along its designed denied path.
- **Deep-link** to OS settings on the permanently-denied branch only.
- **Re-check** on every use and on foreground.
- **Remove** every declared permission with no call site.
- **Rewrite** every purpose string that does not describe the actual use.
- **Declare** foreground-service types in the manifest, the permission set, and the store console together.

## Anti-patterns

- **The onboarding permission gauntlet** — four dialogs before the first screen. Maximises permanent denials and is the single most common cause of a feature that "doesn't work" for a user who cannot remember denying anything.
- **Permission as a boolean in storage** — survives revocation, survives auto-reset, and lies in both cases.
- **Re-prompting on every mount** — the OS will not show the dialog after a permanent denial, so this loop shows the user nothing while feeling broken.
- **Asking for the powerful version first** — full library access where a picker would do; background location where foreground would do. Costs you at review and at the dialog.
- **Inherited permissions nobody chose** — a dependency merges a permission into your manifest; it appears on the store listing and in the data-safety form, and no one in the repo can say why. Audit the merged manifest, not just the one you wrote.
- **Purpose strings written at submission time** — by then the person who knows the actual use has moved on, and the string becomes "required for functionality".
- **A denied path that only exists in the error handler** — degradation the user cannot find until they have already failed.

## Boundary

This pattern owns the **permission lifecycle and its declarations**: the four states, the pre-prompt, re-checking, degradation, and the manifest/purpose-string/store-form surface that must agree with the code.

It does not own: notification permission priming and the channel/category taxonomy (`push-notifications`); what happens to work that is already running when the app leaves the foreground, and foreground-service *scheduling* as opposed to *declaration* (`app-lifecycle`); protecting data once collected (`native-storage`); the review verdict and store metadata (`@app-store-reviewer`); the visual design of the pre-prompt (`ui-ux` pack); the threat model for the data a permission unlocks (`security` pack).

## Related

- `push-notifications.md` — owns notification permission end to end, including provisional authorization. This pattern defers that one case entirely.
- `app-lifecycle.md` — a revoked permission can terminate the process; foreground-service *types* are declared here, but *when a service may run* is that pattern's.
- `native-storage.md` — where the data a permission unlocked is allowed to live.
- `release-pipeline.md` — the store-console side of the declarations above, and the dated gates that enforce them.
- `@app-store-reviewer` — owns the review verdict; this pattern owns having a defensible answer ready.
- `@mobile-architect` — decides which capabilities the product genuinely needs before any of this applies.

## Sources

- Apple, [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — 5.1.1(ii) purpose strings, 5.1.1(iii) data minimisation.
- Apple, [privacy updates for App Store submissions](https://developer.apple.com/news/?id=3d8a9yyh) — required-reason API enforcement from May 1, 2024.
- Apple, [third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) — privacy manifests and signatures for listed SDKs.
- Android, [request runtime permissions](https://developer.android.com/training/permissions/requesting) — permanent denial, rationale UI, one-time permissions.
- Android, [app hibernation](https://developer.android.com/topic/performance/app-hibernation) — permission auto-reset for unused apps.
- Android, [foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types) — manifest, permission, and Play Console declaration.
- Google Play, [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469) — declaration required of every app.
