---
description: One command to SET and INVENT the visual direction of a product / surface / flow — concept, original visual language, signature moments — derived from the product's goals, NOT enforced from the existing system. Diagnoses the current design with a point of view, generates three genuinely distinct directions, renders + scores them, gates on your approval, then hands off to design-system-architect (codify) → /redesign (build) → /polish (finish). Two modes: evolve (default — push the existing language further) / reimagine (greenfield from goals). It PROPOSES and DIRECTS; it never writes the production rebuild. The creative high-ground above /redesign (builds within a language) and design-system-architect (codifies one). Frontend / mobile only.
kind: command
pack: ui-ux
---

# /art-direct <scope> [<more>...]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/art-direct <scope> --plan` runs the diagnose → diverge → score pass and writes the **Art-Direction Brief** (with its renders + scorecard) to `.claude/plans/`, exiting at the approval gate before any handoff. Execute it later with `/execute-plan <file>` (or hand it to any tool). Deliberate deviation from the standard plan-flag "exit before Generate / make no edits" rule: `/art-direct` makes **no production edits in any mode**, so its generative pass IS the plan — there is nothing to guard against until the handoff chain, which `--plan` is exactly what stops.

## The Premise (read this first, internalize, do not deviate)

**You point at a product (or a surface); this command decides what it should look and feel like, and invents the visual language to get there — like handing it to a creative director, not a linter.** Every other UI command operates *within* a visual language someone already chose: `/align` enforces it, `/polish` and `/enhance-ui` finish inside it, `/redesign` rebuilds a page inside it (and is explicitly forbidden to invent a new one — `redesign.md:64`), `design-system-architect` codifies a decided one into tokens. `/art-direct` is the one upstream of all of them: it **chooses and invents the language** they then enforce, finish, build, and codify.

The work is driven by the **`creative-director`** agent and lands as a single gated **Art-Direction Brief** — a cited critique (redlines) of the current design, three genuinely distinct directions, a scorecard, a recommended direction with its honest sacrifice, and an Encodability Table that becomes the architect's payload. It **proposes and directs; it writes nothing into production.** On approval it fans out the handoff chain.

The two hard anchors: **a concept you cannot state in one sentence is decoration** (so the brief always leads with a concept that must *fail* the logo-swap test to count), and **originality is the ceiling but usability is the floor** (so every direction clears WCAG-AA, 320px, RTL, reduced-motion, and a perf budget — computed, not asserted — before it can be recommended). A direction that is bold but unusable, or original but un-buildable, is a failed run.

### `/art-direct` vs `/redesign` vs `design-system-architect` vs `/enhance-ui`·`/polish` vs `/align`

| Decision plane | `/art-direct` (creative-director) | `/redesign` | `design-system-architect` | `/enhance-ui` · `/polish` | `/align` |
|---|---|---|---|---|---|
| **Who DECIDES the visual language** | ✅ **the only one — invents it from product goals** | ❌ forbidden to invent one (`redesign.md:64`) | ❌ codifies a given one | ❌ iterates within it | ❌ enforces it |
| Visual language / concept / mood | **CREATES** (concept, world, refusals, moments) | speaks the existing one | turns a decided one into tokens | tightens within it | enforces tokens/rules |
| Layout / IA | names the **archetype**, hands to `/redesign` | **reworks ONE page within the language** | n/a | preserved | preserved |
| Tokens / primitives | **proposes** (Encodability Table) | consumes | **codifies** (primitive→semantic→component, waves, governance) | maps to existing | enforces existing |
| Usability / a11y | **floor it must clear** (delegated to `ux-reviewer`) | rubric it builds to | a11y contract per primitive | within-system finish | drift enforcement |
| Creative ambition / originality | ✅ **its deliverable** | within-system only | none (mechanic) | iteration, not invention | none (linter) |
| Approval gate | ✅ yes — brief before handoff | ✅ yes — proposal before build | no | no | no |
| Altitude | **UPSTREAM of all of them** | downstream of `/art-direct` | downstream (codifies the decision) | downstream | downstream |

**Stack scope:** frontend / mobile only (`primary_frontend_framework_detected`). On a backend/data-only repo, **HALT** — there is no UI here to art-direct; point the user at the frontend repo.

## When to use
- The product's look is generic, dated, or "fine but forgettable" and needs a point of view — not a tidy-up.
- A new product or surface needs an original visual direction derived from its goals and personas.
- A redesign effort keeps producing restyles because no one decided the *direction* to redesign toward.
- Leadership asks "what should this feel like?" — the question upstream of tokens, pages, and polish.

