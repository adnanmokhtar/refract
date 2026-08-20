---
phase: 6
name: learn
applies-to-modes: [all — runs continuously after setup]
inputs: [in-flight session events, ai/dynamic/, audits, corrections]
outputs: [updated _session-digest.md, _convention-cheatsheet.md, _decision-index.md, ADRs, learnings]
exit-criteria: never — Phase 6 is the continuous loop. Runs forever after setup completes.
triggers:
  - post-task hook
  - weekly cron via /schedule
  - manual /learn-from-task
budget: ai/ ≤ 50 files; each ≤ 300 lines (M3 ceiling enforced by knowledge-curator agent)
---

## Phase 6 — Continuous learning loop (the system that lives with the project)

Setup is the START, not the end. The knowledge base must continuously evolve as code, decisions, and conventions change. Phase 6 wires the mechanisms that keep `ai/` + `.claude/` in sync with reality.

### The persistence pyramid

Knowledge has layers, ordered from MOST stable (top) to MOST fluid (bottom). Information FLOWS UPWARD as evidence accumulates — a raw observation today might become a formal ADR in 3 weeks if the pattern holds.

```
TOP (formal, append-only, rare changes)
├── ai/decisions/                ← formal ADRs (one per major decision; superseded but never deleted)
├── ai/core/                     ← entities, glossary, stakeholders, invariants (changes quarterly)
├── ai/business-domain.md        ← what kind of product (changes on pivot)
├── ai/project-goals.md          ← mission + KPIs (changes when strategy shifts)
├── ai/conventions.md            ← auto-detected style (refreshed on `/refresh-knowledge`)
├── ai/architecture.md           ← layer + component overview
├── ai/patterns/                 ← worked examples (evolves with codebase practice)
├── ai/runbooks/                 ← operational guides (grows from incidents + feature ships)
├── ai/status.md                 ← current state, in-flight work, recent changes
├── ai/dynamic/changelog.md      ← recent code changes (hook-appended every commit; .gitignored local state — see Phase 4.1)
├── ai/dynamic/session-log.md    ← per-session summary (Stop hook; .gitignored local state — see Phase 4.1)
├── ai/dynamic/learned-patterns.md ← emerging patterns being watched (NEW — promotion candidates)
├── ai/dynamic/drift-log.md      ← code-vs-convention divergence findings (NEW)
├── ai/dynamic/interaction-log.md ← what AI has worked on across sessions (NEW)
├── ai/dynamic/feedback-learned.md ← user corrections taken (NEW — global memory mirror)
└── ai/dynamic/decisions-pending.md ← informal decisions waiting to graduate to ADR (NEW)
BOTTOM (raw, high-churn)
```

### Promotion rules — how raw knowledge graduates to formal

| From → To | Trigger |
|---|---|
| `dynamic/learned-patterns.md` → `ai/patterns/<name>.md` | Pattern observed in 3+ files OR explicitly used in 2+ PRs |
| `dynamic/decisions-pending.md` → `ai/decisions/<NNNN>-<slug>.md` | Decision survives 2 weeks without being reversed AND influences ≥2 code changes |
| `dynamic/feedback-learned.md` → `.claude/rules/<rule>.md` | Same correction given 2+ times OR aligns with a documented rule that needs strengthening |
| `dynamic/drift-log.md` finding → action | Resolved either by (a) updating code to match convention OR (b) updating convention to match new reality OR (c) writing ADR explaining intentional divergence |
| `dynamic/glossary-evolution.md` entries → `ai/core/glossary.md` | New entity referenced in 5+ files OR explicitly declared in `ai/business-domain.md` |
| `dynamic/changelog.md` entries → `ai/status.md` Recent Changes | Significant feature ship OR architectural change |

`knowledge-curator` agent (see Phase 6 agents below) runs these promotion rules manually (`/promote-pattern`) or on schedule.

### Triggers — when learning runs

| Trigger | Mechanism | Action |
|---|---|---|
| Session start | `session-start.sh` hook | Show drift summary, recent changelog, pending decisions, last 3 session-log entries |
| Edit done | `post-edit-check.sh` hook (existing) | Lint + type-check; flag if new code violates `conventions.md` |
| Commit | `post-commit-learn.sh` hook (NEW) | Diff scan: new patterns? convention violations? new entities? new dependencies? Append to relevant `dynamic/` file |
| Merge / rebase | `post-merge-learn.sh` hook (NEW) | Same as commit; catches branch work |
| Session end | `update-session-log.sh` hook (existing, enhanced) | Append session summary; surface any drift detected this session |
| Prompt submitted | `recall-inject.sh` hook (NEW — **opt-in**, `touch .claude/.recall`) | BM25-search the existing `ai/` tree with the prompt; inject the top 3 matching POINTERS as context. Reads only — no sink is written. This is the RECALL half: `ai/failures/_index.md` surfaces itself before the failed approach is retried |
| On demand | `/recall <query>` command | The same search, run by hand, with `--kind` / `--owner` / `--since` / `--format` filters. Ranked `path:line` pointers into `ai/dynamic/`, `ai/failures/`, `ai/decisions/`, `ai/patterns/`, `ai/runbooks/`, `ai/conventions.md`, and the `ai/audits/**` archives |
| On demand | `/refresh-knowledge` command | Re-run Phase 2 profile detection; diff against current; update `ai/conventions.md` + `.claude/codebase-profile.md`; surface changes |
| Weekly (optional cron / GitHub Action) | Scheduled `/refresh-knowledge` | Same as on-demand; produce a "weekly drift report" comment on a tracking issue |

### Phase 6 commands (added to `.claude/commands/`)

