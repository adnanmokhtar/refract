---
purpose: Contract first, judged last — write ai/runs/<run>/acceptance.json and its failing tests BEFORE production code, lock them, build, then let the verifier grade the contract at HEAD. COMPLETE only from a fresh PASS verdict.json. Shared by the add-feature commands, /fix-bug and /verify-plan.
---

# Acceptance contract — written before the code, graded by someone else

Done is written down before the code exists, as a finite list the builder cannot edit, and it is
decided by an agent that did not build. Five steps; each leaves a file a script can check.

## 1. Open the run

Run id: `<YYYYMMDD>-<slug>-<4hex>` (`date -u +%Y%m%d`, a kebab slug of the feature, 4 hex chars of
`sha1(slug + timestamp)`). Create `ai/runs/<run_id>/`. The directory is committed with the change:
the contract, its lock, the verdict and the reviews are reviewable product knowledge, and CI re-checks
them (`gate-check.py` G0, G1 acceptance, G7 review). Evidence logs stay in the git-ignored
`.claude/evidence/`.

## 2. Write the contract — from the requirement, never from the code

`ai/runs/<run_id>/acceptance.json`, shape `.claude/schemas/acceptance.schema.json`:

```json
{
  "schema": "refract/acceptance/v1",
  "run_id": "20261002-refund-button-a1b2",
  "source": {"kind": "spec", "ref": "specs/SPEC-0042-refunds.md"},
  "tier": "standard",
  "criteria": [
    {"id": "AC-001", "req": "US-2", "kind": "integration", "negative": true,
     "ears": "IF a user requests a refund for an order of another tenant THEN THE refunds API SHALL return 403 and create no refund",
     "tests": [{"path": "tests/refunds.test.ts", "name": "refuses a foreign tenant's order"}],
     "command": "npx vitest run tests/refunds.test.ts"}
  ],
  "unchanged": ["Refunds already issued keep their amounts and status"]
}
```

- **One EARS sentence per criterion** (`WHEN … THE … SHALL …`, `IF … THEN … SHALL …`, `WHILE …`),
  traced to the spec's AC-ID or the request. Every story gets at least one failure-path (`IF … THEN`)
  criterion. A criterion a test cannot decide is not a criterion yet — sharpen it or ask.
- **Source:** the spec's acceptance criteria (spec path), the confirmed requirements (heavy tier's
  Phase-1 output), the bug report (`kind: regression`, see /fix-bug), or the plan's Goal criterion.
  Never the implementation plan's internals: the contract states what the user observes.
- `unchanged` lists existing behaviour the change must not alter (refunds already issued, the list
  endpoint's shape). The verifier FAILs an unlisted change to any of them.

## 3. Write the acceptance tests and see them fail

For each criterion write the named test **before** production code, at the level `kind` says, with
an assertion that states the EARS response — not a status code standing in for a body, not
`toBeDefined`. Run them through `.claude/hooks/test-lane.sh record '<command>'`: each must be **red
for the reason the criterion names** (missing behaviour), and the record lands in
`.claude/evidence/test-runs.jsonl`. `.claude/scripts/oracle-check.py --files=<test files>` must
report nothing.

## 4. Lock

`.claude/scripts/lock-acceptance.sh <run_id>` — hashes `acceptance.json` and every named test into
`.claude/locks/<run_id>.json`. From here `test-lock.sh` denies edits to them. Heavy tier: present
the contract at the confirmation gate and lock **after** the human confirms; standard tier: lock
before Generate. Building against an unlocked contract is not allowed.

**SPEC_CONFLICT.** If, while building, a locked criterion turns out to contradict the requirement or
another criterion — so no correct implementation can pass it — **stop**. Report
`SPEC_CONFLICT: <AC-id> — <the requirement it contradicts> — <evidence>` and end the run
`BLOCKED`. Do not edit the test, weaken the assertion, special-case the test input in production
code, or skip it. A human decides: either the code is wrong (keep building) or the contract is
(`lock-acceptance.sh --reopen <run_id> --reason=…` — a permission prompt the human approves — then
the editor it names changes the contract and re-seals it).

## 5. Judge — the verifier, never the builder

After the build and the command's own validation, dispatch `@verifier` with the
[delegation brief](delegation-brief.md) — paths and a mode, nothing else:

```text
run_id: <run_id>
mode: acceptance
contract: ai/runs/<run_id>/acceptance.json
diff: <base>..HEAD · touched: <paths>
requirement: <spec path / tracker id / "request" + the quoted ask>
return: one JSON object, schema refract/verdict/v1, last in the final message
```

`persist-verdict.sh` validates and stamps its answer into `ai/runs/<run_id>/verdict.json`. Read that
file — not the subagent's prose:

| verdict.json | Run status |
|---|---|
| `PASS`, fresh, signed `verifier` | **COMPLETE** may be reported |
| `FAIL` | fix the code (never the locked tests), re-run, re-dispatch — at most 3 fix loops (`THR-LOOP`), then `INCOMPLETE` with the failing criteria |
| `CONCERNS` (a criterion UNVERIFIED) | `INCOMPLETE`, naming the criterion and what would let it run |
| missing, or STALE (a path changed after the verdict) | not judged — re-dispatch; never report COMPLETE |

`gate-check.py` re-checks the same file at Stop and in CI: G0 (lock intact), G1 acceptance (verdict
present, valid, fresh, PASS), G15 signer (the verdict's signer is not among the change's authors).

When `.claude/agents/verifier.md` is not installed, the axis is `UNREVIEWED(acceptance)` and the run
is `INCOMPLETE` — the builder never grades its own contract.
