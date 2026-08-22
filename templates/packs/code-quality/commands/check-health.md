---
description: Periodic whole-repo health pulse (no diff) — mechanical checks that must go green, then a standing agent panel, then a per-area RAG grid and an ordered plan. Weekly cadence or milestone gate. Anti-triggers: a PR diff is `/review-changes`; staged files are `/pre-commit`; ranking defects at a target scale and fixing them P0–P4 is `/audit`; grading `.claude/` scaffolding rather than product code is `/setup-project-health`.
---

# /check-health

Run weekly or before a milestone. Mechanical pass first (must be green to continue), then agent audit, then a verdict + top-3 actions.

## Phases applied

AUDIT type — 1, 2, 3, 6 dominate. Phase 4 = the verdict; Phase 5 records the audit + Recent Changes; Phase 7 feeds repeat-finding learning.

## When to use / NOT to use
- USE: weekly cadence on active projects; before declaring a milestone done; after a long pause (`git log --since=...` shows last commit > 30 days).
- NOT: mid-feature — the diff dominates findings; finish the feature, then run.

## Phase 1 — Understand

- Confirm scope: usually full repo on default branch.
- Success: per-area RAG (RED/AMBER/GREEN), overall verdict, and an ordered `## What to do next` plan sorted by `(severity, effort)`.

## Phase 2 — Organize

