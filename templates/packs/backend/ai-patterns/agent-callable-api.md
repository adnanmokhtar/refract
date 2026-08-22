---
name: agent-callable-api
description: 'Pattern: Agent-Callable API Design — tool/endpoint descriptions as interface, unrepresentable-invalid input schemas, actionable errors, response size as a cost defect, retry-safety and server-side gates for a caller whose harness you do not control'
kind: ai-pattern
pack: backend
---

# Pattern: Agent-Callable API Design

> **Hard rule:** An endpoint or tool exposed to an autonomous caller ships (a) a description that states what it does, when to call it, when NOT to call it, and what it does not return; (b) an input schema where invalid states are unrepresentable, not merely rejected; (c) errors carrying the correction, not just the complaint; (d) a bounded, defaulted response whose size is a declared budget; and (e) server-side enforcement of every destructive gate. The caller's confirmation prompt, retry policy, context budget, and rate limiter are all things you can neither see nor trust — designing as though you can is the defining failure of this pattern.

**When to apply**
- You are exposing an MCP server, a tool/function-calling surface, or an HTTP API that an LLM-driven agent will call without a human reading your docs first.
- An existing internal API is being fronted for agent use ("just point the agent at our REST API") — the retrofit is where the defects concentrate.
- Traffic on an existing surface has shifted from human-written clients to automation and the calls-per-task shape changed (see `rate-limiting.md` § Key dimension — caller class).

**When NOT to apply**
- A private endpoint reached only by code you own, deployed in lockstep, with no agent in the path. Nothing here pays for itself; `api-contract.md` already covers you.
- The consumer is an agent *you* build, whose loop and harness you own end to end — then `ai-engineering` `ai-patterns/agent-design.md` is the pattern, because the gates it puts in the loop are gates you actually control. Apply this pattern the moment the harness stops being yours.
- Batch/ETL machine traffic with a fixed, code-generated client. It is automation, but it is deterministic — it does not need trigger phrasing or self-correcting errors.

**Halt conditions / mandatory cites**
- A tool/endpoint proposed for agent exposure with no stated anti-trigger ("when NOT to call this") MUST be cited at its definition `<path:line>` — a description that only says what the tool does is half a description.
- Any "the agent will be asked to confirm" claim MUST cite the enforcement in **your** code. A client-side confirmation prompt is not a control you own; see § Destructive operations.
- Any response-size claim MUST cite a measured token count or a code-enforced cap at `<path:line>`. "The response is small" is a vibe. If no cap exists, that is the finding.
- A destructive or spend-effecting tool with no retry-safety story MUST be cited — name the key, the dedupe window, and the replay behaviour, or record UNKNOWN.
- Any claim that a downstream credential is scoped MUST cite the scope set. An agent-facing surface holding a wildcard credential is a finding, not a TODO.
- Hand-wave grep on `etc.`, `...`, `appears to` is forbidden — every exposed tool is named or the surface is not covered.

## Why the caller changes the design

Three properties of an autonomous caller invalidate assumptions a human-written client silently satisfies:

| Assumption a human client satisfies | Why the agent does not | Design consequence |
|---|---|---|
| Read the docs once; the knowledge persists across every call | The agent's whole knowledge of your API is the description text loaded into its context this turn. There is no second visit to your docs site. | The description **is** the documentation, the tutorial, and the deprecation notice. |
| Saw the dashboard, the changelog, the status page, the field's meaning in the UI | It sees none of these. Out-of-band context does not exist for it. | Everything load-bearing must be in the schema, the description, or the error text — the three things that travel over the wire. |
| Payload size is bandwidth | Every byte you return is tokenised into a finite, billed context window and competes with the agent's actual task | Response size is a **correctness** budget, not only a cost one. |

The last row is the one teams under-rate. Anthropic's tool-use pricing lists `tool_result` content blocks among the inputs billed on API **requests** — and an agent loop issues many requests carrying the same accumulated history ([Tool use overview § Pricing](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)). Whether a bloated result is paid once or on every subsequent turn depends on the caller's context strategy — context editing can clear old tool results, compaction can summarise them — and **you cannot know which the caller uses.** You are sizing a payload whose multiplier is invisible to you. Assume the worst multiplier and cap the payload.

