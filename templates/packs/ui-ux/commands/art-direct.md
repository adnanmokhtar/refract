---
description: One command to DESIGN and BUILD a product / surface / flow's visual direction. Invents three genuinely distinct directions (concept, original visual language, signature moments) from the product's goals — NOT enforced from the existing system — renders + scores them, then after ONE approval (or immediately with `--yes`) automatically BUILDS the chosen direction to finished, committed screens by running design-system-architect (codify) → /redesign (rebuild pages) → /polish (finish), bounded by <scope>. Two modes: evolve (default — push the existing language further) / reimagine (greenfield from goals). `--plan` stops at the design. The creative high-ground above /redesign (builds within a language) and design-system-architect (codifies one). Frontend / mobile only.
kind: command
pack: ui-ux
---

# /art-direct <scope> [<more>...]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/art-direct <scope> --plan` runs the diagnose → diverge → score pass and writes the **Art-Direction Brief** (with its renders + scorecard) to `.claude/plans/`, exiting at the design — it stops **before any build**. Execute it later with `/execute-plan <file>` (or hand it to any tool). `--plan` is the **design-only** mode; the default run designs AND builds.

## The Premise (read this first, internalize, do not deviate)

**You point at a product (or a surface); this command decides what it should look and feel like, invents the visual language to get there, and then builds it — like a creative director who also ships.** Every other UI command operates *within* a visual language someone already chose: `/align` enforces it, `/polish` and `/enhance-ui` finish inside it, `/redesign` rebuilds a page inside it (and is explicitly forbidden to invent a new one — `redesign.md:64`), `design-system-architect` codifies a decided one into tokens. `/art-direct` is the one upstream of all of them: it **chooses and invents the language**, then **drives the chain that codifies, builds, and finishes it**.

The design half is driven by the **`creative-director`** agent and lands as a single gated **Art-Direction Brief** — a cited critique (redlines) of the current design, three genuinely distinct directions, a scorecard, a recommended direction with its honest sacrifice, and an Encodability Table. The agent **decides and directs; it writes no code itself.** The *command* then takes the approved direction the rest of the way: it **automatically runs `design-system-architect` → `/redesign` → `/polish`** to produce finished, committed screens, bounded by `<scope>`.

There is **one approval checkpoint** — you approve the *direction* before anything is rewritten. `--yes` skips that gate (design → build, no stop); `--plan` stops permanently at the design (no build). After approval the build runs the chain to committed screens. It does **not** re-prompt to approve each page — `/redesign`'s per-page proposal gate is *relaxed* under the build (the one direction approval stands in for it, and each surface lands as a reviewable commit, so `git` is the control). The one interaction it cannot skip is a **feature-parity call**: when a surface has no obvious home for an existing feature, `/redesign` surfaces it as **keep / move / drop** and never drops it silently (`redesign.md:181`). The default run pauses for that call; `--yes` defaults it to **keep** and lists each one in the output.

The two hard anchors: **a concept you cannot state in one sentence is decoration** (so the brief always leads with a concept that must *fail* the logo-swap test to count), and **originality is the ceiling but usability is the floor** (so every direction clears WCAG-AA, 320px, RTL, reduced-motion, and a perf budget — computed, not asserted — before it can be recommended or built). A direction that is bold but unusable, or original but un-buildable, is a failed run.

### `/art-direct` vs `/redesign` vs `design-system-architect` vs `/enhance-ui`·`/polish` vs `/align`

