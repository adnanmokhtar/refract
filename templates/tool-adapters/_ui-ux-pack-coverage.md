# UI-UX pack — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces the UI/UX pack's artifacts when `--include=ui-ux` is selected by `/setup-project` (or auto-included for `frontend-*` projects).

The pack provides three commands and a critical skill:
- `/design-review` — read-only audit (cite-or-halt)
- `/enhance-ui <description>` — single-area enhancement orchestrator (cleanup → 3 variants → pick → verify)
- `/ui-sweep [<phase>]` — project-wide UI/UX **specialist** (visual hierarchy, coverage metrics, cross-surface consistency, visual baseline + drift, flow-based phasing, HTML visual report)
- `design-iterate` skill — generates 3 visual variants (style-only) per page

**`--re-audit` flag on `/polish`** — discards `verified`/`done` verdicts in `ai/polish/ledger.md`; re-dispatches the per-surface audit on every row. Use when design system / API conventions / schema / platform spec changed, or you suspect drift on a "complete" polish. Combinable with scope and with `--restart`.

**`--ignore-ledger` flag on `/polish`** — backs up `ai/polish/*` to timestamped `*.bak.md`; re-discovers surface inventory (stack-appropriate: pages/modals for frontend; endpoints for backend; tables for data; screens for mobile) from source; re-runs the stack-conditional audit on every surface; re-creates the polish report. KEEPS ADR pre-check (intentional design / API / schema / platform deviations preserved). IMPLIES `--re-audit`. Use when: design system / API conventions / schema / platform spec changed materially OR you suspect previous polish was incomplete.

**Top-level simple-surface entry — `/polish`** (NOT in this pack — top-level orchestration, sibling to `/migrate` / `/optimize` / `/align`). One command, multi-day workflow, brief output, NO phases / halts / ADRs / variant menus surfaced unless audit explicitly opts in. Whole project or scoped. `/polish` is **stack-conditional** — dispatches different skills per `PROJECT_KIND`:

- `frontend-*` → reuses this pack's skills (`a11y-quick-check`, `design-iterate`, `design-token-audit`, `motion-audit`).
- `backend-*` → dispatches `api-consistency-audit` from the backend pack (envelope / error / pagination / idempotency / log / metric / trace / OpenAPI uniformity).
- `data-*` → dispatches `schema-consistency-audit` from the database pack (column naming / types / indexes / audit fields / migration patterns / soft-delete / nullability).
- `mobile-*` → dispatches `platform-conventions-audit` from the mobile pack PLUS reused frontend skills (iOS HIG / Material conformance + frontend polish).

Power users still drop down to `/enhance-ui` (explicit single-area iteration), `/ui-sweep` (HTML report + coverage metrics), or `/design-review` (read-only) when they need finer control.

**`/ui-sweep` is a specialist, not a wrapper.** It has its own 8 deep detectors, 12 UI/UX-specific verbs, quantified coverage metrics, visual baselines, flow-based phasing, and HTML report. Adapters MUST preserve all of these in translation — flattening to "just runs align with UI/UX classes" is forbidden.

## Capability mapping per tool

| Tool | `/ui-sweep` full | `design-iterate` skill | Visual baseline (Playwright) | HTML report rendering |
|---|---|---|---|---|
| Claude Code | ✓ | ✓ (native skill) | ✓ (Playwright MCP) | ✓ (browser-side) |
| OpenCode | ✓ | ✓ (native skill) | ✓ (Playwright MCP) | ✓ |
| Cursor | ✓ | ✓ (native skill) | ✓ (Playwright MCP) | ✓ |
| Copilot | ✓ | ✓ (native skill) | conditional (if MCP wired) | conditional |
| Continue | ✓ rule + commands | as prompt template | conditional | partial |
| Cline / Roo | ✓ rule + workflows | inlined in rule | conditional | partial |
| Windsurf | ✓ rule + workflows | inlined in rule | conditional | partial |
| Aider | rule-only | inlined in rule | rule documents manual procedure | NO (markdown summary instead) |
| Codex | rule-only | inlined in rule | rule documents manual procedure | NO |
| Gemini CLI | rule-only | inlined in rule | rule documents manual procedure | NO |

