---
purpose: The study every build or spec command runs before it writes code or a card — what exists today, where else the change applies, what it conflicts with, the questions in one list, and a plain brief the person approves.
---

# Study before build — understand it fully, then ask once, then build

A task is understood when you can say, in the person's own words, what changes, where, for whom,
and what stays the same. **No assumption fills a gap.** A gap becomes a question, asked before any
code, together with every other question about the task. Nothing is built while a question is
open. A question that appears only during the build stops the work and goes back to the person;
it is never answered by a guess. A card that reaches QA with an open question was not ready to
build.

Used by:
- `/task`: § *Refine mode* and every single-card run;
- `/add-feature`: P0 step 6;
- `/fix-bug`: Phase 1;
- `/analyze-task` and `/expand-task`.

## 0. Where the files go
- **Under `/task`:** `ops-local/refine/<card-key>/brief.md` and `study.md`. The brief starts with a
  header:

  ```
  card · origin list · status: awaiting answers | awaiting approval | approved | parked at <gate|question|decision>
  approved by <who> <date> (said OK | answers added no work) · gates: <H1/H2 approved by who, date>
  run: <run-id> · worktree: <path>        (only while a build is in progress or parked)
  ```

  The origin list is the pick list the card was in when `/task` took it. It is never `waitIn`: a
  card taken from `waitIn` keeps the origin it had. When the card carries none (filed by
  `/analyze-task`, or rebuilt on another machine), the origin is the card's current list if that is
  a pick list, else the first `pickFrom` list.

  Before the first write, run:

  ```
  git check-ignore -q ops-local/ || echo 'ops-local/' >> .gitignore
  ```

  This folder is local and gitignored, so the shared checkout stays clean. **The board is the
  source of truth; this folder is a cache.** When `brief.md` is missing (another machine, a
  teammate), rebuild it from the card's `/task` comments. The latest Plan comment is the brief,
  the Answer comments are its answers, a ✓ comment is the approval, a Gate comment is a gate
  approval, and the Plan comment's first line names the origin list. A park comment's decision
  cards go into the rebuilt brief under their keys, and an Answer comment that names a card's key
  is its pick (`decide-before-change.md` § 8). `study.md` is not on the card:
  when it is missing, the study is re-run alone, asking nothing new unless it finds something the
  approved brief did not cover.
- **A direct run** (`/add-feature`, `/fix-bug`): `ai/runs/<run-id>/brief.md` and `study.md`. The
  command opens its run before the study.
- **The record, committed with the code** (§ 9): `ai/features/<YYYY-MM-DD>-<slug>/`. Under `/task`,
  `/task` copies `brief.md` and `study.md` into the card's branch before the dispatch. A direct run
  copies them from its run folder. The command that builds writes `design.md` and `acceptance.md`.

## 1. Read the business as it is today
- **`ai/business-rules.md`**: the current rules of the areas the task touches. When the file has no
  section for an area, read that area's rules from the code (§ 2) and note them in `study.md`.
  They are written into the rules files only in the build's commit (§ 8), never while studying.
- **`ai/business-flows.md`** for the flow, and `ai/core/glossary.md` for the words.
- **A rule written there is the business's decision.** It outranks a general idea of how this
  kind of business works. Never replace it with "what a typical ERP or store would do".
- **Only a recorded rule is a decision.** A behaviour the code enforces that no recorded rule
  covers may be deliberate or may be the bug. When a guard, a condition or a default looks
  deliberate, ask "intended?" in the brief. Never decide either way alone.

## 2. Find what exists
For each noun in the task (a screen, a status, a role, a document, an integration):
- the screens, routes and jobs that show it or act on it;
- the rule the code applies today: the guard, the condition, the default;
- **a precedent:** an existing implementation of the same kind, such as a sister integration, the
  same filter on another list, or the same button on another portal. When one exists, the task
  follows it. Say "done like <precedent>" in the brief instead of asking, unless the task says
  otherwise.

Also read, here and not later:
- the task's attachments and linked specs, which are part of what is asked;
- the tests and ADRs that assert something the task would change;
- under `/task` with a `git` block, the rules that exist only on a PR target branch (`/task`
  Phase 3).

## 3. Scope: every place the change applies
List every other place the same thing appears:
- other portals (admin, merchant, marketer, customer);
- other roles;
- other lists, exports, prints and reports;
- the API and the mobile app.

The task names some places. Each one it does not name becomes **one question with the list**:
"also in A, B, C?". Never add a place the task did not ask for. Never leave out one it implies.

For a bug, also run the similar-bugs search here (the literal buggy expression across the code), so
the brief lists every site with the same cause. They are fixed together, as one bug, without a
further question. A site found later with the same literal expression is the same bug, fixed and
listed. A broader or different fix is a question.

## 4. Existing data and existing users
When the change alters behaviour, ask whether it applies to what already exists, or to new records
only:
- accounts, orders, employees and settings created before the change;
- a migration of existing rows, or a default for new ones.

## 5. Conflicts
Compare the change with § 1 and § 2: today's rules, tests and ADRs, and target-only rules. If it
changes something that exists today, the brief says so plainly ("today X; after this, Y") and asks
"intended?". The owner decides; the build never overrides a rule silently.

