# Expo reference (SDK-versioned — read the installed SDK, this file is not pinned)

> **Framework**: Expo SDK + React Native + TypeScript. Checked 2026-08-21, the latest SDK is **57.0.0**, paired with **React Native 0.86** and a **minimum Node 22.13.x** (dependency table at https://docs.expo.dev/versions/latest/). That pairing is not stable across releases — read it from the docs, not from here.
> **Official docs**: https://docs.expo.dev/ • EAS: https://docs.expo.dev/eas/ • config: https://docs.expo.dev/versions/latest/config/app/
> **Read `references/react-native.md` first.** Everything there still holds — New Architecture, FlashList, Reanimated, TanStack Query, render discipline. This file covers only what Expo *changes*: native code is generated rather than edited, configuration lives in app config, and build / submit / update go through EAS.
> **Version-specific gotchas**: Expo Go only supports the **latest** SDK — "This applies to Expo Go as it only supports the latest SDK version and previous versions are no longer supported" (https://docs.expo.dev/workflow/upgrading-expo-sdk-walkthrough/) — so any project not on current must use a development build. The **`runtimeVersion` policy list has changed shape over releases**: as of 2026-08-21 the documented policies are `appVersion`, `nativeVersion` and `fingerprint` (https://docs.expo.dev/versions/latest/sdk/updates/). A policy name emitted from memory is how an update ships to the wrong binaries — read the list from the installed version's docs before you write one.
> **Substitution markers**: replace `<name>` with the project's actual route / feature names.

## Read the project before you read this file

Four facts decide almost everything below. Establish them first; none of them can be guessed.

1. **`package.json` → `expo`.** Every default, every API and every policy name here is SDK-scoped.
2. **`npx expo install --check`** — it "prompts you about packages that are installed incorrectly. It also prompts about installing these packages to their compatible versions locally. It exits with non-zero in Continuous Integration (CI)"; `npx expo install --fix` "will always fix packages if needed, regardless of the environment" (https://docs.expo.dev/more/expo-cli/). Run `--check` before touching dependencies. A native module on a version the SDK did not ship is the standard cause of "works in Expo Go, crashes in the build".
3. **Do `ios/` and `android/` exist in the repo?** This single fact flips the rule in the next section. Check, do not assume.
4. **`app.json` / `app.config.ts` and `eas.json`.** These are the real configuration. Reading native files to learn the config gets you the last build's output, not the project's intent.

Install `expo install` additions with `npx expo install <pkg>`, never bare `npm install` — the Expo CLI resolves the version the installed SDK is built against; npm resolves latest.

## CNG: the native directories are build output, not source

> **Hard rule.** In a Continuous Native Generation project, do not hand-edit `ios/` or `android/`. Express the change in app config or a config plugin.

- "The **android** and **ios** directories are automatically added to **.gitignore** when you create a new project", and "If you modify the generated directories manually then you risk losing your changes the next time you run `npx expo prebuild --clean`" (https://docs.expo.dev/workflow/continuous-native-generation/).
- `Info.plist` and `AndroidManifest.xml` are generated: "When you change the name of your app in app config and run `npx expo prebuild`, the name will change in your native projects automatically without the need to manually update AndroidManifest.xml and Info.plist files" (https://docs.expo.dev/config-plugins/introduction/).
- A config plugin is "a top-level custom configuration point that is not built into the app config" that lets you "modify native projects created during the prebuild process in CNG projects" — "In CNG projects, it is best to avoid modifying these native projects manually, because you cannot regenerate them safely without potentially overwriting manual modifications" (same page). Prefer a library's own plugin; write a local one under `plugins/` only when none exists.
- **The exception, and it decides the rule.** If `ios/` / `android/` are committed, the project has left CNG: "EAS Build will not run Prebuild to avoid overwriting any changes you've made to the native directories" (https://docs.expo.dev/workflow/continuous-native-generation/). There, manual native edits *are* the mechanism and a config plugin will not run. Getting this backwards destroys work in both directions — that is why it is step 3 of the checklist above.
- Permission strings, URL schemes, associated domains, entitlements, and background modes are all app-config surface. When `ai-patterns/deep-linking.md` or `ai-patterns/push-notifications.md` says "add the manifest key", in a CNG project that means app config or a plugin.

## Structure

```
app/                      # expo-router: a file in here IS a route
├── _layout.tsx
├── (tabs)/
│   └── <name>.tsx
└── +not-found.tsx
src/
├── features/<name>/      # same internal shape as references/react-native.md
├── shared/
└── lib/
app.config.ts             # app config — source of truth for native configuration
eas.json                  # build / submit / update profiles
plugins/                  # local config plugins, when no library plugin exists
```

## Core choices (opinionated)

- **Routing** — `expo-router`. "Expo Router is an open-source routing library for Universal React Native applications built with Expo", and "When a file is added to the app directory, the file automatically becomes a route in your navigation" (https://docs.expo.dev/router/introduction/). Enable typed routes: "Expo Router has the ability to statically type routes automatically. This ensures you can only link to valid routes." A project already on React Navigation is not wrong — Expo Router is the file-based alternative, not a required migration.
- **Development build over Expo Go for anything that ships.** A development build is "essentially your own version of Expo Go where you are free to use any native libraries and change any native configuration", and "a development build is recommended when you want to create your own app and release to app stores" (https://docs.expo.dev/develop/development-builds/introduction/). Expo Go is a demo harness: it cannot host arbitrary native code and it tracks only the latest SDK.
- **Secrets** — `expo-secure-store`, which "provides a way to encrypt and securely store key-value pairs locally on the device": on iOS values are "stored using the keychain services as `kSecClassGenericPassword`"; on Android they are "stored in `SharedPreferences`, encrypted with Android's Keystore system" (https://docs.expo.dev/versions/latest/sdk/securestore/). This satisfies the Keychain/Keystore requirement in `rules/mobile-principles.md`. Two documented behaviours to design around, both from that page: values are size-limited — "Large payloads can be rejected by the underlying platform. Historically, some iOS releases refused values above roughly 2048 bytes" — so store a token, never a serialized session blob; and lifetime differs by platform — Android data "will not be preserved upon app uninstallation" while iOS data "will persist across app uninstallations". A reinstalled iOS app can find a stale token; treat that as a real state, not an impossible one.
- **Everything else** — state, data fetching, forms, lists, styling: `references/react-native.md`. Expo does not change those decisions.

## eas.json, and what each profile is for

`eas.json` "is the configuration file for EAS CLI and services", at the project root beside `package.json`, with build configuration under the `build` key; the default file ships `development`, `preview` and `production` profiles (https://docs.expo.dev/build/eas-json/).

- `"developmentClient": true` marks a build that "depends on `expo-dev-client`" — "These builds include developer tools, and they are never submitted to an app store" (same page).
- `"distribution": "internal"` is the shape used for development and preview builds; production profiles target the stores.
- Keep environment-specific API base URLs in build profiles, not in code — this is the Expo mechanism for the "API base URL via build variants" requirement in `rules/mobile-principles.md`.

## Updates: what may ship OTA and what may not

This is the Expo-specific half of `ai-patterns/ota-updates.md`, and it is the part agents get wrong.

- The boundary is not a style rule, it is a compatibility fact: an app is "a native layer that's built into the app's binary, and an update layer, that is swappable with other compatible updates", and "Since updates must be compatible with a build's native code, any time native code is updated, we're required to make a new build before publishing an update" (https://docs.expo.dev/eas-update/runtime-versions/).
- **In a CNG project, "native code changed" includes app-config changes**, because app config generates the native project. Adding a permission string, a URL scheme, or a native dependency is a new build, not an update — even though you only edited a `.ts` file.
- `runtimeVersion` is the field that enforces this, and choosing its policy is a real decision (https://docs.expo.dev/versions/latest/sdk/updates/, read 2026-08-21):
  - `appVersion` — "provided for projects with that wish to define their runtime compatibility based on the app version"; "great for projects that contain custom native code and that update the `version` field after every public release".
  - `nativeVersion` — "provided for projects that wish to define their runtime compatibility based on the project's current `version` and `versionCode` (Android) or `buildNumber` (iOS) properties".
  - `fingerprint` — "automatically calculates the runtime version for you, including through changes like SDK upgrades or adding custom native code", and works "for both projects with and without custom native code".
  The docs designate no single default. `fingerprint` is the one that computes the boundary instead of trusting a human to remember it, which is why it is the safest choice for a team shipping updates frequently — but confirm the policy list against the installed SDK before writing it, since this list has changed.
- Minimum config: `updates.url` ("a URL of a remote service implementing the Expo Updates protocol") and `runtimeVersion` (same page).

## Staged rollout and rollback

`rules/mobile-principles.md`'s "never straight to 100%, always rollback-able" has a concrete Expo implementation. Two mechanisms exist and they are not interchangeable (https://docs.expo.dev/eas-update/rollouts/):

- **Per-update rollout** — "A rollout allows you to roll out a change to a portion of your users to catch bugs or other issues before releasing that change to all your users." Start with `eas update --rollout-percentage=10`, adjust with `eas update:edit`, abort with `eas update:revert-update-rollout` (which "will republish the control update"). Constraint: "Only one update can be rolled out on a branch at one time."
- **Branch-based rollout** — "allows you to incrementally roll out a set of updates on a new branch to a percentage of end users and leave the remaining percentage of users on the current branch", managed through `eas channel:rollout`. Constraint: "Only one branch can be rolled out on a channel at a single time."

Pick per-update for a single fix, branch-based for a body of work. The percentage ladder is a project choice — the docs define no canonical 5/25/100 sequence, so do not present one as a platform rule.

## Agent tooling

Expo publishes first-party skills for coding agents: "Expo Skills are structured instruction files that teach AI agents how to build, deploy, and debug Expo and React Native apps accurately and efficiently. They work with Claude Code, Cursor, Codex, and other AI agents" (https://docs.expo.dev/skills/). Install with `/plugin install expo@claude-plugins-official` (Claude Code) or `npx skills add expo/skills` (other agents). The set includes `expo-router`, `expo-data-fetching`, `expo-ui`, `eas-app-stores` and `eas-observe`. Where a skill and this file disagree about an API, the skill is version-matched and this file is a snapshot — the skill wins, and the diff should say so.

## Anti-patterns

- Editing `ios/` or `android/` in a CNG project — the change survives until the next `prebuild --clean`, then vanishes with no error.
- `npm install <native-lib>` instead of `npx expo install <native-lib>` — installs a version the SDK was not built against.
- Assuming Expo Go proves the app works. It cannot host custom native code, and it only tracks the latest SDK.
- Shipping an app-config change as an OTA update. It is a native change in CNG, and the update will either be rejected by the runtime version or land on a binary that lacks the permission.
- Naming a `runtimeVersion` policy from memory (`sdkVersion` is not in the current documented list — see the gotchas note).
- A large object in `expo-secure-store` — the platform can reject the write, and the failure surfaces as a missing token later.
- Rolling an update straight to 100% because "it's only JS". An OTA bug reaches every user in minutes; that is the argument for staging, not against it.

## Cross-references

- `references/react-native.md` — the base layer; read it first.
- `ai-patterns/ota-updates.md` — the native-vs-JS boundary and rollback contract this file implements.
- `ai-patterns/native-storage.md` — which data class goes in which store; `expo-secure-store` is the secure tier here.
- `rules/mobile-principles.md` — secret handling, permissions, build variants.
- `rules/render-discipline.md` — the React Native fingerprint column applies unchanged.
