---
name: extract-failures-from-history
description: Round-two extraction of recurring failure themes from git log + postmortem docs (if accessible). Walks `git log` for revert/hotfix/incident/regression/rollback messages, reads the diffs, groups by theme, and produces a list of failure families with affected files + commit refs + root-cause family. Used by /setup-project Phase 2.12 in REFINE mode to materialize `ai/failures/<theme>.md` files that future agents inject in pre-flight (per the architectural-agent failure-catalog Hard Rule).
---

# Skill: extract-failures-from-history

## Purpose

A failure that happened once is a story. A failure family that happened 4 times across 18 months is an architectural lesson. Round-two reads the project's actual history and finds the lessons.

The output drives `ai/failures/<theme>.md` generation in Phase 4.7-DEEP, which architectural agents must inject in pre-flight (per Hard Rule). Without this step, agents propose ideas that already failed in this codebase.

## When to use

- `/setup-project --refine` Phase 2.12 — once per project.
- Manually when a developer says "we keep hitting <X> bug" and wants the failure recorded as a permanent lesson.

## Inputs

- `lookback` (default: 24 months OR all-time if repo is younger).
- `min_theme_occurrences` (default: 2 — a theme must have ≥ 2 instances to count as recurring).
- `extra_doc_paths` (optional) — explicit user-opted paths like `docs/postmortems/`, `docs/incidents/`, `INCIDENTS.md`. Skipped unless user passes `--include-incidents=<path>` to setup-project.
- `output_section` — section path (default: `## Failure history`).

## Procedure

### Step 1 — Establish git accessibility

Run `git log --oneline -1`. If git not accessible (no `.git/`, shallow clone, permission error), abort with `[REFINE-WEAK: failures — git not accessible]`.

Run `git log --pretty=format:'%h %s' --since='<lookback> ago' | wc -l`. Need ≥ 30 commits to do useful theme grouping. If less, flag `[REFINE-WEAK: failures — too few commits]`.

### Step 2 — Sweep commit messages for failure-marker keywords

Search the git log for case-insensitive matches:

```bash
git log --pretty=format:'%h%x00%s%x00%b%x00%cd%x00%an' --since='<lookback> ago' \
  | grep -iE '\b(revert|hotfix|incident|regression|rollback|outage|fix.{0,30}critical|fix.{0,30}prod|emergency|p0|p1|sev1|postmortem|fire|broke|broken|outage|panic|crash|leak|exploit|vulnerability)\b'
```

For each match, extract:
- SHA (`%h`).
- Subject (`%s`) — first line.
- Body (`%b`) — full description (often empty; sometimes contains the cause).
- Date (`%cd`).
- Author (`%an`) — for grouping context, NOT for blame.

### Step 3 — Read the diffs

For each candidate commit, run `git show --stat <sha>` to get the affected files. For commits with non-trivial diffs (< 200 LOC changed), run `git show <sha>` and skim the actual change.

Note:
- Affected files (top 3 by lines changed).
- Affected functions (if extractable from hunk headers).
- Type of change: revert? add validation? add null-check? add transaction? add idempotency? change query plan? add index? cache-related? auth-related?

### Step 4 — Group commits by theme

Define candidate themes:

| Theme | Markers |
|---|---|
| `auth-bypass` | auth, permission, role, token, jwt, session |
| `n-plus-1-perf` | N+1, slow query, timeout, prefetch, eager-load, query optimization |
| `migration-drift` | migration, schema, rename, drop column, foreign key |
| `payment-double-charge` | payment, charge, refund, idempotency, duplicate |
| `tenant-leak` | tenant, multi-tenant, cross-tenant, scope |
| `cache-invalidation` | cache, stale, TTL, invalidat |
| `concurrency-bug` | race, concurrent, deadlock, lock, transaction-isolation |
| `null-handling` | null, NoneType, undefined, NPE |
| `rate-limit-storm` | rate-limit, throttle, retry-storm, thundering-herd |
| `data-loss` | data-loss, accidentally deleted, bug deletes |
| `email-blast` | email, notification, accidentally sent |
| `secret-leak` | secret, credential, key leaked, token exposed |
| `external-api-flake` | webhook, vendor, retry, idempotency-key, third-party |

Group each commit into the theme with the strongest marker match. If multiple match, pick by the commit body's specifics, then by file path (e.g. `app/auth/*` → `auth-bypass`). If none match, group as `other` (don't lose them).

### Step 5 — Cross-reference with existing `ai/failures/_index.md`

If round-one wrote any failures (e.g. via `business-auditor` running before REFINE), read them. For each existing failure:

- Check if the new extraction surfaces it (avoid double-counting).
- Check if the existing failure has a `status:` field (`active`, `validated_failure`, `superseded_by_<adr>`). Append-only — never modify existing.

### Step 6 — Filter to recurring themes

Apply `min_theme_occurrences` (default 2). A theme with 1 instance is a story; ≥ 2 is a recurring lesson. Single-occurrence findings go into `## one-off failures` (not promoted to `ai/failures/<theme>.md`).

### Step 7 — Read postmortem docs (opt-in only)

If `extra_doc_paths` was provided AND those paths exist:

- Read every `.md` in those paths.
- Look for headings like `## Cause`, `## Resolution`, `## Prevention`, `## Lessons`.
- Map each to a theme.
- Cross-reference with the git-extracted commits (often the postmortem mentions the SHA).

This step requires explicit opt-in via `--include-incidents=<path>` because postmortem docs are sensitive — they may contain customer references, internal financial impact, blameful language.

### Step 8 — Output

Write to `.claude/_refine-extract.md` under `## Failure history`:

```yaml
extraction_date: <YYYY-MM-DD>
git_lookback: <duration>
total_commits_scanned: <N>
candidate_failure_commits: <N>
strong_signals: ["recurring-themes", "diff-analyzed", "postmortems-read"]   # subset present

recurring_themes:
  - theme: <e.g. auth-bypass>
    occurrences: <N>
    status: active  # default; user can change to validated_failure / superseded_by_ADR-NNNN later
    affected_files:
      - <file/path/sample.py>     # top 3 by frequency across the N commits
    commits:
      - { sha: <hash>, subject: <subject>, date: <YYYY-MM-DD> }
      # ≤ 5 representative commits; full list goes in ai/failures/<theme>.md if STRONG
    root_cause_family: |
      <2-3 sentence narrative — what kind of mistake recurs.
       e.g. "Permissions checked at controller layer but bypassed when service layer
       was called from a background job that didn't propagate the user context."
       Cite the most representative commit's diff inline.>
    prevention_checklist:
      - <bullet — concrete check a future agent can run in pre-flight>
      - <bullet>
    cited_postmortem: <docs/postmortems/2025-04-15-cross-tenant-data.md>   # if extra_doc_paths set

one_off_failures:
  - { theme: <name>, sha: <hash>, subject: <subject>, date: <YYYY-MM-DD> }
  # short list — recorded for completeness, not promoted to ai/failures/<theme>.md
```

## Quality gate

- **STRONG**: ≥ 2 recurring themes (each with ≥ 2 occurrences) extracted, ≥ 1 with prevention-checklist of ≥ 3 bullets.
- **MEDIUM**: 1 recurring theme found.
- **WEAK**: 0 recurring themes (codebase too young, history too clean, or the team lands all hotfixes outside main). Output `## No recurring failure themes` finding. Phase 4.7-DEEP will NOT generate `ai/failures/<theme>.md` files in this case.

## Privacy / safety

- **Never extract failure-history content from any source the user hasn't opted into.** The skill stays inside the repo + local git log; no external bug-tracker calls; no Sentry / Datadog API calls; no Slack scraping.
- **Postmortem docs are opt-in** via `--include-incidents=<path>`. Default: skip.
- **Customer names / specific dollar amounts / individual employee blame** must NOT appear in the output. If the extraction encounters them in commit messages or postmortem bodies, sanitize:
  - Replace customer names with `<customer>`.
  - Replace dollar amounts with `<significant-amount>`.
  - Strip individual names from blame contexts (group context — "the team / engineer who ..." — is fine).
- **Public repo check**: if the project's git remote is a public host (github.com/<user>/<repo> with public visibility), warn the user before writing `ai/failures/<theme>.md` files, since the file will be committed and visible. The user can choose to gitignore `ai/failures/` or proceed.

## Anti-patterns

- **Treating every revert as an incident** — many reverts are benign (deps update broke build, revert, fix forward in 10 minutes). Read the diff before classifying.
- **Calling a single-occurrence bug a recurring failure** — the threshold is the protection. A one-off is a story; a pattern is a lesson.
- **Inventing a theme not represented in commits** — if `cache-invalidation` doesn't appear in any commit, it's not a finding.
- **Naming individual engineers** — failure catalog is institutional learning, not blame. Strip names.
- **Extracting from a fork's `main` while ignoring `develop`** — many shops do hotfixes on `main` and feature work on `develop`. Walk both.
- **Skipping commit bodies** — the subject is often terse ("fix bug"); the body has the details. Always read both.
