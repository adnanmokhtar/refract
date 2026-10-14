# event-contract-scan — stack lanes beyond Node (event stores §6–§9, typed deserializers §2–§3)

Loaded by [`SKILL.md`](SKILL.md) only when its F1 lines printed the stack. The Node lane, the shared gates, the contract lane (§1, §4), the read-the-code questions, the severity rules and every § body live in `SKILL.md`; this file adds each store's append, concurrency and projection API, the defaults that decide verdicts (rows of [`broker-semantics.md`](../../../../snippets/broker-semantics.md) § Event contracts and event stores, read at the installed version), the grep literals and the decoys each grep must stay quiet on. A row tagged `[K?]` there, or a fact marked `[K?]` here, makes its verdict Unconfirmed until the settling oracle (V325, V326 in [`proof-oracles.md`](../../../../snippets/proof-oracles.md) § Distributed) runs.

## The event-store lanes

| Lane | Append with a guard · without | Defaults that decide verdicts | § the shapes feed |
|---|---|---|---|
| **KurrentDB .NET** (`KurrentDB.Client`, legacy `EventStore.Client`) | `AppendToStreamAsync(stream, revisionRead, events)` · `StreamState.Any` | EV2: `StreamState.Any` performs no check; the expected state is positional `[K?]` (parameter order not re-read) | §6 |
| **KurrentDB Python** (`kurrentdbclient`, legacy `esdbclient`) | `append_to_stream(name, current_version=<read>, events=…)` · `current_version=StreamState.ANY` | EV2 | §6 |
| **Marten** (.NET, Postgres) | `FetchForWriting<T>(id)` then append (works in Quick and Rich modes) · `AggregateStreamAsync<T>(id)` then a plain `Events.Append(id, …)` | EV3: plain `Append(id, events)` has no guard; `Append(id, expectedVersion, events)` needs `EventAppendMode.Rich` (the default is Quick); **each async projection runs on exactly one process**; the store owns stream uniqueness (precedent 30) | §6, §9 (daemon mode → performance § 20) |
| **Axon** (JVM) | `AggregateLifecycle.apply` inside a `@CommandHandler`; `@EventSourcingHandler` rebuilds state | the JPA/JDBC event store keeps a per-aggregate sequence with storage-level uniqueness `[K?]` (research notes B § 6.0 — not re-read); an `@EventSourcingHandler` runs on every replay | §7 (precedent 30 when the store is Axon's), §9 |
| **Python `eventsourcing`** | the library's `Application.save()` with the originator version | records carry the originator version under a uniqueness constraint `[K?]` (library docs, not re-read) — precedent 30 | §7, §9 (`apply`/`mutate` methods) |
| **Typed deserializers** — System.Text.Json, Jackson, pydantic | `JsonSerializer.Deserialize<T>`, `mapper.readValue(record.value(), T.class)`, `Model.model_validate_json(raw)` | SZ6: STJ ignores unknown members unless `UnmappedMemberHandling.Disallow`; a plain `new ObjectMapper()` fails on unknown properties (Spring Boot's configured mapper does not); pydantic ignores extras unless `extra="forbid"`; a typed deserialize is not a validation of ranges, formats or required business fields | §2, §3 |

Ruby and PHP have no lane: an event store there (Rails Event Store, EventSauce, Prooph) is read by hand — the append's expected-version argument, the store's uniqueness, and whether its projectors checkpoint in the projection's transaction.

## Pre-flight greps

Run from the repo root, after `SKILL.md`'s block (its `$T` lists are not needed here). The same rules hold: every `rg` names its path, include globs come first and exclusions last, an `rg` exit 2 is a failed grep. Set `ROOTS` to the stack's service directories in a monorepo.

```bash
export LC_ALL=C; ROOTS=(.)
XT=(-g '!**/node_modules/**' -g '!**/{dist,build,out,coverage,generated,__generated__,vendor,target,bin,obj}/**'
    -g '!**/{test,tests,__tests__,spec,specs,e2e,fixtures,__fixtures__,mocks,__mocks__,testdata}/**'
    -g '!**/{test_*,*_test}.{py,go}' -g '!**/*{Test,Tests,IT}.{java,kt,cs}' -g '!**/{migrations,migration,seeders,seeds}/**' -g '!**/{docs,ai,.claude,.refract-fixture}/**')
NC=(rg -v --pcre2 '^[^:]+:\d+:\s*(?://|/\*|\*(?:\s|/|$)|#)')
# S2 .NET / JVM / Python inbound payloads: files with a typed deserialize and no validation call (read: is the type validated, or is a raw dictionary used?)
rg -l0 --pcre2 '\bJsonSerializer\.Deserialize<|\bJsonConvert\.DeserializeObject<|\.readValue\(\s*\w+\.value\(\)|\bjson\.loads\(|\borjson\.loads\(' -g '*.{cs,java,kt,py}' "${XT[@]}" "${ROOTS[@]}" | xargs -0 -r rg --files-without-match --pcre2 '\bValidator\b|\bValidate\w*\(|@Valid\b|\bmodel_validate\w*\(|\bparse_obj\(|\bTypeAdapter\(|\bjsonschema\.validate\(|\bfastavro\b|\bAvroDeserializer\b|\bProtobufDeserializer\b'
# S6 KurrentDB .NET and Python appends with no check; Marten: a read-decide (AggregateStreamAsync) then a plain Append in the same file
rg -n --no-heading --pcre2 '\bAppendToStreamAsync\([^\n]*\bStreamState\.Any\b|\bappend_to_stream\([^\n]*\bcurrent_version\s*=\s*StreamState\.ANY\b|\bappend_to_stream\((?![^\n]*\bcurrent_version\s*=)[^\n]*\)' -g '*.{cs,py}' "${XT[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -l0 --pcre2 '\bAggregateStreamAsync<' -g '*.cs' "${XT[@]}" "${ROOTS[@]}" | xargs -0 -r rg -H -n --no-heading --pcre2 '\.Events\.Append\(\s*\w+\s*,\s*(?:new\b|\w+\s*\))' | "${NC[@]}"
# S9 .NET / JVM apply handlers that do I/O (read: does it run on rehydration?); Marten daemon mode (one async projection process per store, EV3; replicas → performance §20)
rg -n --no-heading -U -o -r '$1' --pcre2 '^[ \t]*(?:@EventSourcingHandler[^\n]*\n[ \t]*)?(?:(?:public|private|protected|internal)\s+)?(?:void|Task)\s+((?:Apply|When|On)\w*)\s*\([^)]*\)\s*\{(?:(?!\n[ \t]*\}\n)[^\n]*\n){0,12}?[^\n]*(?:\bawait\s|\.Send\w*\(|\.Publish\w*\(|\bHttpClient\b|\.send\(|\.publish\()' -g '*.{cs,java,kt}' "${XT[@]}" "${ROOTS[@]}"
rg -n --no-heading --pcre2 '\bDaemonMode\.(?:Solo|HotCold)\b|\bAddAsyncDaemon\(' -g '*.cs' "${XT[@]}" "${ROOTS[@]}" | "${NC[@]}"
```

Reading the output:
- **S2** lists files, not verdicts. A Jackson `readValue` into a class whose fields carry Bean Validation annotations still needs a `Validator` call to run them; a pydantic model *is* the validation (its call is in the clearing list). A `json.loads` into `**kwargs` of an ORM model is the strong case.
- **S6** prints every unguarded append. Part A first: was a decision made from loaded state (any branch on the aggregate before the append)? An audit or telemetry stream is precedent 29. Marten: `FetchForWriting` in the same method is the guard; `AppendOptimistic()` detects only changes between its call and `SaveChangesAsync()`, and `AppendExclusive()` takes a database lock on the stream (research notes B § 6.0, from martendb.io).
- **S9** prints the method name per hit; read whether the method runs during rehydration (`AggregateStreamAsync`, Axon's event-sourcing handler) or only on the command path. A Marten `DaemonMode.Solo` line is a once-per-fleet question for performance § 20: count the replicas of the process that registers it.

## Decoys each grep stays quiet on

`FetchForWriting<T>(id)`; `AppendToStreamAsync(stream, revisionRead, …)`; `append_to_stream(…, current_version=version)`; `model_validate_json(raw)`; a Jackson mapper configured with `FAIL_ON_UNKNOWN_PROPERTIES, false` (`SKILL.md`'s 3c, which clears 3b). `DaemonMode.HotCold` is printed on purpose beside `Solo`: it is the leader-elected mode, and the read clears it.

## Measured (2026-10-14)

| Tree | Result |
|---|---|
| Research samples (`es/Handler.cs`, `es/store.py`, `contracts/Consumer.java`, `contracts/consumer.py`) | 0 rg errors. S6 hits all three non-Node appends — Marten `Events.Append` after `AggregateStreamAsync`, KurrentDB .NET `StreamState.Any`, Python `current_version=StreamState.ANY` — and stays quiet on `FetchForWriting`. S2 lists the Java consumer (`readValue(record.value(), …)` with no validation) and not the Python one (`model_validate_json` in the file) |
| Seeded files (a C# aggregate, a Python consumer, a Java listener) | S9 prints the `Apply` that sends mail and not the pure one; the `DaemonMode.Solo` line; S6 an `append_to_stream` with no `current_version`; S2 both deserialize files |
| `benchmarks/fixtures/*` and the read-only real repository | No .NET, JVM or Python event store in any of them: every S line prints nothing (the real repository is TypeScript only; its §6–§9 are `N/A` in `SKILL.md`'s run) |

Sources: `broker-semantics.md` EV2, EV3 and SZ6 (read 2026-10-14 from the KurrentDB client docs and martendb.io *Appending events*, *Async daemon*); the Axon and Python `eventsourcing` uniqueness facts are research notes B § 6.0, marked `[K?]` there and here; grep literals are notes B § 6.1 (E1, E8, E9) and § 5.1 (C1, C3), tested on the research samples. Paraphrased; no text reproduced beyond identifiers.
