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
  provider:   trello | jira | linear | github | clickup   # which adapter produced this
  id:         <stable internal id>               # for API calls
  key:        <human ref>                        # PROJ-123 / card shortLink / #42
  url:        <permalink>                         # for the write-back comment
  title:      <string>
  description: <markdown>                         # body, ADF/HTML converted to md
  acceptanceCriteria: [<string>, ...]            # parsed (see "AC parsing" below)
  subtasks:   [{ text: <string>, done: <bool> }] # checklist / sub-issues / task-list
  attachments: [{ name, url, mime, localPath }]  # downloaded in Phase 3
  labels:     [<string>, ...]
  comments:   [{ author, date, text, own: <bool> }] # oldest first; own = posted by /task (ends with a `Ref:` line or the line `— /task`)
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

Each adapter declares five things: **ref detection**, **fetch**, **field map**,
**status verbs**, and **create** (used by `/task add`, and by `/analyze-task` and `/expand-task` with `--to-board`).

**Lists on every provider.** `task-flow.json`'s `pickFrom`, `fixLists`, `waitIn`, `addTo`,
`start`, `review` and `done` name a Trello list, a Jira status, a Linear state, a ClickUp status,
or a GitHub label. `next`, `refine` and the moves read and write that same field on each provider
(Jira: transition to the status; Linear: `stateId`; ClickUp: `status`; GitHub: add the label and
remove the previous flow label). With no `task-flow.json`, each adapter's own `next` below applies,
and `refine` reads the same cards `next` would. Tool names are the provider MCP's tools — discover the exact names
at runtime via ToolSearch; the names below are the expected shape.

