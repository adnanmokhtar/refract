---
artifact: postcondition-check
purpose: A skill that WRITES must check that the write achieved what it claimed — preconditions are not verification.
imported-by: writing skills whose procedure ends at the write (dlq-replay, schema-consistency-audit, architectural-diagnosis, debt-ledger, assumption-ledger, changelog-generate, extract-* and any skill that produces an artifact or mutates state).
---

# Postcondition check — did the write do what it said?

**A halt condition is a precondition. A failure-modes list is a warning. Neither is verification.**

The pattern this closes was measured across the skill catalogue: skills that guard their entry
carefully — *refuse unless the fix is deployed, halt unless idempotency is verified* — and then
perform the write and stop. The same file often lists, under **Failure modes**, exactly what will
have gone wrong (*replayed before the fix → messages return to the DLQ; the cycle repeats*) and
never looks to see whether it did. **The knowledge is present and nothing checks it**, which is the
most common defect shape in this repo and the hardest to see by reading one file, because each half
looks complete on its own.

## The contract

Every skill that writes ends with a check that is:

1. **Observed, not assumed.** Re-read the file, re-query the queue depth, re-run the detector that
   produced the finding. "The command exited 0" is not an observation of the outcome.
2. **Stated as the inverse of a named failure mode.** Each entry under *Failure modes* that the
   write could have caused becomes a check. A failure mode with no matching check is a risk the
   skill documented and then accepted silently.
3. **Reported, including when it passes.** A verification whose result appears only on failure is
   indistinguishable from one that never ran — the same reason a coverage ledger prints its
   arithmetic rather than only its gaps.
4. **Honest when it cannot run.** No harness, no access, no measurable signal → `NOT RUN` with the
   reason, never an assumed pass. A tick that was not earned closes the question for everyone after.

## Shape

```
## Verify (postconditions)

- <observation> → <expected>, measured by <how>        ← the inverse of failure mode 1
- <observation> → <expected>, measured by <how>        ← the inverse of failure mode 2
- NOT RUN: <check> — <why it could not be observed here>
```

## What this is not

It is **not a test suite**, and it is not a second set of preconditions. It asks one question the
skill cannot otherwise answer: *after I wrote, is the world the way I said it would be?*

For a skill whose output is an **artifact** (a ledger, a report, an extraction), the postcondition
is usually structural and cheap: the file exists at the declared path, it is non-empty, every row
carries the fields the skill's own output contract names, and the counts inside it agree with the
population the skill resolved. An artifact that claims twelve rows and holds nine is a write that
partially failed and reported success.
