# ADR <NNNN> — <decision title>

Date: <YYYY-MM-DD>
Status: Proposed | Accepted | Deprecated | Superseded by ADR-<NNNN>

## Context

What's the problem? What constraints exist? What forced this decision (incident, scaling, regulation, vendor change)?

## Decision

What did we decide? **One sentence at the top.** Then elaborate.

## Consequences

### Positive
- <benefit>
- <benefit>

### Negative
- <cost>
- <new constraint we're now living with>

### Neutral / trade-offs
- <thing that changes but isn't strictly better or worse>

## Alternatives considered

### Option A: <name>
- Pros: ...
- Cons: ...
- Why rejected: ...

### Option B: <name>
- Pros: ...
- Cons: ...
- Why rejected: ...

## Implementation notes (optional)

Brief pointers to where this decision lives in code: paths, modules, key configs.

## Review triggers

When should we re-open this ADR?
- <metric breach>
- <vendor change>
- <regulation change>
- <scale threshold>

## See also

- ADR-<NNNN> — related / predecessor / superseded
- `ai/patterns/<pattern>.md` — pattern that implements this
- `.claude/rules/<rule>.md` — rule that enforces this
- External reference: <link>

---

**How to use this template:**
1. Copy this file to `<NNNN>-<slug>.md` (e.g., `0042-shard-by-tenant-hash.md`).
2. Use the next sequential number (don't reuse).
3. Fill in EVERY section. If a section truly doesn't apply, say so explicitly ("N/A — no alternatives were considered because regulatory mandate") rather than deleting.
4. Open as a PR for review when status = Proposed.
5. Update status to Accepted on merge.
6. NEVER edit historical ADRs. Supersede via new ADR with `Status: Superseded by ADR-XXXX` on the old one.
