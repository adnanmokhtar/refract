---
description: fixture — anchor whose top-level clause is the generator's own <placeholder>
---
# /review-changes

<!-- project-specific:start -->
## Project-specific (anchored)
- Architecture (`apps/tenant/app.ts:1`): layered router → service → repository flow.
- Data access: a single TypeORM DataSource is configured at app bootstrap.
- Error handling: domain errors live under the core errors module.

> Cite-able sources: `package.json`, top-level: <none — no top-level source dir resolved on disk>.
<!-- project-specific:end -->

apply-anchors.sh emits this form when nothing resolved. It is a Cite-able-sources line
that cites no source. PLACEHOLDER_RE lists pack-template tokens only, so the generator's
OWN placeholder was invisible to every gate; 27 artifacts shipped carrying it.
