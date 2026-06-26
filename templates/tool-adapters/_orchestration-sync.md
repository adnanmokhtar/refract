---
purpose: Adapter-facing sync for simple-surface commands (`/roadmap`, `/migrate`, `/optimize`, `/polish`, `/align`, `/refactor`, `/audit`, `/unify-surfaces`), validators, hooks, and AGENTS discipline paths. Single pointer from each `templates/tool-adapters/<tool>/adapter.md` Cross-references section.
---

# Orchestration & validator sync (for adapters)

Use when translating pack bundles, CI hooks, or discipline blocks. Authoritative command prose: `commands/{optimize,polish,align,refactor,audit,unify-surfaces}.md` (and `templates/packs/migration/commands/migrate.md` for /migrate). Validator sources: `scripts/validate-*-artifacts.sh`.

**Honesty clause (2026-06-07, all simple-surface summaries)**: every run summary of `/migrate`, `/optimize`, `/align`, `/polish`, `/audit`, `/unify-surfaces` closes with three mandatory lines — `Not validated:` (what did NOT run + why, or `none — <what fully ran>`), `Risks:` (residual risk, or `none identified`), `Revert:` (exact git command for the run's commit range). Adapters that approximate these commands via pack commands or the parallel orchestrator scripts MUST carry the same three lines in their end-of-run report. `Tests: green` without the negative space is the Trusted Summary failure mode applied to the run report. **`/audit` is in scope for every execution summary** (it commits P0–P4 fixes); its read-only `--assess` / `--plan-only` short-circuits produce a report, not an execution summary, and are exempt. **`/roadmap` is in scope only under `--build`** (it commits one phase of features); its default plan output is read-only and exempt — same split as `/audit`. **`/refactor` is deliberately exempt** from this mandate — it is git-scoped, behaviour-preserving, and lighter by design (no scale/perf/security claims to under-validate), so "all simple-surface summaries" above does not include it; `/refactor` carries only the standard one-commit-per-finding revert note.

## Command boundary table (authoritative split)

The five quality-sweep commands overlap in what they *can* see but differ in what they *own*. This table is the canonical owner-of-record for each command's exclusive domain and for every shared finding class. Adapters that translate these commands MUST preserve the split — a translation that lets `/align` extract new tokens, or `/polish` claim measured perf wins, has drifted from the contract.

| Command | Exclusive domain | Net-lines | Phase-0 diagnosis | Behaviour |
|---|---|---|---|---|
| **`/align`** | Enforce **existing** conventions / idioms — mechanical drift only (apply a KNOWN idiom to a site that drifted from it; never invent, never *discover*). **Structural:** reinvented-wrapper collapse, silent-catch fix, dead-code, dups, over-abstraction, i18n/a11y rule drift, design-token *drift* (snap to an existing token). **Functional:** apply an existing security / perf / validation idiom where a site is missing it — `add-gate`, `parameterize`, `escape`, `add-validator`, `move-to-secrets`, `parallelize`, `add-index`, `cache-with-explicit-ttl`, … (distinct from `/optimize`'s *measured discovery* and `/audit`'s *ranking + deep pass*). | **structural ≤ 0**; **functional** small + must cite-idiom | none | preserving (structural) / asserted-change (functional — gate→test, perf→assertion) |
| **`/polish`** | Introduce **new** finish — extract NEW tokens, wire empty/loading/error states, rhythm / hierarchy / motion / CTA / focus / type-scale (frontend); envelope / error-contract / pagination / idempotency uniformity (backend); schema consistency (data). May add code. | may be > 0 | none | additive (new finish) |
| **`/optimize`** | Perf + architecture, **measured**. Phase-0 architectural diagnosis (layer / god-module / cycle / missing abstraction) → foundation fixes → tactical sweep (clean code, dedup, dead code, SOLID, perf). Every perf claim ships a baseline + post-fix number. | varies | **required** (Phase 0) | preserving (arch) / measured-change (perf) |
| **`/refactor`** | Behaviour-preserving **structural** change only — the closed Fowler vocabulary (extract / inline / move / rename / replace-conditional-with-polymorphism, …). Git-changed default scope. **No perf work, no Phase-0 diagnosis, no dead-code sweep.** | ~0 | none | strictly preserving |
| **`/audit`** | Rank **everything** across 8 axes + the 13 scale-lens detectors (superset of the above). Cross-axis ranking by `impact-at-target-scale × blast-radius × fix-cost`, then P0–P4 execution. Triage-only via `--assess`; ranked plan via `--plan-only`. | varies | inherits `/optimize` Phase-0 (P3 tier) | per-tier (P0–P3 measured/asserted, P4 preserving) |

### Shared finding-class ownership

When a finding could plausibly be claimed by two commands, the canonical owner is decided by the **kind of work**, not the surface it touches:

| Shared finding class | Canonical owner(s) | Rule |
|---|---|---|
| **Design-token drift** | `/align` (enforce-existing) **/** `/polish` (extract-new) | Snapping a hard-coded value to a **token that already exists** → `/align`. Identifying a repeated raw value with **no token yet** and promoting it to a NEW token → `/polish`. |
| **Accessibility (a11y)** | `/align` (existing-rule drift) **/** `/polish` (new finish) | A violation of an **already-adopted** a11y rule (missing `aria-*` the convention requires, focus-ring drift) → `/align`. Introducing a11y finish the project does **not yet have** (wiring focus management, new skip-links, motion-reduction) → `/polish`. |
| **Layer / boundary violation** | `/optimize` (diagnose + fix) **⇄** `/align` (enforce the rule) | **Bidirectional handoff.** `/optimize` Phase-0 *discovers* a layer violation and may fix it as a P3 foundation; once the boundary rule is codified, repeat *mechanical* drift against that rule is `/align`'s to enforce. Conversely, `/align` finding a violation that needs **structural** rework (not a mechanical snap) hands **back** to `/optimize`. Today only `/optimize → /align` was documented; the reverse `/align → /optimize` direction is equally canonical. |
| **Clean-code / dedup / dead-code** | `/optimize` (P4 tactical) | `/refactor` applies only the closed Fowler vocabulary on git-changed scope; broad dedup / dead-code sweeps belong to `/optimize`'s tactical phase (or `/audit` P4). |
| **Perf / scale** | `/optimize` (discover + measure) **/** `/audit` (rank at target scale) **/** `/align` (apply existing perf idiom) | DISCOVERING a new perf win + baseline→after measurement → `/optimize`. Ranking perf against a throughput/latency target alongside security + DB + resilience → `/audit`. Applying an **existing** perf idiom (`cache-with-explicit-ttl` / `add-index` / `parallelize` / `batch` / `project-columns`) to a site that **drifted** from it, shipping the required assertion (perf assertion / `EXPLAIN ANALYZE`) → `/align`. `/align` applies known idioms but never claims a **measured / discovered** perf win; `/polish` and `/refactor` claim no perf. |
| **Security** | `/audit` (discover + rank + deep pass) **/** `/align` (apply existing security idiom) | DISCOVERING / RANKING security risk, and the deep external pass → `/audit` (and `/security-audit`). Applying an **existing** security idiom (`add-gate` / `parameterize` / `escape` / `add-validator` / `move-to-secrets`) to a site that **drifted** from the project's adopted pattern, shipping the gating test → `/align`. Never claimed by `/polish` / `/refactor`; `/optimize` touches security only incidentally via architecture (no security verb set). |

## Afterburner sequence (full quality sweep)

When a codebase needs the complete pass — diagnose, fix foundations, snap drift, add finish, capture learnings — run the commands in this order so each stage hands a cleaner tree to the next:

```
/audit --assess          # triage — senior-engineer narrative, no fixes (what's the lay of the land)
/optimize                # foundation — Phase-0 architectural diagnosis + tactical sweep (measured)
/align                   # drift — snap conventions / tokens / a11y to existing rules (net-lines ≤ 0)
/polish                  # finish — extract new tokens, wire states, hierarchy / motion / CTA
/learn-from-task         # capture — promote ADRs / conventions / patterns into the knowledge layer
```

Rationale for the order: `--assess` triages before any edit; `/optimize` fixes foundations first (so `/align` and `/polish` operate on a settled structure); `/align` removes mechanical drift before `/polish` adds new finish (so polish doesn't decorate code that's about to be snapped); `/learn-from-task` runs last to promote what was learned.

**Each sweep's `Next:` block should chain to `/learn-from-task`** — every one of `/audit`, `/optimize`, `/align`, `/polish`, `/migrate`, `/unify-surfaces`, `/roadmap` (under `--build`) ends its run summary by offering `/learn-from-task` as a follow-up so the learnings from the sweep are not lost. (`/audit`'s execution examples already carry this in `commands/audit.md`.)

## Discipline enforcement (`AGENTS.md` inject)

Source: **`templates/tool-adapters/_discipline-enforcement.md`** (verbatim block between `<!-- discipline-enforcement:start/end -->`).

- **`ai/migrate/progress.md`** — **only** allowed file under `ai/migrate/` (simple-surface `/migrate` multi-day progress). All other migration workflow state stays under **`ai/migration/`**.

## Validator facts (machine contracts)

| Script | Oracle / prerequisites | Notable flags / env |
|--------|------------------------|---------------------|
| `validate-migration-artifacts.sh` | migration anchors + audits | (see `_migration-pack-coverage.md`) |
| `validate-optimize-artifacts.sh` | `.claude/_extracted-idioms.md` **or** `.claude/codebase-profile.md` **or** root `codebase-profile.md` | `--strict`: Phase 0 must cite oracle; **`ai/optimize/ledger.md`** required under strict |
| `validate-align-artifacts.sh` | `ai/align/ledger.md` format | `--strict` / `--quiet`; **21** closure verbs (5 structural + 16 functional) — see `align-discipline.md` + script |
| `validate-polish-artifacts.sh` | `PROJECT_KIND`, stack evidence files | Env **`QUIET=1`** for quieter logs; **no** `--strict` CLI (failures already exit non-zero). Env `POLISH_DIR`, `PROJECT_KIND` |
| `validate-refactor-artifacts.sh` | `ai/refactor/ledger.md` | `--strict`, `--quiet`, `--phase-base`, `--ledger`, `--findings-dir` |
| `validate-audit-artifacts.sh` | `ai/audit/plan.md` (`--plan-only`) **or** `ai/audit/assessment.md` (`--assess`) + ranked-tier ledger | Checks P0/P1/P2 citations + measured-or-estimated impact; `--strict` rejects hand-waves (`etc.`, `would be slow`, `several places`) and missing failure-mode citations on P0 rows. For `--assess`: validates 8 required sections (good / improve / unify / extract / simplify / redesign / remove / optimize) + `## Actionable next steps` block. |
| `validate-unify-surfaces-artifacts.sh` *(planned)* | `ai/unify-surfaces/progress.md` + per-category inventory | Will check per-category inventory completeness, canonical-wrapper-decision evidence, idioms-update co-commit (`_extracted-idioms.md § Wrappers`), `Reuse-Before-Create` violations (extracting a duplicate where a shared wrapper exists fails). Frontend-only — halts on `PROJECT_KIND` not in `frontend-* / mobile-web / mobile-rn`. |

## Hook globs (when wiring PostToolUse / pre-commit)

Include edits under: `ai/migration/**`, `ai/optimize/**`, `ai/align/**`, `ai/polish/**`, `ai/refactor/**`, `ai/audit/**`, `ai/unify-surfaces/**` (plus pack-specific paths per coverage docs).

## `/refactor` vs the five inventory commands

**`/refactor`** is scoped (default: git-changed paths); it does **not** implement `--refresh` / `--re-audit` / `--restart` / `--ignore-ledger` multi-area orchestration. Those flags apply to **`/migrate`**, **`/optimize`**, **`/align`**, **`/polish`**, **`/audit`** — see `docs/COMMANDS.md`, `commands/refactor.md`, and `commands/audit.md`.

## See also

- `templates/tool-adapters/_migration-pack-coverage.md`
- `templates/tool-adapters/_optimize-pack-coverage.md`
- `templates/tool-adapters/_align-pack-coverage.md`
- `templates/tool-adapters/_polish-pack-coverage.md`
- `templates/tool-adapters/_refactor-pack-coverage.md`
- `templates/tool-adapters/_audit-pack-coverage.md`
- `templates/tool-adapters/_task-integration-coverage.md` — `/task` (MCP-backed task executor: Trello / Jira / Linear / GitHub) per-tool primitive + the `/do`→native-dispatch substitution
- `templates/tool-adapters/_registry.md` § Top-level orchestration commands
