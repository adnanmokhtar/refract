---
name: prompt-audit
description: Static sweep of every prompt-assembly and output-parsing site for the five prompt-engineering defects — free-text regex/split/JSON.parse where the provider offers a schema, instructions concatenated with untrusted user or retrieved content in one blob, a structured-output call with no schema validation and no repair path, sampling parameters wrong for a single-answer call (temperature > 0 where the provider exposes it — or a temperature set at all where the provider has removed it and a non-default value is a 400), and a prompt literal with no version id feeding logs + cache key + eval run. Emits one finding per site with <path:line> + a real excerpt + the pattern's closure verb. TRIGGER — any diff touching a prompt, a model call, or an output parser; dispatched by /ai-audit and by @ai-feature-reviewer dimension 2. ANTI-TRIGGERS (do NOT fire) — authoring or improving a prompt (that is /add-ai-feature Phase 4); the prompt-injection exploit judgment or the output→sink review (that is @llm-security-reviewer LLM01:2026/LLM10:2026 — this skill reports the missing system/user split as an engineering defect and names the handoff); running the eval set (eval-run); building one that does not exist (/add-eval-set).
kind: skill
pack: ai-engineering
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: prompt-audit

## Premise

A production prompt is code: structured, versioned, eval-gated. This skill reads the prompt surface as code and reports where it isn't — five defect classes, each already written as a BAD/GOOD pair in `ai/patterns/prompt-engineering.md`, each anchorable to a line.

**Every finding cites `<path:line>` + a real 1-line excerpt from that line + the closure verb that closes it.** For an *absence* finding (no schema validation, no version id) the citation is the concrete site that should have carried it — the parse call, the prompt literal — not "the prompt module". No site, no excerpt, no verb → it is a vibe, not a finding. This skill detects and reports; it does not rewrite the prompt (that is `/add-ai-feature` Phase 4) and it does not grade the injection exploit (that is `@llm-security-reviewer`).

## Adapt to the codebase

The five defects are only defects **relative to what the provider offers**. Detect the SDK in use from `_extracted-codebase.md § AI/LLM integration` (or the lockfile) and mirror its mechanism — the audit asks "did this call site use the mechanism this provider has", never "did it use the mechanism I know".

| Provider surface | Structured output declared via | System channel expressed as | Sampling controls |
|---|---|---|---|
| Anthropic SDK | `output_config.format` with `{type: "json_schema", schema: …}` (GA — the older `output_format` is deprecated), and/or tool use: a `tools=` entry with an `input_schema` plus **`strict: true`** to guarantee the input validates | a top-level `system=` parameter, separate from `messages` | **REMOVED on current models** — see the state table below |
| OpenAI-compatible SDK | function/tool calling, or a structured-output / `response_format` JSON-schema mode | a `system` (or `developer`) role message at the head of `messages` | request param on the completion call |
| Google GenAI SDK | function declarations, or a response schema on the generation config | a system-instruction field on the model/config | generation-config field |
| Self-hosted (vLLM / Ollama / llama.cpp server) | grammar- or JSON-schema-constrained decoding **where the server exposes it** — otherwise **none** | usually an OpenAI-compatible `system` role; sometimes a chat template only | sampling params on the request |
| A framework wrapper (LangChain / LlamaIndex / Instructor / a house gateway) | the wrapper's typed-output binding, which delegates to one of the above | the wrapper's system-message/prompt-template slot | the wrapper's model-init kwargs |

**Sampling parameters have three states, not two. Establish which one this project is in before grading detector 4:**

| State | What it means | What a single-answer task uses |
|---|---|---|
| `EXPOSED` | the provider accepts `temperature` / `top_p` / `top_k` | `temperature: 0` (+ seed where supported), *plus* the schema mode |
| `DEFAULT-NONZERO` | exposed, and left unset while the documented default is > 0 | same — but say which default you observed |
| `REMOVED` | the provider rejects a non-default value | the schema mode + system-prompt instruction. **Setting temperature at all is the defect** |

