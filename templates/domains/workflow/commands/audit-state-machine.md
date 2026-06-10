---
description: Audit an entity's state machine — locate the status field + transitions, reconstruct the actual transition matrix from source, and verdict explicit-table / guard / optimistic-lock / idempotency / side-effect-ordering / audit / terminal-and-stuck — against real code, never an assumed lifecycle.
---

# /audit-state-machine

Diagnose whether an entity's lifecycle is a real state machine or an accident: is there an explicit allowed-transition table, or is `status` written ad-hoc; is each transition guarded, optimistic-locked, idempotent; do side-effects ride the commit; is every transition audited; are terminal and stuck states handled — built from the REAL code, not a guess.

## Premise

Real signals only. Cite the actual `status` / `state` field at `<path:line>`, the verbatim transition table (or its absence), EVERY raw `status =` / `SET status=` write at `<path:line>`, the optimistic-lock predicate at `<path:line>`, the idempotency check, the side-effect-vs-commit ordering, and the audit write — never narrate a lifecycle you didn't read. Read before auditing: locate the entity, its state column, and every writer of that column in source BEFORE issuing any verdict.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the state field + its type at `<path:line>` (enum or free string), (2) the allowed-transition table at `<path:line>` OR "MISSING — implicit transitions", (3) EVERY writer of the state field at `<path:line>` (the single transition function, or the scattered ad-hoc writes), (4) the optimistic-lock predicate at `<path:line>` OR "MISSING — lost-update race", (5) the idempotency check OR "MISSING — re-fire double-advances", (6) the side-effect-vs-commit ordering (outbox-in-tx | effect-before-commit | best-effort-after), and (7) the audit write at `<path:line>` OR "MISSING". If any of these cannot be produced from real source, HALT and say which — never an assumed table, never an assumed lock.

READ-ONLY. This command reads source and reconstructs the matrix; it does not run transitions, does not mutate any entity, and does not execute migrations.

## What it does

1. **Locate** the entity + its state field — cite `<path:line>` and whether the type is a closed enum or a free string (`status: string` is a finding on its own).
2. **Find the transition table** — the declared `(from → allowed-to)` / `(state, event) → state` table. Cite it at `<path:line>`. If there is none, the lifecycle is implicit — record it and enumerate the de-facto transitions from the writes instead.
3. **Enumerate every writer of the state field** — grep the codebase for `status =`, `state =`, `SET status=`, `.update({ status`, etc. There MUST be exactly one (the transition function). Cite every other writer at `<path:line>` — each is a bypass finding.
4. **Check guards** — does each edge evaluate a precondition against fresh state before mutating? Cite a guardless edge at `<path:line>`.
5. **Check concurrency** — is the state-mutating UPDATE optimistic-locked (`version` / expected-from-state in the WHERE), and does zero-rows-affected abort rather than overwrite? Cite the predicate at `<path:line>`; absence is a lost-update BLOCKER.
6. **Check idempotency** — does a re-fire (retry / duplicate webhook) no-op, or advance twice? Cite the idempotency key / `alreadyApplied` check at `<path:line>`.
7. **Check side-effect ordering** — is the effect an outbox row in the SAME transaction (good), fired BEFORE the commit (effect-without-state), or best-effort AFTER (state-without-effect)? Cite the effect call site relative to the commit at `<path:line>`.
8. **Check audit** — does every transition write who/when/from→to/reason in the same transaction? Cite at `<path:line>`.
9. **Check terminal + stuck** — do terminal states reject all edges (zero outgoing in the table)? Does every waiting state have a timeout/escalation sweep? Cite the sweep at `<path:line>` or flag "no deadline".
10. **Report** — the reconstructed state/transition matrix + a per-axis verdict + the top fix.

## Flow

