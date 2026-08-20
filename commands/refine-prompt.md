---
description: Turn a rough idea, one-liner, or ticket into an execution-ready prompt file. Names the command to run it next, and is output-only by contract — it writes the prompt, never executes it. Trigger on 'refine this prompt', 'turn this one-liner into a proper brief before I run it', or when a richer input is wanted ahead of /scaffold-project or /audit. Do NOT trigger merely because a request is vague; vagueness alone routes to /do. Not when a spec already exists, not for a tracker ref (/task).
compatibility: Writes one file under ai/, so it is the wrong command for a sensitive idea that must stay off disk — refine those in conversation instead. Runs in any repo including an empty one, since the new-project class hands off to /scaffold-project. Names a target command but never invokes it, and stops at one confirmation gate.
kind: command
pack: orchestration
---

# /refine-prompt "<rough idea>"

Turn a vague ask into a **deep, execution-ready prompt** that any specialized command can run directly. Adversarial — surfaces unknowns instead of fabricating answers. Classifies the task, drafts a prompt shaped to that class's target command's input contract, and prints the exact `Run:` line. Saves to `ai/prompts/<YYYYMMDD>-<slug>.md` (the `new-project` class saves to `ai/ideas/` instead, so `/scaffold-project` reads it from its expected location).

**Output-only by contract.** This command produces a prompt; it never executes it. It tells you which command to feed the prompt to and stops. (If you want routing + execution from a raw description, that's `/do`. If you want a prompt artifact you can read, refine, and trigger yourself, that's this command.)

**Universal by design.** Unlike a single-template spec generator, this command detects the **task class** (Phase 1) and selects the matching **prompt contract** (Phase 2). A frontend-feature prompt carries surfaces / states / a11y / tokens; a backend-endpoint prompt carries the request/response contract / auth / idempotency; an audit prompt carries axes + target metrics. The new-project domain spec is one class among many — not the only shape.

## When to use

- You have a one-liner ("add a refund button", "the order list crashes", "audit security") and want a *deep* prompt before committing to the work.
- You want to read / edit / version a prompt before running it — not fire-and-route like `/do`.
- A stakeholder dropped an idea and you want a refined, execution-ready brief back.
- You're about to run a heavy command (`/scaffold-project`, `/audit`, `/migrate`) and want a richer input than a sentence.

## When NOT to use

- You just want it done now, no artifact — use `/do <description>` (routes + executes with the raw text).
- The exact command AND a complete brief are already in your head — call the command directly; refining adds a step.
- A spec already exists in `specs/`, `ai/prompts/`, or a tracker ticket — point at it, don't duplicate.
- The idea is sensitive / private and must not hit disk — refine in conversation, don't run this command (it writes a file).
- The task is a tracker ticket (URL / key / `next`) and you want it executed end-to-end — use `/task <ref>` (it fetches + normalizes + runs + writes status back). Use this command only if you want the *prompt* without execution.

## Phases applied

All 7, with **one final confirmation gate**:

1. Phase 1 — Understand (classify the task)
2. Phase 2 — Organize (pick the prompt contract + target command)
3. Phase 3 — Retrieve (read project context)
4. **Phase 4 — Draft + refine + sweep (single cycle, internal iteration, one user gate: "Ready to run?")**
5. Phase 5 — Update / save
6. Phase 6 — Validate
7. Phase 7 — Improve

## Phase 1 — Understand (classify the task)

Take the user's input as a quoted string (or stdin if `<rough idea>` is `-`). Use **semantic understanding, not keyword tokenization** to extract:

- **Action verb** — the primary intent (add / build / fix / audit / optimize / refactor / align / unify / port / migrate / polish / scaffold / spec).
- **Target noun** — what's acted on (sidebar, endpoint, query, module, whole project, a V1 feature).
- **Stack hint** — frontend UI vs backend API vs data layer vs mobile vs CLI (read `_extracted-codebase.md § Gold standards` for PROJECT_KIND when inside a project).
- **Scope** — single surface / single file / module / whole project.

Then assign exactly one **task class** from the table in Phase 2. Print a one-line restatement:

> *"You want to `<action>` `<target>` (`<class>`, target command `/<cmd>`) — drafting an execution-ready prompt."*

**Proceed directly** — this restatement is non-blocking. The user corrects it at the single Phase 4 gate. Do NOT pause here; a second pause would violate the one-gate rule.

