# mobile pack — changelog

Release history for `templates/packs/mobile/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.7.0 — 2026-08-21

Native depth, and a fabrication repair on the numbers already shipped. The pack covered Flutter and
React Native and nothing else — a native iOS or native Android project got cross-platform guidance
and no reference at all. It also carried five platform figures that no source publishes, which is
the failure mode that matters most here, because mobile advice is mostly numbers and the reader acts
on them.

**New references (+3).** `swiftui.md` (native iOS), `jetpack-compose.md` (native Android),
`expo.md`. Every dated gate, limit and threshold in the three carries the URL that publishes it,
read on 2026-08-21 and quoted verbatim rather than paraphrased. `swiftui.md` additionally documents
the *mechanism* for checking an Apple API before emitting it — the JSON twin at
`developer.apple.com/tutorials/data/documentation/<framework>/<symbol>.json` — because this is the
platform where a model most reliably writes code that compiles and is three API generations stale.
The two deprecations it asserts (`NavigationView`, `foregroundColor(_:)`, both 27.0 on every
platform) now each carry their own JSON-twin URL, so an auditor can pull the exact claim rather than
the file's general promise that it checked.

**New ai-patterns (+4).**

- `app-lifecycle` — the OS state machine including process death, choosing between deferrable
  scheduled work / foreground services / ordinary async, and state restoration. Its § "Execution
  windows are budgeted, not published" states only what Android publishes (`shortService` 3 minutes,
  the 10-minute interruption guidance, Doze and the Standby buckets, each quoted and cited) and says
  plainly that **Apple publishes no fixed duration this pack can cite, so it states none** — listing
  what determines the window instead. Owns *when* the OS lets you run; `offline-sync` owns *what*
  you replay in the window.
- `permissions` — the four-state model, the one-shot dialog and why priming exists,
  re-check-on-every-use, degrade-don't-crash, and the declaration surface (purpose strings, privacy
  manifest, data-safety form, foreground-service types). The notification grant stays with
  `push-notifications`; everything else moved here.
- `release-pipeline` — identity separation across dev/beta/prod, signing material CI holds and the
  repository never contains, symbol upload as a build step, beta track before production, staged
  rollout with a **written halt criterion**. Platform file names stay in `references/`; the
  discipline here is platform-neutral.
- `mobile-api-contract` — designing a server contract for clients you cannot redeploy:
  additive-only, tolerant client parsing, version negotiation, the minimum-supported-version gate as
  a product decision, kill switches, and a sunset protocol that measures the installed-version
  distribution before removing anything.

**New skill (+1): `device-harness`.** The pack could describe what a screen should do on two
platforms and had no way to look at either. This boots a **named** simulator or emulator, installs
the build, drives it to a screen, and captures evidence — screenshots, the UI tree, cold start, a
deep-link open, a process-death restore. Every artifact names the device, the build variant and the
commit; a run with no device available reports `SKIPPED` rather than describing a screen it did not
see. It produces evidence, it does not judge conformance — that stays with
`platform-conventions-audit`, the `ui-ux` floor, and a human.

**Fabrication repair — five figures removed, one miscitation corrected.** Each was a specific number
a reader would have acted on:

- **Apple "§ 3.3.2"** cited as an App Review Guideline in `ota-updates` and `app-store-reviewer`.
  3.3.2 is a Developer Program License Agreement clause; the Review Guidelines contain no § 3.3 at
  all. The downloaded-code rule is **2.5.2**, now quoted from the live Guidelines. A finding citing
  3.3.2 to a reviewer cites a document the reviewer is not reading.
- **"crash rate > 5% is review-rejection territory"** (`app-store-reviewer`). Apple publishes no
  crash-rate figure. Google publishes user-perceived thresholds — 1.09% overall / 8% per device
  model, ANR 0.47% / 8% — and the consequence is **reduced discoverability, not rejection**. Both
  now cited to `developer.android.com/topic/performance/vitals/`.
- **"MMKV is 10-30x faster than AsyncStorage"** (`native-storage`). A vendor benchmark, not a
  property of your app. Replaced with the qualitative claim plus an instruction to measure on the
  read pattern the app actually has, on a named device.
- **"iOS gives ~2–3 silent pushes/hr"** (`push-notifications`). Neither platform publishes a
  delivery rate. Replaced with the signals that actually govern a background wake-up, cross-linked
  to the sourced Android side in `app-lifecycle`.
- **"persistent cache with size cap (e.g., 100MB)"** (`native-storage`). A project budget presented
  as a platform figure. The finding is a cache with *no* cap, not one with a different number.
- **Staged-rollout ladder "5% → 25% → 100%"** (`ota-updates`) demoted from prescription to house
  convention: Play documents that the developer selects the percentage and prescribes no ladder.

Backing this, `rules/mobile-principles.md` now carries a MUST that any platform threshold, limit or
window quoted anywhere carries the URL that publishes it — and names the four places this pack has
got it wrong before (background windows, review turnaround, crash-rate thresholds, install-base
statistics). `commands/optimize-bundle.md` ships its report template with **no** worked numbers, for
the same reason: a plausible size in a template is the easiest thing for an agent to reproduce as a
finding.

**Android storage correction.** `EncryptedSharedPreferences` is deprecated —
`androidx.security:security-crypto` 1.1.0-beta01 (2025-06-04) "Deprecated all APIs in favour of
existing platform APIs and direct use of Android Keystore", and that stands in 1.1.0 (2025-07-30).
The `native-storage` decision matrix now routes Android secrets to the Keystore directly, with the
release page cited and re-check instructions, because this is a versioned status rather than a
permanent fact.

**FCM endpoint correction.** The `deep-linking` test-command table used the retired legacy
`/fcm/send` endpoint with `Authorization: key=<server-key>`. Replaced with HTTP v1
(`/v1/projects/<id>/messages:send`, OAuth bearer). A test script still using the legacy form is a
finding, not a working test.

**Agents and detectors rewritten around their poles.** `mobile-architect` now runs on "a mobile app
is a guest process on hardware that owes it nothing" — five OS powers (suspend/kill · deny ·
throttle · reject · the installed copy you cannot reach), with `web-app-in-a-shell` and
`platform-cargo-cult` as the two failure poles, and an explicit greenfield branch that names a
decision as new instead of presenting an invention as a sibling mirror. `app-store-reviewer` splits
HARD-BLOCK (a dated machine gate at upload) from REJECTION (a cited guideline) from PENALTY (a
post-publish store consequence), and names `policy-cosplay` as its own characteristic failure.
`platform-conventions-audit` gained a closed closure-verb vocabulary: `touch-target-drift` is now
ROUTED to `ui-ux`'s `expand-tap-target` and emits no verb of its own (it was emitting
`expand-touch-target`, which nothing downstream recognises), and the icon-set and typography
detectors now fire only against a **declared** convention — a single cross-platform icon set or one
brand typeface is a legitimate design decision, not a spec violation.

**Manifest repair — the reason the above nearly did not ship.** All five new artifacts were absent
from `_topics.md`, so `phase-4.2-apply` AUTHOR mode would have generated none of them and a
greenfield mobile app — the common case for this pack — would have received nothing. Fixed:

- `_topics.md` +6 entries: the five new artifacts, plus `refactor`, whose overlay has never had one.
  The `refactor` entry points at `commands/refactor.md`, not at `_examples/refactor.md` — that file
  is a six-line usage anecdote carrying none of the overlay's navigation / lifecycle / bundle-size /
  platform-API gates, and a no-signal install pointed at it would have received two bullets about a
  Dart rename in their place. Frontend hit the identical shape and deleted its anecdote; mobile's is
  kept as documentation and disowned as a fallback in the entry itself.
- `_topics.md` header now states the pack's fallback convention and why: the source IS the fallback
  for everything except `mobile-architect` and `mobile-principles`. These files carry dated store
  gates, cited limits and cite-or-halt detectors, and an abridgement of one is a shorter document
  that has quietly dropped a safety signal.
- `_essentials.md`: `device-harness` added to skills; `app-lifecycle`, `permissions` and
  `release-pipeline` added to ai-patterns, ordered as a build reads them. A new § "Deliberately NOT
  in minimal" records why `ota-updates` (stack-conditional — a native app cannot ship a JS OTA),
  `mobile-api-contract` (a problem acquired after v1 is in the wild) and the `refactor` overlay are
  excluded. `_essentials.md` is a curation and no gate can distinguish a considered exclusion from
  drift, which is how `ota-updates` went missing silently at 1.6.0; the omissions are now auditable.

## 1.6.0 — 2026-07-10

- ai-patterns +1: ota-updates (JS/asset-only OTA lifecycle, staged rollout, mandatory-update
  min-version gate, rollback; store-policy conformant).

## 1.5.0 — 2026-07-09

- ai-patterns +1: push-notifications — the send/receive lifecycle (permission-UX timing, token
  registration+server-sync+410 invalidation, Android channels / iOS categories, foreground
  presentation, silent/rich payloads, badge). Owns everything except routing, which hands off to
  deep-linking. Backing MUST in mobile-principles.

## 1.4.0 — 2026-06-16

- add-feature: NEW prior-art gate (Phase 1, all tiers) — searches by behavior for an already-shipped
  screen/flow and HALTs to the user on a near-duplicate; on mobile a duplicate means a second
  offline queue / permission prompt / native-config block drifting independently.
- add-feature: NEW new-dependency gate (Phase 4, all tiers) — a JS package / Pod / Gradle dep no
  sibling uses halts for a dependency review (maintenance / license / bundle + binary-size /
  supply-chain / forced native permissions). HALTs on a dep that silently adds a permission outside
  the declared native surface. Added matching invariant.
- add-feature: standard-tier closure-verb row now requires a bundle / cold-start delta check against
  the Phase 2 budget (any new screen or heavy import).

## 1.3.2 — 2026-06-14

- platform-conventions-audit skill: added `name:` frontmatter field (was missing).

## 1.3.1 — 2026-06-13

- add-feature P0 FIX: trivial-tier deliverable changed from 'Code only.' to 'Code + tests.' — it
  previously allowed untested feature code to ship, contradicting its own Phase 6 'tests pass on iOS +
  Android' gate and diverging from the backend/frontend packs. Added a 'tests ship every tier'
  invariant.
- add-feature: wired the universal --plan handoff flag (templates/snippets/plan-flag.md).
- add-feature: sibling-shape halt BLOCKER:<axis> output now maps onto the shared drifted verdict
  (templates/snippets/sibling-shape-halt.md).

## 1.3.0 — 2026-06-10

- add-feature Phase 6: NEW observability sign-off — crash reporting covers new screens,
  screen-view/perf signal mirrors siblings, offline-queue failures surface to telemetry (not just
  local logs); projects with no observability layer report 'observability: none configured'
  explicitly.
- add-feature Phase 6: NEW release note (heavy tier) — feature flag / remote-config kill switch
  (store review latency makes a flag the only same-day rollback), staged rollout plan (iOS phased /
  Android staged %), store-metadata changes, rollback path.
- add-feature Phase 7: /learn-from-task dispatch added (was the only add-feature variant without it
  — learning loop now closes).
- add-feature Phase 4: missing-agent fallback — uninstalled reviewers in the serial cascade are
  performed inline against their pack/domain checklist, never silently skipped.
- add-feature: 'Phases applied' now tier-scoped (heavy = all 7; trivial/standard run their
  ceremony's subset) — matches the closure-verb table instead of contradicting it.

## 1.2.0 — 2026-06-06

- NEW rule: rules/render-discipline.md — rebuild / re-render waste discipline. 8 shape-based
  detectors (oversized-state-scope, side-effect-in-build, missing-stable-subtree,
  unstable-list-item-props, unvirtualized-list, animation-rebuilds-subtree, store-overinvalidation,
  logic-in-view) with per-framework fingerprint tables for Flutter / React Native / Jetpack Compose
  / SwiftUI. Promotes the setState/rebuild guidance previously buried in references/flutter.md into
  an enforceable rule.
- Closure verbs: scope-state-down, move-to-lifecycle, extract-const-subtree, memoize,
  virtualize-list, scope-animation, select-store-slice; logic-in-view routes to /align (layer
  violation). Every fix requires a before/after rebuild-count or frame-time measurement; blanket
  defensive memoization is itself flagged (over-abstraction).
- Wired into /optimize (Performance class — render/rebuild waste detectors + verbs for
  frontend-*/mobile-*) and /audit (runtime-perf axis, stack-routed via PROJECT_KIND).
- _essentials.md rules list + _topics.md topic spec updated in the same change.

## 1.1.0 — 2026-05-03

- Adds platform-conventions-audit skill (backs /polish on mobile stacks).
