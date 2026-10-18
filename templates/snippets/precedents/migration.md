# Precedents — Migration (V1→V2 ports: surface, semantics, side effects, data cutover, strangler routing, parity proof)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in a **migration** class: V1 does X on a path, and V2, the port that is meant to keep V1's
behaviour, does Y. The class is the *difference*, never the single-codebase defect. The oracles that
prove it are in [`proof-oracles.md`](../proof-oracles.md) § Migration (V358–V388). The detectors
are `paired-inventory` (the lane engine), `surface-parity-scan` (SP §1–§9),
`semantics-parity-scan` (SM §1–§10), `side-effect-parity-scan` (SE §1–§5),
`data-cutover-orchestrate` (DC §1–§12), `cutover-routing-scan` (CR §1–§4) and `parity-proof-scan`
(PF §1–§5) (migration pack). They are run by `/compare-v1` and closed by `/find-and-fix
--from-audit`. `@parity-auditor` judges every detector row in refute mode, and every BLOCKER and
HIGH it keeps goes once to `@verifier` mode `refute`.

**Owned elsewhere.** Migration reports the V1≠V2 delta; whoever owns the class in one codebase
grades the defect that exists whatever V1 did. A neighbour that sees the same site lists it as
corroboration, deduped by `file:line`. Without the owner's pack, the row is reported here, tagged
`<class> (owner pack <x> not installed)`, and never graded as the owner would grade it. The splits:
- Permission widening (MG-AZ-1) is security's `@api-security-reviewer`; lost tenant scope (MG-AZ-3) is security's
  `@tenant-isolation-reviewer`.
- Decimal precision and 64-bit ids (MG-MN-3) are backend `wire-format-scan`.
- Transaction and isolation drift (MG-TX-1) is database `transaction-scan`.
- Catalog and plural drift (MG-I18N-1) is frontend `i18n-scan` (`catalog-parity.py --v1`).
- A V1-gated parity suite (PP-5) is testing `suite-execution-scan` §2c (`gated-suites.tsv`).
- Single-store DDL locks are database `migration-safety`.
- Dual-write and CDC mechanics are distributed-systems `dual-write-scan`.
- A major upgrade inside a port is core `/upgrade-dep`.

"Is it RFC-correct" is backend's question; "is it what V1 did" is migration's.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening**, or Refuted where the entry says so, unless the
flip evidence is shown with a V1 *and* a V2 `file:line`, a lockfile line, a ledger or `pair-map`
row, or a recorded oracle run. Numbers are stable: detectors cite `precedents/migration.md § <n>`.

Index: the claim and the gates · scope and evidence § 1–6 · ordering, nulls, formats § 7–10 ·
money § 11 · data § 12–16 · cutover § 17–19 · agents § 20 · the paired-inventory engine § 21–28 ·
Laravel → NestJS settled questions § 29–33 · engine and runtime drift § 34–38 · the incident
record · rationalizations.

## The claim, restated

§ 1 of the protocol takes this shape here. A candidate that fits it with no concrete value on
**both** sides is not a finding.

> On **[the route, entity verb, job, query or money path]**, V1 at **[the pinned SHA, v1 file:line]**
> does **[the behaviour: the guard, the rule, the effect, the rounding, the row]**, and V2 at
> **[v2 file:line, or "no counterpart after the search in § 1"]** does **[the other behaviour]**.
> There is no ADR plus `changes_baseline` for the difference (§ 3), and it is proven by
> **[the V-number and its family]**.

**Two parts, refuted separately.** Part A says *what the pair is*: "this V1 route is live", "this
V2 handler is its counterpart", "this lane row is a real key and not a normaliser artefact". Part
A is cheap to refute, so it is refuted first:
- a dead V1 route is not a drop (§ 2);
- a V1-ONLY row from a lane that failed calibration is not a row (§ 22);
- a guard found in a V2 global guard or gateway is not a missing guard (§ 1).

Part B says *what the drift does* to a client, a row or a report.

**The proof rule.** A lane diff row is a candidate. The class oracle in `proof-oracles.md`
§ Migration is the proof, by family:
- **D**: a differential replay, V1 and V2 on the same input.
- **J**: a side-effect journal multiset.
- **M**: a permission matrix.
- **R**: a reconciler with seeded drift.
- **P**: a property test with V1 as the oracle.
- **S**: a static fact with both ends cited.

