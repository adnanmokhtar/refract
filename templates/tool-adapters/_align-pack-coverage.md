# Align pack — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces the align pack's artifacts when `--include=align` is selected by `/setup-project`.

The align pack is **non-negotiable** in the same sense the migration pack is — its discipline rule (`align-discipline.md`) is the contract every tool's setup must preserve. Adapters with low capability (Rules-only) translate the rule fully; adapters with full capability (R+A+S+C+H) get the full pack.

> **Why this file exists**: align is migration discipline turned inward — **declared-convention enforcement**: it finds live sites that break a convention the project already declares (a lint rule at `error`, a human-written line in `ai/conventions.md`, an ADR, the glossary, the token set, a named wrapper), proves each against its oracle line, and closes the align-owned rows with EQ / VC / FN proof. The same Trusted-Summary / Hand-waved-Enumeration / Reinvented-Wrapper failure modes that hit V1→V2 ports also hit single-codebase sweeps, plus two of its own: the Invented Convention (a row citing no oracle) and the Majority Vote (a split enforced as a rule). The discipline rule (`align-discipline.md`) is self-sufficient precisely so rule-only tools (Aider, Codex, Gemini) get the enforcement floor without depending on agent / skill / command dispatch.

## Capability mapping per tool

| Tool | Full discipline via | Rule-only fallback |
|---|---|---|
| Claude Code | All artifacts (rule + skills + commands + hooks) | n/a |
| OpenCode | All artifacts (rule + skills + commands) | n/a |
| Cursor | rule + skills + commands + hooks | n/a |
| Copilot | rule + skills + commands | n/a |
| Continue | rule + commands; skills convention-based | partial — rule must self-suffice |
| Cline | rule + commands (workflows); no skills | rule must self-suffice for skill content |
| Windsurf | rule + commands (workflows); no skills | rule must self-suffice for skill content |
| Aider | rule only | full reliance on self-sufficient rule |
| Codex | rule only | full reliance on self-sufficient rule |
| Gemini | rule only | full reliance on self-sufficient rule |
| Kimi | rule + skills (dual-surface: `.kimi/skills/<name>/SKILL.md` + `.kimi/subagents/<name>.yaml`); no per-project hooks — the hooks engine is user-level `~/.kimi/config.toml` | partial — a regular skill is "contextual guidance", so the rule must self-suffice unless the optional Flow Skill upgrade is taken |
| Qwen | rule + skills + commands + agents + hooks (`.qwen/settings.json` `hooks` block, project-level) | n/a — the fullest non-Claude surface in the matrix |

**Conclusion**: every tool MUST receive a faithful translation of `align-discipline.md` (the self-sufficient rule): the oracle and its tiers (T1 / T2 / T2g / contested), what align owns, closes for an owner (EQ rows) and routes, the AL-01…AL-34 class names and the legacy map, the 21-verb closure vocabulary, the EQ / VC / FN proof classes, 11 per-finding audit halts, the 17-check phase-exit gate in outline, and the anti-pattern pointer. The full class ledger (detector, owner, closer per AL id) lives in the `align-detect` skill and the proof ladder in `find-and-align`; a tool without skills must ship those two `SKILL.md` files as reference text, because the rule points at them instead of restating them.

> **Class count.** There are **34 classes, AL-01…AL-34** (`align-detect` § The class ledger), each with one owner. Align's own detectors (`convention-oracle`, `wrapper-adoption-scan`, `naming-layout-scan`, `convention-ratchet-scan`) own AL-01–04, 11, 13–19, 22, 29–32; `align-sweep-gate.py` owns AL-33/34 on fix runs; the rest are owner classes (ui-ux, code-quality, backend, frontend) dispatched when their pack is installed. The old "11 universal classes / 12 detectors" count is retired: security, performance, data, error handling, dead code, SOLID and complexity are no longer align classes, and old ledgers carrying those names are read through the legacy map (routed, never closed).

**Agents (added 1.9.0 — this section previously read "the align pack ships no agents").** Align ships **four**, and they are *auditors, not detectors*. Detection is the five detector skills plus the owner packs' detectors, dispatched by `align-detect`. What the four own is the **verdict** surface, split by when in a row's life the audit happens:

