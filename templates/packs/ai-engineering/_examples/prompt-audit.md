---
name: prompt-audit
kind: example
pack: ai-engineering
description: "Inside each LLM call: structured output, stop reasons, model ids vs a dated table, per-model params, prompt versions."
---

# Skill: prompt-audit

## Premise

This skill reads what goes **into** an LLM call and what the code does with what comes **out**: an answer used before anyone checked it was complete (a `length` / `max_tokens` stop, a refusal, `incomplete`), a request valid only for a model that is gone (retired ids; a non-default `temperature` on Claude 4.7+, assistant prefill on 4.6+, a forced `tool_choice` on Opus 5.5 / Sonnet 5.5, `max_tokens` on OpenAI reasoning models), and rows nobody can attribute to a prompt version. **Model facts come from the dated `model-lifecycle.tsv`** (`llm-sites.py --models`, `STALE` past 90 days), never from memory.

**Every finding cites the call site from the inventory + the consumer or parameter line + the model id it reaches + the dated source + the oracle + the fix.**

## Boundaries

- Boundary: untrusted text in the system role, third-party content as the user's words, unfenced tool results (PI-1…4, 6, 7) → security `llm-trust-scan` §1 when installed (OWASP LLM Top 10 2026 v1.0 (2026-08-03) LLM01); counted here, never graded.
- Boundary: output at sinks → security sink detectors; budgets, loops, metering → `llm-gateway-audit`; eval gating → `eval-run`; prompt wording → `/add-ai-feature`.

## Scans for

| § | Class | Default | Oracle |
|---|---|---|---|
| S1 | SO-1 regex over free text where a schema mode exists (`use-structured-output`) | high | V534 |
| S2 | SO-2 JSON with no schema check (`validate-output-schema`) | medium | V534 |
| S3 | SO-3, SO-4 stop reason or refusal not read (`add-stop-reason-check`) | medium | V534 |
| S4 | SO-5 unbounded validation retries (`bound-retries`) | medium | V534 |
| S5 | SO-6 non-strict schema (`validate-output-schema`) | low | V535 |
| V1 | MV-1, MV-2, MV-5, EV-7 retired, deprecated or moving ids (`pin-model-id`) | high past date | V532 |
| V2 | MV-3 env model id with no validation (`validate-model-config`) | low | V532 |
| V3 | MV-4, TF-2, PM-3 parameter invalid for the model (`fix-model-params`) | medium | V533 |
| P | PM-1, PM-2, PI-5 no prompt version; instructions in tool results (`version-and-eval-prompt`) | low | V538 |
| R | PI-1…4, 6, 7 | routed | owner's |

## Output

```
prompt-audit — lanes: openai-compatible raw gateway; models.tsv 0 rows (table checked 2026-10-19)
1. apps/api/src/chat/assistant-transport.ts:51  [report-with-fix]  medium  §S3 finish_reason never read; a `length` stop is stored and charged. Verb: add-stop-reason-check
2. apps/api/src/orders/extraction.ts:161        [report-flagged]   medium  §V3 forced tool_choice, model from env: read the deployed id. Verb: fix-model-params
Class coverage: every § as checked | N/A (<reason>) | blocked (lifecycle table stale)
```

## When to run

On any diff touching a prompt, a model id (code, `.env*`, IaC, eval config), a request parameter, or code that parses, stores, executes or bills model output; on every whole-repo `/ai-audit`; before a model bump.

## Halt conditions

- `llm-sites.py` exit 2, or a STALE lifecycle table for §V1 → `blocked`. No retirement date or parameter rule from memory.
- §V3 without the model id the call reaches is Unconfirmed with its probe, never a pass either way.
- Routed trust classes are counted, never graded. High rows pass `refute-before-report.md` first. Never "no findings" without the coverage block.
