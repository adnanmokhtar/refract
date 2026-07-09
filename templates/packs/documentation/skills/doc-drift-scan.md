---
name: doc-drift-scan
description: Find docs that describe code that no longer exists. Catches the silent lie — outdated docs are worse than missing docs.
---

# doc-drift-scan

Cross-check every claim in the `ai/` knowledge base + `CLAUDE.md` against the source tree, package manifest, env example, and migrations.

## Premise

Find real issues, cite `<path:line>` for every drift finding. Each "MISSING" reports the doc location + the referenced artifact + the verification command that returned negative. File refs come from `rg` output; missing scripts from `jq` against `package.json`; missing env vars from grep against `.env.example`. Stale `Updated:` lines cite the days computed. No "this looks outdated" without the cross-check producing a concrete miss.

## Halt conditions

- Refuse to flag "missing file" without checking renames via `git log --diff-filter=R`.
- Refuse to flag "stale" without computing days from the `Updated:` line.
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
8. **Signature / example accuracy** — existence checks (steps 1-7) prove a symbol *exists*; this step proves the docs describe it *correctly*. For every documented function signature, code example, or config default in `CLAUDE.md` / `ai/` / README:
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

```
Doc drift — 4 findings

BROKEN (blockers):
  ai/patterns/project-structure.md:23
    References `<modules-root>/legacy/` which was deleted in commit def456a.

  ai/stack.md:31
    Mentions VENDOR_API_V17 — actual .env.example has VENDOR_API_V20.

  README.md:41  (SIGNATURE-DRIFT)
    Documents `createUser(name)` — src/users/service.ts:88 defines
    `createUser(name, options)` with required `options.email`.

  docs/config.md:12  (CONFIG-DRIFT)
    Says `retries` defaults to 5 — src/client.ts:33 default is 3.

STALE:
  ai/status.md `Updated:` is 67 days old.
    Since: 23 commits, 5 new modules. Run /doc-refresh.

  ai/modules.md
    Missing row for `<modules-root>/billing/` (exists in code, not in docs).

  CLAUDE.md:57  (DEPRECATED-REF)
    Presents `legacyAuth()` as current — src/auth.ts:9 marks it `@deprecated`.

OK: 84 file refs, 12 scripts, 19 env vars, 7 ADR citations, 22 signatures/examples all resolved.
```

## False positives / gotchas

- Globs (`src/**/*.ts`) trigger the file-existence check incorrectly — strip patterns containing `*` before checking.
- Scripts referenced only in shell snippets inside fenced code blocks may be intentionally illustrative — read context before flagging.
- Renames done with `git mv` show as "missing" until docs update — surface the new path from `git log --diff-filter=R`.
- Drift is ALWAYS a docs issue, never a code issue — never propose reverting code to match outdated docs.

## Related

- `quickstart-verify.md` — sibling skill; this scans docs for references to dead *code*, quickstart-verify executes the *setup procedure* in a clean env to prove onboarding still runs.
