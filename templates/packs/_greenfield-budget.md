# Greenfield exposure budget

Two per-pack counts that may not **grow**. They exist because the two shapes below are real harm
that no per-file rule can call wrong on its own — the right *level* of either is a judgement no
repo-wide threshold carries — while "more than the last time anyone looked" is exact, unarguable,
and cannot be moved by padding.

This is the same mechanism `scripts/check-rule-budget.sh` runs against
`scripts/_rule-budget-baseline.txt`, and it is deliberately **not** the reasoned-ledger mechanism
of `_fallback-baseline.md` / `_topics-strategy-baseline.md`. Those two ledgers hold defects a human
read and **blessed**, so a reason is mandatory there. Nothing in this file is blessed. Every count
here is a measurement of exposure that exists today; a boilerplate reason on each of the 51
non-agent boundary losses would be exactly the enforcement theatre those ledgers avoid.

- **Regenerate:** `bash scripts/validate-pack-consistency.sh --record-budget`
- **A pack may not GROW either count.** Shrinking is always allowed and WARNs until re-recorded,
  so a repair ratchets the number down permanently.
- **A pack with no row here is budget 0.** So is a missing section, and so is a deleted file:
  removing this budget turns every existing instance RED instead of turning the check off. It is
  fail-safe, not fail-silent — verified by deleting it and observing the gate exit 1.
- **The ceiling, stated:** both counts are per PACK, so repairing one instance and regressing
  another *inside the same pack* nets to zero and stays green. `check-rule-budget.sh` accepts the
  same ceiling. A per-file ratchet was rejected here because it needs a reason per line to be
  honest, and 51 unread reasons protect nothing.

## Zero-delivery topics

Topics whose `fallback:` is the literal `stub-from-sections` — whatever else they declare, a
no-signal project receives headings and no content for them (`phase-4.2-apply.md:26`). Check 3b
gates the two shapes that are decidable per topic (`STUB-NO-SECTIONS`, `STUB-OVER-SOURCE`); this
count is what closes the third — a sentinel with a `sections:` list and no artifact of that name
anywhere, which fires neither rule and is how a pack could quietly go to zero delivery with every
gate green.

```
backend                  9
infrastructure           5
```

## Boundary-loss outside agents

`_examples/` fallbacks whose SOURCE carries a sibling / cross-pack ownership block and which carry
none — counted for the `commands` / `skills` / `ai-patterns` / `rules` classes, where check 8b
reports rather than FAILs. In the `agents` class the same rule is a hard FAIL and this file has no
say: 77 of 77 agent sources carry the block, so the convention is universal there and the gate can
demand it. Outside agents it is not universal (commands 36 of 44, ai-patterns 33 of 81, skills 30
of 64, rules 1 of 16), so demanding it would legislate a convention rather than protect one — but
the loss is real for every project that receives one of these files, so the exposure is counted and
may not grow.

```
ai-engineering           8
backend                  8
business                 4
code-quality             3
database                 3
devops                   2
documentation            2
frontend                 15
observability            1
performance              1
security                 1
testing                  3
```
