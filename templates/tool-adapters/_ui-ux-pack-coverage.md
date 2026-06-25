# UI-UX pack — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces the UI/UX pack's artifacts when `--include=ui-ux` is selected by `/setup-project` (or auto-included for `frontend-*` projects).

The pack provides seven commands and two critical skills:
- `/design-review` — read-only audit (cite-or-halt)
- `/enhance-ui <description>` — single-area enhancement orchestrator (cleanup → 3 variants → pick → verify)
- **`/art-direct <scope>` (v1.5+)** — the pack's UPSTREAM creative command: it DECIDES and INVENTS the visual language (concept, original layouts/shapes/type/colour/motion, signature moments) from the product's GOALS, instead of enforcing or refining the existing one. Driven by the **`creative-director`** agent. Two modes (`--evolve` default / `--reimagine` greenfield). Diagnoses the current design with a cited point-of-view (15-label redline vocabulary), generates **three mechanically-distinct directions** (logo-swap + color-ramp-swap + ≥2-structural-axes checks), renders candidates (`design-iterate`) + scores them on a 9-lens Direction rubric, then **ONE approval gate**. Originality is the ceiling; the usability floor is delegated to `ux-reviewer` and never re-audited (no 17th axis). **Designs THEN builds** — on approval (or immediately under `--yes`) it **auto-runs** `design-system-architect` (codify tokens) → `/redesign` (rebuild pages within the now-existing language) → `/polish` (finish), bounded by `<scope>`; `--plan` stops at the design (no build); `git` is the rollback. Frontend / mobile only. Sibling/upstream of `/redesign` (which builds WITHIN a language; `/art-direct` decides it, then runs it).
- **`/redesign <description-or-path>` (v1.3+)** — from-scratch page/flow rework (rethinks layout + IA + UX, NOT a restyle) rebuilt inside the existing design system, with a **mandatory approval gate before any code**. Method-driven: an **11-lens Design-principles rubric** the run DIAGNOSES the current page against, DESIGNS the proposal to satisfy, self-critiques before the gate, and SCORES the rendered result against (must beat the diagnosis). Composes `design-system-architect` (extraction + conformance) + `ux-reviewer` (proposal) + `ui-design-sweep` closure verbs + optional post-approval `design-iterate`; renders the rebuilt surface (Playwright) to earn its RTL / a11y / responsive checkmarks. Sibling to `/enhance-ui` (which preserves structure). Frontend / mobile only.
- `/ui-sweep [<phase>]` — project-wide UI/UX **specialist** (visual hierarchy, coverage metrics, cross-surface consistency, visual baseline + drift, flow-based phasing, HTML visual report)
- **`/ui-crawl [<scope>]` (v1.2+)** — Playwright-driven cross-route crawler (login once, visit every route, screenshots × 3 breakpoints + dark + RTL, axe-core a11y per route, walks tabs / dialogs / dropdowns, captures console + network errors, writes ranked findings JSON + MD). Detect-only. Sibling to `/ui-sweep` — faster, broader, machine-readable output; `/ui-sweep` is deeper with HTML report.
- **`/ui-crawl-fix [<class>] (v1.2+)`** — auto-fixer that consumes the `/ui-crawl` findings JSON and patches at the **wrapper level** (one fix → hundreds of cascading call sites). Closes color-contrast (token swap), button-name (aria-label injection), label (for/id wiring), unsanitized-html (`v-html` / `dangerouslySetInnerHTML`), raw-library-component, hardcoded-translations. Skips bugs needing human judgment. Re-runs `/ui-crawl` in verify mode for gap-count parity. Inherits closure-verb discipline from `align-discipline.md`.
- **`ui-design-sweep` skill (v1.1+)** — closed 19-verb closure vocabulary (sibling to `refactoring-sweep` / `api-consistency-audit` / `schema-consistency-audit`); per-verb fingerprint + procedure + verify + WCAG / iOS HIG / Material citation. The frontend half of `/polish` and the verb-spec `/ui-sweep` + `/enhance-ui` dispatch into. Cited axes live in `ui-principles.md § Axis catalog`.
- `design-iterate` skill — generates 3 visual variants (style-only) per page

**`--re-audit` flag on `/polish`** — discards `verified`/`done` verdicts in `ai/polish/ledger.md`; re-dispatches the per-surface audit on every row. Use when design system / API conventions / schema / platform spec changed, or you suspect drift on a "complete" polish. Combinable with scope and with `--restart`.

