# claude-config

Portable, intelligent Claude Code configuration. One `git clone` on any device = full toolbox.

> **📖 Looking for the full reference?**
> - **[docs/COMMANDS.md](docs/COMMANDS.md)** — every command, every flag, mode behaviors, flag conflicts, V1→V2 migration walkthrough, where things live.
> - **[docs/REFERENCE.md](docs/REFERENCE.md)** — when something refuses or surprises: `<TBD>` lifecycle, Phase 5 audit failure modes, the four discipline patterns (premise / closure-verb / mechanical halt / lightweight default), migration end-to-end with halts, memory system, validator scripts, common pitfalls.
> - **[docs/FEATURE-LIFECYCLE.md](docs/FEATURE-LIFECYCLE.md)** — the feature-lifecycle playbook: new project + new feature, mapped to commands.
> - **[docs/AIDER-LOCAL-MODEL.md](docs/AIDER-LOCAL-MODEL.md)** — run the setup on a free local GGUF model via Aider (llama.cpp): install → download → server → wire setup → run.
>
> This README is the elevator pitch; `COMMANDS.md` is the manual; `REFERENCE.md` is what you read when something fails.

## Workflow: edit here → sync to `~/.claude`

This repo is the **single source of truth**. Never edit `~/.claude/commands/` or `~/.claude/templates/` directly — those paths are managed symlinks back into this repo.

One-time setup (or after pulling a major refactor):

```bash
./scripts/sync-to-global.sh            # dry run — shows planned actions
./scripts/sync-to-global.sh --apply    # create symlinks
./scripts/sync-to-global.sh --apply --force   # replace stale real files
./scripts/verify-sync.sh               # fail loud on drift
```

Day-to-day: just edit files in this repo. Symlinks mean changes apply immediately to Claude Code with no re-sync.

`~/.claude/settings.json` and `~/.claude/settings.local.json` are NOT touched by sync — they stay user-managed.

> **Refactor history**: M1 → M3 (2026-04-28) split the 5,153-line `commands/setup-project.md` into an orchestrator + pluggable phases/tracks/adapters/capabilities. M14 → M21 (later 2026-04-28 → 2026-05-03) shipped the simple-surface entry points (`/migrate`, `/align`, `/optimize`, `/polish`, `/do`, `/scaffold-project`, `/refine-prompt`) + per-pack validators. Full timeline: `CHANGELOG.md`. Pre-M1 monolith preserved at `.archive/setup-project.M1.monolith.md`.

---

## Commands

| Command                        | Purpose                                                                           |
|--------------------------------|-----------------------------------------------------------------------------------|
| `/setup-project`               | The brain — scaffold or enhance any project, any stack.                           |
| `/setup-project-adapters`      | Re-sync tool adapters (Cursor, OpenCode, Aider, Cline, …).                        |
| `/setup-project-health`        | Read-only health report (drift, staleness, budgets, parity).                      |
| `/scaffold-project`            | Generate a working project from scratch (prompt → stack → boot).                  |
| `/refine-prompt`               | Turn any rough idea into a deep, execution-ready prompt for the right command (output-only; feeds `/scaffold-project`, `/add-feature`, `/audit`, …). |
| `/roadmap [<scope>]`           | Phased completion plan for an unfinished project — maps every missing / stubbed / half-wired feature (six detectors), sized + dependency-phased. Read-only by default; `--build [<N>]` builds ONE phase per run and halts at a gate. Single-codebase analog of `/migration-scan` + `/migration-plan`. |
| `/align [<scope>]`             | One-command convention drift sweep.                                               |
| `/optimize [<scope>]`          | One-command architectural diagnosis + tactical sweep.                             |
| `/refactor [<scope>]`          | Targeted behaviour-preserving refactor (closed vocabulary); ledger `ai/refactor/`. |
| `/polish [<scope>]`            | One-command UI/UX + API + schema + platform polish.                               |
| `/audit [<scope>]`             | One-command full-stack engineering audit — architecture / SOLID / clean code / security / DB perf / runtime perf / scale + resilience / infra / observability. Cross-axis ranked plan + parallel fixes. **Universal across stacks** — any language, any framework, any project shape (backend / frontend / mobile / data / CLI / library / serverless / monorepo / polyglot). 13 scale-lens detectors stack-routed via `PROJECT_KIND`. Scale-first targets: `--target-rps`, `--target-vitals`, `--target-cold-start`, `--target-startup`, `--target-bundle`. |
| `/unify-surfaces [<scope>]`    | One-command surface-type unification (frontend-*). Tables / forms / headers / tabs / filters / buttons / validation. For each: inventories every consumer, decides canonical wrapper, extracts or extends, migrates every consumer in **one cascade-rewrite commit per category**. **Validation extracts a 3-part pipeline** — composable + `<ErrorList>` + API-error mapper. Reuse-Before-Create enforced; idioms updated in same commit. Sibling to `/polish` (axis-typed); this is surface-type-typed. Frontend stacks only. |
| `/do <description>`            | Universal meta-router → dispatches to the right specialized command.              |
| `/task <ref>`                  | Pull ONE task from Trello / Jira / Linear / GitHub (URL, key, or `next`) → fetch title + description + attachments → execute via `/do` → write status back. Per-repo provider via `.env`. See [`docs/TASK-PROVIDERS.md`](docs/TASK-PROVIDERS.md). |