- Sequence: mechanical first (must all pass) → agent audit (parallel) → consolidate.
- If mechanical fails: STOP, report, do not run agents.
- **Halt on RED**: if ANY agent returns a RED finding, halt the verdict report and surface for resolution before continuing. AMBER may pass-through with a 1-line note in the verdict. (Same halt-on-blocker discipline the migration pack applies at gate time.)

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` + `ai/stack.md` — package manager + script names.
- `ai/conventions.md` — what reviewers enforce.
- `ai/status.md` — last Updated date (a stale doc is itself a finding).
- `.claude/rules/*.md` — track-specific reviewer scope.

DETECTION:
- Package manager + scripts (`pnpm`, `bun`, `npm`, `uv`, `poetry`, `go`).
- Tracks present (backend / frontend / DB / infra).

## Phase 4 — Generate (consolidate verdict)

Score per area: GREEN (no findings) / AMBER (warnings) / RED (blockers). Overall = worst component. The `## What to do next` plan orders MUST/SHOULD/OPTIONAL by `(severity, effort)`.

## Phase 5 — Update

- `ai/audits/<YYYY-MM-DD>-health-check.md` — full report.
- `ai/status.md` — Recent Changes entry (always; this is a defined audit cadence).
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/dynamic/drift-log.md` — append findings if `code-vs-rule`.

## Phase 6 — Validate (the bulk of this command)

### Mechanical (parallel, must all pass)

Detected from package manager + scripts:

```bash
# Node-ish
pnpm install --frozen-lockfile
pnpm lint            # or: bun lint, npm run lint
pnpm typecheck       # tsc --noEmit when no script
pnpm build
pnpm test --run --coverage        # the flag is not optional — see below

# Python
uv sync --frozen     # or poetry install --no-root
ruff check .
mypy .
pytest -q --cov

# Go
go vet ./...
golangci-lint run
go build ./...
go test -cover ./...
```

If any step fails: STOP, do not run agents. Fix mechanical first.

**Coverage is measured here or it is not reported.** The report template below has a `coverage` cell; a runner invoked without its coverage flag produces no such number, and filling that cell from memory, from a CI badge, or from the last run is the exact vanity-metric failure this command's own Failure-modes list warns about. Two honest outcomes:

- the flag ran → print the number the tool emitted, and hand the *quality* question to `test-reviewer` (a coverage % with no assertion-strength read is a floor, not a verdict);
- no coverage tooling is configured → print `coverage n/a (no coverage tool configured)` and make **that** the finding. Never a remembered percentage.

### Agent audit (parallel)
- `code-reviewer` — last 20 commits via `git log -p -20`.
- `dead-code-finder` — full repo scan.
- `security-auditor` — auth + data boundaries.
- `performance-optimizer` — hot paths from logs/observability if linked.
- `doc-writer` — `ai/status.md` freshness (FAIL if `Updated:` missing or > 30 days).
- `api-reviewer` — backend track present.
- `ui-reviewer` — frontend track present.
- `schema-reviewer` — DB migrations present.

**Missing-agent fallback (applies to every agent above):** if a named agent is not installed in this project, perform that axis inline against the corresponding pack/domain checklist — never silently skip the axis. Note the substitution in the verdict (`inline:<agent-name>`). A skipped axis scores GREEN by absence, which is the worst failure mode for a health check: it reads as "clean" when it was never checked. (Same discipline as `review-changes.md` § Phase 6 missing-agent fallback.)

### Self-audit
- Did every selected agent return? Missing = incomplete check.
- Are findings consistent across overlapping agents (perf + schema both flagging same query)? De-dup.

## Phase 7 — Improve

- If a finding class repeats across weeks, queue rule sharpening to `ai/dynamic/learned-patterns.md`.
- If `ai/status.md` is consistently stale, queue automation (Stop hook updating Recent Changes) to `ai/dynamic/decisions-pending.md`.
- If overall verdict has been RED for 3+ runs without progress, queue ADR for blocker triage.

## Output

```
Health report — order-api  2026-04-24

Mechanical:
  PASS  Lint        0 errors, 3 warnings
  PASS  Typecheck   0 errors
  PASS  Build       4.2s
  PASS  Tests       245/245, coverage 84% line / 71% branch  (from `pnpm test --run --coverage`)

Agent audit:
  RED    Code         2 blockers, 4 requests, 12 nits
  AMBER  Dead code    3 unused exports
  RED    Security     1 blocker — missing auth on GET /admin/export
  AMBER  Performance  N+1 in listOrders()
  RED    Docs         ai/status.md last updated 2026-02-14 (71 days stale)

Overall: RED  (security blocker requires immediate fix)

## What to do next  (do these in order)

MUST FIX — the overall verdict stays RED until these are done:
  1. <modules-root>/admin/export.controller.<ext>:18 — GET /admin/export has no auth guard.
     Fix: apply the project's auth + admin-role gate primitive (`_extracted-idioms.md § Auth`).
     Verify: e2e test asserts 401 unauthenticated; re-run /check-health → Security GREEN.
  2. ai/status.md is 71 days stale (Updated: 2026-02-14).
     Fix: /doc-refresh.
     Verify: `Updated:` within 30 days; Docs flips GREEN.

SHOULD FIX — fix now unless you have a reason not to:
  3. <modules-root>/orders/<list-handler>.<ext>:24 — N+1 on customer lookup.
     Fix: eager-load customer in the list query (route via /optimize-query).

OPTIONAL — safe to defer:
  4. 3 unused exports flagged by dead-code-finder — confirm with the confidence bucket before deleting.

Then:
  5. Re-run /check-health — confirm the overall verdict comes back GREEN.
  6. Run /learn-from-task to capture what was learned.
```

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the health findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (RED items — blockers that hold the overall verdict at RED) → **SHOULD FIX** (AMBER items — fix now unless you have a reason not to) → **OPTIONAL** (GREEN-with-nits — safe to defer) — each step carrying `<file:line>` + **Fix** (concrete — the named fix / command / pattern, never "consider X") + **Verify** (required on every MUST-FIX step; the mechanical check or test that flips it green), then the closing steps (re-run `/check-health` to confirm the verdict comes back GREEN, `/learn-from-task`, then declare the milestone / proceed). A clean run collapses to a single line ("All GREEN — no blockers"). This is the block shown inside the ```Output``` fence above — it *replaces* the bare `Top 3` list rather than following it: the reader must never reassemble next steps from the RAG grid themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Mechanical greens hide design rot — never skip the agent pass.
- Coverage % without quality threshold = vanity metric; `test-reviewer` looks at assertions. A coverage % printed by a run that never passed a coverage flag is worse than vanity — it is fabrication; print `n/a` instead.
- Stale `ai/status.md` treated as soft warning — it's a real finding (Claude reads it).
- "AMBER everywhere, nothing red" — thresholds set too low; tighten.
- Running on feature branch — diff dominates; run on `main` for true pulse.
- Green today doesn't mean no work — means no blockers found by today's checks.

## Related

### The boundary this command owns

**`/check-health` is the diff-free periodic pulse.** It takes the repo as it stands on the default branch and returns a per-area RAG grid plus a verdict. Its unit of work is *time* (a weekly cadence, a milestone gate), not a change. (`/find-module` is diff-free too, but it answers "where does X live" and forms no opinion about what it finds — no grid, no verdict, no agent panel. Diff-free is the shared property; *judging the repo* is the one that is this command's.)

**Anti-triggers — route away:**
- *"Rank what's wrong across security + perf + DB at 100K RPS"* → **`/audit`** (global). Both are whole-repo and read-only, so they collide on the phrase "sweep the codebase". The split: this one reports **RAG + top-3 by `(severity, effort)`** off cheap mechanical checks and a standing agent panel; `/audit` ranks by **`impact-at-target-scale × blast-radius × fix-cost`** across 8 axes and the 13 scale-lens detectors, then *executes* P0–P4. Health check = pulse. Audit = deep pass with a scale target. If the ask names a load, a launch, or a hardening bar, it is `/audit`.
- *"Are my Claude setup artifacts stale?"* → `/setup-project-health`. That grades `.claude/` scaffolding; this grades product code.
- *"Fix what you find"* → this command writes only its own audit files. Route fixes to `/optimize`, `/audit`, or the specific pack command.
- Mid-feature → don't. The in-flight diff dominates the findings; finish, then run.

### Sibling commands in code-quality pack
- `/review-changes` — the per-PR twin: same reviewer panel, but scoped to a diff and ending in a merge verdict rather than a RAG grid.
- `/pre-commit` — the same idea one scope narrower again (staged files) and one moment earlier (before the commit).
- `/simplify` — this command *finds* rot; `/simplify` is one of the commands that removes it.
- `/find-module` — locate a module the grid flagged.

### Rules
- `.claude/rules/engineering-principles.md`
- `.claude/rules/quality-principles.md`
