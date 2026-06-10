---
name: ab-testing-discipline
description: A/B testing & experimentation discipline
kind: rule
---

# A/B testing & experimentation discipline

## Hard rule

Experiment assignment MUST be DETERMINISTIC: the variant is a pure function of `hash(experimentId + stableUserId + salt)`, so the SAME identity gets the SAME variant on every request, session, device, and on both server and client — re-randomizing per request is FORBIDDEN, it flips a user between variants and contaminates the data beyond repair. Exposure MUST be logged EXACTLY ONCE, and ONLY when the assigned variant is actually applied to the user — logging an exposure for a variant that was never shown, or double-logging it, biases every downstream metric. The stable identity MUST come from a SERVER-AUTHORITATIVE source, never a client-supplied/spoofable field — a client-trusted assignment lets anyone poison the experiment. Conflicting experiments MUST be mutually exclusive. The analysis contract MUST be fixed in advance — a pre-declared sample size with NO peeking — and assignment health MUST be monitored for sample-ratio mismatch (SRM). Every harmful variant MUST have a kill-switch, and consent MUST be respected before a user is enrolled or any exposure/metric event is recorded.

An experiment bug is silently wrong results — a ship/kill decision made on contaminated or peeked data — which erodes trust far more than a failed request, exactly like a wrong-numbers report.

## Must