**Conclusion**: tools without Playwright MCP support fall back to a manual procedure documented in the rule (the rule is self-sufficient for the detection + verb logic; only the visual-baseline + HTML-report steps require the MCP).

## Pre-requisites — universal across tools

`/ui-sweep` requires these regardless of tool:
1. `_extracted-idioms.md § Tokens` — design token system per category (colors, spacing, typography, radii, shadows).
2. `_extracted-idioms.md § Wrappers` — shared component inventory.
3. `_extracted-idioms.md § Surfaces` — prototypical examples per surface type (list-page, detail-page, form, modal).
4. `_extracted-idioms.md § Breakpoints` — responsive breakpoints (defaults: 360 / 768 / 1280).
5. `_extracted-idioms.md § Voice` (optional) — tone of voice guide.
6. Playwright MCP wired (or fallback documented per-tool).

If the idioms inventory is incomplete → halt; route to `/setup-project --refine`.

## Per-tool translation expectations

### Claude Code (`.claude/`)

- `/ui-sweep` → `.claude/commands/ui-sweep.md`
- `/enhance-ui` → `.claude/commands/enhance-ui.md`
- `/design-review` → `.claude/commands/design-review.md`
- `design-iterate` skill → `.claude/skills/design-iterate/SKILL.md`
- Playwright MCP: `~/.claude/mcp/playwright/` (user installs once globally)
- HTML report renders in default browser via `open ai/ui-sweep/report-<date>.html`.

### OpenCode (`AGENTS.md` + `.opencode/`)

- Commands → `.opencode/commands/{ui-sweep,enhance-ui,design-review}.md`
- Skill → `.opencode/skills/design-iterate/SKILL.md`
- Rule (UI principles) → `AGENTS.md § UI/UX` section
- HTML report renders the same way.

### Cursor (`.cursor/`)

- Commands → `.cursor/commands/{ui-sweep,enhance-ui,design-review}.md`
- Skill → `.cursor/skills/design-iterate/SKILL.md`
- Rule → `.cursor/rules/ui-principles.mdc` (with `globs: src/**/*.{vue,tsx,jsx,svelte}`)
- Hooks: `.cursor/hooks.json` triggers `verify-with-playwright` on edits to `src/**/*.{vue,tsx}` (optional).

### Copilot (`.github/`)

- Commands → `.github/prompts/{ui-sweep,enhance-ui,design-review}.prompt.md`
- Skill → `.github/skills/design-iterate/SKILL.md`
- Rule → `.github/instructions/ui-principles.instructions.md`
- Visual baseline / HTML report: requires GitHub Actions with Playwright runner; or local fallback if user's local machine has Playwright MCP.

### Continue (`.continue/`)

- Commands → `.continue/prompts/{ui-sweep,enhance-ui,design-review}.md` (Continue treats commands as prompts)
- Skill → `.continue/prompts/design-iterate.md` (prompt-style)
- Rule → `.continue/rules/ui-principles.md`
- Visual baseline: documented as manual step (Continue has no native MCP integration).

### Cline (`.clinerules/`)

