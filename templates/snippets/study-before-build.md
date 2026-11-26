---
purpose: The study every build or spec command runs before it writes code or a card — what exists today, where else the change applies, what it conflicts with, the questions in one list, and a plain brief the person approves.
---

# Study before build — understand it fully, then ask once, then build

A task is understood when you can say, in the person's own words, what changes, where, for whom,
and what stays the same. **No assumption fills a gap.** A gap becomes a question, asked before any
code, together with every other question about the task. A card that reaches QA with an open
question was not ready to build.

Used by `/task` (§ *Refine mode* and every single-card run), `/add-feature` (P1), `/fix-bug`
(Phase 1), `/analyze-task` and `/expand-task`.

## 1. Read the business as it is today
- **`ai/business-rules.md`**: the current rules of the areas the task touches. When the file is
  missing, or has no section for an area, read that area's rules from the code (§ 2) and add them
  to the file in the same change (§ 7).
- **`ai/business-flows.md`** for the flow, and `ai/core/glossary.md` for the words.
- **A rule written there is the business's decision.** It outranks a general idea of how this
  kind of business works. Never replace it with "what a typical ERP or store would do".

## 2. Find what exists in the code
For each noun in the task (a screen, a status, a role, a document, an integration):
- the screens, routes and jobs that show it or act on it;
- the rule the code applies today: the guard, the condition, the default;
- **a precedent:** an existing implementation of the same kind, such as a sister integration, the
  same filter on another list, or the same button on another portal. When one exists, the task
  follows it. Say "done like <precedent>" in the brief instead of asking, unless the task says
  otherwise.

## 3. Scope: every place the change applies
List every other place the same thing appears:
- other portals (admin, merchant, marketer, customer);
- other roles;
- other lists, exports, prints and reports;
- the API and the mobile app.

The task names some places. Each one it does not name becomes **one question with the list**:
"also in A, B, C?". Never add a place the task did not ask for. Never leave out one it implies.

## 4. Existing data and existing users
When the change alters behaviour, ask whether it applies to what already exists, or to new records
only:
- accounts, orders, employees and settings created before the change;
- a migration of existing rows, or a default for new ones.

## 5. Conflicts
Compare the change with § 1 and § 2. If it changes a rule that exists today, the brief says so
plainly ("today X; after this, Y") and asks "intended?". The owner decides; the build never
overrides a rule silently.

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
Steps:        1. … 2. …            (small task: one line, no list)
Not changing: <what stays as it is>
Where:        <the screens / portals / roles it reaches>
Test it:      <how a person checks it>
Questions:    1. … (options)        (none → "none")
```

A small task (copy, one label, one condition) gets the first three lines only.

## 7. Business rules — keep them current
When the approved task adds, changes or removes a business rule, the same change updates:
- **`ai/business-rules.md`** — the current state. Edit the rule in place, in its area section, with
  where it is enforced (`file:line`). Never leave the old wording beside the new.
- **`ai/business-rules-history.md`** — append only. One line per change:
  `<date> · added|changed|removed · <area> · <rule before> → <rule after> · why · <card> · <PR>`.

A diff that changes a rule and leaves both files untouched is unfinished. The business reviewers
report it (`@workflow-integrity`, `@domain-model-auditor`, `@business-auditor`).

## 8. Approval before code
The person approves the brief before any code is written:
- **A direct run** (`/add-feature`, `/fix-bug`): print the brief and wait.
- **Under `/task`:** the brief is posted on the card, and the card is built only once its brief is
  approved (`/task` § *Refine mode*).
- **`--yes`:** skips the wait only when the brief has no questions.
- **No brief at all:** only a change with no runtime effect (a typo, copy, docs).

## 9. Keep the record in the project
Once the brief is approved, the change carries its record in `ai/features/<YYYY-MM-DD>-<slug>/`,
committed with the code in the same PR (`ai/features/_index.md` explains the folder):
- `brief.md` — the approved brief, with every question, its answer and who gave it;
- `design.md` — `/add-feature`'s design: components, API endpoints, data changes, screens, and why
  this shape;
- `acceptance.md` — the acceptance criteria;
- `study.md` — the study's notes (§ 10).

Then append one line to `ai/features/_index.md`. A later change to the same feature reads that
folder first and adds a new one.

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
- **Where it lives:** `/task refine` writes it to `ops-local/refine/<card-key>.md`, which is
  gitignored and so leaves the shared checkout clean. The build copies it into
  `ai/features/<YYYY-MM-DD>-<slug>/study.md`. A direct `/add-feature` or `/fix-bug` writes it
  straight into the run.
- **Reuse:** the design phases (`@product-analyst`, `@architect`, and `@api-architect` (backend pack)
  or `@ui-architect` (frontend pack) when installed)
  get `study.md` in their brief. They start from it and read only what it does not cover. A search
  it already recorded is not run again. A study on another machine, or one a human comment has
  since overtaken, is refreshed, not trusted.
- **Size to the task:** read the paths the task's nouns lead to, not the whole codebase. A one-line
  change gets a one-paragraph study.
