---
name: design-token-audit
description: Scan UI code for hardcoded color / spacing / typography / radius / shadow values that should come from design tokens, reporting drift and proposing token replacements. Run during PR review on changes touching components/views/screens or theme files, before a design-system version bump, and after a designer hands off a new screen. One dimension of `@design-system-guardian`; motion tokens belong to `motion-audit`.
kind: skill
pack: ui-ux
---

# Skill: design-token-audit

A grep-driven audit. Hardcoded design values are how design systems silently die — one `#3b82f6` here, one `padding: 13px` there, three different button styles within a year.

## Premise

Existing tokens are the truth. Mirror; never invent. Every "hardcoded value → token" proposal must name an existing token from the project's resolved theme (Tailwind config, `tokens.css`, `theme.ts`, Style Dictionary output) — not a token you wished existed. If no token matches, the finding is "designer decision required: use closest existing token OR add new token via the design-system process". Inventing `text-accent-orange` because it would have been nice is the failure mode this skill exists to prevent.

## Halt conditions

- Halt on any proposed replacement that names a token not present in the project's token catalog.
- Halt on `<path:line>` citations that don't resolve or whose cited line doesn't contain the flagged value.
- Halt on auto-fix suggestions ("18 hardcoded colors → exact token match") without showing the resolved token + the source citation per row.
- Halt on listing a **color** swap as "auto-fixable" before its contrast at the rendered role is confirmed ≥ AA — a ΔE-nearest swap can silently drop below AA (see the note under Failure modes). Any category-boundary or high-ΔE swap is "manual review required", not auto-fixable; delegate the contrast measure to `a11y-quick-check`'s lift-contrast.

## When to use

- During PR review on any change touching `components/`, `views/`, `pages/`, `screens/`, theme files.
- Periodic audit (quarterly) to catch accumulated drift.
- Before a design-system version bump (find what would break).
- After a designer hands off a new screen — verify the implementation respects tokens.

## Procedure

### 1. Identify the project's token mechanism

| Mechanism | Detection signal |
|---|---|
| CSS custom properties (`:root { --color-primary: ... }`) | `tokens.css` / `theme.css` / `design-tokens.css` |
| Tailwind theme | `tailwind.config.{js,ts}` with extended `colors` / `spacing` / etc. |
| CSS-in-JS theme | `theme.{ts,js}` with named color / spacing keys |
| Design tokens package | `@org/tokens` or `design-tokens.json` (Style Dictionary) |
| Native (RN/Flutter) | `theme/tokens.ts` / `MaterialTheme`, etc. |

If multiple mechanisms in use → drift hazard. Pick ONE; flag the rest.

### 2. Grep for hardcoded values

| Pattern | Regex | Should-be |
|---|---|---|
| Hex colors | `#[0-9a-fA-F]{3,8}\b` | `var(--color-X)` / `text-primary` / `theme.colors.primary` |
| RGB / RGBA | `rgba?\([^)]+\)` | semantic token |
| HSL / HSLA | `hsla?\([^)]+\)` | semantic token |
| Inline color | `style={{[^}]*color:` (TSX/JSX) | className with token |
| Pixel margins / padding | `(margin\|padding)[^:]*:\s*\d+px` | `space-X` / `p-N` / token |
| Font size | `font-size:\s*\d+(px\|rem)` | `text-X` / `theme.fontSizes.X` |
| Font weight | `font-weight:\s*\d{3}` | `font-bold` / `theme.fontWeights.X` |
| Line height | `line-height:\s*\d` | `leading-X` |
| Border radius | `border-radius:\s*\d+px` | `rounded-X` / `theme.radii.X` |
| Box shadow | `box-shadow:` with values | `shadow-X` / `theme.shadows.X` |
| Z-index | `z-index:\s*\d+` | `z-X` token |
| Transition | `transition:\s*\d+ms` | `duration-X` / `theme.duration.X` |

Exclude:
- 3rd-party deps (`node_modules/`).
- Generated files (`dist/`, `.next/`, etc.).
- Token definition files themselves.

Tools:
- `rg` (ripgrep) — fast, multi-pattern.
- `eslint-plugin-design-tokens` (if configured).
- `stylelint` rules `declaration-property-value-allowed-list`.

