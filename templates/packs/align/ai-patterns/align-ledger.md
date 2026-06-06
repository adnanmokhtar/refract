---
name: align-ledger
description: Pattern: Align ledger (state machine + record format for codebase-quality findings)
kind: ai-pattern
pack: align
---

# Pattern: Align ledger (state machine + record format)

> **Hard rule:** Every detected finding has exactly one ledger row that transitions through the documented state machine; the ledger update is part of the same PR / commit as the fix it records. Verbal status, "I'll update it later", and rows without `evidence:` / closure-verb / tier are forbidden.

**When to apply**
- An align sweep spans more than ~10 findings or > 1 day of work — informal tracking will drift.
- Multiple agents / contributors will close findings concurrently — the ledger is the source of coordination.
- Phase gates require an audit trail (`/align-gate <N>` reads the ledger to refuse on blockers).

**When NOT to apply**
- A one-shot 2-finding spot fix via `/align-recheck <area>` — overhead exceeds value (the spot-fix mode tracks state in commit messages instead).
- A throwaway sweep against an experimental branch where outputs won't ship.

**Halt conditions / mandatory cites**
- Every finding row MUST cite source at `<path:line>` AND the closure verb chosen (from `align-discipline.md § Closure-verb vocabulary`).
- A row missing `tier:` (trivial / standard / heavy) or `closure_verb:` is a bug — reject the PR until filled.
- Hand-wave grep on `etc.`, `...`, `roughly`, `~N findings` is forbidden when claiming "phase done".
- `gaps_in != gaps_closed` halts the row at `find-and-align`'s RECORD step.
- If the ledger path or finding inventory source isn't extracted, halt before transitioning rows.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Align` + `_extracted-idioms.md`.
>
> - **Ledger path**: `ai/align/ledger.md` (default; override only with strong reason).
> - **Finding inventory source**: `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md` (the gold-standard oracle).
> - **Update cadence**: on every commit that closes a finding; phase gate verifies aggregate state.
> - **Owner**: `<extracted>` (typically the engineering team owning the affected module; default = `_extracted-codebase.md § Owners`).

The ledger is the **single source of truth** for codebase-alignment state. It converts a multi-day quality sweep from "vibes-based" tracking to a checkable, queryable artifact. `/align-gate <N>` refuses the phase if the ledger is not fully updated.

## State machine

```
   ┌──────────┐  initial state for every finding in the scan inventory
   │ detected │
   └────┬─────┘
        │ /align-phase or /align-fast claims this row
        ▼
   ┌─────────────┐  evidence captured; tier set; closure verb chosen
   │ in-progress │
   └────┬────────┘
        │ fix shipped; net-lines + idiom-citation + verify pass
        ▼
   ┌──────────┐
   │  fixed   │
   └────┬─────┘
        │ re-detect green at the source path; CI green
        ▼
   ┌──────────┐
   │ verified │  terminal — appears in /align-gate's PASS count
   └──────────┘

   parallel terminal states (any in-progress row may transition to):
   ┌──────────┐  /align-park <id> — defer with rationale (excluded from gate)
   │  parked  │
   └──────────┘
   ┌──────────┐  /align-deprecate <id> — won't fix; ADR required
   │ archived │
   └──────────┘
   ┌──────────┐  blocker; see notes for destination (next phase / ADR / park)
   │  halted  │
   └──────────┘
```

## Record format

Every row is a YAML block under a `## <id>` heading in `ai/align/ledger.md`:

```yaml
## ALIGN-0042
status: verified                # detected | in-progress | fixed | verified | parked | archived | halted
class: silent-catch             # one of the 12 universal classes (or stack-conditional class)
tier: trivial                   # trivial | standard | heavy
source:
  - path: <services-root>/order.<ext>
    lines: 138-142
evidence: "swallowed catch in fetchOrders; no logger call, no rethrow"
closure_verb: surface-error     # from align-discipline.md § Closure-verb vocabulary
gaps_in: 1
gaps_closed: 1                  # MUST equal gaps_in before status can advance to fixed
commit: <sha>                   # the commit that closed this row
phase: 2
ported_at: 2026-05-03T11:42Z
notes: |
  Replaced `catch {}` with `catch (e) { logger.error('orders.fetch failed', e); throw e; }`.
  No behavior change — error was already propagating to caller via undefined return.
```

**Required fields per state**:

| State | Required fields |
|---|---|
| `detected` | `class`, `source`, `evidence`, `tier` |
| `in-progress` | + `closure_verb`, `phase` |
| `fixed` | + `gaps_in`, `gaps_closed` (must equal), `commit` |
| `verified` | + `ported_at` (re-detect timestamp), CI green at `commit` |
| `parked` | `parked_reason`, `parked_at` |
| `archived` | `adr: ADR-NNN` |
| `halted` | `notes:` MUST cite next-step destination (phase / ADR / park) |

## See also

- `align-discipline.md` — closure-verb vocabulary, tier rules, halt conditions.
- `migration-ledger.md` (sibling pattern) — the V1→V2 port equivalent; same state-machine shape, different oracle.
- `find-and-align` skill — the per-finding fix loop that drives state transitions.
- `/align-gate <N>` — phase exit verifier; reads this ledger.
