---
name: legacy-rule
description: Legacy rule with NO markers — should produce MARKERS-MISSING in REFINE.
---

# Legacy rule

This rule was authored before the marker contract existed. There is no
`<!-- project-specific:start -->` block anywhere in this file.

REFINE Phase 4.6-DEEP must skip this artifact and emit a `MARKERS-MISSING`
row in the decision log.

## Project-specific notes

- `LegacyService` at `src/legacy/service.py`
- Path conventions: under `src/legacy/`

(No markers around this section — that's the point of this fixture file.)