### 3. Categorize findings

| Severity | Examples |
|---|---|
| BLOCKER | `style={{ color: '#000' }}` in feature code; `text-blue-500` when system has `text-primary` |
| HIGH | Inline pixel margin in a primitive component; hardcoded box-shadow |
| MEDIUM | One-off `padding: 13px` (off-scale by 1px) |
| LOW | Comment-block hex codes (legacy; not actually rendered) |
| OK | Token name used in a literal — `var(--color-primary)` |

### 4. Propose replacements

For each hardcoded value, identify the closest token:
- Color: nearest token by ΔE distance (perceptual color difference).
- Spacing: nearest scale value (4px / 8px scale).
- Font size: nearest type scale.
- Radius: nearest from radii table.

If no token exists for the value, the design system is missing it — propose adding to the token catalog (architect approval needed).

## Output format

```
## Design token audit — <YYYY-MM-DD>

### Token mechanism detected
- Tailwind config (semantic colors: primary, surface, text-muted, ...)
- 12 spacing tokens (4-px scale, gap-1 through gap-24)

### Findings

**BLOCKER (3):**
- `src/views/Cart.vue:42` — `style="color: #ef4444"` → use `text-danger` token (matches exactly).
- `src/components/CustomModal.vue:88` — hardcoded `box-shadow: 0 4px 6px rgba(0,0,0,0.1)` → use `shadow-md`.
- `src/views/Profile.vue:201` — `padding: 13px` → use `p-3` (12px, closest scale; designer confirmed).

**HIGH (8):**
- `src/components/Button.vue:18` — inline `margin-top: 24px` → use `mt-6` (24px).
- (7 more...)

**MEDIUM (12):**
- (off-scale spacing in non-critical files)

**Suggested new tokens:**
- 3 places use the same orange-amber color (#f59e0b) in feature code. Either standardize on existing `warning` token (slight color shift) or add `accent-orange` token to the system.

### Auto-fixable (with confidence)
Each auto-fixable row carries its `<path:line>` + resolved token — the bare aggregate alone is the exact shape the Halt conditions ban, so itemize, then total:
- `src/views/Cart.vue:42` — `#ef4444` → `text-danger` (exact) · contrast re-checked ≥ AA ✓
- `src/components/Toolbar.vue:88` — `#3b82f6` → `text-primary` (exact) · contrast ✓
- …16 more colors, each cited + contrast-checked → **18 colors, exact token match**, codemod-safe.
- `src/components/Button.vue:18` — `margin-top: 24px` → `mt-6` (exact) · …6 more → **7 spacing values**, codemod-safe.

### Manual review required
- 3 hardcoded colors with no exact match — designer should pick "use closest token" vs "add new token."
- 12 inline `style={{}}` blocks where dynamic values legitimately differ.

### Token coverage trend
<if previous audit exists>
- Hardcoded colors: 32 (last audit) → 21 (today) ↓
- Spacing drift: 18 → 12 ↓
- Direction: improving
```

## Inputs

- Token mechanism (auto-detect or specify).
- Scope (whole repo / specific feature / changed files only).

## Outputs

- `ai/audits/design-tokens-<date>.md`.

## Failure modes

- Reported `style="color: red"` as a violation when it's intentional in a `:hover` for a button reset (rare but possible).
- Missed token-resolved-via-CSS-var when the var name isn't exactly `--color-X`.
- Reported a violation in a 3rd-party copy-pasted snippet that hasn't been ported (still a violation, but flag separately).
- Suggested a token swap that visually looks right but actually violates contrast minimums (always re-verify a11y after token changes).

## Related

- `@design-system-guardian` — full audit + governance; this skill is one dimension of it.
- `motion-audit.md` — motion-token version.
- `a11y-quick-check.md` — verifies token swaps don't break contrast (the ≥ AA gate above delegates here).
- `ui-design-sweep.md` — consumes these findings as the `consolidate-tokens` (token exists) / `extract-token` (no token yet) closure verbs.
- `/ui-sweep` · `/enhance-ui` — apply the token fixes within the system; `/align` — mechanically enforce a token once it exists.
