---
name: parity-testing
kind: example
pack: migration
---

# Pattern: Parity testing (V1 ↔ V2)

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Tests` + `§ Migration`. Do not delete; if extraction is empty, leave the placeholder + open a TODO.
>
> - **Test framework**: `<extracted>` (e.g., Jest / Vitest / Pytest / RSpec / Go test / JUnit / xUnit)
> - **Parity test root**: `<extracted>` (e.g., `tests/parity/`, `__tests__/parity/`, `tests/parity_test.go`)
> - **Snapshot directory**: `<extracted>` (e.g., `__snapshots__/`, `tests/parity/__golden__/`, `testdata/`)
> - **Fixtures location**: `<extracted>` (e.g., `tests/fixtures/`, `tests/factories/`)
> - **Production traffic sample source** (if any): `<extracted>` (e.g., S3 bucket of anonymised request logs, replay tool, none)
> - **Async/IO test wrapper**: `<extracted>` (e.g., `pytest-asyncio`, `vitest`'s native async, `testcontainers` for DB)

Parity tests prove V2 produces equivalent observable behaviour to V1 for the same input. They are the single most important artifact of a migration — they are the gate between phase 3 (port) and phase 6 (cutover) of `feature-port.md`.

## Why parity tests differ from unit tests

| Concern | Unit tests | Parity tests |
|---|---|---|
| What is asserted | "V2 does X" | "V2 produces the same observable as V1 for input I" |
| Oracle | Engineer's intent | V1's actual behaviour (the running V1, not its docs/tests) |
| Failure mode | "V2 has a bug" | "V2 diverges from V1" — could be V2 bug OR V1 bug we want to preserve OR a contract break we forgot to ADR |
| When written | After / alongside V2 code | BEFORE V2 code (or interleaved) — they are V2's spec |
| Ownership | The feature's owner | The migration |
| Lifecycle | Lives forever | Deleted after V1 is deleted (parity becomes meaningless) |

## Tolerance taxonomy

Parity does not always mean byte-for-byte. Pick the tolerance per assertion:

| Tolerance | When | Example |
|---|---|---|
| **Exact** | Stable structured output | Order ID returned in response; status codes; enum values |
| **Structural** | Same shape, value-irrelevant fields tolerated | Timestamps in response can differ by millisecond; auto-incremented IDs differ; opaque tokens differ |
| **Numeric tolerance** | Floating-point math | `expect(v2.total).toBeCloseTo(v1.total, 2)` — within $0.01 |
| **Order-insensitive** | List output where order isn't contractual | `expect(v2.users.sort()).toEqual(v1.users.sort())` |
| **Timestamp-insensitive** | Anywhere V1 + V2 stamp current time | Strip / normalise `created_at` / `updated_at` before compare |
| **ID-insensitive** | Auto-generated IDs that aren't a stable contract | Replace IDs with positional placeholders before compare |
| **Subset** | V2 returns more fields than V1 (additive change) | `expect(v2).toMatchObject(v1)` — V2 may have extra keys, must contain all V1 keys |
| **Superset** | V2 returns fewer fields than V1 (column projection win) | Document in contract that the dropped columns are unconsumed; assert V2 contains exactly the documented columns |

The tolerance for each assertion is a **decision** that goes in the contract. Future changes to tolerance need a contract revision, not a quiet test edit.

## Recipe 1 — Golden master

**When to use**: deterministic feature with well-defined inputs (no time, no random, no external).

**Setup**:

1. Curate an input corpus: `tests/parity/<feature>/inputs/<NN>.json`. Cover happy paths, every error path, every business rule from the contract, every edge case. Aim for ≥ 30 inputs for non-trivial features.
2. Run V1 against the corpus once; capture outputs into `tests/parity/<feature>/__golden__/<NN>.json`. Commit the golden snapshots.
3. Test body: load each input → call V2 → compare V2 output to the golden snapshot per tolerance taxonomy.

```ts
// Pseudocode (Vitest-style)
import { readdirSync, readFileSync } from 'fs';
import { handleFeature } from '../../../src/v2/feature';

