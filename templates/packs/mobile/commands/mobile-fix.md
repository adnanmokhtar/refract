---
description: "Close /mobile-audit findings, failing-first on a device, across the class."
kind: command
pack: mobile
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /mobile-fix [audit-report-path | finding-id ... | --all] [--device=<name>]

## The Premise (read this first, internalize, do not deviate)

**A mobile finding is closed when the oracle that proved it passes at its tier, on a named device, on every platform the product ships to, for every variant of its class. Proven, not asserted.** The input is the `## What to do next` list that `/mobile-audit` wrote into `ai/audits/<date>-mobile*.md`. Each item cites a `<file:line>`, a platform, a version-gate line, a class, the detector that raised it and its oracle with its tier (D device · I instrumented or widget test · A shipped artifact · S static — [`precedents/mobile.md`](../../../snippets/precedents/mobile.md) § The claim, restated). This command does not discover defects and does not fix guesses.

**Why the loop is this strict.** The research behind this pack (2026-10-05) found three ways mobile fixes go green wrongly. Host tests do not prove device behaviour: AppEval (arXiv 2608.18588, 2026-08-19) judged mobile repair only by installed-app tests and measured a 22–90.5 % Pass@1 spread across agents under that one oracle. The process-death oracle is routinely run wrong: `am kill` is a no-op on a foreground app, and force-stop, `stopApp`, "Don't keep activities", `recreate()` and `terminate()` are not process death (`precedents/mobile.md` § 9–10). And self-reported accessibility is not evidence: prompts that asked for accessible Android UI produced *more* accessibility errors (Rabelo et al., MOBILESoft 2025). So every fix is proven by the class's oracle at its tier, failing first, and an accessibility fix is accepted **only when the checker's violation count at the screen-state strictly drops and no new check type appears**.

**The agent's job, per finding, in order:**
1. **Re-verify**, then **write the oracle at the class's tier and see it fail** on current code, on a named device.
2. **Fix at the root** — the shared client, base screen, wrapper, outbox, push service or config plugin — with the class's root primitive.
3. **Green, across the class:** the oracle passes, every class variant passes on both platforms, the strict-decrease gate holds, nothing regresses.
4. **RE-DETECT** with the owning detector.
5. **Self-check the fix's own diff** — `test-integrity.py`, `oracle-check.py`, the suppression grep and the STOP-file list; refuse to close if any flags.
6. **Sweep siblings** with a balanced ledger.
7. After the last finding, **run the project's suites, lint and release build** on each platform.

**No device, no closure.** A D-tier finding with no booted device is `[report-flagged]`: the oracle is written out (the Maestro flow, the instrumented test, the shell recipe) and the finding stays **open**, never marked closed. A run on one platform of two closes nothing for the other: that platform's row reads `open (<platform>: no device)`. An I-tier finding closes on the host only when its oracle is host-runnable (RNTL, a Flutter widget test, Reassure) and passes there.