## When NOT to use
- Enforce a hardcoded value → an existing token, or fix a11y drift from an existing rule → `/align`.
- Add finish (states, rhythm, hierarchy, a few variants) within the current language → `/enhance-ui` or `/polish`.
- Rebuild ONE page's layout/UX *inside the existing visual language* → `/redesign`.
- Turn an already-decided direction into tokens/primitives → the `design-system-architect` agent directly.
- A brand-new page that doesn't exist yet → `/add-feature`.

## Pre-requisites
- `PROJECT_KIND` is `frontend-*` / `mobile-*` (gated on `primary_frontend_framework_detected`). Backend/data-only → HALT.
- **Goals + personas oracles** readable: `ai/project-goals.md` (the differentiating promise) and `ai/users-and-personas.md` (who + their job). In `--reimagine` these are mandatory — missing → HALT → `/setup-project --refine`. In `--evolve` the existing design carries most of the weight, but they still sharpen the concept.
- `_extracted-idioms.md` populated — the existing token source, primitive catalog, surfaces, breakpoints, voice. In `evolve` it is the canon to amplify; in `reimagine` it is read as input (what to surpass + which jobs to preserve).
- Playwright MCP (or the project screenshot harness) wired **if** you want rendered candidate screens — without it, candidates are marked `SKIPPED`, never faked. The brief itself does not require it.
- This command writes **no production code**, so it does not require a clean working tree — but its *handoff* commands (`/redesign`, `/polish`) do; they enforce their own clean-tree gates when you run them.

## Args
- `<scope>` — a route, page component, feature area, or `the whole product`. Same semantic resolution as `/redesign` + `/enhance-ui` (codebase-profile + idioms).
- `--evolve` — **DEFAULT.** Push the existing visual language further, stay on-brand, raise the ceiling. Redlines dominate; output centers on a **Direction Delta**; low-churn handoff.
- `--reimagine` — greenfield original direction derived from product goals; the existing system is input/reference, not a constraint. Requires readable goals + personas; adds a mandatory migration/rollout cost.
- `--direction="<text>"` — optional seed (`"editorial"`, `"engineered precision"`, `"expressive density"`). Default: the director derives the tension axis + three directions from goals + the redline clusters. Note: this seeds the **visual-language / aesthetic axis** — distinct from `/redesign`'s `--direction`, which seeds a **layout archetype** within an already-decided language; what flows to `/redesign` at handoff is the named IA archetype, not this string.
- `--render` / `--no-render` — force or skip the `design-iterate` candidate-screen render. Default: render if Playwright MCP is wired, else mark `SKIPPED`.
- `--plan` — universal handoff flag (see blockquote above): the brief IS the plan artifact; exit at the approval gate before any handoff.

```bash
/art-direct the whole product                      # evolve (default): sharpen the implicit concept
/art-direct dashboard/orders --reimagine            # greenfield direction for the orders surface
/art-direct marketing/landing --direction="editorial" --render
/art-direct the whole product --reimagine --plan    # write the brief, exit at the gate, execute later
```

## What happens internally

**Discipline:** the run is governed by the **[`creative-director`](../agents/creative-director.md)** agent's Premise + halt conditions (concept-first, cite-or-halt, rendered-not-asserted, propose-don't-build) — this command does not hand-roll the rubric or vocabulary; it composes the pack's specialists: `creative-director` owns the concept / direction / invention; `ux-reviewer` is the delegated usability floor (and drives page-level IA/flow when `/redesign` runs); the `design-iterate` skill renders candidate surfaces; and on approval `design-system-architect`, `/redesign`, and `/polish` execute the handoff (those code-editing commands carry the SOLID/clean-code discipline in [`core-discipline.md`](../../../governance/core-discipline.md) — `/art-direct` itself writes no code). Phases below are silent annotations — no phase numbers reach the user.

