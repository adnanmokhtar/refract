---
purpose: How much a build run tests on this machine — one word from the person running it, read by every build command and by /task, with the commands supplied by the project's .claude/testing.json.
---

# Test level — how much this run tests here

Writing tests and running them are two decisions. **Every level writes the tests the command
requires** — the regression test, the test per acceptance criterion, the negative auth test. The
level decides only which of the project's test commands run **on this machine** before the work is
handed on. The person paying for the run says it in one word, for the whole request or batch.

| Said (at the end of the request) | Level | Runs here |
|---|---|---|
| nothing | `stage2` (default) | the tests the change reaches, against the base ref |
| «جاهز» · `ready` | `ready` | stage 1 (lint, format, typecheck, build), then stage 2 — and, when both ran green on the committed tree, a mark on that commit so CI can skip what already ran here |
| «من غير تيست» · `no-test` | `no-test` | nothing |
| «تيست كامل» · `full test` · `--test=full` | `full` | the project's full run — **only when named** |

«من غير كومنت» / `--no-comment` is read in the same pass; it matters only to commands that post to a
tracker or a PR (`/task`).

## Resolve it — first, before Generate

1. `python3 .claude/scripts/test-level.py words --prose <the request>` (the global
   `~/.claude/scripts/test-level.py` where the project has no copy). It reads the words from the
   **end** of the request only and returns `{level, comment, rest}`; `rest` is the request without
   them. Two levels at once exits 2 — ask which one. Called by `/task`, the level arrives as
   `--test=<level>`.
2. Say it as the run's first line: `Test level: ready (from «جاهز»)`, or `Test level: stage2
   (default)`. A misread word is caught here, not after a full run.
3. `test-level.py set <level>` — the Stop gate (`gate-check.py` G1) reads the level in force for
   this worktree and runs the same stages instead of the whole suite. `test-level.py clear` when the
   run ends, so the next session starts from the default.
4. **No `.claude/testing.json`** → say `Test level: not configured — this command's own test step
   applies` and run the command exactly as it is written. The words change nothing.

## Run it — once the change is complete and committed

`python3 .claude/scripts/test-level.py run` runs the level's stages in order, through
`test-lane.sh` when it is installed, and prints one line: `tests: stage 1 + stage 2 — PASS`,
`tests: stage 2 — FAIL at stage 2`, `tests: none on this machine (no-test)`.

- **A red stage stops the task.** Fix the cause and run the level again, or stop and report what
  failed. Never open a PR, move a card or report success over a red stage this run executed.
- **Never raise the level yourself.** A red stage 2 is not a reason to run `full`; a missing
  stage is reported (`not configured: stage 1`), never replaced by the whole suite.
- **The ready mark goes on the commit, never on the PR.** After a green `ready` run, commit, push,
  then `test-level.py mark`: it posts a GitHub commit status (`context` = `readyStatus`) on HEAD,
  and refuses unless the last run was a green `ready` on exactly HEAD's tree, the tree is clean and
  HEAD is on the remote. A label would not do: it stays on the PR through the next push, and the
  commits after the tested one would ride it untested. A new commit has no status, so CI tests it.
- **Order matters, or the mark saves nothing.** A push to an open, ready-for-review PR starts its
  CI run at once, and GitHub takes a status only on a commit it already has — so a mark posted
  after that push lands after the run began, and stage 1 runs anyway. After a green `ready` run on
  a clean tree: (1) an open PR that is ready for review becomes a draft — `gh pr ready <n> --undo`;
  (2) push; (3) `test-level.py mark`; (4) open the PR, or `gh pr ready <n>` again. A failed push or
  a refused mark still ends with step 4 — CI then simply runs stage 1.
- **A command's own "run all tests" step is this step** when the project has `testing.json`: "all
  tests pass locally", "full suite green" and "re-run the tests" read as "the level's stages pass".
- **While writing**, the one test being written may run on its own while it is shaped. Under
  `no-test` nothing else runs — with one exception: `/fix-bug`'s regression test still runs red
  before the fix and green after, one file through `test-lane.sh record`. Without that red record
  the fix is a claim, and the verifier refuses it ([`fix-bug-core.md`](fix-bug-core.md)).

## Close the standards gate honestly

A baseline row whose evidence is "a test that ran green" closes `MET` only on a run at this level.
Under `no-test` — or a stage the project names no command for — it closes `SKIPPED — unverified:
<the level's stage 2 command>` with `test level no-test` as the reason, and the run ends
**INCOMPLETE (tests not run by request)**. The PR's own checks are where it gets verified.

## Report — to the person, never to the tracker or the PR

One line per task in the run's output: what ran and how it ended (`tests: stage 2 — PASS`). Nothing
about local testing goes in a PR body, a PR comment or a tracker comment: what ran on one machine
is the run's business, not the reviewer's or the tester's.

## Config — `.claude/testing.json`

```json
{
  "stage1": "<the routine checks: lint, format, typecheck, build>",
  "stage2": "<the tests the change since <base> reaches — <base> is replaced>",
  "full":   "<the full run>",
  "readyStatus": "tested-locally",
  "base": "origin/main"
}
```

The commands are the project's; this snippet only decides which run and when. `base` defaults to
`task-flow.json`'s `git.branchFrom`, then `origin/main`.

## The CI side — the project's, shown once

To let CI skip what the mark proves, the project's workflow keeps ONE small job that always runs —
never a job skipped by an `if:` on a label (a skipped required job reports success with nothing
run), never `[skip ci]` or a paths filter on a required workflow (it stays pending):

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
jobs:
  checks:
    if: github.event.pull_request.draft == false
    runs-on: ubuntu-latest
    steps:
      - id: mark
        env: { GH_TOKEN: "${{ github.token }}" }
        run: |
          ok=$(gh api "repos/${{ github.repository }}/commits/${{ github.event.pull_request.head.sha }}/statuses" \
               --jq '[.[] | select(.context=="tested-locally" and .state=="success")] | length')
          echo "skip=$([ "$ok" -gt 0 ] && echo true || echo false)" >> "$GITHUB_OUTPUT"
      - if: steps.mark.outputs.skip != 'true'
        uses: actions/checkout@v4
      - if: steps.mark.outputs.skip != 'true'
        run: <stage 1 — the same command as testing.json>
```

A draft runs nothing, so the push in step 2 above costs no minutes; `ready_for_review` runs the
job once the mark is there. A marked commit costs one short job; anything else gets stage 1. The mark is an honour system —
anyone with write access can post a status — which suits a team that trusts its own machines and
pays for CI minutes out of pocket. When CI is cheap, run it on every commit instead.
