---
name: analyze-module
description: fixture — one global anchor block stamped onto every artifact
---
# /analyze-module

<!-- project-specific:start -->
## Project-specific (anchored)
> - **Architecture** (`src/app.ts:1`): layered router → service → repository flow.
> - **Data access** (`src/app.ts:1`): a single DataSource is configured at bootstrap.
> - **Error handling** (`src/app.ts:1`): domain errors route through the shared handler.
> Cite-able sources: `package.json`, top-level: `src/`.
<!-- project-specific:end -->

Every one of these ten commands carries the byte-identical block above. Coverage reads
100% and every citation resolves — yet the anchor says nothing about THIS artifact.
Measured on a live repo: 255 anchored files, 6 distinct bodies, 137 in one group.
