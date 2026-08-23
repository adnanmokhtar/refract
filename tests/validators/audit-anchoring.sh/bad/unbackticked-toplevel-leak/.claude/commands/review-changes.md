---
description: fixture — anchor whose UNBACKTICKED top-level citation names a dir this repo does not have
---
# /review-changes

<!-- project-specific:start -->
## Project-specific (anchored)
- Architecture (`apps/tenant/app.ts:1`): layered router → service → repository flow.
- Data access: a single TypeORM DataSource is configured at app bootstrap.
- Error handling: domain errors live under the core errors module.

> Cite-able sources: `package.json`, top-level: src/.
<!-- project-specific:end -->

This repo roots its code at `apps/`, not `src/`. The `src/` token above is the ONE
path apply-anchors.sh emits WITHOUT backticks, and the leak extractor used to read
backticked tokens only — so a fabricated top-level directory passed the gate. A live
run shipped this exact string into 225 artifacts and the audit reported "0 leaks".