| Decision plane | `/art-direct` (creative-director) | `/redesign` | `design-system-architect` | `/enhance-ui` · `/polish` | `/align` |
|---|---|---|---|---|---|
| **Who DECIDES the visual language** | ✅ **the only one — invents it from product goals** | ❌ forbidden to invent one (`redesign.md:64`) | ❌ codifies a given one | ❌ iterates within it | ❌ enforces it |
| Visual language / concept / mood | **CREATES** (concept, world, refusals, moments) | speaks the existing one | turns a decided one into tokens | tightens within it | enforces tokens/rules |
| Layout / IA | names the **archetype**, then runs `/redesign` | **reworks ONE page within the language** | n/a | preserved | preserved |
| Tokens / primitives | **decides**, then runs `design-system-architect` to codify | consumes | **codifies** (primitive→semantic→component, waves, governance) | maps to existing | enforces existing |
| **Writes code?** | ✅ **yes — runs the build chain** (architect → /redesign → /polish) | yes (rebuilds the page) | yes (the token system) | yes (finish) | yes (enforce) |
| Approval gate | ✅ **one — the direction** (`--yes` skips it; `--plan` stops at it) | yes — proposal per page | no | no | no |
| Output | a built, redesigned set of surfaces + the brief | a rebuilt page | a token/primitive system | finished surfaces | closed findings |
| Altitude | **UPSTREAM of all of them — then drives them** | downstream of `/art-direct` | downstream (codifies the decision) | downstream | downstream |

**Stack scope:** frontend / mobile only (`primary_frontend_framework_detected`). On a backend/data-only repo, **HALT** — there is no UI here to art-direct; point the user at the frontend repo.

## When to use
- The product's look is generic, dated, or "fine but forgettable" and needs a point of view — then needs building.
- A new product (post-`/scaffold-project`) needs a real visual identity, designed from its goals and shipped onto its pages.
- A redesign effort keeps producing restyles because no one decided the *direction* to redesign toward.
- Leadership asks "what should this feel like?" — and then wants it real, not a deck.

## When NOT to use
- Enforce a hardcoded value → an existing token, or fix a11y drift from an existing rule → `/align`.
- Add finish (states, rhythm, hierarchy, a few variants) within the current language → `/enhance-ui` or `/polish`.
- Rebuild ONE page's layout/UX *inside the existing visual language* → `/redesign` directly.
- Turn an already-decided direction into tokens/primitives → the `design-system-architect` agent directly.
- A brand-new page that doesn't exist yet → `/add-feature`.
- You only want the *direction* (a brief), not a build → run with `--plan`.

## Pre-requisites
- `PROJECT_KIND` is `frontend-*` / `mobile-*` (gated on `primary_frontend_framework_detected`). Backend/data-only → HALT.
- **Working tree clean** at HEAD — the build lands as reviewable commits (one per surface) and `git` is the rollback. (Under `--plan` this is relaxed: design-only writes no production code.)
- **Goals + personas oracles** readable: `ai/project-goals.md` (the differentiating promise) and `ai/users-and-personas.md` (who + their job). In `--reimagine` these are mandatory — missing → HALT → `/setup-project --refine`. In `--evolve` the existing design carries most of the weight, but they still sharpen the concept.
- `_extracted-idioms.md` populated — the existing token source, primitive catalog, surfaces, breakpoints, voice. In `evolve` it is the canon to amplify; in `reimagine` it is read as input (what to surpass + which jobs to preserve).
- Playwright MCP (or the project screenshot harness) wired — `/redesign` renders each rebuilt surface to earn its RTL/a11y/responsive checkmarks; without it those claims are marked `SKIPPED (no harness)`, never faked.

## Args
- `<scope>` — a route, page component, feature area, or `the whole product`. Bounds **both** the design and the build: `/art-direct dashboard` rebuilds only the dashboard surfaces, not the whole app. Same semantic resolution as `/redesign` + `/enhance-ui` (codebase-profile + idioms).
- `--evolve` — **DEFAULT.** Push the existing visual language further, stay on-brand, raise the ceiling. Redlines dominate; the build is low-churn (mostly `/redesign` + `/polish`, few new primitives).
- `--reimagine` — greenfield original direction derived from product goals; the existing system is input/reference, not a constraint. Requires readable goals + personas; the build includes the architect re-codifying tokens + a staged migration.
- `--yes` — **skip the single approval gate.** Auto-approve the recommended direction and build it without stopping. Use for throwaway projects, or when you'll review the git diff afterwards. (Still HALTs on the hard pre-flight failures — dirty tree, missing oracles in `reimagine`, no frontend.)
- `--direction="<text>"` — optional seed (`"editorial"`, `"engineered precision"`, `"expressive density"`). Default: the director derives the tension axis + three directions from goals + the redline clusters. Note: this seeds the **visual-language / aesthetic axis** — distinct from `/redesign`'s `--direction`, which seeds a **layout archetype** within an already-decided language.
- `--surfaces=<n>` — cap how many surfaces the build rebuilds in this run (default: the key surfaces named in the brief). For a broad scope, the rest are listed as remaining and you re-run to continue.
- `--render` / `--no-render` — force or skip the `design-iterate` candidate-screen render in the design pass. Default: render if Playwright MCP is wired, else mark `SKIPPED`.
- `--plan` — **design-only.** Universal handoff flag (see blockquote): the brief IS the plan artifact; the run stops at the design before any build.

