# CHANGELOG

All notable changes to claude-config and its commands. Per-pack changelogs live under `templates/packs/<name>/CHANGELOG.md` (Hard rule A27).

The format is loosely inspired by Keep a Changelog. Versions follow Semantic Versioning at the command level: major = breaking artifact-shape change; minor = new capability; patch = fix or doc.

## [Unreleased]

### Refresh: kept-command capability gaps must not stay silent (audit C2s)

**Why** — observed 2026-06-20 in `sahlcart/store` (a bespoke, hand-curated `.claude/`): a conservative refresh correctly chose `KEEP-OURS` for hand-written commands (`add-feature`, `fix-bug`, `review-changes`, …) over the longer generic pack versions — but those curated commands were missing standard safety gates (intent / prior-art / new-dependency / action-plan / coverage-gap / secret-scan), and nothing surfaced it. The user discovered the shallowness by accident. Preserving bespoke is right; hiding the capability gap is not.

- **`audit-setup.sh` C2s** (warn-only) — for every `KEEP-OURS` command row in `_refresh-decisions.md`, compares the kept curated command against its pack counterpart(s) for a sampled high-value gate set (prior-art / new-dependency / intent gate / `## What to do next` / sibling-shape / coverage-gap / secret-scan / change-brief / missing-agent). When the pack has a gate the curated lacks, it names the missing gates and recommends `/setup-project --refine` — without overwriting (conservative stays conservative). Commands with no pack counterpart (bespoke crown-jewels) are never flagged. Same "no silent gap" principle as C2l (rejected commands). Documented in `docs/REFERENCE.md`.
- Verified against `sahlcart/store`: C2s flags the counterpart-having shallow commands with their specific missing gates, leaves the bespoke commands (`design`, `onboard`, `tenant-safety`, …) untouched, and stays warn-only (audit still PASSES: fail 0). Warn-only checks aren't covered by the exit-code `test-validators.sh` harness; behavior verified by the per-command differential output.

### Review/feedback commands must end with a clear "What to do next" action plan

**Why** — a user ran `/review-changes` after `/add-feature` and couldn't tell *what to actually do*: the findings were grouped by severity (each with a fix), but there was no single ordered to-do at the bottom, so the reader had to assemble the next steps themselves. Read-only review/feedback commands exist to produce a list of things to fix — they should hand the user that list, ordered.

- **New snippet `templates/snippets/review-action-plan.md`** — canonical closing-section contract for read-only review/feedback commands: end every report with `## What to do next`, the findings re-expressed as ONE ordered numbered to-do (MUST FIX → SHOULD FIX → OPTIONAL), each step carrying `<file:line>` + Fix + Verify, then the closing steps (re-run the command, `/learn-from-task`, ship). Clean run collapses to one line. Sibling to `actionable-next-steps.md` (which routes *deferred* findings of fix-commands into follow-up slash commands); this one orders the *findings themselves* into a by-hand fix-list.
- **Wired into the entire read-only review/feedback family (14 commands)**: `review-changes` (full inline example), `security-audit`, `db-audit`, `perf-audit`, `threat-model`, `design-review`, `a11y-audit`, `i18n-audit`, `migration-review`, `audit-business`, `audit-distributed-tx`, `audit-iam`, `cost-audit`, `audit-knowledge` — each now ends with the `## What to do next` block. Framing is adapted per command (severity for most; **savings** for `cost-audit`; **recommended-actions** for `audit-knowledge`).
- **Synced** to `sahlcart/capsolah-api` for every one of these installed there (`review-changes`, `security-audit`, `db-audit`, `perf-audit`, `threat-model`, `migration-review`, `audit-business`, `audit-iam`, `cost-audit`, `audit-knowledge`).

### ui-ux pack v1.3.0 — new `/redesign` command

**Why** — the pack had `/enhance-ui` + `/polish` (refine, structure preserved) and `/align` (drift enforcement), but no command for the genuinely-different job of **rethinking a page from scratch** — new layout + IA + UX flow — while staying inside the app's existing design system. `/enhance-ui` is the wrong tool for "this screen's whole structure is wrong"; forcing it produced restyles, not redesigns.

- **`commands/redesign.md`** — from-scratch page/flow rework with a **mandatory approval gate** (a concrete proposal is presented; no code is written until the user approves). Composes the pack's design specialists rather than hand-rolling: `design-system-architect` (system extraction in Phase 3 + conformance re-check in Phase 6), `ux-reviewer` (drives the Phase 4 IA/flow/micro-copy proposal), `ui-design-sweep` closure verbs (finish the rebuilt surface), and optional post-approval `design-iterate` (screenshotted visual variants of the approved structure). Phase 6 **renders** the rebuilt surface (Playwright) at each breakpoint × theme × locale to earn its RTL / a11y / responsive checkmarks — and prints `SKIPPED` rather than faking them when no harness is wired. Pre-requisites (clean tree + idioms populated + frontend PROJECT_KIND), Args (`--direction`, `--plan`), and a Failure-modes section. Frontend / mobile only.
- **Method-driven design quality** — the command is anchored to an **11-lens Design-principles rubric** (IA / visual hierarchy / layout & rhythm / cognitive load / states-as-first-class / consistency / a11y-by-design / mobile-first / locale-RTL / purposeful motion / micro-copy) so results come from method, not latent taste. Phase 4 now runs **diagnose → design → self-critique → structured proposal → gate → build**: it names the current page's failures against the rubric (cited) before designing, red-teams its own proposal before the gate, and presents a structured proposal (diagnosis → screen's job → direction → layout/IA → component map → state inventory → responsive → a11y/RTL → parity map → risks). Phase 6 emits a **design-quality scorecard** that must *measurably beat the Phase-4 diagnosis* on every targeted lens — "looks nicer" is not a passing bar.
- **Sync chain** — `_essentials.md` + `_topics.md` (strict cite_evidence; sections include prerequisites / args / failure_modes) + `_version.json` → 1.3.0 + `docs/COMMANDS.md` UI-UX table row + `docs/REFERENCE.md` section & TOC anchor. `validate-pack-consistency.sh` green (redesign resolves in both manifests).

### Refresh: rejected-command surfaces must stay discoverable (M35 rule 4 + audit C2l)

**Why** — observed 2026-06-20 in `sahlcart/tenant-portal`: a lean refresh rejected the whole `ui-ux` pack on capability-overlap ("repo has v1 design-iterate/a11y/visual skills … would collide"), so `/enhance-ui` silently vanished — the deterministic study had classed it ADD, a manual `--reject` overrode that, and a follow-up review reported all-OK. The capability existed under other names; the *command surface* did not, with no breadcrumb.

- **`setup-project.md` M35 rule 4** — rejecting a pack **command** on capability-overlap (vs a same-name collision) is incomplete until BOTH: the rationale names the replacement (`→ use /<equivalent>`) AND a native same-named command routes to the curated equivalent (a real specialist, never a copy of the pack version, which assumes pack-only deps like `/align-recheck`). Agents/skills/rules are exempt — only commands are user-typed.
- **`audit-setup.sh` C2l** — warns (consolidated, one line) when an overlap-rejected command leaves neither a native router nor a `→ use /` breadcrumb. Rationale-filtered to the overlap family ("repo has" / "covered by" / "handled by" / "v1 has curated"); out-of-scope rejections ("not applicable", "out of scope") are exempt. Documented in `docs/REFERENCE.md`.
- **tenant-portal fix** — authored a native `.claude/commands/enhance-ui.md` routing to curated `design-iterate`(v1) + `/visual-check` + `/a11y-audit` + `ui-reviewer`; updated its ledger line. `/enhance-ui` now resolves and works; C2l confirms it passes (45 other overlap-rejected pack commands surface as a backlog to breadcrumb).

### Major-skills review — frontmatter consistency

**Why** — a review of the 8 global cross-cutting skills (the ones backing `/optimize`, `/polish`, `/audit`, `/migrate`) found them production-grade with no structural gaps, but surfaced two small consistency issues.

- **`name:` frontmatter added** to the 5 skills missing it — `architectural-diagnosis`, `api-consistency-audit`, `schema-consistency-audit`, `platform-conventions-audit`, `refactoring-sweep`. The 3 migration skills already had it. Without `name:`, every Cursor/Codex SKILL.md translation had to LLM-author the field; now it's mechanical.
- **Dangling reference fixed** in `architectural-diagnosis` — a cross-ref cited a non-existent "step 4.7" (the procedure only has steps 1–8); now points at the detector pass (step 4).

Pack bumps: code-quality 1.4.2, backend 1.3.2, database 1.1.1, mobile 1.3.2.

### add-feature / fix-bug / optimize command-suite hardening (SDLC audit fixes)

**Why** — a multi-agent review of the developer-loop commands (add-feature, fix-bug, optimize + refactor / audit and their sibling skills/agents) against the canonical 7-phase template surfaced 2 P0 SDLC violations and a set of P1/P2 consistency gaps. The suite was a genuine specialist family, but two paths shipped broken code and several contracts were advertised-but-unwired.

**P0 fixes**

- **repo-baseline `/fix-bug` is now failing-test-first (TDD).** Phase 4 was Reproduce → Diagnose → Fix → (then) test — fix-before-test, violating the canonical Phase-4-=-TDD mandate and diverging from the backend pack sibling. Reordered to Reproduce → Diagnose → **write FAILING test** → minimal fix → verify; Hard rule "Regression test before merge" → "Failing test BEFORE fix. Always."
- **mobile `/add-feature` trivial tier now requires tests.** Deliverable was `Code only.`, allowing untested feature code to ship and contradicting its own Phase 6 gate. Now `Code + tests` with a "tests ship every tier" invariant.

**P1 fixes**

- **Universal `--plan` flag wired** across optimize / refactor / add-feature (×3) / fix-bug (×2) via new `templates/snippets/plan-flag.md`; `/audit --plan` accepted as alias of `--plan-only`. The docs already advertised universal `--plan`; the commands now honour it.
- **`scripts/validate-audit-artifacts.sh` shipped** (was referenced 3× by `/audit` as a mandatory gate that did not exist). Checks `check_no_handwaves_audit_plan`, `check_p0_failure_mode_cited`, `--strict` `<file:line>` citations, actionable-next-steps, ledger gap-parity. "planned" flipped → present in audit.md + all 12 adapter docs + `_orchestration-sync.md`.
- **refactor vocabulary reconciled.** `refactorer` agent's 3 out-of-vocabulary verbs (value-object, conditional→polymorphism, reduce-fan-out) removed and routed to `/optimize`; `refactoring-sweep` skill now names `/refactor` as its core apply-engine consumer.
- **perf/db specialist agents wired into `/optimize`** (`performance-optimizer`, `query-optimizer`, `database-optimizer`) instead of inline reimplementation; `/optimize` named as the applier of the propose-only DB agents.
- **baseline ↔ backend `/fix-bug` locked as subset ↔ superset** via relationship banners + shared invariants snippet `templates/snippets/fix-bug-core.md`; baseline `ai/failures/` reads softened to optional.

**P2 fixes**

- backend `/add-feature` got its mandatory `## Phases applied` block.
- backend `_examples/{add-feature,fix-bug}.md` regenerated faithfully from their command sources (stale snapshots contradicted the source) + `generated-from` headers.
- halt-verdict vocabulary unified across the three add-feature variants via `templates/snippets/sibling-shape-halt.md` (aligned / drifted / no-siblings); `/review-changes` independent-pass handoff added to optimize / refactor / audit Next blocks.

Pack bumps: backend 1.3.1, frontend 1.1.1, mobile 1.3.1, code-quality 1.4.1.

### repo-baseline hardening — verification gate, secret scan, format-on-save, statusline, path-scoped rules

**Why** — a best-practice gap analysis (official Claude Code docs + dotclaude/showcase reference repos + senior-engineer write-ups) against the baseline surfaced six gaps versus what makes a setup "right the first time". Two levers drive first-time-correctness: a machine-checkable verification signal wired into the loop, and context discipline (load only what the task needs). The baseline had the breadth but was light on the per-turn verification signal and was not path-scoping track rules.

