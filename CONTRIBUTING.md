# Contributing to Refract

Refract is a compiler for AI-agent configuration: one source of truth in this repo, projected into
twelve tools' native formats. That makes almost every bug in it a **drift** bug — a doc that
promises something the script no longer does, a command that exists but is documented nowhere, a
validator quietly regressed to always-pass. The CI gates exist because that class of bug is
invisible in review and expensive in the field.

So the ask is short: **read the neighbouring file before you write yours, and run the gates before
you open the PR.**

---

## 0. The one rule that breaks everything if you miss it

**Edit this repo. Never edit `~/.claude/`.**

`scripts/sync-to-global.sh` installs Claude Code's surface as **symlinks** — every top-level child
of `commands/`, `templates/` and `scripts/` becomes a symlink under `~/.claude/` pointing back into
your clone. Editing a file in this repo is therefore live in the next Claude Code turn with no
re-sync. Editing `~/.claude/` directly either edits *this repo through the symlink* (fine, but
confusing) or replaces a symlink with a real file (drift — and your work is lost the next time
`--force` runs).

```bash
./scripts/verify-sync.sh          # 0 = clean, 1 = drift; tells you which entry drifted
```

The other five global tools (Kimi, Qwen, Gemini, OpenCode, Codex) receive **generated copies**, not
symlinks. Change a command and re-run `./scripts/sync-to-global.sh --apply` for those.

Your `~/.claude/settings.json` and `~/.claude/settings.local.json` are never read or written by any
script here. They stay yours.

---

## 1. Setup

```bash
git clone https://github.com/adnanmokhtar/refract.git
cd refract

./scripts/sync-to-global.sh              # dry run — this is the DEFAULT, it writes nothing
./scripts/sync-to-global.sh --apply      # install
./scripts/verify-sync.sh                 # confirm
```

Dependencies the gates actually use:

| Tool | Needed by | If missing |
|---|---|---|
| `bash` | everything | Scripts target **bash 3.2** (macOS default) unless a header says otherwise. `lint-tool-parity.sh` documents a bash 4 requirement; it currently passes on 3.2, but do not rely on that when adding to it. |
| `python3` | `verify-cheatsheet.sh`, `validate-pack-consistency.sh`, `test-refine-fixture.sh`, `test-adapter-fixtures.sh`, `dry-run-setup.sh`, `detect-mcp.sh --apply` | those gates hard-fail; `detect-mcp.sh` degrades to report-only (says so in the report, still exits 0) |
| `jq` | `detect-mcp.sh`, `detect-tracks.sh`, and the shipped hooks | hooks degrade to a documented fallback (`guard-destructive`, `secret-scan`) or a silent no-op (`inject-path-rules`) |

CI runs on `ubuntu-latest` with no extra install step. If your change needs a new binary, it does not
belong in a gate.

---

## 2. Run the gates locally

`.github/workflows/quality-gates.yml` runs **52 blocking steps** on every push to `main` and every
pull request. Every one of them is blocking: a red gate is a merge blocker, not a note for later.

> **All 52 gates are green on `main`.** There is no known-red allowance: if a gate fails locally,
> your change caused it. Two gates worth knowing about because they fail for non-obvious reasons —
> `verify-cheatsheet.sh` goes red whenever a command is added or renamed without regenerating
> (`python3 scripts/gen-cheatsheet.py`), and `verify-doc-sync.sh` goes red when a new command is not
> also added to `docs/COMMANDS.md`.

```bash
# The whole suite, in workflow order. Stops nothing — prints a pass/fail line per gate.
for g in \
  scripts/test-validators.sh \
  tests/hooks/run.sh \
  tests/real-shape/run.sh \
  scripts/test-new-artifact.sh \
  scripts/lint-context-provenance.sh \
  scripts/lint-plan-schema.sh \
  python3 scripts/gen-baseline-hashes.py --check \
  scripts/test-baseline-sync-advisory.sh \
  scripts/verify-gate-count.sh \
  scripts/verify-fixture-counts.sh \
  scripts/lint-orphan-templates.sh \
  scripts/lint-shell-portability.sh \
  scripts/check-rule-budget.sh \
  scripts/audit-stack-leakage.sh \
  scripts/audit-command-dry.sh \
  scripts/lint-validator-parity.sh \
  scripts/verify-doc-sync.sh \
  scripts/verify-cheatsheet.sh \
  scripts/verify-pack-matrix.sh \
  scripts/validate-pack-consistency.sh \
  scripts/lint-tool-parity.sh \
  scripts/lint-overlay-catalog.sh \
  scripts/lint-track.sh \
  scripts/lint-decision-logs.sh \
  scripts/test-adapter-fixtures.sh \
  scripts/verify-global-scope.sh \
  scripts/test-delegate-relay.sh \
  scripts/lint-handoffs.sh \
  scripts/lint-import-edges.sh \
  scripts/lint-phase-dag.sh \
  scripts/lint-hook-parity.sh \
  scripts/lint-import-budget.sh \
  scripts/test-rank-source-files.sh \
  scripts/test-build-graph.sh \
  scripts/lint-setup-contracts.sh \
  scripts/test-merge-decide.sh \
  scripts/test-anchor-citations.sh \
  scripts/test-preflight-backup.sh ; do
  bash "$g" >/dev/null 2>&1 && echo "PASS  $g" || echo "FAIL  $g"
done
```

Re-run the failing one without the redirect to read the diagnosis. Every gate prints the offending
file and line; none of them require you to guess.

