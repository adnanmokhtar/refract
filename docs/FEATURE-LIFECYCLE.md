# Feature Lifecycle Playbook

One page. How a new project or a new feature moves from idea → shipped, mapped to the commands in this repo. Every build command runs the same 7-phase spine; the ceremony scales to the work.

**The spine (every build command):** `Understand → Organize → Retrieve → Generate → Update → Validate → Improve`

---

## Scenario A — New project (greenfield)

```
1. /refine-prompt "<idea>"          idea → structured spec   →  ai/ideas/<YYYYMMDD>-<slug>.md
2. /scaffold-project <spec-path>     spec → working repo (boots; starter design system + auth + dashboard)
      └─ auto-chains /setup-project --create at Phase 4.8  (→ .claude/ + ai/ + rules + adapters)
3. /art-direct --reimagine           [frontend, optional] invent the REAL visual identity from goals
      └─ approve once → it BUILDS it: auto-runs design-system-architect → /redesign → /polish
                        (--yes skips the approval · --plan stops at the design)
4. then every feature → Scenario B
```

- `/scaffold-project` **embeds** `/setup-project` — you do **not** run setup-project as a separate third step for a fresh scaffold. Its declared "next" is `/add-feature`.
- Run `/setup-project` **standalone** only for an **existing** repo that needs the `.claude/` knowledge layer retrofitted (`--enhance` / `--refresh`).
- Step 3 is **optional and frontend-only** — `/scaffold-project` already ships a *starter* design system, so you can skip straight to features. Run `/art-direct` when you want a real, ownable visual identity instead of the defaults. See the walkthrough below.

### Designing the visual identity — the scaffold → art-direct → build loop (frontend)

`/scaffold-project` gives you a working app with a *starter* design system — sensible defaults, not an identity. To give the product a real, ownable look, run the creative-direction loop **after the scaffold boots** (it needs surfaces to critique + the goals/personas oracles, which the scaffold produces — pointing `/art-direct` at an empty folder has nothing to read):

```
1. /scaffold-project "<idea>"     → working app (boots) + starter design system + the oracles
                                     art-direct reads (ai/project-goals.md, ai/users-and-personas.md)

2. /art-direct --reimagine        → reads the goals + the starter surfaces; invents THREE distinct
                                     directions (concept · layout/shape language · type/colour/motion
                                     · signature moments); renders + scores them  →  ONE APPROVAL
     └─ on approval it BUILDS — auto-runs, in order (the creative-director designs; the
        command runs the builders):
          design-system-architect  → codifies the chosen direction into the scaffolded tokens/primitives
          /redesign  (per surface) → rebuilds each key surface in the new language (one commit each)
          /polish                  → finishes motion / states / contrast / rhythm

3. then every feature → Scenario B → new pages inherit the now-real design system
```

- **One approval:** you approve the *direction* once before anything is rewritten; the build then runs to committed screens (`git` is the rollback), re-prompting only to avoid dropping a feature silently (a **keep / move / drop** call when a feature has no home in the new layout).
- **Skip the stop:** `--yes` builds without the approval (design → build in one shot). **Lighter look:** if the starter system is already close, use `--evolve` (default) instead of `--reimagine`.
- **Design only:** `/art-direct --reimagine --plan` writes the brief to `.claude/plans/` and stops at the design — review the direction, build nothing.
- **Boundary:** `/art-direct` *decides the language and runs the build*; `/redesign` *builds each page within it*; `design-system-architect` *codifies it*; `/polish` *finishes*. It halts on a backend/data-only repo (nothing to art-direct).

## Scenario A2 — Completing an unfinished project

You inherited or paused a half-built project and need to know what's left, then finish it in controlled batches (not one giant unreviewable change).

```
1. /roadmap [--goal "…"]       map every intended-but-unbuilt feature → ai/roadmap/plan.md (phased, sized, read-only)
                               (--goal folds in requirements that aren't in the code/docs yet)
2. read the plan               review the phases before building anything
3. /roadmap --build            build Phase 1 in parallel waves → halt at the phase gate → review
4. /roadmap --build            Phase 2 … repeat one phase per run (never all-at-once)
5. /roadmap                    re-map → converges to 0 missing = done
```

Six detectors reconstruct "done" for a project with no V1 to copy: stubs, dangling wires, feature asymmetry, spec delta (README/PRD/ADRs), domain table-stakes, dead-end flows. Every row cites `<file:line>` — no phantom features. The single-codebase analog of the migration pack's scan → plan → fast loop. Each finished feature then flows into Scenario B for follow-on work.

---

## Scenario B — New feature in an existing project

**Step 0 — pick the entry by how raw the ask is:**