```bash
/art-direct the dashboard                       # design → approve once → build the dashboard
/art-direct the dashboard --yes                  # design → build, no stop
/art-direct marketing/landing --reimagine        # greenfield identity, then build it
/art-direct the whole product --plan             # just the direction; build nothing
```

## What happens internally

**Discipline:** the design pass is governed by the **[`creative-director`](../agents/creative-director.md)** agent's Premise + halt conditions (concept-first, cite-or-halt, rendered-not-asserted) — this command does not hand-roll the rubric or vocabulary. It composes the pack's specialists: `creative-director` owns the concept / direction / invention; the `design-iterate` skill renders candidate surfaces; then the command **runs** `design-system-architect`, `/redesign`, and `/polish` to build — those code-editing commands carry the SOLID/clean-code discipline in [`core-discipline.md`](../../../governance/core-discipline.md) and their own per-surface verification. Phases below are silent annotations — no phase numbers reach the user.

1. **Frame** — parse `<scope>` + mode; intent-gate (`enforce token` → `/align`; `tidy within system` → `/enhance-ui`·`/polish`; `rebuild ONE page in the existing language` → `/redesign`); HALT if no frontend surface or dirty tree. Read GOALS (`ai/project-goals.md`) + PERSONAS (`ai/users-and-personas.md`) from the correct oracles (cite-or-halt; `reimagine` HALTs if unreadable); `reimagine` also inventories the existing token source + primitive catalog as input.
2. **Diagnose (redline pass)** — read the current surfaces; tag each failure with a diagnosis label pinned to `<path:line>` or a named reference; run the wired hand-wave grep ([`hand-wave-grep.md`](../../../snippets/hand-wave-grep.md)); escalate each redline to the aesthetic verdict or ROUTE pure usability-axis findings to `ux-reviewer` / `/redesign`; cluster by severity to seed the directions.
3. **Diverge** — generate exactly THREE directions, each curing a different redline cluster AND placed at a non-adjacent point on the per-product tension axis; each a full mini-brief; apply the mechanical divergence check (color-ramp-swap + ≥2 structural axes); collapse + regenerate any duplicate.
4. **Decide (render + gate)** — validate each direction against content-truth (longest/translated string, dense, empty, RTL) and the usability floor (eliminate any floor failure); render 1–3 key surfaces via `design-iterate` (Playwright MCP, `$SCOPE_TIER`, `.claude/artifacts/`) or mark `SKIPPED` — contrast COMPUTED, never asserted; score all three on the rubric scorecard; recommend ONE with its named sacrifice + live alternative; build the Encodability Table — then run the two **build-readiness gates** below before **GATE: approve / adjust / pick alternative / switch mode.** With `--yes`, auto-approve the recommendation. With `--plan`, write the brief to `.claude/plans/` and exit here — no build.
   - **Mode is surfaced, never silently timid.** When the user passed NEITHER `--evolve` nor `--reimagine`, the run is `evolve` (on-brand refinement) but the gate MUST headline that and offer the escalation: `MODE: evolve — refines your CURRENT look (same type/grid/neutral, retuned + one signature moment). For a genuinely NEW look (new type/grid/shape/color), pick reimagine.` The user may **switch mode at the gate** — the command re-runs Diverge in `reimagine` (reading the goals/personas oracles; HALT→`/setup-project --refine` if unreadable) rather than locking them into the timid default they never chose. `--yes` on a mode-less run stays `evolve` but the built-result footer still prints the escalation line.
   - **Anti-timidity gate (the "loud move / before-after" gate) — blocks the build, not just a prose halt.** The recommended direction may proceed to build ONLY if BOTH hold, each shown at the gate: (a) its **Conviction** lens is `✓` with the ONE deliberate loud move NAMED (`creative-director` rubric); and (b) it passes the **before→after glance delta** — the rendered key surface is visibly distinguishable from the CURRENT surface at 1/8 thumbnail (not just vs competitors). If Conviction is `Δ`/`✗` or the before/after delta fails, the direction is a **restyle masquerading as a direction** → the command HALTS the build and routes to `/enhance-ui`·`/polish` (or asks to regenerate a bolder direction / switch to reimagine). "New paint on the same structure" never reaches the build.