- Commands → `.clinerules/workflows/{ui-sweep,enhance-ui,design-review}.md`
- Skill content → inlined into the rule (Cline doesn't have native skills).
- Rule → `.clinerules/ui-principles.md`
- Visual baseline: rule documents manual screenshot procedure.

### Windsurf (`.windsurf/`)

- Commands → `.windsurf/workflows/{ui-sweep,enhance-ui,design-review}.md`
- Same rule-only fallback as Cline for skills + visual baseline.

### Aider (`CONVENTIONS.md`)

- Rule → appended to `CONVENTIONS.md § UI/UX`
- Commands → documented as manual procedures in the rule (Aider has no command surface).
- `design-iterate` skill content → inlined as a manual procedure ("describe the page; iterate by hand on style; capture before/after manually").
- Visual baseline: rule documents manual screenshot procedure (e.g., "use browser DevTools → Capture full-size screenshot; save to `ai/ui-sweep/baseline/<iso>/`").
- HTML report: substituted with a markdown summary of metrics and findings.

### Codex (`AGENTS.md`)

- Rule → `AGENTS.md § UI/UX` section.
- Same rule-only fallback as Aider.

### Gemini CLI (`GEMINI.md`)

- Rule → `GEMINI.md § UI/UX` section.
- Same rule-only fallback as Aider.

### Qwen Code (`QWEN.md` + `.qwen/`)

- Commands → `.qwen/commands/{ui-sweep,enhance-ui,design-review}.md` (Markdown + YAML frontmatter).
- Skill → `.qwen/skills/design-iterate/SKILL.md`.
- Rule → `QWEN.md § UI/UX` section + cross-reference in `AGENTS.md`.
- Hooks: `.qwen/settings.json` `hooks.PostToolUse` may trigger `verify-with-playwright` on edits to UI source globs (optional).
- HTML report renders via `open ai/ui-sweep/report-<date>.html` (same as Claude Code).

## Adapter responsibilities

When an adapter ships the UI-UX pack:

1. **MUST translate `/ui-sweep` faithfully as a specialist.** Preserve:
   - The 8 specialist detectors (visual hierarchy, component utilization, token coverage, cross-surface consistency, ui-state coverage, responsive matrix, design-language coherence, visual baseline + drift).
   - The 12 UI/UX-specific verbs (`consolidate-tokens`, `unify-component`, `normalize-hierarchy`, `wire-empty-state`, `wire-loading-state`, `wire-error-state`, `add-mobile-affordance`, `fix-responsive`, `normalize-surface`, `unify-iconography`, `normalize-typography`, `tighten-rhythm`).
   - Quantified coverage metrics with targets.
   - User-flow phasing (NOT class-based).
   - Separate `ai/ui-sweep/ledger.md` (separate from `ai/align/ledger.md`).
2. **MUST NOT downgrade to "thin wrapper around align".** Adapters that translate `/ui-sweep` as "just `/align-scan` with UI/UX class filter + `/align-fast`" are forbidden — that flattens the specialist work.
3. **MUST translate `design-iterate` skill** to the tool's native format if supported. For tools without skill dispatch, document the procedure in the rule body.
4. **MUST document Playwright MCP requirement** OR provide a fallback for visual-baseline / drift detection.
5. **MUST translate the workflow simply** — the user-facing workflow is just 3 commands they run in order:
   ```
   /ui-sweep --baseline-only      # once, at the start
   /ui-sweep --first-run          # once, after baseline
   /ui-sweep                      # repeatedly until done
   ```
   Adapters should preserve this 3-command simplicity in their docs.

## Rule-only tool fallback (Aider / Codex / Gemini)

For tools without command/skill dispatch, the UI-UX rule body documents the full procedure:

1. Describe the area (or run on whole project).
2. Read the project's idioms (tokens, wrappers, surfaces, breakpoints).
3. Manually run the 8 detectors:
   - Open each page in a browser, screenshot for baseline.
   - Inspect for visual hierarchy issues (primary action prominence, heading order).
   - Audit token coverage (count hardcoded values vs. token references).
   - Compare list pages structurally (do they share wrappers, props, lifecycle hooks?).
   - Check ui-state coverage per data-fetch (loading, empty, error).
   - Test at 360 / 768 / 1280 px — capture issues.
   - Audit design-language consistency (icons, typography scale, voice).
4. Apply UI/UX verbs (`consolidate-tokens`, `unify-component`, etc.) per finding.
5. Re-screenshot; compare visual baseline.
6. Output markdown report (substitute for HTML report) with metrics + findings.

The rule's "Tool-agnostic procedure" section walks through this for rule-only tools.

## Failure modes

- **Playwright MCP not wired** → tool-with-MCP-support: install MCP. Tool-without: rule documents manual screenshot procedure.
- **Idioms inventory incomplete** → all tools halt; route to `/setup-project --refine`.
- **Non-frontend stack** → halt regardless of tool.
- **Adapter flattens to thin wrapper** → review-checklist failure; reject the translation.

## See also

- `_align-pack-coverage.md` — sibling for align (structural drift). `/ui-sweep` is the visual sibling; structural concerns route to align.
- `_migration-pack-coverage.md` — sibling for V1↔V2 ports.
- `templates/packs/ui-ux/_essentials.md` — the pack's command + skill list.
- `templates/packs/ui-ux/commands/ui-sweep.md` — the canonical specialist command spec.
