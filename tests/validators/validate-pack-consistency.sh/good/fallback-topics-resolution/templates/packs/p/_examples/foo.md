---
name: foo
description: Scan the repo for foo and report what is wrong with it. TRIGGER — "check foo", "foo audit". ANTI-TRIGGER — not for bar, that is /bar.
kind: example
pack: p
---

# foo

> **Hard rule:** never report a foo finding without a `<path:line>` cite.

## Premise

Foo is measured, never estimated. A finding with no cite is not a finding.

Foo is measured, never estimated.

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
- Ranking by count instead of blast radius.
- Treating a bar finding as a foo finding because the file path looked similar.

## Related

- `bar.md` — the sibling surface.

<!--
This fallback is an abridgement of `skills/foo/SKILL.md`. A same-named `commands/foo.md`
also exists in this pack and is what check 8a's dir-precedence walk reaches first; against
THAT file this body loses `hard rules` and `output format` and the fixture goes red. It stays
green only because 8b resolves through the `_topics.md` entry whose `fallback:` names it.
-->
