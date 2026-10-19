# Precedents — Algorithms (complexity on data-sized input, recursion and termination, ordering and keying preconditions, randomness distribution, geodesy, floating-point stability, sketches)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in an **algorithms** class: work that grows faster than linearly in a size users or data
control, a recursion whose depth or cycles come from input, a loop whose progress is not
guaranteed, an algorithm run on input that breaks its precondition (sortedness, stability, key
uniqueness), a draw or a bucket whose distribution is not the one promised, a distance or box
computed on the wrong surface or axis order, an accumulated rounding error in numeric code, and an
approximate structure with no stated error or used as an exact authority. The oracles that prove them
are in [`proof-oracles.md`](../proof-oracles.md) § Algorithms (V590–V609). The detectors are
`complexity-scan` (CX §1–§6, RC §7–§10, with `scripts/algo-sites.py`), `algorithm-contract-scan`
(OC §1–§4, RD §5–§7, GE §8–§10) and `numeric-stability-scan` (NS §1–§5, SL §6–§7, gated on numeric
code) in the algorithms pack. They are run by `/analyze-complexity` and closed by
`/design-algorithm --from-audit`; the judge, in refute mode, is `@algorithm-designer`, and every
BLOCKER and HIGH a run keeps goes once more to `@verifier` mode `refute`.

**Code-quality owns a wrong expression; this pack owns a wrong algorithm.** A line that is wrong for
one input by itself — a comparator, a parse, a float `==`, a date step — is code-quality
`correctness-smell-scan` §2/§4/§6, proved by a boundary vector (V83). A procedure whose contract the
data or the scale violates — the bound it was written for, the depth it recurses to, the order or
uniqueness it assumes, the distribution it promises, the surface it computes on, the precision it
accumulates — is this pack's, proved by counting, adversarial inputs, distributions or reference
vectors. A tie is broken by the remedy: a different expression on the same line → code-quality; a
different data structure, a cap, a visited set, a memo, a stable sort or tie-break, a uniform draw, a
geodesic formula, a compensated sum → algorithms. A neighbour that sees the same `file:line` lists it
as corroboration, deduped by `file:line`; without the owner's pack the row is tagged
`<class> (owner pack <x> not installed)` and listed, never graded as the owner would grade it. The
splits:
- float `==`, NaN, `-0`, equals without hashCode → code-quality `correctness-smell-scan` §2; integer
  overflow, ids above 2^53, parses, truncating division, empty reductions, page math and the
  comparator *expression* (no comparator on numbers, a boolean comparator, subtraction overflow, a
  non-transitive tolerance) → §4; DST, month-end + 1 month, 29 February, `YYYY` → §6;
- money as float in code → code-quality §4; a float money column → database `schema-integrity-scan`
  §4; the money policy (rounding, allocation) → business `pricing-rule-scan`;
- `ORDER BY` on a non-unique key and deep `OFFSET` → database `query-shape-scan`; a query per element
  (N+1) → database `n-plus-one-scan`;
- ReDoS (exponential and polynomial) → security `injection-scan` §13; `Math.random` or
  `java.util.Random` for a token, OTP, nonce or prize → security `sast-scan` (CWE-338);
- a regex, validator or serializer built per call → performance `request-path-scan` §8; memory held
  across requests or an unbounded process-lifetime set → `memory-growth-scan` §1, a per-request clone
  of a large constant → its §8; when the algorithms pack is absent, `request-path-scan` §11 grades
  CX-1…CX-5 itself;
- retry loops without a cap → distributed-systems `retry-deadline-scan`; unseeded randomness in tests
  → testing `flake-source-scan`; property-test generation for pure functions → testing
  `property-invariants` (the fix command uses its frameworks).

## The claim, restated

§ 1 of the protocol takes this shape here. Every algorithms claim names **the bound, the contract or
the error**, not only the line:

> Under **[the size, depth, order, draw count or magnitude the input really reaches — with the cap
> that bounds it (a schema `.max(N)`, a `limit:`, `Math.min(…, N)`, a constant, a body limit) or
> `UNCAPPED`]**, **[the entry point: a route, a job, a consumer, a page render]** executing **[the
> procedure at file:line]** **[does n·m operations / recurses n deep / revisits a cycle / reads a
> stalled cursor / searches unsorted input / reorders ties / collapses two keys / draws a biased
> value / measures in degrees / loses k digits / trusts a false positive]** where **[the budget, the
> contract or the stated tolerance]** allows **[the bound]**, proven by **[V-number, family]**.

