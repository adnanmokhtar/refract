---
type: regex
pattern: '(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:emptyState|empty.?state))(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:refunds?\b))'
flags: i
target: last_message
weight: 1
---

Key row FR-TRAP-04 / refund-page.holdout.test.js (benchmarks/fixtures/feature-refund/DEFECTS.md): the requirements state it, every part inside one 800-char window.
