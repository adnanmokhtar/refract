---
name: parity-test-generate
description: Generate a parity test suite that runs V1 + V2 against identical inputs and asserts equivalence per the contract's tolerance taxonomy. Combines golden master, record-replay, property-based, and (when applicable) shadow / dual-write audit techniques. Outputs runnable tests and a tolerance configuration file.
---

# parity-test-generate

Build the test suite that gates cutover. The suite is V2's spec — V2 is "done" when this suite is green against the pinned V1 commit.

This skill is the procedural arm of `migration-discipline.md` + `parity-testing.md` + `feature-port.md` Phase 4.

## When to use

- A feature has a contract (`ai/migration/contracts/<feature>.md`) and is in state `In-progress` or transitioning to `V2-shadow`.
- The contract was revised (e.g., parity-test failure surfaced a missing case) — regenerate / extend the suite.
- Cutover deadline approaching and the existing suite has tolerance gaps the auditor flagged.

## When NOT to use (refuse + explain)

- No contract yet — run `extract-v1-contract` first. Without a contract, "parity" has no definition.
- V1 is being modified — pin V1 first; otherwise tests run against a moving oracle.
- The feature has no V1 (greenfield V2 feature on the new system) — there's nothing to be parity-equivalent to. Write regular unit/integration tests.

## Prerequisites

- `ai/migration/contracts/<feature>.md` exists + is reviewed.
- V1 commit pinned in `ai/migration/ledger.md` row for this feature.
- Test framework + parity test root extracted in `_extracted-codebase.md`.
- For record-replay: access to a production traffic sample source (or instructions for capturing one safely with anonymisation).
- For shadow / dual-write: infra is set up (router with mirror, comparison sink, schema for dual-write store).

## Procedure

### 1. Decide the recipe mix

Pick from `parity-testing.md` based on feature shape:

#### Backend / API / job / CLI features

| Feature shape | Recipes |
|---|---|
| Pure / deterministic, well-defined inputs | Golden master + property-based |
| Read-heavy, production-traffic-exposed | Record-replay + shadow |
| Write-heavy, mutating | Record-replay + dual-write audit |
| Mixed read/write | All four (shadow read, dual-write writes) |
| Tiny / utility-shaped | Golden master only |

#### Frontend features (page / component / route / screen)

Frontend ports add specific recipes — generic golden-master alone is insufficient because the contract surface includes DOM affordances, event handlers, accessibility, and reactive lifecycle which generic JSON-output golden master cannot pin.

| Feature shape | Recipes | Tooling |
|---|---|---|
| Page with inline business logic | Page-level mount + `defineExpose`-based driver test + DOM assertion | Vue Test Utils / React Testing Library / Svelte Testing Library |
| Page with composable-extracted logic | Composable golden master (unit-test the composable directly) + page-level smoke test | Vue Test Utils + composable runner pattern |
| Component (reusable) | Component-level snapshot per render-state + interaction test (click/submit/change) | Vue Test Utils / RTL / Storybook + Chromatic |
| User flow (multi-page) | E2E parity (Playwright/Cypress) — drive V1 + V2 in parallel; compare DOM / screenshots | Playwright / Cypress / WebdriverIO |
| Visual fidelity | Visual regression (pixel-level with tolerance) | Percy / Chromatic / Playwright snapshots / BackstopJS |
| Accessibility | a11y baseline + diff (axe-core) | axe-core via Playwright / RTL `jest-axe` |
| Multi-locale | Render in every locale; assert i18n keys + RTL/LTR flip | Vue Test Utils + i18n harness |

**Frontend recipe details:**

