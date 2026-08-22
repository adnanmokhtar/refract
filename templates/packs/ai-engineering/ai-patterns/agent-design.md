---
name: agent-design
description: 'Pattern: Agent Design — autonomy, tools, loop budgets, human-in-the-loop'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: Agent Design

> **Hard rule:** Reach for an **agent** (an LLM that chooses its own control flow, tools, and stopping point) only when a fixed **workflow** (deterministic steps with an LLM at named nodes) cannot express the task — agents buy flexibility with cost, latency, and nondeterminism, and you pay all three on every run. Every agent loop MUST have a hard **budget** (max steps + token cap + wall-clock timeout + cost ceiling) and every tool with a **write / delete / spend / send** effect MUST pass a confirmation or policy gate before it fires. An agent loop with no budget is a runaway cost/incident; an unguarded destructive tool is an Excessive-Agency (LLM03:2026) exploit surface. This pattern designs the loop; the **security** pack's `@llm-security-reviewer` secures it.

**When to apply**
- The task's steps aren't knowable up front — the model must decide what to do next from intermediate results (open-ended research, multi-step debugging, "do X however it takes").
- The tool set is large and the right tool depends on context the model discovers mid-run.
- You genuinely need iteration: act → observe → re-plan until a goal condition is met.

**When NOT to apply (prefer a fixed workflow / single call)**
- The steps are known and stable — extract → validate → summarize is a **chain**, not an agent. Hard-code the DAG; put the LLM at the nodes.
- Routing among a fixed set of handlers is a **classifier + switch**, not an agent loop.
- A single prompt with structured output answers it. Don't add a loop to feel agentic.
- The task touches irreversible/high-value effects and you can't afford nondeterminism — constrain to a workflow with explicit human gates.

**Halt conditions / mandatory cites**
- An agent loop where a fixed workflow expresses the same task MUST be cited at `<path:line>` with the fixed step sequence it could be — "feels agentic" is not a justification.
- A tool whose implementation writes / deletes / pays / sends / executes with NO confirmation-or-policy gate MUST be cited at its definition + call site → cross-ref `@llm-security-reviewer` **LLM03:2026 Excessive Agency**.
- An agent loop with no `max_steps` AND no token cap AND no timeout MUST be cited — an unbounded loop is a cost/availability incident, not a style nit.
- Context that grows unboundedly across steps (every observation appended, never compacted) MUST be cited at the assembly site.
- A tool error that throws out of the loop instead of being caught and fed back to the model MUST be cited — a recoverable failure is being turned into a crash.

## Autonomy ladder — pick the lowest rung that works

| Rung | Shape | Control flow | Use when | Nondeterminism |
|---|---|---|---|---|
| **Single call** | one prompt → structured output | none | task fits one prompt | lowest |
| **Chain / workflow** | fixed DAG, LLM at nodes | **code** owns order | steps known + stable | low |
| **Router** | classify → dispatch to a fixed handler | code, one branch | fixed set of intents | low |
| **Agent (bounded)** | act→observe→re-plan loop, LLM picks tools + stops | **model** owns order, code owns budget | steps unknowable up front | high |
| **Multi-agent** | orchestrator + sub-agents | model, nested budgets | subtasks need isolated context/tools | highest |

Every rung up multiplies calls, cost, latency, and failure surface. Default to the lowest rung; document why a higher rung is required. Multi-agent is a last resort — it multiplies budgets and context-handoff bugs; a single bounded agent with good tools usually wins.

## Tool design — tools are the model's API

A tool is an interface you are exposing to a nondeterministic caller. Design it like a public API, not an internal function.

- **Name + description are load-bearing.** The model routes on them. Name the *effect* (`search_orders`, not `handler3`); the description states what it does, when to use it, and what it returns. Ambiguous descriptions cause wrong-tool selection.
- **Typed input schema, validated.** Declare parameters via the provider's tool/function-calling schema (JSON Schema). Validate the model's arguments at the boundary exactly like untrusted user input — the model hallucinates arguments. Reject with a message the model can act on, don't crash.
- **Make errors recoverable, not fatal.** A tool that fails returns a structured error string the model can read and retry/route around (`{"error":"order 4021 not found","hint":"list_orders first"}`) — it does NOT throw out of the loop. Tool failure is a normal branch, not an exception.
- **Least privilege per tool.** Scope each tool to the narrowest capability. A read tool reads; it never gains a delete path. Destructive scope is isolated into its own gated tool.
- **Confirmation gate on effectful tools.** Any tool that writes / deletes / spends / sends / executes passes through a gate BEFORE the side effect: a human confirm, a policy check (allow-list, spend cap, dry-run + diff), or both. The gate lives in code, not in the prompt — a prompt instruction ("ask before deleting") is not an enforcement mechanism.
- **Idempotency + return the result.** Effectful tools should be safe to retry (the model or loop may re-issue) and return the resulting state so the model observes what happened.
- **Keep the tool set small.** Large tool menus degrade selection accuracy and inflate every prompt. Split into sub-agents or route to a subset rather than exposing 40 tools at once.

