---
description: Route one natural-language request to the right specialized command, then run it. Trigger when the user describes work without naming a command — 'enhance the sidebar', 'add a refund button', 'fix the order list crash' — or when one sentence spans several commands. Do NOT trigger when the user already named the command; call it directly, since routing is pure overhead. Not when they want a prompt artifact rather than execution (/refine-prompt), and not for a tracker URL, key, or 'next' (/task).
compatibility: Requires a repo with commands already installed by /setup-project — with none there is nothing to route to. Routing accuracy depends on _extracted-codebase.md being present; without it the stack is inferred from the tree and confidence drops. Does no work itself, and halts rather than guess when nothing matches.
kind: command
pack: orchestration
---

# /do <description>

## The Premise (read this first)

**Single entry point. You describe what you want; the agent picks the command.** No more "is this `/add-feature` or `/enhance-ui` or `/fix-bug`?" Just `/do <thing>`.

This is a **meta-router**, not a new capability. It dispatches to existing specialized commands based on:
1. **Your intent** (parsed from description: enhance / add / fix / audit / port / align / etc.).
2. **The stack** (frontend / backend / data / mobile from `_extracted-codebase.md`).
3. **The available command set** (per `.claude/commands/`).

If the agent is confident, it runs the picked command silently with the same description forwarded. If ambiguous, it surfaces options.

## When to use

- You don't remember the exact command name.
- The task spans multiple commands ("enhance the sidebar AND add a search bar" → routes to enhance-ui then add-feature).
- You want a single muscle-memory command.

## When NOT to use

- You already know the right command — just call it directly. `/do` adds a routing step that's pure overhead in that case.
- The task is genuinely novel and doesn't match any existing command — `/do` will halt and ask.

## Intent → command routing table

The agent uses semantic understanding (not keyword matching) but here's the routing reference:

