---
description: "Read-only mobile audit: lifecycle, a11y, perf, offline, store, platform; device-proved ledger and verdict."
kind: command
pack: mobile
allowed-tools: [Read, Write, Grep, Glob, Bash, Task]
---

# /mobile-audit [base-branch] [--whole-repo] [--classes=<family,…>] [--device=<name>] [--profile=L1|L2]

> **Coverage ledger (mandatory)** — before printing any verdict, emit the ledger over the population this run resolved: see [`templates/snippets/coverage-ledger.md`](../../../snippets/coverage-ledger.md). The population is every screen and entry point on the context map (launcher, navigator routes, link filters, push handlers, background jobs) plus every mobile source and config file under the mobile roots. Each lands in **Reviewed / N/A (with a reason) / Live, unreviewed / Blocked**, and the four counts are printed summing to the population. The **class ledger** in Phase 4 is the second half: "no findings" and "did not look" must never print the same way.

## The Premise (read this first, internalize, do not deviate)

**Find the defects a user meets when the operating system acts — it kills the backgrounded process, denies a permission, throttles background work, delivers a link or a push to an app that is not running, updates JavaScript under an older binary, or a store reviewer opens the build — prove each one at its oracle tier, and say what was not looked at.** Three lanes:

- The **static lane always runs.** A whole-repo run (no diff, or `--whole-repo`) dispatches **every** detector in Phase 2, whatever the signals say; a detector whose surface is absent reports its classes `N/A (<reason>)` in its own coverage block and is never skipped. A diff run dispatches each detector whose signal fires on a changed file.
- The **artifact lane (tier A) runs when a release artifact exists**: the merged `AndroidManifest.xml`, an APK, AAB or IPA, the signed entitlements, the embedded privacy manifests. Libraries inject permissions, services and receivers, so a source manifest is never the verdict. Without an artifact every A-tier row prints `blocked (no build artifact)`.
- The **device lane (tier D) runs only when `device-harness` boots a named device** (`--device`, or the one booted device it finds). Without one, every D-tier row prints `not run — no device`: **SKIPPED, never PASS**, and the verdict is at best `GO-UNVERIFIED`. A run on one platform of the two the product ships to is `PARTIAL (<platform> only)`, and the other platform's D rows are `not run`.

**Oracle tiers** ([`precedents/mobile.md`](../../../snippets/precedents/mobile.md) § The claim, restated): **D** device or emulator run · **I** instrumented or widget test · **A** shipped artifact · **S** static trace. Each class names the tier its proof needs; a candidate below that tier is **Unconfirmed** with the settling command, never a Finding and never dropped. A host-only unit test proves no lifecycle, permission, link, push or background claim.

**Two severity axes, never mixed.**
- **Engineering and security severity** — BLOCKER / HIGH / MEDIUM / LOW from the owning detector. Device-security rows are calibrated by the **OWASP MASWE profile** (`precedents/mobile.md` § 42–48): **L1** unless the project declares L2 (context map F6, or `--profile=L2` for fintech, health, government). An L2-only control in an L1 app — a token in app-private plaintext storage, no certificate pinning — is Hardening (an advisory), never a Finding; the same token in logs, backups or external storage is L1, a defect for every app.
- **The store release-blocker axis** — `@app-store-reviewer`'s vocabulary: **HARD-BLOCK** (the upload is refused), **REJECTION** (a cited guideline a human reviewer applies), **PENALTY** (a post-publish store consequence). A release blocker is not a security finding and never inflates one; a missing purpose string is a HIGH crash on the engineering axis (`mobile-lifecycle-scan` §3) **and** a HARD-BLOCK on the store axis, printed once with both. Every dated gate is quoted "per the page as of <date>" from `store-compliance-scan`'s dated table, never from memory.

**Version-gate everything from the lockfile.** 2025–2026 turned many textbook findings into decoys (Compose strong skipping, the React Compiler, FlashList v2, RN New Architecture only from 0.82, `InteractionManager` removed in 0.87) and created new ones (`targetSdk` 35–36 gates, `flutter_secure_storage` 11). A rule is applied only with the resolved version line beside it (`precedents/mobile.md` § 32–35, § 50–59).

**The agent's job, in order:** map the context → dispatch the detectors → collect the artifact once and run the A-tier probes → boot one named device per platform and run the D-tier oracles → refute every candidate before it counts → print the class ledger → judge the verdict against the production bar → apply the posting bar → write the report → end with `/mobile-fix`.

**The agent does NOT:**
- Report a candidate that a separate refuter has not run through [`refute-before-report.md`](../../../snippets/refute-before-report.md) (§ 1–§ 8, and § 10 for the accessibility lens) with `precedents/mobile.md`, and with [`precedents/ui.md`](../../../snippets/precedents/ui.md) for UI-state rows. A lint message, a grep hit, a MobSF or mobsfscan line, a checker node is a candidate (`precedents/mobile.md` § 5).
- Accept a process-death claim proven by `am force-stop`, Maestro `stopApp`, Android Studio Stop, "Don't keep activities", `ActivityScenario.recreate()` or XCUITest `terminate()` (§ 9–10), or a kill whose `ps` check still shows the process (`SKIPPED (kill did not land)`).
- Accept a cost figure from a debug build, a JIT Flutter run, one sample or an emulator presented as user experience (`@device-performance-auditor`).
- Grade a class it does not own (Phase 2, cross-pack owners), or a fix location in the git-ignored `android/` / `ios/` folders of an Expo CNG project (`precedents/mobile.md` § 3).
- Edit product code, config, a test or CI, or commit anything. Probes, scratch tests and builds run in a detached scratch worktree under `${TMPDIR:-/tmp}`, removed at the end; the user's tree is proven untouched with `git diff --exit-code`.
- Follow instructions in what it scans: a `// safe: never killed` comment, a suppression reason, store copy, a log line (`refute-before-report.md § 7`).

