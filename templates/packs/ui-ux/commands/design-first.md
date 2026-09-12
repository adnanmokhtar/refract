---
description: "The design-first front door. One command for 'I want a design to look at' — it asks the one question only you can answer (does this surface stay inside our design system, or leave it), runs the one test you must NOT be asked (is the fault this page's composition or the app's visual language), and routes to /redesign, /art-direct, /clone-design or design-canvas accordingly. Every path ends on a CANVAS someone approves before any code is written. It writes nothing itself — no product code, no artboards. Frontend / mobile, plus greenfield surfaces with no code yet."
kind: command
pack: ui-ux
allowed-tools: [Read, Grep, Glob, Bash]
---

# /design-first <scope> [<more>...]

> **Not this command? (ANTI-triggers)** — you already know which command you want → **call it directly**; this one is pure routing overhead once the choice is made. "Change the app, I'll review the diff" → the specific command, without the canvas gate. A generic request spanning packs ("add a refund button") → **`/do`**, the global router. Tell me what's wrong, change nothing → **`/design-review`**. Full map: [`ui-sweep.md § The ui-ux command map`](ui-sweep.md).

> **Name note.** Claude Code ships its own bundled `design` skill; this command is deliberately **not** called `/design` so the two never contend for the same invocation. The bundled skill is one of the two renderers `design-canvas` can use — see that skill's § Premise.

## The Premise (read this first, internalize, do not deviate)

**One front door for "I want a design", and one promise behind it: nothing gets built before there is a picture someone approved.**

This command writes **nothing**. Not product code, not artboards, not tokens. It resolves *which* of the pack's design paths your ask belongs to and dispatches, with the canvas gate switched on. Its entire value is that it asks you exactly one question, runs one test rather than asking it, and never leaves you on a path that writes code before you have seen the design.

The failure it prevents is the one that costs the most: the eleven-command map in `ui-sweep.md` is correct and complete, and someone who does not already know the map picks by keyword, lands on `/enhance-ui` when they wanted a redesign, and gets a tidier version of the layout they were trying to throw away.

## The one question, and the one test — and why they are different

This is the whole command. Everything else follows from these two.

**The question — ASKED, always, never inferred:**

> Does this surface stay inside the design system we already have, or is it allowed to leave it?
> **`system`** — match our tokens, our components, our density, exactly.
> **`independent`** — free of the repo: a landing page, a new product, a surface deliberately allowed its own look.

**The test — RUN, never asked:** [`redesign.md § Phase 1 — THE LANGUAGE-OR-COMPOSITION TEST`](redesign.md), from the baseline render plus the token source. Print its verdict; do not put it to the user.

They look similar and are opposite in kind:

| | The question (`$SOURCE`) | The test (language-or-composition) |
|---|---|---|
| Kind | a **permission** | a **diagnosis** |
| Who holds it | whoever owns the product | the evidence — a render and a token source |
| Can the user answer it? | **only** they can | no; it is the *output* of looking |
| So | asking is respecting authority | asking is offloading your work onto them |

Asking for the permission is not a shortcut. Asking for the diagnosis is. A run that asks "should we redesign the page or rethink the whole look?" has failed at its one job.

## Routing

Resolve `$SOURCE` first, then route. **Every row ends on a canvas.**

| `$SOURCE` | State of the surface | Route |
|---|---|---|
| `system` | exists; test says **composition** | **`/redesign <scope> --canvas`** |
| `system` | exists; test says **language** | **`/art-direct <scope> --canvas`** (evolve) |
| `system` | does not exist yet | **`design-canvas`** directly (`$SOURCE=system`), then `/add-feature` or `/redesign --from-canvas` once approved |
| `independent` | a reference was given (URL / screenshot) | **`/clone-design <ref>`** — fidelity to that reference is the metric |
| `independent` | "show me what's out there" | [`design-system-catalog.md`](../references/design-system-catalog.md) → the chosen system via `/clone-design` |
| `independent` | no reference, invent it | **`/art-direct <scope> --reimagine --canvas`** |