- **Page-level mount + driver test**: render the V2 page with mock services; drive interactions; assert the resulting requests / store mutations / route pushes / toast invocations match the V1 contract. Use `defineExpose({...})` (Vue) or component refs (React) when business logic is inline.
- **Composable golden master**: extract logic to a composable (Vue) / hook (React); test the composable's exposed API as a unit. The page becomes a thin wrapper — much easier to test. Encouraged by `migration-discipline.md` § Frontend anti-patterns ("Per-page inline business logic" → fix: composable extraction).
- **Component snapshot per state**: render the component with N input states (loading / loaded / empty / error / readonly / etc.); snapshot each. Combine with interaction tests (click button → assert event emitted).
- **E2E parity**: high-confidence but slow + flaky-prone. Reserve for high-traffic flows (auth, checkout, ordering). Drive Playwright against both V1 and V2 hosts; capture and compare.
- **Visual regression**: use a tolerance threshold (e.g., 0.1% pixel diff) to absorb minor anti-aliasing / font-rendering differences. Pin a single browser + viewport.
- **a11y diff**: axe-core baseline against V1; assert V2 has ≤ V1 violations (V2 may be stricter and have *fewer* violations — that's a win, not a regression).
- **Multi-locale**: parameterise tests over the locale list; assert keys resolve in each locale; verify RTL/LTR layout flip; verify date / number / currency formatting per locale.

#### Auto-import test-config requirement (frontend)

Any test that mounts a `.vue` / `.tsx` / `.jsx` file from a project that uses `unplugin-auto-import` (Vue), Nuxt's auto-imports, Vite's auto-import plugin, etc. requires the SAME plugin in the test config (`vitest.config.ts`, `jest.config.js`). Otherwise the auto-imported `useI18n`, `useRouter`, `computed`, etc. resolve in production but not in tests. **First mount fails with `useI18n is not defined`-type errors.** This is the #8 named anti-pattern in `audit-failure-modes.md` ("The Auto-import Trip"); pre-empt it by writing the test config alongside the test files.

#### KeepAlive-aware mount (Vue)

For Vue pages that use `onActivated` (cached pages under `<KeepAlive>`), the test mount MUST wrap the component in `<KeepAlive>` for the activate hook to fire:

```ts
const wrapper = mount(
  {
    components: { Page },
    template: '<KeepAlive><Page /></KeepAlive>',
  },
  { /* options */ }
)
```

Otherwise `onActivated`-fired API calls don't run and `expect(mockApi).toHaveBeenCalled()` fails. This is the #10 named anti-pattern in `audit-failure-modes.md`.

Aim for ≥2 recipes per non-trivial feature so a gap in one is caught by another.

### 2. Build the input corpus (golden master)

`tests/parity/<feature>/inputs/`:

- **Happy paths**: at least one input per documented happy code path.
- **Each error path**: at least one input that triggers it (per the contract's `Outputs § Error path: <name>` sections).
- **Each business rule**: ≥2 inputs — one that triggers the rule, one that doesn't (boundary tests).
- **Each edge case**: from `Edge cases V1 handles` in the contract — empty, null, oversize, malformed, Unicode, concurrent (where representable).
- **Production samples**: 50–100 anonymised inputs from real traffic (if record-replay is in use, reuse the corpus).

Aim for ≥30 inputs for non-trivial features. Fewer is acceptable only for utility-shaped features.

### 3. Capture V1 outputs (golden snapshots)

Run V1 against the corpus once, in a controlled environment (test DB seeded; deterministic time/random; no external calls real or stubbed):

```bash
node scripts/parity/capture-v1.js \
  --feature=<feature> \
  --inputs=tests/parity/<feature>/inputs \
  --outputs=tests/parity/<feature>/__golden__
```

(Equivalent script per stack — Python: `python scripts/parity/capture_v1.py ...`; Go: `go run scripts/parity/capture_v1.go ...`.)

The capture script:
- Resets seed data + time mocks before each input (otherwise non-determinism poisons the snapshots).
- Records V1's output **per the tolerance taxonomy** — strip / normalise volatile fields BEFORE saving, so future diffs surface only the things the contract pins.
- Saves alongside: the V1 commit hash, the captured input, the captured output, the contract revision used.

Commit `__golden__/`. These snapshots are sacred — no `--update-snapshots` blind refresh.

### 4. Build the tolerance file

`tests/parity/<feature>/tolerance.yaml`:

```yaml
exact:
  - $.id
  - $.status
  - $.error.code
structural:
  - $.created_at
numeric_tolerance:
  $.total: 0.01
order_insensitive:
  - $.tags
ignore:
  - $.debug
  - $.x_request_id
```

Generate this from the contract's **Outputs** section. Each field listed in the contract gets a tolerance — `exact` if it's a stable contract value, `structural` if it's volatile-but-shape-pinned, `ignore` if the contract explicitly excludes it.

### 5. Author the golden-master test

```ts
// Pseudocode (adjust to project's framework + path conventions from extraction)
import { runParity } from '../helpers/run-parity';

describe('feature parity (golden master)', () => {
  runParity({
    feature: 'feature',
    corpus: 'tests/parity/feature/inputs',
    golden: 'tests/parity/feature/__golden__',
    tolerance: 'tests/parity/feature/tolerance.yaml',
    runV2: (input) => v2.handleFeature(input),
  });
});
```

`runParity()` is a shared helper (one per project) that loads inputs + golden + tolerance, runs V2, applies tolerance-aware diff, asserts equivalence. The skill creates this helper if it doesn't already exist (Phase 4.6 anchors it to the project's test framework).

### 6. Author property-based tests

For each invariant in the contract's **Invariants** section, add a property test:

```ts
import { fc, test } from '@fast-check/vitest';

test.prop([validOrderArb])('V1 ≡ V2 totals (within $0.01) — invariant: total = sum(lines) + tax', (order) => {
  const v1 = handleV1(order);
  const v2 = handleV2(order);
  expect(v2.total).toBeCloseTo(v1.total, 2);
});
```

Generators (`validOrderArb` here) must reflect prod input distributions — calibrate against the replay corpus's input shapes (sizes, value ranges, locale variations).

### 7. Build the record-replay harness (when applicable)

```text
1. Capture production traffic samples (input, V1 output) → tests/parity/<feature>/replay/<NNN>.json
   - Anonymise PII at the tap. Don't capture anything that can re-identify a user.
   - Include 1000+ samples for high-traffic features; 100+ for low-traffic.
   - Refresh weekly OR on every V1 deploy that touches the feature.

2. Replay test:
   for sample in replay/*.json:
     v2_output = run_v2(sample.input)
     assert tolerant_equal(v2_output, sample.v1_output, tolerance)
```

The replay corpus is checked in alongside the test, anonymised; raw production data NEVER leaves production. The capture pipeline + anonymiser are themselves audited (see `security/` pack if available).

### 8. Configure shadow / dual-write (for production-stage cutover)

These are infra, not tests — but `parity-test-generate` produces the *comparator* that shadow / dual-write infra runs:

```python
# pseudocode comparator service
def compare(v1_response, v2_response, tolerance):
    diff = tolerant_diff(v1_response, v2_response, tolerance)
    if diff:
        emit_metric('parity_mismatch', tags={'feature': '<feature>', ...})
        log_pair(v1_response, v2_response, diff, anonymised=True)
    else:
        emit_metric('parity_match', ...)
```

Output the comparator code + a Grafana / Datadog dashboard JSON snippet that visualises mismatch_rate over time.

### 9. CI integration

- Golden-master + property-based tests run on every CI push (fast).
- Record-replay tests run nightly OR on `[parity]` PR label (slower; full corpus).
- Dashboard alerts on shadow / dual-write mismatch rate > threshold (≥0.1% sustained for 1h is "wake up an engineer").

### 10. Document tolerance overrides

Every tolerance loosening (e.g., extending `ignore` to a new field, raising numeric tolerance) is a contract change:

- ADR justifying the loosening.
- Ledger note linking the ADR.
- Reviewer signoff (not the person who tightened it).

Tightening tolerance is always allowed without ceremony.

## Output format

```
tests/parity/<feature>/
├── inputs/
│   ├── 001-happy-basic.json
│   ├── 002-happy-with-discount.json
│   ├── 010-error-missing-user.json
│   ├── 011-error-invalid-amount.json
│   ├── 020-edge-empty.json
│   ├── 021-edge-oversize.json
│   ├── 030-rule-001-min-order.json
│   ├── 040-prod-replay-001.json   # anonymised
│   └── ...
├── __golden__/
│   ├── 001-happy-basic.json
│   ├── 002-happy-with-discount.json
│   └── ...
├── replay/                        # if record-replay is in use
│   ├── 2026-04-25/
│   │   ├── 0001.json
│   │   └── ...
├── tolerance.yaml
├── parity.test.ts                 # golden-master + property-based
└── replay.test.ts                 # record-replay
```

Plus, optionally:

```
scripts/parity/
├── capture-v1.ts
├── run-comparator.ts              # for shadow / dual-write
└── refresh-replay.ts              # weekly cron entry point
```

Update the ledger row's `parity_tests` to point at the directory.

## Failure modes

- **Non-deterministic V1**: golden snapshots vary run-to-run because V1 hits real time / random / external state. Strip / mock those at capture time. If V1 is fundamentally non-deterministic, the test is property-based + invariant-checked, not exact-match.
- **Replay corpus PII leak**: the anonymiser missed a field. Treat as an incident; rotate the corpus; audit the anonymiser. Never ship a parity suite whose replay corpus has been sampled but not audited.
- **Tolerance creep**: every parity diff prompts "loosen the tolerance". Reject — investigate the diff first. The default action on a parity diff is "find the V2 bug", not "make the test happy".
- **Mocked dependencies hide bugs**: V1 calls `getUser`, V2 calls `getUser`, both mocked to return the same fake — parity passes; production diverges. Use real fakes (test DB, test HTTP server) when feasible.
- **Property generators don't reflect prod**: generators only cover small inputs, prod has 10MB inputs that V2 OOMs on. Calibrate generators against the replay corpus.
- **Tests pass but shadow shows mismatches**: the test corpus didn't cover what production sends. Add the production-divergent sample to the corpus, refresh.
- **Snapshots drift silently**: someone runs `--update-snapshots` to "fix CI" — the parity oracle is now wrong. CI rejects snapshot updates without a reviewer + ledger note (lint / hook).

## Related

- `parity-testing.md` — recipe details + tolerance taxonomy.
- `extract-v1-contract.md` — produces the contract this skill consumes.
- `migration-discipline.md` — the rule mandating these tests before cutover.
- `parity-auditor.md` (agent) — verifies the suite covers the contract before cutover.
- `testing/agents/tdd-orchestrator.md` (if pack loaded) — runs the suite as part of broader TDD orchestration.
- `database/skills/migration-rehearsal.md` — runs the V2 query plan against prod-sized data; output feeds parity tests' performance assertions.