The seven simple-surface commands (`/roadmap /align /optimize /refactor /polish /audit /unify-surfaces`) are the recommended daily user surface. Each takes optional `<scope>` (whole project if omitted, or natural-language description / explicit path), runs deep multi-agent in parallel, and produces brief output. Pack-level commands (`/migrate`, `/migration-fast`, `/align-fast`, `find-and-fix`, etc.) live in `templates/packs/<pack>/commands/` and install per-project via /setup-project. See `docs/COMMANDS.md` for every flag.

## `/setup-project` — the brain

Works on **empty projects** AND **existing projects**. One command for everything.

- Empty folder + prompt → full scaffold (architecture + DB schema + phase plan + all tooling).
- Existing codebase → scans it, identifies gaps, proposes enhancements, applies them without overwriting your custom work.
- Fullstack workspace? Monorepo? Single repo? It detects the shape.
- Any stack (NestJS / Django / FastAPI / Laravel / Rails / Go / Elixir / Rust / PHP / .NET / Angular / React / Vue / Nuxt / Next / Svelte / etc.) — role-based packs adapt to whatever's there.

Vibe-coding discipline: **plan first, write once, no placeholders, no filler**. The command produces a plan, shows it, then executes after your approval.

---

## Structure

```
claude-config/
├── commands/                # 14 top-level commands (table above)
├── templates/
│   ├── repo-baseline/       # universal — copied into every new repo
│   ├── workspace-baseline/  # for multi-repo workspaces (dispatcher, cross-repo cmds)
│   ├── packs/               # 19 ROLE-based tracks — full inventory in templates/knowledge-hub.md
│   ├── tracks/              # stack-specific scaffolders (web-backend-django, web-frontend-nextjs)
│   ├── tool-adapters/       # per-tool translations (Cursor, OpenCode, Aider, Cline, …)
│   ├── phases/              # /setup-project's phase files (0, 1, 2, 3, 4, 4.0, 4.2, 4.6, 4.7, 4.8, 5, 5.0, 5.1, 5.5, 6)
│   ├── domains/             # business-domain knowledge (saas, ecommerce, healthcare, …)
│   └── regulatory-overlays/ # compliance overlays (GDPR, PCI-DSS, SOC2, …)
├── docs/                    # COMMANDS.md (manual) + REFERENCE.md (failure modes)
├── scripts/                 # validators, sync, verify, audit
├── settings.json            # your global Claude settings
└── README.md                # you are here
```

The 20 packs: ai-engineering, algorithms, align, backend, business, code-quality, database, devops, distributed-systems, documentation, frontend, infrastructure, learning, migration, mobile, observability, performance, security, testing, ui-ux. Each pack ships agents/, skills/, commands/, rules/, ai-patterns/, _essentials.md, _topics.md, _version.json.

### Why role-based packs, not frameworks

Work is organized by **role** — **20 tracks** under `templates/packs/`: ai-engineering, algorithms, align, backend, business, code-quality, database, devops, distributed-systems, documentation, frontend, infrastructure, learning, migration, mobile, observability, performance, security, testing, ui-ux. Framework specifics (NestJS vs Django vs Laravel) live as `references/<framework>.md` inside each track.