| Gate | What it actually catches | Typical fix |
|---|---|---|
| `test-validators.sh` | A validator regressed to always-pass. Replays `tests/validators/<script>/{good,bad}/<case>/` mini-repos and asserts the exit code matches the folder's contract. | Fix the validator, or add the case you just legitimised. |
| `tests/hooks/run.sh` | A security hook regressed to always-allow. 73 fixtures across `guard-destructive` (23), `module-boundaries` (21), `pre-edit-guard` (11), `secret-scan` (8), `inject-path-rules` (5), `recall-inject` (5), plus 3 programmatic assertions that `module-boundaries` stays inert with no `ai/modules.md`, an empty boundaries section, or the opt-out flag, plus 10 payload assertions for the context-only `inject-blast-radius` (exit code proves nothing there — a hook that exits 0 saying nothing looks identical to one that works) — 86 checks total. Filename encodes the expected exit: `*block*` → 2, `*allow*` → 0. | Fix the hook. If the new behaviour is correct, add a fixture proving it. |
| `tests/real-shape/run.sh` | A shipped artifact that is correct about an input nobody writes. Every other gate compares this repo to itself; this one runs `module-boundaries.sh` and `rank-source-files.py` against a project laid out like a real TypeScript monorepo — `apps/<app>/src/`, `libs/<lib>/src/`, a service seven directories deep, a `tools/` script nothing imports. **Its inputs are measured, not invented:** each specifier form carries its share of 33,474 real imports (`../x` 37.5%, `a/b/c` 21.8%, `@org/pkg` 19.2%, `./x` 14.1%, `pkg` 7.4%), and 100% of them carry no extension — the fact the facade bug hid behind. Reverting that fix turns this suite red on the two forms real code uses while the `/index.ts` form keeps passing. | Fix the artifact. If a NEW specifier form appears in real code, add it here with its share — never invent one to make a case. |
| `test-new-artifact.sh` | The scaffolder drifting from the registration surface it exists to cover. `scripts/new-artifact.sh --kind=skill\|command --pack=<p> --name=<n> --description="…"` creates the artifact and re-derives every counted figure; `--resync` alone repairs them. Counts are **computed from disk, never incremented**, so the fixture starts with every number wrong and must come out right. Also pins the four refusals — no description (A02), unknown pack, non-kebab name, existing artifact — and that `--dry-run` writes nothing. | Update `new-artifact.sh` when a new counted figure appears anywhere; a figure the tool cannot compute is a figure someone has to remember, which is the drift this repo pays for most often. |
| `lint-context-provenance.sh` | A shipped `ai/` product-context file claiming things about the WORLD with no source. Seven templates — project-goals, users-and-personas, business-model, competitive-context, business-domain, business-flows, roadmap — carry claims no codebase can settle, and `CLAUDE.md` loads them as product context. Phase 2's `[found:]`/`[inferred:]`/`[unconfirmed]` contract covered only `.claude/_extracted-*`; a live repo had 1,063 lines across six of these with **zero** markers, named competitors included. Checks that each template states the contract, that none drops `[unconfirmed]`, and that `/setup-project-health` check 11 grades the same list. | Add the provenance block to the template. Never drop `[unconfirmed]` to tidy it up — "nobody here knows" is the honest default and becomes a question for the team, and a model's recollection is not a source. |
| `lint-plan-schema.sh` | Eight files stating the plan contract and disagreeing about it. Five `<cmd> --plan` commands, `execute-plan.md`, `verify-plan.md` and `plans/README.md` all tell a generator what to emit; only the README positioned the two optional sections, so two valid plans could differ in shape. Canonical order is **Goal · Context · Inputs · Outputs · Constraints · Steps · Verification · Status**, with `## Approach` after Context and `## Known unknowns` before Verification. Reads the LINE that enumerates the schema, never first-mention order across a file — that drafting error reported `execute-plan.md` as drifted when it was not. | Fix the file to the canonical order. Do **not** make the executor require an order: check [3] fails on that deliberately, because writers are ordered and readers stay tolerant, and tightening the reader rejects every plan already saved in a consuming repo. |
| `gen-baseline-hashes.py --check` | A shipped fix that cannot reach an installed project. `apply-baseline-sync.sh` could not distinguish an **older version of ours** (update it — the user never touched it) from a file the **user edited** (keep it), so it kept both. Demonstrated with the `notify.sh` command-injection repair: the sync printed `KEEP-OURS`, exited 0, and left the vulnerable file intact. The managed-region mechanism intended to solve this has never executed — **zero** of 101 baseline files carry a marker. `.baseline-hashes` records every version this repo has published (101 files, 206 versions) so the decision is a lookup. | Regenerate: `python3 scripts/gen-baseline-hashes.py`. Never hand-edit it, and never add a hash that was not shipped — an unknown hash is treated as user content and preserved, which is the safe direction; a wrongly-added one overwrites somebody's work. |
| `test-baseline-sync-advisory.sh` | A fix withheld in silence. KEEP-OURS is the right call for a guard a human edited — overwriting it would destroy their work — but the row was printed once and dropped, so the project stopped receiving every later fix to that guard while the run printed a clean summary and exited 0. MEASURED across three real installed projects: 4 / 1 / 0 executable guards sat in that state, one of them a security guard. The gate asserts the advisory **names** them; it deliberately does not assert an overwrite. |
| `_merge-hook-wiring.py` (via `--wire-hooks`) | A hook delivered but registered nowhere. `settings.json` is almost always KEEP-OURS, so a hook the sync ADDs lands on disk inert — measured at 7 and 11 hooks on two installed projects, `secret-scan` and `pre-edit-guard` among them. The merge is additive, matches on hook **basename** so a project that wired a hook its own way is never doubled, reuses an existing matcher group, and writes atomically. Opt-in: editing the file that holds the user's permissions is a different act from replacing one we shipped. |
| `verify-gate-count.sh` | A doc that miscounts the very workflow it documents. CONTRIBUTING carried 33, 25 and 19 simultaneously while CI ran 48 — each typed by hand, each drifting alone. A contributor reading "all 25 gates are green" beside 48 results cannot tell which figure lies. The workflow is the one source that cannot be wrong about itself. |
| `lint-shell-portability.sh` | A shell construct that behaves differently on macOS and Linux. The local suite runs on one and CI on the other, and today a defect escaped in EACH direction — GNU-only regex (`\|`, `IGNORECASE`) matching nothing on macOS, and `declare -a` without `=()` aborting under `set -u` on Linux. **Measured scope, not assumed:** shellcheck catches neither the uninitialised array nor the regex dialects. It does catch `SC2128` (array expanded without an index — the shape that left a gate checking 1 adapter of 12), unreachable `case` arms (`SC2221`/`SC2222` — one was a real defect), and a malformed `# shellcheck disable=` directive that had never suppressed anything. | Fix it. If the construct is deliberate, re-record with `--record` and **write the reason on the line** — a reasonless entry is how a ratchet becomes a mute button. Requires shellcheck; its absence is exit 2, never a pass. |
| `check-rule-budget.sh` | The always-loaded rule set busting its token budget. Currently ~4,943 of 6,000 tokens. | Give your rule `paths:` frontmatter (path-scoped, exempt) or trim a foundational rule. |
| `audit-stack-leakage.sh` | Single-stack wording in universal docs — `commands/*.md`, `templates/phases/`, `templates/governance/`, the migration/align/code-quality packs, adapter `_*.md`. A stack token whose ±1-line window names only one stack is a FAIL there; in the other packs it is a WARN. Naming two frontends, two backends, or one of each passes. | Name several stacks, or move the framework-specific text into `references/` (skipped by design). |
| `audit-command-dry.sh` | A command re-explaining SOLID / clean-code / the Phase 3 ALWAYS list instead of linking the shared source. | Point at `templates/governance/core-discipline.md` and `templates/snippets/phase-3-always-reads.md`. |
| `lint-validator-parity.sh` | A doc citing a `check_*` validator in present tense that no script defines — a promise with no enforcement. | Implement it, or mark the citation `(planned)` / `(agent-side …)` / `not script-enforced`. Honest disclosure is exempt; silent fiction is not. |
| `verify-doc-sync.sh` | An undocumented command, or a pack missing a sync file. See §5 — this is the one people trip over. | Document the command; add `_essentials.md` / `_topics.md` / `_version.json`. |
| `verify-cheatsheet.sh` | `docs/CHEATSHEET.md` drifted from the command corpus. | `python3 scripts/gen-cheatsheet.py` — never hand-edit the file. |
| `verify-pack-matrix.sh` | `assets/pack-matrix.svg` drifted from the pack corpus — a pack added, renamed or removed, or its agent/skill/command/rule counts changed. The SVG was hand-authored until it had silently trailed the tree by three packs. | `python3 scripts/gen-pack-matrix.py` — never hand-edit the file. |
| `validate-pack-consistency.sh` | A pack manifest pointing at files that don't exist: a `_topics` `fallback:` that doesn't resolve, an `_essentials` entry with no artifact behind it, malformed `_version.json`. Artifacts with no `_topics` entry are a WARN. **Check 8b** additionally holds every `_examples/` fallback to the source it abridges — see §5b. | Fix the manifest, not the gate. |
| `lint-tool-parity.sh` | The 12-adapter matrix disagreeing across `tool-adapters/_registry.md`, `tool-adapters/README.md` and `repo-baseline/ai/references/tool-parity.md`. | Update all three. They are the same fact stated three times; that is the point. |
| `lint-overlay-catalog.sh` | The regulatory-overlay catalog promising an overlay nobody wrote, an overlay file with no catalog row, a row that declares neither `[SHIPPED]` nor `[PLANNED]`, or a sibling-overlay citation that neither resolves nor discloses. | Ship the overlay, or mark the row `[PLANNED]`. A catalog is a promise; keep it one you kept. |
| `lint-track.sh` | A `templates/tracks/<name>/` missing `detect.md` / `pack.md` / `conventions.md` / `meta.yaml`, or carrying an invalid signal kind, weight, or merge mode. | Follow `templates/tracks/_loader.md`. |
| `lint-decision-logs.sh` | Spec drift in the Phase 4.6/4.7/4.8 decision-log format — an action token, a table column, a helper-function name, or the adapters' `hooks.json` event schema no longer documented where it is owned. Phase 4.8-DEEP's cost bound depends on those files staying parseable. | Update the live owner doc, not a copy. |
| `test-adapter-fixtures.sh` | An adapter doc that cannot actually produce what the Phase 4.8.0 contract promises for it, or asymmetric drift between the adapter doc and its contract row. | Document the missing output path on both sides. |
| `verify-global-scope.sh` | A pack command leaking into the global surface, or `sync-to-global.sh` sourcing from `~/.claude/commands` again. Checks [3] and [4] read live tool dirs and auto-skip in CI. Check [6] fails an analysis script that sinks its report under `$TARGET` with no `--stdout` / `--no-write` arm. | Keep pack commands in their pack. See §4. Add the read-only mode; see §2b. |
| `test-delegate-relay.sh` | The relay dispatching into its own repo, or a committing implementer coming back as an empty diff that reads like a harmless no-op. 9 sandboxed cases / 55 assertions under `mktemp -d` with a throwaway `$HOME`. | Fix the relay, not the fixture — and never test it against a repo you care about. |
| `lint-handoffs.sh` | A reference that resolves as *text* but not as *contract* — a `§` anchor naming a section its target does not have, a key handed to a skill its `## Inputs` never declared, an artifact name no script writes, an ordinal gloss the scaffolder spells differently. The other gates verify the catalog; this one opens the cited file. | Fix the citation. If it is correct as-is, add a line **with a reason** to `scripts/_handoff-baseline.md` — a reasonless line suppresses nothing by design. |
| `lint-import-edges.sh` | A dead BACK-edge — an `imported-by:` frontmatter line naming a consumer that was renamed away, or one that exists and never references the claiming file. It is the repo's only machine-readable "I change this, who breaks?" edge, and nothing read it before this gate. Resolution accepts a full path, a two-segment relative tail, a same-dir basename, or one hop through an index; a bare basename never counts (`ai/observability.md` in a consuming repo is not `templates/observability.md`). Prose fragments ("every phase that loads files"), `repo-baseline/` mirrors and negated mentions are skipped and disclosed in the reach line, never counted as passes. | Fix the claim. If it is correct as-is, add a line **with a reason** to `scripts/_import-edge-baseline.txt` — a reasonless line suppresses nothing by design. |
| `lint-phase-dag.sh` | A phase consuming a file no phase declares producing, or one produced only in a narrower set of modes than the consumer runs in (a REFINE-only artifact read by an `[all]` phase). The `inputs:`/`outputs:`/`applies-to-modes:` frontmatter is the pipeline's only declared wiring and nothing joined the two sides before. Vocabulary entries (`mode`, `approved-plan`, `phase-4-outputs`) are disclosed, not guessed; ordering is not checked, because phase-5.5 legitimately consumes its own prior run's output. | Name the real file in the producing phase's `outputs:`. If the input truly is conditional, say so in the entry — `… (REFINE only)` — which the gate accepts as disclosure. |
| `lint-hook-parity.sh` | A hook that ships in `templates/repo-baseline/.claude/hooks/` and is wired in that baseline's `settings.json`, but has no entry in one of the twelve `adapter.md § Hooks` sections — the only place a porter learns the hook exists. Found `module-boundaries.sh` in **0 of 12** adapters, `verify-gate.sh` in one, `session-start.sh` missing from four and `update-session-log.sh` from five. The required set is read from `settings.json`, not from `ls`, so the two git hooks drop out mechanically. Mentions below the section (in Cross-references) do not count. Also fails on a cited `.claude/hooks/<x>.sh` that no longer exists, and on `recall-inject.sh`'s routed home missing a tool. | Write the entry in that adapter's § Hooks, in that tool's own mechanism — *"this tool cannot enforce it, here is the commit-time fallback"* is a valid entry and the one Aider and Continue carry. If it truly belongs nowhere, add a line **with a reason** to `scripts/_hook-parity-baseline.txt`; a reasonless line suppresses nothing by design. |
| `lint-import-budget.sh` | The HOT tier growing past the 600-line ceiling `templates/import-tiers.md` states. HOT loads before any phase on every run, used or not, so it is the one tier whose size is pure recurring cost — and nothing had ever summed it (542 of 600 when the gate landed: 58 lines of headroom). The budget is read from the doc's own table, so editing it there moves the gate; a table that stops stating a number FAILs rather than reading as unlimited. WARM is checked per file, COLD is counted and not enforced. | Split the file — move reference data (grep tables, file inventories) to COLD, which is what the tier exists for. If the split is real work, add a `REPAIR:` line **naming the split** to `scripts/_import-budget-baseline.txt`; "this file is long" restates the finding and is not a reason. |
| `test-rank-source-files.sh` | The extraction sample regressing to directory depth. `scripts/rank-source-files.py` orders a repo's source by how many distinct directories import each file, reserving a quarter of the budget for entry points; the fixture is a workspace where every real file sits at depth 5, so a depth-4 cap would keep the one worthless file and drop the five carrying the architecture. Nine assertions, including determinism and that unresolvable specifiers are dropped rather than guessed. | Fix the ranker, not the fixture. If the order genuinely changed, say why in the assertion's message. |
| `lint-setup-contracts.sh` | A producer and its consumer that disagree, where neither is wrong alone and nothing compared them. Six rules, each written after a MEASURED end-to-end failure: `find` without `-L` over a symlinked packs dir; a gate extractor blind to a field its own generator emits; GNU-only `grep -P`; a declared trigger with no producer; a browser-only pack artifact with no `project_kind:`; a machine contract addressed by section NUMBER. | Fix it. If the violation is deliberate, re-baseline: `scripts/lint-setup-contracts.sh --record`. |
| `test-merge-decide.sh` | The engine deciding wrong AND its safety net not catching it. Self-test plus two fixtures that make the net catch something: a lying corpus that reaches OVERRIDE on a file it must never overwrite (asserts refusal before any write), and the same with the pre-write check stubbed to approve (asserts the post-write read-back rolled the file back from its backup). | Fix the engine, not the fixture. If a decision genuinely changed, say why in the case comment. |
| `test-anchor-citations.sh` | The `Cite-able sources:` line naming directories that hold no source. Four layouts: a single-root SPA whose tooling dot-dirs sort before `src/`, a legacy space-separated citation that must NOT read as stale, a monorepo (no-regression), and a genuinely dead citation that must still be repaired. | Fix the picker. The ranking is by source-file count; a directory holding no source is not a source directory, whatever its name sorts as. |
| `test-preflight-backup.sh` | The Phase-0 backup silently skipping. Age must come from the timestamp in the directory NAME, not its mtime (a `git reset` refreshes mtimes), and the candidate must actually hold a backup — a one-file directory is not one. | Fix `run-preflight.sh`. Taking a redundant backup costs seconds; skipping a needed one costs the project. |

