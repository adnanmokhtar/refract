# Money

Promoted from the learnings sink on 2026-08-20.

- Amounts are integer minor units in `bigint` columns; never floating point.
- Arithmetic goes through the `Money` value object; currencies never mix in one sum.
- Rendering uses `Money` and the request locale.
