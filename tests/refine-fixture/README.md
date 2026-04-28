# tests/refine-fixture

Synthetic mini-project + static checks used by `scripts/test-refine-fixture.sh`.

## Why this exists

`/setup-project --refine` is an LLM-driven workflow — it can't be invoked from a shell script. But many of its safety guarantees are mechanical: marker integrity, hash-check rollback, three-way plateau verdict, presence of every backing skill, consistency across spec/skill/pattern/cheatsheet/README.

This fixture exercises the **mechanical** parts of REFINE that don't need Claude:

1. **Marker-safety simulation** (`marker_safety.py`) — re-implements the core write contract from `apply-pack-adaptation`'s "Marker safety contract" section. Demonstrates that:
   - A clean rewrite preserves bytes-outside-markers (hashes match).
   - A rewrite that escapes markers FAILS the post-write check (hashes mismatch → rollback).
   - A file with missing markers raises `markers-missing` and never writes.

2. **Static structure checks** (`scripts/test-refine-fixture.sh`) — every REFINE artifact referenced in the spec exists; the marker token strings are byte-stable across all references; the plateau classifier vocabulary is consistent.

The fixture's `before/` directory holds a tiny synthetic project (3 rule files + 1 ai/ file + a sample `_refine-extract.md`) so the marker-safety script has real bytes to work with.

## Layout

```
tests/refine-fixture/
├── README.md                    (this file)
├── marker_safety.py             (executable Python; the REFINE write contract)
└── before/                      (synthetic project — input)
    ├── .claude/
    │   ├── _refine-extract.md   (sample deep-extraction substrate)
    │   └── rules/
    │       ├── database.md      (SHALLOW round-one anchor, has markers — should be ANCHOR-DEEP)
    │       ├── security.md      (DEEP round-one anchor, has markers — should be LEAVE-DEEP-IDEMPOTENT)
    │       └── legacy.md        (NO markers — should report MARKERS-MISSING and skip)
    └── ai/
        └── architecture.md      (has refine-enriched markers)
```

## Usage

```bash
scripts/test-refine-fixture.sh
```

Exit `0` = clean, `1` = drift / contract violation.
