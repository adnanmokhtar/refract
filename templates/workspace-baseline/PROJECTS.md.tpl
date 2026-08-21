# {{WORKSPACE_NAME}} — Project Registry

Parent workspace containing {{MEMBER_COUNT}} member repos. Claude runs here to execute cross-repo tasks from a single session.

> **This file is the durable record of workspace detection.** Phase 1 decided `repo_shape: workspace`; Phase 4.0 § Sub-project enumeration produced the member list and wrote the table below. Without it the member list lives only for the length of one run, and the next session either re-derives it or silently falls back to treating the parent as one averaged project. Phase 4.0 also *reads* this file — an existing `PROJECTS.md` is itself a workspace signal, so a hand-written registry is honoured, not overwritten.

> **Git shape**: {{GIT_SHAPE}} — one of *parent is not a git repo; each member has its own remote* (the common sibling-directory case: separate repos parked under one folder, orchestration-only tooling here, commits land per member) or *one git repo with a workspace manifest* (members are packages; commits land once, but each member still gets its own setup because their stacks differ).

## Registered repos

| Repo | Path | Stack | Port | Role |
|---|---|---|---|---|
| `{{REPO_1}}` | `./{{REPO_1}}/` | {{STACK_1}} | {{PORT_1}} | {{ROLE_1}} |
| `{{REPO_2}}` | `./{{REPO_2}}/` | {{STACK_2}} | {{PORT_2}} | {{ROLE_2}} |

**Role** is what makes this table load-bearing rather than decorative: mark each member `producer` (serves an API / publishes a shared package), `consumer` (calls one), `both`, or `standalone`. `/sync-contract` reads these roles to decide which repos to search — a member with no role recorded gets searched anyway, but a member missing from the table entirely is invisible to every cross-repo command here.

**Stack** is detected per member, never inherited from a sibling. Two members in one workspace routinely disagree about file naming, test layout, and error handling; each member's own `.claude/` + `ai/` holds its conventions, and this row is only the one-line summary.

## Relationships

{{RELATIONSHIPS_DESCRIPTION}}

Record the actual seams, not the inferred ones: which member calls which, at what base path, and how the consumer gets its types (generated from a spec / shared package / hand-written). Directory naming is a hint, not evidence — a folder called `api` may be a client. Cite the file that proves the call.

## Entry points (workspace-level slash commands)

- `/cross-repo-task` — orchestrate a feature touching multiple repos; contract-first, dependency-ordered.
- `/sync-contract` — after a producer contract change, derive the diff, classify it, and find every consumer.
- `/project-map` — dump this registry or locate a concept across members.

## Commits

Each member has its own git remote (or, in the single-repo variant, its own review boundary). Don't try to commit across repos in one step. Claude edits files; you commit each repo separately after reviewing its diff.

## Dispatching hook

Workspace `.claude/hooks/dispatch-hook.sh` runs on every Edit/Write/MultiEdit:
1. Detects which member owns the edited file (longest path match against the Path column)
2. Invokes that repo's `.claude/hooks/post-edit-check.sh`
3. Silently passes for files outside the registered repos

A member absent from the table above therefore gets **no** post-edit checks. Keeping this table current is not bookkeeping — it is what makes the hook work.
