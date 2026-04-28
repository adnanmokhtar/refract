---
description: Dump the workspace registry or locate a concept across sibling repos.
---

# /project-map

## Usage

```
/project-map                       # dumps PROJECTS.md registry
/project-map "<concept>"           # locates the concept across all siblings
```

## Flow (no arg)

Print `PROJECTS.md` content — the registry of siblings, stacks, ports, purposes.

## Flow (with concept)

1. Read `PROJECTS.md` to know every sibling path.
2. Grep for the concept across all siblings in parallel.
3. For each hit, show: repo / file / line / short context.
4. Recommend which repos would need changes if the concept is modified.
