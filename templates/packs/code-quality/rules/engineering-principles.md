---
name: engineering-principles
description: Engineering Principles (project governance layer)
kind: rule
pack: code-quality
---

# Engineering Principles (project governance layer)

These are CROSS-CUTTING engineering rules — broader than the micro-level hygiene in `quality-principles.md`, narrower than full architectural decisions (which live in ADRs at `ai/decisions/`). Think of this as the team contract: how features get structured, how AI is used, how change happens safely, how we stay consistent over time.

Each section has an **Applies when** clause. If your project doesn't match the clause, the section is annotated "Not applicable" by Phase 4.6 (`apply-pack-adaptation` skill) — don't force-fit a layered-architecture rule onto a functional-core codebase.

Anchor block populated by `/setup-project` Phase 4.6 — citing this project's actual modules, base classes, and conventions — appears at the top above this body in the project's installed copy.

## Structure and module boundaries

**Applies when**: project uses module-based / package-based / domain-bounded organization (NestJS modules, Django apps, Go internal packages, Rust crates with public APIs, Java JPMS modules, Laravel packages, Rails engines, etc.). Skip for single-folder scripts, monolithic flat layouts, or pure-functional codebases without modules.

- **Every feature belongs to a defined module.** Loose files at repo root, in `utils/` / `shared/` / `common/` / `misc/`, are the failure mode this rule prevents — they accumulate as architectural debt no later refactor pays back. Locate the home before writing. New domain → plan a new module first (record an ADR if architectural). Module assignment is tracked in `ai/modules.md`.
- **Module boundaries are explicit, not implied.** Each module has a documented public surface (the `index.ts` / `__init__.py` / package exports / `mod.rs`). Things inside the module are private until exported.
- **Cross-module access goes through the public surface only.** No reaching into another module's `internal/` / `_private/` / `__init__`-bypassing imports. The public surface is the team's promise; internals are the team's freedom to refactor. Bypass = future breakage when internals change.
- **A new "shared/" or "utils/" folder is a smell.** If you're creating one, ask: "is this *truly* cross-cutting, or am I avoiding the work of placing the code in the right module?" 90% of the time it's the latter. Truly-cross-cutting → its own named module (e.g., `id-generation`, `time`, `result-types`), not a junk drawer.

## Layered architecture

**Applies when**: project uses a layered backend — Controller→Service→Repository, MVC, Clean Architecture, hexagonal/ports-and-adapters, or any equivalent. Skip for actor-model, CQRS+event-sourcing, functional-core/imperative-shell, or framework-less scripts.

- **Business logic lives in the service layer** (or its named equivalent: use case, interactor, application service, command handler). Not in controllers/handlers (transport concern). Not in repositories (data access concern). Not in views/templates (presentation). The service is where decisions happen.
- **Controllers / handlers are thin.** Parse input → call service → format output. No conditionals beyond input validation, no DB calls, no business decisions.
- **Repositories / DAOs are thin.** Query construction + mapping to domain types. No business logic, no orchestration of multiple aggregates.
- **No direct data access from controllers / UI.** Controllers depend on services; services depend on repositories; repositories depend on the DB. One direction. This lets you swap any layer (REST → gRPC, ORM → another ORM, real DB → mock for tests) without rewriting the others.
- **Layer enforcement is mechanical, not aspirational.** Use `dependency-cruiser` (TS/JS), `ArchUnit` (Java/Kotlin), `import-linter` (Python), `arch-go` (Go), or equivalent to fail CI on cross-layer violations. A rule no tool checks gets quietly broken.

## Feature development

**Applies universally.**

- **Each feature has a single entry point.** One module, one route group, one façade — not "we touched 7 files and changed 4 conventions." Single entry point = single place to read to understand the feature, single place to change to remove it.
- **Always check for existing logic before adding new.** Grep for the concept across the codebase. If a similar shape exists, EXTEND it; don't fork into a parallel implementation. Two implementations of the same concept = drift waiting to happen.
- **Extend over duplicate.** If existing implementation is 90% of what you need, refactor to support both cases. If 50%, that's a real fork — but document why in an ADR. Never silently duplicate.
- **New code follows current architecture, not bypasses it.** The layered structure / module boundaries / DI conventions already in place ARE the architecture. Bypassing them ("just this once for performance") is how the architecture dies — there's never a single bypass; the second one always follows.