describe('feature parity (golden master)', () => {
  for (const file of readdirSync('tests/parity/feature/inputs')) {
    test(file, () => {
      const input = JSON.parse(readFileSync(`tests/parity/feature/inputs/${file}`, 'utf8'));
      const golden = JSON.parse(readFileSync(`tests/parity/feature/__golden__/${file}`, 'utf8'));
      const v2 = handleFeature(input);
      expect(stripVolatile(v2)).toEqual(stripVolatile(golden));   // tolerance: timestamp-insensitive, ID-insensitive
    });
  }
});
```

**Refresh policy**:

- Golden snapshots are NEVER refreshed casually. A change in golden = a change in V1's behaviour = re-pin V1 in the ledger + revise contract.
- If V2 differs from golden, the failure is a real divergence — investigate before "updating the snapshot".

## Recipe 2 — Record-replay

**When to use**: production has traffic shapes the corpus doesn't (almost always).

**Setup**:

1. Tap V1 in production: capture (input, output) pairs to a sink (S3 / file / DB). Anonymise PII at the tap (no raw user data leaves the production network).
2. Sample N requests per day per endpoint (target N: 1000 for high-traffic, 100 for low-traffic).
3. Replay against V1 again in a parity-test harness (deterministic check — V1 should match its own recording within tolerance) → catches non-determinism.
4. Replay against V2 in the same harness → divergences = parity bugs.

```python
# Pseudocode (pytest-style)
@pytest.mark.parametrize('sample', load_replay_corpus('feature', n=200))
def test_v2_matches_v1_replay(sample):
    v2_output = call_v2(sample.input)
    assert tolerant_equal(v2_output, sample.v1_output, tolerance=PARITY_TOLERANCES['feature'])
```

**Refresh policy**:

- Sample corpus refreshed weekly (or on every deploy that changes V1) — keeps the parity oracle aligned with production reality.
- Anonymisation tested on every refresh — a single un-anonymised PII leak in the sample corpus is a serious incident.

## Recipe 3 — Property-based

**When to use**: properties are easier to articulate than examples (e.g., commutativity, monotonicity, invariants).

**Setup**:

1. Declare invariants in tests using `fast-check` / `hypothesis` / `proptest`.
2. Each property: generates an input, calls V1 + V2, asserts the property holds for both AND that V1 ≡ V2 within tolerance.

```ts
// Pseudocode (fast-check)
test.prop([validOrderArb])('V2 totals match V1 totals (within $0.01)', (order) => {
  const v1 = computeV1(order);
  const v2 = computeV2(order);
  expect(v2.total).toBeCloseTo(v1.total, 2);
  expect(v2.lineItems.length).toBe(v1.lineItems.length);
});
```

**Strengths**:

- Finds inputs the corpus didn't include.
- Pins the *contract* (e.g., "totals are commutative under reordering of line items"), not just examples.
- Shrinking finds minimal counter-examples.

**Caveats**:

- Generators must reflect real input distributions — generators that produce only "tiny" inputs miss prod cases.
- Invariants must be *truly* invariant — if V1's behaviour drifts under load, the property holds in test but fails in prod.

## Recipe 4 — Shadow traffic

**When to use**: read-only paths in production. Highest-confidence parity signal.

**Setup**:

1. Router / proxy duplicates each request to V1 + V2.
2. V1's response is served to the client (V2 isn't user-visible).
3. Both responses are logged to a comparison sink.
4. Async job tags each pair: match / mismatch (with a diff per tolerance taxonomy).
5. Mismatch rate = parity gap.

```text
Client ─▶ Router ─▶ V1 ─▶ response (served)
                  └─▶ V2 ─▶ response (logged for compare; discarded)

