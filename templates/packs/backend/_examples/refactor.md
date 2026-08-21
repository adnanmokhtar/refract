---
description: Backend-targeted refactor — preserves API contracts, error envelopes, DI, and layer boundaries. Behaviour-preserving only; uses refactoring-sweep verbs.
kind: example
pack: backend
---

# /refactor [<scope>]

## Pack overlay — backend

**Canonical orchestration:** [`commands/refactor.md`](../../../../commands/refactor.md).

This overlay is deliberately two rules long. Layering, error-envelope stability, DTO stability and "use DI" are already **MUSTs** in `.claude/rules/backend-principles.md`, which is always loaded whenever this command runs. What follows is only what the universal `/refactor` cannot know.

### 1. On a backend, the wire is the observable

"Behaviour-preserving" is stricter here than on a UI: **every byte a consumer can see is behaviour.** A response field name, a route path, an error `code`, an HTTP status, a header, the ordering guarantees of a list — all of them are somebody's parser.

So the Fowler verbs split in two:

| Move | Still `/refactor`? |
|---|---|
| Rename an internal helper, service method, private field, local variable | **Yes** — invisible on the wire. |
| Extract a service, move a module, inline a method, flatten a conditional | **Yes**, provided the handler's inputs and outputs are byte-identical. |
| Rename a DTO **field**, a route segment, an error `code`; change a status; reorder a list | **No.** A contract change wearing a refactor's clothes — it leaves this command entirely and goes through `ai/patterns/api-contract.md` § Evolution rules, with the deprecation flow. |

The deciding test: *could a consumer that never redeploys tell the difference?* If yes, stop — calling it a refactor is how a breaking change ships without a version bump. Snapshot/contract tests are the mechanical form of this check; a green run is the evidence, a red one is the answer.

### 2. Mirror the project's injection style, don't introduce a second one

`backend-principles` requires DI. It does not say *which* DI, because that is per-project. A refactor that extracts a collaborator must wire it the way its siblings are wired — same container, same decorator or provider convention, same construction site.

Introducing constructor injection into a module whose siblings use a factory (or vice versa) is a second architecture, not a refactor — and it is the change most likely to pass review, because each half looks correct on its own.

Cite the sibling you mirrored at `<path:line>` in the change note.

### Worked example

User: `/refactor src/orders/order.controller.ts — flatten nested validation`

- Preserve HTTP status codes and JSON error shape vs sibling `product.controller.ts`.
- Apply `flatten-conditional` only inside the controller handler; delegate persistence changes to the service layer only if siblings already do.
- Name the sibling whose DI wiring was mirrored, at `<path:line>`.

### Dispatch

Follow [`commands/refactor.md`](../../../../commands/refactor.md); apply the `refactoring-sweep` skill; consult this pack's `STACK.md` and `.claude/_extracted-idioms.md` for oracle shapes.

### When NOT

Cross-cutting architectural extraction across services → `/optimize`. Database query perf → `/optimize` or `/optimize-query`. Anything that changes the wire → `/add-endpoint` or the versioning flow, never here.