## AI-assisted development

**Applies universally.**

- **AI-generated code is reviewed before use.** Read what the model produced, run it mentally, run it actually. Don't accept code you don't understand — silent regressions are how trust dies. The agent's "looks plausible" is not a verification.
- **The AI follows the project's structure, not its training-data defaults.** When an agent suggests a generic pattern that doesn't match the project's conventions, REJECT — don't merge it just because it compiles. The setup-project's pre-flight + `ai/conventions.md` + `.claude/codebase-profile.md` exist exactly so the AI has the project's actual conventions; if it's still drifting, the conventions file isn't loaded or the prompt is wrong.
- **Prefer refactoring prompts over generation prompts in existing code.** "Refactor this function to handle X" produces code that respects the existing shape; "Write a function that does X" produces a generic function that may not fit. Generation is for greenfield; refactor is for everything else.
- **Trust but verify agent reports.** When an agent says "done," check: did it actually run the tests it claims to have run? did the diff actually contain the change? Agents have a known failure mode of producing plausible-looking summaries that don't match reality.
- **Save validated corrections.** When you correct an agent's output, the correction is durable knowledge — append to `ai/dynamic/corrections.md` (or `feedback-learned.md`) so the next agent in the same session learns from it. The Phase 6 learning loop graduates corrections into permanent rules.

## Change control

**Applies universally.**

- **Don't modify code you don't understand.** Read the function. Read its callers. Read its dependencies. If you can't trace inputs / outputs / side effects in ~2 minutes, you don't know enough yet — read more, ask, or stop. (See also `quality-principles.md` § Must — same rule, applied at the change-discipline level here.)
- **Identify the blast radius before changing.** "What does this affect downstream?" If "the whole system," your change is high-risk and needs MORE review, not less. High-blast-radius changes get an ADR.
- **Side-effects are surfaced, not hidden.** Adding a new write (DB, log, event, network call) inside a function that previously had none is a behavior change — document it; if the function is named like a query (`getX`, `findX`), RENAME it to reflect the new behavior.
- **Reversibility is a feature.** Prefer changes that revert with a single commit. Two-phase migrations (add new → deprecate old → remove old) over big-bang rewrites. Big-bang rewrites need an ADR explaining why a phased path was rejected.
- **Don't fix unrelated things in the same change.** Unrelated fixes mixed into a feature PR make review impossible and revert dangerous. Keep separate concerns in separate commits or PRs. (Boy Scout Rule from `quality-principles.md` is bounded to *adjacent* cleanup — same change, same diff context — not arbitrary other-file improvements.)

## Consistency

**Applies universally.**

- **Match what's already there.** Same naming style, same file layout, same error handling, same logging style. The codebase IS the style guide; deviation is a bug. (Phase 4.6 anchor block above lists this project's specifics.)
- **New patterns require a reason and an ADR.** If you find yourself introducing a shape that doesn't already exist, pause: is the existing shape genuinely insufficient? Yes → write an ADR. No → use the existing shape.
- **Conventions converge, not diverge.** When you see two ways to do the same thing in the codebase, that's drift. Pick one (usually the newer or more-extended one), add it to `ai/conventions.md`, and gradually migrate the other.

## When to break a rule

These rules are defaults, not laws. Break one when:

- The rule and the situation genuinely don't fit (e.g., a layered-architecture rule applied to a functional-core codebase).
- A more important rule conflicts (e.g., consistency vs correctness — pick correctness).
- A documented exception exists in `ai/conventions.md` or an ADR.

When you break a rule, leave a one-line comment explaining why. Future-you, or the next agent, will thank present-you.

## Cross-references

- `quality-principles.md` — micro-level code hygiene (function size, naming, exceptions, etc.). This file complements it, doesn't replace it.
- `ai/conventions.md` — the project's actual detected/declared conventions (auto-populated from extraction).
- `ai/decisions/` — append-only ADRs for documented exceptions and architectural choices.
- `ai/failures/_index.md` — validated anti-patterns specific to this project ("we tried X; it broke; don't").
