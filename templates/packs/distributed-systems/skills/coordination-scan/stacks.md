# coordination-scan — stack lanes (Python, Java/Kotlin, Go, .NET)

Loaded by [`SKILL.md`](SKILL.md) only when its F1c line printed the stack. The Node lane, the shared gates (F1–F3), the read-the-code questions, the severity rules and every § body live in `SKILL.md`; this file adds each stack's acquire / release / renew API, the defaults that decide verdicts (rows of [`broker-semantics.md`](../../../../snippets/broker-semantics.md), read at the installed version), the grep literals, and the decoys each grep must stay quiet on. A row tagged `[K?]` there makes its verdict Unconfirmed until the settling oracle runs.

## The lanes

| Lane | Acquire · release · renew | Defaults that decide verdicts | § the shapes feed |
|---|---|---|---|
| **redis-py** `Lock` (`r.lock(name, timeout=, blocking_timeout=)`) | `with r.lock(…)` raises when not acquired · Lua token release · `extend(n)` | LO3: **`timeout=None` — the lock never expires**; `blocking_timeout=None` waits forever; `extend()` raises on a lock with no timeout; `raise_on_release_error=True` | §1 (a raw `r.delete`), §2, §3, §4 |
| **python-redis-lock**, pottery | `expire=` + `auto_renewal=True` (a renewal thread) | defaults beyond that not read — read the installed version | §2, §4 |
| **Celery beat / RedBeat**, APScheduler | RedBeat takes a beat lock by default (`redbeat_lock_key = None` disables it, SD7) | the beat's zone: `timezone` / `enable_utc` | §11 (fleet half → perf § 20) |
| **Redisson** (`RLock`, `RFencedLock`) | `lock()` / `tryLock(wait, unit)` (watchdog on) · `unlock()` · `lockAndGetToken()` | LO4: watchdog 30 s while the JVM lives; **passing `leaseTime` disables it** `[K?]`; `tryLock` returns a boolean; `RFencedLock` first version `[K?]` | §3, §4; the token clears perf § 18 |
| **Spring Data Redis / Jedis** hand-rolled | `setIfAbsent(k, v, Duration)` · `delete(k)` | LO1 (a plain delete removes another holder's lock) | §1, §2 |
| **ShedLock** (`@SchedulerLock`) | `lockAtMostFor` (safety lease) · `lockAtLeastFor` | LO5: a run past `lockAtMostFor` may run twice; **assumes synced clocks** (`usingDbTime()` for JDBC); no fencing | §4, §8 |
| **Quartz** clustered | JDBC store + `isClustered=true` | SD7: node clocks within 1 s | §8 (fleet half → perf § 20) |
| **go-redsync** | `Lock()` → `error` · `Unlock()` / `Extend()` → `(bool, error)` | LO6: expiry 8 s, tries 32; **`ErrLockAlreadyExpired`** — `defer m.Unlock()` drops "it expired while you worked" | §3, §4 |
| go-redis hand-rolled | `SetNX(ctx, k, v, ttl)` · `Del(ctx, k)` | `SetNX(…, 0)` sets no expiry | §1, §2 |
| **client-go leaderelection** | `RunOrDie(ctx, LeaderElectionConfig{…, Callbacks})` | LO8: **does not fence**; `LeaseDuration > RenewDeadline > 1.2 × RetryPeriod`; tolerant of skew, not of skew rate | §6 |
| **etcd** `concurrency.Mutex` | lease + mutex; the key's revision is the token | LO9 `[K?]` (API name not re-read) | §4 fencing |
| Go `time` | `time.Now()` carries a monotonic reading | TM1: **stripped by `Round(0)`, `Truncate`, `AddDate`, `In`, `Local`, `UTC`, and by JSON/gob/text encoding** | §7, §8 |
| **DistributedLock** (madelson, .NET) | `TryAcquire*` → handle or **null** · `HandleLostToken` | LO7: default timeout 0; a null handle means not acquired | §3, §4 |
| .NET time | `Stopwatch`, `Environment.TickCount64`, `TimeProvider` | TM2 | §7 |
| Postgres advisory locks (every stack) | `pg_try_advisory_lock` / `pg_advisory_xact_lock` | LO10 | §5 |

Monotonic APIs per stack (TM2): Python `time.monotonic()` / `perf_counter()`; Java `System.nanoTime()`; Go `time.Since(start)` with an in-process `start`; .NET `Stopwatch`. Ruby and PHP have no lane: their shapes (`redis.del`, `Redis::del`, `Cache::lock`, Laravel `onOneServer` and `->timezone(`) are read by hand, and Laravel's DST note is SD3.

## Pre-flight greps

Run from the repo root, after `SKILL.md`'s block (F3's `TZ` line still gates §11). The same rules hold: every `rg` names its path, include globs come first and exclusions last, an `rg` exit 2 is a failed grep. Set `ROOTS` to the stack's service directories in a monorepo.

