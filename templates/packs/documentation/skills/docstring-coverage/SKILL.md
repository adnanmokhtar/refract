---
name: docstring-coverage
description: Detect exported / public API symbols missing a docstring — functions, classes, modules, endpoints, exported types — and optionally gate on a coverage threshold. A docstring states WHY / the contract, not a restated signature. An undocumented public API is a coverage gap.
kind: skill
pack: documentation
---

# docstring-coverage

## Premise

Every exported / public symbol — function, class, module, endpoint, exported type — carries a docstring that states its **contract and its WHY**: what it guarantees, what it assumes, when to reach for it, what it raises. Not a restated signature. An undocumented public API is a coverage gap, and a docstring that merely re-spells the parameter names in prose is a *zero-information* gap wearing a docstring's clothes — worse, because it green-lights the count while teaching nothing.

Cite-or-halt. Every finding cites the symbol at `<path:line>` and its category: `NO-DOC`, `EMPTY-DOC`, `SIGNATURE-RESTATE`, or `INCOMPLETE` (missing param/return/raises on a signature that has them). "This could use more docs" is a vibe. A gap without a symbol citation and a category is not reportable.

**Cross-owned with the lint toolchain — mirror, don't impose.** Docstring coverage is enforced in most ecosystems by a linter (see the adapt table). This skill **defers to the project's existing docstring linter** and its configured convention (Google vs NumPy vs reST style; which D-rules are on; the JSDoc tags required). It reads that config and reports against it. If the repo has no docstring linter wired, this skill reports raw coverage and proposes adopting the ecosystem-standard one — it does **not** invent a house convention or fight a configured one. The linter owns the rules; this skill surfaces and (optionally) gates on the coverage they imply.

## When to run

- Before merging a PR that adds or changes a public/exported symbol.
- Before a release — the public surface is the API contract users read.
- In CI as an optional gate (fail below a coverage threshold on the public surface only).
- After extracting or promoting an internal symbol to the public API — new export, new `pub`, newly re-exported from a barrel/`__init__`.
- **Not** for private/internal helpers — coverage is measured on the *public surface*, not every function.

## Procedure

1. **Delimit the public surface.** This is the whole game — coverage of the wrong set is noise. Enumerate only what's exported:
   - explicit exports (`export`, re-exports from `index`/barrel, `__all__`),
   - visibility keywords (`pub` / `pub(crate)`, `public`, capitalized-name-exports in Go),
   - public methods of exported classes, exported types/interfaces/enums,
   - HTTP/RPC endpoints (route handlers are a public API even without an export keyword),
   - the module/package itself (module-level docstring).
   Exclude `_private`, unexported, and test files.
