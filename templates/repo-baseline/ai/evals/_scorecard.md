# Eval scorecard (append-only run history)

Every `/eval` run appends ONE dated block below. This is the **regression record** — the reason
a case that passed last week and fails today is visible instead of silent. Never edit or delete
prior run blocks; `/eval` compares the newest run against the previous one to detect REGRESS.

`/eval` is the ONLY writer of this file.

## Format per run

```
### <YYYY-MM-DD> — run <N>  ·  cases: <X>  pass: <Y>  fail: <Z>  coverage: <C>%
| case            | guards                          | score        | Δ prev | verdict |
|-----------------|---------------------------------|--------------|--------|---------|
| <slug>          | <rule/convention/pattern>       | <hits/total, viol> | = / + / − / NEW | PASS / FAIL / REGRESS |

Unguarded (no case): <n> — <top few>
Stale (RETIRE): <list>  ·  Toothless: <list>
Failures fed to ai/dynamic/learnings.md: <case slugs, or "none">
```

- **coverage** = promoted units with ≥1 non-toothless guarding case ÷ total promoted units
  (`.claude/rules/*` + `ai/conventions.md` managed entries + `ai/patterns/*`).
- **Δ prev**: `=` unchanged · `+` improved · `−` REGRESS (was PASS, now FAIL) · `NEW` first run of this case.

---

## Runs

<!-- /eval appends run blocks here. No runs yet — author cases (see cases/_template.md,
     or /eval --seed) then run /eval. -->
