---
name: release-pipeline
description: Pattern — mobile release engineering. Identity separation across dev/beta/prod, signing material held by CI and never the repo, symbol upload as a build step, beta track before production, staged rollout with a halt criterion, and the dated store gates that block an upload. Platform file names live in references/; the discipline here is platform-neutral.
kind: ai-pattern
pack: mobile
---

# Pattern: Release pipeline

> **Hard rule:** Every build that reaches a human is produced by CI from a tagged commit, signed with material CI holds and the repository never contains, and uploads its **debug symbols** in the same job that produced the binary. Every production release goes to a **beta track first** and then to a **staged rollout with a written halt criterion**. A build signed on a laptop, a signing key committed to the repository, a release with no symbol upload, or a rollout with no stated condition for halting it, is forbidden.

**When to apply**
- Setting up the first CI build, the first beta distribution, or the first store submission.
- Planning a rollout, a phased release, or a hotfix path.
- Adding a step that produces or consumes signing material, provisioning, or store credentials.
- Onboarding a second developer — the moment "it builds on my machine" stops being a viable release process.

**When NOT to apply**
- What a reviewer will accept or reject in the app itself — `@app-store-reviewer` owns the content and metadata verdict.
- Delivering a JS-layer fix between store releases — `ota-updates` owns that mechanism and its native boundary.
- Which server contract change is safe for old clients — `mobile-api-contract`.
- Generic service deployment, container builds, or infrastructure — the `devops` pack. Mobile release engineering is different work: the artefact is signed, distributed by a third party, reviewed by a human, and installed at the user's discretion.

