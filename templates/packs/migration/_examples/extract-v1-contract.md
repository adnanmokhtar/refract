---
name: extract-v1-contract
description: Read a V1 feature deeply (entry point + every conditional + every dependency call + every error path + git log + tests + bug-tracker references) and produce a structured contract document that V2 must satisfy for parity. The contract is the spec — V2 is re-derived from it, never copy-pasted from V1.
---

# extract-v1-contract

Read V1's *actual* behaviour into `ai/migration/contracts/<feature>.md` so V2 can be re-derived from a written spec, not transposed from V1's source. This is the single highest-leverage step in any port — every regression-after-cutover begins with "we missed this in V1."

This skill is the procedural arm of `migration-discipline.md` + `feature-port.md` Phase 1.

## Premise

Find V1's real behaviour, no hand-waves. Every claim in the contract is a citation: `<v1-path:line>` + a one-line excerpt of the actual source line, pinned to a specific V1 commit SHA. Paraphrases like "validates input" or "returns the user" are halted — the contract is the source line plus its observable consequence. Inputs, outputs, side effects, business rules, invariants, and known V1 bugs are read out of V1's code + tests + git log + telemetry, not inferred from product docs. The contract is what V1 *does*, not what V1 *should* do.

## Halt conditions

- Halt on any contract claim missing `<v1-path:line>` + one-line source excerpt.
- Halt on a contract written against an unpinned V1 (no `v1_commit_pinned` in the ledger row).
- Halt on tier expansion (Standard → Heavy) without an explicit user-recorded justification on the ledger row.
- Halt on "feature too small to need a contract" — small features per tier rules; no contract per tier rules; never silent-skip.

This skill is the procedural arm of `migration-discipline.md` + `feature-port.md` Phase 1.

## When to use

- A new ledger row enters state `In-progress` (called by `/port-feature` automatically).
- Re-extracting an existing contract because parity tests revealed behaviour the contract didn't capture.
- Auditing whether a previously-written contract is complete (call this on the V1 side; diff against existing contract).

## When NOT to use (refuse + explain)

- V1 doesn't exist (greenfield). There is no contract to extract — write the contract from product / API spec.
- The "feature" is not a feature — it's a cross-cutting concern (e.g., logging middleware, error envelope). These migrate as infrastructure, not as features. Use `legacy-modernizer` strategy instead.
- The feature is too large to contract in one document (>500 lines) — split into sub-features first; one ledger row each.
- V1 is being actively modified during extraction. Pin V1's commit before extracting; extraction is meaningless against a moving target.

## Prerequisites

- `.claude/_extracted-codebase.md § Migration` is populated (V1 root + V2 root + ledger path detected).
- A specific feature is identified (entry point: route URL, function name, class, file path).
- Read access to: V1 source, V1's tests, git log, bug tracker (or its equivalent — issue list, PRs, internal docs), production telemetry (latency / error / log samples) for the feature if available.

## Procedure

### 1. Identify the entry point + boundary

Pick **one** entry point (e.g., a route handler, a CLI command, a job consumer). Trace outward until you reach:

- I/O boundaries (DB, external HTTP, queue, cache, file).
- Auth / authz checks.
- Output construction (response builder, log emit, queue publish).

Everything *between* the entry and the boundary is in scope. Things called from outside this scope but used internally (e.g., `getUser`) are dependencies, not part of this feature's contract — record them in the dependencies section.

### 2. Trace the happy path — read every line

```text
For each file in the call graph (entry → boundaries):
  1. Read the entire file. Don't skim — read.
  2. Note every conditional, including ones with no comment.
  3. Note every error path (try/except, error returns, .catch).
  4. Note every side effect (write, emit, publish, invalidate, log).
  5. Note every type / shape of input + output.
  6. Note every dependency call: which function, what args, what return shape.
  7. Note any time / random / external-state dependence.
```

### 3. Trace error paths — read every catch / error return

For each error path:
- What input triggers it?
- What's the observable behaviour (HTTP status, exception class, error code string, log line, side effect attempted/skipped)?
- Does the error path leave the system in a clean state, or partially mutated?
- Is the error path tested? Find the test (if any).

### 4. Read tests — what V1's authors thought it does

Read every test file that touches V1's feature. Note:

