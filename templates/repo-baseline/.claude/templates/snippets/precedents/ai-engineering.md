# Precedents — AI engineering (LLM call sites, budgets and loops, metering, model lifecycle, structured output, evals, retrieval and index, and the LLM trust boundary)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in an **AI engineering** class: a provider call outside the seam, a call budget that is an
SDK default nobody chose, an agent loop with no cap, a charge that settles on the wrong event, a model
id past its retirement date or a parameter the configured model rejects, a truncated or refused
answer used as data, an LLM feature with no eval or a masked eval gate, a filtered-recall collapse,
a stale or mismatched vector index. The oracles that prove them are in
[`proof-oracles.md`](../proof-oracles.md) § AI engineering (V510–V539). The detectors are
`llm-gateway-audit` (§1 seam, §B budgets, §L loops, §M metering), `prompt-audit` (§S structured
output, §V model lifecycle and parameters, §P prompts), `eval-run` (§C coverage lane, run lane),
`retrieval-eval` and `vector-index-audit` (ai-engineering pack); all of them read the inventory that
`llm-sites.py` prints first. The judge is `@ai-feature-reviewer`.

**Trust-boundary classes are security's.** Prompt injection paths, tool authority and approvals, model
output reaching a renderer or an authorisation field, secrets and personal data sent to a provider,
tracing of content, tenant scope of retrieval and caches, and MCP servers are owned by the security
pack, judged by `@llm-security-reviewer` under [`finding-verification.md`](../finding-verification.md),
and closed by `/security-fix`. Entries 1–20 and 29 below are written for that verifier as much as for
this one: the ai detectors route those rows with a count and never grade them. Without the security
pack the routed row is listed as `<class> (owner pack security not installed)` with its hit count,
never cleared. OWASP ids are labelled **OWASP LLM Top 10 2026 v1.0 (2026-08-03)**: the official
resource page shows no list, the order is from two secondary sources, so a run re-reads the PDF
before quoting an entry's text.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips it
back. A match makes the candidate **Hardening**, or Refuted where the entry says so, unless the flip
evidence is shown with a `file:line`, a lockfile version, a dated provider document or a recorded
oracle run. Numbers are stable: detectors cite `precedents/ai-engineering.md § <n>`. They follow the
AI engineering research catalog's precedent order (2026-10-19).

Index: the claim and the gates · trust boundary § 1–20, § 29 · engineering § 21–28, § 30 · real-repo
shapes · posting rules · rationalizations.

## The claim, restated

§ 1 of the protocol takes this shape here. An AI claim names **the call site** from the inventory and
the **dated fact** it rests on, never a remembered one.

> Under **[the condition: a provider error, a timeout, a truncation, a refusal, a client disconnect, a
> tool that always calls again, a model id past its date, a prompt edit on a branch]**, **[the entry
> point: a route, job, consumer or agent turn]** reaches **[the call site at file:line, from
> `sites.tsv`]** without **[the control: an explicit budget, a loop cap, a settle-on-outcome rule, a
> stop-reason branch, a schema check, a live model id, an eval gate]**, which costs **[tokens and
> minutes per logical call / a charge for nothing / a 400 on every request / a truncated answer
> persisted / an unmeasured change shipped]**, proven by **[V-number]** against **[the provider
> document and its date, or the lockfile version]**.

A model id, a parameter rule, an SDK default or a framework loop cap is never stated from memory: it
comes from `model-lifecycle.tsv` (with its `checked_on`), the lockfile, or a provider page fetched and
dated in the run. A STALE table is a blocked gate, not a pass.

## Reading the seven gates for AI engineering

