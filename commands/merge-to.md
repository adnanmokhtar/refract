---
description: Merge open PRs into the branch a person names, after checking what they break together — migration order, conflicts, the tests the incoming diff reaches, an overlap review. Typed by a person only.
compatibility: Requires git and an authenticated `gh` for the repo, and PRs open against the target. Reads .claude/task-flow.json (git.branchFrom, git.prTo, git.conflictBranch) and .claude/testing.json (stage1, stage2) when present; runs the testing pack's coverage-gap skill when it is installed.
kind: command
pack: orchestration
version: 1.0.0
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
disable-model-invocation: true
---

# /merge-to <target> [<PRs, in numbers or words>] [--dry-run]

Merge the PRs you name into `<target>` (an integration branch such as `staging`, or the release
branch such as `main`), after checking what they break **together** — with each other and with
what the target already holds. Every PR passed its own tests; a defect that exists only in the
combination has no test that could fail, and nobody looks across PRs until they share a branch.
This command is that look, run at the moment you decide to merge.

**Level D** (`disable-model-invocation: true`): only a person types it. `/do` prints it and never runs
it. Typing it is the word to merge the PRs it names. It is not the word to deploy, to
run the full test, or to close other PRs — those stay yours.

**Applies phases: 1–7** (Phase 4 = merge; the review in Phase 3 is read-only).

## When to use / NOT to use
- USE: "merge the five card PRs into staging", "staging is ready, merge it to main", "merge #41 and
  #44 into staging". Merges may be days apart and in any order.
- NOT: opening the PRs — `/task` does that per card. NOT: deploying or releasing — the project's
  deploy commands, on your word. NOT: reviewing one PR's own code — `/review-changes`.

## The target is the memory

No state file. Every check compares the incoming PRs with what `origin/<target>` holds at that
moment, so a merge today sees every merge before it, however long ago, whichever session made it.
`git log` over the target and its merge commits is the record of what each earlier PR changed.

## Phase 1 — Understand (what comes in, where it goes)
1. `git fetch --prune origin`. Everything below runs in worktrees outside the shared checkout,
   which is never switched, so a session's uncommitted work there is never touched.
2. **Target** — `<target>` as typed. With `.claude/task-flow.json`, `git.prTo` names the branches
   in promotion order (`["staging", "main"]`); a target outside it → say so in the echo and go on.
3. **Incoming PRs** — said in numbers or in words, in any language:
   - **numbers** (`#41 44`) → those PRs, no question;
   - **words** → resolved to PRs, then the list (number, title, branch) is shown and confirmed
     once before Phase 2:
     - «اللي فتحتها» / "the PRs you opened" → in the session that opened them, the PRs it opened;
       in a new session, the open PRs into the target whose head branch a `/task` line in
       `ai/_history.md` names (`branch=<branch>`), from the last run unless a day is said;
     - card links or keys → the PRs whose head branch those cards' `/task` lines name;
     - «كله» / "all" → every open, non-draft PR into the target;
   - **nothing** and the target is a later `prTo` entry (the release branch) → the earlier entry,
     as ONE merge: its open PR into the target, or one opened now;
   - **nothing** otherwise → list the open, non-draft PRs into the target, with their checks, and
     ask once: all, or which.
4. For each PR: `gh pr view <n> --json number,title,headRefName,baseRefName,isDraft,mergeable,statusCheckRollup,body,files`.
   A draft, a base other than the target, or a failing required check → that PR is left out and
   named in the report; the rest go on.
5. **Echo** in 4–6 lines: target and its tip SHA, the PRs in, the PRs left out and why, and which
   carry migrations.

## Phase 2 — Organize (order, then the combined tree)
**Migrations decide the order.** Find the project's migrations in the folders its stack uses
(`prisma/migrations/`, `db/migrate/`, `database/migrations/`, `<app>/migrations/`,
`alembic/versions/`, `V<n>__*.sql`, `migrations/`). Two kinds:
- **Ordered by name** (a timestamp or number prefix, applied in sort order — Prisma, Rails,
  Laravel, Knex, TypeORM, Flyway, golang-migrate): merge the PRs that carry migrations in the order
  of their migration names. Before each merge, check on the combined tree that every incoming
  migration sorts after every migration the target already holds. One that would sort before
  → rename it on the PR's branch (a new prefix, the same body), push, check again. **Never edit or
  rename a migration the target already holds** — an environment may have run it.