If the input matches **no** class (genuinely novel work no command covers), say so plainly, draft a **generic** prompt (universal sections only, see Phase 4), and name `/do` as the fallback runner. Never force a wrong class.

## Phase 2 — Organize (prompt contract + target command)

The **task class** determines (a) which command will run the prompt and (b) which class-specific sections the prompt carries on top of the universal core. The class→command mapping is the same taxonomy `/do` routes by — this command produces the *deep prompt* that command expects as input, rather than executing it.

| Task class | Signal (action + target) | Target command | Class-specific prompt sections |
|---|---|---|---|
| `new-project` | "new app / from scratch / greenfield / build a `<product>`" | `/scaffold-project` | Full domain spec — personas, jobs-to-be-done, MVP in/out, data model, flows, non-functional, risks, deferred stack decisions (see template below) |
| `frontend-feature` | "add / build" + UI noun (page / component / form / modal / table) in an existing app | `/add-feature` (frontend) → fallback `/do` | Surface + route, component breakdown, **all states** (loading / empty / error / success), data needs, a11y (focus / keyboard / ARIA), responsive behavior, design-token usage |
| `backend-endpoint` | "add / new" + endpoint / route / API noun | `/add-endpoint` (backend) → fallback `/do` | HTTP verb + path, request schema, response envelope, validation rules, auth + permissions, error contract, idempotency, data-model touchpoints |
| `module` | "add / new" + module / service noun | `/add-module` → fallback `/do` | Responsibility boundary, public interface, dependencies, data ownership, layering |
| `bugfix` | "fix / broken / crash / error / wrong / regression" | `/fix-bug` → fallback `/do` | Repro steps, expected vs actual, suspected area (`<file:line>` if known), blast radius / regression risk, the failing assertion |
| `audit-multi` | "audit / review / production-ready / scale to N" (multi-axis) | `/audit [--target-rps=N \| --target-vitals=…]` | Axes in scope, scope path, target metrics, what "ready" means |
| `audit-focused` | "audit" + single axis (security / perf / a11y / i18n / design) | `/security-audit` \| `/perf-audit` \| `/i18n-audit` \| `/design-review` | The single axis, scope, the specific risk worried about |
| `optimize` | "optimize / clean up / improve quality" (whole project / multi-area) | `/optimize [<scope>]` | Scope, suspected hotspots, architectural smells, perf budget |
| `refactor` | "refactor / extract / rename / move / flatten" (specific file / symbol) | `/refactor <target>` | Exact target, the closed refactoring verb intended, behavior-preserve invariant |
| `align` | "align / unify / consistent / drift / harmonize" (convention drift, multi-area) | `/align [<scope>]` | Drift class, the canonical shape to converge on, scope |
| `unify-surfaces` | "unify all tables / forms / headers / validation" (surface-type) | `/unify-surfaces [--surfaces=…]` | Surface categories, the canonical wrapper, consumers in scope |
| `polish` | "polish / tighten / enhance" (whole UI / API / schema sweep) | `/polish [<scope>]` | Scope, the polish axes that matter most |
| `migrate` | "port / migrate / match V1" (whole project / multi-feature) | `/migrate [<scope>]` | V1 source area, V2 target, parity expectations |
| `migrate-spot` | "port / match V1" (single feature) | `/migration-recheck <desc>` | The single feature, V1 reference, the drift to fix |
| `spec` | "figure out what to build / requirements / user stories" (within a project) | `/analyze-task` (business pack) → fallback this command's generic shape | The feature, the unknowns, the stakeholders |
| `generic` | matches no class above | `/do <prompt>` | Universal sections only |

Pick exactly one class. If two plausibly fit (e.g. "clean up the orders module" — could be `refactor` or `optimize`), note both in the restatement and resolve at the final gate; default to the **narrower** class.

**Refinement weight** (controls depth + whether Phase 4 fans out):
- `light` — one surface, one file, a trivial add, a hobby idea → single inline pass, universal sections + the 1–2 most relevant class sections.
- `medium` / `heavy` — whole project, multi-axis audit, new project, contract-defining endpoint → parallel specialist fan-out in Phase 4.

## Phase 3 — Retrieve (read context)

Graceful-fallback reads — skip any that are absent (e.g. empty directory):