| You have… | Command | Produces |
|---|---|---|
| A vague feature/business idea | `/analyze-task "<idea>"` | business spec → (confirm gate) → technical spec (with a **Spec-ID**) in `specs/`; then `/add-feature specs/<file>` builds from it (consumes the spec, doesn't re-derive). Already decided it (e.g. via Plan Mode)? `--decisions <plan-file>` skips the gate and writes 4a+4b in one pass |
| A one-line ticket | `/expand-task "<brief>"` | an implementer-ready prompt + ONE suggested next command |
| A clear feature to build | `/add-feature "<desc>"` ·or· `/add-feature specs/<file>` | scaffold + implement + tests |
| One specific artifact | `/add-module` · `/add-endpoint` · `/add-component` · `/add-page` · `/add-crud-page` · `/add-screen` | just that piece |
| A bug | `/fix-bug "<desc>"` | failing test → fix → postmortem |
| Not sure which | `/do "<anything>"` | routes to the right execution command |

**Step 1 — `/add-feature` auto-tiers (it never pre-inflates):**

| Tier | When | Ceremony |
|---|---|---|
| **Trivial** (default) | 1–2 files, mirrors a sibling exactly | Understand(light) → Generate → Validate. No plan/ADR/docs. |
| **Standard** | new pattern element / reuses primitives | + 1-para plan + sibling-shape note + stack scan (N+1 / bundle / cold-start) |
| **Heavy** (auto-promoted) | cross-module / new primitive / schema / auth / payment / native bridge | full 7 phases + architects + reviewers + ADR + security/observability/release pre-flights |

**Step 2 — three gates run at every tier** (the discipline that keeps the codebase coherent):
1. **Prior-art gate** — HALT on duplicate capability (behaviour, not name).
2. **Sibling-shape halt** — new code must match an existing sibling's layout/naming/errors; invented shapes rejected.
3. **New-dependency gate** — a new dependency needs explicit justification.

> `/add-feature` accepts either a free-text description **or** a `specs/<file>` path. Given a spec, it consumes it as-is (no re-derivation) and threads the spec's **Spec-ID** into the PR title + commits for traceability back to `/analyze-task`.

---

## Plan → Execute → Verify (optional overlay)

Bolt onto any command when you want a checkpoint or the "strong model plans, cheap model executes" split:

```
/<command> "..." --plan       writes .claude/plans/<file>.md   (plan on Opus / opusplan)
/execute-plan <file>          implements it                    (executor sub-agents → Sonnet); auto-verifies
/verify-plan <file>           audits result vs plan            (FULFILLED / DRIFTED / VIOLATED)
```

The plan file is a tool-agnostic contract (`Context · Inputs · Outputs · Steps · Constraints · Verification · Status`) — hand it to any tool, or `/execute-plan` it in Claude.

## Afterburners (quality + learning)

```
/audit       full-stack review — 8 axes + 13 scale-lens, ranked P0–P4   → ai/audit/
/optimize    architectural diagnosis → tactical sweep                    → ai/optimize/
/polish      stack-conditional consistency (UI / API / schema / mobile)  → ai/polish/
/align       convention-drift enforcement (closure verbs, no new work)   → ai/align/
/learn-from-task   promote what was learned into the knowledge layer
```

---

## Cross-cutting (always on)

- **Foundational rules** (auto-loaded from `.claude/rules/`): `read-before-write` · `read-codebase-deeply` · `think-simplify-surgical` · `code-quality`. Plus `templates/governance/core-discipline.md` (SOLID + clean-code) read before any codegen.
- **Knowledge layer** — Phase 3 *reads* `ai/conventions.md`, `ai/business-domain.md`, `ai/status.md`, `ai/dynamic/feedback-learned.md`, siblings; Phase 5 *writes* `ai/status.md` (Recent Changes), `ai/dynamic/changelog.md`, `ai/modules.md`, new ADRs/patterns.

## Adapters (Claude-native vs translated)

| Class | Commands | Other tools |
|---|---|---|
| Setup family (optional translate) | refine-prompt, scaffold-project, setup-project, learn-from-task | surfaced per-adapter if selected; refine-prompt's deep pass is Claude-only |
| Build / spec (generic translate) | analyze-task, expand-task, add-*, fix-bug | every `.claude/commands/<name>.md` → the tool's native primitive |
| Simple-surface multi-agent (Claude-only) | do, audit, optimize, polish, align | not translated as slash commands — they depend on parallel sub-agent dispatch; approximate via pack commands or parallel orchestrator scripts |
| Repo-baseline infra (universal) | execute-plan, verify-plan | ship to every project; execute-plan's fan-out degrades to sequential off-Claude (`--from-plan` / paste fallback) |

---

## End-to-end at a glance

```
NEW PROJECT:   /refine-prompt → /scaffold-project (⤷ /setup-project) → [frontend] /art-direct ⤷ architect→/redesign→/polish → features ↓
NEW FEATURE:   /do  ·or·  /analyze-task → specs/<file> → /add-feature specs/<file>   (Spec-ID threads into PR/commits)
                          ·or·  /expand-task → /add-feature
                                              │
                         (tiers: trivial/standard/heavy · gates: prior-art/sibling-shape/new-dep)
                                              ↓
               [optional]  --plan → /execute-plan → /verify-plan
                                              ↓
               /polish · /audit · /optimize · /align   →   /learn-from-task
```
