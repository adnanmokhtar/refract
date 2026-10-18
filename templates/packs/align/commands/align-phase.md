---
description: "Executes one align phase row by row: find-and-align per row (route, re-detect, EQ/VC/FN proof class, fix rule first, proof ladder L0–L13, record), one commit per row, then hands the phase to /align-gate."
kind: command
pack: align
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /align-phase <N>

## The Premise (read this first, internalize, do not deviate)

**Discipline pointer:** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) — SOLID / clean-code closure vocabulary (single source of truth).

**The declared convention is the truth.** Every row in phase N cites the oracle that declares its convention — a rule at `error` in the resolved lint config, a line a human wrote in `ai/conventions.md`, an ADR, the glossary, the token set, a named wrapper (`oracle:` + quote + `oracle_tier:`). Every fix moves a live site onto that declaration. **Alignment enforces what the oracle already names; it never designs.** A row whose quote no longer resolves is AL-01 and stops; a generated (T2g) oracle is a ratification probe, never an edit.

**The agent's job is exactly this:** for each row in phase N, in plan order, run the `find-and-align` skill — the unit of work — and commit what it closes:
1. **ROUTE** — a row another pack owns (security, performance, data, error handling, dead code, SOLID, complexity, new copy, a declared API contract) moves to `routed (<command>)` with its audit id and no commit; a T2g oracle moves to `pending-ratification`.
2. **DETECT** — re-run the row's `detector_cmd`; 0 hits while the rule matched files → `archived-pre-existing` (aged out); a rule that matched 0 files halts `re-detect-vacuous`; a quote that no longer resolves halts `oracle-gone`.
3. **DECIDE** — the proof class: **EQ** (the swap is exact: value, defaults or catalog value equal), **VC** (a visible change: stops at `pending-approval` until a human writes `approval: <name>@<iso>`), **FN** (a declared idiom added, proven by a behaviour test). `@align-idiom-auditor` before any edit.
4. **FIX** — rule first where expressible; only the matched expression and the verb's footprint; tests, snapshots, fixtures, the class's lint config, baselines and oracle files are read-only.
5. **VERIFY** — the proof ladder L0–L13 (`find-and-align`'s `align-sweep-gate.py ladder`, plus lint / types / build / scoped tests, the zero computed-style diff for EQ, the approved visual diff for VC). The first FAIL reverts the row.
6. **RECORD** — one commit per row, the ledger row updated in the same commit.

**The agent does NOT:**
- Ask the user to validate whether the convention is correct. **The oracle IS the validation**; a convention a human has not written down is not a row (AL-02).
- Ask the user about cosmetic deviations. The closure verb and proof class are on the row; apply them.
- Surface "do you want option A, B, or C" prompts mid-run.
- Fill `approval:` on a VC row, or treat a visual diff as accepted. An agent never signs a visible change.
- Close a row another pack owns, or draft an ADR to legitimize a deviation that should be aligned.

**The agent ONLY asks the user when:**
- The fix would change observable behaviour beyond the row's proof class (an EQ row that is not exact: reclassify VC; a behaviour change: route elsewhere).
- The wrapper or helper the oracle names does not exist, or lacks the capability the raw call uses (oracle drift → `/setup-project --refine`; wrapper gap → `/unify-surfaces`).
- A heavy-tier row's impact analysis surfaces a consumer the planner missed.

That's it. Everything else is mechanical edits, batched into one end-of-phase summary.

**Heavy-tier rows are different.** Heavy rows (cross-package boundary, public API change, > 10 files, an auth / permission / tenant gate, a VC row on a shared component) require reviewer approval before merge AND a single-row-per-commit-per-PR review window. The phase batches trivial + standard rows into one PR; heavy rows ship as separate PRs within the phase, each with its own impact analysis, and wait at `pending-review`.

## When to use

- Default for executing a single phase from `/align-plan`.
- After `/align-rollback <N>` if you want to manually re-run rather than auto-resume.
- For supervision-required phases (heavy-tier rows; user wants to review per-row).

Use `/align-fast <N>` instead when you want one command to drive the whole phase + gate without human-watch pauses. Mirrors `/migration-fast` — runs one phase per invocation; scan + plan must have run already.

## The loop (per row)

For each ledger row in phase N, in the plan's dependency order (re-route callers before removing a raw twin; move a copy's callers before `dedupe`; renames last within the phase), run `.claude/skills/find-and-align/SKILL.md` Steps 1–6. The skill is the contract and it is complete; what follows is what this command adds around it.