## Descriptions are the interface

Anthropic's guidance is unusually blunt about the weighting: "**Provide extremely detailed descriptions.** This is by far the most important factor in tool performance," and it should cover what the tool does, when it should be used **and when it shouldn't**, what each parameter means, and "any important caveats or limitations, such as what information the tool does not return" — with "at least 3–4 sentences for each tool description, more if the tool is complex" ([Define tools § Best practices](https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools)). The engineering write-up frames the standard usefully: "think of how you would describe your tool to a new hire on your team" ([Writing tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents)).

Four rules follow:

1. **State the anti-trigger.** The failure mode is not "the agent cannot use the tool"; it is "the agent uses this tool where a sibling was correct," burning a turn and returning a confidently wrong answer built on the wrong data. Name the sibling: *"For historical prices use `get_price_history` — this tool returns only the latest trade."*
2. **State what you do NOT return.** Anthropic's own good/bad example pair turns on this: the good `get_stock_price` description ends "It will not provide any other information about the stock or company"; the rejected version is the one-liner "Gets the stock price for a ticker." A missing negative space is why an agent calls a tool three times hoping the field appears.
3. **Front-load the discriminating words.** Same reason the canonical command template demands it: selection reads the head of the string.
4. **Name parameters so the name carries the type.** "Instead of a parameter named `user`, try a parameter named `user_id`" (Writing tools for agents). A parameter called `user` invites an email address, a display name, and a UUID from three different runs.

### Naming and namespacing

Prefix by service and resource — `asana_search` / `jira_search`, then `asana_projects_search` / `asana_users_search` — which "can help agents select the right tools" (Writing tools for agents). Define tools § Best practices makes the same call and notes it "is especially important when using tool search."

**UNKNOWN — do not guess the direction.** The same write-up reports "selecting between prefix- and suffix-based namespacing to have non-trivial effects on our tool-use evaluations" but does not say which wins. It is workload-specific. Pick one, hold it consistent across the whole surface, and let your eval set settle it — a repo that mixes both has neither.

**Character-set intersection, if you serve both protocols.** Anthropic tool names "must match the regex `^[a-zA-Z0-9_-]{1,64}$`" (Define tools). MCP says names **SHOULD** be 1–128 characters, are case-sensitive, and **SHOULD** use only ASCII letters, digits, `_`, `-`, and `.` ([MCP 2025-11-25 § Tool Names](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)). The safe intersection is therefore `[A-Za-z0-9_-]`, ≤64 characters — no dots. That is derived from the two rules above, not quoted from either; verify against both before you standardise on it.

### Fewer tools, chosen deliberately

"More tools don't always lead to better outcomes" — build "a few thoughtful tools targeting specific high-impact workflows" instead of wrapping every endpoint, and consolidate: "Instead of implementing a `list_users`, `list_events`, and `create_event` tools, consider implementing a `schedule_event` tool which finds availability and schedules an event" (Writing tools for agents).

Two shapes of consolidation, and they are not the same move:
- **Workflow consolidation** (above) collapses a multi-call sequence into one call that owns the intermediate state. This is the higher-value one: it removes round trips, removes intermediate results from the context, and removes the chance of the agent stopping halfway.
- **Action-parameter consolidation** — "Rather than creating a separate tool for every action (`create_pr`, `review_pr`, `merge_pr`), group them into a single tool with an `action` parameter" (Define tools). Cheaper, mechanical, and it shrinks the schema block; but it also merges a read and a destructive write behind one name, which costs you the per-tool annotation and gating precision described below. Prefer it for same-blast-radius actions; do not use it to hide a `delete` behind the same tool as a `list`.

When the surface is genuinely large, the answer is deferred loading (tool search discovers and loads schemas on demand — [Tool use overview § Choose a tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)), not a shorter description on each of eighty tools.

## Input schemas: unrepresentable, not merely rejected

