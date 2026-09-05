---
description: Turn the decisions you cannot make alone into a questionnaire for the person who can — each question carrying what it changes, a deadline, and the default that fires if it goes unanswered. Writes a document to send, never a decision.
kind: command
pack: product
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /to-questionnaire [<decision, or path to a brief / interview ledger>]

Package the questions you are blocked on into something another human can actually answer, asynchronously, without a meeting. The output is a file you send. It never answers a question on the recipient's behalf, and it never leaves one open-ended.

## When to use / NOT to use

- USE: an interview left `DEFERRED` branches naming someone else as the owner (see [`templates/snippets/interview-loop.md`](../../../snippets/interview-loop.md)).
- USE: a brief is blocked on a legal, finance, security, or commercial answer nobody on the team holds.
- USE: the same question keeps being re-litigated in chat because no one wrote down what turns on it.
- NOT: to interrogate the person already in the session — that is the interview loop, run inline, and it is cheaper than a document.
- NOT: to gather evidence from users at scale — that is research; `/synthesize-research` handles the corpus.
- NOT: to record a decision already made — that is an ADR (`/add-adr`).
- NOT: to ask something the repository answers. Phase 3 exists to catch exactly that.

## Phases applied

1-3 + 4 + 5. **Phase 6 is deliberately absent**: a questionnaire cannot be validated by inspection, only by whether the answers that come back are usable. Phase 7 is the return: answers land, and the branches they close are written into the artifact that was blocked.

## The Premise (read this first, internalize, do not deviate)

**A question with no stated consequence will not be answered.** People deprioritise questions whose stakes they cannot see. Every question in the output names the decision it unblocks and what changes each way.

**The recipient must be able to answer it.** A question aimed at the wrong role is worse than no question: it costs a round trip and returns a guess wearing an authority's name.

**An unanswered question must still resolve.** Every question carries a deadline and a **default that fires** if the deadline passes. A questionnaire with no defaults converts one blocked decision into an indefinite wait, which is the failure this command exists to prevent.

**Never fill in an answer.** Not a suggested one presented as chosen, not silence read as agreement. The recipient's words or the stated default — there is no third source.

## Phase 1 — Understand

Establish, before writing a single question:

- **Recipient and role.** One named person or one named role — not "the business", not "stakeholders". If the answer set spans two roles, that is two questionnaires.
- **What you are blocked on.** The artifact that cannot be finished: a brief, a spec, a prompt, an ADR.
- **Return format.** Prose, a picked option, a number, a yes/no — state it per question so the reply is usable without a follow-up.
- **The by-when**, and what happens at that date.

**Mechanical halt** — recipient unnamed, or named as a group. Ask who specifically, or halt. A questionnaire addressed to everyone is answered by no one.

## Phase 2 — Organize

Collect the candidate questions from the source: the interview ledger's `DEFERRED` rows, the brief's open questions, the assumption ledger's `fatal × high` rows, or the user's description.

Then **cut**, in this order:

1. Drop every question the repository answers — Phase 3 confirms this.
2. Drop every question whose answer changes nothing you can name.
3. Merge questions that share one underlying decision.
4. Order by what unblocks the most: an early answer often deletes three later questions.

**Mechanical halt** — more than 10 questions survive. That is not a questionnaire, it is a meeting agenda, and it will be skimmed. Split it by decision, or cut to the ones that actually block.

## Phase 3 — Retrieve

- [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md) — the universal block.
- `ai/core/glossary.md` — write the questions in the project's own vocabulary; a question phrased in engineering jargon returns a guess.
- `ai/product/briefs/` + `ai/product/assumptions.md` — the blocked artifact and its ranked unknowns.
- `ai/decisions/` — a question already settled by an ADR is not a question; cite the ADR back instead of re-asking.
- The interview ledger, when the caller passed one — its `DEFERRED` rows are the input set, and their stated owner is the recipient check.

Every question that survives Phase 3 must be one the retrieved sources **do not** answer. Record how many were dropped here; that count is the command's cheapest output.

## Phase 4 — Generate

