---
purpose: The rules every command that fans work out to parallel agents follows — how many, where each writes, what stays with the orchestrator, and how a dead agent's work is recovered.
---

# Agent fan-out — the rules for a parallel wave

A wave of agents fails in three ways a single session does not: it burns the usage limit in an
hour, one death loses everything the agent knew, and two agents touching the same shared thing
undo each other. These rules are for every command that dispatches agents in parallel.

## How many

- The command's own cap (`--max-parallel`, default 5) is the ceiling, never the target: no more
  agents than the work has independent units.
- **Near the usage limit, three.** A rate-limit warning in this session, or the person saying the
  limit is close, drops the cap to 3 for the rest of the run. A wave that dies on the limit costs
  more than a slower one that finishes.

## Each agent writes as it goes

- Every agent appends each finding or result to **its own file** the moment it has it —
  `<run dir>/agents/<agent-id>.md` — not in one block at the end. An agent that dies then loses
  the item it was on, not the wave.
- The brief names that file. The orchestrator merges the files after the wave; agents never write
  to a shared ledger directly.

## Shared state stays with the orchestrator

Agents read, write code in their own worktree, and run what is theirs alone. They never:

- commit, push, merge or touch a branch other than their own worktree's;
- run the e2e suite or migrations against a shared database;
- regenerate snapshots, ratchet / ceiling files, lockfiles or other generated files many changes
  meet in — those are built once, by the orchestrator, after the wave;
- run a formatter or fixer in write mode on paths outside their own change.

When an agent must run something heavy, its brief gives it its own lane — a test database name, a
port offset, `isolation: worktree` — and the run goes through `test-lane.sh`.

## Recovering a dead agent's work

On resume (or after a wave where an agent never returned), before re-dispatching:

1. Read every `<run dir>/agents/*.md` — the dead agent's findings so far are there.
2. List the agent worktrees (`git worktree list`) and check each with `git -C <path> status
   --porcelain`. Uncommitted work in one is the dead agent's half-finished change: carry it on,
   or save it as a patch before removing the worktree — never delete it unread.
3. Re-dispatch only what is missing, and say what was recovered.
