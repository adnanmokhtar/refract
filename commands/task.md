---
description: Execute ONE tracker item end to end and write its status back to the source. Trigger only when the input IS a task reference — a Trello, Jira, Linear, or GitHub Issue URL, an issue key such as PROJ-123, or 'next' — as in 'do this card' or 'grab the next ticket and start'. 'next --drain' works the pick lists card by card until empty; 'add <file>' files new cards. Not when the code change is already known and the ticket is noise — call /add-feature or /fix-bug directly.
compatibility: Requires a task-provider MCP in .mcp.json OR that provider's credentials in .env. A healthy MCP is used first; on 401 or a missing MCP it falls back to the provider's REST API over the .env creds, and it halts only when neither exists. Several providers configured plus an ambiguous ref costs one question. Write-back only moves a card forward or comments — it never deletes or downgrades.
kind: command
pack: orchestration
version: 1.8.0
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /task <ref> | refine | add <source> | status [--since=7d] [--drain [--max=N]] [--prompt-only] [--to=<command>] [--no-writeback] [--review-only] [test word] [«من غير كومنت»]

Pull ONE task from your project-management tool and do it. `<ref>` is a card/issue
**URL**, a **key** (`PROJ-123`, `#42`, `trello:<id>`), or **`next`** (the top card of the
repo's pick lists — § *Board flow* — else the top unstarted item assigned to you). Works the same whether the work lives in Trello, Jira, Linear,
or GitHub Issues — the provider is resolved from the ref and the MCP configured in this
repo. The code work is delegated to `/do`; this command owns the **task lifecycle**:
fetch → normalize → ingest attachments → execute → write status back.

## When to use / NOT to use
- USE: "do this card" with a link/key; "grab the next ticket and start"; turning an issue's description + attached spec/screenshot into a working change with the card updated.
- USE: working the queue — `/task next --drain` takes every card in the pick lists, one at a time, each closed before the next starts.
- USE: understanding the batch before any code — `/task refine` studies every card in the pick lists, posts each one's plain brief and questions, and builds nothing (§ *Refine mode*).
- USE: filling the board — `/task add <source>` turns a plan, a spec, an audit report or a scenario sheet into new cards (§ *Add mode*). It does no code work.
- NOT: bulk-porting a whole board in one shot (all cards in one change, or cards outside the pick lists). NOT: when you already know the exact code change and the ticket is just noise — call the specialist command (`/add-feature`, `/fix-bug`) directly.

> **Specialist, not a wrapper.** Its value is provider-neutral task→spec translation
> (checklist→worklist, attachment classification, acceptance-criteria extraction) plus
> the **write-back lifecycle**. Code execution routes through `/do`. The provider field
> maps + status verbs live in [`templates/integrations/task-providers.md`](../templates/integrations/task-providers.md).

**Applies phases: 1–7** (Build/Fix command; Phase 4 = execute via routed specialist).

## Board flow (`.claude/task-flow.json`, optional, tracked)

A team's board has its own vocabulary — which lists are approved work, which list QA watches,
whether an agent may ever reach Done. One tracked file per repo states it, so a teammate's run
reads the same flow:

```json
{
  "pickFrom": ["Fixing", "Approved"],
  "fixLists": ["Fixing"],
  "labelRoutes": [
    { "label": "Bug",         "to": "fix-bug" },
    { "label": "Feature",     "to": "add-feature" },
    { "label": "UI/UX",       "to": "enhance-ui" }
  ],
  "priorityLabels": ["Urgent", "High"],
  "start":    "In Progress",
  "review":   "Testing",
  "done":     null,
  "addTo":    "Backlog",
  "waitIn":   "On Hold",
  "planApproval": "person",
  "git": {
    "branchFrom":     "origin/main",
    "branch":         "<type>/<slug>",
    "worktree":       "../worktrees/<slug>",
    "prTo":           ["staging", "main"],
    "conflictBranch": "merge/<branch>-into-<target>"
  }
}
```

- **`pickFrom`** — the lists/states `next` takes from, **in priority order**: the first list with
  a card wins, top card of that list first. A card in any other list is never picked by `next`
  (Backlog-style lists hold work nobody approved yet). An explicit URL/key still runs any card.
- **`priorityLabels`** — labels that jump the queue, highest first, matched case-insensitively. On a provider with a native priority field (ClickUp, Jira, Linear) its value counts as a label: `["urgent", "high"]`.
  `next` reads every pick list and takes a card carrying the first label before any card carrying
  the second, and those before an unlabelled one — whichever pick list it sits in. Within one
  rank the `pickFrom` order and then the card's position decide. Absent or empty → list order and
  position only.
- **`fixLists`** — pick lists QA sends cards back to. A card taken from one is executed as a
  fix: the tester's latest comment is the bug repro, and it dispatches to `/fix-bug` whatever its
  labels say.
- **`labelRoutes`** — work-type labels → the command that does that kind of work, **in priority
  order**: the first entry whose label is on the card wins (Bug + UI/UX → `/fix-bug`). Labels
  matched case-insensitively. Labels with no entry (area labels: API, Database, DevOps, …) never
  pick the command; they ride along in the description as context. No matching label → `/do`
  routes from the text as before. A target command that does not exist in this repo → fall back to
  `/do` and say so in the echo.
- **`waitIn`** — the list a card waits in while its brief has open questions (§ *Refine mode*).
  Absent → the card stays where it is, labelled with its open-question count in the brief comment.
- **`planApproval`** — `person` (default): a card is built only after a person approved its brief.
  `none`: a brief with no open question is built at once. A brief with an open question is never
  built, whatever this says.
- **`addTo`** — the list `add` creates cards in (§ *Add mode*). Absent → the board's first list
  outside `pickFrom`. Never a pick list unless the person names one in the call.
- **`start` / `review` / `done`** — the `statusFlow` names, matched case-insensitively. **`done:
  null`** means the run never moves past `review`: release lists and Done belong to the humans who
  ship. A name that matches no list on the board → halt before the start-move and name the lists
  that exist.
- **`git`** — where each card's work lives. Absent → commit where the session stands, under the
  project's own git rules. Present:
  - **`branchFrom`** — every card gets a fresh branch cut from this ref, fetched first. In a
    drain, card 2 never stacks on card 1.
  - **`branch`** — its name. `<type>` is the Conventional Commits type of the change (`fix` from
    `/fix-bug`, `feat` from `/add-feature`, `refactor`, `perf`, …); `<slug>` is a short
    lowercase ASCII slug of the card title.
  - **`worktree`** — cut it in its own worktree at this path (`git worktree add -b <branch> <dir>
    <branchFrom>`), so the shared checkout stays on its branch for other sessions. All of Phase
    4–6 runs there. Once the branch is pushed, the worktree is removed; the branch keeps every
    commit. Absent → `git switch -c` in place.
  - **`prTo`** — after Phase 6, push the branch and open one PR into each target, in order.
    `/task` opens PRs and never merges one: merging belongs to whoever releases, who types
    `/merge-to` to check the PRs together before they land. **Each card leaves its record in the
    project**: `ai/features/<YYYY-MM-DD>-<slug>/` with the approved brief (`brief.md`, questions and
    answers included), the design (`design.md`, when `/add-feature` built it) and the acceptance
    criteria (`acceptance.md`). It is committed with the code, with one line in
    `ai/features/_index.md` (`study-before-build.md` § 9). The PR body is the card link and the folder
    path.
  - **`conflictBranch`** — a branch that does not merge cleanly into a target is never fixed on
    the branch itself, because the target's history would then ride into its other PRs. Cut this
    branch from the target, cherry-pick the card's own commits onto it (`git cherry-pick
    $(git merge-base <branch> <branchFrom>)..<branch>`, so its PR shows only the card's change and
    the resolutions, not every commit of `branchFrom` the target lacks), resolve
    there, push it, and open the target's PR from it instead.
    Resolve file by file, reading both sides of each hunk. Never resolve with one generic text rule
    across files (take ours, take theirs, one search-and-replace). After resolving, run the specs
    of every resolved file and the rules a merge breaks without a conflict marker: every locale
    file still has the same keys, and the migrations still run in order. Use the project's own
    checks for these where it has them, and check by hand where it has none. Static checks alone
    (lint, types) do not prove a resolution.

  A push or PR that is refused (hook, auth, network) is handled like a failed write-back: print
  the exact `git push` / `gh pr create` lines, carry on to the finish comment with the branch name
  as the Ref, and add `pr=FAILED(<reason>)` to the audit line. Rules the project's `CLAUDE.md`
  states on top of this block (an env file to copy into the worktree, who may push `main`) still
  apply; where the two disagree, name it in the echo and follow `CLAUDE.md`.
- **File absent** → the adapter defaults in the provider reference (Trello `next` = leftmost
  list; start/review/done resolved by name).

## Words after the ref — test level and comments

One word at the end of the call covers every card in it, a drain included. They are read by
`python3 .claude/scripts/test-level.py words <the arguments>` (the global
`~/.claude/scripts/test-level.py` where the project has no copy), which returns the level, the
comment switch and the arguments without them:

- **Test level** — nothing said = `stage2`; «جاهز» / `ready`; «من غير تيست» / `no-test`; «تيست
  كامل» / `full`. What each runs, and where the commands come from (`.claude/testing.json`), is
  [`templates/snippets/test-level.md`](../templates/snippets/test-level.md). `/task` echoes it with
  the resolved spec, passes it to the routed command as `--test=<level>`, sets it in the card's
  worktree before the dispatch and clears it after. Every level still writes the tests the routed
  command requires.
- **«من غير كومنت» / `--no-comment`** — no finish comment on the card and no comment on the PR; the
  PR body is the card link alone. Status moves still happen. Default: comments on, as below.
- **Nothing about local testing reaches the card or the PR**, at any level: what ran on this
  machine goes in the run's report to the person — one line per card, `<key> — tests: stage 2 —
  PASS` — and in the audit line.
- A red stage stops that card (§ *If the run halts after the card was marked*); its PR is never
  opened. Under `ready`, the ready mark goes on the tested commit (a GitHub commit status, never a
  PR label: a label would stay on the PR through later, untested pushes), in this order — a push to
  a PR that is ready for review starts CI before any mark can land: an already-open PR of this card
  (a `fixLists` card returning) becomes a draft (`gh pr ready <n> --undo`) → push → `test-level.py
  mark` → open the PRs, or `gh pr ready <n>`. A failed push or a refused mark still ends with the PR
  ready; CI then runs stage 1 itself.
- No `testing.json` → the level is echoed as not configured and changes nothing; the comment word
  still applies.

## Drain mode (`next --drain`)

Runs the full Phase 1–7 lifecycle once per card, sequentially, re-reading the pick lists before
each card (a human may have moved one meanwhile). **A card is built only when its latest brief
is approved and has no open question** (§ *Refine mode*). Any other card is refined (brief posted,
moved to `waitIn` when it has questions) and the drain goes on to the next one. Running `/task
refine` first and answering once is the fast path. **One card is closed — committed, written back,
audited — before the next is fetched.** Stops when:
- the pick lists are empty → print the per-card summary and end;
- **any card halts** (§ *If the run halts after the card was marked*) → stop the whole drain; a
  halted card moved back to its list would be picked again and loop forever;
- `--max=N` cards were done (default **5**) — a long unattended run compounds one bad routing.

**Cards in parallel** happen only when the person asks for them; a drain on its own is
sequential. Each card still gets its own branch and PR. Every agent's brief names the other
cards in flight and the files and flows they touch. Two cards on the same flow (a call to an
outside service, stock moves, permissions) are told about each other, and each PR body names the
seam between them.

## Refine mode (`refine`) — understand every card before any code

A card built on an assumption comes back from QA. A question asked after the build is a question
the owner had to answer twice. `refine` does the understanding for the whole batch first, and
builds nothing.

1. **Read every card in the pick lists**, the same way Phase 1 reads one: description, every
   comment, attachments, labels.
2. **Study each card** with [`study-before-build.md`](../templates/snippets/study-before-build.md):
   - the business rules of its area;
   - what exists in the code, and a precedent to follow;
   - every place the change applies;
   - existing data or new only;
   - conflicts with today's rules.

   Cards in the same batch that touch the same flow are read together, and each brief names the
   other.
3. **Write the study once** to `ops-local/refine/<card-key>.md` (gitignored; `study-before-build.md`
   § 10), so the build and its design start from it instead of searching again.
4. **Post the brief on each card** as one comment that opens «الخطة» / «Plan» in the card's
   language: the brief from `study-before-build.md` § 6, questions included. A card that already
   carries a brief is re-briefed only when a human commented after it.
5. **A card with open questions** moves to `waitIn`. A card without any stays where it is.
6. **One page for the person**, in the chat and in `ops-local/refine/<YYYY-MM-DD>.md`:
   - every card's three-line brief;
   - all the questions grouped by card;
   - the cards ready to build.

   The person can answer and approve in one reply.
7. **Record the answers.** An answer given in the chat is posted on its card as a comment
   («إجابة» / «Answer», naming who answered). The card's brief is updated, and it moves back to
   its pick list. An answer that settles a business rule is written to `ai/business-rules.md` and
   `ai/business-rules-history.md` (`study-before-build.md` § 7).
8. **Approval.** Under `planApproval: person`, a brief is approved by the person's OK in the chat
   (posted on the card as `✓ الخطة متوافق عليها — <who>, <date>`), or by a human comment after the
   brief that approves it, or by a human moving the card from `waitIn` back to a pick list after
   answering.

A drain builds only cards whose latest brief is approved and has no open question. It refines any
other card it meets, then moves on to the next one.

## Add mode (`add <source>`) — turn a plan or a report into cards

Every audit, `/roadmap` plan and `/walk-scenarios` sheet ends in a list of work, and nothing put
that list on the board. `add` does. It creates cards and does no code work, so the lifecycle below
(Phase 1–7) does not run.

1. **Source.** A file is read whole: a spec, `ai/roadmap/plan.md`, an audit report, or
   `ai/scenarios/<flow>.md`. Pasted text works too.
2. **Split** into one card per item that ships on its own:
   - one roadmap step or one user story;
   - one audit finding — sibling sites that share one fix are one card;
   - one BREAKS case of a scenario sheet. An `untested` case on money, stock, status or
     permissions is a test card.

   Leave out what the source marks done, refuted, `n-a` or a point to check.
3. **Each card** is written in the board's language (read three of its cards first):
   - **title** — what to do, imperative;
   - **description** — why, citing the source line and the evidence `file:line`, then what to
     change;
   - a **`## Acceptance Criteria`** section, one testable line per criterion. It is the section
     `/task` reads back as AC ([`task-providers.md`](../templates/integrations/task-providers.md)
     § AC parsing);
   - a **work-type label** from `labelRoutes` (Bug, Feature, UI/UX) plus the area labels the board
     already has. Never invent a label;
   - a **priority label** from `priorityLabels`, only when the source carries a severity;
   - **dependencies** as `After: <card title>`;
   - a closing **source line**: `Source: <path>:<line>`.
4. **Duplicates.** Search the board's open cards in every list for the same item: the same
   evidence `file:line`, or a near-identical title. A match is skipped and listed as
   `already on the board: <card url>`.
5. **Confirm once.** Show the cards (title, labels, target list) and the skipped duplicates, then
   ask once. `--yes` skips the question. Cards are visible to the whole team.
6. **Create** in `task-flow.json`'s `addTo` list. Without it, use the board's first list that is not
   in `pickFrom`. New cards never land in a pick list on their own: a pick list is approved work,
   and a drain would start them unreviewed. The provider's **create** verb is in
   `task-providers.md`.
7. **Record.** In a source file this run may edit (under `ai/`), append ` → <card url>` to each item
   that became a card, so running it again skips them. Then append one line to `ai/_history.md`:
   `<iso> /task add <source> → <n> cards (<list>), <k> skipped as duplicates`.

## Status mode (`status [--since=7d]`) — where the work stands

A project manager's read of the week, from the board, the PRs, CI and the deploys. It is
read-only: it moves no card, posts nothing and writes only its report.

1. **Board.** Read every list in `task-flow.json`'s flow (pick lists, `start`, `review`, `addTo`,
   and Done when it exists):
   - the cards that moved in the window;
   - the cards in `start` longer than the window, as **stuck**;
   - the cards in `review` that the tester sent back (a `fixLists` card returning).
