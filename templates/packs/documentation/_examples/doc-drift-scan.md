---
name: doc-drift-scan
description: Find docs that lie about live code, on three axes — DEAD (names something deleted), WRONG (describes an existing symbol, default, flag or signature incorrectly) and UNDOCUMENTED (public thing with no entry). Covers file paths, task names, env vars, schema, ADR links, CLI flags, signatures and examples. Run before merging a PR that touched documented code, after a refactor or rename, and weekly in CI. `quickstart-verify` executes the setup procedure; `diagram-sync` catches the same drift in diagrams.
---

# doc-drift-scan

Cross-check every claim in the `ai/` knowledge base + `CLAUDE.md` against the source tree, package manifest, env example, and migrations.

## Premise

**Three different failures wear the word "drift", and they have three different fixes. Every finding names its axis first:**

| Axis | The doc says… | …and the truth is | The fix |
|---|---|---|---|
| **DEAD** | X exists | X was deleted or renamed | delete the reference, or repoint it |
| **WRONG** | X behaves like this | X exists, behaves differently (signature, default, flag, shape) | correct the claim — the reference is fine |
| **UNDOCUMENTED** | *nothing* | X exists and is public | write the missing entry |

A reader who sees only "BROKEN" cannot tell whether to delete a line or rewrite it, and an absence has no doc line to cite so it never gets a row at all. DEAD and WRONG are both `BROKEN` in severity; **UNDOCUMENTED is counted separately** — nothing is lying, something is missing, and folding absences into the lie count makes both numbers useless.

Find real issues, cite `<path:line>` for every drift finding. Each "MISSING" reports the doc location + the referenced artifact + the verification command that returned negative. File refs come from `rg` output; missing scripts from `jq` against `package.json`; missing env vars from grep against `.env.example`. Stale `Updated:` lines cite the days computed. No "this looks outdated" without the cross-check producing a concrete miss.

## Halt conditions

- Refuse to flag "missing file" without checking renames via `git log --diff-filter=R`.
- Refuse to flag "stale" without computing days from the `Updated:` line. Threshold **30 days**, matching `doc-principles`, `@doc-writer` and `/doc-refresh`.
- Refuse to emit a finding without its axis (`DEAD` / `WRONG` / `UNDOCUMENTED`).
- Refuse to report `UNDOCUMENTED` inside the `BROKEN` count — an absence is not a lie.
- Halt if globs (`src/**`) reach the existence checker — strip them first, they're not file paths.
- Don't propose reverting code to match docs — drift is always a docs problem.

## When to use

- Before merging a PR that touched code referenced by docs.
- Weekly via CI to catch slow drift.
- After a large refactor / module rename.
- After a dependency upgrade that changed CLI commands.

## Prerequisites

- `ripgrep` (`rg`) for fast searches.
- `jq` for parsing `package.json` scripts.
- Repo cloned with full history (drift findings cite commits).

## Procedure

1. Extract referenced file paths from docs and verify each exists:
   ```bash
   rg -oN '(?:src|apps|libs|ai)/[A-Za-z0-9_./-]+\.(ts|js|py|go|md|json)' ai/ CLAUDE.md \
     | sort -u | while IFS=: read _ p; do [[ -e "$p" ]] || echo "MISSING $p"; done
   ```
2. Extract `bun run X` / `pnpm run X` / `npm run X` invocations from `CLAUDE.md` and check `package.json`:
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
8. **Documented CLI flags still exist** — the least-checked surface, and flags are removed far more casually than functions. Extract every `--flag` / option / subcommand the docs hand a reader (fences + inline spans) and resolve each against the tool's own declaration: the argument-parser source (`argparse` / `click` / `commander` / `cobra` / `clap` / `yargs`), the manifest's task names, or a third-party CLI's `--help` at the pinned version. Not declared → `DEAD` (the doc hands the reader a command that errors out). Declared but documented default / type / accepted values differ → `WRONG` (`FLAG-DRIFT`). Exists, user-facing, undocumented → `UNDOCUMENTED`. A flag for an unpinned third-party tool is `UNVERIFIED (external CLI)`, never a guess.
9. Signature / example accuracy: diff documented function signatures, code examples, and config defaults against the real source symbol (`SIGNATURE-DRIFT` / `EXAMPLE-DRIFT` / `CONFIG-DRIFT`); flag docs presenting an `@deprecated` symbol as current (`DEPRECATED-REF`). Cite both `<doc:line>` and `<src:line>`.

## Output

Grouped by AXIS first, severity second. The header line is what `/doc-refresh` reads.

```
Doc drift — DEAD=2  WRONG=3  UNDOCUMENTED=2  STALE=1   (BROKEN = DEAD + WRONG = 5)

DEAD — names something that no longer exists  (fix: delete or repoint)
  ai/patterns/project-structure.md:23
    References `<modules-root>/legacy/` — deleted in def456a (git log --diff-filter=D).
  README.md:64   (FLAG-DEAD)
    Hands the reader `--legacy-import`; the parser declares --import, --import-format
    (cli/args.ext:40). The command errors out.

WRONG — the thing exists; the doc describes it incorrectly  (fix: correct the claim)
  README.md:41   (SIGNATURE-DRIFT)
    Documents `createUser(name)` — src/users/service.ext:88 defines
    `createUser(name, options)` with required `options.email`.
  docs/config.md:12   (CONFIG-DRIFT)
    Says `retries` defaults to 5 — src/client.ext:33 default is 3.
  CLAUDE.md:57   (DEPRECATED-REF)
    Presents `legacyAuth()` as current — src/auth.ext:9 marks it `@deprecated`.

UNDOCUMENTED — exists in code, absent from docs  (fix: write the entry)
  <modules-root>/billing/   — no row in ai/modules.md.
  --strict-tenancy          — user-facing flag at cli/args.ext:57, in no doc.

STALE — true, but old enough to distrust  (fix: re-derive)
  ai/status.md `Updated:` is 67 days old (threshold 30). Run /doc-refresh.

OK: 84 file refs · 12 tasks · 19 env vars · 7 ADR citations · 22 signatures/examples ·
    31 flags all resolved.
```

`DEPRECATED-REF` is **WRONG**, not stale: the symbol exists and the doc presents it as current when the code marks it sunset. A false claim, not an old one.

## False positives / gotchas

- Globs (`src/**/*.ts`) trigger the file-existence check incorrectly — strip patterns containing `*` before checking.
- Scripts referenced only in shell snippets inside fenced code blocks may be intentionally illustrative — read context before flagging.
- Renames done with `git mv` show as "missing" until docs update — surface the new path from `git log --diff-filter=R`.
- Drift is ALWAYS a docs issue, never a code issue — never propose reverting code to match outdated docs.
- A flag in an illustrative fence for an unpinned third-party tool is not resolvable from this repo — `UNVERIFIED (external CLI)`, never a guess.

## Related

- `/doc-refresh` (command) — **the primary caller.** It consumes `BROKEN` (= DEAD + WRONG) as its drift gate; `BROKEN` > 0 forces its `INCOMPLETE` verdict. The header line's shape is a contract.
- `quickstart-verify` — this scans docs for references to dead *code*; that executes the *setup procedure* in a clean env.
- `diagram-sync` — the same failure family on the *picture* surface.
- `docstring-coverage` — measures the public surface for symbols missing a contract docstring; the `UNDOCUMENTED` axis here is its prose counterpart.
