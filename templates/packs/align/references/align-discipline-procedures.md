# Align discipline — procedures & operational reference

> Companion to `.claude/rules/align-discipline.md` (the always-loaded core). Loaded on demand by align commands/skills when scanning, fixing, gating, or reviewing — NOT auto-loaded into every session.
> Rule-only tools (Aider / Codex / Gemini): this file ships alongside the core rule in your adapter bundle — read both; together with the six align `SKILL.md` files they are the complete discipline.
> First relocated from the core rule on 2026-06-07 (40k-char always-on limit); rewritten 2026-10-18 for declared-convention enforcement (AL-01…AL-34, the proof ladder, the 17-check gate).

## Realism guards — moved

The eight guards, and the six supporting mechanisms that carry their own thresholds (coverage
tolerance, parallel race serialization, baseline capture fallback, the reviewer-approval flow,
mid-sweep tier promotion, idiom-drift propagation), live in **`ai/patterns/align-guardrails.md`**.

They moved because a threshold that decides a halt has to reach the project, and this file does not:
`templates/phases/phase-4.2-apply.md:210-213` copies `references/<name>.md` only when `<name>` equals
a **detected framework name**, so `align-discipline-procedures.md` is never installed. `ai-patterns/`
copies unconditionally (`phase-4.2-apply.md:207`). Nothing enforceable is defined only here.

## Tool-agnostic procedure

The skills are the canonical procedures: `convention-oracle` (the oracle map, AL-01–04), `wrapper-adoption-scan` (AL-11, 13, 14, 15, 22), `naming-layout-scan` (AL-16–19), `convention-ratchet-scan` (AL-29–32), `align-detect` (the class ledger and dispatcher) and `find-and-align` (the proof ladder, AL-33/34). Tools that support skills dispatch them. Tools that don't (Aider / Codex / Gemini / Cline / Windsurf reading rules only) follow the outline below, reading each skill's `SKILL.md` as a reference document for its pre-flight script and detectors.

### Procedure: the audit (`/align-scan`)

1. **Build the oracle map** — run `convention-oracle` § 0 (`python3 -I <skills>/convention-oracle/scripts/oracle-map.py . --out=$RUN/oracle --age-buckets`), with `$RUN` a `mktemp -d` under `$TMPDIR`. It prints the tier line (`T1 · T1-warn · T1-noci · T2 · T2g (unratified) · contested`) and writes rules, docs, wrappers, exports, versions, CI and exceptions tables. The inventory falls back `_extracted-idioms.md` → `codebase-profile.md` → `ai/conventions.md`; with no declaration at all, every align class is `N/A (no declared convention)` — a reduction, never a halt.
2. **Dispatch the detectors** — each align detector's pre-flight script over the roots (whole repo, or by signal on a diff run). Every owner detector whose pack is installed: ui-ux `design-token-audit` (AL-05–10, 12), code-quality `architectural-diagnosis` §1–§2 (AL-20/21), frontend `i18n-scan` / `a11y-code-scan` (AL-26–28), backend `edge-error-scan` / `api-consistency-audit` (AL-23–25). A missing owner pack prints `N/A (owner pack <x> not installed)`. Security, performance, data, error handling, dead code, SOLID and complexity are never grepped: one owner line each.
3. **AL-01 first** — run `oracle-map.py quotes` over every candidate. A row whose `oracle:` quote is not in the cited file, or whose rule id is not declared, is dropped and counted.
4. **Refute** — every remaining candidate goes through `refute-before-report.md` § 10 (conventions column; gate 6 is the oracle line quoted + the site) in a verifier that did not raise it, after reading `precedents/align.md`. Buckets: Finding · Unconfirmed (T2g rows collapse to one ratification line per rule) · Hardening · Pre-existing (diff runs) · Refuted.
5. **The class ledger** — all 34 AL rows, each `checked (k → m)` / `N/A (<reason>)` / `blocked (<reason>)` / `NOT RUN (<reason>)` / `Live, unreviewed` / `Live, ratcheted` / `routed (<owner detector>)`, plus the production bar (ENFORCED / RATCHETED / NON-VACUOUS) and the verdict (ALIGNED / ALIGNED-UNVERIFIED (n) / DRIFT).
6. **Write** — `ai/audits/<date>-align.md` and the same report as `ai/align/scan-report.md`, and one ledger row per Finding and Unconfirmed group at `status: detected` in `ai/align/ledger.md`:
   ```yaml
   - id: A001
     al_class: AL-11
     oracle: 'eslint.config.mjs:14 "no-restricted-imports: ky → use @acme/http"'
     oracle_tier: T1                         # T1 | T2 | T2g
     owner: align                            # align | ui-ux | code-quality | frontend | backend | …
     scope: [apps/web/src/features/orders/api.ts]
     evidence: [apps/web/src/features/orders/api.ts:1]
     closure_verb: replace-with-shared       # the closed 21
     shared_equivalent: packages/http/src/index.ts
     proof_class: EQ                         # EQ | VC | FN
     detector: wrapper-adoption-scan §1
     detector_cmd: "<the exact command L5 re-runs>"
     routed: ""                              # owner rows: '<command> <audit id>', status routed
     tier: trivial                           # trivial | standard | heavy
     tier_reason: "1 file; T1 rule; EQ through the wrapper's defaults"
     status: detected
   ```
   The full schema and the fields each state adds: `ai/patterns/align-ledger.md § Record format`.

