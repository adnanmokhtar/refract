---
description: Add a new screen — full chain — route + screen component + navigation wiring + state + i18n + a11y + tests. Smaller than /add-feature; deeper than hand-editing.
---

# /add-screen

Use to add a single screen to an existing module. Smaller than `/add-feature` (no new entity / business logic), deeper than editing one file (full chain incl. navigation + tests + i18n).

## The Premise (read this first, internalize, do not deviate)

**Existing screens are the truth.** The app already ships screens that work — auth-gating, navigation registration, native config (iOS Info.plist + Android manifest), locale keys, error/loading/empty shape, deep-link wiring. Each is a working oracle. A new screen is **not a green field** — it is a sibling, and its shape is **derived**, not invented.

**The agent's job is exactly this:**
1. Find the closest sibling screen in the same stack / flow / navigator.
2. Mirror its shape — folder path, file naming, component decomposition, hook order, auth wrapper, error boundary, locale-key namespace, navigation registration call site, native-permission checks, deep-link entry.
3. Diverge **only** where the new screen's data / action set genuinely requires it. Cosmetic novelty (different state-lib, different error pattern, different folder) is not allowed — it is drift.

**The agent does NOT:**
- Pick a state lib / data-fetch lib / error pattern that differs from siblings. Siblings win.
- Place the screen at a new folder path because "it feels cleaner." Sibling path wins.
- Skip native-config (iOS Info.plist usage strings, Android manifest permissions) because the simulator works without it. Production install will not.
- Skip deep-link registration because "no one uses it yet." Push notifications + universal links break silently when unregistered.
- Invent locale-key namespaces. Mirror the sibling's `<module>.<screen>.<key>` shape exactly.

**Mechanical halt — sibling-shape parity (mandatory before Phase 4 generate):**

Before writing any new file, the agent MUST name (in the Phase 2 design output) the **sibling screen file path** it is mirroring, and confirm:
- Same folder depth + naming convention.
- Same auth wrapper + navigation-options pattern.
- Same data-fetching primitive (TanStack Query / RTK Query / Zustand selector / Riverpod / SwiftUI `@StateObject` — whichever the sibling uses).
- Same error / loading / empty / content state shape.
- Same locale-key namespace shape (`<module>.<screen>.<key>`).
- Same native-config touchpoints declared (Info.plist key list, Android manifest entries, linking config registration line).

If no sibling exists in the same stack — HALT. Ask the user to point at the gold-standard screen. Do not invent shape from training data.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## When to use / NOT to use

- USE: a new screen on an existing flow (e.g., add an "Order details" screen to the orders flow).
- USE: a new tab in an existing tab navigator.
- USE: a new modal screen reachable from existing screens.
- NOT: a brand-new module / feature → use `/add-feature`.
- NOT: edit an existing screen → just edit, then `/review-changes`.

## Phase 1 — Understand (the ask)

Ask (one consolidated question if any unknown):
- Which module / flow does this screen belong to?
- What route name + path? (`OrderDetails` reachable via `orders/:id` or via `OrdersStack > OrderDetailsScreen`)
- Reachable from which other screen(s)? (Update navigation in those parents.)
- What data does it display?
- What user actions (mutations) does it support?
- Modal or push? Tab? Full-screen?
- Auth-gated?
- iOS + Android both? Tablet variant?

If the user provides a Figma link or screenshot, treat as authoritative.

## Phase 2 — Organize (decompose)

Use `mobile-architect` agent to produce the design:

```
## Screen: <name>

### Route
- Stack: <stack-name>
- Name: <RouteName>
- Path: <route-pattern> (deep-link)
- Params: { id: string, source?: 'list' | 'notification' }
- Modal/push: <push>

### Components (new)
| Name | Path | Type |
|---|---|---|
| OrderDetailsScreen | screens/orders/OrderDetailsScreen.tsx | screen container |
| OrderHeader | components/orders/OrderHeader.tsx | display |
| OrderItemsList | components/orders/OrderItemsList.tsx | display |

### Data flow
| Concern | Source | Cache |
|---|---|---|
| Order detail | GET /api/orders/:id | TanStack Query / RTK Query |
| Order items | included in detail | n/a |

### State
- Component-local: scroll position, expanded sections.
- Store: nothing new (the order list store already has the entity).

### Mutations
- Cancel order → DELETE /api/orders/:id (confirm dialog).

### Navigation wiring
- OrdersListScreen — onPress(item) → navigation.navigate('OrderDetails', { id: item.id })
- Push notification handler — opens deep-link `app://orders/<id>`

### i18n keys (new)
| Key | en |
|---|---|
| orders.detail.title | Order #{id} |
| orders.detail.cancel | Cancel order |
| orders.detail.cancel_confirm | Are you sure? This action cannot be undone. |
| orders.detail.error.not_found | Order not found |

