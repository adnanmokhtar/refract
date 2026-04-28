# {{WORKSPACE_NAME}} — Project Registry

Parent workspace containing N sibling repos. Claude runs here to execute cross-repo tasks from a single session.

> **Not a git repo.** This workspace-level `.claude/` is orchestration tooling, not team config.

## Registered repos

| Repo | Path | Stack | Port | Role |
|---|---|---|---|---|
| `{{REPO_1}}` | `./{{REPO_1}}/` | {{STACK_1}} | {{PORT_1}} | {{ROLE_1}} |
| `{{REPO_2}}` | `./{{REPO_2}}/` | {{STACK_2}} | {{PORT_2}} | {{ROLE_2}} |

## Relationships

{{RELATIONSHIPS_DESCRIPTION}}

## Entry points (workspace-level slash commands)

- `/cross-repo-task` — orchestrate a feature touching multiple repos
- `/sync-contract` — after API change, find frontend consumers
- `/project-map` — dump registry or locate a concept across repos

## Commits

Each sibling has its own git remote. Don't try to commit across repos in one step. Claude edits files; you commit each repo separately after reviewing its diff.

## Dispatching hook

Workspace `.claude/hooks/dispatch-hook.sh` runs on every Edit/Write/MultiEdit:
1. Detects which sibling owns the edited file (longest path match)
2. Invokes that repo's `.claude/hooks/post-edit-check.sh`
3. Silently passes for files outside the registered repos
