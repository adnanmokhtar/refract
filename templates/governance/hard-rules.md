---
artifact: hard-rules
purpose: Always / Never governance overlay. Severity must / must-not violations cause Phase 5 audit to refuse "success." Severity should / should-not violations are warned and logged.
imported-by: commands/setup-project.md (orchestrator), every phase, /setup-project-health.
---

# Hard rules

## Top 10 — read these first

If you have time for nothing else, internalize these. They are the rules that, when violated, produce the highest-impact regressions. Ranked by frequency × severity, drawn from the failure catalog and prior-incident notes.

| Rank | ID  | One-line                                                              |
|------|-----|-----------------------------------------------------------------------|
| 1    | A04 | Respect existing user-authored content; never overwrite without confirm |
| 2    | A11 | COPY-mode tracks: copy packs verbatim (no LLM rewrite)                |
| 3    | A15 | Adapt to detected conventions; cite project specifics, not generic    |
| 4    | A19 | Always ship the four foundational `repo-baseline` rules               |
| 5    | A02 | Real content. No placeholders                                         |
| 6    | N15 | Do NOT ship generic `ai/conventions.md` when a real codebase exists   |
| 7    | A12 | AUTHOR-mode: cite only symbols traceable to extraction file           |
| 8    | A29 | Architectural agents inject `ai/failures/_index.md` in pre-flight     |
| 9    | A16 | Map every new file to a defined home in `ai/modules.md` BEFORE writing |
| 10   | N17 | Never REFRESH without backup unless `--no-backup` AND user confirmed  |

The full table follows. Phase 5 references rules by ID; you can grep for any A/N number to find its prose.

---

## Severity codes

- `must` — violation = command refuses to report success in Phase 5.
- `must-not` — same; surfaced as a destructive risk.
- `should` — warned, logged in `ai/_setup-history.md`; user can override.
- `should-not` — same; user override required.

Phase 5 references rules by ID. Edit prose below the table; never delete a row without rules-version bookkeeping (rules-version file is intentionally not yet split out — bump the inline rules-version below when removing/renumbering).

## Always

| ID  | Rule (one-line)                                                          | Severity  | Applies-to-phases       |
|-----|--------------------------------------------------------------------------|-----------|-------------------------|
| A01 | Plan BEFORE write; show plan; wait for approval unless `--force-*`       | must      | 3, 4                    |
| A02 | Real content. No placeholders in generated files                         | must      | 4                       |
| A03 | Phase 1 bias in knowledge-base generation                                | should    | 4                       |
| A04 | Respect existing user-authored content; never overwrite without confirm  | must      | 4                       |
| A05 | Save reusable outputs back to packs                                      | should    | 6                       |
| A06 | `ai/status.md` always has `Updated:` + `## Recent Changes`               | must      | 4, 6                    |
| A07 | Opinionated — make decisions, record as ADRs                             | should    | 3, 4                    |
| A08 | Token-aware — terse output; delegate heavy scans to Explore subagent     | should    | all                     |
| A09 | Always write `AGENTS.md` + `ai/references/models.md`                     | must      | 4 (4.8)                 |
| A10 | Respect each adapter's idempotency markers across re-runs                | must      | 4 (4.8)                 |
| A11 | COPY-mode tracks: copy packs verbatim (deterministic; no LLM rewrite)    | must      | 4 (4.2.b)               |
| A12 | AUTHOR-mode tracks: only emit content traceable to extracted-idioms file | must      | 2.5, 4 (4.2-AUTHOR)     |
| A13 | Run Phase 2.5 in every ENHANCE/REFRESH when ≥1 base class has ≥3 extenders | must    | 2                       |
| A14 | Pack authoring: signal-density over line count                           | should    | 6                       |
| A15 | Adapt to detected conventions; cite project specifics, not generic prose | must      | 4 (4.6)                 |
| A16 | Map every new file to a defined home in `ai/modules.md` BEFORE writing   | must      | 4                       |
| A17 | Boy Scout Rule on every touched file (bounded scope)                     | should    | 4, 6                    |
| A18 | Inject mandatory pre-flight in every generated agent                     | must      | 4 (4.6)                 |
| A19 | Foundational ruleset: ship the four `repo-baseline` rules — period       | must      | 4 (4.0.7, 5.1)          |
| A20 | Backend track + async runtime → ship parallel-IO discipline artifacts    | must      | 4 (4.0)                 |
| A21 | Run setup-project's own independent sub-steps in parallel where allowed  | should    | 2, 4                    |
| A22 | REFINE deepens; never substitutes for CREATE/ENHANCE/REFRESH             | must      | 1, 4-DEEP               |
| A23 | V1→V2 migration is first-class when detected or `--include=migration`    | should    | 2 (16), 4 (4.6)         |
| A24 | Every generated command follows the 7-phase canonical structure          | must      | 4                       |
| A25 | REFRESH order: backup → extract → re-detect → merge → regen → audit      | must      | 0                       |
| A26 | REFRESH preserves ADRs, validated corrections, project intent            | must      | 0, 4                    |
| A27 | Every pack source has `_version.json` + `CHANGELOG.md`                   | must      | 4 (4.0)                 |
| A28 | Version stamps recorded per-run in `codebase-profile.md`                 | must      | 4 (4.0), 6              |
| A29 | Architectural agents inject `ai/failures/_index.md` in pre-flight        | must      | 4 (4.6)                 |
| A30 | Failures append-only; superseded entries archived, never deleted         | must      | 6                       |
| A31 | Schema validation runs in Phase 5.4 every mode                           | must      | 5 (5.4)                 |
| A32 | Health score appears in `_session-digest.md` (Tier 1 visibility)         | must      | 6                       |
| A33 | Telemetry is local-only; no network; no PII; `.gitignore`d               | must      | 4, 6                    |
| A34 | Factories scaffold per detected business-domain (when --with-factories OR factory framework detected) | should | 4 (4.4b)                |
| A35 | Multi-language preamble in human-facing docs only; code stays English    | must      | 4                       |
| A36 | Wizard preview shows real content, not placeholders                      | must      | 3 (wizard mode)         |