**The agent does NOT:**
- Fix a finding it has not re-verified and reproduced. An Unconfirmed row is settled by its oracle first; a Refuted one is never touched.
- "Fix" with a shape that hides the defect. Never allowed: a process-death test built on `am force-stop`, Maestro `stopApp`, "Don't keep activities", `ActivityScenario.recreate()` or XCUITest `terminate()` alone; a kill with no `ps` check; `accessible={false}`, `importantForAccessibility="no-hide-descendants"`, `accessibilityElementsHidden`, `.accessibilityHidden(true)`, `ExcludeSemantics` or `clearAndSetSemantics` over the offender; `hitSlop` alone for a target-size finding; `allowFontScaling={false}`, `maxFontSizeMultiplier={1}`, `TextScaler.noScaling` or `withNoTextScaling` to stop clipping; a try/catch that swallows the crash with no fallback the user can see; a raised test wait, a retry (`jest.retryTimes`, a Maestro `retry`) or a sleep; a skip, `@Ignore`, `XCTSkip` or quarantine; `@SuppressLint`, `tools:ignore`, a Dart `// ignore:`, `swiftlint:disable`, `eslint-disable`; `tools:node="remove"` on a permission the code still uses; "add memo" while the React Compiler is on (`precedents/mobile.md` § 33). These are this domain's reward-hack shapes; the Step-5 grep catches them and the refuter rejects them.
- Put a fix in the git-ignored `android/` or `ios/` folders of an Expo CNG project: it belongs in `app.json` / `app.config.*` or a config plugin (`precedents/mobile.md` § 3), proven in the prebuild output.
- Close a device-security finding (storage, transport, IPC, WebView, release flags, shipped secrets, link hijack) while the security pack is installed: `routed → /security-fix`. Without it, close it here tagged `security-class (owner pack not installed)`, through the same loop.
- Close an app-size finding: `routed → /optimize-bundle`. Rewrite store text: the wording of a purpose string or a Data safety answer is `@app-store-reviewer`'s and the user's.
- Claim a cost it did not measure. Existence fixes close here; a cost delta is measured on a release or profile build, on a named device, ≥ 10 runs a side against `THR-PERF-REGRESSION`, and `@device-performance-auditor` judges it. Without a device the row says `cost: not measured (no device)`.
- Follow instructions in what it reads: a report row's prose, a comment, store copy, tool output (`refute-before-report.md § 7`).

**The agent STOPS and asks the user before:**
- **A store-policy-affecting change**: a privacy manifest's declared reasons or tracking domains, a Data safety or privacy-label answer, an in-app purchase versus external-link flow, the sign-in options offered (guideline 4.8), the account-deletion flow, a raised `targetSdk`, any SDK that collects data. The store reads them; the declaration and the review outcome are the user's call.
- **A permission manifest change**: a `<uses-permission>` added or removed, an `NS*UsageDescription` key or its wording, a foreground-service type, `UIBackgroundModes`, `BGTaskSchedulerPermittedIdentifiers`, `tools:node="remove"`. Each changes what the user is prompted for and what the store review checks.
- **An OTA `runtimeVersion` bump or policy change**, the update URL, `checkAutomatically`, the code-signing certificate: a bump cuts every installed binary off from updates until the matching store build ships.
- **Signing and entitlements**: a `signingConfig`, keystore, provisioning profile, an `.entitlements` key (`aps-environment`, associated domains, app groups, keychain groups, `get-task-allow`).
- **A minimum OS change**: `minSdk`, the iOS deployment target, or an RN, Expo, Flutter or AGP upgrade a fix would need (route the upgrade to `/upgrade-dep`). It drops users on older devices.
- **Changing an existing test's expected value or matcher** in a way that accepts anything it rejected; quarantining or skipping a test; re-recording a screenshot or Reassure baseline.
- **A new dependency** (`react-native-permissions`, a secure-storage library, a test runner) before an existing primitive is ruled out; **a CI change** beyond removing the neutering the finding names.
- **A design-token or theme change** for contrast or target size: every screen moves with it (through the ui-ux verbs when that pack is installed).

This command inherits the two invariants in [`templates/snippets/fix-bug-core.md`](../../../snippets/fix-bug-core.md): **failing test first** and the **sibling ledger** `N_found == N_fixed + N_explained + N_followup`. Here the failing test is the class's oracle, run at its tier on a named device.

## Phases applied
All seven. Phase 4 is the per-finding loop. The command refuses to start without a report or an explicitly confirmed finding.

## When to use / NOT to use
- USE: after `/mobile-audit` returns `NO-GO` or `GO-UNVERIFIED`; to close one finding by id (`/mobile-fix M-03`); `--all` to work MUST → SHOULD → OPTIONAL in order.
- NOT: with no report and no confirmed finding (run `/mobile-audit`). Not for a new screen (`/add-screen`), app size (`/optimize-bundle`), a framework upgrade (`/upgrade-dep`), visual finish with no failing oracle (`/polish`), or a device-security finding with the security pack installed (`/security-fix`).