**Halt conditions / mandatory cites**
- Any release claim MUST cite the **CI job** that produced the binary and the **tag or commit** it was built from. A build whose provenance is a developer's machine cannot be reproduced or audited; reject.
- Any signing step MUST cite where the material lives — a secret store, not the repository. A key, keystore, provisioning profile, or API key found under version control is a **blocker**, not a finding; reject and rotate.
- Any release MUST cite the **symbol upload step** at `<path:line>` in the CI config. Without it every production crash is an unreadable stack trace.
- Any staged rollout MUST cite its **halt criterion** — the metric and the threshold at which a human stops it. "Watch the dashboards" is not a criterion.
- Any store-gate claim (target API level, SDK version, testing prerequisite) MUST cite the platform page that publishes it, with its date. An uncited deadline is a fabrication; reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming a release pipeline is complete.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Mobile` + the CI config.
>
> - **CI provider + release workflow**: `<file path>`
> - **Build identities**: `<dev / beta / prod bundle ids + application ids>`
> - **Signing material location**: `<secret store name — never a repo path>`
> - **Beta distribution**: `<TestFlight group(s) / Play testing track(s) / internal distribution>`
> - **Symbol upload step**: `<file path:line>`
> - **Rollout policy**: `<staged percentages used by this project + the halt criterion>`
> - **Store account type**: `<organization / personal — decides whether the closed-testing prerequisite applies>`

## Why this pattern matters

Mobile release engineering is a day-one problem that looks like a launch-week problem, and both readings produce a failure.

**Deferring it** is the common one. The first build is made on a laptop, the certificate lives in a developer's keychain, the keystore is in the repository "temporarily", and the first production crash arrives as `a.b.a` with no mapping file to un-mangle it. Every one of those is cheap to set up before there is an app and expensive to retrofit after there is a user base — and the store gates in this pattern have *dates*, which means the retrofit happens under a deadline you did not choose.

**Gold-plating it** is the other pole and it is real: a matrix build across six device profiles, three notification channels and a release-notes generator, for an app with no users. The floor below is deliberately small. It is the set of things whose absence costs you a release or a debuggable crash, and nothing else.

The thing that makes this pack's problem different from server deployment: **you cannot roll back an install.** Halting a rollout stops distribution; it does not retrieve the version already on someone's phone.

## Identity separation

Three build identities, separated at the platform's identifier level — not by a flag, a scheme name, or an environment variable.

| Identity | Points at | Installed alongside production? |
|---|---|---|
| **dev** | Local or staging services, verbose logging, debug tooling enabled | Yes — distinct identifier, distinct icon |
| **beta** | Production-shaped services (or a dedicated pre-prod), production logging | Yes — distinct identifier |
| **prod** | Production only | — |

Why identifier-level separation and not a runtime flag: push tokens, keychain entries, local databases, deep-link registrations and analytics identities are all keyed by the app identifier. A single identity switching environments at runtime cross-contaminates all of them, and the first symptom is usually a test push landing on a real user's phone.

Consequences to accept up front: three sets of push credentials, three deep-link configurations, three store/console entries where the platform requires one. That is the cost of never wondering which backend the crashing build was pointed at.

## Signing material never lives in the repository

The rule is absolute and its enforcement is mechanical: CI holds the material in a secret store; the repository holds only the *reference* to it.

- **Android** — Play App Signing splits the key you can lose from the key you cannot. Google holds the app signing key and "uses this key to sign the final APKs delivered to users' devices"; you hold an upload key that you "use… to sign your app bundle before uploading it to the Play Console. Google uses it to verify your identity." The asymmetry is the point: "If compromised or lost, Google can reset this key for you" ([Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)). Enrol at first release; retrofitting is possible but is a step nobody wants under time pressure.
- **Apple** — certificates, provisioning profiles, and an App Store Connect API key for automated upload. All three belong in the CI secret store. The API key in particular is what removes a human's credentials from the release path.
- **Both** — a leaked signing credential is a rotation event, not a cleanup task. Treat any occurrence in version control as a blocker, rotate, and then fix the pipeline that allowed it.
- **Restrict who can release.** The set of people who can publish to production should be smaller than the set who can merge, and it should be a deliberate list rather than whoever set up the account.

## The dated store gates

These are not advice. They are dated conditions that block an upload, and they are the class of thing a new project discovers at the worst possible moment. Each row cites the page that publishes it; re-read the source before acting, because these dates move.

| Gate | What it says | Source |
|---|---|---|
| **Apple SDK floor** | Since **April 28, 2026**: "Apps uploaded to App Store Connect must be built with Xcode 26 or later using an SDK for iOS 26, iPadOS 26, tvOS 26, visionOS 26, or watchOS 26." | [Apple upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) |
| **Apple age ratings** | Answers to the updated age-rating questions were required by **January 31, 2026**, "to avoid an interruption when submitting your app updates in App Store Connect." | [Apple upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) |
| **Apple required-reason APIs** | Since **May 1, 2024**: "You'll need to include approved reasons for the listed APIs used by your app's code to upload a new or updated app to App Store Connect." | [Apple developer news](https://developer.apple.com/news/?id=3d8a9yyh) |
| **Apple third-party SDK manifests** | Privacy manifests, and signatures for binary dependencies, are required for the SDKs on Apple's published list — which includes the major cross-platform frameworks, so it applies to cross-platform apps too. | [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) |
| **Play target API level** | From **August 31, 2026**, new apps and updates must target **Android 16 (API 36)** or higher (Wear OS and Automotive: API 35; Android TV and XR: API 34). Existing apps must target API 35 or higher to remain available to new users on newer OS versions. An extension to **November 1, 2026** can be requested in Play Console. | [Play target API requirements](https://developer.android.com/google/play/requirements/target-sdk) |
| **Play 16 KB page size** | "All apps targeting Android 15 (API level 35) and higher must support 16 KB memory page sizes on 64-bit devices on Google Play." From **February 1, 2027**, "if your app updates don't support 16 KB memory page sizes, you won't be able to release these updates." It binds any app carrying NDK libraries — "either directly or indirectly through an SDK" — which is every React Native, Flutter, Expo and Capacitor build, so a cross-platform project cannot treat this as a native-Android concern. Support is proved by **rebuilding**, not by a manifest flag. | [16 KB page sizes](https://developer.android.com/guide/practices/page-sizes) |
| **Play Data safety** | "Even developers with apps that do not collect any user data must complete this form and provide a link to their privacy policy." Non-compliance draws "policy enforcement, like blocked updates or removal from Google Play." | [Play Data safety](https://support.google.com/googleplay/android-developer/answer/10787469) |
| **Play foreground-service types** | "If your app targets Android 14 or higher, you'll need to declare your app's foreground service types in the Play Console's app content page (Policy > App content)." | [FGS types](https://developer.android.com/develop/background-work/services/fgs/service-types) |
| **Play closed-testing prerequisite (personal accounts created after 2023-11-13)** | The requirement applies to personal — not organization — developer accounts **created after November 13, 2023**. For those, production access requires a closed test with "a minimum of 12 testers who have been opted in continuously for at least 14 days", and "Testers who opt in, test for fewer than 14 days, and then opt out do not count toward the requirement." | [Play closed testing](https://support.google.com/googleplay/android-developer/answer/14151465) |

**Who owns these dates.** `@app-store-reviewer` § 1 carries the same gate set and **re-fetches every figure at review time** — it is the authority at submission. This table is the *planning* copy: it exists because these dates change the release schedule months before a build is ever uploaded. The two must move together; a correction to either is a correction to both.

**The last row is a schedule dependency, not a checklist item.** If the account is a personal one created after 2023-11-13, the launch date cannot be earlier than the day the continuous-testing window closes — and the window only starts once twelve real testers have opted in. Discover this in week one, not in launch week. Whether the account is personal or an organization is therefore a **release-planning input**, which is why it appears in the project-specific block above.

## Beta before production

Every production release has been on a beta track first. No exceptions for "it's a one-line fix" — one-line fixes are disproportionately represented in emergency rollbacks.

- **Apple / TestFlight** — internal testing covers "up to 100 App Store Connect users with access to your content"; external testing covers "up to 10,000 people". "You can test a build for up to 90 days" and "your build becomes unavailable for testers after 90 days." Note the review step: "When you add the first build of your app to a group, the build gets sent to App Review to make sure it follows the App Review Guidelines. A review is required only for the first build" ([TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)). That first-build review is a schedule item people forget when planning a beta.
- **Google Play** — internal, closed, and open testing tracks, promoted upward. For personal accounts the closed track is also a *prerequisite*, per the gate table above.
- **What beta is for:** catching what only real devices and real accounts reveal — install-over-upgrade paths, push on real hardware, deep links from real clients, permission dialogs in the real system language. It is not a substitute for tests; it is the only place some categories of bug exist.
- **Give beta a feedback channel that reaches the repository.** A crash reported in a chat thread and never filed is a crash you ship.

## Staged rollout and the halt criterion

- **Never publish to 100% at once.** The blast radius of a bad build is the entire installed base, and there is no recall.
- **Percentages are yours to choose.** Google Play documents that "when you roll out a release, you select the percentage of users who will receive your rollout" and that "your app's staged rollout percentage won't increase automatically" — it prescribes **no canonical ladder** ([staged rollouts](https://support.google.com/googleplay/android-developer/answer/6346149)). A project that uses a fixed ladder should record it in the project-specific block as *its own convention*, not as a platform rule.
- **Write the halt criterion before the rollout starts.** The metric, the threshold, the observation window, and who is allowed to call it. Deciding mid-incident produces the wrong answer slowly.
- **Halting is containment, not reversal.** "When you halt a staged rollout, no additional users will receive the app version in your existing staged rollout. Users who already received the app version in your staged rollout version will remain on that version" (same source). Plan the forward fix at the same time you plan the halt.
- **Watch the version you just shipped, not the aggregate.** A crash rate that looks fine across all versions can hide a new build failing badly at a small rollout percentage. Segment by app version or the rollout tells you nothing.
- **Do not start a rollout you will not be present for.** A staged rollout with nobody watching is a slower way to ship to everyone.

## Symbols are part of the build

Symbol upload belongs in the job that produced the binary. Not a manual step, not "we'll upload them if we need them" — the binary and its symbols are produced together and only together are they reproducible.

- **Apple platforms** — crash reporting "automatically processes your debug symbol (dSYM) files to give you deobfuscated and human-readable crash reports"; the build setting must produce them (Debug Information Format set to DWARF with dSYM File), and "when an upload fails, Crashlytics displays a 'Missing dSYM' alert in the Firebase console" ([Crashlytics deobfuscated reports](https://firebase.google.com/docs/crashlytics/get-deobfuscated-reports)). Treat that alert as a build failure, not a notification.
- **Android** — the shrinker "shortens the names of classes, fields, and methods (for example, `com.example.MyActivity` could become `a.b.a`)", and the documentation warns that "enabling app optimization makes stack traces difficult to understand, especially if R8 renames class or method names" ([shrink your app](https://developer.android.com/studio/build/shrink-code)). The `mapping.txt` produced by that build is what makes production stack traces readable; upload it with the release and retain it per release.
- **Retain per release, forever-ish.** A crash reported against a version from eight months ago needs that version's symbols. Symbols deleted with the CI workspace are gone.

## Store-release, kill-switch, or OTA

Three delivery mechanisms with different latencies and different rules. Pick deliberately.

| Situation | Mechanism | Why |
|---|---|---|
| Native change, new dependency, permission change, SDK bump | Store release | Nothing else can deliver it, and the store's rules say so (`ota-updates` owns the boundary). |
| A feature is misbehaving and can be turned off | Kill switch / remote config | Fastest, reversible, no review. `mobile-api-contract` owns the flag discipline. |
| JS-layer bug fix within reviewed scope | OTA update | Faster than a release; constrained by what the store permits. `ota-updates` owns it. |
| Server can absorb the fix | Server change | Reaches everyone, including versions you could not otherwise fix — subject to the additive rule in `mobile-api-contract`. |

**Prefer the mechanism that reaches the most installs fastest and is easiest to reverse** — which usually means the server, then the flag, then OTA, then the store. Reach for the store release when the others genuinely cannot carry the change, not by default.

## Adapt to the codebase

| Concern | What to look for, whatever the stack |
|---|---|
| Release workflow | A CI workflow triggered by a tag, not by a push to a branch |
| Version + build number | Derived in CI from the tag or run number, never hand-edited in two places |
| Signing | A secret-store reference; a decrypt step scoped to the release job |
| Symbols | An upload step in the same job as the build |
| Beta distribution | An automated upload to the platform's beta track on every tagged build |
| Release notes | Generated from the tag range, not written from memory at submission time |

Cross-platform toolchains bundle several of these behind one command; native projects wire them individually. The steps are the same either way — the file names differ, and platform-specific file names, commands, and credential types belong in this pack's per-platform files under `references/`, not here.

## Detectors (cite-or-halt)

1. **Signing material in the repository.**
   - BAD: a keystore, `.p12`, `.mobileprovision`, `.p8`, or a password in a properties file under version control.
   - GOOD: only a reference to a secret-store entry.
   - `git ls-files | grep -niE "\.(keystore|jks|p12|pem|p8|mobileprovision|cer)$"` and `grep -rniE "storePassword|keyPassword|ASC_KEY|API_KEY" --include='*.properties' --include='*.gradle*' --include='*.plist' .` — any hit is a blocker; rotate.
2. **No CI release workflow.**
   - BAD: releases produced locally; no workflow file references a store upload.
   - GOOD: a tag-triggered workflow that builds, signs, uploads symbols, and distributes to beta.
   - `ls -a .github/workflows .gitlab-ci.yml bitrise.yml codemagic.yaml fastlane 2>/dev/null` — then read the release job.
3. **Missing symbol upload.**
   - BAD: a release job that builds and uploads a binary but never uploads dSYMs or `mapping.txt`.
   - GOOD: symbol upload in the same job, and a failure there fails the build.
   - `grep -rniE "dSYM|upload-symbols|mapping.txt|uploadCrashlyticsMappingFile|sentry-cli" .github/ fastlane/ ci/ 2>/dev/null`
4. **Shared identity across environments.**
   - BAD: one bundle id / application id for every environment, switched by a runtime flag.
   - GOOD: distinct identifiers per identity, so both can be installed side by side.
   - `grep -rniE "applicationId|PRODUCT_BUNDLE_IDENTIFIER|bundleIdentifier" android/ ios/ app.json app.config.* 2>/dev/null`
5. **Direct-to-production release path.**
   - BAD: the release job publishes to the production track with no beta step and no rollout percentage.
   - GOOD: beta track first; production behind a staged rollout.
   - Read the release job's target track / destination.
6. **No halt criterion recorded.**
   - BAD: a rollout policy that says "monitor" with no metric and no threshold.
   - GOOD: metric, threshold, window, and owner written down before the rollout.
   - Read the project-specific block above; absence is the finding.
7. **Version number edited by hand in more than one place.**
   - BAD: version strings in a manifest, a project file, and a package file, drifting apart.
   - GOOD: one source, propagated by the build.
   - `grep -rniE "versionName|versionCode|MARKETING_VERSION|CURRENT_PROJECT_VERSION|\"version\":" android/ ios/ package.json pubspec.yaml 2>/dev/null`

## Closure verbs

- **Separate** the three build identities at the platform identifier level.
- **Move** every piece of signing material into the CI secret store, and rotate anything that was in the repository.
- **Automate** the release from a tag so no binary is built on a laptop.
- **Upload** symbols in the job that produced the binary, and fail the build when it fails.
- **Route** every release through a beta track before production.
- **Stage** the production rollout and **write** its halt criterion before starting.
- **Record** the store account type and the gate dates that apply to it.
- **Derive** the version and build number from one source.

## Anti-patterns

- **The laptop release** — reproducible only by one person, on one machine, with one keychain. It works until that person is unavailable, which is exactly when a hotfix is needed.
- **The temporary keystore commit** — never temporary. Rotation is the only remedy.
- **Symbols as a follow-up task** — the first production crash is when you discover the mapping file for that build no longer exists.
- **One identity for all environments** — cross-contaminated push tokens, keychain entries and analytics, and no way to install beta beside production.
- **Full-rollout by default** — the entire installed base as the canary group, with no recall.
- **A halt criterion invented during the incident** — the thresholds get set to whatever makes the current number look acceptable.
- **Discovering a store gate at submission** — the target-API and closed-testing gates in the table above have dates; they are plannable, and only ever painful when they are not planned.
- **Treating a halted rollout as a rollback** — the users who already updated are still on the bad build; the forward fix is still required.
- **A beta group of one** — the developer who wrote the change is the worst available tester of it.

## Boundary

This pattern owns **how a build becomes a release**: identity separation, signing custody, symbol upload, beta gating, staged rollout, and the dated store gates that block an upload.

It does not own: whether the app's content and metadata will pass review (`@app-store-reviewer`); the JS-layer delivery mechanism and what it may contain (`ota-updates`); which server change is safe for shipped clients (`mobile-api-contract`); the permission and privacy declarations themselves (`permissions` — this pattern owns the *deadline* by which they must exist); bundle and binary size (`optimize-bundle`); platform-specific command names and credential types (this pack's `references/`).

The `devops` pack owns service deployment and infrastructure. It does not currently own mobile release engineering, and this pattern is where that work belongs until it does.

## Related

- `@app-store-reviewer` — runs before submission; this pattern gets the artefact to the point where submission is possible.
- `ota-updates.md` — the other delivery mechanism, with its own boundary rules; the decision table above routes between them.
- `mobile-api-contract.md` — kill switches and version gates are the fast alternatives to a store release.
- `permissions.md` — the declarations the dated gates enforce.
- `app-lifecycle.md` — a staged rollout is watched through crash and stability data, which is only readable if lifecycle-related crashes are symbolicated.
- `optimize-bundle` (command) — binary size is measured against store limits before submission.
- `device-harness` (skill) — installs and drives a build on a real device or simulator before it reaches a beta tester.

## Sources

- Apple, [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) — Xcode/SDK floor and age-rating dates.
- Apple, [privacy updates for App Store submissions](https://developer.apple.com/news/?id=3d8a9yyh) — required-reason API enforcement.
- Apple, [third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) — privacy manifests and signatures.
- Apple, [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview) — tester counts, 90-day build window, first-build review.
- Google Play, [target API level requirements](https://developer.android.com/google/play/requirements/target-sdk) — dates, levels, and the extension.
- Google Play, [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469) — the form is required of every app.
- Google Play, [closed testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465) — 12 testers, 14 continuous days.
- Google Play, [staged rollouts](https://support.google.com/googleplay/android-developer/answer/6346149) — percentage selection and what halting does.
- Google Play, [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756) — app signing key vs upload key.
- Android, [foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types) — Play Console declaration.
- Android, [shrink your app](https://developer.android.com/studio/build/shrink-code) — obfuscation and the mapping file.
- Firebase, [get deobfuscated crash reports](https://firebase.google.com/docs/crashlytics/get-deobfuscated-reports) — dSYM processing and the missing-dSYM alert.
