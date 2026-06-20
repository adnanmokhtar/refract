---
description: fixture — a real (non-fenced) anchor left in template skeleton state
---
# /review-changes

<!-- project-specific:start -->
## Project-specific (anchored)
- Architecture (`<src/path>`): <one-liner>
- Naming (`<src/path>`): <one-liner>
- Data access (`<src/path>`): <one-liner>
<!-- project-specific:end -->

This anchor is NOT fenced — it is a genuine but unpopulated skeleton. The auditor
MUST still flag it (`--strict` → exit 1). Proves the fence-skip patch did not
blind the placeholder check.