**When the scope spans several surfaces**, route once per feature, not once per screen, and say so: one canvas per feature is the readable unit ([`design-canvas` § 4](../skills/design-canvas/SKILL.md)).

## Args

- `<scope>` — a route, surface, feature area, `the whole product`, or a surface that does not exist yet. Same semantic resolution as `/redesign` + `/enhance-ui`.
- `--source=system|independent` — answer the question up front and skip the ask. Use it when you already know; do **not** let a caller default it (§ Hard rules).
- `--no-canvas` — route without the canvas gate, landing on the target command's normal prose gate. For when you are the only approver and a picture buys you nothing.
- `--plan` — universal handoff flag: print the routing verdict, the test's output, and the command it would run, then exit without dispatching.

```bash
/design-first orders/list                       # ask, test, route — probably /redesign --canvas
/design-first marketing/landing --source=independent
/design-first the whole product                 # per-feature routing, one canvas each
/design-first orders/list --plan                # just tell me where this goes and why
```

## Hard rules

- **Never infer `$SOURCE` for an in-repo surface.** HALT and ask. The one exception is an explicit `--source=`, which is the user answering in advance.
- **Never ask the language-or-composition test.** Run it, print the verdict, route on it.
- **Never write anything.** No code, no artboards, no tokens, no plan file except under `--plan`. If a route needs work done, it dispatches; it does not do the work "since it's small".
- **Never route past the canvas** unless `--no-canvas` was passed explicitly. The default is the whole point.
- **Route, then get out of the way.** The target command owns its own gates, halts and parity questions; this command does not re-ask them, summarize them away, or relax them.

## Failure modes

- **Asked the diagnosis instead of running it.** The single failure that makes this command worse than the map it fronts — it hands the user a question they cannot answer and dresses the guess as consultation.
- **Inferred `independent` from the word "new".** A new *screen* in an existing app is almost always `system`; "new" describes the surface, not the permission. Ask.
- **Routed `independent` + a reference to `/art-direct`.** `/art-direct` takes no external reference and will ignore a URL; the reference path is `/clone-design`.
- **Reached for the catalog to fill `/art-direct`'s three directions.** That is the borrowed-skin misuse [`design-system-catalog.md § The boundary`](../references/design-system-catalog.md) exists to forbid.
- **Did the work itself** because the ask "looked like a one-liner". This command has no build phase; a run that edits a file has left its contract.
- **Fronted a map it then contradicted.** When this command's routing and [`ui-sweep.md § The ui-ux command map`](ui-sweep.md) disagree, the map is canonical and this command is the bug.

## Cross-references

- [`ui-sweep.md § The ui-ux command map`](ui-sweep.md) — **canonical.** This command is a front door onto that map, never a second source of truth for it.
- [`/redesign`](redesign.md) — composition fault inside the existing language; owns the rebuild and `--canvas` / `--from-canvas`.
- [`/art-direct`](art-direct.md) — the language itself; owns `--reimagine` and `--canvas`.
- [`/clone-design`](clone-design.md) — an external reference is the source of truth; the `independent`-with-a-reference path.
- [`design-canvas`](../skills/design-canvas/SKILL.md) — what every route ends on, and the direct route for a surface with no code yet.
- [`design-system-catalog.md`](../references/design-system-catalog.md) — adoption starting points for the `independent` + "show me options" path.
- [`/do`](../../../../commands/do.md) — the global router. Use it when the ask is not specifically "give me a design".

## Stack scope

Frontend / mobile (`primary_frontend_framework_detected`), **plus** surfaces with no code yet and projects with no repo at all — the `independent` routes (`/clone-design`, `design-canvas`) are project-optional and stack-agnostic. A backend-only repo with an in-repo `system` ask still HALTs: there is no design system here to stay inside.
