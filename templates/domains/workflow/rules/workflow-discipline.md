---
name: workflow-discipline
description: Workflow / state-machine discipline
kind: rule
---

# Workflow / state-machine discipline

## Hard rule

Any entity whose `status` / `state` advances through a lifecycle (orders, approvals, KYC, onboarding, fulfilment, subscriptions, tickets, claims) MUST be driven by an EXPLICIT state machine: a declared set of states (an enum, never free strings) and a declared ALLOWED-TRANSITION table. Every state change goes through ONE transition function that (1) rejects any transition not in the table — illegal/unreachable states are impossible by construction, (2) evaluates the transition's GUARD / precondition before mutating, (3) commits the new state ATOMICALLY with an OPTIMISTIC LOCK (version / expected-from-state in the WHERE), so two concurrent transitions cannot both win, (4) is IDEMPOTENT — re-firing the same transition on an already-advanced entity is a no-op, not a second advance, (5) emits side-effects TRANSACTIONALLY with the state commit (outbox / after-commit hook), never before it, and (6) writes an AUDIT row (who, when, from→to, reason) for every transition. Terminal states reject all further transitions; long-lived non-terminal states carry a timeout / escalation. A multi-step process spanning services is a SAGA with an explicit compensation for every step.

A workflow bug is a split-brain entity (`status` that doesn't match reality), a double-charged / double-shipped side-effect, an order stuck half-done forever, or a state reached that the code never expected — all of which corrupt the system of record, not just a single request.

`status = 'shipped'` written anywhere outside the transition function is the canonical defect. There is exactly one writer of state, and it is the machine.

## Must

- **Explicit allowed-transition table**: states are a closed enum; transitions are a declared table (`from → [allowed to-states]` with a guard + effect per edge). The transition function looks the edge up; an undeclared edge THROWS. Illegal states (`paid → draft`) are unreachable because they are absent from the table, not because a human remembered to check.
- **Single writer**: state is mutated in EXACTLY one place — the transition function. No feature code, controller, migration, or admin script writes `entity.status = x` directly. Grep for raw `status =` assignments; each one is a finding.
- **Guard per transition**: every edge declares a precondition (`canPay`: balance due > 0 and not already paid; `canShip`: payment captured and stock reserved). The guard runs against freshly-read state inside the transaction, BEFORE the mutation. A transition with no guard is a finding unless the edge is genuinely unconditional.
- **Atomic + optimistic-locked commit**: the new state is written with an expected-from-state / version predicate (`UPDATE … SET status='paid', version=version+1 WHERE id=$1 AND status='pending' AND version=$2`). Zero rows affected ⇒ someone else transitioned first ⇒ abort + re-read, never blind-overwrite. Read-modify-write of a status field with no version / no expected-from is FORBIDDEN — it is a lost update.
- **Idempotent transitions**: firing `pay(order)` twice — retry, duplicate webhook, double click — advances the entity at most ONCE and runs side-effects at most once. Re-fire on an entity already in the target state returns the existing result; it does not throw "illegal transition" for the common retry case and never double-applies. Key side-effects by a transition id / idempotency key.
- **Side-effects transactional with the commit**: external effects (charge card, send email, call fulfilment, publish event) are recorded as an OUTBOX row in the SAME transaction as the state change, and dispatched AFTER commit by a relay — or run in an after-commit hook. Never fire an effect before the state is durably committed (the effect can succeed and the commit roll back ⇒ effect without state) and never commit the state then fire best-effort (the process can die between ⇒ state without effect).
- **Audit every transition**: each transition writes who (actor / system), when, from→to, the trigger/reason, and a correlation id — see `<rules-path>/audit-log`. The audit row is written in the same transaction as the state change, so an advanced entity ALWAYS has a matching audit trail. State history is reconstructable from the audit log.
- **Terminal-state handling**: terminal states (`cancelled`, `refunded`, `closed`, `expired`) are declared and reject ALL outgoing transitions. The table has no edges out of a terminal state; the transition function refuses them explicitly rather than silently no-oping.
- **Timeout / escalation on stuck states**: every non-terminal state that can be entered and then wait (`awaiting_payment`, `pending_review`, `in_fulfilment`) has a deadline. A scheduled sweep (see `<rules-path>/background-jobs`) fires a timeout transition (`expire`, `escalate`, `auto_cancel`) so nothing sits half-done forever. A state with no exit deadline is a finding.
- **Saga with compensation**: a process spanning multiple services / aggregates (place order = reserve stock + capture payment + create shipment) is modelled as an explicit saga where EVERY forward step has a compensating step (release stock, refund payment, cancel shipment). A partial failure runs the compensations in reverse; the process never strands the entity half-applied.

## Must not

- Write `entity.status = 'x'` (or `UPDATE … SET status='x'`) anywhere outside the single transition function — bypasses the table, the guard, the lock, the audit, and the side-effects.
- Represent state as a free string with no enum / no transition table — typos (`'canceled'` vs `'cancelled'`), unreachable states, and "any string to any string" transitions.
- Transition with no guard / precondition — lets `draft → shipped` happen because nothing checked payment was captured.
- Read-modify-write a status field with no version column and no expected-from-state predicate — two concurrent transitions both read `pending`, both write, the second clobbers the first (lost update / split-brain).
- Make a transition non-idempotent — a retried `pay()` or a duplicate webhook advances the entity twice and charges / ships twice.
- Fire a side-effect (charge, email, downstream call, event publish) BEFORE the state is committed, or as a non-transactional best-effort AFTER — effect-without-state or state-without-effect.
- Advance an entity with no audit row — the history of who moved it from where to where is gone.
- Leave a non-terminal state with no timeout / escalation — entities pile up in `pending_review` forever and no one notices.
- Run a multi-step cross-service process with no compensation — a failure at step 3 leaves stock reserved and payment captured with no order (stuck half-done, no rollback).
- Drive the lifecycle with scattered booleans (`is_paid`, `is_shipped`, `is_cancelled`) instead of one state field — they drift into contradictory combinations (`is_cancelled && is_shipped`) the code never anticipated.

## Should

- Wrap the machine behind a project-internal `<StateMachine>` / `transition(entity, event, ctx)` so the table lookup, guard evaluation, optimistic-locked commit, outbox write, and audit write happen in ONE place — feature code dispatches an EVENT (`pay`, `ship`, `cancel`), never a target state.
- Model the lifecycle as `(state, event) → state` rather than `from → to`, so the trigger is explicit and the same target state reached by different events is distinguishable in the audit trail.
- Make illegal states unrepresentable in the type system where the language allows it (discriminated unions / sealed types per state carrying only that state's data) so `shipped` without a `shippedAt` won't compile.
- For event-driven lifecycles, derive state from an append-only event log (see `<patterns-path>/event-sourced`) — the current state is a fold over events; transitions are events; the audit trail IS the event stream.
- Emit a structured metric per transition (`{ entity, from, to, event, durationInState, actor }`); alert on entities exceeding a state's deadline, on transition error rate, and on any raw-status-write detected at runtime.
- Keep the transition table and the diagram in sync (generate the diagram from the table); a drifted diagram hides illegal edges.

## Review checklist (PRs touching status / state / lifecycle / approval / workflow)

- [ ] State is a closed enum; an explicit allowed-transition table exists — cite it at `<path:line>`.
- [ ] Every state change goes through ONE transition function; no raw `status =` writes elsewhere — cite the writer at `<path:line>`.
- [ ] Each transition has a guard/precondition evaluated against fresh state before the mutation.
- [ ] The commit is atomic + optimistic-locked (version / expected-from-state in the WHERE); zero-rows ⇒ abort, not overwrite — cite at `<path:line>`.
- [ ] The transition is idempotent — a re-fire (retry / duplicate webhook) is a no-op, not a second advance.
- [ ] Side-effects are emitted via outbox / after-commit in the SAME transaction as the state change — never before commit, never best-effort after.
- [ ] Every transition writes an audit row (who/when/from→to/reason) in the same transaction — cite at `<path:line>`.
- [ ] Terminal states reject all outgoing transitions.
- [ ] Every non-terminal "waiting" state has a timeout / escalation transition driven by a scheduled sweep.
- [ ] Multi-step cross-service processes are sagas with a compensation per forward step.

## Anti-patterns

- **Implicit transition** — `order.status = 'shipped'; await order.save()` in a controller. No table, no guard, no lock, no audit. `draft → shipped` is now possible because nothing forbids it. Route through `transition(order, 'ship', ctx)`.
- **Stringly-typed state** — `status: string` with `'pending' | 'Pending' | 'PENDING' | 'canceled'` drifting across the codebase. Closed enum + table; reject anything off the table.
- **Guardless transition** — `ship()` flips status to `shipped` without checking payment captured / stock reserved. Declare a `canShip` guard that runs inside the transaction.
- **Lost update** — two `approve()` calls both read `status='pending'`, both write `status='approved'` and run the approval effect twice. Optimistic lock: `WHERE status='pending' AND version=$v`; zero rows ⇒ abort.
- **Non-idempotent transition** — a duplicate Stripe webhook fires `markPaid()` twice → the order advances twice and the fulfilment email sends twice. Key the effect by event id; re-fire is a no-op.
- **Effect before commit** — `await stripe.capture(); order.status='paid'; await order.save()` → capture succeeds, save throws → money taken, order still `pending`. Write an outbox row in the same tx; capture after commit.
- **State without effect** — `await order.save(); await email.send()` → save commits, process crashes → order is `paid` but the customer never hears. Outbox + relay guarantees the effect eventually fires exactly once.
- **No audit** — `status` flips with no record of who moved it or why → a disputed cancellation has no trail. Write the audit row in the same transaction (see `<rules-path>/audit-log`).
- **Boolean soup** — `is_paid`, `is_shipped`, `is_cancelled`, `is_refunded` instead of one `status`. They reach contradictory combos (`is_cancelled && is_shipped`) no code path expected. Collapse to one state field + table.
- **No terminal handling** — `refunded` still accepts `ship` because the table has an edge out of it. Terminal states have zero outgoing edges; the function refuses them.
- **Stuck forever** — entities enter `pending_review` and there's no sweep to expire / escalate them; the queue grows without bound and no one notices. Every waiting state needs a deadline + a timeout transition.
- **Saga with no compensation** — place-order reserves stock + captures payment, then shipment creation fails, and nothing releases the stock or refunds. Declare a compensation per step; run them in reverse on failure.

## Enforcement

- `<commands-path>/audit-state-machine.md` (slash: `/audit-state-machine`) — locates the status field + transitions at `<path:line>`, builds the actual state/transition matrix from source, and verdicts the explicit-table, guard, optimistic-lock, idempotency, side-effect-ordering, audit, and terminal/stuck axes — cite-or-halt, never an assumed lifecycle.
- `<agents-path>/workflow-reviewer.md` — review gate hard-failing on implicit transitions, stringly-typed state, guardless transitions, lost-update races, non-idempotent transitions, effect-before-commit, missing audit, missing terminal handling, missing timeout, and saga-without-compensation.
- CI lint MUST reject raw `status =` / `state =` assignments and `SET status=` outside the declared transition module (AST heuristic; flag for review).
- CI lint MUST reject a status/state column typed as free string where a domain enum exists.
- CI MUST assert every state-mutating UPDATE carries an expected-from-state / version predicate in its WHERE (no blind status overwrite).
- TODO: `scripts/validate-transition-table.sh` to walk the transition module, assert every edge has a guard + an audit write + an outbox/after-commit effect path, and assert no state-write occurs outside it.

## Cross-references

- `<patterns-path>/state-machine.md` — explicit transition table + guard + optimistic-locked atomic commit + idempotency + transactional outbox + audit + terminal/stuck + saga-with-compensation code shapes.
- `<rules-path>/audit-log` — every transition is an audited event; who/when/from→to/reason recorded in the same transaction.
- `<rules-path>/background-jobs` — async transitions, the outbox relay, and the scheduled sweep that fires timeout / escalation transitions on stuck states.
- `<patterns-path>/event-sourced` — event-driven lifecycles where state is a fold over an append-only event log and transitions are events.
- `<adr-path>/<NNN>-workflow-state-model.md` — ADR pinning the state model (enum vs. event-sourced), the concurrency strategy (optimistic lock vs. serializable), and the saga/compensation approach.
- **Boundary**: this rule governs APP-LEVEL state machines (an entity's lifecycle inside your service). It is distinct from the cataloged `workflow-orchestration` domain (Temporal / Cadence / Step Functions durable-execution infra) — that pack covers the orchestration engine; this pack covers the domain state machine your code runs.
