---
description: Dump the workspace registry or locate a concept across sibling repos.
---

# /project-map

## The Premise (read this first)

**Map real files. No invented paths.** When asked to locate a concept across siblings, every result MUST be a path you actually read in this session — confirmed via `Read` or `Grep`, never inferred from naming convention. Recommendations require concrete grep hits.

**Mechanical halt** — refuse to emit:
- A path that wasn't returned by an actual filesystem call.
- "Likely lives at..." or "should be at..." — those are guesses, not findings.
- A "no matches" verdict without showing the search command + scope.

Read-only. Never modifies the registry.

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