2. **PRs.** `gh pr list --state all --search "updated:>=<since>"`:
   - opened, merged and closed;
   - open with a failing check, or not mergeable;
   - open longer than the window with no review.
3. **CI and deploys.** The last run on each `git.prTo` branch, red or green. The deploys in the
   window, from the deploy ledger (`ai/runtime/deploys.md`) or the release tags, plus every revert
   or hotfix commit on the release branch.
4. **Delivery numbers**, each computed from the records above, never estimated:
   - **lead time** — card start move to its PR merged into the release branch, the median of the
     window;
   - **deploys** — how many reached the release branch's environment;
   - **change failure** — deploys followed by a revert or a hotfix, of all deploys;
   - **time to restore** — a hotfix's merge minus the bad deploy's time, the median.

   A number with no record behind it prints `not recorded`, never a guess.
5. **Risks**, ranked:
   - a stuck card on a money, stock, status or permission path;
   - a red CI on a `prTo` branch;
   - a PR that conflicts with its target;
   - a card the tester returned twice.

Print it in the language the person writes in, short enough to read in a minute. Write it to
`ops-local/status/<YYYY-MM-DD>.md`. `ops-local/` is gitignored; add it to `.gitignore` the first
time. Scheduled: `/schedule` → "every Sunday 09:00, run `/task status`".

