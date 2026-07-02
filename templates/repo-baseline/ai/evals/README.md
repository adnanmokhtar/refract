# ai/evals — the measurement half of the learning loop

`ai/dynamic/` **captures** what the AI learns. `ai/evals/` **grades** whether that learning
actually works. Together they close the loop the rest of the `ai/` folder only opens:

```
/learn-from-task  →  notices "AI keeps getting refund-auth wrong"  →  curator promotes a rule
/eval             →  re-runs the refund-auth case  →  PASS ⇒ the rule works
                                                    →  FAIL ⇒ back to ai/dynamic/learnings.md, try again
```

Without evals you can promote a rule and *assume* it helped. With evals you have proof —
and you catch the day a promoted rule silently stops working (a **regression**).

## What lives here

| File | What it is |
|------|-----------|
| `cases/<slug>.md` | one frozen scenario + an answer key + a `guards:` link to the promoted knowledge it protects |
| `cases/_template.md` | the case format — copy it to author a new case |
| `_scorecard.md` | append-only, dated log of every `/eval` run — the regression history |

## The unit: an eval case

A case is a **question with a known-good answer**. It has three parts:

1. **Scenario** — a concrete, self-contained task or question you hand the AI.
2. **Answer key** — checkable assertions: what the correct output MUST include, and MUST NOT do.
3. **`guards:`** — which rule / convention / pattern this case protects. This is the coverage link:
   a promoted rule with no case guarding it is *unguarded* — nothing proves it works.

See `cases/_template.md` for the exact shape.

## Lifecycle

```
promote a rule (/learn-from-task → curator)
      │
      ▼
/eval --seed          → generates a case stub for the new, unguarded rule
      │
   (you fill in the scenario + answer key)
      │
      ▼
/eval                 → runs every case, scores it, writes a run block to _scorecard.md
      │
   FAIL / REGRESS ────→ appended to ai/dynamic/learnings.md  (loop close)
      │
      ▼
fix the rule or the code → re-run /eval → PASS
```

## How to run it

- `/eval` — run all cases, score, write a scorecard run.
- `/eval --case <slug>` — run one case (fast iterate).
- `/eval --coverage` — read-only: what % of promoted knowledge is guarded, plus stale / toothless cases.
- `/eval --seed` — turn unguarded rules/conventions/failures into case stubs to fill in.

## Auto vs manual — read this before wiring it up

`/eval` is **manual by default**, and that is deliberate. There is **no auto-hook and no cron**
in the baseline (same honesty contract as `/learn-from-task`). You choose when it runs:

1. **Manual** (`/eval`) — start here. Run it by hand after you change a rule or finish a task.
   You stay in control and you learn what the scores mean.
2. **Auto after a task** — once you trust the scores, add a `Stop` hook in `settings.json`
   that runs `/eval` when a task finishes. Now you never forget.
3. **Auto on push (CI)** — run `/eval` in CI and fail the build if coverage or pass-rate drops.
   The team safety net.

Do **not** wire auto on day one — an eval that blocks your work before you trust it is just
friction. Run manual → trust → automate.

## What `/eval` will NOT do

- It never invents a passing scorecard when there are no cases (that would be theater — it halts instead).
- It never edits a case's answer key during a scoring run (you can't grade against a moving target).
- It never promotes anything — promotion is `knowledge-curator`'s job. `/eval` only measures and,
  on failure, writes a raw note to `ai/dynamic/learnings.md` for the curator to pick up.
