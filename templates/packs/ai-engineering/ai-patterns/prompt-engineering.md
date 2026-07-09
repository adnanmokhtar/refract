---
name: prompt-engineering
description: 'Pattern: Prompt Engineering — structure, structured output, determinism, versioning'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: Prompt Engineering — structure, structured output, determinism, versioning

> **Hard rule:** A production prompt is **code**: structured, versioned, and eval-gated — not a string edited in place on a hunch. Where the provider offers structured output (tool/function-calling or a JSON/structured-output mode with a schema), you **use it and validate against the schema** — you NEVER regex-parse free text into a data structure. Instructions live in the **system** message; untrusted data (user input, retrieved documents, tool results) lives in the **user** message, delimited — mixing them is a prompt-injection hole. Extraction and classification run at **temperature 0**. Every prompt change goes through the eval gate before it ships.

**When to apply**
- Every LLM call site — this pattern governs how the prompt is assembled, how output is parsed, and how the prompt is versioned.
- Especially: extraction / classification (need determinism + schema), anything consuming untrusted user or retrieved content (need system/user separation), and any output the code parses (need structured output).

**When NOT to apply**
- A genuinely free-form creative/chat surface where the output is shown to a human and never parsed by code — structured output + temperature 0 don't apply, but system/user separation and versioning still do.

**Halt conditions / mandatory cites**
- **Regex/string-parsing free-text output where the provider supports structured output** MUST be cited at `<path:line>` — a schema is available; parsing free text is a reliability bug.
- Instructions concatenated with **untrusted user data or retrieved content in one blob** (no system/user split, no delimiting) MUST be flagged — this is the prompt-injection surface (cross-link `llm-security`).
- A structured-output call with **no schema validation (and no repair path)** on the response MUST be cited — "the model usually returns valid JSON" is not a guarantee.
- **`temperature > 0` on an extraction or classification task** MUST be cited — non-determinism on a task with one correct answer is a defect.
- A prompt string **edited in place with no version bump and no eval-diff** MUST be flagged — an unversioned, unevaluated prompt change is an untested code change (cross-link `evals`).

## 1. Prompt structure

A reliable prompt has clearly separated parts. Label them; don't run them together.

- **Role** — who the model is acting as ("You are a support-ticket classifier"). Sets stance + vocabulary.
- **Task** — the single, specific instruction. One prompt, one job.
- **Constraints** — what it must / must not do: allowed values, tone, "only use the provided context", "if unsure, say you don't know", length limits.
- **Format** — the exact output shape (prefer a schema via structured output over prose instructions about JSON — see §2).
- **Context / data** — the documents or input to operate on, clearly delimited.

Ordering that matters:
- **Put long context/documents BEFORE the instruction** for long-context models. Models attend better to instructions that follow the bulk of the input, and it lets the provider cache the long, stable document prefix across calls (cheaper + faster). The short, variable instruction goes last.
- **Delimit untrusted content** with clear boundaries (XML-style tags, fenced sections) and tell the model that everything inside is data to be processed, never instructions to follow.
- **Give the model an out.** Explicitly permit "I don't know" / "no answer in the context" so it isn't forced to fabricate (ties to `rag-pipeline`'s no-context guard).

## 2. Structured output — schema, don't scrape

When code consumes the output, the output must be machine-parseable by construction.

- **Use the provider's native mechanism:** tool/function-calling, JSON mode, or a constrained/structured-output mode bound to a **schema** (JSON Schema / a typed model). This constrains generation so the response conforms — far more reliable than "please respond in JSON" in the prompt.
- **Always validate the response against the schema** even so — providers can still return an out-of-schema or truncated result under edge conditions.
- **Have a repair path:** on a validation failure, re-ask with the validation error (a bounded retry), or fail closed — never silently pass a malformed object downstream.
- **NEVER regex-parse free text when a schema is available.** Regex over prose is brittle: it breaks on rewordings, locales, and formatting drift, and it fails silently. Structured output eliminates the whole class of parsing bugs.
- Prefer a **flat, explicitly-typed schema** with enums for closed sets — it constrains the model and makes validation strict.

## 3. Few-shot vs zero-shot

