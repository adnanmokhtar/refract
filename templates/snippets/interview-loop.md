---
purpose: Canonical live-interview loop — close the unknowns by asking the user, instead of recording them as open questions. Used by commands that would otherwise emit an unknown for someone else to resolve later.
---

# Interview loop (close the branch, don't log it)

An open question in an artifact is an unknown handed to whoever reads it next. This block converts
that hand-off into an answer **while the user is still here**. Commands that own a `## Open questions`
section link here to gain an interview mode; they do not restate the loop.

The loop is not "ask a lot of questions". It is: read first, ask only what the source cannot answer,
and stop the moment no remaining branch would change the output.

## 1. Read before asking

Run the command's Phase 3 reads FIRST. Every question the codebase, `ai/`, the tracker ticket, or the
git history already answers is a question that must not be asked.

**Mechanical halt** — asking the user something the retrieved sources state at a citable
`<path:line>`. The interview burns the one resource the artifact cannot regenerate (the user's
attention); spending it on a lookup is the failure this step exists to prevent. Re-read, then ask
only the residue.

## 2. Every question must be load-bearing

A question earns a turn only if you can name **which section of the output changes** depending on the
answer. Write the consequence before writing the question:

```
branch:      refund destination
consequence: ## Scope — IN + ## Data model touchpoints + acceptance criterion 2
question:    Does a refund return to the original card, or to wallet credit?
```

**Mechanical halt** — a question whose `consequence:` is empty, is the whole artifact, or is
"context". Delete it before asking. Curiosity is not a consequence, and a question that changes
nothing spends the user's attention for no artifact difference.

## 3. Ask in rounds, not in a stream

- Group the load-bearing questions into rounds of **at most 4**, related ones together.
- Order rounds by blast radius: a branch that decides the shape of the work comes before one that
  decides a field name. An early answer often deletes three later questions.
- Where the harness offers a structured prompt (`AskUserQuestion` in Claude Code), use it and give
  each option its real consequence, not a label. Otherwise ask in plain prose, numbered.
- Re-derive the remaining branches after each round before asking the next.

## 4. Never answer on the user's behalf

**Mechanical halt** — writing an answer the user did not give. This includes: filling a branch with
the "obvious" choice, treating silence as assent, and reading a partial answer as a complete one.
A branch the user did not close is `DEFERRED`, never `CLOSED`.

An assumption stated back for confirmation (*"I'll assume card-original unless you say otherwise"*)
is only closed once the user answers. Until then it is open, and it is dishonest to draft as if it
were settled.

## 5. Keep a branch ledger

| id | branch | consequence | state | answer / deferral reason |
|----|--------|-------------|-------|--------------------------|
| B1 | refund destination | Scope-IN, Data model, AC2 | CLOSED | original card |
| B2 | who may refund | Auth & permissions | DEFERRED | needs the finance owner, not this user |

Three states only: `OPEN`, `CLOSED`, `DEFERRED(<who or what would close it>)`. A deferral names the
person, document, or measurement that resolves it — "unclear" is not a deferral reason.

## 6. Stopping condition (checkable, not felt)

Stop when **zero branches are `OPEN`**. Not when the user seems satisfied, not after a fixed number
of rounds.

At that point:

- `CLOSED` branches are written into the artifact as decided content, with no hedge left in the prose.
- `DEFERRED` branches — and only those — become the artifact's `## Open questions` rows, each carrying
  its deferral reason and who closes it.
- If a command mandates a minimum count of open questions, the interview **overrides that floor**:
  a question that was asked and answered is not an open question, and re-listing it as one
  misreports a settled decision as an unknown.

## 7. Report what the interview cost and bought

```
Interview: <n> rounds, <n> questions asked, <n> branches closed, <n> deferred
Not asked (already in source): <n>   ← the reads did this work
Deferred: <branch> — <who closes it>
```

A run that closes zero branches means step 1 already had the answers; say so rather than padding the
transcript.

## Failure modes

- **Interviewing instead of reading** — the residue after Phase 3 is the question set, not the whole topic.
- **Consequence-free questions** — asked because they sound thorough; deleted by step 2.
- **Streaming one question at a time for twenty turns** — rounds of ≤4, re-derived between rounds.
- **Silence read as assent** — step 4's halt.
- **Draft written before the ledger is clear** — a `CLOSED` row is a precondition for the section it feeds.
- **Deferrals with no owner** — becomes an unknown again the moment the artifact is read.

Commands that use this block SHOULD link here instead of pasting these steps verbatim — use a path
relative to your command file (e.g. `../templates/snippets/interview-loop.md` from `commands/`).
