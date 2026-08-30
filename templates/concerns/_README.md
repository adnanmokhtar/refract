# `templates/concerns/` — cross-cutting concern detectors

Phase 4 of [`docs/plans/audit-review-matrix.md`](../../docs/plans/audit-review-matrix.md).

## Why this directory exists

The review model has three dimensions ([`_review-model.md`](../_review-model.md) §1) and, until
this directory, only two of them had a home on disk:

| Dimension | Lives in |
|---|---|
| Surface | `templates/domains/<key>/` — one folder per technical signal |
| Axis | `templates/packs/<pack>/` — the packs are axis-major |
| **Concern** | **nowhere** |

That absence is not cosmetic — it is the mechanical cause of the gap the matrix measured. A
concern with no home cannot ship a detector, so `Data Lifecycle × <anything>` was empty on 13 of
35 surfaces not because nobody cared, but because there was no file to put it in.

## The contract

One file per concern. Each ships:

1. **A hard rule** — one paragraph, the thing that must be true everywhere.
2. **Per-surface fingerprints** — a table, one row per surface where the concern bites, naming the
   concrete shape to look for. This is the same design the 13 scale-lens detectors already use in
   [`commands/audit.md`](../../commands/audit.md): the detector's *logic* is universal, the
   *fingerprint* adapts. A surface with no meaningful fingerprint is marked N/A **with a reason**,
   never omitted.
3. **Closure verbs** — what a fix looks like, so a finding has an execution path.

Surface names are literal keys from [`domains/_registry.md`](../domains/_registry.md) or the four
structural surfaces. `scripts/validate-review-model.sh` and the matrix generator both read them;
a coined name resolves to nothing and its row is never dispatched.

## Priority order — evidence, not guesswork

Built in descending `severity × empty-surface-count`, computed from the matrix. The plan named
four "highest-value candidates" before the matrix existed; when it was built, **three of the four
turned out to be already covered** — which is exactly why Phase 4 was made to depend on Phase 3.
