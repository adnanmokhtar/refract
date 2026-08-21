# mobile pack — changelog

Release history for `templates/packs/mobile/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.8.0 — 2026-08-22

The two audits nobody owned. The pack could **plan** a mobile app (`mobile-architect`) and **judge
its submission** (`app-store-reviewer`), and between those two sat the entire question of whether
the built app is any good on a real phone. Both gaps have the same shape: the failure is invisible
to a passing test suite, invisible to a store reviewer, and only reproduces on a device that is not
the one on the developer's desk. Agents 2 → 4.

**New agent: `offline-sync-auditor`.** The pack has described offline sync since 1.0 — the strategy
table, the queue components, the conflict options are all in `ai-patterns/offline-sync.md`, and
`mobile-architect` classifies every screen works / degrades / blocks. Nothing read the code and said
whether the classification was true. This agent audits **the distance between what the screen told
the user and what the device can honour**: every "Saved", every dismissed sheet, every optimistically
moved row is a durability promise, and the verdict per entity is `durable` / `lossy` / `unproven`
with `<file:line>` for the persisted queue, the idempotency key and the conflict policy. It runs the
write path against process death, duplicate delivery, reordering, poison failures, account switch and
a local schema migration — the six cases no ordinary test exercises. Its poles are `optimistic-lie`
(the UI acknowledges what the device cannot honour) and `sync-engine-cosplay` (version vectors and a
merge UI over a read-only catalogue); both are rejected by name, and `sync-engine-cosplay` is a
finding at the same severity as a missing key. `unproven` is a first-class verdict, so "the code
looks careful" can never quietly become "durable". It recommends **no numbers at all** — no retry
ceiling, no backoff curve, no TTL, no queue cap — because no platform publishes one, and every
number in its report is read at a `<file:line>` or labelled the project's own budget.

**New agent: `device-performance-auditor`.** The pack could measure size (`bundle-analyze`), find
rebuild waste (`render-discipline`) and boot a device (`device-harness`, which by design captures
evidence and judges nothing). Nothing owned **what the app costs the person holding the phone**.
This agent takes the four costs — startup, responsiveness, memory, battery — and refuses any figure
not measured on a **named device, in a release build, more than once**. Its poles are
`simulator-truth` (a debug build, a simulator, or the newest flagship reported as user experience —
three lies that compound) and `micro-optimization-theater` (blanket memoization with no profile and
no post-fix metric). Its premise is a three-way split that most mobile performance advice collapses:
a PLATFORM THRESHOLD is published and cited, a PROJECT BUDGET is chosen and measured, and an
UNMEASURED claim is not a finding.

**Every figure in it was fetched and quoted verbatim on 2026-08-22, and the absences were fetched
too.** Six sources, `[P1]`–`[P6]`: Android vitals excessive startup (cold 5s / warm 2s / hot 1.5s),
slow rendering (16ms at 60fps, 11ms at 90fps, 8ms at 120fps; "Frozen frames are UI frames that take
longer than 700ms to render"), low-memory killers ("An LMK rate above 1% indicates a critical need
for immediate action"), excessive partial wake locks ("2 or more hours in a 24-hour period"), and
two Apple pages read through the JSON twin the pack documented at 1.7.0 — hangs ("exceeds 250 ms",
"less than 100 ms … is rarely noticeable") and launch time. The Apple launch-time page is the reason
the § Deliberately absent list exists and is load-bearing: **Apple publishes a method, not a target**
(the Xcode Organizer Launch Time pane, read at the 50th and 90th percentile), so an Apple launch
figure would have to be invented to fill the cell the Android column occupies. Also declared absent
and never to be written: an Apple per-app memory ceiling, an Apple battery or thermal threshold, a
Play bad-behaviour threshold for slow or frozen frames (the 16ms/700ms figures are rendering
definitions, not store-visibility thresholds), and the pack-wide background-window duration. The
crash and ANR thresholds and the **store consequence** of any vital are deliberately *not* restated
here — `app-store-reviewer` already carries them, cited, and one number in two places is how a
figure drifts.

**Both agents refuse a floor they delegate**, which is the discipline `creative-director` (ui-ux)
established and the one this pack's 1.7.0 rewrite adopted. `device-performance-auditor` measures the
frame and hands the *cause* to `render-discipline` by detector number, emitting no ninth detector and
no competing closure verb; it consumes `bundle-analyze`'s size number and is HALTed from producing
one; it reads `device-harness` artifacts and is HALTed from describing a run that did not happen; it
names no background-window duration and picks no scheduler (`app-lifecycle`); it quotes no store
consequence (`app-store-reviewer`); it routes a slow endpoint to `performance-optimizer` with the
client measurement attached. `offline-sync-auditor` takes `mobile-architect`'s works/degrades/blocks
as **input** and is HALTed from re-picking it, routes the offline copy out by axis name, and states
the client's requirement on server-side dedupe rather than designing the endpoint.

**The seam between them is the point.** A user-perceived low-memory kill *is* process death: Android
publishes that such a termination "looks like the app crashed, often bypassing standard lifecycle
state-saving mechanisms and resulting in lost user progress" `[P3]`. So the performance agent's kill
measurement converts every `lossy` entity in the sync agent's ledger from a theoretical risk into an
active data-loss bug, and both files carry that hand-off explicitly. Two agents that compose beat
five that overlap.

**What was evaluated and rejected**, recorded so the next pass does not re-litigate it:

- **A release / store-submission agent beyond `app-store-reviewer`.** The verdict and the eight
  dated machine gates are already its; the pipeline discipline — identity separation, signing
  material, symbol upload, beta track, staged rollout with a written halt criterion — is already
  `ai-patterns/release-pipeline.md` (229 lines, detectors, closure verbs, sources); what may ship
  without a review round-trip is `ai-patterns/ota-updates.md`. The residue was one decision the
  staged-rollout halt criterion already owns.
- **A native-module + permissions agent.** Bridge code is `skills/native-bridge-audit/SKILL.md` (a
  9-step procedure covering type safety, error propagation, threading, lifecycle, retain cycles,
  permissions, versioning and tests); the permission model is `ai-patterns/permissions.md` (four-state
  model, detectors, eight closure verbs); the declaration reconciliation is `app-store-reviewer` § 2
  and § 3; the degraded path is `mobile-architect` power 2. An agent there would have been a router
  over four existing owners with no point of view of its own.

**Manifest, in the same change** — the failure mode 1.7.0 nearly shipped and repaired:

- `_topics.md` +2 entries, both `kind: agent`, `cite_evidence: strict`, each with an `_examples/`
  fallback and a declared section list. `device-performance-auditor` carries a comment making
  `sources` non-optional for the same reason the 1.7.0 patterns do: an AUTHOR-mode rewrite that drops
  it leaves six numbers standing with nothing behind them and loses the "Deliberately absent" list.
- `_topics.md` header updated: four entries now point at `_examples/`, not two, and the paragraph
  states what the two new abridgements keep, in countable form — every halt condition (11 and 14),
  every invariant (9 each), both poles, every row of the delegated-floor table (9 and 10), and every
  figure with its URL. Exactly one § Failure modes bullet per file is dropped, each because its
  substance is restated elsewhere in the same abridgement (`reachability-as-truth` as a § Failure
  catalogue row; "a metric with no budget is a finding, not a blank" as an output heading). Nothing
  dropped from either is a number, a citation, a halt, or a boundary. Note what check 8b does and
  does not cover: it polices a fallback ASSERTING what its source does not say, so a fallback that
  silently DROPS a halt passes it — the counts above are the check for that, and they are the reason
  this bullet carries numbers instead of adjectives. `validate-pack-consistency.sh` check 8b reports
  295 pairs, 0 new findings.
- `_essentials.md`: both agents added to the minimal set, with the four-agent boundary written out
  (plan → submission verdict → data promises → device cost) and the seam between the two auditors
  named. The `performance` cross-pack row was corrected in the same edit: cold start, frame rate,
  memory and battery are owned here, and `performance-optimizer` owns the **server** side of a slow
  screen and receives the client measurement rather than re-deriving it.

Measured against 2e77692 — `git ls-tree -r 2e77692 templates/packs/mobile` for the before,
`find templates/packs/mobile -name '*.md' | xargs wc -l` for the after: mobile `agents/` 2 → 4
files, `_examples/` 3 → 5, pack markdown 4,936 → 5,962 lines (this entry counts itself, so the
after-figure moves whenever this file does — re-run the command rather than trusting it).

**Two files outside the pack change with it, and the release is not complete without them.**
`assets/pack-matrix.svg`, regenerated by `scripts/gen-pack-matrix.py`: the `mobile` agents cell
2 → 4, its bar width, the TOTAL 86 → 88, and the `<desc>` line's "Totals: 86 agents" → "88 agents"
— every hunk in the file, and nothing else. And `README.md`'s agent-count row, **86 agents** →
**88 agents**; `scripts/verify-readme-stats.sh` fails the repo until that cell is updated, which is
the gate that makes the coupling non-optional. Nothing else outside `templates/packs/mobile/` is
touched by this release.

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
