---
description: Pre-commit gate — mechanical + agent review on staged changes. Blocks commit on blockers.
---

# /pre-commit

Run right before committing. Scoped to staged diff only — faster than `/check-health`.

## The Premise (read this first, internalize, do not deviate)

**Existing checks are the truth. Mirror project's lint/typecheck/test commands; don't inject new ones.** The repo already declares its quality gates — `package.json` scripts, `Makefile` targets, `pyproject.toml`, `.pre-commit-config.yaml`, `lefthook.yml`, `husky` hooks, the project's `CLAUDE.md` quality section. This command runs THOSE commands on the staged scope. It does NOT introduce a parallel toolchain ("let me try `prettier` even though the project uses `biome`"), does NOT add stricter flags, does NOT reformat with a different style.

**The closure verb is `gate`.** This command never authors files. It returns one of:
- `APPROVED` — mechanical green + agent green.
- `APPROVED_WITH_REQUESTS` — green but non-blocking notes.
- `REQUEST_CHANGES` — at least one blocker; commit refused.

**Forbidden:**
- Asking the user style-flag questions ("tabs or spaces?", "single or double quotes?", "max line length?"). The project's lint config is the answer. Fix to match.
- Inventing a typecheck/lint/test command not declared by the project. If the project has no typecheck script, say so; do not run an ad-hoc `tsc --noEmit` with custom flags.
- Continuing past a red mechanical step to "see what the agents say". Mechanical red poisons the diff context.
- Padding nits to look thorough. Blockers are blockers; nits are nits; nothing in between to inflate the report.

**Mechanical halt — refuse to advance on red:** if `lint` / `typecheck` / `test` returns non-zero on the staged scope, the gate HALTS at Phase 6 mechanical, does NOT dispatch agents, does NOT emit a verdict beyond `REQUEST_CHANGES (mechanical-red)`. Fix the toolchain failure, re-stage, re-run.

**Lightweight default.** Staged scope only. No full-repo passes, no historical commits, no rebuild from clean. If a check needs the full repo (cross-file type errors, transitive test impact), surface that as a Phase 7 note, not as scope creep mid-run.

## Phases applied

VALIDATE type — Phase 6 dominates. Phase 4 = the agent verdict; Phase 5/7 minimal (this command doesn't change files; it gates the commit).

## When to use / NOT to use
- USE: right before `git commit`.
- NOT: nothing staged (command fails fast); replacement for husky/lefthook (different layer — runs IN ADDITION).

## Phase 1 — Understand

- Determine staged scope: `git diff --cached --name-only`.
- If empty → exit `nothing staged`. Don't proceed.
- Success: verdict in {APPROVED, APPROVED_WITH_REQUESTS, REQUEST_CHANGES}; blockers list with file:line + concrete fix.

## Phase 2 — Organize

- Sub-tasks: mechanical pass (lint/typecheck/tests, scoped) THEN agent pass (parallel).
- If mechanical fails: STOP, do not run agents — fix the toolchain failure first.

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` + `ai/conventions.md` — what reviewers enforce.
- `.claude/rules/*.md` — scoped to changed-path tracks.

PATH-BASED reviewer selection:
| Touched | Agent + rules to read |
|---|---|
| `apps/**/controllers/`, `services/`, `repositories/` | `api-reviewer` (+ `tenant-isolation-reviewer` if multi-tenant) |
| `app/`, `pages/`, `components/`, `*.vue`, `*.tsx`, `*.jsx`, `*.svelte`, `*.razor`, `*.component.ts` | `ui-reviewer` + `i18n-auditor` |
| DB migrations | `schema-reviewer` (internally invoke `/migration-review`) |
| `__tests__/`, `*.spec.*` | `test-reviewer` |
| `auth/`, `crypto/`, `secrets/`, `payment` | `security-auditor` |

## Phase 4 — Generate (verdict)

- ANY blocker → `REQUEST_CHANGES`, commit BLOCKED.
- Requests-only → `APPROVED_WITH_REQUESTS`, commit allowed; list surfaced.
- Nits-only or clean → `APPROVED`, commit allowed.

## Phase 5 — Update (minimal)

- No persistent file changes — this command gates, it doesn't author.
- If a recurring blocker class emerges (e.g. third commit this week with same pattern), queue to `ai/dynamic/feedback-learned.md`.

## Phase 6 — Validate (the bulk of this command)

### Mechanical (parallel, scoped to staged files)
- **Lint** — only on staged files (most linters support paths).
- **Typecheck** — affected files when toolchain supports it (`tsc --build` with project refs); else full project tsc.
- **Tests** — selective: `vitest related <files>`, `jest --findRelatedTests <files>`, `pytest --picked` (if installed); else suites covering staged paths.

If any mechanical step fails → STOP, do not run agents.

### Agent review (parallel)
- `code-reviewer` on the staged diff.
- Path-selected reviewers (table in Phase 3).
- Each returns: blockers, requests, nits.

### Self-audit
- Did every selected reviewer return? Missing reviewer = incomplete gate.
- Partial-stage check (`git add -p` half a file): lint/test scope = staged content; agents read full file from disk including unstaged lines. Note this gap in the report.

## Phase 7 — Improve

- If a blocker pattern repeats across 3+ commits, queue rule sharpening to `ai/dynamic/learned-patterns.md`.
- If an agent verdict was overridden by user, queue feedback to `ai/dynamic/feedback-learned.md` (rule may be too strict).

## Output

```
Pre-commit report  scope=4 staged files

Mechanical:
  PASS  Lint       (4 files, 0 errors)
  PASS  Typecheck  (0 errors)
  PASS  Tests      (12/12 in affected suites)

Review verdict: REQUEST_CHANGES

Blockers (1):
  src/modules/orders/orders.service.ts:42
    Raw query missing tenant filter — cross-tenant leak risk
    Fix: chain .where('order.tenant_id = :tid', { tid: this.context.tenantId }) before returning

Requests (2):
  src/modules/orders/orders.controller.ts:88
    No test for the new error path (404 when product missing)
  src/locales/en/orders.json
    Hardcoded copy in OrderList — extract orders.list.empty key

Nits (3): see full report

Commit BLOCKED until blocker resolved.
```

## Failure modes

- Blockers deferred to "next commit" — next commit still ships the blocker.
- Nits padded to look thorough — keep blockers as blockers.
- Selective test runs miss transitive regressions on critical paths — run full suite once before pushing.
- Husky/lefthook hooks treated as replacement — that layer catches mechanical issues; this layer catches design + security.
- Empty stage with `--allow-empty` style commits — don't proceed.
- Partial-stage gap (`git add -p`): agents see unstaged lines too — note in report.

## Related

### Sibling commands in code-quality pack
- `/check-health` — sibling command in code-quality pack
- `/find-module` — sibling command in code-quality pack
- `/review-changes` — sibling command in code-quality pack
- `/simplify` — sibling command in code-quality pack

### Rules
- `.claude/rules/engineering-principles.md`
- `.claude/rules/quality-principles.md`
