---
name: diagram-sync
description: Generate / refresh architecture diagrams (C4 · mermaid) from the REAL module + import graph, embed them in docs, and flag drift when a committed diagram no longer matches the code. A hand-drawn diagram left to rot is worse than none.
---

# diagram-sync

An architecture diagram is a *rendering of the real module/import graph*, re-verified against it — never hand-drawn and left to rot. A diagram that contradicts the code teaches a wrong mental model with the authority of a picture.

## Premise

Cite-or-halt. Every node/edge traces to a `<path>` (a module dir) or `<path:line>` (the import / call that makes the edge). Every DRIFT finding cites the diagram element + the graph fact that contradicts it — "box `PaymentGateway`, no module resolves to it (deleted in `git log --diff-filter=D`)". "The diagram looks stale" is a vibe.

**Boundary — this skill does NOT build the graph.** `code-quality`'s `architectural-diagnosis` emits `ai/optimize/_dep-graph.json` + `_responsibility-map.md`; diagram-sync consumes and renders them. Never re-walk the source into a parallel, drifting graph.

**No graph is not the same as no work.** Without `_dep-graph.json` you cannot RENDER, but you can still resolve each box's `<path>` against the filesystem — an existence check, not a graph rebuild — and report `DIAGRAM-DRIFT (stale node)` for every box naming a module that is gone. Do that half, then mark missing-nodes, edge accuracy and level correctness `UNVERIFIED (no _dep-graph.json — run architectural-diagnosis)`. Halting with nothing while a dead box sits in the picture is a worse answer than a partial one that says which half it did.

## When to run

- After a refactor that adds / removes / renames / re-wires a module or service.
- Before a release / design review; weekly in CI to catch slow drift.
- Module / service / container altitude only — not per-function structure.

## Procedure (abridged)

1. Load the graph — don't rebuild it; pin its commit (behind HEAD → that staleness is the finding).
2. Pick the C4 level (Context / Container / Component); one diagram = one level.
3. Project the graph to that level; label edges with the real relationship (import, HTTP, event, DB read).
4. Render mermaid / C4 between stable markers so re-runs replace in place, not append.
5. DRIFT check both directions: stale node, missing node, level-mismatch.

## Output (abridged)

```
diagram-sync — ai/architecture.md § High-level architecture (Container)
Graph: _dep-graph.json @ 4f2a9c1  ·  11 modules, 18 edges  ·  drift: 3

STALE NODE:   architecture.md:40 box `PaymentGateway` — deleted a1b2c3d → remove node + 2 edges.
MISSING NODE: graph has notifications/ (orders→, billing→) absent from diagram → add.
LEVEL-MISMATCH: titled "System Context" but shows 6 internal modules → split to Container.
```

## Halt conditions

- Refuse to RENDER without a current `_dep-graph.json` — request an architectural-diagnosis run. (The stale-node existence check above needs no graph; do it and label the rest UNVERIFIED.)
- Refuse a DRIFT claim without the paired citation (diagram element + contradicting graph fact).
- Never hand-draw a box with no module and no external-system label; never edit source to match a picture.

## Related

- `doc-drift-scan.md` — sibling skill: it catches drift in *text* claims (a doc naming a dead symbol); diagram-sync catches drift in the *picture* (a box naming a dead module). Same failure family, visual surface.
- `code-quality` `architectural-diagnosis` (cross-pack) — the graph source; it graphs, this draws. Neither rebuilds the other's artifact.
