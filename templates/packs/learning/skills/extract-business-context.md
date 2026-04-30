---
name: extract-business-context
description: Extract the project's WHY — mission, target users, business model, success KPIs, constraints, anti-goals, competitive context, maturity stage — from README + git log + manifest description + ai/status.md. Asks the user ONE consolidated question only for facets nothing in the repo answers. Outputs `.claude/_extracted-business.md`, consumed by Phase 4.7b to populate `ai/project-goals.md`, `ai/users-and-personas.md`, `ai/business-model.md`, `ai/competitive-context.md`, `ai/roadmap.md`.
---

# Skill: extract-business-context

## Purpose

Stack tells what tech. Domain (ecommerce/lms/etc.) tells what kind of product. THIS skill captures **why this specific product exists, for whom, at what maturity, with what constraints** — the facets that distinguish two ecommerce projects from each other.

Without this output, generated content (CLAUDE.md opener, agent personas, rule prose) addresses a generic "user" instead of the project's actual primary persona, and proposes solutions that ignore the project's real constraints (latency budget, regulatory regime, team size).

## Premise

- Real source is the truth. Read README + manifests + `ai/status.md` + git log + LICENSE + prior `ai/project-goals.md` before composing a single facet answer.
- Every `[CONFIDENT]` claim cites the source file (or `<path:line>` for inline mentions).
- Every `[INFERRED]` claim names the circumstantial signal it derived from (e.g. "maturity inferred from 18-month repo age + 14 ADRs").
- Empty extraction is honest — `[UNKNOWN]` + `_UNKNOWN — fill in when decided_` is a valid facet outcome.
- Fabrication — inferring a persona from a logo, a KPI from a hunch, a competitor from training-data memory — is the failure mode downstream files inherit forever.

## Mechanical halt

- Hand-wave answers — `enterprise users`, `typical SaaS`, `standard subscription`, `appears to target`, `roughly MVP-stage`, any claim without source attribution — REFUSE to write.
- Re-derive from a cited source OR downgrade to `[UNKNOWN]` and surface in the consolidated question.
- If a facet has no signal in any source AND `interactive: false`, write `<NOT-DETECTED: <facet>: no signal in <sources searched>>` plus `_UNKNOWN_` — never synthesize an answer to make the file look complete.
- Phase 5 audit surfaces every `<NOT-DETECTED>` row so the user can re-run with `--interactive` to fill it.

## When to use

- `/setup-project` Phase 2 — invoked by `extract-codebase-overview` Step 13.
- On-demand by `/refresh-knowledge` after a strategy pivot, persona shift, or KPI change.

## Inputs

- `project_root` — absolute cwd.
- `output_path` — defaults to `<project_root>/.claude/_extracted-business.md`.
- `interactive` — if `false`, never asks; missing facets recorded as `_UNKNOWN — fill in when decided_`.

## Procedure

### Step 1 — Mine the obvious sources first (no questions yet)

Read in priority order. Each source MAY answer multiple facets; record everything found:

| Source | What to extract |
|---|---|
| `README.md` (root) | Mission paragraph, target user mentions, screenshots/feature list, install/quick-start (signals maturity), badges (CI / coverage / version). |
| `package.json` / `pyproject.toml` / `Cargo.toml` / `composer.json` description + keywords | One-line mission + tag soup. |
| `ai/status.md` (if exists) | Current phase, in-flight work, recent changes — primary maturity signal. |
| `ai/business-domain.md` (if exists) | Already-classified domain — confirms or feeds into our domain classification. |
| `ai/project-goals.md` (if exists, REFRESH mode) | Prior answers — preserve verbatim, ask only for new facets. |
| Git log first commit message + repo creation date | Maturity (months/years old) + original intent. |
| Top-level `docs/` or `documentation/` | Product overview docs if maintained. |
| `LICENSE` | Open-source vs proprietary signal. |
| `.github/ISSUE_TEMPLATE/*` | If present + populated, hints at user types reporting issues. |
| Domain name in `package.json` repository field | Sometimes reveals product category. |

### Step 2 — Map findings to the 8 facets

For each facet, record the answer + confidence + source:

| Facet | Asks |
|---|---|
| **mission** | "In one sentence, what does this product do?" |
| **target_users** | "Who uses it? Personas (e.g., Egyptian SMB merchants, US enterprise IT admins, gig drivers)." |
| **business_model** | "How does it make money / serve mission? subscription / per-tx / ad / freemium / open-source / internal-tooling." |
| **maturity_stage** | "Where in lifecycle? idea / prototype / MVP / paying-customers / scale / mature / sunsetting." |
| **success_kpis** | "Top 1-3 metrics that move when this product wins." |
| **constraints** | "Hard limits — latency / cost / compliance / team size / language?" |
| **anti_goals** | "What is this NOT trying to be?" |
| **competitive_context** | "Closest 1-3 alternatives + why this product instead?" |