## The loop + budgets — an unbudgeted agent is an incident

Bound EVERY axis; a single uncapped axis is the failure mode.

- **Max steps / iterations** — a hard integer cap; on hit, stop and return partial + a "budget exhausted" signal. No cap ⇒ a two-tool ping-pong runs forever.
- **Token budget** — cumulative input+output tokens across the whole run, not per call. Trip it → stop.
- **Cost ceiling ($)** — derived from tokens × model price; the loop tracks running cost and halts at the ceiling. This is the money kill-switch.
- **Wall-clock timeout** — a deadline for the whole run; a slow tool or provider stall can't hang the request.
- **Loop / no-progress detection** — detect repeated identical tool calls or oscillation (same 2 states) and break; the model can get stuck re-calling a failing tool.
- **Termination condition** — an explicit goal check (structured "done" signal or a validator), not "the model said it's finished" alone. On any budget trip, degrade gracefully: return best-effort output + surface that the budget bound it.

## Human-in-the-loop — on irreversible / high-value actions

- **Irreversible or high-value effects require an explicit human (or policy) approval step**: delete, external send (email/message/webhook), payment/refund, production write, privilege change. Present the proposed action + a diff/preview; execute only on approval.
- **Tier by blast radius:** auto-approve read/reversible low-value actions; require confirmation for reversible-but-costly; require a second human for irreversible/high-value. Encode the tiers as policy, not vibes.
- **Approvals are auditable** — log who approved what, when, and the exact action executed (feeds the audit trail; see observability).

## Context management across steps — don't grow unboundedly

- Naively appending every tool observation to the running context blows the window, inflates cost per step (you re-pay for the whole history each call), and degrades quality (lost-in-the-middle).
- **Compact / summarize** older turns once the context crosses a threshold: replace verbose tool outputs with a running summary; keep the goal, recent steps, and salient facts.
- **Externalize** large artifacts (fetched docs, files) to a store and pass a reference/handle, not the full blob, back into the loop.
- **Scope sub-tasks** to sub-agents with their own fresh context when a subtask needs a lot of tokens that the parent doesn't need to retain.

## Detectors (cite-or-halt)

- An agent loop (`while` / recursive tool-use loop) whose task decomposes into a fixed, knowable step sequence → cite the sequence → `downgrade-to-workflow`.
- A tool definition with write/delete/spend/send/execute scope and no confirmation-or-policy gate at the call site → `add-tool-gate` + cross-ref `@llm-security-reviewer` LLM03:2026.
- An agent loop with no `max_steps` / no token cap / no timeout / no cost ceiling → `add-loop-budget`.
- Context assembled by unconditionally appending every step's observation with no compaction/threshold → `add-context-compaction`.
- A tool that `throw`s (or lets an exception propagate) instead of returning a structured error the model can read → `make-tool-error-recoverable`.
- A tool input consumed without schema validation (model arguments trusted raw) → `validate-tool-args`.
- An irreversible/high-value action (delete/payment/external-send/prod-write) executed with no human/policy approval step → `add-human-gate`.

**Closure verbs:** `downgrade-to-workflow`, `add-tool-gate`, `add-loop-budget`, `add-context-compaction`, `make-tool-error-recoverable`, `validate-tool-args`, `add-human-gate`.

## Related

- **Patterns (in-pack):** `llm-gateway` (every tool-call/model-call routes through the gateway — budgets, cost tracking, fallback live there), `prompt-engineering` (tool descriptions + structured output are prompt surface), `evals` (an agent trajectory needs its own eval set — step count, tool-choice accuracy, task success), `rag-pipeline` (retrieval as a tool).
- **Rule (in-pack):** `ai-engineering-principles` (no unbounded agent loop; model output + tool output are untrusted; structured output via schema).
- **Cross-pack owners (referenced, not duplicated):** Excessive Agency, prompt injection via tool output, output-sink handling → **security** `@llm-security-reviewer` (LLM03:2026 / LLM10:2026 / LLM01:2026); per-call timeout/retry/circuit-breaker for the *tool's* downstream I/O → **distributed-systems** / **backend** resilience (don't re-implement here); trace-linked step logging + cost per run + approval audit trail → **observability** (`tracing`, `audit-logging`).