## 6. The questions and the brief
**Questions:**
- one list, numbered;
- each answerable with a word or a choice: give the options and what each one changes;
- no question whose answer is already in § 1, § 2 or a precedent;
- a question you could not avoid with one more read of the code is a question you did not need.

**The brief** is written in the person's language, plain, no code terms unless asked:

```
<task title>
Problem:      <one line — what is wrong or missing today>
We will:      <one or two lines>
Steps:        1. … 2. …
Not changing: <what stays as it is>
Where:        <the screens / portals / roles it reaches>
Test it:      <how a person checks it>
Questions:    1. … (options)        (none → "none")
```

A small task (one label, one condition) keeps `Problem`, `We will` and `Questions`, and drops the
rest.

**An improvement task** carries its decision card in the brief, after `We will`
(`decide-before-change.md` § 8). That covers performance, refactor, scale, database, architecture
and a new technology, and any task whose solution needs something the project does not run today.
Which option to take is one of the brief's questions, and the brief's approval approves the card.
Under `--yes`, a recommendation that adds no moving part and is not one-way is not an open question
(`decide-before-change.md` § 8).

## 7. Answers and approval
- **Answers go into `brief.md`**: each question gets its answer, who gave it, and when. The brief's
  lines change to match.
- **Approval is the person's OK on the brief as it stands.** An answer can count as approval:
  - **It counts** when it settles only what was asked and adds no work. The revised brief is shown
    back in one line, and the status becomes `approved`. The record says `answers added no work`,
    never that the person said OK; the ✓ comment says so too.
  - **It does not count** when it adds scope, a place or a step. The status becomes `awaiting
    approval`, the revised brief is shown in full, and the run waits for an OK.
- **What makes a brief stale.** Only a human comment that changes what is asked: new scope, a new
  place, a changed requirement. These do not make it stale; they update `brief.md`:
  - a comment that only approves;
  - a comment that only answers the brief's own questions;
  - a gate approval;
  - a tester's comment reporting the approved brief not met.
- **A direct run** (`/add-feature`, `/fix-bug`): print the brief and wait.
- **Under `/task`:** the brief, the answers and the approval are each posted on the card as `/task`
  comments, and recorded in `brief.md`. A card is built only when its status is `approved`.
- **`--yes`:** skips the wait only when the brief has no questions.
- **`--plan`** (`/add-feature`, `/fix-bug`): the study and the approved brief come first. The plan
  file then **embeds** the brief, answers included, and the study's notes in its `## Context`, so
  it stands alone in another tool or on another machine. Its `## Outputs` include the record files
  and, when the brief changes a rule, the two rules files (`plan-flag.md`). The brief is for the
  person; the plan file is for the executor.
- **`/fix-bug --fast`** (typed by the person: production is down): prints a one-line brief and
  skips the wait unless it has an open question. Nothing else skips the wait on its own judgement.
- **No brief at all:** only for a change with no runtime effect, such as a typo or docs.

## 8. Business rules — keep them current
When the approved task adds, changes or removes a business rule, the build's commit updates
**both** files:
- **`ai/business-rules.md`** — the current state. Edit the rule in place, in its area section, with
  where it is enforced (`file:line`). Never leave the old wording beside the new.
- **`ai/business-rules-history.md`** — append only. One line per change:
  `<date> · added|changed|removed · <area> · <rule before> → <rule after> · why · <card> · <branch>`.
  A rule the study read from the code for an area the file did not cover yet is recorded as
  `added · … · (recorded from code)`.

A rule change that leaves **either** file untouched is unfinished. The business reviewers report it
(`@workflow-integrity`, `@domain-model-auditor`, `@business-auditor`).

## 9. Keep the record in the project
The change carries its record in `ai/features/<YYYY-MM-DD>-<slug>/`, committed with the code in the
same branch (`ai/features/_index.md` explains the folder):
- `brief.md` — the approved brief, with every question, its answer and who gave it;
- `study.md` — the study's notes (§ 10);
- `design.md` — how it was built: components, API endpoints, data changes, screens, and why this
  shape. `/add-feature` takes it from its design (from `plan.md` at T1). `/fix-bug` writes the cause
  and what the fix changed, where and why;
- `acceptance.md` — the acceptance criteria. For a bug, the expected behaviour and the regression
  test that pins it.

Then append one line to `ai/features/_index.md`:
`<date> · <title> · <card> · <branch> · ai/features/<YYYY-MM-DD>-<slug>/`.
The PR links live on the card, since a card may open more than one. A later change to the same
feature reads that folder first and adds a new one.

## 10. Study once — the design starts from it
The study is paid for once. Its findings are written down, and everything after it reads them
instead of searching again.
- **`study.md`** holds the evidence the study gathered:
  - each file and line read, and what it showed;
  - the rules of the area;
  - the precedent and its paths;
  - the list of places;
  - the existing data;
  - the conflicts;
  - every question with its answer.

  It is notes with paths, not prose.
- **Reuse:** `@product-analyst` and `@architect` get `ai/runs/<run-id>/study.md` and `brief.md` in
  their dispatch.
  They start from them and read only what the study does not cover. A search it already recorded
  is not run again.
- **When it goes stale:** a study written on another machine is re-run (§ 0). A
  study is refreshed when a human comment changed what is asked (§ 7). `/task`'s own comments
  never make it stale.
- **Size to the task:** read the paths the task's nouns lead to, not the whole codebase. A one-line
  change gets a one-paragraph study.