Confidence levels:
- `[CONFIDENT]` — explicit answer in 1+ source.
- `[INFERRED]` — derivable from circumstantial signals (e.g., maturity inferred from age + commit frequency + deps stability).
- `[UNKNOWN]` — nothing in the repo addresses this.

### Step 3 — Consolidated question (only for `[UNKNOWN]` facets)

If `interactive: true` AND any facets are `[UNKNOWN]`:

Bundle them into ONE message (not N separate questions). Show what was inferred for the `[INFERRED]` ones with [Y/correct?] markers. Show `[UNKNOWN]` facets as fields to fill.

```
📋 Project context — please confirm + fill blanks (one message):

  ✓ Mission [CONFIDENT, from README]: "Multi-tenant ecommerce SaaS for Egyptian SMB merchants"
  ✓ Domain [CONFIDENT, detected]: ecommerce + ai (Claude integration in deps)
  ? Maturity [INFERRED — paying-customers, based on 14 ADRs + audits + 18 months age]: confirm or override
  ? Target users [INFERRED from README, partial]: SMB merchants in Egypt — also other regions?
  ✗ Business model: ____
  ✗ Success KPIs (top 1-3): ____
  ✗ Hard constraints (latency / regulatory / team size): ____
  ✗ Anti-goals (what NOT to build): ____
  ✗ Competitive context (closest alternative + why this instead): ____

Reply in any shape — paragraphs, bullets, partial answers. Skip with "skip <facet>" — left as TBD.
```

If `interactive: false`: skip the ask; record `[UNKNOWN]` facets as `_UNKNOWN — fill in when decided_` placeholder.

### Step 4 — Author the output

Write `.claude/_extracted-business.md`:

```markdown
# Business Context Extracted
Generated: <ISO> by `extract-business-context` skill
Consumed by: Phase 4.7b → populates ai/project-goals.md + users-and-personas.md + business-model.md + competitive-context.md + roadmap.md

## Mission
<one sentence>
Confidence: [CONFIDENT|INFERRED|UNKNOWN]
Source: <where derived from>

## Target users + personas
<list of 1-3 personas with: who they are, primary need, top frustration, why they choose this product>

## Business model
<how value/money flows; pricing if relevant; unit economics one-liner>

## Maturity stage
<one of: idea / prototype / MVP / paying-customers / scale / mature / sunsetting>
Evidence: <commits-per-week | ADR count | deps stability | customer count if cited>

## Success KPIs
1. <metric + target + current value if known>
2. ...

## Constraints
<latency budget, cost ceiling, compliance regime, team size, locale/RTL requirements, etc.>

## Anti-goals
<bullets — what this product explicitly is NOT trying to be>

## Competitive context
- <alternative 1>: <why we're not them>
- ...

## Asked-and-answered (interactive Q/A trail, REFRESH-friendly)
<verbatim Q+A from Step 3 if interactive — preserves traceability for next REFRESH>

## Open / unknown facets
<facets still _UNKNOWN_ — Phase 4.7b writes them as placeholders in the user-facing files; surfaced in Phase 5 report>
```

### Step 5 — Cross-link

Append a one-line entry to `.claude/_extracted-codebase.md` (if it exists):
> `## Business context — see _extracted-business.md`

## Output

Single file: `.claude/_extracted-business.md`. Print to stdout:

```
Extracted business context → .claude/_extracted-business.md
  Mission: <one-line>
  Domain: <detected domain(s)>
  Maturity: <stage>
  Personas: <count>
  KPIs: <count>
  Constraints: <count>
  Open facets: <count of _UNKNOWN_>
```

## Failure modes

- **Brand-new repo, no README, prompt-driven CREATE** → fall back entirely to the prompt as source. If even prompt is sparse, write skeleton with all `_UNKNOWN_` and surface in plan.
- **README exists but is just a generated template (e.g., "Created by create-react-app")** → ignore it; treat as if absent.
- **REFRESH mode + existing `ai/project-goals.md` etc.** → read those files FIRST as authoritative; only re-ask facets where the user explicitly flagged "needs update" or where prior answer was `_UNKNOWN_`.
- **`interactive: false` + most facets `[UNKNOWN]`** → write the file with placeholders + emit warning. Phase 5 audit MUST surface so user can fill via re-run.

## Quality bar

After this skill runs, downstream Phase 4.7b should write `ai/project-goals.md` + the 4 sibling files **with no further questions** — every section has either a real answer or an explicit `_UNKNOWN_` placeholder. If 4.7b finds itself asking the user a question this skill should have captured, that's a skill bug.
