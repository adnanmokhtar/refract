---
type: regex
pattern: '(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:pending|unpaid|not (?:yet )?paid))(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:\b409\b|refus|reject|conflict|cannot|not allowed))'
flags: i
target: last_message
weight: 1
---

Key row control: refund-refused-unpaid.holdout.test.js (benchmarks/fixtures/feature-refund/DEFECTS.md): the requirements state it, every part inside one 800-char window.
