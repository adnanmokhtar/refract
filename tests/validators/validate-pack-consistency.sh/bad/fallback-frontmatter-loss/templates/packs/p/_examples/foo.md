---
name: foo
kind: example
pack: p
---

# foo

> **Hard rule:** never report a foo finding without a `<path:line>` cite.

## Premise

Foo is measured, never estimated. A finding with no cite is not a finding.

Foo is measured, never estimated. The `description:` the harness dispatches this skill on
is gone, so the copied skill is undiscoverable in the project that receives it.

## When to use

When the project has a foo surface and nobody has audited it.

## Halt conditions

- No foo surface found → halt, say so, do not invent one.

## Procedure

1. Locate the foo surface.
2. Read every entry point.

## Output

A ranked table: `| finding | path:line | severity | fix |`.

## Failure modes

- Reporting a foo finding that is really a bar finding.
