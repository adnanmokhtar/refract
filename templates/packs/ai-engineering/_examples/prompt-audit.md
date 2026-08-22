---
name: prompt-audit
kind: example
pack: ai-engineering
description: Static sweep of prompt-assembly + output-parsing sites for the five prompt-engineering defects; one finding per site with <path:line> + excerpt + closure verb.
---

# Skill: prompt-audit

## Premise

A production prompt is code: structured, versioned, eval-gated. This skill reads the prompt surface as code and reports where it isn't. **Every finding cites `<path:line>` + a real 1-line excerpt + its closure verb** — for an absence, the concrete site that should carry it. It detects; it does not rewrite the prompt (`/add-ai-feature` Phase 4) and does not grade the injection exploit (`@llm-security-reviewer` LLM01:2026).

## Adapt to the codebase

The defects are only defects relative to what the provider offers. Detect the SDK, then mirror its mechanism:

| Provider surface | Structured output via | System channel | Sampling controls |
|---|---|---|---|
| Anthropic SDK | `output_config.format` json_schema (GA; `output_format` is deprecated) and/or tool use with `input_schema` + **`strict: true`** | top-level `system=` | **REMOVED on current models** — see the state table |
| OpenAI-compatible | function calling / JSON-schema response format | `system` role message | request param |
| Google GenAI | function declarations / response schema | system-instruction field | generation config |
| Self-hosted (vLLM / Ollama) | constrained decoding **where exposed** — otherwise NONE | usually a `system` role | sampling params |
| Framework wrapper | the wrapper's typed-output binding | its prompt-template slot | model-init kwargs |

**Sampling has three states, and detector 4 inverts between them. Establish the state before grading:**

| State | Meaning | A single-answer task uses |
|---|---|---|
| `EXPOSED` | provider accepts `temperature`/`top_p`/`top_k` | `temperature: 0` (+ seed where supported) **plus** the schema mode |
| `DEFAULT-NONZERO` | exposed, unset, documented default > 0 | same — and say which default you observed |
| `REMOVED` | provider rejects a non-default value | schema mode + system-prompt instruction; **setting temperature at all is the defect** |

`REMOVED` is live, not hypothetical: on current Anthropic models (Opus 4.7+, Sonnet 5, Fable 5) a non-default `temperature`/`top_p`/`top_k` returns **HTTP 400** ([Sonnet 5 release notes](https://platform.claude.com/docs/en/about-claude/models/whats-new-sonnet-5), read 2026-08-23). Read the model id at the call site, then the provider's **current** parameter reference — this table's verdict expires, which is why the state column exists.

**Report "no schema mechanism on this provider" as its own state**: `use-structured-output` no longer applies, and `add-output-schema` (validate + bounded repair) becomes mandatory, not advisory. Audit the gateway layer AND the call site — cite whichever decides; on a `REMOVED` provider a gateway-level default temperature is a BLOCKER, since it breaks every call through the seam.

## When to run

- Any diff touching a prompt, a model call, or an output parser; dispatched by `/ai-audit` and `@ai-feature-reviewer` dim 2.
- NOT for authoring or improving a prompt (that is `/add-ai-feature` Phase 4, measured by `eval-run`).

## The five detectors

1. **Free-text parsing where a schema exists** → `use-structured-output`. BAD: `out.match(/Total:\s*\$([\d.]+)/)`. GOOD: a typed schema through the provider's tool mode. Cite the parse line — that is where it executes. BLOCKER.
2. **Instructions concatenated with untrusted content** → `split-system-user`. BAD: `RULES + userMsg + docs` in one role. GOOD: rules in the system channel; user + retrieved content delimited as data. **Mandatory handoff line to `@llm-security-reviewer` (LLM01:2026)** — report the engineering defect, never grade exploitability.
3. **Structured-output call with no validation, no repair** → `add-output-schema`. BAD: `JSON.parse(resp)` flowing onward. GOOD: parse → validate → bounded re-ask, else fail closed. Also fires where a guaranteed-validation variant was declined — an Anthropic tool without `strict: true` still admits input violating its own schema.
4. **Sampling controls wrong for a single-answer task** — the finding *inverts* on the state above. `EXPOSED`/`DEFAULT-NONZERO` → `set-deterministic-params`; BAD: a classifier at `temperature: 0.7`. `REMOVED` → **`remove-sampling-params`, BLOCKER**; BAD: `temperature: 0` on a current Anthropic model — not a safe no-op, an HTTP 400 on every request; GOOD: no sampling parameter, constraint from the schema mode + system prompt. An *unset* temperature is a finding only where the documented default is non-zero — say which you observed. A generative surface is `N-A`, not a pass. Model id unresolved → `UNVERIFIED`, never a pass in either direction.
5. **Prompt with no version id** (or duplicated across sites) → `version-and-eval-prompt`. The version must reach the log line, the cache key, and the eval run. A prompt change with no eval-diff upgrades the finding and hands to `eval-run` / `/add-eval-set`.

## Output

```
prompt-audit — <scope> (provider=<detected>, model=<id>, schema-mode=<json-schema|tool-strict|tool|NONE>, sampling=<EXPOSED|DEFAULT-NONZERO|REMOVED|UNVERIFIED>, sites=N)

BLOCKER  use-structured-output     extract/invoice.ts:52  `out.match(/Total:.../)`  → schema mode + validate
BLOCKER  add-output-schema         extract/invoice.ts:49  `JSON.parse(resp.content)` → validate + repair path
REQUEST  split-system-user         support/answer.ts:31   → HANDOFF @llm-security-reviewer (LLM01:2026)
REQUEST  set-deterministic-params  classify/intent.ts:19  `temperature: 0.7` on a fixed-label classifier
NIT      version-and-eval-prompt   prompts/titles.ts:8 + titles-batch.ts:14 — duplicated, unversioned

Not applicable: draft/compose.ts:22 — generative surface, temperature 0.9 deliberate.
Schema mechanism: available. Where NONE, add-output-schema is mandatory.
Sampling state: EXPOSED (read from <model id> against the provider's current reference, <date>).
  Had it been REMOVED, the classifier finding inverts to BLOCKER remove-sampling-params.
```

## False positives / gotchas

- A regex over deliberately free-text output (pulling a fenced block, trimming) is not the defect — parsing *structured data* by regex is.
- Delimiting inside one role is better than concatenation, worse than the role split: REQUEST, and say which half is present.
- The framework may already set the system message or bind a typed output — read the wrapper and cite the line.
- Temperature 0 is not determinism (AI-5) — report the parameter, never claim reproducibility.
- **A withdrawn sampling parameter is rejected, not ignored** — the request 400s. Grade the state before the value; a stale copy of the table above is a worse input than none.
- A prompt in a registry is still versioned code; check the registry before reporting absence.

## Halt conditions

- A finding without `<path:line>` + excerpt (or the concrete absence site) → not emittable.
- Hand-wave grep (`etc.` / `several similar` / `N+ others` / `might`) → STOP and enumerate.
- **Provider surface not identified** → HALT detectors 1, 3, 4; report `UNVERIFIED` + name what settles it (the SDK import + lockfile version).
- Grading the injection exploit, or rewriting the prompt → out of scope; route it.

## References

- `ai/patterns/prompt-engineering.md` (the pattern), `evals.md`; skills `llm-gateway-audit` (the seam around the same calls), `eval-run`; `@ai-feature-reviewer` dim 2; `@llm-security-reviewer`; `.claude/rules/ai-engineering-principles.md` (AI-4/5/7).
