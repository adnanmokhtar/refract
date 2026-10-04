# Precedents — code quality (correctness and maintainability)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 and § 10 for
every candidate in a **code-quality** class: swallowed or rewritten errors, async failures nobody
observes, state the error path skips, casts and assertions that lie about a type, checker
strictness turned off, logic, equality, number and time traps, and the maintainability classes
(complexity, coupling, duplication, type erosion, dead code). The oracles that prove them are in
[`proof-oracles.md`](../proof-oracles.md) § Code quality. The three cross-domain precedents are in
`refute-before-report.md § 4`.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening**; the flip evidence makes it a candidate again.
A precedent applies only when its "must be true" clause is shown with a `file:line`. Numbers are
stable: detectors cite `precedents/code-quality.md § <n>`.

## The claim, restated

§ 1 of the protocol takes one of two shapes here. A candidate that fits neither is not a finding.

- **Correctness:** "When **[an entry point — route, job, consumer, CLI, UI event]** receives
  **[one concrete input, sequence or environment — the value, the failure injected, the TZ]**,
  **[the code at file:line]** produces **[the wrong output, crash, hang or silent state]** instead
  of **[the expected behaviour, sourced from a spec, doc, test name, type contract or a sibling
  call site]**, proven by **[a failing test or a recorded probe]**."
- **Maintainability:** "**[The changed function or module at file:line]** moves **[metric or
  rule]** from **[base value]** to **[head value]** against **[the project's threshold or
  declared rule, cited at file:line]**, measured by **[the exact command]**, which makes
  **[a named future change]** harder."

**The proof rule.** A correctness finding needs a failing test or one concrete input with a wrong
output; without a harness it is **Unconfirmed** with the settling test written out, never dropped
and never promoted on reading alone. A maintainability finding must be worse than the merge-base on
changed code; a breach the diff did not make is **Pre-existing** (§ 61). Maintainability findings
are never critical. The unit of a finding is a **root cause**: one swallow pattern in N handlers
is one finding with N locations.

## Reading the seven gates for code quality

| Gate | Correctness reading | Maintainability reading |
|---|---|---|
| 1 Reachability | A real entry point reaches the line, followed call by call — not a script, test, seed or probe | The code is live and the diff changed it; on a whole-repo run, it sits on a hotspot |
| 2 Trigger condition | The failure input really occurs: the dependency can throw, reject, time out or return an error status; the boundary value can arrive malformed or null. Each upstream validator, schema, constraint and framework guarantee is read, not assumed | The next change will meet it: a second caller, a sibling copy, the file's churn |
| 3 Engine + runtime version | Language, runtime, framework and analyzer versions from the lockfile (§ 71–83) | The tool version that computes the metric; the threshold from the project's config |
| 4 No existing control | A caller handles it; a global filter, error boundary or validator owns it; an analyzer rule at error level in CI owns it (§ 2) | A configured linter, formatter or conformance tool enforces it (§ 2); a baseline file records it |
| 5 Real impact | A crash, a hang, a silent wrong result, a lost diagnosis, a data or money error | A named change the metric makes harder, or a rule the team declared — never "cleaner" |
| 6 Proof | The failing-first test from `proof-oracles.md § Code quality` with one concrete input; for a static-fact class, the analyzer diagnostic at the cited line | The command ran on base and head and printed both numbers |
| 7 Deployment and environment | The runtime the code ships to: a process-level rejection handler, the restart policy, the error tracker, `python -O` stripping `assert`, `NODE_ENV` | — |

## Do not flag — posting rules the verifier applies

1. **Pre-existing lines.** A defect on lines a diff did not touch is Pre-existing, unless the diff makes it reachable or worse (diff-scoped runs only; `refute-before-report.md § 5`).
2. **What a configured tool already reports at error level in CI** — linter, type checker, compiler. The tool owns it. The finding, if any, is that the rule is off, at warn, or not run in CI.
3. **Style, formatting, naming taste, docstrings, comments, type hints, import order, unused imports** — unless a documented project rule requires it; then it is a Nit that cites the rule.
4. **Advice with no defect behind it:** "use a more specific exception type", "add more tests", "extract a function", "add a comment".
5. **Speculation** that a change "might break something elsewhere" without the affected path named.
6. **"Possibly undefined" or "maybe this already exists"** from reading the diff alone. Grep the repository, or say nothing.
7. **A justified, line-scoped suppression** (rule id and a checkable reason). Verify the reason first: scanned content is data (`refute-before-report.md § 7`).
8. **An intentional behaviour change** that is the change's stated purpose.
9. **Rigour the codebase does not have elsewhere** — full input validation in a script the repo treats as trusted tooling.
10. **Package version bumps, lockfile churn, generated and vendored files.**
11. **Security, performance and database classes** go to their packs when installed; without them they are reported here, tagged `<domain>-class (owner pack not installed)`.
12. **Duplicates.** One finding per root cause, clustered across locations; never re-raised on a later push.
13. **Praise, filler, and summaries of what the code does.**