**What ships** —
1. **Verification gate** (`repo-baseline/.claude/hooks/verify-gate.sh`, Stop hook) — closes the "looks done" gap: when the session left uncommitted source changes AND a test command is detected AND it FAILS, blocks the stop (exit 2) so red tests get fixed instead of declared done. No-op when nothing changed / no runner / tests green. Opt-out `.claude/.no-verify-gate`. (Claude Code overrides a Stop block after 8 consecutive blocks, so it can't trap a session.)
2. **Secret scan** (`hooks/secret-scan.sh`, PreToolUse Edit|Write|MultiEdit) — blocks writes introducing 11 high-confidence credential shapes (sk-ant / OpenAI sk- / AWS AKIA·ASIA / Google AIza / GitHub gh*_ + fine-grained PAT / Slack xox / Twilio / private-key blocks / JWT). Conservative by shape to keep false positives near zero; skips `*.example`/test files; opt-out `.claude/.no-secret-scan`.
3. **Format-on-save** (`hooks/format-on-save.sh`, PostToolUse) — auto-formats the touched file via biome/prettier/ruff/black/gofmt/rustfmt/rubocop; never blocks (lint gating stays in `post-edit-check.sh`); opt-out `.claude/.no-format`.
4. **Statusline** (`repo-baseline/.claude/statusline.sh` + `statusLine` in settings) — surfaces the #1 constraint live: dir • branch • model • **context %** • cost. jq-optional.
5. **Path-scoped track rules** (`scripts/scope-rules.sh` + Phase 4.2 wiring) — idempotent frontmatter injector adds `paths:` globs to TRACK/DOMAIN rules in MULTI-track projects so a track's rules load only when Claude touches that track's source (no cross-track pollution). Single-track projects skip it; core baseline rules are never scoped.
6. **Listing-budget trim** — `audit` / `polish` / `unify-surfaces` / `optimize` frontmatter `description:` trimmed (total 8149 → 5373 chars, under the default skill-listing budget; `audit` was 2038 > the 1536 per-skill cap and got truncated). Trigger keywords + differentiators preserved; specialist depth stays in the body + docs.

Added `"$schema"` to `repo-baseline/.claude/settings.json`; new hooks wired alongside existing ones (additive — nothing removed).

**Files touched**: `templates/repo-baseline/.claude/{settings.json, statusline.sh (new), hooks/{verify-gate.sh, secret-scan.sh, format-on-save.sh} (new)}`, `scripts/scope-rules.sh` (new), `templates/phases/phase-4.2-apply.md`, `commands/{audit,polish,unify-surfaces,optimize}.md` (description only).

### migration pack v1.6.0 + align pack v1.7.0 — discipline rules split for the 40k always-on limit

**Why** — Claude Code truncates always-loaded files at 40k chars. `migration-discipline.md` was 79.5k and `align-discipline.md` 94.4k — **roughly half of each rule was silently never loaded** in every session, and project copies + a global symlink multiplied the waste (tenant-portal-v2 carried 176k of truncated rule text; a global `~/.claude/rules/` symlink loaded migration rules into every project including non-migration V1 repos).

**What ships** — each rule split into an always-on core (<40k) + two on-demand companions under `references/` (content relocated **verbatim**, zero rewording): `<name>-discipline-procedures.md` (tier specs, contract template, full halt elaborations, tool-agnostic procedures, operational protocols, enforcement matrix) + `<name>-discipline-catalogue.md` (worked examples, anti-pattern catalogue, per-tool dispatch tables). Core keeps the philosophy, tier rules, anti-bloat gates, all halts (12-13 compacted with pointers), Must/Must-not, and the structure-vs-behaviour axis table. The "procedures are inlined here" contract is replaced by the **rule-bundle contract**: core + 2 references = ONE discipline; every adapter bundle ships all three (`_migration-pack-coverage.md` / `_align-pack-coverage.md` § Rule-bundle requirement). Manifests declare the pair (`rule_references:` in `_essentials.md`, `reference-pair` topic in `_topics.md`).

**Deployed**: slim cores + references pushed to master-portal-v2 / tenant-portal-v2 / claude-v2; global `~/.claude/rules/migration-discipline.md` symlink removed (double-load + loaded migration rules in V1/non-migration repos); claude-v2's 85.6k CLAUDE.md relocated to 29.5k (4 sections → `.claude/references/`, verbatim).

**Files touched**: `templates/packs/migration/{rules/migration-discipline.md, references/* (new), _essentials.md, _topics.md, _version.json}`, `templates/packs/align/{rules/align-discipline.md, references/* (new), _essentials.md, _topics.md, _version.json}`, `templates/tool-adapters/{_migration-pack-coverage.md, _align-pack-coverage.md}`.

### learning pack v1.2.0 — oracle provenance + approval stamp; honesty clause on simple-surface summaries

**Why** — gap surfaced by reviewing an external repo (HosamZewain/ai-assisted-development-framework): we enforce `<path:line>` citation discipline on migration artifacts while the oracle they all trust (`_extracted-idioms.md` / `_extracted-codebase.md`) was unverified, uncited at claim level, and auto-trusted the moment `/setup-project` wrote it — the Trusted Summary anti-pattern applied to our own pipeline. Separately, simple-surface run summaries reported only the positive space (`Tests: N/N passing`) with no declaration of what was NOT validated.

**What ships** —
1. **Provenance discipline** (`templates/phases/phase-2-profile.md § Provenance discipline`): every claim in `_extracted-codebase.md` / `_extracted-idioms.md` / `_extracted-business.md` / `_refine-extract.md` is `[found: <path:line>]` (resolving citation = marker), `[inferred: <basis>]`, or `[unconfirmed]`; `_extracted-business.md`'s pre-existing `[CONFIDENT]/[INFERRED]/[UNKNOWN]` maps 1:1. Uncited + unmarked claims join the mechanical-halt family in `extract-codebase-overview § Mechanical halt`. Downstream contract: Phase 4 generators anchor only to `[found:]`; migration/align oracle readers treat `[inferred:]` as needs-source-check, never close findings against `[unconfirmed]`. Step 15 provenance sweep + stdout counts.
2. **Oracle approval stamp** (`§ Oracle approval`): `approved_by:` / `approved_hash:` frontmatter on `_extracted-idioms.md` + header lines on `_extracted-codebase.md` — empty at generation, human-stamped after review, hash-mismatch flags "changed since approval". New **check 9 in `/setup-project-health` (v1.1.0)** — warn-only, prints the paste-ready stamp command.
3. **Honesty clause** on the 5 simple-surface command summaries (`/migrate`, `/optimize`, `/align`, `/polish`, `/unify-surfaces`): mandatory `Not validated:` / `Risks:` / `Revert:` lines close every run summary; `Tests: green` without naming the negative space is forbidden (hard rule added per command).

**Files touched**: `templates/phases/phase-2-profile.md`, `templates/packs/learning/{skills/extract-codebase-overview.md, skills/extract-business-context.md, _essentials.md, _topics.md, _version.json}`, `commands/{setup-project-health.md, migrate.md, optimize.md, align.md, polish.md, unify-surfaces.md}`, `docs/{COMMANDS.md, REFERENCE.md}`.

### code-quality pack v1.4.0 — `change-brief` skill (the comprehension gate)

**Why** — "if you can't explain the code, it isn't yours" was advisory in `engineering-principles.md § AI-assisted development` with zero enforcement: AI code accepted because it ran, defect surfaces in production weeks later, nobody can navigate the code that caused it.

**What ships** — **new `templates/packs/code-quality/skills/change-brief.md`**: every non-trivial change carries a 5-field brief (What / Why this shape / Edge cases / Blast radius / Verified by) in the commit/PR body. Mode A generates (reading the actual diff, citing the convention/idiom/ADR the shape follows — a shape that follows no convention surfaces the missing-idiom-or-ADR decision before merge); mode B validates mechanically (field presence, hand-wave grep — `should work` / `looks good` / `standard approach` fail, citation check — ≥ 1 resolving `<path:line>`/ADR per explanatory field, echo check — diff paraphrases fail, verification check — future tense / modals fail). Writing the brief takes 2 minutes when the change is understood and is impossible when it isn't — that asymmetry is the gate. Dispatched by `/pre-commit` (new Comprehension-gate step in Phase 6; missing/failing brief is a blocker) and `/review-changes` (universal dispatch alongside `code-reviewer`). Trigger tiers scale with risk (> 20-line diff, new dependency / public symbol / abstraction, I/O-auth-payments touch, error-path / default / permission-gate change); typo fixes, mechanical renames, formatting, lockfile-only changes exempt — no manufactured ceremony.

**Files touched**: `templates/packs/code-quality/{skills/change-brief.md (new), rules/engineering-principles.md, commands/pre-commit.md, commands/review-changes.md, _essentials.md, _topics.md, _version.json}`.

### mobile pack v1.2.0 — `render-discipline` rule (rebuild / re-render waste) + `/optimize` + `/audit` wiring

**Why** — rebuild-waste guidance (the Flutter "fetch + setState at screen root" defect: works first run, rebuilds the whole screen per keystroke) lived as prose in `references/flutter.md` with no detector in `/optimize` or `/audit` — review skims past it because every test passes.

**What ships** — **new `templates/packs/mobile/rules/render-discipline.md`**: 8 shape-based detectors (oversized-state-scope, side-effect-in-build, missing-stable-subtree, unstable-list-item-props, unvirtualized-list, animation-rebuilds-subtree, store-overinvalidation, logic-in-view) with per-framework fingerprint tables for Flutter / React Native / Jetpack Compose / SwiftUI. Closure verbs: `scope-state-down`, `move-to-lifecycle`, `extract-const-subtree`, `memoize`, `virtualize-list`, `scope-animation`, `select-store-slice`; logic-in-view routes to `/align` (architecture finding wearing a perf costume). Every fix requires a measured before/after rebuild-count or frame-time delta; blanket defensive memoization is itself flagged (over-abstraction). Wired into `/optimize` (Performance class + render-waste verb list) and `/audit` (runtime-perf axis, stack-routed via `PROJECT_KIND`). Enforcement: flutter_lints const rules + DevTools rebuild stats, eslint-plugin-react-perf + Profiler, Compose compiler metrics in CI, `Self._printChanges()` + Instruments.

**Files touched**: `templates/packs/mobile/{rules/render-discipline.md (new), _essentials.md, _topics.md, _version.json}`, `commands/{optimize.md, audit.md}`, `docs/REFERENCE.md`.

### align pack v1.6.0 — `unhandled-io` detector (happy-path-only I/O) + `/audit` unhandled-I/O pass

**Why** — the canonical AI-generated-code defect (works first run, crashes/hangs on the first failure) had no universal detector: frontend fetch-in-component was caught as missing-UI-states, swallowed errors as silent-catch — but an I/O call with NO error path at all (no catch, no error-return check, no timeout, no failure surfacing) in services / jobs / queue handlers / CLI paths had no mechanical surface.

**What ships** — **new `unhandled-io` functional class** in the align pack. 11 universal named classes (6 structural + 5 functional); 12 detectors incl. stack-specific. Detector 11 in `detect-drift`: enumerate I/O sites from `_extracted-idioms.md` primitives → trace failure path → caller-chain cross-check before flagging (caller-handled rejections are NOT findings). Closure: `replace-with-shared` (project's wrapped I/O primitive); no per-site hand-rolled try/catch — missing primitive halts to `/setup-project --refine`. Tier: standard floor for hot-path / user-facing sites; write-path I/O (DB mutation / queue publish / payment) ALWAYS ≥ standard. `validate-align-artifacts.sh § check_scan_report_evidence` regex extended; `is_structural_class` unchanged (functional routing: idiom-citation budget applies, net≤0 does not). `/audit` gains the **unhandled-I/O pass** (runs with the scale-lens wave; findings rank P1 correctness; regression test in same commit). Counts synced across discipline rule, scan/recheck commands, skills, ledger pattern, `_essentials`, `_topics`, docs, `_align-pack-coverage.md`.

**Files touched**: `templates/packs/align/{rules/align-discipline.md, skills/detect-drift.md, skills/find-and-align.md, commands/align-scan.md, commands/align-recheck.md, ai-patterns/align-ledger.md, _essentials.md, _topics.md, _version.json}`, `scripts/validate-align-artifacts.sh`, `commands/{align.md, audit.md}`, `docs/{COMMANDS.md, REFERENCE.md}`, `templates/tool-adapters/_align-pack-coverage.md`.

### `/audit --assess` — senior-engineer narrative assessment mode (new flag)

**Why** — `/audit` is fix-it oriented (scan → rank → execute) with `--plan-only` as the executor-handoff alternative. Neither produced what users keep asking for when they paste a long "evaluate the entire frontend / backend codebase deeply across architecture / SOLID / DRY / scalability / maintainability / styling / design-system / etc., report what's good / what to improve / what to unify / what to extract / what to simplify / what to redesign / what to remove / what to optimize" prompt. That request is a **narrative senior-engineer assessment for a reader** (tech lead / stakeholder / new joiner), not a ranked closure-verb checklist for an executor. The decomposition existed across `/audit + /polish + /unify-surfaces + /align + /optimize`, but the simple-surface answer was missing. Users were either running all 5 commands and merging by hand, or pasting the long prompt and getting hand-waved prose without `<file:line>` citations.

**What ships** — **`--assess` mode added to `commands/audit.md`** (mutually exclusive with `--plan-only`). Same Phase 1 eight-axis scan as today (architecture, SOLID + clean code, security, DB perf, runtime perf, scale + resilience, infra, observability). Different rendering:

- Phase 3a short-circuit: skip ranking + execution; author `ai/audit/assessment.md` with **exactly 8 top-level sections in order**: (1) What's already good, (2) What needs improvement, (3) What should be unified, (4) What should be extracted or shared, (5) What should be simplified, (6) What should be redesigned, (7) What should be removed, (8) What should be optimized.
- **Stack-conditional rendering** — frontend-* inlines component / composable / state-management / routing / styling / design-system / a11y / typing narrative; backend-* (NestJS / Django / Rails / Spring / FastAPI / etc.) inlines module / DTO / validation / guards-interceptors-filters / repository / transaction / API-design / testing narrative; mobile / data / serverless inherit the 8 sections with stack-appropriate emphasis. Agent reads project vocabulary from `_extracted-idioms.md`.
- **Anti-hand-wave discipline preserved** — every claim cites `<file:line>`; same grep that `--strict` enforces on the ranked fix-plan rejects `etc.` / `several places` / `multiple endpoints` / `appears to`. Empty-praise prose ("the code is well organised") is forbidden — each strength names a specific artefact.
- **Closes with paste-ready `## Actionable next steps`** per `templates/snippets/actionable-next-steps.md`: routes each section to its execution command (`/optimize` for arch + redesign + simplify, `/unify-surfaces` for unify, `/polish` for backend API consistency + frontend tokens, `/align` for convention drift, `/security-audit` for deep security pass, `/audit` no-flag to execute, `/audit --plan-only` for ranked fix-plan).
- **Read-only** — no commits, no `progress.md` advance, no `plan.md` written. Distinct artifact: `assessment.md` next to `plan.md` (`--plan-only`) and `final-report.md` (default execute).

**Distinct from siblings**:
- `--plan-only` writes `plan.md` — ranked P0–P4 fix-plan with closure verbs + citations — executor handoff.
- `--assess` writes `assessment.md` — 8-section narrative prose — reader handoff.
- Default execute writes `final-report.md` after fixing.
- Same Phase 1 scan underneath; only rendering differs.

**Files touched**:
- `commands/audit.md` — new `--assess` flag in args + description + examples + Phase 3a short-circuit spec + two stack-flavoured output examples (Vue storefront + NestJS backend).
- `docs/COMMANDS.md` — glance-row updated; new `### --assess` subsection in the `/audit` doc.
- `docs/REFERENCE.md` — `/audit` row in the simple-commands table includes the three-modes description.
- `templates/tool-adapters/{12 adapters}/adapter.md` — Audit-pack bullet adds `assessment.md` artifact + three-modes description (single-line patch consistent across all 12).
- `templates/tool-adapters/_orchestration-sync.md` — `validate-audit-artifacts.sh` planned-row updated to validate the 8 sections + `## Actionable next steps` when `--assess` is used.
- Adapter coverage docs unchanged — `ai/audit/**` glob already covered.
- Global `~/.claude/commands/audit.md` (symlink) auto-propagates.
- Downstream: `tenant-portal-v2` + `claude-v2` `.claude/commands/audit.md` resynced.

### `/unify-surfaces` — surface-type unification orchestrator (new top-level, frontend-only)

**Why** — `/polish` polishes per-axis (tokens / rhythm / motion / type-scale / states / contrast / etc.) across surfaces; `/align` closes per-class structural drift. Neither does what users keep asking for: *"unify all tables and forms across the entire codebase. If a page has a title, one unified header. If a page has tabs, one tab design. List filters move into one unified filter panel. Buttons / colors / spacing / styles / interactions consistent. Forms aligned with consistent spacing + layouts + input structures. Validation handling unified — frontend validators, error states, required-field handling, API-validation errors displayed consistently."* That request is **typed by surface category**, not by axis. The closest workflow today is `/ui-sweep --first-run` → `/align` (`duplicated-surface-styles`) → `/polish` → `/ui-crawl-fix --verify` — 4 commands the user has to know to chain. And **form-validation pipeline unification** (frontend validator + error rendering + API-error mapping as one extracted system) was emergent across 3 generic detectors with no first-class command.

**What ships** — **`commands/unify-surfaces.md`** (new ~280-LOC orchestrator). Sibling to `/polish` / `/migrate` / `/optimize` / `/align` / `/refactor` / `/audit`. Single command:

- **7 default surface categories**: tables, forms, headers, tabs, filters, buttons, validation. `--surfaces=<list>` narrows.
- **Per category, in parallel where independent** (foundation order: buttons → headers / tabs / forms / tables / filters → validation):
  - **INVENTORY** — find every consumer of this surface type (per-category detection signals stack-conditional, listed in command spec).
  - **DECIDE CANONICAL** — `_extracted-idioms.md § Wrappers` if named there; else cluster by shape and pick most-used; else halt + ask.
  - **EXTRACT / EXTEND** — extend the existing shared wrapper (Reuse-Before-Create), or extract a new one. Add to `_extracted-idioms.md § Wrappers` in the same commit.
  - **MIGRATE CONSUMERS** — rewrite every non-canonical consumer in **one cascade-rewrite commit per category** (per-consumer commits hide unification).
  - **VERIFY** — typecheck + lint + scoped tests + visual-regression on non-target surfaces (must not change pixels).
- **Validation pipeline (special-cased)** — extracts a 3-part system, not a single wrapper:
  1. Frontend validator composable (`useFormValidation()` or project-specific).
  2. Error rendering primitives (`<ErrorList>` + `<FieldError>` with one convention for placement + tone + required-field marker + summary placement).
  3. API-validation-error mapper wired as a global response interceptor; turns server `{field: [msg]}` into field-level errors the composable attaches.
  Migration order: ship 3 primitives → wire mapper → migrate forms one at a time (each removes its bespoke validator + bespoke error renderer + bespoke server-error handler).
- **Stack scope**: frontend-* / mobile-web / mobile-rn only. Halts on backend / data / library / CLI / mobile-native with redirect to `/polish`.
- **Multi-day workflow** — `ai/unify-surfaces/progress.md` matches the `/migrate /optimize /align /polish /audit` pattern. Same common flags (`--status`, `--resume`, `--re-audit`, `--refresh`, `--restart`, `--ignore-ledger`, `--max-parallel`, `--exclude`, `--surface-blockers`, `--dry-run`). Plus category-specific: `--surfaces=`, `--canonical=<category>=<wrapper-path>`, `--keep-ad-hoc=<glob>`, `--validation-library=<name>`.
- **Ends with paste-ready next steps** per `actionable-next-steps.md` snippet contract — surfaces skipped consumers, halted categories, and follow-ups (`/enhance-ui` for visual iteration after unification; `/polish --focus=<verb>` for residual axis drift; `/ui-crawl-fix` for mechanical findings on the now-unified wrappers).
- **Validator** `validate-unify-surfaces-artifacts.sh` is **planned**: per-category inventory completeness, canonical-wrapper-decision evidence, idioms-update co-commit, Reuse-Before-Create violations.

**Differentiation vs siblings**:
- **vs `/polish`** (frontend) — `/polish` is axis-typed (per-surface, across 18 axes); `/unify-surfaces` is surface-type-typed (per-category, across the project). They compose: unify the wrappers first, then polish each canonical wrapper to spec.
- **vs `/align`** — `/align` closes any `duplicated-surface-styles` finding via `extract-to-shared`; `/unify-surfaces` is opinionated about WHICH surface types to consolidate AND drives a per-category 5-step pipeline (inventory / decide / extract / migrate / verify) plus the special-cased validation pipeline.
- **vs `/enhance-ui`** — single-area iteration with style variants; this is whole-project type-level consolidation.
- **vs `/ui-sweep`** — measurement + HTML report + flow-based phasing; this is type-level unification with cascade-rewrite commits.
- **vs `/ui-crawl-fix`** — mechanical wrapper-level patches against `/ui-crawl` findings; this is surface-type-level extraction + migration.

**Sync chain** (per `feedback_full_sync_chain` discipline):
- `commands/unify-surfaces.md` (new)
- `docs/COMMANDS.md` — TOC, glance table row, dedicated `## /unify-surfaces` section with 7 categories table + pipeline + validation pipeline + flag block + output sample.
- `docs/REFERENCE.md` — "The 6 simple commands" section (was 5) + flag table; row added with frontend-stack scope + 3-part validation pipeline note.
- `README.md` — top-level table row added; "seven simple-surface commands" updated (was six).
- `templates/tool-adapters/_orchestration-sync.md` — purpose line, validator table (planned), hook globs (`ai/unify-surfaces/**`), brace-list `{migrate,optimize,polish,align,refactor,audit,unify-surfaces}` propagated.
- `templates/tool-adapters/_registry.md` — Simple-surface row updated; planned `unify-surfaces-parallel.sh` parallel-orchestrator entry added.
- `templates/tool-adapters/_discipline-enforcement.md` — `ai/unify-surfaces/progress.md` ledger entry; pack-ecosystem command list updated.
- `templates/tool-adapters/{12 adapters}/adapter.md` — Unify-surfaces pack bullet inserted after Audit bullet; orchestrator list in Actionable next steps universal contract includes `/unify-surfaces`.
- `commands/do.md` — intent → routing table row + ambiguous-disambiguation row + 3 routing examples + bottom command list.
- `CHANGELOG.md` — this entry.

**Distinct from siblings** — `/polish` (axis-typed across 18 axes; per-surface), `/align` (any-class structural drift), `/enhance-ui` (single-area iteration), `/ui-sweep` (HTML report specialist), `/ui-crawl` + `/ui-crawl-fix` (Playwright crawler + wrapper-level mechanical fix). `/unify-surfaces` is the simple-surface entry that explicitly types by surface category and runs the full extract-and-migrate pipeline.

### `/ui-crawl` + `/ui-crawl-fix` — Playwright cross-route QA crawler + wrapper-level auto-fixer (ui-ux pack v1.2.0)

**Why** — pre-`/ui-crawl`, surfacing regressions across 100+ routes was a manual click-through; `/ui-sweep` is the right tool for quarterly UI/UX cadence (HTML report, baselines, hierarchy metrics) but too heavy for "did the design-token change break anything". Needed a fast, repeatable, machine-readable crawler — and a wrapper-level auto-fixer so `/ui-crawl`'s typical output (~700 contrast + ~300 button-name + ~300 label findings) doesn't translate into 1,000 commits when 5 wrappers can close them all.

**What ships** — two new commands in `templates/packs/ui-ux/commands/`:

- **`/ui-crawl [<scope>] [--smoke] [--filter=<substr>] [--full-matrix]`** — Playwright + axe-core. Logs in once via `auth.setup.ts`, visits every crawlable route in `ai/audits/ui-crawl-inventory.json`, screenshots at 3 breakpoints (375 / 768 / 1440) plus dark mode plus RTL, walks in-page tabs (cap 8), opens up to 3 dialogs / dropdowns per route, runs `wcag2a` / `wcag2aa` / `wcag21aa` axe rules, captures console + page errors + network 4xx/5xx + horizontal-overflow detection per viewport. Severity scoring per route (load-fail 100, page-error 20, axe-critical 8, dialog-open-fail 6, etc.) → ranked `ai/audits/ui-crawl-findings.md` + machine-readable `.json`. Detect-only.
- **`/ui-crawl-fix [<class>] [--dry-run] [--safe-only] [--verify]`** — consumes the findings JSON and patches at the **wrapper level** (`FormField`, `CrudActions`, `TableActions`, `BaseModal`, etc.) so one fix cascades through hundreds of call sites. 8-class safe-list: `color-contrast` (token swap in `_variables.scss`), `button-name` (aria-label injection from i18n key), `label` (`for`/`id` wiring), raw `<Dialog>` / `<Dropdown>` / `<MultiSelect>` (swap to project's shared wrappers), `<v-html>` / `dangerouslySetInnerHTML` without sanitize, hardcoded `{ en: '', ar: '' }` translation refs, `<a target="_blank">` missing `rel="noopener noreferrer"`, empty silent `catch {}`. Skips human-judgment bugs (broken triggers, page-load failures, layout overflow, heading skips, 5xx, structural aria mismatches). Inherits closure-verb discipline from `align-discipline.md`: one finding-class = one commit, no new abstractions, behaviour-preservation gate, security findings ship with assertions, re-detect mandatory.

**Differentiation vs siblings**:
- **vs `/ui-sweep`** — `/ui-crawl` is faster (~30–60 min full crawl), broader (every route, not just sampled per phase), machine-readable (JSON for CI consumption); `/ui-sweep` is deeper (visual hierarchy / coverage % / cross-surface consistency / HTML report / visual baselines + drift). Use `/ui-crawl` for pre-release sweeps + recurring CI; `/ui-sweep` for quarterly cadence.
- **vs `/align-recheck`** — `/align-recheck` is structural-only (static-source detection); `/ui-crawl-fix` is browser-driven (axe in real DOM, network probes, dialog-trigger checks).
- **vs `/enhance-ui`** — `/enhance-ui` is single-area visual polish with iterate loop; this is whole-app mechanical detection + bulk fix.

**Stack scope** — frontend stacks only (`PROJECT_KIND in {frontend-*, mobile-web}`). Halts on backend / data / library / CLI.

**Sync chain** (per `feedback_full_sync_chain` discipline):
- `templates/packs/ui-ux/commands/ui-crawl.md` (new)
- `templates/packs/ui-ux/commands/ui-crawl-fix.md` (new)
- `templates/packs/ui-ux/_essentials.md` — rationale row updated (kept out of minimal due to Playwright + axe + scaffold dependency)
- `templates/packs/ui-ux/_topics.md` — two new topic specs with extracts_from + sections + cite_evidence: strict
- `templates/packs/ui-ux/_version.json` — bumped to 1.2.0
- `templates/tool-adapters/_ui-ux-pack-coverage.md` — capability matrix gains a column; per-tool translation rows updated; `{ui-sweep,ui-crawl,ui-crawl-fix,enhance-ui,design-review}` brace-list applied across 6 adapter sections; new responsibility item #6 forbids flattening `/ui-crawl` to "`/ui-sweep --auto-fix`".
- `docs/COMMANDS.md` — UI-UX track table gains 2 rows; new walkthrough section with the paired DETECT → FIX → VERIFY loop.
- `docs/REFERENCE.md` — TOC entry; new section after `/ui-sweep` covering when-to-use-which, auto-fixable safe-list, human-only triage list, output paths, hard rules.
- Downstream: `tenant-portal-v2/.claude/commands/{ui-crawl,ui-crawl-fix}.md` already in place (origin); propagated to `.opencode/commands/`, `.cursor/commands/`, `.kimi/skills/{ui-crawl,ui-crawl-fix}/SKILL.md`.

### `/audit` — full-stack engineering audit (new top-level orchestrator)

**Why** — `/optimize` covers architecture / SOLID / clean code / tactical perf, but stops short on security and on a scale-lens (the engineering-principle a heavily-trafficked system actually fails on first). Pre-`/audit`, the user had to chain `/optimize` + `/security-audit` + `/db-audit` + `/perf-audit` + `/design-system` and merge findings by hand — five commands, five plans, no cross-axis ranker, no scale anchor.

**What ships** — **`commands/audit.md`** (new ~360-LOC orchestrator). Sibling to `/migrate` / `/optimize` / `/align` / `/polish` / `/refactor`. Single command:

- **Eight-axis parallel scan in one pass**: architecture, SOLID + clean code, security (`security-auditor` + `auth-reviewer` + `secret-scan` + `deps-audit` + `threat-model`), DB perf (`database-optimizer` + `query-optimizer` + `schema-reviewer`), runtime perf (`performance-optimizer` + `caching-architect` + `n-plus-one-scan`), **scale + resilience** (own 13 scale-lens detectors + `system-architect` + `resilience-reviewer`), infra/capacity (`infra-architect` + `k8s-reviewer`), observability (`observability-reviewer` + `telemetry-architect`).
- **Differentiation vs `/optimize`**: 13 scale-lens detectors — hot-path scan, fan-out depth, sync HTTP in request path, single-instance bottleneck, lock contention, queue back-pressure, write amplification, tenant blast radius, capacity headroom, SLO delta, idempotency gaps, statelessness violations, cold-start cost. None of these are in `/optimize`'s detector set.
- **Cross-axis ranker** — orders findings by `impact-at-target-scale × blast-radius × fix-cost`, NOT by axis. P0 scale-blockers → P1 security/correctness → P2 high-leverage scale fixes → P3 architectural foundations → P4 tactical cleanup.
- **Scale anchors**: `--target-rps=<N>` and `--target-p95=<ms>` flags drive ranking. Defaults: 2× current measured RPS (from observability) OR 100 RPS / 200ms.
- **Plan + execute**: writes `ai/audit/plan.md`; executes in tier order. P0/P1 ship with regression tests in same commit. P2 ships with measured before/after. `--plan-only` short-circuits before execute.
- **Multi-day workflow** — `ai/audit/progress.md` matches the `/migrate /optimize /align /polish` pattern. Same common flags (`--status`, `--resume`, `--re-audit`, `--refresh`, `--restart`, `--ignore-ledger`, `--max-parallel`, `--exclude`, `--surface-blockers`).
- **Ends with paste-ready next steps** per `actionable-next-steps.md` snippet contract — deferrals route to `/optimize`, `/security-audit`, `/db-audit`, `/k8s-generate`, `/add-metrics`, `/refactor`, etc.
- **Validator** `validate-audit-artifacts.sh` is **planned**: P0 findings must cite a failure mode at target RPS; P0/P1/P2 findings must cite `<file:line>` + measured-or-estimated impact; rejects hand-waves (`etc.`, `would be slow`, `at scale this is bad`).

**Stack-agnostic by construction** (added 2026-05-08, same release):
- Stack list expanded in frontmatter + intro to enumerate every common backend (Node / TS / Python / Ruby / PHP / Java / Kotlin / Scala / C# / F# / Go / Rust / Elixir / Erlang / Crystal / Haskell / OCaml / Swift), frontend (Vue / Nuxt / React / Next / Remix / Svelte / SvelteKit / Solid / Qwik / Astro / Angular / Lit / Stencil / Preact / vanilla), mobile (Swift / SwiftUI / UIKit / Kotlin / Compose / RN / Flutter / Expo / Capacitor / .NET MAUI / KMP), data layer (relational / document / k-v / graph / search / time-series / warehouse / pipelines / streaming), CLI / library / SDK, serverless / edge, monorepo / polyglot.
- **Stack-conditional detector matrix** (13 axes × 6 stack shapes) added to `commands/audit.md`. Each scale-lens axis has a concrete fingerprint per `PROJECT_KIND` — backend (`every endpoint × RPS × cost`), frontend (`every route mount × visit-rate × LCP cost`), mobile (`every screen × open-rate × jank cost`), CLI / library / SDK (`every entry-point × invoke-rate × wallclock`), serverless (`every handler × invoke-rate × billed-ms`), data pipeline (`every step × per-batch rows × stage time`). The detector logic is universal; the fingerprint adapts. Multi-tenant axis (#8) is the only axis gated on a tenancy anchor.
- **Stack-appropriate target flags** — `--target-rps` (backend/serverless/pipeline), `--target-p95` (backend), `--target-vitals=fcp:N,lcp:N,tti:N,inp:N,cls:N` (frontend), `--target-cold-start` (serverless/mobile), `--target-startup` (CLI/library), `--target-bundle` (frontend/mobile). In polyglot monorepos, each `PROJECT_KIND` subtree picks up the flags that apply; non-applicable flags are ignored for that subtree.
- **Polyglot monorepo handling** — per-subtree PROJECT_KIND drives axis routing; cross-`PROJECT_KIND` fixes (e.g., backend idempotency key + frontend retry handler) bundle into one plan row.
- **Three load-bearing claims documented**: (1) detectors are shape-based not name-based, (2) specialist agents are themselves stack-agnostic, (3) no hard-coded language tokens — agent reads idioms from `_extracted-idioms.md` per project.
- Output examples added: backend (Laravel SaaS), frontend (Vue 3 storefront), **mobile (React Native)**, **serverless (AWS Lambda)**, **CLI / SDK (TypeScript)**, **polyglot monorepo (Next.js + NestJS + Python ETL)**.

**Sync chain** (per `feedback_full_sync_chain` discipline):
- `commands/audit.md` (new + stack-agnostic expansion)
- `docs/COMMANDS.md` — TOC, glance table, dedicated `## /audit` section (with stack matrix link + stack-appropriate flag block), multi-day workflow paragraph, common-flag block.
- `docs/REFERENCE.md` — "The 5 simple commands" section + flag table; row expanded with stack-conditional detector matrix description.
- `templates/tool-adapters/_orchestration-sync.md` — purpose line, validator table (planned), hook globs, `/refactor` callout.
- `templates/tool-adapters/_registry.md` — Simple-surface row + rule-only-tool fallback note.
- `templates/tool-adapters/{12 adapters}/adapter.md` — Audit pack bullet inserted after Align bullet; orchestrator list includes `/audit` in the Actionable next steps universal contract.
- `commands/do.md` — intent → routing table + bottom command list.
- `README.md` — top-level table (with stack list + flag list) + simple-surface count.
- Global `~/.claude/commands/audit.md` (symlink) + `~/.kimi/skills/audit/SKILL.md` (auto-generated).
- Downstream projects: `tenant-portal-v2` and `claude-v2` each got `audit.md` propagated to `.claude/commands/`, `.opencode/commands/`, `.cursor/commands/`, and Kimi skill wrapper at `.kimi/skills/audit/SKILL.md`.
- `CHANGELOG.md` — this entry.

**Distinct from siblings** — `/optimize` (no security, no scale lens), `/security-audit` (security-only), `/db-audit` (DB-only), `/perf-audit` (runtime perf only), `/design-system` (design-time only, not codebase scan). `/audit` is the simple-surface alternative that fans out and cross-ranks.

### `apply-adapter-sync.sh` normalizes agent `tools:` frontmatter for OpenCode

**Root cause** — Claude Code accepts agent frontmatter `tools:` as a comma-separated string (`tools: Bash, Read, Grep, Glob`), but OpenCode's schema requires a YAML record (`tools:\n  bash: true\n  read: true`). `sync_opencode()` did a verbatim 1:1 copy of `.claude/agents/<name>.md` → `.opencode/agents/<name>.md`. When a project's agent had been customized with the Claude string form (e.g. via `/setup-project --refine`), OpenCode refused to load: `Configuration is invalid… Invalid input: expected record, received string tools`. Hit a downstream project (May 2026) with `endpoint-tester.md`.

**Fix** — new helper `opencode_normalize_agent_tools()` runs after each agent copy in `sync_opencode()`:
- Detects string-form `tools:` lines inside the frontmatter (regex anchored to `fm==1` block + `^tools:[[:space:]]*[A-Za-z]` — won't match record-form, where the same line ends in whitespace).
- Splits values by `,`, trims, lowercases each, emits as a YAML record (`<name>: true` per line).
- Idempotent — second run on already-converted file is a no-op (detection short-circuits).
- Frontmatter-only — body markdown is never touched.

**Self-test verified** — converted `endpoint-tester.md` (Bash, Read, Grep, Glob) cleanly; second run no-op; OpenCode now loads.

### `apply-adapter-sync.sh` preserves project-specific blocks across all adapters

**Root cause** — `apply-anchors.sh` injects `<!-- project-specific:start --> ... <!-- project-specific:end -->` blocks into `.claude/{commands,agents,skills,rules}/`. `apply-adapter-sync.sh` then propagates `.claude/<file>` → adapter-native paths (`.cursor/commands/<file>`, `.opencode/commands/<file>`, `.qwen/commands/<file>`, `.github/agents/<name>.agent.md`, etc.). On REFRESH (overwrite), the old `sync_file()` did `cp "$src" "$dst"` blindly — wiping any project-specific block the destination had accumulated. This bit a downstream project (May 2026) when ~38 adapter files lost their blocks.

**Fix** — single chokepoint, scales to all 12 adapters automatically:

- **`extract_project_specific_block()`** (new helper) — `awk` extracts the block from a file when markers appear on their own line (real injected block); ignores prose mentions of the marker text inside backticks (safe against false positives).
- **`reinject_project_specific_block()`** (new helper) — re-injects extracted block at the canonical insertion point (after frontmatter / after first H1 / before first H2). No-ops if destination already carries a real block (avoids double-injection). Block passed via temp file because `awk -v` can't carry newlines.
- **`sync_file()`** (modified) — on REFRESH path: extract dst block to temp file, then `cp src dst`, then re-inject. NO-OP path and ADD path unchanged. Single line of net new behavior, single chokepoint, automatically protects every adapter (`.cursor/`, `.opencode/`, `.qwen/`, `.kimi/`, `.github/`, `.clinerules/`, `.windsurf/`, `.continue/`, plus future ones).

**Why this is the right place to fix it** — `apply-adapter-sync.sh` is the one script that copies `.claude/` → other adapters. Fixing here means we don't have to enumerate adapter folders in `apply-anchors.sh` (Option A would have hardcoded 12 paths and broken silently when adapters are added). Fixing the propagation chokepoint covers all adapters present and future with zero per-adapter mapping.

**Self-test verified** — clobbered `.opencode/commands/draft-phase-adrs.md` (lost block + lost project content), ran `apply-adapter-sync.sh --apply --adapters=opencode`, block + content restored cleanly. End-to-end on a real adapter file.

### Migration plan completeness — 3 system improvements

**Root cause** — observed in May 2026: a downstream project ran `/migration-scan` + `/migration-plan` and got incomplete output. The LLM that produced the plan skipped (a) heavy-tier promoter rows for auth/payment/order/cart/security (b) a cross-cutting audit dimensions preamble (tenant-isolation, cache namespacing, translation parity) (c) the `## Actionable next steps` section (the contract was new) (d) ~5 V1 directories without `.module.ts` markers were silently dropped from the ledger. Commands didn't fail; they just produced silently incomplete output.

**Fix** — three system improvements making this class of drift mechanically impossible going forward:

- **`templates/packs/migration/commands/migration-scan.md`** — added "Backend / API dir-walk completeness gate" subsection in Phase 2. For `PROJECT_KIND in {backend-*, api-other}`, scan MUST `find $v1_root -type d` recursively, filter to dirs with source files, and produce `dir_walk_total: N; mapped_to_rows: M; umbrella_excluded: K; dead_excluded: L; N == M + K + L` count assertion in scan-report. Halts when unmapped V1 dirs exist (catches the "module-marker filter missed alt-shape dirs" failure).

- **`templates/packs/migration/commands/migration-plan.md`** — restructured Phase 4 output template to require three load-bearing sections BEFORE Phase 1: (1) "Cross-cutting audit dimensions" preamble (tenant-isolation gate, cache-key namespacing, translation parity, naming-boundary integrity, audit/soft-delete columns, concurrency primitive parity, error envelope shape — stack-conditional), (2) "Heavy-tier promoter rollup" pre-flagging every auth / payment / order / cart / subscription / financial-transaction / saved-card / security / s2s / cron-write-path / multi-tenant-blast-radius row with `tier: heavy` so reviewer-approval engages, (3) `## Actionable next steps` per `templates/snippets/actionable-next-steps.md`. Phase 6 validate step expanded with foundation-completeness check (Phase 1 must mention ≥2 of: tenant-context, cache, error-envelope, audit-fields, concurrency, locale primitives).

- **`scripts/validate-migration-artifacts.sh`** — new `check_plan_completeness` function called against `ai/migration/plan.md`. Halts the gate when any of the 3 required sections is missing OR when Phase 1 foundation language references fewer than 2 of 6 core primitives. Self-tested 3 cases (good / missing-rollup-thin-foundation / missing-actionable) — all expected pass/fail outcomes confirmed.

**Why this is the right fix** — the migration system itself wasn't broken; the LLM running the commands had no mechanical gate forcing the output shape. Now the gate is mechanical: validators reject incomplete plans BEFORE `/migration-fast` fires, so the LLM is force-prompted to backfill the missing sections instead of advancing into per-feature audits with a thin plan. Same anti-Trusted-Summary discipline as the other halt-checks in the validator (`check_section_0_evidence`, `check_inventory_primitives_match`, etc.).

**Bug fix during implementation** — caught my own regex bug via unit test: `\|` inside double-quoted bash strings becomes literal pipe under `grep -E`, breaking OR matching. Fixed before sync.

### Bug fix — apply-anchors.sh leaves stale `<extracted-from-codebase>` placeholders

**Root cause** — three rule source files (`migration-discipline.md`, `concurrency-discipline.md`, `align-discipline.md`) shipped with an upstream **instructional blockquote** (`> Project-specific block — Phase 4.6 fills this in...`) full of `<extracted-from-codebase>` placeholders, plus a downstream `<!-- project-specific:start --> ... <!-- project-specific:end -->` marker block. `scripts/apply-anchors.sh` correctly populated the marker block but did not remove the upstream blockquote, so the placeholders survived into every project that ran `/setup-project --refresh`.

**Fix**
- **Source rules cleaned** — `templates/packs/{migration,backend,align}/rules/*-discipline.md` (+ matching `_examples/*.md`). Replaced the obsolete blockquote + 6-line placeholder list with a 1-line pointer at the canonical marker block (and `_v2-anchors.md` for migration).
- **`scripts/apply-anchors.sh`** — added `scrub_upstream_placeholder_blockquote()` safety-net function called per-file after `inject_block`. Mechanically removes any leftover blockquote that both starts with `> **Project-specific block** ... Phase 4.6` AND contains `<extracted-from-codebase>` — touches user content only when both fingerprints match (no false positives).

**Why this matters** — the placeholder text was confusing to any tool reading the rule top-to-bottom (Aider / Codex / Gemini in rule-only mode would see `<extracted-from-codebase>` first and misinterpret it as a missing extraction). Now the rule body either has no blockquote at all (source files updated) OR the scrub function removes it (existing project files re-anchored on next refresh).

### Universal "Actionable next steps" report contract

**Added**
- **`templates/snippets/actionable-next-steps.md`** (new) — canonical contract every report-producing command (`/optimize`, `/polish`, `/align`, `/migrate`, `/refactor`) follows. Every `final-report.md` MUST end with a `## Actionable next steps` section: comment line (WHAT + WHY + scope) + exact paste-ready command + sorted by leverage. Closes the dead-end-deferral failure mode where reports list "deferred items" with no routing.
- **`check_actionable_next_steps`** function added to all 5 validators (`validate-{optimize,polish,align,refactor,migration}-artifacts.sh`). Halts when the section is missing, when commands are outside a bash fence (not paste-ready), or when a `/<command>` line lacks a concrete path / `--scope=<path>` (i.e., hand-wave like `/refactor god files`). Migration accepts ledger-row tokens (`F<NNN>`) in addition to paths.
- **Per-command flag mapping** in the snippet — names the closure-verb vocabulary each command's actionable lines should cite via `--focus=<verb>` (`refactoring-sweep` 10 verbs for `/refactor`; `ui-design-sweep` 18 verbs for `/polish` frontend; `api-consistency-audit` for `/polish` backend; etc.).

**Changed**
- **`commands/optimize.md`** + **`commands/polish.md`** + **`commands/align.md`** + **`commands/migrate.md`** + **`commands/refactor.md`** — each gained a "## Final report contract" section pointing at the snippet, plus a "Final report MUST end with paste-ready next steps" rule under Hard rules.

**Why this matters** — without this contract, `/optimize` reports list "275 inline styles deferred" / "5 god files deferred" with no routing; users (and other tools) must manually translate deferrals into the next command. With it, the report ends with paste-ready commands like `/polish src/modules/inventory/` and `/refactor src/modules/orders/pages/OrdersListPage.vue --focus=extract-method` — direct user agency, no translation step.

### `/polish` frontend specialist — `ui-design-sweep` skill

**Added**
- **`templates/packs/ui-ux/skills/ui-design-sweep.md`** (new, ~340 LOC) — closed 18-verb closure vocabulary for the frontend half of `/polish`. Sibling to `refactoring-sweep` (code-quality), `api-consistency-audit` (backend), and `schema-consistency-audit` (data). Per-verb fingerprint + procedure + verify + WCAG / iOS HIG / Material / Refactoring UI citation. The 18 verbs: `consolidate-tokens`, `extract-token`, `unify-component`, `extract-pattern`, `normalize-hierarchy`, `apply-type-scale`, `tighten-rhythm`, `simplify-density`, `wire-empty-state`, `wire-loading-state`, `wire-error-state`, `lift-contrast`, `align-focus-ring`, `unify-iconography`, `normalize-motion`, `expand-tap-target`, `unify-cta-placement`, `clarify-affordance`, `normalize-surface`.
- **`templates/packs/ui-ux/rules/ui-principles.md`** — added "Axis catalog" section: 16 axes (tokens / wrappers / patterns / hierarchy / type-scale / rhythm / density / states / contrast / focus / iconography / motion / tap-target / cta / affordance / surface), each with heuristic + the closure verbs that operate on it. The skill cites this catalog per verb.
- **`scripts/validate-polish-artifacts.sh`** — new `check_frontend_verb_vocabulary` function rejects any `closure_verb:` outside the closed 18-verb set in `ai/polish/ledger.md` or `_visual-decisions.md`. Mirrors how `validate-refactor-artifacts.sh` enforces refactoring-sweep's 10 verbs.
- **`templates/packs/ui-ux/_essentials.md`** — `ui-design-sweep` added to the skills minimal-mode list (the closed-verb spec is essential, not optional).
- **`templates/packs/ui-ux/_topics.md`** — `ui-design-sweep` topic spec added with extraction sources + sections.
- **`templates/packs/ui-ux/_version.json`** — bumped `1.0.0 → 1.1.0` with summary.

**Changed**
- **`commands/polish.md` § Frontend (`frontend-*`)** — replaced ad-hoc detector / verb comma-list with reference to `ui-design-sweep`'s closed vocabulary; lists the 18 verbs by axis cluster.
- **`templates/packs/ui-ux/commands/ui-sweep.md`** — pruned the in-file verb table (was 12 verbs, half overlapping with polish's list); replaced with detector→verb mapping table that cross-references the canonical `ui-design-sweep.md` spec.
- **`docs/COMMANDS.md`** + **`docs/REFERENCE.md`** — `/polish` row references the 18-verb vocabulary + validator gate.
- **`templates/tool-adapters/_polish-pack-coverage.md`** — stack-conditional table now lists `ui-design-sweep` as the frontend closure-verb spec; new "Frontend-only — `check_frontend_verb_vocabulary`" validator-gate section enumerates the 18-verb set.
- **`templates/tool-adapters/_ui-ux-pack-coverage.md`** — `ui-design-sweep` added as a critical skill; capability table extended with `ui-design-sweep` column for all 12 tools (Kimi + Qwen rows added too).
- **All 12 `templates/tool-adapters/<tool>/adapter.md`** — Polish bullet extended with "frontend rows additionally gated by **`check_frontend_verb_vocabulary`** against the closed 18-verb **`ui-design-sweep`** set". Verb preserved per adapter (Include / Document / Add / Run / Also install / Shell CI should run / installs).
- **Downstream project propagation** — projects with the prior ui-ux pack already installed pick up the new skill via `/setup-project --refresh`: `ui-principles.md` gains the Axis catalog section; `skills/ui-design-sweep.md` is copied; `commands/polish.md` + `commands/ui-sweep.md` are re-rendered to reference the new skill. Project-specific marker blocks (`<!-- project-specific:start -->` / `<!-- project-specific:end -->`) are preserved by the SHA-256 hash check in the refresh routine.

### Adapter coverage — `/polish` + `/align`

**Added**
- **`templates/tool-adapters/_polish-pack-coverage.md`** (new) — capability mapping, stack-conditional evidence routing (`PROJECT_KIND` → `_visual-decisions.md` / `_api-decisions.md` / `_schema-decisions.md` / `_platform-decisions.md`), validator + `polish-parallel.sh` + `parallel-fan-out.sh --ledger=ai/polish/ledger.md` bundle.
- **Polish pack — companion scripts (2026-05)** bullet on all **12** `templates/tool-adapters/*/adapter.md` (verb preserved per adapter: Include / Document / Add / Run / Also install / Shell CI should run).
- **Align pack — companion scripts (2026-05)** bullet on all **12** `templates/tool-adapters/*/adapter.md` (closes prior gap — `_align-pack-coverage.md` shipped, validator existed, but no per-adapter bullet propagated).
- **`templates/tool-adapters/qwen/adapter.md`** — `_polish-pack-coverage.md` added to the Pack-coverage-docs cross-reference list.

### `/refactor` command

**Added**
- **`commands/refactor.md`** — Simple-surface targeted refactor (behaviour-preserving; `refactoring-sweep` verbs only); progress **`ai/refactor/`**, validator **`scripts/validate-refactor-artifacts.sh`** (`--self-test`).
- **Pack overlays** — `templates/packs/{code-quality,backend,frontend,mobile}/commands/refactor.md` + **`_examples/refactor.md`** per pack.
- **`templates/tool-adapters/_refactor-pack-coverage.md`** — adapter expectations; companion-script bullet on all **12** `templates/tool-adapters/*/adapter.md`.
- **`templates/tool-adapters/_registry.md`** — **12** top-level `commands/` entries; **`/refactor`** listed with simple-surface group.
- **`commands/do.md`** — routes narrow “refactor / extract / rename … + specific target” to **`/refactor`**; broad quality sweep stays **`/optimize`**.
- **`scripts/audit-setup.sh`** — **C2i**: `validate-refactor-artifacts.sh --self-test`.
- **Docs** — `README.md`, `docs/COMMANDS.md`, `docs/REFERENCE.md`.

### Final review fixes

**Changed**
- **`scripts/lint-tool-parity.sh`** — Phase 4.8.0 contract scan reads **`commands/setup-project-adapters.md`** (M2 split); **`parity_label_for`** adds **Kimi** / **Qwen**.
- **`commands/setup-project-adapters.md`** — Phase 4.8.0 table rows for **kimi** and **qwen** (native paths per `_registry.md` + adapters).
- **`templates/repo-baseline/ai/references/tool-parity.md`** — **Kimi Code** and **Qwen Code** columns (capabilities aligned with registry; Hooks row lifecycle parity **❌** for both).
- **`README.md`**, **`docs/setup-project-cheatsheet.md`** — track count **17 → 18**; **`align`** in the catalog list.
- **`~/.claude/` sync** — `scripts/sync-to-global.sh --apply` for missing symlinks (`templates/snippets`, `audit-command-dry.sh`, `audit-stack-leakage.sh`, `migration-reachability.sh`).

### Command DRY + SOLID single-source-of-truth

**Changed / Added**
- **`templates/governance/core-discipline.md`** — single pointer to SOLID + clean-code rules (`align-discipline`, `engineering-principles`, `quality-principles`).
- **`templates/snippets/`** — `phase-3-always-reads.md`, `hand-wave-grep.md`, `intent-gate-skeleton.md`, `instrumentation-parity.md` (canonical reusable blocks with front matter).
- **`templates/canonical-command-template.md`** — Phase 3 references snippets + `core-discipline.md` instead of inlining the ALWAYS list; **Reusable snippets** subsection.
- **Dedupe pass** — `db-audit`, `migration-review`, `add-telemetry` / `add-metrics` / `add-tracing`, baseline + backend `fix-bug` intent gate, `commands/optimize.md`; bulk Phase 3 ALWAYS → snippet link across pack commands that still inlined all seven paths.
- **Code-writing commands** — Phase 3 (or equivalent) **MUST read** `core-discipline.md` on `add-feature`, `add-component`, `add-crud-page`, `add-endpoint`, `fix-bug`, `align-recheck`, `commands/{optimize,align,polish}.md`, `refactorer` agent.
- **`scripts/audit-command-dry.sh`** — mechanical lint for duplicated SOLID prose / full Phase 3 paste / hand-wave grep; **`scripts/audit-setup.sh`** invokes it as **C2g**.
- **Docs** — `docs/REFERENCE.md`, `docs/COMMANDS.md`, this changelog.
- **Tool adapters** — `templates/tool-adapters/_template-author-scripts.md` (C2f/C2g + canonical pointers); README + `_registry.md` + `_discipline-enforcement.md` + `claude-code` / `cursor` adapter cross-references.
- **Setup-project link hygiene** — `templates/repo-baseline/.claude/templates/{snippets,governance}/` ships canonical snippet + `core-discipline.md` into targets; `apply-study-decisions.sh` rewrites `../../../snippets/` and `../../../governance/` → `../templates/...` when copying pack **commands** and **agents** so links work under `.claude/` (baseline `fix-bug.md` uses `../templates/` links directly).

### enhance-ui DRY fix — design-system-tier scope detection

**Changed / Added**
- **`templates/packs/ui-ux/commands/enhance-ui.md`** — Phase **1.5 Surface scope detection**: tiers `token` · `wrapper-variant` · `wrapper-extract` · `leaf-local`; duplicate call-site map; `$CONSUMER_ROUTES` for multi-route screenshots; cleanup includes **`duplicated-surface-styles`**. New flags: `--scope`, `--auto-extract`, `--dry-detect`. Hard rule: never repeat scoped iterate on ≥2 leaves for one shared affordance.
- **`templates/packs/ui-ux/skills/design-iterate.md`** — **`$SCOPE_TIER`** + **`$CONSUMER_ROUTES`**; per-tier edit surfaces; template/script locked for `leaf-local`; wrapper/token tiers with consumer screenshots.
- **`templates/packs/align/rules/align-discipline.md`** — UI/UX subclass **duplicated surface styles** → closure verb **`extract-to-shared`**.
- **`templates/packs/align/commands/align-recheck.md`** — `--class` example lists `duplicated-surface-styles`.
- **`docs/COMMANDS.md`** — `/enhance-ui` row documents DRY tiers and flags.

### Stack-agnostic language sweep

**Changed / Added**
- **`templates/rule-7-phase-4-6-file-adaptation.md`** — documented `<TBD: …>` vocabulary (tab primitive, router file, store, form helpers, hooks) + optional **STACK-AGNOSTIC** banner; Phase 4.6 substitution contract.
- **`scripts/apply-anchors.sh`** — per-file anchor block includes **Stack placeholders pending** when `<TBD:…>` tokens remain in the injected artifact (counted before injection).
- **`templates/packs/learning/skills/apply-pack-adaptation.md`** — Phase 4.6-DEEP section maps each `<TBD:…>` family to `_extracted-codebase.md` / `_extracted-idioms.md` reads.
- **`scripts/audit-stack-leakage.sh`** (new) — mechanical lint: universal docs must show multi-stack diversity or placeholders; pack-level files warn when tokens lack sibling stacks in ±5 lines. Exit 1 on FAIL.
- **`scripts/audit-setup.sh`** — invokes `audit-stack-leakage.sh` against the template pack source repo (C2f).
- **Docs** — `docs/REFERENCE.md` validator row; universal commands + templates swept for Vue-only / React-only leakage (notably `scaffold-project`, `migrate`, `appendices`, code-quality agents).
- **Frontend pack** — `templates/packs/frontend/rules/migration-frontend.md` Layer-A-Only Scan row uses `<TBD: …>` + primitive-table cross-reference; translation anti-pattern lists Vue / React / Angular / Svelte cues.

### Migration cycle accuracy — validator + tooling hardening

**Changed / Added**
- **`scripts/validate-migration-artifacts.sh`** — Section 0 wired into `validate_feature`; trivial-tier primitive gate fixed; `mixed` `project_kind`; strict corpus / gap-marker checks; reachability + cutover-evidence + tolerance/scope hooks; forms-bearing aggregation; backend-only bypass for primitives.
- **`scripts/migration-doctor.sh`** — Cross-repo deps + stale audits affect exit code; YAML/fenced ledger parsing aligned with canonical ledger shape.
- **`scripts/migrate-parallel.sh`** — Row discovery aligned with `## <id>` + `state:`/`status:` blocks.
- **`scripts/parallel-fan-out.sh`** — Optional `LEDGER_LOCK` flock around worker ledger writes.
- **`scripts/migration-detect-existing.sh`** — `v2_root` from `_v2-anchors.md`; broader scan roots / patterns.
- **`scripts/migration-reachability.sh`** (new) — 6-axis reachability template + `--lint`.
- **Docs / schema** — `mixed` in `_v2-anchors-schema.md`; tier default narrative unified (trivial until audit); `commands/migrate.md` recovery flags; example `cutover-evidence-stage.json`.
- **Tool adapters** — `_migration-pack-coverage.md` documents the **full** `scripts/` bundle (validator + doctor + reachability + detect-existing + parallel flock); `_discipline-enforcement.md` lists cutover + reachability paths; `_registry.md` notes flock / ledger parsing; every `templates/tool-adapters/*/adapter.md` cross-references the companion-script contract.

### Optimize cycle accuracy — validator + tooling hardening

**Changed / Added**
- **`scripts/validate-optimize-artifacts.sh`** — Phase 0 non-empty blocks, per-`### F-A-*` citations, oracle presence + `--strict` idioms reference, hand-waves, optional ledger parsing (`id:` fenced YAML), terminal `gaps_in == gaps_closed`, structural net-lines / functional idiom heuristic, findings-dir hand-waves.
- **`scripts/optimize-parallel.sh`** — Canonical **`id:`** + fenced-block ledger picker (matches migrate-parallel); forwards **`--ledger`** to `parallel-fan-out.sh`.
- **`scripts/parallel-fan-out.sh`** — **`--ledger=<path>`** sets the flock target (CLI overrides default `ai/migration/ledger.md`).
- **`scripts/migrate-parallel.sh`**, **`align-parallel.sh`**, **`polish-parallel.sh`**, **`audit-parallel.sh`** — Pass **`--ledger`** through to the fan-out engine.
- **`templates/tool-adapters/_optimize-pack-coverage.md`** (new) + optimize companion-script bullets on every `templates/tool-adapters/*/adapter.md`.
- **Docs** — `docs/REFERENCE.md` (validator truth table + `--ledger`); `templates/tool-adapters/_discipline-enforcement.md` (validator scope caveat); `commands/optimize.md` (mechanical vs agent-side tags).

### M21 — Decisions-first batch flow for migration pack

User pain point: "running /port-feature per row takes very long and I need to keep my eye on the CLI." Per-feature interactive ports re-prompt the user for the same cross-cutting decisions (RBAC slug renames, payload shape changes, `is_active` defaults) once per affected feature. M21 adds a **decisions-first batch flow** that decouples decisions from execution.

#### Added
- **`/draft-phase-adrs <N>`** (new command) — Reads `phase-<N>.md` audit summary + per-feature audits, drafts one ADR per P0 + cross-cutting decision in `ai/decisions/`. Each ADR ships as `Status: proposed`; user reviews + flips to `accepted` in one focus session. Cross-cutting decisions get a single ADR covering ≥2 features (instead of N micro-decisions across N port runs).
- **Index doc** `ai/decisions/_phase-<N>-decisions.md` — single managed-block index per phase listing every drafted ADR + cross-repo coordination items + sign-off checklist.

#### Changed
- **`/port-feature`** — added `--unattended` flag. When set, the command reads accepted ADRs as pre-approved decisions and skips the matching halts (e.g., contract review, plan slicing, intentional-break authoring). HALTS preserved for: new ambiguities not covered by an ADR, path violations, parity-auditor verdicts, cutover stage advance.
- **`/migration-phase <N>`** — added `--chain` flag. After `/draft-phase-adrs` produces ADRs the user accepts, `--chain` runs `/port-feature <id> --unattended` per feature in dependency order, aggregates halts at end-of-phase, and auto-invokes `/migration-gate <N>`. New `--stop-on-halt` (default) and `--no-stop-on-halt` modifiers. Mutually exclusive with `--audit-only`.
- **`docs/COMMANDS.md`** — Suite A migration table updated with `/draft-phase-adrs` row + new "batch workflow" example next to the interactive workflow.

#### Why
Empirical: Phase 7 + Phase 8 audits (<frontend-v2>, 21 features total) surfaced the same RBAC permission-slug renames recurring across 4–8 features per phase. Per-row interactive `/port-feature` would require deciding the rename policy 4–8 times. Batching cuts that supervision cost ~30% per phase. The pattern is exactly Phase 2 of any phased migration plan ("Pre-port decisions") — already built into `/migration-plan`'s output, but skipped when teams jump from `--audit-only` to per-row porting. M21 makes Phase 2 first-class with its own command + the unattended wiring.

#### Compatibility
- **Backward compatible.** Default `/migration-phase <N>` and `/port-feature <id>` invocations unchanged. `--chain` and `--unattended` are opt-in.
- **No new artifacts in the discipline rule.** `migration-discipline.md`'s 9-section contract, 10-halt audit, parity tests, perf-decisions, rollback runbooks all unchanged. The new command + flags are about *when* the user makes intentional-break decisions, not *what* the discipline requires.

#### Files touched
- `templates/packs/migration/commands/draft-phase-adrs.md` (new)
- `templates/packs/migration/commands/port-feature.md` (added Flags + Unattended-mode sections)
- `templates/packs/migration/commands/migration-phase.md` (added flags + Workflow modes table + Chain mode section)
- `docs/COMMANDS.md` (Suite A table + batch workflow example)

## [2.16.0] — 2026-04-28

### M20 — Fill remaining pack gaps (19 new artifacts across 5 packs)

User: "fix the gaps." M20 closes coverage in security / performance / observability / infrastructure / distributed-systems.

#### Added (per pack)
- **security** (3 commands): secret-scan, threat-model, dependency-vuln-check
- **performance** (4): commands profile-perf + bundle-perf; agent caching-architect; pattern lazy-loading
- **observability** (4): commands add-tracing + add-metrics + alert-design; skill slo-audit
- **infrastructure** (5): commands audit-iam + cost-audit + provision-tier; skill tf-plan-review; pattern multi-region
- **distributed-systems** (4): commands add-saga + add-event-handler + audit-distributed-tx; skill dlq-replay

#### Verified
- audit-template-quality: 0 thin / 0 non-7-phase / 0 no-preflight / 0 no-output / 0 thin (any kind). Every M20 file at full canonical depth.
- smoke-test: 8/8 pass; 0 fail / 0 warn.
- verify-sync: 57 ok / 0 drift.

#### State after M20
17 packs; all with ≥2 commands except ui-ux (1 command + 3 audit skills). No empty packs. Coverage spans:
- Web (backend + frontend)
- Mobile
- Code-quality / testing / refactoring
- Database (incl. migrations)
- Security (incl. threat modeling + secret scanning + dep vuln)
- Performance (perf + bundle + caching + lazy-load)
- Observability (tracing + metrics + alerts + SLO)
- Infrastructure (provisioning + IAM + cost + tf-review + multi-region)
- Distributed systems (sagas + events + DLQ + idempotency)
- Business completeness (cycles + funnel + coverage)
- UI-UX (design tokens + a11y + motion)
- Documentation, devops, learning, migration

The pack-template content is the deep knowledge center the user asked for. The agent's job is honoring the M11→M17 contracts so that content lands in target projects.

## [2.15.0] — 2026-04-28

### M19 — Mobile / business / ui-ux pack expansion (17 new artifacts)

User asked for a deep knowledge center, no stubs. M19 fills the largest coverage gaps.

#### Added — mobile pack (10 new; was 2 → now 12)
- commands: `add-screen`, `add-feature`, `optimize-bundle`
- agents: `app-store-reviewer`
- skills: `bundle-analyze`, `native-bridge-audit`
- patterns: `offline-sync`, `native-storage`, `deep-linking`

#### Added — business pack (4 new; was 5 → now 9)
- rule: `business-completeness`
- skills: `audit-funnel-completion`, `check-business-coverage`
- pattern: `missing-counterparts`

#### Added — ui-ux pack (3 new; was 11 → now 14)
- skills: `design-token-audit`, `motion-audit`, `a11y-quick-check`

#### Pack inventory after M19
| Pack | Before | After |
|------|--------|-------|
| mobile | 2 | 12 |
| business | 5 | 9 |
| ui-ux | 11 | 14 |

#### Verified
- audit-template-quality: 0 thin / 0 non-7-phase / 0 no-preflight / 0 no-output / 0 thin (any kind).
- smoke-test: 8/8 pass; 0 fail / 0 warn.
- verify-sync: 57 ok / 0 drift.

#### Honest scope
M19 fills the largest gaps. distributed-systems / infrastructure / observability / performance / security still have 1-2 commands each — M20+ candidates. Each new artifact is 100-300 lines of engineering content.

## [2.14.0] — 2026-04-28

### M18 — Template content audit + frontend `/add-feature` parity

User asked for review of ALL templates. Real audit + concrete fix.

#### Audit results (71 commands, 70 agents, 43 skills, 34 rules, 53 patterns)
- Thin commands: 0
- Non-7-phase commands: 0 (read-only exceptions honored)
- Thin / no-preflight / no-output agents: 0
- Thin skills / rules / patterns: 0

**Total: 0 content-quality issues.** Pack templates are clean.

#### Diagnosis: the 57-line stub
The user's `add-feature.md` at 57 lines in <frontend-v2> was NOT a pack issue. The pack source is 301 lines, well-formed. The 57-line file was an **agent-authored stub from a prior buggy run** — exactly the bug class M11/M15/M16/M17 closes. M15's `study-existing.sh` correctly flags it as `REPLACE-OR-ENHANCE` (target 57 / pack 301 = 19%).

#### Real cross-pack gap closed
- **`templates/packs/frontend/commands/add-feature.md`** added (~250 lines). Mirrors backend's depth, uses canonical 7-phase template, dispatches frontend-specific agents (ui-architect / ui-reviewer / accessibility-auditor / i18n-auditor / design-system-guardian), hard rules (one styling system, every string is a key, schema validation at boundary).

#### Added
- `scripts/audit-template-quality.sh` — re-runnable comprehensive audit. Honors documented exceptions (read-only commands skip Phases 5-7).

#### What this means
M15+M16+M17 detect / refuse stubs at the artifact layer. M18 confirms the source content is clean. Together: when the agent honors the M11→M17 contract, refresh produces good output because the templates are quality AND the agent can't ship shortcuts.

#### Honest scope
Audit is mechanical. Doesn't verify semantic quality, version freshness of framework references, or cross-reference resolution. Those are per-file human review.

## [2.13.0] — 2026-04-28

### M17 — Final round: front-loaded contract + composite + auditor + regression

User asked for the final round. M17 closes the four remaining gaps from the M11 → M16 trajectory: prose-rule skipping, no single composite invocation, audit-form Phase 5 still LLM-judged, and no regression test for the whole loop.

#### Added
- `scripts/run-preflight.sh` — composite invocation. Runs all 4 deterministic scripts in order. The orchestrator's hard rule becomes "run THIS one script."
- `scripts/audit-setup.sh` — Phase 5 deterministic auditor. Reads all 4 reports, checks `<TBD>` markers, counts structural recommendations, verifies pack-coverage Missing rows are now present. Exit 1 = REFUSED; exit 0 = safe.

#### Changed — orchestrator front-loaded
- `commands/setup-project.md` opens with **🛑 STEP ZERO — deterministic preflight (M17)**. Before persona, before mandate. Agent reads: run preflight at Phase 0.0; run audit at Phase 5; if audit exits 1 → REFUSED; Phase 4's work plan IS the 4 reports.

#### Changed — smoke test extended
- `smoke-test.sh` check #8: M17 regression. Copies django fixture, runs preflight, verifies 3 reports written, runs audit, verifies it exits 1 (TBDs unfilled = expected). Catches any break in the M11→M17 chain.

#### Closes M11→M16 trajectory
| Gap | Closed by |
|---|---|
| Prose rules skipped under context pressure | M17 front-loaded contract |
| 4 separate scripts → easy to forget one | M17 `run-preflight.sh` composite |
| Phase 5 audit LLM-judged | M17 `audit-setup.sh` deterministic |
| No regression test for the loop | M17 smoke check #8 |

#### Verified
- `smoke-test.sh`: 8/8 pass; 0 fail / 0 warn.
- `verify-sync.sh`: 56 ok / 0 drift.

#### Honest scope
M11 → M17 is mechanical from orchestrator's first instruction to Phase 5's exit code. Remaining LLM-judgment: filling `<TBD>` prose, addressing actionable rows in Phase 4, judging recommendation quality. Bug class reduced from "agent silently skipped the work" to "agent did the work shallowly" — much narrower and easier to spot in review.

## [2.12.0] — 2026-04-28

### M16 — Full codebase analysis + structural recommendations contract

User directive: "the next run — refresh / migration / refine — must prioritize a full codebase analysis. Review the current setup, every individual file, all command/setup/package-level files. Decide on **meaningful, structural improvements — not just minor, isolated changes.**"

M15 covered the artifact layer (.claude/ + ai/). M16 covers the actual codebase (src/, app/, lib/, manifests, configs).

#### Added
- `scripts/deep-codebase-scan.sh <target>` — walks the actual codebase. Mechanical sections (auto-filled):
  - Section 1: file count by language extension
  - Section 2: top-level directory tree
  - Section 3: manifests + framework markers detected (package.json, pyproject.toml, vite.config, next.config, tsconfig, etc.)
  - Section 4: suffix patterns visible (`*.service.ts`, `*.repository.ts`, `*.dto.ts` — counts files matching 30+ architectural suffixes)
  - Section 5: lines of code by language (excluding tests)
  - Section 6: pattern grep — class extenders (TS/JS + Python) → potential base classes with 3+ extenders
  - Section 7: setup-artifact summary (cross-reference for drift detection)

  Then 8 semantic-questions sections (LLM MUST fill — empty = Phase 5 fails):
  - Section 8: module map — top-level features/contexts visible in code
  - Section 9: architecture pattern detected (vs ai/architecture.md declaration)
  - Section 10: top 10 conventions visible — compared to ai/conventions.md
  - Section 11: patterns repeated 3+ times (candidates for ai/patterns/)
  - Section 12: decisions implicit in code (candidates for ADRs)
  - Section 13: drift between rules and code (rules code violates, code patterns not in rules)
  - Section 14: stale references in setup (paths/classes that no longer exist)
  - **Section 15: recommended STRUCTURAL improvements** — minimum 3 on non-trivial codebases. Format requires What / Why / Where / Effort / Risk per item. Explicit "qualifies vs doesn't qualify" examples in the script — minor isolated changes are REJECTED.

  Output: `<target>/.claude/_codebase-scan.md`. Bug fix: `|| true` on grep pipelines so pipefail doesn't kill the script when no matches found.

#### Changed
- **Phase 0.0** now mandates running the 4th script (`deep-codebase-scan.sh`) alongside M15's three. Total: 4 reports the agent must consume.
- **Phase 5 audit C2c** (NEW): 6 must-pass checks for the deep-scan report. Empty section = fail. Less than 3 structural recommendations on a non-trivial codebase = fail. Drift findings unaddressed = fail. Stale references unaddressed = fail.

#### What this changes for the user

Next `/setup-project --refresh / --refine / --enhance` on any codebase:

1. Phase 0.0 runs `deep-codebase-scan.sh` → mechanical sections auto-fill (file counts, suffix patterns, base classes, manifests).
2. Agent MUST fill semantic sections 8-15 — module map, architecture pattern, conventions visible, repeated patterns, implicit decisions, rule-vs-code drift, stale references, **structural improvements**.
3. Phase 4 reads section 15's recommendations and applies them (ADRs proposed, patterns documented, rules updated/anchored, stale refs cleaned).
4. Phase 5 refuses success if any section is `<TBD>`, if section 15 has fewer than 3 structural recommendations, or if recommendations are minor.

**Net effect**: the historical bug ("refresh ran shallow — touched ≤5 surface files, never compared rules to code, never proposed structural changes") becomes mechanically prevented at the artifact layer (M15) AND the code layer (M16).

#### Verified
- Tested against `claude-config/tests/setup-project/fixtures/django/` — script ran clean, wrote 131-line report with 10 `<TBD>` markers (8 mandatory sections × 2 lines each + section 15 + summary).
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 54 ok / 0 drift.

#### Honest scope statement
The script is deterministic. The semantic answers are LLM-authored. Phase 5 audit catches empty `<TBD>` and "fewer than 3 recommendations" mechanically. **It cannot judge whether recommendations are genuinely "structural" vs "isolated"** — that's still LLM judgment in the audit, partially mitigated by the explicit qualifying-examples table embedded in section 15.

## [2.11.0] — 2026-04-28

### M15 — Make refresh / refine / enhance / migration actually do the deep work

User reported repeatedly that `/setup-project --refresh --include=migration` produced shallow output: backed up + version-stamped + a few derived files, then declared "no work to do" while 21 migration pack files were missing from the target. Re-running M11's "directory parity scan" rule didn't fix it because the agent kept ignoring prose rules under context pressure.

**M15 root cause**: prose rules don't constrain LLM behavior. Shell scripts producing files the LLM must read DO constrain it.

#### Added — three deterministic scripts

- `scripts/pack-coverage-scan.sh <target> [packs...]` — for each selected pack, lists pack source files vs target, classifies each as Missing or Present (with size ratio for merge-matrix decisions). Writes `.claude/_pack-coverage-report.md`. Exit always 0; the report is the contract.
- `scripts/refresh-extract-checklist.sh <target>` — auto-inventories the target's existing artifacts (counts of agents, commands, skills, rules, ADRs, patterns); writes `.claude/_refresh-extract.md` with **9 prose sections that Phase 0.2 MUST fill**. Sections 2-8: ADRs preserved, validated user corrections, project intent, custom rules, custom agents/skills/commands, architecture decisions implicit in code, detected stack + version. Section 9: V1↔V2 mapping when migration in scope. Empty `<TBD>` sections fail Phase 5 audit.
- `scripts/study-existing.sh <target> [packs...]` — for every existing target file with a pack equivalent, applies Appendix C merge matrix deterministically: byte-identity check first (IDENTICAL-NO-OP), then size ratio decides REPLACE-OR-ENHANCE / KEEP-OURS-PLUS-INJECT / MERGE / KEEP-OURS-ADD-SIDE-DOC / KEEP-OURS-DEEP. Files in target but NOT in pack flagged as REVIEW (project-specific keeper or upstream-deprecated). Writes `.claude/_study-existing-report.md`.

#### Changed — phases now MANDATE the scripts

- **Phase 0.0 (NEW first sub-step of Phase 0)**: runs all three scripts before any other Phase 0 work. Reports become the contract for Phase 4 actions.
- **Phase 4.0**: if Phase 0.0 didn't run (CREATE/ENHANCE skip Phase 0), Phase 4.0 runs `pack-coverage-scan.sh` + `study-existing.sh` itself. Either way, no Phase 4.2 decision is made without consulting the reports.
- **Phase 5 audit (C2b NEW)**: 7 new must-pass checks:
  - The three reports exist.
  - Every "Missing" / "REPLACE-OR-ENHANCE" / "MERGE" / "KEEP-OURS-PLUS-INJECT" row was addressed (or explicitly skipped with rationale).
  - Sections 2-8 of `_refresh-extract.md` are non-empty.
  - Section 9 non-empty when `--include=migration` was set.

#### Sync infrastructure

- Added `scripts:scripts` to `sync-to-global.sh` `SYNC_MAP`. `~/.claude/scripts/` is now symlinked back to the repo. Old `~/.claude/scripts/` directory backed up automatically.
- 23 scripts now visible at `~/.claude/scripts/` for the agent to invoke.
- `verify-sync.sh` updated to check scripts as well: 53 ok / 0 drift (was 30 ok before scripts were synced).

#### Verified
- All 3 scripts work against `<frontend-v2>` (used as live test target):
  - `pack-coverage-scan.sh <frontend-v2> migration` → wrote report listing all 21 pack files (all present after prior manual cp).
  - `refresh-extract-checklist.sh <frontend-v2>` → wrote checklist with auto-inventory + 9 sections demanding fill.
  - `study-existing.sh <frontend-v2> migration` → 0 actionable / 21 keep / 48 orphans (correctly classifies the 21 migration files as IDENTICAL-NO-OP and flags 48 project-specific commands/agents for REVIEW).
- `lint-artifact.sh`: 0 errors / 22 warnings.
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 53 ok / 0 drift.

#### What this changes for the user

Next `/setup-project --refresh --include=migration` run on a target where files are missing:

1. Phase 0.0 runs `pack-coverage-scan.sh` → writes report listing every missing file by name and target path.
2. Phase 0.0 runs `study-existing.sh` → classifies every existing-vs-pack pairing per Appendix C.
3. Phase 0.0 runs `refresh-extract-checklist.sh` → produces the 9-section extract template the agent must fill.
4. Phase 4 reads ALL three reports and applies the decisions. Cannot skip "Missing" rows.
5. Phase 5 audit refuses success if any actionable row was silently ignored.

The historic bug ("idempotent — no work to do" while 21 files missing) becomes mechanically impossible: the report lists the 21 files, Phase 4 must address each, Phase 5 verifies.

#### Honest scope statement
The scripts are deterministic. The agent reading them is still an LLM. If the agent ignores the script output entirely (a regression of the same class), Phase 5's "did Phase 4 address every actionable row?" check catches it — but only if the agent honors Phase 5. M15 raises the floor significantly; doesn't eliminate LLM judgment from the loop entirely.

## [2.10.0] — 2026-04-28

### M14 — Related sections across all packs

User: "not migration only — all commands agents skills rules and the ai knowledge for all packs". Real refinement work, not a survey.

#### Coverage before M14
- Migration commands: 11/12 had `## Related` (M13 added them).
- All other commands + agents: **0 / ~120 had Related sections.**

#### What landed
- `scripts/add-related-sections.sh` — generates per-file Related sections from the pack's contents:
  - Sibling commands / agents in the same pack/kind.
  - Patterns in the same pack.
  - Rules in the same pack.
- Idempotent: skips files that already have `## Related`.
- Default dry-run; `--apply` to write.

Applied across all packs:
- **98 files updated** with Related sections.
- 11 files skipped (migration commands already had them from M13).

After M14: every command + agent in every pack has navigation links to siblings + patterns + rules.

#### Audit findings (no fixes needed)
Verified during the per-pack pass:
- All 11 migration commands' phase counts are correct (false positives caused by sed double-counting example output blocks).
- 514-line `apply-pack-adaptation` skill is justified (two distinct mode outputs).
- 273-line `api-reviewer` agent is content density, not padding.
- 4 baseline rules (A19) reviewed in M7 — still solid.

#### Honest scope
- M14 is **mechanical**: Related sections auto-generated from pack contents. Each section lists ALL siblings, not just the most-relevant ones — so it's a navigation aid, not a curated cross-reference.
- M14 does **not** read individual file content for semantic improvements. That remains M15+ multi-day work.

#### Verified
- 109/109 commands + agents now have `## Related`.
- `lint-artifact.sh`: 0 errors / 22 warnings (the 2 new warnings: `add-frontmatter.sh` and `add-related-sections.sh` themselves are not under packs/, so unrelated).
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 30 ok / 0 drift.

## [2.9.0] — 2026-04-28

### M13 — Final review pass: migration command navigation

User asked for a final review with focus on whether content is actually refined. Real findings + real fixes.

#### Audit findings

**False positives (no fix needed):**
- `migration-status` 4-phase count is intentional — read-only commands canonically skip Update/Validate/Improve.
- `migration-plan` 10-phase count was a grep false positive — extra 3 are inside an example code block; actual structure is correctly 7-phase.
- 514-line `apply-pack-adaptation.md` skill — verified to be two distinct example outputs (shallow + deep anchor); both needed.
- 273-line `api-reviewer.md` agent length is justified by content density (checklists + examples, not padding).

**Real fix landed:**
- **None of the 10 new migration commands had a `## Related` section.** Added them. Each command now links to siblings (where in the workflow), patterns/rules it depends on, and output paths it produces. Self-navigable.

#### Verified
- 10/10 migration commands have `## Related` sections.
- `lint-artifact.sh`: 0 errors / 20 warnings.
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 30 ok / 0 drift.

#### Honest scope
Audit was structural + sample-deep. Every migration command read for navigation completeness; longest-3 skills + agents sampled to verify length is justified. ~150 files under packs/ were NOT exhaustively read — prior structural lint (M6) + dedup audit (M7) + spot-reads (M8) cover their quality at the ensemble level.

## [2.8.0] — 2026-04-28

### M12 — Migration lifecycle commands + extended ledger schema

User asked for "all migrations no skip" — meaning all 10 gaps from the M10 self-critique should land. M12 ships them.

#### Added — 6 new commands
- `commands/migration-rollback.md` — restores phase N's pre-run state. Reverts ledger + ported files (managed blocks). User-authored content preserved. Mandatory reason logged. Backup never auto-deleted.
- `commands/migration-replan.md` — regenerates plan from current ledger. Preserves `done` rows in original phase numbers; re-phases everything else. Use after rollbacks / V1 changes / when day-1 plan ages out.
- `commands/migration-park.md` — set hairy features aside without blocking phase gate. Writes `parked/<id>.md` with full context. Reversible.
- `commands/migration-unpark.md` — reverse a park. Restores `prior_status` + `prior_phase`. Archives parked file to `parked/_resolved/`.
- `commands/migration-deprecate.md` — V1 feature being killed in V2. Requires Accepted ADR. Permanent — no undeprecate. Tenant-impact + V1-sunset captured.
- `templates/workspace-baseline/.claude/commands/migration-workspace-status.md` — cross-repo aggregator (workspace-level). Reads each sibling's ledger, reports per-repo summary + cross-repo blockers + phase synchronization.

#### Extended ledger schema (`ai-patterns/migration-ledger.md`)
New fields documented:
- **Park/unpark**: `parked_reason`, `parked_blocker` (`decision-pending` / `third-party` / `arch-debt` / `adr-needed` / `other`), `parked_at`, `prior_status`, `prior_phase`, `unparked_at`, `unparked_reason`.
- **Deprecation**: `deprecated_at`, `deprecated_by`, `deprecation_adr` (mandatory), `deprecation_reason`, `tenant_impact`, `v1_sunset_date`.
- **Per-feature cutover**: `cutover_mechanism` (overrides project default — `feature-flag` / `strangler` / `dns-swap` / `blue-green` / `parallel-write` / `shadow-read` / `sticky-session` / `direct`), `cutover_progress` (`0%` → `10%` → `50%` → `100%`).
- **Composition**: `composes:` (1 V2 ← N V1), `composite_of:` (1 V1 → N V2). For split / merge cases.
- **Soft-parity tolerance**: `soft_parity_tolerance:` list of axes where exact parity isn't required (timestamp_format, error_message_wording, currency_rounding, etc.). Avoids ADR-pollution for cosmetic diffs.
- **Phased flow tracking**: `phase`, `phase_passed_at`, `audit_findings`, `intentional_break` (ADR ref).

#### Changed — `migration-scan` flags
- `--since=<commit>` — incremental scan for large repos.
- `--include-deprecated=<re-scan|skip>` — handle deprecated rows on re-scan.
- `--workspace` — produce a workspace-level ledger.

#### Changed — manifests + docs
- `_essentials.md` `commands` list extended to 12 (was 7).
- `_topics.md` adds 5 entries under "Suite C — lifecycle commands".
- `docs/COMMANDS.md` migration section now shows three suites: Suite A (phased), Suite B (per-feature), Suite C (lifecycle).

#### Verified
- `lint-artifact.sh`: 0 errors / 20 warnings (the 5 new commands all parse clean).
- `test-pack-directory-parity.sh`: 0 errors (migration pack manifests in sync).
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 30 ok / 0 drift.

#### Coverage of the M10 critique gaps

All 10 gaps from M10's self-critique now have a system answer:

| Gap (from M10 critique) | Resolved by |
|---|---|
| 1. Re-audit cost | `--since=<commit>` flag |
| 2. Binary done/not-done | `cutover_progress` field |
| 3. No rollback | `/migration-rollback` |
| 4. No deprecation path | `/migration-deprecate` |
| 5. No split/merge | `composes` / `composite_of` fields |
| 6. Single cutover mechanism | per-feature `cutover_mechanism` field |
| 7. Hairy feature blocks phase | `/migration-park` |
| 8. ADR per cosmetic diff | `soft_parity_tolerance` field |
| 9. No multi-repo coordination | `/migration-workspace-status` |
| 10. Plan ages out | `/migration-replan` |

#### Honest scope statement
Coverage is at the **schema + command level.** The actual logic (what happens when `/migration-rollback 3` runs against a real repo with parked features that depended on now-deprecated ones) is documented in each command's hard rules but has not been exercised against real data. Expect at least one edge case to surface in first real use.

## [2.7.0] — 2026-04-28

### M10 — Migration command suite (5 phased-execution commands)

User asked for slash commands instead of agent prompts for V1→V2 migration. Built 5 stack-agnostic commands that force a phased migration with gap-finding + verification.

#### Added
- `templates/packs/migration/commands/migration-scan.md` — deep V1↔V2 comparison. Reads BOTH codebases, understands structures, builds `ai/migration/ledger.md` with every row `status: unverified` (trust nothing). Outputs `scan-report.md` with structural deltas + recommended phasing.
- `templates/packs/migration/commands/migration-plan.md` — produces `ai/migration/plan.md`. Phased plan grouped by domain + dependency. Foundation first (auth, tenant, infra). Each phase has measurable exit criteria. **Honors V2's NEW structure — never lift-and-shift.**
- `templates/packs/migration/commands/migration-phase.md` — executes phase N. Per feature: AUDIT → GAP-FIND → PORT (using V2 conventions) → VERIFY (parity test) → UPDATE ledger. Stops at phase boundary. `--feature=<id>` for retry; `--audit-only` for triage.
- `templates/packs/migration/commands/migration-gate.md` — phase exit gate. Confirms every phase-N feature is `done` + `parity_test=passing`. **Read-only; refuses on any blocking issue.** Append-only `_history.md` entry on PASS.
- `templates/packs/migration/commands/migration-final.md` — full sweep. Confirms every feature complete across all phases. Optional `--re-audit` to re-run parity tests catching drift since gate. Produces V1 retirement plan with cutover sequence + rollback procedure.

#### Design properties
- **Stack-agnostic** — works for frontend pages, API endpoints, scheduled jobs, queue consumers, CLI commands, anything that has identifiable behavior.
- **Trust nothing** — every status reset to `unverified` at scan; verified by parity test before flipping to `done`.
- **No silent ports** — `/migration-scan` and `/migration-plan` write zero code; only `/migration-phase` ports.
- **Idempotent** — every command writes through managed markers; re-running doesn't lose state.
- **Phased gating** — `/migration-gate` refuses pass on any blocking issue; next phase can't start until current is green.

#### Workflow
```
/migration-scan          # build fresh ledger, deep V1↔V2 comparison
/migration-plan          # phased plan covering everything
/migration-phase 1       # run phase 1: audit + port + verify
/migration-gate 1        # confirm phase 1 complete
/migration-phase 2       # next phase
/migration-gate 2
... (repeat per phase)
/migration-final         # full sweep + V1 retirement plan
```

#### Activation
After M10 syncs, run `/setup-project --include=migration` in any V2 repo to receive the 5 new commands. The merge matrix decides per command: ADD if no project equivalent exists, SKIP-with-redirect if a specialized version is already present.

#### Verified
- `lint-artifact.sh`: 0 errors / 20 warnings (5 new commands all parse clean).
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 30 ok / 0 drift.

## [2.6.0] — 2026-04-28

### M9 — Canonical reference doc

The flag table, mode descriptions, and migration walkthrough were comprehensive but buried inside `templates/quick-start.md` (an internal orchestrator import). M9 surfaces them as a real user-facing reference.

#### Added
- `docs/COMMANDS.md` — the canonical user manual. ~370 lines covering:
  - All 4 commands (`/setup-project`, `/setup-project-adapters`, `/setup-project-health`, `/learn-from-task`).
  - All `/setup-project` flags grouped by purpose (universal / mode-forcing / track-and-signal / tool-adapters / backup / REFINE-only / read-only / UX).
  - Flag combinations + conflicts (refusals, precedence, warnings).
  - All 4 modes (CREATE / ENHANCE / REFRESH / REFINE) with exit-criteria.
  - Generated-command catalog (`/add-endpoint`, `/add-module`, `/port-feature`, `/migration-status`, etc.) with `--plan` universal-flag note.
  - 6 worked workflows: first-setup-new, first-setup-existing, refresh, refine, V1→V2 migration (step-by-step with explicit hard rules), plan-only mode.
  - Top-10 hard rules summary (with link to full table).
  - "Where things live" map: command files, phase files, packs, domains, business-domains, tool-adapters, scripts, tests, archived monolith, sync state.

#### Changed
- `README.md` — top callout pointing to `docs/COMMANDS.md` for the full reference. README stays focused on the elevator pitch + sync workflow.

#### Verified
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 30 ok / 0 drift.

#### Why this milestone existed
A user asked: "is this mentioned in the README?" — and discovered I'd been documenting flags (`--v1-root`) that didn't exist while the genuine flag reference was buried in an internal file. M9 fixes the documentation gap so this doesn't happen again.

#### Honest correction also landed
- I claimed `--v1-root=<path>` was a flag. It is not. V1 root is detected by Phase 2 Step 16 OR resolved interactively. `docs/COMMANDS.md` documents the actual mechanism.

## [2.5.0] — 2026-04-28

### M8 — Pre-flight coverage + length budgets + reference freshness + spot-reads

After M7's mechanical dedup, M8 turns to per-file content quality. Five concrete, scoped passes; no auto-magic, all changes traceable.

#### Pre-flight discipline (Hard Rule A18) — fixed across 11 agents
M6 detected pre-flight via the literal keyword "pre-flight"; M8 fixes the agents that had the discipline but used different headings:
- 4 agents had a pre-flight section under another name → renamed: `security-auditor` ("Before auditing"), `design-system-guardian` (same), `ux-reviewer` ("Before reviewing"), `project-dispatcher` (split out from "Steps").
- 7 agents had **no pre-flight section at all** → added concrete pre-flight blocks: `endpoint-tester` (renamed Preparation), `websocket-engineer` (added), `business-auditor` (added), `code-reviewer` (renamed "Before you start"), `dead-code-finder` (added), `monorepo-architect` (added), `ci-reviewer` (added).
- Each added pre-flight names 3-5 specific files / configs / patterns the agent must read first — not generic "read the codebase."

#### Reference freshness — Next.js
- `templates/packs/frontend/references/nextjs.md` updated header from "App Router, 14+" to "App Router, 14 / 15" and added a version-note callout: Next 14 default `fetch` cache was `force-cache`; Next 15 default is `no-store`. ALWAYS set `cache:` and `next.revalidate` explicitly.
- All other references (django, fastapi, rails, nestjs, etc.) intentionally don't pin versions — pattern-level guidance that survives major bumps. Confirmed correct.

#### H1 normalization — 3 rule files
- `domains/background-jobs/rules/job-design.md`, `domains/event-sourced/rules/event-sourcing-discipline.md`, `domains/feature-flags/rules/flag-discipline.md` started with H2 / H3 instead of H1. Promoted to H1.

#### Length budget tuning
- `lint-artifact.sh`: skills budget 200 → 250, ai-patterns budget 200 → 250. Several technical-domain patterns (compliance, payment, websocket-fanout, search-indexing) are legitimately complex; the previous budget produced noise without signal. The 250 ceiling still flags genuine outliers (e.g., `learning/skills/apply-pack-adaptation.md` at 514 — Phase 4.6 anchoring contract; complex by necessity).
- Lint warnings: 48 → 20. Remaining warnings are all length-related on legitimately complex content; documented as signal, not bugs.

#### Spot-reads (4 high-impact files, all judged solid)
- `packs/backend/agents/api-architect.md` (102 lines): excellent. Concrete invariants, structured output template, framework references, "common rewrites to push back on", self-failure-modes.
- `packs/backend/commands/add-endpoint.md` (314 lines): follows the canonical 7-phase template (Hard Rule A24). Length appropriate for a complex generation command.
- `packs/security/rules/security-principles.md` (62 lines): excellent. Cites specific algorithms (argon2id), specific tools (gitleaks, semgrep), specific HTTP headers. Concrete, actionable.
- `packs/backend/ai-patterns/parallel-io.md` (172 lines): excellent. Project-specific block scaffold, decision matrix per language, opinionated guidance.

#### Verified
- `lint-artifact.sh`: 0 errors / 20 warnings (was 48). The 20 remaining are length-related on complex content.
- `smoke-test.sh`: 0 fail / 0 warn.
- `run.sh --apply` + `--idempotency-only`: 2 passed each.

#### Honest scope
M8 covered the highest-leverage content issues that automated tools could surface. **Most artifacts have not been deeply read.** The 4 spot-reads suggest content quality is good across the board, but that's a sample, not a survey. A semantic per-file audit of all ~150 artifacts under packs/ remains M9+ work — multi-day, not amenable to automation.

## [2.4.0] — 2026-04-28

### M7 — Content audit (cross-pack dedup + spot reads)

After M6 hardened *structure*, M7 verifies *content*. Bounded scope: cross-pack duplicate detection, sample-read of high-impact files, fix concrete issues.

#### Added
- `scripts/find-duplication.sh` — detects overlapping content across packs by H1 title, opening paragraph (100 chars), and verbatim MUST bullet repetition. Exposes redundancy candidates without auto-merging.

#### Findings (real, non-trivial)
- **`templates/packs/backend/ai-patterns/multi-tenancy.md` was a 100% byte-for-byte duplicate** of `templates/domains/multi-tenant/ai-patterns/multi-tenancy.md` (83 lines). Multi-tenancy is a technical signal, not a backend-pack concern — canonical home is `domains/`. **Removed the backend duplicate.**
- **H1 collision: "Code Quality Principles"** appeared in both `repo-baseline/.claude/rules/code-quality.md` (foundational A19 rule) and `packs/code-quality/rules/quality-principles.md` (concrete pack rules). Different content, same heading = confusion. **Renamed pack version's H1 to "Code Quality — concrete pack rules"** with explicit `extends: repo-baseline/.claude/rules/code-quality.md` in frontmatter and a quoted callout reading "Reads the baseline `code-quality.md` first."
- **MUST-bullet repetition 3+ times: zero.** No verbatim MUST/MUST-NOT statements duplicated across files — surprisingly clean.
- **Lead-paragraph duplicates: 5 groups** — but four of them are Phase 4.6 scaffold markers ("> Project-specific block — Phase 4.6 fills this in from..."). Expected. One genuine overlap (`learning/ai-patterns/setup-quality-scoring.md` ↔ `learning/skills/compute-anchor-density.md`) — cross-references are appropriate; not flagged for deletion.

#### Spot-reads (4 baseline rules + 4 ai/ knowledge templates)
- All 4 foundational rules (A19): well-written, opinionated, cross-referenced, concise. No content fixes needed.
- ai/ knowledge templates (architecture.md, conventions.md, modules.md, _session-digest.md): minimalist scaffolds with `<placeholder>` markers that Phase 4.6 fills at runtime. Shape is correct; content is template-stage by design.

#### Verified
- `find-duplication.sh`: 0 duplicate H1 groups (was 2).
- `lint-artifact.sh`: 0 errors / 48 warnings.
- `smoke-test.sh`: 0 fail / 0 warn.
- `run.sh --apply`: 2 passed (django + nextjs snapshot diff empty).

#### Honest scope statement
M7 verified content for the highest-impact subset: cross-pack dedup (mechanical) + 4 baseline rules + sampled ai/ templates. The remaining content audit (~150 individual artifacts under packs/) is M8+ work — semantic per-file review, not amenable to automation.

## [2.3.0] — 2026-04-28

### M6 — Artifact lint + spot audit

After M1–M5 hardened the meta-system (`/setup-project` and its harness), M6 turns attention to the artifacts the meta-system actually ships: 200+ agents / commands / skills / rules / patterns under `templates/packs/` and `templates/repo-baseline/`. Most pre-date the schema introduced in M2; this milestone fixes the structural gaps and surfaces the remaining content-quality flags.

#### Added (executable tools)
- `scripts/lint-artifact.sh` — structural lint for shipped artifacts. Checks frontmatter presence, required keys per kind (agent / command / skill / rule / pattern), length budgets (agents ≤ 300, commands ≤ 250, skills ≤ 200, rules ≤ 250, patterns ≤ 200), placeholder strings (outside code spans), top-level heading, and pre-flight block presence in agents (Hard Rule A18). Exits 0 healthy / 1 errors.
- `scripts/add-frontmatter.sh` — bulk migration tool. For any rule/pattern .md file lacking frontmatter, prepends a minimal block (`name`, `description` derived from H1 or first H2, `kind`, `pack` if applicable). Idempotent. Default dry-run; `--apply` to write.

#### Changed
- **The 4 foundational baseline rules now have frontmatter** (Hard Rule A19): `repo-baseline/.claude/rules/{read-before-write, read-codebase-deeply, code-quality, think-simplify-surgical}.md`. These ship in every project and previously had no metadata.
- **86 rule + pattern files received frontmatter** via `add-frontmatter.sh --apply`. Coverage now near-universal across `templates/packs/*/` and `templates/domains/*/`.
- `repo-baseline/.claude/agents/knowledge-curator.md` — renamed "Inputs you read" section to "Pre-flight (read before any write)" so the linter's pre-flight heuristic recognizes it.

#### Verified (with caveats below)
- `lint-artifact.sh`: **0 errors / 48 warnings.** Errors are now zero — every artifact has frontmatter and an H1.
- `smoke-test.sh`: 0 fail / 0 warn.
- `tests/setup-project/run.sh --apply`: 2 passed (django + nextjs); django snapshot re-recorded after pattern frontmatter changes — confirms the snapshot test correctly catches schema drift.
- `tests/setup-project/run.sh --idempotency-only`: 2 passed.

#### What the 48 warnings tell us (M7+ scope)
- **Length budget breaches** (~5 files): `learning/skills/apply-pack-adaptation.md` (514 lines vs 200), `compute-anchor-density.md` (246 vs 200), and similar. Some are genuinely complex extractors; some could likely be split. Worth a content audit, not blocking.
- **4 agents missing the literal "pre-flight" keyword**: `security-auditor`, `design-system-guardian`, `ux-reviewer`, `project-dispatcher`. Each has the discipline (sections describing what to read first) but doesn't use the keyword. Heuristic linter false-ish-positives — fix is renaming a section in each, ~5 minutes per agent.
- **3 ai-patterns slightly over budget** (`test-strategy.md` at 207, `theming.md` at 212): borderline; not worth chopping.

#### Honest scope statement
M6 is the first milestone where the **artifacts** (not just the system that ships them) are validated against a contract. Structural lint is now a CI-able gate. Content lint (e.g., "does this rule cite project specifics or generic prose?") remains M7+ — that requires reading semantics, not just structure.

#### Side effects
- The django snapshot was re-recorded once during M6 because two pattern source files (`patterns/{models,views}.md`) gained frontmatter. The test suite caught this drift on the first `--apply` run — exactly the behavior a snapshot suite should produce. Re-recorded with explicit confirm; idempotency holds in run-2.

## [2.2.0] — 2026-04-28

### M5 — Close the verification gap

**The forcing-function milestone.** Until M5, every refactor was unverified. M5 ships the deterministic harness that proves the system actually works end-to-end (for the deterministic phases — LLM-driven phases still need a CLI strategy in M6+).

#### Added (executable)
- `scripts/apply-pack.sh` — deterministic Phase 4 subset: 4.0 preflight + 4.2.b copy + managed-marker wrapping. Pure shell, no model. Same input → same output. Idempotent. Records gaps for missing source files; records unsupported merge modes (managed-section is M6+).
- `tests/setup-project/run.sh` — drives `apply-pack.sh` against fixtures. Modes: `--shape-only`, `--apply` (diff vs snapshot), `--update-snapshots` (record), `--idempotency-only` (run twice, assert empty diff).

#### Added (artifacts)
- `templates/tracks/web-frontend-nextjs/` — second concrete track plugin (npm-ecosystem detection, App Router + Pages Router awareness, conditional emits gated by detected flags + deps). Validates that the schema generalizes beyond django.
- `templates/tracks/web-backend-django/{rules-template.md, claude-md-section.md, patterns/views.md, patterns/models.md}` — pack source files referenced by the track's `pack.md` emits contract. The django track now ships 4 unconditional emits + 5 conditional gaps + 1 unsupported merge mode (CLAUDE.md managed-section).
- `tests/setup-project/snapshots/django/` — first real snapshot. 6 files: rules, conventions, patterns × 2, apply-pack report, original fixture files (preserved).
- `tests/setup-project/snapshots/nextjs/` — second real snapshot. 4 files: rules, conventions, apply-pack report, original fixture file.

#### Verified (now actually testable claims)
- **Idempotency contract round-trips for both tracks.** `run.sh --idempotency-only` runs apply-pack twice and asserts the trees are byte-identical (with `applied-at:` masked). 2 passed / 0 failed.
- **Snapshot diff is empty.** `run.sh --apply` re-runs the harness and diffs against the recorded snapshot. 2 passed / 0 failed.
- **Schema generalizes.** Both tracks pass `lint-track.sh` with zero schema changes. Adding the second track required no edits to `templates/tracks/_loader.md`.
- **Smoke test still clean.** 0 fail / 0 warn across 7 structural checks.

#### Still NOT verified (M6+ scope)
- LLM-driven phases (Phase 1 mode detection, Phase 2 deep extraction, Phase 4.6 anchoring) — these need real CLI invocation against a fixture, which is the open automation problem documented in `tests/setup-project/run.sh` header.
- Multi-track fixtures (monorepo) — apply-pack runs one track at a time today; multi-track conflict resolution is M6+.
- Bootstrap mode (empty fixture) — needs LLM-driven authoring.
- managed-section merge mode — apply-pack records as unsupported; M6+ implementation.
- Conditional emits — apply-pack treats `emits-conditional` as "always include" today; M6+ should evaluate against the target's deps.

#### Honest scope statement
M5 verifies the deterministic floor of the system. The deterministic floor is approximately 60% of what `/setup-project` does in production: pack preflight, deterministic copy, marker discipline, idempotency. The remaining 40% (LLM-driven authoring, deep extraction, project anchoring) is the M6+ horizon — well-defined, but requires an automation strategy beyond shell.

## [2.1.0] — 2026-04-28

### M4 — Verification + tooling

#### Added (executable tools)
- `tests/setup-project/run.sh` — snapshot test runner (shape-only mode today; full-runner mode documented but stubbed pending automation strategy).
- `scripts/lint-track.sh` — validates `templates/tracks/<name>/` against the schema (required files, frontmatter keys, signal kinds, weights, merge modes).
- `scripts/migrate-setup.sh` — applies a named migration to a target repo. Implements the `v1-to-v2` migration spec; dry-run by default.
- `scripts/smoke-test.sh` — structural integrity check: command parsing, import resolution, track lint, phase frontmatter, HOT-tier budget, sync state, fixture shape. Exits 0 healthy / 1 broken.

#### Added (artifacts)
- `templates/migrations/v1-to-v2.md` — migration spec for the M2 split (markers, version stamps, derived files, adapter re-sync). Idempotent.
- `templates/import-tiers.md` — HOT / WARM / COLD definitions with line budgets. HOT ≤ 600 lines combined. Tier-budget audit lives in `/setup-project-health` (C7).
- `templates/tracks/web-backend-django/` — first concrete track plugin under the M2 schema. Has `detect.md` (signals + threshold + exclusive-with), `pack.md` (emits contract), `conventions.md` (Django MUST / MUST-NOT rules), `meta.yaml`. Validates the schema end-to-end.

#### Changed
- `commands/setup-project.md` `imports:` reorganized into HOT / WARM / COLD groups. Loaders are expected to honor tier when pulling content.
- `templates/governance/hard-rules.md` — added "Top 10" surface at the top, ranking the highest-impact rules so readers see the floor before the full table.
- `templates/phases/phase-5-verify.md` (was 577 lines) split into:
  - `phase-5-verify.md` (397 lines, orchestrator)
  - `phase-5.0-retry.md` (coverage check + retry loop)
  - `phase-5.1-baseline.md` (required-baseline + inventory diff)
  - `phase-5.5-quality.md` (REFINE-only setup-quality score)

#### Verified
- `scripts/smoke-test.sh` — all 7 checks pass: 0 fail, 0 warn.
- `scripts/lint-track.sh` — `web-backend-django` track validates clean.
- `scripts/sync-to-global.sh` — 30 symlinks ok, 0 drift.

#### Still deferred to M5+
- Real `/setup-project` invocation against fixtures (the runner has the harness; the missing piece is non-interactive CLI invocation strategy — Claude Code commands are model-executed prompts, not shell commands). Two paths documented in `tests/setup-project/run.sh` header.
- Snapshots — empty until a real runner records them.
- Additional tracks — `web-frontend-nextjs`, `mobile-react-native`, `data-pipeline-airflow`, etc.
- Migration runner Step 2 (auto-wrapping existing managed regions) is currently advisory; a non-interactive runner is too risky for that step. User runs it manually and re-runs migrate-setup.sh.

## [2.0.0] — 2026-04-28

### M3 — Polish (this release)

#### Added
- `commands/setup-project-health.md` — read-only health reporter (digest age, ADRs, drift, budgets, dead files, adapter parity, idempotency markers, version drift). Exits 0/1.
- `commands/learn-from-task.md` — Phase 6 manual entry point; respects the persistence pyramid (raw → conventions → ADRs).
- `templates/repo-baseline/.claude/agents/knowledge-curator.md` — recurring counterpart; budget-enforcing; never edits ADRs; "no-op" is a valid run.
- `templates/persona.md` — full prose preserved; orchestrator now references via 5-bullet summary.
- `templates/phases/phase-5-checklist.md` — Phase 5 audit as a checklist (8 sections, must/should rows, halt+retry policy).
- `CHANGELOG.md` (this file).

#### Changed
- `templates/governance/hard-rules.md` reformatted from prose to ID-keyed tables (A01–A36 Always, N01–N20 Never) with severity column. Full prose preserved as reference below the table; Phase 5 references rules by ID.
- `commands/setup-project.md` persona block compressed to 5 bullets + reference to `@templates/persona.md`.
- `README.md` workflow section + milestone status updated for M3.

#### Known follow-ups (deferred)
- Phase 4 file remains at ~1500 lines — sub-phase split (4.0 / 4.2 / 4.6-DEEP / 4.7-DEEP / 4.8-DEEP) is open.
- `templates/capabilities.md` (~830 lines) not yet split per-capability.
- `scripts/lint-track.sh` (track schema validator) not yet implemented.
- `/setup-project --upgrade` migration runner not yet implemented (versioning scaffold + `templates/migrations/` exist; runner is M4).
- Snapshot test runner (`tests/setup-project/run.sh`) not yet implemented; fixtures exist.

### M2 — Split monolith into orchestrator + phase plugins (commit 1bc91cd)

#### Added
- `templates/phases/phase-{0..6}-*.md` — one file per execution phase, each with a frontmatter contract (inputs, outputs, exit criteria, applies-to-modes).
- `templates/critical-execution-rules.md` — the 7 hard guardrails extracted from the monolith head.
- `templates/quick-start.md` — flags, end states, cheat sheet.
- `templates/knowledge-hub.md` — tracks/domains/agents/skills inventory.
- `templates/decision-engine.md` — 4-input reasoning + tie-breaks + self-audit.
- `templates/idempotency.md` — re-run safety contract + managed-marker convention.
- `templates/tracks/_loader.md` — track plugin schema (detect.md weighted signals + pack.md emits contract + meta.yaml).
- `templates/governance/hard-rules.md` (initial extraction; reformatted in M3).
- `templates/canonical-command-template.md` — META: shape of generated commands.
- `templates/capabilities.md` — 7 cross-cutting features (versioning, health, schema, failures, fixtures, multi-language, wizard).
- `templates/appendices.md` — A–F (detection, filter, merge, profile, learnings, glossary).
- `commands/setup-project-adapters.md` — sibling command holding adapter detail.

#### Changed
- `commands/setup-project.md` reduced from 5,153 lines → 236 lines. Behavior preserved via @-imports.

### M1 — Foundation (commit a712053)

#### Added
- `scripts/sync-to-global.sh` — symlink-based sync from this repo to `~/.claude`.
- `scripts/verify-sync.sh` — drift detection.
- `tests/setup-project/` — fixture stubs (empty / django / nextjs / monorepo) + snapshots placeholder.
- `README.md` — workflow doc (edit-here-then-sync) + milestone status.

#### Changed
- `~/.claude/commands/` and `~/.claude/templates/` are now managed symlinks back to this repo. Backup tarball at `~/.claude-backup-20260428-125420.tar.gz`.

## [1.0.0] — pre-2026-04-28

The 5,153-line monolith era. Original archived at `.archive/setup-project.M1.monolith.md`.