So one `api-architect` agent works for every backend. One `schema-architect` works for Postgres, MySQL, Mongo. Add a new framework → drop a reference file → same agents adapt.

---

## Install

This repo is the **single source of truth**. `~/.claude/` is a symlink farm pointing back to it. Don't clone the repo AT `~/.claude/` — clone it elsewhere and let `sync-to-global.sh` create the symlinks.

```bash
# 1. Clone the repo somewhere stable (NOT at ~/.claude/)
git clone git@github.com:YOUR_USERNAME/claude-config.git \
  ~/Workspace/Projects/claude-config

# 2. Create the symlinks into ~/.claude/
cd ~/Workspace/Projects/claude-config
./scripts/sync-to-global.sh            # dry run first — review planned actions
./scripts/sync-to-global.sh --apply    # actually symlink

# 3. Restore your personal settings (NOT auto-synced)
#    ~/.claude/settings.json + settings.local.json stay user-managed.
#    Copy from backup or recreate.

# 4. Verify the symlink farm is intact
./scripts/verify-sync.sh
```

**Already have a `~/.claude/` from a previous setup?** Back it up first, then run the steps above:

```bash
mv ~/.claude ~/.claude.backup
mkdir ~/.claude
# then run steps 2-4 above; restore settings.json from .backup/
```

**Day-to-day:** edit files in this repo. The symlinks mean changes apply immediately to Claude Code with no re-sync. The only manual sync left is per-target-project (`<project>/.claude/` is a copy, not a symlink — re-run `/setup-project --refresh` in the target to pull pack updates).

Verify the install: open Claude anywhere, type `/set` — `setup-project` should appear in the slash-command picker.

---

## Using `/setup-project`

### New project (empty folder)

```bash
mkdir ~/my-new-saas && cd ~/my-new-saas
claude
```

```
/setup-project "Multi-tenant SaaS: NestJS API + Angular admin + Nuxt storefront. AI via Claude. WhatsApp integration. Multi-tenant. Phase 1 MVP."
```

What you get:
1. A **plan** showing mode, shape, tracks to apply, domain tooling, files to create — you approve or adjust.
2. Workspace parent with dispatcher + `PROJECTS.md` + cross-repo `ai/architecture.md`.
3. `api/` with `code-quality + documentation + backend(nestjs) + database(postgres) + security + testing + business + performance + devops` tracks applied.
4. `admin/` with `code-quality + documentation + frontend(angular) + ui-ux + testing + security` tracks.
5. `storefront/` with `code-quality + documentation + frontend(nuxt) + ui-ux + testing + security + performance`.
6. **Domain tooling auto-generated** based on prompt signals:
   - AI → `/prompt-eval`, `/token-audit`, `prompt-reviewer` agent
   - WhatsApp → `/simulate-webhook`, `webhook-signature-verifier` rule
   - Multi-tenant → `/tenant-leak-audit`, `tenant-isolation-reviewer`
7. Full `ai/` per repo: architecture, DB schema, modules, Phase-1 plan, ADRs, patterns.

### Existing project (retrofit / enhance)

```bash
cd ~/some-existing-codebase
claude
```

```
/setup-project
```

What happens:
1. **Scans** everything — `package.json`, `CLAUDE.md` (if any), existing `.claude/`, existing `ai/`, recent git log, folder structure.
2. **Gap analysis** — what tracks are missing, what framework references are missing, what domain tooling the code would benefit from, whether docs are stale or drifted from code.
3. **Plan** — lists every proposed action: "add X (new)", "update Y (needs refresh)", "leave Z (custom, keep)". You approve.
4. **Applies only approved changes**. Existing files are never overwritten without explicit confirmation.
5. **Prepends** a dated `Recent Changes` entry to `ai/status.md`.
6. **Reports** what was added / updated / left alone.

### Any stack works

```
/setup-project "Laravel + Vue + MariaDB e-commerce with Stripe checkout"
/setup-project "Django + React + Postgres, GDPR-compliant CRM"
/setup-project "Go CLI that syncs DNS records — no DB"
/setup-project "Python FastAPI + Next.js dashboard + MongoDB, Firebase auth"
/setup-project "PHP Laravel with Inertia + Vue, Stripe, file uploads"
```