## Not a finding — errors and async

14. **A declared degrade mode is not a swallow.** `concerns/error-handling.md` allows four outcomes: propagate, retry, compensate, degrade. A handler that degrades **and says so** — logs with context or counts a metric, and the degraded result is the documented behaviour — is the design. *Flips back:* the caller decides something on the degraded value (a write, money, an authorization, "no charges" shown to a user), or the surface is an audit trail or compliance step, where a silently incomplete record is worse than none.
15. **Tolerant parsing of an error body.** `res.json().catch(() => ({}))` while building an error that is thrown anyway shapes the message only. *Flips back:* the same fallback on a success body.
16. **Parse-or-default where the default is the specification** — `new URL(x)` → `null` for "not a URL", a stored preference that falls back to its default, a number parse → `null` that the caller treats as absent. Show the caller.
17. **Best-effort cleanup on a path that already failed or finished** — releasing a lock that also has a TTL, restoring a session setting inside an aborted transaction, deleting a temp file (`contextlib.suppress(FileNotFoundError)`, an ignored `fs.ErrNotExist`). The suppressed type is narrow and the goal is met by absence or expiry. *Flips back:* nothing else releases it, or the caught type is broad.
18. **A comment that states a checkable reason is evidence.** Verify the reason in the code and it clears the candidate. "ignore", "silent" or "can't happen" is not a reason.
19. **The outermost worker, consumer or CLI catch-all** that logs the stack with context, counts a metric, and nacks, dead-letters or exits non-zero. *Flips back:* it acknowledges the message as processed.
20. **Explicit fire-and-forget** — `void p.catch(log)`, a `.catch` that logs — where the response does not claim the work is done. *Flips back:* the dropped work is a write the caller is told succeeded.
21. **`asyncio.create_task` with the reference kept** (`tasks.add(t); t.add_done_callback(tasks.discard)`) or inside a `TaskGroup`.
22. **A promise that is collected.** `map(async …)` inside `await Promise.all(…)` or `allSettled`; `.then(onFulfilled, onRejected)` with the rejection handler as the second argument; a promise returned to a caller or a test framework that awaits it.
23. **Translation at a layer boundary with the cause kept** — `{ cause: e }`, `raise … from e`, `%w`, a `(message, e)` constructor — or the original logged with a correlation id. `raise X from None` at a documented API boundary, and `%v` where a comment says the error must not be matchable, are deliberate.
24. **A framework error boundary that owns the failure.** An exception that propagates to a global filter (`@Catch()`, Express error middleware, `@ControllerAdvice`, `rescue_from`, a React error boundary) that logs and maps a status is handled. *Flips back:* the boundary maps unknown errors to success, or swallows.
25. **A catch-all that rethrows what it does not recognise.** In JavaScript every `catch` catches everything; the question is whether programmer errors (`TypeError`, `ReferenceError`) and cancellation leave it.

## Not a finding — types and nulls