## Phase 1 — Understand (resolve the task)
1. **Resolve provider** from `<ref>`:
   - URL → match host (`trello.com`→trello, `*.atlassian.net`/`/browse/`→jira, `linear.app`→linear, `app.clickup.com/t/`→clickup, `github.com/.../issues/`→github).
   - Prefix → `jira:` / `linear:` / `trello:` / `clickup:` / `gh:`.
   - Bare key shape → `PROJ-123`→jira, `ABC-123`→linear, `#42`→github (current repo).
   - `next` or bare → the provider of `.claude/task-flow.json` if it names one (`"provider"`), else the **single task-provider MCP present in `.mcp.json`** — or the single provider with creds in `.env` (trello/jira/linear/clickup/github). If more than one is configured and the ref is ambiguous → ask which provider (one question).
2. **Load credentials from `.env`** (the MCP server is spawned at editor startup and may have been launched without the provider vars in its environment → it will 401 with empty creds). Before any provider call, make the creds available to this session's shell:
   ```bash
   [ -f .env ] && set -a && . ./.env && set +a    # exports TRELLO_*/JIRA_*/LINEAR_*/CLICKUP_* for direct API calls
   ```
   This does NOT retroactively fix an already-spawned MCP's environment — that's what the fallback in step 3 is for.