## Never

| ID  | Rule (one-line)                                                          | Severity  | Applies-to-phases       |
|-----|--------------------------------------------------------------------------|-----------|-------------------------|
| N01 | Overwrite `.env*` or lock files                                          | must-not  | 4                       |
| N02 | Delete user-authored docs / agents / rules                               | must-not  | 4                       |
| N03 | Generate tooling for signals not present                                 | must-not  | 4                       |
| N04 | Invent architecture that conflicts with existing code                    | must-not  | 4                       |
| N05 | Downgrade an existing setup (enhance = ADD, never SUBTRACT)              | must-not  | 4                       |
| N06 | Bypass safety hooks (`--no-verify`, `rm -rf`)                            | must-not  | all                     |
| N07 | Force-push, reset-hard, destructive git                                  | must-not  | all                     |
| N08 | Write tool configs the project isn't using                               | must-not  | 4 (4.8)                 |
| N09 | Duplicate rule content across every tool config                          | must-not  | 4 (4.8)                 |
| N10 | Thin-generate content when a pack source exists                          | must-not  | 4 (4.2)                 |
| N11 | Pad pack templates to hit line targets                                   | should-not| 6 (authoring)           |
| N12 | Restate frontmatter `description` in the body                            | should-not| 4, 6                    |
| N13 | Create redundant sections (Invariants + Rules + Anti-patterns…)          | should-not| 4, 6                    |
| N14 | Write "References" that duplicate "Pre-flight reading"                   | should-not| 4, 6                    |
| N15 | Ship generic `ai/conventions.md` when a real codebase exists             | must-not  | 4                       |
| N16 | Skip project-specific block at the top of generated rules                | must-not  | 4 (4.6)                 |
| N17 | REFRESH without backup unless `--no-backup` AND confirmed                | must-not  | 0                       |
| N18 | REFRESH without reading existing setup first                             | must-not  | 0                       |
| N19 | REFRESH that drops ADRs                                                  | must-not  | 0, 5                    |
| N20 | Auto-delete the REFRESH backup directory                                 | must-not  | 0, 5                    |

## When to ask (ONE consolidated question)

Phase 3 surfaces these as a single user prompt; never ask in dribs and drabs:

- Ambiguous shape (single / mono / workspace).
- Ambiguous domain (prompt says "AI" without naming provider).
- Enhancement conflict (existing CLAUDE.md contradicts new prompt).
- Ambiguous tool adapter set.

Otherwise proceed with opinionated defaults; record the choice as an ADR.

---

