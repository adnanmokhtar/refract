---
name: engineering-principles
description: Engineering Principles (project governance layer)
kind: rule
pack: code-quality
severity: must
applies-to: code-quality-track, every-code-writing-task-in-code-quality
---

# Engineering Principles (project governance layer)

> **Hard rule.** New code MUST live in a defined module with an explicit public surface, MUST follow the project's existing layering / DI / naming conventions, and MUST extend an existing implementation of a concept rather than parallel-build a second one. New "shared/" / "utils/" / "common/" buckets, parallel re-implementations, and silent convention deviations are forbidden — each requires an ADR or it doesn't merge.

These are CROSS-CUTTING engineering rules — broader than the micro-level hygiene in `quality-principles.md`, narrower than full architectural decisions (which live in ADRs at `ai/decisions/`). This is the team contract: how features get structured, how AI is used, how change happens safely, how we stay consistent.

**Defaults, not laws.** Break one when the rule genuinely doesn't fit the situation, when a more important rule conflicts (consistency vs correctness — pick correctness), or when `ai/conventions.md` or an ADR documents the exception. Leave a one-line comment naming which of the three applies; an undocumented break is indistinguishable from an accident.

Each section has an **Applies when** clause; a section your project doesn't match is annotated "Not applicable" by Phase 4.6 (`apply-pack-adaptation`), which also anchors the rest to this project's actual modules, base classes and conventions above this body. Don't force-fit a layered-architecture rule onto a functional-core codebase.

## Structure and module boundaries

**Applies when**: project uses module-based / package-based / domain-bounded organization (NestJS modules, Django apps, Go internal packages, Rust crates with public APIs, Java JPMS modules, Rails engines, etc.). Skip for single-folder scripts, flat monolithic layouts, or pure-functional codebases without modules.

- **Every feature belongs to a defined module**, decided before you write, and recorded in `ai/modules.md`. Loose files at repo root or in `utils/` / `shared/` / `common/` are the failure mode this prevents — and the test for whether a bucket is legitimate is whether you can NAME the concept (`id-generation`, `money`, `result-types` → its own named module) or only call it "helpers" (→ you're avoiding the placement decision, and the ADR the Hard rule demands won't write itself).
- **Cross-module access goes through the documented public surface only** — no reaching into another module's `internal/` / `_private/`. The surface is the team's promise; internals are the team's freedom to refactor.

→ Placement judgement, the layered-boundary detail, and the CI wiring that enforces both: `ai/patterns/module-boundaries.md`.

## Layered architecture

**Applies when**: project uses a layered backend — Controller→Service→Repository, MVC, Clean Architecture, hexagonal/ports-and-adapters, or an equivalent. Skip for actor-model, CQRS+event-sourcing, functional-core/imperative-shell, or framework-less scripts.

- **Business logic lives in the service layer** (or its named equivalent: use case, interactor, application service, command handler) — not in controllers/handlers (transport), repositories (data access), or views (presentation).
- **Dependencies point one direction**: controllers → services → repositories → DB. No data access from controllers or UI. This is what makes any single layer swappable (REST→gRPC, ORM→ORM, real DB→fake) without rewriting the others.
- **The rule is mechanical or it is aspirational.** A boundary linter fails CI on cross-layer imports; a rule no tool checks gets quietly broken, because each individual violating import looks reasonable in review.

→ Per-layer ownership table, the "just this once for performance" bypass, and per-ecosystem linter wiring: `ai/patterns/module-boundaries.md`.

## Feature development

**Applies universally.**

- **Extend over duplicate — and the fork test is not a percentage.** Grep for the concept before you add; if a similar shape exists, extend it. Fork only when the two cases need **different invariants** — a rule that must change for one and must NOT change for the other. If you can't name that invariant, you're duplicating, and two implementations of one concept is drift with a start date. A real fork gets an ADR naming the invariant that split.
- **New code follows the current architecture, not around it.** The layering / module boundaries / DI conventions already in place ARE the architecture. Bypassing them is how it dies — there is never a single bypass, and the second one cites the first as precedent.

## AI-assisted development

**Applies universally.**

- **If you can't explain the code, it isn't yours — and it doesn't merge.** Mechanical, not advisory: every non-trivial change carries a 5-field **change brief** (What / Why this shape / Edge cases / Blast radius / Verified by) in the commit/PR body, generated and validated by the `change-brief` skill (dispatched by `/pre-commit` + `/review-changes`). Writing it takes 2 minutes when you understand the change and is impossible when you don't — that asymmetry is the gate. A brief that paraphrases the diff, cites nothing, or says "should work" fails.
- **Trust but verify agent reports.** When an agent says "done": did the tests it claims to have run actually run, and does the diff actually contain the change? Agents have a known failure mode of producing plausible summaries that don't match reality. A claim with no artifact behind it is marked UNVERIFIED, never upgraded to a pass.
- **The AI follows the project's structure, not its training-data defaults.** Reject a generic pattern that doesn't match this project's conventions; that it compiles is not the argument.

→ Why the safety net has to exist *before* change volume rises (DORA 2025, cited), the conventions-drift diagnosis, and where corrections get captured: `ai/patterns/ai-assisted-change.md`.

## Change control

**Applies universally.**

- **Identify the blast radius before changing.** "What does this affect downstream?" If the answer is "the whole system", the change needs MORE review, not less — and an ADR.
- **Side-effects are surfaced, not hidden.** Adding a write (DB, log, event, network) inside a function that previously had none is a behaviour change. Document it; if the function is named like a query (`getX`, `findX`), rename it.
- **Reversibility is a feature.** Prefer changes that revert in one commit. Two-phase migrations (add new → deprecate old → remove old) over big-bang rewrites; a big-bang rewrite needs an ADR explaining why the phased path was rejected.
- **Don't fix unrelated things in the same change.** Mixed concerns make review impossible and revert dangerous. (The Boy Scout Rule in `quality-principles.md` is bounded to *adjacent* cleanup — same diff context — for exactly this reason.)

## Consistency

**Applies universally.** *(Resident on purpose: this is the rule that has to be loaded BEFORE the model writes, not fetched after it has already chosen a shape.)*

- **Match what's already there.** Same naming style, file layout, error handling, logging style. The codebase IS the style guide; deviation is a bug.
- **New patterns require a reason and an ADR.** Introducing a shape that doesn't already exist? Pause: is the existing shape genuinely insufficient? Yes → ADR. No → use the existing shape.
- **Conventions converge, not diverge.** Two ways to do the same thing is drift. Pick one (usually the newer or more-extended), record it in `ai/conventions.md`, migrate the other.

## Enforcement

- **Boundaries**: a boundary linter fails CI on cross-layer / cross-module-internal imports. Per-ecosystem linters, the PR-template checkbox and the CI cadence are wired in `ai/patterns/module-boundaries.md § Enforcement`.
- **New shapes**: reviewers MUST reject a pattern the codebase doesn't have, or a new `utils/` / `shared/` bucket, without an `ai/decisions/<NNNN>-*.md`. No automated check exists for either — review IS the mechanism, and a gate nobody enforces is not a gate.
- **Drift**: `/setup-project-health` diffs `ai/conventions.md` against the working tree.

Companions: `quality-principles.md` (micro-level hygiene — complements, doesn't replace), `ai/conventions.md` (this project's detected conventions), `ai/decisions/` (ADRs), `ai/failures/_index.md` (validated project anti-patterns).
