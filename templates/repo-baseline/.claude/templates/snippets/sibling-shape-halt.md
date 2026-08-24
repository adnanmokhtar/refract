---
purpose: Canonical sibling-shape halt VERDICT vocabulary shared by every `/add-feature` variant. Each pack keeps its own stack-specific halt CRITERIA inline and links here for the verdict enum so the three variants stop speaking three dialects.
imported-by: templates/packs/{backend,frontend,mobile}/commands/add-feature.md (and any future add-* command with a sibling-mirror gate).
---

# Sibling-shape halt — canonical verdict vocabulary

Before declaring success / before merge, compare the new file(s) against **≥2 sibling files** in the same module. The per-stack *criteria* (which imports / primitives / paths / naming count as drift) live in each command; the **verdict enum below is shared and fixed** so the gate reads identically across backend, frontend, and mobile.

## Per-file verdict (use these three words, nothing else)

| Verdict | Meaning | Action |
|---|---|---|
| `aligned` | Matches ≥2 siblings on every axis the command checks. | Pass. Ship. |
| `drifted` | One or more axes diverge from siblings. | **HALT before merge.** Re-shape to match siblings (default), OR — if the deviation is intentional and load-bearing — write an ADR and promote the row to heavy tier. Drift without an ADR is forbidden. |
| `no-siblings` | First feature of its kind in the module; no sibling to mirror. | **Escalate to the user** to get the new shape blessed before it becomes the template others mirror. |

## Per-gap parity rule

Each axis the command lists (imports, error/DI primitive, path shape, naming, tests, i18n, a11y, platform parity, …) is evaluated independently. A single diverging axis is enough for `drifted` — there is no "mostly aligned" pass. Map any stack-specific blocker output (e.g. mobile's `BLOCKER:<axis>`, a frontend `regressed` check) onto `drifted` so the merge gate is one decision, not three vocabularies.

## Why this is shared

The mechanical gate is identical across stacks — only the drift axes differ. Three different verdict words (`closed/still-open/regressed`, `BLOCKER-with-axis`, `aligned/drifted/no-siblings`) for the same gate made the suite read as three unrelated commands. One enum, stack-specific criteria.
