---
name: agent-callable-api
kind: example
pack: backend
---

# Pattern: Agent-Callable API Design

> **Hard rule:** An endpoint or tool exposed to an autonomous caller ships (a) a description stating what it does, when to call it, when NOT to, and what it does not return; (b) an input schema where invalid states are unrepresentable, not merely rejected; (c) errors carrying the correction, not just the complaint; (d) a bounded, defaulted response whose size is a declared budget; and (e) server-side enforcement of every destructive gate. The caller's confirmation prompt, retry policy, context budget, and rate limiter are things you can neither see nor trust.

**When to apply** — exposing an MCP server, a tool/function-calling surface, or an HTTP API an agent drives without a human reading the docs; retrofitting an internal API for agent use; traffic shifting from human-written clients to automation.

**When NOT to apply** — private endpoints reached only by code you own and deploy in lockstep; an agent whose loop and harness YOU own (that is `ai-engineering` `agent-design.md`, whose gates you actually control); deterministic code-generated batch clients.

## Why the caller changes the design

| Human client assumes | The agent does not | Consequence |
|---|---|---|
| Docs read once, knowledge persists | Its whole knowledge of your API is the description in context this turn | The description IS the docs |
| Saw the dashboard / changelog / UI | Sees none of it | Load-bearing facts go in schema, description, or error text |
| Payload size is bandwidth | Every byte is billed context competing with its task | Response size is a **correctness** budget |

You cannot see the caller's context strategy, so you cannot know whether a bloated result is billed once or on every turn. Assume the worst multiplier and cap the payload.

## Rules

1. **Descriptions are the interface.** Anthropic: "Provide extremely detailed descriptions. This is by far the most important factor in tool performance" — cover what it does, when it should be used **and when it shouldn't**, each parameter, and "what information the tool does not return"; "at least 3–4 sentences … more if the tool is complex" ([Define tools](https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools)).
2. **Name the anti-trigger and the sibling.** The failure is not "cannot use the tool" — it is "used this one where a sibling was correct," returning a confident wrong answer.
3. **Namespace by service and resource** (`asana_search` / `jira_search`) ([Writing tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents)). **UNKNOWN:** prefix-vs-suffix has "non-trivial effects" but the source does not say which wins — pick one, hold it, let your evals settle it. Serving both protocols? Safe name intersection is `[A-Za-z0-9_-]`, ≤64 (derived from Define tools' `^[a-zA-Z0-9_-]{1,64}$` and MCP's 1–128 / `A-Za-z0-9_-.` — verify before standardising).
4. **Fewer tools.** "More tools don't always lead to better outcomes." Prefer workflow consolidation (`schedule_event` over `list_users`+`list_events`+`create_event`) over action-parameter consolidation — the latter hides a delete behind the same name as a list, costing per-tool annotation and gating precision. Large surface → deferred loading / tool search, not shorter descriptions.
5. **Schema is a prompt, not just a gate.** Enums over prose-described strings; `required` + `additionalProperties: false`; `user_id` not `user`. `strict: true` constrains sampling to schema-valid output, removing `"2"`-for-`2` and omitted fields ([Strict tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use)) — note its toolset and PHI-in-schema limits. Do **not** rely on the model asking for a missing field: docs say it "might also infer a reasonable value" and "this behavior is not guaranteed". Server-side validation still runs — `request-validation.md` is unchanged.
6. **Errors carry the correction.** MCP splits execution errors (`isError: true` — "actionable feedback that language models can use to self-correct and retry with adjusted parameters") from protocol errors (models "are less likely to be able to fix"). Returning a recoverable failure through the unrecoverable channel strips the agent of the retry. Exemplar: `"Invalid departure date: must be in the future. Current date is 08/08/2025."` — field, rule, **and the missing fact**. Answer three questions: what is wrong / what to change / is retry worth it.
7. **Cap the response, truncate honestly.** Anthropic restricts tool responses to 25,000 tokens by default in Claude Code — evidence a cap is normal, **not your number**; measure yours. Offer `response_format` concise/detailed (one Slack example: concise ≈ one-third the tokens). Return high-signal fields and resolved names, not raw UUIDs ("significantly improves Claude's precision in retrieval tasks"). A 40KB object answering a boolean is a defect here, not just waste. MCP `outputSchema` is worth declaring, but the back-compat rule ("SHOULD also return the serialized JSON in a TextContent block") carries the payload **twice** — budget for it.
8. **Destructive ops: the caller retries and its gate is not yours.** MCP `ToolAnnotations` defaults are safety-biased — `readOnlyHint` false, `destructiveHint` **true**, `idempotentHint` false, `openWorldHint` true — so annotating *read* tools is the high-value move. But "all properties in ToolAnnotations are **hints** … not guaranteed to provide a faithful description of tool behavior" and clients "MUST consider tool annotations to be untrusted." The human-in-the-loop confirmation is a `SHOULD` addressed to the **client**. Enforce server-side: separate scope, two-step confirm token, exercised dry-run, per-window blast-radius cap. Return the resulting state, not `{"ok": true}`.
9. **Auth for a non-human caller** (all `MUST`s from [MCP § Authorization](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization) / [§ Security Best Practices](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices)): validate tokens were issued **for you** (audience); "MUST NOT accept or transit any other tokens"; token passthrough is "explicitly forbidden" — call upstreams with a separate token; implement RFC 9728 metadata; `401` + `WWW-Authenticate` with `resource_metadata` and `scope`; `403 error="insufficient_scope"` for step-up. Start minimal-scope and elevate. Named mistakes: wildcard/omnibus scopes (`*`, `all`, `full-access`), publishing every scope in `scopes_supported`, trusting claimed scopes without server-side authorization. Sessions are **not** authentication; bind session IDs to the user (`<user_id>:<session_id>`).
10. **Sometimes: don't expose it.** Irreversible + unauditable + no dry-run; correctness depending on out-of-band context the caller cannot have; responses carrying data that must not land in a transcript; a fixed call sequence that is really a script; no eval set (trajectory tasks + tool-error and token metrics, held-out) so description rewording is unfalsifiable; or a missing floor — no per-caller identity, no rate limit, no audit log.

