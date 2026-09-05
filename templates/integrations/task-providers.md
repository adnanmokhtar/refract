---
artifact: task-providers
purpose: Canonical task-source abstraction. Defines the provider-neutral TaskSpec + one thin adapter per provider (field map + status verbs + ref detection). Consumed by the /task command.
imported-by: commands/task.md (Phase 1 resolve + Phase 5 write-back). Adding a provider = add an adapter block here + a detect-mcp.sh registry entry. The command never changes.
---

# Task providers — one command, swappable backends

`/task` is provider-agnostic. It resolves a task reference, fetches the underlying
card/issue via **whichever provider MCP is configured in this repo**, normalizes it
to the canonical **TaskSpec** below, executes the work (via `/do`), then writes status
back. Every provider plugs in through a thin adapter — the command itself is identical
across Trello / Jira / Linear / GitHub.

> **Per-repo.** Each repo declares its provider + creds in its own `.env` (see
> `scripts/detect-mcp.sh`). A repo can use a different provider than the next. The
> provider is inferred from the reference's URL host, an explicit `provider:` prefix,
> or — for bare refs / `next` — the single task-provider MCP present in `.mcp.json`.

---

## Canonical TaskSpec (provider-neutral)

Every adapter MUST map its source object onto exactly this shape. Downstream phases
read ONLY this — never raw provider fields.

```yaml
TaskSpec:
  provider:   trello | jira | linear | github   # which adapter produced this
  id:         <stable internal id>               # for API calls
  key:        <human ref>                        # PROJ-123 / card shortLink / #42
  url:        <permalink>                         # for the write-back comment
  title:      <string>
  description: <markdown>                         # body, ADF/HTML converted to md
  acceptanceCriteria: [<string>, ...]            # parsed (see "AC parsing" below)
  subtasks:   [{ text: <string>, done: <bool> }] # checklist / sub-issues / task-list
  attachments: [{ name, url, mime, localPath }]  # downloaded in Phase 3
  labels:     [<string>, ...]
  priority:   <string|null>
  assignee:   <string|null>
  status:     <current provider status name>
  statusFlow: { start, review, done }            # provider status names to transition to
```

### AC parsing (uniform across providers)
Acceptance criteria are extracted, in priority order, from:
1. A dedicated AC field (Jira custom field / explicit "Acceptance Criteria" heading).
2. A markdown section headed `## Acceptance Criteria` / `AC:` / `Definition of Done`.
3. The checklist / task-list items, if no AC section exists (each item = one criterion).
If none found → `acceptanceCriteria: []` and Phase 6 falls back to "title intent satisfied".

---

## Adapters

Each adapter declares four things: **ref detection**, **fetch**, **field map**,
**status verbs**. Tool names are the provider MCP's tools — discover the exact names
at runtime via ToolSearch; the names below are the expected shape.

### trello — `@delorenj/mcp-server-trello`
- **ref**: `trello.com/c/<shortLink>` URL · `trello:<id>` · bare card id · `next` (top card of the "To Do"/leftmost list on `TRELLO_BOARD_ID`).
- **fetch**: `get_card` / `get_card_by_id`; `get_checklists`; card `attachments`; `get_lists` (to resolve status-flow list ids).
- **field map**: `name`→title · `desc`→description · checklist items→subtasks · `attachments[]`→attachments · `labels[].name`→labels · list name of `idList`→status.
- **status verbs**: move card via `update_card { idList }` — `start`=In Progress, `review`=Review/QA, `done`=Done; `add_comment_to_card` for the write-back; tick checklist item via `update_checkitem` as each subtask completes.

### jira — `@aashari/mcp-server-atlassian-jira`
- **ref**: `.../browse/PROJ-123` URL · `PROJ-123` · `jira:PROJ-123` · `next` (top of JQL `assignee = currentUser() AND statusCategory != Done ORDER BY priority DESC`).
- **fetch**: `get_issue` (expand subtasks, attachments, comments).
- **field map**: `summary`→title · `description` (ADF→markdown)→description · `subtasks[]`→subtasks · `attachment[]`→attachments · `labels[]`→labels · `priority.name`→priority · `assignee.displayName`→assignee · `status.name`→status.
- **status verbs**: `transition_issue` through the board workflow — `start`=In Progress, `review`=In Review, `done`=Done; `add_comment` for the write-back. (Transition names vary per board — read available transitions first, match case-insensitively.)

### linear — `@tacticlaunch/mcp-linear`
- **ref**: `linear.app/<team>/issue/ABC-123` URL · `ABC-123` · `linear:ABC-123` · `next` (assigned, state ≠ Done/Canceled, ordered by priority).
- **fetch**: `get_issue` (with sub-issues, attachments, comments).
- **field map**: `title`→title · `description`→description · sub-issues→subtasks · `attachments[]`→attachments · `labels[].name`→labels · `priority`→priority · `assignee.name`→assignee · `state.name`→status.
- **status verbs**: `update_issue { stateId }` — `start`=In Progress, `review`=In Review, `done`=Done; `create_comment` for the write-back.

### github — `ghcr.io/github/github-mcp-server` (already universal in detect-mcp.sh)
- **ref**: `github.com/<owner>/<repo>/issues/<n>` URL · `#<n>` (current repo) · `gh:<owner>/<repo>#<n>` · `next` (open issues `assignee=@me`, ordered by milestone then priority label).
- **fetch**: `get_issue`; `list_issue_comments`.
- **field map**: `title`→title · `body`→description · markdown task-list `- [ ]`→subtasks · image/file links in body→attachments · `labels[].name`→labels · milestone/`priority:*` label→priority · `assignee.login`→assignee · `state`→status.
- **status verbs**: `add_labels` (`in-progress`, then `needs-review`) — GitHub has no In-Progress state, so labels stand in; `add_issue_comment` for the write-back; `update_issue { state: closed }` on `done`.

---

## Adding a new provider (Asana, ClickUp, Notion, Azure Boards, …)
1. Add a `### <id> — <package>` adapter block above with the four sections.
2. Add a detection + config block to `scripts/detect-mcp.sh` (gate on the repo's own `.env` creds; mirror the trello/jira/linear blocks).
3. Document the env-var names and verify them against the server's README.
That's it — `commands/task.md` requires no edit; it reads adapters generically.
