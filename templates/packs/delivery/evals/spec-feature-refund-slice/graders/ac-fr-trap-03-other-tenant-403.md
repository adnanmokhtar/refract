---
type: regex
pattern: '(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:\b403\b|forbidden))(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:(?:another|other|different|foreign) (?:tenant|merchant)|requireOwnOrder))'
flags: i
target: last_message
weight: 1
---

Key row FR-TRAP-03 / refund-tenant.holdout.test.js (+ the negative criterion) (benchmarks/fixtures/feature-refund/DEFECTS.md): the requirements state it, every part inside one 800-char window.