5. **Codify (build step 1)** — **run `design-system-architect`** on the approved direction: turn the Encodability Table + Direction Delta (`evolve`) or original-system proposal + migration cost (`reimagine`) into governed token/primitive layers in code. Lands as commits.
6. **Build (build step 2)** — **run `/redesign` on each key surface in scope** with its per-page **proposal gate relaxed** (the direction was approved once at Phase 4; each surface lands as one reviewable commit, so `git` — not a per-page prompt — is the control): each surface is rebuilt in the now-codified language, rendered to verify (breakpoints × theme × locale), one commit per surface. `/redesign`'s one mandatory non-gate question still fires — a feature with no home in the new layout is surfaced as **keep / move / drop**, never dropped silently (`redesign.md:181`); under `--yes` it defaults to keep. Surfaces beyond `--surfaces=<n>` are listed as remaining.
7. **Finish + report (build step 3)** — **run `/polish`** to finish motion/focus/states/rhythm/contrast on the rebuilt surfaces; then run the **coverage gate** (below) before emitting the built-result summary + the honesty footer. Because step 2 runs `/redesign`, each surface goes through `/redesign`'s **render→critique→improve refine loop** (up to `--max-refine`, default 3) against its Design-principles rubric — so the built surfaces are iterated to the **motion-actually-implemented / modern-register / performance** bar, not shipped one-pass. `/art-direct` does not report success on a flat, motionless, or default-template result: the loop drives it to a modern, animated, efficient surface or names the residual honestly. The full brief lives in `.claude/artifacts/art-direct/<iso>/brief.md`.

**i18n-completeness gate (no raw keys on screen).** Any label, section header, empty/error/loading string, or grouping the redesign INTRODUCES must have a real translation added to **every shipped locale file** (`i18n/*.json` / `locales/*`) in the same change — and the rendered surface is grepped for un-interpolated keys (`STATUS.GROUP_X`, `Status.no_products`, any user-visible `dotted.key` / `SCREAMING_KEY`). A raw key on screen is a **build FAILURE**, not a nit: the run does not report success while a surface shows a translation key instead of translated text. (This is the exact defect where a redesign adds nice grouping but forgets the copy.)

**Coverage gate (no half-redesigned surface).** The approved language applies to **every element inside `<scope>`, not just the prominent ones.** After the build, enumerate the in-scope surface's regions (header/toolbar, **filter/control bar**, cards/tiles, primary content, **data-visualization / charts**, **data tables / lists**, secondary panels, empty/loading states) and confirm each was rebuilt in the NEW language — a region still carrying the pre-run tokens/style (the classic "new cards, old filter bar", or **new cards but the chart and the tables untouched**) is a **coverage failure**, reported as such and NOT counted as success. A `coverage:` line prints the count (`N/N regions in the new language`) and names any left in the old style. A run that restyles the hero elements and leaves the controls/charts/tables untouched is INCOMPLETE — the command either finishes the scope or states the scope was mis-bounded; it never reports a consistent redesign over an inconsistent one.

Two regions the build MUST NOT skip (they are the ones it silently skips today):