## Rule prose (full text per ID)

Phase 5 audit references rules by ID. The prose below is the full text used to interpret edge cases. The `Why:` and `How to apply:` lines exist so a future maintainer can judge whether a rule still applies as the codebase evolves.

### A01 — Plan before write
Plan BEFORE write. Show plan; wait for "proceed" unless `--force-*`.
**Why:** lets the user catch wrong-direction work before any file is written.
**How to apply:** Phase 3 emits the plan; Phase 4 only proceeds after user approval (or explicit `--force-*` flag).

### A02 — No placeholders
Real content. No placeholders in generated files.
**Why:** placeholders ship as bugs the moment the user merges.
**How to apply:** Phase 5 greps generated files for `<TODO>`, `<TBD>`, `<FILL ME>`, `<placeholder>`. Any hit = halt.

### A03 — Phase 1 bias
Don't over-design for later phases.
**Why:** speculative scaffolding rots. Build for what's known, defer the rest.

### A04 — Respect existing user content
Never overwrite user-authored content without explicit confirmation.
**Why:** the user's notes are load-bearing. Silent overwrite = lost work.
**How to apply:** managed markers (`templates/idempotency.md`) bracket generated content; everything outside markers is preserved.

### A05 — Save reusable outputs back
**Why:** the system improves only when concrete learnings flow back to packs.
**How to apply:** Phase 6 / `/learn-from-task` promote dynamic observations.

### A06 — `ai/status.md` always has Updated + Recent Changes
**Why:** without these, hooks can't detect drift; sessions can't bootstrap.

### A07 — Opinionated
Make decisions, record as ADRs. Don't hedge.
**Why:** "could be X or Y" defers the decision to the next session, where context is gone.

### A08 — Token-aware
Delegate heavy scans to Explore subagent; terse output.
**Why:** the orchestrator's context is finite; subagents protect it.

### A09 — Always write `AGENTS.md` + `ai/references/models.md`
**Why:** `AGENTS.md` is the standalone-tool entry point; `models.md` documents which models the project uses by role. Both are required by Phase 4.8 ordering.

### A10 — Respect adapter idempotency markers
**Why:** users edit below the marker; re-runs must not stomp those edits.

### A11 — COPY-mode: deterministic copy
**Why:** LLM-rewriting a pack source = silent regression. Output shorter than source = bug.
**How to apply:** Phase 4.2.b runs `cp` via Bash, never asks the model to "regenerate."

### A12 — AUTHOR-mode: trace every claim
**Why:** invented method names + path references look authoritative and are deeply wrong. The extraction file is the floor of truth.
**How to apply:** Phase 4.2-AUTHOR refuses to emit any cited symbol that isn't in `.claude/_extracted-idioms.md`.

### A13 — Phase 2.5 mandatory when extender count ≥3
**Why:** without 2.5, every track falls to COPY mode and produces generic output.

### A14 — Density over line count
**Why:** padding teaches the LLM to skim. Density teaches it to read.

### A15 — Adapt to detected conventions
**Why:** generic prose ("use parameterized queries") doesn't tell Claude *which* helper to import. Project-specific anchors do.

### A16 — Every new file has a defined home
**Why:** files dropped in `utils/` / root / `common/` accumulate as architectural debt no later refactor pays back.

### A17 — Boy Scout Rule
**Why:** small adjacent cleanups don't bloat the diff and stop "I'll do it later" from rotting.

### A18 — Mandatory pre-flight in every agent
**Why:** without injected pre-flight, agents fall back to generic patterns in the next task.

### A19 — Four `repo-baseline` rules — period
The first three answer *what to read* + *what "clean" means*; the fourth (Karpathy-inspired task-discipline layer) answers *how to act on what you read* — explicit assumptions, simplicity-first, surgical scope, verifiable success criteria.
**Why:** skipping any one re-introduces a known LLM failure mode.
**How to apply:** Phase 4.0.7 enforces presence; Phase 5.1 retries-then-halts if any are missing.

### A20 — Parallel I/O discipline on async backends
**Why:** sequential `await` of independent I/O is the most common LLM-authored backend perf failure (turning 100ms × 8 batches into 800ms wall-clock).
**How to apply:** Phase 2 Step 15 detects the runtime's primitive (`Promise.all` / `asyncio.gather` / `errgroup` / `StructuredTaskScope` / `Parallel.ForEachAsync`); Phase 4.0 ships the rule + pattern + skill; Phase 4.6 anchors them. Synchronous-only stacks (sync-only Python, single-threaded scripts) skip.