Behaviour classes need D, J, M, R or P. A static-fact class (a dropped route, guard, observer,
constraint or cron entry) passes with the two-ended S fact (§ 5). Without either, the row is
**Unconfirmed**, with the oracle request written out.

## Reading the seven gates for migration

| Gate | Migration |
|---|---|
| 1 Reachability | The V1 element is **live**: it has callers on halt 11's six axes (app source, tests, cron, route, infra, telemetry). The V2 counterpart is mounted: the module is imported and the route is under the real global prefix (`dto-types.py --routes`) |
| 2 Trigger | The differing input reaches both sides. Examples: an empty string that V1's global pipe nulled, a negative half, a soft-deleted row, a role with no ability, a count of 2 in Arabic |
| 3 Version | Both lockfiles (`composer.lock`, `pnpm-lock.yaml`, …) and the PHP or Node platform line. A default that differs by version is `UNREAD` without them, never assumed (§ 6) |
| 4 Existing control | **The counterpart search (§ 1), cross-tree and cross-file.** Look in V2 global guards, pipes, filters, interceptors, base repositories, ORM filters and subscribers, the gateway or façade, DB triggers, infra (CronJob, Lambda) and sibling services. Then look for a `pair-map` row with a reason, and the ledger |
| 5 Impact | Someone observes the difference: a client, a consumer, a stored row, a report, an email someone waited for. A difference nothing observes is Hardening (§ 7, § 8) |
| 6 Proof | The family oracle fired on the **pre-fix V2 against V1** (paired), or the two-ended S fact. In solo mode only guarantee classes reach Finding (§ 21). A comparator that masks the class proves nothing about it (§ 15) |
| 7 Environment | The cutover phase: pre-shadow, shadow, dual write, read flip, write flip, past the point of no return. A shadow or reconcile row is real only in the phase that runs it. The process `TZ` and locale on both sides; the database engine and collation on both sides |

## Scope and evidence

1. **A V1 element with no V2 counterpart is a candidate, not a finding,** until the counterpart has been searched for. Search middleware, base classes, global scopes and guards, the gateway or façade, DB triggers, infra (CronJob, Lambda) and sibling services. *Flips back:* the search is written out, and each place reads empty.
2. **Dead V1 is not a drop.** A V1 route, job or effect with zero callers on all six reachability axes moves to the ledger as deprecated, with an ADR. It is Refuted as a drop. *Flips back:* any axis has a caller (an access-log hit, a mobile client, a partner, a cron).
3. **An intentional break with an ADR and a `changes_baseline` declaration is not drift.** Without both, it is drift. "We fixed a V1 bug" is an intentional break and needs the same record (PP-3).
4. **Single-codebase correctness belongs to its owner** (above). Migration reports only the V1≠V2 delta. A V2 float money field is backend's whatever V1 did. A V1 `decimal:2` cast that V2 renders as a float is the delta, and both rows link.
5. **A parity claim needs execution.** "The code is equivalent" from reading never passes gate 6 for a behaviour class. A static-fact class passes with both ends cited.
6. **Versions come from lockfiles.** Framework defaults decide many rows: Laravel's global trim, Pydantic v1 vs v2 coercion, i18next plural suffixes, the PHP 8.4 `round()` change, Express 5's query parser. No lockfile means the version-gated row is `UNREAD`.

## Ordering, nulls, formats

