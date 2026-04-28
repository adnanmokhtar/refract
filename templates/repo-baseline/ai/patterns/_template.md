---
name: _template
description: Pattern: <Pattern Name>
kind: ai-pattern
---

# Pattern: <Pattern Name>

<one-paragraph: what + when + what problem it solves>

## Context

When to reach for this pattern — the signals, the scale, the trade-offs that make this the right approach.

## Problem

What's wrong without this pattern — concrete failure modes that show up in real code.

## Solution / structure

How the pattern works — diagram (ASCII or mermaid) + key components + invariants.

```
<diagram>
```

## Worked example

Real, near-runnable code. Not pseudocode. Not stubs. Match the project's stack + style.

```ts
// Full working example
```

## Variants

If there are 2-4 ways the pattern bends to different constraints, document each briefly.

## Trade-offs

### Pros
- ...

### Cons
- ...

### When NOT to use
- <case 1>
- <case 2>

Every pattern has misuses; document them.

## Common mistakes

Specific wrong implementations + how to recognize them in code review:

- <mistake>: <why wrong> → <fix>
- <mistake>: <why wrong> → <fix>

## Testing

How to test code that uses this pattern. What invariants the tests enforce.

## Operational concerns (optional)

How the pattern behaves under load / failure / rollout.

## Migration path (if retrofitting existing code)

How to adopt incrementally rather than big-bang.

## References

- ADR-<NNNN> if this pattern was decided as a formal ADR
- Related patterns: <links>
- Canonical sources: Fowler / Microservices.io / OWASP / etc.

---

**How to use this template:**
1. Copy this file to `<pattern-name>.md` in `ai/patterns/`.
2. Patterns describe HOW; rules in `.claude/rules/` describe WHAT/MUST.
3. Worked example is the highest-value section — invest there.
4. "When NOT to use" prevents the pattern from being applied indiscriminately.
5. Promote candidates from `ai/dynamic/learned-patterns.md` via `/promote-pattern`.