The pack already owns *validating* inbound data — `request-validation.md` § Bounds and § the allow-list are unchanged here and MUST still run server-side; the model's arguments are untrusted input like any other. What is new is that the schema is also a **prompt**: it is read by the caller before the call, so a constraint expressed in the schema prevents the bad call, while the same constraint enforced only in the handler merely punishes it a round trip later.

- **Enumerate instead of describing.** `{"type": "string", "enum": ["standard","express","pickup"]}` cannot produce a fourth value. A `string` with the allowed values written in prose can, and will.
- **Close the object.** `additionalProperties: false` plus an explicit `required` list. MCP requires `inputSchema` to be "a valid JSON Schema object (not `null`)" and recommends `{ "type": "object", "additionalProperties": false }` as the no-parameter form (MCP § Tool).
- **Constrain at the sampling layer where the platform offers it.** `strict: true` on a tool definition "guarantees Claude's tool inputs match your JSON Schema by constraining the model's token sampling to schema-valid outputs"; the documented shape sets `strict` as a top-level property alongside `name` / `description` / `input_schema`, with `required` and `additionalProperties: false` in the schema ([Strict tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use)). The stated failure it removes: without it the model "might return incompatible types (`"2"` instead of `2`) or omit required fields." Note the page's own limits — the computer-use and browser-use toolset entries reject `strict: true`, and PHI must not appear in schema property names, `enum`/`const` values, or `pattern` regexes, because compiled schemas are cached separately from message content.
- **Do not rely on the caller asking for a missing field.** Anthropic documents the behaviour honestly: a more capable model "is much more likely to recognize that a parameter is missing and ask for it," while a smaller one "might also infer a reasonable value" — and "this behavior is not guaranteed" (Tool use overview). A required field with an ambiguous name is an invitation to invent one.
- **Examples, when the shape is awkward.** `input_examples` supplies schema-validated example inputs; invalid examples return 400, and the cost is roughly "~20–50 tokens for simple examples, ~100–200 tokens for complex nested objects" (Define tools). Reach for it after the description is right, not instead of it.

## Errors must carry the correction

An agent cannot open your logs. The only remediation material it will ever have is the bytes you return. MCP formalises this as two channels with different intents, and the reasoning is worth quoting because it is the design rule:

> "**Tool Execution Errors** contain actionable feedback that language models can use to self-correct and retry with adjusted parameters. **Protocol Errors** indicate issues with the request structure itself that models are less likely to be able to fix." (MCP § Error Handling)

Protocol errors are JSON-RPC errors (unknown tool, malformed request). Execution errors are a normal result with `isError: true` — API failures, input-validation failures, business-logic failures. Clients **SHOULD** hand execution errors to the model and **MAY** hand it protocol errors, "though these are less likely to result in successful recovery." So: **a recoverable failure returned through the unrecoverable channel is a design bug** — it strips the agent of the retry it could have made.

The spec's own exemplar earns study: `"Invalid departure date: must be in the future. Current date is 08/08/2025."` It names the field, the rule, **and the fact the caller was missing.** The agent can fix this without another call. Compare a compliant-but-useless `422 VALIDATION_FAILED — departure_date invalid`.

Every agent-facing error answers three questions:

| Question | Bad | Good |
|---|---|---|
| What is wrong? | `INVALID_ARGUMENT` | `orderId "4021" not found` |
| What should change? | *(absent)* | `use an id from list_orders; ids look like "ord_..."` |
| Is retrying worth it? | *(absent)* | `retryable: false` / `retryable: true, retry_after_s: 30` |

Avoid "opaque error codes or tracebacks"; instead "clearly communicate specific and actionable improvements" — the write-up's framing is that you should **prompt-engineer your error responses** (Writing tools for agents), which is the right mental model: this text is a prompt, and it gets read by a model, so write it for that reader.

**Boundary — no duplication.** `error-handling.md` owns the error *envelope*, the status mapping, and typed domain errors; `request-validation.md` owns per-field `422` rows with stable machine codes. This pattern adds exactly one requirement on top of both: the **remediation payload** — the corrective fact and the retry verdict. A `422` that satisfies `request-validation.md` and carries no remediation still fails here.

## Response shape and size