Unknown framework? `/setup-project` generates a reference on the fly, saves it to `~/.claude/templates/packs/<track>/references/<framework>.md`, and every future project reuses it.

### Flags

All optional. Full reference (with conflict rules) lives in `commands/setup-project.md`.

**Mode overrides** (auto-detected by default):

```
/setup-project --create             # force CREATE mode (refuse to touch existing setup)
/setup-project --enhance            # force ENHANCE mode (additive gap-fill — NEW files only)
/setup-project --refresh            # backup + extract knowledge + regenerate fresh
/setup-project --refine             # round two: deepen EXISTING files via deep code analysis
```

**Three-mode mental model:**

| Mode | What it does | When |
|---|---|---|
| `--enhance` | **Add missing files only** — never touches existing ones | First-pass on a half-set-up project; pulling in newly-released packs |
| `--refresh` | **Backup → extract knowledge → wipe → regenerate** all artifacts from latest templates | Pack version drift; structural upgrade; recover from accumulated drift |
| `--refine` | **Round two — deepen existing artifacts** via deep code analysis (entities / architecture / flows / emergent conventions / hot paths / failure history). Rewrites only the auto-generated `## Project-specific` blocks; preserves user-authored sections verbatim | After CREATE / ENHANCE when first-pass artifacts feel generic; whenever the codebase has grown enough that round-one anchors are now shallow |

The flags are complementary, not redundant. Common pipeline: `--create` (round 1) → use the project for a while → `--refine` (round 2: deepen) → later `--refresh` (when packs ship a major upgrade).

**Read-only previews** (write nothing):

```
/setup-project --dry-run            # show the plan
/setup-project --diff               # show pack version drift (recorded → current)
/setup-project --health             # compute setup health score + emit telemetry
/setup-project --validate-schemas   # validate generated JSON configs against schemas
```

**Scope / content**:

```
/setup-project --minimal                  # essentials-only (~30% of full pack); upgrade later via --enhance
/setup-project --include=multi-tenant     # force-apply a technical-signal pack (comma-separated)
/setup-project --tools=cursor,aider       # generate adapters for specific tools
/setup-project --tools=auto               # auto-detect installed tools
/setup-project --add-tool=opencode        # ENHANCE-only: add ONE adapter on top of existing
```

**Refresh safety**:

```
/setup-project --refresh --no-backup              # skip Phase 0 backup (DANGEROUS — refuse without explicit confirm)
/setup-project --refresh --backup-dir=<path>      # override default .claude/backups/<YYYYMMDD-HHmm>/
```

**Merge policy** (override Appendix C matrix):

```
/setup-project --force-replace-all   # overwrite every overlap with pack version
/setup-project --force-keep-all      # never overwrite existing files
```

**Refine tuning** (REFINE-only — override the plateau classifier defaults):

```
/setup-project --refine --plateau-delta=1     # stricter: declare plateau only when ≤ 1 artifact moved (default 2)
/setup-project --refine --plateau-consumed=0.9 # require 90% of deep-extraction signal consumed (default 0.85)
/setup-project --refine --plateau-score=85    # require avg score ≥ 85 for PLATEAU-DEEP (default 80)
```

Defaults are theoretical (calibrated against synthetic fixtures). Tune as you accumulate REFINE telemetry from `.claude/_setup-quality.md` history.

**UX**:

```
/setup-project --wizard              # interactive Q&A instead of one consolidated question block
/setup-project --lang=ar             # Arabic prompts + bilingual CLAUDE.md/AGENTS.md headers (also: en, auto)
/setup-project --no-telemetry        # disable local-only telemetry append
```

**Workflow handoff** (universal — applies to EVERY generated command, not just /setup-project):

```
/<command> "..." --plan              # plan only; writes .claude/plans/<file>.md; exits before implementation
/execute-plan <plan-file>            # implements the plan (executor sub-agents default to Sonnet); auto-verifies
/verify-plan <plan-file>             # audits implementation against plan; reports drift
```

See "Plan-then-implement workflow" section below for the full handoff story.

**Common conflicts** (refuses with error):