### A11y notes
- Header back button: accessible label "Back to orders".
- Action buttons: minimum 44x44 touch target.
- Loading state: announce via accessibilityLiveRegion.
- Color-only state indicators: pair with icon or text.

### Tests
| Layer | File |
|---|---|
| unit | OrderDetailsScreen.test.tsx |
| component | OrderHeader.test.tsx |
| e2e | orderDetail.e2e.ts (Detox / Maestro) |

### Open questions
<flag for user>
```

## Phase 3 — Retrieve (read context)

Read in order:
1. `CLAUDE.md` — declared stack (RN / Flutter / iOS native / Android native), state lib.
2. `ai/conventions.md` — file naming, folder structure.
3. `ai/patterns/components.md`, `ai/patterns/navigation.md`, `ai/patterns/data-fetching.md` — applicable patterns.
4. `.claude/rules/mobile-principles.md` — project rules.
5. Sibling screen file in the same stack — mirror its shape (auth pattern, error handling, loading state).
6. Navigator file (`AppNavigator.tsx` / `RootStack.tsx`) — understand current routes + how params flow.

## Phase 4 — Generate

For each new file:
1. **Pre-flight comment** at top: read sibling screen + navigator + relevant patterns.
2. **Use the project's actual primitives** — UI library (NativeBase / Tamagui / RN Paper / SwiftUI / Compose), navigation library (React Navigation / Expo Router / Flutter Navigator 2 / SwiftUI NavigationStack / Jetpack Compose Navigation).
3. **Loading + error + empty + content states** — every data-driven screen has all 4. Skeleton / spinner / error retry / empty illustration + CTA.
4. **A11y from the start** — accessibility props on every interactive element.
5. **Locale strings** — never hardcode user-facing text.
6. **Deep-link routing** — register the route in the linking config.
7. **Navigation params typed** — RN: TypeScript-typed `RootStackParamList`. Flutter: typed routes. SwiftUI: typed values.

After generation, dispatch:
- `@mobile-architect` — design review.
- `@accessibility-auditor` — a11y check.
- `@i18n-auditor` — locale completeness.
- `@ux-reviewer` — flow + content tone.
- `@design-system-guardian` (if design system in scope).

## Phase 5 — Update

- `ai/modules.md` — append entry if a new submodule.
- `ai/patterns/<new>.md` — only if a new pattern emerged.
- `ai/decisions/<NNNN>-*.md` — if architectural choice made (e.g., screen state goes to URL vs store).
- `ai/status.md` § Recent Changes — one-line entry.

## Phase 6 — Validate

- Lint + type-check pass.
- Unit + e2e tests pass on iOS + Android (if applicable).
- Bundle-size delta acceptable.
- A11y check passes (axe-react-native / accessibility scanner).
- Locale completeness — no missing keys.
- Manual smoke — open from list → see content → navigate back → state preserved.
- Deep-link test — `xcrun simctl openurl booted "app://orders/123"` lands on the screen.

## Phase 7 — Improve

- If a recurring pattern emerged → `/learn-from-task` to promote.
- If sibling screens have inconsistencies (this one differs from the rest) → flag for `ai/dynamic/drift-log.md`.

## Output format

```
## /add-screen — <screen-name>

Status: SHIPPED | NEEDS REVIEW | BLOCKED

Files written:
  - <path>
  - <path>

Tests:
  - unit + e2e: passing
  - a11y: <score>

i18n:
  - new keys: <count> per locale

Knowledge updates:
  - ai/modules.md      ✓
  - new pattern        (if extracted)

Open follow-ups:
  - <thing flagged>
```

## Hard rules

- **Loading + error + empty states.** All four required for any data-driven screen.
- **A11y from the start.** Touch targets 44+, semantic roles, accessibility labels.
- **i18n keyed strings only.** No hardcoded UI text.
- **Deep-link registered.** Even if not used today, ensures notifications + universal links work.
- **Typed navigation params.** No `any` on navigator state.

## Failure modes

- Missing back-button handler on Android → user is stuck.
- Hardcoded portrait orientation when the rest of the app supports rotation.
- Modal that doesn't dismiss on background tap (when other modals do).
- Loading state covers entire screen instead of just the data area, blocking back navigation.
- Deep-link works in dev but not after install (linking config not registered in native project).

## Related

- `/add-feature` — multi-screen mobile feature.
- `@mobile-architect` — produces the screen design.
- `@accessibility-auditor` — runs in Phase 4.
- `@i18n-auditor` — runs in Phase 4.
- `ai/patterns/navigation.md`, `data-fetching.md`, `offline-sync.md`.