**Cap arithmetic is printed, never inferred.** A complexity claim cites the cap on each collection
and multiplies: `n_max × m_max = ops` against the budget (the pack rule's table: `n ≤ 5e3 → O(n²)`,
`n·m ≤ ~1e6` per request). `algo-sites.py` prints the column; the verifier checks each cap in the file
it names. A claim with an uncited cap is Unconfirmed until the cap, or its absence, is read.

**The proof rule.** Static two-ended facts pass gate 6 with both ends cited: the cap and its source
(or the absence of one at every entry point), the precondition the algorithm needs and the code path
that feeds it unsorted or non-unique data, the axis order a library expects and the order the caller
passes, a build flag and the code it compiles. Behaviour classes (super-linear growth, depth, cycles,
termination, distribution, accumulated error) need the oracle red: an operation count at N and 4N, a
depth bomb, a cycle injection, a chi-square with a fixed seed, a reference vector, a high-precision
reference. A model-asserted complexity class is never evidence (the pack's research: the best model
predicts the time-complexity class of a solution 41.4 % of the time). Without either, the row is
**Unconfirmed** with the oracle written out.

## Reading the seven gates for algorithms

| Gate | Algorithms |
|---|---|
| 1 Reachability | a route, a resolver, a consumer, a scheduled job, a page or component that renders on a real route; scripts, seeds, CLIs, benchmarks and test helpers fail here unless they are the backfill that runs in production |
| 2 Trigger | the input reaches the size, depth, order or magnitude: a tenant-sized list, a user-built tree, an editable parent pointer, unsorted rows from a second path, duplicate keys, a draw that decides eligibility, a point near the antimeridian, a sum of 10^6 mixed-magnitude floats |
| 3 Version | the runtime's stable-sort guarantee (JS ≥ ES2019, Python, Java objects), Rust ≥ 1.81 panicking on a non-total `Ord`, the stack size of the runtime (measured, never quoted), PostgreSQL ≥ 14 `CYCLE`, the library's own semantics (lodash `_.difference` hashes at ≥ 200 items) |
| 4 Existing control | a cap at the boundary (schema, `limit`, `Math.min`, body limit), a `Set`/`Map` index built once, a depth cap and a visited set, a memo, a unique cursor with strict `>`, a sort by the same key on every path, a DB unique constraint in the same scope, a vetted shuffle, a `::geography` cast, `math.fsum` / pairwise `np.sum`, a sketch confirmed against the source of truth |
| 5 Impact | a request or job that runs past its budget as the data grows, a crashed worker or a hung loop, a wrong search result, a lost or misattributed row, an unfair or biased assignment, a wrong distance or a missed point, a reported number off by more than the stated tolerance, a charge skipped by a false positive |
| 6 Proof | the two-ended static fact, or the V-oracle red on the current code |
| 7 Environment | the runtime and its stack size, the deploy's body-size limit, the SRID and column types the database really holds, the regions the product serves (does any data cross ±180°?), whether the numeric code runs with `-ffast-math` |

A cap that exists but sits **above** the budget is not a refutation: the row stays and drops one
severity step, and it is refuted only with the realistic size cited (a production count, an
enforced business rule, a schema).

## Complexity on data-sized input (CX)