### trello — `@delorenj/mcp-server-trello`
- **ref**: `trello.com/c/<shortLink>` URL · `trello:<id>` · bare card id · `next` (top card of the first non-empty `pickFrom` list in `.claude/task-flow.json`, after any card carrying a `priorityLabels` label — the card's `labels[].name`, ranked by that list; without that file, the "To Do"/leftmost list on `TRELLO_BOARD_ID`).
- **fetch**: `get_card` / `get_card_by_id`; `get_checklists`; card `attachments`; card comments (`get_card_comments`, or REST `/cards/<id>/actions?filter=commentCard` — the card object does not carry them); `get_lists` (to resolve status-flow list ids).
- **field map**: `name`→title · `desc`→description · checklist items→subtasks · `attachments[]`→attachments · `labels[].name`→labels · comment actions (`memberCreator.fullName`, `date`, `data.text`)→comments · list name of `idList`→status.
- **status verbs**: move card via `update_card { idList }` — `start`=In Progress, `review`=Review/QA, `done`=Done; `add_comment_to_card` for the write-back; tick checklist item via `update_checkitem` as each subtask completes.
- **create**: `add_card_to_list { listId, name, description, labels }`, or REST `POST /1/cards` with `idList`, `name`, `desc` and `idLabels` (label ids from `GET /1/boards/<board>/labels`; never create a label).

### jira — `@aashari/mcp-server-atlassian-jira`
- **ref**: `.../browse/PROJ-123` URL · `PROJ-123` · `jira:PROJ-123` · `next` (top of JQL `assignee = currentUser() AND statusCategory != Done ORDER BY priority DESC`).
- **fetch**: `get_issue` (expand subtasks, attachments, comments).
- **field map**: `summary`→title · `description` (ADF→markdown)→description · `subtasks[]`→subtasks · `attachment[]`→attachments · `labels[]`→labels · `priority.name`→priority · `assignee.displayName`→assignee · `status.name`→status.
- **status verbs**: `transition_issue` through the board workflow — `start`=In Progress, `review`=In Review, `done`=Done; `add_comment` for the write-back. (Transition names vary per board — read available transitions first, match case-insensitively.)
- **create**: `create_issue { project, issuetype, summary, description, labels }` — the issue type is the project's own name for a story or a bug (read `GET /rest/api/3/issue/createmeta` first); then transition it to the `addTo` status when that is not the project's initial status.

### linear — `@tacticlaunch/mcp-linear`
- **ref**: `linear.app/<team>/issue/ABC-123` URL · `ABC-123` · `linear:ABC-123` · `next` (assigned, state ≠ Done/Canceled, ordered by priority).
- **fetch**: `get_issue` (with sub-issues, attachments, comments).
- **field map**: `title`→title · `description`→description · sub-issues→subtasks · `attachments[]`→attachments · `labels[].name`→labels · `priority`→priority · `assignee.name`→assignee · `state.name`→status.
- **status verbs**: `update_issue { stateId }` — `start`=In Progress, `review`=In Review, `done`=Done; `create_comment` for the write-back.
- **create**: `create_issue { teamId, title, description, labelIds, stateId }` — the state is the `addTo` state.

### github — `ghcr.io/github/github-mcp-server` (already universal in detect-mcp.sh)
- **ref**: `github.com/<owner>/<repo>/issues/<n>` URL · `#<n>` (current repo) · `gh:<owner>/<repo>#<n>` · `next` (open issues `assignee=@me`, ordered by milestone then priority label).
- **fetch**: `get_issue`; `list_issue_comments`.
- **field map**: `title`→title · `body`→description · markdown task-list `- [ ]`→subtasks · image/file links in body→attachments · `labels[].name`→labels · milestone/`priority:*` label→priority · `assignee.login`→assignee · `state`→status.
- **status verbs**: `add_labels` (`in-progress`, then `needs-review`) — GitHub has no In-Progress state, so labels stand in; `add_issue_comment` for the write-back; `update_issue { state: closed }` on `done`.
- **create**: `create_issue { title, body, labels }`, or `gh issue create --title … --body-file … --label …` — `labels` includes the `addTo` label.

### clickup — REST API v2 first · official MCP `https://mcp.clickup.com/mcp` optional
- **channel**: REST over `CLICKUP_API_TOKEN` (a personal token, `pk_…`, sent as `Authorization: <token>`), base `https://api.clickup.com/api/v2`. **REST is the primary channel here, not the fallback**: the official MCP signs in by OAuth only (an interactive `/mcp` step, no token) and is capped per day by plan — 100 calls/day on Free, 300 on Unlimited — which one drain can spend. Use the MCP only when no token is set. REST allows 100 requests/min per token on the lower plans.
- **ref**: `app.clickup.com/t/<task_id>` URL · `app.clickup.com/t/<team_id>/<CUSTOM-ID>` URL · `clickup:<task_id>` · `clickup:<CUSTOM-ID>` (a custom id needs `?custom_task_ids=true&team_id=$CLICKUP_TEAM_ID` on every task call). A bare `ABC-123` stays Jira/Linear's shape: a custom id needs the `clickup:` prefix unless `task-flow.json` names `"provider": "clickup"`. `next` → the tasks of `CLICKUP_LIST_ID` whose **status** is in `pickFrom` — ClickUp's board columns are statuses, not lists: `GET /list/{list_id}/task?statuses[]=<s>&subtasks=true`, 100 a page, `page` from 0 until `last_page`. The API cannot sort by priority, so rank on the client.
- **priority**: ClickUp has a native priority field — 1 urgent, 2 high, 3 normal, 4 low, null none — and it cannot be renamed. `priorityLabels` matches the priority's name as well as tags, so `"priorityLabels": ["urgent", "high"]` ranks by the native field with no tags at all; an unset priority ranks last.
- **fetch**: `GET /task/{id}?include_markdown_description=true&include_subtasks=true` (checklists, attachments, tags, priority, status, custom fields in one call); comments `GET /task/{id}/comment` — the newest 25 only: page back with `start` + `start_id` (the oldest comment's `date` and `id`) until a page comes back empty, then reverse to oldest first. Attachment `url`s download with the same token header.
- **field map**: `name`→title · `markdown_description` (else `description`)→description · `checklists[].items[]` (`name`, `resolved`) and child tasks→subtasks · `attachments[]` (`title`, `url`)→attachments · `tags[].name`→labels (what `labelRoutes` match) · `priority.priority`→priority · `assignees[0].username`→assignee · `status.status`→status · comments (`user.username`, `date` in epoch ms, `comment_text`)→comments.
- **status verbs**: `PUT /task/{id}` `{"status": "<name>"}` — status names are the list's own (`GET /list/{list_id}` → `statuses[]`), matched case-insensitively; `POST /task/{id}/comment` `{"comment_text": "…", "notify_all": false}` for the write-back; tick a checklist item with `PUT /checklist/{checklist_id}/checklist_item/{item_id}` `{"resolved": true}`.
- **create**: `POST /list/{list_id}/task` `{"name", "markdown_content", "tags", "priority", "status"}` — `status` is the `addTo` status; tags must already exist in the space.
- **env**: `CLICKUP_API_TOKEN` (required) · `CLICKUP_LIST_ID` (for `next`) · `CLICKUP_TEAM_ID` (custom ids only).
- Written from ClickUp's API reference (2026-11); not yet run against a real workspace — the first real run checks each field name above and corrects this block.

---

## Adding a new provider (Asana, Notion, Azure Boards, …)
1. Add a `### <id> — <package>` adapter block above with the five sections.
2. Add a detection + config block to `scripts/detect-mcp.sh` (gate on the repo's own `.env` creds; mirror the trello/jira/linear blocks).
3. Document the env-var names and verify them against the server's README.
That's it — `commands/task.md` requires no edit; it reads adapters generically.
