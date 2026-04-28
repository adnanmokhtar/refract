# Drift log

Findings where current code DIVERGES from documented conventions / rules / ADRs. Surfaced by `convention-drift-detector` agent or `/detect-drift` command.

## Why this exists

Drift is silent rot. A rule says "always use `Repository` suffix"; a new file uses `Service` instead; nobody notices; six months later half the codebase is inconsistent. This file forces the divergence into the open + tracks resolution.

## Format per entry

```
### <YYYY-MM-DD> — <one-line summary>
Source: `convention-drift-detector` agent | manual | CI check
Severity: low | medium | high
Type: code-vs-rule | rule-vs-reality | rule-vs-rule | unclear

Finding:
<concrete file:line evidence>
Rule violated / convention diverged: <link to rule or convention>

Possible resolutions (pick ONE):
- [ ] FIX CODE — bring code into line with rule. Owner: ____. Target: ____.
- [ ] UPDATE RULE — code is right; rule is stale. Update `<rule>` to match. ADR if material.
- [ ] DOCUMENT EXCEPTION — both right; this case is special. Write ADR documenting the exception.
- [ ] REJECT FINDING — false positive (e.g., generated code, intentional test fixture).

Status: OPEN | IN_PROGRESS | RESOLVED → <action taken> | REJECTED
```

## Severity rubric

- **High**: security / correctness / cross-tenant safety violation. Fix immediately.
- **Medium**: convention divergence visible to multiple developers; technical-debt accruing. Schedule.
- **Low**: cosmetic; can wait for batched cleanup or live with it.

## Lifecycle

1. Agent or `/detect-drift` finds divergence → appends entry, `OPEN`.
2. Reviewer triages, picks a resolution path.
3. Resolution executed; entry marked `RESOLVED` with the action.
4. Resolved entries archived monthly (move to `ai/audits/drift-resolved-YYYY-MM.md`).

## See also

- `ai/conventions.md` — what conventions are documented.
- `.claude/rules/` — what rules exist.
- `ai/decisions/` — where intentional exceptions land as ADRs.
- `.claude/agents/convention-drift-detector.md` — the agent.