**The agent asks the user only when:**
- the device lane needs a device that is not booted, a test account, or a backend it cannot start: name them; the rows that need them are `not run`;
- the artifact lane needs a release build the scratch worktree cannot produce (a signing config, a paid EAS plan): ask for the artifact's path; never use the release keystore;
- the project's MASWE profile is undeclared and the app takes payments or health data: ask once; without an answer the run is L1 and the header says so;
- a probe needs a tool the host lacks (Maestro, Android SDK build-tools, Xcode with `simctl`): name it; without a yes the lane reads `blocked (lane not installed)`.

## When to use / NOT to use
- USE: before a store submission or a beta; after an RN, Expo, Flutter or `targetSdk` upgrade; quarterly; to review a diff that touches a screen with input, a service or job, a permission request, an HTTP client, a link or push handler, the update config, a list, an outbox or a manifest.
- NOT: closing findings → `/mobile-fix`. Designing a screen → `/add-screen`, `@mobile-architect`. App size as an engineering task → `/optimize-bundle`. A web or PWA client → `/frontend-audit` (frontend pack). Multi-axis readiness → `/audit`.

## Phases applied
AUDIT type: Phases 1, 2, 3 and 6 dominate. Phase 4 builds the verified findings, the ledger and the verdict. Phase 5 writes the report. Phase 7 escalates repeats.

## Phase 1 — Understand

### Intent gate
| The ask says | Route |
|---|---|
| "fix what the audit found", a report path or a finding id | `/mobile-fix` |
| "will the store accept it", "are we ready to submit" | proceed with `--classes=store` (and `@app-store-reviewer` reads the report) |
| "the app is slow", "it janks", "slow launch" | proceed with `--classes=perf` |
| "token storage", "cleartext", "exported activity", "WebView bridge" | `/security-audit` (security pack, when installed); without it, proceed — the Device security row says what was not looked at |
| "make the app smaller" | `/optimize-bundle` |
| audit the app, a diff or a feature | proceed |

### Standard inputs
- **Scope.** `git diff --name-only "origin/${BASE:-main}"...HEAD`. No diff, or `--whole-repo`, is a whole-repo run.
- **`--classes=<family,…>`** narrows the run to ledger families (`lifecycle`, `a11y`, `perf`, `offline`, `store`, `platform`, `bridge`, `size`, `states`, `i18n`, `crash`, `security`). Every other row prints `N/A (out of scope: --classes=<list>)` and the verdict names its scope.
- **Stack and versions** from the lockfiles and build files (F1), never from memory.
- **Judges.** Native accessibility → `@ux-reviewer` (ui-ux pack, when installed), else `@verifier`. Perf cost → `@device-performance-auditor` (this pack). Offline writes → `@offline-sync-auditor` (this pack). Store gates → `@app-store-reviewer` (this pack). Every other class → `@verifier` mode `refute` (repo-baseline, when installed), else a `Task` refuter (`refute-before-report.md § 8`).

## Phase 2 — Organize

### Detectors — every one on a whole repo, by signal on a diff
Run every static detector once, in parallel; each writes its own coverage block, and this command never re-greps a class a detector owns. Then collect the artifact once and boot one device per platform, so every A- and D-tier oracle shares them. A detector not on disk (an install made before it shipped) prints `not run (detector absent)` when its surface exists.

| Detector | Pack | Owns (§ = its own numbering) | Diff signal |
|---|---|---|---|
| `mobile-lifecycle-scan` | mobile | §1 process death and restoration · §2 background work · §3 permissions · §4 network timeout and handler · §5 deep-link payloads · §6 push · §7 OTA | a screen with input, a ViewModel or `State`, a service, receiver, alarm, job or BG task, a permission request, an HTTP client, a link handler, push wiring, a logout path, the update config |
| `mobile-a11y-scan` | mobile | §1 accessible name · §2 role or trait · §3 target size · §4 text scaling · §5 grouping and reading order · §6 gesture actions · §7 announcements · §8 contrast | a screen, a touchable or tap handler, an icon button, a swipe row, a toast or banner, a text style or theme |
| `mobile-perf-scan` | mobile | §1 unvirtualized lists · §2 list identity · §3 render waste · §4 main-thread blocking · §5 image decode · §6 startup · §7 leaks | a list or row, a provider or store, an animation, an image in a list, a start-up path, a listener, timer, controller or subscription |
| `offline-sync-scan` | mobile | §1 queue durability · §2 replay identity · §3 ordering and poison · §4 conflict policy · §5 identity bleed · §6 reachability as truth | an outbox, queue, optimistic write, persisted cache, sign-out path, NetInfo or connectivity read |
| `store-compliance-scan` | mobile | §1 privacy manifest and required-reason APIs · §2 purpose strings and declarations · §3 ATT · §4 account deletion · §5 login 4.8 · §6 target SDK · §7 16 KB pages · §8 data declarations · §9 IAP — **release-blocker axis** | a manifest, `Info.plist`, `PrivacyInfo.xcprivacy`, entitlements, app config, a new SDK, a sign-up, login or purchase flow |
| `platform-conventions-audit` | mobile | back and predictive back · edge-to-edge insets · safe area · keyboard avoidance · navigation patterns · platform divergence | a navigator, a screen layout, a back handler, a theme |
| `native-bridge-audit` | mobile | New Architecture interop · sync JSI calls · threading · lifecycle · Flutter channels and Pigeon | a TurboModule, Expo module, native module or platform channel |
| `app-size-scan` | mobile | size classes: unused assets, minify and R8, app thinning, bundle composition | a dependency, an asset folder, a build or minify setting |
| `ui-state-scan` + `state-matrix` lint | ui-ux, when installed | the mobile lanes of §1–§15 (loading, empty, error, offline, pending, …); G12 matrix rows | a data hook or repository, a screen that renders fetched data |
| `i18n-scan` | frontend, when installed | mobile catalogs, hard-coded label text, RTL mirroring, locale formatting | a catalog, a user-visible string, a layout direction |
| `correctness-smell-scan` | code-quality, when installed | crash-prone code: force unwraps, `!!`, unguarded `late`, unhandled rejections | any source change |
| `mobile-security-scan` | security, when installed | token storage · cleartext and trust-all TLS · exported components and intents · WebView bridges · release flags · shipped secrets · link hijack · pinning | a manifest, plist, storage call, WebView, network config, build type, env file |

