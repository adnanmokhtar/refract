# Learned patterns (watch list)

Patterns observed in the code or in AI interactions that aren't yet formal `ai/patterns/` entries — but might graduate. The `pattern-emergence-watcher` agent appends here; `knowledge-curator` promotes to formal patterns.

## Promotion criteria (Rule of Three — same wording as the curators + watcher + /promote-pattern)

- **≥3 occurrences** of the same behavioural shape (3+ files, or the same fix recipe applied across 3+ PRs) **AND ≥2 weeks** held up. Both gates required for `READY`; 2 occurrences is duplication, not a pattern.
- Has a clear name, problem statement, and at least one worked example.
- Doesn't contradict an existing formal pattern (if it does, the existing one needs updating, not a competing pattern).

## Format per entry

```
### <pattern name>
First seen: <YYYY-MM-DD>
Occurrences: <N> (paths: file:line, file:line, ...)
Status: WATCHING | READY | PROMOTED → ai/patterns/<name>.md | REJECTED

Description: <1-2 sentences>
Worked example: <path or inline code>
Related: <links to existing patterns / rules>

Decision needed: <PROMOTE | EXPAND | DISCARD>
```

## Lifecycle

1. `pattern-emergence-watcher` agent (or human) finds a recurring shape → appends entry with status `WATCHING`.
2. As more occurrences appear, `Occurrences` count + paths grow.
3. When count ≥3 + 2 weeks have passed, status becomes `READY`.
4. `/promote-pattern <name>` graduates it: writes formal `ai/patterns/<name>.md` with full structure (context, problem, solution, example, trade-offs, common mistakes, testing). Entry here marked `PROMOTED → <path>`.
5. If pattern fades or proves wrong, mark `REJECTED` with reason; archive after a month.

## Empty?

Empty until either the watcher agent runs or a human appends. The presence of this file is the invitation.

## See also

- `ai/patterns/` — formal patterns (graduation destination).
- `ai/dynamic/drift-log.md` — convention divergence (related signal).
- `.claude/agents/pattern-emergence-watcher.md` — agent that populates this file.
- `.claude/agents/knowledge-curator.md` — agent that promotes entries.
