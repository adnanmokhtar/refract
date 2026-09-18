---
description: "Incremental V1→V2 sync. One command, full cycle: pull V1 from its remote → list the commits V2 hasn't absorbed → analyse what each change MEANS (business rules, validations, endpoints, DTOs, schema, API vs Web) → map V1-change→V2-implementation → port through V2's architecture (never copy/paste) → verify every hunk was accounted for → test → final independent audit → advance the sync watermark. Answers 'what landed in V1 since last time, and is all of it in V2 now'. `/migrate` ports the whole codebase once; this keeps V2 caught up commit-by-commit afterwards."
kind: command
pack: migration
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /migration-sync [<scope>]

## The Premise (read this first)

**V1 is still alive and still shipping. This command is how V2 keeps up.**

`/migrate` answers "is V2 at parity with V1 *as it stands today*" — it reads both trees whole and closes the gap. That is the right shape once, or after a long drift. It is the wrong shape for a Monday-morning "what did the V1 team merge last week": a whole-tree re-scan pays to re-read thousands of unchanged files and, worse, has no notion of *a change* — it cannot tell you that a validation rule was tightened, only that V1 and V2 currently differ.

`/migration-sync` is commit-delta driven. The unit of work is **a V1 change**, not a V1 file. It pulls, computes the commits V2 has not absorbed, and drives each one through the full cycle:

```
Pull → Analyze → Understand → Map → Implement → Verify → Test → Audit → Advance watermark
```

**The two rules that govern every step:**

- **V1 = What.** V1 is the source of truth for business requirements — the rules, constraints, validations, edge cases, and observable behaviour. What changed in V1 must exist in V2.
- **V2 = How.** V2 is the source of truth for architecture — layering, patterns, naming, shared/common components, services, repositories, domain logic, API shape, UI. **Copy/paste from V1 is forbidden**, including when the V1 code would compile as-is. If V1's implementation does not fit V2's architecture, the requirement is re-implemented V2's way.

Porting the *behaviour*, not the *implementation*, is the whole job.

## When to use

- "Pull whatever the V1 team merged this week into V2." → `/migration-sync`
- "Sync just the orders module." → `/migration-sync the orders module`
- "Sync from this release tag onward." → `/migration-sync --since=v1.42.0`
- "Show me what V1 changed and what it means — don't write code yet." → `/migration-sync --analyze-only`

## When NOT to use

- **V2 has never been brought to parity** → run `/migrate` first. Syncing a delta onto a V2 that is missing the feature the delta modifies produces a half-feature. `/migration-sync` halts on this (see § Bootstrap).
- V1 is frozen (`v1_status: frozen` in `_v2-anchors.md`) → there is no delta; use `/migrate --re-audit` for drift instead.
- One known feature, no interest in commits → `/find-and-fix <id>` or `/migration-recheck <description>`.
- Mid-feature work in V2 / dirty tree → finish and commit first (or `--allow-dirty`).

## Args

- `<scope>` (optional) — natural-language description or explicit path, resolved the same way `/migration-recheck` resolves one. Restricts the sync to commits touching that area; commits outside it stay unabsorbed and the watermark does not pass them (see § Watermark).

## Pre-requisites

- `_v2-anchors.md` has `v1_root` (and, for the pull, `v1_remote` / `v1_branch` — see § Anchors).
- `v1_root` is a git working copy (not a vendored snapshot, not a tarball). Not a repo → halt; `--no-pull` does not rescue this, because the delta itself needs git history.
- `ai/migration/ledger.md` exists and has rows — i.e. `/migrate` or `/migration-scan` has run at least once.
- V2 working tree clean (or `--allow-dirty`), mechanical CI green.

---

## Step 1 — Pull (bring V1 local up to date)

Never analyse a stale V1. The command's first act is to prove the local V1 equals its remote.

```bash
git -C <v1-root> status --porcelain          # must be empty
git -C <v1-root> fetch <v1-remote> --prune --tags
git -C <v1-root> rev-parse --abbrev-ref HEAD # must equal <v1-branch>, not detached
git -C <v1-root> merge --ff-only <v1-remote>/<v1-branch>
git -C <v1-root> rev-parse HEAD              # → v1_head
```

**Halts (all of them refuse rather than guess):**