**Never dispatch the bare name `bundle-analyze`:** in an install that also has the frontend pack it resolves to the web skill. Dispatch `app-size-scan` (the mobile pack's size detector, renamed from `bundle-analyze` at 2.0.0).

**Dedupe by `<file:line>`:** one finding per site, credited to the owner, the other detector listed as corroboration. Known overlaps: the push token left registered at logout — `mobile-lifecycle-scan` §6 owns, `offline-sync-scan` identity bleed corroborates; the client timeout — `mobile-lifecycle-scan` §4 owns, the rendered error or endless spinner is `ui-state-scan` §3 / §11; listener and controller leaks — `mobile-perf-scan` §7 (lifecycle routes them there); target size — `mobile-a11y-scan` §3 (platform-conventions routes it); the offline banner the user sees — `ui-state-scan` §7, the queue behind it — `offline-sync-scan`; a missing purpose string — one site on two axes (engineering: lifecycle §3; store: store-compliance-scan); app size against a store limit — `app-size-scan` detects, `store-compliance-scan` owns the limit. A triggered detector that did not run is a `not run` ledger row.

### Cross-pack owners
- **ui-ux** (when installed): `@ux-reviewer` is the single native-WCAG judge and dispatches `mobile-a11y-scan` itself on mobile diffs; `ui-state-scan` and the state-matrix lint own the rendered states. **Without it,** `mobile-a11y-scan` runs standalone under the protocol and `@verifier` refutes its rows; the UI states and State matrix rows print `N/A (owner pack ui-ux not installed)` and the STATES bar line reads `UNVERIFIED (no owner)`.
- **Security** (when installed): `mobile-security-scan` owns device storage, transport, IPC, WebView, release flags, shipped secrets, link hijack and pinning, verified by [`finding-verification.md`](../../../snippets/finding-verification.md) with `precedents/mobile.md` § 42–48. Consume a same-day `ai/audits/<date>-security.md` when it holds those lines. **Without it** — the pack absent, or an install older than `mobile-security-scan` (security 2.2.0) — the security-tagged rows the mobile detectors raise (lifecycle §5d link hijack, a11y `FLAG_SECURE`) are reported here tagged `security-class (owner pack not installed)` (`precedents/mobile.md` § 8), and the Device security row prints `not run (mobile-security-scan absent)`. No other artifact covers on-device storage, transport, IPC or release flags, so that row **forces `GO-UNVERIFIED`** on a whole-repo run: a mobile GO never implies device security was looked at.
- **Frontend** (when installed): `i18n-scan` owns RTL, hard-coded label text and locale formatting in mobile catalogs; a React Native Web or Expo web build is `/frontend-audit`'s. **Without it,** the i18n row prints `N/A (owner pack frontend not installed)`.
- **Code quality** (when installed): crash-prone code is `correctness-smell-scan`'s; an unhandled rejection in general code is `error-handling-scan`'s (lifecycle §4 keeps only calls that drive a screen). **Without it,** the Crash-prone row prints `N/A (owner pack code-quality not installed)`.
- **Performance** (when installed): server latency behind an API the app waits on is `performance-optimizer`'s; the client-side measurement stays here.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Mobile-specific:
- `.claude/rules/mobile-principles.md`, `.claude/rules/render-discipline.md`; `ai/patterns/` files for lifecycle, permissions, push, deep links, OTA, offline sync and storage when present.
- [`refute-before-report.md`](../../../snippets/refute-before-report.md), [`precedents/mobile.md`](../../../snippets/precedents/mobile.md), [`precedents/ui.md`](../../../snippets/precedents/ui.md) (state rows, § 58 for the automated floor). The oracles (Process-death restore, Scheduler trigger, Permission-denied flow, Network never answers, Link matrix, Push matrix, OTA compatibility, Offline kill, Native a11y checker, Name and role query, Largest-size render, Render count, Frame and render cost, Release-mode tripwire, Oversized-decode log, Startup metric, Leak assertion, Lost-response replay, Identity switch, Conflict and rollback, Store probe, Store flow walk) and their variants V152–V179 are [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Mobile; each owning skill's `## Proof` names the class's fixture.
- Earlier `ai/audits/<date>-mobile*.md`. A class that repeats is systemic (Phase 7).

### Context before hunting (whole-repo runs)
The detectors and the judges share one map. Build it first, as one script from the repo root (every `rg` names its path; the root computation is the one the mobile detectors use, so the counts agree):

```bash
ROOTS=()
while IFS= read -r d; do ROOTS+=("$d"); done < <(
  { rg -l --pcre2 '"(?:react-native|expo)"\s*:' -g 'package.json' -g '!**/node_modules/**' .
    rg -l --pcre2 '^\s+sdk:\s*flutter\b' -g 'pubspec.yaml' -g '!**/.dart_tool/**' .
    rg --files -g '**/src/main/AndroidManifest.xml' -g '!**/{build,node_modules,.gradle}/**' . | sed 's#/src/main/AndroidManifest\.xml$#/x#'
    rg --files -g '**/*.xcodeproj/project.pbxproj' -g '!**/{Pods,node_modules,DerivedData}/**' . | sed 's#/[^/]*\.xcodeproj/project\.pbxproj$#/x#'
  } | while IFS= read -r f; do dirname "$f"; done | sort -u | awk 'p != "" && index($0, p "/") == 1 { next } { print; p = $0 }')
[ ${#ROOTS[@]} -gt 0 ] || { echo 'no mobile root — every class N/A (no mobile surface)'; exit 0; }
printf 'root %s\n' "${ROOTS[@]}"
X=(-g '!**/{node_modules,Pods,build,.gradle,.dart_tool,.expo,DerivedData,dist,vendor,.cxx}/**' -g '!**/src/{test,androidTest,debug}/**'
   -g '!**/{test,tests,__tests__,__mocks__,mocks,fixtures,__fixtures__,testdata,e2e,integration_test,.maestro,docs,ai}/**'
   -g '!**/*{Tests,UITests}/**' -g '!**/*.{test,spec,stories}.*' -g '!**/*_test.dart' -g '!**/*.{g,freezed,mocks}.dart' -g '!**/*.{md,mdx,lock,snap,map}')
# F1 versions (gate 3): declared ranges, build files, then the RESOLVED lockfile lines every version gate cites
rg -n --pcre2 '"(?:react-native|expo|expo-router|expo-updates|@react-navigation/native|@shopify/flash-list|react-native-reanimated|@tanstack/react-query|@react-native-async-storage/async-storage|react-native-mmkv|@nozbe/watermelondb|babel-plugin-react-compiler|@testing-library/react-native|reassure|detox|eslint-plugin-react-native-a11y)"\s*:\s*"[^"]+"' -g 'package.json' "${X[@]}" "${ROOTS[@]}"
rg -n --pcre2 '^\s+(?:sdk|flutter|dio|go_router|flutter_riverpod|flutter_bloc|drift|isar|hive|sqflite|firebase_messaging|flutter_secure_storage|integration_test|patrol):\s*["^>=<\d]' -g 'pubspec.yaml' "${ROOTS[@]}"
rg -n --pcre2 '\b(?:targetSdk|minSdk|compileSdk)(?:Version)?\b\s*[=:]?\s*(?:\d+|flutter\.\w+)|\b(?:agp|kotlin|compose-bom|composeBom)\b\s*=\s*"[^"]+"|\bkotlin\("[\w.]+"\)\s*version\s*"[^"]+"|IPHONEOS_DEPLOYMENT_TARGET|SWIFT_VERSION|SWIFT_DEFAULT_ACTOR_ISOLATION|"(?:targetSdkVersion|minSdkVersion|deploymentTarget)"\s*:' -g '*.{gradle,kts,toml,pbxproj,xcconfig,json}' -g '!**/package*.json' "${X[@]}" "${ROOTS[@]}"
rg -n -U --pcre2 '"node_modules/(?:react-native|expo|@shopify/flash-list)"\s*:\s*\{\s*"version"\s*:\s*"[^"]+"|^"?(?:react-native|expo|@shopify/flash-list)@[^\n]*:\n\s+version:?\s+"?[\w.-]+|^\s+/?(?:react-native|expo)@\d[\w.-]*|^  (?:flutter_secure_storage|firebase_messaging|go_router|dio):\n(?:    [^\n]*\n)*?    version: "[^"]+"' -g '{package-lock.json,yarn.lock,pnpm-lock.yaml,pubspec.lock}' -g '!**/node_modules/**' "${ROOTS[@]}"
# F2 entry points: navigator files, Expo Router layouts, link filters and schemes (every 3,000-hit path intersects with this)
rg -l --pcre2 '\bcreate(?:NativeStack|Stack|BottomTab|Drawer)Navigator\b|\bNavigationContainer\b|\bGoRouter\(|\bNavHost\(|\bNavigationStack\b|\bUINavigationController\b' "${X[@]}" "${ROOTS[@]}" | wc -l
rg --files -g '**/app/**/_layout.{tsx,jsx,ts,js}' "${X[@]}" "${ROOTS[@]}" | wc -l
rg -n -U --pcre2 '<intent-filter[^>]*>(?:(?!</intent-filter>)[\s\S])*?android\.intent\.action\.VIEW' -g 'AndroidManifest.xml' "${X[@]}" "${ROOTS[@]}"
rg -n --pcre2 '"scheme"\s*:|\bapplinks:|\bCFBundleURLSchemes\b|\.onOpenURL\b|"associatedDomains"\s*:|"intentFilters"\s*:' -g '*.{json,plist,entitlements,swift}' "${X[@]}" "${ROOTS[@]}"
# F3 Expo CNG (git-ignored native folders: fixes go to app config or a plugin) and the effective-config sources (tier A)
rg -n --hidden --pcre2 '^/?(?:android|ios)/?\s*$' -g '.gitignore' "${ROOTS[@]}"
rg --files --no-ignore -g '**/merged_manifests/**/AndroidManifest.xml' -g '**/*.{apk,aab,ipa}' -g '**/*.xcarchive/Info.plist' -g '!**/node_modules/**' "${ROOTS[@]}" | head -20
rg --files -g '**/{Info.plist,PrivacyInfo.xcprivacy,*.entitlements,app.json,app.config.*,eas.json}' "${X[@]}" "${ROOTS[@]}"
# F4 harness: device flows and instrumented suites, then the oracles already in the repo
rg --files -g '**/.maestro/**/*.{yaml,yml}' -g '**/{.detoxrc*,detox.config.*}' -g '**/integration_test/**/*.dart' -g '**/src/androidTest/**/*.{kt,java}' -g '**/*UITests/**/*.swift' -g '**/*.perf-test.{ts,tsx,js,jsx}' -g '!**/{node_modules,Pods,build}/**' "${ROOTS[@]}" | wc -l
rg -l --pcre2 '\bperformAccessibilityAudit\b|\bmeetsGuideline\(|\benableAccessibilityChecks\(|\bAccessibilityChecks\.enable\(|\bmeasureRenders\(|\brestartAndRestore\(|\bStateRestorationTester\b|\bkillApp\b' -g '!**/{node_modules,Pods,build,.dart_tool}/**' "${ROOTS[@]}"
# F5 devices (the device lane's precondition; xcrun without simctl is a Command Line Tools host: no simulator)
if command -v adb >/dev/null; then adb devices | sed 1d; else echo 'adb: not on PATH'; fi
if command -v xcrun >/dev/null; then xcrun simctl list devices booted; else echo 'xcrun: not on PATH'; fi
# F6 a declared MASWE profile (L2 posture) — absent means L1
rg -l -i --pcre2 '\bMASVS\b|\bMASWE\b|\bMAS-?L2\b|\bPCI[ -]DSS\b|\bHIPAA\b' -g '{ai,docs}/**/*.md' -g 'README*' -g 'SECURITY*' -g '!**/node_modules/**' .
# F7 installed owners and tool lanes (the "when installed" rows of Phase 2)
ls -d .claude/skills/{mobile-lifecycle-scan,mobile-a11y-scan,mobile-perf-scan,offline-sync-scan,store-compliance-scan,platform-conventions-audit,native-bridge-audit,app-size-scan,device-harness,ui-state-scan,state-matrix,i18n-scan,correctness-smell-scan,mobile-security-scan} .claude/agents/{ux-reviewer,device-performance-auditor,offline-sync-auditor,app-store-reviewer,verifier}.md .claude/scripts/{test-integrity,oracle-check}.py 2>/dev/null
```

Measured 2026-10-05: on the twelve `benchmarks/fixtures/*` (none is a mobile app) the script prints the no-mobile-root line and exits. On the program's six-root mobile sample (bare RN 0.82, two Expo SDK 57 apps, Flutter 3.47, Kotlin + Compose, SwiftUI) it runs in 0.13 s: F1 26 version lines (no lockfile in the sample; the lockfile regex was checked separately on `package-lock.json`, `yarn.lock` and `pubspec.lock` shapes), F2 2 navigator files, 1 Expo Router layout, 3 VIEW intent-filters and 1 scheme, F3 1 merged release manifest, 8 config files and no CNG ignore line, F4 0 harness files, F5 no `adb` and an `xcrun` without `simctl` — so the device lane is `not run — no device`. No real mobile repo was available read-only in this session: re-measure on a real Expo, Flutter and native app before trusting these counts.

From these lines write a one-page map: the **platforms the product ships to** and their resolved versions (F1); the **entry points** — screens reached from the launcher, navigator routes, link filters, push handlers, background jobs (F2) — ranked by user cost (payment, checkout, compose and sign-in first, then link and push targets), with field signals (Play vitals, Crashlytics, Sentry, Xcode Organizer) outranking code order when present; **CNG or not**, and whether an **artifact** exists for tier A (F3); the **harness** (F4) and the **devices** (F5); the **MASWE profile** (F6); the **owners installed** (F7). Then list the **assumptions nothing enforces** — "the OS never kills us mid-checkout", "the user always grants the camera", "the outbox drains before anyone signs out", "the OTA update matches the binary" — and hand them to the detectors as seeds.

## Phase 4 — Generate (verified findings, ledger, verdict)

### Verify every candidate before it becomes a finding
Follow `refute-before-report.md` with `precedents/mobile.md`: the claim restated in its mobile shape (§ The claim, restated), the seven gates as § Reading the seven gates for mobile reads them, the posting rules (§ 1–8) as hard rules. Six checks decide most mobile candidates: **release reachability** (not `__DEV__`, `kDebugMode`, `BuildConfig.DEBUG`, `#if DEBUG`, `src/debug/` or a test target); **the version gate** cited from the lockfile; **the effective config** (merged manifest, signed entitlements, prebuild output) agrees with the source; **a neutralizer search** (a wrapper, a library default, R8 rules, a compiler mode, a backup exclude); **sensitivity by value, not name**, with the MASWE profile, for security rows; **the oracle tier reached** (D > I > A > S).
- **Each BLOCKER or HIGH candidate goes to its own refuter that did not produce it**: native accessibility → `@ux-reviewer` (refute mode, the accessibility column of § 10), else `@verifier`; perf cost → `@device-performance-auditor`, handed `mobile-perf-scan`'s cost rows and the `device-harness` artifacts this command already collected (named device, release or profile build, run count) — it runs the harness itself only when none were collected; offline writes → `@offline-sync-auditor`, handed `offline-sync-scan`'s rows, which caps every `durable` verdict at `unproven` without a real kill; store rows → `@app-store-reviewer`, handed `store-compliance-scan`'s rows, which refuses a row without a quotable dated policy section or a `<file:line>` discrepancy; every other class → `@verifier` mode `refute`, dispatched with a [delegation brief](../../../snippets/delegation-brief.md) under `ai/runs/<YYYYMMDD>-mobile-audit-<4hex>/`, its record in `verdict-refute.json`; else a `Task` refuter. The refuter gets the candidate, its anchors, the platform and the precedents — never the detector's reasoning. MEDIUM and LOW candidates may share one batch refuter.
- **Proof by execution beats proof by reading** (gate 6): the restored text after a real kill, the denied flow reaching Settings, the call failing within its timeout on a server that never answers, the checker's violation list, the probe output on the shipped artifact. Below the class's tier the candidate is **Unconfirmed** with that oracle written out.
- **Buckets** (`refute-before-report.md § 5`): **Finding** · **Unconfirmed** (the gate and the settling oracle) · **Hardening** (a precedent; an L2-only control in an L1 app) · **Pre-existing** (diff runs only; never blocks) · **Refuted** (gate and reason). Nothing is dropped silently. Print `Verification: <n> candidates → <F> findings · <U> unconfirmed · <H> hardening · <P> pre-existing · <R> refuted`.
- **Siblings** (`refute-before-report.md § 6`): state the root cause at the shared code ("the one axios instance sets no timeout", not "the cart screen spins"). A defect in a shared client, base screen, wrapper or config plugin is **one finding with N sites** (`precedents/mobile.md` § 7).
- **Every Finding carries:** the source `<file:line>`; the platform, the resolved version gate and the OS event; the owning detector, § and class; severity on its axis (engineering, MASWE level, or HARD-BLOCK / REJECTION / PENALTY); the restated claim; the proof (oracle name, tier, device and build, measured or not run); and the fix in the project's stack. `/mobile-fix` turns that oracle into its failing-first test.

**Severity.** A Finding keeps the owning detector's severity; confidence decides only the bucket. Critical maps to **BLOCKER**, and these are BLOCKER whatever the detector printed: another account's data or notifications reaching a signed-in user (identity bleed, a push token kept at logout); an offline write on an order, payment or message path lost or applied twice; a crash on restore or on a cold-start link into sign-in or checkout; an OTA update that can run unsigned from a self-hosted server; a primary action (sign-in, pay, submit, back) that a screen-reader user cannot reach, with checker evidence. **HIGH** is the detector's high: typed input lost on process death, a foreground service that throws at the merged `targetSdk`, a permanently-denied dead end on a primary feature, a call that drives a write and can wait forever.

### Class coverage ledger (required — the answer to "did it look for everything?")
One row per class family, sourced from each owner's coverage block. **The list is fixed**, so no run can quietly shrink it:

| Row (`--classes` family) | Classes | Owner · judge |
|---|---|---|
| Lifecycle (`lifecycle`) | process death · background work · permissions · timeouts · deep-link payloads · push · OTA | `mobile-lifecycle-scan` §1–§7 · `@verifier` |
| Native a11y (`a11y`) | name · role · target size · text scaling · grouping and order · gesture actions · announcements · contrast | `mobile-a11y-scan` §1–§8 · `@ux-reviewer` (else `@verifier`) |
| A11y manual pass (`a11y`) | TalkBack and VoiceOver walk at the largest font · Switch Access / Full Keyboard Access | human lane — `NOT RUN (human lane)` unless a recorded pass is cited |
| Perf, existence (`perf`) | lists · identity · render waste · main-thread blocking · image decode · startup · leaks | `mobile-perf-scan` §1–§7 · `@verifier` |
| Perf, cost (`perf`) | frames, launch, render counts on a named device, release or profile build, repeated runs | `@device-performance-auditor` over `device-harness` |
| Offline sync (`offline`) | queue durability · replay identity · ordering and poison · conflict policy · identity bleed · reachability as truth | `offline-sync-scan` · `@offline-sync-auditor` |
| Store gates (`store`, release-blocker axis) | every § in `store-compliance-scan`'s coverage block | `store-compliance-scan` · `@app-store-reviewer` |
| Platform conventions (`platform`) | every § in `platform-conventions-audit`'s coverage block | `platform-conventions-audit` · `@verifier` |
| Native bridge (`bridge`) | every § in `native-bridge-audit`'s coverage block | `native-bridge-audit` · `@verifier` |
| App size (`size`) | every § in `app-size-scan`'s coverage block | `app-size-scan` · `/optimize-bundle` fixes |
| UI states (`states`) | the mobile lanes of `ui-state-scan` §1–§15 | `ui-state-scan` (ui-ux) · `@ux-reviewer` |
| State matrix, G12 (`states`) | a row per screen × state, each naming a test that exists | `state-matrix-lint.py` (ui-ux) |
| i18n and RTL (`i18n`) | hard-coded strings · RTL mirroring · locale formatting · catalog parity | `i18n-scan` (frontend, when installed) |
| Crash-prone code (`crash`) | force unwraps · `!!` · unguarded `late` · unhandled rejections | `correctness-smell-scan` (code-quality, when installed) |
| Device security (`security`) | storage · transport · IPC · WebView · release flags · shipped secrets · link hijack · pinning | `mobile-security-scan` (security, when installed) |
| Device lane | every D-tier oracle, per platform shipped | `device-harness` |

Each row prints `checked (k hits → m findings)` / `N/A (<reason>)` / `blocked (<reason>)` / `not run (<reason>)` / `Live, unreviewed (k groups / n hits — <continuing command>)`. A row whose owner's block lacks one of its classes prints `not run (<class>: no line in <owner>'s block)`. A missing owner pack prints `N/A (owner pack <x> not installed)`, except Device security, which prints `not run (mobile-security-scan absent)`. **On a whole-repo run, a `not run` row, or a `blocked` row other than A11y manual pass, forces `GO-UNVERIFIED`;** so does a Device lane `not run — no device` or `PARTIAL (<platform> only)`.

### Production bar and control verification (GO-critical)
- **ARTIFACT:** the A-tier probes ran on a release artifact (or the merged manifest and signed entitlements) whose build date is recorded. Source-only is an `ARTIFACT:` gap.
- **DEVICE:** the D-tier oracles ran on a named device for every platform the product ships to. One platform, or none, is a `DEVICE:` gap.
- **RESTORE:** the top input flow (compose, checkout, sign-up) has a process-death restore test in the repo — a Maestro flow with `killApp`, or a UiAutomator / XCUITest equivalent — that CI runs. Missing is a `RESTORE:` gap.
- **A11Y CHECKER:** a native accessibility checker runs in CI (RNTL role-and-name queries, Flutter `meetsGuideline`, ATF through Espresso or Compose, XCUITest `performAccessibilityAudit()`). Missing, or present and never run, is an `A11Y CHECKER:` gap.
- **BUDGETS:** a launch budget (engineering baseline MOB-9) is declared and measured on a release build. Undeclared is a `BUDGETS:` gap.
- **STATES** (ui-ux, when installed): every top screen has a state matrix that `state-matrix-lint.py` passes.

Write a **control verification table**: one row per GO-critical control. Each row carries an Evidence token — **Device** (a recorded run: device, OS, build type), **Kill** (the `ps` check printed nothing), **Checker** (the checker's output at the screen-state), **Artifact** (probe output on the release artifact, with its build date), **Measured** (release build, named device, n runs and the spread), **Static** (the line, for a self-proving fact) — or `UNVERIFIED`. A control that was read but never exercised is `UNVERIFIED`, not a pass.

### Verdict (three states, two axes)
- **NO-GO:** at least one Finding at BLOCKER or HIGH, **or** at least one confirmed HARD-BLOCK or REJECTION on the store axis — printed `NO-GO (release blocker)` when only the store axis blocks.
- **GO-UNVERIFIED (N):** no such Finding, but N open items: Unconfirmed candidates at HIGH or above, `not run` or blocking ledger rows, the device lane not run or partial, production-bar gaps, `UNVERIFIED` control rows, dispatched detectors with no result. Each is named. A GO-UNVERIFIED is not a GO.
- **GO:** none of the above. MEDIUM, LOW and PENALTY rows are listed and do not block. With `a11y` in scope it prints `GO — automated floor; manual pass <recorded at <path> | not recorded>` (`precedents/ui.md` § 58).

### Posting bar — what reaches a human
[`posting-bar.md`](../../../snippets/posting-bar.md) § 1–§ 4 applies after verification: BLOCKER and HIGH Findings and HARD-BLOCK / REJECTION rows are **IMPORTANT**; MEDIUM, LOW and PENALTY are **NIT**, at most 5 printed with the rest as a count (the report keeps them all); Pre-existing is listed, never blocking. Nothing a configured lint already fails in CI at error level (`precedents/mobile.md` § 4); no store-text wording verdict from a detector (§ 6). Every posted finding is its one-sentence restatement.

### RE-DETECT
On a re-audit after `/mobile-fix`, re-run the owning detector on each first-pass finding's `<file:line>` and its oracle at the same tier, on the same device class. A finding is closed only when the detector goes quiet there and the oracle passes on every platform shipped. Any first-pass BLOCKER that still reproduces keeps the verdict NO-GO.

## Phase 5 — Update
- Write `ai/audits/<YYYY-MM-DD>-mobile.md` (a `--classes` run: `-mobile-<families>.md`): the context map, the class ledger, the coverage ledger, the verification line, findings by bucket on both axes, the production bar, the control verification table, the automated-floor line, the verdict, and `## What to do next`. **A `GO` printed without the ledger and the control table in this file is a defective run.**
- `ai/dynamic/changelog.md`: `Mobile audit on <scope>: B blockers, H high, RB release blockers, U unconfirmed, device lane <ran on … | not run>, verdict <state>`.
- `ai/status.md` `## Recent Changes`: one bullet when the verdict is NO-GO or there is a BLOCKER or a HARD-BLOCK.
- Nothing else. No product file, config or test is touched; the scratch worktree, its builds and the device's test install are removed.

## Phase 6 — Validate
- Every Finding has a `<file:line>`, a platform, a version-gate line, an owner, an oracle at its tier (or is Unconfirmed with it), and a fix. Grep the draft for hand-waves ([`hand-wave-grep.md`](../../../snippets/hand-wave-grep.md)) plus `accessible`, `compliant`, `store-ready`, `no issues`, `might`, `seems`, `TBD`.
- Every framework, library and version named exists in a lockfile or build file; every rule id exists in the version that ran; every number came from a tool run in this session, with its device and build type; every dated store gate carries its page date.
- No D-tier row reads PASS without a recorded device run; no process-death row rests on force-stop, `stopApp`, `recreate()` or `terminate()`.
- The class ledger has every row; the coverage ledger's counts sum to the population; the verdict matches the open-item count on both axes.

## Phase 7 — Improve
- `/learn-from-task`: capture each confirmed class.
- A class seen in two audits is systemic. Queue an ADR and the mechanical gate that refuses it: a Maestro process-death flow per top input screen in CI, the native a11y checker test at error, Android lint and SwiftLint rules at error, StrictMode `penaltyDeath` / Main Thread Checker in the test plan, a Reassure baseline in CI, a `zipalign -c -P 16` and merged-manifest check on the release artifact.

## Output format
```
## /mobile-audit — verdict NO-GO (1 blocker, 1 release blocker)   scope=whole repo   profile L1 (undeclared)
Stack: driver/ expo SDK 57 / react-native 0.87.1 (package-lock.json), CNG · ops/ kotlin 2.2 + compose, targetSdk 36 (build.gradle.kts:9) · ios 15.1
Lanes: static ✓ · artifact ✓ (app-release.aab 2026-10-04) · device PARTIAL (Pixel 8 API 36, release; no iOS simulator)
Verification: 73 candidates → 4 findings · 6 unconfirmed · 14 hardening · 0 pre-existing · 49 refuted
BLOCKER (1):
  driver/src/auth/logout.ts:18             mobile-lifecycle-scan §6 · push token kept at logout   proof: Push matrix (D) — account B received A's order push
HIGH (1):
  ops/app/src/main/java/com/acme/ops/NoteScreen.kt:41   mobile-lifecycle-scan §1 · draft in remember, not rememberSaveable   proof: Process-death restore (D) — draft gone after am kill
RELEASE BLOCKER (1):
  driver/app.json:21                       store-compliance-scan · camera used, NSCameraUsageDescription absent — release blocker + lifecycle §3 crash   proof: Store probe (A)
UNCONFIRMED (6): ios rows — settle: Process-death restore on an iOS simulator (background, Xcode Stop, relaunch) · …
Class ledger: Lifecycle checked (52 → 2) · Native a11y checked (38 → 1) · A11y manual NOT RUN (human lane) · Perf checked (41 → 0) ·
              Offline checked (17 → 0) · Device security not run (security pack not installed) · Device lane PARTIAL (android only) · …
Production bar: DEVICE gap — no iOS run · RESTORE gap — no killApp flow in CI · A11Y CHECKER gap — none in CI
Automated floor only: no report here says "accessible" or "store-ready"; the TalkBack / VoiceOver pass is not recorded.
```

## What to do next — required closing section
Every run ends its report with `## What to do next`: the findings as ONE ordered, numbered to-do. **MUST FIX** (BLOCKER, HIGH, HARD-BLOCK and REJECTION) first, then **SHOULD FIX** (MEDIUM), then **OPTIONAL** (LOW, PENALTY, Hardening). Each step carries `<file:line>`, the platform, the **Fix** (in the project's stack; in app config or a config plugin under CNG) and the **Verify** (the oracle by name and its tier). On `GO-UNVERIFIED` the MUST FIX list also carries a **PROVE** section: each Unconfirmed candidate, each `not run` device row and each `UNVERIFIED` control, with the device, artifact or test that settles it. The closing steps are: run **`/mobile-fix`** on this report (it re-verifies each finding, proves it failing first at its tier on a device, fixes the root cause, runs the class variants on both platforms and re-detects); size rows go to `/optimize-bundle`, device-security rows to `/security-fix` (security pack, when installed); re-run `/mobile-audit`; `/learn-from-task`. A clean run collapses to one line, which still names the automated floor and the device lane. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes
- **"Tests pass" as device proof.** A host test runs in a process nobody kills, denies nothing and receives no push; the D rows are `not run`, not green.
- **The wrong kill.** Force-stop, `stopApp`, `recreate()`, "Don't keep activities" or `terminate()` reported as process death; a kill with no `ps` check.
- **The source manifest as the verdict.** Libraries inject permissions and services; read the merged one, or the row is `blocked (no build artifact)`.
- **A version rule outside its gate.** Strong skipping, the React Compiler, FlashList v2, `targetSdk` gates, RN 0.82+ — no rule without the resolved version line.
- **Axes mixed.** A store gate inflated into a security HIGH, or an L2-only control reported as an L1 defect.
- **The finder judging itself.** Every BLOCKER and HIGH goes to a separate refuter.
- **A shrunken ledger.** A missing row — device security above all — reads as "looked, nothing found".

## Related

### Detector skills (dispatched in Phase 2)
This pack: `mobile-lifecycle-scan` · `mobile-a11y-scan` · `mobile-perf-scan` · `offline-sync-scan` · `store-compliance-scan` · `platform-conventions-audit` · `native-bridge-audit` · `app-size-scan` · `device-harness` (the D-tier runner). ui-ux (when installed): `ui-state-scan` · `state-matrix`. Frontend (when installed): `i18n-scan`. Code quality (when installed): `correctness-smell-scan`. Security (when installed): `mobile-security-scan`.

### Agents
- `@ux-reviewer` (ui-ux, when installed): the native-WCAG judge of `mobile-a11y-scan`. `@device-performance-auditor` (judges `mobile-perf-scan`'s cost rows over `device-harness`), `@offline-sync-auditor` (judges `offline-sync-scan`), `@app-store-reviewer` (judges `store-compliance-scan`) — this pack. `@verifier` (repo-baseline, mode `refute`): every other class.

### Commands
- `/mobile-fix`: closes this report's findings. `/optimize-bundle`: app size. `/security-audit`, `/security-fix` (security pack, when installed): device security. `/frontend-audit` (frontend pack): web and React Native Web targets.

### Shared contracts
[`refute-before-report.md`](../../../snippets/refute-before-report.md) · [`precedents/mobile.md`](../../../snippets/precedents/mobile.md) · [`precedents/ui.md`](../../../snippets/precedents/ui.md) · [`posting-bar.md`](../../../snippets/posting-bar.md) · [`coverage-ledger.md`](../../../snippets/coverage-ledger.md) · [`delegation-brief.md`](../../../snippets/delegation-brief.md) · [`finding-verification.md`](../../../snippets/finding-verification.md)
