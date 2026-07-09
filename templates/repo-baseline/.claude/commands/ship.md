---
description: Take uncommitted work from working tree → commit → push → PR, with a confirmation gate at every step. Never-stage guard (secrets, lock churn, build output), upstream handling, conventional-commit synthesis, and optional stale-branch cleanup. The standalone delivery flow — distinct from /pre-commit (a gate that never authors) and from a command's own final PR step.
allowed-tools: [Read, Grep, Glob, Bash]
---

# /ship

> **Scope.** `/ship` is the *delivery* command: it turns whatever is in your working tree into a reviewed PR. It is NOT a code-quality gate — `/pre-commit` reviews a diff and returns APPROVED/REQUEST_CHANGES without ever staging or committing; `/ship` consumes that verdict and actually ships. Commands like `/fix-bug` / `/add-feature` end with their *own* commit+PR step for the work they authored; `/ship` exists for arbitrary hand-written or multi-command work that has no home flow.

## The Premise (read this first, internalize, do not deviate)

**The working tree is the source of truth; every step is reversible until the push.** The agent's job is to package what exists into a clean commit and a reviewable PR — not to write code, not to "finish" the feature, not to fix lint it happens to notice. Confirmation is mandatory at each irreversible boundary (stage, commit, push, PR-open) because the human owns the delivery decision.

**The agent does NOT:**
- Author or edit source to "complete" the work. If the diff looks unfinished, say so and stop — shipping is the user's call.
- Stage files on the never-stage list (below) without an explicit override.
- Push to a protected branch, force-push, or run `--no-verify`.
- Squash unrelated changes into one commit — if the tree mixes two concerns, offer to split.

**The agent ONLY proceeds past a gate when the user confirms** — or when invoked with `--yes` (CI / trusted-loop use), which pre-confirms every gate EXCEPT a never-stage-list hit or a secret finding, which always halt.

## Usage

```
/ship                       # interactive: scan → confirm each step → PR
/ship "<commit subject>"    # seed the commit subject (still confirmed)
/ship --yes                 # pre-confirm gates (secrets/never-stage still halt)
/ship --no-pr               # commit + push, skip PR
/ship --cleanup             # after PR, prune local branches whose upstream is [gone]
```

## Never-stage list (mechanical halt)

Refuse to stage — halt and report, even under `--yes`:

- Secret-bearing content: anything `secret-scan.sh` would flag (API keys, tokens, private keys, connection strings). Re-use the same shapes; do not re-implement loosely.
- `.env`, `.env.*`, `*.pem`, `*.key`, `*.crt`, `*.p12`, `*.pfx`, `id_rsa`, `credentials.json`.
- Build output / deps: `node_modules/`, `dist/`, `build/`, `.next/`, `target/`, `__pycache__/`, `.venv/`.
- A lock file changed with **no** corresponding manifest change (`package-lock.json` moved but `package.json` didn't) — usually accidental churn; confirm explicitly.

If a never-stage file is genuinely intended (e.g. adding a new `*.crt` fixture), the user names it explicitly and re-runs; `/ship` does not guess.

## Procedure

### 1. Scan (read-only)

- `git status --porcelain` + `git diff --stat` + `git diff` (staged and unstaged).
- Current branch. If it is a protected branch (`main`/`master`/`git config init.defaultBranch`, or `CLAUDE_PROTECTED_BRANCHES`), **halt**: offer to create `feature/<slug>` from here and move the changes to it. Never commit product changes straight onto a protected branch.
- Run the never-stage scan over every changed path + the diff content. Any hit → halt with the file list.
- Detect concern-mixing: if the diff spans clearly unrelated areas (e.g. an auth fix + an unrelated README rewrite), surface it and offer to stage/commit them separately.

### 2. Stage — CONFIRM

Propose the exact `git add` set (explicit paths, never `git add -A` blind). Show it. On confirm, stage.

### 3. Commit — CONFIRM

Synthesize a Conventional-Commit message from the diff: `type(scope): subject` (≤72-char subject), a body explaining *why* when non-obvious, and any `BREAKING CHANGE:` / issue trailer. Show the full message. On confirm, `git commit` (respecting the project's own commit hooks — never `--no-verify`).

### 4. Push — CONFIRM

- New branch with no upstream → `git push -u origin <branch>`.
- Existing upstream → `git push` (fast-forward only). If the remote has diverged, **halt** and report — do not force-push; tell the user to reconcile (`git pull --rebase`) themselves.

### 5. PR — CONFIRM (skip with `--no-pr`)

- Require `gh` + auth (`gh auth status`); if absent, print the branch + a ready-to-paste PR title/body and stop.
- Title = commit subject. Body = what/why + a Testing section derived from what the diff touched + `Fixes #N` when an issue is referenced.
- `gh pr create`; print the URL.

### 6. Cleanup — opt-in (`--cleanup`)

After the PR is open, offer to prune local branches whose upstream is gone:

```
git fetch --prune
git for-each-ref --format '%(refname:short) %(upstream:track)' refs/heads \
  | awk '$2=="[gone]"{print $1}'
```

List candidates, CONFIRM, then delete each (`git branch -D` is fine here — these are merged/deleted-upstream branches; still confirm the list first).

## Output format

```
## /ship — <branch> → <PR title>

Staged:      <N files> (<M> excluded by never-stage: <reason>)
Commit:      <type(scope): subject>  (<sha>)
Push:        <branch> → origin (<new upstream | fast-forward>)
PR:          <url>  (or: "skipped (--no-pr)" / "gh unavailable — body printed above")
Cleanup:     <N branches pruned | not run>

Halts hit:   <none | never-stage: <files> | diverged remote | protected branch>
```

## Hard rules

- **Never author or edit product code.** `/ship` packages; it does not build.
- **Confirm every irreversible step.** Stage / commit / push / PR / branch-delete each gate on the user (or `--yes`, minus the always-halt cases).
- **Secrets and the never-stage list halt unconditionally** — `--yes` does not override them.
- **Never force-push, never `--no-verify`, never push to a protected branch.** These overlap `guard-destructive.sh`; `/ship` refuses them at the command level too so the intent is explicit, not just hook-blocked.
- **Explicit `git add <paths>`**, never blind `-A`.

## Failure modes

- Staged a generated lock-file churn as if it were a real change (caught by the manifest-pairing check).
- Committed two concerns as one (caught by concern-mixing detection — offer the split).
- Opened a PR from a protected branch because the scan step was skipped.
- Pushed with a diverged remote and clobbered a teammate's commit (prevented — diverged remote halts, never force-pushes).

## Related

- `/pre-commit` — the review *gate* (`APPROVED`/`REQUEST_CHANGES`); run it before `/ship` for a quality check. `/ship` is the delivery step, not a reviewer.
- `guard-destructive.sh` — the always-on hook that also blocks force-push / protected-branch push; `/ship`'s rules mirror it intentionally.
- `/catchup handoff` — write a handoff note before stepping away; `/ship` is for when the work is done, not paused.