```bash
ROOTS=(.)
X=(-g '!**/{node_modules,vendor,.venv,venv,site-packages,target,build,dist,out,bin,obj,generated}/**'
   -g '!**/{test,tests,__tests__,spec,specs,e2e,fixtures,testdata,mocks}/**'
   -g '!**/*{_test.go,Test.java,Tests.java,Test.kt,Tests.cs,Test.cs,_spec.rb}' -g '!**/test_*.py' -g '!**/*_test.py'
   -g '!**/{migrations,migration,db/migrate}/**' -g '!**/{docs,ai,.claude}/**')
NC=(rg -v --pcre2 '^[^:]+:\d+:\s*(?://|/\*|\*(?:\s|/|$)|#)')
PY=(-g '*.py'); JV=(-g '*.{java,kt}'); GO=(-g '*.go'); CS=(-g '*.cs')
# Python — F the lock and scheduler libraries; 1 a delete of a lock key; 2 SET nx=True with no px/ex, SETNX, redis-py lock() with no timeout= (LO3); 3 acquire(blocking=False) as a statement; 4 a dropped extend()/reacquire(), a release error swallowed (LO3); 7 time.time() deltas in a comparison; 8 an expiry from the app clock; 10 the clock as an id; 11 a non-UTC Celery or Django zone (the beat's fire zone)
rg -n --no-heading --pcre2 '^\s*(?:redis|python-redis-lock|redlock-py|pottery|celery|celery-redbeat|apscheduler|kubernetes)\b[^\n]*' -g '**/requirements*.txt' -g '**/pyproject.toml' -g '!**/{.venv,venv}/**' .
rg -n --no-heading --pcre2 '\.(?:delete|unlink)\(\s*[^)\n]*(?:(?:\b|_)(?:lock|leader|mutex|lease)|Lock|Leader|LOCK|LEADER)' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '^(?![^\n]*\b(?:px|ex|pxat|exat|keepttl)\s*=)[^\n]*\.set\([^\n]*\bnx\s*=\s*True|\.setnx\(|^(?![^\n]*\btimeout\s*=)[^\n]*\.lock\(\s*(?:f?["\x27]|[\w.]+\s*[,)])' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '^\s*(?:await\s+)?[\w.]+\.acquire\([^)\n]*\bblocking(?:_timeout)?\s*=[^)\n]*\)\s*(?:#.*)?$' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '^\s*(?:await\s+)?[\w.]*(?:lock|lease|leader|mutex|lk)\w*\.(?:extend|reacquire)\([^)\n]*\)\s*(?:#.*)?$|\braise_on_release_error\s*=\s*False\b|\bexcept\s+(?:redis\.exceptions\.)?LockNotOwnedError\b' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '\btime\.time\(\)\s*-\s*[\w.]+\s*[<>]=?|[<>]=?\s*time\.time\(\)\s*-\s*[\w.]+|\btime\.time\(\)\s*[<>]=?\s*[\w.]+\s*\+|\bdatetime\.(?:utc)?now\(\)\s*-\s*[\w.]+\s*[<>]=?' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '(?i)\b(?:expires?_?at|lease_?\w*|locked_?until|valid_?until)\s*=\s*(?:datetime\.)?(?:utc)?now\(|\b(?:expires?_?at|lease_?\w*|locked_?until)\s*=\s*time\.time\(\)' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '\b\w*(?:id|key|seq)\s*=\s*(?:str\()?int\(time\.time\(\)|\b\w*(?:id|key)\s*=\s*str\(time\.time\(\)' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '\b(?:CELERY_TIMEZONE|TIME_ZONE|timezone)\s*=\s*["\x27](?!(?:Etc/)?(?:UTC|GMT)\b)[A-Za-z_]+/|\benable_utc\s*=\s*False\b|\bCELERY_ENABLE_UTC\s*=\s*False\b' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# Java / Kotlin — 1 a delete of a lock key (RedisTemplate, Jedis); 2 two-argument setIfAbsent, Jedis setnx; 3 tryLock(…) as a statement; 4 Redisson lock(lease, unit) / tryLock(wait, lease, unit) (the watchdog is off, LO4), ShedLock lockAtMostFor (LO5), a swallowed IllegalMonitorStateException; 7 currentTimeMillis deltas in a comparison; 8 an expiry from Instant.now(); 11 a cron with no zone
rg -n --no-heading --pcre2 '\.(?:delete|del|unlink)\(\s*[^)\n]*(?:(?:\b|_)(?:lock|leader|mutex|lease)|Lock|Leader|LOCK|LEADER)' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '\.setIfAbsent\(\s*[^,()]+(?:\([^()]*\))?[^,()]*,\s*[^,()]+\)\s*;|\.setnx\(' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '^\s*[\w.]+\.tryLock\([^;\n]*\)\s*;' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '\.lock\(\s*[^,()\n]+,\s*TimeUnit\.|\.tryLock\(\s*[^,()\n]+,\s*[^,()\n]+,\s*TimeUnit\.|\blockAtMostFor\s*=\s*"[^"]+"|\bcatch\s*\(\s*IllegalMonitorStateException\b' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 'System\.currentTimeMillis\(\)\s*-\s*[\w.]+\s*[<>]=?|[<>]=?\s*System\.currentTimeMillis\(\)\s*-\s*[\w.]+|System\.currentTimeMillis\(\)\s*[<>]=?\s*[\w.]+\s*\+' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '(?i)\b(?:expires?_?at|lease\w*|locked_?until|valid_?until)\s*=\s*(?:Instant|LocalDateTime|ZonedDateTime|OffsetDateTime)\.now\(\)' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '@Scheduled\(\s*cron\s*=(?![^)\n]*\bzone\s*=)' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# Go — 1 Del of a lock key; 2 SetNX with expiration 0; 3 in redsync files, Lock/Unlock/Extend whose error or bool is dropped (LO6; a sync.Mutex in the same file is read); 6 client-go callbacks and the three timings (LO8); 7 monotonic reading stripped (TM1); 8 an expiry from time.Now() that another process compares
rg -n --no-heading --pcre2 '\.(?:Del|Unlink)\(\s*ctx\s*,\s*[^)\n]*(?:(?:\b|_)(?:lock|leader|mutex|lease)|Lock|Leader|LOCK|LEADER)' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '\.SetNX\([^)\n]*,\s*0\s*\)' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -l0 --pcre2 'go-redsync/redsync|\brs\.NewMutex\(|\bredsync\.New\(' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -0 -r rg -H -n --no-heading --pcre2 '^\s*(?:defer\s+)?\w+\.(?:Lock|LockContext|TryLock|Unlock|UnlockContext|Extend|ExtendContext)\([^)]*\)\s*(?://.*)?$'
rg -n --no-heading --pcre2 'OnStartedLeading:\s*func\(\s*_\s+context\.Context|OnStartedLeading:[^\n]*context\.(?:Background|TODO)\(\)|OnStoppedLeading:|\b(?:LeaseDuration|RenewDeadline|RetryPeriod)\s*:' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '\.(?:Round|Truncate)\(\s*0\s*\)|\b\w+\s*:=\s*time\.Now\(\)\.(?:UTC|Local|In)\(' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '(?i)\b(?:expires?_?at|lease_?until|locked_?until|valid_?until)\w*\s*(?::=|=|:)\s*time\.Now\(\)' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# .NET — 3 TryAcquire* with no null check within 3 lines (LO7); 7 DateTime.UtcNow deltas in a comparison; 8 an expiry from DateTime.UtcNow
rg -n --no-heading -U --pcre2 '=\s*await\s+[\w.]+\.TryAcquire\w*\([^)\n]*\)\s*;(?!(?:[^\n]*\n){0,3}[^\n]*(?:\bis\s+(?:not\s+)?null\b|[!=]=\s*null\b))' "${CS[@]}" "${X[@]}" "${ROOTS[@]}" | rg --pcre2 'TryAcquire'
rg -n --no-heading --pcre2 'DateTime(?:Offset)?\.(?:UtcNow|Now)\s*-\s*[\w.]+\)?(?:\.\w+)?\s*[<>]=?|[<>]=?\s*DateTime(?:Offset)?\.(?:UtcNow|Now)\s*-\s*[\w.]+' "${CS[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 '(?i)\b(?:expires?_?at|lease\w*|locked_?until|valid_?until)\s*=\s*DateTime(?:Offset)?\.(?:UtcNow|Now)' "${CS[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# All stacks — 5 session-scoped advisory locks in code or SQL (the pooler check is SKILL.md's 5b)
rg -n --no-heading --pcre2 '\bpg_(?:try_)?advisory_lock(?:_shared)?\s*\(' "${PY[@]}" "${JV[@]}" "${GO[@]}" "${CS[@]}" -g '*.{sql,rb,php}' "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
```