| Agent | Window | Owns | Dispatched by |
|---|---|---|---|
| `align-evidence-auditor` | pre-fix (scan output) | audit halts #1–#4, #11, the AL-01 quote check + out-of-domain routing | `/align-scan` Phase 6, `/align-recheck` TRIAGE, `/align-replan --include-drifted` |
| `align-idiom-auditor` | per-fix (one diff) | audit halts #6, #9, #10 + the enforce-existing-vs-introduce-new boundary | `find-and-align` DECIDE + VERIFY (so: `/align-phase`, `/align-fast`, `/align-recheck`) |
| `align-gate-auditor` | post-phase (one phase) | the 17-check matrix; PASS / REFUSE | `/align-gate`, `/align-fast` auto-gate, `/align-final` |
| `align-ledger-auditor` | cross-phase (all state) | ledger ↔ git ↔ halts ↔ plan reconciliation + SLA | `/align-status`, `/align-final`, `/align-replan` |

**What this changes for adapters: nothing structural, but do not translate them away.** The four agents are the rule's halts given an owner and a dispatch address — they add no discipline the self-sufficient rule did not already carry, which is why rule-only tools (Aider / Codex / Gemini) still reach the same enforcement floor by following the inlined procedure. A tool WITH agent support that drops them regresses to the pre-1.9.0 shape: each command re-deriving the same audit inline, with no guarantee two commands run it the same way. Tools with agent support MUST surface all four; tools without MUST keep the inlined halts they already carry. Neither may claim the audits ran when they did not.

## Sibling top-level commands — `/optimize` and `/polish` (NOT in this pack)

`/optimize` and `/polish` are top-level orchestration commands (siblings to `/align`, NOT pack members). They dispatch different skill sets:

- **`/optimize`** is backed by `architectural-diagnosis` + `refactoring-sweep` (code-quality pack v1.1+) — Phase 0 architectural diagnosis runs FIRST, then tactical refactoring + SOLID + perf sweep. Foundation-first ordering means architectural fixes cascade and dissolve tactical findings (47 N+1 → 22 after fetching moves to right layer; etc.).
- **`/polish`** is stack-conditional, dispatching `a11y-quick-check`/`design-iterate`/`design-token-audit`/`motion-audit` (ui-ux pack) for `frontend-*`, `api-consistency-audit` (backend pack v1.1+) for `backend-*`, `schema-consistency-audit` (database pack v1.1+) for `data-*`, and `platform-conventions-audit` (mobile pack v1.1+) for `mobile-*`.

Adapters MUST surface all four top-level commands (`/migrate`, `/optimize`, `/align`, `/polish`) in their command surface; they are the recommended user entry-points above the pack-level phased commands.

## Simple-surface entry — `/align` (top-level command)

Above the phased `/align-scan` → `/align-plan` → `/align-fast` ceremony, the top-level `/align [<scope>]` command provides a one-shot entry point. Same discipline runs internally; user sees only the brief end-of-run summary.

- **Source**: `commands/align.md` (top-level, NOT in pack folder — installed alongside pack commands).
- **Progress tracking**: `ai/align/progress.md` (single source of truth across multi-day runs).
- **Flags**: `--status`, `--resume`, `--reset <area>`, `--refresh`, `--re-audit`, `--restart`, `--dry-run`, `--allow-dirty`, `--max-parallel=<N>`, `--focus=<list>`, `--exclude=<scope>`, `--surface-blockers`.

**`--re-audit` semantics** — discards `verified`/`done` verdicts in the discipline ledger; re-dispatches the per-row loop on every row. Rows that re-verify clean stay `verified`; rows with reappearing fingerprints flip to `halted` and re-fix in same run. Combinable with scope (re-audit one area only) and with `--restart` (full reset).

**`--ignore-ledger` semantics** — backs up `ai/align/*` (ledger, findings, scan-report, plan, progress) to timestamped `*.bak.md` files; re-discovers idiom inventory from source; re-runs all detectors against current state; re-creates the scan report + plan + ledger from scratch. KEEPS ADR pre-check (intentional convention exemptions preserved). IMPLIES `--re-audit`. Use when: idioms changed materially OR you suspect previous align was incomplete. Combinable with `<scope>`.

