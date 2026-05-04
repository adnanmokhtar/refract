# Discipline-enforcement section — injected into AGENTS.md

This file is the **canonical hard-rules block** every adapter that writes or reads `AGENTS.md` MUST inject into the project's `AGENTS.md`. Locks any AGENTS.md-reading tool (OpenCode, Cursor fallback, Aider, Copilot, Cline, Windsurf, Codex, Gemini, Kimi via the AGENTS.md consumer set) into the same path / halt / discipline conventions Claude Code follows natively — for **every command**, not just migration.

## Why

Claude Code is tuned + tested against the pack discipline rules. Other tools have weaker discipline-following by default — they invent file paths, skip halts, write outside canonical directories, paraphrase across commands, hand-wave findings. This block forces them to behave for every command in the pack ecosystem.

Observed drift class (2026-05): when a non-Claude-Code tool runs `/migrate` against a downstream project, the parallel scan can complete correctly but land scan output at `.claude/_v1-scan-inventory.md` + `.claude/_v2-scan-inventory.md` and progress backup at `ai/migrate/...` instead of the canonical `ai/migration/scan-report.md`. The validator (`validate-migration-artifacts.sh`) then can't find the artifacts and the gate fails. Same drift class hits **every command** without explicit guardrails — `/add-feature` invents file structures, `/fix-bug` skips path conventions, `/security-audit` writes to wrong directories.

## Inject contract

Adapters that own or update `AGENTS.md` (codex, opencode, cursor, copilot, cline, windsurf, kimi, qwen, gemini) MUST inject the marker-bracketed block below into the project's `AGENTS.md` near the TOP of the file (after Project overview, before Stack/Architecture — it must be one of the first things any tool reads).

The block lives between `<!-- discipline-enforcement:start -->` / `<!-- discipline-enforcement:end -->` markers. `/setup-project --refresh` re-syncs it; user-authored content outside the markers is preserved via SHA-256 hash check.

## The block (paste verbatim into AGENTS.md)

