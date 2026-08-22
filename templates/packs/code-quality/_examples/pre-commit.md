---
description: Commit gate on the STAGED index — the project's own lint/typecheck/test on staged scope (halt on red), then agent review, secret-scan and coverage-gap on every staged file, then a comprehension brief. Refuses the commit on any blocker. Anti-triggers: the whole-branch PR review is `/review-changes` (which also owns the shared reviewer routing table); the no-diff weekly repo pulse is `/check-health`; ranking and fixing at target scale is `/audit`.
---

# /pre-commit

Run right before committing. Scoped to staged diff only — faster than `/check-health`.

## The Premise (read this first, internalize, do not deviate)

**Existing checks are the truth. Mirror the project's lint/typecheck/test commands; don't inject new ones.** The repo already declares its quality gates — manifest scripts, `Makefile` targets, `pyproject.toml`, the pre-commit/hook config, the project's `CLAUDE.md` quality section. This command runs THOSE commands on the staged scope. It does NOT introduce a parallel toolchain, add stricter flags, or reformat with a different style.

**The closure verb is `gate`.** This command never authors files. It returns exactly one of `APPROVED` (mechanical green + agent green), `APPROVED_WITH_REQUESTS` (green with non-blocking notes), or `REQUEST_CHANGES` (at least one blocker; commit refused).

**Forbidden:** asking the user style-flag questions ("tabs or spaces?", "max line length?") — the project's lint config is the answer, fix to match; inventing a typecheck/lint/test command the project does not declare; continuing past a red mechanical step to "see what the agents say"; padding nits to look thorough.

**Mechanical halt — refuse to advance on red:** if lint / typecheck / test returns non-zero on the staged scope, the gate HALTS at the mechanical phase, does NOT dispatch agents, and emits nothing beyond `REQUEST_CHANGES (mechanical-red)`. Fix the toolchain failure, re-stage, re-run.

**Lightweight default.** Staged scope only. No full-repo passes, no historical commits, no rebuild from clean.

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
| `app/`, `pages/`, `components/`, `*.vue`, `*.tsx` | `ui-reviewer` + `i18n-auditor` |
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

### Comprehension gate (change-brief)
- Dispatch the `change-brief` skill (mode B — validate; mode A — generate first if the commit body has none) when the staged change matches a trigger tier (> 20 lines, new dependency / public symbol / abstraction, touches I/O / auth / payments, changes an error path / default / permission gate).
- The brief's 5 fields (What / Why this shape / Edge cases / Blast radius / Verified by) must PASS the skill's hand-wave + citation + echo + verification checks. Missing or failing brief = **blocker** — "the code runs" is not "the code is owned".
- Exempt: typo/comment fixes, mechanical renames, formatting, lockfile-only, generated files. Don't manufacture ceremony on trivial diffs.

### Mechanical (parallel, scoped to staged files)
- **Lint** — only on staged files (most linters support paths).
- **Typecheck** — affected files when toolchain supports it (`tsc --build` with project refs); else full project tsc.
- **Tests** — selective: `vitest related <files>`, `jest --findRelatedTests <files>`, `pytest --picked` (if installed); else suites covering staged paths.

If any mechanical step fails → STOP, do not run agents.

### Agent review (parallel)
- `code-reviewer` on the staged diff.
- Path-selected reviewers (table in Phase 3).
- Each returns: blockers, requests, nits.

### Universal skill checks (every run, regardless of which paths were touched)

A commit is the last moment a secret can be stopped cheaply. After it lands, removal means a history rewrite and a credential rotation. So the two category-independent checks run **here**, earlier than `/review-changes`, not later:

- **`secret-scan` on every staged file.** Not just `auth/` — a key in a test fixture, a seed script, or a config default is the same leak. A real secret is a **blocker**: the commit is refused. No skill installed → inline check over the *added* lines: high-entropy strings plus known prefixes (`AKIA`, `sk-`, `ghp_`, `xoxb-`, `-----BEGIN * PRIVATE KEY-----`, `postgres://…:…@`). Also refuse an accidentally-staged credential FILE (`.env`, `*.pem`, `*.p12`, `id_rsa`, service-account JSON) regardless of content.
- **`coverage-gap` on staged lines.** New behaviour with no covering test is a finding **even when no test file was staged** — otherwise `test-reviewer` never dispatches (its trigger is a staged test path) and the gap is structurally invisible. Request by default; **blocker** on a security / data-integrity / write-path change.

**Never silently skip either axis** — a skipped axis reads as "clean" when it was never checked. Note the substitution (`inline:<skill-name>`).

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
