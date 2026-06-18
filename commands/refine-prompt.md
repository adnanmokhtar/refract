---
description: Take a rough idea / prompt / one-liner and produce a deep, structured spec ready to feed `/scaffold-project` or to share with stakeholders. Single-cycle draft with one final confirmation gate.
kind: command
pack: orchestration
---

# /refine-prompt "<idea>"

Turn vague ambition into a structured spec. Adversarial — surfaces unknowns instead of fabricating answers. Produces `ai/ideas/<YYYYMMDD>-<slug>.md` ready to feed `/scaffold-project` or hand to engineering / design / stakeholders.

This command is **stack-agnostic by design**. Phase 4 outputs a domain spec; technical choices belong to `/scaffold-project` (or a separate ADR exercise). The output is intentionally implementation-free.

## When to use

- You have a one-liner ("an app for X") and need a real spec before committing engineering time.
- A stakeholder dropped an idea in Slack and you want to bounce back a refined version for confirmation.
- You're about to run `/scaffold-project` and want a deeper input than a sentence.
- You want a written spec to share with designers, product, or investors.

## When NOT to use

- Spec already exists in `specs/` or a tracker ticket — point at the existing spec, don't duplicate.
- The idea is one-line and trivial ("add a dark-mode toggle") — over-process.
- You're working WITHIN an existing project and need a feature spec — use `/analyze-task` (business pack) instead.
- The idea is sensitive / private and you don't want it written to disk — refine in conversation, don't run this command.

## Phases applied

All 7, with **one final confirmation gate**:

1. Phase 1 — Understand
2. Phase 2 — Organize
3. Phase 3 — Retrieve
4. **Phase 4 — Draft + refine + sweep (single cycle, internal iteration, ends with one user gate: "Ready to scaffold?")**
5. Phase 5 — Update / save
6. Phase 6 — Validate
7. Phase 7 — Improve

## Phase 1 — Understand

- Take the user's input as a quoted string (or stdin if `<idea>` is `-`).
- Detect signals in the input:
  - **Domain markers** — "shop", "marketplace", "chat", "dashboard", "social", "tool", "game", "saas", "internal" → tags the idea's category.
  - **Audience markers** — "for developers", "for retailers", "for kids", "internal team" → tags the user persona class.
  - **Scale markers** — "for me", "small team", "thousands of users", "millions" → tags the scale tier.
  - **Constraint markers** — "no backend", "must be offline-first", "uses our existing X" → records hard constraints.
- Produce a one-line restatement: *"You want a `<domain>` for `<audience>` at `<scale>` with constraints `<list>`."* Print it and **proceed directly** — this is non-blocking. The user can correct it at the single Phase 4 gate ("Ready to scaffold?"). Do NOT pause here; pausing would create a second gate and violate the one-gate hard rule.

## Phase 2 — Organize

Decide the refinement approach based on Phase 1 signals:

| Signal class | Refinement weight |
|---|---|
| Consumer app (B2C) | Heavy on user personas + emotional jobs-to-be-done |
| B2B SaaS | Heavy on workflows + ROI + integrations + admin/permissions |
| Internal tool | Heavy on existing-process mapping + adoption + handoff |
| Solo / hobby | Heavy on MVP scope discipline + cost ceiling |
| Marketplace | Heavy on two-sided dynamics + trust mechanics + moderation |
| Real-time / collaborative | Heavy on conflict resolution + presence + offline behavior |

Pick the refinement weight; downstream phases adapt section depth accordingly.

## Phase 3 — Retrieve