- **Ordered by a graph** (each migration names its parent: a `dependencies` list, Alembic's
  `down_revision`): the order is inside the files. Check the combined tree has one head per chain
  (`alembic heads`, `manage.py makemigrations --check --dry-run`). Two heads → the tool's own merge
  migration, on the merge branch of the PR that made the second head.

PRs without migrations follow, in the order given.

**Build the combined tree** in a worktree outside the shared checkout: `git worktree add --detach
<dir> origin/<target>`, then merge each incoming PR's head into it in that order. It is never
pushed; it is what the tests and the review read. A PR that does not merge cleanly here goes
through § *Conflicts* first, and its merge branch is what goes in.

### Conflicts
A PR that does not merge cleanly into the target as it stands now is resolved on its own branch,
never on the PR's branch (the target's history would ride into the PR's other targets):
1. Cut `merge/<branch>-into-<target>` (`git.conflictBranch` when set) from `origin/<target>`, in
   its own worktree.
2. Cherry-pick the PR's own commits — `git cherry-pick $(git merge-base <branch> <branchFrom>)..<branch>`.
   The merge branch's PR then shows only this PR's change and its resolutions; merging the branch
   would also show every commit of `<branchFrom>` the target does not have yet.
3. Resolve file by file, reading both sides of each hunk. **Never one generic text rule across
   files** (take ours, take theirs, one search-and-replace): on one real board that rule merged two
   entries of a locale file into one and dropped a key.
4. **Generated files are regenerated, never hand-merged** — API schemas, OpenAPI documents,
   generated wire or client types, lockfiles — with the project's own generator.
5. **A count both sides bumped from the same base** (a version, a ratchet or baseline count, a
   numbered list) merges silently to one side's number. Recount it from disk.
