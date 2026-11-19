# Feedback learned (project-scoped)

User corrections taken during AI-assisted work — captured here so future sessions / other agents don't repeat the same mistake.

This is the PROJECT-LOCAL mirror of the user's global feedback memory (`~/.claude/projects/<project>/memory/feedback_*.md`). The global memory persists across all your projects; this file persists across all sessions in THIS project, even if a different driver (Cursor, OpenCode, Cline) is used.

## Format per entry

```
### <YYYY-MM-DD> — <short rule>
Source: <session ref / commit / PR>
Repeated: <count of times this correction has been given>
Scope: <where this applies — specific module / specific layer / project-wide>
Lasts: standing | session-only

Rule: <imperative sentence — "always X" / "never Y">

Why: <user's reasoning, in their words if possible>

How to apply:
<concrete guidance — what trigger fires this rule, what the correct alternative is>

Status: WATCHING (1 occurrence) | RULE_CANDIDATE (2+ occurrences, or one explicit standing statement) | PROMOTED → <rule path> | REJECTED | SUPERSEDED → <newer entry>
```

## Lifecycle

1. User corrects AI: "don't do X, do Y instead." → `update-session-log.sh` (or `/learn-from-task`) appends entry, status `WATCHING`.
2. Same correction given again → `Repeated` count increments; status becomes `RULE_CANDIDATE`. A correction stated as standing the first time — "always", "never", "from now on", "make it a rule" — is a `RULE_CANDIDATE` at once; the person already said it is not a one-off.
3. `knowledge-curator` (or manual) promotes a `RULE_CANDIDATE` to a formal `.claude/rules/<name>.md` entry. Original entry marked `PROMOTED`.
4. If correction proves wrong (user reverses position), mark `REJECTED` with reason.
5. **Newer wins.** A later statement that contradicts an earlier entry marks the earlier one `SUPERSEDED → <newer entry>`, both dated, so nobody re-litigates which one holds.

**A permission is not a rule.** "Merge it tonight", "you may push this branch", "skip the tests this
time" are `Lasts: session-only`: they authorise one session and die with it. They are never written
here, to `.claude/rules/`, or to memory as anything that a later session could read as standing
permission — a written-down one-night permission becomes a standing one the person never gave.

## Why this matters

Without persisting feedback project-locally:
- Switching drivers (Claude Code → Cursor) loses the learning.
- New team members joining don't see the corrections.
- Even within Claude Code, only YOUR sessions remember; teammates start fresh.

With it:
- Every agent's pre-flight reads this file; the same mistake doesn't get made twice.
- Cross-driver portability: `AGENTS.md` reference includes pointers here.
- Onboarding gain: "here's what we've learned NOT to do" is concrete.

## See also

- `~/.claude/projects/<project>/memory/MEMORY.md` — global (cross-project, your machine only) feedback memory.
- `.claude/rules/` — promoted formal rules.
- `.claude/agents/knowledge-curator.md` — agent that promotes entries.