**`--refresh` semantics** — re-scans codebase, merges with existing progress: new areas → `pending`, missing → `archived`, existing rows preserved. NO fix work. Safe to run anytime; auto-creates `progress.md` if missing.

**`--restart` semantics** — backs up current progress to `ai/align/progress-<iso>.bak.md`, resets every area to pending, begins from the first area. Does NOT revert commits already made.

Adapter responsibility:
1. Every tool that exposes commands MUST surface `/align` in its native command surface (`.cursor/commands/`, `.opencode/commands/`, `.qwen/commands/`, `.github/prompts/`, `.clinerules/workflows/`, `.windsurf/workflows/`, `.continue/prompts/`).
2. The "no phases / halts / ADRs in user-facing output" contract MUST be preserved — adapters MUST NOT downgrade the simple command into the verbose phased flow.
3. Progress file location (`ai/align/progress.md`) MUST be honoured so multi-day runs survive across sessions.
4. For rule-only tools (Aider / Codex / Gemini), document as a manual procedure: "describe the area; agent builds the oracle map, runs the align detectors' pre-flights on it, drops rows whose oracle quote does not resolve, fixes the align-owned rows through the proof ladder, routes the rest, brief end-of-run summary."

## Verification flow — `--re-audit`

`/align-fast <N> --re-audit` and `/align-final --re-audit` re-dispatch the detector for every row, including ones at `status: verified`. Mirrors `/migration-fast --re-audit`. Catches false-verified or drifted rows; re-fixes them in the same run.

Adapter responsibility: this flag MUST be exposed in tool-native command surfaces (Cursor `.cursor/commands/align-fast.md`, OpenCode `.opencode/commands/`, Qwen `.qwen/commands/`, Copilot `.github/prompts/`, Cline `.clinerules/workflows/`, Windsurf `.windsurf/workflows/`). For rule-only tools (Aider / Codex / Gemini), document the flag in the rule's "Tool-agnostic procedure" section so users can invoke the equivalent re-detection manually.

## Validator script — `validate-align-artifacts.sh` (v1.5+)

Ships at `scripts/validate-align-artifacts.sh`. Enforces the `[SCRIPT]`-tagged row checks **mechanically** (see the tagged 17-check matrix below): evidence-resolves, no-handwaves, al-class (AL ids + the legacy map), oracle-cited, closure-verb-vocab, no-new-symbols, structural-net-lines-non-positive, scope-boundary (file level, every commit of the row), proof-class, vc-approval, owner-routed, side-state fields, idiom-citation, oracle-unmodified, scope-code-smells — plus, for legacy rows only, security-tier-minimum, security-assertion and perf-baseline — and the run-level scan-report-evidence (every AL class has a status line), progress/ledger-reconciliation, and actionable-next-steps checks. A check it cannot run prints `NOT RUN`, which `--strict` counts as a failure.

The `[SWEEP]`-tagged checks run in `find-and-align`'s `scripts/align-sweep-gate.py` (stdlib Python, `python3 -I`, writes only under `$TMPDIR`): line-level scope, re-detect zero, one way per pattern, test lock, emitted names, value round-trip (with the ui-ux pack's `token-map.py`), non-vacuous, ratchet shrink-only, coverage. The `[AGENT]`-tagged checks (ledger completeness, mechanical + boot at HEAD, the zero computed-style evidence, per-tier artifacts) stay agent-side — rule-only tools MUST NOT assume a script covers them.

Adapter responsibility: install the script as a hook integration per tool (see Validator script — universal callable section), and ship `align-sweep-gate.py` with the `find-and-align` skill (or, for skill-less tools, beside the validator).

## Reviewer-approval mechanism (v1.5+)

Heavy-tier rows pause for reviewer approval. Ledger field: `reviewer_approval: <name>@<iso>`. Status `pending-review` between fix and signoff. Default reviewer from `CODEOWNERS` or `ai/align/_anchors.md`. 7-day timeout; no auto-fail.

