---
track: mobile
purpose: Mobile app architecture (iOS / Android / cross-platform) — screens + features + native bridges + offline + deep-links + bundle hygiene.
essentials:
  agents: [mobile-architect, app-store-reviewer]
  commands: [add-screen, add-feature, optimize-bundle]
  skills: [bundle-analyze, native-bridge-audit, platform-conventions-audit, device-harness]
  rules: [mobile-principles, render-discipline]
  ai-patterns: [app-lifecycle, permissions, offline-sync, native-storage, deep-linking, push-notifications, release-pipeline]
---

# Mobile — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category:
- **agents**: `mobile-architect` designs against the OS rather than against a browser — every screen and every piece of state must name which OS power applies (suspend/kill · deny · throttle · reject · the installed copy you cannot reach) and what answers it; `app-store-reviewer` decides whether the built release can be uploaded, will survive review, or will be penalised after publication, separating HARD-BLOCK (a dated machine gate at upload) from REJECTION (a cited guideline) from PENALTY (a post-publish store consequence). Neither agent re-audits the usability floor — that is `ui-principles.md` § Axis catalog (ui-ux pack).
- **commands**: `/add-screen` (single screen), `/add-feature` (multi-screen feature), `/optimize-bundle` (size + cold-start).
- **skills**: `bundle-analyze` (one-shot size analysis), `native-bridge-audit` (audit JS↔native bridge code), `platform-conventions-audit` (judge a static tree against each platform's conventions), `device-harness` (boot a named simulator / emulator, drive the app, and capture evidence — screenshots, the UI tree, cold start, a deep-link open, a process-death restore). The first three reason over files; the fourth is the only one that looks at the running app, and it reports `SKIPPED` rather than describing a screen it did not see.
- **rules**: `mobile-principles` (foundational rules — touch targets, permissions, offline, lifecycle); `render-discipline` (rebuild / re-render waste — 8 detectors with Flutter / RN / Compose / SwiftUI fingerprint tables; backs the render-waste class in `/optimize` + `/audit` for `mobile-*`).
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
- **`performance`** — mobile-specific concerns (cold start, frame rate, battery) covered by `optimize-bundle` here + `performance` pack agents.
- **`ui-ux`** — accessibility + design tokens apply equally to mobile; `ui-ux/skills/a11y-quick-check/SKILL.md` runs against mobile UI.