```markdown
<!-- discipline-enforcement:start -->
## Discipline enforcement — read FIRST, applies to EVERY command

This project follows the claude-config pack discipline. Every tool reading this file — Claude Code, OpenCode, Cursor, Aider, Copilot, Cline, Windsurf, Codex, Gemini, Kimi — MUST honor the rules below for **every command**, regardless of how cleverly the tool's default behavior would otherwise route the work.

The pack ecosystem ships ~70 commands (`/add-feature`, `/fix-bug`, `/add-endpoint`, `/add-module`, `/add-page`, `/add-component`, `/add-migration`, `/migrate`, `/align`, `/optimize`, `/polish`, `/do`, `/security-audit`, `/perf-audit`, `/db-audit`, `/a11y-audit`, `/i18n-audit`, `/find-and-fix`, `/port-feature`, `/review-changes`, `/simplify`, `/run-tests`, `/enhance-ui`, `/ui-sweep`, `/design-review`, `/threat-model`, `/secret-scan`, `/add-tracing`, `/add-metrics`, `/add-telemetry`, `/alert-design`, `/add-saga`, `/audit-distributed-tx`, `/dockerize`, `/add-ci`, `/deploy-stage`, `/add-test`, `/flaky-test-hunt`, `/promote-pattern`, `/detect-drift`, `/learn-from-task`, `/pre-commit`, `/check-health`, `/threat-model`, `/scaffold-project`, `/refine-prompt`, `/setup-project*`, plus pack-specific siblings). The rules below cover every one.

### Universal rules — apply to EVERY command

1. **Read the command file first.** Before executing `/<name>`, read `.claude/commands/<name>.md` (or the pack's source) end-to-end. Do not paraphrase across commands. Do not assume one command's flow applies to another.

2. **Cite `<path:line>` for every claim.** "Looks fine," "appears identical," "should work" are forbidden. Every assertion the agent makes about source code MUST include a path + line number that resolves.

3. **No hand-waves.** The tokens `etc.`, `...`, `&...`, `N+ items`, `and so on`, `roughly`, `several`, `mostly`, `appears to`, `deferred to port-phase parity author`, `by audit-by-inspection` are forbidden in audit / finding / contract output. Every item is enumerated explicitly.

4. **Halt on uncertainty.** Do NOT invent file paths, directory names, or workflow steps to make progress. If the canonical surface doesn't fit, surface the conflict to the user and stop.

5. **Verify before record.** Every fix runs the project's verification suite (lint + typecheck + scoped tests + class-specific re-detect) BEFORE updating the ledger / writing the audit / committing. Status only advances on green.

6. **One commit per finding / feature.** Bundling fixes hides regressions and conflates intentional change with mechanical close. The discipline mandates atomic commits keyed to ledger rows.

7. **Update the ledger atomically with the work.** A merged change without a ledger update is incomplete. The ledger row's status / commit-sha / timestamp MUST land in the same PR / commit as the code change.

8. **Don't modify oracle files mid-workflow.** V1 (migration), `_extracted-idioms.md` (align/optimize/polish), `ai/conventions.md` (drift detection) are oracles. Touching them invalidates the verdict.

### Canonical artifact paths — by output kind

**Pack workflow ledgers (one per pack):**
- `ai/migration/ledger.md` — V1→V2 port state
- `ai/align/ledger.md` — convention drift findings
- `ai/optimize/ledger.md` — code quality + perf findings
- `ai/polish/ledger.md` — UI/UX + API + schema polish findings
- `ai/security-audit/ledger.md` — security findings
- `ai/perf-audit/ledger.md` — performance findings
- `ai/i18n-audit/ledger.md` — i18n drift
- `ai/a11y-audit/ledger.md` — a11y violations
- `ai/db-audit/ledger.md` — schema / query drift
- `ai/ui-sweep/ledger.md` — UI-UX whole-project sweep findings

**Per-pack supporting artifacts:**
- Scan reports: `ai/<pack>/scan-report.md` — ONE file per pack with all sides (V1+V2 sections in migration; etc.)
- Plans: `ai/<pack>/plan.md`
- Audits: `ai/<pack>/audits/<id>.md`
- Contracts: `ai/migration/contracts/<feature>.md` (migration only)
- Mapping: `ai/migration/mapping/<feature>.md` (migration only)
- Cutover evidence: `ai/migration/cutover-evidence/<feature>-<stage>.json` (migration — stage metrics when row is in shadow / canary / V2-only)
- Reachability matrix: `ai/migration/reachability/<feature>.md` (migration — 6-axis dead/alive)
- API samples: `ai/migration/api-samples/<feature>/<endpoint>.json` (migration only)
- Perf decisions: `ai/migration/perf-decisions/<feature>.md` + `ai/perf-audit/measurements/<row>.md`
- Visual baselines: `ai/polish/baseline/<iso>/<page>.png` + `ai/ui-sweep/baseline/<iso>/<page>.png`
- Halts: `ai/<pack>/halts/<id>-<iso>.md`
- Backups: `ai/<pack>/_backups/<iso>/`
- History: `ai/<pack>/_history.md`
- **Simple-surface `/migrate` progress (exception):** `ai/migrate/progress.md` — multi-day run tracking for the top-level `/migrate` command. Co-located with `ai/migration/` (ledger, audits, final-report). **Only** this file is allowed under `ai/migrate/`; do not place other workflow artifacts there.

**Per-task work:**
- Plans (from `--plan` flag on any command): `.claude/plans/<command>-<slug>-<iso>.md`
- Decisions: `ai/decisions/<NNNN>-<slug>.md` (ADRs, append-only)
- Patterns: `ai/patterns/<name>.md`
- Runbooks: `ai/runbooks/<name>.md`
- Failures (don't-retry catalog): `ai/_baseline/failures/<NNNN>-<slug>.md`
- Dynamic learning notes: `ai/dynamic/learnings.md` (append, agent-managed)
- Knowledge digests: `ai/_session-digest.md`, `ai/_decision-index.md`, `ai/_convention-cheatsheet.md`

**Setup / Claude config:**
- Commands: `.claude/commands/<name>.md`
- Skills: `.claude/skills/<name>.md`
- Agents: `.claude/agents/<name>.md`
- Rules: `.claude/rules/<name>.md`
- Settings: `.claude/settings.json`
- Extracted profiles: `.claude/_extracted-codebase.md`, `.claude/_extracted-idioms.md`, `.claude/codebase-profile.md`
- Refine extracts: `.claude/_refine-extract.md`, `.claude/_setup-quality.md`

**Knowledge layer:**
- `ai/README.md` — knowledge-base index
- `ai/architecture.md` — layer / data flow / state / routing
- `ai/conventions.md` — naming + NEVER/ALWAYS rules
- `ai/modules.md` — module inventory
- `ai/stack.md` — dependencies + scripts + build
- `ai/status.md` — current state + metrics
- `ai/business-domain.md`, `ai/business-flows.md`, `ai/business-model.md`, `ai/competitive-context.md`, `ai/users-and-personas.md`

**Forbidden:**
- NEVER write workflow artifacts to `.claude/` (`.claude/` is for Claude config — rules, skills, agents, commands, settings)
- NEVER invent new top-level dirs under `ai/` (no `ai/aligns/`, `ai/optimizes/`, `ai/sec/`, etc.). **Exception:** `ai/migrate/progress.md` is the only allowed path under `ai/migrate/` (see above).
- NEVER split scan output into per-side files (use ONE `scan-report.md` with sections)
- NEVER write outside `src/`, `tests/`, `public/`, `docs/`, `ai/`, `.claude/`, `.<adapter>/`, `<configured-build-output>` — every other path is forbidden

If a planned write path doesn't match the canonical list, HALT and surface to the user.

### Universal halt conditions — apply to EVERY command

A tool running ANY pack workflow MUST halt under these conditions. Do not continue, do not silently fix, do not invent a workaround:

1. **Canonical path mismatch** — planned write path is not in the canonical list above.
2. **Missing oracle file** — `_extracted-idioms.md` (for align/optimize/polish/audits) or `_v2-anchors.md` (for migration) absent. Route the user to `/setup-project --refine` first.
3. **Hand-wave findings** — audit / finding / contract contains forbidden tokens listed above.
4. **Per-axis enumeration density failure** — UI-leaf rows above the density threshold MUST emit per-row enumeration tables with `<v1-path:line>` + `<v2-path:line>` citations. PARITY claims pay MORE enumeration cost than DRIFT.
5. **Trusted Summary** — echoing a search-agent's "looks identical" verdict without reading source line-by-line is forbidden. Every PARITY claim has cited evidence.
6. **gaps_in != gaps_closed** — a row whose detected gap count doesn't equal the closed gap count cannot advance from `in-progress` to `done` / `fixed` / `verified`. Halt at RECORD.
7. **Dead V1 ported (migration)** — 6-axis reachability check shows zero callers → mark `status: deprecated` with `deprecation_reason: dead-v1-no-callers`, do NOT port.
8. **V1 modified in port PR (migration)** — port PRs touch V2 only; V1 is the parity oracle.
9. **Behavior change without explicit user opt-in** — fixes are behavior-preserving by default. A change that alters observable behavior requires an ADR + user confirmation.
10. **Security finding below standard tier** — security findings are ALWAYS at least standard tier; critical security ALWAYS heavy. No demotion.
11. **Net-lines positive on structural class (align/optimize)** — structural fixes (dead code, dedup, over-abstraction) MUST be entropy-reducing. Net new lines on a structural row halts the gate.
12. **Functional add without idiom citation** — when an align/optimize fix adds new lines, those lines MUST cite an idiom in `_extracted-idioms.md`. Inventing a new abstraction inline is forbidden — extend the shared one or halt.
13. **Reinvented wrapper** — port code creates a custom component / hook / util when a shared one exists in the project's gold-standard inventory. Halt; route to the existing wrapper.
14. **Silent catch** — `catch { /* ignore */ }` or empty catch in port / fix code. Every catch routes through the project's error handler OR includes a comment explaining recovery + debug log.
15. **Frontend / consumer compensation for backend gap** — if a backend response shape diverges from spec, fix the backend. Don't map fields locally in the consumer.

### Per-command discipline rules — consult before acting

Each pack rule is the contract for its command set. Tools MUST read the relevant rule when working in that pack scope:

- **Migration ports**: `.claude/rules/migration-discipline.md` (universal) + `frontend/rules/migration-frontend.md` OR `backend/rules/migration-backend.md` (per stack)
- **Align sweeps**: `.claude/rules/align-discipline.md`
- **Code quality / `/optimize`**: `.claude/rules/quality-principles.md` + `engineering-principles.md`
- **Backend per-feature**: `.claude/rules/backend-principles.md` + `concurrency-discipline.md`
- **Frontend per-feature**: `.claude/rules/frontend-principles.md` + `i18n.md`
- **Database per-feature**: `.claude/rules/database.md` (or pack equivalent)
- **Security**: `.claude/rules/security-principles.md`
- **Performance**: `.claude/rules/performance-principles.md`
- **Observability**: `.claude/rules/observability-principles.md`
- **Distributed systems**: `.claude/rules/distributed-principles.md`
- **Documentation**: `.claude/rules/doc-principles.md`
- **Testing**: `.claude/rules/testing-principles.md`
- **Business**: `.claude/rules/business-completeness.md`

If the tool's runtime cannot dynamically load these rules, the user should `cat` the relevant rule file into their prompt before asking the tool to act on a pack workflow.

### Read-before-write — universal precondition

Before authoring any code, the tool MUST read existing files that use the same pattern (the project's "Read Before You Write" rule, codified in CLAUDE.md / AGENTS.md):

- New CRUD page → read the project's gold-standard CRUD page (named in `_extracted-idioms.md § Gold standards`).
- New composable / hook → read an existing one in the same module + the canonical base helper.
- New service → read `_extracted-idioms.md § Service primitives` + 1 existing service in the module.
- New endpoint / handler → read 2 V2 endpoints in the same module.
- New form → read 2 existing forms with the same validator stack.
- New migration → read 2 prior migrations to mirror the project's pattern.

Skipping this step IS the Reinvented Wrapper / Transposition Trap anti-pattern. The mapping file `ai/migration/mapping/<feature>.md` (migration) or the equivalent in other packs records what was read.

### When in doubt — HALT

A tool that is uncertain about path / structure / discipline MUST halt and ask the user. Silent invention of file names, directories, or workflow steps that deviate from the canonical surface is forbidden. The cost of one extra confirmation prompt is far less than the cost of cleaning up a tool that wrote 50 files in the wrong place.

This block was generated by `/setup-project`. Do not edit manually — changes will be overwritten on `--refresh`. To extend, add user-authored content OUTSIDE the marker block.
<!-- discipline-enforcement:end -->
```