### Before the first row

```bash
RUN=$(mktemp -d "${TMPDIR:-/tmp}/align-phase.XXXXXX"); export GIT_OPTIONAL_LOCKS=0
OM=$(find .claude/skills -path '*/convention-oracle/scripts/oracle-map.py' 2>/dev/null | head -1)
python3 -I "$OM" . --out="$RUN/oracle" > "$RUN/oracle.log" 2>&1; echo "oracle-map exit $?"     # L0 reads $RUN/oracle
PHASE_BASE=$(git rev-parse HEAD); echo "phase base $PHASE_BASE"
```

### The closure verbs

The closed **21-verb vocabulary** (`align-discipline.md` halt #4; `ai/patterns/align-guardrails.md § Anti-bloat merge gates`). A verb in neither group → halt; the fix is a refactor / redesign / feature, route elsewhere. Long-form worked procedures exist pack-side in `references/align-discipline-procedures.md § Closure-verb procedures`, which Phase 4.2 does not install; this summary is the contract.

**Structural verbs (net-lines ≤ 0 per row; the first `replace-with-shared` import is exempt):**

| Verb | Procedure (one-line summary) | Typical AL classes |
|---|---|---|
| `remove` | Delete the cited lines (a reasonless suppression, a banned import with its replacement already in place). Re-grep; any remaining inbound import = halt + revert. | AL-29 |
| `inline` | Substitute a wrapper body inline at its single call site; delete the wrapper. Two or more consumers → mis-classified, `/refactor`. | — |
| `dedupe` | After the differential test (V403) shows copy = canonical on the copy's call-site inputs, replace the copy with the named helper's import. Diverged → `/quality-fix`. | AL-13 |
| `rename-comment-out` | Delete cited comment line(s). No code change. | — |
| `replace-with-shared` | Replace the hit expression with the named wrapper, token or key; one import added, one removed. The wrapper's defaults must reproduce the call's props (else VC). | AL-11, AL-14, AL-22, AL-05, AL-12, AL-26 (EQ key), AL-30 |

**Functional verbs (small + budget; every added block cites `idiom_cited`):**

| Verb | Procedure (one-line summary) | Use in align |
|---|---|---|
| `add-gate` | Wrap the action with the project's **declared** gate (`<Can>` or its equivalent, named by the oracle). FN: a render test as the role that must not see it, failing first (V401). | AL-15, AL-28 in the AL-15 form |
| `rename` | Apply the declared naming rule: a file by `git mv`, an identifier by the language server; no wire, DB, env or generated name (those go to `/refactor` + ADR). Serialised names unchanged (V402). | AL-16, AL-17, AL-18 |
| `extract-to-shared` | Move a block to a **pre-named** idiom the oracle declares. Forbidden to extract to a new helper. | AL-19 (a declared barrel or module) |
| `inline-magic-to-named-const` | Replace a magic value with a named const from the declared constants module. | AL-32 when the ADR names the const |
| `parameterize`, `escape`, `move-to-secrets`, `add-validator`, `bump-dep` | Security verbs. Security rows are `/security-fix`'s (always installed): these never run here. | — (routed) |
| `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `inline-filter-to-query` | Performance and data verbs. Rows go to `/perf-fix` / `/db-fix` when installed; without those packs, the carve-out applies an idiom the oracle already names with a baseline **measured** by a failing-first test (`find-and-align` Step 1). | carve-out only |
| `split-extract` | SOLID rework. Routed to `/quality-fix` / `/optimize`. | — (routed) |

**Touch only files in `scope`**, and inside them only evidence lines and the verb's footprint (`/align-gate` check 5). A fix that needs a file outside `scope` halts; the row was mis-scoped at scan time.

**No new abstractions.** Even functional verbs use the project's pre-named idioms. If the idiom needed doesn't exist, halt; route to `/setup-project --refine` to declare it first.

### VERIFY — the ladder, then the phase checks

`find-and-align` Step 5 runs the ladder per row and writes `$RUN/ladder-<id>.json`. Do not mark a row fixed until every applicable step is PASS or PASS-flagged; a `NOT RUN` step is listed with its reason and makes the row `(static EQ)` or Unconfirmed, never verified. In summary:
- **L0** oracle resolves · **L1** VC approval present · **L3** no whitespace-only change and no test, snapshot, fixture, lint-config, baseline or oracle file · **L4** line-level scope · **L5** re-detect zero · **L6** one way per pattern · **L7** emitted names declared · **L8** token round-trip (`token-map.py`, ui-ux) · **L9** class rule at error, lint, types (`tsc --noEmit --incremental false`), build, scoped tests · **L10a** EQ: zero computed-style or compiled-CSS diff · **L10b** VC: visual diff at `maxDiffPixels: 0` with the human approval · **L11** ratchet shrink-only · **L12** test and assertion counts not down, coverage within tolerance (`ai/patterns/align-guardrails.md § Coverage tolerance`) · **L13** non-vacuous.

After the last row, run the run-level steps once over the whole phase so far, so a before-value resolved two ways by two rows fails here and not at the gate:

```bash
G=$(find .claude/skills -path '*/find-and-align/scripts/align-sweep-gate.py' 2>/dev/null | head -1)
for c in consistency scope lock-paths names ratchet; do
  TMPDIR="$RUN" python3 -I "$G" "$c" --repo=. --base="$PHASE_BASE" --ledger=ai/align/ledger.md --json > "$RUN/phase-$c.json"
  echo "phase $c exit $? (0 PASS · 1 FAIL · 4 NOT RUN)"; done
```

### RECORD — update the ledger row + commit

- `fixed`: `status: fixed`, `fixed_at`, `commit`, `gaps_closed` (= `len(evidence)`), `proof_class`, `proof:` (the V-numbers that passed and `$RUN/ladder-<id>.json`); `approval:` only as a human wrote it; `notes: ""` (trivial) OR a 20–200-char rationale (standard) OR `impact_analysis_path: ai/align/impact/<id>.md` (heavy, then `pending-review`).
- `routed`, `pending-approval`, `pending-ratification`, `archived-pre-existing`: no commit; the fields `ai/patterns/align-ledger.md` § Record format lists for that state.
- Commit: `align/<phase-N>/<row-id>: <one-line description>` — one row per commit. Body cites the evidence, the oracle line and the closure verb.

If any step fails: mark the row `status: halted`; write `ai/align/halts/<row-id>.md` with the failing step, its ladder line and the destination; revert the row's edit; do NOT advance the row.

## Phase-end batched summary

After all rows in phase N have been processed, surface ONE summary to the user:

```
Phase <N> — <theme> — complete

Rows processed:               <N>
  Fixed:                      <F>   (EQ <E> · FN <Fn> · VC <V> approved)
  Routed:                     <R>   (<command> × k …)
  Pending approval:           <A>   (VC, no human approval yet)
  Pending ratification:       <G>   (T2g oracle)
  Pending review:             <P>   (heavy)
  Archived (aged out):        <O>
  Halted:                     <H>

Cumulative diff:
  Lines added / removed:      <added> / <removed>   (structural rows net <net>, must be ≤ 0)

Ladder (per row, worst step):
  L5 re-detect zero           PASS (<F> rows)
  L10a zero style diff        PASS <E> · (static EQ) <S> with probes
  …
Phase-level sweep gate:
  consistency                 PASS (<K> before-keys, 1 after each)
  scope · lock-paths · names · ratchet   PASS · PASS · PASS · SKIP (no baseline file)

Mechanical:
  Lint / typecheck / build    PASS
  Scoped tests                PASS (<X> tests; count <base> → <head>)
  Coverage                    <pre>% → <post>% (tolerance 0.5 pp)

Halts (require resolution before /align-gate):
  <row-id>: <ladder step> — <reason> → <destination>

Next:
  /align-gate <N>             (the 17-check matrix; advances the phase)
  /align-park <id> <reason>   (park a halted row)
  /align-rollback <N>         (undo this phase if rethink needed)
```

## Project-specific anchors

> - **Test runner**: `<extracted>` (e.g., `vitest`, `pytest`)
> - **Lint command**: `<extracted>`
> - **Typecheck command**: `<extracted>`
> - **Coverage command**: `<extracted>`
> - **Computed-style / visual harness** (UI rows): `<extracted>` (Playwright, or none → `(static EQ)`)
> - **Detector commands per class**: each row's own `detector_cmd`, written by `/align-scan`

## Pre-flight checks (before starting the loop)

1. `/align-plan` has been run; `ai/align/plan.md` exists; phase N exists in plan.
2. Mechanical pass: `lint`, `typecheck`, `build`, `tests` — all green at HEAD. If red, halt; pre-existing red drowns alignment changes.
3. No uncommitted changes in working tree (`git status --porcelain` empty). If dirty, halt; user-error.
4. Current branch is NOT main / master (or is, with explicit `--allow-main` flag — risky default).
5. The ledger has rows with `phase: <N>` and `status: planned` (or `detected`). If 0 rows, halt; nothing to do.
6. A declared convention resolves: the oracle map has at least one T1 or T2 row (inventory fallback `_extracted-idioms.md` → `codebase-profile.md` → `ai/conventions.md`).
7. `find-and-align`'s `align-sweep-gate.py` is present. A missing **tool** (`token-map.py`, a browser) is not a pre-requisite: its ladder step prints `NOT RUN`.

If any pre-flight fails → halt + report.

## Optional flags

- `--dry-run` — run ROUTE, DETECT and DECIDE only (`find-and-align --dry-run`), report what would happen, no edits.
- `--start-from=<row-id>` — resume from a specific row (e.g., after manual halt resolution).
- `--stop-on-halt` — halt the entire phase on the first row halt. Default: continue with remaining rows; surface all halts at the end.
- `--heavy` — require single-row-per-commit + reviewer approval prompt for every row in the phase (default: auto-applied to heavy-tier rows only; this flag forces it for all rows).
- `--max-parallel=<N>` — cap parallel row processing (default: 1 = sequential). Rows with overlapping `scope` files always serialise, and only this command commits (`ai/patterns/align-guardrails.md § Parallel race serialization (per-file lock)`).

## Mechanical halt — refuse to violate the closure-verb vocabulary

Forbidden in this command:
- Introducing any new symbol (function / class / type / interface / file) the oracle does not name. Validator `check_no_new_symbols`.
- Net-positive line count on a structural row.
- Touching files outside the row's `scope`, or lines that are neither evidence nor footprint.
- Editing a test, snapshot, fixture, the class's lint config, a baseline or an oracle file (`ai/conventions.md`, `ai/architecture.md`, `_extracted-idioms.md`, ADRs, lint configs).
- Skipping a ladder step, or counting a `NOT RUN` step as PASS.
- Bundling multiple rows in one commit.
- Closing a row another pack owns instead of routing it.
- Writing `approval:` on a VC row.
- Marking a row `fixed` when `gaps_closed != len(evidence)` (gap-count parity), or without re-detect returning 0 hits.

Each halt writes `ai/align/halts/<row-id>.md` and surfaces in the end-of-phase summary. The phase cannot advance through `/align-gate` until every halt is resolved (fixed manually, parked via `/align-park`, or rolled back via `/align-rollback`).

## Hard rules

- **Every row cites its oracle**, and L0 re-checks the quote before any edit.
- **Prove by class.** EQ by a zero diff, VC by a named human approval, FN by a behaviour test that fails first. Deterministic ladder steps run before any reviewer; a judge can move PASS to `pending-review`, never FAIL to PASS.
- **No new abstractions.** Functional verbs use the project's pre-named idioms; inventing new ones is forbidden.
- **Net-lines rule by verb group:** structural ≤ 0 per row; functional small + with idiom citation.
- **One row = one commit.** Bundling hides regressions.
- **Re-detect after every fix.** A fix that doesn't close the fingerprint is a halt.
- **Tests are read-only.** A swap that "needs" a snapshot update was not EQ (`align-discipline.md` halt #7).
- **One way per pattern** across the phase (AL-33).
- **Route, do not absorb.** Security, performance, data and quality rows go to their owners' fix commands.
- **No oracle modification.** Declarations change via `/setup-project --refine` or an ADR, never in this command.
- **Heavy-tier rows reviewed before merge** (`reviewer_approval: <name>@<iso>`).

## Failure modes

- **Pre-existing mechanical red** — fix mechanical first via `/check-health`.
- **A detector command matched 0 files** — `re-detect-vacuous`: the row's `detector_cmd` is wrong, not the code clean; fix the detector, never archive the row.
- **Test suite is slow** — scoped tests preferred over full suite; if scoping isn't possible, halt and configure the project's test-by-file pattern.
- **An EQ swap shows a computed-style difference** — reclassify VC; the row stops at `pending-approval`.
- **Mid-row commit hook fails** — pre-commit hook (lint / format / etc.) modifies files; treat as part of FIX (re-run VERIFY after hook); if hook fails non-deterministically, halt the row.
- **Heavy row needs cross-repo change** — halt; route to `/cross-repo-task`; mark `status: halted` with `reason: cross-repo`.
- **Reviewer not available for heavy row** — the heavy row waits at `pending-review` (continue trivial / standard rows); surface in end-of-phase summary.

## Related

### Agents
- `.claude/agents/align-idiom-auditor.md` — dispatched at DECIDE and again at VERIFY per row; owns audit halts #6, #9, #10 and the enforce-existing-vs-introduce-new boundary.
- `.claude/agents/align-gate-auditor.md` — runs after this command via `/align-gate <N>`; its 17-check matrix is what this command's rows are being prepared for.

### Sibling commands in align pack
- `/align-scan` — runs first; the audit that writes the rows.
- `/align-plan` — runs before this command; produces the phased plan.
- `/align-gate <N>` — runs after this command; validates artifacts and advances the phase.
- `/align-fast <N>` — one-shot variant (this command + gate, waves, no human-watch pauses).
- `/align-park <id> <reason>` — park a halted row.
- `/align-rollback <N>` — undo this phase.
- `/align-status` — read-only progress reader.

### Skills
- `.claude/skills/find-and-align/SKILL.md` — the per-row loop and proof ladder; its `scripts/align-sweep-gate.py`.
- `.claude/skills/convention-oracle/SKILL.md` — the oracle map L0 reads.
- `.claude/skills/align-detect/SKILL.md` — the class ledger (owner, closer) ROUTE reads.

### Cross-pack references
- `code-quality/commands/simplify.md` — closure-verb vocabulary inherited.
- `ui-ux/skills/design-token-audit/` and its `token-map.py` (when the ui-ux pack is installed) — the token classifier behind L8 and the EQ/VC split.

### Rules and snippets
- `.claude/rules/align-discipline.md` — the discipline this command enforces.
- `precedents/align.md`, `proof-oracles.md` § Align (V389–V408).

### Patterns
- `ai/patterns/align-ledger.md` — schema for the ledger this command updates.