- **Data-visualization / charts.** A chart-library chart (Chart.js / ECharts / Recharts / ApexCharts / D3) keeps its colors, axis/grid lines, fonts, legend, and tooltip in its **own config object — NOT design tokens** — so token re-codification alone leaves it in the old palette. The build MUST re-theme the chart's config to the new language: dataset/series colors → the new palette; grid/axis lines → the new hairline/neutral; tick/label font → the new type; legend + tooltip → the new surface/radius/shadow; empty/no-data state → the new empty language. Coverage verifies the chart's **actual rendered colors/grid changed** (from the screenshot), not merely "a chart is present."
- **Shared components (tables, cards, chart wrappers, badges).** `/redesign` composes shared components rather than re-implementing them (`redesign.md:103`) — correct for DRY, but it means a shared table/chart used on other pages is reused **in its old style** and the page looks half-done. Resolution: a shared component still carrying the old language is a coverage failure whose fix is to **restyle it at the design-system level** (via `design-system-architect`, so the new language propagates to it — and every page that uses it) — the run states the blast radius ("restyling `DataTable` updates it on N pages"). Never silently compose an old-style shared component and call the page redesigned; either restyle it system-wide (the `reimagine` default) or report the region INCOMPLETE with why.

The full **Direction rubric**, the **diagnosis vocabulary**, and the **invention vocabulary** are owned by the [`creative-director`](../agents/creative-director.md) agent — this command cites them rather than restating them.

## The approval gate (the one approval)

By default the run pauses **once** to approve — at Phase 4, the *direction*, before anything is rewritten. The gate is the load-bearing safety step: design is taste, and you should see the chosen look (one sentence + a rendered surface) before the build changes your app. You may **approve** the recommendation, **adjust** it, **pick one of the two live alternatives**, or **switch mode** (evolve↔reimagine).

**The gate always states the mode and its ambition** — so a `/art-direct dashboard` run (no flag) can never silently ship you a timid `evolve` when you wanted a new look: the gate reads `MODE: evolve — refines your CURRENT look; pick reimagine for a genuinely new one`, and picking reimagine re-diverges from goals/personas before you approve. The gate also refuses to hand a **restyle** to the build (the anti-timidity gate in Phase 4): if the recommended direction has no named loud move or is indistinguishable from the current surface at a glance, the build is blocked and you're routed to `/enhance-ui`·`/polish` or asked for a bolder direction — the "same layout, new paint" result is caught here, before it reaches your code.

- `--yes` — skip the gate. Design and build in one shot; review the git diff afterwards.
- `--plan` — stop at the gate permanently. Design only; no build.

The build does **not** re-prompt to approve each page: `/redesign`'s per-page proposal gate is **relaxed** here — the direction is approved once and each surface lands as its own reviewable commit (`git` is the rollback if a rebuilt surface isn't right), rather than a proposal gate per page. The one interaction it keeps is a **feature-parity** conflict — a feature with no home in the new layout is surfaced as **keep / move / drop** and never dropped silently; the default run pauses for it, `--yes` defaults it to **keep** (and lists each).

## What you see

```
/art-direct the dashboard --reimagine

Concept (built — Direction B "Instrument Panel"):
  "Every screen is a precision instrument: the one number that matters is the
   loudest thing in the room, everything else recedes to a hairline grid."
  ▸ logo-swap test FAILS (good — ownable) · 1/8 thumbnail identifiable ✓

Designed:   11 redlines cited · 3 distinct directions (divergence check ✓)
Approved:   B over A — sacrifices first-impression warmth for scan-speed on the
            40×/day ops job (the primary persona)
Built:
  tokens:   design-system-architect codified B → 22 primitives, 31 semantic tokens
  surfaces: /redesign rebuilt 4/4 in-scope (dashboard, orders, order-detail, filters)
  coverage: 7/7 regions of the dashboard in the new language (toolbar · filter-bar ·
            KPI cards · chart · tables · empty/loading · secondary panel) — none left old
  finish:   /polish — focus/motion/states/contrast on the 4 surfaces
  rendered: 4 surfaces @ 320/1280 + dark + ar-RTL → RTL ✓ · a11y AA ✓
  commits:  9 (1 tokens · 4 redesign · 4 polish) · diff +1,840/−1,210
  brief:    .claude/artifacts/art-direct/2026-06-26T14-02/brief.md

Not validated: cross-browser pass (Playwright ran chromium-only)
Risks:         reimagine migration touched 22 primitives — legacy aliases kept 1 release
Revert:        git revert <first>..<last>   (or git reset --hard <pre-run HEAD>)
```

