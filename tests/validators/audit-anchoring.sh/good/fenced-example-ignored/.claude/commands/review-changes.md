---
description: fixture — real anchor + a fenced documentation example anchor
---
# /review-changes

<!-- project-specific:start -->
## Project-specific (anchored)
- Architecture (`src/app.ts:10`): layered router → service → repository flow.
- Data access: a single TypeORM DataSource is configured at app bootstrap.
- Error handling: domain errors live under the core errors module.
<!-- project-specific:end -->

The block below is DOCUMENTATION — it shows what an anchor looks like. It is
inside a code fence, so the auditor must NOT treat it as a live anchor (else its
placeholders surface as a false skeleton finding). This is the regression the
`extract_anchor_block` fence-skip guards against.

```markdown
<!-- project-specific:start -->
- Architecture (`<src/path>`): <one-liner>
<!-- project-specific:end -->
```
