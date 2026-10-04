# Contract block — what an agent takes, returns and may touch

Every agent (and every orchestrated command) carries one `## Contract` section, near the top, as a
fenced `yaml` block. It replaces eight verdict vocabularies with one, says where the output goes,
and makes the tool list checkable: `scripts/lint-agent-contract.sh` reads it.

```yaml
role: judge                     # judge | proposer | writer
                                #   judge    — grades code or findings; holds no Edit/Write
                                #   proposer — returns a design, ranking or plan; holds no Edit/Write
                                #   writer   — writes exactly the paths in output.writes
inputs:
  required: [scope]             # what the caller MUST pass — paths and ids, never narrative
  reads:    [<path or glob>]    # what the agent reads to do the job
  never:    [<path>]            # judges: what it must not read (the builder's ledger, PR text)
output:
  returns:  <named block | findings.schema.json | verdict.schema.json>
  writes:   none                # or [<path>, …] — a declared write needs the Write (or Edit) tool
  persisted_by: caller          # or hook:persist-review.sh → ai/runs/{run_id}/reviews/{agent}.json
skills:     []                  # skills the body RUNS — needs the Skill tool or a `skills:` preload
status:     DONE | INCOMPLETE | BLOCKED | NEEDS_INPUT | SPEC_CONFLICT | UNREVIEWED(<axis>)
verdict:    PASS | CONCERNS | FAIL
severity:   IMPORTANT | NIT | PRE-EXISTING
next:       <who owns the follow-up>
```

## The one vocabulary

| Field | Values | Display aliases an agent may keep printing |
|---|---|---|
| `verdict` | `PASS` · `CONCERNS` · `FAIL` | APPROVE→PASS · REQUEST_CHANGES→CONCERNS · BLOCK→FAIL · GO→PASS · GO-UNVERIFIED→CONCERNS · NO-GO→FAIL · READY→PASS · NOT-READY→FAIL |
| `status` | `DONE` · `INCOMPLETE` · `BLOCKED` · `NEEDS_INPUT` · `SPEC_CONFLICT` · `UNREVIEWED(<axis>)` | — |
| `severity` | `IMPORTANT` · `NIT` · `PRE-EXISTING` | BLOCKER/HIGH→IMPORTANT · LOW/STYLE→NIT |

- **`NEEDS_INPUT`** replaces "ask the user" inside a subagent: a subagent cannot ask, so it returns
  `NEEDS_INPUT` with the exact question and the options, and the main session asks.
- **`SPEC_CONFLICT`** is the implementer's abort when a locked acceptance test and the requirement
  disagree — the alternative to bending the test (`acceptance-contract.md`).
- **`UNREVIEWED(<axis>)`** is what a missing reviewer produces. It is never replaced by the builder
  reviewing its own work; the caller reports INCOMPLETE.
- A proposer's verdict is usually omitted — it proposes; the judge grades.

## What the lint checks (`scripts/lint-agent-contract.sh`)

1. The block is present (ratcheted across the roster; required on every agent that declares one).
2. `output.writes` other than `none` ⇒ `tools:` has `Write` or `Edit`.
3. `skills:` non-empty ⇒ `tools:` has `Skill`, or the frontmatter preloads them with `skills:`.
4. `role: judge` or `role: proposer` ⇒ no `Write`, `Edit`, `MultiEdit` or `NotebookEdit`.
5. Frontmatter declares `model:`.

Numbers an agent applies (nit caps, loop caps, regression thresholds) are cited by id from
`governance/thresholds.json`, not restated in the contract.
