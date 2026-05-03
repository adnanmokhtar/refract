---
description: Universal meta-router. Take any natural-language description ("enhance the sidebar", "add a refund button", "fix the order list crash", "audit security") and dispatch to the right specialized command. The agent reads the project's available commands, infers user intent, and either runs the matching command directly OR surfaces options for ambiguous cases. Single entry point — you don't need to know which command is right.
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
| "polish" / "enhance" / "improve" / "tighten" / "consistent" + UI sweep / whole project / module / page (no explicit variant ask) | `/polish [<scope>]` |
| "redesign" / "iterate" / "try variants" / "few options" / "different look" + single UI surface (creative iteration ask) | `/enhance-ui <description>` |
| "match colors" / "fix padding" / "cleaner spacing" + single UI surface (mechanical cleanup) | `/enhance-ui <description>` |
| "add" / "new" / "create" / "build" + UI noun (page / component / form / modal / etc.) | `/add-feature <description>` (frontend) |
| "add" / "new" + endpoint / route / API noun | `/add-endpoint <description>` (backend) |
| "add" / "new" + module noun | `/add-module <description>` |
| "add migration" / "new migration" | `/add-migration <description>` |
| "fix" / "broken" / "crash" / "error" / "wrong" / "regression" | `/fix-bug <description>` |
| "audit" / "review" + design / UX / a11y | `/design-review <path>` |
| "audit" / "review" + security / vuln | `/security-audit` |
| "audit" / "review" + perf / slow | `/perf-audit` |
| "audit" / "review" + i18n | `/i18n-audit` |
| "align" / "convention drift" / "cleanup conventions" / "match design system" + whole-project / multi-area scope | `/align [<scope>]` |
| "align" / "drift" + single area, narrow scope | `/align-recheck <description>` (align pack) |
| "port" / "migrate" / "match V1" / "compare V1" + whole-project / multi-feature scope | `/migrate [<scope>]` |
| "port" + single feature, narrow scope | `/migration-recheck <description>` (migration pack) |
| "refactor" / "extract" / "rename" / "move" / "flatten" + **specific file / module / symbol** (narrow target) | `/refactor <target>` |
| "optimize" / "clean up" / "improve quality" + whole-project / multi-area scope | `/optimize [<scope>]` |
| "clean up" + **ambiguous** (could mean tidy diff vs whole codebase) | Ask one question: narrow target → `/refactor`; broad sweep → `/optimize` |
| "iterate" / "try variants" / "few options" + visual | invoke `design-iterate` skill |
| "playground" / "test in isolation" + component | invoke `component-playground` skill |
| "deploy" / "ship to staging" / "release" | `/deploy-stage` |
| "rollback" / "revert deployment" | `/rollback-deploy` |
| "test" / "run tests" / "coverage" | `/run-tests` |
| "scan" / "inventory" + V1↔V2 | `/migration-scan` |
| "scan" / "inventory" + alignment / drift | `/align-scan` |

For ambiguous descriptions, the agent asks one clarifying question.

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

## Phase 2 — Organize (decompose the work)

```
1. PARSE       — extract action + target + stack from description
2. READ-CTX    — codebase profile + idioms + available commands
3. ROUTE       — match intent to command
4. CONFIRM     — silent (high confidence) | ask (medium) | halt (low)
5. DISPATCH    — invoke the picked command with the description forwarded
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
  [1] /align-recheck the orders module     (codebase quality drift)
  [2] /enhance-ui the orders pages         (UI/UX polish)
  [3] /migration-recheck the orders module (V1↔V2 parity drift)

Which? [1 / 2 / 3 / cancel]
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

- **No silent dispatch on medium/low confidence.** Always confirm or list options.
- **Never invent commands.** Only routes to commands that exist in `.claude/commands/`.
- **Forward the description verbatim.** The routed command receives the user's full original description, not a re-paraphrased version.
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
```

### Medium-confidence (asks)

```
/do clean up the auth module
  [1] /align-recheck the auth module (drift cleanup)
  [2] /enhance-ui the auth pages (visual polish)
  [3] /migration-recheck the auth module (V1↔V2 parity)
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
- `/migrate`, `/align`, `/optimize`, `/polish` — top-level simple-surface (whole-project / multi-area)
- `/add-feature`, `/add-page`, `/add-component`, `/add-endpoint`, `/add-module`, `/add-migration`
- `/enhance-ui`, `/fix-bug`, `/align-recheck`, `/migration-recheck`
- `/security-audit`, `/perf-audit`, `/i18n-audit`, `/a11y-audit`, `/design-review`
- `/run-tests`, `/deploy-stage`, `/rollback-deploy`
- `/migration-scan`, `/align-scan`

### Skills (this command can dispatch via)
- `design-iterate`, `component-playground`

### Discipline note
`/do` is a thin orchestrator — it does NO work itself. The dispatched command applies its own discipline. If you want to bypass `/do` for any reason (you know the exact command, you want to pass specialized flags, etc.), call the specialized command directly. `/do` is for ergonomics, not enforcement.