Write `ai/product/questions/<YYYYMMDD>-<slug>.md`:

```markdown
# <Decision this unblocks> — questions for <name / role>

**Blocked artifact**: <path> — <what cannot be finished without these answers>
**Return by**: <YYYY-MM-DD>  ·  **Format**: reply in this file / in thread / 15-min call
**If unanswered by that date**: <what proceeds, on which default — stated once, up front>

---

### Q1. <the question, in the project's own vocabulary>

- **Why it is being asked**: <the decision it unblocks, one sentence>
- **What changes**: <option A → this happens> · <option B → this happens instead>
- **Answer shape**: pick one / a number / yes-no / a paragraph
- **If you do not answer**: <the default that fires> — <its consequence>

> _Your answer:_

### Q2. …
```

Rules for the questions themselves:

- **One decision per question.** A question containing "and" is usually two.
- **No leading.** *"We should probably refund to the original card, right?"* is not a question; it is a request for agreement. State the options neutrally with their consequences.
- **No jargon the recipient does not use.** Translate through `ai/core/glossary.md`, in their direction.
- **Options must be exhaustive or say they are not.** Add "something else — what?" wherever the list may not be complete.
- **The default must be a real default** — the thing that will genuinely happen, not a threat used to force a reply.

## Phase 5 — Update

- Write the questionnaire file.
- In the blocked artifact, replace each open question with a pointer: `→ asked in ai/product/questions/<file>#Q<n>, due <date>, default: <x>`. An open question that is out for answer is not the same as an unknown nobody has touched, and the artifact must say which it is.
- Append unanswered-by-deadline items to `ai/product/assumptions.md` when the default fires: a default that fired is an assumption the project is now carrying, and it needs an expiry like any other.

## Output format

```
## /to-questionnaire — <slug>

Recipient: <name / role>
Blocked: <artifact path>
Questions: <n> asked · <n> dropped (already answered in repo) · <n> merged
Return by: <date> — defaults stated for <n>/<n>

Written: ai/product/questions/<YYYYMMDD>-<slug>.md
Pointers written back into: <blocked artifact path>

Send it: <the one-line ask to paste alongside the file>
```

## Hard rules

- **Never answer for the recipient.** No pre-filled choice, no "I assume you'd say X". Silence resolves to the stated default, which is a documented consequence, not an answer.
- **Every question carries a consequence, a shape, and a default.** A question missing any of the three is deleted before the file is written, not shipped with a blank.
- **One recipient per file.** Two roles is two files; a shared file gets answered by whoever cares least.
- **≤10 questions.** Past that it is a meeting, and this command has failed to cut.
- **Repository first.** A question the repo answers is a question that must not be asked; Phase 3's dropped count is the proof it was checked.
- **Writes a document, never a decision.** This command does not choose, does not implement, and does not mark anything resolved. The answers do that when they arrive.

## Failure modes

- **Addressed to "the business."** Nobody owns it, nobody answers. Phase 1's halt.
- **Twenty questions.** Skimmed, then answered in one line that resolves nothing. Phase 2's halt.
- **Consequence-free questions** — asked because the writer was curious. They dilute the ones that matter.
- **Leading questions** that return the asker's own preference with someone else's name on it.
- **No default** — the artifact stays blocked and the questionnaire becomes the excuse for the delay.
- **Jargon** — the recipient answers a different question than the one intended, confidently.
- **Answers arrive and nothing is updated** — the blocked artifact keeps its open questions and the round trip bought nothing. Phase 5's pointers exist so the return path is obvious.

## Related

- [`templates/snippets/interview-loop.md`](../../../snippets/interview-loop.md) — produces the `DEFERRED` rows this command packages; a deferral names its owner precisely so it can become a recipient here.
- `/frame-problem` — the brief that is usually what is blocked.
- `assumption-ledger` — its `fatal × high` rows are the highest-value questions to send; fired defaults come back to it.
- `/add-adr` (documentation pack) — where an answer that settles an architectural choice lands afterwards.
- `/refine-prompt --interview` — asks the questions **you** can answer; this command handles the residue you cannot.
