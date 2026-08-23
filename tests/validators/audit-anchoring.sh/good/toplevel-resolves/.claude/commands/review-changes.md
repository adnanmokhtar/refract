---
description: fixture — anchor whose unbackticked top-level citation resolves on disk
---
# /review-changes

<!-- project-specific:start -->
## Project-specific (anchored)
- Architecture (`apps/tenant/app.ts:1`): layered router → service → repository flow.
- Data access: a single TypeORM DataSource is configured at app bootstrap.
- Error handling: domain errors live under the core errors module.

> Cite-able sources: `package.json`, top-level: `apps/`, `libs/`.
<!-- project-specific:end -->

Both cited top-level dirs exist here. The counterpart bad/ cases prove the extractor
that reads this line is live, so this good/ case cannot pass by the extractor being dead.