- `.claude/_extracted-codebase.md § Gold standards` — PROJECT_KIND, module list, stack (anchors stack-specific prompt sections).
- `.claude/_extracted-idioms.md` — known surfaces, wrappers, naming, error shape (so the prompt references *real* idioms, not invented ones).
- `.claude/commands/` — confirm the target command actually exists in this project; if absent, fall back per the table's `→ fallback` and say so.
- `ai/prompts/` and `ai/ideas/` — prior refined prompts / ideas; surface overlap, never duplicate.
- `ai/decisions/` — recent ADRs that constrain the idea space (new-project / spec classes especially).

For the `new-project` class, domain framework depth (B2C / B2B / marketplace / real-time) comes from the inline weighting in Phase 4 — no external template file required.

## Phase 4 — Draft + refine + sweep (single cycle)

Run draft → deep refine → adversarial sweep as **one internal cycle**. No inter-stage user pause; iterate silently, then surface ONE final gate.

Every refined prompt — regardless of class — opens with the **universal core**:

```markdown
# Execution-ready prompt — <slug>

> **Task class:** <class>   **Run with:** `/<target-command>`   **Weight:** <light|medium|heavy>

## Objective
<one sentence: what "done" looks like, observable>

## Context
<where this lives in the codebase / what exists today / why now — references real idioms from _extracted-idioms.md when inside a project>

## Scope — IN
- <in 1>
- <in 2>

## Scope — OUT (non-negotiable anti-goals)
- <explicitly not doing>

## Constraints
- <must reuse existing X / follow convention Y / perf budget Z / no new deps>
- **Read-before-write**: read the named files / `CLAUDE.md` / sibling module first; mirror the existing pattern before innovating.

## Pinned contracts (do NOT change)
- <external API / schema / public interface that is live and off-limits — exact shape>
- **If the task cannot be done without changing a pinned contract → STOP and report; do not edit it.**
  (Omit this section only when nothing external is pinned.)

## Acceptance criteria (testable)
- Given <…> when <…> then <…>.
- ...

## Verification & done
- <how to confirm it works: `/verify <route>`, the exact tests to run, lint + typecheck clean>
- <RTL / dark-mode / locale checks when relevant>

## Open questions (forced — at least 3)
- <unknown 1 — harvest every "verify / likely / if X" hedge from the body into here>
- <unknown 2>
- <unknown 3>
```

Then **append the class-specific sections** named in the Phase 2 row. Examples of the class blocks:

```markdown
<!-- frontend-feature -->
## Surface & route
<page / component, where it mounts, the route>
## Component breakdown
- <component> — <responsibility>
## States (all required)
- Loading: <…>  Empty: <…>  Error: <…>  Success: <…>
## Data
- <what it reads / writes, the shape, the source>
## Accessibility
- Focus order, keyboard paths, ARIA roles, contrast
## Responsive
- <breakpoints / behavior>
## Design tokens
- <tokens to use from the system — no hardcoded values>
```

```markdown
<!-- backend-endpoint -->
## Endpoint
<VERB /path>
## Request
- <field>: <type> — <validation>
## Response (success envelope)
- <shape, status code>
## Errors
- <code> → <when> → <message contract>
## Auth & permissions
- <who can call it; tenant scoping>
## Idempotency / side effects
- <idempotency key? retries? write-path safety>
## Data model touchpoints
- <entities / tables read or written>
```

```markdown
<!-- bugfix -->
## Repro
1. <step>
## Expected vs actual
- Expected: <…>  Actual: <…>
## Suspected area
- <file:line or module — if known>
## Blast radius / regression risk
- <what else this code path feeds>
```

```markdown
<!-- audit-multi / audit-focused -->
## Axes in scope
- <architecture / security / perf / scale / a11y …>
## Scope
- <path / whole project>
## Targets
- <--target-rps / --target-vitals / SLO — the number that defines "ready">
## Specific worry
- <the risk that prompted this>
```

For `new-project`, the class block is the full domain spec (personas, jobs-to-be-done, MVP in/out, inspirations, data model, user flows, permissions, non-functional, risks, assumptions, success metrics, and a final "decisions deferred to /scaffold-project" section). Mirror the depth a `/scaffold-project` run expects.

### Execution model — specialist fan-out (silent, internal; medium/heavy only)