**Not in CI, worth running anyway:**

```bash
bash scripts/test-refine-fixture.sh     # /setup-project --refine marker-safety + structural contract
bash tests/setup-project/run.sh         # setup-project fixtures/snapshots

# The model-driven half — NOT in the blocking suite, and deliberately so.
bash tests/live/run.sh                  # Phase 1 mode detection, Phase 2 stack detection, provenance

bash scripts/dry-run-setup.sh           # what a /setup-project run would emit
bash scripts/pack-coverage-scan.sh <target-repo> --stdout   # pack content vs a real target tree
bash scripts/verify-readme-stats.sh     # README's "What's inside" + the cheatsheet's pack-catalog figures vs disk
bash scripts/validate-pack-consistency.sh --fallback-report   # the `_examples/` repair worklist (§5b)
```

`verify-readme-stats.sh` is the one gate deliberately left out of `quality-gates.yml`, and the reason
is §8's rule rather than a known-red allowance: a validator is wired into the workflow **only if
green**, and this one goes red the moment the corpus changes without a matching README refresh.
It was green at `5ffd22b`; it is red right now, for exactly that reason — `README.md`'s "What's
inside" block reads `**72 scripts**` while `scripts/` holds 73, the 73rd being `scripts/lint-handoffs.sh`.
`bash scripts/verify-readme-stats.sh --print` emits the corrected block; restoring that one cell
returns it to `FAIL=0 WARN=0`, after which wiring it in is a two-line addition above. It is
regression-pinned by `tests/validators/verify-readme-stats.sh/` in the meantime, so it cannot rot
while it waits.

