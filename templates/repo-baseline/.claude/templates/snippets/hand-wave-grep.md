---
purpose: Canonical mechanical halt — grep draft output for vague tokens; cite or delete. Used by audit-style commands.
---

# Mechanical halt — hand-wave grep

**Before emitting findings or a final report**, the agent MUST run:

1. Grep the draft for hand-wave tokens: `potentially`, `might`, `may`, `consider`, `could be`, `seems`, `appears to`, `possibly`, `unclear`, `unsure`, `TBD`, `etc.`, `and so on` (extend per command if listed in its mechanical halt).
2. For each hit: either anchor it (`<path:line>`, `<table.column>`, schema proof) or delete the line.
3. Re-grep. If any hand-wave token survives without an anchor on the same line → **HALT**.
4. Optional domain-specific check: `findings_emitted == findings_with_anchors` (or equivalent) — if unequal → **HALT**.

If hand-waves persist after one rewrite cycle → halt and ask whether to drop unanchored lines or gather more evidence.

Commands that use this block SHOULD link here instead of pasting these four steps verbatim.