- `--create` + `--enhance` · `--create` + `--refresh` · `--create` + `--refine` · `--force-replace-all` + `--force-keep-all` · `--no-backup` without `--refresh`
- `--enhance` + `--refresh` → REFRESH wins (warns)
- `--enhance` + `--refine` → runs as 2-phase pipeline: ENHANCE first (gap-fill) → REFINE (deepen)
- `--refresh` + `--refine` → REFRESH wins; recommends running `--refine` afterwards if needed
- `--refine` with no `.claude/` artifacts present → user error; suggests `/setup-project` (CREATE) first
- `--refine` + `--force-replace-all` → refused (incompatible with REFINE's "preserve user-authored sections" contract)
- `--diff` / `--health` + any write flag → read-only wins (warns)

---

## Plan-then-implement workflow (`--plan`)

**PLAN → EXECUTE → VERIFY.** Plan on a strong model, execute on a cheap one, verify independently. Every command supports `--plan`:

```
/add-feature "filter prescriptions by status" --plan
/fix-bug 42 --plan
```

The flag runs Phases 1–3, writes `.claude/plans/<cmd>-<slug>-<ts>.md`, exits before code change. Then **execute** the plan one of two ways:

- **In Claude** — `/execute-plan <plan-file>` implements it; its executor sub-agents default to **Sonnet**, so authoring the plan under **Opus** (or `opusplan` plan mode) gives you "Opus plans, Sonnet executes" for free. It auto-runs `/verify-plan` at the end.
- **In any other tool** — hand the self-contained plan file to OpenCode / Cursor / Aider / a human. (`<command> --from-plan <file>` is the per-command/adapter spelling of the same implement-from-plan entry, e.g. in OpenCode.)

Audit drift any time with `/verify-plan <plan-file>`.

Full spec — including plan file format and retrofitting existing projects — in [`docs/REFERENCE.md`](docs/REFERENCE.md). Skip it for trivial / spike / read-only work.

---

## Round-two deepening (`--refine`)

Round one (`/setup-project --enhance`) puts every load-bearing artifact in place anchored to surface signals. Round two (`/setup-project --refine`) deepens the auto-generated `## Project-specific` blocks against the real code via 6 deep-extraction phases (entities → architecture → flows → conventions → hot paths → failure history), then re-anchors anything scoring < 70/100 plus propagates the deepening into every selected tool adapter.

Safety: user-authored sections preserved verbatim (marker-bracketed; SHA-256 verified). Idempotent — repeated runs converge. Failure-history is opt-in. Cost-capped via `--max-subagents=<N>`.

Verdicts after each run: `PLATEAU-DEEP` (stop), `PLATEAU-WEAK` (grow upstream signal first), `NOT-PLATEAU` (run again).

Full walkthrough — phase tables, adapter sync details, output files, plateau diagnosis — in [`docs/REFERENCE.md` § Refine — round-two deepening](docs/REFERENCE.md).

---

## The track mix logic

Always applied (per `templates/packs/_registry.md`):
- `code-quality` · `documentation` · `learning` · `security`

Conditional (selected on detection signals):
- `backend` → if backend code / API mentioned
- `frontend` + `ui-ux` → if frontend code / UI mentioned
- `database` → if DB code / schema mentioned
- `devops` → if deploy / Docker / CI mentioned, or Phase 2+
- `performance` → rules always; agents on demand or if scale target mentioned
- `testing` → if test folders / runners detected
- `business` → if domain models / billing / multi-tenant identity detected
- (other signal-gated tracks: `distributed-systems`, `infrastructure`, `migration`, `mobile`, `observability`)

Framework references copied automatically from the pack into the project's `.claude/references/`.

---

## Domain tooling auto-generated

Based on prompt signals, `/setup-project` creates tools the project will actually use:

| Signal | Generates |
|---|---|
| AI / LLM | `/prompt-eval`, `/token-audit`, `prompt-reviewer` |
| Webhooks (Stripe / WhatsApp / GitHub) | `/simulate-webhook`, `webhook-signature-verifier` |
| Payment / billing | `/replay-charge`, `payment-reviewer` |
| Multi-tenant | `/tenant-leak-audit`, `tenant-isolation-reviewer` |
| Real-time / websockets | `/ws-trace`, `ws-contract-reviewer` |
| E-commerce | `/seed-catalog`, `checkout-flow-reviewer` |
| Event-sourced | `/replay-events`, `event-schema-reviewer` |
| File uploads | `/file-security-audit` |
| Search-heavy | `/reindex`, `search-relevance-reviewer` |
| Feature flags | `/flag-cleanup-scan` |
| Notifications | `/notification-preview` |
| Background jobs | `/job-trace`, `job-idempotency-reviewer` |
| Compliance (GDPR / HIPAA / SOC2) | `/compliance-audit`, `data-retention-reviewer` |

Rule: every strong signal gets at least one tool. No speculative tooling for signals that aren't present.

---

## Syncing across devices

```bash
# Push:
cd ~/.claude && git add . && git commit -m "describe change" && git push

# Pull on another device:
cd ~/.claude && git pull
```

---

## What's NOT synced

Machine state (gitignored): `projects/`, `todos/`, `tasks/`, `sessions/`, `shell-snapshots/`, `statsig/`, `telemetry/`, `cache/`, `debug/`, `downloads/`, `backups/`, `plans/`, `history.jsonl`, `settings.local.json`, `plugins/`.

---

## First push to GitHub

1. Create a **private** `claude-config` repo (empty — no README, no .gitignore).
2. From this directory:

```bash
git init
git add .
git commit -m "initial claude config — /setup-project + 20 tracks + workspace template"
git branch -M main
git remote add origin git@github.com:YOUR_USERNAME/claude-config.git
git push -u origin main
```

---

## Extending

- New agent → drop into matching track's `agents/`. Synced to every device + every future project.
- New track → `packs/<name>/{agents,commands,rules,references}/` + update `setup-project.md` track mix logic.
- New framework reference → `packs/<track>/references/<framework>.md`. Agents read it automatically.
- New rule → `packs/<track>/rules/<rule>.md`. Auto-loaded in every new project that uses that track.

Existing projects don't auto-upgrade (intentional — prevents surprise behavior changes). Run `/setup-project` in enhance mode to pull in new stuff.

---

## Verification scripts

The repo ships with a smoke-test pipeline that verifies the spec stays internally consistent and matches the adapter contracts. Run all of them before committing changes that touch `commands/setup-project.md`, the adapter docs, or the apply-pack-adaptation skill:

```bash
scripts/dry-run-setup.sh             # runs everything below in sequence (no network)
scripts/lint-tool-parity.sh          # tool-parity matrix ⇄ adapter docs ⇄ contract row symmetry
scripts/test-refine-fixture.sh       # marker safety + REFINE artifact presence (synthetic fixture)
scripts/test-adapter-fixtures.sh     # per-adapter contract ⇄ adapter doc symmetry (kind-by-kind)
scripts/test-migration-paths.sh      # legacy → native shape regression (Cursor 2.3 / Cline / etc.)
scripts/lint-decision-logs.sh        # Phase 4.6/4.7/4.8 tokens + hooks.json events documented
```

Network-dependent (run as a maintenance task — NOT in the smoke pipeline):

```bash
scripts/check-tool-versions.sh                  # informational drift report against vendor docs
scripts/check-tool-versions.sh --strict         # exit 1 on any drift (use in scheduled CI only)
scripts/check-tool-versions.sh --update         # refresh recorded hashes after manual review
scripts/check-tool-versions.sh --adapter=cursor # restrict to one adapter
```

Every adapter's `_version.json` records `docs_urls` + `last_verified` + `last_verified_hashes`. The watcher hashes the meaningful body of each upstream doc (timestamps + CDN noise scrubbed), compares to the recorded hash, and flags drift so a human can re-verify the adapter doc against the upstream tool's current docs.

## Troubleshooting

**Command not found** → repo isn't at `~/.claude/`. `ls ~/.claude/commands/` should list `setup-project.md`.

**Hooks not running** → `chmod +x ~/.claude/templates/repo-baseline/.claude/hooks/*.sh ~/.claude/templates/workspace-baseline/.claude/hooks/*.sh`.

**Want to undo a scaffold** → delete `.claude/`, `ai/`, `CLAUDE.md` in the target folder. Everything else is yours.

**Want to see the plan without writing** → `/setup-project --dry-run`.

---

## License

Personal config. Use however you want.
