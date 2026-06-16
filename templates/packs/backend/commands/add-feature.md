---
description: Comprehensive orchestration for a new feature. Detects domain signals, consults every relevant pattern, dispatches every applicable agent, runs every safety skill, produces ready-to-ship code + tests + docs + telemetry.
---

# /add-feature

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/add-feature <desc> --plan` plans the feature and exits before any edit.

## The Premise (read this first, internalize, do not deviate)

**Existing siblings are the truth.** When 50 endpoints in this codebase follow pattern X — same controller shape, same DI primitive, same error envelope, same validation library, same file path under `<module>/<kind>/...` — that pattern IS the project's intentional truth. The 51st endpoint does not get to invent pattern Y. Future maintainers can't predict where things live, fixes can't be applied uniformly, and the codebase fragments by one more weight every time someone improvises.

**The agent's job is exactly this:**
1. Find ≥2 sibling endpoints / services / modules in the same pack (same module if it exists; nearest neighbor module if not).
2. Read their shape — file paths, naming, layer boundaries, error envelopes, validation, DI primitives, logging, test layout.
3. Mirror that shape for the new feature. Innovating without precedent is the failure mode.

**The agent does NOT:**
- Ask the user about cosmetic style (camelCase vs snake_case, file naming, import order). **Mirror the sibling silently.**
- Ask the user which error type / DI primitive / validation library to use. **Mirror the sibling silently.**
- Draft an ADR to legitimize a one-off shape. **Mirror the sibling, no ADR.**
- Reach for a pattern from training data when the codebase already has one. **Sibling wins.**

**The agent ONLY asks the user when:**
- **No siblings exist** — this is genuinely the first feature in a new module / new layer / new primitive class. Ask once, get the shape blessed, then mirror it forever after.
- **Requirements conflict with existing patterns** — the new feature's shape genuinely cannot be expressed in the project's existing primitives (e.g., first async job in a sync-only codebase).
- **Cross-module dependency requires architecture decision** — a new coupling between modules that didn't talk before; this is an ADR, not a code question.

That's it. Three escalation triggers. Everything else is silent sibling-mirror with the closure verbs below.

## Prior-art gate (all tiers, runs before tier selection)

Sibling search finds a pattern to *copy*. This gate asks a different question first: **does the capability already exist** under another name? Building a second copy of something the codebase already has is the single most expensive waste mode in a mature project, and sibling-mirror does not catch it.

1. Search by **behavior, not name** — handler/route names, service methods, domain verbs, table/column names that would already cover the ask. A "send invoice email" feature may already live inside a `NotificationService.dispatch(...)` path.
2. **Near-duplicate found → HALT.** Surface the existing implementation (path + what it does) and ask the user: extend it, replace it, or ship a deliberate parallel (rare — requires a one-line rationale recorded in the PR).
3. Nothing matches → proceed to tier selection.

This is the cheapest check in the command and prevents the costliest rework. It runs even at trivial tier.

## Closure verbs (complexity → ceremony)

Default to the lightest tier that fits. Heavy ceremony is opt-in, not default.

| Tier | Triggers | Artifacts | Phases |
|---|---|---|---|
| **Trivial** (default) | 1 file added, mirrors 1 sibling exactly. No new pattern element. | Code + tests. **No plan, no ADR, no Phase 5 docs.** | Understand (light) → Generate → Validate (sibling-shape halt) |
| **Standard** | 2-5 files, includes 1 new pattern element (new endpoint kind, new DTO shape) but reuses existing primitives. | Code + tests + 1-paragraph plan + sibling-shape note in PR. **`n-plus-one-scan` on any new list / query endpoint.** **No ADR unless pattern is genuinely new.** | Understand → Retrieve (siblings) → Generate → Validate |
| **Heavy** | Cross-module, new layer, new primitive, schema change, write-path mutation, payment / auth / multi-tenant surface. | ADR + plan + reviewer dispatch + parity tests for affected existing endpoints. Full 7-phase ceremony below. | All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve) |

**Most adds are 2 files. Default to trivial.** If the audit (Phase 6 sibling-shape halt) flags new primitives or cross-module touch, it promotes the row to standard or heavy — the agent does NOT pre-emptively pick heavy "to be safe."

## Invariants (all tiers)

- **Zero placeholders** in output. Every file has real content.
- **New external dependency is gated** — pulling in a package siblings don't already use halts for a dependency review (see § New-dependency gate). No silent dep additions, any tier.
- **Sibling shape mirrored** — paths, naming, primitives match ≥2 existing siblings.
- **Zero untested business logic ships.**
- **Signal-aware at heavy tier** — multi-tenant code → multi-tenant reviewers; AI → AI reviewers.
- **Telemetry designed, not bolted on** (heavy tier).

## Phases applied

Heavy tier runs all 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve). Trivial / standard tiers run the subset their closure-verb tier requires (see the table above) — skipping phases outside your tier's ceremony is sanctioned; skipping phases inside it is not. Per canonical line 27, this declaration is mandatory even when the answer is "all 7 at heavy tier."

## When to use / NOT to use

- USE (trivial/standard): a new feature that mirrors existing siblings — most cases.
- USE (heavy, opt-in): a feature that touches multiple layers, introduces a new primitive, or hits the heavy-tier triggers above.
- NOT: single-endpoint addition that mirrors an existing endpoint → use `/add-endpoint`.
- NOT: bug fix → use `/fix-bug`.
- NOT: pure refactor → use `/refactor`.

## Sibling-shape halt (mechanical gate, all tiers)

**Before declaring success / before merge, the auditor compares the new file(s) against ≥2 sibling files in the same module.** This is the same `regressed` mechanism from `parity-auditor.md` (V2-structure conformance) — borrowed, adapted for greenfield adds.

Halt if the new file:
- **Imports utilities sibling files don't import** (sign of pattern drift — fetched from training data instead of mirrored).
- **Uses an error type / DI primitive / validation library siblings don't use** (e.g., raw `try/catch` when siblings use a `Result` envelope; raw `axios` when siblings use a typed client; `zod` when siblings use `class-validator`).
- **Sits at a path that doesn't match the existing module shape** (e.g., `src/foo/handlers/` when siblings live at `src/<module>/controllers/`).
- **Names exports / classes / files differently from siblings** (PascalCase vs camelCase drift, suffix drift like `*Service` vs `*Manager`).

Halt verdict for each new file uses the shared vocabulary in [`templates/snippets/sibling-shape-halt.md`](../../../snippets/sibling-shape-halt.md): `aligned` (matches ≥2 siblings) | `drifted` (one or more axes diverge) | `no-siblings` (escalate to user — first feature in module, get shape blessed).

Any `drifted` → HALT before merge. Either re-shape to match siblings (default closure) or — if the deviation is intentional and load-bearing — write an ADR justifying it and promote the row to heavy tier. Drift without ADR is forbidden.

For trivial-tier ports, this halt is the only gate. No reviewers, no telemetry sign-off — just sibling parity.

## New-dependency gate (all tiers)

The sibling-shape halt flags an unfamiliar import as *drift* — fetched from training data instead of mirrored. This gate covers the other case: a dependency the feature **genuinely needs** that no sibling already uses (first HTTP client, first PDF lib, first crypto package).

Adding it is not automatically wrong, but it is never silent. Before the package lands:

- **Confirm it's actually new** — not already in the lockfile under a sibling's import. Reuse the existing one if so.
- **Run a dependency review** (dispatch `security-auditor` on the dep, or inline against the checklist if not installed): maintenance health (last release, open-CVE count), license compatibility, transitive bloat / install size, and whether a stdlib or already-present primitive does the job.
- **Record the decision** — one line in the PR (trivial / standard) or an ADR (heavy, or any dep touching auth / crypto / payment / data-handling).

HALT on an unreviewed new dependency. A new package on a write-path / security surface with no ADR is forbidden.

---

## Heavy-tier 7-phase ceremony (opt-in)

Everything below applies ONLY when the row is heavy-tier per the table above. Trivial / standard rows skip directly to Phase 4 (Generate), apply siblings-mirror, run the sibling-shape halt, and ship.

## Phase 1 — Understand (the ask)

1. If prompt is vague → run `/expand-task "<brief>"` first. Get full spec. Pause for user confirmation.
2. If prompt is clear → continue.
3. Identify signals from ask AND `CLAUDE.md`:
   - Multi-tenant? AI? Webhook? Payment? Real-time? Event-sourced? File-upload? Search? Notifications? Background job? Cross-service? Compliance?
4. Define scope boundaries: what's IN, what's explicitly OUT.

### Requirements (business-analyst)

Dispatch `business-analyst` with the refined prompt + current phase from `ai/status.md`.

Output: goal, actors, user stories, acceptance criteria, edge cases, non-functional requirements, dependencies, explicit out-of-scope, open questions.

**Pause. Get user confirmation on requirements.** Don't design on shaky requirements.

## Phase 2 — Organize (design the work)

Dispatch architects in parallel:

- `api-architect` — module shape, API surface, DTOs, service boundaries, DI wiring.
- `schema-architect` (if DB changes) — tables, columns, indexes, FKs, migration approach.
- `telemetry-architect` — logs + metrics + traces + alerts + SLOs for this feature.
- `system-architect` (if cross-service / distributed) — boundaries, consistency model, failure modes.
- `ui-architect` (if frontend) — page/component shape, state, services, i18n keys.
- `design-system-architect` (if new UI patterns) — tokens + primitives needed.

If a named architect is not installed in this project, produce that design axis inline against its pack's checklist — never silently skip the axis.

Cross-reference outputs for contradictions. Resolve before proceeding.

**Pause. Get user confirmation on design.** Designs are cheap to change; code isn't.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Plus:
- `.claude/rules/` — every file (auto-loaded, but re-scan for this task).
- `ai/architecture.md` — existing layers, data flow, trust boundaries.
- `ai/modules.md` — existing modules (mirror their shape).
- `ai/patterns/api-contract.md` — response shape + DTO evolution.
- `ai/patterns/error-handling.md` — typed errors + HTTP mapping.

SIGNAL-BASED (parallel):

| Signal | Read these patterns |
|---|---|
| Multi-tenant | `multi-tenancy.md`, `tenant-isolation.md` |
| AI / LLM | `prompt-builder.md`, `ai-cost-tracking.md` |
| Webhook | `webhook-flow.md` + `webhook-signature-verification` rule |
| Payment | `payment-idempotency.md`, `idempotency.md` |
| Real-time | `ssr-safety.md`, websocket patterns |
| Event-sourced | `event-sourcing.md`, `cqrs.md` |
| Cross-service call | `saga.md`, `outbox.md`, `circuit-breaker.md`, `idempotency.md`, `api-versioning.md` |
| Heavy reads | `caching-strategy.md`, `indexing-strategy.md` |
| High scale | `sharding-partitioning.md` |
| Frontend | `rendering-strategy.md`, `i18n.md`, `forms.md` |
| User-facing UI | `design-systems.md`, `theming.md`, `rtl.md`, `motion.md` |
| New DB tables | `migrations.md`, `indexing-strategy.md` |
| Deployment change | `zero-downtime-deploys.md`, `cicd-pipeline.md` |
| Observability needs | `structured-logging.md`, `metrics.md`, `tracing.md` |
| Security surface | `zero-trust.md`, `auth-flow.md` |
| Testing strategy | `test-strategy.md`, `test-doubles.md` |

Don't read everything. Read what matters for THIS feature.

EXISTING CODE:
- 1-2 sibling modules in the same layer — confirm the pattern is project-wide.
- The exact module(s) being extended (if any).

## Phase 4 — Generate (scaffold + implement + test)

### Scaffold

- New module? → `module-scaffold` skill.
- New endpoints on existing module? → `/add-endpoint` pattern per endpoint.
- DB changes? → `/add-migration`, then `schema-diff` skill to verify; if populated table touched, run `migration-rehearsal` skill.
- Frontend? → `/add-page` / `/add-component` / `/add-crud-page` per ui-architect's design.

### Implement

Mirror sibling modules EXACTLY. Never invent a layout / name / export style.

Domain-specific implementation requirements:

**Multi-tenant**: every query filters by `tenant_id`. Every cache key tenant-prefixed. Events carry tenant in metadata (not payload).

**AI / LLM**: prompt builder uses documented 4-layer structure. `max_tokens` always set. Tokens + cost logged per call.

**Webhook**: raw body + HMAC verified BEFORE processing. Idempotency key stored. Return 200 within budget.

**Payment**: idempotency key required. Provider call uses the key. Failure handled without double-charging.

**Cross-service**: timeout + retry policy + circuit breaker + fallback per call.

### Tests

Dispatch `test-engineer` with:
- Acceptance criteria from Phase 1 → test cases.
- Edge cases → boundary tests.
- Multi-tenant? → cross-tenant leak test.
- AI? → prompt-eval fixture added.
- Webhook? → signature verification test + idempotency test.
- Cross-service? → `contract-test` if applicable.

Verify:
- Unit tests exist for every use-case.
- Integration tests exist for every repo change.
- E2E test for the user flow.
- All tests pass locally.

Run skills:
- `endpoint-test` against dev server for each new endpoint.
- `coverage-gap` — are changed lines tested?
- `n-plus-one-scan` on new list endpoints.

## Phase 5 — Update (persist changes to the knowledge base)

Update via `doc-writer`:
- `ai/modules.md` — new row if a module was added.
- `ai/status.md` — prepend Recent Changes entry (what / why / follow-ups).
- `ai/patterns/<new>.md` — if a new reusable pattern emerged.
- `ai/decisions/NNNN-*.md` — ADR if an architectural decision was made.
- `ai/dynamic/changelog.md` — one-line summary.
- For UI changes: regenerate i18n keys in `locales/`.

## Phase 6 — Validate (review + observability + domain + security)

### Review (parallel dispatches)

**Always dispatch**:
- `code-reviewer`
- `test-reviewer`
- `doc-drift-scan` skill — does the change need doc updates beyond status.md?

**Dispatch based on TOUCH** (what files changed):
| Touched | Agent |
|---|---|
| Backend code | `api-reviewer` |
| DB entities / migrations | `schema-reviewer` (+ `migration-review` command for migrations) |
| Frontend components | `ui-reviewer`, `design-system-guardian`, `accessibility-auditor`, `i18n-auditor` |
| Auth / crypto / secrets | `security-auditor`, `auth-reviewer` |
| Hot paths / queries | `performance-optimizer`, `query-optimizer` |
| Events / queues / cross-service | `resilience-reviewer` |
| Telemetry / logs / metrics | `observability-reviewer` |

**Dispatch based on DOMAIN SIGNALS** (what the project is):
| Signal | Agent |
|---|---|
| Multi-tenant | `tenant-isolation-reviewer` |
| AI | `prompt-reviewer` |
| Payment | `payment-reviewer` |

**Missing-agent fallback (applies to every dispatch table in this command):** if a named agent is not installed in this project, perform that review inline against the corresponding pack/domain checklist — never silently skip the axis. Note the substitution in the consolidation note (`inline:<agent-name>`).

Consolidate findings. **Mechanical halt**: HALT unless EVERY dispatched reviewer returns 0 BLOCKER and 0 CRITICAL findings. Record `reviewers_dispatched=N` and `reviewers_clean=N` in the consolidation note — proceed only when `reviewers_clean == reviewers_dispatched`. If any reviewer flags a blocker, re-run that specific reviewer after the fix; do not paper over, do not aggregate-and-ignore.

### Observability sign-off

Verify:
- Every new endpoint emits request counter + latency histogram.
- Every external call emits success/failure + latency.
- New errors have alert rules (or explicit "no alert needed" note).
- Correlation id propagates through.
- Trace spans on hot paths.
- Sensitive data redacted in logs.

If gaps: dispatch `/add-telemetry` before ship.

### Domain-specific verifications (signal-driven)

Run based on signals:
- AI → `/prompt-eval` + `/token-audit`
- Webhook → `/simulate-webhook` with a new fixture
- Multi-tenant → `/tenant-leak-audit` focused on changed files
- Public API surface → `api-snapshot` diff (breaking change detection)
- Cross-service → `chaos-test` planned for staging (ticket, not inline)
- Frontend → `visual-check` + `a11y-scan` for affected routes

### Security pre-flight

Dispatch `/security-audit` scoped to the diff. Block on any BLOCKER.

### Release pre-flight (heavy tier)

One short note in the PR description — not a new ceremony:

- **Flag decision**: behind a feature flag, or flagless with rationale (e.g., additive endpoint, no existing-path risk).
- **Migration ordering**: if schema changed, expand → migrate → contract sequence stated; deploy is safe with old + new code running simultaneously.
- **Rollback path**: one sentence — flag off / revert commit / down-migration. "Cannot roll back" requires an ADR.
- **Staging verification**: what gets checked on staging before production (the `chaos-test` ticket for cross-service features lands here).

If any check fails: HALT, report the failure, do not paper over.

## Phase 7 — Improve (feed the learning loop)

- Run `/learn-from-task` to capture: decisions, patterns followed/introduced, corrections, follow-ups.
- If a new shape emerged in 3+ places across this feature: queue to `ai/dynamic/learned-patterns.md`.
- If a user correction during architecture review reset the design direction: append to `ai/dynamic/feedback-learned.md`.
- If a decision warrants formal ADR: queue to `ai/dynamic/decisions-pending.md`.
- If review surfaced drift between code + convention: append to `ai/dynamic/drift-log.md`.

## Output

**Trivial / standard tier** (most runs) — report only what actually ran:

```
✅ Feature: <name>  (tier: trivial|standard)

