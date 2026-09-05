---
name: debt-ledger
description: Track technical debt as a persisted, ranked ledger — dated/owned TODOs, unjustified suppressions, deprecated-API call sites, major-version-lag deps — each with a blast-radius and a fix-cost, diffed run-over-run so accrual (new debt vs paid-down) is visible instead of rediscovered every audit.
kind: skill
pack: code-quality
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# Skill: debt-ledger

## Premise

Technical debt that gets rediscovered on every audit is debt nobody is accountable for. This skill treats debt as a **persisted, ranked ledger** — a durable artifact at `ai/debt-ledger.md` — not a transient scan result. Every item carries an **owner**, a **date**, a **blast-radius**, and a **fix-cost**, and every run **diffs against the last ledger** so you can see what accrued (new debt) and what was paid down. The point is not to list debt once; it is to make *accrual over time* visible, so intentional debt gets a due date instead of becoming permanent.

Every item cites `<path:line>`. "Debt" here means **intentional, marked, or knowingly-deferred** shortcuts: an undated `TODO`, a suppression with no justification, a call into a deprecated API, a dependency several major versions behind. If it isn't cite-backed and classifiable into one of the four inventory sources below, it doesn't go in the ledger.

## Boundary — what this owns vs siblings

- `dead-code-finder` / `dead-branch-scan` find **unreachable** code (delete candidates). Debt is *reachable, running* code that's knowingly suboptimal — the two never overlap.
- `@dependency-auditor` scans dependencies for **vulnerabilities / license issues** (a security posture). This skill records **version-lag as debt** (how far behind, what it costs to catch up) — a maintenance posture, not a CVE list. When a dep is both vulnerable *and* lagging, the auditor owns the CVE; the ledger owns the upgrade-cost tracking.
- `check-health` surfaces debt **point-in-time** as one of many health signals. This skill is the **longitudinal tracker**: it persists, ranks, and diffs debt run-over-run so accrual is a trend, not a snapshot. check-health can cite the ledger's headline number; it does not own the ledger.
- `architectural-diagnosis` finds structural smells (god modules, layer violations). Those are *unmarked* architectural debt; this skill tracks *marked/intentional* debt. An architectural finding may spawn a ledger item (with a due date) once acknowledged.

## Halt conditions

- Refuse to enter an item with no `<path:line>` cite.
- Refuse to rank an item without both a blast-radius AND a fix-cost — an unranked ledger is just a list.
- Do NOT auto-delete or auto-fix. This skill *records and ranks*; remediation is a separate, owned decision.
- Do NOT flag exhaustiveness suppressions or framework-required suppressions (a documented `ts-ignore` for a known upstream type bug *with* a justification comment + issue link is paid-down risk, not open debt) — a suppression WITH a justification is compliant; only the unjustified ones are debt.
- If the previous `ai/debt-ledger.md` is missing, run in **baseline mode** (no diff; the whole ledger is "new"; say so in the header) rather than failing.

## When to use

- Quarterly (or per-release) debt review — the canonical cadence; the diff is the deliverable.
- After a "we'll fix it later" sprint — capture the deferrals as dated, owned items before they evaporate.
- Before planning — the ranked ledger feeds the top-N into the backlog.
- After a major dependency or language-version bump — record the new deprecated-API surface the bump introduced.

## Inventory sources (the four debt kinds)

### 1. Undated / unowned markers

`TODO` / `FIXME` / `HACK` / `XXX` comments with no owner and no date. A marker without an owner and a date is debt with no due date — it never gets paid.

```bash
rg -n --pcre2 '\b(TODO|FIXME|HACK|XXX)\b(?!.*\((@?\w+),?\s*\d{4})' -g '!**/{node_modules,vendor,dist,build}/**'
# then classify: has owner+date in `(name, 2025-01)` shape → compliant; bare → debt
```

Age each marker via `git blame` / `git log -L` — a `FIXME` that's 18 months old ranks above one added last week.

### 2. Unjustified suppressions

Linter/compiler/analyzer suppressions with no justification comment on the same or preceding line:

- JS/TS: `// eslint-disable`, `// eslint-disable-next-line`, `// @ts-ignore`, `// @ts-expect-error`, `// @ts-nocheck`
- Python: `# noqa`, `# type: ignore`, `# pylint: disable`
- Java/Kotlin: `@SuppressWarnings`
- Go: `//nolint`
- C#: `#pragma warning disable`

```bash
rg -n 'eslint-disable|@ts-(ignore|nocheck)|# ?noqa|# ?type: ?ignore|@SuppressWarnings|//nolint|pragma warning disable' -g '!**/{node_modules,vendor,dist,build}/**'
```

Classify: a suppression with an adjacent justification (`// eslint-disable-next-line no-explicit-any -- upstream types are wrong, see #1234`) is compliant; a bare suppression is debt. `@ts-expect-error` is *slightly* better than `@ts-ignore` (it fails when the error goes away) but still needs a reason.

### 3. Deprecated-API call sites