- **Zero-shot** (instruction only) — start here for capable models on clear tasks; it's cheaper and simpler.
- **Few-shot** (worked examples in the prompt) — add when the task has a specific format, edge cases, or a nuanced label boundary the instruction alone doesn't pin down. Examples teach by demonstration where description falls short.
- **Choose representative examples**, cover the tricky/edge cases and the "negative"/refusal cases, and keep them consistent with the exact output format you want. A handful of good examples beats a dozen redundant ones (and every example costs tokens on every call — consider prompt caching for a stable example block).
- If you find yourself adding many examples to fix quality, that's a signal to **fine-tune** or to revisit retrieval — not to grow an ever-longer prompt.

## 4. System vs user separation

- **Instructions, role, constraints, format → system message.** This is the trusted, developer-controlled channel.
- **Untrusted data (user input, retrieved documents, tool outputs) → user message**, delimited and labeled as data.
- Providers weight the system message as higher-priority guidance; keeping instructions there (and data out of there) both improves adherence AND is the structural defense against prompt injection — an instruction smuggled inside user data is far less likely to override a system instruction than one concatenated into the same blob. **This is a security boundary — cross-link `llm-security` / `@llm-security-reviewer`.**
- Never interpolate untrusted content into the system message.

## 5. Determinism

- **Temperature 0 (or the lowest supported) for extraction, classification, routing, structured output, tool-argument generation** — any task with a single correct answer. Non-determinism there means the same input can produce different outputs across retries, which is a correctness + reproducibility bug and makes evals noisy.
- **Fix the seed where the provider supports it** for further reproducibility; note that determinism is best-effort even so (provider infra can vary).
- Higher temperature belongs only where variation is the point (brainstorming, creative drafts, sampling diverse candidates).
- Determinism makes the eval gate meaningful — a scorer over a flapping output can't distinguish a regression from sampling noise (see `evals`).

## 6. Prompt versioning — prompts are code

- **Version every production prompt** (a prompt id + version, in the repo or a prompt registry) so an output is attributable to a specific prompt version × model × params.
- **Never edit a prompt string in place with no trail.** A prompt change is a behavior change: bump the version, run the eval set, and review the eval-diff on the PR (see `evals`). "I tweaked the wording" without an eval-diff is an unmeasured quality change.
- **Pin the model + params with the prompt** — a prompt is only reproducible together with the model version and temperature/seed it was tuned against. A model upgrade re-runs the eval set before adoption.
- Keep prompts out of scattered inline literals where practical — centralize them so they're reviewable, diffable, and testable like any other code artifact.

## Detectors (cite-or-halt)

- **Regex/string-parsing free-text output where structured output exists** →
  - BAD: `const id = output.match(/ID:\s*(\w+)/)[1]` over a free-form completion.
  - GOOD: a tool/JSON-schema call returning `{ id }`, validated against the schema.
  - → `use-structured-output`
- **Instructions mixed with untrusted data in one blob** →
  - BAD: `prompt = systemRules + "\n" + userMessage + retrievedDocs` in a single string, one role.
  - GOOD: rules in the system message; user input + retrieved docs delimited in the user message, labeled as data.
  - → `split-system-user` (security — cross-link `llm-security`)
- **No output schema / validation** →
  - BAD: `JSON.parse(output)` with no schema check and no repair, passed downstream.
  - GOOD: schema-constrained output + validation + a bounded repair/fail-closed path.
  - → `add-output-schema`
- **`temperature > 0` on extraction/classification** →
  - BAD: a classifier called at `temperature: 0.7`.
  - GOOD: `temperature: 0` (+ seed where supported) for single-answer tasks.
  - → `set-deterministic-params`
- **Un-versioned prompt edited in place, no eval** →
  - BAD: an inline prompt literal changed in a PR with no version bump and no scores.
  - GOOD: a versioned prompt + an eval-diff on the PR.
  - → `version-and-eval-prompt`

**Closure verbs:** `use-structured-output`, `split-system-user`, `add-output-schema`, `set-deterministic-params`, `version-and-eval-prompt`.

## Related

- `evals` — a prompt change is only safe once it passes the eval gate; structured-output validation is itself an assertion scorer, and the eval-diff is the review artifact for a prompt edit.
- `rag-pipeline` — assembled retrieved context is untrusted data placed before the instruction and delimited; the no-context guard is expressed in the prompt.
- `agent-design` — tool definitions are structured-output schemas; the same schema-first, validate-the-args discipline applies to tool calls.
- `llm-gateway` — versioned prompts + pinned model/params are what the gateway routes and caches.
- Security `@llm-security-reviewer` / `llm-security` — system/user separation and delimiting untrusted content are the structural prompt-injection defenses; author the untrusted-content boundary WITH the security reviewer.
