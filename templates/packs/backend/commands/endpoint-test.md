---
description: Hit a dev endpoint with curl and verify status + response shape via the endpoint-tester agent.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /endpoint-test [controller|method-path]

Diagnostic / read-only verification that a controller actually works end-to-end. Phases 1, 3, 6 dominate; 4 (Generate) produces only test calls; 5, 7 N/A.

**This command is a router, not a test harness.** The triad has one owner per job and this file states its own:

| Artifact | Owns |
|---|---|
| `.claude/skills/endpoint-test/SKILL.md` | The **mechanism** — curl invocations, the five mandatory cases, the conditional cases, the field-by-field diff against the response DTO. |
| `@endpoint-tester` (agent) | **Case selection and verdict** — which tier applies, which conditional cases are in scope, PASS / FAIL / LEAK. |
| This command | **Argument resolution, the hand-wave halt, and escalation routing.** |

Anything below that restates a case, a curl flag, or an assertion belongs in the skill, not here. If you find yourself editing this file to change what a call asserts, you are editing the wrong file.

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves.** This command pokes a live dev server and reports what the wire actually does. The whole value is empirical: status codes, response shapes, headers — observed, not assumed. A response shape claimed without the actual JSON is a hypothesis dressed as a finding. A "200 OK" claimed without the actual status line is a fabrication.

**This command does NOT:** run curl inline (it always delegates), report "the endpoint returns the expected shape" without quoting the body, or accept a run in which a mandatory case was skipped to save time.

## Phase 1 — Understand (argument resolution)

- `<controller-name>` → list every route on that controller, ask which one.
- `METHOD /path` (e.g. `POST /users`) → use directly.
- No arg → read the recent `git diff` for changed controllers; ask if more than one matches.
- Resolve the base URL and dev port from `CLAUDE.md`. If the server is unreachable, **stop and ask the user to start it** — this command refuses to auto-start anything (side effects).
- **Refuse** any non-localhost target without an explicit dev-tunnel approval recorded this session, and any `PROD_*` credential source.

## Phase 2 — Organize (tier selection)

Default to the lightest tier that fits. Heavy ceremony is opt-in — the agent does NOT pre-emptively pick heavy "to be safe."

| Tier | Triggers | Scope handed to the agent |
|---|---|---|
| **Trivial** (default) | Single endpoint, known DTO, internal route. | The five mandatory cases (`endpoint-test/SKILL.md` § Procedure, step 6) and nothing else. No conditionals, no follow-up dispatch unless a leak or replay break surfaces. |
| **Standard** | Controller sweep, or a write path / auth-protected / multi-tenant resource. | Mandatory five per route, plus every conditional case whose signal the contract actually declares. The agent picks them from its signal → case table (`@endpoint-tester` § Case selection) and cites the declaration that put each in scope; this command does not enumerate them. |
| **Heavy** | Public API surface, webhook, or payment endpoint. | Standard's scope, plus the two agent-owned cases run *unconditionally* instead of signal-gated: content negotiation (`@endpoint-tester` § Content negotiation) and tenant side-effects (§ Tenant side-effects). On a surface the public can reach, a missing declaration is not evidence of correct behaviour. |

Signature tampering and stale-key replay are **not this triad's cases** and must not be handed to `@endpoint-tester` as if they were — nothing in the skill or the agent implements them. They belong to `/simulate-webhook --tamper` in the webhook domain (`domains/webhook/rules/webhook-signature-verification.md` § Enforcement). On a Heavy-tier webhook route, dispatch that command if the domain is installed; if it is not, the report carries `signature cases NOT RUN (webhook domain absent)` — never a claim of coverage.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Endpoint-specific: the controller file (route decorators, guards, pipes), the input DTO, the output DTO, and any declaration that puts a conditional case in scope (limiter binding, `ETag` emission, `202` offload, streaming transport).

## Phase 4 — Generate (dispatch)

Dispatch `@endpoint-tester` with the resolved spec: method, path, headers, minimal valid body, expected response, tier, and the in-scope conditional cases. The agent runs the skill and returns a results table plus a replayable curl block. No code is written.

If `@endpoint-tester` is not installed in this project, run `.claude/skills/endpoint-test/SKILL.md` directly and apply this command's halt and routing rules to its output — never silently skip the verification.

## Phase 5 — Update — N/A
Read-only. No state changes, no knowledge persistence.

## Phase 6 — Validate (the hand-wave halt, then routing)

**Mechanical gate, all tiers.** Before printing anything, grep the returned report for hand-wave tokens: `etc.`, `...` used as "and similar", `usual fields`, `expected shape` (without the literal shape quoted), `looks correct` (without the literal body quoted), `among others`, `several headers`, `various status codes`.

Any hit outside a quoted curl output **halts the report**. The finding is replaced with the literal observed value — quoted JSON body, listed header keys, exact status line — or dropped. Paraphrase is forbidden; the wire is the truth.

Then route by what came back:

| Observation | Route |
|---|---|
| Cross-tenant case returned `2xx` | **CRITICAL leak.** Halt, surface as a blocker, route to `/security-audit`. Never downgraded to "dev mode". |
| Idempotency replay created a fresh resource | Idempotency broken → `/fix-bug`. |
| `500` with no body | `/log-tail correlation:<id>` to capture context, then `/fix-bug`. |
| Status green but the body diverges from the DTO | Phantom success → `/fix-bug`. A `200` is not a pass. |
| Edits not reflected in responses | Stale dev server → restart and re-run. A phantom pass is not a pass. |

## Phase 7 — Improve — N/A
Diagnostic. Discoveries get filed by the follow-up `/fix-bug` or `/security-audit`.

## Output format
```
## /endpoint-test — <method> <path> — <PASS | FAIL | LEAK>

Phase 1 (Understand): <route resolved> | base=<url> (SAFE — localhost)
Phase 2 (Organize):   tier=<trivial|standard|heavy>; conditional cases in scope: <list or none>
Phase 4 (Generated):  dispatched via @endpoint-tester
Phase 6 (Validated):  <per-case result + verdict>

Status: COMPLETE | BLOCKED on <X>

Open follow-ups:
  - <e.g. "tenant leak — invoke /security-audit">
```

## Related

### Sibling commands — where the boundary falls
- `/add-endpoint` — produces the routes this command verifies. Its production-readiness gate is a static claim; this run is the wire evidence for it.
- `/trace-flow` — the static counterpart. That one reads the call chain without running it; this one runs it without reading it. A disagreement between the two is itself the finding.
- `/log-tail` — where a `500` with no body goes next: this command observes the status line, that one recovers the context behind it.
- `/fix-bug` — every FAIL row this run produces routes there; a LEAK row routes to `/security-audit` first and is never downgraded.

### Patterns
- `ai/patterns/api-contract.md`
- `ai/patterns/error-handling.md`
- `ai/patterns/rate-limiting.md`
- `ai/patterns/conditional-requests.md`
- `ai/patterns/async-job-offload.md`

### Rules
- `.claude/rules/backend-principles.md`