7. **Order drift is a finding only when something depends on the order:** pagination, "first match", exports, a UI default sort, or a contract statement. Otherwise it is Hardening. *Flips back:* a consumer that sorts nothing and shows the list as delivered (Hyrum's law; read the consumer).
8. **Presence drift (`null` vs absent vs `[]` vs `{}`) is a finding when any consumer is typed or branches on presence,** for example a mobile app with a strict decoder. A `structural` tolerance that ignores presence is itself a comparator defect (CO-4, § 15).
9. **Message text is tolerated; status, `code` and field keys are not.**
10. **Timestamps, generated ids and host names are noise only when calibration shows they differ between two V1 runs** (Scientist's control-vs-control rule; Diffy's primary-vs-secondary, used as a design reference only because its licence is CC BY-NC-ND 4.0). Every other entry in an ignore list carries a reason.

## Money

11. **Any rounding-mode or rounding-order difference on a stored, charged or reported amount is high,** whatever its size. A display-only difference is Hardening. *Flips back:* the displayed figure is the one charged, or the one a report sums.

## Data

12. **An immutable, append-only dataset needs no dual write,** but it still needs counts and checksums before the read flip.
13. **A declared, bounded replication lag, with the reconcile threshold set to match, is not drift.** An undeclared lag is drift.
14. **Sampling is acceptable only with a stated rate and confidence,** plus full scans of the most recently written ranges.
15. **A reconciler configured with a masking option proves nothing about the masked class.** That class is reported Unconfirmed. Known masks (research notes, 2026-10-18):
   - Google DVT row hashes apply RTRIM.
   - DVT wildcard aggregates skip string lengths and timestamps unless `--wildcard-include-string-len` / `--wildcard-include-timestamp` is set.
   - DVT aggregates timestamps as unix seconds.
   - DVT `-cim` uppercases values.
   - pt-table-checksum needs `--trim` and `--float-precision`.
   - AWS DMS validation stops after 10,000 failures, and fails against Oracle when the Postgres PK collation is not "C".
16. **pgloader, DMS or ETL default casts are a finding on any column they touched,** unless the V2 schema declares the cast intentional. pgloader's defaults turn zero dates to NULL (dropping NOT NULL), `tinyint(1)` to boolean, and `datetime` to `timestamptz` read in the session time zone.

## Cutover

17. **Shadow on a write route without side-effect isolation is a blocker,** even at 1%. Mirrors discard responses, and mirrored writes reach real downstreams. Istio and Envoy also append `-shadow` to the host.
18. **The point of no return must be a named, signed step:** the reverse path switched off, or V1 objects dropped. Dropping V1 objects in the release that flips writes is a finding. The successful public cutovers kept a reverse path: Stripe (2024-06-06), Figma (2023-04-04) and Notion (2021-10-06).
19. **A session or auth difference across the façade is a finding only on routes that both halves serve during the window.**

## Agents

20. **A port PR that modifies, skips or re-records V1-pinned tests or goldens is Refuted as evidence of parity,** whatever reason it gives, unless a separate PR with an ADR made the change first. The repo-baseline `test-integrity.py` rows `new-skip` and `undeclared-baseline-rewrite` are the mechanism. A line-coverage drop above 5 points is the FreshBrew gate (NeurIPS 2025): in its audit of 50 attempts, drops that large were consistently reward hacking. Many hacks fell under 5 points, so a small drop clears nothing on its own.

## The paired-inventory engine

21. **Solo mode (a recorded V1 inventory, no V1 tree) never prints GO.** A recorded V1 row cannot be refuted on V1 liveness or on a V1 middleware the record did not capture. **Guarantee classes** can still become Findings from the recorded line plus a full V2 counterpart search: AZ-1 widening, AZ-3 scope lost, a lost unique / FK / NOT NULL constraint, lost soft delete, an absent global trim or empty→null pipe. **Drop classes** (RT-1, SE-1, JB-1, VO-1, …) stay `Unconfirmed-solo`, with the settling probe "re-run with `--v1=<path>`".
22. **A lane that diffs a known-parity pair is asymmetric, not the port.** The calibration pair (the clean twins) must diff to 0 rows. Otherwise the lane prints `blocked (lane <x> asymmetric: k rows on the calibration pair)` and every row it would emit is withheld.
23. **Prefix sanity.** When more than 50% of V1 keys are V1-ONLY **and** more than 50% of V2 keys are V2-ONLY, the normaliser is wrong (a global prefix, a version segment, a `RouterModule` path), and no row is a candidate until a `pair-map` prefix row or a `--routes` re-run fixes the join.
24. **A recorded inventory is fresh only at the pin.** A `sha` that differs from the ledger's `v1_commit_pinned` makes every row of that lane Unconfirmed `stale-v1-inventory`. An extractor hash that differs from the installed lane module makes the lane `blocked (extractor changed since record; re-record)`. A lane absent from the record is `blocked`, never `checked`.
25. **A skipped V1-gated suite is NOT-RUN, never PASS.** Parity tests behind `HAS_V1 ? describe : describe.skip`, or `skipif(not os.environ…V1…)`, run only where CI sets the variable. Every parity claim resting on a `v1` row of `gated-suites.tsv` with `ci_sets no` is NOT-RUN, and the verdict cannot exceed GO-UNVERIFIED.
26. **A `pair-map` row without a reason is ignored and printed.** A rename, a vocabulary map (`can:orders.update` ↔ `@Permissions('orders:update')`) or a moved effect clears a V1-ONLY row only with `ADR-NNN`, `rename` or `moved-to-<place>`, read from a file V2's authors own. Ability names are compared after lower-casing and unifying `[._:-]`.
27. **One wiring row is one finding with N sites.** One V1 global middleware, guard, scope, trim pipe or observer trait missing in V2 is one finding. `TrimStrings` covers every string field; `SoftDeletes` covers every list of that model; an `auth:sanctum` group covers every route in it. Write routes, guards and money paths are never bulk-closed by name.
28. **A counterpart outside the application is a counterpart once it is read:** nginx `auth_request`, a k8s `CronJob`, a DB trigger, a gateway rule. *Flips back:* the file was not read (then it is Unconfirmed with the file to read), or the counterpart covers fewer routes, roles or schedules than V1.

## Laravel → NestJS settled questions (the silent top five)

Facts from framework docs and source read 2026-10-18 (research notes, D-classes), paraphrased.
Each holds only under its version condition, which is read from the lockfiles.

29. **V1 trims and nulls every string; V2 does neither by default.** The Laravel skeleton registers `TrimStrings` and `ConvertEmptyStringsToNull` globally (Laravel 12.x request docs). NestJS and Express ship no equivalent. *Read:* `bootstrap/app.php` (11+) or `app/Http/Kernel.php` (≤ 10) for the two entries and any `$middleware->remove(`/`except`. *Not drift when* V2 registers a global trim and empty→null transform covering the same routes. A per-DTO `@Transform` on some fields is partial: the rest are the finding (§ 27).
30. **Nest routes are open unless a guard runs.** V1 authorizes in layers the port does not see: route and group `middleware`, controller-constructor middleware, `authorize()`, policies, FormRequest `authorize()`, global scopes. *Not drift when* an `APP_GUARD` covers the route (an `@Public()` opt-out is then the thing to read), or the gateway authenticates it (§ 28).
31. **422 becomes 400, and every error becomes a list of messages.** Laravel validation answers 422 with `{message, errors: {field: [...]}}`, all errors by default (`bail` / `stopOnFirstFailure` aside). Nest's `ValidationPipe` answers 400 with `{statusCode, error, message: string[]}`. *Not drift when* an ADR plus `changes_baseline` declares the new envelope **and** every V1 client is updated; otherwise each client branching on 422 or on `errors.<field>` is broken (V362).
32. **Observers and traits carry effects no controller shows.** Observers (`::observe(`, `#[ObservedBy]`), `$dispatchesEvents`, `booted()` closures, `LogsActivity` / `Searchable` / `Notifiable` traits and `EventServiceProvider::$listen` all emit with no call at the use site. *Not drift when* a V2 subscriber, listener, outbox row or DB trigger emits the same (entity, verb) multiset (read it; § 28).
33. **PHP rounds negative halves away from zero; JS rounds them up.** PHP `round()` defaults to half away from zero (`round(-2.5)` is −3). JS `Math.round` ties toward +∞ (`Math.round(-2.5)` is −2; MDN, modified 2025-07-10). PHP 8.4 also removed pre-rounding: `round(0.285, 2)` is now 0.28 where earlier versions gave 0.29. *Read:* the PHP platform version and every rounding call on the money path, on both sides. *Not drift when* both sides call one decimal library with an explicit mode, or the value is display-only (§ 11).

## Engine and runtime drift that rides along with a port

34. **MySQL → Postgres reorders unordered queries.** Without `ORDER BY`, Postgres returns rows in an unspecified order, and InnoDB's practical PK order disappears. MySQL sorts strings case-insensitively by default and leaves the order of case variants undefined. A finding only with a consumer (§ 7).
35. **A `_ci` unique key becomes case-sensitive.** On a MySQL `_ci` collation, `A@x` and `a@x` collide; Postgres's default collations are deterministic, so V2 admits both. Read the V1 column collation and the V2 index (a `lower()` expression index or `citext` is the control).
36. **REPEATABLE READ becomes READ COMMITTED.** InnoDB's default is REPEATABLE READ; Postgres's is READ COMMITTED. A read-modify-write that V1's engine serialised needs its lock or version check in V2. The class is database's (MG-TX-1); migration supplies the V1 transaction inventory.
37. **PHP JSON shapes are not JS JSON shapes.** `json_encode([])` gives `[]`, never `{}`. An array that `unset` left non-sequential becomes an object. `12.0` prints as `12` without `JSON_PRESERVE_ZERO_FRACTION`. These are presence and shape rows (§ 8), not rounding.
38. **Laravel pipes are not CLDR categories.** `'one|many'` and `{0} …|[1,19] …|[20,*] …` select by count or range. i18next v21+ selects by `Intl.PluralRules` category, and Arabic has six categories (zero one two few many other). A two-form V1 string ported 1:1 renders wrong for Arabic counts such as 0, 2, 3–10 and 11–99. Range forms have no CLDR equivalent and need a read. Frontend owns the class; `catalog-parity.py --v1` supplies the rows.

## The incident record

There is no public postmortem of a Laravel → NestJS port. The rows above rest on framework
documentation and mechanism. Adjacent dated incidents:
- an e.foundation service migration let users see other users' files for about 15 minutes (notice dated 2022-06-15);
- Twitter added `id_str` in 2010 because JavaScript parsers corrupted 64-bit ids;
- Odoo's JavaScript front end rounded a 4.245 payment to 4.25 but its −4.245 refund to −4.24, so the refund did not cancel the payment; the fix was a "Python-like rounding method" (commit date unverified).

A finding never invents an incident to raise its severity.

## Rationalizations to reject (migration)

**Wrongly accepting parity:**
- "The port compiles." FreshBrew's best agent compiled 79.8% but succeeded on 52.3%.
- "The tests pass." Which tests, run against what? Dropping MigrationBench's test-integrity checks raised the reported success from 71.67% to 97.67%.
- "It is the same code in TypeScript." Look-alike APIs differ: `round`, `substr`, `array_search`, `json_encode`.
- "The agent says parity." LLM judges scored at most 0.65 AUROC at telling false success from real success (arXiv 2606.09863).
- "0 mismatches." Check what the comparator ignores, and whether control-vs-control ran.
- "We will reconcile after cutover." The reverse path decides whether "after" exists.
- "The suite is green in CI." Did the V1-gated tests run, k > 0 (§ 25)?

**Wrongly flagging drift:**
- "V1 has the route, V2 does not." It may be dead (§ 2) or moved to the gateway (§ 28).
- "The order changed." Is there a consumer (§ 7)?
- "The message text differs." Text is tolerated (§ 9).
- "V2 rejects what V1 accepted." Is there an ADR plus `changes_baseline` (§ 3)?
- "Every route lost its guard." Look for a global `APP_GUARD` (§ 30).
- "1,200 V1-ONLY routes." That is a normaliser failure (§ 23), not 1,200 findings.

---

Sources: the migration research catalog (2026-10-18) § 4, which gives precedents 1–20, and its
notes. Notes A (parity-proof tooling and LLM-port evidence) give Scientist, Diffy (CC BY-NC-ND 4.0,
design reference only), Istio, Envoy and nginx mirroring, FreshBrew (arXiv 2510.04852), MigrationBench
(arXiv 2505.09569 v3) and arXiv 2606.09863. Notes B (data cutover, drift classes and upgrade
tooling) give the Stripe, Figma and Notion cutovers, DVT 8.10.0, pt-table-checksum, AWS DMS
validation, pgloader, MySQL 8.4 and PostgreSQL 18 docs, the Laravel 12.x request, validation and
localization docs, NestJS validation docs, the PHP `round` and `json_encode` manuals with the PHP 8.4
migration notes, MDN `Math.round`, the i18next migration guide, and the incident rows. The batch-6
migration eval (2026-10-18) § 3 adds the engine rules § 21–28 and § 4.11 sets the file's scope.
Paraphrased; no text is reproduced beyond short quoted identifiers.