### 2a. Scripts run from two places

Every script in `scripts/` is invoked two ways: directly out of the checkout, and through
`~/.claude/scripts/<name>`, which `sync-to-global.sh` creates as a **symlink into this repo**.
That second path is how `/setup-project` actually runs them.

So a script must find **its own checkout**, not the directory it was invoked from:

```bash
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
```

**Why this is not pedantic.** `REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` —
the obvious form — resolves to `~/.claude` when the script is reached through the symlink.
Every sibling asset it then reaches for resolves *only if that asset happens to have been linked
too*. On 2026-08-23 `scripts/merge-decide.py` existed at HEAD, `sync-to-global.sh` had not been
re-run since it landed, and `$REPO_ROOT/scripts/merge-decide.py` therefore pointed at a link
that was never created. 238 MERGE rows across two live product repos — the entire payload of a
seven-batch programme — degraded to "listed, not decided", and the script still exited 0. Seven
repo files were missing from the global install and nothing detected the drift.

Three consequences, all enforced:

- **`pwd -P` is not a substitute.** It resolves the *directory*, never the symlinked *file*.
  `apply-baseline-sync.sh` computed a second root that way, printed
  `WARN wire-rule-imports.sh not found beside this script` on every run while the script sat in
  the checkout, and left every rule in both target repos unimported — 55 rules, ~82,475 tokens,
  loaded by nothing. `lint-setup-contracts.sh` **Rule 10** checks *every* root a file derives,
  not just the first.
- **Framework DATA is checkout-first too.** `${CLAUDE_CONFIG_ROOT:-$HOME/.claude}/templates/…`
  alone has the same failure mode, and the checks that read those corpora (C2i, C2n, C2s)
  degrade *quietly* when the corpus is missing. `audit-setup.sh` resolves them through
  `framework_path()`: checkout first, global second.
- **A printed remediation must be runnable.** Rule 13 fails any script that roots a fix at a
  literal `~/.claude/scripts/`, or that names a script this repo does not ship. The audit once
  identified a mandatory failure correctly and then handed the reader
  `~/.claude/scripts/wire-rule-imports.sh` — "No such file or directory".

A stale global install can now only mean a stale **entry point**, never a missing library.

### 2b. Running an analysis script against a repo you must not modify

Every script here that ANALYSES a target repo used to sink its report inside that repo, so
running one to *check* a project modified it — and `.claude/` got created in targets that
had none. On 2026-08-22 that turned "verify the fix against the real project, read-only"
into three regenerated reports inside the protected project: the verification **was** the
write. Each of them now takes a read-only mode, and `verify-global-scope.sh` check [6]
fails any new one that does not:

| Script | Read-only invocation |
|---|---|
| `audit-anchoring.sh` | `--stdout` |
| `audit-adapter-coverage.sh` | `--stdout` |
| `study-existing.sh` | `--stdout` |
| `pack-coverage-scan.sh` | `--stdout` |
| `deep-codebase-scan.sh` | `--stdout` (also suppresses the preserve-path header re-stamp) |
| `refresh-extract-checklist.sh` | `--stdout` (same) |
| `detect-mcp.sh` | `--stdout` (refused with `--apply`, which exists to write) |
| `migration-detect-existing.sh` | `--no-write` — **not** `--stdout`: stdout carries the verdict token callers read with `$(...)` |
| `audit-setup.sh` | `--read-only` — routes all three sub-audits off-target |