If the screenshot harness was unavailable, the `rendered:` line reads `SKIPPED (no harness) — visual claims NOT verified` instead of printing unearned checkmarks. Under `--plan` the output ends at `Designed:` + the brief path — nothing is built.

## What you DON'T see
- Phase numbers, the redline-clustering, or the divergence-check mechanics.
- The agent dispatch, the scorecard math, or the rubric/vocabulary internals.
- Per-page **proposal** prompts during the build — you approved the direction once and review the per-surface commits (`git`) instead of a proposal gate per page. (A **keep / move / drop** parity question still appears if a feature has no home in the new layout — that is the one build interaction; `--yes` defaults it to keep.)

## Hard rules
- The Premise is read first and never deviated from: concept-first, taste WITH discipline, **design then build**.
- Cite-or-halt via the wired [`hand-wave-grep.md`](../../../snippets/hand-wave-grep.md) — every diagnosis carries a `<path:line>` or a named principle-level reference, or it is deleted.
- Rendered, not asserted: route every visual claim through `design-iterate` / `/redesign`'s render (Playwright MCP); contrast is COMPUTED; unrendered = `SKIPPED`, never a faked checkmark.
- Encodable or owned: every signature move is an Encodability row or a flagged rendered `art-directed exception` — never un-buildable-and-unrendered.
- The usability floor is delegated to `ux-reviewer` and the 16-axis catalog (`ui-principles.md` § Axis catalog): self-checked in the design pass before the recommendation (not re-audited there), then confirmed per surface by `ux-reviewer` during the `/redesign` build; no 17th axis (`ui-principles.md:87`).
- Goals come from `ai/project-goals.md`; personas from `ai/users-and-personas.md` — never cross the oracles.
- The three directions pass the divergence check (color-ramp-swap + ≥2 structural axes) or one is regenerated; no averaging into a safe blend.
- **One approval checkpoint** — the direction (Phase 4). `--yes` skips it; `--plan` stops at it. The build then runs without per-page approval prompts (`/redesign`'s page gate is relaxed; per-surface commits are the review surface); the only interaction it keeps is the **keep / move / drop** parity call, which never drops a feature silently (`--yes` defaults it to keep). The build is bounded by `<scope>` + `--surfaces`.
- Project-agnostic: anonymous SaaS/storefront/marketplace examples, principle-level references, never a brand or downstream-project name.
- **Build, don't fabricate**: `/art-direct` produces real commits via `design-system-architect` → `/redesign` → `/polish`; `git` is the rollback. Every run ends with the house honesty footer (`Not validated: / Risks: / Revert:`); chat output stays brief; the full brief lives in `.claude/artifacts/art-direct/<iso>/`.

## Failure modes
- **No frontend in the repo** (backend/data-only) — HALT; point the user at the frontend repo. Nothing to art-direct here.
- **Working tree dirty** — HALT; ask the user to commit or stash first (the build lands commits; rollback safety depends on a clean baseline). Exempt under `--plan` (design-only writes no production code).
- **`--reimagine` but goals (`ai/project-goals.md`) or personas (`ai/users-and-personas.md`) are missing/unreadable** — HALT (even under `--yes`); route to `/setup-project --refine`, or offer `--evolve` (which leans on the existing design).
- **The redline pass scores the current design on-concept and high-craft on every lens** — HALT; do not invent a problem; recommend `/enhance-ui`·`/polish` and stop. Never switch to `reimagine` without the user.
- **Playwright MCP / render harness not wired** — do NOT fake renders; mark visual claims `SKIPPED (no harness) — visual claims NOT verified`, build what can be built, note it under `Not validated:`.
- **Three directions fail the divergence check** — collapse the offender and regenerate from an unused redline cluster; never ship three tints of one idea.
- **The best-scoring direction fails a usability-floor item** — eliminate it from the recommendation (or send it back to keep the concept and fix the values); never score a floor failure up for being bold.
- **A signature move can't be encoded** — re-express it until codifiable, or flag a rendered, owned `art-directed exception`; never build it un-encodable AND unrendered.
- **The `reimagine` migration cost is unbounded** (whole catalog rewritten, no phased path) — propose `evolve` instead and say why, or stage the migration (legacy aliases kept ≥1 release) before building.
- **A surface can't be rebuilt cleanly** (e.g., `/redesign` can't preserve a feature even after a keep / move / drop call) — **discard that surface** (`git reset`; never commit a half-rebuilt page, `redesign.md:174`), keep the surfaces that already committed cleanly, and STOP with done-vs-pending + the decision needed. Per-surface commit granularity is what lets one bad surface roll back without touching the good ones.
- **Build is broad and long** (`the whole product`) — rebuild the key surfaces (or `--surfaces=<n>`), list the remaining surfaces, and report; the user re-runs to continue rather than the run going unbounded.