A **VC row** (a visible change: a nearest-token snap, a wrapper with different defaults) is a separate gate: `approval: <name>@<iso>` written by a human after reading the visual diff, never by an agent and never in the fix commit; the row waits at `pending-approval` until then.

Adapter responsibility: surface `pending-review` and `pending-approval` rows to the user. Tools with native PR review surfaces MAY auto-populate `reviewer_approval` on merge; nothing may auto-populate `approval:`.

## Mid-sweep tier promotion — `/align-promote-tier` (v1.5+)

`/align-promote-tier <id> <new-tier> [--reason="<text>"]`. Demotion below heavy of an AL-15 gate row (or a VC row on a shared component) is forbidden; procedure in `ai/patterns/align-guardrails.md § Mid-sweep tier promotion`.

Adapter responsibility: surface in command surface.

## Idiom-drift propagation (v1.5+)

`/align-scan` compares the hashes of the oracle files rows cite against the prior scan; lists the rows whose `oracle:` or `idiom_cited` points into a changed file (re-verified, never auto-flipped). `/align-replan --include-drifted` re-phases.

Adapter responsibility: include the drift section in the scan command's output template translation.

## Plan-independent ad-hoc spot-check — `/align-recheck`

`/align-recheck <description-or-path>` is the user's bypass-the-ceremony tool (v1.4.0). **NO plan / phase / ledger required.** Accepts natural-language descriptions OR paths. Semantic resolution via codebase-profile + idioms (same intent-interpretation model as `/add-feature`). Scans source FRESH via `align-detect` scoped to the area (the four align detectors + every installed owner detector, the AL-01 quote check, refute-before-report) — no cache lookup, no ledger-row dependency.

Adapter responsibility:
1. Every tool that exposes commands MUST surface `/align-recheck` in its native command surface (`.cursor/commands/`, `.opencode/commands/`, `.qwen/commands/`, `.github/prompts/`, `.clinerules/workflows/`, `.windsurf/workflows/`, `.continue/prompts/`).
2. The semantic resolution flow (read codebase-profile + idioms → understand intent → confirm-or-run) MUST be preserved. Adapters MUST NOT downgrade to keyword tokenization.
3. The plan-independence MUST be preserved. Adapters MUST NOT add a "ledger required" pre-flight check that wasn't in the source rule.
4. For rule-only tools (Aider / Codex / Gemini), document as a manual procedure: "describe the area you want re-checked; the agent builds the oracle map, runs the align detectors' pre-flights over the area, fixes the align-owned rows through the proof ladder, routes the rest, optionally records into ledger if one exists."

## Required artifacts per project

Every adapter setup that includes `--include=align` MUST also propagate these elements:

1. **A declared convention** — the oracle. The inventory falls back `_extracted-idioms.md` → `codebase-profile.md` → `ai/conventions.md`; a missing file is a reduction with a printed line, never a halt. With no declaration at all, every align class prints `N/A (no declared convention)`. Adapters surface the `/setup-project --refine` prompt in that case; they MUST NOT block the install on an empty `_extracted-idioms.md`.

2. **`PROJECT_KIND` anchor** — populated in `_extracted-codebase.md § Gold standards`. Decides which owner detectors `align-detect` can dispatch (ui-ux / frontend / backend); the align detectors run on every stack.

3. **`ai/align/` directory and the audit report** — `/align-scan` writes `ai/audits/<date>-align.md` and the same report as `ai/align/scan-report.md` (what `/align-plan` and the validator read), plus ledger rows at `detected`. Later commands add `plan.md`, `halts/`, `runs/`, `gate-history.md`, `rollback-history.md`, `park-history.md`, `impact/` (heavy-tier), `final-report-<date>.md`, `_deferred.md`.

4. **Validator script** `scripts/validate-align-artifacts.sh` and **sweep gate** `align-sweep-gate.py` — together they run the script-enforced checks of the 17-check phase-exit matrix. Universal callable from any tool's hook / CI / pre-commit.