1. **Bounded n.** A lookup over an enum-sized literal, a config list or any collection capped by a cited constant below the budget (`n·m ≤ ~1e6` per request) is not CX-1. A carrier poll that reads ≤ 800 open shipments and filters them against ≤ 800 finished ones does ≤ 640k comparisons per tick: below budget. *Flips back:* the cap is not enforced on every path that fills the collection, or the job's tick rate multiplies it past a per-second budget.
2. **Already indexed.** A `Set`/`Map`/dict built once outside the loop and probed inside, or a list sorted once and binary-searched inside, is the fix, not the finding (`new Map(xs.map(x => [x.id, x]))` was the house idiom at 339 sites in one real monorepo).
3. **lodash `_.difference` / `_.differenceBy` hash the exclusion list at ≥ 200 items**; `_.differenceWith`, `_.intersectionWith` and `_.uniqWith` do not and stay quadratic.
4. **V8 ropes.** JS `s += x` in a loop is near-linear while the string is only appended; flag it only when the string is indexed or searched each iteration.
5. **CPython in-place `str +=`** applies to a local with a reference count of 1; flag attributes, elements, or code that must also run on PyPy.
6. **Java `+` outside a loop** compiles efficiently (JEP 280); inside a loop it still allocates per iteration.
7. **Immutable and persistent structures** (Immer, Immutable.js) make "copy in reduce" O(log n) or amortised. Read the library before flagging; UNVERIFIED per library.
8. **A bounded FIFO may `shift()`.** A waiting list capped at `maxWaiting` (a bulkhead) shifts at most that many elements.
9. **Python `re.compile` in a loop is cached; a JS regex literal is one object per evaluation site**; `new RegExp(str)` in a loop is the real CX-4.
10. **Go `regexp`, Rust `regex`, RE2, .NET `NonBacktracking` and V8's linear engine are linear**; regex complexity is security's class in any case.
11. **Hash flooding is mitigated by the platform** (Java 8+ treeified buckets for `Comparable` keys, Python's salted `str` hash); only a custom hash function remains a candidate.
29. **One side capped at ≤ 50 is linear in the other.** `algo-sites.py` prints `const-small`; the work is O(n·k) with a constant k. *Flips back:* the "constant" is rebuilt from data (a list of a tenant's custom statuses).
30. **An ORM `find(Entity, {...})` inside a loop is a query per element**, database `n-plus-one-scan`'s class, not a linear scan; `algo-sites.py` drops a `.find` whose first argument is not a callback.
31. **A combinatorial generator stopped at the downstream cap** (`MAX_SKUS + 1`, then refuse) is the CX-6 GOOD block; filtering after full generation is not.

## Recursion and termination (RC)

12. **Recursion over parsed JSON cannot cycle** (`JSON.parse` builds trees), and its depth is bounded by the route's body limit; in Node a `RangeError` caught by the global filter fails one request. A finding only when no limit bounds the depth, the runtime is Go (stack overflow is fatal), or the handler is unauthenticated and the error kills the worker.
13. **A walker with a depth cap and an ancestor set** (caps on depth, array items, keys and string length; ancestors tracked, not siblings) is the RC-1/RC-2 GOOD block.
14. **A root-down walk of a parent map cannot loop.** A walk that starts from `parent = null` never reaches a cycle; dropping orphans is a display choice.
15. **Keyset loops on a unique key with strict `>` and a short-page exit terminate**, as does a recursive CTE that advances on `key >`. *Flips back:* the cursor is non-unique (`created_at`), the compare is `>=`, or the exit needs an empty page that a concurrent insert can keep from coming.
16. **Memoised recursion** (`functools.cache`, `lru_cache`, a `Map` memo, `useMemo` of a pure function) is not RC-3.
17. **Trusted, bounded-depth structures** — the project's own AST, a route config, a menu tree with a schema-enforced max depth — are not RC-1.
32. **A process-lifetime loop is not RC-4.** A reconnect loop, a stream reader or a poll worker with no `break` is meant to run until shutdown; whether it honours an abort signal is backend `job-lifecycle-scan` and distributed-systems territory.
33. **Recursion with a counted bound** — a retry that recurses with `attempt + 1` and stops at a constant, Euclid's `gcd` (depth O(log n)) — is not RC-1.

## Ordering and keying preconditions (OC)

18. **JS sort is stable since ES2019; Python and Java object sorts are stable.** A multi-pass sort that relies on stability is correct there.
19. **An unstable sort on unique keys** cannot reorder ties: there are none.
20. **A Map keyed by a column with a unique constraint in the same tenant scope** cannot collapse two rows (a customer index keyed by a phone key with a `(tenant, phone_key)` unique constraint).
28. **`.sort()` with no comparator on machine keys** (table names, ids, enum values) is code-point order by design — and code-quality's class.
34. **A binary search over a constant table sorted in source** (a rate table, a breakpoint list) with a test or an assertion that it is sorted meets its precondition.

## Randomness distribution (RD)

21. **`Math.random()` for jitter, backoff, animation, sampling, React keys or client draft ids** is not a draw.
22. **A sort-by-random shuffle in dev seed data and fixtures**, where fairness is irrelevant, is not RD-1.
23. **`crypto.randomInt(n)` is uniform**, and a murmur, xxhash or SHA-256 of an unsigned value `% n` is uniform enough; only a signed `hashCode()` and Python's salted `hash()` are RD-3.

## Geodesy (GE)

24. **Leaflet `[lat, lng]` is Leaflet's API**; only GeoJSON, PostGIS and Mapbox are lon-first.
25. **`ST_DWithin` on a projected SRID in metres, or with a `::geography` cast**, is already metric.
26. **Haversine is fine for UX distances**; an ellipsoid is needed only when the spec states a tolerance below the spherical error (the error figure is UNVERIFIED in the pack's research; V605's 0.5 % is a design choice).
35. **A service area that cannot cross ±180°** (a country or a city with a cited bounding box) does not need antimeridian splitting; GE-3 is then Hardening.

## Floating-point stability and sketches (NS, SL)

36. **`np.sum`, `math.fsum`, `statistics.fmean`/`pvariance` and `np.var`** are pairwise or compensated (or exact for `fsum`); a sum through them is not NS-1.
37. **Integer minor-unit arithmetic** (cents in `int`/`BigInt`/`bigint`) is exact and outside NS; float money is code-quality §4 anyway.
38. **float32 in ML inference with a tolerance the tests state** is a design choice, not NS-1. *Flips back:* the float32 value is accumulated into a reported total or a training statistic.
39. **A sketch used only as a negative pre-filter** whose positives are confirmed against the source of truth is the SL-2 GOOD block.
40. **An approximate count labelled approximate** (a dashboard's "about 1.2M visitors" from HyperLogLog) is not SL-2; billing or quota enforcement on it is.

## The project's own harness

27. **A project-owned shrinking fuzzer is the property harness.** A repo with its own fuzz specs (its own config, time budget, shrinking) gets its oracles written there; the fix command does not add `fast-check` or Hypothesis beside it.

## Rationalizations to reject

**Wrongly accepting a defect:**
- "This is O(n²)." With what n — and what caps each side (§ 1, § 29)?
- "The lookup is linear." Is the receiver a `Set`, a string, or a constant (§ 2, § 29)?
- "This recursion can overflow." Over what — parsed JSON under a body limit, a trusted AST, a capped tree (§ 12, § 17)?
- "This loop never ends." Is it meant to run until shutdown (§ 32)?
- "The sort is unstable." Are the keys unique, or is the runtime's sort stable (§ 18, § 19)?
- "The model says this is quadratic." A model's complexity class is not evidence; count operations.

**Wrongly dismissing a defect:**
- "It is capped." At what number, enforced on every path, and is that number below the budget?
- "The tests pass." With 3 elements — run V590 at N and 4N.
- "It is only the browser." One tab freezing on a merchant's catalog is still low severity, not zero.
- "JSON cannot cycle." Is it JSON, or an object graph with parent pointers built after parsing?
- "The draw looks random." Run the chi-square with a fixed seed.
- "Haversine is close enough." Is the code using haversine — or Euclid on degrees?

---

Sources: the algorithms research catalog (2026-10-19) § 4 for entries 1–28 (numbering kept) and its
notes on complexity, recursion, regex cost, property-based testing, numeric stability, ordering,
equality, time, randomness and geodesy (sources A1–A60 and B1–B52 there: lodash 4.17.21 source, JEP
280 and JEP 180, the CPython `re` and PEP 8 notes, the V8 rope note, MDN `Array.prototype.sort`, the
Python sorting HOWTO, Go `sort.Slice`, .NET `List.Sort`, the Rust 1.81 release notes, RFC 7946,
PostGIS `ST_Distance`, the "Will It Shuffle?" note); the batch-8 algorithms eval (2026-10-19) for the
ownership splits and entries 29–40. The observations behind § 1, § 2, § 8, § 12–§ 15, § 20, § 21,
§ 23, § 27, § 28, § 30 and § 32 were measured read-only on one NestJS + MikroORM + Postgres + React
monorepo and on the benchmark fixtures on 2026-10-19. Paraphrased; no text is reproduced beyond
identifiers.
