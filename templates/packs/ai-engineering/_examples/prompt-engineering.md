---
name: prompt-engineering
description: 'Pattern: Prompt Engineering — structure, structured output, determinism, versioning'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: Prompt Engineering — structure, structured output, determinism, versioning

> **Hard rule:** A production prompt is **code**: structured, versioned, and eval-gated — not a string edited in place on a hunch. Where the provider offers structured output (tool/function-calling or a JSON/structured-output mode with a schema), you **use it and validate against the schema** — you NEVER regex-parse free text into a data structure. Instructions live in the **system** message; untrusted data (user input, retrieved docs, tool results) lives in the **user** message, delimited — mixing them is a prompt-injection hole. Extraction/classification are **constrained by whatever the provider still exposes** — the schema mode always, `temperature: 0` only where sampling params exist at all. Every prompt change goes through the eval gate.

**When to apply** — every LLM call site (assembly, parsing, versioning); especially extraction/classification (determinism + schema), untrusted-content consumers (system/user split), and any output code parses (structured output). **Not** a purely free-form creative surface never parsed — but versioning + system/user split still apply.

**Halt conditions / mandatory cites**
- **Regex/string-parsing free-text output where structured output exists** MUST be cited at `<path:line>`.
- Instructions concatenated with **untrusted data in one blob** (no system/user split, no delimiting) MUST be flagged (injection — cross-link `llm-security`).
- Structured-output call with **no schema validation / repair path** MUST be cited.
- **Sampling params wrong for extraction/classification** MUST be cited — `temperature > 0` where the provider exposes it, *or* a temperature set at all where the provider withdrew it (a non-default value is a 400 there, so the parameter is the defect).
- A prompt **edited in place, no version bump, no eval-diff** MUST be flagged (cross-link `evals`).

## 1. Structure

Separate + label the parts: **Role** (who it acts as), **Task** (one specific job), **Constraints** (allowed values, tone, "only use the context", "say you don't know if unsure"), **Format** (prefer a schema over prose about JSON), **Context/data** (delimited).
- **Put long context/documents BEFORE the instruction** for long-context models — better attention + lets the provider cache the stable prefix (cheaper/faster); the short variable instruction goes last.
- **Delimit untrusted content** (XML-style tags/fenced) and tell the model it's data, not instructions.
- **Give an out** — permit "I don't know" so it doesn't fabricate (ties to `rag-pipeline`).

## 2. Structured output — schema, don't scrape

Use the provider's **tool/function-calling / JSON / structured-output mode bound to a schema** — it constrains generation to conform. **Always validate** the response anyway (edge truncation/drift). **Repair path:** on validation failure, re-ask with the error (bounded retry) or fail closed — never pass a malformed object downstream. **NEVER regex-parse free text when a schema is available** — brittle, locale-fragile, fails silently. Prefer a flat, explicitly-typed schema with enums for closed sets.

## 3. Few-shot vs zero-shot

Start **zero-shot** on clear tasks (cheaper). Add **few-shot** for specific formats, edge cases, or nuanced label boundaries — examples teach where description falls short. Choose representative examples, cover edge + refusal/negative cases, match the exact output format; a few good beat many redundant (each costs tokens every call — cache a stable example block). Needing many examples to fix quality → fine-tune or fix retrieval, don't grow the prompt.

## 4. System vs user separation

Instructions/role/constraints/format → **system** (trusted, developer-controlled). Untrusted data (user input, retrieved docs, tool outputs) → **user**, delimited + labeled as data. Providers weight the system message higher, so this both improves adherence AND is the structural prompt-injection defense — an instruction smuggled in user data is far less likely to override system than one concatenated into the same blob. Never interpolate untrusted content into the system message. **Security boundary — cross-link `llm-security` / `@llm-security-reviewer`.**

## 5. Determinism

A single-answer task — extraction, classification, routing, structured output, tool-argument generation — must be constrained, or the same input yields different outputs across retries: a correctness bug that also makes evals noisy. **How is provider- and model-dependent and it changes underneath you.**

- **The schema mode is the constraint that always applies**, on every provider that has one; its *strict* variant, where offered, is the strongest control available. Reach for it before any sampling knob.
- **Sampling params EXPOSED** → `temperature: 0` (or lowest) + a fixed seed where supported. Best-effort even then; provider infra varies.
- **Sampling params REMOVED** → setting one is an error, not a no-op. On current Anthropic models (Opus 4.7+, Sonnet 5, Fable 5) a non-default `temperature`/`top_p`/`top_k` returns **HTTP 400**; the documented replacement is system-prompt instruction ([Sonnet 5 release notes](https://platform.claude.com/docs/en/about-claude/models/whats-new-sonnet-5), read 2026-08-23). A prompt tuned on an older model and carried forward 400s on the first call after the model id changes.
- **The durable rule: read the provider's current parameter reference for the model at the call site before writing a sampling parameter.** The product names above expire; the check does not.

Determinism makes the eval gate meaningful — a scorer over a flapping output can't tell a regression from noise (see `evals`).

## 6. Versioning — prompts are code

**Version every production prompt** (id + version) so an output is attributable to prompt-version × model × params. **Never edit in place with no trail** — bump the version, run the eval set, review the eval-diff on the PR (see `evals`). **Pin the model + params with the prompt** (only reproducible together); a model upgrade re-runs the eval set first **and re-checks the pinned params still exist on the new model** — one the new model withdrew turns the upgrade into a 400, not a quality question. Centralize prompts (not scattered inline literals) so they're reviewable/diffable/testable.

## Detectors (cite-or-halt)

- **Regex-parsing free-text where structured output exists** → BAD: `output.match(/ID:\s*(\w+)/)`; GOOD: schema-bound tool call, validated → `use-structured-output`
- **Instructions mixed with untrusted data in one blob** → GOOD: rules in system, data delimited in user → `split-system-user` (cross-link `llm-security`)
- **No output schema/validation** → `add-output-schema`
- **Sampling params wrong for extraction/classification** — inverts on provider state → EXPOSED, BAD `temperature: 0.7` → `set-deterministic-params`; REMOVED, BAD `temperature: 0` on a model that rejects it (a 400 every request, not a harmless no-op) → `remove-sampling-params`
- **Un-versioned prompt edited in place, no eval** → `version-and-eval-prompt`

**Closure verbs:** `use-structured-output`, `split-system-user`, `add-output-schema`, `set-deterministic-params`, `remove-sampling-params`, `version-and-eval-prompt`.

## Related

- `evals` — a prompt change is safe only through the gate; schema validation is an assertion scorer; the eval-diff is the review artifact.
- `rag-pipeline` — retrieved context is untrusted data before the instruction, delimited; no-context guard lives in the prompt.
- `agent-design` — tool definitions are output schemas; same validate-the-args discipline. `llm-gateway` — routes/caches versioned prompts + pinned params.
- Security `@llm-security-reviewer` / `llm-security` — system/user separation + delimiting are the injection defenses; author the boundary WITH the security reviewer.
