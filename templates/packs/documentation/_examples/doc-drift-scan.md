---
name: doc-drift-scan
description: Find docs that describe code that no longer exists. Catches the silent lie — outdated docs are worse than missing docs.
---

# doc-drift-scan

Cross-check every claim in the `ai/` knowledge base + `CLAUDE.md` against the source tree, package manifest, env example, and migrations.

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

## Output

```
Doc drift — 4 findings

BROKEN (blockers):
  ai/patterns/project-structure.md:23
    References `src/modules/legacy/` which was deleted in commit def456a.

  ai/stack.md:31
    Mentions WHATSAPP_API_V17 — actual .env.example has WHATSAPP_API_V20.

STALE:
  ai/status.md `Updated:` is 67 days old.
    Since: 23 commits, 5 new modules. Run /doc-refresh.

  ai/modules.md
    Missing row for `src/modules/billing/` (exists in code, not in docs).

OK: 84 file refs, 12 scripts, 19 env vars, 7 ADR citations all resolved.
```

## False positives / gotchas

- Globs (`src/**/*.ts`) trigger the file-existence check incorrectly — strip patterns containing `*` before checking.
- Scripts referenced only in shell snippets inside fenced code blocks may be intentionally illustrative — read context before flagging.
- Renames done with `git mv` show as "missing" until docs update — surface the new path from `git log --diff-filter=R`.
- Drift is ALWAYS a docs issue, never a code issue — never propose reverting code to match outdated docs.
