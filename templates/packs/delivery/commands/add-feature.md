---
description: Build a feature as a run — risk tier chosen before code, then requirements, design, a locked acceptance contract, one writer at a time, parallel read-only reviews and an independent verdict, scaled by tier (T0 direct edit … T3 full chain with human gates). Any stack; lanes backend/frontend/mobile. Not for bugs (/fix-bug) or refactors (/refactor).
kind: command
pack: delivery
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task, Skill]
---

# /add-feature <description | specs/<file> | Spec-ID> [--lane=<lane>[,<lane>]] [--tier=T<n> --reason="…"] [--yes] [--plan]

> **`--plan`**: honours the universal handoff flag — [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md).
> The run stops after P5 with the contract locked and `plan.md` written; `/execute-plan ai/runs/<run-id>/plan.md`
> resumes it at P6. When planning from a spec the plan carries `Spec: <Spec-ID>`.

## The Premise (read first, do not deviate)

**A feature does not start with code.** It starts with a risk tier chosen by a script, a written
requirement, a design, and a finite list of acceptance criteria that are written, failing and
locked before any production line exists. Then exactly one writer builds it, read-only lenses
review it in parallel, and an agent that did not build it decides whether it is done.

**The tier decides the ceremony, never the baseline.** `.claude/scripts/risk-tier.py` classifies the
ask before code and re-classifies from the design and the diff; it only ever promotes. T0 is a
direct edit plus checks; T3 is every phase plus holdouts and four human gates. The matrix is one
file — `.claude/templates/governance/tiers.json` — and this command follows it. The engineering
baseline (`standards-gate.md`) fires at every tier.

**Every phase writes a typed artifact someone else checks.** The run lives in `ai/runs/<run-id>/`
under the contract in [`run-ledger.md`](../../../snippets/run-ledger.md): who writes which file, its
budget, its checker. You — the main session — are the orchestrator: you own `run.json`,
`ledger.md` and `plan.md`, you hold the human gates, and at T2+ you never edit source
(`artifact-ownership.sh` denies it during P6) and never author a role's artifact.

**Status comes from records, not from accounts.** A subagent's prose is never the result: you read
the artifact it wrote, the review a hook persisted, the verdict the verifier's hook stamped.

## Contract

```yaml
role: writer                                   # the orchestrator
inputs:
  required: [request]                          # the ask verbatim, a specs/ path, or a Spec-ID
  reads:    [.claude/templates/governance/tiers.json, ai/runs/{run_id}/*, .claude/skills/lane-{lane}/SKILL.md]
output:
  returns:  the Output block below
  writes:   [ai/runs/{run_id}/run.json, ai/runs/{run_id}/ledger.md, ai/runs/{run_id}/plan.md, ai/runs/.gitignore, ai/status.md]
  persisted_by: caller
status:     COMPLETE | INCOMPLETE | BLOCKED | NEEDS_INPUT | SPEC_CONFLICT | UNREVIEWED(<axis>)
verdict:    from ai/runs/{run_id}/verdict.json only
next:       the human (H4 merge) · /ship
```

## Roles — who runs each phase, and what happens when one is missing

| Phase | Agent (pack) | Missing → |
|---|---|---|
| P1–P2 | `@product-analyst` (delivery) | T1: you write the P1-lite file; T2+: `UNREVIEWED(requirements)` → INCOMPLETE |
| P1 check | `@requirements-reviewer` (delivery) | `UNREVIEWED(requirements)` → INCOMPLETE |
| P3 | `@ux-designer` *(ui-ux)* writes `ux.md`; `@ux-reviewer` *(ui-ux)* reviews it at P4 | the architect's UI slice in `design.md`; skip with `covered_by: design.md UI slice (P4)` |
| P4–P5 | `@architect`, `@architecture-reviewer` (delivery) | `UNREVIEWED(architecture)` → INCOMPLETE |
| P5 | `@test-engineer` (delivery), `@plan-critic` (delivery) | `UNREVIEWED(contract)` → INCOMPLETE |
| P6 | `@implementer` (delivery) · `@platform-engineer` *(devops)* for infra tasks · doc-writer *(documentation)* | T2+: never yourself — BLOCKED; infra task without devops → `HANDOFF UNROUTED (devops not installed)`, `@implementer` writes it |
| P7–P11 | `@test-reviewer` *(testing)*, `@code-reviewer` *(code-quality)*, `@security-auditor` + lenses *(security)*, `@performance-optimizer` *(performance)*, `@schema-reviewer` *(database)*, `@observability-reviewer` *(observability)*, `@ux-reviewer` *(ui-ux)*, `@architecture-reviewer` (conformance) + each lane's § Review tables | `UNREVIEWED(<axis>) — <agent> not installed (<pack> pack)`; the run ends INCOMPLETE naming `/setup-project --include=<pack>` |
| P12 | `@verifier` (repo-baseline) | `UNREVIEWED(acceptance)` → INCOMPLETE |