Sibling(s) mirrored: <paths>
Files created/modified: <counts>
Tests added: <count> — passing
Sibling-shape halt: aligned (<N> axes checked)
Docs: ai/status.md updated <+ plan paragraph if standard>

Next: commit + open PR
```

**Heavy tier** — full report:

```
✅ Feature: <name>

Phase 1 (Understand): goal, actors, acceptance criteria confirmed; signals: <list>.
Phase 2 (Organize): architects dispatched (api, schema, telemetry, system); design confirmed.
Phase 3 (Retrieved): 7 universals + <N> signal-specific patterns + <N> sibling modules.
Phase 4 (Generated): <files created>; tests passing.
Phase 5 (Updated): ai/modules.md (+1), ai/status.md (Recent Changes), ai/patterns/<new>.md.
Phase 6 (Validated): <reviewers> ran; security pre-flight clean; observability sign-off.
Phase 7 (Improved): /learn-from-task queued.

Scope:
  Modules touched: <list>
  Files created:   <count>
  Files modified:  <count>
  Tests added:     <count>
  Migrations:      <count>

Consulted patterns: <list>
Agents dispatched:  <list>
Skills run:         <list>

Review verdict: APPROVE / REQUEST_CHANGES / BLOCK

Telemetry added:
  Metrics: <list>
  Alerts:  <list>
  Traces:  <list>

