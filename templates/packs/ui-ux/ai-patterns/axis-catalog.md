---
name: axis-catalog
description: "Pattern: the 16-axis UI/UX usability catalog — detection heuristic and closure verb per axis"
kind: ai-pattern
pack: ui-ux
---

# Pattern: The 16-axis usability catalog

> **Hard rule** — This is a CLOSED vocabulary. A UI/UX finding that is not on one of these 16 axes routes OUT (see § Routing out); it never becomes a 17th axis. The counts `16 axes / 19 closure verbs` are cited verbatim by `ui-design-sweep`, `creative-director`, `/art-direct` and four mobile artifacts — extend a row, never renumber the set.

**When to apply** — whenever a finding must be *named* (which axis is this?) or *closed* (which verb ends it?): `ui-design-sweep` per verb, `/design-review` and `/ui-sweep` when classifying, `ux-reviewer` and `/redesign` when scoring an existing surface, `creative-director` and `/art-direct` when self-checking their OWN inventions against the floor.

The always-loaded rule `ui-principles.md § Axis catalog` carries the closed axis NAMES and the routing rule — the part that must be in session so no one invents a 17th axis. This file carries the DEPTH: the detection heuristic per axis and the verb that closes it. Load it at dispatch; do not restate it into a rule.

## The dual role (do not narrow either half)

1. **The closure map `ui-design-sweep` closes against.** That skill operates from a closed vocabulary of 19 verbs, each of which closes a finding on exactly ONE axis below. When a tool reports "design-token drift" or "hierarchy violation", it cites the axis NAME from this list.
2. **The pack-wide canonical usability FLOOR.** `creative-director` / `/art-direct` delegate to it and self-check their own inventions against it — never re-auditing the existing design's floor — and `redesign` / `enhance-ui` / `ux-reviewer` score existing surfaces against it.

Re-scoping this catalog to only one of those roles silently breaks the delegation the other consumers depend on. Extend it, never narrow it.

**Why 19 ≠ 16, and why that is not drift.** Some axes carry more than one verb: `tokens` has both `consolidate-tokens` and `extract-token`; `states` has `wire-empty-state` / `wire-loading-state` / `wire-error-state`. Downstream consumers cite both numbers.

## The catalog

| Axis | Heuristic | Closure verbs that operate on it |
|---|---|---|
| **tokens** | Every conceptual value (color / spacing / radius / shadow / type / motion) lives in `_extracted-idioms.md § Tokens`; literals in components are drift. | `consolidate-tokens`, `extract-token` |
| **wrappers** | A shared wrapper exists for every recurring component shape; raw HTML / library components used where a wrapper exists is drift. | `unify-component` |
| **patterns** | ≥5 instances of the same affordance pattern means the wrapper is missing and should be extracted. | `extract-pattern` |
| **hierarchy** | Exactly one primary action per screen (visually dominant); heading levels descend without skips; primary-action prominence ≥ 80 score. | `normalize-hierarchy` |
| **type-scale** | Every `font-size` matches a declared scale step (no `17.5px` when scale is `12 / 14 / 16 / 18 / 20 / 24 / 32 / 48`). | `apply-type-scale` |
| **rhythm** | Every margin / padding / gap is a multiple of the spacing-token base (typically 4 or 8 px). | `tighten-rhythm` |
| **density** | A single surface uses one density (compact / cozy / comfortable); density chosen for context (admin → compact, marketing → comfortable). | `simplify-density` |
| **states** | Every async surface renders a specific empty / loading / error state; data + spinner never simultaneous (no CLS). | `wire-empty-state`, `wire-loading-state`, `wire-error-state` |
| **contrast** | Body text ≥ 4.5:1, large text + UI components ≥ 3:1 (WCAG 2.2 AA), at every interactive state (default / hover / focus / disabled). | `lift-contrast` |
| **focus** | Every interactive element has visible `:focus-visible` ring with ≥ 3:1 contrast; never `outline: none` without replacement. | `align-focus-ring` |
| **iconography** | One canonical icon set per project (no Heroicons + Material + FontAwesome mixed). | `unify-iconography` |
| **motion** | Animation duration + easing comes from motion tokens; respects `prefers-reduced-motion`; targets `transform` / `opacity` (no layout-thrash). | `normalize-motion` |
| **tap-target** | AA floor: every pointer target ≥ 24×24 CSS px — [WCAG 2.2 SC 2.5.8 Target Size (Minimum), **Level AA**](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) — unless covered by its Spacing / Inline / Equivalent / User-Agent / Essential exception. House design target at the mobile breakpoint: 44×44 CSS px (iOS HIG 44pt) / 48dp (Material). 44×44 is [SC 2.5.5 Target Size (Enhanced)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html), Level **AAA** — never cite it as the AA floor. | `expand-tap-target` |
| **cta** | Primary CTA position is canonical per surface type (list / detail / form / modal). | `unify-cta-placement` |
| **affordance** | Action elements LOOK interactive (hover / focus / cursor); icon-only has `aria-label`; disabled buttons explain WHY. | `clarify-affordance` |
| **surface** | Each page matches the prototypical example for its surface type (list / detail / form / modal); divergent skeletons are drift. | `normalize-surface` |

## Routing out

Any UI/UX finding NOT on this catalog is either (a) an architectural concern (route to `architectural-diagnosis` — code-quality pack), (b) a code-structure concern (route to `refactoring-sweep` — code-quality pack — or `/align-recheck`, align pack), or (c) outside scope — halt and surface it. Do not invent a 17th axis.

## The companion floor (a different dimension — do NOT fold it into the 16 axes)

The catalog above is the per-ELEMENT usability floor. Whether a whole COMPOSITE surface carries its table-stakes affordances — a data-table's toolbar / search / filter / sort / bulk-select + bulk-actions / export / sticky header; a dashboard's labeled metric tiles + re-themed charts + widget hierarchy (+ a period control / activity feed / quick-actions when its job is time-bound or operational) — is a per-SURFACE **completeness** floor, owned by `ui-design-sweep.md § normalize-surface — Built-in composite-surface table-stakes` (verb 19's fallback prototype, used when a project has not authored `_extracted-idioms.md § Surfaces`).

It is NOT a 17th axis and does not change the `16 axes / 19 verbs` counts.

## Common mistakes

- **Naming a finding by its fix instead of its axis.** "Swap the hex for a token" is the verb, not the axis; the axis is `tokens`. Reports that lead with verbs cannot be counted or deduplicated across runs.
- **Filing a composite-surface gap as a `surface` axis finding.** A dashboard that is missing its period control is a COMPLETENESS gap (the companion floor), not a prototypical-skeleton divergence. Different oracle, different fix.
- **Treating a floor axis as a creative finding.** `contrast`, `states`, `tap-target`, `focus`, `hierarchy`, `type-scale` and `rhythm` are the floor. `creative-director` halts when a redline stops at one of them — it must escalate to the aesthetic verdict or route to `ux-reviewer` / `/redesign`.
- **Widening the set to fit a finding.** The route-out rule exists precisely for findings that do not fit; a 17th axis breaks every consumer that cites `16 axes / 19 verbs`.

## Cross-references

- `.claude/rules/ui-principles.md` § Axis catalog — the always-loaded closed axis NAMES + routing rule this file expands.
- `ui-design-sweep` (skill) § The 19 closure verbs — fingerprint / procedure / verify / citation per verb.
- `ux-reviewer` · `creative-director` (agents) — the two consumers that score against the floor rather than close against the verbs.