| Intent signal in description | Routes to |
|---|---|
| "polish" / "enhance" / "improve" / "tighten" / "consistent" + UI sweep / whole project / module / page (no explicit variant ask), **and the finish being asked for does not exist yet** — "consistent" here means a missing token / state / contract gets introduced, not that an existing one gets applied where it drifted (that is the `/align` rows below) | `/polish [<scope>]` |
| "redesign" / "iterate" / "try variants" / "few options" / "different look" + single UI surface (creative iteration ask) | `/enhance-ui <description>` |
| "match colors" / "fix padding" / "cleaner spacing" + single UI surface (mechanical cleanup) | `/enhance-ui <description>` |
| "new project" / "from scratch" / "scaffold" / "start a new app / website / service" / "greenfield" / "build a \<product\> from nothing" | `/scaffold-project "<description>"` (run `/refine-prompt` first if the idea is still rough) |
| "figure out what to build" / "requirements" / "user stories" / "turn this idea into a spec" / "what should this feature do" (vague / spec intent) | `/analyze-task "<description>"` (business pack) |
| "turn this ticket into a task" / "unpack this one-liner" / "make this brief implementer-ready" (one-line-ticket intent) | `/expand-task "<description>"` (business pack) |
| "refine this prompt" / "tighten this idea" / "deepen this spec" (prompt-refinement intent) | `/refine-prompt "<description>"` |
| "add" / "new" / "create" / "build" + UI noun (page / component / form / modal / etc.) into an EXISTING app | `/add-feature <description>` (frontend) |
| "add" / "new" + endpoint / route / API noun | `/add-endpoint <description>` (backend) |
| "add" / "new" + module noun | `/add-module <description>` |
| "add migration" / "new migration" | `/add-migration <description>` |
| "fix" / "broken" / "crash" / "error" / "wrong" / "regression" | `/fix-bug <description>` |
| "audit" / "review" + design / UX / a11y | `/design-review <path>` |
| "audit" / "review" + security / vuln (security-only) | `/security-audit` |
| "audit" / "review" + perf / slow (perf-only) | `/perf-audit` |
| "audit" / "review" + i18n | `/i18n-audit` |
| "what's left" / "what's missing" / "what do I still need to build" / "map the missing features" / "plan completion" / "what's left before this is shippable" / "build the next phase" / "where am I" + **capability that was never built** (not a defect in code that already exists) | `/roadmap [<scope>]` |
| "audit" / "review" + **multi-axis** (architecture + SOLID + security + DB + perf + scale) / "engineering principles" / "system design" / "ready for traffic" / "scale to N RPS" / "production hardening" / "pre-launch **hardening** sweep" (an unqualified "pre-launch sweep" is ambiguous — see the sweep row below) | `/audit [<scope>] [--target-rps=<N>]` |
| "align" / "convention drift" / "cleanup conventions" / "match design system" + whole-project / multi-area scope | `/align [<scope>]` |
| "unify" / "harmonize" / "make consistent" / "consistent codebase" / "uniform" / "standardize" / "single way" / **"some-X-some-Y"** ("some in one way and some in another", "half the files do X and half do Y") + codebase / project / module scope, **and the remedy is applying a convention the project already documents in place** — no API surface, and no one surface type that has to converge on one wrapper | `/align [<scope>]` |
| "unify all tables" / "unify all forms" / "unify all headers" / "unify all tabs" / "unify all filters" / "unify all buttons" / "unify validation" / "every page has the same header" / "all list pages should share the same filter panel" / "every table chrome the same" / "standardize form validation" / "consistent error display across all forms" / "fully unified UI/UX system" / "make every X look the same" + **surface-type vocabulary** (tables / forms / headers / tabs / filters / buttons / validation), **and the remedy is that every instance of that type end up going through ONE canonical shared implementation** — extracted, extended, or migrated onto. For six of the seven categories that implementation is one shared wrapper; for **validation** it is the one 3-part pipeline (validator composable + error-rendering primitives + API-validation-error mapper — `commands/unify-surfaces.md § Validation pipeline`), which is why *"standardize form validation"* sits on this row even though no single wrapper comes out of it. This is also what *"some pages use the shared PageHeader and some roll their own"* asks for — the rolled-own headers get reconciled INTO the canonical shape | `/unify-surfaces [--surfaces=<list>] [<scope>]` |
| "match the original structure" / "match the gold standard" / "follow the existing pattern" / "use the shared wrapper instead of custom" / "stop reinventing" / "one canonical way" + codebase / project scope, **and the shared thing already exists and is adopted as-is** — nothing about it is extracted, extended, or re-shaped (if every instance of one surface type has to converge on one canonical shared implementation, that is `/unify-surfaces` — see the row above) | `/align [<scope>]` |
| "the buttons ignore our spacing tokens" / "half the forms skip the focus-ring rule" / "these pages don't follow our documented naming convention" — a **surface noun appears but the wrapper is not what changes**: a token, a11y rule, naming rule, or layer boundary the project ALREADY documents gets applied in place | `/align [<scope>]` — a surface noun on its own never routes to `/unify-surfaces`; the remedy does. Same enforce-existing carve-out as [`templates/tool-adapters/_orchestration-sync.md § Command boundary table`](../templates/tool-adapters/_orchestration-sync.md) rows *Design-token drift* and *Accessibility* |
| "camelCase on some endpoints and snake_case on others" / "the response shape differs per endpoint" / "our error shape is different everywhere" / "pagination is inconsistent" / log-field / metric-name / envelope drift + **API-surface vocabulary** — API / endpoint / schema, and equally the contract nouns *envelope*, *response shape*, *error shape* / *error contract*, *pagination*, *log field*, *metric name*, each of which names the API surface on its own | `/polish [<scope>]` — envelope, error-contract and API-naming uniformity are `/polish`'s owned classes; `/align`'s closed verb set has no envelope verb, and its `rename` only applies a convention the project already documents rather than choosing one for an API surface, so it would accept the job and have nothing to close it with |
| "drift" / "inconsistencies" / "fork(s) of the same thing" / "duplicate implementations of X" / "all over the place" / "inconsistent naming" / "mixed patterns" + multi-area scope, **and no API surface**, **and no one surface type that has to converge on one wrapper** (see the rows above) | `/align [<scope>]` |
| "align" / "drift" / "unify" / "harmonize" / "make consistent" + **single area**, narrow scope (one page, one module, one file) | `/align-recheck <description>` (align pack) |
| "port" / "migrate" / "match V1" / "compare V1" + whole-project / multi-feature scope | `/migrate [<scope>]` |
| "port" + single feature, narrow scope | `/migration-recheck <description>` (migration pack) |
| "refactor" / "extract" / "rename" / "move" / "flatten" + **specific file / module / symbol** (narrow target) | `/refactor <target>` |
| "optimize" / "clean up" / "improve quality" + whole-project / multi-area scope | `/optimize [<scope>]` |
| "clean up" + **ambiguous** (could mean one named target vs one module vs the whole codebase) | Ask one question — `/optimize` owns the phrase "clean up" and is the default reading: one named file / symbol → `/refactor`; whole-project or multi-area sweep → `/optimize`; convention drift in one narrow area → `/align-recheck`; visual polish on one surface → `/enhance-ui` |
| "pre-launch sweep" / "ship-readiness sweep" / "we ship <day> — sweep it" + **no axis noun** (neither hardening / security / scale nor finish / look-and-feel) | Ask one question: security / scale / correctness hardening → `/audit`; look-and-feel or API-surface finish → `/polish`; capability still missing → `/roadmap` |
| "unify" / "consistent" / "harmonize" + **ambiguous** (could mean drift vs perf vs arch vs surface-type) | Ask one question: surface-type unification (tables / forms / headers / tabs / filters / buttons / validation across the project) → `/unify-surfaces`; convention drift / inconsistent patterns → `/align`; architecture / SOLID / clean code → `/optimize`; production-readiness / scale → `/audit` |
| "iterate" / "try variants" / "few options" + visual | invoke `design-iterate` skill |
| "playground" / "test in isolation" + component | invoke `component-playground` skill |
| "deploy" / "ship to staging" / "release" | `/deploy-stage` |
| "rollback" / "revert deployment" | `/rollback-deploy` |
| "test" / "run tests" / "coverage" | `/run-tests` |
| "scan" / "inventory" + V1↔V2 | `/migration-scan` |
| "scan" / "inventory" + alignment / drift | `/align-scan` |
| the user **names another AI coding CLI as the implementer** ("have Codex take a crack at it", "delegate this to Cursor", "run it through Aider", "get a second opinion from another CLI", "burn the cheap CLI's quota on this", "cross-tool diff") | `/delegate "<task>" --to=<cli>` |
| "set up Claude orchestration here" / "analyze this codebase and generate tooling" / "refresh my setup" / "install the packs" | `/setup-project` |
| "add Cursor / Windsurf / Cline support to this repo" / "re-sync the adapters" / "push my rule changes out to the other tools" / "make this repo work without .claude/" | `/setup-project-adapters` |
| "is my setup stale" / "check setup health" / "are my conventions still in sync with the code" / "why does setup say there is no work to do" + **read-only report, no fixes** | `/setup-project-health` |
| a task-tracker **URL / key / `next`** (`trello.com/c/…`, `*.atlassian.net/browse/PROJ-123`, `linear.app/…/issue/ABC-123`, `github.com/…/issues/N`, bare `PROJ-123` / `#42`, `trello:`/`jira:`/`linear:`/`gh:` prefix, or "the next ticket / next card") | `/task <ref>` |

