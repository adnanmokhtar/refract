---
type: regex
pattern: '(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:refund))(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:minor.?units?|amountMinor|integer))(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:ledger|recordEntry|entry))'
flags: i
target: last_message
weight: 1
---

Key row FR-TRAP-01 / refund-amount.holdout.test.js (benchmarks/fixtures/feature-refund/DEFECTS.md): the requirements state it, every part inside one 800-char window.
