---
name: paired-inventory
description: "Paired V1/V2 lane inventory: the same keyed rows from both trees, set-diffed into candidates — read-only."
kind: skill
pack: migration
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: paired-inventory

## Premise

A migration class is a **difference**: V1 does X on a route, an entity verb, a job or a money path, and V2 does Y. Reading both trees by eye misses it in both directions, and counting primitives per file (the validator's `extract_inventory_primitives`) cannot see a guard lost on route A while one is added on route B. This skill is the engine every migration detector calls: **one row schema, two extractors, one diff**. It prints **candidates**, never findings. `surface-parity-scan`, `semantics-parity-scan` and `side-effect-parity-scan` (this pack) turn a candidate into a finding only after the counterpart search and the refute pass of [`refute-before-report.md`](../../../../snippets/refute-before-report.md), with the precedents in [`precedents/migration.md`](../../../../snippets/precedents/migration.md) § 21–28.

"The same extraction on both trees" means the same **schema and normaliser**, not the same regex. A Laravel route, a Django `urls.py` entry, a Rails `routes.rb` line and a Nest route are read by different code, and all of them emit `GET /api/orders/{}`. That asymmetry is the main risk, so every lane is **calibrated** like Scientist's control-vs-control: a known-parity pair must diff to 0 rows, or the lane prints `blocked` and emits nothing.

The engine is `scripts/pair-inventory.py` (stdlib Python 3.8+, `python3 -I` safe). It loads seven lane modules from beside it (its `MODULES` tuple): `scripts/lanes_laravel.py` (V1 Laravel, a PHP-free reader), `scripts/lanes_node.py` (NestJS, through the backend pack's `dto-types.py`), and five per-stack modules whose every lane is tagged `partial` — `scripts/lanes_ruby.py` (Rails), `scripts/lanes_python.py` (Django, FastAPI), `scripts/lanes_java.py` (Spring), `scripts/lanes_js.py` (Express, Fastify) and `scripts/lanes_go.py` (Go). Those five share the readers in `scripts/lanes_common.py`, so the six files `lanes_common`/`ruby`/`python`/`java`/`js`/`go` replace the old single `lanes_other.py` (gone; a recorded inventory naming it is `blocked (extractor changed since record; re-record)`). An edit to `lanes_common.py` changes every per-stack module's extractor hash.

## The rule

A diff row is printed as a candidate only when all of these hold:

1. **Both sides were extracted by a calibrated lane.** For Laravel → NestJS (the program's port), the built-in calibration pair runs before every paired run. Any other stack pair (Rails, Django, Spring, FastAPI, Go on either side) needs `--calibration-pair=<v1>,<v2>` (three features the team calls ported-and-correct). Without one, every row carries `uncalibrated`.
2. **The keys joined.** If more than 50% of V1 route keys are V1-ONLY **and** more than 50% of V2 keys are V2-ONLY, the normaliser is wrong, not the port. I-ROUTES, I-AUTHZ and I-RULES halt and print the 10 nearest pairs plus a suggested `pair-map` prefix row (precedent § 23).
3. **V1 was read at the pin.** Paired mode reads a `git archive` snapshot of the pinned SHA, never the live checkout (§ Modes). Solo mode reads a record whose `sha` equals the pin and whose extractor hash equals the installed module (precedent § 24).
4. **Every listing ran.** An `rg` exit 2, a `dto-types.py` failure or an unreadable file makes the lane `blocked`. It never makes it "0 rows".

## Boundaries

- The engine owns extraction, normalisation, pairing and the diff. The **classes** belong to the detectors that consume the rows (§ Lanes, *Feeds*), and the **verdict** belongs to `/compare-v1` and `@parity-auditor`.
- A widened or dropped guard (I-AUTHZ, MG-AZ-1) → security `@api-security-reviewer`; a lost tenant scope (I-SCOPE tenant, MG-AZ-3) → security `@tenant-isolation-reviewer` — when the security pack is installed. Without it, the consuming detector reports the row tagged `security-class (owner pack security not installed)`.
- Nest routes, params and decorator blocks come from the backend pack's `dto-types.py --routes`, in the `scripts/` folder of its `validation-boundary-scan` skill (source `templates/packs/backend/skills/validation-boundary-scan/`, installed `.claude/skills/validation-boundary-scan/`), when the backend pack is installed. It is called, never copied. Without the backend pack, the Nest I-ROUTES, I-AUTHZ and I-RULES lanes print `blocked (dto-types NOT-RUN)`.
- DDL (I-SCHEMA) → database `schema-map.py` (the `index-coverage-scan` skill's), when the database pack is installed: `--lane=laravel` replays Laravel Blueprints, the snapshot lane reads MikroORM, the DDL lane reads SQL migrations. Django and Rails migrations have no lane (`blocked (gap …)`). Without the database pack, I-SCHEMA prints `blocked (schema-map NOT-RUN)`.
- V1-gated parity suites (PP-5) → testing `suite-execution-scan` §2c `gated-suites.tsv`, when the testing pack is installed. Without it, the one grep in § Pre-flight lists them.
- Catalog and plural drift → frontend `catalog-parity.py --v1`. Transaction drift → database `transaction-scan`. Neither is a lane here.

## Lanes

One schema per lane. Every row is `lane · key · attrs · at · excerpt`. `attrs` is `k=v;k=v`, sorted. Set values are comma-joined, sorted and unique. `''` is the empty set, and `?` means **unread**, which is never diffed. Only the *compared* attrs produce CHANGED rows. The others ride along for the reader.

| Lane | Key | Compared attrs | V1 Laravel | V2 NestJS | Feeds |
|---|---|---|---|---|---|
| I-ROUTES | `METHOD /path` (`{}` params, `{*}` wildcard, lower-case, no trailing `/`; all-methods = `ANY`) | `opt` (optional-param count), `constraint` (`pos:int\|uuid\|in\|re…`; compared only when V1 has one) | `routes/*.php` facade chains by brace depth, `resource`/`apiResource` expanded with `only`/`except`, `match`/`any`/`fallback`, entry files from `withRouting` (`apiPrefix`) or `RouteServiceProvider` | `dto-types.py --routes` `mounted` paths: global prefix with `exclude`, URI version, `RouterModule`; `ParseIntPipe`/`ParseUUIDPipe` constraints | SP §1 §2 §9 |
| I-AUTHZ | route key | `authn` (required\|none), `abilities`, `roles`, `extra_guard` (yes\|no); `src` says `declared-by-decorator(<name>)` when `@Permissions('x')` has no definition in the tree | route + group middleware (`auth*`, `can:`, spatie `role:`/`permission:`), aliases and group appends, controller `__construct` / `HasMiddleware`, `$this->authorize`, `Gate::`, `authorizeResource`, FormRequest `authorize()` | `APP_GUARD` / `useGlobalGuards`, class + method `@UseGuards`, metadata decorators traced to `SetMetadata` / `Reflector.createDecorator` / `applyDecorators`, `@Public()` | SP §3 §4 |
| I-RULES | `<route key> <field>` (`items.*.qty`); `GLOBAL trim_strings`, `GLOBAL empty_to_null` | `presence`, `nullable`, `type`, `format`, `max`, `min`, `in`, `regex`; `on` for the globals | FormRequest `rules()`, `$request->validate`, `Validator::make`, `Rule::in` / `Rule::enum`; `required` on a string or array sets `min=1`; params read by hand (`min((int) $request->input('per_page', 25), 100)`: optional, int, `clamp_max=100`; a paginator's `page`: `clamp_min=1`); aliased and namespaced controllers resolved through the route file's `use`; globals on by default from Laravel 11 (`composer.lock`) unless `->remove(` | class-validator PROP blocks followed through `@ValidateNested`; zod schemas through the pipe argument or `z.infer<typeof S>`, with `.extend()` and element rules (`roles.*`); named `@Query('per_page')` params read like V1's (`Math.min`/`Math.max` → `clamp_*`); a global pipe counts only if its body trims / nulls and the function that registers it is called | SP §7 |
| I-ENUM | `type:<ident>` or `col:<table>.<column>` | `values` (wire / stored) | PHP 8.1 enums, `$casts`, migration `->enum()` | TS enums with values, string unions, `z.enum` (incl. `as const` arrays), MikroORM `@Enum`, TypeORM enum columns | SP §6 |
| I-ERR | `validation`, `not_found`, `unauthenticated`, `forbidden`; `code:<code>` when the error renders a machine code, else `exc:<ident>` | `status` | framework defaults (422 / 404 / 401 / 403), `withExceptions` / `Handler` render closures (`'code' => '…'`), exception classes with a status | `ValidationPipe` `errorHttpStatusCode` / `exceptionFactory`, zod pipes, `HttpException` subclasses, parametric errors (`new DomainError(409, msg, 'order_not_editable')`), built-ins with `{ code }`, `@Catch` filters that set a status, auth guard 401 vs 403 | SP §8 |
| I-SIDE | `<table>.<event>`, a route key, or `event:<ident>` | `kinds` ⊆ {mail, notify, event, job, webhook, audit, activity, search, cache} | observers (`#[ObservedBy]`, `::observe`, `$observers`), `booted()` closures, `LogsActivity` / `Searchable`, `$dispatchesEvents`, listeners, handler bodies + one hop | MikroORM / TypeORM subscribers and lifecycle hooks, `@OnEvent`, queue adds classified by queue name, handler bodies + one hop | SE §1 §2 |
| I-SCHED | `job:<words>` (order-free, verbs dropped) | `cron` (canonical), `tz`, `overlap` | `routes/console.php` `Schedule::`, Kernel `schedule()`, `withSchedule`; frequency helpers → cron | `@Cron` / `@Interval` (CronExpression from its member name), BullMQ `repeat` / `upsertJobScheduler`, k8s `CronJob` (one that runs `php artisan` is V1 infrastructure: skipped, noted) | SE §4 |
| I-SCOPE | `table:<singular table>` | `soft_delete`, `tenant` | `SoftDeletes`, `#[ScopedBy]`, `addGlobalScope`, tenant traits | MikroORM `@Filter({ default: true })` and its aliases, config `filters`, `addFilter`, TypeORM `@DeleteDateColumn` | SP §5, DC §7 |
| I-SCHEMA | `col:<table>.<column>`, `unique:<table>(<cols>)`, `fk:<table>(<cols>)`, `view:<name>`, `derived:<table>.<column>` (a column a trigger, formula or generated expression maintains); a V1 table with no V2 row at all collapses to one `table:<t>` row | `null` (only when V1 is NOT NULL), `numeric` (p,s), `ref`, `on_delete`; presence for views and derived columns | `schema-map.py --lane=laravel`; `CREATE VIEW` / `CREATE TRIGGER … UPDATE t SET c` in migrations | `schema-map.py` snapshot or DDL lane; SQL views and triggers in migrations; MikroORM `formula:` | SE §5, DC §5–§9 |
| I-MONEY | `area:<domain noun>` of the **outermost** money method: modes flow up the call graph (`$this->pricing->lineNet()`, `roundHalfAway(x, 2)`), and a method another method calls is a helper, not a row. The noun is the first non-role word of the class, the file, its folder, then the function. Browser-app files (display rounding) are left out and counted | `modes` ⊆ {half-away, half-even, half-up, float-tofixed, trunc, floor, ceil} | `round()` (± `PHP_ROUND_HALF_EVEN`), `number_format`, `bc*` (trunc), brick `RoundingMode` | `Math.round` (half-up), `toFixed` (float, or half-away under decimal.js / big.js), decimal.js `ROUND_*`, `Intl.NumberFormat` | SM §1–§3 |
| I-CONF | `timezone`, `locale`, `per_page`, `currency` | `value` | `config/app.php` with `.env.example` winning; `per_page` = the request default (`input('per_page', 25)`) or an empty `paginate()` (the model's `$perPage`, else 15); a fixed `paginate(50)` is a route default, left out | app config `process.env.X ?? 'd'`, Dockerfile / manifest `TZ`, `.env.example`, i18next `lng` (not `fallbackLng`), DTO or zod page-size defaults | SM §8, SP §9 |

I-SCHED and I-MONEY keys are word sets (an I-MONEY row adds its function's words). A V1 key with no exact twin pairs with the single V2 key whose words overlap best (Jaccard ≥ 0.5, unique, mutual), and the row carries `paired-by-name(<v2 key>)`. In I-RULES a clamp (`clamp_min`/`clamp_max`) coerces and never rejects, so it is kept beside the compared `min`/`max`: V1 clamping where V2 rejects is a real CHANGED row.

**Stacks.** `python3 -I "$PI" --list-lanes` prints every stack, its module hash and its lanes. `laravel` and `nest` are calibrated by the built-in pair [V]. `rails`, `django`, `spring`, `express`, `fastify`, `fastapi` and `go` are `partial`: their extractors are measured on fixtures (§ Measured), but no paired fixture covers them yet [K?]. A lane a stack lacks prints `blocked (gap — <reason>)`, never `N/A`.

## Modes

| Mode | Command | How V1 is read | Verdict ceiling |
|---|---|---|---|
| **paired** | `--v1=<root> --v2=<root> [--pin=<sha\|ref>]` | `GIT_OPTIONAL_LOCKS=0 git archive <pin>:<subdir>` streamed into the run folder. The pin defaults to the ledger's `v1_commit_pinned`. A moving checkout cannot change the result. | NO-GO / GO-UNVERIFIED / GO |
| **paired, live** | `… --live-v1` | the V1 directory in place (no git, or an uncommitted fixture). Every row is tagged `live-v1`. | GO-UNVERIFIED |
| **solo** | `--v2=<root> --v1-inventory=<dir>` | the recorded TSVs | NO-GO / GO-UNVERIFIED, **never GO** |
| **record** | `--record-v1 --v1=<root> --pin=<sha> --out=<dir>` | as paired. It writes one TSV per lane, run only through `/migration-scan --record-v1-inventory`. It is the one write this design makes into V2 (`ai/migration/v1-inventory/`), never into V1. | — |
| **calibrate** | `--calibrate --v1=<pair-v1> --v2=<pair-v2>` | the known-parity pair | every lane `calibrated (0 rows)` or `blocked (lane <x> asymmetric: k rows …)` |

**Exit codes.** `0` ran with no candidates · `1` candidates · `2` usage · `3` self-test failed · `4` a lane is blocked, a lane module failed to load, or a file under either root is newer than the run start. A lane that is a declared stack gap (`blocked (gap …)`) sets 4 only when it was named in `--lanes`.

**The record contract.** One file per lane, two header lines, then rows:

```
# pair-inventory 1 · lane=I-ROUTES · side=v1 · sha=<pin> · root=<v1 root as given> · stack=laravel
# extractor=lanes_laravel.py@sha256:<16 hex> · normaliser=1 · generated=<UTC ISO> · rows=<n>
# lane	key	attrs	at	excerpt
I-ROUTES	POST /api/orders	constraint=;handler=OrderController@store;opt=0	routes/api.php:22	Route::post('/', 'store')->…
```

Freshness, checked per lane in solo mode:
- a `sha` that differs from the pin tags every row `stale-v1-inventory(<sha> vs pin <pin>)`, so those rows are Unconfirmed;
- an extractor hash or normaliser that differs from the installed one makes the lane `blocked (extractor changed since record; re-record)`;
- a `rows=` count that differs from the rows read gives `blocked (record truncated)`;
- a lane with no file is `blocked (no V1 tree, no recorded <lane>)`.

**The pair map** (`<v2>/ai/migration/pair-map.tsv`, or `--pair-map`; read-only, owned by V2's authors) has the columns `lane · v1-key · v2-key · reason [· attr=value]`. The header row is skipped, and `*` in a key matches any run of characters.
- A rename names both keys. An I-ROUTES rename or removal also applies to the I-AUTHZ, I-RULES and I-SIDE rows of that route.
- `-`, or a reason starting `moved-to`, maps a key away. It is listed under `mapped away`, and the counterpart outside the app still has to be read (precedent § 28).
- `prefix:/api ⇥ prefix:/v1` rewrites V1 route prefixes.
- `value:orders.update ⇥ value:orders:update` maps an attribute vocabulary.
- `- ⇥ <v2-key> ⇥ reason` acknowledges a key V2 has and V1 never had (`I-SCHEMA ⇥ - ⇥ col:*.legacy_id ⇥ ADR-0007`). An I-ROUTES row also covers that route's I-AUTHZ, I-RULES and I-SIDE rows.
- `<key> ⇥ <key> ⇥ ADR-NNN … ⇥ attr=value` accepts one attribute change, and only that exact V2 value: `I-ENUM ⇥ *ticket*status ⇥ *ticket*status ⇥ ADR-0008 ⇥ values=closed,merged,open,pending,solved`. A further drift on the same attribute is still a candidate. A row with an attribute but no `ADR-NNN` in its reason is ignored and printed.

Every closed row is listed in the ledger under `pair-map:` with its reason, so a reviewer reads what the map hid.

Keys in the map use the lane key formats above. A row with no reason is ignored and printed (precedent § 26).

## Tool lane and the never-write rule

The static lanes always run offline: no composer, npm or pip install, and nothing is booted. Framework tools (Laravel `php artisan route:list --json -vv --except-vendor`, Rails `bin/rails routes -E`, Django `show_urls --format json`, Spring `/actuator/mappings`) are an opt-in cross-check. Run them only on the snapshot under the run folder, only when its `vendor/` exists, and never on the audited trees. Booting Laravel may write `bootstrap/cache/*.php` [K?].

The engine writes only under `--out`, which defaults to a fresh `${TMPDIR}` folder. It refuses an `--out` inside either root (exit 2). Before it exits, it walks both roots for files newer than the run start and prints `write check: <n> files newer …`; any hit exits 4. `sys.dont_write_bytecode` keeps importing the lane modules from leaving a `__pycache__` in the installed skill folder. `dto-types.py` runs as `python3 -I -B`. Every `rg` runs with `cwd=<root>` and the path `.`, includes first and the shared exclusion array last:
- vendor, build and coverage directories;
- tests, specs, mocks and fixtures;
- `*.test-data.*` and `*.fixture(s).*`;
- `lang/`, `locales/`, `i18n/`, `resources/lang/`, `database/seeders/`, `database/factories/`, `docs/`;
- migrations, except for the lanes that read them.

Listings use `--no-ignore`, so a snapshot (no `.git`) and a live tree read the same files.

## Pre-flight

Run as one script from the V2 root (shell state does not survive between tool calls; bash 3.2-safe). `V1` may be empty: the script then runs solo against the recorded inventory.

```bash
PI="${PI:-.claude/skills/paired-inventory/scripts/pair-inventory.py}"; V2="${V2:-.}"; V1="${V1:-}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/pair-inventory.XXXXXX")"; STAMP="$OUT/stamp"; : > "$STAMP"; export GIT_OPTIONAL_LOCKS=0
python3 -I "$PI" --self-test | tail -1                    # the engine on its own pairs: PASS or stop
python3 -I "$PI" --list-lanes
if [ -n "$V1" ]; then
  python3 -I "$PI" --v1="$V1" --v2="$V2" --out="$OUT/run" > "$OUT/candidates.tsv"; echo "pair-inventory exit $?"
else
  python3 -I "$PI" --v2="$V2" --v1-inventory="$V2/ai/migration/v1-inventory" --out="$OUT/run" > "$OUT/candidates.tsv"; echo "pair-inventory exit $?"
fi
cut -f2,3 "$OUT/candidates.tsv" | sort | uniq -c | sort -rn | head -20   # lane x diff counts
# PP-5 when the testing pack is absent: parity suites gated on V1 presence (NOT-RUN unless a CI job sets the variable).
rg -n --pcre2 '\bV1_REPO_PATH\b|\bHAS_V1\b\s*\?|\bdescribe\.skip\b|\btest\.skipIf\(|\bskipif\([^)]*V1' -g '*.{ts,tsx,js,py,rb,php}' -g '!**/node_modules/**' -g '!**/vendor/**' "$V2"; echo "rg exit $?"
for R in "$V1" "$V2"; do [ -n "$R" ] && find "$R" -newer "$STAMP" -not -path '*/node_modules/*' | head -5; done
```

`pair-inventory exit 4` means: read the ledger before reading any row (a blocked lane, or a write). `rg exit 2` is a failed grep, never zero hits.

## Measured

Measured 2026-10-18, on this repo's fixtures only.

- **Self-test.** `--self-test` passes (153 checks, about 10 s). The built-in Laravel 11 → NestJS 11 calibration pair diffs to 0 rows on all 11 lanes, and 20 single-site seeds (one or two per lane) are each found as the expected V1-ONLY or CHANGED row. It also checks:
  - the prefix-sanity halt, and its fix by a pair-map prefix row;
  - a pair-map row with no reason being ignored;
  - the acknowledgement and acceptance rows, and an attribute row without an ADR being ignored;
  - `rg` exit 2 giving `blocked`;
  - a committed V1 read at its pin (V1 in a subdirectory of its repo) being immune to an uncommitted edit;
  - the record → solo round trip, with a stale `sha`, an old extractor hash and an absent lane;
  - an `--out` inside a tree being refused;
  - 108 per-stack samples and decoys (Rails 22, Django + FastAPI 37, Spring 15, Express + Fastify 20, Go 14).
- **Write-free snapshot on this repo.** A paired run of `backend-defects/apps/api` against itself at `--pin=HEAD` archived 157 files from `<sha>:benchmarks/fixtures/backend-defects/apps/api` (run from the top level, because from a subdirectory `git archive` also filters by the current path). It found 0 candidates, and `find .git benchmarks/fixtures/backend-defects -newer <stamp>` was empty.
- **Record mode on the fixtures** (`--record-v1 --live-v1`). Every run had 0 `rg` exit-2, 0 unparsed, 0 module errors and a write check of 0. Rows per lane, in the order ROUTES / AUTHZ / RULES / ENUM / ERR / SIDE / SCHED / SCOPE / SCHEMA / MONEY / CONF:
  - `backend-defects/apps/api` (nest): 49 / 49 / 81 / 2 / 3 / 4 / 7 / 12 / 0 / 1 / 2. Every route sits under `v1/`, and `health` is excluded, as `setGlobalPrefix('v1', { exclude: ['health'] })` says.
  - `backend-defects` (nest, django, express, go): 88 / 88 / 81 / 2 / 5 / 5 / 11 / 15 / 0 / 2 / 3.
  - `slow-marketplace` (nest, django): 23 / 23 / 4 / 15 / 4 / 0 / 2 / 22 / 40 / 4 / 3.
  - `obs-defects` (nest, fastapi, go, spring): 20 / 20 / 2 / 0 / 4 / 0 / 1 / 0 / 0 / 0 / 0.
  - `half-built-crm` (fastapi): 14 / 14 / 16 / 0 / 1 / 0 / 0 / gap / gap / 0 / 0.
  With the `--routes` build of `dto-types.py`, the prefix, the class-level decorators and the enum values come from it, and the ledger says so. Against an older build, `lanes_node` applies all three itself.
- **`port-pair` calibration** (`--calibrate` on `run.sh --clean-pair`, with the fixture's `pair-map.tsv`). Rows per lane before → after this engine's fixes and the map's acknowledgement and acceptance rows:

  | Lane | Before | After |
  |---|---|---|
  | I-ROUTES | 1 | 0 |
  | I-AUTHZ | 1 | 0 |
  | I-RULES | 6 | 7 |
  | I-ENUM | 2 | 0 |
  | I-ERR | 1 | 0 |
  | I-SIDE | 0 | 0 |
  | I-SCHED | 1 | 0 |
  | I-SCOPE | 1 | 0 |
  | I-SCHEMA | 15 | 0 |
  | I-MONEY | 5 | 0 |
  | I-CONF | 2 | 0 |
  | **Total** | **35** | **7** |

  The 7 I-RULES rows have one cause, and it is real, not an extractor artefact. V2's shared `PageQuery` rejects `page` < 1 and `per_page` outside 1–100, and `TicketListQuery` rejects `q` longer than 100. V1 clamped or coerced those values, or accepted them. That is narrowing ("V2 accepts less", SP §7 medium), and it closes only with an ADR-backed acceptance row.
- **`port-pair` paired run** (seeded tree, `--live-v1`). 41 candidates; 7 are the calibration residue above, and the other 34 rows are seed-attributable. They surface 25 of the 92 seeds:
  - PX-RT1a, PX-RT1b;
  - PX-AZ1a, PX-AZ1b, PX-AZ2a, PX-AZ2b, PX-AZ3a;
  - PX-VA1a (both globals; the ledger says `registerInputNormalization()` is never called), PX-VA1b;
  - PX-VO1a, PX-VO1b (with their `col:` and `in` echoes);
  - PX-ER1a (`code:order_not_editable`: V2 throws a 400 with no code);
  - PX-SE1a, PX-SE1b, PX-JB1a, PX-JB1b;
  - PX-DM7a, PX-DM10a (`derived:order.line_count`), PX-DM10b, PX-HC1a (`view:finance_invoice_totals`);
  - PX-MN1a, PX-MN1b, PX-MN2b, PX-TZ1a, PX-SD1a.

  The lane seeds still not surfaced need a detector § rather than a lane: page base and query parser (RT2), a raw-SQL tenant predicate (AZ3b), the error envelope (ER1b), rounding order with equal modes (MN2a), integer division (NUM1), after-commit or replication timing (SE2) and V1-side validation (DM7b).

## The 3,000-row path

A large diff is almost always one root cause. Work it in this order, and record every step in the coverage block:

1. **Read the ledger first.** Resolve a blocked lane, the prefix-sanity halt (add the suggested `prefix:` row, or re-run after the `--routes` fix), `uncalibrated` tags (add `--calibration-pair`) and a write-check hit. No row is triaged before that.
2. **Group by wiring row.** `cut -f2,3,5 candidates.tsv | sort | uniq -c` by lane, then by V1 module or controller, then by attr. One V1 global middleware, guard, scope, trim pipe or observer trait missing in V2 is **one finding with N sites** (precedent § 27). Examples: `GLOBAL trim_strings on yes→no` covers every string field; `table:order soft_delete yes→no` covers every list of orders; an `auth:sanctum` group covers every route in it.
3. **Read in severity order.** Guarantee classes first (I-AUTHZ, I-SCOPE, `GLOBAL` rules, unique and enum stored values), then I-MONEY, then I-SIDE on write routes, then the rest.
4. **Close a group with one checked reason**, for example `41 V1-ONLY routes under /admin/legacy: zero callers on six axes, ADR-031 deprecates`. Write routes, guards and money paths are never bulk-closed by name.
5. **Ledger the rest.** Report what is left as `Live, unreviewed (k groups / n rows)` with the command that continues it. Never mark it `checked`.

## Output

The engine prints the candidate TSV on stdout and the ledger on stderr. It also writes `<out>/{v1,v2}/<lane>.tsv`, `<out>/candidates.tsv` and `<out>/ledger.txt`.

```
# CANDIDATE	lane	diff	key	attr	v1	v2	v1_at	v2_at	tags	excerpt
CANDIDATE	I-RULES	CHANGED	GLOBAL trim_strings	on	yes	no	bootstrap/app.php:15	-	live-v1	->withMiddleware(function (Middleware $middleware) {
CANDIDATE	I-SCOPE	CHANGED	table:ticket	tenant	yes	no	app/Models/Ticket.php:18	apps/api/src/tickets/ticket.entity.ts:10	live-v1	class Ticket extends Model
CANDIDATE	I-SCHED	V1-ONLY	job:credit.expire.wallet	-	cron=15 0 * * *;overlap=no;target=wallets:expire-credits;tz=Asia/Riyadh	-	routes/console.php:9	-	live-v1	Schedule::command('wallets:expire-credits')->dailyAt('00:15')…
```

A consuming detector turns a candidate into a reported row only after the refute pass:

```
1. GLOBAL trim_strings — V1 bootstrap/app.php:15 (framework default, composer.lock v11.31.0)      [report-with-fix]  high
   V2 registers NormalizeInputPipe in registerInputNormalization() (common/http-setup.ts:14), which nothing
   calls. One finding, every string field. Proof: V361 boundary corpus, "  a@b.c " accepted and stored untrimmed.
2. table:ticket tenant yes→no — V1 Ticket.php:18 account scope; V2 ticket.entity.ts:10 carries no account filter  [report-flagged]  blocker → security
   Unproven link: raw-SQL reads of tickets not followed. Settling probe: V359 cross-tenant cell on GET /api/tickets/{}.
```

`[report-with-fix]` means the counterpart search is written out, the oracle fired, and the fix is local. `[report-flagged]` names the one unproven link and the probe that settles it.

**Lane coverage block.** Every run prints all eleven lanes, in this vocabulary:

```
Lane coverage (pair-inventory 1 · paired · laravel 11.31.0 -> nest 11.0.6 · calibrated: built-in laravel->nest 0 rows; --calibration-pair I-RULES 7):
  I-ROUTES  checked (44 v1 / 34 v2 → 2 V1-ONLY, 0 V2-ONLY, 0 CHANGED; 10 closed by pair-map rows)
  I-AUTHZ   checked (44 / 34 → 2 / 0 / 4)
  I-RULES   blocked (lane I-RULES asymmetric: 7 rows on the calibration pair)
  I-SCHEMA  checked (139 / 151 → 2 / 0 / 1)
  I-MONEY   checked · partial (5 / 5 → 1 / 1 / 2)
  …
```

The allowed states:
- `checked (…)` — the lane ran on both sides;
- `checked · partial` — a stack lane no paired fixture covers;
- `blocked (<reason>)` — calibration, prefix sanity, rg exit 2, `dto-types` NOT-RUN, a stale record or a stack gap;
- `N/A (no <lane> surface on either side)`;
- `Unconfirmed-solo (k)` — a drop class read from a record.

## Precedents

The verifier reads [`precedents/migration.md`](../../../../snippets/precedents/migration.md): § 21–28 settle the engine's own questions (solo mode never prints GO, calibration, prefix sanity, freshness, gated suites, pair-map reasons, one wiring row = one finding, counterparts outside the app). § 29–33 settle the Laravel → NestJS top five that these lanes surface: global trim, open-by-default routes, 422 → 400, observer and trait effects, and negative-half rounding. The oracles are [`proof-oracles.md`](../../../../snippets/proof-oracles.md) § Migration (V358–V388).

## Halt conditions

- Do not report a candidate as a finding: a diff row has passed no counterpart search. A finding needs [`refute-before-report.md`](../../../../snippets/refute-before-report.md), run by a verifier other than the run that produced the row. Run standalone, tag rows `self-verified` and keep the rest Unconfirmed. Never drop them.
- Halt when the self-test fails, and when any lane prints `blocked` and the run would still be reported as `checked`.
- Halt on the prefix-sanity halt until a `pair-map` prefix row or a `--routes` re-run fixes the join. No route-keyed row is a candidate before that.
- Do not emit rows from a lane that failed calibration (`blocked (lane <x> asymmetric …)`), and do not compare a stack pair with no calibration pair without the `uncalibrated` tag.
- Solo mode never prints GO. Drop classes from a record stay `Unconfirmed-solo` with the settling probe "re-run with `--v1=<path>`".
- Never read the live V1 checkout in paired mode, never write into either tree, and never pass an `--out` inside one. A non-zero write check stops the run.
- Never edit `pair-map.tsv` to make a lane quiet. A rename without a reason is not a mapping.

## Related

- `/compare-v1` runs this engine for the whole-repo audit and folds its lane coverage into the class ledger. `/migration-scan --record-v1-inventory` is the only caller of record mode. `/find-and-fix --from-audit` closes the findings.
- `surface-parity-scan` (I-ROUTES, I-AUTHZ, I-RULES, I-ENUM, I-ERR, I-SCOPE), `semantics-parity-scan` (I-MONEY, I-CONF) and `side-effect-parity-scan` (I-SIDE, I-SCHED) consume the rows. `@parity-auditor` judges them in refute mode.
- Backend `validation-boundary-scan` owns `dto-types.py`. Database `index-coverage-scan` owns `schema-map.py`. Testing `suite-execution-scan` §2c owns `gated-suites.tsv`.