Anthropic's reference point: "We restrict tool responses to 25,000 tokens by default" for Claude Code, alongside "pagination, range selection, filtering, and/or truncation with sensible default parameter values" (Writing tools for agents).

**Treat 25,000 as evidence that a cap is normal, not as your number.** Your cap is a function of your payloads and your callers' windows. Measure it. A cap imported from someone else's product without your telemetry behind it is a guess wearing a citation.

Rules:

- **A cap exists and is enforced in code.** Not documented, not intended — enforced, with the truncation visible in the response.
- **Truncate honestly.** A silently truncated list is worse than a rejected one: the agent reasons over a partial set and reports a confident wrong total. Say it was truncated, say how many were withheld, and say the exact call that fetches the rest. *(House doctrine — the cited sources prescribe truncation with sensible defaults but do not specify this disclosure; adopt it because silent truncation converts a size problem into a correctness one.)*
- **Offer a verbosity control.** A `response_format` enum letting the caller choose `"concise"` or `"detailed"` is the documented shape; in one reported Slack example "concise responses used approximately one-third the tokens of detailed responses" (Writing tools for agents). Treat the ratio as one measured instance, not a law — but the control itself generalises.
- **Return high-signal fields only** — "tool implementations should take care to return only high signal information back to agents."
- **Return names, not opaque keys.** "Merely resolving arbitrary alphanumeric UUIDs to more semantically meaningful and interpretable language … significantly improves Claude's precision in retrieval tasks." A row of raw foreign keys forces a second call to become meaningful; a row carrying the resolved name does not.
- **Yes/no questions get yes/no answers.** A 40KB object returned to establish one boolean is a defect on this surface, not merely waste. It costs tokens the caller needed for its task, it dilutes the signal it is meant to carry, and — because you cannot see the caller's context strategy — you cannot bound how many times it is re-billed. Expose the predicate as its own tool.
- **Structured output has a price.** MCP's `outputSchema` is worth declaring: servers **MUST** conform to it and clients **SHOULD** validate against it. But note the compatibility rule — "a tool that returns structured content SHOULD also return the serialized JSON in a TextContent block" — which means the payload is carried **twice**. Budget for the duplication; it is not free, and it is easy to miss when measuring.

**Cross-references, not restatements:** cursor semantics, default and max page size, and stable sort → `pagination.md`. `ETag` / `If-None-Match` so an unchanged resource costs a `304` and zero tokens → `conditional-requests.md`. Genuinely unbounded results → `response-streaming.md`. Narrow list-projection DTOs and per-endpoint body-size caps → `api-contract.md` § Response shaping & size limits (PERF-4). None of that changes here; this pattern only adds the token-budget lens over it.

## Destructive operations: the caller may retry, and its gate is not yours

An agent loop retries. It retries on timeouts it cannot distinguish from failures, it retries after a self-corrected error, and a harness you do not control may retry on your behalf. Therefore:

- **Every effectful operation is retry-safe or explicitly declares it is not.** The key's *shape* is validated at the boundary (`request-validation.md` § Idempotency-key), the *replay semantics* — store the outcome, return the recorded response verbatim — belong to the **distributed-systems** pack's idempotency pattern, and the batch-scoped case is already specified in `api-contract.md` § Bulk / batch. Do not re-specify any of it here; do cite which one this endpoint uses.
- **Publish behavioural hints — and understand exactly what they are worth.** MCP `ToolAnnotations` carries `readOnlyHint` (default `false`), `destructiveHint` (default `true`, "meaningful only when `readOnlyHint == false`"), `idempotentHint` (default `false`), and `openWorldHint` (default `true`) ([MCP schema](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/schema/2025-11-25/schema.ts)). Two facts must travel together:
  - **The defaults are safety-biased.** An unannotated tool reads as not-read-only, destructive, and non-idempotent. So annotating your *read* tools is the higher-value action — it is what lets a client parallelise or auto-approve them instead of serialising everything behind a confirmation.
  - **They are hints, and the spec says so twice.** "All properties in ToolAnnotations are **hints**. They are not guaranteed to provide a faithful description of tool behavior," and clients "**MUST** consider tool annotations to be untrusted unless they come from trusted servers" (MCP schema; MCP § Tool). They are UX metadata for the client. **They enforce nothing.**
