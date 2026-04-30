---
description: Project health dashboard — mechanical checks + multi-agent audit. Catches drift early.
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
- Success: per-area RAG (RED/AMBER/GREEN), overall verdict, top-3 sorted by `(severity, effort)`.

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

Score per area: GREEN (no findings) / AMBER (warnings) / RED (blockers). Overall = worst component. Top-3 = sorted by `(severity, effort)`.

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
pnpm test --run

# Python
uv sync --frozen     # or poetry install --no-root
ruff check .
mypy .
pytest -q

# Go
go vet ./...
golangci-lint run
go build ./...
go test ./...
```

If any step fails: STOP, do not run agents. Fix mechanical first.

### Agent audit (parallel)
- `code-reviewer` — last 20 commits via `git log -p -20`.
- `dead-code-finder` — full repo scan.
- `security-auditor` — auth + data boundaries.
- `performance-optimizer` — hot paths from logs/observability if linked.
- `doc-writer` — `ai/status.md` freshness (FAIL if `Updated:` missing or > 30 days).
- `api-reviewer` — backend track present.
- `ui-reviewer` — frontend track present.
- `schema-reviewer` — DB migrations present.

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
  PASS  Tests       245/245, coverage 87%

Agent audit:
  RED    Code         2 blockers, 4 requests, 12 nits
  AMBER  Dead code    3 unused exports
  RED    Security     1 blocker — missing auth on GET /admin/export
  AMBER  Performance  N+1 in listOrders()
  RED    Docs         ai/status.md last updated 2026-02-14 (71 days stale)

Overall: RED  (security blocker requires immediate fix)

Top 3:
  1. Add auth guard to GET /admin/export        (security, ~10min)
  2. Fix N+1 in listOrders                      (perf, ~1h via /optimize-query)
  3. Run /doc-refresh and re-run /check-health  (docs, ~15min)
```

## Failure modes

- Mechanical greens hide design rot — never skip the agent pass.
- Coverage % without quality threshold = vanity metric; `test-reviewer` looks at assertions.
- Stale `ai/status.md` treated as soft warning — it's a real finding (Claude reads it).
- "AMBER everywhere, nothing red" — thresholds set too low; tighten.
- Running on feature branch — diff dominates; run on `main` for true pulse.
- Green today doesn't mean no work — means no blockers found by today's checks.

## Related

### Sibling commands in code-quality pack
- `/find-module` — sibling command in code-quality pack
- `/pre-commit` — sibling command in code-quality pack
- `/review-changes` — sibling command in code-quality pack
- `/simplify` — sibling command in code-quality pack

### Rules
- `.claude/rules/engineering-principles.md`
- `.claude/rules/quality-principles.md`
