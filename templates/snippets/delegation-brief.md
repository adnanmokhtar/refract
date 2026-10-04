---
purpose: How every command dispatches a judge or a review lens — paths and a mode, never the builder's narrative; returns are typed JSON a hook persists. brief-lint (judge-bash-guard.sh) refuses a judge brief that breaks it.
---

# Delegation brief — what a judge or a reviewer is told

A judge given the builder's account agrees with it. Framing a change as safe defeated reviewers on
32 of 33 seeded vulnerabilities; a fresh-context reviewer with no producer narrative finds more than
one that shares the producer's context (architecture proposal `[A §2 #1]`). So a brief to a judge is
**paths and a mode** — the files to read, the contract to grade — and nothing that tells the judge
what to conclude.

## 1. The brief

```text
run_id: <YYYYMMDD>-<slug>-<4hex>            # ai/runs/<run_id>/ exists before the dispatch
mode: acceptance | refute                    # verifier only; a review lens names its lens instead
lens: <correctness | performance | a11y | data | observability | security-<lens> | …>   # reviewers
contract: ai/runs/<run_id>/acceptance.json   # acceptance mode
candidates: ai/runs/<run_id>/reviews/*.json  # refute mode (or one named file)
diff: <base>..HEAD (or "working tree vs <base>") · touched: <path>, <path>, …
requirement: <spec path / Spec-ID / tracker id>   # the source the contract came from
protocol: .claude/templates/snippets/refute-before-report.md (+ precedents/<domain>.md)
return: one JSON object, schema refract/verdict/v1 (judge) or refract/findings/v1 (lens), last in the final message
```

That is the whole brief. Every value is a path, an id or an enum. The judge reads the files itself.

## 2. Never in a brief (brief-lint)

`.claude/hooks/judge-bash-guard.sh` lints every `Agent`/`Task` dispatch whose `subagent_type` is a
judge (default: `verifier`) and **denies** it when the prompt:

- cites the builder's own record — `ledger.md`, `ai/status.md`, `ai/dynamic/changelog.md`, a
  session log;
- cites commit messages, `git log` output or PR text;
- carries narrative — "I implemented / added / fixed / verified…", "we built…";
- asserts the outcome — "all tests pass", "should now work";
- frames the change — "is correct / safe / done", "safe to merge", "just confirm", "no issues";
- names no `run_id` or no `mode`;
- runs past 4,000 characters (a brief is a list of paths, not an account).

A reviewer lens is held to the same brief by this snippet (the hook lints judges only, because the
judge's verdict is what decides "done"). Rewrite a denied brief; never route around the lint by
dispatching the judge under another agent type.

## 3. The return

- **≤ 2K tokens of prose** around **one JSON object**, last in the final message. The prose is for
  the human; the JSON is the record.
- The agent holds no Write tool and writes no file. The SubagentStop hook persists the object —
  `persist-verdict.sh` → `ai/runs/<run_id>/verdict.json` (refute mode: `verdict-refute.json`);
  `persist-review.sh` → `ai/runs/<run_id>/reviews/<agent>-<lens>.json` — after validating it
  against `.claude/schemas/` and stamping **who signed** (the `agent_type` Claude Code put in the
  hook input), **who authored** the change (the edit ledger) and **what was judged** (the blob of
  every touched path). A record that claims those fields itself is refused.
- The dispatcher reads the persisted record, not the subagent's prose: `COMPLETE` comes from
  `verdict.json` saying `PASS`, fresh, signed by a judge — never from a subagent's "looks good".
- A record goes **stale** the moment a path it judged changes. After a fix, re-dispatch the judge;
  `gate-check.py` (G1 acceptance, G7 review) FAILs a stale record.

## 4. Status words the caller may report

`DONE` · `INCOMPLETE` · `BLOCKED` · `NEEDS_INPUT` · `SPEC_CONFLICT` · `UNREVIEWED(<axis>)`.
`SPEC_CONFLICT` is the builder's abort: a locked criterion contradicts the requirement, so the
builder **stops and says so** (criterion id, the requirement it contradicts, the evidence) instead
of bending the code or the test. Only a human reopens a locked contract
(`.claude/scripts/lock-acceptance.sh --reopen`, which test-lock.sh turns into a permission prompt).

## 5. When the judge is not installed

`.claude/agents/verifier.md` ships with the baseline. If it is missing (an older install), the axis
is `UNREVIEWED(acceptance)` and the run ends `INCOMPLETE`, naming the fix
(`apply-baseline-sync.sh --apply`). The builder never grades its own contract in the judge's place.
