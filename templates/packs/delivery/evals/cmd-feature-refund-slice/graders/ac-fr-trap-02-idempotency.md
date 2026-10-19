---
type: regex
pattern: '(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:withIdempotency|Idempotency-Key))(?=(?:(?!\n[ \t]*\n)[\s\S]){0,800}?(?:replay|same (?:key|response)|first response|once|twice|duplicate))'
flags: i
target: last_message
weight: 1
---

Key row FR-TRAP-02 / refund-idempotency.holdout.test.js (benchmarks/fixtures/feature-refund/DEFECTS.md): the requirements state it, every part inside one 800-char window.