**`--ignore-ledger` flag on `/polish`** — backs up `ai/polish/*` to timestamped `*.bak.md`; re-discovers surface inventory (stack-appropriate: pages/modals for frontend; endpoints for backend; tables for data; screens for mobile) from source; re-runs the stack-conditional audit on every surface; re-creates the polish report. KEEPS ADR pre-check (intentional design / API / schema / platform deviations preserved). IMPLIES `--re-audit`. Use when: design system / API conventions / schema / platform spec changed materially OR you suspect previous polish was incomplete.

**Top-level simple-surface entry — `/polish`** (NOT in this pack — top-level orchestration, sibling to `/migrate` / `/optimize` / `/align`). One command, multi-day workflow, brief output, NO phases / halts / ADRs / variant menus surfaced unless audit explicitly opts in. Whole project or scoped. `/polish` is **stack-conditional** — dispatches different skills per `PROJECT_KIND`:

- `frontend-*` → dispatches **`ui-design-sweep`** (closed 19-verb closure vocabulary — the spec, sibling to backend's `api-consistency-audit`); fed by detector skills `a11y-quick-check`, `design-token-audit`, `motion-audit`, with `design-iterate` as the visual-variant generator (NOT a closure verb). Validator `validate-polish-artifacts.sh § check_frontend_verb_vocabulary` rejects any `closure_verb:` outside the 19-verb set.
- `backend-*` → dispatches `api-consistency-audit` from the backend pack (envelope / error / pagination / idempotency / log / metric / trace / OpenAPI uniformity).
- `data-*` → dispatches `schema-consistency-audit` from the database pack (column naming / types / indexes / audit fields / migration patterns / soft-delete / nullability).
- `mobile-*` → dispatches `platform-conventions-audit` from the mobile pack PLUS reused frontend skills (iOS HIG / Material conformance + frontend polish).

Power users still drop down to `/enhance-ui` (explicit single-area iteration), `/redesign` (from-scratch page rework with approval gate), `/ui-sweep` (HTML report + coverage metrics), or `/design-review` (read-only) when they need finer control.

**`/ui-sweep` is a specialist, not a wrapper.** It has its own 8 deep detectors, the 19-verb closure vocabulary from `ui-design-sweep`, quantified coverage metrics, visual baselines, flow-based phasing, and HTML report. Adapters MUST preserve all of these in translation — flattening to "just runs align with UI/UX classes" is forbidden.

## Capability mapping per tool

| Tool | `/ui-sweep` full | `/ui-crawl` + `/ui-crawl-fix` | `/redesign` (gate + rubric + render) | `ui-design-sweep` skill | `design-iterate` skill | Visual baseline (Playwright) | HTML report rendering |
|---|---|---|---|---|---|---|---|
| Claude Code | ✓ | ✓ (Playwright project at `tests/crawl/`) | ✓ (native command; gate pauses for approval) | ✓ (native skill) | ✓ (native skill) | ✓ (Playwright MCP) | ✓ (browser-side) |
| OpenCode | ✓ | ✓ (same Playwright project; commands at `.opencode/commands/`) | ✓ (`agent: build`; gate = explicit user-approval step) | ✓ (native skill) | ✓ (native skill) | ✓ (Playwright MCP) | ✓ |
| Cursor | ✓ | ✓ (commands at `.cursor/commands/`; runs against same Playwright project) | ✓ (Skill `redesign`; gate pauses for approval) | ✓ (native skill) | ✓ (native skill) | ✓ (Playwright MCP) | ✓ |
| Copilot | ✓ | ✓ prompt + Playwright runner via Actions | ✓ prompt; gate = approval checkpoint in prompt | ✓ (native skill) | ✓ (native skill) | conditional (if MCP wired) | conditional |
| Qwen | ✓ | ✓ command translation; Playwright project shared | ✓ (command; gate pauses for approval) | ✓ (native skill) | ✓ (native skill) | conditional | partial |
| Kimi | ✓ | ✓ skill wrapper; Playwright project shared | ✓ (skill wrapper; gate pauses for approval) | ✓ (native skill) | ✓ (native skill) | conditional | partial |
| Continue | ✓ rule + commands | as prompt template; relies on Playwright in repo | as prompt template; gate = approval checkpoint | as prompt template | as prompt template | conditional | partial |
| Cline / Roo | ✓ rule + workflows | inlined workflow; Playwright in repo | inlined workflow; gate = explicit `ask` step before edits | inlined in rule | inlined in rule | conditional | partial |
| Windsurf | ✓ rule + workflows | inlined workflow; Playwright in repo | inlined workflow; gate = approval step before edits | inlined in rule | inlined in rule | conditional | partial |
| Aider | rule-only | rule documents manual `pnpm crawl` invocation; no Playwright orchestration | rule-only (EXECUTE-NOW preamble); gate = "STOP, present proposal, await approval" | inlined in rule (closed-verb spec self-sufficient) | inlined in rule | rule documents manual procedure | NO (markdown summary instead) |
| Codex | rule-only | rule documents manual invocation | rule-only; gate = explicit approval step in the procedure | inlined in rule (closed-verb spec self-sufficient) | inlined in rule | rule documents manual procedure | NO |
| Gemini CLI | TOML command | rule documents manual invocation | `.gemini/commands/redesign.toml`; gate = approval step in `prompt` | inlined in rule (closed-verb spec self-sufficient) | inlined in rule | rule documents manual procedure | NO |

**`/art-direct` (v1.5+) shares the `/redesign` column's per-tool profile exactly** — it is not a separate capability axis. Its **approval gate** translates the same way `/redesign`'s does: a native pause on Claude Code / Cursor / OpenCode, and an explicit "STOP — present the Art-Direction Brief, await approval before building" step on rule-only tools (Aider / Codex / Gemini). Its optional **candidate renders** use the same `design-iterate` + Visual-baseline (Playwright) capability shown in the table — marked `SKIPPED (no harness)` wherever the MCP is absent, never faked. Its driver **agent `creative-director`** translates via the generic agent mechanism (`apply-adapter-sync.sh` writes one native file per `.claude/agents/<name>.md`): native on the agent-capable tools (Claude Code / OpenCode / Copilot / Qwen, and Cursor's `agent-<name>` command form), and rule-inlined into the UI/UX rule body on the agent-less tools (Aider / Cline / Windsurf / Gemini / Codex) — the same surface the pack's other agents (`design-system-architect`, `ux-reviewer`) already use. Because the default `/art-direct` run **builds** (it auto-runs `/redesign` etc. after the gate), the tool must honour the **one approval gate before the build chain runs** — `--yes` skips that gate, `--plan` stops at the design. The build itself reuses the same per-tool surfaces as `/redesign` + `/polish`, so no new translation primitive is needed; the tool just needs a clean working tree and `git` as the rollback.

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
- `/ui-crawl` → `.claude/commands/ui-crawl.md`
- `/ui-crawl-fix` → `.claude/commands/ui-crawl-fix.md`
- `/enhance-ui` → `.claude/commands/enhance-ui.md`
- `/redesign` → `.claude/commands/redesign.md`
- `/art-direct` → `.claude/commands/art-direct.md` (driver agent `creative-director` → `.claude/agents/creative-director.md`)
- `/design-review` → `.claude/commands/design-review.md`
- `design-iterate` skill → `.claude/skills/design-iterate/SKILL.md`
- Playwright MCP: `~/.claude/mcp/playwright/` (user installs once globally)
- Playwright crawler project: `tests/crawl/` (auth.setup.ts + ui-crawl.spec.ts + aggregate.ts + lib/)
- HTML report renders in default browser via `open ai/ui-sweep/report-<date>.html`; Playwright crawler report at `tests/crawl/.report/index.html`.

### OpenCode (`AGENTS.md` + `.opencode/`)

- Commands → `.opencode/commands/{ui-sweep,ui-crawl,ui-crawl-fix,enhance-ui,redesign,art-direct,design-review}.md`
- Skill → `.opencode/skills/design-iterate/SKILL.md`
- Rule (UI principles) → `AGENTS.md § UI/UX` section
- HTML report renders the same way.

### Cursor (`.cursor/`)

- Commands → `.cursor/commands/{ui-sweep,ui-crawl,ui-crawl-fix,enhance-ui,redesign,art-direct,design-review}.md`
- Skill → `.cursor/skills/design-iterate/SKILL.md`
- Rule → `.cursor/rules/ui-principles.mdc` (with `globs: src/**/*.{vue,tsx,jsx,svelte}`)
- Hooks: `.cursor/hooks.json` triggers `verify-with-playwright` on edits to `src/**/*.{vue,tsx}` (optional).

### Copilot (`.github/`)

- Commands → `.github/prompts/{ui-sweep,ui-crawl,ui-crawl-fix,enhance-ui,redesign,art-direct,design-review}.prompt.md`
- Skill → `.github/skills/design-iterate/SKILL.md`
- Rule → `.github/instructions/ui-principles.instructions.md`
- Visual baseline / HTML report: requires GitHub Actions with Playwright runner; or local fallback if user's local machine has Playwright MCP.

### Continue (`.continue/`)

- Commands → `.continue/prompts/{ui-sweep,ui-crawl,ui-crawl-fix,enhance-ui,redesign,art-direct,design-review}.md` (Continue treats commands as prompts)
- Skill → `.continue/prompts/design-iterate.md` (prompt-style)
- Rule → `.continue/rules/ui-principles.md`
- Visual baseline: documented as manual step (Continue has no native MCP integration).

### Cline (`.clinerules/`)

- Commands → `.clinerules/workflows/{ui-sweep,ui-crawl,ui-crawl-fix,enhance-ui,redesign,art-direct,design-review}.md`
- Skill content → inlined into the rule (Cline doesn't have native skills).
- Rule → `.clinerules/ui-principles.md`
- Visual baseline: rule documents manual screenshot procedure.

### Windsurf (`.windsurf/`)

- Commands → `.windsurf/workflows/{ui-sweep,ui-crawl,ui-crawl-fix,enhance-ui,redesign,art-direct,design-review}.md`
- Same rule-only fallback as Cline for skills + visual baseline.

### Aider (`CONVENTIONS.md`)

- Rule → appended to `CONVENTIONS.md § UI/UX`
- Commands → documented as manual procedures in the rule (Aider has no command surface). Each opens with an **EXECUTE-NOW** second-person preamble (Aider loads prose as reference otherwise).
- `/redesign` → manual procedure with the **approval gate made explicit**: "diagnose the page against the 11-lens rubric → design → self-critique → present the structured proposal → **STOP and await the user's approval before editing any file** → build → render/verify → scorecard." The gate is the load-bearing step; a rule-only tool MUST halt there, not auto-build.
- `design-iterate` skill content → inlined as a manual procedure ("describe the page; iterate by hand on style; capture before/after manually").
- Visual baseline: rule documents manual screenshot procedure (e.g., "use browser DevTools → Capture full-size screenshot; save to `ai/ui-sweep/baseline/<iso>/`").
- HTML report: substituted with a markdown summary of metrics and findings.

### Codex (`AGENTS.md`)

- Rule → `AGENTS.md § UI/UX` section.
- Same rule-only fallback as Aider — including `/redesign`'s explicit approval-gate halt before any edit.

### Gemini CLI (`GEMINI.md` + `.gemini/`)

- Rule → `GEMINI.md § UI/UX` section.
- Commands → `.gemini/commands/{ui-sweep,ui-crawl,ui-crawl-fix,enhance-ui,redesign,art-direct,design-review}.toml` (Gemini custom commands are **TOML-only**; the workflow body goes in `prompt = """..."""`).
- `/redesign`'s `prompt` MUST keep the **approval gate** as an explicit checkpoint ("present the structured proposal, then STOP and await approval before editing") and carry the 11-lens rubric + diagnose / self-critique / scorecard method — not a flattened "restyle the page" prompt.
- Visual baseline / HTML report: rule documents the manual procedure (no Playwright MCP).

### Qwen Code (`QWEN.md` + `.qwen/`)

- Commands → `.qwen/commands/{ui-sweep,ui-crawl,ui-crawl-fix,enhance-ui,redesign,art-direct,design-review}.md` (Markdown + YAML frontmatter).
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
6. **MUST translate `/ui-crawl` + `/ui-crawl-fix` as a paired loop.** They are NOT thin wrappers around `/ui-sweep` — `/ui-crawl` is the QA-style crawler with its own scoring rubric (see `severity_scoring` section), Playwright project layout (`tests/crawl/`), and machine-readable findings format (`ai/audits/ui-crawl-findings.json`). `/ui-crawl-fix` is the auto-fix loop that consumes those findings and patches at the wrapper level using `align-discipline.md`'s closure verbs. Adapters MUST preserve:
   - The paired DETECT (`/ui-crawl`) → FIX (`/ui-crawl-fix`) → VERIFY (`/ui-crawl --filter=<modules>`) loop.
   - The auto-fixable safe-list (8 classes) AND the human-only triage list (broken triggers, layout overflow, page-load failures, heading-hierarchy skips, 5xx, aria-required structural mismatches, raw-color leaks).
   - The wrapper-level fix discipline (one fix → hundreds of cascading call sites; never per-call-site).
   - The Playwright + axe-core dependency declaration.
   - Auth-setup-once + reuse-storageState pattern.
   Flattening to "just `/ui-sweep` with `--auto-fix`" is forbidden.
7. **MUST translate `/redesign` with its gate and method intact.** `/redesign` is a from-scratch specialist, NOT a restyle and NOT `/enhance-ui`. Adapters MUST preserve:
   - The **mandatory approval gate** — no file is edited until the user approves the proposal. On tools with a native pause (Claude Code, Cursor, OpenCode) this is a real halt; on rule-only tools (Aider / Codex / Gemini) it is an explicit "STOP and await approval" step in the procedure. An adapter that auto-builds without the gate is a failed translation.
   - The **11-lens Design-principles rubric** and the **diagnose → design → self-critique → structured proposal → score** method. The Phase-6 **scorecard must beat the Phase-4 diagnosis**; "looks nicer" is not a passing bar.
   - The specialist composition (`design-system-architect` + `ux-reviewer` + `ui-design-sweep` closure verbs + optional `design-iterate`), or the rule-inlined equivalent on tools without agent/skill dispatch.
   - **Rendered, not asserted** verification — print `SKIPPED` rather than faking `RTL ✓ / a11y ✓` when no Playwright/visual harness is wired.
   Flattening `/redesign` to "`/enhance-ui` without the gate" or "a restyle pass" is forbidden.
8. **MUST translate `/art-direct` with its gate, method, and DESIGN→GATE→BUILD flow intact.** `/art-direct` is the UPSTREAM creative command — the only one that DECIDES and INVENTS the visual language, then *runs the build* to ship it; it is NOT `/redesign` (which builds within a given language) and NOT a restyle. Adapters MUST preserve:
   - The **one approval gate** — by default no *build* runs until the user approves the direction. On tools with a native pause (Claude Code, Cursor, OpenCode) this is a real halt; on rule-only tools (Aider / Codex / Gemini) it is an explicit "STOP, present the Art-Direction Brief, await approval before building" step. `--yes` skips this single gate (design → build); `--plan` stops at the design (no build). An adapter that builds without the gate (and without `--yes`) is a failed translation — and so is one that *never* builds.
   - The **DESIGN→GATE→BUILD flow** — after approval (or `--yes`), `/art-direct` **auto-runs** `design-system-architect` → `/redesign` → `/polish`, in that order, to produce real commits bounded by `<scope>`. An adapter that collapses it to "just a brief" (drops the build) or to "just rebuild the pages" (drops the design) erases the command. `git` is the rollback; the build reuses the same per-tool surfaces as `/redesign` + `/polish`.
   - The **two modes** (`--evolve` default / `--reimagine`) and the goals/personas oracles (`ai/project-goals.md` + `ai/users-and-personas.md`, cite-or-halt; `reimagine` HALTs if unreadable).
   - The **mechanical creative discipline** — the one-sentence concept (must fail the logo-swap test), the three-direction divergence check (color-ramp-swap + ≥2 structural axes), the Encodability Table (every signature move buildable), and **computed-AA / rendered-not-asserted** (mark `SKIPPED` rather than faking a render when no Playwright/visual harness is wired).
   - The **delegated usability floor** — `/art-direct` does NOT re-audit the 16-axis catalog (`ui-principles.md` § Axis catalog); floor findings route to `ux-reviewer`. The `creative-director` agent (the driver) translates to the tool's agent surface, or is inlined into the rule for tools without agent dispatch.
   Flattening `/art-direct` to "`/redesign` with a brief" or "a moodboard generator" is forbidden.

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
- `templates/packs/ui-ux/commands/art-direct.md` — the upstream creative-direction command spec (decide + invent the visual language; gate + handoff; evolve / reimagine modes) (v1.5+).
- `templates/packs/ui-ux/agents/creative-director.md` — the creative high-ground agent that drives `/art-direct` (concept / Direction rubric / diagnosis + invention vocabularies) (v1.5+).
- `templates/packs/ui-ux/commands/redesign.md` — the from-scratch redesign command spec (gate + 11-lens rubric + diagnose/scorecard method) (v1.3+).
- `templates/packs/ui-ux/commands/ui-crawl.md` — the cross-route Playwright crawler spec (v1.2+).
- `templates/packs/ui-ux/commands/ui-crawl-fix.md` — the wrapper-level auto-fixer spec (v1.2+).
- `templates/packs/align/rules/align-discipline.md` — closure-verb vocabulary `/ui-crawl-fix` operates on.
