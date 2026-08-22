---
description: fixture — the marker appears ONLY as fenced documentation; no live anchor
---
# /review-changes

This file TEACHES the marker convention, so it shows the markers inside a fence.
A fenced marker is documentation, not an anchor this artifact carries — so the
auditor must report `anchor-documented-not-applied` (not `anchor-too-thin`), and
`--strict` must exit 1. `scripts/apply-anchors.sh § has_live_anchor` uses the same
fence-aware test, so re-running the injector DOES resolve this finding — which is
what makes the audit's printed remediation honest.

Regression pinned: while the injector matched a bare `^<!-- project-specific:start -->$`
and the auditor skipped fenced regions, this shape deadlocked — skipped as "already
anchored" by the injector, failed as an empty block by the auditor, forever.

```markdown
<!-- project-specific:start -->
## Project-specific (anchored)
- Architecture (`src/app.ts:1`): layered router → service → repository flow.
- Data access: a single DataSource is configured at app bootstrap.
- Error handling: domain errors live under the core errors module.
<!-- project-specific:end -->
```