## Decoys each grep must stay quiet on

| Grep | Quiet on (measured) | Read by hand |
|---|---|---|
| py-2 | `r.set(k, tok, nx=True, px=30000)` · `with r.lock("x", timeout=60, blocking_timeout=5)` | a multi-line `set(` or `lock(` (the TTL on the next line); a trailing comment holding `timeout=` masks the lock arm |
| py-3 | `if not lk.acquire(blocking=False): return` · `threading.Lock().acquire()` | a result bound and checked two lines later |
| py-4 | `if not lk.extend(30): return` | python-redis-lock's renewal thread (no `extend` call at all — §4's fixed-TTL read) |
| jv-2 / jv-3 | `setIfAbsent(k, tok, Duration.ofSeconds(30))` · `if (!lock.tryLock(0, TimeUnit.SECONDS)) return;` | a `tryLock` statement whose next line checks `isHeldByCurrentThread()` |
| jv-4 | — (inventory: every `lockAtMostFor` and every `leaseTime` call is read against the work's bound) | `@SchedulerLock` above `@Scheduled` |
| go-3 | `if err := m.Lock(); err != nil { return }` · `if ok, err := m.Extend(); !ok …` · `var mu sync.Mutex; mu.Lock()` on one line | a bare `mu.Lock()` of a `sync.Mutex` in a redsync file |
| go-6 | — (inventory: the three timings are checked against LO8's inequality) | a callback that passes its own `ctx` on |
| go-7 | `time.Since(start)` with an in-process start | a `time.Time` read back from JSON, a database or another service, then compared with `time.Now()` |
| cs-3 | `if (h is null) return;` within 3 lines | a null check further down, after an effect |
| py-7 / jv-7 / cs-7 | `time.monotonic()` · `System.nanoTime()` · `Stopwatch.Elapsed` · a delta only stored or logged | the age of a stored instant (calendar logic, not CK-1) |

## Measured (2026-10-14)

| Tree | Result |
|---|---|
| Research samples (`locks/` and `clocks/` in Python, Java, Go and C#; `sched/`) | 0 rg errors. Every BAD line hits: py-1 `r.delete("lock:report")`, py-2 `nx=True` with no TTL and `r.lock("rebuild-index")`, py-3 an unchecked `acquire(blocking=False)`, py-8 an app-clock lease expiry; jv-1 `redisTemplate.delete` + `jedis.del`, jv-2 two-argument `setIfAbsent`, jv-3 + jv-4 `tryLock(0, 30, SECONDS)` as a statement with a lease, jv-8 `Instant.now().plusSeconds(30)`, jv-11 two zone-less `@Scheduled` crons; go-1 `defer rdb.Del(ctx, "lock:sync")`, go-2 `SetNX(…, 0)`, go-3 `mutex.Lock()` and `defer mutex.Unlock()` unchecked, go-6 `OnStartedLeading` under `context.Background()`, go-7 `Round(0)`, go-8 a lease `ExpiresAt` from `time.Now()`; cs-3 an unchecked `TryAcquireLockAsync`. Every decoy above stays quiet. The messaging samples (`samples/`, every stack) give 0 |
| Seeded files for shapes the samples lack (one per stack) | py-4 a dropped `extend(30)` and a swallowed `LockNotOwnedError`, py-7 `time.time() - started > LEASE`, py-10 `str(int(time.time()))`, py-11 `CELERY_TIMEZONE = "Europe/Berlin"`; jv-4 `lock(10, SECONDS)`, `tryLock(1, 10, SECONDS)` and a swallowed `IllegalMonitorStateException`, jv-7 a `currentTimeMillis` lease compare, jv-11 a zone-less cron (the `zone = "UTC"` one stays out); go-6 the three timings, go-7 `Round(0)` in a `Since` and `time.Now().UTC()`; cs-7 both `DateTime.UtcNow - started >` forms, cs-8 an expiry from `UtcNow`. The monotonic decoys stay quiet |
| `benchmarks/fixtures/*` (18) and a real NestJS repository | 0 hits; slow-marketplace's `requirements.txt` prints `redis==5.2.1` in F1c (its Python service: 0 lane hits) |

Sources: `broker-semantics.md` LO1–LO10, SD3, SD7, TM1–TM4 (each dated there, read 2026-10-14) and the distributed-systems research notes B §§ 1, 2 and 7 (L1–L7, K1, T1–T7 greps, tested on the research samples 2026-10-14), re-measured here. Paraphrased; no text reproduced beyond identifiers.
