---
description: Provider-agnostic task executor. Take ONE task reference (Trello / Jira / Linear / GitHub Issue — URL, key, or "next"), fetch its title + description + attachments + checklist, normalize to a canonical spec, then execute it end-to-end via /do and write status back to the source (in-progress → comment → done). One command, swappable backends. Per-repo provider via .env + the MCP wired by detect-mcp.sh.
kind: command
pack: orchestration
---

# /task <ref> [--no-writeback] [--review-only]

Pull ONE task from your project-management tool and do it. `<ref>` is a card/issue
**URL**, a **key** (`PROJ-123`, `#42`, `trello:<id>`), or **`next`** (the top unstarted
item assigned to you). Works the same whether the work lives in Trello, Jira, Linear,
or GitHub Issues — the provider is resolved from the ref and the MCP configured in this
repo. The code work is delegated to `/do`; this command owns the **task lifecycle**:
fetch → normalize → ingest attachments → execute → write status back.

## When to use / NOT to use
- USE: "do this card" with a link/key; "grab the next ticket and start"; turning an issue's description + attached spec/screenshot into a working change with the card updated.
- USE: a daily loop — `/task next` repeatedly to drain a list/sprint.
- NOT: bulk-porting a whole board in one shot (that's many tasks — loop `/task next`, or use a workflow). NOT: when you already know the exact code change and the ticket is just noise — call the specialist command (`/add-feature`, `/fix-bug`) directly.

> **Specialist, not a wrapper.** Its value is provider-neutral task→spec translation
> (checklist→worklist, attachment classification, acceptance-criteria extraction) plus
> the **write-back lifecycle**. Code execution routes through `/do`. The provider field
> maps + status verbs live in [`templates/integrations/task-providers.md`](../templates/integrations/task-providers.md).

**Applies phases: 1–7** (Build/Fix command; Phase 4 = execute via routed specialist).

## Phase 1 — Understand (resolve the task)
1. **Resolve provider** from `<ref>`:
   - URL → match host (`trello.com`→trello, `*.atlassian.net`/`/browse/`→jira, `linear.app`→linear, `github.com/.../issues/`→github).
   - Prefix → `jira:` / `linear:` / `trello:` / `gh:`.
   - Bare key shape → `PROJ-123`→jira, `ABC-123`→linear, `#42`→github (current repo).
   - `next` or bare → the **single task-provider MCP present in `.mcp.json`** (trello/jira/linear/github). If more than one is configured and the ref is ambiguous → ask which provider (one question).
2. **Verify the provider MCP is available** (ToolSearch for its tools). If absent → halt: "Provider `<x>` isn't wired in this repo. Add its creds to `.env` and run `/setup-project` (or `detect-mcp.sh --apply`)."
3. **Fetch + normalize** to the canonical **TaskSpec** using that provider's adapter (field map in the reference doc). Read title, description, checklist/sub-issues, attachments metadata, labels, current status, and the status-flow target names.
4. **Echo the resolved spec** (title, key, AC count, subtask count, attachment count) in 4–5 lines and state the plan. Proceed without a pause unless the AC are empty AND the title is vague (then ask one scoping question).

## Phase 2 — Organize (decompose)
```
1. RESOLVE   — provider + fetch + normalize → TaskSpec
2. INGEST    — download attachments, read specs/screenshots
3. PLAN      — AC + subtasks → ordered worklist; classify intent (feature/fix/refactor/audit)
4. MARK      — write-back: move source to "In Progress" (unless --no-writeback)
5. EXECUTE   — route the synthesized description to /do
6. VERIFY    — check each AC / subtask against the change
7. CLOSE     — comment summary + commit/PR on the source; move to Review or Done
```

## Phase 3 — Retrieve (ingest context)
- **ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../templates/snippets/phase-3-always-reads.md).
- **Attachments** → download to `.claude/tasks/<provider>-<key>/` and classify:
  - image (png/jpg/gif) → **design/repro reference** (feed to UI work; if it's an error screenshot, treat as the bug repro).
  - `.md`/`.txt`/`.pdf`/`.docx` → **spec** (read fully; its content is part of the requirements).
  - code/diff/`.json`/`.csv` → **reference data / fixtures**.
- **Description links** to other cards/issues → fetch titles for context (do NOT recurse into doing them).

## Phase 4 — Generate (execute the work)
- Synthesize a single, faithful description from `title` + `description` + `acceptanceCriteria` + `subtasks` + attachment findings — verbatim intent, not paraphrased away.
- **Dispatch to `/do`** with that description so it routes to the right specialist (`/add-feature`, `/fix-bug`, `/enhance-ui`, `/optimize`, …). `/task` does NO code work itself.
- If the task obviously spans multiple specialists (e.g. "add endpoint AND its UI"), run them in dependency order; record each in the worklist.

## Phase 5 — Update (write back to the source)
Unless `--no-writeback`:
- **On start** — move the source to its `statusFlow.start` (Trello list / Jira transition / Linear state / GitHub `in-progress` label).
- **On finish** — post ONE comment via the adapter's comment verb: 1-line summary, the commit SHA(s)/PR link, and a per-AC ✓/✗ checklist. Tick completed checklist items / close sub-issues.
- **Move** to `statusFlow.review` by default (human verifies), or `statusFlow.done` if `--review-only` is NOT set and all AC pass and tests are green. **Never delete** a card/issue.
- Append a local audit line to `ai/_history.md`: `<iso> /task <provider>:<key> → /<routed-command> → <review|done>`.

## Phase 6 — Validate (verify against the card)
- Each `acceptanceCriteria` item → checked against the actual change (test, run, or inspection). Empty AC → verify the title's intent is satisfied.
- Tests run green (or explicitly report which fail). Attachment-derived specs honored (e.g. screenshot layout matched).
- The write-back comment's ✓/✗ list must reflect reality — never report an unmet AC as met.

## Phase 7 — Improve (feed the loop)
- If the same provider+pattern recurs, suggest `/task next` looping or a scheduled drain.
- If a card was under-specified (empty AC, vague title) and needed a question, note it — the fix is in the ticket-writing, surface that back in the comment.
- New provider needed? Point to the extension steps in the task-providers reference.

## Hard rules
- **One task per invocation.** `<ref>` resolves to exactly one card/issue. For many, loop `/task next`.
- **Read adapters, don't hard-code.** Provider field maps + status verbs come from `templates/integrations/task-providers.md`; tool names are discovered at runtime.
- **Never delete; never silently downgrade.** Write-back moves forward (start→review→done) or comments; destructive ops are out of scope.
- **Faithful execution.** The routed description preserves the card's intent verbatim — no scope drift, no silent omission of AC.
- **Secrets stay in `.env`.** `/task` reads creds only via the provider MCP's env; it never prints or echoes tokens.

## Failure modes
- **No provider MCP in repo** → halt with the `.env` + `detect-mcp.sh --apply` fix.
- **Ambiguous `next` (multiple providers)** → ask which provider (one question).
- **Card not found / no access** → halt; surface the provider's error verbatim.
- **Empty description AND empty AC AND vague title** → ask one scoping question before executing.
- **Routed specialist halts** (its own intent gate) → re-surface both routings; do not force.

## Examples
```
/task https://trello.com/c/aB12cD34
→ trello:aB12cD34 "Add refund button to order details" · 3 AC · 2 subtasks · 1 attachment (mock.png)
  → moved to In Progress → /do add a refund button to order details (per mock.png)
  → /add-feature … → 3/3 AC ✓, tests green → comment + PR link posted → moved to Review

/task PROJ-128
→ jira:PROJ-128 "Orders list crashes on empty filter" · repro screenshot attached
  → In Progress → /fix-bug … → repro fixed, regression test added → transitioned to In Review

/task next
→ linear:ENG-44 "Tighten dashboard spacing" (top of my queue) → /enhance-ui … → In Review

/task #57 --no-writeback
→ github issue #57 → executed; no labels/comments written (dry lifecycle)
```

## Related
- **Routes to**: `/do` (which dispatches to `/add-feature`, `/fix-bug`, `/enhance-ui`, `/optimize`, …).
- **Backed by**: provider MCPs wired in `scripts/detect-mcp.sh` (trello / jira / linear / github), gated on each repo's own `.env` creds.
- **Reference**: [`templates/integrations/task-providers.md`](../templates/integrations/task-providers.md) — canonical TaskSpec + adapters + extension steps.
- **Sibling**: `/do` is intent→command routing; `/task` is source→spec→execute→write-back. `/task` uses `/do` under the hood.