Compare job: read pairs, diff per tolerance → mismatch_rate metric → dashboard + alert
```

**Caveats**:

- Side-effecting V2 in shadow is destructive — V2 must be **read-only** in shadow OR write to a separate store. Dual-write requires recipe 5.
- V2's load mirrors V1's, so capacity must be planned.
- If V2 errors, shadow logs + investigates — does NOT degrade the V1 response.

## Recipe 5 — Dual-write audit

**When to use**: write-path features that must cut over without losing data.

**Setup**:

1. Cutover stage 1: V1 still authoritative; V2 writes-through to a parallel store.
2. Periodic (e.g., hourly) job compares V1's store and V2's store for the rows touched.
3. Mismatch = parity gap.
4. Cutover stage 2: V2 authoritative; V1 stops writing.
5. Cutover stage 3: V1 store retained read-only for retention period.

```sql
-- Audit query (pseudo)
SELECT v1.id, v1.checksum, v2.checksum, v1.updated_at, v2.updated_at
FROM   v1.orders v1 LEFT JOIN v2.orders v2 USING (id)
WHERE  v1.checksum != v2.checksum OR v2.id IS NULL;
```

**Caveats**:

- Schema differences (V2 column names ≠ V1) need a normalisation step before compare.
- Eventual consistency windows need a tolerance (e.g., "compare only rows updated > 5 minutes ago").
- Schema evolution during dual-write window is dangerous — freeze schema if possible.

## What to pin explicitly

Parity tests assert the **contract**, which means:

- **Outputs**: every documented output field, per code path (happy + every error).
- **Side effects**: DB writes (audit query checks them), queue publishes (consume in test, assert content), external HTTP (mock + assert call args / counts), cache invalidations (read after, assert miss).
- **Observable state changes**: row counts, queue depths, cache contents (only the keys the contract names).
- **Error shapes**: HTTP status codes, error type names, error code strings, error messages exposed to callers (NOT internal stack traces).
- **Logs systems depend on**: structured log fields that monitoring / billing / audit reads. NOT human-readable log strings.
- **Metrics**: counter increments, histogram observations the SLO depends on.
- **Performance**: latency p50/p95 within tolerance band; DB queries per call ≤ V1 (allowing V2 wins); memory per call ≤ V1.

## What NOT to pin

- **Internal helper outputs**: V2 can refactor freely if external behaviour holds.
- **Log strings meant for humans**: V2's log line phrasing can change if no system parses it. The structured fields stay.
- **Internal IDs / cursors / opaque tokens**: as long as they're stable for the caller across the test, the value can differ V1 vs V2.
- **Stack traces / debug info**: explicitly tolerance: `string-shape-only` or omitted.
- **Implementation-specific details**: V1's choice of HTTP library; V1's connection pool size; V1's specific SQL phrasing if the result set is identical.

## Tolerance file convention

Per-feature tolerance lives in `tests/parity/<feature>/tolerance.yaml`:

```yaml
exact:
  - $.id
  - $.status
  - $.error.code
structural:
  - $.created_at      # presence required, value irrelevant
  - $.trace_id
numeric_tolerance:
  $.total: 0.01
  $.tax: 0.01
order_insensitive:
  - $.tags
  - $.permissions
ignore:
  - $.debug
  - $.x_request_id
```

The runtime parity-comparator reads this file; engineers don't reinvent tolerance per assertion. Phase 4.6 generates the initial file from the contract.

## Pitfalls (named)

- **Snapshot whitewashing**: `--update-snapshots` blindly run when V2 disagrees with V1. The first commit that does this silently kills parity for that feature. Treat snapshot updates as contract changes — require ledger entry + reviewer.
- **Mock leakage**: V1 calls `getUser()`, V2 calls `getUser()` — both mocked to return the same value, so parity passes. Real prod has divergent behaviour. Parity tests should run against real fakes (test DB, test HTTP server) when feasible — see `testing/test-strategy.md`.
- **Replay sample staleness**: a 6-month-old replay corpus parity-passes but production is now hitting code paths the corpus doesn't cover. Refresh the corpus on every V1 deploy, weekly minimum.
- **Tolerance creep**: every parity diff prompts a "loosen the tolerance" reaction. Each loosening removes contract coverage. Loosening is a contract decision, not a test edit.
- **Property generators that don't reflect prod**: generators only produce small inputs; V1 + V2 agree on small inputs but diverge on prod-shape inputs. Calibrate generators against the replay corpus's input distribution.
- **Time / random / external state pollution**: "flaky" parity tests are usually contract gaps — the feature has hidden time-dependence or external-call dependence the contract didn't capture. Capture it; tolerate it; or stub it.
- **Parity tests in shadow only**: skipping CI parity tests because "shadow will catch it" — shadow only runs after deploy. CI parity tests catch failures BEFORE merge. Both run.
