---
description: Fire a controlled burst at a target endpoint (LOCAL / STAGING ONLY) to verify the rate limit actually triggers and the 429 + Retry-After + RateLimit-* headers are correct.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /probe-limits

Prove the limit is real. A limiter that "should" trigger but doesn't is the most expensive kind of bug — it passes review by inspection and fails in production. This command sends a deliberate burst and reports the ACTUAL status sequence + the ACTUAL headers observed, so the limit is verified by behaviour, not by reading the config.

## Premise

Real signals only. Cite the actual target URL, the configured policy under test, the exact number of requests sent, the OBSERVED status sequence (e.g. `200×N, 429×M`), and the ACTUAL `Retry-After` + `RateLimit-Limit` / `RateLimit-Remaining` / `RateLimit-Reset` header values seen on the first 429 — never narrate a probe you didn't run, never report an assumed result. Read before firing: confirm the endpoint + its declared policy (limit, window, keyBy) BEFORE sending, so the expected vs observed comparison is meaningful.

## Mechanical halt

Cite-or-halt: every run prints the target URL, the request count sent, the observed status sequence, and the response headers seen on the first throttled response (or "no 429 observed in N requests" with the full sequence). **LOCAL / STAGING ONLY** — refuse to run if the target host resolves outside `localhost` / `127.0.0.1` / an explicit non-prod `--target`. If the host looks like production (no `localhost`, no `staging`/`dev` marker, or matches a configured prod hostname), HALT and refuse — probing prod is a self-inflicted DoS + pollutes real customers' limit windows. Negative results (limit never triggered, missing header) are reported as the actual observation, never softened.

## What it does

1. Resolves the target endpoint + reads its declared rate-limit policy (limit, window, keyBy, expected failMode) from the route metadata / config.
2. Refuses to proceed unless the target is `localhost` / `127.0.0.1` / an explicit `--target` staging/dev URL.
3. Sends `limit + buffer` requests (default `buffer = 5`) to the SAME identity (same API key / same user token / same source) so they all land in one bucket — controlling for the keyBy dimension.
4. Records, per request: status code + the `Retry-After` and `RateLimit-*` headers.
5. Reports:
   - target URL + policy under test,
   - requests sent,
   - observed status sequence (`200×N then 429×M`),
   - the header values on the first 429,
   - a PASS / FAIL verdict against the expected contract.
6. Optionally (`--reset-wait`) waits `Retry-After` seconds, re-sends one request, and asserts it returns `200` — proving the window actually resets.

## Verdict criteria (all must hold for PASS)

- The first ~`limit` requests return `200` (allowing for any pre-existing window consumption).
- Subsequent requests return `429` — not 200, not a dropped connection, not 500.
- The first `429` carries `Retry-After: <seconds>` (a positive integer).
- Both throttled and successful responses carry `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset`; `RateLimit-Remaining` decreases toward 0 and reads `0` on the throttled responses.
- (`--reset-wait`) after waiting `Retry-After`, one more request returns `200`.

Any deviation is reported as FAIL with the exact observation — e.g. "sent 105, observed 105×200, no 429: limit not triggering (in-memory counter? wrong keyBy? store unreachable?)".

## Usage

```bash
# Probe a route on the local dev server (reads the route's declared policy):
.claude/skills/probe-limits.sh /auth/login

# Different identity dimension — probe per-API-key with an explicit key:
.claude/skills/probe-limits.sh /products --key "$DEV_API_KEY"

# Override the burst size + wait for the window to reset and re-test:
.claude/skills/probe-limits.sh /reports/export --count 75 --reset-wait

# Staging target (must be an explicit non-prod host):
.claude/skills/probe-limits.sh /products --target https://staging.example.com
```

Or slash: `/probe-limits /auth/login`.

## Example output

```
/probe-limits — POST http://localhost:3000/auth/login
Policy under test: keyBy=ip limit=5 window=60s failMode=closed
Identity: ip (same source for all requests)
Requests sent: 10

Status sequence:  200,200,200,200,200,429,429,429,429,429
First 429 headers:
  Retry-After: 54
  RateLimit-Limit: 5
  RateLimit-Remaining: 0
  RateLimit-Reset: 54

Verdict: PASS — limit triggered at request 6; 429 + Retry-After + RateLimit-* all present + correct.
```

```
/probe-limits — GET http://localhost:3000/products
Policy under test: keyBy=tenant limit=100 window=60s
Requests sent: 105

Status sequence:  200 ×105   (no 429 observed)

Verdict: FAIL — limit never triggered after 105 requests against a 100/min policy.
Likely causes to investigate (cite the source): in-memory counter behind a load balancer,
wrong keyBy (requests not landing in one bucket), or the limiter store unreachable (silent fail-open).
RateLimit-Remaining did not decrease across requests -> counter is not shared / not incrementing.
```

## Rules

- **LOCAL / STAGING ONLY. Refuse prod.** Probing a production limiter is a self-inflicted burst + pollutes real customers' windows.
- Always send to a SINGLE identity so the requests share one bucket — otherwise you're testing nothing.
- Report the OBSERVED status sequence + ACTUAL headers. Never report an assumed or "should be" result.
- A missing 429, a missing `Retry-After`, or a non-decreasing `RateLimit-Remaining` is a FAIL — surface it, don't soften it.
- Use a dev/staging identity (test API key / test user), never a real customer's key.
- Pair with `<agents-path>/rate-limit-reviewer.md` for the static review; this command is the behavioural proof.

## Cross-references

- `<rules-path>/rate-limit-discipline.md` — the response-contract + atomicity hard rules this probe verifies.
- `<patterns-path>/rate-limiter.md` — the limiter shape + header emission the probe asserts against.
- `<agents-path>/rate-limit-reviewer.md` — static review gate (this command is its behavioural counterpart).