| Gate | AI engineering |
|---|---|
| 1 Reachability | a production route, job, consumer, cron or agent turn reaches the call site; eval harnesses, notebooks, `scripts/` one-offs and tests fail here (they still owe a budget when they run in CI, § 28) |
| 2 Trigger | the failure the claim needs occurs: a provider 5xx / 529 / 429, a timeout, a `length` or `max_tokens` stop, a refusal, a disconnect mid-stream, a tool loop, a model retirement date that has passed or falls within the release window |
| 3 Version | the SDK, framework and model generation from the lockfile and the call site: SDK retry and timeout defaults, AI SDK v5/v6/v7 step and usage semantics, LangGraph ≥ 1.0.6 recursion default, LangChain v1 middleware, Claude 4.6 / 4.7 / 5.5 and OpenAI reasoning-model parameter rules; `UNREAD` without a lockfile |
| 4 Existing control | the seam's defaults (client-level timeout, cap, retries), an aggregate request deadline, a gateway or proxy that enforces caps and budgets, a framework cap, a reserve-then-settle meter, a schema-validated parse with a fail-closed branch, a scheduled regression eval |
| 5 Impact | money (a charge for nothing, an unbilled stream, a price-table miss), an outage (a 400 on every call after a model bump, a retired id), a wrong answer persisted as complete, minutes of held request capacity, a change shipped unmeasured. Hygiene with none of these is Hardening (§ posting rules) |
| 6 Proof | the scripted-model test (V510 family U) that fails first, the `llm-sites.py` tool exit (T), or the two-ended static fact (S); a live eval (L) runs only on the user's word |
| 7 Environment | the deployment's route and proxy timeouts, the worker concurrency and replica count that multiply a loop or a race, the provider platform (first-party, Bedrock, Vertex, Azure) whose lifecycle applies |

## Trust boundary (owner: security; listed for both verifiers)

1. **The end user's own text in the user role** is the designed channel, not PI-2 (the class is third-party text presented as the user's). *Flips back:* retrieved documents, tool results, emails or another user's rows are placed in the same user turn as if the user wrote them.
2. **Tool results JSON-encoded inside a labelled fence**, plus an untrusted-data rule in the system prompt, close PI-3 for reliability. Injection is still judged by the gates (§ 3), not by the fence. *Flips back:* the fence tag is fixed and the content is not escaped, so a payload closes it (PI-4 Hardening), or a write tool stays callable after the fenced read.
3. **Write tools withdrawn for the turn once a third-party-text tool runs**, and a confirmation bound to the tool, the argument hash, the actor and an *earlier* turn, break the trifecta's action leg: AG-5 and AG-6 are refuted. *Flips back:* the taint flag is optional on the tool port (a new tool defaults to trusted), the token is visible to the model in the minting turn, or consumption does not compare the argument hash.
4. **Tool id arguments re-checked against the session's membership** inside `execute` are not AG-1. *Flips back:* one tool reads `args.tenantId` / `args.userId` without the check.
5. **A tool catalogue filtered in code** by mode, permission and account kind is not AG-7. *Flips back:* the restriction lives only in the system prompt, or a read-only mode still declares a write tool.
6. **Staff-authored prompt templates** in config or the database are configuration, not PI-1. *Flips back:* a tenant user, a marketplace seller or an import can write the template row.
7. **The tenant's own catalogue names in its own system prompt** are same-tenant data, not PI-1. *Flips back:* the text comes from third parties (marketplace titles, customer notes, carrier messages) or another tenant.
8. **Markdown images rendered as links**, and `react-markdown` without `rehype-raw`, refute OH-1 and OH-2; a click-through link stays Hardening. *Flips back:* any renderer of model text (an email, a PDF, a Slack post, Mermaid or SVG) auto-fetches images, or the CSP allows `img-src *`.
9. **Malformed model output coerced field by field into a typed draft the user confirms** makes SO-2 and OH-6 Hardening, not High. *Flips back:* a coerced field drives a price, quantity, status or authorisation without a server-side re-derivation, or the draft is committed without the confirmation.
10. **An aggregate request deadline that aborts outbound calls**, with error lines that never carry upstream text, refutes TF-1 and LG-1 on that path. *Flips back:* the deadline does not reach the model call (a queue worker, a stream that outlives the request), or an error branch logs the prompt or the provider body.
11. **An MCP authorisation server and resource server that are one app**, with opaque tokens stored in the database, make the absence of RFC 8707 `resource` Hardening, not MC-1. *Flips back:* the server forwards the caller's token upstream, or accepts JWTs without an audience check.
12. **A read-only MCP catalogue asserted at boot**, one `read` scope, a staff-only door, a per-token rate limit and a batch cap refute MC-5. *Flips back:* a write tool is registered conditionally, or the scope is not checked per tool.
13. **`/v1/messages` on an SMS or notification client** is not an LLM call: the wire lane needs `max_tokens` or `anthropic-version` beside it. *Flips back:* the body carries `model` and `max_tokens`.
14. **A debit keyed by the turn id under a unique index**, or a worker charge claimed with `SET NX`, refutes CO-12. CO-2 (what the charge settles on) is still read (§ 30). *Flips back:* the key is minted per attempt, or the uniqueness lives in code only.
15. **`cohere` inside "coherence"; `seed` in seed scripts; `nList` / `nProbe` variables; `agent` in "user agent"** are grep noise, never a signal. *Flips back:* —; this is why every lane is word-bounded and the inventory comes before any grep.
16. **Personal data sent to a provider with a transfer-register entry and a documented basis** refutes SD-4. *Flips back:* the register does not name this provider or this data category, or zero-retention is claimed with no contract reference.
17. **`dangerouslyAllowBrowser` in a bring-your-own-key local tool** is a threat-model question first, not Critical. *Flips back:* the key is the operator's, shipped in a bundle served to users.
18. **An extractable system prompt holding non-secret business rules** is an accepted risk while no authorisation depends on it. *Flips back:* the prompt carries a secret, an internal URL, or the only enforcement of an access rule (SD-2, SD-3).
19. **A per-tenant namespace or index derived from the session** is not RG-1. *Flips back:* the namespace value comes from the request body or the model's arguments (RG-2).
20. **A global knowledge base seeded by a migration and read-only at runtime** is not RG-1 or RG-5. *Flips back:* an upload, crawl or admin path writes to it at runtime.
29. **A guardrail classifier plus architecture gates** is fine; the classifier alone is PI-6. Adaptive attacks bypassed twelve published defences ("The Attacker Moves Second", 2025-10-10). *Flips back:* nothing downstream of the classifier gates the tool, the approval or the egress.