### A21 — Parallelize independent sub-steps
**Why:** sequential phases waste wall-clock when the steps are independent.
**How to apply:** Phase 2.5 base-class extraction (≤6 concurrent), Phase 4.2 per-track copies, Phase 4.4 per-signal overlays, Phase 4.4b per-domain authoring, Phase 4.8 per-adapter generation all fan out. Phase 0 backup→extract→re-detect, Phase 4.1 baseline, Phase 5 audit ordering stay sequential.

### A22 — REFINE is round-two
**Why:** REFINE is for deepening already-correct artifacts, not for first setup.
**How to apply:** REFINE only rewrites managed `## Project-specific` blocks whose anchor density is below threshold. User sections preserved verbatim.

### A23 — V1→V2 migration first-class
**Why:** the two most common migration failures are silent behavioural drift and scope creep. The `migration` pack prevents both.
**How to apply:** Phase 2 detects `migration_layout_detected` (`phase-2-profile.md § Profile content` field 16 — a profile field, not a step of `extract-codebase-overview`, which has 15 steps and no Step 16); Phase 4.0 ships ledger + parity tooling; Phase 4.6 anchors to the project's V1/V2 roots and cutover mechanism. Greenfield without V1 evidence skips unless `--include=migration`.

### A24 — Canonical 7-phase command structure
See `templates/canonical-command-template.md`. Deviations require explicit documentation.

### A25 — REFRESH order
backup → extract → re-detect → merge → regen → audit-against-extract → cleanup. Skipping or reordering = data loss.

### A26 — REFRESH preserves three categories
ADRs (append-only history); validated corrections (user-given truth); project intent (facts the codebase doesn't encode). Generic packs and conventions get regenerated; these three get preserved verbatim.

### A27 — Pack version + changelog mandatory
**How to apply:** Phase 4.0 pack-load preflight refuses to apply a pack without `_version.json` + `CHANGELOG.md`. Major bumps ship a `migrations/` script.

### A28 — Per-run version stamps
**Why:** drift detection at session-start needs the stamps.

### A29 — Failure catalog in agent pre-flight
**Why:** without it, agents propose ideas that have already failed in this codebase.

### A30 — Failures append-only
`status: superseded_by_<adr>` when conditions change; `validated_failure` becomes archive.

### A31 — Schema validation in Phase 5.4
**How to apply:** every generated JSON config + frontmatter validated against `templates/schemas/`. Missing schema = halt.

### A32 — Health score in `_session-digest.md`
**Why:** silent decay isn't allowed. Tier 1 visibility forces the score in front of every session.

### A33 — Telemetry local-only
NEVER make a network call from telemetry. NEVER include user/PII. `.claude/_telemetry.jsonl` MUST be `.gitignore`d.

### A34 — Per-domain factories
**How to apply:** when `business_domain = ecommerce` is detected, generate `test/factories/<entity>.factory.ts` for every entity in code (matching detected test framework + ORM).

### A35 — Multi-language: docs only
`--lang=ar` adds bilingual preamble to CLAUDE.md / AGENTS.md / `ai/README.md`. Generated code comments + variable names stay English.

### A36 — Wizard preview is real
A wizard that previews `<TODO>` is broken. Mock outputs MUST be the actual what-will-be-written content.

### N01–N20

The Never rules are mostly self-explanatory. Detail for the non-obvious ones:

- **N15** — Ship generic `ai/conventions.md` when a real codebase exists. The file MUST be auto-populated from the codebase profile. Generic content here = Claude will write code that doesn't match project style in subsequent tasks.
- **N16** — Skip the project-specific block at the top of generated rules. Without it, the rule is a generic copy that Claude applies blindly.
- **N18** — REFRESH without reading existing setup first. Even if the user is in a hurry. Phase 0.2 extract is what makes REFRESH non-destructive to accumulated knowledge.
- **N19** — REFRESH that drops ADRs. ADRs are append-only history. If an ADR existed in the backup and is missing in the regen output, the audit MUST halt.
- **N20** — Auto-delete the REFRESH backup. Even after a successful regen, the backup stays. The user decides when (if ever) to remove `.claude/backups/`.