After the universal core is drafted and saved, dispatch parallel specialist sub-agents via the Agent tool — **all in one message so they run concurrently** — one per class-specific section cluster. Each receives identical shared context (the Phase 1 restatement + class, the Phase 2 contract, the Phase 3 idiom/ADR notes, and the universal core) and returns **only** its section(s) as raw markdown — no preamble.

Choose the specialist set by class. For `new-project` use the domain-spec specialists (flows-and-permissions, data-model, non-functional, risk, metrics). For an implementation class (`frontend-feature` / `backend-endpoint` / `module`) use a contract specialist (the class block above) + an `acceptance-and-edge-cases` specialist + a `constraints-and-idioms` specialist that grounds the prompt in `_extracted-idioms.md`. For audit/optimize/migrate classes, a `targets-and-scope` specialist + a `risk` specialist.

**Model strategy — Opus reasons, Sonnet drafts.** Drafting specialists run on **`sonnet`** (parallel, bounded, contract-shaped — cheap at fan-out width). The final adversarial reconcile runs on **`opus`** (the hardest step — cross-section contradiction hunting). Pass the model explicitly via the Agent tool's `model` parameter (`model: "sonnet"` for specialists, `model: "opus"` for the reconcile). These overrides hold even under an `opusplan` session.

`light` weight does **not** fan out — it drafts the universal core + the 1–2 relevant class sections inline and runs the sweep inline. Fanning out for "add a dark-mode toggle" is exactly the bloat to avoid.

**Silent.** No specialist output is surfaced mid-run; the user sees only the final assembled prompt + the brief Phase-output status.

**No silent drops.** A specialist that returns nothing / errors → write its section as `<!-- specialist failed: <name> — re-run -->` and flag it in Phase 6. Never silently omit a section.

### Adversarial reconcile (final pass)

Re-read the whole prompt from a *contrarian* angle. For each section: What's missing? What contradicts another section? What's a "yes" that should be a "maybe"? What's an acceptance criterion with no matching scope item — or a scope item with no acceptance criterion?

**For `heavy` weight, run this as a dedicated reconcile sub-agent on `opus`** prompted to *refute the prompt's executability*: "find every claim a command could not act on — an acceptance criterion not traceable to a scope item, a state with no data source, an endpoint field with no validation, a constraint that contradicts the objective." Its findings sharpen the Open questions section. For `light`/`medium`, run this inline at the session model. Either way it is silent.

The reconcile pass also **fixes** (not just flags) three defect classes — re-emit the corrected prompt, never ship them:

- **Output integrity.** No corruption artifacts: no doubled punctuation (`::`, `;;`), no stray single-character tokens (`endpoints e —`), no truncated / concatenated words (`:idpoint`), no duplicated bullets or lines. Every identifier introduced once must be spelled **identically everywhere** (a permission key, URL, type name, or i18n key must not appear as both `affiliate_registrations.delete` and `a_registrations.delete`).
- **Snippet fidelity.** Any embedded code shape (component props, service generics, URL maps, route configs, object literals) must be **one canonical, internally-consistent shape grounded in the actual file read** — never two divergent guesses for the same thing (e.g. a `tabItems` entry shaped `{value: '/path'}` in one line and `{value: 1, path: '/path'}` in the next). When the real shape is unknown, write a single placeholder and a `// confirm against <file>` note, and lift the unknown into Open questions — do not invent a second guess.
- **Unknowns harvested.** Every inline hedge in the body ("verify which field…", "likely a `can()` helper", "if BaseCrudService demands…") is **moved into the Open questions section**, not left buried mid-instruction where an implementer skims past it.

**Final user gate.** Print the full prompt and the `Run:` line, then ask: **"Ready to run?"** Reply with:
- "yes" / "ship it" → continue to Phase 5.
- "fix X / revise Y" → re-enter Phase 4 internal iteration; do NOT re-pause until the next "Ready to run?".
- "stop" → save as-is, skip Phase 5.

Wait for confirmation OR auto-confirm if `--no-prompt` is passed (logged). This is the only Phase 4 user pause.

## Phase 5 — Update

- File saved at `ai/prompts/<YYYYMMDD>-<slug>.md` throughout phases (or `ai/ideas/<YYYYMMDD>-<slug>.md` for the `new-project` class — the location `/scaffold-project` reads).
- If running in a repo with `ai/dynamic/changelog.md` → append: `prompt refined: <slug> (<class> → /<cmd>)`.
- If running in a repo with `ai/status.md § Recent Changes` → append a bullet.