## Engineering (owner: ai-engineering)

21. **A moving alias with a scheduled regression eval and a drift alert** downgrades MV-2 to Info. *Flips back:* the eval does not cover the feature that uses the alias, or it is not in CI (`eval-run` §C2).
22. **No OpenAI output cap where a gateway enforces per-key caps** (LiteLLM, Portkey, a provider gateway) is Info once the gateway config is read and cited. *Flips back:* the gateway config is not in the repo or does not cap this key or route.
23. **Retries on idempotent, cheap calls** (embeddings of cached chunks, batch-status reads) are fine, not CO-7. *Flips back:* the retried call generates, charges, sends or writes.
24. **AI SDK `generateText` / `streamText` without `stopWhen`** runs one step by default, so it is not CO-5; `ToolLoopAgent` defaults to 20 steps (AI SDK docs, read 2026-10-19). *Flips back:* `stopWhen` is set to a large or custom condition with no step bound, or the lockfile's major changes the default (v7 renames `stepCountIs` to `isStepCount`).
25. **A cacheable prefix below the provider's minimum** (512–4,096 tokens by model on Anthropic, 1,024 on recent OpenAI models, per their prompt-caching pages read 2026-10-19) has nothing to fix; CO-10 does not apply. *Flips back:* the stable content, consolidated, would clear the minimum and the path is high-volume.
26. **Snapshots of recorded fixtures** (VCR, nock, cassettes, a stubbed transport replaying a recorded response) are deterministic, not EV-3. *Flips back:* the snapshot is of live model output, or the suite only asserts the stub (a plumbing test, which is not an eval: § 30's EV-1 note).
27. **No temperature on Claude 4.7+ or OpenAI reasoning models** is required, not a smell: a non-default value returns 400 there (Anthropic deprecations page, read 2026-10-19). The old "temperature not set" smell is wrong on those models. *Flips back:* the model id at the call site, or its env default, is a generation that still exposes sampling and the task is single-answer (PM-3).
28. **A retired id in a migration script, a changelog or a test of 404 / 410 handling** is not MV-1. `llm-sites.py --models` never reads CHANGELOG, docs, migrations or tests. *Flips back:* the same id is in code, `.env.example`, IaC, an eval config or a fallback list that runs.
30. **A documented bounded leak** (a balance clamped at zero on a credit race) is Hardening only when the stated bound is true. A comment that bounds the leak to "one batch" is false when the worker runs several jobs per replica: the bound is concurrency × replicas. The race itself is security `logic-race-scan` §5; the ai detector routes it with the meter's shape. *Flips back:* the stated bound is checked against the deploy files' worker concurrency and replica count, and holds.

## Real-repo shapes (unnamed; measured read-only 2026-10-19)

A NestJS + React monorepo with an OpenAI-compatible gateway over raw HTTP, no provider SDK, an
assistant with 18 tools and a credit-metered extraction is the reference shape for these entries.
What it taught:
- the provider-name grep found 0 of its 2 call sites and 107 `cohere` substrings; the wire lane found
  both with no noise (§ 13, § 15). The inventory comes first in every detector;
- the extraction path charges after a validated result under `SET NX` (§ 14) while the chat path
  debits the turn before the model loop with no refund on gateway failure: two policies in one
  product. CO-2 is read **across** the product's billed features, and stays Unconfirmed, capped at
  MEDIUM, until the product's terms are read;
- the assistant reads no `finish_reason`: a `length`-truncated answer is recorded and charged (SO-3);
  the extraction path turns truncated arguments into a refusal with no charge (refuted there);
- the forced `tool_choice` with a model id from env is a 400 on Opus 5.5 / Sonnet 5.5 (Anthropic API
  errors page, read 2026-10-19), so MV-4 is Unconfirmed until the configured id is read;
- fifteen AI unit specs stub the transport: plumbing tests, not an eval set (EV-1).

## Posting rules (AI engineering)

- Hygiene with no money, outage, wrong-answer or unmeasured-change impact is **Hardening**: an
  unversioned prompt on an internal tool, a cap that could be lower, a non-strict schema with a
  defensive parse downstream. NITs are capped at 5 per report, each with its site.
- Every row carries its inventory line (`sites.tsv` file:line and the columns it read), the lockfile
  version it relied on, and the dated table or page for any model fact.
- One root cause at N sites is one finding with N sites: one client with SDK-default budgets, one
  meter that debits before the call, one parser that ignores the stop reason.
- **A product decision is not a code fix.** Whether a failed or refused turn is charged, which
  fallback model is acceptable, the eval threshold: the finding names the decision and stops.
- Never ask the model under test whether it is safe or correct; oracles assert the deterministic shell
  around it (V510).

## Rationalizations to reject (AI engineering)

**Wrongly accepting "correct":**
- "The SDK has a timeout." Which one: 600 s × 3 attempts against a 30 s route is TF-1 (§ gates, 3).
- "The model always returns valid JSON." Show the stop-reason branch and the validation (SO-2, SO-3).
- "The agent stops when it is done." Show the cap and the terminal reason (CO-5).
- "We charge per message, that is fair." On a failed, refused or truncated turn too (CO-2)?
- "The model id is configurable." Validated at boot against what list (MV-3)?
- "We have tests for the AI feature." Do they assert the stub or score real outputs (EV-1, § 26)?
- "The guardrail library handles injection." Not alone (§ 29).

**Wrongly flagging a defect:**
- "There is no temperature." On Claude 4.7+ that is required (§ 27).
- "There is no `stopWhen`." One step is the default (§ 24).
- "There is no cache marker." Is the prefix above the minimum (§ 25)?
- "This file says `cohere`." Read the word (§ 15).
- "This POSTs to `/v1/messages`." With `max_tokens` (§ 13)?
- "A retired model id appears." In the changelog (§ 28)?

---

Sources: the AI engineering research catalog (2026-10-19) § 4 for entries 1–30 and its two notes
(injection, agency, output, MCP and data; cost, reliability, pinning and evals); the batch-8
ai-engineering eval (2026-10-19) for the ownership split. Provider facts cite the provider page and
the date it was read: Anthropic model deprecations and API errors, OpenAI deprecations, Gemini API
deprecations, AI SDK loop control, LangGraph graph API, LangChain middleware, all read 2026-10-19.
OWASP ids per OWASP LLM Top 10 2026 v1.0 (2026-08-03). Paraphrased; no text is reproduced beyond
identifiers.