3. **Establish a WORKING provider connection** (MCP-first, REST-fallback — never halt while valid `.env` creds exist):
   - Probe the provider MCP (ToolSearch for its tools, then a cheap auth check — e.g. Trello `get_health` / a whoami call). **Exception:** an adapter that names REST as its primary channel (ClickUp — its MCP is OAuth-only and capped per day) uses REST whenever its token is set, and the MCP only without one.
   - **MCP healthy** → use it for fetch + write-back.
   - **MCP missing, OR returns 401 / auth failure / 0% health** → do NOT halt. Fall back to the provider's **direct REST API via Bash** using the `.env` creds loaded in step 2 (Trello: `curl "https://api.trello.com/1/cards/<id>?key=$TRELLO_API_KEY&token=$TRELLO_TOKEN&..."`; Jira/Linear: their REST/GraphQL endpoints). Fetch AND write-back both work over REST. Note in the run summary that REST fallback was used (so the user knows to fix the MCP env via `set -a; source .env; set +a` before relaunching).
   - **Only halt** if there is no provider MCP AND `.env` has no creds for the resolved provider → "Provider `<x>` not configured: add its creds to `.env` and run `/setup-project` (or `detect-mcp.sh --apply`)."
4. **Fetch + normalize** to the canonical **TaskSpec** over whichever channel works (MCP or REST), using that provider's adapter (field map in the reference doc). Read title, description, checklist/sub-issues, attachments metadata, labels, **every comment**, current status, and the status-flow target names. Trello does not return comments with the card — fetch them separately (`/cards/<id>/actions?filter=commentCard`), oldest first.
5. **Read the comments as part of the requirements**, on every card in every list — people clarify, narrow and add scope in comments far more often than they edit the description:
   - A human comment that clarifies, adds or changes what is wanted is requirement text — it joins the description and can add AC.
   - **Conflict → the newest human statement wins** over the description and older comments; the brief names the conflict and which one was followed. A conflict no statement settles is a question in the brief, before any code.
   - **`/task`'s own earlier comments** (they end with the reference line, or open with a commit SHA in the older format) are history — what was tried and where it stopped — never new requirements. They post under the token owner's name, so the author alone does not tell them apart.
   - Questions in comments that nobody answered → they join the brief's questions; the card is not built until they are answered.
   - Links and Drive files in comments are attachments (Phase 3).
