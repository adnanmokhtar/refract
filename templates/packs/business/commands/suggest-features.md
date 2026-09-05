---
description: Analyze the whole product against what a business in its domain should have, and WRITE a file of recommended missing capabilities — each one "analyze-task-ready" so you pick one, run /analyze-task on it to get a buildable spec, then /add-feature to implement. The breadth counterpart to /audit-business (one feature deep) and the feature arm of /suggest-metrics (metrics). Recommends what to BUILD (and what to skip); does not build it.
kind: command
pack: business
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /suggest-features [<scope>]

## The Premise (read this first, internalize, do not deviate)

**This is the analysis half of a build pipeline, not a report that dies in chat.** The deliverable is a **written file** of recommended capabilities, and each recommendation is shaped so you can take it straight into the build seam:

```
/suggest-features   →  writes ai/business/feature-recommendations.md   (WHAT to build, prioritized)
     ↓  (you pick one)
/analyze-task "<the recommendation>"   →  writes a buildable spec to specs/<id>.md
     ↓
/add-feature specs/<id>.md   →  implements it (spec→build seam, no re-deriving)
```

So the job is: analyze the product against its domain, and hand back **pick-able, implementable candidates in a file** — never vague advice. A recommendation that `/analyze-task` cannot turn into a spec without re-deriving everything is a failed recommendation.

**Every recommended capability MUST clear three gates or it is not written:**
1. **Domain-warranted** — it appears in the domain's `feature-checklist.md` (the "what a business like this needs" list) OR is justified against a persona job; not invented to pad the list.
2. **Missing (not already built)** — diffed against the product's ACTUAL capabilities (Phase 2 inventory), not assumed. A capability the product already has is not "missing".
3. **Analyze-task-ready** — carries enough context (the capability, its business value, the entities/flows/modules it touches, what infra already exists) that `/analyze-task` can spec it directly. This is what makes the file *actionable* rather than a wish-list.

**And the reverse gate (do not just pile on):** flag what the product would be **over-building** — the checklist's "defer until validated" items — so the user adds high-value capabilities and *skips* premature ones. More features is not the goal; the right next features are.

**Ownership boundary:** this command **recommends WHICH capabilities + writes them as buildable candidates** and hands off. It does NOT write the spec (that's `/analyze-task`), build the feature (that's `/add-feature` / the track pack), or design the UI (frontend/ui-ux). It is the product analyst's recommendation, written to a file, ready to feed the seam.

## When to use / NOT to use

**Use when:** "what should I build next?", "what is my product/store missing vs others like it?", "analyze my business and give me something I can implement", a pre-roadmap gap pass, or after entering a new market/segment.

**NOT for:**
- Auditing whether ONE existing feature is complete (forward/inverse/recovery) → `/audit-business <feature>` (depth, one feature).
- Recommending which METRICS to track → `/suggest-metrics` (the metrics arm).
- Turning a chosen recommendation into a spec → `/analyze-task` (this command feeds it).
- Building a feature → `/add-feature` (consumes the spec `/analyze-task` produces).

## Phase 1 — Understand (domain + personas)

- **Domain** — detect the business domain from `ai/business-domain.md`, entities, and the installed `business-domains/<domain>/` knowledge. Ambiguous → ASK once; the capability set is domain-specific.
- **Personas + their jobs** — `ai/users-and-personas.md`. Missing capabilities are ranked by which persona's job they unblock and how often.
- `<scope>` (optional) — narrow to a slice (`the checkout flow`, `the marketing surface`, `operator/admin`). Default: the whole product.

## Phase 2 — Retrieve (inventory what the product ALREADY has)

Do NOT recommend blind. Build the **capability inventory** from the CODE, not assumption:
- Enumerate modules / routes / entities / admin screens / integrations (grep the router, the modules dir, the entity/model files, the admin surfaces, the `package.json` integrations).
- Record each capability as `capability | surface | maturity (full / partial / stub)`. This is the diff baseline — recommending something already built is a bug.
- Note **partial** capabilities (e.g. cart exists but no abandonment recovery, orders exist but no returns flow) — a partial is a *completion* recommendation, distinct from a greenfield one.

## Phase 3 — Retrieve (the domain capability set)

Load `business-domains/<domain>/feature-checklist.md` — the comprehensive "what a business like this should have", organized by its own sections (for a storefront: Catalog · Cart · Checkout · Account · Post-purchase · Order-management · Catalog-management · Customer-management · Marketing · Trust+compliance · Operational). Also read its two decisive lists:
- **"Things v1s commonly miss"** → high-signal recommendation candidates.
- **"Things often over-built (defer until validated)"** → the reverse-gate skip list.

Cite the checklist section for each candidate — it is the domain warrant.

## Phase 4 — Generate (diff → prioritize → WRITE the file)

1. **Diff** the domain capability set (Phase 3) against the inventory (Phase 2). Mark each: `have` / `partial (complete it)` / `MISSING (build it)` / `over-build (defer)`.
2. **Prioritize** each gap by **business-value × reach × effort**:
   - *Value*: the revenue/retention/trust decision it serves.
   - *Reach*: how many users / how often (from personas).
   - *Effort*: `have-infra` (extends existing modules) / `greenfield` (new module) — name which existing entities/modules it builds on.
   - High value × high reach × have-infra = recommend first.