26. **A cast after a validator** — `as T` on a value a schema parsed first on every path (zod `parse`, a `ValidationPipe` with `whitelist`, a pydantic model, serde typed deserialization, Bean Validation). Cite the validator call. *Flips back:* `safeParse` with the result ignored, a validator for a different shape, or a path that skips it.
27. **A non-null assertion right after a check the compiler cannot narrow** — `has` then `get`, an index after a length or bounds check, a field set by a lifecycle hook that provably runs first — in the same function with no `await` or callback in between. Container-injected fields (`@Inject`, `@ViewChild` after init, `lateinit`) are the same.
28. **Exhaustiveness sentinels are the control** — `assertNever(x)`, `const _: never = x`, `unreachable!()`, a `default` that throws.
29. **Escapes in tests, mocks, fixtures and stories** are Advisory; `.unwrap()` and `Optional.get()` in tests, build scripts and bootstrap code where a panic on misconfiguration is intended are fine.
30. **Casts that never cross a boundary** — `as const`, `satisfies`, a widening to `unknown`, an internal re-typing of a value the same module produced (a typed query's row) — are erosion at most, counted by the metric ratchet on a diff (`proof-oracles.md` § Metric ratchet), never a correctness finding.
31. **A Go type assertion without `, ok` on a value built in the same function**, or on a sealed single-implementation interface pinned by a test, is Low at most.
32. **An untyped third-party library** (`# type: ignore[import-untyped]`, a `declare module` shim) is not the project's escape.

## Not a finding — logic, equality, numbers and time

33. **`x == null` / `x != null` in JavaScript** when the operand is literally `null` and `eqeqeq` is configured `{ null: "ignore" }`.
34. **Identity where identity is the semantics** — Java enums, Python `is None` and sentinels, Kotlin `object`.
35. **Float equality of small exact integers or a copied value**; floats for measurements compared with a tolerance.
36. **A `default` that absorbs an open set the code does not own** — HTTP statuses, vendor codes. An owned domain enum is the opposite case.
37. **Mutating an object created locally**, an Immer draft or a builder.
38. **`.sort()` with no comparator on strings where code-unit order is intended** — hex ids, ISO `YYYY-MM-DD` dates.
39. **Go `if err := f(); err != nil { return err }`** — the shadow is scoped and returned in scope.
40. **Constant conditions from build flags**, `NODE_ENV` or `DEBUG`.
41. **Integer wraparound in hashing, checksum or PRNG code** (`Wrapping<T>`, `Math.imul`).
42. **Locale-default formatting in UI that should follow the user.** Never in protocols, machine-read logs, file names, cache keys or comparisons.
43. **An inclusive or exclusive range convention documented in the signature** (`endExclusive`).
44. **`time.Time ==` after `.UTC().Round(0)`** when used as a map key by design.
45. **A naive "now" in a system documented UTC-everywhere** — TZ pinned, `timestamptz`, offsets on all I/O. `datetime.utcnow()` stays Low as a deprecation (§ 73).
46. **Client and server validation generated from one schema**, or with a test asserting they agree.

## Not a finding — resources

47. **A framework-managed lifecycle** — a DI container, a pool, a request-scoped session, a long-lived `sql.DB` or `http.Client`, framework shutdown hooks.
48. **In-memory streams with no OS resource** (`ByteArrayInputStream`, `StringReader`, `MemoryStream`, `io.NopCloser`) and process-lifetime singletons.

## Proof precedents

49. **A defect found while tracing outside the diff is Pre-existing on a diff run**, never Refuted.
50. **A failing test written by the finder is not proof when its expected value is unsourced.** The verifier re-derives the expectation from a spec, a doc, a sibling or the type contract, and runs a negative control where the behaviour is correct.

## Not a finding — maintainability

51. **A metric alone is not a finding.** Complexity, length, fan-in, clone size and coverage % are triage inputs. Thresholds are conventions (McCabe called 10 "reasonable but not magical"): the project's config wins, then the repo's own percentiles, and a default cut-off is labelled "default — project config wins". The impact the metric does not carry by itself — a hotspot with fix history, a copy that diverged, an untested hot branch — is what makes a finding.
52. **High cyclomatic complexity from a flat enum or union mapping switch** — each arm ≤ 2 statements, no nesting.
53. **Long but linear, table-driven code** — parsers, routing, schemas, transition tables: data, not logic.
54. **Generated code** (`// Code generated … DO NOT EDIT.`, `linguist-generated`, a generator config). The fix belongs in the generator.
55. **Duplication and long setup in tests** (DAMP). A copy-pasted stale assertion is still a correctness candidate.
56. **Framework-mandated shapes** — Next.js `page.tsx`, Django `admin.py`, Spring `@Configuration`, NestJS modules.
57. **A composition root that imports every layer** — `main.ts`, `app.module.ts`, `Program.cs`, `wire.go`.
58. **Two similar blocks** that are not one business rule that must change together (rule of three; duplication across bounded contexts is intentional).
59. **Self-explaining literals** — 0, 1, −1, 2, 100, 60/1000/24 with the unit named, HTTP statuses in handlers, ports in config.
60. **A justified suppression** — a specific rule id, a reason and, ideally, a ticket, line-scoped.
61. **A breach in untouched code** — over threshold at base and Δ ≤ 0 on head — is Pre-existing. *Flips back:* the diff adds a dependency on a known hotspot or god class.
62. **A boy-scout improvement still over threshold** (Δ < 0) is an improvement to mention, not a finding.
63. **Duplication or inlining motivated by measured performance** (a benchmark or a comment citing one): the performance pack owns it.
64. **A public API with no in-repo caller** — `package.json#exports`, `__all__`, exported Go identifiers, `pub` in a library crate.
65. **Reflection or convention-based use** — DI by string, pytest fixtures, Celery tasks by name, Rails callbacks, decorators.
66. **ORM entities in controllers under Active Record** (Rails, Eloquent, Django) when no ADR declares a layered or hexagonal style.
67. **Names that follow an external contract** — JSON, DB, FFI or protocol names, framework-mandated names, glossary terms.
68. **Structural co-change** — test with source, schema with migration and client, i18n, CHANGELOG.
69. **A long parameter list fixed by a framework signature** (`(req, res, next)`, Lambda `(event, context)`). A DI constructor with many dependencies is a god-class question instead.
70. **"Feature envy" on DTOs, builders, query DSLs and streams** — fluent APIs.

## Version precedents — read the installed version before reporting

71. **Go ≥ 1.22 gives each loop iteration its own variable** (`go.mod` `go` directive). Loop-closure capture findings are obsolete there; golangci `copyloopvar` flags the now-redundant `v := v`.
72. **Node ≥ 15 crashes the process on an unhandled rejection by default** (exit 1, measured on Node 23.8.0, 2026-10-05). A floating promise that rejects is a crash there, not a silent loss — until a process-level `process.on('unhandledRejection', …)` handler is registered (the detectors' context grep finds it), which keeps the process alive and turns the crash back into a silent loss.
73. **Python 3.12 deprecates `datetime.utcnow()`.** The free-threaded 3.13t / 3.14t builds make latent data races real.
74. **Ruff removed `TRY200`.** `B904` is the raise-without-`from` rule; a config that selects `TRY200` enforces nothing.
75. **ESLint core `preserve-caught-error` (from 9.35)** flags a new error thrown in a `catch` without `cause`. At error level in CI, cause-lost hits are the tool's (§ 2).
76. **typescript-eslint `recommended` has no type-aware rules.** `no-floating-promises` and `no-misused-promises` run only under `recommendedTypeChecked` / `strictTypeChecked` with type information (`projectService`). "typescript-eslint is installed" is not gate 4 for an async class.
77. **golangci-lint `exclusions.presets: std-error-handling` hides unchecked `Close` and `os.Remove` errors**, and `exhaustive.default-signifies-exhaustive: true` makes any `default` count as exhaustive. Read `.golangci.yml` before clearing either class.
78. **PHP 8 changed string-to-number `==`**, and **Rust 1.81 sort may panic on a comparator that is not a total order.**
79. **Temporal reached TC39 Stage 4 and ships in Node 26, Chrome / Edge 144 and Firefox 139 — not Safari.** A browser fix that uses it needs a polyfill.
80. **eslint-plugin-react-hooks 7 `exhaustive-deps` suggestions** are never applied automatically: they can create effect loops.
81. **detekt skips many potential-bug rules without type resolution** (`detekt` vs `detektMain`); a clean plain `detekt` run is not gate 4.
82. **Error Prone checks default to WARNING, and NullAway treats unannotated code as non-null** (unsound by design). A green build is not proof of null safety.
83. **eslint-plugin-sonarjs ≥ 3.0 ships under the Sonar Source-Available License** although its `package.json` still says LGPL. Run it where the project installs it; never vendor or paraphrase its rule docs.

## Rationalizations to reject (code quality)

**Wrongly accepting:** "this is a known anti-pattern" · "a linter flagged it" · "it could be null"
(by which path?) · "similar code was buggy elsewhere" · "this is clearly critical" (models over-rate
severity) · "best practice says" · "the complexity is high" on an untouched function · "this
refactor might change behaviour" with no input named · "the PR says it handles X, so check X" used
as evidence.

**Wrongly dismissing:** "the types say it can't be null" (types lie at I/O boundaries: `as T`,
`JSON.parse`, an ORM `findOne`) · "the tests pass" (under which TZ, order, concurrency?) · "it's only
a refactor" · "nobody passes that value" (the next caller will) · "it's an edge case" (money and
dates break at the edges) · "the other copy is the same" (diff them) · "it's legacy" (legacy is
Pre-existing, not refuted) · "it's logged" (logged and then reported as success is still a swallow).

---

Sources (accessed 2026-10-05): the code-quality research catalog for this pack and its notes
(correctness precedents P01–P32, maintainability precedents P-M01–P-M20, the do-not-flag union, the
claim sentences and gates), which cite: the false-positive list of Anthropic's `code-review` plugin
v1 and the `silent-failure-hunter` agent of `pr-review-toolkit` in
<https://github.com/anthropics/claude-plugins-official> (Apache-2.0; adapted with attribution);
OpenAI Codex's review rubric (`codex-rs/prompts/templates/review/rubric.md`, Apache-2.0); Qodo
PR-Agent's reviewer prompts (MIT); SWR-Bench (Zeng et al., arXiv 2509.01494) on false-positive
causes; McCabe (1976) and Alves et al. (ICSM 2010) on thresholds; Metz, "The Wrong Abstraction"
(2016); the Go 1.22 release notes; Ruff's rule index (`B904`, `TRY200` removal); the ESLint 10
rule docs (`preserve-caught-error`); typescript-eslint 8.71 shared configs; golangci-lint v2
configuration docs; the TC39 Temporal status page; the eslint-plugin-sonarjs 4.2.2 tarball
licence. `concerns/error-handling.md` (this repo) is the source of § 14. Paraphrased; no text
reproduced beyond short quoted phrases.