6. **Study, brief, approval — before the start-move, for every card, refined or not.** Run [`study-before-build.md`](../templates/snippets/study-before-build.md) on the card (Phase 3 reads feed it). Write the study and the brief to `ops-local/refine/<card-key>.md`, so the plan is in a file before anyone approves it. The build copies them into `ai/features/<YYYY-MM-DD>-<slug>/` (`brief.md`, `study.md`). The card has an approved brief with no open question → go on. Otherwise:
   - **a single card in a session:** print the brief and wait for the person's OK or answers;
   - **in a drain:** post the brief on the card (§ *Refine mode*) and take the next card.

   **No assumption ever fills a gap**: a gap is a question in the brief, and the card waits. A card refined earlier on this machine reuses `ops-local/refine/<card-key>.md` when no human comment came after it, and is not studied again (§ 10).

## Phase 2 — Organize (decompose)
```
0. ENV       — load .env creds; pick MCP if healthy, else REST fallback (never halt with valid creds)
1. RESOLVE   — provider + fetch + normalize → TaskSpec
2. INGEST    — download attachments, read specs/screenshots
3. PLAN      — AC + subtasks → ordered worklist; classify intent (feature/fix/refactor/audit)
4. MARK      — write-back: move source to "In Progress" (unless --no-writeback)
5. BRANCH    — with task-flow.json `git`: cut the card's branch (and worktree) from branchFrom; `test-level.py set <level>` there
6. EXECUTE   — route the synthesized description to /do, with --test=<level>
7. VERIFY    — check each AC / subtask against the change; `test-level.py run` at the level; run .claude/scripts/gate-check.py --local when the project has one
8. CLOSE     — under `ready`: open PR → draft, push, `test-level.py mark`, then PRs opened / made ready — else push + one PR per `git.prTo` target; comment summary + commit/PR on the source unless «من غير كومنت»; move to Review (Done only on gate-check PASS)
```
All provider reads AND write-backs use the same channel resolved in Phase 1 (MCP if healthy, else REST over `.env` creds).