For ambiguous descriptions, the agent asks one clarifying question.

> **Precedence when two rows both match.** Resolve the collision by **what has to change to close the ask** — never by how many trigger phrases fire, and never by which nouns happen to appear. (1) If one **surface type** — tables / forms / headers / tabs / filters / buttons / validation — has to end up behind ONE canonical shared implementation that gets extracted, extended, or migrated onto, that is `/unify-surfaces`. "Shared implementation", not "wrapper", because six of the seven categories converge on one wrapper and **validation converges on one 3-part pipeline** (composable + error primitives + API-error mapper); a literal one-wrapper test would route *"standardise form validation everywhere"* nowhere, since `/align` is barred from wrapper-class work and `/polish` is barred from surface-type consolidation. (2) If an **API / endpoint / schema** surface has to be given a canonical envelope, error contract, page shape, or case convention it does not have yet, that is `/polish`. (3) If what changes is something the project **already documents** — a token, an a11y rule, a naming rule, a layer boundary, an already-named shared helper — applied in place with the wrapper left alone, that is `/align`, **whether or not a surface noun appears in the sentence**. Worked case A — *"some pages use the shared PageHeader and some roll their own"* fires the `some-X-some-Y` row, the "stop reinventing" row **and** the surface-type row. The rolled-own headers have to be reconciled into one canonical `<PageHeader>`, which is wrapper work `/align` is barred from — `align-discipline.md § Per-finding audit` halt 10 refuses a fix that introduces a new shared helper and halt 5 refuses net-positive lines on a structural finding — so the answer is `/unify-surfaces`. Worked case B — *"our buttons ignore the spacing tokens on the auth pages"* names a surface type just as squarely, but no wrapper changes and the token already exists, so the answer is `/align`. A surface noun is evidence, never the verdict. The enforce-existing half of this split is the *Design-token drift* and *Accessibility* rows of [`templates/tool-adapters/_orchestration-sync.md § Command boundary table`](../templates/tool-adapters/_orchestration-sync.md), and that file's *Surface-type consolidation vs generic drift* row now states this same remedy test — including Worked case B — so the twelve tool adapters that cite it route *"our buttons ignore the spacing tokens on the auth pages"* to `/align` exactly as this table does.

