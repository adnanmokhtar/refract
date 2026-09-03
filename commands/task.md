---
description: Execute ONE tracker item end to end and write its status back to the source. Trigger only when the input IS a task reference — a Trello, Jira, Linear, or GitHub Issue URL, an issue key such as PROJ-123, or 'next' — as in 'do this card' or 'grab the next ticket and start'. Do NOT trigger for a whole board or sprint in one shot; loop /task next instead. Not when the code change is already known and the ticket is noise — call /add-feature or /fix-bug directly.
compatibility: Requires a task-provider MCP in .mcp.json OR that provider's credentials in .env. A healthy MCP is used first; on 401 or a missing MCP it falls back to the provider's REST API over the .env creds, and it halts only when neither exists. Several providers configured plus an ambiguous ref costs one question. Write-back only moves a card forward or comments — it never deletes or downgrades.
kind: command
pack: orchestration
version: 1.0.0
---

# /task <ref> [--prompt-only] [--to=<command>] [--no-writeback] [--review-only]

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
2. **Load credentials from `.env`** (the MCP server is spawned at editor startup and may have been launched without the provider vars in its environment → it will 401 with empty creds). Before any provider call, make the creds available to this session's shell:
   ```bash
   [ -f .env ] && set -a && . ./.env && set +a    # exports TRELLO_*/JIRA_*/LINEAR_* for direct API calls
   ```
   This does NOT retroactively fix an already-spawned MCP's environment — that's what the fallback in step 3 is for.
3. **Establish a WORKING provider connection** (MCP-first, REST-fallback — never halt while valid `.env` creds exist):
   - Probe the provider MCP (ToolSearch for its tools, then a cheap auth check — e.g. Trello `get_health` / a whoami call).
   - **MCP healthy** → use it for fetch + write-back.
   - **MCP missing, OR returns 401 / auth failure / 0% health** → do NOT halt. Fall back to the provider's **direct REST API via Bash** using the `.env` creds loaded in step 2 (Trello: `curl "https://api.trello.com/1/cards/<id>?key=$TRELLO_API_KEY&token=$TRELLO_TOKEN&..."`; Jira/Linear: their REST/GraphQL endpoints). Fetch AND write-back both work over REST. Note in the run summary that REST fallback was used (so the user knows to fix the MCP env via `set -a; source .env; set +a` before relaunching).
   - **Only halt** if there is no provider MCP AND `.env` has no creds for the resolved provider → "Provider `<x>` not configured: add its creds to `.env` and run `/setup-project` (or `detect-mcp.sh --apply`)."
4. **Fetch + normalize** to the canonical **TaskSpec** over whichever channel works (MCP or REST), using that provider's adapter (field map in the reference doc). Read title, description, checklist/sub-issues, attachments metadata, labels, current status, and the status-flow target names.
5. **Echo the resolved spec** (title, key, AC count, subtask count, attachment count) in 4–5 lines and state the plan. Proceed without a pause unless the AC are empty AND the title is vague (then ask one scoping question).

## Phase 2 — Organize (decompose)
```
0. ENV       — load .env creds; pick MCP if healthy, else REST fallback (never halt with valid creds)
1. RESOLVE   — provider + fetch + normalize → TaskSpec
2. INGEST    — download attachments, read specs/screenshots
3. PLAN      — AC + subtasks → ordered worklist; classify intent (feature/fix/refactor/audit)
4. MARK      — write-back: move source to "In Progress" (unless --no-writeback)
5. EXECUTE   — route the synthesized description to /do
6. VERIFY    — check each AC / subtask against the change
7. CLOSE     — comment summary + commit/PR on the source; move to Review or Done
```
All provider reads AND write-backs use the same channel resolved in Phase 1 (MCP if healthy, else REST over `.env` creds).