Nothing else is written: no source, no oracle file, no lint config, no baseline.

### Procedure: the per-row fix (`find-and-align`)

For each row in the phase, in dependency order (re-route callers before removing a raw twin; move a copy's callers before `dedupe`; renames after the rows whose evidence sits in the renamed file):

1. **ROUTE** — a row another pack owns moves to `status: routed` with `routed: <command> <audit id>` and no commit (security → `/security-fix`; perf / data → `/perf-fix`, `/db-fix`; error handling, dead code, a diverged copy, SOLID → `/quality-fix`; new copy, catalog, a11y on a native element → `/frontend-fix`; a declared API contract → `/backend-fix`; uniformity with no contract, or a token / state that does not exist → `/polish`; a wrapper gap → `/unify-surfaces`; layer rework → `/optimize`; a wire-name rename → `/refactor` + ADR). A T2g oracle → `pending-ratification`.
2. **DETECT** — re-run the row's `detector_cmd`. Evidence still matches → continue. 0 hits while the rule matched files → `archived-pre-existing` (aged out). The rule matched 0 files → halt `re-detect-vacuous`. The oracle quote no longer resolves → halt `oracle-gone`.
3. **DECIDE** — the proof class. **EQ**: the literal equals the token's value in every theme within one property family with one candidate (`token-map.py --lookup`, ui-ux pack); the wrapper's defaults reproduce the raw call's props; the literal equals an existing catalog value whose key resolves in every locale; a rename touches no wire name. **VC**: anything visible — stops at `pending-approval` until a human writes `approval: <name>@<iso>`. **FN**: a declared idiom added (`add-gate` with the declared `<Can>`), proven by a behaviour test that fails first.
4. **FIX** — rule first where expressible (an ESLint / ast-grep rule with BAD and GOOD tests, run from `$RUN`); change only the matched expression and the verb's footprint; touch only `scope`. Tests, snapshots, fixtures, the class's lint config, baselines and oracle files are read-only.
5. **VERIFY** — the ladder L0–L13, stopping at the first FAIL: `align-sweep-gate.py ladder` (oracle, approval, diffkind, lock-paths, scope, redetect, consistency, names, roundtrip, ratchet, lock-count, vacuous) plus lint / types (`tsc --noEmit --incremental false`) / build / scoped tests (L9), the zero computed-style or compiled-CSS diff for EQ (L10a) or the approved visual diff for VC (L10b). A `NOT RUN` step never counts as PASS: the row becomes `(static EQ)` with its probe, or Unconfirmed.
6. **RECORD** — `status: fixed`, `commit`, `gaps_closed` (= `len(evidence)`), `proof_class`, `proof:` (V-numbers + the ladder file); one row, one commit, subject `align/<phase-N>/<id>: …`. Heavy rows wait at `pending-review`.

Any failure: `status: halted`, `ai/align/halts/<id>.md` with the failing step and its destination; revert; do not advance the row.

### Closure-verb procedures

Each verb has a specific procedure. The agent follows it mechanically. The security, performance and validation verbs exist for the owner carve-out only (an owner pack absent and an idiom the oracle names); an owner row is otherwise routed, never closed with them.

**Structural verbs (net-lines ≤ 0):**

| Verb | Procedure | Typical AL | Notes |
|---|---|---|---|
| `remove` | Delete the cited lines (a reasonless suppression once the site is fixed; a banned import whose replacement is in place). Re-grep post-delete; any remaining inbound import = halt + revert. | AL-29 | Net: −. |
| `inline` | Read the wrapper's body and its single call site; substitute the body inline; delete the wrapper. Two or more consumers → mis-classified, `/refactor`. | — | Net: −. |
| `dedupe` | After the differential test (V403) shows the copy equals the named helper on the copy's call-site inputs, delete the copy and import the helper. A copy that diverged is `/quality-fix`'s. | AL-13 | Net: −. |
| `rename-comment-out` | Delete the cited comment line(s). No code change. | — | Net: −. |
| `replace-with-shared` | Replace the hit expression with the named wrapper, token or catalog key; one import added, one removed. Preserve other props. If the wrapper's defaults do not reproduce the props, the row is VC. | AL-11, 14, 22; EQ rows of AL-05, 12, 26 | Net: − cumulative; the first site may net + from the import. |

**Functional verbs (small + budget; added lines cite `idiom_cited`):**

| Verb | Procedure | Use in align |
|---|---|---|
| `add-gate` | Wrap the action with the **declared** gate the oracle names (`<Can action="…">`). FN: a render test as the role that must not see it, failing first (V401). | AL-15; AL-28 in the AL-15 form |
| `rename` | File by `git mv`; identifier by the language server or ts-morph (TS 6 API, else `NOT RUN`); every consumer in the repo; no wire, DB, env or generated name (V402). | AL-16, 17, 18 |
| `extract-to-shared` | Move a block to a module or barrel the oracle already names. Extracting to a new helper is forbidden. | AL-19 |
| `inline-magic-to-named-const` | Replace a magic value with the named const from the declared constants module. | AL-32 when the ADR names it |
| `split-extract` | SOLID rework — routed to `/quality-fix` / `/optimize`. | routed |
| `parameterize`, `escape`, `move-to-secrets`, `add-validator` | Security verbs — `/security-fix`. | routed |
| `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `inline-filter-to-query` | Perf / data verbs — `/perf-fix`, `/db-fix`; without those packs, the carve-out with a committed failing-first baseline test (a query-count scaling test). | carve-out only |
| `bump-dep` | Dependency bumps are `/upgrade-dep` / `/security-fix`. In align only for a declared same-major migration step with a lockfile-only diff and the full suite green. | rare |

### Procedure: phase exit gate (`/align-gate <N>`)

Run all 17 checks; the first failure sets REFUSE and the rest still run:

1. Ledger completeness — no `detected` / `planned` / `in-progress` / `halted` row; `routed`, `pending-approval`, `pending-ratification`, `parked` named; `pending-review` blocks.
2. Gap-count parity — `gaps_closed == len(evidence)` per fixed row.
3. Net-lines ≤ 0 on structural rows.
4. No new symbol the oracle does not name.
5. Line-level scope (V392, AL-34) — every removed line is an evidence line or the verb's footprint; no file outside `scope`.
6. Re-detect zero (V391).
7. One way per pattern (V393, AL-33).
8. Tests locked (V408) — no test, snapshot, fixture, lint-config, baseline or oracle file in a row commit; counts not down.
9. Emitted names exist (V398).
10. Value round-trip (V397) — `NOT RUN` with EQ token rows present refuses.
11. Non-vacuous (V399).
12. Ratchet shrink-only (V395, AL-30).
13. Proof class and approval (V394 / V396, V407).
14. Mechanical pass + boot at HEAD.
15. Coverage within tolerance (default 0.5 pp; > 5 pp hard).
16. Per-tier artifacts + idiom citation.
17. Oracle cited and unmodified; owner rows routed.

`scripts/validate-align-artifacts.sh --phase=<N> --phase-base=<base> --strict` carries 2, 3, 4, 5 (file level), 13, 16 and 17; `align-sweep-gate.py ladder --all` carries 5 (line level), 6–12 and the coverage half of 15; 1, 14 and the zero-diff evidence of 13 are agent-side.

## Review checklist (per phase PR)

- [ ] Every commit in the PR maps to exactly one ledger row by `id`.
- [ ] Every row is `fixed`, `archived-pre-existing`, `routed`, `pending-approval` or `pending-ratification` (no `halted`, no `in-progress`); routed and pending rows carry no commit.
- [ ] Every row's `oracle:` quote resolves in the cited file, and no oracle file is in the diff.
- [ ] Every row's `evidence` lines were re-detected at DETECT and confirmed gone at VERIFY, by a rule that matched ≥ 1 file.
- [ ] `gaps_in == gaps_closed` for every row (gap-count parity).
- [ ] Structural rows net-lines ≤ 0; functional adds cite the declared idiom.
- [ ] One before-value → one after-value across the phase.
- [ ] No test, snapshot, fixture, lint-config or baseline file touched; test and assertion counts not down; coverage within tolerance.
- [ ] EQ rows: a zero computed-style / compiled-CSS diff, or `(static EQ)` with the probe. VC rows: `approval: <name>@<iso>` by a human, not in the fix commit. FN rows: the behaviour test failed first.
- [ ] Lint + typecheck + full test suite + boot green at HEAD.
- [ ] No new symbol introduced (function / class / type / interface / file) that the oracle does not name.
- [ ] Per-tier artifact set complete:
  - trivial: row + commit
  - standard: + 1-paragraph rationale in row's `notes`
  - heavy: + impact analysis at `ai/align/impact/<id>.md` + `reviewer_approval: <name>@<iso>`
- [ ] No hand-wave tokens (`etc.`, `...`, `several`, `N+`, `multiple`) in any ledger field.
- [ ] PR title = `align/phase-<N>: <one-class-or-domain>` (single-class or single-domain phases preferred).

## Enforcement — moved

Gate behaviour, the SLA clocks (`in-progress` > 7d stalled; a halted HIGH gate row > 24h escalated) and
the anti-pattern → check-function matrix live in **`ai/patterns/align-guardrails.md`
§ Enforcement — gate behaviour, SLA clocks, anti-pattern → check**, for the same delivery reason as
§ Realism guards above.

## Relationship to migration discipline

The align discipline is **migration discipline turned inward**. Migration ports V1 features to V2; align moves the codebase's live sites onto the conventions the project already **declares** (a lint rule at `error`, a human-written line, an ADR, the glossary, the token set, a named wrapper). The same anti-patterns apply (Reinvented Wrapper, Trusted Summary, Hand-waved enumeration), the same tiered floor (trivial / standard / heavy), the same atomic-fix discipline, the same gap-count parity rule (`gaps_in == gaps_closed`).

The differences:
- **No V1/V2 split.** One codebase. The oracle is the declaration each row quotes, not a sibling V1 source; a majority with no declaration is not an oracle (AL-02).
- **No parity tests.** The proof classes replace them: EQ by a zero diff, VC by a named approval, FN by a behaviour test.
- **No cutover mechanism.** A row is fixed in-place; no shadow / canary / feature-flag stage. Atomicity comes from one-row-per-commit, not staged rollout.
- **No contract document.** Rows are scoped (one site group, one closure verb, one oracle line). The contract is implicit: "after the fix, the declared convention holds at every evidence line, and nothing else changed."

If a row is large enough to need a parity test, a contract, a cutover plan, or a behaviour-change ADR — it is NOT an alignment row. It is a migration / refactor / feature task. Mis-categorisation is the #1 way alignment sweeps creep into multi-week rewrites. Halt and route to the right surface.