Read for context:
- `ai/ideas/` — any prior refined ideas in this directory; surface similarities (don't duplicate).
- Recent ADRs (if running inside an existing repo at `ai/decisions/`) — note constraints that limit the idea space.

Domain-specific framework depth (B2C, B2B, marketplace, real-time, etc.) comes from the inline refinement-weight table in Phase 2 — no external template file is required.

Skip if running in an empty directory — these are graceful-fallback reads.

## Phase 4 — Draft + refine + sweep (single cycle)

Run outline → deep refine → open-questions sweep as one internal cycle. No inter-stage user pause; iterate silently until the spec is fully drafted, then surface ONE final gate.

**Section depth proportional to input weight.** If Phase 2's refinement-weight scoring is `light` (one-line idea, hobby project, prototype), the spec includes only sections 1-8 (goal, users, features, stack-agnostic scope, anti-goals, inspirations, open questions, scaffolding plan / deferred decisions). Sections 9-17 (data model, permissions, non-functional, ops, multi-tenancy, etc.) ship only when refinement-weight is `medium` or `heavy`. Avoid 17-section spec bloat for trivial inputs.

### Execution model — specialist fan-out (silent, internal)

The deep-refine pass is **not** a single sequential write. For `medium`/`heavy` weight, after the outline (sections 1-8) is saved, dispatch parallel specialist sub-agents via the Agent tool — **all in one message so they run concurrently**. Each receives identical shared context — the Phase 1 restatement, the Phase 2 refinement weight, the Phase 3 prior-idea/ADR notes, and the full outline (sections 1-8) — and returns **only** its assigned section(s) in the exact markdown shape below: raw spec content, no preamble, no commentary.

| Specialist | Owns | Specialist lens (own detectors / contract) |
|---|---|---|
| `flows-and-permissions` | §9 user flows + §11 permissions/roles | Flows reveal the actors that define roles; each role's can/cannot list must trace to a step in some flow. |
| `data-model` | §10 entities/fields/relations | Reads §4-5 (jobs + scope); every entity must trace to a capability, every relation must be bidirectional-consistent. |
| `non-functional` | §12 perf/scale/reliability/compliance/i18n/a11y | Budgets weighted by the Phase 2 scale-tier signal; refuses "TBD" — names a concrete number or marks it an open question. |
| `risk` | §13 risks + §14 assumptions | Forces ≥1 risk in each impact tier (anti risk-theater); each assumption names the section it would invalidate if false. |
| `metrics` | §15 success metrics | North-star + secondary, each metric traceable to a specific job-to-be-done in §4. |

The split is deliberate (specialist value, not slicing): the agents are **independent — none can see another's draft**. That independence is the point — independent perspectives surface gaps a single linear pass smooths over.

`light` weight does **not** fan out. It drafts sections 1-8 in a single inline pass and runs the contrarian sweep inline — dispatching five sub-agents for a "dark-mode toggle" idea is exactly the bloat this command warns against.

**Silent.** No specialist output is surfaced mid-run; the user sees only the final assembled spec plus the brief Phase-output status. The parallelism and the adversarial reconcile stay internal.

**No silent drops.** A specialist that returns nothing or errors → write its section as `<!-- specialist failed: <name> — re-run -->` and flag it in Phase 6. Never silently omit a section.

First pass — wide and shallow. Draft the OUTLINE:

```markdown
# Refined idea — <slug>

## 1. One-sentence pitch
<one sentence>

## 2. Problem statement (the pain)
<2-3 sentences>

## 3. Target users (3-5 personas)
- <persona 1 — role, context, pain>
- <persona 2 — role, context, pain>
...

## 4. Core jobs-to-be-done (5-10)
- When <situation> I want to <motivation> so I can <outcome>.
- ...

## 5. MVP scope — IN
- Capability 1
- Capability 2
- ...

## 6. MVP scope — OUT (anti-goals — non-negotiable)
- <what we are explicitly NOT building>
- ...

## 7. Inspirations / similar systems (3-5)
- <name> — <why we're like it / different from it>

## 8. Open questions (forced — at least 5)
- <unknown 1>
- <unknown 2>
...
```

Save the OUTLINE draft to `ai/ideas/<YYYYMMDD>-<slug>.md` (no user pause here — proceed directly to deep refine if weight is medium/heavy; if weight is light, skip directly to the open-questions sweep).

Second pass (medium/heavy weight only) — narrow and deep, executed by the parallel specialists defined in the Execution model above. Each specialist returns its section(s) in this shape; the orchestrator collects all outputs, then APPENDs sections 9-15 to the file in order:

```markdown
## 9. User flows (top 3)
**Flow A — <name>**
1. User <action>.
2. System <response>.
3. ...
**Acceptance**: <given/when/then>.

(Repeat for flows B and C.)

## 10. Data model (entities + key fields, no schema yet)
- **<Entity>**: id, <field>, <field>, <relation to other entity>.
- ...

## 11. Permissions / roles (if any)
- <role>: can do <list>; cannot do <list>.

## 12. Non-functional needs
- Performance: <budget — page load, API latency, etc.>
- Scale: <targets — req/s, users, data volume>
- Reliability: <budget — uptime, error rate>
- Compliance: <regulations / certifications applicable>
- Internationalization: <required locales / RTL>
- Accessibility: <WCAG level + key flows>

## 13. Risks (5-10, each with mitigation)
- **Risk**: <description>
  **Likelihood**: low / medium / high
  **Impact**: low / medium / high
  **Mitigation**: <one sentence>

## 14. Assumptions log
- We assume <X>; if false, the spec needs revision in section <Y>.
- ...

## 15. Success metrics (north-star + 2-3 secondary)
- North-star: <metric and target value at <time>>.
- Secondary: <metric>, <metric>.
```

Save. Continue directly to the open-questions sweep — no user pause.

Third pass — synthesis + adversarial reconcile. Re-read sections 4-13 (or 4-7 for light weight) from a *contrarian* angle. For each section:
- What's missing?
- What contradicts another section?
- What's a "yes" that should be a "maybe"?
- What's a "maybe" that should be a hard "no"?

**For `heavy` weight, run this as a dedicated reconcile sub-agent** (perspective-diverse verify / completeness-critic pattern) prompted to *refute the spec's coherence*: "find every claim in sections 1-15 not supported by another section — an entity with no owning persona, a risk with no mitigation, a metric not traceable to a job, a permission for a role absent from every flow." Its findings become section 16. For `light`/`medium`, the orchestrator runs this reconcile inline. Either way it is silent — only the resulting section 16 is written.

APPEND to the file:

```markdown
## 16. Open questions (final sweep)
- <question 1 — section X claimed Y; have we validated that?>
- <question 2 — assumption A in section 14 conflicts with persona pain B in section 3; reconcile?>
- ...

## 17. Decisions deferred to /scaffold-project
- Stack choice (frontend / backend / DB / auth / payments).
- Architecture (monolith / services / serverless).
- Hosting target.
- Specific design system / brand identity.
- Initial migration plan.
```

Section 17 is intentional — `/scaffold-project` reads it and knows what's settled vs. what's still up for negotiation.

**Final user gate.** Print the full spec and ask: "Ready to scaffold?" Reply with:
  - "yes" / "ship it" → continue to Phase 5.
  - "fix X / revise Y" → re-enter Phase 4 internal iteration; do NOT re-pause until next "Ready to scaffold?".
  - "stop" → save as-is, skip Phase 5.

Wait for confirmation OR auto-confirm if `--no-prompt` flag passed. This is the only Phase 4 user pause.

## Phase 5 — Update

- File saved at `ai/ideas/<YYYYMMDD>-<slug>.md` throughout phases.
- If running in a repo with `ai/dynamic/changelog.md` → append: `idea refined: <slug>`.
- If running in a repo with `ai/status.md` § Recent Changes → append a bullet.

## Phase 6 — Validate

Report any section under its target threshold; **flag, do NOT block**. The user accepts the light spec or asks for an extension pass.

Targets (scaled to refinement-weight from Phase 2):
- Sections present: 1-8 for `light`; 1-17 for `medium`/`heavy`.
- Section 4 (jobs-to-be-done) target ≥5 entries.
- Section 6 (anti-goals) non-empty (forces explicit boundary).
- Section 8 + 16 (open questions) target ≥5 (forces honesty about unknowns).
- Section 13 (risks) target ≥3 entries each with mitigation filled (medium/heavy only).
- Every persona in section 3 referenced by at least one job in section 4.
- No section left as `<TBD>` or `<placeholder>`.
- No `<!-- specialist failed: ... -->` markers remain — each is a section a deep-refine specialist did not deliver; flag for re-run.

For each unmet target, print a flag line such as: `3 risks listed; target 5 — light spec acceptable for a hobby project, flag for re-pass on enterprise scope`. Phase 6 does NOT refuse to ship. The user decides: accept as-is, or re-enter Phase 4 to extend.

## Phase 7 — Improve

- Suggest the natural next command:
  ```
  Next: `/scaffold-project ai/ideas/<YYYYMMDD>-<slug>.md`
  ```
- If a similar spec already exists in `ai/ideas/`, mention it:
  ```
  Similar prior idea: ai/ideas/<old-slug>.md — review for overlap before scaffolding.
  ```
- If 3+ refined ideas share a domain (consumer-fashion, b2b-ops, etc.) → suggest a shared design-language spec.

## Output format

```
## /refine-prompt — <slug>

Phase 1 (Understand): "you want a <domain> for <audience> at <scale>" — restated (non-blocking; correct at final gate)
Phase 2 (Organize): refinement weight = <class> (B2C / B2B SaaS / internal tool / solo / marketplace / real-time)
Phase 3 (Retrieved): N prior ideas scanned for overlap; M ADRs reviewed (if applicable)
Phase 4 (Draft + refine + sweep): outline drafted; <N> specialists dispatched in parallel for deep refine (skipped for light weight); adversarial reconcile produced section 16; single cycle; final "Ready to scaffold?" gate confirmed
Phase 5 (Updated): spec file saved; changelog + status.md updated (if applicable)
Phase 6 (Validated): N sections present (light=1-8 / full=1-17); thresholds reported and flagged where under target — user accepted
Phase 7 (Improved): next-command suggested; similar prior ideas flagged

Status: COMPLETE — ready to feed /scaffold-project
File: ai/ideas/<date>-<slug>.md (~<line count> lines)
```

## Failure modes

- **"Just make it work" / "you decide everything"** — incomplete brief; refine pushes back instead of inventing. Open questions section is the safety net.
- **One-pass without the final gate** → wrong direction; user catches divergence too late. The single "Ready to scaffold?" pause is non-negotiable.
- **Sections fabricated to look complete** → fictional spec. Validation flags `<TBD>` markers; user decides whether to extend.
- **All risks tagged "low likelihood, low impact"** → risk theater. Force at least one risk in each impact tier.
- **Persona section names roles but skips pains** → useless personas. Validation requires pain text per persona.
- **Anti-goals (section 6) empty** → guaranteed scope creep. Flag prominently; user decides.
- **Inspirations vague ("like Twitter but better")** → not actionable. Force specifics: which feature of which product, and how the new idea differs.
- **Specialists run sequentially** → wasted wall-clock and lost independence. Dispatch all section specialists in one message; their value is that none sees another's draft.
- **Specialist output surfaced mid-run** → noise; breaks the silent-execution contract. Only the final assembled spec + Phase-output status reach the user.
- **A specialist silently drops its section** → looks complete, isn't. Write `<!-- specialist failed: <name> — re-run -->` and flag in Phase 6 instead.
- **Fanning out on a light/trivial idea** → five agents for a one-liner. Light weight stays single-pass inline.

## Hard rules

- **One final confirmation gate at the end of Phase 4 ("Ready to scaffold?").** Outline / deep refine / open-questions sweep iterate internally without inter-stage user pauses. `--no-prompt` is the only way to skip the final gate; that flag is logged.
- **Deep refine fans out to parallel specialists (medium/heavy weight).** Sections 9-15 are drafted by independent specialist sub-agents dispatched in one message; section 16 comes from an adversarial reconcile. Light weight stays single-pass inline. The fan-out is silent — discipline internal, output brief.
- **Adversarial questioning, not stenography.** If the user says something contradictory, surface the contradiction; don't smooth it over.
- **Open questions are mandatory.** A "complete" refined idea has ≥5 unknowns, not zero.
- **No technical decisions.** Stack / architecture / hosting choices belong in `/scaffold-project`. Refining a spec that pre-commits the stack constrains design unnecessarily.
- **No fabricated personas.** Every persona section must trace to a Phase 1 audience signal or an explicit user mention.
- **Implementation-free language.** "User saves a draft" not "POST /api/drafts." This is a domain spec.
- **Flag loudly on missing sections.** Phase 6 reports any `<TBD>` or under-target threshold; the user decides whether to accept the light spec or re-enter Phase 4. Reporting is mandatory; blocking is not.

## Related

- `/scaffold-project` — the natural next step. Reads the output of this command and produces a working repo.
- `/analyze-task` (business pack) — for feature-level specs WITHIN an existing project. This command is for project-level / new-idea refinement.
- `/expand-task` (business pack) — for breaking a spec into implementation tasks (within a project).
