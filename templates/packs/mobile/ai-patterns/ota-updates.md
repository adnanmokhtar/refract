---
name: ota-updates
description: Pattern — over-the-air (JS-bundle) updates. Ship only the layer the store allows, stage/rollback every rollout, and gate a mandatory update behind a version check.
kind: ai-pattern
pack: mobile
---

# Pattern: OTA updates

> **Hard rule:** Over-the-air updates ship ONLY the JS/asset layer the store allows, are staged (percentage rollout) and rollback-able, and gate a mandatory update behind a min-supported-version check. Shipping a native change via OTA, or a force-update with no rollback path, is forbidden.

**When to apply**
- The app uses a JS-bundle runtime (React Native, Expo, Capacitor/Ionic) and ships fixes between store releases.
- A hotfix must reach users faster than a store review cycle allows.
- The app must force old clients off a broken/removed API version.

**When NOT to apply**
- A fully native app with no JS/web bundle layer — every change is a store release; there is no OTA surface.
- A change that touches native code, native dependencies, or app permissions — that CANNOT go OTA; it needs a store build.

**Halt conditions / mandatory cites**
- An OTA update MUST cite that the diff is JS/assets ONLY — if it touches native modules, native deps, or `Info.plist`/`AndroidManifest` permissions, reject it as a store-policy violation (Apple's downloaded-code rule, guideline **2.5.2** — see § store-policy conformance below).
- A mandatory/force update MUST cite BOTH the min-supported-version gate AND a rollback path — a force-update with no rollback is a bug; reject.
- A rollout MUST cite its staging (percentage or channel), not "publish to 100%".
- The update-apply UX MUST cite where it applies (on-launch / on-resume) and the safe-restart mechanism — an update swapped mid-session with no controlled restart is a bug.
- Hand-wave grep on `etc.`, `...`, `appears to` is forbidden when claiming "this update is JS-only".

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Mobile`.
>
> - **OTA provider**: `<Expo EAS Update / self-hosted CodePush / hand-rolled bundle host / Capacitor live updates>`
> - **Update channel(s)**: `<production / staging / preview>`
> - **Min-supported-version source**: `<remote config key / API version header / file>`
> - **Runtime version policy**: `<how JS bundle is pinned to a native build>`
> - **Rollback mechanism**: `<republish previous / channel repoint / provider rollback command>`
> - **Update-check entry point**: `<file path>`

## Why this pattern matters

OTA is the fastest path to users and the fastest path to a bricked install. The two failure modes are equal and opposite: shipping too much (a native change that OTA can't actually deliver, so it crashes on launch) and shipping too recklessly (100% blast radius, no rollback, a forced update with no escape). This pattern draws the line on both.

## The native-vs-JS update boundary

An OTA update replaces the JS bundle and bundled assets. It CANNOT change native code.

| Change | Delivery |
|---|---|
| JS logic, React components, styles, bundled images/fonts | ✅ OTA |
| A copy/config/feature-flag tweak | ✅ OTA |
| New native module / native dependency version | ❌ store release |
| Permission change (`Info.plist` / `AndroidManifest`) | ❌ store release |
| SDK/runtime upgrade that bumps the native shell | ❌ store release |
| App icon / splash / entitlements | ❌ store release |

Store-policy conformance: the App Review Guideline that governs downloaded code is **2.5.2**, which says apps "may not read or write data outside the designated container area, nor may they download, install, or execute code which introduces or changes features or functionality of the app, including other apps" ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)). An OTA that ships a native change or materially new functionality therefore risks rejection AND — because the native shell doesn't match — a crash on launch. Keep OTA to bug fixes and reviewed-scope changes. Pin every JS bundle to a **runtime version** so it only lands on a native build that can actually run it (a bundle expecting a native module the installed shell lacks = crash).

> **Cite the right section.** Guideline **3.3.2** is a section of the Apple Developer Program License Agreement, not of the App Review Guidelines — the Guidelines have no §3.3 at all. A finding that cites "3.3.2" against the Review Guidelines is citing a document the reviewer is not reading; use 2.5.2.

## Staged / percentage rollout

- Never publish to 100% at once — a bad bundle then hits every user with no containment.
- Roll out by percentage or channel, watching crash-free rate + error telemetry between stages. **The percentages are the project's convention, not a platform rule** — Google Play documents that "when you roll out a release, you select the percentage of users who will receive your rollout" and prescribes no ladder ([staged rollouts](https://support.google.com/googleplay/android-developer/answer/6346149)); OTA providers likewise let you pick. Record this project's ladder in the project-specific block above and treat it as a house convention.
- Halt/rollback the moment crash-free rate or a key metric regresses; a JS crash-loop from a bad bundle can lock users out of the very screen that would fetch the fix.

## Mandatory vs optional update gating

- **Optional** — update downloads in the background, applies on next safe restart, user never blocked.
- **Mandatory** — gated behind a **min-supported-version** check: the client asks the server (remote config / API version header) for the minimum version it still accepts; if the installed version is below it, block with an update prompt.
- Use mandatory sparingly and only for real breakage: a removed/broken API old clients hit, a security fix, a data-format change. A mandatory native-store update also needs an escape hatch (link to the store) — you cannot OTA a native update.

## Rollback path

- Every rollout has a one-step reversal: republish the previous bundle, repoint the channel, or the provider's rollback command.
- A **force-update with no rollback is forbidden** — if the forced version is itself broken, users are stuck with no way forward and no way back.
- Rollback must be faster than a store review; that's the entire reason OTA exists.

## Update-on-resume vs on-launch UX

- **On-launch** — check for an update at cold start; if one is ready, apply before the first screen renders. Clean, but adds startup latency and can't fix a mid-session bug until the next launch.
- **On-resume** — check when the app foregrounds; download in the background, apply on the NEXT launch/resume, never swap the running bundle out from under an active session.
- Never hot-swap the bundle mid-session — reloading the JS context under the user drops their in-flight state. Download in the background, then apply behind a controlled restart at a safe boundary (next launch, or a user-acknowledged "restart to update").

## Adapt to the provider

**Read the provider from the project before using this table** — the OTA tooling market has already retired one entry, and a command from the retired one fails against a dead service rather than loudly.

| Provider | Mechanism |
|---|---|
| Expo Updates (EAS Update) | `runtimeVersion` pins bundle↔native; channels + branches; `eas update`; rollout via channel repoint; rollback = republish the prior update. Policy names change per SDK — read them from the installed version (`references/expo.md`). |
| CodePush, **self-hosted** | Deployment keys (Staging / Production); a mandatory flag per release. **Hosted CodePush is gone**: Visual Studio App Center "is scheduled for retirement on March 31, 2025. After that date, it will not be possible to sign in with your user account nor make API calls", and Microsoft's own migration row for CodePush is "a special version of CodePush that can be integrated into your app and run independently from App Center … in this GitHub repository" — `microsoft/code-push-server` (https://learn.microsoft.com/en-us/appcenter/retirement, read 2026-08-20). Any `appcenter codepush …` command in a project or a doc is calling a dead service. Self-hosting means **you** own the rollout percentage, the telemetry gate and the rollback command; none of them arrive with the server. |
| Bare React Native, rolled by hand | **React Native core ships no update module** — there is no built-in `Updates` API. This row is a bundle host, a version manifest and code you wrote: you own staging, rollback, the runtime-version pin and the version gate. Choose it deliberately, knowing that every guarantee in this pattern is now yours to implement. |
| Capacitor / Ionic Live Updates (Appflow) | Channels + native binary compatibility; percentage rollout; revert to prior build |

## Detectors

- An OTA update whose diff touches native code, native deps, or permissions — store-policy violation + crash risk (native shell mismatch).
- A force/mandatory update with no rollback path.
- A rollout published straight to 100% — no staging, full blast radius.
- No min-supported-version gate — old clients keep hitting a removed/broken API.
- An update applied mid-session with no safe-restart boundary.

## Anti-patterns

- **OTA-ing a native change** — "it built fine locally" hides that the JS bundle now expects a native module the installed shell lacks. Crashes on the users who update.
- **Runtime version not pinned** — a bundle lands on an incompatible native build and crashes.
- **100% rollout on a Friday** — no canary, no time to catch the regression before it's everywhere.
- **Mandatory update with no store escape hatch** — forcing a version that requires a native store update, but not linking to the store.
- **Hot-swapping the bundle mid-session** — drops in-flight state; users lose work.
- **No telemetry gate between stages** — rolling forward blind, unable to tell the rollout is failing.

## Project-specific anchors

(Phase 4.6 fills with the project's actual OTA provider, channel names, runtime-version policy, min-version source, update-check entry point, and rollback command.)

## Boundary

This pattern owns the OTA lifecycle — the native-vs-JS boundary, staging, version gating, rollback, and apply-UX. `@app-store-reviewer` owns store-submission policy (what a review will accept); `optimize-bundle` owns bundle size (what the OTA payload weighs). Hand submission questions to the reviewer and payload-weight questions to optimize-bundle.

## Related

- `@app-store-reviewer` — owns submission policy; confirms an OTA stays within reviewed scope (Apple guideline 2.5.2). Anything that would need re-review is a store release, not OTA.
- `@mobile-architect` — invoked to design the runtime-version pinning + channel strategy.
- `optimize-bundle` — a smaller JS bundle is a faster, safer OTA payload; oversized updates are its concern, not this pattern's.

## Sources

- Apple, [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — 2.5.2 downloaded code. There is no guideline 3.3.2; 3.3.2 is a Developer Program License Agreement section.
- Google Play, [staged rollouts](https://support.google.com/googleplay/android-developer/answer/6346149) — the developer selects the percentage; no ladder is prescribed.
- Microsoft, [App Center retirement](https://learn.microsoft.com/en-us/appcenter/retirement) — retired 2025-03-31; CodePush survives only as the self-hostable `microsoft/code-push-server`.
