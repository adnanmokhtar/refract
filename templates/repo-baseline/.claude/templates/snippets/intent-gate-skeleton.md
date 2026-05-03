---
purpose: Universal intent-routing table shape — extend per command; do not copy universal rows into each file verbatim.
---

# Intent gate (skeleton)

Parse the user's words **before** heavy work. Extend this table in your command with command-specific rows.

## Universal routing (reference only — duplicate rows in your command only if you need offline readability; prefer linking here)

| User intent keywords | Typical route | Action |
|---|---|---|
| "add" / "new" / "create" / "build" / "implement" (new capability) | `/add-feature` or pack-specific add command | Halt; route |
| "fix" + ("bug" / "broken" / "wrong" / "crash") | `/fix-bug` | Halt; route |
| "audit" / "review" / read-only | Audit or review command | Halt; route |
| "enhance" / "improve" / "polish" / "better look" (existing UI) | `/enhance-ui` or `/polish` | Proceed or route |

If ambiguous: **one consolidated question**, then route.

Your command file should add rows **below** these (e.g. migrate vs align vs optimize). Commands link here instead of duplicating the universal rows — use a path relative to your command file (e.g. `../../../templates/snippets/intent-gate-skeleton.md` from `templates/packs/*/commands/`).
