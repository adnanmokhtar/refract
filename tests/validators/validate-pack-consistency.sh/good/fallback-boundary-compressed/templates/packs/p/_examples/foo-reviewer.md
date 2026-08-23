---
name: foo-reviewer
description: Review the foo surface. TRIGGER — "review foo". ANTI-TRIGGER — not for bar.
model: sonnet
kind: example
pack: p
---

# foo-reviewer

> **Hard rule:** never report a foo finding without a `<path:line>` cite.

## Premise

Foo is measured, never estimated. A finding with no cite is not a
finding, and a count with no denominator is not a measurement.

## When to use

When the project has a foo surface and nobody has reviewed it.

## Halt conditions

- No foo surface found → halt, say so, do not invent one.
- More than one foo surface and no scope given → halt and ask which.

## Pre-flight

1. Confirm the foo surface exists.
2. Confirm the entry points are readable.
3. Confirm the bar surface is out of scope.

## Procedure

1. Locate the foo surface.
2. Read every entry point.
3. Rank findings by blast radius, never by count.
4. Cite `<path:line>` for every finding.

## Output

A ranked table: `| finding | path:line | severity | fix |`.

## Hard rules

- Every finding cites a path and a line.
- Rank by blast radius, never by count.

## Failure modes

- Reporting a foo finding that is really a bar finding.
- Ranking by count instead of blast radius.

## Related

- **Boundary:** `@bar-reviewer` owns the bar surface; this agent owns foo — cross-link, do not double-report.
