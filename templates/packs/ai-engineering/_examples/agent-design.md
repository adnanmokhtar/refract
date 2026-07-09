---
name: agent-design
description: 'Pattern: Agent Design — autonomy, tools, loop budgets, human-in-the-loop'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: Agent Design

> **Hard rule:** Use an **agent** (LLM chooses its own control flow + tools + stop) only when a fixed **workflow** (deterministic steps, LLM at nodes) can't express the task — agents buy flexibility with cost, latency, and nondeterminism. Every agent loop has a hard **budget** (max steps + token cap + timeout + cost ceiling); every **write/delete/spend/send** tool passes a confirmation-or-policy gate before firing. Unbudgeted loop = runaway incident; unguarded destructive tool = Excessive Agency (LLM06). This designs the loop; `@llm-security-reviewer` secures it.

**When to apply** — steps unknowable up front (model decides next move from results), large context-dependent tool set, genuine act→observe→re-plan iteration.

**When NOT to** — known/stable steps are a **chain**; fixed intents are a **classifier + switch**; one prompt with structured output needs no loop.

**Halt conditions / mandatory cites**
- Agent loop where a fixed workflow fits MUST cite the step sequence at `<path:line>` — "feels agentic" isn't a reason.
- Effectful tool (write/delete/pay/send/exec) with no gate MUST be cited → `@llm-security-reviewer` LLM06.
- Loop with no max-steps AND no token cap AND no timeout MUST be cited.
- Unbounded context growth (every observation appended, never compacted) MUST be cited.
- Tool error thrown out of the loop instead of fed back MUST be cited.

## Autonomy ladder — pick the lowest rung that works

| Rung | Control flow | Use when |
|---|---|---|
| Single call | none | fits one prompt |
| Chain / workflow | **code** owns order | steps known + stable |
| Router | code, one branch | fixed set of intents |
| Agent (bounded) | **model** owns order, code owns budget | steps unknowable |
| Multi-agent | nested budgets | subtasks need isolated context/tools (last resort) |

Every rung up multiplies calls/cost/latency/failure surface. Default to the lowest; document why higher is required.

## Tool design — tools are the model's API

- **Name + description are load-bearing** — the model routes on them; name the effect, state when to use + what it returns.
- **Typed input schema, validated** at the boundary like untrusted input — the model hallucinates arguments.
- **Errors recoverable, not fatal** — return a structured error the model can read + retry; never `throw` out of the loop.
- **Least privilege per tool**; isolate destructive scope into its own gated tool.
- **Confirmation gate in code** on write/delete/spend/send/exec — a prompt instruction ("ask before deleting") is not enforcement.
- **Idempotent + returns result**; keep the tool set small (big menus degrade selection).

## The loop + budgets

Bound EVERY axis — one uncapped axis is the failure mode: **max steps**, **cumulative token budget**, **cost ceiling ($) kill-switch**, **wall-clock timeout**, **loop/no-progress detection** (break on repeated identical calls), explicit **termination condition** (structured "done" or validator, not just the model saying so). On any trip: return best-effort + signal budget-bound.

## Human-in-the-loop

Irreversible/high-value effects (delete, external send, payment, prod write, privilege change) need an explicit human/policy approval with a preview/diff. Tier by blast radius; log every approval (audit trail).

## Context management across steps

Don't append every observation forever (blows the window, re-pays for history each call, lost-in-the-middle). **Compact/summarize** past turns over a threshold; **externalize** big artifacts to a store and pass a handle; **scope** heavy subtasks to sub-agents with fresh context.

## Detectors (cite-or-halt)

- Agent loop over a knowable fixed sequence → `downgrade-to-workflow`.
- Effectful tool with no confirmation/policy gate → `add-tool-gate` (+ LLM06).
- Loop with no max-steps/token/timeout/cost budget → `add-loop-budget`.
- Context appended with no compaction → `add-context-compaction`.
- Tool that throws instead of returning a readable error → `make-tool-error-recoverable`.
- Tool args consumed unvalidated → `validate-tool-args`.
- Irreversible/high-value action with no approval step → `add-human-gate`.

**Closure verbs:** `downgrade-to-workflow`, `add-tool-gate`, `add-loop-budget`, `add-context-compaction`, `make-tool-error-recoverable`, `validate-tool-args`, `add-human-gate`.

## Related

- **Patterns (in-pack):** `llm-gateway` (tool/model calls route through it; budgets live there), `prompt-engineering` (tool descriptions + structured output), `evals` (trajectory eval — steps, tool-choice, success), `rag-pipeline` (retrieval as a tool).
- **Rule (in-pack):** `ai-engineering-principles`.
- **Cross-pack:** Excessive Agency / injection / output sinks → **security** `@llm-security-reviewer` (LLM06/05/01); tool downstream timeout/retry/circuit-breaker → **distributed-systems**/**backend**; step logging + cost + approval audit → **observability** (`tracing`, `audit-logging`).
