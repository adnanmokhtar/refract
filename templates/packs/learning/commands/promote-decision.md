---
description: Graduate an entry from ai/dynamic/decisions-pending.md into a formal, sequentially-numbered ADR under ai/decisions/. Invokes knowledge-curator. The decision sibling of /promote-pattern (which graduates learned-patterns → ai/patterns/). Phase-6 maintenance — turns an "open architectural decision" into durable, referenceable record.
kind: command
pack: learning
---

# /promote-decision

**One command. Turn a pending architectural decision into a numbered ADR.** A decision that lives only in `ai/dynamic/decisions-pending.md` is invisible to future sessions and un-citable; this graduates it to the durable `ai/decisions/` layer.

## When to use

- A pending decision in `ai/dynamic/decisions-pending.md` has been **made** (the team chose a direction) and should become permanent.
- `/audit-knowledge` flagged a pending decision that's been resolved in practice but never recorded.
- NOT for emerging code patterns — that's `/promote-pattern` (→ `ai/patterns/`).

## Args

```
/promote-decision <id>          # graduate the named pending decision
/promote-decision               # list resolved-looking pending decisions, ask which
```

## What happens (via knowledge-curator)

1. **Read** the entry in `ai/dynamic/decisions-pending.md` (context, options, what was blocking).
2. **Allocate the next ADR number** — scan `ai/decisions/` for the highest `NNNN-` prefix, increment.
3. **Author the ADR** at `ai/decisions/<NNNN>-<slug>.md` with the full structure: context, decision, status (`accepted`), consequences, alternatives considered, date, and — if it closes a V1↔V2 divergence — the `user_decision_quote:` the migration discipline requires.
4. **Remove** the graduated entry from `decisions-pending.md` (it now lives in the ADR; append-only history preserved via the ADR itself).
5. **Update indexes** — add a line to `ai/_decision-index.md`; cross-link from `ai/status.md § Recent Changes` if it changed the status quo.
6. **Regenerate** the Tier-1 derived files (`_session-digest.md` reflects the new last-3-decisions).

## Halts

- The pending decision isn't actually resolved (still "blocked / undecided") → refuse; a pending decision isn't an ADR until a direction is chosen.
- No `ai/decisions/` dir → create it (CREATE-mode projects) or surface that the project has no ADR layer.

## Output (brief)

- ADR path + number · pending entry removed · index lines updated.

## See also

- `/promote-pattern` — the pattern sibling (→ `ai/patterns/`).
- `/audit-knowledge` — surfaces pending decisions worth promoting.
- `ai/decisions/` · `ai/_decision-index.md` · `ai/dynamic/decisions-pending.md`.