5. **Detector scripts and tools** — `oracle-map.py` (convention-oracle), `name-check.py` (naming-layout-scan), `align-sweep-gate.py` (find-and-align): stdlib Python, run with `python3 -I`, never write the scanned tree. Project lint tools (ESLint, stylelint, ls-lint, dependency-cruiser, Ruff) are used when installed; a missing tool is `blocked (<tool>)` with a fallback grep, never a halt. Never `npx -y`.

## Per-tool translation expectations

### Claude Code (`.claude/`)
- Full pack as-is.
- `align-discipline.md` → `.claude/rules/align-discipline.md`
- Skills `align-detect`, `convention-oracle`, `wrapper-adoption-scan`, `naming-layout-scan`, `convention-ratchet-scan`, `find-and-align` (each with its `scripts/`) → `.claude/skills/<name>/`
- All 13 commands → `.claude/commands/`
- `validate-align-artifacts.sh` → `~/.claude/scripts/` (user installs once globally)
- Hooks: `.claude/settings.json` PostToolUse hook on edits to `ai/align/**` runs the validator.

### OpenCode (`AGENTS.md` + `.opencode/`)
- Rule's contents inlined into `AGENTS.md` "Codebase alignment" section + linked from `.opencode/`.
- Skills → `.opencode/skills/<name>/SKILL.md` for all six align skills (`align-detect`, `convention-oracle`, `wrapper-adoption-scan`, `naming-layout-scan`, `convention-ratchet-scan`, `find-and-align`), each with its `scripts/`.
- Commands → `.opencode/commands/align-scan.md`, `.opencode/commands/align-fast.md`, etc.

### Cursor (`.cursor/`)
- Rule → `.cursor/rules/align-discipline.mdc` (with frontmatter `globs: ai/align/**`)
- Skills → `.cursor/skills/<name>/SKILL.md` for all six align skills, each with its `scripts/`
- Commands → `.cursor/commands/align-scan.md`, `.cursor/commands/align-fast.md`, etc.
- Hooks → `.cursor/hooks.json` triggering `validate-align-artifacts.sh` on file edits in `ai/align/`

### Copilot (`.github/`)
- Rule → `.github/instructions/align-discipline.instructions.md`
- Skills → `.github/skills/<name>/SKILL.md` for all six align skills, each with its `scripts/`
- Commands → `.github/prompts/align-scan.prompt.md`, `.github/prompts/align-fast.prompt.md`, etc.
- Or `chatmodes/` for sub-agent-style chat modes for `/align-phase` (which dispatches per-row sub-tasks).

### Continue (`.continue/`)
- Rule → `.continue/rules/align-discipline.md`
- Skills → expressed as prompts in `.continue/prompts/<name>.md` for all six align skills (Continue treats skills as prompt templates); their scripts ship beside the validator
- Commands → `.continue/prompts/align-scan.md`, `.continue/prompts/align-fast.md`, etc.

### Cline (`.clinerules/`)
- Rule → `.clinerules/align-discipline.md`
- Commands → `.clinerules/workflows/align-scan.md`, `.clinerules/workflows/align-fast.md`, etc.
- **Skills NOT supported natively.** The rule carries the contract (oracle, classes, verbs, proof classes, halts); the detectors' pre-flights and `find-and-align`'s proof ladder are procedure the rule points at. Ship the six `SKILL.md` files and their `scripts/` as reference documents (e.g. `.clinerules/align/`) so the rule's pointers resolve.

### Windsurf (`.windsurf/`)
- Rule → `.windsurf/rules/align-discipline.md`
- Commands → `.windsurf/workflows/align-scan.md`, `.windsurf/workflows/align-fast.md`, etc.
- Same skill-inlining as Cline.

### Aider (`CONVENTIONS.md`)
- Rule → appended to `CONVENTIONS.md` under a `## Codebase alignment` section.
- **No commands, no skills.** Aider relies entirely on the rule for alignment discipline.
- Aider users invoke procedures by reading the rule's "Tool-agnostic procedure" section (scan + find-and-align + gate are all inlined) and following them manually.
- The validator script `validate-align-artifacts.sh` is the only callable verifier — Aider users run it from the shell or as a pre-commit hook.