## Detectors (cite-or-halt)

1. Description that is one clause, omits "when NOT to use", or never says what it does not return → `expand-tool-description`.
2. Schema with no `required`, missing `additionalProperties: false`, a bare `string` where a closed set exists, or `user` instead of `user_id` → `close-input-schema`.
3. Validation/business failure returned as a protocol error or `500` instead of an actionable execution error → `reclassify-tool-error`.
4. Error naming the problem but not the correction, with no retry verdict → `add-error-remediation`.
5. List/read tool with no default limit, no maximum, no enforced size cap, or silent truncation → `add-response-budget`; fat object answering a boolean → `narrow-response-projection`.
6. Effectful tool relying on client confirmation or on `destructiveHint` for safety, or with no idempotency key → `add-server-side-gate`.
7. Caller token forwarded downstream, or accepted without audience validation → `enforce-token-audience`; wildcard scope on an agent credential → `scope-down-agent-credential`.
8. Exposed tool surface with no multi-call eval and no tool-error/token metrics → `add-tool-eval`.

**Closure verbs:** `expand-tool-description`, `close-input-schema`, `reclassify-tool-error`, `add-error-remediation`, `add-response-budget`, `narrow-response-projection`, `add-server-side-gate`, `enforce-token-audience`, `scope-down-agent-credential`, `add-tool-eval`.

## Forbidden

A description stating only what the tool does; an open schema on a model-driven surface; a validation failure as a protocol error or `500`; an error with no correction; an uncapped list/read tool; silent truncation; `destructiveHint` or the client's confirmation dialog as the safety control; forwarding the caller's token downstream or skipping audience validation; a wildcard scope on an agent credential; restating anything the boundary table below assigns elsewhere.

## Boundaries (cite, do not restate)

`api-contract.md` (envelope, paths, breaking-change table) · `error-handling.md` (error shape + status mapping — this pattern adds only the remediation payload) · `request-validation.md` (boundary validation, allow-list, bounds, `422` rows) · `rate-limiting.md` (`429`, `Retry-After`, caller-class keys, load shedding; MCP also requires servers to "rate limit tool invocations") · `pagination.md` / `conditional-requests.md` / `response-streaming.md` / `api-contract.md` § PERF-4 (size, `304`, streaming) · **distributed-systems** (idempotency replay semantics) · **ai-engineering** `agent-design.md` (the loop and its harness-side gates — the inversion: you own the surface, not the loop, so its gates are your untrusted assumptions) + `evals` · **security** `@llm-security-reviewer` (prompt injection via tool output, LLM06 excessive agency).

## References

- [Writing tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents) — Anthropic engineering. Namespacing, consolidation, the 25,000-token response cap, `response_format` concise/detailed, prompt-engineering error responses.
- [Define tools](https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools) — description best practices ("by far the most important factor"; 3–4 sentences), name regex, `input_examples` and its token cost.
- [Strict tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use) — grammar-constrained sampling, `strict: true` placement, schema requirements.
- [MCP § Tools (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/server/tools) — Tool object, `inputSchema` / `outputSchema` / `structuredContent`, the two error channels, annotations-are-untrusted.
- [MCP § Authorization (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization) — audience validation, no-passthrough, RFC 9728 / RFC 8707, `401` / `403 insufficient_scope`.
- [MCP § Security Best Practices (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices) — token passthrough rationale, confused deputy, session hijacking, scope minimization.
- In-repo: `templates/canonical-command-template.md:35,42–44` — this framework's own description + `USE:`/`NOT:` convention.

> MCP citations pinned to the `2025-11-25` revision; re-verify annotation defaults and authorization `MUST`s against the current revision before treating them as settled.