- **Deterministic, stable bucketing**: the variant is `bucket(hash(experimentId + ':' + stableUserId + ':' + salt))` — a pure function. The same identity resolves to the same variant forever (until the experiment ends), across sessions, devices, server renders, and client hydration. No `Math.random()`, no per-request roll, no time-seeded assignment.
- **Server-authoritative identity**: `stableUserId` is the authenticated user id, or for anonymous traffic a signed, server-issued sticky id (httpOnly cookie / server-set). It is NEVER read from a client-controlled body/query/header the visitor can change. Assignment is computed server-side (or from a server-signed bucketing token); the client is told its variant, it does not pick one.
- **Exposure logged once, on actual exposure**: an `exposure` event fires the first time the assigned variant is actually rendered/applied to the user — not at assignment time, not on a code path the user never reached. It is idempotent per (experimentId, unit, session) so refreshes/re-renders don't double-count. Assignment without exposure is allowed; exposure without application is FORBIDDEN.
- **Assignment and metric events go through the analytics layer**: exposure + metric events are emitted via the project's tracking contract (see `<rules-path>/analytics`) with stable dedup keys, server-stamped identity, and consent honored — never an ad-hoc fire-and-forget `fetch`.
- **Mutual exclusion for conflicting experiments**: experiments that touch the same surface / metric belong to a declared mutual-exclusion group (a layer / namespace) so a unit is in at most one of them. Overlapping experiments without exclusion produce uninterpretable interaction effects.
- **Fixed sample size, no peeking**: each experiment declares its target sample size / minimum detectable effect / duration BEFORE it starts. The decision is read once the pre-registered size is reached. Repeatedly checking significance and stopping the moment `p < 0.05` (peeking) inflates the false-positive rate and is FORBIDDEN unless a sequential/always-valid test is explicitly used.
- **SRM detection**: the realized split is checked against the intended split (a chi-square / proportion test on assignment counts). A sample-ratio mismatch means assignment is broken (a redirect dropped one arm, a bot hit one variant, a guard skewed enrollment) and the result is INVALID — alert and quarantine, don't ship.
- **Kill-switch**: every experiment can be force-disabled to a safe control without a deploy (see `<rules-path>/feature-flags`). Disabling stops new enrollment and forces existing units to control; a harmful variant must be killable in seconds.
- **Consent respected**: a user who has not consented to experimentation/measurement (per the org's policy) is NOT enrolled and emits NO exposure/metric events — they fall through to control silently (see `<rules-path>/compliance`, `<rules-path>/analytics`).
- **No PII in experiment events**: exposure/metric payloads carry the bucketing unit id + variant + experiment id + dedup key — never raw email / name / free-text / sensitive attributes.
- **Experiments are flags, results are reports**: enrollment/kill ride the flag infra (`<rules-path>/feature-flags`); the readout (lift, CI, p-value, sample counts) is a trust-critical number governed by reporting discipline — tenant-scoped, reproducible, labeled with the as-of instant.

## Must not

- Assign a variant with `Math.random()` / a per-request roll / a time-seeded value — the same user flips arms between requests and the data is unanalyzable.
- Bucket on an unstable unit (a fresh session id per visit, an unsignable client value, a field that changes across devices) so one human spans multiple variants.
- Read the bucketing identity (or the variant itself) from a client-supplied body/query/header — spoofable; lets a caller pick its arm or poison the split.
- Log exposure at assignment time, or on a branch the user never actually reached — it counts users who never saw the variant and biases the metric.
- Log exposure more than once per unit/session (re-render, refresh, retry) with no dedup — inflates the denominator.
- Run overlapping experiments on the same surface/metric with no mutual-exclusion group — interaction effects make both unreadable.
- Peek at significance and stop the experiment the instant `p < 0.05` with no pre-registered sample size — manufactures false positives.
- Ship/kill on the result without checking SRM — a broken assignment silently invalidates the whole test.
- Enroll a non-consented user, or emit exposure/metric events for one.
- Put PII into experiment/exposure/metric payloads.
- Ship a variant with no kill-switch — a harmful arm then needs a deploy to stop.

## Should

- Wrap assignment behind a project-internal `<Experiments>` / `assign(experimentId, ctx)` interface so the deterministic hash, the server-authoritative unit, exposure logging, mutual exclusion, consent, and the kill-switch are enforced in ONE place — feature code asks "which variant?" and gets a logged answer, it never hashes or rolls inline.
- Express each experiment as a declarative spec (id, salt, variants + weights, unit type, mutual-exclusion layer, target sample size / MDE, primary metric, guardrail metrics, consent class) so bucketing, exclusion, and the analysis contract are derived, not hand-written per call site.
- Define a primary metric + guardrail metrics up front; auto-flag a variant that wins the primary while regressing a guardrail.
- Compute the readout via the reporting layer (tenant-scoped, replica/warehouse, as-of snapshot) so experiment numbers are reproducible and auditable — not a one-off query someone eyeballs.
- Emit structured `{ experimentId, variant, unitId, exposed, srmCheck, sampleSize, decision }` and alert on SRM, on exposure-without-assignment, on assignment-without-eventual-exposure drift, and on any experiment running past its declared horizon.
- Keep a kill/launch audit trail (who toggled, when, to what) — an experiment ship is a decision worth recording.

## Review checklist (PRs touching assignment / variants / experiment events / readouts)

- [ ] Assignment is deterministic: `hash(experimentId + stableUserId + salt)`, a pure function — no `Math.random()` / per-request roll. Cite the bucketing fn at `<path:line>`.
- [ ] The bucketing unit is stable across sessions/devices/server+client and is SERVER-authoritative (auth id or server-signed sticky id), not client-supplied. Cite where the unit is resolved at `<path:line>`.
- [ ] Exposure is logged exactly once, ONLY when the variant is actually applied (not at assignment, not on an unreached branch), with a dedup key. Cite the exposure call at `<path:line>`.
- [ ] Exposure + metric events route through the analytics contract with server-stamped identity + consent honored — no ad-hoc fetch.
- [ ] Conflicting experiments share a mutual-exclusion group/layer; a unit is in at most one.
- [ ] A fixed sample size / horizon is declared up front; the decision is read once — no peek-and-stop.
- [ ] SRM is checked before any decision; a mismatch quarantines the result.
- [ ] A kill-switch forces the experiment to control without a deploy.
- [ ] Non-consented users are not enrolled and emit no events.
- [ ] No PII in exposure/metric payloads.
- [ ] The readout is tenant-scoped + reproducible + as-of-labeled (reporting discipline).

## Anti-patterns

- **Per-request random** — `const variant = Math.random() < 0.5 ? 'a' : 'b'` -> the same user gets A then B then A across page loads -> their events land in both arms -> the experiment is noise. Bucket on `hash(experimentId + stableUserId)`.
- **Unstable unit** — bucketing on a per-visit session id -> one human is six different "users" in six arms. Bucket on a sticky server-issued id (or the auth id).
- **Client-trusted assignment** — `variant = req.query.variant` / the client posts which arm it's in -> anyone forces themselves (or a bot army) into one arm -> poisoned split. Assign server-side from a server-authoritative unit; the client is *told*, it doesn't *tell*.
- **Exposure at assignment** — logging "exposed" the moment `assign()` runs, even on a request that never renders the variant -> the denominator counts users who never saw it -> measured effect is diluted/biased. Log on actual application only.
- **Double-counted exposure** — exposure fires on every re-render/refresh with no dedup -> the same user is counted 40 times -> inflated denominator, deflated rate. Dedup per (experiment, unit, session).
- **Overlapping experiments** — two tests change the checkout button at once with no exclusion -> you can't tell which one moved the metric -> both unreadable. Put them in one mutual-exclusion layer.
- **Peeking** — watching the dashboard and stopping the instant `p < 0.05` -> with daily looks the real false-positive rate is far above 5% -> you ship noise. Pre-register the sample size; read once (or use an always-valid sequential test).
- **Ignored SRM** — intended 50/50, realized 53/47, shipped anyway -> a redirect silently dropped part of one arm -> the comparison is between non-comparable groups -> the result is invalid. Check SRM first; quarantine on mismatch.
- **No kill-switch** — the treatment causes errors/lost revenue and stopping it needs a deploy -> minutes-to-hours of harm. Every experiment force-disables to control without a deploy.
- **PII in events** — exposure payload includes the user's email / full name -> experiment telemetry becomes a PII store. Send the unit id + variant + dedup key only.
- **Consent ignored** — a user who opted out of measurement is still enrolled and tracked -> a compliance breach baked into the experiment path. No consent -> control, no events.
- **Eyeballed readout** — the "winner" is a one-off `GROUP BY variant` someone ran by hand with no tenant scope / no as-of / no reproducibility -> a ship decision on a number nobody can re-derive. Compute via the reporting layer.

## Enforcement

- `<commands-path>/audit-experiment.md` (slash: `/audit-experiment`) — locates the assignment at `<path:line>` and verifies deterministic/stable bucketing, exposure logging (present? fires only on actual exposure? deduped?), server-vs-client identity, mutual exclusion, SRM/peeking, kill-switch, and consent/PII — cite-or-halt, never an assumed assignment shape.
- `<agents-path>/ab-testing-reviewer.md` — review gate hard-failing on per-request/random assignment, non-deterministic or client-trusted bucketing, missing/misfired/duplicated exposure logging, no mutual exclusion, peeking / no fixed sample size, undetected SRM, missing kill-switch, PII in events, and consent not respected.
- CI lint MUST reject `Math.random()` / time-seeded randomness inside any assignment/bucketing module (heuristic; flag for review).
- CI lint MUST reject reading the variant or the bucketing unit from request input (`req.body`/`req.query`/`req.headers`) in assignment code (AST heuristic; flag for review).
- CI MUST assert every declared experiment spec carries a target sample size / horizon and a mutual-exclusion layer before it can be enabled.
- TODO: `scripts/validate-experiment-assignment.sh` to AST-walk assignment call sites and assert each resolves a server-authoritative stable unit, hashes deterministically, and logs exposure exactly once on application.

## Cross-references

- `<patterns-path>/experiment-assignment.md` — deterministic hash bucketing + server-authoritative unit + exposure-on-application + mutual exclusion + fixed-sample analysis contract + SRM + kill-switch code shapes.
- `<rules-path>/feature-flags` — the assignment/rollout infra + kill-switch live here. BOUNDARY: a flag is a rollout toggle (ship X to N% / this cohort); an experiment is a MEASURED comparison (which of A/B/C moves the metric, with exposure + analysis). Experiments ride flag infra but add stable bucketing, exposure logging, and a fixed analysis contract.
- `<rules-path>/analytics` — exposure + metric events are tracking events: dedup keys, server-stamped identity, consent. Experiment events MUST flow through the same contract.
- `<rules-path>/compliance` — consent classes; a non-consented user is not enrolled and emits no events.
- `reporting` — the experiment readout (lift, CI, p-value, sample counts) is a trust-critical number: tenant-scoped, reproducible, as-of-labeled, computed on the read store — not eyeballed.
- `<adr-path>/<NNN>-experimentation-platform.md` — ADR pinning the assignment/bucketing platform, the analysis methodology (fixed-horizon vs. sequential), and the SRM/kill-switch contract.