`--no-write` is accepted as an alias for `--stdout` everywhere it appears above. All of them
also take `--report=<path>` to redirect the report; the space form `--report <path>` is
**refused**, because in the scripts that take positional pack names a bare path would parse
as a pack and the report would silently land in the target after all.

The apply-family (`apply-*.sh`) is exempt: writing the target is their contract, and they
are dry-run by default with `--apply` to commit.

---

## 3. The architecture, in the order you'll need it

```
commands/                   15 global commands. THE global surface — nothing else is.
templates/
  packs/                    23 role-based tracks. Per-PROJECT, installed by /setup-project.
  phases/                   /setup-project's execution flow, one file per phase.
  repo-baseline/            what every target repo gets: rules, hooks, settings, baseline commands.
  workspace-baseline/       multi-repo workspaces (dispatcher + cross-repo commands).
  tracks/                   stack-specific scaffolders (detect → emit).
  tool-adapters/            one folder per supported tool + the registry/parity matrices.
  domains/                  technical signals (auth, payment, real-time, …).
  business-domains/         business knowledge.
  regulatory-overlays/      GDPR · HIPAA · PCI-DSS · SOC 2.
  governance/               hard rules, core discipline. Cited, never duplicated.
  snippets/                 shared prose fragments commands @-import.
docs/                       COMMANDS.md + REFERENCE.md are hand-written; CHEATSHEET.md is GENERATED.
scripts/                    sync, validators, linters, audits. Deterministic, fixture-pinned.
tests/                      hooks/ · validators/ · refine-fixture/ · setup-project/
```

Three distinctions that decide where your change goes:

**`commands/` vs `templates/packs/*/commands/`** — this is a scope boundary, enforced by
`verify-global-scope.sh`. `commands/` is the cross-tool **global** set: stack-agnostic orchestration
that makes sense on any machine, symlinked into `~/.claude/` and ported into five other tools'
global command dirs. Pack commands are **project-scoped**: `/setup-project` installs them into a
repo's `.claude/commands/` only when that pack is selected, and `apply-adapter-sync.sh` ports them
per-repo. A single stray `ln -s` of a pack command into `~/.claude/commands` used to re-bloat every
tool's global surface with 19 migration commands. That is why the gate exists and why it is blocking.

**`templates/packs/` vs `templates/phases/`** — packs are *content* (what an agent knows about a
role). Phases are *control flow* (what `/setup-project` does, in order). A phase file is ≤500 lines,
carries `phase:` / `name:` / `inputs:` / `outputs:` / `exit-criteria:` frontmatter, and **must not
reference another phase by content — only by named output.** If you find yourself writing "as Phase
2 explained", you are coupling two files that the orchestrator imports independently.

**`scripts/` vs everything else** — scripts are deterministic. If a step can be a shell script with
a fixture, it should be: an LLM instruction cannot be pinned by a test, and this repo's whole
premise is that unpinned promises drift.

---

## 4. Recipes

### Add an agent

1. `templates/packs/<pack>/agents/<name>.md`, frontmatter `name:` / `description:` / `model:`.
2. Register it in the pack's `_topics.md` as `kind: agent` with a `triggers:` expression drawn from
   `templates/packs/_trigger-vocabulary.md` — that file is the **only** valid source of trigger
   names. Inventing one there means also teaching the Phase 2 orchestrator to record it.
3. Optional `_examples/<name>.md` as the AUTHOR-mode structural fallback. If you skip it, the
   fallback chain (topic description → closest literal template) still produces a viable artifact.
   Half-filled `_examples/` is fine.
4. Bump the pack's `_version.json` (minor for a new artifact) **and add a matching
   `## <version>` section to the pack's `CHANGELOG.md`**. All 23 packs ship a separate
   `CHANGELOG.md` and all 23 point at it with the string form `"changelog": "CHANGELOG.md"`;
   the legacy in-JSON object is still honoured by `validate-pack-consistency.sh` but no pack
   uses it, so do not introduce one. A version with no matching heading is a WARN (check 6).
5. Read an existing agent first. The house contract is cite-or-halt: every BLOCKER/HIGH finding
   carries `<file:line>` plus an external authority (OWASP class, RFC section, CVE). Agents that
   hand-wave get merged and then quietly produce noise forever.

### Add a pack

1. `templates/packs/<name>/` with the three required files: `_version.json`, `_essentials.md`,
   `_topics.md`. Phase 4.0 preflight enforces their presence; `verify-doc-sync.sh` gate [1] and
   `validate-pack-consistency.sh` both fail without them.
2. `CHANGELOG.md` with a `## <version>` heading matching `_version.json` (hard rule A27; WARN-only
   in the script, but all 23 packs honour it).
3. At least one of `agents/` `commands/` `skills/` `rules/` `ai-patterns/`. **Not `runbooks/`** —
   `templates/packs/README.md` documents it, but 0 of 23 packs use one; do not start. Any
   `_examples/<name>.md` you add is a shipped AUTHOR-mode fallback, not a sample, and is held to
   its source by check 8b, and its `fallback:` STRATEGY is gated by check 3b — read §5b before
   writing one.
4. Add any NEW trigger name your `_topics.md` uses to `templates/packs/_trigger-vocabulary.md`.
   Reusing existing names needs no edit there.
5. Add a row to `templates/packs/_registry.md` — that table, not a hard-coded list, is what Phase 2
   / 4.0 / 4.2 and Appendix B consult. Folder↔row parity is hand-maintained; see that file's
   § "Drift detection" for the one-line check.
6. Add a floor row to the "Minimum artifacts per LOAD-BEARING track" table in
   `templates/phases/phase-4.0-preflight.md` (**not** `commands/setup-project.md`, which is a thin
   orchestrator and holds no track logic). Without a row, Phase 2.6.b has no floor to check.
7. Add a detection block to `scripts/detect-tracks.sh`, or the pack is never auto-selected. Opt-in
   packs (`align`, `algorithms`) deliberately have none — say so in the registry row rather than
   leaving it ambiguous.
8. Add the pack key to `is_pack_path()` in `scripts/audit-stack-leakage.sh`. A pack in neither
   `is_pack_path()` nor `is_universal_path()` gets **zero** leakage scanning — silently, not as a
   failure.
9. If the pack ships commands: add each `/<name>` to `docs/COMMANDS.md`, then regenerate with
   `python3 scripts/gen-cheatsheet.py`. `verify-doc-sync.sh` and `verify-cheatsheet.sh` are red
   until you do.
