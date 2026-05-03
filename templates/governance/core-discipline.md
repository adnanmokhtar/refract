---
artifact: core-discipline
purpose: Single pointer for clean-code + SOLID discipline — every operational command links here from Phase 3 instead of restating rules.
---

# Core discipline (clean code + SOLID)

**Why this file exists:** SOLID, clean-code tiers, and closure verbs have one authoritative home in the packs. Commands MUST NOT paste evolving rule prose inline — link here and read the targets below **before generating or refactoring code**.

## Canonical sources (read these; do not duplicate)

| Concern | Source in this repo |
|---|---|
| **`solid-violation` / `clean-code` finding classes**, tier defaults, ledger shape, **closure-verb vocabulary** (`extract-to-shared`, `split-extract`, `dedupe`, …) | [`templates/packs/align/rules/align-discipline.md`](../packs/align/rules/align-discipline.md) |
| Module boundaries, layering, extend-over-duplicate, AI change discipline | [`templates/packs/code-quality/rules/engineering-principles.md`](../packs/code-quality/rules/engineering-principles.md) |
| Micro hygiene, SRP-style caps, naming MUSTs | [`templates/packs/code-quality/rules/quality-principles.md`](../packs/code-quality/rules/quality-principles.md) |

## How commands consume this

1. **Phase 3 — Retrieve:** add a bullet **MUST read** `templates/governance/core-discipline.md` (this file) before writing code or closing alignment findings.
2. **Do not** restate SOLID acronym definitions or copy closure-verb tables — cite paths above.
3. **Orchestrator commands** (`/optimize`, `/align`, `/polish`, …) already dispatch `detect-drift` / align detectors — still link this file so the implementing agent loads the same vocabulary.

## Related snippets

- Universal Phase 3 file list: [`templates/snippets/phase-3-always-reads.md`](../snippets/phase-3-always-reads.md)
- Hand-wave grep gate: [`templates/snippets/hand-wave-grep.md`](../snippets/hand-wave-grep.md)
- Intent-gate skeleton: [`templates/snippets/intent-gate-skeleton.md`](../snippets/intent-gate-skeleton.md)