## Phase 3 — Retrieve (ingest context)
- **ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../templates/snippets/phase-3-always-reads.md).
- **Attachments** → download to `.claude/tasks/<provider>-<key>/` and classify. Before the first download, check `git check-ignore -q .claude/tasks/`; if it is not ignored, append `.claude/tasks/` to `.gitignore` — card screenshots are working copies of the tracker's files, never source:
  - image (png/jpg/gif) → **design/repro reference** (feed to UI work; if it's an error screenshot, treat as the bug repro).
  - `.md`/`.txt`/`.pdf`/`.docx` → **spec** (read fully; its content is part of the requirements).
  - code/diff/`.json`/`.csv` → **reference data / fixtures**.
- **Google Drive links** (attachment URLs or links in the description: `drive.google.com/file/d/<id>`, `open?id=<id>`) → fetch `https://drive.google.com/uc?export=download&id=<id>` into the same folder. A response that is an HTML sign-in page, not the file, means the link is not shared as "Anyone with the link": record it as unreadable, carry on, and say so in the write-back comment so the card owner can re-share it. Never ask for Google credentials.
- **Description and comment links** to other cards/issues → fetch titles for context (do NOT recurse into doing them). Images and Drive links posted in comments are attachments, same rules as above.
- **Does the card overturn an earlier decision?** State the card's rule in one sentence ("a marketer's order counts once the carrier confirms it"). Search the tests and `ai/decisions/` for its key nouns, and read what they assume. A test or ADR that asserts the opposite is a conflict: ask ONE question per conflict before the start-move, naming the test or ADR and the line — "the card says X; `<spec file>:<line>` pins Y; which holds?" A conflict found at the release gate costs a re-gate; found here it costs one question. None found → say `Prior decisions: none contradicted` in the echo and go on.
- **Has a PR target already changed these files?** With a `git` block whose `prTo` names a branch
  other than `branchFrom` (cut from `origin/main`, PR into `staging` too), list the files the plan
  will touch and run `git log <branchFrom>..origin/<target> -- <files>`. For each file the target
  changed, read the target's version (`git show origin/<target>:<file>`). Name in the plan every
  rule that exists only on the target and that the card must respect. The branch is still cut
  from `branchFrom`. None → say `Target-only changes: none` in the echo.

## Phase 4 — Generate (execute the work)
- Synthesize a single, faithful description from `title` + `description` + the requirement-bearing `comments` + `acceptanceCriteria` + `subtasks` + attachment findings — verbatim intent, not paraphrased away; where a comment overrode the description, the comment's version is the one dispatched. Name the card's labels in it (`Labels: Bug, Database`) — the area labels are the only place that context survives.
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
- **`--to=<command>`** (pin the target) → skip `/do` routing; dispatch the synthesized description **directly** to `/<command>` (must exist in this repo). Without `--to`, the target is picked in this order: a `fixLists` card → `/fix-bug`; the first `labelRoutes` match → its command, dispatched exactly as `--to` would; otherwise **dispatch to `/do`** so it routes to the right specialist (`/add-feature`, `/fix-bug`, `/enhance-ui`, `/optimize`, …). `/task` does NO code work itself.
- **`--to=` naming a level-D command** (its frontmatter carries `disable-model-invocation: true` — deploy, rollback, provisioning, the mutating migration commands, `/delegate`, `/setup-project*`) is NOT dispatched: the Skill tool refuses it, and a human types those (H3). Run Phase 1–3 as normal, then print the exact `/<command> <synthesized description>` for the user to type and end the run without write-back — the same hand-back `/do` performs.
- If the task obviously spans multiple specialists (e.g. "add endpoint AND its UI"), run them in dependency order; record each in the worklist.
- **With a `git` block** (§ *Board flow*), the card's branch — and its worktree — is cut before the dispatch, and the routed command runs inside it. A card that re-enters from `fixLists` and already has its branch reuses that branch, recreating the worktree from it, instead of cutting a second one.

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
   SHA(s) already made. Under «من غير كومنت» skip the comment and put the same three facts in the report. A card silently stuck In Progress is worse than a failed one — it reads
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
- **Under «من غير كومنت»** neither finish comment below is posted, and no halt comment either; the moves still happen, and the report to the person carries what the comments would have said, questions included.
- **On finish — only after Phase 6 has run.** The finish write-back reports what Phase 6 validated; it never precedes it, and a card is never moved on the strength of "the routed command said done". Post the **tester comment** via the adapter's comment verb, in the card's language. Questions are not asked here: they were asked in the brief, before the build.

  **The tester comment.** Its reader is the tester, not a developer, and it is short — read in a minute, no paragraph of background:
  1. What changed in one plain line (for a bug, the cause in one plain sentence). No commit SHA and no "will reach the server with the next deploy" here — the review list already says it is not deployed.
  2. The per-AC ✓/✗ checklist from Phase 6.
  3. **«How to test»** — numbered steps in the product's own UI: where to go, what to do, what should happen. Include the edge case the fix is about (the input that used to break) and any data the tester needs.
  4. Checks — **only what a tester can act on**, and never what ran on this machine (§ *Words after the ref*). A passing suite is not mentioned: test counts, file counts and "failed before / passes after" belong in the commit message and `ai/_history.md`. A failing or skipped check gets one line saying what failed. gate-check's `verdict:` line appears only when the project has `gate-check.py`; **no gate script → no verdict line**, since «verdict: UNVERIFIED» on a shared board reads to a tester as "not verified" (the missing gate goes in the local audit line).
  5. Last, one small reference line: the commit SHA(s) or PR link (`Ref: e88913e4d`, in the card's language) — with a `git` block, the branch name and each PR link. It is for the developer who checks whether the deployed build carries the fix when a tester reports it still broken. Tick completed checklist items / close sub-issues.

  **A question that appears only during the build** — something the code showed that no reading could — stops the card before the finish move. Post it in a **questions comment**: it opens «أسئلة» / «Questions», then one numbered question per line, each answerable with a word or a choice. Then move the card to `waitIn` (or leave it In Progress, with the branch pushed), **never to review**. A card does not reach the review list carrying an open question, and nothing is built on «افترضت».
- **Move** to `statusFlow.review` by default (a human verifies). Move to `statusFlow.done` only when ALL hold: `task-flow.json` does not set `done: null`; `--review-only` is NOT set; Phase 6 validated every AC ✓; and `python3 .claude/scripts/gate-check.py --local` ended `verdict: PASS` for the committed change (evidence in `.claude/evidence/<sha>/`). A `FAIL` or `UNVERIFIED` verdict moves to Review with that line in the comment; a project with no `gate-check.py` moves to Review with no verdict line — never to Done either way. **Never delete** a card/issue.
- **Write-back is post-execution — the work is already done and committed.** A failed status move / comment post (MCP error, REST 4xx/5xx, network) must NOT lose the work or leave the user without a record. When write-back fails AFTER execution:
  1. Do NOT halt silently and do NOT retry-loop forever (one retry max).
  2. **Print the exact comment body** that failed to post (the 1-line summary + commit SHA(s)/PR link + per-AC ✓/✗ list) so nothing is lost.
  3. **Print the exact command the user can run to post it manually** — the same channel that was being used: the MCP tool call args, OR a ready-to-paste `curl`/REST command using `.env` creds (e.g. Trello `curl -X POST "https://api.trello.com/1/cards/<id>/actions/comments?key=$TRELLO_API_KEY&token=$TRELLO_TOKEN&text=<body>"`; Jira/Linear comment endpoints similarly). Include the status-move command too.
  4. **STILL append the local audit line** (below) with a `writeback=FAILED(<reason>)` marker so the history reflects reality — the execution happened even though the source wasn't updated.
- Append a local audit line to `ai/_history.md` (**create the file with a `# Task history` header if absent** — never assume it exists): `<iso> /task <provider>:<key> → /<routed-command> → <review|done>` (on write-back failure, append ` writeback=FAILED(<reason>)`; with no `gate-check.py` in the project, append ` gate=none`; with a `git` block, append ` branch=<branch>`, plus ` pr=FAILED(<reason>)` when a push or PR was refused; with a `testing.json`, append ` tests=<level>:<PASS|FAIL|none>`).

## Phase 6 — Validate (verify against the card)
Runs BEFORE Phase 5's finish write-back: the on-start move happens before the work, the on-finish move waits for this phase.
- Each `acceptanceCriteria` item → checked against the actual change (test, run, or inspection). Empty AC → verify the title's intent is satisfied.
- Tests run green (or explicitly report which fail) — with a `testing.json`, exactly the stages the test level names, via `test-level.py run`, and no more. Attachment-derived specs honored (e.g. screenshot layout matched).
- When the project has `.claude/scripts/gate-check.py`, run `python3 .claude/scripts/gate-check.py --local` once the change is committed and keep its last line (`verdict: PASS | FAIL | UNVERIFIED`) — it is the only verdict that can move the card to Done. No gate script → nothing to run and nothing to report on the card; the card stops at Review. The routed command's own "COMPLETE" is a claim; the gate's verdict is evidence.
- The write-back comment's ✓/✗ list must reflect reality — never report an unmet AC as met.
- When the brief says a business rule changes, the commit updates `ai/business-rules.md` in place and appends to `ai/business-rules-history.md` (`study-before-build.md` § 7); otherwise the card is not done.

## Phase 7 — Improve (feed the loop)
- If the same provider+pattern recurs, suggest `/task next` looping or a scheduled drain.
- If a card was under-specified (empty AC, vague title) and needed a question, note it — the fix is in the ticket-writing, and `/analyze-task` writes the next one studied.
- New provider needed? Point to the extension steps in the task-providers reference.

## Hard rules
- **One task at a time.** `<ref>` resolves to exactly one card/issue; `--drain` runs cards sequentially, each closed before the next is fetched, unless the person asked for them in parallel (§ *Drain mode*) — never several cards in one change.
- **`next` takes only from the pick lists.** With a `task-flow.json`, a card outside `pickFrom` is never picked, and `done: null` is never overridden by a passing gate. `priorityLabels` reorder the pick lists; they never add a list to them.
- **Never merges.** With a `git` block, `/task` cuts the branch, pushes it and opens its PRs; merging any of them is a human's release call.
- **The full run only when named.** No level, no red stage and no missing command ever turns into `full`; and local test results never go on the card or the PR.
- **Read adapters, don't hard-code.** Provider field maps + status verbs come from `templates/integrations/task-providers.md`; tool names are discovered at runtime.
- **Never delete; never silently downgrade.** Write-back moves forward (start→review→done) or comments; destructive ops are out of scope.
- **Validate before write-back; Done needs a passing gate.** The finish move follows Phase 6, defaults to Review, and reaches Done only on gate-check `verdict: PASS` with every AC ✓. A card in Done that no gate passed tells the board the work was verified when it was not. The tracker comment is written for the tester: how to test it, and only the checks they can act on — no gate script, no verdict line. Questions go in their own comment after it, never inside it.
- **Understand first, build second.** No card is built on an assumption, none before its brief is approved, and none reaches the review list with an open question (§ *Refine mode*).
- **Faithful execution.** The routed description preserves the card's intent verbatim — no scope drift, no silent omission of AC, and no human comment left unread.
- **Secrets stay in `.env`.** `/task` reads creds only via the provider MCP's env; it never prints or echoes tokens.

## Failure modes

- **Run halts after the card was marked In Progress** → the card is sitting on a shared board claiming work is in flight. Comment what stopped it, move it back unless commits exist, and state both the card's position and the local state. See § *If the run halts after the card was marked* — this is the one failure whose blast radius is other people.
- **Provider MCP missing or 401 (stale/empty env)** → do NOT halt; load `.env` and use the REST fallback (Phase 1 step 3). Halt only when there is ALSO no `.env` creds for the provider.
- **Ambiguous `next` (multiple providers)** → ask which provider (one question).
- **Project has no `gate-check.py`** → not a halt and not a verdict: the comment carries no verdict line, the card stops at Review, and `ai/_history.md` notes `gate=none`.
- **Card not found / no access** → halt; surface the provider's error verbatim.
- **Empty description AND empty AC AND vague title** → the brief says what is missing, its questions ask it, and the card waits in `waitIn`.
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

/task next --drain
→ task-flow.json: pickFrom [Fixing, Approved] · review=Testing · done=null
  → Fixing: "Login rejects valid OTP" (tester comment = repro) → /fix-bug … → Testing
  → Approved: "Export attendance as CSV" [Feature, API] → labelRoutes → /add-feature … → Testing
  → pick lists empty → 2 cards done, 2 in Testing

/task next --drain جاهز
→ Test level: ready (from «جاهز»)
  → each card: stage 1 + stage 2 green in its worktree → pushed → commit marked `tested-locally` → PRs opened
  → report: trello:#231 — tests: stage 1 + stage 2 — PASS · trello:#232 — tests: stage 1 + stage 2 — FAIL at stage 2 (halted, card moved back)

/task https://trello.com/c/aB12cD34 من غير تيست من غير كومنت
→ Test level: no-test · comments off → tests written, none run here → no card comment → Review

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

/task refine
→ 9 cards in Approved studied · 6 briefs ready · 3 with questions (moved to On Hold)
  → one page: each card's brief in three lines + 5 questions → the person answers and says «تمام»
  → answers posted on the cards, 2 rules written to ai/business-rules.md → /task next --drain builds the 9

/task add ai/scenarios/return-request.md
→ 2 BREAKS + 1 untested refund case → 3 cards [Bug ×2, Test ×1] for Backlog · 0 already on the board
  → confirmed → created → each sheet row gets " → <card url>" · ai/_history.md: 3 cards (Backlog)

/task status
→ last 7 days · 9 cards moved (4 to Testing, 2 returned) · 2 stuck in In Progress > 7d
  → PRs: 6 merged, 3 open (1 failing check) · CI: staging green, main green · 2 deploys, 0 reverted
  → lead time 3.5 days (median) · risks: the stuck refund card (money path), PR #61 conflicts with staging
```

## Flags
| Flag | Effect |
|---|---|
| `--drain` | With `next`: work the pick lists card by card until empty, a card halts, or `--max`. |
| `refine` | Study every card in the pick lists, post each one's plain brief and questions, move cards with questions to `waitIn`, print one page of all of it; builds nothing (§ *Refine mode*). |
| `add <source>` | Turn a plan, spec, audit report or scenario sheet into new cards in `addTo` (§ *Add mode*); no code work. `--yes` skips the one confirmation. |
| `status [--since=7d]` | Where the work stands: board moves, stuck cards, PRs, CI, deploys, lead time and change failure from records, ranked risks (§ *Status mode*). Read-only. |
| `--max=N` | Cap a drain at N cards (default 5). |
| `--prompt-only` | Fetch + normalize, then **print a paste-ready prompt and stop** — no `/do`, no execution, no write-back. Hand-off mode. |
| `--to=<command>` | Dispatch directly to `/<command>` instead of routing through `/do` (command must exist in this repo). |
| `--no-writeback` | Execute, but don't touch the source (no status move, no comment). |
| `--review-only` | On finish, stop at the Review state — never auto-advance to Done. |
| `--test=<level>` · «جاهز» · «من غير تيست» · «تيست كامل» | Test level for every card in the call: `stage2` (default), `ready`, `no-test`, `full`. See `templates/snippets/test-level.md`. |
| `--no-comment` · «من غير كومنت» | Post no comment on the card or the PR; moves still happen. |

## Related
- **Routes to**: `/do` (which dispatches to `/add-feature`, `/fix-bug`, `/enhance-ui`, `/optimize`, …).
- **Backed by**: provider MCPs wired in `scripts/detect-mcp.sh` (trello / jira / linear / github), gated on each repo's own `.env` creds.
- **Reference**: [`templates/integrations/task-providers.md`](../templates/integrations/task-providers.md) — canonical TaskSpec + adapters + extension steps.
- **Next**: `/merge-to <target>` — typed by whoever releases; merges the PRs this command opened after checking them together.
- **Sibling**: `/do` is intent→command routing; `/task` is source→spec→execute→write-back. `/task` uses `/do` under the hood.