1. **Frame** — parse `<scope>` + mode; intent-gate (`enforce token` → `/align`; `tidy within system` → `/enhance-ui`·`/polish`; `rebuild ONE page in the existing language` → `/redesign`); HALT if no frontend surface. Read GOALS (`ai/project-goals.md`) + PERSONAS (`ai/users-and-personas.md`) from the correct oracles (cite-or-halt; `reimagine` HALTs if unreadable); `reimagine` also inventories the existing token source + primitive catalog as input.
2. **Diagnose (redline pass)** — read the current surfaces; tag each failure with a diagnosis label pinned to `<path:line>` or a named reference; run the wired hand-wave grep ([`hand-wave-grep.md`](../../../snippets/hand-wave-grep.md)); escalate each redline to the aesthetic verdict or ROUTE pure usability-axis findings to `ux-reviewer` / `/redesign`; cluster by severity to seed the directions.
3. **Diverge** — generate exactly THREE directions, each curing a different redline cluster AND placed at a non-adjacent point on the per-product tension axis; each a full mini-brief; apply the mechanical divergence check (color-ramp-swap + ≥2 structural axes); collapse + regenerate any duplicate.
4. **Generate (render + gate)** — validate each direction against content-truth (longest/translated string, dense, empty, RTL) and the usability floor (eliminate any floor failure); render 1–3 key surfaces via `design-iterate` (Playwright MCP, `$SCOPE_TIER`, `.claude/artifacts/`) or mark `SKIPPED` — contrast COMPUTED, never asserted; score all three on the rubric scorecard; recommend ONE with its named sacrifice + live alternative; build the Encodability Table — then **GATE: approve / adjust / pick alternative.** Nothing proceeds without approval. (Under `--plan`, the brief IS the plan artifact — written to `.claude/plans/` instead of the artifacts dir — and the run exits here, before the handoff chain.)
5. **Codify handoff** — on approval, hand the Encodability Table + Direction Delta (`evolve`) or original-system proposal + migration cost (`reimagine`) to `design-system-architect` to turn the decided aesthetic into governed token/primitive layers.
6. **Build handoff** — hand each key surface's IA archetype + signature spec + state language + redlines to `/redesign`, which rebuilds pages *within the now-codified language* (its "no inventing a visual language" constraint is satisfied — the architect made the new language the existing one); `ux-reviewer` — which drives the page-level IA/flow rethink inside `/redesign` — confirms the usability floor on each rebuilt surface.
7. **Finish handoff + report** — hand the closure-verb targets to `/polish` to finish motion/focus/states/rhythm/contrast on the rebuilt surfaces; emit the brief chat output + the honesty footer; the full brief lives in `.claude/artifacts/art-direct/<iso>/brief.md`.

The full **Direction rubric**, the **diagnosis vocabulary**, and the **invention vocabulary** are owned by the [`creative-director`](../agents/creative-director.md) agent — this command cites them rather than restating them.

## The approval gate (mandatory)

No code is written and no handoff runs before you approve the brief. The gate is the load-bearing step: `/art-direct` decides a direction; it does not impose one. You may **approve** the recommendation, **adjust** it, or **pick one of the two live alternatives** (each carries the one condition under which it wins). The two un-recommended directions are real, non-strawman options — not a sales funnel.

## What you see

```
/art-direct the dashboard --reimagine

Concept (recommended — Direction B "Instrument Panel"):
  "Every screen is a precision instrument: the one number that matters is the
   loudest thing in the room, everything else recedes to a hairline grid."
  ▸ logo-swap test FAILS (good — ownable) · 1/8 thumbnail identifiable ✓

Redlines:   11 cited (3 conceptless · 4 timid · 2 dated · 2 incoherent-world)
Directions: 3 distinct (divergence check ✓ — color-ramp-swap + ≥2 structural axes)
Recommend:  B over A — sacrifices first-impression warmth for scan-speed on the
            40×/day ops job (the primary persona). A wins if marketing reach
            matters more than daily-operator velocity.
Render:     3 surfaces @ 320/1280 + dark + ar-RTL via design-iterate ✓
Floor:      computed-AA ✓ · one primary + focus ✓ · ≥44px ✓ · reduced-motion ✓
            · 320px reflow ✓ · RTL ✓ · perf budget ✓
Brief:      .claude/artifacts/art-direct/2026-06-25T14-02/brief.md

Gate → approve · adjust · pick A/C
Handoff (on approval): design-system-architect → /redesign → /polish

Not validated: candidate renders are static screenshots, not live a11y/perf runs —
               ux-reviewer confirms the floor during /redesign.
Risks:         reimagine migration touches ~22 primitives (staged path in the brief).
Revert:        no production code written; this run is reversible by discarding the brief.
```

If the screenshot harness was unavailable, the `Render:` line reads `SKIPPED (no harness) — visual claims NOT verified` instead of printing unearned checkmarks.

## What you DON'T see
- Phase numbers, the redline-clustering, or the divergence-check mechanics.
- The agent dispatch, the scorecard math, or the rubric/vocabulary internals.
- Mid-run prompts other than the single approval gate (and the one allowed clarifying question when a goal genuinely forks the direction space).