**The builder never grades its own work.** A missing reviewer is an `UNREVIEWED(<axis>)` line,
never a review you perform inline.

Every dispatch is a [delegation brief](../../../snippets/delegation-brief.md): `run_id`, the role's
input paths, the mode or lens, the return shape — never your narrative, never `ledger.md`.

---

## P0 — Intake and risk

1. **Is this a feature?** A bug report → `/fix-bug`; an enhancement of an existing surface's look →
   `/enhance-ui` *(ui-ux)* or `/polish`; convention drift → `/align`; an audit → its audit command.
   Each lane's § Intent gate (frontend) applies. Halt with the redirect; an explicit "run it anyway"
   proceeds and is recorded in the ledger.
2. **Lanes.** `--lane=` when given (a stack pack's `/add-feature.<stack>` passes it); otherwise from
   the ask's nouns and `.claude/codebase-profile.md` (UI noun → frontend; screen on a device →
   mobile; endpoint, job, table → backend; both sides of a button that calls an API → both). Read
   `.claude/skills/lane-<lane>/SKILL.md` for each lane; a lane whose skill is absent is reported, not improvised.
3. **Tier — before any code.**
   `python3 .claude/scripts/risk-tier.py --request="<the ask verbatim>" --json` (a spec:
   `--request-file=<spec>`). Record the tier and every reason. `--tier=T<n>` higher than computed is
   allowed; lower only here, with `--reason` (written to `forced_lower`; CI re-tiers from the diff).
   No signal at all reads T1; decision O3 still makes a feature with a write path or a UI surface T2
   as soon as the design or the diff shows one.
4. **T0 → no run.** Docs, copy, a typo, config with no runtime effect: make the edit, run
   `python3 .claude/scripts/gate-check.py --local`, add one line to `ai/status.md`
   (`<date> — <what> (T0, no run)`), output, stop. If the edit turns out to touch runtime behaviour,
   it is not T0: open a run at T1 and continue.
5. **Open the run (T1+).** Run id `<YYYYMMDD>-<slug>-<4hex>` (run-ledger § 1). Create
   `ai/runs/<run-id>/`, write `ai/runs/.gitignore` (`*/evidence/raw/`) if absent, `run.json`
   (`status: open`, `phase: P0`, the tier and its reasons, the lanes, every phase the tier skips in
   `skips[]` with what covers it — `.claude/schemas/run.schema.json`; validate with
   `python3 .claude/scripts/refract_records.py validate run ai/runs/<run-id>/run.json`) and
   `ledger.md` (run-ledger § 4). Mark P0 `done`.

**Phases by tier** (`tiers.json`; ✓ runs, L = lite, – skipped with `covered_by: tier T<n>`):

| | P1 | P2 | P3 | P4 | P5 | P6 | P7 | P8 | P9 | P10 | P11 | P12 | Human gates |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T1 | L | – | – | – | L | ✓ | ✓ | – | – | code-reviewer | – | ✓ | plan-critic for H2 · H4 |
| T2 | ✓ | ✓ | UI | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | H2 · H4 |
| T3 | ✓ | ✓ | UI | ✓ + threat model | ✓ + holdouts | ✓ | ✓ + PBT, mutation | ✓ | ✓ | ✓ | ✓ + release.md | ✓ | H1 · H2 · H3 · H4 |

## P1 — Requirement

