---
artifact: decision-engine
purpose: How /setup-project reasons over its 4 inputs and resolves conflicts.
imported-by: commands/setup-project.md (orchestrator) and every phase that branches on mode/track.
---

## 🧭 Decision engine — how this command REASONS

Not a blind template dump. The brain has 4 inputs, 4 outputs, and explicit weighting between them.

### Inputs (the brain looks at all 4-5 before deciding anything)

| Input | What it answers | Source |
|---|---|---|
| **Tech stack** | "What languages / frameworks / DBs / infra?" | Manifests + lock files + folder probes (Appendix A). |
| **Business domain** | "What kind of product is this? (ecommerce / lms / fintech / ...)" | Entity names + folder names + dep hints + prompt + ask. |
| **Project intent** | "Why does this exist, for whom, at what maturity?" | README + prompt + asking the user (Phase 2.y). |
| **Existing setup** | "What's already in `.claude/` + `ai/`?" | Direct file scan. |
| **Prior knowledge (REFRESH only)** | "What durable insights did the previous setup capture that the codebase alone can't tell us?" | Phase 0.2 extract: ADRs, custom glossary, validated corrections, project-intent answers, custom rules — sourced from existing setup files BEFORE regen. |
| **Prior failures** | "What have we already tried that failed — so we don't propose it again?" | `ai/failures/_index.md` (the failure catalog — see Advanced Capabilities § 4). |

The brain refuses to proceed past detection if any input is genuinely unknown. It asks ONE consolidated question instead of guessing.

**Failure-history tie-breaking**: when a proposed approach matches a `validated_failure` in `ai/failures/_index.md`, the brain MUST surface the failure in the plan + require explicit override. Pack rule says "use approach X" + failure entry says "we tried X, broke" → failure wins for current state; the rule applies only after the failure is superseded with new evidence.

**REFRESH-mode tie-breaking (input 5 vs others)**: prior knowledge wins on ANYTHING the user / team explicitly answered before — domain glossary, project intent facets, validated corrections, custom rules. Codebase wins on ANYTHING that's structural — current stack, base classes, paths, conventions actually in code. If they conflict (e.g., extract says "we use `<SomeBaseClass>`" but the current codebase shows it's been removed or renamed), CODE WINS for current state and the conflict is logged as a "stale extract item" in Phase 5 audit.

### Decision rules (how inputs combine)

1. **Stack alone is insufficient.** A NestJS+Postgres ecommerce project and a NestJS+Postgres LMS share zero domain knowledge. Domain wins on what content gets generated; stack wins on HOW it's expressed.
2. **Project intent overrides domain defaults.** If domain = ecommerce but intent = "internal tool, not for sale", skip billing/compliance bloat.
3. **Existing setup wins on overlap.** Project-idiom files (>200 lines, framework-specific) NEVER get replaced by generic packs; generic packs go alongside.
4. **Specialized agent wins over generic.** If `nestjs-architect` exists in repo, don't add `api-architect`; add the gap-fillers only.
5. **Pack templates copied verbatim** *(COPY-mode tracks only)*. Reference-path injection adapts; never trims. Output shorter than source = bug. **In AUTHOR-mode tracks (rule 7), this rule does not apply** — output is generated from extraction.
6. **Workspace cascade is N+1, not 1.** Workspace root gets orchestration; each sub-project gets its own full setup matched to its own stack + domain.
7. **Pack content is nucleus, codebase is full picture.** When a track's pack ships `_topics.md` AND Phase 2.5 produced extraction signal, the pack body is INSPIRATION, not output. Output is authored from `.claude/_extracted-idioms.md` + the topic spec — citing real paths, real extenders, real pitfalls. When a pack ships an optional `_examples/` directory, those files are fallback ONLY when extraction yields no signal (true greenfield, or base class with <3 extenders); if no `_examples/<topic>.md` exists, fall back to the closest literal template in that pack's `agents/`, `skills/`, or `ai-patterns/` or generate a stub from `_topics.md` section headings. This rule inverts the historical default ("packs are templates"); it's what closes the gap between hand-written project knowledge and generated setup. See Phase 2.5 + Phase 4.2-AUTHOR.

### Tie-breaking (when inputs disagree)

| Conflict | Winner |
|---|---|
| Prompt says X, manifest says Y (different stacks) | **Ask user.** Don't silently pick. |
| Detection says ecommerce + 50% confidence; prompt says SaaS-B2B | **Prompt wins** + log "stack-only signals were weak". |
| ADR says hexagonal; code is layered MVC | **Code wins** for current state; offer to write a "drift" ADR. |
| Two domains both have 3+ signals (ecommerce + affiliate) | **Both apply** (union). |
| Pack agent + project agent overlap by name | **Project wins.** Pack version goes to `.claude/agents/_pack-<name>.md` for reference. |
| Pack rule says generic X; detected convention says Y | **Detected wins.** Generated rule has "Project-specific (from `.claude/codebase-profile.md`)" block at TOP citing Y; pack rule body remains below as the general principle. Both visible; project's overrides what's generic. |
| Pack pattern says approach X; codebase uses approach Y | **Codebase wins.** Generated pattern annotates: "This project uses Y instead of X. See `<example file>`. The pack's X approach below is for context only." |
| Pack template uses generic file naming; detected uses kebab-case + suffix matrix | **Detected wins.** Every generated example, scaffold output, agent's "File list" section uses the detected naming. |

### Uncertainty handling

The brain **explicitly flags** when it's not confident:
- `[CONFIDENT]` — 3+ converging signals.
- `[INFERRED]` — 1-2 signals or single source.
- `[UNKNOWN — assumed default]` — no signal; default applied; ASK in plan.
- `[CONFLICT]` — signals disagree; ASK in plan.

Output every classification with a confidence tag in the plan. User reviews before apply.

### Self-audit (the brain checks its own output)

Phase 5 runs cross-reference / naming / contradiction / coverage / idempotency checks. Failures halt the apply — they're bugs in the brain's reasoning, not user issues. Full check list: see Phase 5.2.

### 8-step pipeline

1. **DETECT** — deterministic scans (Appendix A). Facts with evidence.
2. **CLASSIFY** — shape × mode × phase × signals × business-domain × intent.
3. **FILTER** — strip irrelevant (Appendix B).
4. **DECIDE per-file** — merge matrix (Appendix C) + tie-breaking rules above.
5. **GENERATE-on-signal** — missing agent for a strong signal? Generate from external library / best practices + save to pack.
6. **ADAPT** — inject profile-detected paths AND convention-aware prose into generic agents/rules (see Phase 4.6).
7. **AUDIT** — self-consistency check before reporting (cross-references, naming, contradictions, coverage, idempotency, no-ghost-files).
8. **REPORT** — every decision explainable, every uncertainty surfaced.

Supports `--dry-run`, `--force-*`, `--include=<signal>`, `--tools=<list>`, `--add-tool=<name>`.

---

## Unified execution flow

Same 5 phases whether CREATE, ENHANCE-retrofit, ENHANCE-extend, or REFRESH. REFRESH adds a Phase 0 (backup + extract) before Phase 1; every other phase still runs but with prior knowledge as additional input. No mode-specific parallel flows.

