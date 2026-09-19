---
description: The design team in one command — the visual sibling of /audit. Renders every route, LOOKS at each and scores it, then rebuilds every below-bar surface until it beats its own diagnosis. It raises a bar rather than clearing a defect list, so a page with no defects and no quality still gets work. Triggers — 'go through every page and make the design better, do not ask me', 'I want a design team in one command', 'it works but it looks mediocre'. Do NOT trigger when the caller wants to pick a variant (/enhance-ui), wants metrics and phase stops (/ui-sweep), wants nothing written (/design-review, /ui-crawl), or wants ONE surface (/redesign). Frontend / mobile only.
kind: command
pack: ui-ux
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /ui-audit [<scope>]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/ui-audit --plan` runs PRE-FLIGHT → SCAN → RANK → DIRECT (everything read-only, including the direction decision) and writes the plan to `.claude/plans/`, then exits before the first edit. Execute it later with `/execute-plan <file>`.

> **Not this command? (ANTI-triggers)** — "let me pick between variants" → **`/enhance-ui`** (this command picks for you). "give me the metrics and the HTML report, and stop between phases" → **`/ui-sweep`**. "change nothing, just tell me" → **`/design-review`** (one surface) or **`/ui-crawl`** (every route). "one surface only" → **`/enhance-ui`** / **`/redesign`**. "the code, not the look" → **`/audit`**, which is this command's sibling on the engineering axes. Full map: [`ui-sweep.md § The ui-ux command map`](ui-sweep.md).

## The Premise (read this first)

**`/audit` is the engineering team in one command. This is the design team in one command.**

The pack's other ten commands each own one decision and hand the rest back to you: `/design-first` asks which path, `/enhance-ui` offers three variants, `/redesign` gates on approval, `/ui-sweep` stops between phases. Each of those gates exists for a good reason — a human wanted to steer. **This command is for when nobody wants to steer.** It makes every one of those calls itself, from evidence it gathers, and does not come back until the work is done.

It is not a new detector layer. It is the **autonomous driver** over the pack's existing machinery — `/ui-crawl`'s browser truth, `/ui-sweep`'s 8 detectors, `redesign.md`'s language-or-composition test, `creative-director`'s direction rubric, `ui-design-sweep`'s closed 19 verbs, `/redesign`'s composition rebuild. Nothing here re-defines a verb, a lens or a fingerprint; the specs stay where they are, and this command is judged on whether it dispatches them completely and decides honestly.

**This is a BAR, not a defect list — the distinction the whole command turns on.** A fingerprint that does not match means *no defect of that shape was found*; it does not mean the surface is good. A run built only on fingerprints therefore reports `clean` on a page that is merely unremarkable, which is the single way this command fails while appearing to work. So **every rendered surface is SCORED before any tier decision is taken**, and a surface below the bar gets work **even when not one fingerprint matched**. Measurements feed the score; they never substitute for it.

**And the scoring is done by LOOKING.** The lenses in [`redesign.md § Design principles`](redesign.md) are judgements about a rendered image — hierarchy, composition, modern register, craft — not quantities a detector can compute. The run opens the screenshot and grades it against them. A score derived from token coverage and contrast ratios without the image is not a score, and a run that produces one has failed this command's premise, not satisfied it.

**Three things it refuses to fake.** It never scores a surface it did not render (a login wall is not a dashboard); it never reports a fix it did not re-render after applying; and it never reports a verdict — including `clean` — for a surface it cannot show you the render and the score for. All three HALT rather than degrade.

## The boundary with `/audit` — the seam where things get dropped

Two autonomous commands over one codebase have exactly one failure mode worth designing against: **a concern each assumes the other owns.** The split is by *evidence*, not by topic, and it is stated here so a run of both leaves no gap:

| Concern | Owner | Why that owner |
|---|---|---|
| Frontend **code** quality — component structure, state management, prop drilling, dead components, bundle size, render waste | **`/audit`** | Measured from source and from a profiler. A re-render storm is invisible in a screenshot. |
| **Accessibility** | **`/ui-audit`** (V1) | `/audit`'s model carries an Accessibility axis gated on `browser`/`mobile`, but it reads source. A contrast ratio and a focus order are **rendered** properties: axe against a live route is the evidence, and this command has the harness. `/audit` defers its axis here rather than grading it blind. |
| **UX / interaction** | **`/ui-audit`** (V2/V3) | Same reason — an interaction is a thing a browser does, not a thing a file says. |
| **i18n / RTL** | **split, and the split is the point** | Missing extraction, hardcoded strings, plural rules → `/audit` (source). A layout that breaks under RTL, a truncated translated label, a mirrored icon that should not mirror → `/ui-audit` (render). |
| Performance a user **sees** — LCP, CLS, INP, jank, layout thrash | **`/audit`** | It owns the measured-performance axis across every stack and already routes web-vitals through it. This command reports what its renders observed and files it there rather than growing a second perf ranker. |
| Design tokens, wrappers, states, hierarchy, composition, visual language | **`/ui-audit`** | Nothing in `/audit`'s vocabulary can close these. |

**The rule when a finding fits both:** it belongs to whoever can *verify* the fix. A fix whose proof is a re-render is this command's; a fix whose proof is a test, a profile or a benchmark is `/audit`'s. A finding neither can verify is a `Live, unreviewed` cell (Phase 2b) — named, not absorbed.

**Run order**: `/audit` first, then `/ui-audit`. Engineering fixes move markup and state; running the visual pass first means re-rendering everything twice. The reverse order is not wrong, only wasteful — nothing in either command depends on the other having run.

## What makes it autonomous (the contract)

The pack's gates each protect a decision. This command resolves each one **mechanically**, and the mechanism is named so you can audit the call after the fact:

| Gate that normally asks | How this command decides instead |
|---|---|
| `/design-first` — `$SOURCE`: system or independent | **Always `system`.** A project-wide sweep is bound to the project's own language by definition; `independent` is a greenfield permission and is out of scope here. Stated, not inferred. |
| `/redesign` — approval before code | **`git` is the approval.** One commit per surface, one verb or one rebuild per commit, every commit independently revertable. The gate becomes a diff you read afterwards instead of a prompt you answer beforehand. |
| `/enhance-ui` — pick 1 of 3 variants | **The 9-lens Direction rubric picks.** Candidates are rendered and scored; the winner is the highest score, ties broken toward the candidate closer to the existing language. The three candidates and their scores land in the report. |
| `/art-direct` — is the language itself wrong? | **The language-or-composition test decides** ([`redesign.md § Phase 1`](redesign.md)), per surface, from the baseline render plus the token source — never asked, exactly as that section already requires. |
| `/ui-sweep` — stop between phases | **Does not stop.** Tiers run V0 → V3 in one session; the ledger makes a resumed run pick up where it left off. |

**What still HALTs** — the short list, and it is short on purpose:

1. **Blocked render.** An auth-gated route that renders a login wall, a blank shell, or a bot wall. Scoring it would be a lie; `SKIPPED (no harness)` is not available as a silent state. Fix the session, re-run.
2. **No token source.** `_extracted-idioms.md § Tokens` absent or empty. There is no language to work inside and no evidence to decide with → route to `/setup-project --refine`.
3. **Dirty tree or red CI at HEAD.** `git` is the rollback; it has to mean something.
4. **A fix that re-detects after being applied** (Phase 8). Flipped `halted`, surfaced, never silently re-attempted.
5. **`--reimagine` asked for on a multi-theme app** — that is `/add-theme-variant`'s slot system, and inventing a language in place would edit the shared layer.
6. **A verdict with nothing behind it.** Before the run may print any per-surface outcome, `ai/ui-audit/` must hold, for **every VIEW in the resolved set** — every tab panel, wizard step and structurally distinct modal the crawl inventory counted, not merely every route — a stored render and a scorecard. A missing pair is not a surface with no findings — it is a surface nobody looked at, and the two are indistinguishable in a report that prints only findings. This is the mechanical half of HALT #1: #1 stops a blocked render, #6 stops a run that never attempted one. **A run that ends with no `ai/ui-audit/` directory has not "found nothing"; it has not run, and says so.**

Anything else is a decision, and decisions are this command's job.

## Phase 0 — Resolve scope + targets

- `PROJECT_KIND` must be `frontend-*` or `mobile-*`. Anything else HALTs → `/audit` (engineering) or `/polish` (backend API surface).
- Read the idioms oracle: `_extracted-idioms.md` §§ `Tokens` · `Wrappers` · `Surfaces` · `Breakpoints` · `Voice` (optional). Missing Tokens → HALT #2.
- **Route inventory** from the router source, not from a guess. Each route resolved to: path · surface type (list-page / detail-page / form / modal / wizard / empty-shell) · auth requirement · visit-rate if telemetry is wired.
- **Shared-surface inventory**: every wrapper in § Wrappers, with its consumer count. This is what makes V0 leverage real — one fix at a wrapper with 40 consumers is 40 surfaces.
- Session: authenticate per `visual-check`'s contract (`storageState` / login step). A route that cannot be reached authenticated is recorded `BLOCKED` and HALTs the run, per HALT #1.
- `--scope=<path>` narrows the route set; the shared-surface inventory is **never** narrowed, because a wrapper outside the scope is still what the in-scope surfaces render through.

## Phase 1 — Matrix scan (parallel, route-major)

The scan is `route × axis`, dispatched in parallel waves. It composes rather than re-implements:

**Wave A — browser truth** (dispatch `/ui-crawl` over the resolved route set)
Screenshots × 3 breakpoints + dark + RTL, axe-core per route, tabs / dialogs / dropdowns walked, console + network errors captured. This wave is what catches what static reading cannot: overlapping floating elements, a control bar still in the library's default theme, a chart rendering in the library's stock palette, a row whose height changes because a pill wrapped.

**Wave B — the 8 specialist detectors** ([`ui-sweep.md § The 8 UI/UX-specific deep detectors`](ui-sweep.md)) — visual hierarchy · component utilization · token coverage · cross-surface consistency · UI-state coverage · responsive matrix · design-language coherence · visual baseline + drift. Run against the Wave-A renders, never against source alone.

**Wave C — the composition diagnosis.** Per surface, run [`redesign.md § Phase 1 — THE LANGUAGE-OR-COMPOSITION TEST`](redesign.md) from that surface's baseline render plus the token source. Output per surface is one of three verdicts, and this verdict is what routes the surface in Phase 4–7:

| Verdict | Meaning | Routed to |
|---|---|---|
| `finish` | Language is fine, composition is fine, execution is not | V3 — the 19 verbs |
| `compose` | Language is fine, this page's layout / IA / ranking is wrong | V2 — `/redesign` within the existing language |
| `language` | The fault is the visual language itself, not this page | Phase 3 — direction, then V2 for every surface |

A `language` verdict on **one** surface is composition; the same verdict on **a majority of scored surfaces** is what promotes the run to a direction decision. The threshold is printed, never implied.

**Carve-outs the scan must honour** (from [`ui-design-sweep/SKILL.md § Cross-cutting carve-outs`](../skills/ui-design-sweep/SKILL.md)): a component-library control's inner classes and a chart's config object do **not** inherit the token layer. Both are graded as first-class components **from the render**, and a token sweep that leaves them in the library's stock theme is a miss, not a pass. This is the single most common false-green in a project-wide visual sweep.

## Phase 1.5 — Score every VIEW (mandatory, and the reason this is not a linter)

Runs on **every** rendered view, before Phase 2 and regardless of what Waves A–C found. It is the step whose absence lets a run finish fast and report nothing.

### The unit is the VIEW, not the route

**A route is not a surface. A view is.** One route commonly renders several distinct screens behind tab strips, sub-tab strips, segmented controls, wizard steps, drawers and modals — an admin settings route with six tabs is six designs sharing a URL, and they drift apart exactly because nothing ever looked at more than the first one.

Scoring per route grades whichever panel happened to be active and then reports the route as scored. That is the same defect HALT #6 exists to prevent, one level down: five panels invisible, and a ledger that says covered.

**The inventory already exists** — `/ui-crawl` walks tabs, dialogs and dropdowns and writes their counts into `ai/audits/ui-crawl-inventory.json`. Phase 0 reads that count; Phase 1.5 must produce one scorecard per counted view, and a route whose inventory says 6 tabs and whose score directory holds 1 file fails HALT #6.

A view is enumerated when activating it **changes what is rendered without changing the route**:

| Counts as its own view | Does not |
|---|---|
| Each tab / sub-tab panel | A tab whose panel is the same component with a different filter value — score once, note the parameter |
| Each wizard or stepper step | Hover, focus and pressed states — component states, graded inside their view |
| A modal, drawer or sheet with its own layout | A confirm dialog that is the shared `confirm` primitive — graded once, project-wide |
| An empty / loading / error state that replaces the whole view | An inline field error |
| A role- or permission-conditional layout that differs structurally | The same layout with fewer rows |

**Modals, drawers and sheets are the half most often missed, and the half that most needs grading.** A tab is at least visible on arrival; a dialog requires an interaction to exist at all, so a run that only loads routes never sees one. They also concentrate the two defects this command was extended for:

- A dialog is **literally a surface on a surface** — the floating-surface fingerprint applies to it against the scrim *and* against the page behind it, and a dialog that reads as lifted on a white page can vanish on a dark one.
- Form dialogs are where control-size disagreement lives, because their footer buttons and their fields are usually authored in different files from the page's.
- A dialog is the most common place a project keeps a **second, competing implementation** of a surface it already has — the V0 `/unify-surfaces` dispatch should expect to find pairs here.

**Open every one the crawl inventory counted**, grade it as its own view, and grade its **trigger state** too where the page changes behind it (a scrim that dims, a body that scrolls). A dialog that was never opened is `Live, unreviewed`, never `clean`.

**Cost control, honestly stated.** Enumerating views multiplies the work — six tabs is six renders and six scorecards. `--first-run` caps the count per route and the ledger reports the uncapped population as `Live, unreviewed`, so the cap is visible rather than silent. What is never acceptable is scoring one view and reporting the route.

**Dispatch the [`design-score`](../skills/design-score/SKILL.md) skill per surface.** It grades the rendered image against [`redesign.md § Design principles`](redesign.md) — the same lens set `/redesign` designs against and scores with — and carries the halt this phase depends on: no render, no score, ever. Do not inline the grading here and do not invent a second rubric; a second vocabulary for the same judgement is how two commands start disagreeing about whether a page is good.

**A `below-bar` surface is then handed to the [`ui-designer`](../agents/ui-designer.md) agent**, whose whole job is the sentence no other agent in this pack is allowed to say: *nothing here is broken and it still is not good enough — here is what to change.* Its proposals name the element, the change, the existing token that delivers it, and the lens the change moves. Those proposals are what V2 builds; a `below-bar` verdict with no proposals behind it is a complaint, and V2 has nothing to execute.

Per surface, per lens: `✓` / `Δ` (with a one-line cited note) / `✗`. Plus the per-component pass `/redesign` already defines: every component on the surface graded from the render, `below-bar` until it visibly matches the language — and the filter / control bar graded as a first-class component, because a library control in its default theme is the most-missed `below-bar` on any admin screen.

**The bar**: a surface passes when no targeted lens is `✗`, no more than two are `Δ`, and no component is `below-bar`. Anything else is **below bar** and enters V2 — *even with zero fingerprint matches from Wave B*. This is the entire difference between a defect scanner and a design team: the team is allowed to say *"nothing here is broken and it still is not good enough."*

**What a score may NOT be built from.** Token coverage, contrast ratios, state coverage and a11y results are **inputs to lenses**, never the score itself. `design-score` returns `RESCORE-REQUIRED` for a scorecard whose every verdict could have been produced without opening the screenshot, and Phase 9 re-checks it. The failure mode this closes is precise and observed: a run that computes ten metrics, finds each within tolerance, and reports a mediocre page as clean.

**Honest residuals.** A lens the run cannot grade from a still image — motion, focus order, keyboard behaviour — is recorded `NOT RUN` with the reason, never `✓`. `/redesign` already draws this line for what a drawing can and cannot carry; the same line applies to a screenshot.

Scores land in `ai/ui-audit/scores/<route>/<view>.md` — one file per view, `index.md` for the route's default view. This is what HALT #6 counts against the crawl inventory.

## Phase 2 — Cross-axis rank

One ranker reads every wave's findings and produces `ai/ui-audit/plan.md`, ranked into V0–V3 by `user-impact × blast-radius × fix-cost` — **not** by axis and not by route.

- **User-impact** is weighted by the route's visit-rate where telemetry exists, and by surface type where it does not (an auth screen and a checkout step outrank a settings sub-tab).
- **Blast-radius** is the consumer count of the surface being changed. A wrapper with 40 consumers outranks a leaf page, which is why V0 exists as its own tier.
- A finding that a Wave-A render **proves** (a measured contrast ratio, a captured overlap, a chart's actual pixel colors) outranks one inferred from source at the same tier.
- **A below-bar surface is a first-class row**, ranked by `(bar − score) × visit-rate`, and carries the lenses that failed as its closure target. It does not need a fingerprint to exist. A plan in which every row traces to a fingerprint is a plan that skipped Phase 1.5.

Every finding carries: id · axis · surface · `<file:line>` · closure verb (or `redesign`) · the render that evidences it · dependency-on · tier · fix-cost.

**Anti-hand-wave**: the same grep `/audit --strict` enforces. `several places` / `multiple components` / `appears to` / `etc.` in a finding is a rejected finding, not a soft one.

## Phase 2b — The cell ledger

Written as the **first section** of `ai/ui-audit/plan.md`, before any finding — the same discipline [`audit.md § Phase 2b`](../../../../commands/audit.md) applies to engineering cells, applied here to `route × axis`.

```
## Cell ledger — 34 routes → 61 views × 9 axes = 549 cells