- Behaviours the tests cover (these are the AUTHORS' contract).
- Behaviours the tests do NOT cover but the code clearly handles (these are the SILENT contract — the most common source of regressions).
- Behaviours the tests cover that aren't in the code anymore (dead tests = past contract).

### 5. Read git log — why is V1 shaped this way

```bash
git log --follow -p <v1-entry-point>      # entry point's history
git log --follow -p <v1-supporting-files> # each file in the call graph
```

Pay attention to:

- Recent bug fixes — these reveal hidden invariants (the conditional that "looks weird" is the patch for an old bug).
- "Quick fix" / "hotfix" commits — disproportionately load-bearing in production.
- PR discussion / review comments (if accessible) — reveal contract decisions never in the code.

### 6. Read bug tracker / issue list

Search for the feature name + adjacent terms. Capture:

- Bugs reported against V1 that are still open (these are V1's *known* bugs — decide explicitly: preserve in V2 (parity) OR fix in V2 (contract break + ADR)).
- Bugs reported and fixed (these often left a check or branch in the code that's not obvious — find the commit).
- Feature requests against V1 that landed (these are evolution of V1's contract).

### 7. Inspect production telemetry (if available)

- **Latency p50/p95/p99** — V2's contract includes "no worse than V1". Capture the V1 baseline.
- **Error rate** — what's V1's normal error rate? V2's must not exceed it.
- **Throughput** — V1's QPS / RPS / req-rate. V2 must handle the same.
- **Log samples** — sample 100 production logs of this feature. What inputs is V1 actually receiving (vs what the unit tests use)? Anonymise before saving.
- **DB cost per call** — how many queries, what query plans, what row counts. Captures perf-uplift candidates.

### 8. Inspect adjacent code that *consumes* V1

Run `git grep` for V1's exported symbols / endpoints. For each consumer:

- What return shape does the consumer expect? (E.g., does the caller `if (user)` or does it `if (user != null)` — both should still work in V2; if the consumer uses `Object.keys(user)` then V2's column projection must keep all keys.)
- Does the consumer rely on side-effect ordering?
- Does the consumer rely on V1 throwing vs returning null? (One of the most common silent breaks.)

The contract section "Caller assumptions" lists every observable the consumers depend on, with `<file>:<line>` citations.

### 9. Synthesise the contract

Write `ai/migration/contracts/<feature>.md` with this structure:

```markdown
# Contract: <feature>

> V1 entry point: `<v1-path:line>`
> V1 commit pinned: `<sha>`
> Author: <name> | Reviewed: <name> | Date: <iso>

## Inputs

- `<param-name>`: <type> — <constraints>; default `<default>` if any; validated by `<validator-path:line>` if any.
  - Edge cases V1 handles: empty string, null, oversize (>N bytes), malformed (e.g., trailing whitespace), Unicode normalisation, etc.
- ...

## Outputs (per code path)

### Happy path
- Shape: `<TS / Pydantic / dataclass / JSON shape>`
- Field-by-field semantics: `<name>` is `<source>` — e.g., `total = sum(line.amount) + tax` where `tax = orderTotal * taxRate(jurisdiction)`.

### Error path: <name> (e.g., `MissingUser`)
- Trigger: `<input condition>`
- Observable: HTTP `<code>`, body `<shape>`, log line `<structured fields>`, metric `<name>` incremented.
- Side effects executed before the error: `<list>` (e.g., "audit log written before failing — system depends on this").
- Side effects skipped: `<list>`.

(Repeat for every error path.)

## Side effects (every code path)

- DB writes: table `<t>`, columns `<c>`, condition `<when>`, idempotency key `<if any>`.
- External HTTP: endpoint `<url>`, method `<m>`, when `<condition>`, retry policy `<r>`, timeout `<t>`.
- Queue publishes: queue `<q>`, message shape `<s>`, ordering required `<y/n>`.
- Cache: reads from `<key pattern>`, writes to `<key pattern>` with TTL `<t>`, invalidates on `<event>`.
- File I/O: `<path>`, mode, atomicity required.
- Logs systems depend on: structured field `<name>`, consumed by `<system>` (e.g., billing dashboard reads `event=order_created`).
- Metrics: counter `<name>`, histogram `<name>`, when emitted.

## Business rules

For each named rule found in code (give it a name even if V1 doesn't):

- **Rule-001: orders.discount.minimum_order_value** — discount applies only if `order.total >= 50`. Source: `<path:line>`. Test: `<path:line>` (or "no direct test"). Origin: `<git commit / issue>`.
- ...

## Invariants

- **Ordering**: e.g., audit log written BEFORE the DB commit (so audit captures intent even on commit failure). Source: `<path:line>`.
- **Idempotency**: e.g., POST /orders with same `Idempotency-Key` returns same response without re-executing side effects. Source: `<path:line>`. Storage: `<table>`.
- **Atomicity**: e.g., user-create + welcome-email-enqueue are in one DB transaction; either both happen or neither.
- **Retry semantics**: e.g., on HTTP 503 from external X, retry up to 3 times with exponential backoff; on 4xx, no retry; on network error, retry once.
- **Concurrency**: ordering or exclusion guarantees under concurrent calls (e.g., row-level lock on user; advisory lock on report-generation per user).

## Performance characteristics (V1 baseline)

- Latency: p50 `<ms>`, p95 `<ms>`, p99 `<ms>` (source: `<dashboard / log / measurement>`).
- DB queries per call: `<count>` (`<list>`).
- External HTTP calls per call: `<count>`.
- Memory per call: `<estimate>`.
- Throughput cap: `<qps>` if known.

## Caller assumptions (consumers of V1)

- `<consumer-path:line>` expects V1 to: `<observable>`. Breaking this is a contract change.
- ...

## Edge cases V1 handles (catalogued, with citations)

- Empty input: `<observable>` (source: `<path:line>`).
- Null input: `<observable>` (source: `<path:line>`).
- Concurrent calls with same key: `<observable>` (source: `<path:line>`).
- Network error from dependency X: `<observable>` (source: `<path:line>`).
- Dependency timeout: `<observable>` (source: `<path:line>`).
- Oversized input: `<observable>` (source: `<path:line>`).
- Malformed input (per validator): `<observable>` (source: `<path:line>`).

## Known V1 bugs

For each, decide: **preserve** (parity) or **fix** (contract break, separate ADR).

- **Bug-001**: <description>. <issue link>. Decision: **preserve** — V2 reproduces this behaviour. Caller depends on the buggy behaviour (`<path:line>`). Fixing requires ADR + caller migration.
- **Bug-002**: <description>. <issue link>. Decision: **fix** — pre-arranged ADR `<ADR-NNN>`; ships in a separate PR after V2 cutover.

## Open questions (for migration owner)

- ...
```

### 10. Review the contract

A second reviewer reads V1 alongside the contract. Their job: find anything the contract missed. Common misses:

- A debug-only log line that production parses for billing.
- A test fixture that hides the only callsite that exercises a rare branch.
- An old hotfix branch with no comment and no test that now reads as "obviously dead".

### 11. Pin V1 + register in ledger

```bash
git -C <v1-root> rev-parse HEAD > /dev/null   # ensures V1's branch is checked out
PIN=$(git -C <v1-root> rev-parse HEAD)
# update ai/migration/ledger.md row for this feature: state=In-progress, v1_commit_pinned=<sha>, contract=ai/migration/contracts/<feature>.md
```

After this point, V1 must NOT be modified for this feature. V1 is the parity oracle.

## Output format

The contract file at `ai/migration/contracts/<feature>.md` is the artifact. Linting checks:

- Every `<path:line>` citation resolves (file exists, line exists, content roughly matches).
- Every error path has: trigger + observable + side-effect notes.
- Every external dependency has: shape + retry/timeout/idempotency notes.
- The ledger row references this contract.
- The V1 commit pinned in the ledger row resolves.

## Failure modes

- **"This feature is too small to need a contract."** — small features are where regressions hide because nobody bothered. The contract is cheap; write it.
- **"V1 is incomprehensible."** — incomprehensible V1 is exactly when the contract is most valuable. Allocate more time; pair with V1's last author if reachable.
- **"The contract grew too big."** — feature is too large; split. Each split feature gets its own contract + ledger row.
- **"V1 has no tests."** — record-replay is your test data. Capture production traffic samples (anonymised) into `tests/parity/<feature>/replay/`.
- **"V1 has bugs we don't know about."** — that's fine; the contract is "what V1 *does*", not "what V1 *should* do". Bugs live in the **Known V1 bugs** section. The contract evolves when parity tests find new ones.
- **"The contract is wrong about V1 (parity tests failing in unexpected ways)."** — revise the contract; re-pin V1 if V1 has moved; investigate. The contract being wrong is itself a discovery.

## Related

- `migration-discipline.md` — the rule this skill enforces.
- `feature-port.md` — Phase 1 of the per-feature lifecycle.
- `parity-test-generate.md` — consumes this contract to build parity tests.
- `perf-uplift-survey.md` — consumes the **Performance characteristics** + **Side effects** sections.
- `migration-architect.md` (agent) — uses this contract to plan V2.
- `parity-auditor.md` (agent) — verifies the contract is complete before cutover.