- `/refresh-knowledge` — re-runs Phase 2 detection, diffs against current `ai/conventions.md` + `.claude/codebase-profile.md`, surfaces changes for user review, applies on confirmation. Use after major refactors, dependency upgrades, architectural changes.
- `/detect-drift` — invokes `convention-drift-detector` agent. Compares current code against documented conventions; produces a categorized list (drift to fix in code · drift to fix in conventions · acceptable variation · ambiguous).
- `/promote-pattern <name>` — invokes `knowledge-curator` to promote an entry from `dynamic/learned-patterns.md` to a formal `ai/patterns/<name>.md` with full structure (context, problem, solution, example, trade-offs, common mistakes).
- `/learn-from-task` — at end of a task, capture: what was decided, what convention was followed/violated, what new pattern emerged, what user correction was applied. Appends to relevant `dynamic/` files.
- `/promote-decision <id>` — graduate an entry from `dynamic/decisions-pending.md` to a formal ADR with sequential number.
- `/audit-knowledge` — runs `knowledge-curator` to find: stale `dynamic/` entries (>30d, no progress), unfollowed conventions, unreferenced patterns, dead ADRs.
- `/recall <query>` — **retrieval, not capture.** Searches the `ai/` tree this phase writes and returns ranked `path:line` pointers. It adds no sink and no store; the corpus is the pyramid above. This is what makes the budgets below affordable: with the archives indexed, "archive" stops meaning "gone".

### Phase 6 agents (added to `.claude/agents/`)

- **`knowledge-curator`** — maintains `ai/` over time. Reads all `dynamic/` files, applies promotion rules, surfaces stale entries, refactors `ai/status.md` Recent Changes when too long, archives old entries.
- **`convention-drift-detector`** — compares actual code against `ai/conventions.md` + `.claude/rules/`. For each finding: (a) suggest code fix, OR (b) suggest convention update, OR (c) flag ambiguity. Output is structured for `/detect-drift` consumption.
- **`pattern-emergence-watcher`** — runs over recent commits + recent edits to find: same code shape repeated 3+ times → propose to `dynamic/learned-patterns.md`. Same fix recipe applied across files → propose. Same anti-pattern occurring → propose adding to `.claude/rules/`.

These agents are MAINTENANCE agents — different from feature-building agents. They keep the knowledge layer healthy so feature-building agents always work from current truth.

### Phase 6 hooks (added to `.claude/hooks/`)

- **`post-commit-learn.sh`** (NEW) — runs after every commit. Diff scan + append to `dynamic/changelog.md`. If diff includes >5 file edits OR introduces a new entity name (caps + sufix patterns) OR adds a new module, queue a `pattern-emergence-watcher` review for next session.
- **`post-merge-learn.sh`** (NEW) — same as post-commit; catches merges from feature branches.
- **`session-start.sh`** (existing — enhanced) — at session open, surface in console: pending drift findings, top 3 recent commits, top 3 entries from `dynamic/decisions-pending.md` aging >7 days. One-screen briefing.
- **`update-session-log.sh`** (existing — enhanced) — on session end, additionally check: did this session introduce drift? Did it use any `learned-pattern`? Did the user correct the AI? Append signals to relevant `dynamic/` files. It also records the harness's `session_id` + `transcript_path` as POINTERS at the verbatim transcript the host already stores under `~/.claude/projects/<encoded>/` — never a copy of it; a hook write is not an Edit, so `secret-scan.sh` never sees what it writes.
- **`recall-inject.sh`** (NEW — UserPromptSubmit, **opt-in** via `touch .claude/.recall`) — the recall half of the loop. Context-only, never blocks, always exits 0; injects at most 3 pointer rows per prompt, deduped per row per session.

### How session N+1 benefits from session N

1. Session N writes to `dynamic/` files via hooks + skills.
2. Session N+1's `session-start.sh` reads `dynamic/` + surfaces what changed.
3. Every agent's pre-flight reads `ai/conventions.md` + `.claude/codebase-profile.md` (which incorporate prior learnings).
4. Every agent reads `ai/dynamic/feedback-learned.md` if relevant (user corrections from prior sessions).
5. The `knowledge-curator` periodically (or on-demand) graduates raw observations into formal patterns, ADRs, conventions — making them visible to all future sessions.

### What this prevents

- **"Same correction every session"** — once user says "don't do X", it's in `feedback-learned.md` + relevant rule; future sessions don't repeat the mistake.
- **"Pattern reinvention"** — `learned-patterns.md` records the shape; agents pick it up via curator promotion.
- **"Drift accumulating silently"** — `drift-log.md` tracks every divergence; nothing rots in the dark.
- **"Knowledge base getting stale"** — refresh + curator + audit cycle keeps it current.
- **"Onboarding lost on team rotation"** — the formal layer (top of pyramid) captures hard-won knowledge in a form that survives.

### What this is NOT

- NOT a second memory store. `/recall` and `recall-inject.sh` add RETRIEVAL over the pyramid above and nothing else — no new sink, no new file format, no second place to write. The canonical sink set stays defined once, in `templates/snippets/learning-sink.md`.
- NOT automatic capture. A hook is a shell script; it cannot understand a session. Only `/learn-from-task` (a model call) turns a session into a sink entry, and it stays human-dispatched. Recall does not fix capture discipline and does not claim to.
- NOT auto-coding new patterns into existing files (curator suggests; user approves).
- NOT automatic rule changes based on a single observation (promotion thresholds = N=3 minimum).
- NOT silent adjustments to ADRs (formal layer is append-only; new evidence = new ADR superseding old).
- NOT a replacement for human review (curator surfaces; humans decide).

---