10. Update the track count in `docs/setup-project-cheatsheet.md` and `README.md`
    (`lint-tool-parity.sh` polices the `<N> tracks` string in both), plus the untested-but-wrong
    count strings in `CONTRIBUTING.md`, `.claude-plugin/{plugin,marketplace}.json`, and
    `docs/RETRIEVAL.md`.
11. Tool adapters need **nothing** unless the pack ships a discipline that generic per-adapter
    translation would flatten — see `templates/tool-adapters/_registry.md` § "Maintaining pack
    templates" for the four triggers.
12. `bash scripts/seed-versions.sh` to confirm the version file is well-formed.

Never rename a pack in place. Add the new key and mark the old `deprecated: true` with
`replaced_by:` in its `_version.json`, so Phase 0.2 extract can still read older installs.

### Add a framework reference

`templates/packs/<pack>/references/<framework>.md`. That's the whole change — agents pick it up with
no edits, because they are written against roles, not frameworks.

This is also the pressure valve for `audit-stack-leakage.sh`: `references/` and any `STACK.md` are
explicitly skipped. Framework-specific idioms (`useState`, `v-model`, `*ngIf`, `app.get(`) are
*correct* there and a build failure almost anywhere else.

### Add a rule

Decide the tier first — it is decided by exactly one thing, the presence of `paths:` frontmatter.

- **Always-loaded** (no `paths:`) — must be `@`-imported by the target repo's `CLAUDE.md`, costs
  tokens every session, counts against the 6,000-token budget. There are four of these today
  (`read-before-write`, `read-codebase-deeply`, `think-simplify-surgical`, `code-quality`) and the
  bar for a fifth is high.
- **Path-scoped** (`paths:` list of globs) — not imported; `inject-path-rules.sh` matches the edit
  target and injects the rule as `additionalContext`, once per session. Near-zero cost. Globs
  support `**`, `*`, `**/`, `/**` and literal paths.

**Default to path-scoped.** Most rules govern a slice of the tree, and the budget gate exists
precisely to force that question. Repo-baseline rules live in
`templates/repo-baseline/.claude/rules/`; role-specific rules live in `templates/packs/<pack>/rules/`.

Adding a file to a rules directory does **not** load it. Claude Code does not auto-load
`.claude/rules/`. It loads because `CLAUDE.md` imports it or because it has `paths:`.

### Add a command

**Global** (`commands/<name>.md`): frontmatter `description:` / `kind: command` / `pack: orchestration`.
`orchestration` is a logical label, not a track — there is deliberately no
`templates/packs/orchestration/` folder, and `_registry.md` documents it as a reserved non-track
namespace.

**Pack** (`templates/packs/<pack>/commands/<name>.md`): frontmatter `description:`. Register it in
`_topics.md`, consider `_essentials.md`, bump `_version.json` and its `changelog` block. Do not symlink
or copy it into `commands/`.

Either way, follow `templates/canonical-command-template.md`: declare which of the seven phases
(Understand → Organize → Retrieve → Generate → Update → Validate → Improve) apply to your command
type, and write `## Phase X — N/A — <reason>` for the ones that don't, rather than omitting them
silently. Then do §5.

### Add a hook

`templates/repo-baseline/.claude/hooks/<name>.sh`, wired into
`templates/repo-baseline/.claude/settings.json` under the right event and matcher. Conventions the
existing hooks all follow, and yours should too:

- Exit 2 = block (Claude sees your stderr and stops); exit 0 = allow. Context-only hooks always
  exit 0.
- Read the payload from stdin. Prefer `jq`, fall back to `sed` so the hook still works without it.
- Ship a per-project opt-out flag file (`.claude/.no-<name>`), checked on line one.
- Say *why* on block, and say how to proceed legitimately.
- **Add fixtures.** `tests/hooks/cases/<name>/NN-{block,allow}-<what>.json` — the filename is the
  assertion. A hook with no fixtures is a hook that will silently regress.

### Add a validator or a gate

1. Write `scripts/<name>.sh`. Accept `--repo-root=<dir>` if at all possible — that is what lets the
   harness point it at a fixture.
2. Add `tests/validators/<name>.sh/good/<case>/` and `.../bad/<case>/`, each a self-contained
   mini-repo-root. The harness asserts exit 0 on every `good` and non-zero on every `bad`.
3. If your script does not take `--repo-root`, add an entry to `invoke()`'s case statement in
   `scripts/test-validators.sh`.
4. Wire it into `.github/workflows/quality-gates.yml` **only once it is green** — and say in the
   step comment what drift it prevents. Every existing step does; that comment is how the next
   contributor knows whether the gate is still earning its slot.

### Exercise the delegate relay

`scripts/delegate-relay.sh` launches a *different* AI CLI against a real working tree. Exercising it
therefore means letting an autonomous process write to a repo — so the repo has to be one you are
willing to lose.

**Never run it against this repository, and never against a repo whose history you care about.** It
refuses a self-target by default (exit 6, `--allow-self` overrides), because the artifact directory
is written *inside the target tree*: an implementer that commits there commits the relay's own
brief, logs and shim along with your work. That is not hypothetical — it is why the guard exists.

Build a throwaway repo and a stub implementer named after a real one:

```bash
SB="$(mktemp -d)"; export HOME="$SB/home"; mkdir -p "$SB/home" "$SB/bin" "$SB/repo"
git -C "$SB/repo" init -q && printf 'seed\n' > "$SB/repo/file.txt"
git -C "$SB/repo" add file.txt && git -C "$SB/repo" commit -qm seed

printf '#!/bin/sh\ncase "$1" in --version) echo stub; exit 0;; esac\nprintf x > a.txt\n' > "$SB/bin/kimi"
chmod +x "$SB/bin/kimi"

PATH="$SB/bin:$PATH" bash scripts/delegate-relay.sh --implementer=kimi \
  --repo="$SB/repo" --brief=<(echo "edit a.txt") --timeout=60
```

`kimi` is the cheapest stub target: its profile declares no read-only mode and no autonomy flag, so
the relay probes nothing beyond `kimi --version`. A throwaway `$HOME` keeps the run out of your real
`~/.gitconfig` and CLI credentials.

`scripts/test-delegate-relay.sh` is that procedure as a fixture — nine cases, 55 assertions, every
repo built under `mktemp -d`, and an isolation guard that aborts the whole run if a sandbox path
escapes the temp root. Extend it rather than testing by hand: it is one of §2's 52 blocking gates,
so a relay regression fails CI instead of surfacing in someone's clone.

---

## 5. The doc-sync requirement

`verify-doc-sync.sh` is mechanical and unforgiving, and it is the gate most PRs fail first.

**Gate [2]:** it collects every command basename from `commands/`, every
`templates/packs/*/commands/`, `templates/repo-baseline/.claude/commands/` and
`templates/workspace-baseline/.claude/commands/` (ignoring `_`-prefixed helpers), and requires each
one to appear as a whole `/<name>` token in **`docs/COMMANDS.md`** or **`docs/REFERENCE.md`**
(workspace commands may instead be indexed in `templates/workspace-baseline/.claude/rules/workspace.md`).

