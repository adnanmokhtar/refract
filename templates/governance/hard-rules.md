---
artifact: hard-rules
purpose: Always / Never governance overlay. A `must`/`must-not` violation in Phase 5 audit = command refuses to report success.
imported-by: commands/setup-project.md (orchestrator) and Phase 5.
note: M3 will reformat as a Rule | Why | Applies-To-Phases | Severity table. Content is preserved verbatim from the M1 monolith.
---

## Hard rules

### Always
- Plan BEFORE write. Show plan; wait for "proceed" unless `--force-*`.
- Real content. No placeholders in generated files.
- Phase 1 bias in knowledge-base generation (don't over-design for later phases).
- Respect existing work — never overwrite user-authored content without explicit confirmation.
- Save reusable outputs back to packs (framework refs + generate-on-signal agents).
- Hook-aware `ai/status.md` — always has `Updated:` + `## Recent Changes`.
- Opinionated — make decisions, record as ADRs. Don't hedge.
- Token-aware — delegate heavy scans to Explore subagent; terse output.
- Always write `AGENTS.md` + `ai/references/models.md` (canonical: see § "3.2 Tool-adapter selection" Tool-adapters table + Phase 4.8 ordering).
- Respect each tool adapter's idempotency markers — user edits below the marker must persist across re-runs.
- **Copy packs verbatim when applying** *(COPY-mode tracks)* — see Phase 4.2.b (deterministic `cp`, never LLM-driven). Reference-path injection adapts; never trims. Output shorter than source = regression bug.
- **Author from extracted idioms** *(AUTHOR-mode tracks)* — see Phase 2.5 + Phase 4.2-AUTHOR + Decision Engine rule 7. When extraction signal exists, generate output from `.claude/_extracted-idioms.md` + topic spec, NOT from pack template body. Every cited method/path/line must trace to a file the extractor read; no invention.
- **Run Phase 2.5 in every ENHANCE/REFRESH** when ≥1 base class has ≥3 extenders. Skipping it forces every track into COPY mode and reverts to generic output. The extracted-idioms file is what makes the difference between "templated setup" and "project-aligned setup."
- **Signal-density over line count when authoring packs** — every line teaches something unique (rule, step, example, failure mode). A 60-line dense file beats a 200-line padded one. Density (pack-authoring) and verbatim copy (pack-applying) are complementary, not contradictory.
<!-- Workspace cascade canonical home: Decision engine § rule 6. Implementation: Phase 4.1. Tool-adapter scope: Phase 4.8. -->
<!-- AGENTS.md always-written canonical home: § "3.2 Tool-adapter selection" Tool-adapters table. Implementation: Phase 4.8 ordering (codex adapter is the canonical writer). -->
<!-- Pre-flight injection canonical home: Phase 4.6. -->
<!-- Tool-adapter selection canonical home: Phase 3.2. -->

- **Adapt to detected conventions, don't override them.** Generated rules + agents + patterns MUST cite the project's actual conventions (file-naming style, base classes by path if any, suffix matrix, test colocation, etc.) at the TOP, with generic prose underneath. A `database.md` that says only "use parameterized queries" without naming the project's actual data-access lib + repository helper from `.claude/_extracted-codebase.md` is broken — the LLM won't follow project style in subsequent tasks. The cited specifics come ENTIRELY from this codebase's extraction; never from another project's run.
- **If you don't know where new code belongs, don't write it.** Map every new file / module / feature to a defined home in `ai/modules.md` BEFORE writing. No module fits → plan a new module first (and record it as an ADR if architectural), or stop and ask. Files dropped into the repo root, a catch-all `utils/` / `shared/` / `common/` folder, or a vague "misc" location accumulate as architectural debt that no later refactor pays back. The discipline is: "where does this live?" answered, then code.
- **Boy Scout Rule on every touched file.** Code you change leaves cleaner than you found it: dead imports removed, commented-out blocks deleted, vague names sharpened, redundant comments cut, single obvious cleanup applied. Bound the scope to what's adjacent to your change (don't balloon the diff into a whole-file rewrite). The Phase 6 learning loop captures these as patterns when they recur; the Hard Rule keeps them from being silently skipped under "I'll do it in the cleanup PR" (which never lands).
- **Inject mandatory pre-flight in every agent.** Every copied/generated agent gets the auto-injected pre-flight ("read codebase-profile + conventions + business-domain + project-goals + mirror existing module + identify I/O & deps before modifying"). Without this, agents fall back to generic patterns in the next task.
- **Foundational ruleset is the four `repo-baseline` rules — period.** Every project ships `.claude/rules/read-before-write.md` + `.claude/rules/read-codebase-deeply.md` + `.claude/rules/code-quality.md` + `.claude/rules/think-simplify-surgical.md`. The first three answer *what to read* + *what "clean" means*; the fourth (Karpathy-inspired task-discipline layer) answers *how to act on what you read* — explicit assumptions, simplicity-first, surgical scope, verifiable success criteria. Skipping any one re-introduces a known LLM failure mode. Phase 4.0.6 enforces their presence; Phase 5.1 retries-then-halts if any are missing.
- **Parallel I/O is load-bearing for any backend on a non-blocking-I/O runtime.** When the backend track is selected AND the runtime supports async (Node.js, Python-async, Go, Java 21+, .NET, Kotlin, Rust-tokio, Elixir), Phase 4.0 ships `.claude/rules/concurrency-discipline.md` + `ai/patterns/parallel-io.md` + `.claude/skills/parallelize-independent-ops.md` and Phase 4.6 anchors them to the project's actual primitive (Phase 2 Step 15 detection: native `Promise.all` / `Bluebird.map` / `p-limit` / `asyncio.gather` / `asyncio.Semaphore` / `errgroup` / `CompletableFuture` / `StructuredTaskScope` / `Parallel.ForEachAsync`). Without this, generated agents reproduce the most common LLM-authored backend perf failure: sequential `await` of independent I/O — turning 100ms × 8 batches into 800ms wall-clock when it could be 100ms. Synchronous-only stacks (Ruby without Async, sync-only Python, single-threaded scripts) are exempt — Phase 2 Step 15 detection skips, and these three artifacts are not enforced.
- **Run setup-project's own independent sub-steps in parallel where dependency allows.** Concrete opportunities: (a) Phase 2.5 base-class idiom extraction is already parallel — up to 6 concurrent Explore subagents (one per base class). (b) Phase 4.2 per-track copies are independent across tracks — fan out one subagent per LOAD-BEARING track, cap = total tracks. (c) Phase 4.4 technical-signal overlays are independent across signals. (d) Phase 4.4b business-domain content authoring is per-domain, parallel-safe. (e) Phase 4.8 tool-adapter generation is independent across adapters — fan out one subagent per selected adapter, cap = #adapters (typically 1–4). What MUST stay sequential: Phase 0 backup → extract → re-detect (each step depends on the prior); Phase 4.1 baseline scaffold (must complete before any pack copy reads from disk); Phase 5.1 → 5.2 → … audit ordering (each gates the next). When in doubt, treat phase boundaries as sequential and intra-phase fan-out as parallel.
- **REFINE is the round-two deepening pass — not a substitute for CREATE / ENHANCE / REFRESH.** Round one (CREATE / ENHANCE) gets the floor right: every load-bearing track has its minimum artifacts present, anchored to the project's surface signals. Round two (`--refine`) goes deeper: re-reads the actual code (Phases 2.7–2.12 — domain entities by inspection of model classes / migrations / Pydantic / Zod schemas; architecture by tracing import graphs and request lifecycles; flows by following endpoints from controller to repository to DB; convention emergence by detecting recurring patterns the first pass missed; perf hot paths by reading hot endpoints + N+1 patterns + index coverage; failure history from git log / bug tracker / incident postmortems if accessible) and rewrites ONLY the `## Project-specific` blocks of artifacts whose anchor-density is below threshold. User-authored sections are preserved verbatim — REFINE only deepens what the command itself wrote. Round-two outputs include `.claude/_setup-quality.md` (per-artifact density score: name-density, path-density, signal-density, total) + `.claude/_refine-extract.md` (deep-extraction findings) + per-artifact diff appended to `.claude/_refine-log.md`. Idempotent: when no shallow artifacts remain (every artifact ≥ 70/100 OR no new deep-extraction signal surfaces), REFINE reports "plateau reached" and exits without writes. Without REFINE, first-pass setups stay generic — referencing "your service layer" instead of `app/services/billing.py:Billing` — and Claude inherits that genericness in every downstream task. The `--refine` flag is opt-in (never auto-applied) because the user decides when round-one settling is "done enough" to deepen.
- **V1→V2 migration is a first-class workflow** when Phase 2 Step 16 detects `migration_layout_detected` OR the user opts in via `--include=migration`. The `migration` pack ships: rule `migration-discipline.md` (parity is non-negotiable; perf uplift only when parity-preserving; every intentional behaviour break documented), patterns `feature-port.md` + `parity-testing.md` + `migration-ledger.md`, skills `extract-v1-contract.md` + `parity-test-generate.md` + `perf-uplift-survey.md`, agents `migration-architect.md` + `parity-auditor.md`, commands `/port-feature` + `/migration-status`. Phase 4.0 ledger bootstrapping populates `ai/migration/ledger.md` from the V1 feature inventory (per Phase 2 Step 16 detection) so per-feature ports have a starting state. Phase 4.6 anchors `migration-discipline.md` + `feature-port.md` + `parity-testing.md` + `migration-ledger.md` to the project's actual V1 root + V2 root + cutover mechanism + ledger path. Without this, generated agents reproduce the two most common migration failures: silent behavioural drift (V2 *almost* matches V1, ships, customer issues surface for months) AND scope creep (port + redesign + perf + new feature in one PR — none reviewable). Migration-time perf uplift (caching strategies, DB indexes, query optimisation, column projection) is captured per-feature in `ai/migration/perf-decisions/<feature>.md` with applied / deferred / rejected decisions + measurements. Greenfield projects without V1+V2 evidence skip the pack unless the user opts in.
- **Every command follows the 7-phase canonical structure** (Understand → Organize → Retrieve → Generate → Update → Validate → Improve). See "Canonical command structure" section above. Deviations must be documented; silent omissions are not allowed.
- **REFRESH always backs up first, extracts second, regenerates third.** Phase 0 is non-negotiable in REFRESH mode (Critical Execution Rule 6). The order is fixed: backup → extract → re-detect → merge → regen → audit-against-extract → cleanup. Skipping or reordering any step is the failure mode this mode exists to prevent.
- **REFRESH preserves ADRs, validated corrections, and project intent verbatim.** ADRs are append-only history; validated corrections are user-given truth; project intent answers are facts the codebase doesn't encode. Generic packs and conventions get regenerated; these three categories get preserved.
- **Every pack source has `_version.json` + `CHANGELOG.md` (B2).** Phase 4.0 pack-load preflight refuses to apply a pack without them. Breaking changes (major bump) MUST ship with a migration script in `migrations/`.
- **Version stamps record per-run.** `.claude/codebase-profile.md` § "Setup version" MUST contain `setup_command` + per-pack + per-domain + per-adapter versions. Without this, drift detection at session-start can't function.
- **Failure catalog loaded in pre-flight for architectural agents (B10).** Every architecture-decision-class agent (nestjs-architect / backend-architect / db-architect / etc.) injects `@file ai/failures/_index.md` in pre-flight. Without it, agents propose ideas that already failed.
- **Failures are append-only** (B10). `status: superseded_by_<adr>` when conditions change; `validated_failure` becomes archive, never deleted.
- **Schema validation runs in Phase 5.4 every mode (B4).** Every generated JSON config + frontmatter validated against `~/.claude/templates/schemas/`. Missing schema = broken adapter = halt.
- **Health score appears in `_session-digest.md` (B3).** Tier 1 visibility — silent decay isn't allowed.
- **Telemetry is local-only** (B3). NEVER make a network call from telemetry. NEVER include user/PII in telemetry entries. `.claude/_telemetry.jsonl` MUST be `.gitignore`d.
- **Factories scaffold per detected business-domain** (B17). When `business_domain = ecommerce` is detected, `test/factories/<entity>.factory.ts` is generated for every entity in code (matching detected test framework + ORM). Skipping factory generation when factories.md exists is a regression.
- **Multi-language preamble in human-facing docs only** (B14). `--lang=ar` adds bilingual preamble to CLAUDE.md / AGENTS.md / `ai/README.md`. Generated code comments + variable names stay English.
- **Wizard preview shows real content, not placeholders** (B22). A wizard that previews `<TODO>` is broken. Mock outputs MUST be the actual what-will-be-written content.

