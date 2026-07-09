---
description: Rebuild working context fast after /clear or a break. Read mode (default) reconstructs where the branch stands from the handoff note + git state + ai/status.md and prints goal / done / in-flight / next / gotchas. Write mode (`/catchup handoff`) captures that note before you stop. Read-only in the default mode — never edits code.
allowed-tools: [Read, Grep, Glob, Bash, Write]
---

# /catchup

> **Why this exists.** A `/clear` (or closing the laptop) drops the model's working memory, but the *branch* still knows what's going on. `/catchup` reseats a session from durable signals in seconds so you don't re-explain the task. It is distinct from `/learn-from-task` (which persists *durable* project learnings into `ai/` — ADRs, conventions, failures) — `/catchup` is *ephemeral, per-branch, this-task* state, not project knowledge.

## The Premise (read this first)

**Everything needed to resume is already recorded — read it, don't ask.** The handoff note (if one was written), the branch's commits since it forked, the current diff, and `ai/status.md` together reconstruct goal + progress + next step. The agent's job is to *synthesize* those into a tight briefing, not to interrogate the user or start working.

**Default mode is strictly read-only.** `/catchup` reports where things stand and stops. It does not resume the work, edit code, or run the build — the user decides what to do next from the briefing.

## Usage

```
/catchup            # read mode: reconstruct + print the briefing (default)
/catchup handoff    # write mode: capture the current state to .claude/HANDOFF.md
/catchup handoff "tried X, broke Y, use Z"   # write mode with an explicit gotcha line
```

## The handoff note — `.claude/HANDOFF.md`

- Personal + ephemeral: **gitignored** (see `templates/repo-baseline/.claude/.gitignore`), like `CLAUDE.local.md`. It is your note to your next self, not a project artifact.
- Overwritten each `/catchup handoff` — it holds the *current* task, not a log. (Durable history goes to `ai/dynamic/` via the Stop hook.)
- Shape (kept short — every line earns its place):

```markdown
# Handoff — <branch>  (<YYYY-MM-DD HH:mm>)

Goal:      <one line — what this branch is trying to achieve>
Status:    <in-flight | blocked | ready-to-ship>
Done:      <bullet(s) — what's finished + verified>
Next:      <the single next action>
Gotchas:   <"tried X, broke Y, use Z" — the traps worth not re-hitting>
Files:     <the 2-5 files in play>
```

## Read mode — procedure

1. **Handoff note** — read `.claude/HANDOFF.md` if present. It is the highest-signal source; treat it as the spine of the briefing. Note its timestamp — if the branch has moved since (newer commits), reconcile.
2. **Branch state** —
   - `git branch --show-current`; the fork point: `git merge-base HEAD <default-branch>`.
   - Commits since fork: `git log --oneline <default>..HEAD`.
   - Uncommitted work: `git status --porcelain` + `git diff --stat` (and read the actual `git diff` for the in-flight files).
3. **Project status** — `ai/status.md` "Recent Changes" (cross-reference; the session-start hook already surfaces a slice of this).
4. **Reconcile + synthesize** — where the note and git disagree, git wins for *what changed*, the note wins for *why / what's next*. Produce the briefing.

If **no** handoff note exists and the branch has commits/diff, reconstruct from git alone and say so (`(no handoff note — reconstructed from git)`), then suggest `/catchup handoff` for next time.

## Read mode — output format

```
## /catchup — <branch>  (<N> commits ahead of <default>, <M> files dirty)

Goal:        <from note, or inferred from commit subjects + diff>
Status:      <in-flight | blocked | ready-to-ship>   [note: <age of handoff note>]

Done (verified):
- <bullet>  (<sha> / test name)

In flight (uncommitted):
- <file>: <what's mid-change>

Next action:
- <the single most useful next step>

Gotchas:
- <from note; omit the section if none>

Suggested command:
- <e.g. /ship  ·  /fix-bug --plan  ·  keep editing <file>>
```

## Write mode (`/catchup handoff`) — procedure

1. Gather the same git signals (branch, commits-since-fork, diff).
2. Compose the note in the shape above. `Goal` / `Next` / `Gotchas` come from the current conversation; `Done` / `Files` from git + what was verified this session. Fold any explicit `"…"` argument into `Gotchas`.
3. `Write` `.claude/HANDOFF.md` (overwrite). Confirm the path + a one-line preview. **This is the only mode that writes**, and it writes exactly one gitignored file.

## Hard rules

- **Read mode never edits, never resumes the work, never runs the build.** Briefing only.
- **Reconstruct, don't interrogate.** Ask the user only if git + note are both empty (nothing to catch up on) — then say so plainly.
- **The handoff note is gitignored and overwritten**, never committed, never appended into a growing log. Durable knowledge belongs in `ai/` via `/learn-from-task`.
- **Git wins for facts, the note wins for intent** when they disagree.

## Failure modes

- Treating a stale handoff note as current when the branch moved past it (prevented — reconcile against `git log` and stamp the note's age).
- Dumping raw `git log` instead of synthesizing goal/next (the briefing must interpret, not transcribe).
- Committing `HANDOFF.md` (prevented by the gitignore entry).
- Confusing `/catchup` with `/learn-from-task` and writing task-ephemera into `ai/` (per-branch state stays in the note).

## Related

- `/learn-from-task` — the durable-knowledge sibling: persists ADRs / conventions / failures into `ai/` before `/clear`. Use it for lessons; use `/catchup handoff` for "where am I."
- `session-start.sh` hook — surfaces branch + status every session automatically; `/catchup` is the on-demand deep version.
- `/ship` — when the briefing says `ready-to-ship`, that's the next command.