- **T2/T3:** dispatch `@product-analyst` — `run_id`, `request` (or the spec path), `return: DONE |
  NEEDS_INPUT | BLOCKED`. It writes `requirements.md` (EARS, REQ-/AC- ids, an `IF … THEN` per
  story, unchanged behaviour, success + counter-metric, open questions as options).
- **T1 (lite):** you write `requirements.md` yourself — ≤5 EARS criteria, each story with an
  `IF … THEN` clause, same format.
- `python3 .claude/scripts/ears-lint.py ai/runs/<run-id>/requirements.md` — green, or back to the writer.
- Dispatch `@requirements-reviewer` (run mode, lens `requirements`); read
  `reviews/requirements-reviewer-requirements.json`. IMPORTANT findings go back to the writer;
  round 2 admits IMPORTANT only; a third round escalates to the human (`posting-bar.md`).
- **Exit:** ears-lint green · no IMPORTANT finding standing · no open question that changes the
  design (ask the human now — a question with options, not a verdict). A new T3 signal in the
  requirements → `risk-tier.py --run=<id> --request-file=ai/runs/<id>/requirements.md --write`.

## P2 — Analysis (T2, T3)

Dispatch `@product-analyst` again for `## Impact` (prior-art search, affected modules — from
`build-graph.py --who-breaks` when the graph exists —, NFR → QA refs) and the draft
`quality-attributes.md`. A near-duplicate capability is `NEEDS_INPUT`: extend, replace, or a
deliberate parallel. Then `python3 .claude/scripts/trace-matrix.py <run-id> --phase=analysis` and
`@plan-critic` (`phase: P2`).
**H1 (T3):** show the human `requirements.md` and `quality-attributes.md`; on approval append
`approvals[]` `{gate: H1, by: human, artifacts: [{path, sha256}]}` (`shasum -a 256 <file>`).

## P3 — UX (UI lanes, T2/T3)

**ui-ux pack installed:** dispatch `@ux-designer` (`run_id`). It writes `ai/runs/<run-id>/ux.md` —
flows, the `## State matrix` (the `state-matrix` skill's design mode: a row per surface × state in
`THR-UI-STATES`, each `n-a` with a reason or naming the story or test that will force it, one row per
`IF … THEN` clause), interface contracts, a11y and i18n notes — and lints it before it returns:
`python3 .claude/skills/state-matrix/scripts/state-matrix-lint.py --run=ai/runs/<run-id> --phase=design`.
`NEEDS_INPUT` → ask the human; the architect then reads `ux.md` at P4.

**Without it:** the UI design lives in the lane skill's *Phase 2 design slice* that `@architect`
writes into `design.md`, with the same `## State matrix` section in the same format. Record
`skips[]: {phase: P3, covered_by: "design.md UI slice (P4)"}`; the state-matrix lint is not installed,
so G12's computational half reports `UNVERIFIED` for the run.

## P4 — Architecture (T2, T3)