Follow-ups:
  - <anything left for a later PR>

Docs updated:
  - <list>

Status: COMPLETE

Next:
  - /review-changes  (for a final independent pass)
  - Commit + open PR
```

## Hard rules

- Never skip phases within your tier's ceremony to save time. Tier selection (Closure verbs table) is the only sanctioned way to shrink the flow.
- Pause at Phase 1 (requirements) and Phase 2 (design) — heavy tier only. Trivial / standard run unpaused.
- No feature ships without tests for every acceptance criterion.
- No feature ships without telemetry.
- No feature ships with any security BLOCKER open.
- Domain signals drive automatic reviewer dispatch — don't forget them.
- Every consulted pattern logged in the report for traceability.

## Related

### Sibling commands in backend pack
- `/add-endpoint` — sibling command in backend pack
- `/add-module` — sibling command in backend pack
- `/analyze-module` — sibling command in backend pack
- `/endpoint-test` — sibling command in backend pack
- `/fix-bug` — sibling command in backend pack
- `/log-tail` — sibling command in backend pack
- `/trace-flow` — sibling command in backend pack

### Patterns
- `ai/patterns/api-contract.md`
- `ai/patterns/api-versioning.md`
- `ai/patterns/caching-strategy.md`
- `ai/patterns/error-handling.md`
- `ai/patterns/parallel-io.md`

### Rules
- `.claude/rules/backend-principles.md`
- `.claude/rules/concurrency-discipline.md`
