---
name: do-foo
description: Build a foo end to end.
kind: example
pack: p
---

# /do-foo

> **Hard rule:** never stamp done on an unmeasured foo.

## Premise

A foo that is not measured is not finished.

## When to use

When a new foo has to be built.

## Halt conditions

- No foo spec → halt.

## Procedure

1. Build the foo.
2. Measure it.

## Ship gate — production-grade or INCOMPLETE (the closing verdict)

The run is not done until every floor row is MET with cited evidence.

## Output

```
✅ foo built: <name>

Review verdict: APPROVE / REQUEST_CHANGES / BLOCK

Status: COMPLETE
```

## Failure modes

- Stamping done on an unmeasured foo.