`REMOVED` is live today, not hypothetical: on current Anthropic models (Opus 4.7 and later, Sonnet 5, Fable 5) a non-default `temperature`, `top_p`, or `top_k` returns **HTTP 400** — *"Setting `temperature`, `top_p`, or `top_k` to a non-default value returns a 400 error … Use system-prompt instructions to guide model behavior"* ([Sonnet 5 release notes](https://platform.claude.com/docs/en/about-claude/models/whats-new-sonnet-5), read 2026-08-23). Read the model id at the call site, then the provider's **current** parameter reference. Do not carry this table's verdict forward without re-reading it — the whole point of the state column is that the answer expires.

**Report "no schema mechanism available on this provider/model" as its own state.** Where the detected surface genuinely offers no constrained-decoding path, `use-structured-output` is not the finding — the finding becomes `add-output-schema`: validation + a bounded repair path is then **mandatory, not optional**, because nothing else constrains the response. Downgrading the finding silently because "the SDK can't do it" is the failure this row exists to prevent.

Where a house gateway module wraps the SDK, audit **both** layers: the gateway may set a default temperature or a default schema mode that the call site overrides. Cite the layer that actually decides — and on a `REMOVED` provider a gateway-level default temperature is a **BLOCKER**, because it breaks every call routed through the seam, not one site.

## When to run

- On any diff touching a prompt string/template, a model call, or a function that parses model output.
- Dispatched by `/ai-audit` (prompt axis) and by `@ai-feature-reviewer` (dimension 2, prompt quality).
- Before `/add-eval-set` on a feature whose prompt is unversioned — a set scored against a prompt nobody can pin is unattributable.
- NOT for authoring a prompt, choosing wording, or improving quality — this skill reports mechanism defects, not phrasing. Wording changes are `/add-ai-feature` Phase 4, measured by `eval-run`.

## Map the surface first

Adapt these to the project's language and SDK; enumerate every hit, never a count:

- **Prompt assembly** — `rg -n "system|systemPrompt|SYSTEM_PROMPT|messages|prompt|template" src`
- **Model calls** — `rg -n "messages.create|chat.completions|generate_content|generateText|invoke|complete\(" src`
- **Output parsing** — `rg -n "JSON.parse|json.loads|\.match\(|re\.(search|findall)|\.split\(|regex" src` narrowed to lines downstream of a model call
- **Schema declarations** — `rg -n "input_schema|response_format|response_schema|tools=|function_declarations|zodResponseFormat|BaseModel|pydantic" src`
- **Sampling params** — `rg -n "temperature|top_p|top_k|seed" src`
- **Model ids** — `rg -n "model\s*[:=]|MODEL|_MODEL" src` — detector 4 cannot be graded without them; the same `temperature: 0` line is correct on one model and a 400 on another
- **Prompt version ids** — `rg -n "prompt_version|promptVersion|PROMPT_V|version.*prompt" src`

## The five detectors

### 1. Free-text parsing where a schema exists → `use-structured-output`

**Fingerprint:** a regex, `.split()`, index-slice, or bare `JSON.parse`/`json.loads` applied to a completion's text, on a provider surface that offers tool/schema mode.

- BAD: `const total = out.match(/Total:\s*\$([\d.]+)/)[1]` over a free-form completion.
- GOOD: the call declares a typed schema (`{ total: number, currency: string }`) through the provider's tool/structured-output mode; the response is the object.

Cite the parse line, not the call line — that is where the defect executes. Severity is BLOCKER: it fails silently on any phrasing drift, which is a class of bug no test written against today's output will catch.

### 2. Instructions concatenated with untrusted content → `split-system-user`

**Fingerprint:** one string built from developer instructions **plus** user input and/or retrieved chunks, sent in a single role — or untrusted content interpolated into the system channel.

- BAD: `prompt = RULES + "\n" + userMessage + "\n" + retrievedDocs` sent as one user message.
- GOOD: rules in the provider's system channel; user input and retrieved documents in the user message, delimited and labelled as data.

**This finding carries a mandatory handoff line.** Report it here as an engineering defect (adherence + un-reviewable prompt boundary) and name `@llm-security-reviewer` LLM01:2026 as the owner of the injection judgment. Do not grade exploitability, do not write the payload, do not clear it.

### 3. Structured-output call with no validation and no repair path → `add-output-schema`

**Fingerprint:** a schema-mode call whose result flows onward with no validation step, or a `JSON.parse`/`json.loads` with no schema check and no bounded retry/fail-closed branch. Also fires where the provider offers a **guaranteed-validation** variant the call site declined — an Anthropic tool definition without `strict: true`, for instance, still admits an input that violates its own `input_schema`.

- BAD: `const obj = JSON.parse(resp.content); return obj.items[0].id` — one truncated response away from a crash or a wrong value.
- GOOD: parse → validate against the declared schema → on failure, re-ask once with the validation error, else fail closed.

"The model usually returns valid JSON" is the belief this detector exists to kill. On a provider with **no** schema mechanism (see the table), this is the most severe finding available, not a nit.

### 4. Sampling controls wrong for a single-answer task → `set-deterministic-params` / `remove-sampling-params`

**Fingerprint depends on the sampling state you established above. Grade the state first; the finding inverts between them.**

On an `EXPOSED` / `DEFAULT-NONZERO` provider → **`set-deterministic-params`**:
- BAD: a fixed-label intent classifier called at `temperature: 0.7`.
- GOOD: `temperature: 0` (plus a seed where the provider supports it), *and* the schema mode from detector 1.

On a `REMOVED` provider → **`remove-sampling-params`**, the opposite finding:
- BAD: `temperature: 0` on a classifier hitting a current Anthropic model — this is not a safe no-op, it is an **HTTP 400 on every request**.
- GOOD: no sampling parameter at all; the single-answer constraint comes from `output_config.format` / `strict: true` tools plus an explicit system-prompt instruction.

Severity on `remove-sampling-params` is **BLOCKER**, not REQUEST — the call does not degrade, it fails. Cite the model id you read and the line that sets the parameter.

Three care points: an **unset** temperature is a finding only when the SDK's documented default is non-zero — say which you observed. A genuinely generative surface (draft, brainstorm, chat) is `N-A`, not a pass; name it as out of scope rather than grading it green. And if you could not determine the model id, the axis is `UNVERIFIED — model id not resolved`, never a pass in either direction: the same line is correct on one model and a 400 on another, so an ungrounded verdict here is worse than no verdict.

### 5. Prompt with no version id → `version-and-eval-prompt`

**Fingerprint:** a prompt literal or template with no version identifier flowing into the log line, the cache key, and the eval run — or the same prompt duplicated across call sites, which guarantees drift and means only one copy is eval-covered.

- BAD: an inline system-prompt string edited in a PR with no version bump and no scores.
- GOOD: an owned, versioned prompt module; the version id appears in the gateway log line and the cache key; the PR carries an eval-diff.

Where the diff **changes** a prompt and no eval-diff is present, this finding upgrades: name it and hand the measurement to `eval-run` (or `/add-eval-set` if no harness exists). An unversioned prompt also makes `llm-gateway-audit`'s cache-key finding un-fixable — cross-reference it when both fire.

## Output

```
prompt-audit — <scope> (provider=<detected>, model=<id read at the call site>, schema-mode=<json-schema|tool-strict|tool|constrained|NONE>, sampling=<EXPOSED|DEFAULT-NONZERO|REMOVED|UNVERIFIED>, sites=<N>)

Findings (5):
  BLOCKER  use-structured-output       src/extract/invoice.ts:52
           `const total = out.match(/Total:\s*\$([\d.]+)/)[1]`
           Free-text regex over a completion; the SDK exposes tool schemas. Drift drops the field silently.
  BLOCKER  add-output-schema           src/extract/invoice.ts:49
           `const obj = JSON.parse(resp.content)`
           No schema validation, no repair path — a truncated response reaches the caller as a wrong object.
  REQUEST  split-system-user           src/support/answer.ts:31
           `prompt = RULES + "\n" + msg + docs`
           Instructions + user text + retrieved chunks in one role. → HANDOFF @llm-security-reviewer (LLM01:2026).
  REQUEST  set-deterministic-params    src/classify/intent.ts:19
           `temperature: 0.7`
           Fixed-label classifier; same input yields different labels and the eval is noisy.
  NIT      version-and-eval-prompt     prompts/titles.ts:8, prompts/titles-batch.ts:14
           Near-identical system prompt at two sites, no version id in either.

Not applicable:
  set-deterministic-params — src/draft/compose.ts:22 is a generative surface (temperature 0.9 is deliberate).

Handed to @llm-security-reviewer:
  - src/support/answer.ts:31 — untrusted user + retrieved content share the instruction blob (LLM01:2026).

Schema mechanism: available (tool schemas). Where NONE, add-output-schema is mandatory, not advisory.
Sampling state: EXPOSED (read from <model id> against the provider's current parameter reference, <date>).
  Had it been REMOVED, the classifier finding above inverts to BLOCKER remove-sampling-params.
```

## False positives / gotchas

- **A regex over model output is not automatically a defect.** Extracting a fenced code block from a deliberately free-text answer, or trimming whitespace, is fine. The defect is regex used *as the parser for structured data* the schema mode could have returned typed.
- **Delimiting is not the same as splitting roles.** A single-role prompt with XML-style tags around the untrusted block is better than raw concatenation and worse than the system/user split — grade it REQUEST, say which half is present, don't call it clean.
- **The framework may already do it.** Wrapper libraries often set a system message or bind a typed output behind one call. Read the wrapper before reporting the absence; cite the wrapper line that proves it.
- **Temperature 0 is not determinism.** Provider infrastructure, model version rollovers, and caching all still vary output. Report the parameter, never claim reproducibility the runtime cannot give (AI-5).
- **"The parameter is harmless if the provider ignores it" is false.** A withdrawn sampling parameter is rejected, not ignored — the request 400s. This is why detector 4 grades the *state* before the value, and why a stale copy of this table is a worse input than none.
- **A prompt in a database or a prompt registry is still versioned code** — the version id must reach the log + cache key + eval run. Absence of a file is not absence of versioning; check the registry before reporting.
- **Duplicated prompts across a monorepo's packages** may be deliberate vendoring. Confirm they are meant to be one prompt before calling it drift.

## Halt conditions

- **A finding without `<path:line>` + a real excerpt (or the concrete site that should carry the missing thing)** → not emittable. Re-enumerate or drop.
- **The hand-wave grep** — if a draft finding contains `etc.` / `…` / `several similar` / `N+ others` / `consider` / `seems` / `might`, STOP and enumerate each site individually. A count is not a citation.
- **Provider surface not identified** → HALT before grading detectors 1, 3, and 4 — "should have used a schema" is unprovable until you know whether one exists. Report the axis as `UNVERIFIED — provider surface not identified` and name what would settle it (the SDK import + its version from the lockfile).
- **Grading the injection exploit** → forbidden. Detector 2 is reported as an engineering defect and HANDED to `@llm-security-reviewer`; never absorbed, never cleared here.
- **Rewriting the prompt** → out of scope. This skill emits verbs; `/add-ai-feature` Phase 4 applies them and `eval-run` proves the change.

## References

- `ai/patterns/prompt-engineering.md` — the pattern this skill mechanizes: structure, structured output, few-shot, system/user separation, determinism, versioning. Owner of the *what*; this skill is the *find it*.
- `ai/patterns/evals.md` — a prompt change is unmeasured until the eval-diff exists; `version-and-eval-prompt` closes into that gate.
- `llm-gateway-audit` — sibling skill on the same call sites: it audits the seam (timeout, cap, fallback, cache, cost, redaction); this one audits what is *inside* the call. A cache key that is not versioned by prompt version is its finding and this skill's detector 5 combined.
- `eval-run` — measures the prompt change this skill flags as unmeasured; `/add-eval-set` builds the harness when `eval-run` halts.
- `@ai-feature-reviewer` — dispatches this skill for dimension 2 and folds its findings into the PR verdict.
- `@llm-security-reviewer` (security pack) — owns LLM01:2026 prompt injection and LLM10:2026 improper output handling (LLM05 in the 2025 edition); detector 2 hands across, always.
- `.claude/rules/ai-engineering-principles.md` — AI-4 (structured output, never regex), AI-5 (constrain single-answer tasks with the mechanism the provider actually exposes; no undated provider-behaviour claim), AI-7 (prompts are versioned code).