So: **adding a command means updating `docs/COMMANDS.md`.** Not a mention in a PR description, not a
line in the CHANGELOG — the manual. Add it to the table of contents, the at-a-glance table, and its
own section if it has flags or modes.

**Gate [3]** is the mirror, as a WARN: a backtick-wrapped `` `/token` `` in the docs with no backing
command file is a dangling reference. Harness builtins (`/continue`, `/resume`, `/schedule`) are
allowlisted; `/<real-command>-<something>` is treated as an example invocation.

Then regenerate the cheat sheet:

```bash
python3 scripts/gen-cheatsheet.py     # docs/CHEATSHEET.md — GENERATED, never hand-edited
```

`verify-cheatsheet.sh` re-derives it and fails red if the committed copy is stale, so a renamed
command or an edited `description:` needs this too.

---

## 5b. The `_examples/` fallback contract

`templates/packs/<pack>/_examples/<name>.md` is **not documentation**. It is the AUTHOR-mode
fallback: `templates/phases/phase-4.2-apply.md:26` copies it **verbatim** into a project whenever
extraction has no signal for that topic, at the same destination path as the real artifact. That is
the default for greenfield, for `--lightweight`, and for every `[EXTRACTION-WEAK]` track. 287 of the
297 files are named as a live `fallback:` in a `_topics.md`. **Edit a source artifact and you have
probably invalidated its fallback — and re-cutting it is YOUR job, not the gate's.**

Check 8b of `validate-pack-consistency.sh` catches *some* of the ways that goes wrong. Read the next
two paragraphs together; the second is the one that matters. Fallbacks are deliberately abridged —
29 of 293 are under 40% of their source's length — so the check never diffs prose and never looks at
length (except for byte-equality, which is a fact, not a threshold). It flags (a) something the
fallback asserts that its source does not, (b) something the source carries that the corpus itself
keeps ≥85% of the time or that is a safety signal at any retention, and (c) a fallback that is
secretly a literal copy:

| Rule | Fires when |
|---|---|
| `COPY-DRIFT` | The file declares `generated-from:` and its body no longer matches that file. |
| `UNSOURCED-MAGNITUDE` | A number-with-unit framed as a target/limit that its source does not contain. This is the fingerprint of commit `f2f0ccd`, where a fabricated "10-50k connections per Node process" was deleted from the agent and survived in the fallback. |
| `DANGLING-DISPATCH` | A routing-table row or load instruction naming an artifact absent from the source that no pack can supply. |
| `FRONTMATTER-LOSS` | A skill/command/agent fallback lost the `description:` it is dispatched on, an agent's `model:` contradicts the source, or `name:` is missing/wrong. |
| `NOT-AN-ARTIFACT` | A declared fallback with no frontmatter, no `## ` section, or below 40% of its class's Phase 4.0 depth floor — i.e. not a copyable artifact at all. |
| `SECTION-LOSS` | A load-bearing source section is gone. "Load-bearing" is the complete ≥85%-retention / n≥8 band measured over the pre-repair corpus — `Output`, `Hard rules`, `Forbidden`, `Failure modes`, `When to use`, `Procedure`, `Enforcement`, `Checklist`, `Context`, `Phases applied`, the `Phase N` skeleton, and 20 more; the derivation lists every one. Sections the corpus drops freely — `Related`, `Detectors`, `Pre-flight`, `Example findings`, `When to run` — are **not** checked. `Premise` and `Halt conditions` are below the band but are covered by `SIGNAL-LOSS` instead. |
| `SECTION-ORDER` | The sections that were kept appear in a different order than in the source. |
| `SIGNAL-LOSS` | The source carries a `> **Hard rule:` line, a halt block, a `## Premise`, or an agent `TRIGGER` clause and the fallback drops it. Matched on the block, not the heading spelling, so renaming `## Halt conditions` to `## Halt` is fine. |
| `UNDECLARED-COPY` | The fallback's body is byte-identical to its source and nothing declares it. Fix by adding a `generated-from:` header (then `COPY-DRIFT` holds it to the source line-for-line) or by re-cutting it as a real abridgement. |

**What check 8b does NOT catch — do not read a green run as a re-cut.** Every rule compares text
against text; none of them understands either file. The failure mode the check is named for is
half-covered:

- A source that **deletes a Hard-rules bullet** while the fallback keeps asserting the retracted
  rule → **0 findings**.
- A source that **flips a `MUST` to a `MUST NOT`** while the fallback keeps the old polarity →
  **0 findings**.
- A fabricated magnitude is caught only when its line frames it as a target/limit/ceiling *or* its
  unit is inherently a claim (`rps`, `connections per`). `200000 concurrent sockets per process`,
  `Redis Cluster handles 1000 shards comfortably`, `You MUST store session state in memory`,
  `use the ws.setMaxConnections() API`, and `follow RFC 9999` are all **missed**.

Commit `f2f0ccd` was caught by this check only because the fabrication happened to carry a unit noun
on the regex list. A source edit whose retraction is non-numeric is invisible here. The gate is a
floor on fallback integrity, not a certificate of fidelity — when you edit a source, open its
fallback.

Every violation known when the check landed is enumerated in
**`templates/packs/_fallback-baseline.md`** and suppressed to one counted WARN; anything not listed
is a hard FAIL. So:

- **Repairing a fallback** → fix it, then delete its line from the baseline. A line that no longer
  reproduces WARNs, so stale entries cannot pile up.
- **A new FAIL you believe is correct as-is** → add `<pack>/<name>  <RULE>` to the baseline *with a
  reason*. Silencing a finding you did not read is the exact failure this gate exists to prevent.
- The reason is **mandatory and mechanically enforced**: a baseline line with no trailing
  `# reason` suppresses nothing — the finding stays red and the gate WARNs that the line is inert.
- `bash scripts/validate-pack-consistency.sh --fallback-report` prints the full picture. The
  backlog it lists is **zero**; if a comment anywhere claims a larger one, the comment is stale and
  `templates/packs/_fallback-baseline.md` is the authority — a claim the gate now *checks*, because
  that sentence and the check's own header comment both went stale the day the backlog emptied.
  8b parses the "The backlog is N lines" sentence and FAILs when it disagrees with the entries. Safety-signal loss
  used to be the large ungated class here (227 of 292, 78%) on the grounds that it could not be
  told apart from abridgement; the repair pass closed all 227, which proved the opposite, so it is
  now gated as `SIGNAL-LOSS` at 0 of 293.
  Deleting the sentence is no longer cheaper than correcting it either: an existing baseline that
  advertises no count is itself a FAIL.
