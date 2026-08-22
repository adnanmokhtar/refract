---
description: Reduce entropy in CHANGED code using four closed verbs (remove / inline / dedupe / rename-comment-out) with a mechanical net-lines ≤ 0 gate — it may only reuse what already exists and refuses to add a symbol. Anti-triggers: creating a new helper or performing a structure move is `/refactor`; whole-project architecture or measured perf work is `/optimize` (global); convention drift with no entropy angle is `/align` (global); ranking defects at target scale is `/audit` (global).
---

# /simplify [path]

Looks at staged + unstaged diffs and proposes specific simplifications with before/after diffs. Optionally applies them.

## The Premise (read this first, internalize, do not deviate)

**Existing patterns are the truth. Simplification means matching siblings, not innovating.** The repo already has a shape — helpers, base classes, repository pairs, error envelopes, validation primitives. Simplifying means: fewer lines, fewer abstractions, more reuse of what's already there. It does NOT mean: introducing a new helper, a new generic, a new strategy interface, a new base class, a new "cleaner" pattern the agent thinks is nicer.

**The closure verb is `remove-or-inline`.** Each candidate is one of:
- `remove` — delete dead branch / unused export / unreachable return / no-op wrapper.
- `inline` — fold a single-caller wrapper / factory / strategy into its only call site.
- `dedupe` — replace a local re-implementation with the existing helper (cite the helper's `<path>:<line>`).
- `rename-comment-out` — delete a `// gets the user` above `function getUser()`.

That's the entire vocabulary. If the simplification doesn't fit one of those four, it isn't a simplification — it's a refactor or a redesign, and `/simplify` refuses it.

**Forbidden:**
- Introducing a NEW abstraction (helper, base class, mixin, generic, strategy, factory, decorator, hook) — even if "it would be cleaner". The simplify command is an entropy-reducer, not a designer.
- Replacing a clear loop with a clever `reduce`-chain or pipeline.
- Replacing project primitives with stdlib equivalents the project doesn't already use elsewhere (don't introduce `lodash` if the project doesn't use it; do use it if siblings already do).
- Cross-module API rewrites — those go to `/refactor`.
- Applying any candidate without grep-confirming all call sites of an inlined symbol.

**Mechanical halt — refuse refactor that introduces new abstractions; only remove/inline:** before proposing a candidate, the agent classifies it against the four-verb vocabulary. Any candidate that adds a new symbol (function / class / type / interface / file) HALTS with a route-to-`/refactor` note. Net-line-count for an applied simplify run MUST be ≤ 0 (lines removed ≥ lines added). If the diff goes positive, revert.

**Production-grade gate — a simplification is DONE only when it is measurably simpler AND provably behaviour-identical; otherwise report INCOMPLETE/UNVERIFIED.** "Compiles + fewer lines + suite still green" is the FLOOR, not the bar. Green-fewer-lines can still be churn (a lateral rewrite) or silent behaviour change (on a branch no test exercises). Each APPLIED candidate must clear both arms below, with EVIDENCE, or it is reverted / reported unmet — never counted as success:

- **Arm 1 — measurably simpler (not lateral).** The flagged smell must actually be GONE at the source, not just re-shaped: re-run the detector that flagged it (over-abstraction / dead-branch / duplicated-logic / premature-options) — its fingerprint must return **zero hits at the site** (the `refactoring-sweep` re-detect closure verb, `../skills/refactoring-sweep/SKILL.md` step 6). Combined with net-lines ≤ 0. A candidate whose fingerprint still fires and whose net-lines did not drop lowered nothing → it is churn → drop it.
- **Arm 2 — behaviour identical, proven on the TOUCHED path (not the whole suite).** "Coverage must not move" is a suite-level number; it does not prove the specific removed branch / inlined call-site / de-duped call was behaviour-preserving. For each applied candidate: the exact touched path must be covered by a test that is **green before AND after** the edit. If the touched path is uncovered, dispatch [`test-shield`](../skills/test-shield/SKILL.md) (→ `/add-test`) to pin current behaviour BEFORE applying; if it cannot be characterized (side-effect-only / external), the candidate is **UNVERIFIED** — do not apply it silently, list it. For a `remove` of a supposedly dead branch, the pin is inverted: confirm **no** test exercised it (if one did, it was not dead — halt that candidate).

**Lightweight default.** Staged + unstaged diffs only (or `[path]` arg). No project-wide sweeps, no global pattern proposals, no `ai/patterns/` authoring inside this command. If 3+ duplicates surface, queue a one-line note to `ai/dynamic/learned-patterns.md` for a future `/refactor` to act on; do not act on it here.

## Phases applied

All 7. Phase 4 = propose diffs (no auto-apply without confirmation).

## When to use / NOT to use
- USE: right after writing a draft, before opening a PR; reviewing a sibling's PR with too much code for the problem.
- NOT: file is intentionally verbose (generated code, schema, fixture); cross-module API change (use `/refactor` instead).

## Phase 1 — Understand

- Parse `[path]` arg if given; else default to staged + unstaged diffs.
- Confirm scope: own diff vs teammate's PR — different consent rules.
- Success: each candidate has a one-line rationale + before/after, and lint/typecheck stay green after applied edits.

## Phase 2 — Organize

- Resolve target file list (`git diff --name-only HEAD` + `git diff --name-only --cached`, or path arg).
- For each file, queue 7 detector passes (see Phase 3).
- Trivial single-file scope: skip planning, proceed.

## Phase 3 — Retrieve

- `CLAUDE.md` + `ai/conventions.md` — what counts as "verbose" here (project may codify it).
- `ai/patterns/` — the canonical shapes; "wrapper with one implementer" only flags if it diverges from documented pattern.
- For each changed file: existing helpers/utilities in the same layer (grep before flagging "duplicated logic").

## Phase 4 — Generate (candidates)

For each file, scan for:
- **Duplicated logic** — same shape exists in a helper / utility / sibling. Grep first.
- **Over-abstraction** — wrapper class / factory / strategy with one implementer.
- **Dead branches** — `if (false)`, unreachable returns, conditions that became invariants.
- **Over-validation** — validating types TypeScript already enforces; null-checks on non-nullable types.
- **Premature parameterization** — `options: { foo?: bool }` where every caller passes the same value.
- **Verbose error handling** — try/catch that re-throws unchanged.
- **Reinventing stdlib** — manual `groupBy` / `chunk` / `partition` when `lodash` / `Array.prototype` covers it.
- **Comment-as-rename** — `// gets the user` above `function getUser()`.

Produce candidates with before/after snippets + one-line rationale. Ask user which to apply.

## Phase 5 — Update

- Apply selected edits via Edit tool.
- No knowledge-base updates unless a new "duplicated logic" finding reveals a missing entry in `ai/patterns/` — then queue to `ai/dynamic/learned-patterns.md`.

## Phase 6 — Validate (the production-grade gate, per applied candidate)

- Lint + typecheck on touched files; revert if anything fails. **(floor — necessary, not sufficient.)**
- **Arm 2 (behaviour):** re-run scoped tests — coverage must not move, AND the specific touched path was covered by a test green **before and after** (test-shield-pinned if it was uncovered). A suite that stays green on an uncovered touched path is UNVERIFIED, not proof.
- **Arm 1 (simpler):** re-run the flagging detector — its fingerprint must be **cleared at the site** (zero hits), and net-lines for the run must be ≤ 0. If the smell still fingerprints and lines did not drop, the candidate was churn — revert it.
- For removed branches: confirm no test exercised them (if it did, the branch wasn't dead — halt the candidate).
- Any candidate that fails an arm is **reverted** and moved to the run's `INCOMPLETE`/`UNVERIFIED` list with the unmet arm named — the run reports what it could NOT prove rather than silently shipping it.

## Phase 7 — Improve

- If 3+ similar duplicates found across files, queue a pattern entry (e.g. "extract X helper") to `ai/dynamic/learned-patterns.md`.
- If a "wrapper with one implementer" recurs, append to `ai/dynamic/drift-log.md` — the abstraction policy may be too eager.

## Output

```
3 candidates in src/orders/orders.service.ts:

[1] L42  Duplicated query
    Existing helper: ordersRepo.findByTenant() at libs/repos/orders.ts:88
    Before:  const o = await this.qb('orders').where(...).getMany();
    After:   const o = await this.ordersRepo.findByTenant(tenantId);

[2] L88  Wrapper with one implementer
    OrderFactory.create() only used by OrderService.create() — fold into the call site.

[3] L120 Premature options
    paginate(opts: { limit?: number; offset?: number })  every caller passes both.

Apply [1,2,3] / [1,3] / none?
```

After applying, the run MUST print a Verification footer — the checkable artifact of the production-grade gate. `Simplified` is claimed only for candidates that cleared both arms; the rest are named:

```
Verification (applied: [1,2])
  net-lines: −18  (removed 22 / added 4)  ✓ ≤ 0
  [1] dedupe  → fingerprint `duplicated-logic` @ orders.service.ts:42 cleared (0 hits) ✓
              → covered by orders.service.spec.ts::lists tenant orders — green before+after ✓   → Simplified
  [2] inline  → fingerprint `wrapper-one-implementer` @ :88 cleared ✓
              → call-site was uncovered → test-shield pinned OrderService.create — green before+after ✓   → Simplified
INCOMPLETE / UNVERIFIED (not applied)
  [3] premature-options → touched path paginate() has no covering test and is used across 6 call sites;
        could not pin behaviour before the edit → UNVERIFIED, left in place.
```

A run with nothing to put under `Simplified` did not simplify — it says so, rather than reporting green-and-fewer-lines as success.

## Failure modes

- Cross-module simplification breaks a public API consumer — never apply without grep-confirming all call sites.
- "Simplify" turning into "optimize" (clever reduce-chain replacing clear loop) — opposite of this command's goal.
- Verbose form is correct (audit logs, retry logic for known-flaky API) — skip when in doubt.
- Test coverage moves after applied edit — revert; the change was not behavior-preserving.
- **Green-and-fewer-lines reported as success on an uncovered path** — the run declared done because the suite stayed green and net-lines dropped, but no test exercised the inlined/de-duped path. That is UNVERIFIED, not Simplified — pin it with test-shield first or list it unmet.
- **Churn-for-churn** — a candidate re-shaped code (lateral rewrite, cosmetic reorder) but its smell fingerprint still fires and net-lines did not drop. It lowered nothing; revert and do not count it.
- Reviewing teammate's PR — get consent before applying anything.

## Related

### The boundary this command owns

**`/simplify` is the subtraction-only editor: `net lines ≤ 0` on a closed four-verb vocabulary, hard-refusing "introduce a symbol", with no exemption and no prerequisite.** A run that added a helper was not a `/simplify` run.

That gate pair is **not unique to this command** — `/align-gate` (global, `align` pack) runs both, as checks 3 and 4 of its 14-check matrix ([`align-gate.md`](../../align/commands/align-gate.md) § "Check 3 — Net-lines on structural rows ≤ 0" / § "Check 4 — No new symbols"). What differs is *what the gate is attached to*, and that is what picks between them:

| | `/simplify` | `/align-gate` |
|---|---|---|
| Gates | its own edits, per run | a phase of an existing `ai/align/ledger.md`, after the fact |
| Writes code | yes — it *is* the editor | no — read-only; its only verdict is refusal |
| Net-lines scope | every applied candidate | the *structural subset* of the phase diff; functional rows are exempt |
| New symbol | absolute refusal | permitted when the symbol is named in `_extracted-idioms.md` |
| Prerequisite | none — point it at a diff | a populated align ledger + plan |

No ledger and you just want the diff smaller → here. Closing out a ledger phase → `/align-gate`.

**Anti-triggers — route away, do not run this command:**
- The fix needs a **new** helper, class, or module, or a structure move → **`/refactor`**. The split is directional and mechanical: `/simplify` may only *reuse* what already exists; `/refactor` is where creating a symbol is allowed (Rule of Three — ≥3 concrete callers, per [`refactorer.md`](../agents/refactorer.md) § "Safe refactors" → *Replace duplication*). A candidate `/simplify` halts on because it would add an abstraction belongs there, and vice-versa: a `/refactor` finding that turns out to be "delete this, the shared helper already does it" belongs here.
- Whole-project cleanup, architecture, or a **measured** perf win → **`/optimize`** (global). It runs Phase-0 architectural diagnosis first; this command has none and never looks past the diff.
- "Some files do X, some do Y" with no entropy angle → **`/align`** (global): enforcing an idiom the project already documents.
- Ranking what is wrong at a target scale → **`/audit`** (global).
- **Name collision worth knowing:** the Claude Code harness ships a built-in `simplify` skill with a near-identical brief ("review the changed code for reuse, simplification, efficiency… quality only"). They do not overwrite each other — a pack command installs as `<name>.<track>.md` — but a user typing "simplify" may reach either. What *this* one adds is the closed verb set, the net-lines gate, the two evidence arms, and the refusal to introduce a symbol. If those constraints are not what you want, the built-in is the looser tool and the right one.

### Sibling commands in code-quality pack
- `/refactor` (pack overlay) — the create-a-symbol half of the same job; see above.
- `/review-changes` — reports on a diff and never edits; this command edits. Route a `simplify:`-shaped finding from a review here.
- `/pre-commit` / `/check-health` — gates and pulses; neither reduces entropy.
- `/find-module` — locate the existing helper before deciding a duplicate is really a duplicate.

### Rules
- `.claude/rules/engineering-principles.md`
- `.claude/rules/quality-principles.md`