6. Run the specs of every resolved file, the locale key parity (every locale file has the same
   keys), the migration order above, and the whole-repo static checks (testing.json `stage1`, or
   the project's lint, type check and build). Static checks alone do not prove a resolution.
7. Push the merge branch and open its PR into the target. Its body names the original PR and how
   each conflicted file was resolved. It replaces the original PR from here on.

## Phase 3 — Retrieve (test and review the combination, before anything merges)

### Combined test
Run, on the combined tree, the tests the incoming diff reaches — testing.json `stage2` with its
base set to `origin/<target>`. Never `full`: the full run is your word, not this command's. No
`testing.json` → the project's test runner limited to the tests of the changed files where it can
select them, and the report says what ran. No way to select → `Combined test: not configured`, and
nothing runs.

A red combined test stops the run before any merge. § *Where a fix goes* decides the branch.

### Changed and untested
When the project has the testing pack's `coverage-gap` skill (`.claude/skills/coverage-gap/`), run
it in `--diff` mode on the combined tree with `BASE_REF=origin/<target>`, so it reads the incoming
changes only and stays fast. Each changed branch or condition that no test executes is reported as
a **changed and untested** point. It does not block by itself; you decide. Not installed → the
report says `coverage-gap: not installed (testing pack)`.

What it cannot see: a scenario nobody coded. Missing handling has no line to be uncovered — the
review below is for that. On the board this command came from, 5 of 6 defects found in the
combination had no test that could fail, and one had no line of handling at all.

### Overlap review (read-only)
For each file and function an incoming PR touches, find the earlier PRs on the target that touched
it: `git log --first-parent origin/<target> -- <file>` from the PR's merge base, each merge commit
mapped to its PR (`gh pr list --state merged --search <sha>`). For each pair — incoming × earlier,
and incoming × incoming:
- state each one's intent in one sentence, from its PR body or card;
- read the shared path end to end on the combined tree and check that both intents still hold;
- look hardest at shared flows: a call to an outside service, stock or balance moves, permissions,
  a status machine fed by callbacks or polls, retries. Events that arrive late or out of order (a
  status for a record since voided, replaced or re-sent) and a rule that exists on only one branch
  (one PR built on the release branch, the other's rule added on the integration branch) were where
  the combination failed.

Report a **finding** only with a concrete scenario: the inputs or state, the wrong outcome, who it
hits, how big. Anything without one is **a point to check**. When the session can start agents,
give each overlapping pair to its own agent with both diffs and both intents, not this run's guess.

### Where a fix goes
- **A defect of ONE PR** (wrong even alone) → fixed on that PR's own branch, so its other PRs carry
  the fix too. Then the combined tree is rebuilt and Phase 3 runs again for it.
- **A defect only in the COMBINATION** → a `fix/<what>` branch cut from the target after the PRs
  merge (they coexist only there), with a test that fails before the fix, and a PR into the target.
  It is reported open; you merge it with another `/merge-to`.
- **A resolution slip** → fixed on the merge branch before it merges; once merged, a small fix
  branch from the target.

Fixes go through `/fix-bug` where the project has it. A point to check is reported, never fixed.

## Phase 3.5 — `--dry-run`
Stop here: print the order, the conflicts and how they would be resolved, the combined test, the
changed and untested points and the review. Under `--dry-run`, Phase 2's renames and merge
branches stay in local worktrees: nothing is pushed or merged, no PR is opened, and the worktrees
are removed here.

## Phase 4 — Generate (merge)
In the Phase 2 order, for each PR (its merge-branch PR where § *Conflicts* made one):
1. Check again that it merges cleanly into the target as it now stands; the target moves with each
   merge.
2. `gh pr merge <n> --merge` when the repo allows merge commits (`gh repo view --json
   mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed`): the merge parents keep the record the
   next run reads, and the later promotion does not replay the commits. Otherwise the method the
   project's `CLAUDE.md` names, else the one the repo allows.
3. A PR replaced by its merge-branch PR gets one comment (`merged via #<m>`) and is closed.

The project's `CLAUDE.md` decides who may merge into a branch. Where it reserves the merge for a
person, print the exact `gh pr merge` lines instead and carry on with the report.

### Target is the release branch
- The incoming is usually the integration branch as ONE merge.
- Check that no PR merged into the release branch alone conflicts with the integration branch's
  migrations or code: an older-named migration on the integration branch that would run after a
  newer one the release branch already ran, or undo it, is renamed on the integration branch first.
- After the merge, list the release branch's open PRs whose content arrived through the
  integration branch (their head is now an ancestor of the target, or `git cherry` finds every
  commit). Close them only on your word.

## Phase 5 — Update (write back)
No tracker writes; `/task` owns the cards. Each merged PR keeps GitHub's merge record. Each fix PR
and merge-branch PR body names what it fixes or resolves. The worktree is removed.

## Phase 6 — Validate
After the last merge, `git fetch` and check that `origin/<target>` holds every merged PR's head or
its cherry-picked commits, and that the migration order still holds on the target itself.

## Phase 7 — Improve
A finding the review made and no test caught → name the test that would have caught it, in the
report. A rule that exists on only one branch and broke a PR built on the other → suggest the
`/task` check that reads the target's version of each file before building.

## What you see
```
/merge-to staging — 4 merged · 1 open fix · ready for your word
Order:     #41 (migration 20261120…), #44 (migration 20261122…), #38, #47
Conflicts: #47 → #52 (merge/fix-sender-into-staging) — locales/en.json resolved per key; openapi.json regenerated
Combined:  stage 2 over the incoming diff — PASS (212 tests)
Untested:  3 changed and untested points — <file:line> · <file:line> · <file:line>
Review:    1 finding — #44 × #38: <inputs> → <wrong outcome>; hits <who>; fix PR #53 (open)
           2 points to check — <one line each>
Not merged: #45 (draft)
Not validated: full test, deploy — yours to start
```

## Hard rules
- **Merges only the PRs the person named or picked.** Never deploys, never runs the full suite,
  never closes a PR the person did not confirm (a PR it replaced with its own merge-branch PR
  excepted).
- **Nothing merges over a red check**: a failing required check, a red combined test, or a broken
  migration order.
- **Never pushes to the target directly.** Every merge goes through a PR.
- **Never edits or renames a migration the target holds.**
- **Never resolves a conflict with one generic text rule.**

## Failure modes
- **`gh` not authenticated or the merge refused** (branch protection, hook) → print the exact
  `gh pr merge` lines, stop, and report what merged before it.
- **The target moved during the run** (someone else merged) → rebuild the combined tree and run
  Phase 3 again for the PRs not merged yet.
- **A PR's branch cannot take the rename** (protected, or someone else's fork) → stop on that PR
  and name the migration and the name it needs.

## Related
- `/task` — opens one PR per card into each `git.prTo` target and never merges; this command is
  where those PRs meet.
- `templates/snippets/test-level.md` — what `stage1` and `stage2` run.
- The testing pack's `coverage-gap` skill — the changed-and-untested lane.