> The spec-layer rows (`/analyze-task`, `/expand-task`) apply only when the **business pack** is installed — same "scoped to commands that exist in this project" rule as everything else. If the business pack is absent, fall back to the closest available command (e.g. `/refine-prompt` for spec shaping, or `/add-feature` / `/scaffold-project` for the downstream build).

> The SOLID / clean-code / architecture vocabulary the `/optimize` and `/audit` routes enforce is defined canonically in `templates/governance/core-discipline.md` — this router points at those commands rather than restating the discipline.

## Pre-requisites

- A project with at least some commands installed (otherwise `/do` has nothing to route to).
- The agent has read `_extracted-codebase.md` to know the project's stack.

## Phase 1 — Understand (the ask)

1. **Parse intent** — the agent reads the description and uses semantic understanding (NOT regex / keyword tokenization) to identify:
   - **Action verb** (the user's primary intent: enhance / add / fix / audit / port / etc.).
   - **Target noun** (what's being acted on: sidebar, endpoint, query, etc.).
   - **Stack hint** (frontend UI vs backend API vs data layer).

2. **Read project context**:
   - `.claude/_extracted-codebase.md § Gold standards` — PROJECT_KIND.
   - `.claude/_extracted-idioms.md` — known UI surfaces, modules, patterns.
   - `.claude/commands/` — what's actually available in this project.

3. **Match** — pick the most likely command from the routing table above, scoped to commands that exist in this project.

4. **Confidence check**:
   - **High confidence** (intent + target + stack all align) → dispatch silently with a 1-line preamble.
   - **Medium confidence** (intent clear but target ambiguous, OR stack unclear) → ask one clarifying question.
   - **Low confidence** (description doesn't match any command's scope) → halt with the description echoed and a list of available commands.
   - **Multi-ask** (the sentence carries two independent asks — the halves route to different commands) → **always confirm**, even when each half is individually high confidence. See § Multi-command asks.
   - **Two rows both match one ask** → this is not ambiguity, it is precedence: resolve by the noun per the precedence note under the routing table, and dispatch. Only ask when the ask carries no disambiguating noun at all.

## Phase 2 — Organize (decompose the work)

```
1. PARSE       — extract action + target + stack from description
2. READ-CTX    — codebase profile + idioms + available commands
3. ROUTE       — match intent to command
4. CONFIRM     — silent (high confidence) | ask (medium) | halt (low)
5. DISPATCH    — invoke the picked command(s), the matching clause forwarded verbatim
               (two commands only via § Multi-command asks — always confirmed, never silent)
6. RECORD      — log the dispatch in ai/_history.md (audit trail)
```

## Phase 3 — Retrieve (read the right context)

- `.claude/_extracted-codebase.md` — PROJECT_KIND, module list.
- `.claude/_extracted-idioms.md` — known surfaces (sidebar, header, etc.).
- `.claude/commands/` — directory listing, descriptions read for routing.
- Recent `ai/_history.md` entries — pattern from prior dispatches.

## Phase 4 — Generate (produce the output)

For high-confidence dispatch:

```
/do enhance the sidebar with cleaner padding

→ Routed to: /enhance-ui the sidebar with cleaner padding
  Confidence: HIGH (action="enhance" + target="sidebar" + stack="frontend-vue")
  Dispatching...

[/enhance-ui's output follows]
```

For medium-confidence (ambiguous target):

```
/do clean up the orders module

Could mean:
  [1] /optimize the orders module          (code quality + architecture — the default reading;
                                            /optimize's own description claims "clean up")
  [2] /align-recheck the orders module     (convention drift only, no arch or perf angle)
  [3] /enhance-ui the orders pages         (UI/UX polish)
  [4] /migration-recheck the orders module (V1↔V2 parity drift)

Which? [1 / 2 / 3 / 4 / cancel]
```

For low-confidence:

```
/do automate the deployment notification webhook

No matching command found. Available commands relevant to "deployment":
  /deploy-stage     - deploy to staging environment
  /add-ci           - add CI workflow
  /dockerize        - add Dockerfile

For "automate" + "webhook" — this looks like a new feature.
Suggested: /add-feature automate the deployment notification webhook

Proceed with /add-feature? [y / n / different command]
```

### Multi-command asks (one sentence, two commands)

The premise above promises routing "when one sentence spans several commands", so this is the mechanism that keeps that promise. A sentence spans several commands when it carries **two independent asks that no single command's scope covers** — *"the orders page has no empty state and the buttons are all different sizes"* is a missing-finish ask (`/polish` owns `wire-empty-state`) **plus** a surface-type consolidation ask (`/unify-surfaces` owns the buttons category). Routing the whole sentence to either one silently drops half the ask.

Rules:

1. **Split at most three ways.** Four or more sub-asks is a wish-list, not a request — halt and ask which one to run first.
2. **Never split silently.** Multi-dispatch is always confirmed, even when both halves are individually HIGH confidence: the user asked once and is about to get two runs and two sets of commits.
3. **Order by dependency, not by mention order.** Structure before finish (consolidate the wrapper, then polish it — polishing five shapes that are about to become one is wasted work), foundations before cosmetics. Same rationale as the afterburner sequence in [`templates/tool-adapters/_orchestration-sync.md § Afterburner sequence`](../templates/tool-adapters/_orchestration-sync.md).
4. **Run sequentially with a gate between.** The second command starts only after the first returns. If the first halts, surface that and do NOT start the second.
5. **Forward only the matching clause.** Each command receives the part of the sentence that routed to it, verbatim — not the whole sentence. A `/polish` run told about button variance will try to fix it and cross the boundary.
6. **Log one `ai/_history.md` line per dispatch**, both carrying the same original description so the pair is reconstructable.

```
/do the orders page has no empty state and the buttons are all different sizes

Two asks in one sentence:
  [1] /unify-surfaces --surfaces=buttons   (button variance app-wide — surface-type consolidation)
  [2] /polish the orders page              (missing empty state — finish that does not exist yet)

Order: [1] then [2] — unify the button primitive first so polish finishes one shape, not five.

Run both? [y / only 1 / only 2 / cancel]
```

If one half matches no command, run the half that does and report the other as unrouted — never invent a command for it (see Hard rules).

## Phase 5 — Update (persist changes)

- `ai/_history.md` — one-line entry per dispatch: `<iso> /do "<description>" → /<routed-command>`.
- All other persistence is the routed command's responsibility.

## Phase 6 — Validate (verify correctness)

- Routing is deterministic for high-confidence cases — re-running the same description routes to the same command.
- Ambiguous cases halt for confirmation; never silently pick.
- Low-confidence cases halt with available commands listed.

## Phase 7 — Improve (feed the learning loop)

- If the same routing happens 5+ times, surface "you might want to call `/X` directly to skip the routing step."
- If routing fails consistently for a description pattern, add it to the routing table (file as a docs improvement).
- If a description routes to "no matching command," that's a gap — log to `ai/dynamic/learned-patterns.md` for future pack expansion.

## Hard rules

- **No silent dispatch on medium/low confidence, or on any multi-ask.** Always confirm or list options.
- **Never invent commands.** Only routes to commands that exist in `.claude/commands/`.
- **Forward verbatim — never paraphrase.** The routed command receives the user's own words, not a re-worded version. On a single-command route that is the full original description. On a multi-ask (§ Multi-command asks) each command receives its **own clause, still verbatim** — splitting the sentence at the boundary between two asks is not paraphrasing; rewriting either half is.
- **Log every dispatch.** The audit trail in `ai/_history.md` lets the user see what got routed where.

## Failure modes

- **No commands installed** — halt; route user to `/setup-project --include=<pack>`.
- **Description is empty** — halt; require non-empty arg.
- **Description matches multiple commands equally** — halt; show options.
- **Routed command halts** (e.g., its own intent gate fires for an even-more-specific routing) — re-surface to user with both routings explained.

## Examples

### High-confidence (silent dispatch)

```
/do enhance the navigation header
→ /enhance-ui the navigation header
```

```
/do add a refund button to order details
→ /add-feature add a refund button to order details
```

```
/do fix the crash on order filter
→ /fix-bug fix the crash on order filter

/do unify all tables and forms across the codebase
→ /unify-surfaces --surfaces=tables,forms

/do every page should have the same header and tabs
→ /unify-surfaces --surfaces=headers,tabs

/do standardize form validation and error display everywhere
→ /unify-surfaces --surfaces=validation

/do what's left before this is shippable?
→ /roadmap
  (missing capability, not a defect — /audit would rank what is WRONG, which is not the ask)

/do have Codex take a crack at the test backfill
→ /delegate "backfill the missing unit tests" --to=codex
  (the human named the implementer — that is the only trigger /delegate has)

/do push my rule changes out to Cursor and Windsurf
→ /setup-project-adapters
  (wiring a tool up is NOT dispatching to one — /delegate declines this by its own anti-trigger)

/do the setup feels stale — are my conventions still in sync with the code?
→ /setup-project-health
  (read-only; the fix door is /setup-project --refresh)
```

### Medium-confidence (asks)

```
/do clean up the auth module
  [1] /optimize the auth module (code quality + architecture — default reading of "clean up")
  [2] /align-recheck the auth module (drift cleanup)
  [3] /enhance-ui the auth pages (visual polish)
  [4] /migration-recheck the auth module (V1↔V2 parity)
```

### Low-confidence (halts with suggestions)

```
/do make the dashboard more interactive
→ "interactive" doesn't directly match a command's scope.
   Suggested next:
   - /add-feature make the dashboard more interactive (treats it as new functionality)
   - /enhance-ui the dashboard (treats it as visual polish)
   - Be more specific: "add filtering", "add sorting", "add live updates"
```

## Related

### Sibling commands (this command routes to)
- `/migrate`, `/align`, `/optimize`, `/polish`, `/audit`, `/unify-surfaces` — top-level simple-surface (whole-project / multi-area)
- `/roadmap` — map what is INTENDED but not yet built, then phase the build order (the complement of `/audit`: what is *missing*, not what is *wrong*)
- `/add-feature`, `/add-page`, `/add-component`, `/add-endpoint`, `/add-module`, `/add-migration`
- `/enhance-ui`, `/fix-bug`, `/align-recheck`, `/migration-recheck`
- `/analyze-task`, `/expand-task`, `/refine-prompt` — spec layer (business pack: idea → requirements / user stories → implementer-ready brief)
- `/security-audit`, `/perf-audit`, `/i18n-audit`, `/a11y-audit`, `/design-review`
- `/run-tests`, `/deploy-stage`, `/rollback-deploy`
- `/migration-scan`, `/align-scan`
- `/task` — provider-agnostic task executor (Trello / Jira / Linear / GitHub Issue → execute → write status back)
- `/delegate` — hand ONE bounded task to a DIFFERENT AI coding CLI, then review its diff (routes here only when the human names the other tool)
- `/setup-project`, `/setup-project-adapters`, `/setup-project-health` — install / re-sync / grade this repo's orchestration layer (the setup layer `/do` itself depends on)

### Skills (this command can dispatch via)
- `design-iterate`, `component-playground`

### Discipline note
`/do` is a thin orchestrator — it does NO work itself. The dispatched command applies its own discipline. If you want to bypass `/do` for any reason (you know the exact command, you want to pass specialized flags, etc.), call the specialized command directly. `/do` is for ergonomics, not enforcement.
