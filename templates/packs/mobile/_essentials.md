---
track: mobile
purpose: Mobile app architecture (iOS / Android / cross-platform) — screens + features + native bridges + offline + deep-links + bundle hygiene.
essentials:
  agents: [mobile-architect, app-store-reviewer, offline-sync-auditor, device-performance-auditor]
  commands: [add-screen, add-feature, optimize-bundle]
  skills: [bundle-analyze, native-bridge-audit, platform-conventions-audit, device-harness]
  rules: [mobile-principles, render-discipline]
  ai-patterns: [app-lifecycle, permissions, offline-sync, native-storage, deep-linking, push-notifications, release-pipeline]
---

# Mobile — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category:
- **agents**, and the boundary between them: `mobile-architect` **plans** — every screen and every piece of state must name which OS power applies (suspend/kill · deny · throttle · reject · the installed copy you cannot reach) and what answers it. `app-store-reviewer` **judges the submission** — whether the built release can be uploaded, will survive review, or will be penalised after publication, separating HARD-BLOCK (a dated machine gate at upload) from REJECTION (a cited guideline) from PENALTY (a post-publish store consequence). The two auditors added at 1.8.0 cover what neither of those catches, because neither is a store problem and neither shows up in a passing test suite: `offline-sync-auditor` **proves the data promises** — for every "Saved" the UI shows before the server accepted the write, it returns a per-entity durable / lossy / unproven verdict with `<file:line>` for the persisted queue, the idempotency key and the conflict policy, tested against process death, duplicate delivery, reordering and a second account on the same device. `device-performance-auditor` **judges what the app costs the person holding the phone** — startup, responsiveness, memory, battery — and refuses any figure not measured on a named device, in a release build, more than once, separating a published platform threshold from a project budget from an unmeasured claim. The two meet at one seam: a memory kill *is* process death, so the second agent's kill measurement turns the first agent's `lossy` verdicts into active data-loss bugs. None of the four re-audits the usability floor — that is `ui-principles.md` § Axis catalog (ui-ux pack) — and neither auditor re-owns what it delegates: frame *causes* stay with `render-discipline`, size stays with `bundle-analyze`, the execution window stays with `app-lifecycle`, and the store consequence of a vital stays with `app-store-reviewer`.
- **commands**: `/add-feature` is the canonical orchestration — prior-art gate, sibling-shape halt, new-dependency gate, and a Phase 4 reviewer cascade whose preconditions now reach all four agents (`@security-auditor` on a biometric / keychain / secrets diff, `@app-store-reviewer` on a store update, `@offline-sync-auditor` on a write path, `@device-performance-auditor` on a bundle / cold-start delta), with a BLOCKER halt and an inline-review fallback when an agent is not installed. `/add-screen` is a scope-narrowing **overlay** on it (1.9.0) rather than a second copy: it adds only what one screen needs — the screen-level mirror axes, the sensitive-entity gate, the screen design, and the deep-link registration — so a Heavy screen gets the same cascade a Heavy feature gets. `/optimize-bundle` owns size; cold start routes to `@device-performance-auditor`.
- **skills**: `bundle-analyze` (one-shot size analysis), `native-bridge-audit` (audit JS↔native bridge code), `platform-conventions-audit` (judge a static tree against each platform's conventions), `device-harness` (boot a named simulator / emulator, drive the app, and capture evidence — screenshots, the UI tree, cold start, a deep-link open, a process-death restore). The first three reason over files; the fourth is the only one that looks at the running app, and it reports `SKIPPED` rather than describing a screen it did not see.
- **rules**: these two are the pack's only always-loaded cost, so both are deliberately thin. `mobile-principles` carries the MUSTs that change the next line you write and delegates every subject that has an on-demand home. `render-discipline` carries the 8 shape-based detectors and their closure verbs; the **per-framework fingerprints and their lint / profiler enforcement moved into `references/<framework>.md` § Render-discipline fingerprints** at 1.9.0, because a project is exactly one framework and three of the four columns were dead weight in every session. `phase-4.2-apply.md` copies only the detected framework's reference, so the depth arrives without the cost. Backs the render-waste class in `/optimize` + `/audit` for `mobile-*`.
- **ai-patterns**, ordered as a build reads them: `app-lifecycle` (the OS suspends, kills and throttles you — the state machine, what determines an execution window, state restoration after process death); `permissions` (the four-state model, pre-prompt, re-check-on-every-use, degrade-don't-crash, and the declaration surface the stores review); `offline-sync` (read/write strategies offline — what to replay in the window `app-lifecycle` grants); `native-storage` (right primitive per data class); `deep-linking` (URL schemes / universal links / push routing); `push-notifications` (client-side push lifecycle — permission priming, token sync + invalidation, channels/categories, foreground + receipt states; the grant itself delegates to `permissions`, routing to `deep-linking`); `release-pipeline` (identity separation, signing material CI holds and the repo never contains, symbol upload, beta track, staged rollout with a written halt criterion).

### Deliberately NOT in minimal

Recorded so the next omission is auditable rather than silent — `_essentials.md` is a curation, and nothing in the gate set can tell a considered exclusion from drift (check 4 verifies that listed entries resolve, never that present artifacts are listed).

- `ota-updates` — conditional on the stack, not on the project. A native Swift or Kotlin app cannot ship a JS/asset OTA at all, so it would be dead weight in the minimal install for a whole class of target. Standard mode ships it, and any Expo / React Native project should pull it in.
- `mobile-api-contract` — it governs *changing* a contract that shipped clients already depend on, which is a problem you acquire after v1 is in the wild, not before it. Standard mode ships it; add it to a minimal install the moment a second client version exists.
- `refactor` (command) — an overlay on the universal `/refactor`; it adds gates rather than capability.

## What this pack is NOT for

- **Backend APIs** mobile consumes → use the `backend` pack.
- **Web frontend** even if it reuses components (PWA / mobile web) → use the `frontend` pack.
- **Embedded / IoT firmware** → out of scope.

## How this pack relates to others

- **`backend`** — mobile features almost always pair with backend endpoints. The `add-feature` commands across both packs are designed to compose.
- **`security`** — mobile-specific concerns (keychain, biometric, certificate pinning) covered by `security/agents/security-auditor.md` + `auth-reviewer.md`.
- **`performance`** — cold start, frame rate, memory and battery are owned here by `device-performance-auditor` + `optimize-bundle`; the `performance` pack's `performance-optimizer` owns the server side of a slow screen (query plans, indexes, p99s behind the API) and receives the client-side measurement rather than re-deriving it.
- **`ui-ux`** — accessibility + design tokens apply equally to mobile; `ui-ux/skills/a11y-quick-check/SKILL.md` runs against mobile UI.
