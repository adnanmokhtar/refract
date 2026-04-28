---
description: Inventory every feature flag in code — site count, age, ownership, rollout state, eval rate. Surface long-stable flags for cleanup and orphan flags missing owners.
---

# /flag-audit

Purpose: keep flag debt visible. Without this, flags accumulate forever — every one a fork in the codebase.

## What it scans

1. **Flag declarations** (registry / `flags.yaml` / DB `feature_flags`). Records name, owner, sunset date, default, type.
2. **Evaluation sites** in code. Greps for SDK call patterns:
   - `flagService.isOn('...')` / `.variant('...')` / `.evaluate('...')`
   - `client.boolVariation('...')` / `.stringVariation('...')` (LaunchDarkly)
   - `growthbook.isOn('...')` / `.getFeatureValue('...')` (GrowthBook)
   - `unleash.isEnabled('...')` (Unleash)
   - `useFlag('...')` (React/Vue hooks)
3. **Cross-references** — for each flag, list every file:line where it's evaluated.
4. **Provider state** (if API key available) — current rollout %, last-modified date, eval count last 7d.
5. **Cleanup candidates** — flags at 100% (or 0%) rollout for >14 days with all branches still in code.
6. **Orphans** — flags evaluated in code but absent from registry, OR registered but never evaluated.

## How

```bash
# Local-only (no provider API call)
.claude/skills/flag-audit-scan.sh

# With provider state
LAUNCHDARKLY_API_KEY=... .claude/skills/flag-audit-scan.sh --provider=launchdarkly
```

Or `/flag-audit` slash. Output is a table:

| Flag key | Sites | Owner | Sunset | Rollout | Last eval | Status |
|---|---|---|---|---|---|---|
| `checkout.new-cart.v2` | 3 | @ali | 2026-02-01 (overdue 80d) | 100% (since 2026-01-12) | 1.2M/day | CLEANUP |
| `pricing.discount.test` | 1 | (none) | (none) | 50% | 4k/day | ORPHAN-OWNER |
| `search.faceted-v2` | 5 | @sara | 2026-06-30 | 25% | 800k/day | active |
| `legacy.old-checkout` | 0 | @ali | 2025-12-01 | 100% | 0 | DEAD-CODE-REMOVED-NOT-DELETED |

## Status codes

- `active` — within sunset window, partial rollout, healthy.
- `CLEANUP` — 100% (or 0%) for >14 days. Both branches still in code. Open cleanup PR.
- `ORPHAN-OWNER` — flag has no owner. Assign before merge of next change touching it.
- `ORPHAN-IN-CODE` — evaluated in code, not in registry. Either register or remove.
- `DEAD-IN-REGISTRY` — registered but no evaluation site. Remove from provider (saves $).
- `OVERDUE-SUNSET` — past sunset date. Block PR until decision documented.
- `LOW-EVAL` — evaluated <100 times last 7d. Possible dead path or wrong targeting.

## When to run

- Pre-merge of any PR adding / removing a flag.
- Weekly background sweep — paste output into `#engineering-flag-debt` channel.
- Before a "flag cleanup sprint" — gives the prioritized backlog.
- Before provider plan renewal — every active flag costs money.

## Resolution

Each non-active row needs an action:

- `CLEANUP` → open `cleanup/remove-<flag-key>` PR within 7 days.
- `ORPHAN-OWNER` → DM the most recent author of evaluation site; require owner before next merge.
- `ORPHAN-IN-CODE` → register OR remove eval site. No silent flags.
- `DEAD-IN-REGISTRY` → delete from provider (one click, saves $).
- `OVERDUE-SUNSET` → owner extends sunset (with reason in PR) OR opens cleanup PR.

## Output artifact

Writes `ai/audits/flag-audit-<YYYY-MM-DD>.md` with full table + summary stats:

```
Total flags: 47
  active:                    32
  CLEANUP:                    8
  ORPHAN-OWNER:               3
  ORPHAN-IN-CODE:             1
  DEAD-IN-REGISTRY:           2
  OVERDUE-SUNSET:             1

Cost estimate (provider plan):
  Tier:               Pro ($89/mo for 50 flags)
  Current:            47 / 50 (94%)
  After cleanup:      37 / 50 (74%) — would NOT downgrade tier
  After full cleanup: 32 / 50 (64%) — could downgrade to Starter ($19/mo) → save $70/mo
```

## See also

- `ai/patterns/feature-flag.md` — lifecycle + SDK choice + code shape.
- `.claude/rules/flag-discipline.md` — naming + ownership + rollout cadence.
- `.claude/agents/flag-reviewer.md` — review gate for flag PRs.
