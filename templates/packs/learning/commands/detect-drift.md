---
description: "Code vs documented conventions: dispatches align's oracle when installed; logs divergences to drift-log.md."
kind: command
pack: learning
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task, Skill]
---

# /detect-drift

Find where current code DIVERGES from the conventions you've documented. Three outcomes per finding: fix code, update convention, or write ADR for intentional exception.

**A narrow alias, conventions only.** Convention claims against the code majority (KN-10) are owned by align `convention-oracle` (AL-01–AL-04) when the align pack is installed; this command dispatches it (the `Skill` tool) and maps its classes onto the four outcomes below. Without align it dispatches `@convention-drift-detector` (the `Task` tool), which grades rule staleness and the contested set only and routes anti-patterns, layer and type rows to their owners. Everything else wrong with the knowledge layer — dead references, wrong facts, stale anchors and indexes, sink hygiene, ADR lifecycle, load — is `/audit-knowledge`.

## Phases applied

MAINTAIN type — 1, 3, 5, 6. Phase 4 here = generating the categorized report (no code changes); Phase 5 = persisting findings to the knowledge layer (drift-log.md, status.md).

## When to use / NOT to use
- USE: before a release (catch regressions in style discipline); after onboarding new team members; quarterly housekeeping pair with `/refresh-knowledge`; investigating "why does this codebase feel inconsistent?".
- NOT: mid-feature (would distract); fresh after `/setup-project` (nothing has changed yet); on dirty tree (commit/stash first).

## Phase 1 — Understand

- Confirm scope: full repo or path-scoped.
- Confirm documented baseline exists (`ai/conventions.md` + `.claude/rules/*.md`) — refuse if absent (run `/refresh-knowledge` first).
- Success: per-finding evidence (file:line), violated rule, severity, categorization, recommended resolution path.

## Phase 2 — Organize

- Plan: gather documented expectations → run drift detector → categorize → group by resolution path → present.

## Phase 3 — Retrieve

ALWAYS:
- `ai/conventions.md` — auto-detected naming + style.
- `.claude/rules/*.md` — every rule file.
- `.claude/codebase-profile.md` — every detected fact.
- `ai/business-domain.md` — entity ownership for tenant/security checks.
- **The contested set** — `ai/conventions.md § Unsettled conventions` (written only by REFINE) AND `grep '\[CONTESTED:' .claude/_extracted-codebase.md` (written by every mode). Both, not either: a project that never ran `--refine` records its splits only in the oracle. A category in that set is a **live split**, not a rule; findings in it are `ambiguous`, never `code-vs-rule` — see `convention-drift-detector § Contested categories`. If neither source is readable, report `contested set: unavailable` in the header instead of proceeding as if nothing is contested.

## Phase 4 — Generate (the categorized report)

**When the align pack is installed** (`.claude/skills/convention-oracle/SKILL.md` exists), run `convention-oracle` first: its § 0 builds the oracle map with each rule's tier (`oracle-map.py`: T1 at `error`, T2 human-written, T2g generated, contested), § 2 the splits, § 3 the declared-but-unenforced rules, § 4 the stale docs. Hand that map to `convention-drift-detector` instead of letting it re-read the rules from prose, and map its classes onto this report's four outcomes: AL-02 (a split, or a contested category) → `ambiguous`; AL-04 (most sites and the newest files follow the other shape) → `rule-vs-reality`; AL-03 (a written rule no lint rule enforces) → `rule-vs-reality` with "enforce it" as the resolution; a site breaking a T1/T2 rule → `code-vs-rule`. A generated (T2g) line never produces `code-vs-rule`: it is `ambiguous` until a human ratifies it. This command stays read-only either way; closing `code-vs-rule` rows is `/align`'s. **Without the align pack**, invoke the agent as below — the four outcomes and the contested-set rule are the same.

Invoke `convention-drift-detector` agent against the codebase.

Per finding:
- File + line evidence.
- Convention violated (which rule / which `conventions.md` section).
- Severity (high / medium / low).
- Categorization: `code-vs-rule` (code wrong) / `rule-vs-reality` (rule stale) / `rule-vs-rule` (two rules contradict) / `ambiguous` (need human — **including every contested category**).

**Contested categories collapse to one row each.** A 6/4 split across 10 files is ONE `ambiguous`
finding carrying both counts and one citation per side — not four FIX-CODE rows against the files on
the minority side. Those files are following a convention this codebase demonstrably has; the split
is the finding.

Group by resolution path:
- **FIX CODE** — bring violation into line.
- **UPDATE CONVENTION** — code is right; documentation is stale.
- **WRITE ADR** — both legitimate; divergence is intentional.
- **REJECT** — false positive (generated, vendored, intentional fixture).

## Phase 5 — Update (the knowledge layer)

This is where the command's value lands. Persist:
- `ai/dynamic/drift-log.md` — append every finding with status `OPEN`, its `file:line`, the rule it cites and the recommended resolution, in the shape the sink's own `## Format per entry` declares (a project may redefine it; the declared format is what its consumers must read, precedents § 24), else the template.
- `ai/status.md` — prepend Recent Changes ("Drift detected: 3 high-severity items pending fix") if any high-severity.
- `ai/dynamic/changelog.md` — one-line summary entry.
- For `rule-vs-reality` findings: do NOT auto-update conventions; surface so user can run `/refresh-knowledge` or edit manually.
- For contested categories: queue each to `ai/dynamic/decisions-pending.md` as "resolve the split via ADR, or accept it" — NOT to `drift-log.md § OPEN`, which is a fix-list and would re-surface the split as unresolved work every run.
- For `rule-vs-rule` contradictions: queue to `ai/dynamic/decisions-pending.md` AND add to `ai/status.md § Blockers` with status `BLOCKED` — needs human resolution. The next session sees the blocker before any rule-loading work; the conflict cannot ship hidden in a queue.