| Condition | Why it halts | Escape |
|---|---|---|
| V1 working copy dirty | A pull over local edits either fails or silently stashes someone's work. | Commit/stash in V1, or `--no-pull` to analyse local HEAD as-is |
| V1 on a detached HEAD or a branch ≠ `v1_branch` | The delta would be computed against the wrong line of history. | Check out the right branch, or `--v1-branch=<name>` |
| `fetch` fails (no network, auth) | Analysing a stale V1 produces a sync that *looks* complete and is not. | `--offline` — explicitly proceeds from local HEAD, and stamps `offline: true` on the sync record |
| `merge --ff-only` rejects (local V1 has commits not on the remote) | Someone committed into the V1 clone. Merging is not this command's call. | Resolve in V1, then re-run |

`--no-pull` skips this entire step (local HEAD is taken as the truth) and is recorded in the sync record as such. It does not skip the halts about V1 being a git repo.

## Step 2 — Delta (which commits has V2 not absorbed?)

The watermark lives in **`ai/migration/sync-state.md`**:

```yaml
---
last_synced_v1_commit: 7a3b9c1        # every V1 change up to and including this sha exists in V2
last_synced_at: 2026-09-18T09:12:00Z
last_sync_run: sync-2026-09-18-0912
v1_remote: origin
v1_branch: main
offline_runs: 0
deferred:                              # commits deliberately NOT absorbed; they do NOT block the watermark
  - commit: 4f1e2d3
    reason: dead-v1-code — 6-axis check, zero callers
    decided_at: 2026-09-11
    evidence: ai/migration/sync/2026-09-11/analysis.md#4f1e2d3
---
```

Delta computation:

```bash
git -C <v1-root> log --first-parent --no-merges --reverse \
    <last_synced_v1_commit>..<v1_head> -- <paths-if-scoped>
```

The `--first-parent` walk keeps the mainline; merge commits are expanded to their file changes, not treated as atomic units. Commits already listed under `deferred:` are skipped with their recorded reason re-printed (never silently).

**Bootstrap — no `sync-state.md` yet:**

1. `--since=<sha|tag>` given → use it, write the watermark, proceed.
2. Otherwise derive a candidate from the ledger: the oldest `v1_commit_pinned` across all rows whose state is `done` / `V2-only` / `V2-canary`. **Report it and halt** — do not auto-adopt. A wrong bootstrap silently skips every commit before it, which is exactly the failure this command exists to prevent.
3. `--bootstrap` records `v1_head` as the watermark and ports **nothing** — the declaration "V2 is at parity as of now". Only legitimate straight after a green `/migrate`; the command prints that caveat.

**Ledger coverage check (mandatory before analysis):** every V1 path touched by the delta is matched against ledger rows by `v1_path` prefix. A touched path whose *feature* has no row, or has a row in state `V1-only` / `pending`, means V1 changed something V2 never had. That is not a sync — the base feature is missing. Such commits are quarantined with `needs: full-port` and routed to `/find-and-fix <id>` (or a new `pending` row), and they do not block the rest of the delta.

## Step 3 — Analyze + Understand (what does each change MEAN?)

**This step reads V1 source and V1 history. It does not read V2 yet, and it writes no code.** Its output is `ai/migration/sync/<run-id>/analysis.md`, one section per commit (or per squashed group of commits touching the same feature).

Every section answers, with a `<path>:<line>` citation for each claim:

| Question | Where the answer comes from |
|---|---|
| What changed? | `git show <sha>` — the diff, plus the commit message and any linked issue |
| Which files / modules are affected? | Changed-path list, mapped to feature rows |
| API, Web, or both? | Path classification against `_extracted-codebase.md § Stack` + anchors (`v2_root` layout) |
| What business logic is new or modified? | The diff's non-mechanical hunks, read as behaviour |
| Which rules / constraints / validations changed? | Validators, guards, schema decorators, `if`-guards, error throws in the diff |
| DB / entity / DTO / endpoint changes? | Migration files, entity/model classes, DTO classes, route registrations in the diff |
| New feature or a modification of an existing one? | Ledger row exists for the touched feature → modification; no row → new |
| What else depends on this? | Reverse-grep of every changed exported symbol across V1 |

**Classification per commit** — exactly one of:

