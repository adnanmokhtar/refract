---
name: prompt-audit
kind: example
pack: ai-engineering
description: Static sweep of prompt-assembly + output-parsing sites for the five prompt-engineering defects; one finding per site with <path:line> + excerpt + closure verb.
---

# Skill: prompt-audit

## Premise

A production prompt is code: structured, versioned, eval-gated. This skill reads the prompt surface as code and reports where it isn't. **Every finding cites `<path:line>` + a real 1-line excerpt + its closure verb** — for an absence, the concrete site that should carry it. It detects; it does not rewrite the prompt (`/add-ai-feature` Phase 4) and does not grade the injection exploit (`@llm-security-reviewer` LLM01).

## Adapt to the codebase

The defects are only defects relative to what the provider offers. Detect the SDK, then mirror its mechanism:

| Provider surface | Structured output via | System channel | Temperature |
|---|---|---|---|
| Anthropic SDK | tool use with `input_schema` | top-level `system=` | request param |
| OpenAI-compatible | function calling / JSON-schema response format | `system` role message | request param |
| Google GenAI | function declarations / response schema | system-instruction field | generation config |
| Self-hosted (vLLM / Ollama) | constrained decoding **where exposed** — otherwise NONE | usually a `system` role | sampling params |
| Framework wrapper | the wrapper's typed-output binding | its prompt-template slot | model-init kwargs |

**Report "no schema mechanism on this provider" as its own state**: `use-structured-output` no longer applies, and `add-output-schema` (validate + bounded repair) becomes mandatory, not advisory. Audit the gateway layer AND the call site — cite whichever decides.

## When to run

- Any diff touching a prompt, a model call, or an output parser; dispatched by `/ai-audit` and `@ai-feature-reviewer` dim 2.
- NOT for authoring or improving a prompt (that is `/add-ai-feature` Phase 4, measured by `eval-run`).

## The five detectors

1. **Free-text parsing where a schema exists** → `use-structured-output`. BAD: `out.match(/Total:\s*\$([\d.]+)/)`. GOOD: a typed schema through the provider's tool mode. Cite the parse line — that is where it executes. BLOCKER.
2. **Instructions concatenated with untrusted content** → `split-system-user`. BAD: `RULES + userMsg + docs` in one role. GOOD: rules in the system channel; user + retrieved content delimited as data. **Mandatory handoff line to `@llm-security-reviewer` (LLM01)** — report the engineering defect, never grade exploitability.
3. **Structured-output call with no validation, no repair** → `add-output-schema`. BAD: `JSON.parse(resp)` flowing onward. GOOD: parse → validate → bounded re-ask, else fail closed.
4. **Non-deterministic params on a single-answer task** → `set-deterministic-params`. BAD: a classifier at `temperature: 0.7`. An *unset* temperature is a finding only where the SDK default is non-zero — say which you observed. A generative surface is `N-A`, not a pass.
5. **Prompt with no version id** (or duplicated across sites) → `version-and-eval-prompt`. The version must reach the log line, the cache key, and the eval run. A prompt change with no eval-diff upgrades the finding and hands to `eval-run` / `/add-eval-set`.

## Output

```
prompt-audit — <scope> (provider=<detected>, schema-mode=<tool|json-schema|NONE>, sites=N)

BLOCKER  use-structured-output     extract/invoice.ts:52  `out.match(/Total:.../)`  → schema mode + validate
BLOCKER  add-output-schema         extract/invoice.ts:49  `JSON.parse(resp.content)` → validate + repair path
REQUEST  split-system-user         support/answer.ts:31   → HANDOFF @llm-security-reviewer (LLM01)
REQUEST  set-deterministic-params  classify/intent.ts:19  `temperature: 0.7` on a fixed-label classifier
NIT      version-and-eval-prompt   prompts/titles.ts:8 + titles-batch.ts:14 — duplicated, unversioned

Not applicable: draft/compose.ts:22 — generative surface, temperature 0.9 deliberate.
Schema mechanism: available. Where NONE, add-output-schema is mandatory.
```

## False positives / gotchas

- A regex over deliberately free-text output (pulling a fenced block, trimming) is not the defect — parsing *structured data* by regex is.
- Delimiting inside one role is better than concatenation, worse than the role split: REQUEST, and say which half is present.
- The framework may already set the system message or bind a typed output — read the wrapper and cite the line.
- Temperature 0 is not determinism (AI-5) — report the parameter, never claim reproducibility.
- A prompt in a registry is still versioned code; check the registry before reporting absence.

## Halt conditions

- A finding without `<path:line>` + excerpt (or the concrete absence site) → not emittable.
- Hand-wave grep (`etc.` / `several similar` / `N+ others` / `might`) → STOP and enumerate.
- **Provider surface not identified** → HALT detectors 1, 3, 4; report `UNVERIFIED` + name what settles it (the SDK import + lockfile version).
- Grading the injection exploit, or rewriting the prompt → out of scope; route it.

## References

- `ai/patterns/prompt-engineering.md` (the pattern), `evals.md`; skills `llm-gateway-audit` (the seam around the same calls), `eval-run`; `@ai-feature-reviewer` dim 2; `@llm-security-reviewer`; `.claude/rules/ai-engineering-principles.md` (AI-4/5/7).