## The build chain (what the command runs after approval)

On gate approval (or immediately under `--yes`) the command runs three downstream owners, in order, producing real commits — `git` is the rollback:

1. **`design-system-architect` codifies** — receives the Encodability Table directly (already shaped `name | what it creates | encode-as | a11y+perf note`) and lifts each row into its layers (color → primitive ramps + semantic tokens; type personality + scale → type tokens; motion → duration/easing tokens; shape → radius/border tokens; density → spacing rhythm). For `evolve` the Direction Delta becomes its retune + alias plan; for `reimagine` the original-system proposal + migration cost becomes its greenfield catalog + phased deprecation. Token-economy restraint keeps the semantic layer inside the ~30–50 cap (`design-system-architect.md:156`). **Sequencing requirement:** the codified direction must land in the *same source `/redesign` re-extracts in its Phase 3* — both the token files **and** `ai/_extracted-idioms.md` (the primitive / surface / voice canon) — and be committed **before** step 2; updating the token files but not the idioms oracle would silently rebuild toward the pre-`art-direct` system.
2. **`/redesign` builds pages** — each key surface in scope is rebuilt page-by-page *within the new language*; `/redesign`'s "no inventing a visual language" constraint is satisfied because the new tokens/primitives ARE its existing system now. It receives the recommended direction + IA archetype + signature spec + state language + the redlined screens; it renders each surface to verify and lands one commit per surface. Its per-page **proposal** gate is **relaxed** under the build — the direction was approved once at the gate, and per-surface commits are the review surface, rather than a proposal prompt per page. Its one mandatory non-gate question survives: a feature with no home is surfaced as **keep / move / drop**, never dropped silently (`redesign.md:181`; `--yes` defaults it to keep).
3. **`/polish` finishes** — after pages are built, the closure-verb sweep (hierarchy/rhythm/states/contrast/focus/motion) brings the long tail and the signature-moment micro-details to AA-clean craft within the system.

Sequence is enforced (codify → build → finish); each stage carries the approved concept as its north star; `ux-reviewer` (which `/redesign` composes) confirms the usability floor on each rebuilt surface.

## Cross-references
- agent [`creative-director`](../agents/creative-director.md) — owns the concept / Direction rubric / diagnosis + invention vocabularies the design pass runs.
- agent `design-system-architect` — **run** to codify the approved direction into tokens/primitives (build step 1).
- agent `ux-reviewer` — the delegated usability floor; confirms it during the `/redesign` build.
- `/redesign` — **run** per surface to rebuild pages *within* the new language (build step 2); `/art-direct` decides the language `/redesign` builds toward.
- `/polish` — **run** to finish the rebuilt surfaces (build step 3).
- `/align` — enforce existing tokens/rules; no creative work.
- skill `design-iterate` — renders the candidate surfaces (Phase 4).
- rule `ui-principles` — the 16-axis usability catalog (the floor; not extended here).
- pattern `design-systems`, `motion`, `rtl`, `theming`, `dark-mode` — the system context the codified direction lands in.
- `/scaffold-project` — for a NEW project: scaffold first (it ships a starter design system + the goals/personas oracles), then `/art-direct --reimagine` designs + builds the real identity. See `docs/FEATURE-LIFECYCLE.md` § Scenario A.

## Stack scope
Frontend / mobile only. Gated on `primary_frontend_framework_detected`. On a backend/data-only repo the command halts with a redirect to the frontend repo.