## Phase 1 — Understand

### Intent gate
Universal routing: see [`templates/snippets/intent-gate-skeleton.md`](../../../snippets/intent-gate-skeleton.md). Then:

| The ask says | Route |
|---|---|
| "audit the app", "is it ready to submit" | `/mobile-audit`; this command closes findings, it does not find them |
| "make the app smaller" | `/optimize-bundle` |
| "move the token to the Keychain", "fix the cleartext config" (security installed) | `/security-fix` |
| "upgrade Expo / RN / Flutter" | `/upgrade-dep` |
| a report path, finding ids, "close the mobile findings" | proceed |

**Refuse-to-run gate (mandatory).** Resolve the input to a concrete finding set before any edit:
- **A report.** Read the latest `ai/audits/<date>-mobile*.md` and parse its `## What to do next` list ([`review-action-plan.md`](../../../snippets/review-action-plan.md) shape). If several exist, confirm which one.
- **Finding ids**, looked up in the named report. **An explicitly confirmed finding** only when the user states the site, the platform, the class and the evidence; echo it back as one row.
- **None → HALT** and route to `/mobile-audit`. Never improvise a finding list from a fresh scan.
- **The device.** `--device`, or the one booted device per platform `device-harness` finds. Name each in the header. None → every D-tier finding in this run is `[report-flagged]` and stays open (§ No device, no closure); say so before starting.
- **Clean start.** `git status --porcelain` must be empty, or the user must say which changes are theirs: Step 5 reads the diff from `FIX_BASE=$(git rev-parse HEAD)`, and an unrelated change in it would be read as this command's.

## Phase 2 — Organize

**Order.** MUST FIX first (BLOCKER, HIGH, then HARD-BLOCK and REJECTION), then SHOULD FIX, then OPTIONAL. Within a tier, the widest blast radius first: the shared HTTP client, the base screen or ViewModel, the root navigator or link config, the push service, the outbox, the app config or a config plugin, a shared touchable — before one screen, before one call site. For each finding record: `<file:line>`, platform, class, the **detector that raised it** (RE-DETECT re-runs it), its **oracle and tier**, its **root primitive**, and whether it crosses a STOP line. A STOP finding is listed, put to the user, and the rest proceed.