Views scored       61 / 61  ← fewer than the crawl inventory counted BLOCKS the run
Reviewed          389   findings ranked below
N/A                61   each with a reason
Live, unreviewed   31   ← nobody is looking at these
Blocked             0   ← any value here HALTs (see HALT #1)

### Live, unreviewed
| Cell | Surface population | Why nothing ran |
|---|---|---|
| Motion × print-views        | 4 routes   | no motion fingerprint for a print stylesheet |
| Responsive × embedded-iframe| 2 routes   | breakpoints not observable through the frame |
```

**Hard rules**, inherited verbatim in spirit from `/audit`:
- A cell may never be silently absent; absent = a Phase 0 resolution bug, and the run says so.
- **No bare `N/A`** — every N/A row carries its reason.
- **`Live, unreviewed` is never merged into `N/A`.** They are opposite claims: N/A says *this does not apply here*; live-unreviewed says *this applies and nobody is looking*.
- **`Blocked` is its own column and is never merged into either.** A route behind a login wall is not out of scope and is not clean — it is unrendered, and an unrendered route is why this tier HALTs instead of averaging.
- The four counts must sum to the resolved cell count. Print the arithmetic.

## Phase 3 — Direction (the creative decision, taken not asked)

Runs **only** when Phase 1 Wave C returned `language` on a majority of scored surfaces. Otherwise skipped with one printed line, and the run goes straight to V0.

Dispatch `creative-director` in `--evolve` mode (`--reimagine` only when the caller passed it, and never on a multi-theme app — HALT #5):

1. Diagnose the current language with a cited point-of-view (the 15-label redline vocabulary).
2. Generate **three mechanically-distinct directions** — the logo-swap, color-ramp-swap and ≥2-structural-axes checks are what stop three renders of the same idea from being called three directions.
3. Render candidates via `design-iterate`; score each on the **9-lens Direction rubric**.
4. **Pick the winner: highest score. Ties break toward the candidate closer to the existing language** — a sweep is not the place to take the more adventurous of two equals.
5. Hand the winner to `design-system-architect` to codify as tokens. From here the new language **is** the project's language, and every later tier enforces it.

The usability floor is `ux-reviewer`'s and is never re-audited here — originality is the ceiling, the floor is delegated, and there is no 17th axis.

**The report carries all three candidates and all three scores.** A direction taken without asking still has to be inspectable afterwards, and a run that prints only the winner has removed the only evidence that a choice was made at all.

## Phase 4 — V0: foundation (project-wide, sequential)

The highest-leverage tier and the reason this command is not a per-page loop. One fix here lands on every consumer at once.

- Verbs: `consolidate-tokens`, `extract-token`, `unify-component`, `extract-pattern`, `normalize-surface`.
- One commit per verb, **not** per site — `consolidate-tokens` across 50 sites is one commit, per the verb's own procedure.
- Each commit: re-detect → apply → **re-render every affected route** → visual diff must be within the verb's stated tolerance → lint + typecheck + scoped tests → commit.
- **The carve-outs are executed here, not deferred.** Library-control inner classes get explicit `:deep()` / theme-token overrides; chart configs get re-themed through their own theming API (or a build-time-resolved literal). Verified from the rendered pixels, never from "a chart is present".

### The competing-implementation escape hatch — V0's one dispatch out of the verb set

`unify-component` fires on exactly one shape: **a shared wrapper exists and a RAW element is used somewhere that fits its contract.** It swaps the raw site for the wrapper. That is the whole verb, and it leaves the harder case untouched — the one a project actually accumulates:

| What Wave B found | Closable here? |
|---|---|
| A raw `<button>` where `<AppButton>` exists | **yes** — `unify-component` |
| A radius / shadow / height literal where a token exists | **yes** — `consolidate-tokens` |
| A page whose skeleton diverges from its surface-type prototype | **yes** — `normalize-surface` |
| **Two competing wrappers** — `Card` and `PanelBox`, both shared, both real, neither raw | **NO** |
| **A rolled-own component** that must be folded INTO the canonical one, absorbing its props | **NO** |

The last two are what the user means by *"every page uses a different shape."* No verb in the closed 19 can close them: reconciling a rolled-own instance INTO a canonical shape requires deciding which implementation wins, migrating the losing one's call sites, and widening the survivor's contract to cover what the loser did. That is `/unify-surfaces`' entire job, and duplicating it here would create a second, weaker implementation of the exact thing this section is about.

**So V0 dispatches it.** When Wave B's component-utilization detector reports ≥2 implementations of one surface type that are each used by ≥2 consumers and neither is raw, V0 runs:

```
/unify-surfaces <surface-type> --scope=<the union of both implementations' consumers>
```

one surface type at a time, in descending consumer count, before any leaf work. Its commits land in this run's ledger like any other V0 row, and its result is re-rendered and re-scored by Phase 8 exactly as a verb's would be. `--tier=V0` includes these dispatches; `--plan` lists them as rows without running them.

**Three guards, because this is the one place V0 leaves its own vocabulary:**

1. **Never on a single implementation.** One wrapper plus raw sites is `unify-component`, and sending it to `/unify-surfaces` would rebuild a wrapper that already works.
2. **Never on a declared variant.** Two implementations that `_extracted-idioms.md § Wrappers` names as *deliberately different* surfaces (a `Card` and a `StatCard` with different jobs) are a decision, not drift. When § Wrappers is silent on the pair, the run reports the ambiguity as a `Live, unreviewed` ledger row rather than guessing — merging two surfaces that were meant to differ is not recoverable by re-running anything.
3. **After tokens, before composition.** Consolidating tokens first means the survivor is already on the design language when consumers migrate onto it; running it after V2 would re-open every page V2 had just rebuilt.

## Phase 5 — V1: correctness of experience (sequential)

Things that are not taste. A user is blocked, misled, or excluded.

- Verbs: `lift-contrast`, `align-focus-ring`, `expand-tap-target`, `clarify-affordance`, `wire-empty-state`, `wire-loading-state`, `wire-error-state`.
- Every axe-core violation Wave A captured is a row here, and every row closes with the **re-run of axe on that route** attached to the commit — the same same-commit assertion rule `/audit` applies to security fixes.
- A state wired here is wired with the project's `Voice` where § Voice exists. An empty state that says "لا توجد بيانات متاحة" and offers nothing is a wired state that failed its own verb; the verb requires the cause and the next action.

## Phase 6 — V2: composition (sequential, one surface per commit)

Three populations enter this tier, and the second is the one the command exists for:

1. Every surface Wave C verdicted `compose` — its layout is wrong.
2. **Every surface Phase 1.5 scored BELOW BAR** — nothing is broken and it is not good enough. No fingerprint required, no defect cited. If this population is empty on a real app, suspect Phase 1.5 of having graded from metrics instead of from the image.
3. If Phase 3 ran, **every** scored surface, because a new language is not applied by re-skinning old compositions.

**Resolve the SCOPE TIER before building — the fix's true home, not the page it was noticed on.** `/enhance-ui` opens with this question and `/ui-audit` never asked it: is this change a **token**, a **shared wrapper variant**, or a **single leaf**? A table footer that reads as too heavy is almost never that page's footer; it is the shared `<DataTable>`, and rebuilding it per surface produces the drift the run was sent to remove — twelve pages each carrying their own corrected footer, and the thirteenth still wrong.

Per proposal, before any edit:

| Tier | Fingerprint | Where the fix lands |
|---|---|---|
| `token` | the value is wrong for its ROLE everywhere it appears | the token; every consumer moves at once |
| `wrapper-variant` | the shared component is right and this usage needs a declared variant | a variant on the wrapper, named |
| `leaf` | this surface genuinely differs, and the difference is intended | the page |

A proposal resolved to `token` or `wrapper-variant` is **applied once and removed from every other surface's queue**, and the routes it touches are re-rendered as part of its own verification — that is `$CONSUMER_ROUTES`, the same input `/enhance-ui` passes to `design-iterate`. A run that applies the same visual change on eight pages has mis-tiered it eight times.

**A `leaf` verdict needs its reason recorded.** "This page is different" with nothing behind it is how a design system erodes one justified exception at a time.

- For a **population-2** surface, `/redesign` builds `ui-designer`'s ranked proposals rather than re-deriving what is wrong: the diagnosis was done in Phase 1.5 and repeating it wastes a render and invites a second opinion. For population 1 and 3, `/redesign` diagnoses as it normally does.
- Dispatch `/redesign` per surface, inside the now-current language. **Use its refine loop, which is the machinery that makes this command improve rather than merely repair**: diagnose → design → self-critique → build → score the rendered result → **while any targeted lens is `Δ`/`✗` or any component is `below-bar`, improve that named lens in code, re-render and re-score**, up to `--max-refine` rounds (default 3). Each round must move a named lens from `Δ` to `✓`, not restate the score.
- The result must **measurably beat the Phase-1.5 diagnosis** on the lenses it targeted. A lens the diagnosis flagged that is still `Δ` after the loop is reported plainly as a residual, never hidden and never quietly dropped.
- The approval gate `/redesign` normally holds is satisfied by the per-surface commit, per the autonomy contract above. A surface whose post-build score does **not** beat its diagnosis is reverted and flipped `halted` — it is not committed and argued for.

**Why the loop is not optional here.** One pass produces the first thing that satisfies the brief; a designer looks at that and keeps going. `/redesign` already encodes the difference and this command previously routed around it, reaching `/redesign` only for `compose` surfaces and sending everything else to V3's fingerprint verbs — which have no bar, so a merely-unremarkable page passed every tier untouched. That is the defect this tier's population 2 closes.

## Phase 7 — V3: finish (parallel waves)

- Verbs: `normalize-hierarchy`, `apply-type-scale`, `tighten-rhythm`, `simplify-density`, `unify-iconography`, `normalize-motion`, `unify-cta-placement`.
- Up to `--max-parallel` (default 5) concurrent subagents, one surface each. Parallel is safe at this tier and only at this tier: V0 changed shared code, V2 changed structure, V3 changes leaf presentation.
- After the tier, **re-run the Phase 1 detectors on every changed route**. Rows that re-detect clean → `verified`. Rows that re-detect → `halted` and surfaced (HALT #4).

## Phase 8 — Verify

- Every touched route re-rendered at 3 breakpoints + dark + RTL. The post-render is the evidence; a fix without one does not close.
- Per-axis metric must improve against the Phase 1 baseline, per route. A tier that moved no metric is reported as such rather than as done.
- axe-core clean on every route that had a violation, or the row is `halted`.
- Coverage must not drop; lint + typecheck green after every commit.
- **Visual-baseline drift is read in both directions.** A route this run never touched that now renders differently is a regression from a V0 fix reaching further than its finding claimed — surfaced, not absorbed.

## Phase 9 — Report

`ai/ui-audit/report-<YYYY-MM-DD>.html` — before/after screenshots per route at each breakpoint, **the Phase-1.5 scorecard per surface with its per-lens verdicts and its before→after delta**, per-axis metrics against the Phase 1 baseline, the cell ledger, the direction candidates and their scores where Phase 3 ran, per-tier commit list, and the `halted` rows with what re-detected.

**Phase 9 is also the audit of Phase 1.5.** A scorecard whose every lens verdict could be derived from the metrics alone — no reference to anything only visible in the image — is rejected, and that surface is re-scored from the render before the report is written. A report that lists findings but no scores is not a short report; it is a run that never set a bar, and it says so at the top instead of reading as a clean sweep. Browse-able; the thing you hand a stakeholder who did not read the diffs.

`ai/ui-audit/progress.md` is the resume ledger — tier, per-route status, and which commits closed which findings.

## Optional flags

- `<scope>` — restrict the route set (`--scope=src/modules/orders/`). Shared surfaces are never narrowed; see Phase 0.
- `--plan` — read-only through the direction decision; writes the handoff plan and stops. See the flag note at the top.
- `--reimagine` — allow Phase 3 to invent a language rather than evolve one. HALTs on a multi-theme app (HALT #5).
- `--max-parallel=<N>` — V3 concurrency (default 5).
- `--first-run` — caps Wave B at 5 routes per detector, so a first run on a large app returns in a sane time. The cell ledger reports the uncapped population, so the cap shows up as `Live, unreviewed` rather than disappearing.
- `--tier=<V0|V1|V2|V3>` — run one tier. Re-reads the existing plan; does not re-scan.
- `--re-scan` — discard `ai/ui-audit/plan.md` and re-run Phase 1 from scratch.

## Examples

```bash
/ui-audit                                  # the whole app, scan → decide → fix → verify
/ui-audit --plan                           # everything read-only, plan written, no edits
/ui-audit --scope=src/modules/orders/      # one module's routes (shared surfaces still global)
/ui-audit --first-run                      # large app, capped scan, honest ledger
/ui-audit --tier=V1                        # just the a11y / states tier from an existing plan
```

## Cross-references

### Commands
- [`/audit`](../../../../commands/audit.md) — the engineering sibling. Same shape (matrix scan → cross-axis rank → cell ledger → tiered execution → verify), the other half of the codebase. Run both for a full pass.
- [`/ui-sweep`](ui-sweep.md) — the same detectors with metrics, an HTML report and a stop between phases. Use it when you want to read before it writes.
- [`/enhance-ui`](enhance-ui.md) — one surface, and you pick the variant.
- [`/redesign`](redesign.md) — one surface's composition; dispatched by this command's V2.
- [`/art-direct`](art-direct.md) — the language decision as its own command, with its approval gate intact; this command's Phase 3 is the same machinery with the gate resolved by rubric.
- [`/ui-crawl`](ui-crawl.md) — this command's Wave A, usable alone when you want detection only.

### Skills
- [`design-score`](../skills/design-score/SKILL.md) — Phase 1.5's procedure: one render in, one scorecard out, with the no-render halt and the metrics-only anti-cheat.
- [`ui-design-sweep`](../skills/ui-design-sweep/SKILL.md) — the closed 19-verb vocabulary every tier dispatches into, and the carve-outs Phase 4 executes.
- [`design-iterate`](../skills/design-iterate/SKILL.md) — candidate renders for Phase 3.
- `visual-check` (frontend pack) — the render harness and the authenticated / blocked-render contract HALT #1 enforces.
- [`a11y-quick-check`](../skills/a11y-quick-check/SKILL.md) — the a11y primitives V1 closes against.

### Agents
- [`ui-designer`](../agents/ui-designer.md) — Phase 1.5's proposer; the per-screen craft judgement. Takes a `below-bar` scorecard and returns what to change.
- `creative-director` — Phase 3's driver.
- `design-system-architect` — codifies the winning direction as tokens.
- `ux-reviewer` — the usability floor, delegated and never re-audited here.

### Rules
- [`ui-principles.md`](../rules/ui-principles.md) — the axis catalog the detectors cite.
- `.claude/rules/align-discipline.md` — closure-verb discipline.

### Required project anchors
- `_extracted-idioms.md` §§ `Tokens` (HALT if absent) · `Wrappers` · `Surfaces` · `Breakpoints` · `Voice` (optional).