## Phase 6 — Validate

- Self-audit: every finding has file:line evidence (not vague "feels off").
- Categorization sanity: a `code-vs-rule` finding's rule actually exists in `.claude/rules/` (not invented).
- For "false positive" findings: add path to `.claude/drift-ignore.txt` so future runs don't re-flag.
- Confirm `ai/dynamic/drift-log.md` was actually written (not just printed).

## Phase 7 — Improve

- If same drift class recurs across runs (e.g. direct stdout / print calls instead of the project's structured logger), queue lint rule promotion to `ai/dynamic/feedback-learned.md` — drift detection is a stopgap; CI lint is the fix.
- If `rule-vs-reality` rate > 30%, conventions are stale — queue `/refresh-knowledge` invocation.
- Archive RESOLVED entries from drift-log monthly via `@knowledge-curator` mode `archive` to `ai/audits/drift-resolved-YYYY-MM.md`.

## Output

```
## /detect-drift report — <commit hash> · <YYYY-MM-DD>

### High (3)
- <billing service file:42> — uses a direct stdout / print call (rule: `.claude/rules/observability.md` line 12 says use the project's structured logger).
  -> FIX CODE
- <legacy-root>/admin.controller.<ext>:88 — bypasses tenant filter via raw SQL (rule: `.claude/rules/multi-tenancy.md`).
  -> FIX CODE (security-relevant)
- <modules-root>/orders/order.entity.<ext>:15 — uses a binary-float type for price (`ai/conventions.md` says integer minor units / fixed-precision decimal).
  -> FIX CODE

### Medium (8)
- <modules-root>/auth/*.<ext> — file naming uses `auth.guard.<ext>`. Conventions say `.<name>.guard.<ext>`. Either:
  -> FIX CODE (rename) or -> UPDATE CONVENTION (allow `.guard.<ext>`)
- <modules-root>/notifications/notifier.<ext> — class lacks `Service` suffix.
  -> FIX CODE (rename to `notification.service.<ext>`)
- ... (6 more)

### Rule-vs-reality (2 — your conventions are stale)
- `.claude/rules/dtos-mappers.md` says "DTOs use `<validator-lib>@0.13`". Actually using `0.14.x`.
  -> UPDATE CONVENTION
- `ai/conventions.md` lists `BaseService` as having 147 extenders; actual is 162.
  -> UPDATE CONVENTION (auto via `/refresh-knowledge`)

### Suggested actions
- 6 high-severity FIX CODE — schedule before next release.
- 2 UPDATE CONVENTION — apply now via `/refresh-knowledge` (auto) or `ai/conventions.md` (manual).
- 12 low-severity — review with team; either codify as rule or accept variation.

Append all findings to `ai/dynamic/drift-log.md`? [y/n]
```

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the drift findings re-expressed as ONE ordered, numbered to-do — **DO NOW** (high-severity `code-vs-rule` FIX CODE + stale conventions to promote/refresh) → **REVIEW** (medium-severity drifted conventions + `ambiguous` / `rule-vs-rule` items needing a human call) → **OPTIONAL** (low-severity variation, codify-or-accept) — each step carrying `<file:line>` + **Fix** (concrete) + **Verify** on every DO-NOW step. Where a sibling command does the work better, the step IS the paste-ready command — `/promote-pattern <name>` for a convention that should become a rule, `/refresh-knowledge` for `rule-vs-reality` staleness, `/audit-knowledge` for the rest of the knowledge layer — composing with the drift-log writes from Phase 5. Close with: re-run `/detect-drift` to confirm the drift is cleared, `/learn-from-task`, then ship. A clean run collapses to a single line ("No drift — code matches documented conventions"). This supersedes the bare `Suggested actions` block as the actionable closer. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Pattern false-positive (generated code looks like violation) — add path to `.claude/drift-ignore.txt`.
- Rule too vague to detect against — agent flags as `ambiguous`; sharpen the rule then re-run.
- Drift log getting too long — `@knowledge-curator` mode `archive` moves RESOLVED entries out monthly.
- Running without baseline (`ai/conventions.md` missing) — refuse; run `/refresh-knowledge` first.
- High `rule-vs-reality` rate ignored — conventions decay silently; treat as a maintenance signal.

## Difference from `/refresh-knowledge` and `/setup-project --refresh`

Three widths, and picking the wrong one is the usual way a stale project stays stale:

| Command | Re-runs extraction? | Rewrites the oracle? | Re-applies packs / anchors / adapters? |
|---|---|---|---|
| `/detect-drift` | no — reads the documented layer | no | no |
| `/refresh-knowledge` | yes — invokes `extract-codebase-overview` | yes (`_extracted-codebase.md`, stamp preserved) | no |
| `/setup-project --refresh` | yes — all 15 steps | yes | yes |

- `/detect-drift` answers "does the code still match what we wrote down?" It cannot tell you the
  written-down thing was never true, because it never re-reads the codebase from scratch — that is
  `/refresh-knowledge`'s job, and it is why a high `rule-vs-reality` rate is a signal to escalate.
- Use `/detect-drift` weekly; `/refresh-knowledge` quarterly or after a big refactor; and reach for `/setup-project --refresh` when the stack itself moved.

## Related

### Sibling commands in learning pack
- `/learn-from-task` — sibling command in learning pack
- `/promote-pattern` — sibling command in learning pack
- `/refresh-knowledge` — sibling command in learning pack