## Phase 6 — Validate

Report any check below it threshold; **flag, do NOT block**. The user accepts the light prompt or asks for an extension pass.

Universal checks (every class):
- Objective is one observable sentence (not "make it good").
- Scope IN and Scope OUT both non-empty (forces an explicit boundary).
- ≥1 acceptance criterion, each in given/when/then form and traceable to a scope-IN item.
- Verification & done section names a concrete check (a `/verify` route, the tests, lint + typecheck).
- Open questions ≥3 (forces honesty about unknowns); no inline hedge ("verify…/likely…/if X") left buried in the body.
- Constraints reference real idioms when inside a project (no invented APIs / wrappers).
- A pinned external contract (if any) carries the explicit "STOP and report, do not change it" rule.
- `Run:` line names a command that **exists** in this project (or a stated fallback).
- No section left as `<TBD>` / `<placeholder>`.
- No `<!-- specialist failed: … -->` markers remain.

Output-integrity checks (must be **clean** — the reconcile fixes these; Phase 6 asserts none survived):
- No doubled punctuation (`::`, `;;`), stray single-char tokens, or truncated / concatenated words.
- No duplicated bullets or lines.
- Every identifier (permission key, URL, type, i18n key, route name) spelled identically at every occurrence.
- Every embedded code snippet is syntactically valid and uses **one** canonical shape — no two divergent guesses for the same structure.

Class checks (the relevant ones):
- `frontend-feature`: all four states (loading / empty / error / success) present; a11y section non-empty.
- `backend-endpoint`: request + response + error contract + auth all present; idempotency stated for any write path.
- `bugfix`: repro steps present; expected-vs-actual present.
- `audit-*`: at least one concrete target metric or an explicit "no numeric target — qualitative" note.
- `new-project`: personas trace to jobs-to-be-done; ≥3 risks with mitigations; deferred-decisions section present.

For each unmet target, print a flag line (e.g. `frontend-feature: error state missing — flag for re-pass`). Phase 6 never refuses to ship.

## Phase 7 — Improve

