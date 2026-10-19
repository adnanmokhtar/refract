# Precedents — Learning (the AI knowledge layer: references, facts, derived copies, memory sinks, ADRs, context loading)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 and § 10
(the maintainability / conventions column) for every candidate in a **learning** class KN-01…KN-36:
a claim the AI knowledge layer makes (`CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, `GEMINI.md`,
`.cursor/rules`, Copilot instructions, `ai/**`, `.claude/codebase-profile.md`, `.claude/_extracted-*.md`,
`.claude/rules/**` and the live anchor block of every installed agent, command, skill and pack pattern)
no longer matches the repository it describes. The detectors are `knowledge-ref-scan` (KN-01–05, 15,
with `knowledge-refs.py` and the shared reader `kn_common.py`), `knowledge-fact-scan` (KN-07–09, 11–14,
with `knowledge-facts.py`), `memory-hygiene-scan` (KN-20–27, 36, with `sink-audit.py`),
`decision-record-scan` (KN-28–29, with `adr-index.py`) and `context-load-scan` (KN-19, 31–33, with
`load-budget.py`), all in the learning pack. The failing-first shapes are
[`proof-oracles.md`](../proof-oracles.md) § Learning (V490–V509).

**Owned elsewhere.** Learning reports that the knowledge layer is wrong about this repository. A
neighbour that sees the same `file:line` lists it as corroboration, deduped by `file:line`. Without the
owner's pack, the row prints `N/A (owner pack <x> not installed)`; learning never grades it in the
owner's place. The splits:
- A convention the code majority contradicts (KN-10) is align `convention-oracle` AL-04.
- Human docs — README, `docs/**`, runbooks written for people, diagrams, external links — are documentation `doc-drift-scan`. Learning owns dead references in agent-facing knowledge: `ai/`, `CLAUDE.md`, `AGENTS.md`, `.claude/` (owner decision O-1).
- A secret in a context or memory file (KN-34) is security `secret-scan-method`; hidden Unicode or injection-shaped content (KN-35) is security `sast-scan`. Learning hands over the file list.
- Unmarked claims, sampled oracles, a stale approval stamp and a missing ADR for a dependency (KN-16, 17, 18, 30) are `/setup-project-health` checks 11, 7, 9 and 2 and `audit-setup.sh` C2v; learning reads them, never re-grades them.
- ADR authoring format is documentation `/add-adr`; learning owns ADR lifecycle and the ADR home.

Each entry names when a pattern that *looks* like knowledge drift is not, and the evidence that flips it
back. A match makes the candidate **Hardening**, or Refuted where the entry says so, unless the flip
evidence is shown with a `file:line`, an engine row, a lockfile line or a recorded run. Numbers are
stable; § n is the research catalog's P-n for § 1–26. Detectors cite `precedents/learning.md § <n>`.

Index: the claim, the tiers and the gates · scope § 1–10 · facts and contradictions § 11–17 ·
memory sinks § 18–20, 24–25 · loaders and budgets § 21–23 · text § 26 · real-repo additions § 27–33 ·
rationalizations.

## The claim, restated

§ 1 of the protocol takes this shape here. A candidate that cannot fill every bracket from a file or an
engine row is not a finding.

> **[The knowledge file:line, and whether it loads every session]** states **[the claim: a path, a
> symbol, a command, an engine, an id scheme, a count, an ADR status, a lesson]**, while
> **[the source of truth: `git ls-files`, the lockfile, the cited line at HEAD, the ADR file, the
> manifest, the loader's rule]** says **[the other value]**. No precedent below covers it, and an
> agent that follows the claim **[opens a file that is gone / writes code for the wrong engine /
> runs a command that errors / binds to a superseded decision / never sees the instruction]**,
> proven by **[the tier and the V-number]**.

**The proof tiers:**

| Tier | What it is | Enough for |
|---|---|---|
| **S** two-ended static | both ends cited: the knowledge `file:line` quoted and the truth (`git ls-files` miss with the RENAMED/DELETED commit, the lockfile line, the cited line at HEAD, the ADR status line) | a Finding for KN-01–05, 07–09, 11–15, 20, 23, 28–29, 31–32 |
| **T** engine exit | the owning engine re-run on that site with `--only=<file>:<line>` fires before the edit and is quiet after it | closing a row in `/refresh-knowledge --from-audit` |
| **U** regenerate-twice | a derived file regenerated twice from its source, the second run byte-identical (`cmp`, never mtime) | KN-13 and KN-15 fixes (anchors, indexes, cheatsheets) |

A contradiction between two lessons (KN-22), a near-duplicate (KN-21) or an over-generalised lesson
(KN-25) needs a judge reading **both quotes**; the engine only pairs them. Implied judge confirm rates
for conflicting instructions sit near 57% (dos Santos, SCAM 2026), so a judge-only row stays
Unconfirmed until a second reader agrees.

## Reading the seven gates for learning

| Gate | Learning |
|---|---|
| 1 Reachability | The file loads: every session (`CLAUDE.md`, `CLAUDE.local.md`, its `@import` closure, rules without `paths:`, an anchor block in an installed agent's body), on demand (`ai/**` an agent opens), or for another tool only (`AGENTS.md` with no import, § 16). History and sinks are out of the reference classes (§ 3) |
| 2 Trigger | An agent will act on the claim: it is in a loaded file, an anchor, or a file a command tells the agent to read |
| 3 Version | Facts compare MAJOR versions from the lockfile; a range (`engines >=18`) is satisfied by any major inside it (§ 12). A tool fact carries its fetch date |
| 4 No existing control | No precedent here covers it; the claim is not history-marked (§ 14), not a placeholder (§ 4), not an abbreviation that resolves (§ 6), not the other codebase's path (§ 8) |
| 5 Real impact | The agent opens, runs, binds to or writes against something wrong, or never sees an instruction the team maintains. A cosmetic count off by one in an unloaded file is L |
| 6 Proof | Tier S, T or U above. A citation that resolves is not proof that it still supports the claim (§ 27) |
| 7 Deployment | — |

## Scope: what is a project claim

1. **(P-1) Generated targets.** A path inside `.gitignore` or a known codegen directory is INFO, unless the doc says the file is checked in. `knowledge-refs.py` asks `git check-ignore` once for every unresolved path. *Flips back:* the line says the file is committed, or a command reads it as an input.
2. **(P-2) ADR considered options.** Rejected options are expected to be absent; only the chosen option is checked (`adr-index.py` §4 never reads "Considered options").
3. **(P-3) History is not drift.** Dated records are excluded from KN-01–KN-09: `ai/audits/**`, `ai/incidents/**`, `ai/runs/**`, `ai/migration/**`, `*_history.md`, `CHANGELOG*`, `ai/dynamic/changelog.md`, `ai/dynamic/interaction-log.md`, and an ADR's Context section. On a real NestJS + React monorepo this was 10,771 of 15,173 naive candidates.
4. **(P-4) Placeholders.** `<…>`, `{…}`, `path/to/`, `your-*`, `foo`, `example.com`, `YOUR_API_KEY`, `NNNN`, `Class.method`, every `_template*.md` file, and a bare file name that never existed in this history (`OrderRow.tsx` in a naming rule is a shape example, not a location).
5. **(P-5) External symbols** are dead only if they once resolved in this repository or are qualified with a repo module. A symbol no commit ever removed never existed here; `knowledge-refs.py` drops it (measured 2026-10-19: 72 of 74 unresolved symbols on the real repo were external or prose).
6. **(P-6) Abbreviations and aliases.** A member-relative or basename path that resolves to exactly one tracked file is an abbreviation (4,161 on the real repo). tsconfig `paths`, workspace package names and per-directory tsconfigs resolve first, with JSON-with-comments read by a string-aware scanner (a `/*` inside `"@/*"` is not a comment). An ambiguous suffix is not dead: it is an INFO row asking for the full path.
7. **(P-7) Planned or roadmap content** clearly marked (Proposed, Roadmap, "not yet implemented"), and an output a command *will* write (`ai/align/ledger.md`, "writes", "creates", "e.g.") are INFO. *Flips back:* the line states the file exists or tells the agent to read it now.
8. **(P-8) Another codebase's paths.** Versioned docs folders describe old versions on purpose, and a porting ledger names the V1 or legacy codebase's files: a line that says `v1`, `legacy`, "old app", or a file named `v1-*.md`, does not claim the path exists here (169 such references on the real repo).
9. **(P-9) Per-environment values** that name their environment (dev, staging, prod, test, CI) are not contradictions.
10. **(P-10) Pack-generic illustration is not a project claim.** In an installed agent, command, skill, pack pattern (frontmatter `pack:`) or rule, only the live anchor block (column-0 `project-specific:start`/`end` markers outside fences) makes project claims. Example names in the generic body are dead by design: `services.py`, `orders.repository.ts`, `ADR-0042`.

## Facts, presence and contradictions

11. **(P-11) Case.** Always check against `git ls-files`, never `test -e`: macOS hides a case-only rename.
12. **(P-12) Presence means in code.** A symbol whose only surviving mention is a comment or another doc is not present. `knowledge-refs.py` reports it with `comment-only survivor (P-12)`.
13. **(P-13) An edit is not a review.** `last_reviewed` is separate from mtime or last commit; a write that changes nothing still moves the mtime, so freshness is computed from content and from the commits that touched the cited sources, never from mtime.
14. **(P-14) History-marked facts.** "Postgres 16, not MySQL", "was X, now Y", "superseded by", "retired", "any doc still saying ULID is stale", an arrow `MySQL → Postgres`: correct temporal handling, not contradictions. The stale copies elsewhere are the finding.
15. **(P-15) Nested precedence.** The nearest `AGENTS.md` or rule wins by design; Cursor team > project > user. A nested file that overrides the root is not a contradiction.
16. **(P-16) An `@AGENTS.md` import or a symlink** is not duplication, and it is how `AGENTS.md` loads in Claude Code. A SessionStart hook that prints `AGENTS.md` again IS duplication. Without either, `AGENTS.md` beside a `CLAUDE.md` is loaded by other tools only — Unconfirmed, because the user setting `claude-md-and-agents-md` lives outside the repo.
17. **(P-17) Per-tool files generated from one source** (adapter sync) are one fact, not N: fix the source. The same rule groups a stale bullet copied into N anchors into **one finding with N sites** (KN-12).

## Memory sinks

18. **(P-18) An index line plus its topic file** is a pointer, not a duplicate (MEMORY.md, `_decision-index.md`).
19. **(P-19) Project memories with no code anchor** (a decision, a deadline, a user preference) have provenance "user, <date>". They are never stale by code.
20. **(P-20) One-incident safety lessons.** n=1 is enough for an irreversible or safety action (delete, drop, force-push, production, secrets, money, tenancy); `sink-audit.py` §6 never flags those.

## Loaders and budgets

21. **(P-21) HTML block comments** in `CLAUDE.md` are stripped before injection; a raw `wc -l` overstates the load. `load-budget.py` counts effective lines.
22. **(P-22) Path-scoped rules** (`paths:`) are not part of the always-on budget. `globs:` is NOT a field Claude Code reads: a `globs:`-only rule loads every session (Refract platform facts, verified 2026-10-05 on Claude Code 2.1.236).
23. **(P-23) Global and plugin commands** referenced from project knowledge resolve against `~/.claude/commands`, `~/.claude/skills`, plugin manifests and Claude Code's built-ins, not only `.claude/commands`. A command that exists only in the Refract pack catalog is an *uninstalled* command (KN-03), not an unknown word; a slash token with no command cue is a URL segment (`/api`, `/orders`).

## Sink formats and session files

24. **(P-24) A project-redefined sink format** declared in the sink's own `## Format per entry` block is the contract its consumers must read (KN-27). The template format is not. A consumer that greps a field the declared format dropped is the finding, not the sink.
25. **(P-25) A gitignored session file** (`ai/dynamic/session-log.md`, `.review-queue`) is absent on a fresh clone by design.

## Text

26. **(P-26) Bidi marks inside RTL text** (Arabic or Hebrew strings and prose) are legitimate. Flag only overrides or isolates (U+202A–E, U+2066–9) and zero-widths outside RTL lines; LRM and RLM (U+200E/F) are never flagged. The grading is security's (§ Owned elsewhere).

## Real-repo additions (2026-10-19)

Measured read-only on a real NestJS + React monorepo (pnpm, 13,620 tracked files, 657 knowledge files).

27. **(P-27) A citation that resolves is not a citation that supports.** An anchor bullet citing `.claude/codebase-profile.md:19` resolved, while the cited line had been corrected to Postgres and UUIDv7 and the bullet still said MySQL and ULID. KN-14 compares the claim's typed facts with the cited line ±3 (a 2-line shift is not drift). *But:* a cited line that says *neither* value, while the claim agrees with the lockfile, is an Unconfirmed citation drift, never a stale fact (51 pattern anchors on the real repo).
28. **(P-28) A count needs its set named.** "168 rules", "40 workspaces", "1,575 packages" in a domain doc count business rules, tenants and npm packages. A count is checkable only when the line names the set (`.claude/`, `ADRs`, `apps/`, `src/modules`); approximations (`~`, "about", "over", "last N") and "as of <date>" are never checked.
29. **(P-29) A partial supersede is an amendment.** "Supersedes: the chrome clause of [0016]" leaves ADR-0016 Accepted correctly; the missing back link is Unconfirmed and the fix is `Amended by`, not `Superseded by`.
30. **(P-30) A dated file name is not an ADR citation.** `2026-10-13-order-variant-matching.md` contains `13-order…md`; only `ADR-NNNN` and a zero-padded `NNNN-slug.md` cite an ADR.
31. **(P-31) A drift entry names a divergence; it is not a rule.** Contradiction pairs (KN-22) are built from lessons, patterns, feedback, pending decisions and failures against `CLAUDE.md` and rules — never from drift-log entries, which quote both sides of a divergence by design.
32. **(P-32) An oracle file that was never written** (`.claude/_extracted-idioms.md`, `_refine-extract.md`, `_setup-quality.md`) cited from 297 anchor sites is ONE root cause — the extraction did not run or was cleaned up — reported as KN-19 under `context-load-scan` §4, not as 297 dead references.
33. **(P-33) A command in a shell comment is prose.** `# this just died` inside a fence is not `just died`; `bun run scripts/x.ts` runs a file, not a package script. A command is a claim only where a fence line or a backtick span starts with it.

## Rationalizations to reject (learning)

**Wrongly accepting (finder side):**
- "The path is dead." Did it ever resolve here (§ 5, § 8), and is it an abbreviation (§ 6) or an output (§ 7)?
- "177 findings." One root cause, N sites (§ 17).
- "The citation resolves, so the anchor is fine." Does the cited line still carry the claim (§ 27)?
- "The digest says MySQL." Read the clause: "not MySQL" is a correction (§ 14).
- "AGENTS.md is ignored." Is it imported or symlinked (§ 16), and is the user setting knowable?
- "The two lessons contradict." Quote both, check their scope, and let a second reader decide.
- "The file is 260 lines." How many load after HTML comments are stripped (§ 21)?

**Wrongly dismissing (verifier side):**
- "It's only documentation." It loads every session and an agent acts on it.
- "The bullet is generated." Generated copies are what loads; regenerate them (tier U).
- "The setup audit passed." It checks that identifiers resolve, not that facts are true (§ 27).
- "It's an old entry." An open entry whose evidence moved is stale, whatever its age.
- "The hook says nothing, so nothing is high." Does the hook read the format the sink declares (§ 24)?

---

Sources: the learning research catalog (2026-10-19) § 4, which gives P-1…P-26 and both rationalization
lists, and its notes on DOCER (Tan, Wagner, Treude, EMSE 2024), ReCite (ASE 2026), dos Santos
(SCAM 2026), the Claude Code memory docs (code.claude.com/docs/en/memory, fetched 2026-10-19), GitHub
Copilot code review docs (fetched 2026-10-19), MADR 4.0.0 and Nygard (2011); the batch-7 learning eval
(2026-10-19) § 2–§ 4; Refract platform facts (verified 2026-10-05). § 27–33 are measured on the real
repository named above with the five learning engines (2026-10-19). Paraphrased; no text is reproduced
beyond short quoted identifiers.