Dispatch `@architect` (`run_id`; it reads the lanes' § Binding constraints itself). It writes
`design.md` (constraints table first, then components, frozen `§ Interfaces`, data model, failure
modes, `§ Work split`), completes `quality-attributes.md`, writes `threat-model.md` at T3 and an ADR
per new primitive or dependency. Then:

- `python3 .claude/scripts/risk-tier.py --run=<id> --files-from=ai/runs/<id>/design.md --write` —
  the predicted file set through `ai/risk-map.json` and the graph; a promotion re-opens phases.
- `@architecture-reviewer` mode `design`; at T3 also `@security-auditor` on `threat-model.md`
  (lens `security-threat-model`); `@ux-reviewer` on `ux.md` or the UI slice when installed, after
  `state-matrix-lint.py --run=ai/runs/<run-id> --phase=design` passes (a named, not-yet-written test
  passes here; at the gate, G12 requires it to exist).
- **Exit:** every binding constraint satisfied or waived with a reason (the mechanical gate the
  stack add-features always had) and no IMPORTANT finding standing.

## P5 — Technical design, contract and plan

1. `@architect` confirms `§ Interfaces` and `§ Work split` are buildable (T2/T3).
2. `@test-engineer` (T2/T3; you at T1): `test-plan.md`, `acceptance.json` (the run's tier, one
   criterion per AC with the EARS sentence verbatim, negative criteria for every authorization rule
   and failure clause, `unchanged` from the requirements), the acceptance tests — each seen **red**
   through `bash .claude/hooks/test-lane.sh record '<cmd>'` — and, at T3, holdouts in
   `.claude/holdouts/<run-id>/`. Follow [`acceptance-contract.md`](../../../snippets/acceptance-contract.md) §§ 2–3.
3. **Behavioural baseline — captured now, before any production line** (proposal §7 rule 1). The tree
   is still the base sha. `@test-engineer` (you at T1) runs the testing pack's `characterize` skill on
   every pre-existing entry point `design.md` names (T1: the files the tasks name) and their importers
   in `.claude/_graph.json`, then `bash .claude/scripts/baseline-capture.sh capture --run=<run-id>`
   (T1: `--paths=<file>,…`) → `.claude/baselines/<base-sha>/manifest.json`, which also re-captures every
   registered entry whose scope the design meets (api-snapshot, schema-diff, visual-check …). A criterion
   that deliberately changes recorded behaviour says so in `acceptance.json` before the lock —
   `"changes_baseline": ["<entry>/<case>"]`; G14 (`behavior-diff.py`, via `gate-check.py`) fails any
   difference no criterion declares, and `test-integrity.py` fails a golden file re-recorded without one.
   Nothing pre-existing in scope (a new module only) → ledger line `baseline: n-a — no pre-existing
   behaviour in scope`; testing pack absent → `UNREVIEWED(baseline)`.
4. You write `plan.md`: the 8-header plan schema (`.claude/plans/README.md`), `## Constraints`
   carrying `design.md § Constraints` and the fired standards rows, each task one line under
   `## Steps` — `- T-001 (AC-001, AC-002) [lane: backend] <step>` — in dependency order.
5. `python3 .claude/scripts/trace-matrix.py <run-id> --phase=plan` — REQ → AC → task → test with no
   orphan. Then `@plan-critic` (`phase: P5`).
6. **H2 — one combined gate** (T2/T3). Pause once and show everything the human needs:

   ```
   Run:          ai/runs/<run-id>/ — tier <T> (<reasons>)
   Requirements: <stories · criteria · unchanged · out of scope>          requirements.md
   Constraints:  <each binding constraint + how the design satisfies it>   design.md § Constraints
   Design:       <components · interfaces · data model · failure modes>   design.md
   Contract:     <N> criteria (EARS), tests written and red; <k> holdouts  acceptance.json
   Baseline:     <n> entries captured @<base-sha>; <d> declared changes     .claude/baselines/<base-sha>/
   Plan:         <tasks by lane>                                           plan.md
   Critic:       <plan-critic's top findings, or none>                     reviews/plan-critic-plan.json
   Open:         <anything still undecided — each with its options>
   ```

   On approval: `approvals[]` `{gate: H2, by: human, artifacts: [requirements.md, design.md,
   acceptance.json, plan.md with sha256]}`, then `.claude/scripts/lock-acceptance.sh <run-id>`.
   **T1, and `--yes` at T2:** `@plan-critic` stands in — PASS (no IMPORTANT finding) is recorded as
   `{gate: H2, by: plan-critic}`. `--yes` never stands in for H2 at T3, nor for H1, H3 or H4.
7. Building against an unlocked contract, or before the baseline is captured, is not allowed. `--plan` stops here.

## P6 — Implementation (one writer at a time)

- **T2/T3:** dispatch `@implementer` once per task, in `plan.md` order — `run_id`, `task: T-###`,
  `lane`; it reads its slice, the interfaces, the lane skill. One task at a time; mark each task done
  in `plan.md § Status`. At T3, tasks with disjoint paths in `§ Work split` may run as parallel
  implementers with `isolation: worktree`; you integrate, and two writers never share a file.
- **Infra tasks — one writer of CI / IaC.** A task whose paths are CI files, a Dockerfile or compose
  file, an IaC root or manifests (`python3 .claude/scripts/ownership-guard.py who <path>
  --agent=platform-engineer` says `allowed`) goes to `@platform-engineer` *(devops pack)*, not to the
  implementer: `run_id`, `task: T-###`, the paths, and the `design.md` slice it serves. It returns
  `DONE <paths> + plan/diff/dry-run output`; no apply, deploy or tag push happens in P6
  (`guard-irreversible.sh`). It is the only writer of those paths while the run is open —
  `ownership-guard.py` denies them to every other agent — so a task mixing source and infra is split
  into two tasks in `plan.md`. **When the devops pack is not installed**, record
  `HANDOFF UNROUTED (devops not installed) — T-### infra paths written by @implementer` in `ledger.md`
  and dispatch the implementer as usual.
- **T1:** you may build directly, following the lane skill's Phase 3–4.
- Returns: `DONE` → next task; `SPEC_CONFLICT` → stop, end the run **BLOCKED**, show the human the
  criterion, the requirement and the evidence (only a human reopens the lock);
  `NEEDS_INPUT` → ask; a red criterion after `THR-LOOP.fix_loops_max` fix loops → INCOMPLETE.
- After the last task: `python3 .claude/scripts/risk-tier.py --run=<id> --diff --write`. A promotion
  back-fills the phases it re-opened before P7.
- **P6b docs:** the lane skill's Phase 5 Update, by `@doc-writer` *(documentation pack)* — the
  `Spec: <Spec-ID>` backreference at every tier.

## P7 — Testing

`bash .claude/hooks/test-lane.sh run '<full suite>'`; `python3 .claude/scripts/gate-check.py --local
--only=G0,G1,G2`; `python3 .claude/scripts/trace-matrix.py <run-id> --phase=build`. At T2/T3
`@test-engineer` adds the E2E and property tests `test-plan.md` names (outside the lock), and
`@test-reviewer` *(testing pack)* reviews test strength (lens `test`). Mutation per `THR-MUTATION`
(T2 core paths, T3 all changed code) when the testing pack's `mutation-probe` is installed;
otherwise `mutation: not measured`.

## P8–P11 — Reviews: ONE parallel fan-out of read-only lenses

Send every lens in a single message (reading tasks parallelise safely; the verdict keeps the order
security → performance → code → observability). Each gets a brief with `run_id`, `lens`, the diff
(`<base>..HEAD` or the working tree) and the touched paths, and returns `refract/findings/v1`;
`persist-review.sh` writes `reviews/<agent>-<lens>.json`.

| Lens | T1 | T2 | T3 |
|---|---|---|---|
| `@code-reviewer` — correctness, conventions, contracts | ✓ | ✓ | ✓ |
| `@architecture-reviewer` mode `conformance` | – | ✓ | ✓ |
| security: `@security-auditor` (+ `auth-reviewer`, `tenant-isolation-reviewer`, `data-privacy-reviewer`, `api-security-reviewer` when their trigger fired) | floor only | ✓ | ✓ + `/security-audit` scoped to the diff |
| `@performance-optimizer` — N+1, unbounded queries, budgets in `ai/runtime/perf-budgets.md` | – | ✓ when a hot path or bundle is touched | ✓ |
| `@schema-reviewer` — migrations, constraints | – | ✓ on a schema change | ✓ |
| `@observability-reviewer` — instrumentation parity, `release.md` | – | ✓ | ✓ |
| `@ux-reviewer` — states, a11y | – | ✓ UI lanes | ✓ UI lanes |
| each lane skill's § Review / lens table | its T1 rows | its rows | its rows |

The lane floors (risk-bearing diff: minimal observability sign-off + diff-scoped security
pre-flight) apply at every tier. At T3 the operability lens also checks `release.md` (flag or kill
switch, migration order, rollback, staging checks, success-metric instrumentation). Review rounds
cap at `THR-LOOP.review_rounds_max`; a fix re-runs only the lens that found it.

## P12 — Final quality gate (the verdict)

1. **Refute.** Dispatch `@verifier` mode `refute` over `reviews/*.json` → `verdict-refute.json`.
   Confirmed IMPORTANT findings go back to P6 (a fix loop); unconfirmed ones name the probe.
2. **Accept.** Dispatch `@verifier` mode `acceptance` (`contract: ai/runs/<run-id>/acceptance.json`,
   holdouts at T3) → `verdict.json`.
3. `python3 .claude/scripts/gate-check.py --local` — G0 lock intact, G1 acceptance fresh PASS, G2,
   G3, G7 (lint, typecheck, standards, review), G12 state-matrix on a UI run (every touched surface has
   every state, each proof exists; shadow), G14 behaviour (every baseline entry in the touched scope
   re-run at HEAD; shadow), G15 signer ≠ author. G4 (performance entries, interleaved base/head) runs in CI.

| `verdict.json` | Run |
|---|---|
| PASS, fresh, signed `verifier`, gate-check clean | **COMPLETE** — `run.json` `status: closed`, `outcome: COMPLETE` |
| FAIL | fix the code (never the locked tests); ≤ `THR-LOOP.fix_loops_max` loops, then INCOMPLETE |
| CONCERNS | INCOMPLETE, naming the criterion and what would let it run |
| missing or STALE | not judged — re-dispatch; never COMPLETE |

**H4:** a human merges. P13 deploy is `/deploy-stage` (level D — the human types it, H3).

## Loop control and context

Caps from `THR-LOOP`: fix ≤3, review rounds ≤2, replans ≤2; two stalls → replan, a third → stop and
hand the human `ledger.md`. Update `run.json.loops` and the ledger at every phase. Before a
compaction `precompact-handoff.sh` writes `handoff.json` and steers the summary; after it,
`session-start.sh` prints the handoff — resume at its `next`.

## Output

```
/add-feature — <feature>   Status: COMPLETE | INCOMPLETE | BLOCKED (SPEC_CONFLICT) | NEEDS_INPUT
Run:        ai/runs/<run-id>/   tier <T> (<reasons>)   lanes <lanes>      (T0: "no run — T0")
Spec:       <Spec-ID>                                    (when built from a spec — every tier)
Phases:     P0 ✓ · P1 ✓ · … · skipped: <phase → covered_by>
Gates:      H1 <–|human> · H2 <human|plan-critic> · H4 pending
Contract:   <N> criteria locked · holdouts <k> · trace REQ→AC→T→test <n/n>
Baseline:   G14 <PASS|FAIL|N-A> — <n> entries same · <d> explained by an AC · <q> quarantined   (G4: CI)
Reviews:    <lens: PASS|CONCERNS|FAIL> … · UNREVIEWED(<axis>) …
Verdict:    ai/runs/<run-id>/verdict.json — PASS | FAIL | CONCERNS (fresh | STALE)
Standards:  <N> fired — <M> MET · <K> n-a · <U> UNMET
Next:       /ship (commit + PR) · a human merges
```

## Hard rules

- The tier is chosen by `risk-tier.py` before code and only ever promoted; a lower tier is forced at
  P0 only, with a logged reason.
- No production code before the acceptance contract is written, red and locked, and the behaviour it
  touches is captured as a baseline (T1+).
- At T2+ you never edit source and never author a role's artifact — you dispatch the owner.
- One writer of source at a time; parallel writers only at T3, in worktrees, on disjoint paths.
- A missing reviewer is `UNREVIEWED(<axis>)` and the run is INCOMPLETE — never an inline self-review.
- COMPLETE only from a fresh PASS `verdict.json` signed by the verifier.
- `SPEC_CONFLICT` ends the run BLOCKED; only a human reopens a locked contract.
- `--yes` never replaces H1, H3, H4, or H2 at T3.

## Related

- Lane entry points: `/add-feature.backend`, `/add-feature.frontend`, `/add-feature.mobile` (the
  stack packs' thin presets of this command). Leaves: `/add-endpoint`, `/add-module`, `/add-page`,
  `/add-component`, `/add-crud-page`, `/add-screen` — single-file grain; they stay as they are.
- `/analyze-task` *(business pack)* — writes a spec this command consumes as its source.
- `/fix-bug`, `/execute-plan`, `/verify-plan`, `/ship` (repo-baseline).
- Snippets: [`run-ledger.md`](../../../snippets/run-ledger.md) · [`acceptance-contract.md`](../../../snippets/acceptance-contract.md) ·
  [`delegation-brief.md`](../../../snippets/delegation-brief.md) · [`posting-bar.md`](../../../snippets/posting-bar.md) ·
  [`refute-before-report.md`](../../../snippets/refute-before-report.md) · [`standards-gate.md`](../../../snippets/standards-gate.md).
