---
description: Orchestrator for UI/UX enhancement. Takes a natural-language description ("the sidebar", "the dashboard header") OR explicit path. Runs the 3-step combo automatically: (1) /align-recheck for structural drift cleanup (design tokens, a11y, raw library components, missing UI states); (2) design-iterate skill for visual variants (you pick); (3) /align-recheck again to enforce conventions on the result. One command, complete UI/UX enhancement loop.
kind: command
pack: ui-ux
---

# /enhance-ui <description-or-path> [<more>...]

## The Premise (read this first)

**You describe what you want enhanced; this command runs the cleanup → iterate → verify loop.** Three steps, one command. Cleanup ensures the surface uses the design system correctly BEFORE you iterate on visuals (no point polishing on top of hardcoded colors). Iterate generates 3 style variants for you to pick. Verify catches anything the iteration accidentally drifted.

This is the orchestrator for visual / UX enhancement work. It composes:
1. **`/align-recheck`** — fixes structural drift (design-token-drift, a11y-violation, raw-library-component, missing-ui-state, motion-drift, responsive-drift).
2. **`design-iterate` skill** — generates 3 style variants (polished / bolder / minimal); user picks; skill applies.
3. **`/align-recheck`** again — re-enforces conventions on the picked variant.

Examples:
- `/enhance-ui the sidebar`
- `/enhance-ui the dashboard header`
- `/enhance-ui the login page`
- `/enhance-ui src/modules/orders/pages/OrderListPage.vue`
- `/enhance-ui the customer tabs --direction="cleaner padding"`

## When to use

- "Make the sidebar look better."
- "Polish the dashboard."
- "Tighten up the spacing on the order page."
- "The header feels off — try a few variants."
- After a feature merge that landed UI without much polish.
- Pre-launch cleanup of a specific surface.

## When NOT to use

- For new UI features (new menu, new screen) → `/add-feature`.
- For pure cleanup with no creative work → `/align-recheck` alone.
- For visual review without changes → `/design-review`.
- For non-frontend stacks (`PROJECT_KIND` not `frontend-*`) — this command halts.

## Pre-requisites

