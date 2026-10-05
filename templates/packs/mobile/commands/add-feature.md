---
description: Mobile lane preset of the delivery /add-feature — runs the cross-stack orchestrator with --lane=mobile (risk tier before code, locked acceptance contract, one writer, independent verdict). Installed as /add-feature.mobile beside the orchestrator.
allowed-tools: [Read, Grep, Glob, Skill]
---

# /add-feature.mobile <description | specs/<file> | Spec-ID> [flags]

A thin entry point (architecture proposal decision O6). A feature is built as a **run** by the one
cross-stack orchestrator, `/add-feature` (delivery pack, always installed and applied first, so it
owns the bare name). This preset only fixes the lane: it hands the ask, verbatim, to

```text
/add-feature --lane=mobile <the ask, verbatim, with every flag the user passed>
```

through the Skill tool and does nothing else. Use it when the ask is a mobile change — a screen, native capability, offline flow or push entry —
and you want the lane chosen for you; the orchestrator still picks the risk tier, and adds a lane
when the design shows the change crosses stacks.

## Where the procedure that lived here went

The mobile procedure this file used to hold was **cut, not rewritten**, into the lane skill
`.claude/skills/lane-mobile/SKILL.md` (delivery pack) — the same section names, so citations like
"§ Phase 3", "§ Phase 4 — Generate", "§ Sibling-shape halt", "§ New-dependency gate" and
"§ Spec-conformance gate" now resolve there. What did NOT move there lives once in the orchestrator:
the tier table (now `.claude/templates/governance/tiers.json`, T0–T3), the acceptance contract and
its lock (P5), the single confirmation gate (H2), the reviewer fan-out (P8–P11), the verdict (P12)
and the output block. Leaf commands of this pack (`/add-endpoint`, `/add-module`, `/add-page`,
`/add-component`, `/add-crud-page`, `/add-screen`) are unchanged.

## When the orchestrator is missing

An install made before the delivery pack existed has no `/add-feature` orchestrator and no lane
skill. Do not improvise the old procedure from memory: stop and print
`Missing: the delivery pack — run /setup-project --refresh (it installs delivery always-on).`

## Related

- `/add-feature` (delivery) — the orchestrator; `lane-mobile` — this stack's procedure.
- `.claude/rules/mobile-principles.md` — the stack rule the lane applies.