## Hard rules
- The Premise is read first and never deviated from: concept-first, taste WITH discipline, propose-don't-build.
- Cite-or-halt via the wired [`hand-wave-grep.md`](../../../snippets/hand-wave-grep.md) — every diagnosis carries a `<path:line>` or a named principle-level reference, or it is deleted.
- Rendered, not asserted: route every visual claim through `design-iterate` (Playwright MCP); contrast is COMPUTED; unrendered = `SKIPPED`, never a faked checkmark.
- Encodable or owned: every signature move is an Encodability row or a flagged rendered `art-directed exception` — never un-buildable-and-unrendered.
- The usability floor is delegated to `ux-reviewer` and the 16-axis catalog (`ui-principles.md` § Axis catalog), self-checked before the recommendation, never re-audited; no 17th axis (`ui-principles.md:87`).
- Goals come from `ai/project-goals.md`; personas from `ai/users-and-personas.md` — never cross the oracles.
- The three directions pass the divergence check (color-ramp-swap + ≥2 structural axes) or one is regenerated; no averaging into a safe blend.
- Project-agnostic: anonymous SaaS/storefront/marketplace examples, principle-level references, never a brand or downstream-project name.
- `/art-direct` PROPOSES and DIRECTS, gates on approval, then hands off to `design-system-architect` → `/redesign` → `/polish`; it writes nothing into production.
- Every run ends with the house honesty footer (`Not validated: / Risks: / Revert:`); chat output stays brief; the full brief lives in the artifact.

## Failure modes
- **No frontend in the repo** (backend/data-only) — HALT; point the user at the frontend repo. Nothing to art-direct here.
- **`--reimagine` but goals (`ai/project-goals.md`) or personas (`ai/users-and-personas.md`) are missing/unreadable** — HALT; route to `/setup-project --refine`, or offer `--evolve` (which leans on the existing design).
- **The redline pass scores the current design on-concept and high-craft on every lens** — HALT; do not invent a problem; recommend `/enhance-ui`·`/polish` and stop. Never switch to `reimagine` without the user.
- **Playwright MCP / `design-iterate` harness not wired** — do NOT fake renders; mark candidates `SKIPPED (no harness) — visual claims NOT verified`, proceed with the brief, note it under `Not validated:`.
- **Three directions fail the divergence check** — collapse the offender and regenerate from an unused redline cluster; never ship three tints of one idea.
- **The best-scoring direction fails a usability-floor item** — eliminate it from the recommendation (or send it back to keep the concept and fix the values); never score a floor failure up for being bold.
- **A signature move can't be encoded** — re-express it until codifiable, or flag a rendered, owned `art-directed exception`; never ship it un-encodable AND unrendered.
- **The `reimagine` migration cost is unbounded** (whole catalog rewritten, no phased path) — propose `evolve` instead and say why, or add a staged migration path under Risks.
- **The user asks `/art-direct` to implement the rebuild itself** — HALT; `/art-direct` directs. Building is the handoff chain; print the commands.

## The handoff chain (what runs on approval)

On gate approval the brief fans out to three downstream owners, in order — `/art-direct` writes nothing into production:

1. **`design-system-architect` codifies** — receives the Encodability Table directly (already shaped `name | what it creates | encode-as | a11y+perf note`) and lifts each row into its layers (color → primitive ramps + semantic tokens; type personality + scale → type tokens; motion → duration/easing tokens; shape → radius/border tokens; density → spacing rhythm). For `evolve` the Direction Delta becomes its retune + alias plan; for `reimagine` the original-system proposal + migration cost becomes its greenfield catalog + phased deprecation. Token-economy restraint keeps the semantic layer inside the ~30–50 cap (`design-system-architect.md:156`).
2. **`/redesign` builds pages** — once codified, each key surface is rebuilt page-by-page *within the new language*; `/redesign`'s "no inventing a visual language" constraint is satisfied because the new tokens/primitives ARE its existing system now. Pass it the recommended direction + IA archetype + signature spec + state language + the redlined screens; it runs its own usability rubric + per-page approval gate.
3. **`/polish` finishes** — after pages are built, the closure-verb sweep (hierarchy/rhythm/states/contrast/focus/motion) brings the long tail and the signature-moment micro-details to AA-clean craft within the system.

Sequence is enforced (codify → build → finish); each stage carries the approved concept as its north star; the usability floor is confirmed during the `/redesign` build, which already composes `ux-reviewer`.

## Cross-references
- agent [`creative-director`](../agents/creative-director.md) — owns the concept / Direction rubric / diagnosis + invention vocabularies this command runs.
- agent `design-system-architect` — codifies the approved direction into tokens/primitives (handoff #1).
- agent `ux-reviewer` — the delegated usability floor; also drives the page-level IA/flow rethink during `/redesign`'s build.
- `/redesign` — rebuilds a page *within* a visual language (handoff #2); `/art-direct` decides the language `/redesign` builds toward.
- `/enhance-ui` · `/polish` — finish within the system (handoff #3); not direction.
- `/align` — enforce existing tokens/rules; no creative work.
- skill `design-iterate` — renders the candidate surfaces (Phase 4).
- rule `ui-principles` — the 16-axis usability catalog (the floor; not extended here).
- pattern `design-systems`, `motion`, `rtl`, `theming`, `dark-mode` — the system context the codified direction lands in.

## Stack scope
Frontend / mobile only. Gated on `primary_frontend_framework_detected`. On a backend/data-only repo the command halts with a redirect to the frontend repo.