3. **WRITE the recommendations to `ai/business/feature-recommendations.md`** (dated, append). This file IS the deliverable. Each recommendation is an **analyze-task-ready block** (format below) so the user can pick one and run the seam. Group by the checklist categories; put the skip-list at the end so the user sees what NOT to build.
4. **Closure verbs** (each recommendation is exactly one):
   - `recommend-capability` — a MISSING high-value feature to build greenfield.
   - `complete-capability` — a PARTIAL feature to finish (names the specific gap).
   - `defer-capability` — an over-build the user might expect; named with why to wait (the reverse gate).

## The recommendation block (what makes the file actionable)

Each written recommendation follows this shape so `/analyze-task` can spec it directly:

```
### [Marketing] Abandoned-cart recovery        recommend-capability · value: HIGH · reach: HIGH · effort: have-infra
What:     email/SMS a customer who left items in cart, with a recovery link (+ optional discount).
Why:      recovers otherwise-lost revenue; ties to the abandoned-cart metric you already track.
Touches:  Cart entity (has `status`), Customer (has contact), a scheduler/queue, the email/SMS channel.
Have:     cart + status exist; missing the trigger + template + send.
Warrant:  business-domains/ecommerce/feature-checklist.md § Marketing / "things v1s commonly miss".
→ Spec it:   /analyze-task "abandoned-cart recovery — email/SMS a customer who left items in cart with a recovery link"
→ Then build: /add-feature specs/<generated-id>.md
```

The `→ Spec it` line is copy-paste-ready — that is the whole point: analysis → pick → spec → build.

## Phase 5 — Update

- The file `ai/business/feature-recommendations.md` is the artifact (dated; prior runs kept for trend).
- One line to `ai/dynamic/changelog.md`: `Feature-gap analysis: <M> missing, <P> partial, <D> deferred`.

## Phase 6 — Validate

- Every `recommend`/`complete` block has all six fields (What · Why · Touches · Have · Warrant · the copy-paste `→ Spec it` line). A block missing the `→ Spec it` line is not analyze-task-ready → dropped.
- No recommendation duplicates a Phase-2 inventory capability (a `have` is never recommended; a `partial` is a `complete-capability`, not a new build).
- Every `recommend`/`complete` cites a checklist section or a named persona job (no invented features).
- The skip-list (`defer-capability`) is present when the checklist flags over-builds — the user must see what NOT to build.

## Phase 7 — Improve

- If the product is already at domain parity, say so — "capability coverage complete for <domain>; the gaps are polish/scale, not missing features" — never invent low-value features to fill a roadmap.
- If several recommendations share one missing primitive (a queue, a notifications channel), surface that primitive first — it unblocks a whole category.

## Output format (chat is a summary; the FILE is the deliverable)

```
/suggest-features — <domain> · <scope>
Coverage: <have>/<total> capabilities · <M> missing · <P> partial · <D> deferred
Written: ai/business/feature-recommendations.md   ← the pick-able, buildable file

Top recommendations (by value×reach×effort):
  1. [Marketing]  Abandoned-cart recovery      HIGH  have-infra   → /analyze-task "..."
  2. [Post-purchase] Returns/refunds flow       HIGH  have-infra   → /analyze-task "..."
  3. [Account]    Wishlist / save-for-later     MED   greenfield   → /analyze-task "..."
Deferred (do NOT build yet): <over-build items + why>

Not validated: <domain confidence | personas inferred | none>
```

## What to do next — required closing section

Per `~/.claude/templates/snippets/actionable-next-steps.md`, the file ends with the pipeline, ordered by leverage. Each recommendation's paste-ready path is: `/analyze-task "<intent>"` → `/add-feature specs/<id>.md`. Never leave a recommendation without its `/analyze-task` line — that line is what turns analysis into implementation.

## Failure modes

- **Domain unknown/unset** → ASK once; do not guess a capability set.
- **Personas file missing** → recommend the domain-standard set, flag `Not validated: personas — reach inferred`.
- **Already at parity** → say so; do not pad with low-value features.
- **A recommendation is too vague to spec** → it failed the analyze-task-ready gate; either add the Touches/Have context or drop it — never write a block `/analyze-task` cannot consume.
- **User picks a `defer` item anyway** → fine, it's their call; the block still specs cleanly, but the file recorded why it was deferred so the decision is eyes-open.

## Related

### Sibling commands in business pack
- `/suggest-metrics` — the metrics arm (what to *measure*); this is the capability arm (what to *build*).
- `/audit-business <feature>` — audits ONE feature deeply; this audits the whole product's capability coverage.
- `/analyze-task` — **consumes** a recommendation from this file and writes the buildable spec (the next step in the pipeline).

### Skills / rules
- `check-business-coverage` — cross-feature cycle-counterpart audit (completeness of existing features).
- `.claude/rules/business-completeness.md` — the completeness philosophy this feeds.

### Hands off to (the pipeline)
- `/analyze-task "<recommendation>"` → writes `specs/<id>.md` → `/add-feature specs/<id>.md` builds it.
