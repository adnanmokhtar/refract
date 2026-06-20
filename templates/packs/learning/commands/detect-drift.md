---
description: Compares current code against documented conventions in ai/conventions.md + .claude/rules/. Categorizes divergences. Appends findings to ai/dynamic/drift-log.md.
---

# /detect-drift

Find where current code DIVERGES from the conventions you've documented. Three outcomes per finding: fix code, update convention, or write ADR for intentional exception.

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

## Phase 4 — Generate (the categorized report)

Invoke `convention-drift-detector` agent against the codebase.

Per finding:
- File + line evidence.
- Convention violated (which rule / which `conventions.md` section).
- Severity (high / medium / low).
- Categorization: `code-vs-rule` (code wrong) / `rule-vs-reality` (rule stale) / `rule-vs-rule` (two rules contradict) / `ambiguous` (need human).

Group by resolution path:
- **FIX CODE** — bring violation into line.
- **UPDATE CONVENTION** — code is right; documentation is stale.
- **WRITE ADR** — both legitimate; divergence is intentional.
- **REJECT** — false positive (generated, vendored, intentional fixture).

## Phase 5 — Update (the knowledge layer)

This is where the command's value lands. Persist:
- `ai/dynamic/drift-log.md` — append every finding with status `OPEN` and recommended resolution. Use the standard finding template.
- `ai/status.md` — prepend Recent Changes ("Drift detected: 3 high-severity items pending fix") if any high-severity.
- `ai/dynamic/changelog.md` — one-line summary entry.
- For `rule-vs-reality` findings: do NOT auto-update conventions; surface so user can run `/refresh-knowledge` or edit manually.
- For `rule-vs-rule` contradictions: queue to `ai/dynamic/decisions-pending.md` AND add to `ai/status.md § Blockers` with status `BLOCKED` — needs human resolution. The next session sees the blocker before any rule-loading work; the conflict cannot ship hidden in a queue.

## Phase 6 — Validate

- Self-audit: every finding has file:line evidence (not vague "feels off").
- Categorization sanity: a `code-vs-rule` finding's rule actually exists in `.claude/rules/` (not invented).
- For "false positive" findings: add path to `.claude/drift-ignore.txt` so future runs don't re-flag.
- Confirm `ai/dynamic/drift-log.md` was actually written (not just printed).

## Phase 7 — Improve

- If same drift class recurs across runs (e.g. direct stdout / print calls instead of the project's structured logger), queue lint rule promotion to `ai/dynamic/feedback-learned.md` — drift detection is a stopgap; CI lint is the fix.
- If `rule-vs-reality` rate > 30%, conventions are stale — queue `/refresh-knowledge` invocation.
- Archive RESOLVED entries from drift-log monthly via `/audit-knowledge` to `ai/audits/drift-resolved-YYYY-MM.md`.

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

Every run MUST end its report with a `## What to do next` block: the drift findings re-expressed as ONE ordered, numbered to-do — **DO NOW** (high-severity `code-vs-rule` FIX CODE + stale conventions to promote/refresh) → **REVIEW** (medium-severity drifted conventions + `ambiguous` / `rule-vs-rule` items needing a human call) → **OPTIONAL** (low-severity variation, codify-or-accept) — each step carrying `<file:line>` + **Fix** (concrete) + **Verify** on every DO-NOW step. Where a sibling command does the work better, the step IS the paste-ready command — `/promote-pattern <name>` for a convention that should become a rule, `/refresh-knowledge` for `rule-vs-reality` staleness, `/audit-knowledge` to archive resolved entries — composing with the drift-log writes from Phase 5. Close with: re-run `/detect-drift` to confirm the drift is cleared, `/learn-from-task`, then ship. A clean run collapses to a single line ("No drift — code matches documented conventions"). This supersedes the bare `Suggested actions` block as the actionable closer. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Pattern false-positive (generated code looks like violation) — add path to `.claude/drift-ignore.txt`.
- Rule too vague to detect against — agent flags as `ambiguous`; sharpen the rule then re-run.
- Drift log getting too long — `/audit-knowledge` archives RESOLVED monthly.
- Running without baseline (`ai/conventions.md` missing) — refuse; run `/refresh-knowledge` first.
- High `rule-vs-reality` rate ignored — conventions decay silently; treat as a maintenance signal.

## Difference from `/refresh-knowledge`

- `/refresh-knowledge` re-detects EVERYTHING (full Phase 2 rerun).
- `/detect-drift` is narrower: only checks code vs documented rules + conventions.
- Use `/detect-drift` weekly; `/refresh-knowledge` quarterly.

## Related

### Sibling commands in learning pack
- `/learn-from-task` — sibling command in learning pack
- `/promote-pattern` — sibling command in learning pack
- `/refresh-knowledge` — sibling command in learning pack

### Patterns
- `ai/patterns/setup-quality-scoring.md`