- Print the natural next command, ready to paste (use `ai/ideas/…` for the `new-project` class, `ai/prompts/…` otherwise):
  ```
  Run: /<target-command> ai/prompts/<YYYYMMDD>-<slug>.md
  ```
  (For commands that take an inline description rather than a file path, print the prompt's Objective + key sections inline-ready, and note: "paste the prompt body as the description".)
- If a similar prompt exists in `ai/prompts/`, mention it for overlap review.
- If 3+ refined prompts share a class/domain, suggest a shared spec or a reusable template.

## Output format

```
## /refine-prompt — <slug>

Phase 1 (Understand): "you want to <action> <target>" — class=<class> (non-blocking; correct at final gate)
Phase 2 (Organize): target command = /<cmd>; refinement weight = <light|medium|heavy>
Phase 3 (Retrieved): N prior prompts scanned; idioms + M ADRs reviewed (if applicable); target command exists ✓ / fallback /<x>
Phase 4 (Draft + refine + sweep): universal core + <class> sections; <N> specialists on sonnet (skipped for light); adversarial reconcile on opus; single cycle; final "Ready to run?" gate confirmed
Phase 5 (Updated): prompt file saved; changelog + status.md updated (if applicable)
Phase 6 (Validated): universal + class checks reported; flagged where under target — user accepted
Phase 7 (Improved): Run-line printed; similar prior prompts flagged

Status: COMPLETE — ready to run /<cmd>
File: ai/prompts/<date>-<slug>.md (~<line count> lines)
Run: /<cmd> ai/prompts/<date>-<slug>.md
```

## Failure modes

- **"Just make it work" / "you decide everything"** — incomplete brief; refine pushes back via the Open questions section instead of inventing.
- **Wrong class forced** — a `bugfix` shaped as a `frontend-feature` produces a useless prompt. When two classes fit, name both at the gate and default to the narrower; when none fit, use the `generic` shape + `/do`.
- **Prompt that the target command can't act on** — an acceptance criterion with no scope item, a state with no data source. The adversarial reconcile exists to catch exactly this.
- **`Run:` line names a command not installed here** — the prompt is unrunnable. Phase 6 checks `.claude/commands/`; fall back per the Phase 2 table and say so.
- **Invented idioms** — a frontend prompt referencing a `<DataTable>` wrapper the project doesn't have. Ground every idiom in `_extracted-idioms.md`; mark unknowns as open questions.
- **Corruption artifacts** — `value::`, `:idpoint`, `endpoints e`, a permission key spelled two ways, a duplicated bullet. The output-integrity pass exists to catch and fix exactly these before ship; a prompt with them reads as careless and misleads the implementer.
- **Invented / inconsistent code shapes** — two different shapes for the same `tabItems` / props / service-generics, or a guessed component contract. Ground snippets in the real file or mark `// confirm against <file>` + an open question; never ship two divergent guesses.
- **Unknowns buried inline** — "verify which field…" left mid-instruction instead of in Open questions, where the implementer skims past it and builds on a guess.
- **Pinned contract editable** — a live external API / schema named but with no "do not change → STOP" rule, inviting the implementer to "fix" it.
- **One-pass without the final gate** → wrong direction caught too late. The single "Ready to run?" pause is non-negotiable.
- **Sections fabricated to look complete** → fictional prompt. Validation flags `<TBD>` markers.
- **Specialists run sequentially** → wasted wall-clock + lost independence. Dispatch all in one message.
- **Specialist output surfaced mid-run** → noise; breaks the silent contract. Only the final assembled prompt + status reach the user.
- **Fanning out on a light/trivial idea** → five agents for a one-liner. Light weight stays single-pass inline.
- **Executing the prompt** → scope violation. This command is output-only; it prints `Run:` and stops. Routing + execution is `/do`.

## Hard rules

- **Output-only.** Produce the prompt, save it, print the `Run:` line, stop. Never execute the target command. (Execution is `/do` / `/task`.)
- **Classify first.** Phase 1 assigns exactly one task class; Phase 2 maps it to a target command + prompt contract. A class-less prompt is a generic prompt routed to `/do`, never a fabricated wrong class.
- **One final confirmation gate ("Ready to run?").** Draft / deep refine / sweep iterate internally without inter-stage pauses. `--no-prompt` is the only skip, and it is logged.
- **Deep refine fans out to parallel specialists (medium/heavy weight).** Independent sub-agents dispatched in one message; the adversarial reconcile sharpens open questions. Light weight stays single-pass inline. Silent — discipline internal, output brief.
- **Opus reasons, Sonnet drafts.** Drafting specialists on `sonnet`; the adversarial reconcile on `opus`. Pass `model` explicitly; overrides hold under `opusplan`.
- **Execution-ready, not implementation-prescriptive.** The prompt states *what* and *acceptance*, grounded in real idioms — it does not write the diff. The target command writes the code.
- **Adversarial questioning, not stenography.** Surface contradictions; don't smooth them over. Open questions are mandatory (≥3).
- **Ground in reality.** Every referenced idiom, wrapper, module, file, **and code snippet** must trace to something real (per `_extracted-idioms.md` / `.claude/commands/` / the actual file). Unknowns become open questions; a code shape you can't confirm gets one placeholder + a `// confirm against <file>` note — never an invented or doubly-guessed shape.
- **Output integrity is non-negotiable.** The reconcile pass fixes corruption artifacts (doubled punctuation, stray/truncated tokens, duplicated lines), enforces one consistent spelling per identifier, and harvests buried inline hedges into Open questions before ship. Phase 6 asserts none survived. A strong prompt is clean prompt — these are bugs, not style.
- **Pin what's off-limits.** When the task names a live external contract (API / schema / public interface), the prompt must state "do NOT change it → STOP and report" explicitly.
- **Flag loudly, block never.** Phase 6 reports `<TBD>` / under-target / unrunnable `Run:` lines; the user decides whether to accept or re-enter Phase 4. (Output-integrity defects are the exception — those are *fixed* in reconcile, not shipped-and-flagged.)

## Related

- `/do <description>` — routes a raw description to the right command AND executes it. Use when you want the work done, not a prompt artifact. This command is its output-only, deep-prompt sibling.
- `/scaffold-project` — consumes a `new-project`-class prompt and produces a working repo.
- `/task <ref>` — fetches a tracker ticket, normalizes it to a spec, and runs it end-to-end (writes status back). Use for ticket-driven execution.
- `/analyze-task`, `/expand-task` (business pack) — feature-level specs / task breakdown WITHIN an existing project; the `spec` class falls back to `/analyze-task` when the business pack is installed.
