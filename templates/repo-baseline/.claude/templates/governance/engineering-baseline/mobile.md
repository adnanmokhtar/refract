---
artifact: engineering-baseline/mobile
purpose: Mobile rows. Applies to PROJECT_KIND mobile-*. The UI rows it shares with the web live in web.md and are listed at the bottom.
---

# Baseline — mobile

Format and verdicts: `README.md` in this directory.

| ID | Standard | Fires when the change… | MET means | Checked by | Source |
|---|---|---|---|---|---|
| MOB-1 | Tokens, passwords and keys live in Keychain / Keystore through the project's secure-store wrapper — never plain `AsyncStorage` / `SharedPreferences` / `UserDefaults`. | stores a credential or secret | the secure-store call site | gate · `@security-auditor` | `packs/mobile/rules/mobile-principles.md` |
| MOB-2 | Every network call has a declared timeout and an error path that updates the UI. | adds a request | the timeout constant and the error UI | gate | `packs/mobile/rules/mobile-principles.md` |
| MOB-3 | Permissions are requested in context behind a pre-prompt; denial degrades the feature, never crashes it; state is re-checked on every use. | adds a permission | the permission state machine | gate | `packs/mobile/rules/mobile-principles.md` · `packs/mobile/ai-patterns/permissions.md` |
| MOB-4 | State that must survive process death is persisted, not held in the view layer. | adds screen or flow state | the persistence site and a restore test | gate | `packs/mobile/rules/mobile-principles.md` |
| MOB-5 | Each screen's offline behaviour is classified — works / degrades / blocks — and implemented as classified; queued writes are idempotent. | adds a screen or a write | the classification and the sync path | gate · `@offline-sync-auditor` | `packs/mobile/ai-patterns/offline-sync.md` |
| MOB-6 | Background work goes through the platform scheduler with the declared service type. | adds background work | the scheduler call | gate | `packs/mobile/rules/mobile-principles.md` |
| MOB-7 | Screen-reader label on every interactive element; touch targets 44 pt (iOS) / 48 dp (Android). | adds interactive UI | labels in the diff | gate | `packs/mobile/rules/mobile-principles.md` |
| MOB-8 | Deep-link payloads are validated before routing. | adds or changes a deep link | the validator site | gate | `packs/mobile/rules/mobile-principles.md` · `packs/mobile/ai-patterns/deep-linking.md` |
| MOB-9 | Budgets — cold start, frame, memory, size — are written down, against a named device, before the first measurement. | adds a screen, a heavy dependency or a startup task | the budget and the measurement | gate · `@device-performance-auditor` | `packs/mobile/rules/mobile-principles.md` |
| MOB-10 | Orientation, dynamic type and dark mode hold on the changed screens. | changes a screen | a smoke pass on each | gate | `packs/mobile/rules/mobile-principles.md` |

**Shared with web** — apply to mobile UI unchanged: WEB-1 (shared components), WEB-2 (tokens),
WEB-3 (API client + cache), WEB-4 (standard error path), WEB-5 (loading / empty / error states),
WEB-6 (shared validation), WEB-7 (role-gated UI), WEB-11 (i18n).
