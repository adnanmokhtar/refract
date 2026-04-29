---
description: Take a rough idea / prompt / one-liner and produce a deep, structured spec ready to feed `/scaffold-project` or to share with stakeholders. Multi-pass with confirmation gates.
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

All 7, with **two confirmation gates**:

1. Phase 1 — Understand
2. Phase 2 — Organize
3. Phase 3 — Retrieve
4. **Phase 4a — Outline (then PAUSE for user confirmation)**
5. **Phase 4b — Deep refine (then PAUSE for user confirmation)**
6. Phase 4c — Open questions sweep
7. Phase 5 — Update / save
8. Phase 6 — Validate
9. Phase 7 — Improve

## Phase 1 — Understand

- Take the user's input as a quoted string (or stdin if `<idea>` is `-`).
- Detect signals in the input:
  - **Domain markers** — "shop", "marketplace", "chat", "dashboard", "social", "tool", "game", "saas", "internal" → tags the idea's category.
  - **Audience markers** — "for developers", "for retailers", "for kids", "internal team" → tags the user persona class.
  - **Scale markers** — "for me", "small team", "thousands of users", "millions" → tags the scale tier.
  - **Constraint markers** — "no backend", "must be offline-first", "uses our existing X" → records hard constraints.
- Produce a one-line restatement: *"You want a `<domain>` for `<audience>` at `<scale>` with constraints `<list>`."* Print it and ask: "Restated correctly?" Wait for confirmation OR auto-confirm if `--no-prompt` flag passed.

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
- `~/.claude/templates/refine-prompt/refinement-frameworks.md` — domain-specific framework checklists (B2C, B2B, marketplace, real-time, etc.). If absent (the file is optional), use built-in heuristics.
- Recent ADRs (if running inside an existing repo at `ai/decisions/`) — note constraints that limit the idea space.

Skip if running in an empty directory — these are graceful-fallback reads.

## Phase 4a — Outline (then PAUSE)

First pass — wide and shallow. Output the OUTLINE only, not the full spec:

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

Save the OUTLINE draft to `ai/ideas/<YYYYMMDD>-<slug>.md`. Print it. **STOP.** Tell the user:

> Review the outline. Reply with:
>   - "looks good" → continue to Phase 4b (deep refine).
>   - "fix X / change Y / add Z" → I'll revise and re-show.
>   - "stop" → spec stays at outline level.

Wait. Do NOT proceed to Phase 4b without explicit go-ahead OR `--no-prompt`.

## Phase 4b — Deep refine (then PAUSE)

Second pass — narrow and deep. APPEND to the same file:

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

Save. Print. **STOP again.** Tell the user:

> Deep refine complete. Reply with:
>   - "ship it" → finalize, move to Phase 4c (open questions sweep).
>   - "fix X" → I'll revise.
>   - "stop" → save as-is.

Wait. Do NOT proceed without confirmation OR `--no-prompt`.

## Phase 4c — Open questions sweep

Re-read sections 4-13 from a *contrarian* angle. For each section:
- What's missing?
- What contradicts another section?
- What's a "yes" that should be a "maybe"?
- What's a "maybe" that should be a hard "no"?

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

## Phase 5 — Update

- File saved at `ai/ideas/<YYYYMMDD>-<slug>.md` throughout phases.
- If running in a repo with `ai/dynamic/changelog.md` → append: `idea refined: <slug>`.
- If running in a repo with `ai/status.md` § Recent Changes → append a bullet.

## Phase 6 — Validate

Refuse to declare success unless:
- Sections 1-17 are present.
- Section 4 (jobs-to-be-done) has ≥5 entries.
- Section 6 (anti-goals) is non-empty (forces explicit boundary).
- Section 8 + 16 (open questions) total ≥5 (forces honesty about unknowns).
- Section 13 (risks) has ≥3 entries each with mitigation filled.
- Every persona in section 3 is referenced by at least one job in section 4.
- No section is left as `<TBD>` or `<placeholder>`.

If any check fails: print which one + what's missing, and re-enter Phase 4 to fix. Don't ship a half-spec.

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

Phase 1 (Understand): "you want a <domain> for <audience> at <scale>" — confirmed
Phase 2 (Organize): refinement weight = <class> (B2C / B2B SaaS / internal tool / solo / marketplace / real-time)
Phase 3 (Retrieved): N prior ideas scanned for overlap; M ADRs reviewed (if applicable)
Phase 4a (Outline): saved to ai/ideas/<date>-<slug>.md — gate 1 confirmed
Phase 4b (Deep refine): sections 9-15 appended — gate 2 confirmed
Phase 4c (Open questions sweep): N questions surfaced; M deferred to /scaffold-project
Phase 5 (Updated): spec file saved; changelog + status.md updated (if applicable)
Phase 6 (Validated): all 17 sections present; ≥5 jobs / ≥3 risks / ≥5 open questions
Phase 7 (Improved): next-command suggested; similar prior ideas flagged

Status: COMPLETE — ready to feed /scaffold-project
File: ai/ideas/<date>-<slug>.md (~<line count> lines)
```

## Failure modes

- **"Just make it work" / "you decide everything"** — incomplete brief; refine pushes back instead of inventing. Open questions section is the safety net.
- **One-pass without confirmation gates** → wrong direction; user catches divergence too late. The two PAUSES are non-negotiable.
- **Sections fabricated to look complete** → fictional spec. Validation refuses if `<TBD>` markers remain.
- **All risks tagged "low likelihood, low impact"** → risk theater. Force at least one risk in each impact tier.
- **Persona section names roles but skips pains** → useless personas. Validation requires pain text per persona.
- **Anti-goals (section 6) empty** → guaranteed scope creep. Refuse to ship without it.
- **Inspirations vague ("like Twitter but better")** → not actionable. Force specifics: which feature of which product, and how the new idea differs.

## Hard rules

- **Two confirmation gates between Phase 4a and 4b, and between 4b and 4c.** Skipping either produces a spec that drifts from the user's intent. `--no-prompt` is the only way to skip; that flag is logged.
- **Adversarial questioning, not stenography.** If the user says something contradictory, surface the contradiction; don't smooth it over.
- **Open questions are mandatory.** A "complete" refined idea has ≥5 unknowns, not zero.
- **No technical decisions.** Stack / architecture / hosting choices belong in `/scaffold-project`. Refining a spec that pre-commits the stack constrains design unnecessarily.
- **No fabricated personas.** Every persona section must trace to a Phase 1 audience signal or an explicit user mention.
- **Implementation-free language.** "User saves a draft" not "POST /api/drafts." This is a domain spec.
- **Fail loudly on missing sections.** Phase 6 refuses success on any `<TBD>`. The agent must finish or stop, not fudge.

## Related

- `/scaffold-project` — the natural next step. Reads the output of this command and produces a working repo.
- `/analyze-task` (business pack) — for feature-level specs WITHIN an existing project. This command is for project-level / new-idea refinement.
- `/expand-task` (business pack) — for breaking a spec into implementation tasks (within a project).
