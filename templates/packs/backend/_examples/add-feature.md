---
description: Comprehensive orchestration for a new feature. Detects domain signals, consults every relevant pattern, dispatches every applicable agent, runs every safety skill, produces ready-to-ship code + tests + docs + telemetry.
---

# /add-feature

The most important command in the repo. Delivers a feature end-to-end at best-practice quality the FIRST time.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## Invariants

- **Zero placeholders** in output. Every file has real content.
- **All relevant patterns consulted** — not just principles, specific pattern docs.
- **All applicable agents dispatched** — parallel where independent.
- **Signal-aware** — if CLAUDE.md / code says multi-tenant, multi-tenant reviewers fire. AI → AI reviewers. Etc.
- **Zero untested business logic ships.**
- **Telemetry designed, not bolted on.**

## When to use / NOT to use

- USE: a new feature, end-to-end, that touches multiple layers.
- USE: when scope merits architecture + tests + telemetry + docs.
- NOT: single-endpoint addition to an existing module → use `/add-endpoint`.
- NOT: bug fix → use `/fix-bug`.
- NOT: pure refactor → use `/refactor`.

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

Cross-reference outputs for contradictions. Resolve before proceeding.

**Pause. Get user confirmation on design.** Designs are cheap to change; code isn't.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

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

Consolidate findings. Block on any CRITICAL / BLOCKER finding.

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

- **Flag decision**: behind a feature flag, or flagless with rationale.
- **Migration ordering**: if schema changed, expand → migrate → contract sequence stated; deploy is safe with old + new code running simultaneously.
- **Rollback path**: one sentence — flag off / revert commit / down-migration. "Cannot roll back" requires an ADR.
- **Staging verification**: what gets checked on staging before production.

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

- Never skip phases within your tier's ceremony to save time. Tier selection is the only sanctioned way to shrink the flow.
- Pause at Phase 1 (requirements) and Phase 2 (design) — heavy tier only. Trivial / standard run unpaused.
- No feature ships without tests for every acceptance criterion.
- No feature ships without telemetry.
- No feature ships with any security BLOCKER open.
- Domain signals drive automatic reviewer dispatch — don't forget them.
- Every consulted pattern logged in the report for traceability.