### Codex (`AGENTS.md` + `~/.codex/config.toml`)
- Rule → `AGENTS.md` "Codebase alignment" section.
- Same rule-only fallback as Aider for the procedural surface.

### Gemini CLI (`GEMINI.md`)
- Rule → `GEMINI.md` "Codebase alignment" section.
- **Rule-only tool.** Same as Aider/Codex.

### Qwen Code (`QWEN.md` + `.qwen/`)
- Rule → `.claude/rules/align-discipline.md` content mirrored into `QWEN.md` § `## Codebase alignment`.
- Skills → `.qwen/skills/<name>/SKILL.md` for all six align skills, each with its `scripts/`.
- Commands → `.qwen/commands/align-scan.md`, `.qwen/commands/align-fast.md`, etc. (one file per align command).
- Hooks → `.qwen/settings.json` `hooks.PostToolUse` triggering `validate-align-artifacts.sh` on edits to `ai/align/**`.

## Validator script — universal callable

`scripts/validate-align-artifacts.sh` is callable from any tool's hook system or directly from the shell. Setup per tool:

| Tool | Hook integration |
|---|---|
| Claude Code | `.claude/settings.json` PostToolUse hook on edits to `ai/align/**` |
| Cursor | `.cursor/hooks.json` `onSave` for `ai/align/**` |
| Copilot | GitHub Actions workflow (no native pre-commit) |
| Continue | (no native hook) — manual pre-commit hook or CI workflow |
| Cline / Windsurf | (no native hook) — manual pre-commit or CI |
| Qwen Code | `.qwen/settings.json` `hooks.PostToolUse` matcher on edits to `ai/align/**` |
| Aider / Codex / Gemini | Pre-commit hook in `.git/hooks/pre-commit` (manual install) OR CI workflow |

The script returns non-zero on any failure; tool integrations should treat that as a blocking error.

The 17-check phase-exit matrix (`/align-gate`) — **tagged by enforcement surface**. `[SCRIPT]` = `validate-align-artifacts.sh`. `[SWEEP]` = `align-sweep-gate.py`. `[AGENT]` = needs runtime tooling or judgment, so it is **agent-side only** — a rule-only tool MUST run it by hand. Do NOT translate this matrix as if it were fully mechanical:

1. `[AGENT]` Ledger completeness — no `detected` / `planned` / `in-progress` / `halted` row in the phase; `routed`, `pending-approval`, `pending-ratification`, `parked` listed by name; `pending-review` blocks.
2. `[SCRIPT]` Gap-count parity — `gaps_closed == len(evidence)` for every fixed row.
3. `[SCRIPT]` Net-lines on structural rows ≤ 0 — `check_net_lines_structural`.
4. `[SCRIPT]` + `[AGENT]` No new symbols — `check_no_new_symbols` + `@align-idiom-auditor`.
5. `[SWEEP]` + `[SCRIPT]` Line-level scope (V392, AL-34) — sweep gate `scope`; `check_scope_boundary` over every row commit.
6. `[SWEEP]` Re-detect zero (V391) — `redetect` runs each row's `detector_cmd`.
7. `[SWEEP]` One way per pattern (V393, AL-33) — `consistency`.
8. `[SWEEP]` Tests locked (V408) — `lock-paths`, `lock-count`.
9. `[SWEEP]` Emitted names exist (V398) — `names`.
10. `[SWEEP]` Value round-trip (V397) — `roundtrip` (needs the ui-ux pack's `token-map.py`; `NOT RUN` with EQ token rows present refuses).
11. `[SWEEP]` Non-vacuous (V399) — `vacuous`.
12. `[SWEEP]` Ratchet shrink-only (V395, AL-30) — `ratchet`.
13. `[SCRIPT]` + `[AGENT]` Proof class and approval (V394/V396, V407) — `check_proof_class`, `check_vc_approval`; the zero-diff evidence is read by the agent.
14. `[AGENT]` Mechanical pass + boot at HEAD.
15. `[SWEEP]` + `[AGENT]` Coverage within tolerance.
16. `[SCRIPT]` + `[AGENT]` Per-tier artifacts + idiom citation — `check_added_lines_cite_idioms`; tier fields read by the agent.
17. `[SCRIPT]` Oracle cited and unmodified; owner rows routed — `check_oracle_cited`, `check_oracle_unmodified`, `check_owner_routed`.

Plus run-level `[SCRIPT]` checks: scan-report evidence (every AL class has a status line in `ai/align/scan-report.md`), progress/ledger reconciliation (`ai/align/ledger.md` is the single source of truth — `progress.md` may not mark a module done while non-terminal ledger rows remain in its scope), scope-code-smells, and actionable-next-steps.

> **The old 14-check matrix** graded security and performance fixes made inside align (security assertion, perf baseline, security tier). Those rows are now routed to `/security-fix`, `/perf-fix` and `/db-fix`, which carry their own failing-first proofs; check 17 refuses a phase that closed one here. The validator keeps the three legacy checks for old ledgers only.

## Companion scripts — install the **full** bundle

Mirrors the optimize / polish coverage docs: the validator alone is not the full executable surface. Ship the bundle.

| Script | Role |
|--------|------|
| `validate-align-artifacts.sh` | Primary gate for the scan-report + ledger (the `[SCRIPT]` checks above) |
| `align-parallel.sh` | Headless dispatch; parses **`id:`** rows + `status:` like `migrate-parallel.sh`; drives the per-finding fix waves |
| `parallel-fan-out.sh` | Worker engine; pass **`--ledger=ai/align/ledger.md`** so `flock` targets the align ledger (not the migration default) |

**Parallel runners MUST pass `--ledger=`** — wrappers (`align-parallel.sh`, `optimize-parallel.sh`, `polish-parallel.sh`, `migrate-parallel.sh`, `audit-parallel.sh`) forward their ledger path to `parallel-fan-out.sh`. Adapters MUST install the bundle, not only the validator script.

## Adapter responsibilities

When an adapter ships the align pack:

1. **MUST translate the rule** (`align-discipline.md`) faithfully — the oracle and its tiers, Scope (owns / closes for an owner / routes), the AL class names and legacy map, the 21-verb closure vocabulary, the EQ / VC / FN proof classes, 11 per-finding audit halts, the 17-check gate outline, and the anti-pattern pointer. Do NOT abridge.
2. **MUST translate or ship skills** (`align-detect`, `convention-oracle`, `wrapper-adoption-scan`, `naming-layout-scan`, `convention-ratchet-scan`, `find-and-align`, each with its `scripts/`) in the tool's native format if supported; if not, ship them as reference documents the rule's pointers resolve to.
3. **MUST install or document `validate-align-artifacts.sh` and `align-sweep-gate.py`** as a pre-commit / CI / hook integration.
4. **MUST translate all 13 commands** (`align-scan`, `align-plan`, `align-phase`, `align-gate`, `align-fast`, `align-recheck`, `align-status`, `align-final`, `align-rollback`, `align-park`, `align-unpark`, `align-promote-tier`, `align-replan`) — or for rule-only tools, document them as procedural recipes in the rule.
5. **MUST NOT block on an empty `_extracted-idioms.md`** — the inventory falls back to `codebase-profile.md` → `ai/conventions.md`, and a project with no declaration prints every align class `N/A (no declared convention)`. Adapter setup surfaces `/setup-project --refine` as a recommendation in that case.
6. **MUST NOT silently drop the align pack on tools with limited capability.** A rule-only tool gets the rule (which is sufficient — the self-sufficient rule has the full surface inlined).

## Failure mode protections

The same anti-patterns that hit migration ports also hit alignment sweeps. The validator script pattern-recognises:

- **Trusted Summary** — `check_evidence_resolves` validates every row's `evidence` is a real `<path:line>` containing the claimed fingerprint.
- **Invented Convention** — `check_oracle_cited` fails a row whose `oracle:` quote does not resolve in the cited file or whose rule id is not declared.
- **Hand-waved Finding** — `check_no_handwaves` greps for hand-wave tokens (`etc.`, `...`, `several`, `multiple`, `~N`).
- **Net-Positive Cleanup** — `check_net_lines_structural` measures structural-row diffs.
- **Reinvented Idiom in Functional Verb** — `check_added_lines_cite_idioms` enforces idiom citation for functional adds.
- **Self-Signed Visual** — `check_vc_approval` fails a VC row with no human `approval:`, or one written in the fix commit.
- **Absorbed Owner Row** — `check_owner_routed` fails a security, performance, database or code-quality row closed here instead of routed (legacy rows: `check_security_assertion_present`, `check_perf_baseline_present`, `check_security_tier_minimum`).
- **Oracle Drift** — `check_oracle_unmodified` fails on any modification of an oracle file in the align range.
- **Scope creep** — `check_scope_boundary` (file level) and the sweep gate's `scope` (line level).
- **Two-Way Swap, Snapshot Re-record, Vacuous Clean, Silent Coverage Drop** — `align-sweep-gate.py` `consistency`, `lock-paths` / `lock-count`, `vacuous`, and the coverage half of `lock-count`.

This means: a Cursor user, a Copilot user, an Aider user, and a Claude Code user all get the same enforcement floor when they run the validator. The discipline is universal; the tool surface is per-adapter convenience.

## Composition with other packs

`align-detect` dispatches owner detectors at scan time, each "when the <pack> pack is installed"; without the pack, its classes print `N/A (owner pack <x> not installed)` and nothing is graded in its place:

| Detector | Source pack | AL classes | Closer |
|---|---|---|---|
| `design-token-audit` skill (+ `token-map.py`) | `ui-ux/skills/` | AL-05–10, AL-12 | align for EQ rows; else VC with approval or `/polish` |
| `architectural-diagnosis` §1–§2 | `code-quality/skills/` (always installed) | AL-20, AL-21 | align for a re-route through a named public surface; rework → `/optimize` |
| `duplication-scan` | `code-quality/skills/` | AL-13 diverged | `/quality-fix` |
| `i18n-scan` §1–§2 | `frontend/skills/` | AL-26, AL-27 | align for an EQ key; else `/frontend-fix` |
| `a11y-code-scan` | `frontend/skills/` | AL-28 | align in the AL-15 form; else `/frontend-fix` |
| `edge-error-scan` §6–§7 | `backend/skills/` | AL-23 | `/backend-fix` (declared contract); else `/polish` |
| `api-consistency-audit` | `backend/skills/` | AL-24, AL-25 | `/polish` |

Security, performance, database, error handling, dead code, SOLID and complexity are **not align classes**. Align prints one owner line for each (`owner: security → /security-audit`, `owner: code-quality → /quality-audit`, `owner: performance → /perf-audit`, `owner: database → /db-audit`) and routes any such row to the owner's fix command. Where the performance or database pack is not loaded, align may apply an idiom the oracle already names only with a baseline measured by a failing-first test.

`/setup-project --include=align` does not auto-include the owner packs; code-quality and security are always installed, and ui-ux / frontend / backend follow the project's own selection.

## Selection rules

`/setup-project --include=align` is **opt-in only**. The align pack does NOT auto-load — alignment is a deliberate cadence, not a constant. Auto-loading would conflict with feature work.

Auto-detection signals that surface a recommendation (but don't auto-include):
- An existing `ai/align/ledger.md` (prior alignment effort exists).
- A declared convention (a lint config with rules at `error`, a human-written `ai/conventions.md`, ADRs) AND no recent `/align-scan` run (eligible for first sweep).
- A scheduled cron job pointing to `/align-scan` (recurring sweep).

When a signal is detected, `/setup-project` surfaces: "Detected potential alignment workflow. Add `--include=align`? [y/N]".

## Rule-bundle requirement (2026-06-07)

The discipline rule was split for the 40k-char always-on limit: `rules/<name>-discipline.md` (core, always-loaded) + `references/<name>-discipline-procedures.md` + `references/<name>-discipline-catalogue.md` (on-demand). **Every adapter translation MUST ship all three files together** — the core alone is NOT the complete discipline. Rule-only tools (Aider / Codex / Gemini) read all three as one contract; tools with on-demand file loading reference the two companions by path. Never re-inline the references into the core (that recreates the truncation bug); never drop them from a bundle.
