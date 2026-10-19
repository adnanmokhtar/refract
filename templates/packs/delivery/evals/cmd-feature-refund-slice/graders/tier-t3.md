---
type: regex
pattern: '(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:\bT3\b|\btier[ -]?3\b))'
flags: i
target: last_message
weight: 1
---

Key row Proving gate: predicted T3 before code (benchmarks/fixtures/feature-refund/DEFECTS.md): the requirements state it, every part inside one 800-char window.