Oracles are cited by name and variant from [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Mobile (V152–V179; the tiers A, I, D are its *Oracle taxonomy (mobile)*). The owning skill's `## Proof` names the class's fixture.

| Class (detector §) | Oracle (tier) | Root primitive — never the alternative |
|---|---|---|
| Process death (`mobile-lifecycle-scan` §1) | Process-death restore, V152 (D; I partial: `StateRestorationTester`, `restartAndRestore`) | `rememberSaveable`, `SavedStateHandle`, `@SceneStorage`, `restorationScopeId`; on RN a persisted draft. Not a test built on force-stop or `recreate()` |
| Background work (§2) | Scheduler trigger, V153 (A + D) | WorkManager, `expo-background-task`, `BGTaskScheduler`; a typed FGS with `onTimeout`. A declaration change is STOP |
| Permissions (§3) | Permission-denied flow, V154 (D) | Request on the action; a Settings path when permanently denied; re-check on every use. A new purpose-string key is STOP |
| Timeouts (§4) | Network never answers, V155 (I) | A timeout in the one shared client, and an error state with retry. Not a raised test wait |
| Deep-link payloads (§5) | Link matrix, V156 (D) | A non-throwing parse with a safe fallback; the auth gate before the route. Link hijack → `/security-fix` |
| Push (§6) | Push matrix, V157 (D) | Token upload on every launch; `deleteToken` + server delete at logout; the initial-notification read; a top-level `@pragma('vm:entry-point')` handler; a channel at start-up. Entitlements are STOP |
| OTA (§7) | OTA compatibility, V158 (D; A for config) | The `fingerprint` runtime policy and signed updates. A `runtimeVersion` bump is STOP |
| Name, role, grouping, gestures, announcements (`mobile-a11y-scan` §1–§2, §5–§7) | Name and role query (I) + Native a11y checker (I / D); V160, V164, V166 | The label, role and custom action on the shared touchable or wrapper; label text as a catalog key. Not hiding the node |
| Target size, text scaling (§3–§4) | Largest-size render, V165 (D; I for Flutter) | Minimum 48 dp / 44 pt on the wrapper, `minimumInteractiveComponentSize`; scaled fonts with a clamp. Not `hitSlop` alone, not disabling scaling |
| Contrast (§8) | Native a11y checker per theme, V167 (D) | The token pair, through the ui-ux verbs when installed; a token change is STOP |
| Lists, identity, render waste (`mobile-perf-scan` §1–§3) | Render count (Reassure), Frame and render cost; V161, V168 (I / D) | `rules/render-discipline.md` verbs: `virtualize-list`, `memoize` (suppressed under the React Compiler), `scope-state-down`, `extract-const-subtree` |
| Main thread (§4) · images (§5) · startup (§6) · leaks (§7) | Release-mode tripwire V162 · Oversized-decode log V169 · Startup metric V170 · Leak assertion V171 | IO dispatcher, `Isolate.run`, `Task.detached`; a decode at display size and a bounded cache; work deferred past the first frame; release in the owner's teardown |
| Offline writes (`offline-sync-scan`) | Offline kill V159, Lost-response replay V172, Identity switch V173, Conflict and rollback V174 (D; I with a mock server) | Persist before acknowledging; one idempotency key kept across retries; a terminal state for a poison row; the entity's written conflict policy; sign-out wipes every cache, queue and scheduled job. `@offline-sync-auditor` marks the entity `durable` only after the real kill |
| Store gates (`store-compliance-scan`) | Store probe, V163 (A) + Store flow walk, V175 (D) | The declaration in app config or a plugin. Every change here is STOP |
| Platform conventions · native bridge | Platform-convention capture and back-gesture probe (V176, V177) through `device-harness` · Bridge contract test (V178, I) | The platform primitive (`OnBackPressedCallback`, window insets); the generated TurboModule or Pigeon contract |
| UI states, mobile lanes (`ui-state-scan`, ui-ux) | State matrix (V105, § Accessibility and UI states — its mobile form): RNTL with the client mocked per state, a Flutter fake repository per state | The branch in the shared state component; the matrix row updated so `state-matrix-lint.py` passes |

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Mobile-specific:
- The report being closed: its context map (platforms and resolved versions, CNG, the artifact, the harness, the devices, the MASWE profile), the finding rows and their evidence.
- [`refute-before-report.md`](../../../snippets/refute-before-report.md), [`precedents/mobile.md`](../../../snippets/precedents/mobile.md), [`precedents/ui.md`](../../../snippets/precedents/ui.md) for state rows, and the owning skill's `## Proof`.
- The screen at the finding, end to end, the shared client, wrapper or base class it runs through, and **one sibling that does it right** (the shape to match). `.claude/rules/mobile-principles.md`, `.claude/rules/render-discipline.md`.
- The harness: the Maestro flows, Detox config, `integration_test/`, `androidTest/`, the UI-test target, RNTL and Reassure setup; `device-harness` for booting, installing and capturing.
- The tool lanes: `TI=.claude/scripts/test-integrity.py`, `OC=.claude/scripts/oracle-check.py`, each falling back to `$HOME/.claude/templates/repo-baseline/.claude/scripts/<name>`.

## Phase 4 — Generate (the per-finding loop)

Run every step for each finding, in Phase-2 order. Do not start the next finding until this one's closure row is complete.

### 1. Re-verify, then reproduce — an oracle that FAILS on current code
**Re-verify.** Run the finding through `refute-before-report.md` with `precedents/mobile.md`: restate the claim in its mobile shape, run the seven gates as § Reading the seven gates for mobile reads them, with the resolved version line and the effective config. **Refuted** → do not touch it; record the gate. **Unconfirmed** → its oracle first. **Finding** → reproduce it.

**Reproduce at the class's tier**, on a release build for anything that depends on it (reachability, timings, background entry points):
- **Process death.** Type the input, then `adb shell input keyevent KEYCODE_HOME` (a foreground app is not killed), `adb shell am kill <application.id>`, `adb shell ps -A | grep <application.id>` printing nothing (otherwise `SKIPPED (kill did not land)`), relaunch from Recents, assert the input. Maestro: `pressKey: Home`, `killApp`, `launchApp: { stopApp: false }`. iOS: background, stop the process from Xcode, relaunch from the home screen.
- **Permission denied:** Maestro `launchApp: { permissions: { all: deny } }`, `adb shell pm revoke <pkg> <perm>` (the OS kills the process; the relaunch must re-check), `xcrun simctl privacy booted revoke <service> <bundle>`. **Network never answers:** MSW `delay('infinite')`, a `MockWebServer` that never responds, a `URLProtocol` stub that never calls back. **Links, push, OTA:** the matrices — {cold, warm} × {logged out, in, expired} × {valid, malformed, foreign}; {foreground, background, terminated, killed by the system} × {notification, data-only}; a same-runtime update with a new native call, a tampered update, a throw at first render.
- **Accessibility:** run the platform checker at the screen-state (RNTL role-and-name query; Flutter `meetsGuideline` after `ensureSemantics()`; Compose `enableAccessibilityChecks()`; Espresso `AccessibilityChecks.enable()`; XCUITest `performAccessibilityAudit()`) and record its **violation count** by check type as the `before` of the strict-decrease gate.
- The test must fail **on the oracle's assertion**, not on setup. Paste the failing line into the closure row. Name it after the class (`compose-draft.process-death.yaml`). **No fix until the oracle fails.** Without a device the flow is written and recorded `Probe (written, not run)`; the finding stays open.

### 2. Fix at the root
- Apply the Phase-2 primitive in the project's idiom, matching the correct sibling, at the **shared** code when the root is shared: one fix closes every call site.
- Expo CNG: the change goes into app config or a config plugin, and the prebuild output is checked to carry it. Label text goes into the source catalog as a key. Every STOP line is put to the user first.

### 3. Green, across the class — all five
1. **The oracle passes** at the same tier, on the same device and build type.
2. **Every class variant passes, on every platform shipped.** Process death: config change (rotation, dark mode, font scale, locale), "Don't keep activities" as an *additional* variant, the state of screen N−1, a dialog open at kill time, an in-flight request. Permissions: deny, deny twice, "Only this time", revoke while running, limited photos, approximate location. Accessibility: each screen state (loading, empty, error, content), the largest font, dark theme, RTL, an open sheet. Offline: kill during enqueue, during upload, after the server commit and before the ack, logout with a pending outbox. The full lists are `proof-oracles.md` § Mobile, *Class variants (mobile)*.
3. **Strict decrease (accessibility).** Re-run the checker at the screen-state. Accept only when the finding's check count strictly drops, the screen's total strictly drops, and the set of check types is a subset of `before`.
4. **No regression.** Every other screen the changed wrapper or client serves keeps its checker count and its behaviour; the release build still starts; a render-count or launch figure is unchanged unless the finding was about it.
5. **Every number is labelled measured**, with device, build type and run count. A delta inside the noise band reads `NO-CHANGE`.

If any of the five fails, the fix is wrong. Do not move on.

### 4. RE-DETECT (the owning detector on the diff)
Re-run the detector recorded in Phase 2 on the patched `<file:line>` and its surrounding diff. It must go quiet there and raise nothing new. A detector that still reports means the patch moved the symptom; reopen the finding.

### 5. Self-check the fix's own diff
The command does not grade its own honesty; the scripts do. On the diff from `FIX_BASE` to the working tree:

```bash
python3 "$TI" --base="$FIX_BASE" --json      # deleted test or case, fewer assertions, new skip/only/xfail, removed CI test step
python3 "$OC" --base="$FIX_BASE" --json      # no-assertion, weak-oracle, tautology in every case this fix added or touched
git diff -U0 "$FIX_BASE" | rg -n --pcre2 '^\+(?!\+\+).*(?:\bforce-stop\b|\bstopApp\b|\.recreate\(\)|\.terminate\(\)|\baccessible=\{\s*false|importantForAccessibility=["{]\s*["\x27]?no-hide-descendants|\baccessibilityElementsHidden\b|\.accessibilityHidden\(\s*true|\bExcludeSemantics\b|\bclearAndSetSemantics\b|\ballowFontScaling=\{\s*false|\bmaxFontSizeMultiplier=\{\s*1\b|\bTextScaler\.noScaling\b|\bwithNoTextScaling\b|\bhitSlop=|@SuppressLint\b|\btools:(?:ignore|node="remove")|//\s*ignore(?:_for_file)?:|swiftlint:disable|eslint-disable|@ts-(?:expect-error|ignore)|\bretryTimes\(|\bit\.skip\(|\bxit\(|@Ignore\b|\bXCTSkip\b|\b(?:targetSdk|minSdk)(?:Version)?\b|IPHONEOS_DEPLOYMENT_TARGET|\bruntimeVersion\b)'
git diff --name-only "$FIX_BASE" | rg -n --pcre2 '(?:AndroidManifest\.xml|Info\.plist|\.entitlements|PrivacyInfo\.xcprivacy|app\.(?:json|config\.[jt]s)|eas\.json|build\.gradle(?:\.kts)?|\.pbxproj|\.xcconfig|network_security_config\.xml|data_extraction_rules\.xml)$'
```

- **Either script exits 1 → the finding does not close.** Rework the fix so nothing is net-removed, or put the row to the user as a STOP item; until approved it stays `escalated (integrity: <kind> <file:line>)`. Exit 2 is a failed lane: `self-check: blocked`, never clean.
- **Every line the suppression grep prints** must be a legitimate use read in context — a fixed-size badge whose box must not grow while body text still scales, decorative content hidden on purpose ([`precedents/mobile.md`](../../../snippets/precedents/mobile.md) § 61–62), "Don't keep activities" or `recreate()` as an *additional* variant beside the real kill — cited in the closure row, or the hunk is reverted. A `targetSdk`, `minSdk`, deployment-target or `runtimeVersion` line is a STOP line: it needs the user's recorded yes.
- **Every file the last line prints** is a store, permission, signing or OS-floor surface: the closure row cites the STOP approval for its hunk, or shows the hunk crosses no STOP line.
- Without the repo-baseline scripts, read `git diff -U0 "$FIX_BASE"` for removed assertions and added skips, run both greps, and mark the row `self-check: inline (repo-baseline scripts absent)`.

### 6. Sweep for siblings
State the root cause in one line (`refute-before-report.md § 6`): "the one axios instance sets no timeout", "screens keep drafts in component state", "logout clears storage but keeps the push token", "the shared `IconTap` renders no name" — not "the cart screen spins". Grep it with the owning detector's pre-flight line narrowed to that cause, and run each hit back through Step 1. Each confirmed hit is **fixed**, **explained** (one line, or Refuted by a named gate), or **followup** (its own id). `N_found == N_fixed + N_explained + N_followup` must hold.

### 7. Suites, lint and release builds (after the last finding)
Run the project's tests (unit, widget, instrumented and the Maestro or Detox flows, through `bash .claude/hooks/test-lane.sh run '<cmd>'` when the repo-baseline is installed), the typecheck, the lint lanes at their CI level (Android lint, detekt, `flutter analyze`, SwiftLint, ESLint), and the project's release build for each platform. Red here reopens the finding whose change it traces to.

### Commit (one finding = one commit, only where the repo allows it)
Read the convention first (recent `git log`, a protected or PR-only branch, a no-commit rule in `CLAUDE.md` or `CONTRIBUTING`). Where commits are allowed: `fix(mobile): <what a user lost or could not do> — <finding id>`, for example `fix(mobile): the compose draft was lost when Android killed the app — M-02`. Otherwise **leave the change staged and say so**.

## Phase 5 — Update
- Update `ai/audits/<date>-mobile*.md` in place, or write a `-fix.md` companion: mark each finding and append the closure table.
- `ai/dynamic/changelog.md`: `Mobile fix on <scope>: C closed, S staged, O open (no device), E escalated, D deferred`.
- `ai/status.md` `## Recent Changes`: one bullet per STOP decision still owed and per finding left open for want of a device.

### Closure table (required artifact)
```
| Finding | Class (detector §)        | Platform · device · build     | Oracle (tier): before → after       | Variants      | Checker count | Self-check (TI · OC · grep · files) | RE-DETECT | State                    |
|---------|---------------------------|-------------------------------|-------------------------------------|---------------|---------------|-------------------------------------|-----------|--------------------------|
| M-02    | process death (lc §1)     | android · Pixel 8 API 36 · rel | Process-death restore (D): fail → pass | 6/6 android | —             | 0 · 0 · 0 · 0                       | quiet     | <sha> fix(mobile)        |
| M-02    | process death (lc §1)     | ios · no simulator            | flow written, not run               | —             | —             | —                                   | —         | open (ios: no device)    |
| M-05    | name (a11y §1)            | both · RNTL host + Pixel 8    | Name and role query (I): fail → pass | 5/5          | 4 → 1         | 0 · 0 · 0 · 0                       | quiet     | staged (PR-only)         |
| M-07    | permissions (lc §3)       | ios                           | —                                   | —             | —             | —                                   | —         | escalated: STOP purpose string |
```
A finding with no failing-first proof at its tier, a platform not run, a strict-decrease gate not met, a self-check that flagged, or a RE-DETECT that is not `quiet` is **not** closed.

## Phase 6 — Validate
- Each closed finding has a failing-first proof at its tier on a named device, a green run of every variant on every platform shipped, the strict decrease for accessibility rows, a clean self-check, a quiet RE-DETECT, a balanced sibling ledger and green suites and release builds.
- **Re-run `/mobile-audit` on the touched scope** (with the same `--classes`). The verdict must not regress on either axis, and each first-pass finding must no longer reproduce at its `<file:line>`.
- No store declaration, permission manifest, OTA runtime, signing or minimum-OS line changed without the user's yes.
- The report says "automated floor" for accessibility: a closed checker finding is not a claim the screen is accessible; the TalkBack / VoiceOver walk stays a human row (`precedents/ui.md` § 58).

## Phase 7 — Improve
- `/learn-from-task`: record each closed class and the primitive that closed it.
- A class seen in two audits gets an ADR in `ai/decisions/` and its mechanical guard: the process-death Maestro flow in CI, the native a11y checker test at error, the lint rule at error, a Reassure baseline, StrictMode `penaltyDeath` or Main Thread Checker in the test plan, a merged-manifest and `zipalign -c -P 16` check on the release artifact.

## Output format
```
## /mobile-fix — <N closed · M staged · O open (no device) · E escalated · K deferred>
Input:  ai/audits/<date>-mobile.md  (findings: <total>; routed: /security-fix <s>, /optimize-bundle <z>)
Devices: android Pixel 8 API 36 (release) · ios <simulator | none>
Order:  MUST FIX (<c>) → SHOULD FIX (<m>) → OPTIONAL (<l>)
Closure table: (Phase 5 — one row per finding per platform)
Escalated (decision owed):
  - M-07  NSPhotoLibraryUsageDescription added to app.json for the avatar picker — approve the key and its wording?
  - M-11  runtimeVersion policy appVersion → fingerprint — installed 4.2.x binaries stop receiving updates until 4.3 ships; approve?
Suites: jest PASS · maestro (3 flows, android) PASS · ./gradlew lintRelease PASS · release builds: android PASS, ios not run (no Xcode)
Re-audit: /mobile-audit on touched scope → verdict <was → now>, no regression · automated floor only
Status: COMPLETE | INCOMPLETE  (COMPLETE only when every MUST-FIX finding is closed on every platform shipped, or escalated, the self-check is clean and the re-audit did not regress)
```

## What to do next — required closing section
Every run ends with `## What to do next`: the remaining work as ONE ordered, numbered to-do. **MUST FIX** (open or escalated BLOCKER, HIGH, HARD-BLOCK and REJECTION) first, then **SHOULD FIX**, then **OPTIONAL**. Each step carries `<file:line>` and the platform, the **Fix**, and the **Verify** (the oracle by name and its tier). An open-for-want-of-a-device item names the device and the written flow that settles it. An escalated item names the decision the user owes: the store declaration, the permission and its prompt, the runtime bump and the binaries it orphans, the signing change, the OS floor and the users it drops. The closing steps are: re-run `/mobile-audit` to confirm the verdict, `/learn-from-task`, then ship or open the PR. A fully closed run collapses to one line. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes
- **Green on the host, never on a device.** A unit test that mocks the OS proves nothing about a kill, a denial, a link or a push.
- **The wrong kill.** Force-stop or `recreate()` as the oracle; a kill with no `ps` check; a restore asserted after a resume.
- **Green by hiding.** The node hidden from the accessibility tree, scaling turned off, a lint suppressed: the count drops and the user still cannot do the thing.
- **One platform closed for two.** An Android pass reported as the fix; the iOS row never run.
- **The fix in the generated folder.** An Expo CNG `android/` or `ios/` edit that the next prebuild erases.
- **A STOP line crossed quietly.** A permission, a purpose string, a runtime version or a minimum OS changed as "just the fix".
- **Committing against repo policy.** On a PR-only branch, leave the change staged and say so.

## Related

### Sibling commands
- `/mobile-audit`: the producer. Without a report the refuse-to-run gate halts.
- `/optimize-bundle` (this pack): app size. `/security-fix` (security pack, when installed): device security. `/upgrade-dep`: a version upgrade a fix needs. `/polish` (ui-ux, when installed): the visual verbs for target size and contrast. `/fix-bug`: the general discipline ([`fix-bug-core.md`](../../../snippets/fix-bug-core.md)).

### Detector skills (re-run for RE-DETECT)
This pack: `mobile-lifecycle-scan` · `mobile-a11y-scan` · `mobile-perf-scan` · `offline-sync-scan` · `store-compliance-scan` · `platform-conventions-audit` · `native-bridge-audit`; `device-harness` runs the D-tier oracles. ui-ux (when installed): `ui-state-scan` · `state-matrix`.

### Agents
`@offline-sync-auditor` (durable only after a real kill) · `@device-performance-auditor` (cost on a named device, release build) · `@app-store-reviewer` (store consequences) · `@ux-reviewer` (ui-ux, when installed; the native-WCAG judge) · `@verifier` (repo-baseline, mode `refute`).

### Shared contracts
[`refute-before-report.md`](../../../snippets/refute-before-report.md) · [`precedents/mobile.md`](../../../snippets/precedents/mobile.md) · [`precedents/ui.md`](../../../snippets/precedents/ui.md) · [`fix-bug-core.md`](../../../snippets/fix-bug-core.md) · [`review-action-plan.md`](../../../snippets/review-action-plan.md)
