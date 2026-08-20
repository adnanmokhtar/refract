# mobile pack — changelog

Release history for `templates/packs/mobile/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

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