### Never
- Overwrite `.env*` or lock files.
- Delete user-authored docs / agents / rules.
- Generate tooling for signals not present (no payment files without Stripe/etc.).
- Invent architecture conflicting with existing code.
- Downgrade an existing setup — enhance means ADD, never SUBTRACT.
- Bypass safety hooks (`--no-verify`, `rm -rf`).
- Force-push, reset-hard, or destructive git.
- Write tool configs the project isn't using (don't scatter `.cursor/`, `.clinerules/`, etc. unless selected by `--tools` or detected).
- Duplicate rule content across every tool config — each adapter either references canonical `.claude/rules/*.md` or embeds a compact summary. Never fan-out full verbatim copies.
- **Thin-generate content when a pack source exists.** Copy the pack source. If output is shallower than source, it's a regression.
- **Pad pack templates to hit line targets.** Depth means unique signal per line, not word count. If you add content, it must be a new rule / new step / new example / new failure mode — never a restatement of content already present.
- **Restate frontmatter `description` in the body.** The reader already saw it.
- **Create redundant sections** ("Invariants" + "Rules" + "What not to do" + "Anti-patterns" + "Failure modes" — pick ONE hat per concern).
- **Write "References" that duplicate "Pre-flight reading"** — one list is enough.
- **Ship generic conventions in `ai/conventions.md`** when a real codebase exists. The file MUST be auto-populated from the codebase profile. Generic content here = Claude will write code that doesn't match project style in subsequent tasks.
- **Skip the project-specific block** at the top of generated rules. Without it, the rule is a generic copy that Claude applies blindly.
- **REFRESH without backup** unless `--no-backup` is passed AND user confirmed in plan. Default backup is the rollback safety net; bypassing silently is a destructive-action escalation.
- **REFRESH without reading existing setup files first** — even if the user is in a hurry. Phase 0.2 extract is what makes REFRESH non-destructive to accumulated knowledge. Without it, REFRESH = nuke + regen-from-scratch, which is what `--force-replace-all` already does — REFRESH must be MORE careful, not less.
- **REFRESH that drops ADRs.** ADRs are append-only history. If an ADR existed in the backup and is missing in the regen output, the audit MUST halt. Period.
- **REFRESH that delete the backup directory.** Even after a successful regen, the backup stays. The user decides when (if ever) to remove `.claude/backups/`. Auto-cleanup is a footgun.

### When to ask (ONE consolidated question)
- Ambiguous shape (single / mono / workspace).
- Ambiguous domain (prompt says "AI" without naming provider).
- Enhancement conflict (existing CLAUDE.md contradicts new prompt).
- Ambiguous tool adapter set (existing repo has `.cursor/` + `.claude/` + `AGENTS.md` — confirm all three should be kept + refreshed).

Otherwise proceed with opinionated defaults; record in ADR.

---

