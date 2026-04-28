---
name: flag-discipline
description: Declaration
kind: rule
---

### Feature flag discipline

Flags are temporary forks in the codebase. Every flag past its useful life rots into a maintenance trap. These rules keep the inventory honest.

## Declaration

- Every flag has an OWNER (Slack handle or team) and a SUNSET DATE recorded at creation. No owner / no date = no merge.
- Flag key follows `<domain>.<feature>[.<variant>]` (e.g., `checkout.new-cart.v2`). No `temp_`, no `fix_2024_03`, no human names in keys.
- Default value is OFF unless an ADR justifies default-ON. Default-ON flag failure = 100% blast radius on day 1.
- Flag declared in ONE source of truth: provider dashboard OR `flags.yaml` OR `feature_flags` table — never two. `/flag-audit` reconciles code → declaration.

## Evaluation

- Evaluate a flag at MOST ONCE per request. Memoize on the request context / closure / middleware.
- NEVER evaluate inside `.map`, `.filter`, `for`, or any per-row code path. Evaluate before the loop, branch on the boolean.
- ALWAYS pass an explicit `default`: `flag.isOn('key', { default: false })`. SDK outage → known fallback, not undefined.
- NEVER call the flag SDK from within a DB transaction or hot serialization path — adds network IO to a critical path.
- Targeting context uses STABLE identifiers (tenantId, userId, deviceHash). Never session id, IP, or random — each eval would re-bucket.

## Rollout cadence

- Start at 1%. Watch metrics for ≥1 hour (or 1 deploy cycle).
- Then 5% → 25% → 50% → 100%. Each step ≥1 hour with health check.
- Document the cadence in the PR description. Skipping straight to 100% needs an explicit reason ("hotfix rollback" is the only common one).
- Kill-switch flags (rollback toggles) are documented separately and ALWAYS default-ON-with-fast-OFF — purpose is operational, not experimental.

## Cleanup

- 100% rollout for >14 days = open a cleanup PR. Both branches stay in code = debt accruing.
- Cleanup PR removes BOTH the dead branch AND the surviving branch's `if (flag.isOn(...))` wrapper.
- After code removal, delete the flag from the provider within 24h. Provider plans are priced per active flag.
- Reused flag keys are FORBIDDEN — historical eval data + analytics events lose meaning. Always a new key.

## Telemetry

- Eval logs are sampled (1-5%) — never log every eval in a hot path.
- A/B experiment flags emit an `analytics.flag.exposed` event WHENEVER the user is exposed to the variant (not just on eval — only when the variant actually affects the response).
- Default-fallback rate is monitored — SDK degraded → silent shift to default. Alert when fallback >0.5% of evals.
- Per-flag eval count is queryable (provider dashboard or analytics) for the audit pass.

## Forbidden uses

- Flag as AUTH boundary. SDK outage = flag returns default = auth bypass or lockout. Use roles + permissions.
- Flag as TENANT data filter. Tenant scoping is a guard, not a toggle.
- Flag as COMPLIANCE control (GDPR mode, region redaction). Compliance is environment / config, not flag.
- Flag controlling SECURITY-relevant behavior (CSP, CORS, rate limit). Same reason as auth.
- Flag wrapping a NoOp / NoOp branch (`if (flag) { doX(); } else { doX(); }`) — flag does nothing, code rots.

## Tests

- Each flag has unit tests for ON branch AND OFF branch.
- Default-fallback path tested (mock SDK throw → assert default behavior).
- Rollout targeting tested with mocked context (assert 1% bucket gets variant, 99% does not).

## Provider hygiene

- Server SDK key NEVER ships in client bundles. Use environment-scoped client keys.
- Provider webhook events (flag changed, rollout updated) trigger a Slack message to the owner.
- Provider dashboard access = production-equivalent — anyone who can flip a 100% rollout can break prod.