- **The human gate is the client's, not yours.** MCP is explicit that there "**SHOULD** always be a human in the loop with the ability to deny tool invocations" and that applications **SHOULD** present confirmation prompts (MCP § User Interaction Model). Read the modal verb: `SHOULD`, and addressed to the *client*. You are not on that side of the wire. A destructive operation whose only safety is the caller's confirmation dialog is unguarded — and this is precisely where the boundary with `ai-engineering` `ai-patterns/agent-design.md` bites: every gate that pattern installs in the loop is, from your side, an assumption about someone else's code.
- **So enforce server-side.** Options, in rough order of cost: require a distinct scope for the destructive tool (§ below); require a two-step confirm — the first call returns a preview plus a short-lived, single-use confirmation token that the second call must present; require a dry-run flag to have been exercised; cap blast radius per call and per window (`rate-limiting.md`). *(These are the pack's recommended constructions, not protocol requirements — the specs mandate that servers "implement proper access controls" and "rate limit tool invocations" (MCP § Security Considerations) without prescribing a mechanism.)*
- **Make effects observable in the result.** Return the resulting state, not `{"ok": true}`. An agent that cannot see what changed will re-issue the call to find out.

## Authentication and scoping for a non-human caller

MCP's authorization rules are the most concrete published guidance here, and they are normative — the requirements below are `MUST`s from [MCP 2025-11-25 § Authorization](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization) and [§ Security Best Practices](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices):

- **Validate the audience.** Servers "**MUST** validate that access tokens were issued specifically for them as the intended audience," "**MUST** only accept tokens specifically intended for themselves and **MUST** reject tokens that do not include them in the audience claim," and "**MUST NOT** accept or transit any other tokens." Invalid or expired tokens **MUST** get a `401`.
- **Never pass the caller's token downstream.** Token passthrough — accepting a token and forwarding it unvalidated to a downstream API — is "explicitly forbidden." If your service calls an upstream API, "the access token used at the upstream API is a separate token, issued by the upstream authorization server. The MCP server **MUST NOT** pass through the token it received from the MCP client." The spec's own list of why is the argument to reuse in review: it circumvents rate limits and validation that key on audience, it destroys the audit trail (downstream logs show the wrong identity), and a stolen token turns your service into an exfiltration proxy.
- **Advertise where to authenticate.** Servers **MUST** implement RFC 9728 Protected Resource Metadata; the `401` **SHOULD** carry a `WWW-Authenticate` header with `resource_metadata` and a `scope` parameter, "following the principle of least privilege and preventing clients from requesting excessive permissions."
- **Scope down, then step up.** The spec's Scope Minimization guidance: start from a "minimal initial scope set … containing only low-risk discovery/read operations" and elevate incrementally via targeted `WWW-Authenticate` `scope="..."` challenges; runtime insufficiency answers `403` with `error="insufficient_scope"` and the scopes needed. Its named common mistakes are a ready-made review checklist — "publishing all possible scopes in `scopes_supported`", "using wildcard or omnibus scopes (`*`, `all`, `full-access`)", and "treating claimed scopes in token as sufficient without server-side authorization logic."
- **Sessions are not authentication.** "MCP servers that implement authorization **MUST** verify all inbound requests. MCP Servers **MUST NOT** use sessions for authentication." Session IDs **MUST** be secure and non-deterministic and **SHOULD** be bound to user-specific information — the spec suggests a `<user_id>:<session_id>` key format so a guessed session ID cannot impersonate another user.
- **Least privilege has a specific meaning here.** The agent's credential is not the user's credential. Scope it to the intersection of what the user may do and what *this task* needs. A read-only agent surface backed by a read-write service account is a wildcard credential with a polite description.

Rate limiting, admission control, and the human-vs-automation traffic shape are already owned by `rate-limiting.md` — including the per-caller-class key dimension and the reason token bucket suits an agent's burst-then-silence pattern. MCP § Security Considerations independently requires servers to "rate limit tool invocations." Cite that file; do not restate it.

## When NOT to expose an API to agents at all

The honest answer is sometimes "not yet," and saying so is cheaper than the incident:

- **Irreversible, unauditable, and un-previewable.** If the action cannot be undone, cannot be attributed to a caller after the fact, and has no dry-run, an agent-callable front door is a liability with no compensating control. Build the audit trail and the preview first.
- **Correctness depends on context the caller structurally cannot have.** Out-of-band legal or compliance approval, a physical interlock, a judgement call requiring accountability. No amount of description text supplies it.
- **The response necessarily contains data the caller is not cleared to hold.** A tool result does not stop at the model: it lands in a context window, and typically in a transcript that may be persisted, replayed, and read by other operators. MCP tells clients to "show tool inputs to the user before calling the server, to avoid malicious or accidental data exfiltration" and to "validate tool results before passing to LLM" (MCP § Security Considerations) — advice that exists because this path is an exfiltration surface. Field-level redaction at the boundary, or no exposure.
- **A deterministic client would do the job better.** If the sequence of calls is fixed and knowable, it is a script, not an agent surface. `ai-engineering` `ai-patterns/agent-design.md` § Autonomy ladder makes the same call from the caller's side: pick the lowest rung that works.
- **You cannot afford the evaluation.** The write-up's method is realistic tasks requiring "multiple tool calls—potentially dozens," with metrics beyond accuracy — "total runtime of individual tool calls and tasks, the total number of tool calls, the total token consumption, and tool errors" — and held-out test sets "to ensure we did not overfit to our 'training' evaluations" (Writing tools for agents). No eval set means no evidence the surface works and no way to detect the regression when you reword a description. Ship the eval with the surface.
- **The prerequisites are missing.** No per-caller identity, no rate limit, no audit log → the surface has no failure containment. Fix the floor before adding the door.

Framework-specific wiring (schema library, auth middleware, transport) goes in `references/<framework>.md`; the contract above is the part that is stack-independent.

## Boundaries with the rest of the pack (read before adding anything here)

| Concern | Owner | What this pattern adds |
|---|---|---|
| Success/error envelope, path naming, breaking-change table | `api-contract.md` | Nothing. Cite it. |
| Error shape, status mapping, typed domain errors | `error-handling.md` | The **remediation payload**: corrective fact + retry verdict. |
| Boundary validation, allow-list, bounds, `422` field rows | `request-validation.md` | Schema-as-prompt: make invalid states unrepresentable *before* the call. |
| `429`, `Retry-After`, quotas, caller-class keys, load shedding | `rate-limiting.md` | Nothing. Cite it. |
| Cursor pagination, page defaults and maxima | `pagination.md` | A token budget over the top of it. |
| `ETag` / `304`, optimistic concurrency | `conditional-requests.md` | Nothing. Cite it. |
| Idempotency-key replay semantics | **distributed-systems** pack | Which key this endpoint uses, and that one exists. |
| Agent loop, budgets, harness-side gates, context compaction | **ai-engineering** `agent-design.md` | The inversion: you own the *surface*, not the loop — its gates are your untrusted assumptions. |
| Prompt injection via tool output, excessive agency (LLM06/LLM01) | **security** pack | Nothing. Route to `@llm-security-reviewer`. |

A section added here that restates a row's owner is a defect in this file.

## Detectors (cite-or-halt)

Each finding cites `<path:line>` + the matched pattern + the fix. "The tool surface looks agent-unfriendly" without a cited definition is not a finding.

### 1. Description with no anti-trigger or no negative space

```
BAD:   description: "Gets the stock price for a ticker."
GOOD:  description: "Retrieves the current stock price … It should be used when the user asks
       about the current or most recent price of a specific stock. It will not provide any other
       information about the stock or company."   (Define tools § good example)
```
Flag a tool/endpoint description that is a single clause, omits "when NOT to use", or never says what it does not return → `expand-tool-description`.

### 2. Open or stringly-typed input schema

Flag an `input_schema` / `inputSchema` with no `required`, missing `additionalProperties: false`, a bare `string` where a closed set exists, or a parameter named for its entity rather than its identifier (`user` vs `user_id`) → `close-input-schema`.

### 3. Recoverable failure sent through the unrecoverable channel

A validation or business-logic failure returned as a JSON-RPC protocol error (or an HTTP `500`) instead of an execution error the model can act on → the agent cannot self-correct → `reclassify-tool-error`.

### 4. Error with no remediation payload

An agent-facing error naming what was wrong but not what to change, and carrying no retry verdict → `add-error-remediation` (envelope stays `error-handling.md`'s).

### 5. Unbounded or uncapped response

A list/read tool with no default limit, no maximum, no enforced size cap, or one that truncates without disclosing it → `add-response-budget`. A fat object returned to answer a boolean → `narrow-response-projection`.

### 6. Destructive tool with no server-side gate

An effectful tool relying solely on client confirmation, or on a `destructiveHint`, for safety; or an effectful tool with no idempotency key and no dedupe window → `add-server-side-gate`.

### 7. Token passthrough / missing audience validation

The inbound caller token forwarded to a downstream API, or accepted without validating it was issued for this service → `enforce-token-audience` (MCP: explicitly forbidden). Also flag a wildcard/omnibus scope (`*`, `all`, `full-access`) on an agent-facing credential → `scope-down-agent-credential`.

### 8. Agent surface with no eval set

An exposed tool surface with no task-level eval exercising multi-call trajectories and no tool-error/token metrics → description rewording is unfalsifiable → `add-tool-eval` (route to **ai-engineering** `evals`).

**Closure verbs:** `expand-tool-description`, `close-input-schema`, `reclassify-tool-error`, `add-error-remediation`, `add-response-budget`, `narrow-response-projection`, `add-server-side-gate`, `enforce-token-audience`, `scope-down-agent-credential`, `add-tool-eval`.

## Forbidden

- A tool description that states only what the tool does.
- An input schema with no `required` and no `additionalProperties: false` on a surface a model drives.
- A validation failure returned as a protocol error or a `500`.
- An error that names the problem and not the correction.
- A list or read tool with no default limit, no maximum, and no enforced size cap.
- Silent truncation.
- Relying on `destructiveHint`, or on the client's confirmation prompt, as the safety control for a destructive operation.
- Forwarding the caller's token to a downstream API, or accepting a token without validating its audience.
- A wildcard or omnibus scope on an agent-facing credential.
- Restating, in this file, anything the boundary table assigns to another pattern.

## References

- [Writing tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents) — Anthropic engineering. Namespacing, consolidation, the 25,000-token response cap, `response_format` concise/detailed, resolving UUIDs to names, prompt-engineering error responses, evaluation method.
- [Define tools](https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools) — description best practices ("by far the most important factor"; 3–4 sentences), the good/poor example pair, name regex, `input_examples` and its token cost, `tool_choice`.
- [Tool use overview](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview) — pricing (tool definitions and `tool_result` blocks are billed input), missing-parameter behaviour, tool search.
- [Strict tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use) — grammar-constrained sampling, `strict: true` placement, schema requirements, toolset and PHI limits.
- [MCP § Tools (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/server/tools) — Tool object, name rules, `inputSchema` / `outputSchema` / `structuredContent`, the two error channels, annotations-are-untrusted, server security requirements.
- [MCP § Authorization (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization) — audience validation, no-passthrough, RFC 9728 / RFC 8707, `401` / `403 insufficient_scope`, step-up flow.
- [MCP § Security Best Practices (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices) — token passthrough rationale, confused deputy, session hijacking, scope minimization.
- [MCP schema — `ToolAnnotations`](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/schema/2025-11-25/schema.ts) — `readOnlyHint` / `destructiveHint` / `idempotentHint` / `openWorldHint` and their defaults; the hints-are-not-guarantees note.
- In-repo: `templates/canonical-command-template.md:35,42–44` — this framework's own description + `USE:`/`NOT:` convention, the parallel drawn in § Descriptions are the interface.

> **Version note.** MCP citations are pinned to the `2025-11-25` specification revision. The revision is dated in the URL and MCP revises on a schedule — re-verify the annotation defaults and the authorization `MUST`s against the current revision before treating them as settled, and update the pin rather than the prose.