- `behaviour` — changes what the system does. Always ports.
- `refactor-only` — V1 internal restructuring, no observable change. **Does not port** (V2 has its own structure; copying a V1 refactor is the copy/paste failure wearing a hat). Recorded with the reasoning.
- `dead-v1` — touches code with zero callers on the 6-axis reachability check. Does not port; goes to `deferred:` with evidence.
- `mechanical` — formatting, lint, dependency bumps with no behaviour delta. Does not port.
- `needs: full-port` — the base feature was never ported (from step 2's coverage check).

A commit classified anything other than `behaviour` still gets its one-line justification in the analysis, and the justification is what the final audit (step 8) re-checks.

**`--analyze-only` stops here** and prints the analysis path. Nothing is written to V2, no ledger transition, no watermark move.

## Step 4 — Map (V1 change → V2 implementation, before any code)

For every `behaviour` commit, extend the feature's mapping doc — `ai/migration/mapping/<feature>.md`, the artifact `check_v2_mapping_doc` already validates — with a **V1 change → V2 implementation** table:

| V1 change (`<path>:<line>`) | Business requirement (the WHAT) | V2 implementation site (`<path>:<line>`) | Shared V2 entity reused | Behaviour delta |
|---|---|---|---|---|

Rules for filling it:

- The **"Business requirement"** column is prose about behaviour, never V1 code. If it can only be expressed by quoting V1's implementation, the analysis is not finished.
- **"Shared V2 entity reused"** comes from `_extracted-idioms.md` and `_v2-anchors.md § Shared component wrappers / composables`. An empty cell where V2 *has* a wrapper for that job is a mapping failure, not a style note — it is how duplicate logic enters V2.
- If V1's approach has no sane V2 equivalent, the row records the re-implementation and **why** V1's shape was not carried over.
- The map is authored **before** the edit. A mapping written afterwards documents what was typed, not what was decided.

## Step 5 — Implement (port through V2's architecture)

Each mapped feature is dispatched through the existing per-feature engine — this command adds no second porting path:

| Tier | Dispatch |
|---|---|
| trivial / standard | `/find-and-fix <id>` |
| heavy (or promoted by the primitive-count check) | `/port-feature <id> --heavy --unattended` |
| `needs: full-port` rows | `/port-feature <id>` on the whole feature, not the delta |

Parallelism: `--max-parallel` (default 6 trivial / 3 standard / 1 heavy). Commits touching the same feature are serialised in V1 commit order — a later commit may amend what an earlier one introduced, and porting them out of order re-creates a state V1 never had.

The dispatched loop already enforces the rules this command depends on, and they are restated here because they are the point of the command:

- V1 wins on observable behaviour (rules, validations, permission gates, error shapes, empty/null returns, navigation structure).
- V2 wins on structure (layering, wrappers, services, repositories, naming, API shape, lifecycle hooks, UI primitives).
- Reuse V2's shared/common layer wherever it covers the job; never introduce a second implementation of something V2 already has.
- Do not change existing V2 behaviour unless the V1 change requires it — and when it does, say so in the commit body.
- No new technical debt: the ported code obeys `core-discipline.md` (clean-code + SOLID) like any other V2 code.
- One commit per feature per sync run, message citing the V1 sha(s) absorbed: `port(<feature>): absorb V1 7a3b9c1..4d5e6f7 — <requirement>`.

## Step 6 — Verify (was every part of the V1 change accounted for?)

Completeness is counted, not felt. The mirror of the ledger's `gaps_in == gaps_closed`:

```
changes_in      = behaviour hunks in the V1 delta (per analysis.md)
changes_closed  = hunks with a resolution
```

Every hunk resolves to exactly one of: **ported** (cites V2 `<path>:<line>`), **intentionally-not-ported** (cites an accepted ADR with a `user_decision_quote`, or dead-V1 evidence), or **deferred** (cites a blocker id — cross-repo task, missing upstream endpoint). **There is no fourth bucket, and "not applicable" is not a resolution.** `changes_in != changes_closed` → the run halts before testing and names the unresolved hunks.

Then the per-axis checklist, over the delta only:

- every changed business rule present in V2;
- every changed validation present in V2, at V2's validation layer;
- every changed API endpoint / parameter / response shape reflected — request DTO, response DTO, and the Web caller;
- every changed Web/UI behaviour reflected — fields, affordances, event handlers, per-button permission gates, navigation structure;
- every dependency the analysis flagged reviewed, with a one-line verdict each;
- every important scenario/edge case from the V1 diff represented in V2 or in a parity test.

For UI-leaf pairs, the per-axis enumeration tables with `<v1-path:line>` / `<v2-path:line>` citations are mandatory regardless of verdict — a bare "clean" is a Trusted-Summary failure, and `validate-migration-artifacts.sh --feature <feature>` reports it when the agent runs the validator (agent-side discipline; nothing halts the run automatically).

## Step 7 — Test

Run, in this order, and report each result rather than a rollup:

1. **Typecheck / compile** — zero errors. A pre-existing error count is recorded as a baseline; new errors halt.
2. **Lint** — zero *new* findings against the pre-sync baseline.
3. **Unit + integration** — the suites covering the touched features, then the full suite if wall-clock allows.
4. **Parity tests** — generated via `parity-test-generate` for every non-trivial behaviour change, pinned to `v1_commit_pinned = <the absorbed sha>`. These are what prove the *rule* moved, not just the code.
5. **API ↔ Web contract** — when the delta touched both sides, assert the V2 Web caller matches the V2 API's actual response shape (captured sample in `ai/migration/api-samples/`, not inferred from caller code).
6. **Permissions / validations / business rules** — exercised explicitly, positive and negative case, for every gate the delta touched.
7. **E2E** — if a suite exists and the environment can run it.
8. **Boot check** — `smoke-verify` after the last commit. Green parity tests over an application that no longer boots is the Green-Suite Mirage; a sync that re-points imports onto V2 wrappers and re-registers routes is exactly when it happens. `--no-boot-check` skips it; the summary then reads `boot-check: skipped(<reason>)`, never silence.

**Where tests do not exist**, say so explicitly and do the best available verification (manual trace of the changed path, a written argument citing both sides). "No tests for this" is an acceptable report; an implied "tested" is not.

## Step 8 — Final audit (independent re-read)

The last pass is adversarial and **re-reads the raw V1 diff, not `analysis.md`** — an audit that trusts the analysis can only confirm the analysis's own blind spots. Dispatch `parity-auditor` per touched feature with the V1 sha range and the V2 commit range, hunting for:

- business logic in the delta with no V2 counterpart;
- a rule or constraint quietly dropped;
- an endpoint / parameter / response change with no V2 reflection;
- a Web/UI behaviour not carried over;
- **work done in an earlier sync (or by `/migrate`) that this delta reveals was wrong** — a row being `done` is not a defence. It is re-opened and corrected against V1's requirement, V2's way;
- anything ported only partially;
- anything ported in a way that does not match V2's architecture or standards (the copy/paste tell: V1 naming, V1 layering, or a hand-rolled equivalent of an existing V2 shared entity).

Findings re-enter step 5 in the same run. The run does not finish with an open finding; it finishes, or it reports the finding as a blocker.

## Step 9 — Advance the watermark (contiguous prefix only)

**The watermark moves to the newest commit such that every commit up to and including it is resolved** — ported, intentionally-not-ported, or deferred-with-a-record. Not the newest *ported* commit.

```
delta:   c1 ✅  c2 ✅  c3 ❌(blocked)  c4 ✅  c5 ✅
         └────────┘
watermark → c2.  c4 and c5 stay in the delta and are re-offered next run.
```

c4 and c5 are ported and committed — the work is not thrown away — but the watermark does not jump c3, because a watermark past an unresolved commit is precisely how a business rule disappears forever. The sync record lists them as `ported-ahead-of-watermark` so the next run recognises them and does not re-port them.

The run appends `ai/migration/sync/<run-id>/record.md` (commits carried, per-commit classification and resolution, ledger rows touched, V2 commit shas, test results) and updates `sync-state.md`. `--dry-run` and `--analyze-only` write neither.

---

## Flags

- `--since=<sha|tag>` — start the delta here instead of the watermark (bootstrap, or re-running a range).
- `--until=<sha|tag>` — stop here instead of `v1_head`. Useful to absorb one release at a time.
- `--bootstrap` — record `v1_head` as the watermark, port nothing. Only after a green `/migrate`.
- `--analyze-only` — stop after step 3. Writes `analysis.md`, no code, no watermark.
- `--plan` — read-only through step 4; writes a handoff plan to `.claude/plans/migration-sync-<run-id>.md` per `~/.claude/templates/snippets/plan-flag.md`. Hand to `/execute-plan <file>`.
- `--dry-run` — list the delta and each commit's classification, then stop.
- `--no-pull` — take local V1 HEAD as the truth; skip step 1's fetch/merge.
- `--offline` — attempt the fetch, proceed from local HEAD if it fails, stamp `offline: true`.
- `--v1-branch=<name>` / `--v1-remote=<name>` — override the anchors for this run.
- `--allow-dirty` — proceed with an uncommitted V2 tree (V1 dirtiness still halts).
- `--max-parallel=<N>` — cap concurrent feature dispatch.
- `--include-dead` — port `dead-v1` commits too (default: deferred with evidence).
- `--no-boot-check` — skip `smoke-verify`; the reason is recorded in the summary.
- `--re-audit-touched` — in step 8, re-audit every ledger row the delta touches in full, not only the delta's hunks. Slower; use when you suspect an earlier port of the same feature was wrong.

## Anchors

`_v2-anchors.md` carries the sync fields alongside `v1_root`:

```yaml
v1_remote: origin                    # default: origin
v1_branch: main                      # default: the upstream of v1_root's checked-out branch
v1_sync_state: ai/migration/sync-state.md
```

Missing `v1_remote` / `v1_branch` are defaulted as above and the defaults are printed. A wrong branch is worse than an absent one, so if `v1_root`'s branch has no upstream and no anchor is set, step 1 halts.

## Output

```
Sync complete

V1:                  <v1-root> @ origin/main
Absorbed:            7a3b9c1..4d5e6f7  (14 commits → 9 behaviour, 3 refactor-only, 1 mechanical, 1 dead-v1)
Watermark:           7a3b9c1 → 9c8b7a6   (stopped before 4d5e6f7 — blocked, see below)

Features touched:    5
  orders/checkout      API + Web   — refund-window rule 14d → 30d, DTO field added
  orders/list          Web         — status filter gains "partially-refunded"
  auth/session         API         — session TTL validation tightened
  ... (2 more)

Changes:             38 hunks → 34 ported, 3 intentionally-not-ported (ADR-0031), 1 deferred (XR-012)
Commits (V2):        5 (one per feature)
Diff:                +412 / -168

Tests:               unit 214/214 · integration 48/48 · parity 9/9 (3 new) · e2e not run
boot-check:          pass

Deferred (1):        4d5e6f7 — bulk-refund needs <api-repo> POST /v2/refunds/bulk
                     → /cross-repo-task register XR-012

Not validated:       e2e suite (no staging DB here) — run before merge
Risks:               the refund-window change touches the payment summary widget — manual smoke-check
Revert:              git revert a1b2c3d..f9e8d7c   (or per-feature: git revert <sha>)

Next: /migration-sync   (re-offers 4d5e6f7 once XR-012 clears)
```

## Hard rules

- **No copy/paste from V1.** Every ported hunk lands in V2's structure, through V2's shared layer. A V2 file that gains V1's naming, V1's layering, or a hand-rolled twin of an existing V2 wrapper is a defect, not a port.
- **The watermark never passes an unresolved commit.** Contiguous prefix only, no exceptions, no `--force-watermark`.
- **`changes_in == changes_closed`** before testing starts. Every hunk resolves to ported / intentionally-not-ported / deferred.
- **The final audit re-reads the V1 diff**, never `analysis.md`. An audit that reads the summary audits the summary.
- **`done` is not a defence.** A previously-ported feature the delta proves wrong is re-opened and fixed in this run.
- **Refactor-only V1 commits do not port.** Carrying a V1 internal restructure into V2 is the copy/paste failure with a better excuse.
- **Every claim cites `<path>:<line>`** — V1 side and V2 side.
- **The honesty block is mandatory**: `Not validated:` / `Risks:` / `Revert:` appear in every summary, before `Next:`. `Tests: N/N` alone is insufficient — name what did *not* run, or state `none — full suite ran`.
- **Offline runs are stamped.** A sync computed against a possibly-stale V1 says so in the record and in the summary.

## Failure modes

- **V1 not a git working copy** → halt. No delta is computable; `/migrate` is the tool for a snapshot-only V1.
- **No `sync-state.md` and no `--since`** → halt with the ledger-derived candidate printed. Never auto-adopted.
- **Delta touches a feature with no ledger row** → that commit is quarantined as `needs: full-port` and routed; the rest of the delta proceeds.
- **Delta is empty** → "V2 is current with `<v1-branch>` at `<sha>`", exit 0, no files written.
- **Huge delta** (default > 60 commits or > 400 changed files) → halt and suggest `--until=<tag>` to absorb release by release. A 300-commit sync in one run produces an audit nobody can verify.
- **Every commit blocked** → halt; the blockers list is the output, and the watermark does not move.

## Related

- `/migrate` — whole-tree parity port. Run it first; `/migration-sync` keeps V2 current afterwards.
- `/migration-recheck <description>` — ad-hoc spot-check of one area, no commit delta involved.
- `/find-and-fix <id>` · `/port-feature <id>` — the per-feature engines this command dispatches.
- `/cross-repo-task` — where deferred cross-repo blockers live.
- `/migration-status` — ledger view; `sync-state.md` is the commit-side companion to it.