## Phase 3 — Retrieve (ingest context)
- **ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../templates/snippets/phase-3-always-reads.md).
- **Attachments** → download to `.claude/tasks/<provider>-<key>/` and classify:
  - image (png/jpg/gif) → **design/repro reference** (feed to UI work; if it's an error screenshot, treat as the bug repro).
  - `.md`/`.txt`/`.pdf`/`.docx` → **spec** (read fully; its content is part of the requirements).
  - code/diff/`.json`/`.csv` → **reference data / fixtures**.
- **Description links** to other cards/issues → fetch titles for context (do NOT recurse into doing them).

## Phase 4 — Generate (execute the work)
- Synthesize a single, faithful description from `title` + `description` + `acceptanceCriteria` + `subtasks` + attachment findings — verbatim intent, not paraphrased away.
- **`--prompt-only`** (emit, don't execute) → **STOP here.** Print a clean, paste-ready prompt block and do NOT dispatch, do NOT write back. Format:
  ```
  # Task: <title>  (<provider>:<key> · <priority>)
  ## Context
  <synthesized description>
  ## Acceptance criteria
  - [ ] <each AC>            (or: "none stated — verify title intent")
  ## Subtasks
  - <each subtask>           (omit section if none)
  ## Attachments (downloaded)
  - <name> → <localPath>     (omit section if none)
  ## Suggested command
  /<routed-or-`--to`-command> <one-line synthesized description>
  ```
  The "Suggested command" line uses `--to`'s value if given, else the command `/do` would route to. End the run after printing — this is the hand-off mode.
  **Output integrity** — the printed block must be clean: no corruption artifacts (doubled punctuation, stray/truncated tokens, duplicated lines), every identifier (key, URL, type, perm) spelled consistently, every code snippet one canonical shape, and every "verify/likely/if X" hedge collected — not buried inline. Same bar as `/refine-prompt`'s output-integrity rule; for a *deep* class-tailored prompt (frontend feature, endpoint, audit, …) rather than a ticket transcription, prefer `/refine-prompt`.
- **`--to=<command>`** (pin the target) → skip `/do` routing; dispatch the synthesized description **directly** to `/<command>` (must exist in this repo). Without `--to`, **dispatch to `/do`** so it routes to the right specialist (`/add-feature`, `/fix-bug`, `/enhance-ui`, `/optimize`, …). `/task` does NO code work itself.
- If the task obviously spans multiple specialists (e.g. "add endpoint AND its UI"), run them in dependency order; record each in the worklist.

### If the run halts after the card was marked

Phase 5's "On start" move happens BEFORE the work — so from that moment the card reads
**In Progress on a board other people watch**. Every halt below it (routing refusal, a `/do`
failure, a Constraint collision, an interrupted session) leaves that state behind on shared
infrastructure. `/execute-plan` has this contract for local git state; this is the same contract
for state that is not on your machine, and it matters more, because a teammate cannot see your
working tree but can see the card.

**On any halt after the start-move, and before the finish-move:**

1. **Do not leave the board lying.** Post ONE comment on the card via the same channel Phase 1
   resolved (MCP if healthy, else REST): what was attempted, what stopped it, and any commit
   SHA(s) already made. A card silently stuck In Progress is worse than a failed one — it reads
   as work in flight and blocks whoever would pick it up.
2. **Move it back to `statusFlow.start`'s predecessor** (the list/state it came from, captured in
   Phase 1) **unless code was already committed** — in which case leave it In Progress, because
   the branch really does carry partial work and moving it back would misreport that too.
3. **Tell the user both facts explicitly**: where the card now sits, and what exists locally
   (branch, commits, files). Never end a halted run without saying what state the tracker is in.
4. **If the comment or the move itself fails**, fall through to the same four steps Phase 5 uses
   for a failed write-back: print the exact body, print the exact command to run it by hand, and
   record `writeback=FAILED(<reason>)` in the local audit line.

Under `--no-writeback` there is nothing to undo — no start-move happened. Under `--prompt-only`
the run ends before Phase 4 dispatches, so it never reaches the start-move either.

## Phase 5 — Update (write back to the source)
Skipped entirely under `--prompt-only` (nothing was executed). Otherwise, unless `--no-writeback`:
- **On start** — move the source to its `statusFlow.start` (Trello list / Jira transition / Linear state / GitHub `in-progress` label).
- **On finish** — post ONE comment via the adapter's comment verb: 1-line summary, the commit SHA(s)/PR link, and a per-AC ✓/✗ checklist. Tick completed checklist items / close sub-issues.
- **Move** to `statusFlow.review` by default (human verifies), or `statusFlow.done` if `--review-only` is NOT set and all AC pass and tests are green. **Never delete** a card/issue.
- **Write-back is post-execution — the work is already done and committed.** A failed status move / comment post (MCP error, REST 4xx/5xx, network) must NOT lose the work or leave the user without a record. When write-back fails AFTER execution:
  1. Do NOT halt silently and do NOT retry-loop forever (one retry max).
  2. **Print the exact comment body** that failed to post (the 1-line summary + commit SHA(s)/PR link + per-AC ✓/✗ list) so nothing is lost.
  3. **Print the exact command the user can run to post it manually** — the same channel that was being used: the MCP tool call args, OR a ready-to-paste `curl`/REST command using `.env` creds (e.g. Trello `curl -X POST "https://api.trello.com/1/cards/<id>/actions/comments?key=$TRELLO_API_KEY&token=$TRELLO_TOKEN&text=<body>"`; Jira/Linear comment endpoints similarly). Include the status-move command too.
  4. **STILL append the local audit line** (below) with a `writeback=FAILED(<reason>)` marker so the history reflects reality — the execution happened even though the source wasn't updated.
- Append a local audit line to `ai/_history.md` (**create the file with a `# Task history` header if absent** — never assume it exists): `<iso> /task <provider>:<key> → /<routed-command> → <review|done>` (on write-back failure, append ` writeback=FAILED(<reason>)`).

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

- **Run halts after the card was marked In Progress** → the card is sitting on a shared board claiming work is in flight. Comment what stopped it, move it back unless commits exist, and state both the card's position and the local state. See § *If the run halts after the card was marked* — this is the one failure whose blast radius is other people.
- **Provider MCP missing or 401 (stale/empty env)** → do NOT halt; load `.env` and use the REST fallback (Phase 1 step 3). Halt only when there is ALSO no `.env` creds for the provider.
- **Ambiguous `next` (multiple providers)** → ask which provider (one question).
- **Card not found / no access** → halt; surface the provider's error verbatim.
- **Empty description AND empty AC AND vague title** → ask one scoping question before executing.
- **Routed specialist halts** (its own intent gate) → re-surface both routings; do not force.
- **Write-back fails AFTER execution** (MCP/REST error on the status move or comment post) → do NOT lose the work: print the comment body + the exact manual post command (MCP args or `curl`/REST with `.env` creds), still append the `ai/_history.md` audit line marked `writeback=FAILED(<reason>)`. The committed change stays; only the source update is deferred to the user.

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

/task https://trello.com/c/NBswBsfN --prompt-only
→ fetch + normalize, then PRINT a paste-ready prompt block (+ suggested command); no execution, no write-back

/task PROJ-128 --to=fix-bug
→ fetch → dispatch directly to /fix-bug (skips /do routing) → write-back as normal

/task PROJ-128 --to=add-feature --prompt-only
→ print an /add-feature-shaped prompt for PROJ-128; you run it elsewhere
```

## Flags
| Flag | Effect |
|---|---|
| `--prompt-only` | Fetch + normalize, then **print a paste-ready prompt and stop** — no `/do`, no execution, no write-back. Hand-off mode. |
| `--to=<command>` | Dispatch directly to `/<command>` instead of routing through `/do` (command must exist in this repo). |
| `--no-writeback` | Execute, but don't touch the source (no status move, no comment). |
| `--review-only` | On finish, stop at the Review state — never auto-advance to Done. |

## Related
- **Routes to**: `/do` (which dispatches to `/add-feature`, `/fix-bug`, `/enhance-ui`, `/optimize`, …).
- **Backed by**: provider MCPs wired in `scripts/detect-mcp.sh` (trello / jira / linear / github), gated on each repo's own `.env` creds.
- **Reference**: [`templates/integrations/task-providers.md`](../templates/integrations/task-providers.md) — canonical TaskSpec + adapters + extension steps.
- **Sibling**: `/do` is intent→command routing; `/task` is source→spec→execute→write-back. `/task` uses `/do` under the hood.
