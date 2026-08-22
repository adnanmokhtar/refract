---
name: doc-drift-scan
description: Find docs that lie about live code, on three axes — DEAD (names something deleted), WRONG (describes an existing symbol, default, flag or signature incorrectly) and UNDOCUMENTED (public thing with no entry). Covers file paths, task names, env vars, schema, ADR links, CLI flags, signatures and examples. Run before merging a PR that touched documented code, after a refactor or rename, and weekly in CI. `quickstart-verify` executes the setup procedure; `diagram-sync` catches the same drift in diagrams.
---

# doc-drift-scan

Cross-check every claim in the `ai/` knowledge base + `CLAUDE.md` against the source tree, package manifest, env example, and migrations.

## Premise

**Three different failures wear the same word "drift", and they have three different fixes. Every finding names its axis before anything else:**

| Axis | The doc says… | …and the truth is | The fix |
|---|---|---|---|
| **DEAD** | X exists | X was deleted or renamed | delete the reference, or repoint it at the new name |
| **WRONG** | X behaves like this | X exists but behaves differently (signature, default, flag, shape) | correct the description — the reference is fine, the claim is false |
| **UNDOCUMENTED** | *nothing* | X exists and is public | write the missing entry |

Collapsing these is the classic failure of a drift report: a reader who sees "BROKEN" cannot tell whether to delete a line or rewrite it, and an absence has no doc line to cite at all so it silently never gets a row. **DEAD** and **WRONG** are both `BROKEN` in severity (a doc that lies blocks a PRODUCTION-GRADE verdict); **UNDOCUMENTED** is counted separately, because nothing is lying — something is simply missing, and a scan that folds absences into the lie count makes both numbers useless.

Find real issues, cite `<path:line>` for every drift finding. Each "MISSING" reports the doc location + the referenced artifact + the verification command that returned negative. File refs come from `rg` output; missing scripts from `jq` against `package.json`; missing env vars from grep against `.env.example`. Stale `Updated:` lines cite the days computed. No "this looks outdated" without the cross-check producing a concrete miss.

## Halt conditions

- Refuse to flag "missing file" without checking renames via `git log --diff-filter=R`.
- Refuse to flag "stale" without computing days from the `Updated:` line. The threshold is **30 days**, matching `doc-principles`, `@doc-writer` and `/doc-refresh` — one number across the pack.
- Refuse to emit a finding without its axis (`DEAD` / `WRONG` / `UNDOCUMENTED`). "Drift" alone does not tell the reader whether to delete the line or rewrite it.
- Refuse to report `UNDOCUMENTED` inside the `BROKEN` count. An absence is not a lie; merging them destroys both numbers.
- Halt if globs (`src/**`) reach the existence checker — strip them first, they're not file paths.
- Don't propose reverting code to match docs — drift is always a docs problem.

## When to use

- Before merging a PR that touched code referenced by docs.
- Weekly via CI to catch slow drift.
- After a large refactor / module rename.
- After a dependency upgrade that changed CLI commands.

## Prerequisites