2. **Read the project's docstring-lint config** (see adapt table) — style convention + which rules are enabled. Report against *that*, not a preference.
3. **Classify each public symbol:**
   - `NO-DOC` — no docstring/doc-comment at all.
   - `EMPTY-DOC` — a docstring that's whitespace or a placeholder (`"""TODO"""`, `/** */`).
   - `SIGNATURE-RESTATE` — the docstring only re-states the signature (`// returns the user by id` on `getUserById`) with no contract, no why, no invariant. Cross-ref `doc-principles` § "Must not — duplicate code in prose".
   - `INCOMPLETE` — on a non-trivial signature: a documented symbol missing `@param`/`@returns`/`@raises` (or the convention's equivalent) for a parameter, a return value, or a thrown error that the code actually has.
   - `NO-EXAMPLE` (soft) — a public API whose usage is non-obvious and carries no example snippet.
4. **Compute coverage** — `documented public symbols / total public symbols`, and separately the *quality-adjusted* rate that subtracts `SIGNATURE-RESTATE` (a restate is not a documented symbol).
5. **Gate (optional).** If a threshold is configured, fail when raw or quality-adjusted coverage falls below it. Report the delta the PR introduced so a decline is caught even above threshold.
6. **Emit** the report; for `NO-DOC`/`INCOMPLETE`, propose a why-first stub the author fills in — never auto-generate a signature-restating docstring (that manufactures the exact defect this skill exists to catch).

## Adapt to the codebase

Mirror the project's existing docstring linter and convention; run the tool the repo already configures.

| Stack | Coverage / lint tool | Convention signal |
|---|---|---|
| Python | `interrogate` (coverage %), `pydocstyle`, `ruff` D-rules (`D1xx`) | `[tool.ruff.lint.pydocstyle] convention = "google" \| "numpy" \| "pep257"` |
| JS / TS | `eslint-plugin-jsdoc` (`require-jsdoc`, `require-param`, `require-returns`), `typedoc` coverage | `.eslintrc` jsdoc rules; TSDoc tags |
| Java | `javadoc` (`-Xdoclint`), Checkstyle `JavadocMethod`/`MissingJavadocMethod` | Checkstyle config scope (`public`/`protected`) |
| Go | `golint`/`revive` exported-comment rule, `staticcheck ST1000` (package comment) | "exported X should have comment" |
| Rust | `#![deny(missing_docs)]` / `#![warn(missing_docs)]`, `cargo doc` warnings, clippy `missing_docs_in_private_items` | crate-level lint attribute |
| Ruby | `rubocop` `Style/Documentation`, YARD `--fail-on-warning` | `.rubocop.yml` |

If none is wired: report raw coverage from a manual scan of the public surface, and recommend adopting the ecosystem-standard tool above — scoped to the public surface — rather than introducing a bespoke convention.

## Output

Literal report: coverage headline, then findings grouped by category with `<path:line>` citations.

```
docstring-coverage — public surface: 84 symbols  ·  convention: google (ruff D, pydocstyle)
Raw coverage: 71% (60/84)   Quality-adjusted: 62% (52/84)   Gate: ≥ 80% → FAIL (−9)
PR delta: −4% (added 3 public symbols, 0 documented)

NO-DOC (blockers on public surface):
  src/billing/refund.py:22    refund_order()        exported, no docstring
  src/api/routes/users.py:14  GET /users/{id}       endpoint, no handler docstring
  src/types/order.py:8        class Order           exported dataclass, no docstring

SIGNATURE-RESTATE (counts as undocumented):
  src/users/service.py:40     get_user_by_id()
    """Get user by id."""  — restates the signature; no contract (raises? None on miss?).
    → state the WHY: "Raises NotFound if the id is unknown; results are request-cached."

INCOMPLETE:
  src/orders/create.py:31     create_order(items, coupon=None)
    docstring omits `coupon` and the `PaymentDeclined` it raises.

NO-EXAMPLE (soft):
  src/sdk/client.py:12        class Client — public SDK entrypoint, non-obvious init; add a usage snippet.

OK: 52 public symbols documented with contract-level docstrings.
```

Closure verb: **report-with-stub** (emit a why-first skeleton for the author to complete) — never **auto-fill**, which would manufacture SIGNATURE-RESTATE defects.

## False positives / gotchas

- **Overrides / interface implementations** inherit the base's docstring by convention (`@inheritdoc`, Python `__doc__` inheritance). Don't flag an override as `NO-DOC` when the contract lives on the interface.
- **Generated code** (protobuf stubs, ORM models, migration files) has no hand-written docstrings by design — exclude generated paths, don't drown the report.
- **Trivial accessors** — a one-line getter/property may legitimately need no prose; `doc-principles` warns against multi-paragraph docstrings on obvious methods. Weight `NO-DOC` by signature complexity; don't demand a paragraph on `is_active`.
- **Private-looking-but-exported** — a barrel/`__init__` re-export makes an underscore-free helper part of the public surface. Follow the exports, not the name.
- **Convention mismatch is the linter's call, not yours** — if the repo uses NumPy style and a docstring is Google style, that's a lint finding under *their* config; don't re-adjudicate the house convention.

## Halt conditions

- Refuse any coverage claim without the enumerated public surface — coverage of an undefined denominator is meaningless. Show the symbol count and how it was delimited.
- Refuse to auto-generate docstrings that restate signatures. If a symbol has no discernible contract to state, emit a `TODO(owner, date)` stub per `doc-principles`, not a fabricated one.
- Do not impose a docstring convention the project hasn't chosen; read its linter config and report against it. No linter → recommend the standard one, don't invent one.
- Measure coverage on the **public surface only** — flagging private helpers inflates the gap and buries the real API gaps.
- Never gate a build below threshold silently — surface the number, the threshold, and the PR delta so the failure is legible.

## Related

- `doc-principles.md` (rule) — the WHY-not-WHAT discipline this skill enforces: "duplicate code in prose ... drift is guaranteed" is exactly the `SIGNATURE-RESTATE` finding, and "every public class / interface / enum / exported function has a one-sentence docstring" is the surface this skill measures.
- `@doc-writer` — writes the contract prose once a gap is flagged; this skill finds the gap, doc-writer fills it with the why.
- `@api-documenter` — owns the endpoint/OpenAPI surface; docstring-coverage flags an undocumented endpoint, api-documenter authors its machine-readable contract.