- `PROJECT_KIND` is `frontend-*` (Vue / React / Angular / Svelte / etc.).
- `_extracted-idioms.md` populated (oracle for cleanup step).
- Mechanical CI green at HEAD.
- Working tree clean.
- Playwright MCP wired (for design-iterate's screenshot step).

## Args

- `<description-or-path>` — natural-language description OR explicit path. Same resolution as `/align-recheck` (semantic understanding via codebase-profile + idioms).
- `--direction="<text>"` — pass-through to design-iterate ("cleaner", "more minimal", "bolder", "card-based"). Default: agent picks based on the description.
- `--skip-cleanup` — skip step 1; jump straight to design-iterate. Use only if you've JUST run align-recheck.
- `--skip-iterate` — only run cleanup steps (1 + 3); no creative variants. Equivalent to `/align-recheck the X --class=design-token-drift,...`.
- `--re-detect-only` — both align-recheck calls run in re-detect-only mode (no fixes). Useful for surface inspection.

## Phase 1 — Understand

### Intent gate (mandatory pre-step)

Parse the user's description for keywords that indicate a different command is the right choice:

| User description contains | Right command | Action |
|---|---|---|
| "add" / "new" / "create" / "build" / "implement" | `/add-feature` | Halt; suggest `/add-feature <description>` |
| "fix" + ("bug" / "broken" / "wrong" / "crash") | `/fix-bug` | Halt; suggest `/fix-bug <description>` |
| "audit" / "review" — read-only intent | `/design-review` | Halt; suggest read-only command |
| Pure cleanup, no creative work ("just fix tokens", "just a11y") | `/align-recheck <description> --class=<targeted>` | Halt; suggest narrower class filter |
| "enhance" / "improve" / "polish" / "cleaner" / "better look" | `/enhance-ui` (this command) | Proceed |

If ambiguous: ASK "are you enhancing existing UI, or adding something new?" Route based on answer.

If user insists on `/enhance-ui` for an add-feature task, halt; cannot proceed (this command is enhancement-only — no template/script changes).

### Standard inputs

Resolves the description to file paths via the same semantic flow as `/align-recheck` (read codebase-profile + idioms + ledger). Confirms the resolved files are UI components (`.vue` / `.tsx` / `.svelte` / etc.) — refuses to enhance a service or composable.

## Phase 2 — Organize

```
1. RESOLVE         — semantic understanding maps description → UI component file(s)
2. CLEANUP         — /align-recheck <resolved> --class=<UI/UX classes>
                     classes: design-token-drift, a11y-violation, reinvented-wrapper,
                              raw-library-component, missing-ui-state, motion-drift,
                              responsive-drift
3. ITERATE         — invoke design-iterate skill on each resolved file
                     (skill generates 3 variants, screenshots, presents)
4. PICK            — user picks A / B / C / "tune one further"
5. APPLY           — design-iterate applies the picked variant
6. RE-ENFORCE      — /align-recheck <resolved> (full universal class set)
                     catches anything iterate drifted
7. SUMMARY         — final diff stats + screenshots
```

## Phase 3 — Retrieve

- `_extracted-idioms.md` (design tokens, shared components, motion tokens).
- `ai/conventions.md` (UI conventions).
- The resolved component file(s) source.

## Phase 4 — Generate (the orchestration)

This command does NOT directly write code — it dispatches `/align-recheck` and `design-iterate`. Each downstream produces its own output; this command consolidates.

End-of-run summary:

```
/enhance-ui the sidebar — complete

Resolved:                  src/shared/components/AppSidebar.vue

Step 1 — Cleanup:          5 findings fixed
  design-token-drift:        3 (hardcoded #3b82f6 → $primary; padding 12px → $space-md ×2)
  a11y-violation:            1 (focus state missing on collapse button)
  raw-library-component:     1 (PrimeVue Button → AppButton)

Step 2 — Iterate:          3 variants generated
  Variant A (polished):      .claude/artifacts/design-iterate/2026-05-02T18-30/variant-a.png
  Variant B (bolder):        .claude/artifacts/design-iterate/2026-05-02T18-30/variant-b.png
  Variant C (minimal):       .claude/artifacts/design-iterate/2026-05-02T18-30/variant-c.png

User picked:               C (minimal)

Step 3 — Apply:            variant C applied to AppSidebar.vue (scoped <style> only)

Step 4 — Re-enforce:       0 new findings (clean)

Total impact:
  Diff:                    +18 / -34 = -16 lines
  a11y score:              92 → 96 (improved)
  Visual regression:       1 diff accepted (intentional design change)
  Bundle-size delta:       -0.2% (smaller)

Commits:                   5 cleanup commits + 1 design-iterate commit + 0 re-enforce commits
```

## Phase 5 — Update (persist changes)

- Per downstream commands: ledger updates from /align-recheck; screenshot artifacts from design-iterate.
- One log entry to `ai/_history.md`: `<iso> enhance-ui <resolved> | cleanup-fixes=<N> | variant=<A|B|C>`.

## Phase 6 — Validate

- Each step's downstream validation runs as normal (align-recheck's gate, design-iterate's snapshot review).
- Final state: working tree clean, tests pass, a11y score not below baseline, bundle-size within tolerance.

## Phase 7 — Improve

- If the picked variant introduces new design-token drift, surface "iterate produced non-on-system styling; flag for design-token sync."
- If cleanup step found > 10 findings, surface "this surface had high drift; consider quarterly UI/UX cadence."

## Hard rules

- **Frontend stacks only.** Halts on non-frontend PROJECT_KIND.
- **Cleanup before iterate.** Don't polish on top of drift. The order is fixed (cleanup → iterate → re-enforce).
- **No template / script changes.** design-iterate is style-only. If structural changes are needed (new prop, new affordance), route to `/add-feature`.
- **User picks the variant.** This command does NOT auto-pick. The skill pauses for user input.
- **Re-enforce always runs.** Even if iterate produced no diff (user picked variant A which was current). The cheap safety check.

## Failure modes

- **Resolution returns 0 matches** — halt; route to `/align-status` for known surfaces or paths.
- **Resolved file is not a UI component** (it's a service / composable) — halt; ask user for the right file.
- **Cleanup step halts** (idiom missing, etc.) — halt the whole flow; route to `/setup-project --refine`.
- **design-iterate fails** (Playwright unavailable) — halt; document the missing infra.
- **User skips the pick** — leaves the file in cleanup-only state (no creative change); legitimate flow.
- **Re-enforce surfaces drift** that iterate introduced — auto-fixes via the standard align loop; surfaces in the summary.

## Related

### Sibling commands
- `/align-recheck` — the cleanup primitive this command dispatches.
- `/design-review` — read-only audit (use BEFORE enhance-ui to see what needs cleaning).
- `/add-feature` — for new UI features (this command is enhancement only).

### Skills
- `design-iterate` — generates the 3 visual variants.
- `a11y-scan` — runs as part of cleanup verification.
- `bundle-analyze` — runs as part of re-enforce verification.

### Rules
- `.claude/rules/align-discipline.md` — the discipline the cleanup steps enforce.