- `ripgrep` (`rg`) for fast searches.
- `jq` (or the project's equivalent) for parsing the manifest's task names.
- Repo cloned with full history (drift findings cite commits).
- The project's own manifest / env example / argument-parser sources identified — the checks below are written against a Node-manifest repo as the worked instance, and resolve nothing if pointed at the wrong files.

## Procedure

1. Extract referenced file paths from docs and verify each exists:
   ```bash
   rg -oN '(?:src|apps|libs|ai)/[A-Za-z0-9_./-]+\.(ts|js|py|go|md|json)' ai/ CLAUDE.md \
     | sort -u | while IFS=: read _ p; do [[ -e "$p" ]] || echo "MISSING $p"; done
   ```
2. Extract task invocations from `CLAUDE.md` / `ai/` and resolve each against the project's OWN task source — `package.json` scripts, a `Makefile` / `Justfile` / `Taskfile` target list, `pyproject.toml`, or `pubspec.yaml`. The Node form below is one instance; substitute the project's manifest or the check silently passes by finding nothing:
   ```bash
   rg -oN '(?:bun|pnpm|npm|yarn) run [a-z:-]+' CLAUDE.md ai/ | awk '{print $NF}' | sort -u \
     | while read s; do jq -e ".scripts[\"$s\"]" package.json >/dev/null 2>&1 || echo "MISSING-SCRIPT $s"; done
   ```
3. Extract env vars from `ai/stack.md` and verify `.env.example`:
   ```bash
   rg -oN '\b[A-Z][A-Z0-9_]{3,}\b' ai/stack.md | sort -u \
     | while read v; do grep -q "^$v=" .env.example || echo "MISSING-ENV $v"; done
   ```
4. Cross-check tables/columns named in `ai/architecture.md` against the latest migration files.
5. Verify ADR cross-references resolve (each "see ADR-NNNN" maps to a file in `ai/decisions/`).
6. Check `ai/status.md` `Updated:` line age (portable: GNU date first, BSD/macOS date as fallback):
   ```bash
   updated=$(awk '/^Updated:/ {print $2}' ai/status.md)
   updated_epoch=$(date -d "$updated" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$updated" +%s 2>/dev/null)
   echo "$(( ($(date +%s) - updated_epoch) / 86400 )) days"
   ```
7. Check `ai/modules.md` rows against actual module directories — flag both directions (in-tree-not-in-docs and in-docs-not-in-tree).
8. **Documented CLI flags and options still exist (`WRONG`, and the least-checked surface).** A README, quickstart or runbook that hands the reader `--dry-run`, `--config <path>`, `-v`, an env-var switch or a subcommand is asserting that flag is still parsed. Flags are renamed and removed far more casually than functions are, and nothing else in this scan looks at them.
   - Extract every flag/option/subcommand the docs hand a reader from code fences and inline `--flag` spans.
   - Resolve each against the tool's own declaration: the argument-parser definitions in source (`argparse` / `click` / `commander` / `cobra` / `clap` / `yargs`), the manifest's script/task names, or — for a third-party CLI the docs invoke — that tool's `--help` output captured at the pinned version.
   ```bash
   # every long flag the docs hand the reader
   rg -oN -- '--[a-z][a-z0-9-]+' README.md ai/ docs/ 2>/dev/null | awk -F: '{print $NF}' | sort -u
   # then, per flag, confirm it is declared somewhere in the parser
   rg -n -- '"--dry-run"|'"'"'--dry-run'"'"'|dry_run|dryRun' src apps libs
   ```
   - Flag not declared anywhere → `DEAD` (the doc hands the reader a command that will error out).
   - Flag declared but its documented default, type, or accepted values differ from the parser → `WRONG` (`FLAG-DRIFT`).
   - Own-project flag that exists and is never documented → `UNDOCUMENTED`, only if it is user-facing.
   Precision rule: a flag inside an illustrative fence for a *third-party* tool at an unpinned version is not resolvable from this repo — mark it `UNVERIFIED (external CLI)` rather than guessing, exactly as `/add-runbook` does for live-infra commands.

9. **Signature / example accuracy** — existence checks (steps 1-7) prove a symbol *exists*; this step proves the docs describe it *correctly*. For every documented function signature, code example, or config default in `CLAUDE.md` / `ai/` / README:
   - **Signatures**: locate the real definition and diff the documented parameter names, order, types, defaults, and return type against it. Flag `SIGNATURE-DRIFT` when they differ.
     ```bash
     # e.g. docs say createUser(name); grep the definition and compare arity/params
     rg -n 'function\s+createUser|createUser\s*[=:]\s*\(|def\s+createUser' src apps libs
     ```
   - **Code examples**: trace each fenced example against source — does the import path resolve? does the call accept those arguments? does the return shape match what the example asserts? Flag `EXAMPLE-DRIFT` with the exact mismatch.
   - **Config options / defaults**: for each documented option, grep the source for the key and confirm it is still read and that the documented default matches the code default. Flag `CONFIG-DRIFT`.
   - **Deprecated references**: grep for `@deprecated` / `Deprecated` near symbols the docs still present as current; flag `DEPRECATED-REF` so docs stop steering readers to a sunset API.
   Precision rule: only flag when you have both the doc claim (`<doc:line>`) AND the source truth (`<src:line>`) in hand — never "looks wrong" without the paired citation. Skip prose that paraphrases behavior; this step is for *literal* signatures/examples/defaults.

## Output

Grouped by AXIS first (what kind of wrong), severity second. The header line is what `/doc-refresh` reads.

```
Doc drift — DEAD=2  WRONG=3  UNDOCUMENTED=2  STALE=1   (BROKEN = DEAD + WRONG = 5)

DEAD — the doc names something that no longer exists  (fix: delete or repoint)
  ai/patterns/project-structure.md:23
    References `<modules-root>/legacy/` — deleted in def456a (git log --diff-filter=D).
  README.md:64   (FLAG-DEAD)
    Hands the reader `--legacy-import`; no such flag in the parser
    (cli/args.ext:40 declares --import, --import-format). The command errors out.

WRONG — the thing exists; the doc describes it incorrectly  (fix: correct the claim)
  README.md:41   (SIGNATURE-DRIFT)
    Documents `createUser(name)` — src/users/service.ext:88 defines
    `createUser(name, options)` with required `options.email`.
  docs/config.md:12   (CONFIG-DRIFT)
    Says `retries` defaults to 5 — src/client.ext:33 default is 3.
  ai/stack.md:31   (ENV-DRIFT)
    Mentions VENDOR_API_V17 — the env example declares VENDOR_API_V20.

UNDOCUMENTED — exists in code, absent from docs  (fix: write the entry)
  <modules-root>/billing/   — no row in ai/modules.md.
  --strict-tenancy          — user-facing flag at cli/args.ext:57, in no doc.

STALE — true, but old enough to distrust  (fix: re-derive)
  ai/status.md `Updated:` is 67 days old (threshold 30).
    Since: 23 commits, 5 new modules. Run /doc-refresh.

UNVERIFIED
  ai/runbooks/restore.md:22 — `kubectl rollout status …` (external CLI, not resolvable here).

OK: 84 file refs · 12 tasks · 19 env vars · 7 ADR citations · 22 signatures/examples ·
    31 flags all resolved.
```

Note `DEPRECATED-REF` is a **WRONG** finding, not a stale one: the symbol exists, and the doc presents it as current when the code marks it sunset. That is a false claim, not an old one.

## False positives / gotchas

- Globs (`src/**/*.ts`) trigger the file-existence check incorrectly — strip patterns containing `*` before checking.
- Scripts referenced only in shell snippets inside fenced code blocks may be intentionally illustrative — read context before flagging.
- Renames done with `git mv` show as "missing" until docs update — surface the new path from `git log --diff-filter=R`.
- Drift is ALWAYS a docs issue, never a code issue — never propose reverting code to match outdated docs.

## Related

- `quickstart-verify.md` — sibling skill; this scans docs for references to dead *code*, quickstart-verify executes the *setup procedure* in a clean env to prove onboarding still runs.
- `diagram-sync.md` — the diagram complement: doc-drift-scan catches drift in *text* claims (a doc naming a dead symbol); diagram-sync catches drift in the *picture* (a box naming a dead module). Same failure family, visual surface.
- `docstring-coverage.md` — the docstring complement: this scans prose docs against the tree; docstring-coverage measures the *public API surface* for symbols missing a contract docstring. Text-drift here, symbol-coverage there.
- `/doc-refresh` (command) — **the primary caller.** It consumes this scan's `BROKEN` count (= DEAD + WRONG) as its drift gate, and a `BROKEN` > 0 forces its `INCOMPLETE` verdict. Keep the header line's shape stable; that line is a contract.
- `changelog-generate.md` — the release-notes complement: this finds docs that lie about current code; changelog-generate builds the categorized record of *what changed* from commit/PR history so the release notes never drift from git.