```text
locate entity + state field (<path:line>)                        [finding if free string]
  -> find transition table (<path:line>)                         [BLOCKER if MISSING — implicit]
  -> enumerate ALL writers of the state field                    [finding per writer outside the fn]
  -> per edge: guard present?                                    [finding if guardless]
  -> state UPDATE optimistic-locked? zero-rows aborts?           [BLOCKER if blind overwrite]
  -> transition idempotent on re-fire?                           [BLOCKER if double-advances]
  -> effect: outbox-in-tx | before-commit | best-effort-after    [BLOCKER if before/after]
  -> every transition audited in the same tx?                    [BLOCKER if MISSING]
  -> terminal states reject all edges? waiting states timed-out? [finding if not]
  -> report: matrix + per-axis verdict + top fix
```

## Output

```
/audit-state-machine — <entity> @ <path:line>

State field:       order.status : OrderStatus (enum)  @ order.entity.ts:14   [or: string — FINDING]
Transition table:  TABLE  @ order.machine.ts:31                              [or: MISSING — implicit, BLOCKER]
Single writer:     OrderMachine.transition  @ order.machine.ts:48
  Other writers:   NONE                                                       [or: orders.controller.ts:62 status='shipped' — BLOCKER]

State / transition matrix (reconstructed from source):
  draft             --submit-->  awaiting_payment   guard=hasLineItems
  awaiting_payment  --pay----->  paid               guard=paymentDue     effect=capturePayment
  awaiting_payment  --expire-->  cancelled          guard=always         effect=notifyExpired   (timeout)
  paid              --refund-->  refunded (terminal) guard=always         effect=refund
  ...
  cancelled         (terminal — 0 outgoing edges)
  refunded          (terminal — 0 outgoing edges)

Guards:            present on all non-trivial edges                          [or: ship has no guard @ :77 — FINDING]
Concurrency:       optimistic lock WHERE status=$from AND version=$v @ :71   [or: MISSING — lost-update BLOCKER]
                   zero-rows -> ConcurrentTransition (abort)                 [or: blind overwrite — BLOCKER]
Idempotency:       alreadyApplied + idemKey @ :55                            [or: MISSING — re-fire double-advances BLOCKER]
Side-effects:      outbox.enqueue(tx, ...) in the same tx @ :83              [or: stripe.capture() BEFORE commit @ :80 — BLOCKER]
Audit:             audit.record(tx, {from,to,actor,reason}) @ :88            [or: MISSING — BLOCKER]
Terminal:          cancelled/refunded reject all edges                       [or: edge out of refunded @ :40 — FINDING]
Stuck states:      awaiting_payment sweep @ order.sweeper.ts:9 (24h)         [or: no deadline — FINDING]

Verdict: OK | NEEDS-TABLE | NEEDS-LOCK | NEEDS-IDEMPOTENCY | NEEDS-OUTBOX | BLOCKER(implicit/race/effect/audit)

Top recommendation:
  - <e.g. introduce the allowed-transition table + route all writes through transition();
         or add version to the UPDATE WHERE; or move stripe.capture() to the outbox>
```

## Rules

- READ-ONLY. Reconstruct the matrix from source; never run a transition, never mutate an entity, never execute a migration.
- Cite-or-halt: real state field, real table (or its absence), real writers, real lock predicate, real audit write — or halt naming what's missing.
- Always enumerate EVERY writer of the state field; more than one (outside the transition function) is the headline finding (implicit transitions).
- A blind status overwrite (no version / no expected-from-state in the WHERE) is a lost-update BLOCKER, reported even if "it hasn't raced yet."
- A side-effect fired before the state commit, or best-effort after, is a BLOCKER — say which.
- A free-string state column where the domain has discrete states is a finding, not an aside.

## Cross-references

- `.claude/rules/workflow-discipline.md` — the hard-rule list this command enforces (explicit table, single writer, guard, optimistic lock, idempotency, transactional outbox, audit, terminal/stuck, saga).
- `ai/patterns/state-machine.md` — the transition-table + guard + optimistic-locked commit + idempotency + outbox + audit code shapes.
- `<agents-path>/workflow-reviewer.md` — review gate that consumes these findings.
- `<rules-path>/audit-log` — every transition must be audited; what to record per transition.
