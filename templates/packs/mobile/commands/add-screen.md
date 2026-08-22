---
description: Add a new screen — full chain — route + screen component + navigation wiring + state + i18n + a11y + tests. Smaller than /add-feature; deeper than hand-editing.
---

# /add-screen

## Pack overlay — one screen

**Canonical orchestration: [`/add-feature`](add-feature.md) in this pack.** One screen is the same
seven phases with a narrower ask, not a different procedure — and the machinery a screen most needs
is the machinery this command used to be missing. `/add-feature` owns, and this command runs
unchanged: the **prior-art gate**, the **sibling-shape mechanical halt**, the **new-dependency
gate**, the **Phase 4 reviewer table with its per-agent precondition**, the **BLOCKER halt rule**,
the **not-installed inline-review fallback**, Phases 5–7, and the spec-consumption branch.

Nothing below repeats those. What is below is what a *screen* adds on top.

### Scope

- USE: a new screen on an existing flow; a new tab in an existing tab navigator; a new modal screen.
- NOT: a brand-new module or a flow spanning ≥2 screens → `/add-feature` directly.
- NOT: editing an existing screen → edit, then `/review-changes`.

The premise is `/add-feature`'s: **the closest sibling screen is the truth.** Derive the shape, do
not invent it. If no sibling exists in the same stack — HALT and ask for the gold-standard screen.

### Screen-scoped mirror axes (added to `/add-feature`'s sibling-shape halt)

Name the sibling screen's **file path** in the Phase 2 design output, then confirm each axis matches
it. These are mechanical, and any divergence is `drifted` in the shared vocabulary
([`sibling-shape-halt.md`](../../../snippets/sibling-shape-halt.md)):

- Folder depth + file-naming convention.
- Auth wrapper + navigation-options pattern.
- Data-fetching primitive (whichever the sibling uses — siblings win over preference).
- Error / loading / empty / content state shape — all four present on any data-driven screen.
- Locale-key namespace shape (`<module>.<screen>.<key>`), no new namespace invented.
- Native-config touchpoints declared: `Info.plist` keys, `AndroidManifest` entries, the linking-config
  registration line, the push-handler route.

### Tier — the same table, read at screen scope

`/add-feature` § Closure verb applies verbatim. Two clarifications for a single screen:

- **Trivial** is the default and is the common case: a screen that mirrors a sibling, adds no
  permission, no native config, and no write path.
- Any Heavy trigger — **new native permission class, biometric / Keychain / secrets touch,
  write-path mutation, store-blocking change** — promotes the run to `/add-feature`'s **full serial
  cascade**, including `@security-auditor` and `@app-store-reviewer`, which are gated on exactly
  those triggers. A Heavy screen is not a lighter cascade than a Heavy feature; it is the same one
  over fewer files.

### Sensitive-entity gate (runs before any form is scaffolded)

A screen that renders or collects a **payment instrument, credential, government or health
identifier, or third-party access token** is refused the generic screen scaffold on those fields.
The rule, the surface-by-surface branch table, and the mandatory report line are
[`frontend/commands/add-crud-page.md` § Data-sensitivity gate](../../frontend/commands/add-crud-page.md)
— **read it there; this pack does not carry a second version of it.** It is stack-neutral: a card
number belongs in the payment provider's hosted/tokenised primitive (its native SDK's card element,
or a web view it owns), never in a `TextInput` this command scaffolds, because a value your form
never receives cannot be logged, crash-reported, session-replayed, or held in form state.

Mobile adds two consequences the web branch does not have, and both are this pack's:

- **Where the token lands** is `native-storage.md` § Secrets — Keychain / Android Keystore, never
  `AsyncStorage` / `SharedPreferences` / `UserDefaults`.
- **The biometric unlock in front of it** is `native-storage.md` § Biometric-gated secrets — the
  hardware-backed requirement, enrollment-change invalidation, and the passcode-fallback decision.
  `/add-feature` § Hard rules states the floor: *no biometric without secure-enclave / hardware-backed
  keystore.*

If the project ships no provider primitive for that data class, that is a **HALT**, not a licence to
build the input.

### Phase 2 — the screen design (produced by `@mobile-architect`)

```
## Screen: <name>

### Route
Stack · route name · deep-link path · params (typed) · modal|push

### Components (new)      | name | path | type (screen container / display) |
### Data flow             | concern | source | cache primitive |
### State                 component-local vs store — and what must survive process death
### Mutations             endpoint + confirm UX + offline classification (works / degrades / blocks)
### Navigation wiring     parent screen call sites · push-notification entry · deep-link entry
### i18n keys (new)       | key | en |   — sibling's namespace shape
### A11y notes            per-element labels; live-region announcement for the loading state;
                          state never signalled by colour alone
### Tests                 | layer | file |   — mirroring the sibling's test shape
### Open questions        <flag for user>
```

**Accessibility figures are not this command's to state.** Touch-target minimums are **44×44 pt on
Apple** and **48×48 dp on Android** (`rules/mobile-principles.md` [S3] / [S4]); the axis is
`tap-target`, owned by `ui-principles.md` § Axis catalog *(ui-ux pack, when co-installed)* and closed
with `expand-tap-target`. Absent that pack, apply the two figures and mark the lane
`floor: not audited (ui-ux pack absent)`. Do not restate one platform's figure as universal, and do
not coin a mobile-only synonym for the axis.

### Phase 3 — what a screen reads, on top of `/add-feature` § Phase 3

`/add-feature` § Phase 3 items 1–9 apply unchanged. A screen additionally reads:

- The **sibling screen file** in the same stack — the shape being mirrored.
- The **navigator file** — current routes and how params flow.
- `ai/patterns/native-storage.md` when the screen holds anything at rest, `offline-sync.md` when it
  writes, `permissions.md` when it prompts, `deep-linking.md` when it is reachable by URL or push.

### Deep-link registration

Register the route in the linking config **and** the native project, even if nothing links to it
today — push taps and universal links break silently when unregistered. An **auth-gated** screen
registers behind the auth-gated-link contract in `deep-linking.md` § Defensive patterns: resolve the
intent, hold it, authenticate, then replay it. A registration that drops the pending intent at the
login boundary is the finding.

### Phase 6 — screen-scoped validation additions

`/add-feature` § Phase 6 applies. A screen also smoke-tests: open from the parent list → content →
back → state preserved; deep-link open from cold and warm
(`xcrun simctl openurl booted "<scheme>://<path>"` / `adb shell am start -W -a android.intent.action.VIEW -d "<url>"`);
and, when the screen holds unsaved state, a process-death restore via `device-harness` § 7.

### Output format

`/add-feature` § Output format, minus the multi-screen rows. Always emit: files written, tests
(unit + e2e, both platforms), i18n key count per locale, native surface touched (permissions, deep
links, push handlers), observability sign-off (`observability: none configured` when the project
ships none — explicit, never silent), and the tier with the trigger that set it.

### Related

- `/add-feature` — the canonical orchestration this overlays; use it directly for ≥2 screens.
- `@mobile-architect` — produces the Phase 2 design.
- `@offline-sync-auditor` — dispatched by the Heavy cascade when the screen adds a write path.
- `@app-store-reviewer` · `@security-auditor` — Heavy-tier gates, per `/add-feature` § Phase 4.
- `ai/patterns/native-storage.md`, `offline-sync.md`, `permissions.md`, `deep-linking.md`.