- **Two ratchets, and they are not interchangeable.** `_fallback-baseline.md` and
  `_topics-strategy-baseline.md` hold defects a human **read and blessed**, so a `# reason` is
  mandatory there. `templates/packs/_greenfield-budget.md` holds per-pack **counts** that nothing
  has blessed — zero-delivery topics, and boundary loss outside the `agents` class — and simply may
  not grow; regenerate with `bash scripts/validate-pack-consistency.sh --record-budget`. Use the
  count budget when the honest entry would be 51 boilerplate reasons nobody reads, and the reasoned
  ledger when there is an actual judgement to record.
- **Read the coverage, not just the rule name.** The closing gate / verdict rules evaluate the 80 of
  282 pairs whose *source* carries a done-condition; the `BOUNDARY-LOSS` hard FAIL covers the
  `agents` class only. Both ceilings are stated at the rules themselves. A green 8b run is a floor,
  never a certificate.

---

## 6. Why existing projects never auto-upgrade

A `git pull` here changes what *new* setups produce. It does **not** change how an already-configured
repository behaves, and that is deliberate — not an unfinished feature.

The reasoning: a target repo's `.claude/` and `ai/` are a mix of generated templates and things a
human wrote and validated on top of them. An automatic upgrade cannot tell the difference, so it
either overwrites work someone did (hard rule A04) or leaves half-merged content that nobody
reviewed. Worse, it would change an agent's behaviour in a working repository at a moment nobody
chose — the exact failure mode of "my AI setup started doing something different today and I don't
know why".

Upgrades are therefore explicit and staged:

| Command | What moves |
|---|---|
| `/setup-project --enhance` | Adds only what is missing. Never touches an existing file. |
| `/setup-project --refresh` | Backs up, extracts knowledge, re-detects, then applies **or ledger-rejects** each flagged row. Rejections persist in `.claude/_refresh-decisions.md` and are never re-proposed until the pack source actually changes. |
| `/setup-project --refine` | Deepens existing artifacts against the real code. Rewrites only `## Project-specific` blocks. |

What this means for you as a contributor: **pack `_version.json` bumps are the upgrade signal.**
Phase 1.1 reads them for drift detection at session start; a pack without a version stamp is
silently skipped by drift detection entirely. Bump minor for a new artifact, major for a rename or
removal (which also writes a `deprecated.md` mapping note), patch for a substantive body change.
Typo fixes don't need a bump.

Round-two deepening is also protected: user-authored sections are marker-bracketed and SHA-256
verified, and `scripts/test-refine-fixture.sh` simulates the byte-level write contract. If you touch
the marker tokens, that fixture is your gate.

---

## 7. House style

The repo has a voice. Match it.

- **Precise and dense.** Say the mechanism, not the vibe. "Injected as `additionalContext`, deduped
  on `session_id`" beats "smart context loading".
- **Honest about limits.** A gate comment that says what it does *not* cover is worth more than one
  that oversells. `lint-validator-parity.sh` exists solely to punish overselling.
- **No placeholders.** Hard rule A02. `<TBD:...>` is a recognised token in a few generation paths;
  everywhere else, ship real content or don't ship the file.
- **Cite, don't duplicate.** SOLID and clean-code prose lives in `templates/governance/`. Repeating
  it in a command is a gate failure, and a maintenance liability the day the principle is reworded.
- **Stack-neutral in universal docs.** If a sentence only makes sense to a React developer, it
  belongs in a pack or a `references/` file.
- **Bidirectional links.** When an agent references a sibling in `## Related`, add the reverse link.
- **Never name a private repo.** This repo is published and installed by other people; measurements
  taken against real codebases must cite the evidence without the identity. The two standing sources
  are **"the reference monorepo"** (a ~4.3k-file TypeScript monorepo, `apps/` · `libs/` · `prisma/`)
  and **"the sibling repo"** (a smaller frontend project set up from the same baseline). Keep the
  number and the finding, drop the name — `MEASURED on the reference monorepo: 8 of its 9 scoped
  rules were dead` says everything the original said. Illustrative project-specific headings use the
  `<Project>` placeholder. Before pushing: `git grep -iE '<your-client-names>'`. This was not
  hypothetical — 176 occurrences of two client repo names had to be removed from 26 files, six of
  them shipped to users, one of them a hook that installs into every consuming project.

**Commits:** Conventional Commits, scoped to the pack or subsystem, with the resulting version in
brackets when a pack version moves:

```
feat(ui-ux): /add-theme-variant — additive theme builder [1.23.0]
fix(apply-study-decisions): update decision handling for anchored files
chore(learning): bump to 1.3.2 for the graded sub-agent safety fix
```

**Changelogs:** the root `CHANGELOG.md` carries milestone history under `## [Unreleased]`. Per-pack
history lives in the `changelog` object of `templates/packs/<name>/_version.json`. Write the **why**
first — every good entry in this repo starts by naming the failure it closes.

---

## 8. PR checklist

Copy this into the PR description and tick honestly. An unticked box with a one-line reason is
completely fine; a silently skipped one is not.

```markdown
- [ ] I edited this repo, not `~/.claude/`. `./scripts/verify-sync.sh` is clean.
- [ ] I read the neighbouring files in the directory I touched and matched their shape.
- [ ] All 22 gates pass locally.
- [ ] New/changed command → documented in `docs/COMMANDS.md` (or `docs/REFERENCE.md`).
- [ ] Command corpus changed → re-ran `python3 scripts/gen-cheatsheet.py`.
- [ ] Pack content changed → `_version.json` bumped + a matching `## <version>` section added to that pack's `CHANGELOG.md`.
- [ ] New pack artifact → registered in `_topics.md` (valid trigger from `_trigger-vocabulary.md`).
- [ ] New rule → tier chosen deliberately; if always-loaded, `check-rule-budget.sh` still passes.
- [ ] New hook or hook change → fixtures added under `tests/hooks/cases/`.
- [ ] New validator → good/bad fixtures under `tests/validators/`, wired into the workflow only if green.
- [ ] Any `check_*` validator I cited is either implemented or explicitly disclosed as planned.
- [ ] Adapter/matrix change → all three of registry, adapters README, and parity matrix updated.
- [ ] Root `CHANGELOG.md` entry under `## [Unreleased]`, leading with the *why*.
- [ ] No secrets, no absolute paths from my machine, no placeholder text.
```

**Scope:** one concern per PR. This repo's changes fan out across twelve tools and twenty packs;
a mixed PR is genuinely hard to review and nearly impossible to revert cleanly.

**Not sure it belongs?** Open an issue describing the drift or gap you hit before writing the code.
"Here is the failure mode I ran into" is a better opening than a patch — half the gates in this repo
started as exactly that.

---

## 9. Code of conduct and security

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

**Do not open a public issue or PR for a security problem.** This tool writes into `$HOME`, ships
hooks that execute, and runs shell scripts on contributors' machines — see
[SECURITY.md](SECURITY.md) for the threat surface and the private reporting route.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
