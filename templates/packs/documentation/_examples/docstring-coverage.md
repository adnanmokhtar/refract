---
name: docstring-coverage
description: Detect exported / public API symbols missing a docstring — functions, classes, modules, endpoints, exported types — and optionally gate on a coverage threshold. A docstring states WHY / the contract, not a restated signature. An undocumented public API is a coverage gap.
---

# docstring-coverage

Every exported symbol carries a docstring stating its **contract and WHY** — what it guarantees, assumes, and raises — not a restated signature. An undocumented public API is a coverage gap; a docstring that re-spells the parameter names is a zero-information gap wearing a docstring's clothes.

## Premise

Cite-or-halt. Every finding cites the symbol at `<path:line>` and a category: `NO-DOC`, `EMPTY-DOC`, `SIGNATURE-RESTATE`, or `INCOMPLETE` (missing param / return / raises). "Could use more docs" is a vibe.

**Cross-owned with the lint toolchain — mirror, don't impose.** Defer to the project's docstring linter and its configured convention (Google / NumPy / reST; required JSDoc tags). No linter wired → report raw coverage from a manual scan and propose the ecosystem-standard tool; never invent a house convention or fight a configured one.

## When to run

- Before merging a PR that adds / changes a public symbol; before a release.
- In CI as an optional gate below a coverage threshold — public surface only.
- After promoting an internal symbol to the public API. Not for private / internal helpers.

## Procedure (abridged)

1. Delimit the public surface (exports, `pub`, capitalized Go names, endpoints, the module itself) — coverage of the wrong set is noise.
2. Read the project's docstring-lint config; report against it.
3. Classify: NO-DOC / EMPTY-DOC / SIGNATURE-RESTATE / INCOMPLETE / NO-EXAMPLE (soft).
4. Compute raw + quality-adjusted coverage (subtract restates); gate if a threshold is configured.
5. Emit why-first stubs — never auto-fill a signature-restating docstring.

## Output (abridged)

```
docstring-coverage — public surface: 84 symbols · convention: google (ruff D, pydocstyle)
Raw: 71% (60/84)  Quality-adjusted: 62%  Gate: ≥ 80% → FAIL (−9)  PR delta: −4%

NO-DOC:  src/billing/refund.py:22 refund_order() · api/routes/users.py:14 GET /users/{id}
SIGNATURE-RESTATE:  users/service.py:40 get_user_by_id — """Get user by id.""" states no contract.
INCOMPLETE:  orders/create.py:31 create_order — omits `coupon` and the PaymentDeclined it raises.
```

## Halt conditions

- Refuse a coverage claim without the enumerated public surface — an undefined denominator is meaningless.
- Refuse to auto-generate signature-restating docstrings; emit a `TODO(owner, date)` stub instead.
- Measure the public surface only; don't impose a convention the project hasn't chosen. No linter → recommend the standard one.

## Related

- `doc-principles.md` (rule) — the WHY-not-WHAT discipline this enforces; "every public class / interface / enum / exported function has a one-sentence docstring" is the surface it measures.
- `@doc-writer` / `@api-documenter` — fill the flagged prose gap / own the endpoint (OpenAPI) contract.
