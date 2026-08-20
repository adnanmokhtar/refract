---
track: mobile
purpose: Mobile app architecture (iOS / Android / cross-platform) — screens + features + native bridges + offline + deep-links + bundle hygiene.
essentials:
  agents: [mobile-architect, app-store-reviewer]
  commands: [add-screen, add-feature, optimize-bundle]
  skills: [bundle-analyze, native-bridge-audit, platform-conventions-audit]
  rules: [mobile-principles, render-discipline]
  ai-patterns: [offline-sync, native-storage, deep-linking, push-notifications]
---

# Mobile — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category:
- **agents**: `mobile-architect` designs (screens, features, navigation, state); `app-store-reviewer` audits releases pre-submission.
- **commands**: `/add-screen` (single screen), `/add-feature` (multi-screen feature), `/optimize-bundle` (size + cold-start).
- **skills**: `bundle-analyze` (one-shot size analysis), `native-bridge-audit` (audit JS↔native bridge code).
- **rules**: `mobile-principles` (foundational rules — touch targets, permissions, offline, lifecycle); `render-discipline` (rebuild / re-render waste — 8 detectors with Flutter / RN / Compose / SwiftUI fingerprint tables; backs the render-waste class in `/optimize` + `/audit` for `mobile-*`).
- **ai-patterns**: `offline-sync` (read/write strategies offline), `native-storage` (right primitive per data class), `deep-linking` (URL schemes / universal links / push routing), `push-notifications` (client-side push lifecycle — permission priming, token sync + invalidation, channels/categories, foreground + receipt states; routing delegated to `deep-linking`).

## What this pack is NOT for

- **Backend APIs** mobile consumes → use the `backend` pack.
- **Web frontend** even if it reuses components (PWA / mobile web) → use the `frontend` pack.
- **Embedded / IoT firmware** → out of scope.

## How this pack relates to others

- **`backend`** — mobile features almost always pair with backend endpoints. The `add-feature` commands across both packs are designed to compose.
- **`security`** — mobile-specific concerns (keychain, biometric, certificate pinning) covered by `security/agents/security-auditor.md` + `auth-reviewer.md`.
- **`performance`** — mobile-specific concerns (cold start, frame rate, battery) covered by `optimize-bundle` here + `performance` pack agents.
- **`ui-ux`** — accessibility + design tokens apply equally to mobile; `ui-ux/skills/a11y-quick-check/SKILL.md` runs against mobile UI.