## Adapter responsibility per tool

| Adapter | Inject into | Notes |
|---|---|---|
| `codex` | `AGENTS.md` (codex owns the file) | Inject after Project overview section, before Stack/Architecture. Single canonical writer. |
| `opencode` | `AGENTS.md` (consumer) | Verify the block exists; if missing, write it (codex adapter takes precedence on conflicts). |
| `cursor` | `AGENTS.md` (fallback consumer) + `.cursor/rules/00-discipline.mdc` (mirrored, `alwaysApply: true`) | Cursor reads both; the rules/.mdc version applies always-on. |
| `kimi` | `AGENTS.md` (consumer) + first paragraph of `.kimi/skills/<every-skill>/SKILL.md` (cross-reference) | Kimi reads AGENTS.md but each skill should also point users at it. |
| `qwen` | `AGENTS.md` (consumer) + mirrored block at top of `QWEN.md` (between same markers) | Qwen reads `QWEN.md` natively; mirror the block there so the discipline applies even when the user runs Qwen without `AGENTS.md` in context. |
| `aider` | `AGENTS.md` (via `read:` directive in `.aider.conf.yml`) + `CONVENTIONS.md` summary | Aider has limited surface; the rules summary in CONVENTIONS.md is the load-bearing copy. |
| `copilot` | `AGENTS.md` + `.github/copilot-instructions.md` (mirror) | Copilot's instruction file is path-scoped; mirror the canonical-paths section there. |
| `cline` | `AGENTS.md` + `.clinerules/00-discipline.md` | Cline reads `.clinerules/` first; mirror the block. |
| `windsurf` | `AGENTS.md` + `.windsurf/rules/00-discipline.md` | Same as Cline. |
| `gemini` | `GEMINI.md` (Gemini's project memory file) | Gemini doesn't read AGENTS.md natively; copy the block verbatim into GEMINI.md. |
| `continue` | `.continue/rules/00-discipline.md` + `AGENTS.md` reference | Continue reads `.continue/rules/`; mirror the block. |

## Idempotency

The block lives between `<!-- discipline-enforcement:start -->` / `<!-- discipline-enforcement:end -->` markers. SHA-256 hash check on bytes outside markers; if user-authored sections changed, the marker block updates without touching them. If user edits inside the markers, log a warning + halt the refresh until user resolves.

## Validation

The validator scripts (`validate-migration-artifacts.sh`, `validate-align-artifacts.sh`, `validate-optimize-artifacts.sh`, `validate-polish-artifacts.sh`, `validate-refactor-artifacts.sh`) mechanically gate **specific artifact shapes** per pack (see each script header + `templates/tool-adapters/_*-pack-coverage.md` + **`templates/tool-adapters/_orchestration-sync.md`** for adapter-facing facts). Coverage differs by pack: migration is the deepest gate; optimize gates Phase 0 + ledger rows + findings hand-waves; align ships 7 of 14 checks; polish is stack-conditional evidence headings. **Discipline halts in AGENTS.md below still apply as universal intent** even when a pack's validator does not yet automate every halt (see `commands/*.md` + pack rules). Tools that ignore this discipline block will drift off canonical paths. This block is the **soft-enforcement layer**; the validators are the **hard-enforcement layer** for what they implement.

**Pack source hygiene (claude-config repo only):** Editing commands under `templates/packs/` must stay DRY — link **`templates/governance/core-discipline.md`** and shared snippets instead of pasting SOLID glossaries; Phase 5 **`audit-command-dry.sh`** enforces this. See **`templates/tool-adapters/_template-author-scripts.md`**.

## See also

- `templates/tool-adapters/_orchestration-sync.md` — adapter sync for simple-surface commands, validators, hooks (`ai/migrate/progress.md`, optimize oracles, align 21 verbs, polish env, refactor paths)
- `templates/tool-adapters/_template-author-scripts.md` — C2f/C2g scripts + canonical snippet pointers (claude-config maintainers)
- `templates/tool-adapters/_registry.md` — capability matrix per tool
- `templates/tool-adapters/_<pack>-pack-coverage.md` — per-pack adapter expectations (`_migration-pack-coverage.md`, `_align-pack-coverage.md`, `_optimize-pack-coverage.md`, `_refactor-pack-coverage.md`, `_ui-ux-pack-coverage.md`, …)
- `templates/packs/migration/rules/migration-discipline.md` § canonical paths
- `templates/packs/align/rules/align-discipline.md` § canonical paths
- `templates/packs/code-quality/rules/quality-principles.md` § anti-patterns
- All per-pack `<pack>-principles.md` files