Call sites into APIs marked deprecated (by `@deprecated` JSDoc/annotation, a deprecation shim, or the framework's known-deprecated surface). Each call site is a future breakage the next major bump will force.

```bash
# find deprecated declarations, then find their call sites
rg -n '@[Dd]eprecated|DeprecationWarning|@deprecated' -g '!**/{node_modules,vendor}/**'
```

Rank by call-site count (blast-radius) and removal timeline (fix-cost / urgency).

### 4. Major-version-behind dependencies

Dependencies ≥ 1 major version behind current. Track the lag magnitude and the migration cost, not just "outdated".

```bash
# ecosystem-specific; e.g.
npm outdated --json 2>/dev/null   # compare current vs latest major
# pip: pip list --outdated --format=json ; go: go list -u -m all ; etc.
```

Record `<pkg> current@X.y → latest@Z.y (N majors behind)`. A dep 3 majors behind with a hard breaking-change history is high fix-cost; one 1 major behind with a codemod is low.

## Ranking

Each item is scored **blast-radius × fix-cost**, then bucketed:

- **blast-radius** — how much breaks / how many sites are affected if this debt bites (call-site count, module count, is-it-on-a-hot-path, does-it-block-an-upgrade).
- **fix-cost** — effort to pay it down (mechanical codemod = low; manual per-site + behavior risk = high).
- **priority** = high blast-radius × low fix-cost first (cheap wins that de-risk a lot), then high × high (the scary ones — schedule, don't ignore), then low × low last.

Age is a multiplier: older debt ranks up (it has survived scrutiny and compounds).

## The persisted artifact — `ai/debt-ledger.md`

```markdown
# Technical debt ledger — <iso date>

> Run at commit <sha>. Previous ledger: <prev iso date @ prev sha> (or "baseline — no prior ledger").
> Accrual since last run: +<new> new, −<paid> paid down, net <±N>. Total open: <count>.

## Accrual diff (headline)

| | count | blast×cost (sum) |
|---|---|---|
| Paid down since last run | <n> | −<score> |
| New since last run | <n> | +<score> |
| Carried (unchanged) | <n> | <score> |
| **Total open** | **<n>** | **<score>** |

## Open debt (ranked)

### D-001 — deprecated-api [P0 · blast=high · cost=low]
- **Kind**: deprecated-api-call-site
- **Evidence**: <path:line> calls `oldClient.fetch()` (deprecated since v4, removed in v6) — 23 call sites
- **Owner**: unassigned → NEEDS OWNER
- **Since**: first seen 2024-11 (this run: carried, age 8mo)
- **Blast-radius**: 23 sites across 6 modules; blocks the v6 upgrade
- **Fix-cost**: low (codemod `oldClient.fetch(x)` → `client.get(x)`)
- **Due**: before v6 bump

### D-002 — unjustified-suppression [P1 · blast=med · cost=med]
- **Kind**: suppression-no-justification
- **Evidence**: <path:line> `// @ts-ignore` with no reason; hides a real type mismatch
- **Owner**: <name> (from git blame)
- **Since**: 2025-03 (this run: new)
- ...

### D-003 — stale-marker [P2 · blast=low · cost=low]
- **Kind**: undated-todo
- **Evidence**: <path:line> `// FIXME: handle the empty case` — 14 months old, no owner
- ...

### D-004 — version-lag [P1 · blast=high · cost=high]
- **Kind**: dependency-major-lag
- **Evidence**: `<pkg>` current@2.4 → latest@5.1 (3 majors behind)
- **Fix-cost**: high (breaking changes across 3 majors; no single codemod)
- ...

## Paid down since last run

- ~~D-0xx~~ suppression at <path:line> — removed / justified ✓
- ~~D-0yy~~ `<pkg>` upgraded 1.x → 2.x ✓
```

The ledger is INTERNAL (like the other pack artifacts); `check-health` / planning surfaces cite its headline numbers, not the whole file.

## Procedure (step-by-step)

1. **Pin commit** — `git rev-parse HEAD` → artifact header.
2. **Load prior ledger** — read the previous `ai/debt-ledger.md` if present; else baseline mode.
3. **Run the four inventory sources** — collect cite-backed candidates from markers, suppressions, deprecated-API call sites, dep version-lag.
4. **Filter compliant items** — drop markers with owner+date, suppressions with justification, `@ts-expect-error` that self-heal; keep only real debt.
5. **Age each item** — `git blame` / `git log` for first-seen date; compute age.
6. **Rank** — blast-radius × fix-cost × age → priority bucket per item.
7. **Diff against prior ledger** — match by (kind, path-anchor, identity); classify each as new / carried / paid-down. Compute the accrual headline.
8. **Assign owners** — from `git blame` where the marker/suppression has no explicit owner; flag `NEEDS OWNER`.
9. **Write `ai/debt-ledger.md`** — the structure above. No fixes applied.

## The owner + date discipline (the point of the whole skill)

- Every new marker/suppression SHOULD carry `(owner, YYYY-MM)` and a reason — the skill flags the ones that don't and back-fills owners from `git blame`.
- Debt with an owner and a due date gets paid; anonymous undated debt becomes permanent. The ledger exists to convert the latter into the former.
- The run-over-run **net accrual** number is the health signal: net-positive quarter over quarter means debt is compounding faster than it's paid — surface that trend, don't bury it.

## False positives / gotchas

- Generated code, vendored code, and fixtures carry markers/suppressions that aren't yours — exclude `node_modules` / `vendor` / `dist` / `build` and generated-file globs.
- A justified suppression is NOT debt — don't punish teams for documenting a real upstream bug with an issue link.
- `@deprecated` on your *own* API you're mid-migration on is expected; rank by remaining call sites, and drop to zero when the last caller is migrated (that's a paid-down item, celebrate it in the diff).
- Dep "latest" can itself be pre-release / unstable — compare against latest *stable* major, not bleeding edge.

## Related

- `dead-branch-scan` — finds unreachable code (delete); disjoint from reachable-but-suboptimal debt.
- `architectural-diagnosis` — unmarked structural debt; may spawn ledger items once acknowledged.
- `@dependency-auditor` — owns dep vulnerabilities/licenses; this skill owns dep version-lag as tracked debt.
- `check-health` — point-in-time health snapshot; cites this ledger's headline, doesn't own it.
