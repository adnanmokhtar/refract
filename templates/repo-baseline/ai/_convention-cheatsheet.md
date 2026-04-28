# Convention cheat sheet

Top ~20 rules in one screen. Auto-derived from `ai/conventions.md` (which is itself auto-populated from `.claude/_extracted-codebase.md`). Loaded by code-edit tasks instead of the full conventions file (saves tokens).

> **All values below are placeholders.** This file is filled at setup time from this codebase's actual extraction. Never copy concrete class names, library names, or rule bodies from another project's `_convention-cheatsheet.md` into this one — derive from extraction.

Last updated: <YYYY-MM-DD by knowledge-curator>

---

## File naming

1. Source files: <detected case + extension>
2. Test files: <detected pattern + colocation>
3. Migrations: <detected pattern, or n/a if no DB>

## Class / identifier naming

4. Classes: <detected case>
5. Properties / functions: <detected case>
6. DB columns: <detected case, or n/a>
7. Constants: <detected case>
8. DI tokens: <detected style — Symbol / string constants / framework-native / none>

## Suffix matrix (only fill rows the codebase actually uses)

| Concept | Suffix in this codebase |
|---|---|
| <e.g., Service / Handler / UseCase / Resolver — use this codebase's vocabulary> | <detected suffix> |
| <e.g., Controller / Router / View / Endpoint> | <detected suffix> |
| <e.g., Repository / DAO / Query / Mapper> | <detected suffix> |
| <e.g., DTO / Schema / Form / Serializer> | <detected suffix + create/update prefix if any> |
| <e.g., Entity / Model / Record> | <detected suffix> |
| ... | (omit rows the codebase doesn't use; never invent) |

## Base classes / inheritance patterns (only if the project uses inheritance bases — OMIT this section for functional / module-style codebases)

9. `<DetectedBase>` at `<detected/path>` — <N> extenders
10. `<DetectedBase>` at `<detected/path>` — <N> extenders
11. `<DetectedBase>` at `<detected/path>` — <N> extenders

## MUST (top invariants — derived from this project's extraction + always-on rules)

12. <MUST rule 1 — derived from extraction>
13. <MUST rule 2>
14. <MUST rule 3>
15. <MUST rule 4>
16. <MUST rule 5>

## MUST NOT (top anti-patterns — from this project's extraction + always-on)

17. No `<broad-type from extraction — e.g. any / interface{} / dict>`
18. No `<noisy-debug primitive from extraction — e.g. console.log / print>` — use `<detected logger>`
19. <MUST NOT rule 3>
20. <MUST NOT rule 4>
21. <MUST NOT rule 5>

## Code style (from manifest + formatter config)

- Quotes: <detected>
- Indent: <detected>
- Line width: <detected>
- Semicolons / line endings / etc.: <detected>

---

**Full conventions**: `ai/conventions.md` (load when this cheat sheet isn't enough).

**This file is auto-maintained.** Don't hand-edit — regenerated from `conventions.md` by `knowledge-curator`.
