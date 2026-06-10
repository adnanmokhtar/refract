---
name: experiment-assignment
description: "Pattern: Experiment (stable bucketing, exposure-logged, consistent, analysis-ready)"
kind: ai-pattern
---

# Pattern: Experiment (stable bucketing, exposure-logged, consistent, analysis-ready)

> **Hard rule** — A variant is a PURE FUNCTION of `hash(experimentId + stableUserId + salt)`, so the same identity gets the same arm on every request / session / device / server + client — never `Math.random()`, never a per-request roll. The bucketing unit is SERVER-AUTHORITATIVE (auth id or a server-signed sticky id), never a client-supplied field. Exposure is logged EXACTLY ONCE and ONLY when the variant is actually applied, through the analytics contract, with consent honored. Conflicting experiments are mutually exclusive. The analysis contract is fixed in advance (pre-declared sample size, no peeking), SRM is monitored, and every experiment has a kill-switch.

**When to apply**
- Any controlled experiment / A/B/n test where you compare variants and read a metric to make a ship/kill decision.
- Multi-surface products where the same user hits the experiment from web, mobile, server render, and client — and MUST see one consistent variant.
- Anything whose result feeds a trust-critical decision (pricing, checkout, onboarding) where contaminated or peeked data is worse than no data.

**When NOT to apply**
- A pure rollout with no measured comparison — "ship X to 10% then 100%" is a feature flag (see `<rules-path>/feature-flags`), not an experiment; it needs a toggle, not bucketing + exposure + analysis.
- Plain product analytics / funnel tracking with no assigned variant — that's the analytics pattern (see `<rules-path>/analytics`), not experimentation.
- A one-off, non-decisional UI variation nobody will analyze — the bucketing + exposure + SRM machinery is overhead.

**Halt conditions / mandatory cites**
- Cite the deterministic bucketing function at `<path:line>`. `Math.random()` / a per-request roll / a time-seeded value = halt — the user flips variants and the data is unanalyzable.
- Cite where the bucketing unit is resolved at `<path:line>`, and that it is server-authoritative + stable across sessions/devices. A client-supplied unit or the variant itself read from request input = halt (poisoned split).
- Cite the exposure-log call at `<path:line>` and the branch it fires on. Exposure at assignment time, on an unreached branch, or with no dedup = halt (biased denominator).
- Cite the mutual-exclusion declaration, the fixed-sample/horizon analysis contract, the SRM check, the consent gate, and the kill-switch at `<path:line>` each.
- Grep ban: "the experiment is consistent / unbiased / analysis-ready" without file:line for the deterministic hash, the server-authoritative unit, the exposure-on-application call, and the SRM/sample-size contract.

## Why

An experiment is simultaneously a consistency problem, a data-integrity problem, and a decision problem. The failure modes recur:

1. **The user flips variants** — assignment re-rolls per request (`Math.random()`) or buckets on an unstable unit, so one human lands in both arms across page loads/devices. Their behaviour is now split across A and B and the comparison is noise. Assignment MUST be a deterministic hash of a stable, server-authoritative id.
2. **The data is biased** — exposure is logged at assignment time (counting users who never saw the variant) or double-logged on every re-render (inflating the denominator), or assignment is client-trusted (a caller forces its arm and poisons the split). Exposure is logged ONCE, on actual application, server-side.
3. **The decision is false** — someone peeks at the dashboard and stops the instant `p < 0.05`, or ships despite a sample-ratio mismatch that means assignment was broken. The analysis contract (fixed sample size, SRM gate, no peeking) is what makes the readout a real decision instead of manufactured significance.

The pattern: declare an experiment SPEC, assign deterministically from a server-authoritative unit, enforce mutual exclusion + consent, log exposure once on application through the analytics contract, monitor SRM, read once at the pre-registered size, and keep a kill-switch.

## Experiment spec (declarative)

```ts
// src/modules/experiments/core/experiment-spec.ts

export interface ExperimentSpec {
  id: string;                          // 'checkout-button-2026q2'
  /** Salt rotates the hash so re-running an id reshuffles buckets intentionally. */
  salt: string;
  /** Variants + integer weights; weights sum to a known total (e.g. 100). */
  variants: ReadonlyArray<{ key: string; weight: number }>;   // [{key:'control',weight:50},{key:'treatment',weight:50}]
  /** Bucketing unit: the authenticated user, an org, or a server-issued anonymous sticky id. */
  unit: 'user' | 'org' | 'anonymousSticky';
  /** Mutual-exclusion layer — units in this layer are in at most one of its experiments. */
  exclusionLayer: string;              // 'checkout'
  /** Analysis contract, declared BEFORE launch. No peeking against this. */
  analysis: {
    primaryMetric: string;             // 'checkout_completed'
    guardrailMetrics: ReadonlyArray<string>;   // ['error_rate','latency_p95']
    minDetectableEffect: number;       // 0.02  (2pp)
    targetSampleSize: number;          // pre-registered; decision read here, not before
    horizonDays: number;
  };
  /** Consent class required to enroll + emit events. */
  requiresConsent: string;             // 'experimentation'
  enabled: boolean;                    // the kill-switch (see feature-flags infra)
}
```

The spec — not an inline `Math.random()` in a component — is what feature code authors. Bucketing, exclusion, consent, and the analysis contract are derived from it.

## Deterministic bucketing — same identity, same variant, forever

> The TypeScript below uses Node's `crypto` + a NestJS-style service for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the hash primitive, the DI mechanism, the request-context accessor. The SHAPE — hash(experimentId + salt + stableUnitId) → a point in [0,1) → weighted variant — is what's universal.

```ts
// src/modules/experiments/core/bucketing.ts
import { createHash } from 'node:crypto';

/** Pure, deterministic. Same (experimentId, salt, unitId) ALWAYS returns the same point. */
export function bucketPoint(experimentId: string, salt: string, unitId: string): number {
  const digest = createHash('sha256').update(`${experimentId}:${salt}:${unitId}`).digest();
  // Take the first 8 bytes as an unsigned int, normalize to [0, 1).
  const n = digest.readBigUInt64BE(0);
  return Number(n) / 2 ** 64;
}

/** Map the point to a variant by cumulative weight. Pure function — no randomness, no time, no I/O. */
export function pickVariant(spec: ExperimentSpec, unitId: string): string {
  const point = bucketPoint(spec.id, spec.salt, unitId);          // SAME unit -> SAME point
  const total = spec.variants.reduce((s, v) => s + v.weight, 0);
  let cumulative = 0;
  for (const v of spec.variants) {
    cumulative += v.weight / total;
    if (point < cumulative) return v.key;
  }
  return spec.variants[spec.variants.length - 1].key;             // floating-point tail guard
}
// NEVER: Math.random(), Date.now() as a seed, a per-request roll. The user would flip variants.
```

`bucketPoint` is a pure function: the same identity resolves to the same variant on every request, session, device, server render, and client hydration. There is no state to get out of sync.

## Server-authoritative assignment — the client is told, it does not pick

```ts
// src/modules/experiments/experiments.service.ts

@Injectable()
export class ExperimentsService {
  constructor(
    @Inject(EXPERIMENT_SPECS) private specs: SpecRegistry,
    @Inject(STICKY_ID) private sticky: StickyIdService,        // server-issued, signed, httpOnly cookie
    @Inject(EXCLUSION) private exclusion: ExclusionService,
    @Inject(ANALYTICS) private analytics: Analytics,          // exposure + metrics flow through HERE
    @Inject(CONSENT) private consent: ConsentService,
  ) {}

  /** Resolve the variant for the CURRENT request. Identity is server-authoritative. */
  assign(experimentId: string, ctx: AuthContext): Assignment {
    const spec = this.specs.get(experimentId);

    // Kill-switch + consent: non-enrolled units fall through to control, silently, no events.
    if (!spec.enabled) return { variant: 'control', enrolled: false };
    if (!this.consent.has(ctx, spec.requiresConsent)) return { variant: 'control', enrolled: false };

    // The bucketing unit is SERVER-AUTHORITATIVE — auth user id, or a server-signed sticky id.
    // It is NEVER read from req.body / req.query / req.headers. The visitor cannot change it.
    const unitId =
      spec.unit === 'anonymousSticky'
        ? this.sticky.getOrIssue(ctx)            // server sets + signs the cookie; client can't forge it
        : ctx.tenantScopedUnitId(spec.unit);     // ctx.userId / ctx.orgId from the verified session

    // Mutual exclusion: a unit already claimed by another experiment in this layer is NOT enrolled.
    if (!this.exclusion.claim(spec.exclusionLayer, experimentId, unitId)) {
      return { variant: 'control', enrolled: false };
    }

    const variant = pickVariant(spec, unitId);   // deterministic; the client is TOLD this, it does not pick
    return { variant, enrolled: true, unitId, experimentId };
  }

  /**
   * Log exposure EXACTLY ONCE, and ONLY when the variant is actually applied to the user.
   * Call this at the render/apply site — NOT inside assign(), NOT on a branch the user never reaches.
   */
  exposeOnce(a: Assignment, ctx: AuthContext): void {
    if (!a.enrolled) return;                     // control/non-enrolled emit nothing
    // Dedup key makes refresh / re-render / retry idempotent: one exposure per (experiment, unit, session).
    const dedupKey = `expose:${a.experimentId}:${a.unitId}:${ctx.sessionId}`;
    this.analytics.trackOnce(dedupKey, 'experiment_exposure', {
      experimentId: a.experimentId,
      variant: a.variant,
      unitId: a.unitId,                          // unit id + variant only — NO PII (no email/name/free text)
    });                                          // server-stamped identity + consent already honored upstream
  }
}
```

Identity comes from the verified session, never the request body. The client receives its variant; it never asserts one. Exposure is a separate call made at the point of application, deduped per session.

## Exposure on actual application — not at assignment

```ts
// src/modules/checkout/checkout.controller.ts  — exposure fires at the RENDER site, once.

@Get('/checkout')
async checkout(@Ctx() ctx: AuthContext) {
  const a = this.experiments.assign('checkout-button-2026q2', ctx);   // assignment: no exposure yet

  if (a.variant === 'treatment') {
    this.experiments.exposeOnce(a, ctx);          // EXPOSURE logged HERE — the variant is actually shown
    return this.renderTreatmentButton();
  }
  // control path: if control is a measured arm, expose it too on its render; otherwise no event.
  this.experiments.exposeOnce(a, ctx);
  return this.renderControlButton();
}
// WRONG: calling exposeOnce() inside assign() would count users on requests that never render the button
//        -> the denominator includes people who never saw the variant -> the measured effect is biased.
```

Exposure is logged when the user actually sees the variant, exactly once. Assignment without exposure is fine; exposure without application is forbidden.

## Mutual exclusion between conflicting experiments

```ts
// src/modules/experiments/core/exclusion.ts

@Injectable()
export class ExclusionService {
  /** A unit is in AT MOST ONE experiment per layer. Deterministic: same unit -> same claimant. */
  claim(layer: string, experimentId: string, unitId: string): boolean {
    // Deterministically pick which experiment in the layer owns this unit, by hashing the unit
    // against the layer's active experiments — so overlapping tests on the same surface never
    // both enroll the same user (which would make their interaction uninterpretable).
    const active = this.registry.activeInLayer(layer);                 // ['checkout-button','checkout-copy']
    const owner = active[Math.floor(bucketPoint(layer, 'exclusion', unitId) * active.length)];
    return owner === experimentId;
  }
}
// Two experiments changing the checkout button at once, with no exclusion, make BOTH unreadable:
// you can't attribute the metric move to either. The layer guarantees one experiment per unit.
```

## Sample-ratio-mismatch (SRM) detection — broken assignment must not pass silently

```ts
// src/modules/experiments/analysis/srm.ts

/** Chi-square goodness-of-fit: realized counts vs. the intended split. */
export function checkSRM(
  observed: Record<string, number>,                 // { control: 50214, treatment: 47120 }
  spec: ExperimentSpec,
): { ok: boolean; pValue: number; reason?: string } {
  const total = Object.values(observed).reduce((s, n) => s + n, 0);
  const weightTotal = spec.variants.reduce((s, v) => s + v.weight, 0);
  let chiSq = 0;
  for (const v of spec.variants) {
    const expected = total * (v.weight / weightTotal);
    const diff = (observed[v.key] ?? 0) - expected;
    chiSq += (diff * diff) / expected;
  }
  const pValue = chiSquarePValue(chiSq, spec.variants.length - 1);
  // A LOW p-value means the realized split differs from intended -> assignment is BROKEN.
  // (a redirect dropped an arm, a bot flooded one variant, a guard skewed enrollment)
  if (pValue < 0.001) {
    return { ok: false, pValue, reason: `SRM: split differs from intended (p=${pValue.toExponential(2)})` };
  }
  return { ok: true, pValue };
}
// On SRM: ALERT + QUARANTINE the result. Never ship/kill on a test whose groups aren't comparable.
```

## Fixed-sample analysis contract — no peeking

```ts
// src/modules/experiments/analysis/decide.ts

/** Read the decision ONCE, at the pre-registered sample size. Peeking inflates false positives. */
export function decide(
  experiment: ExperimentSpec,
  results: ExperimentResults,
): Decision {
  // GUARD: do not evaluate significance before the pre-registered sample size is reached.
  if (results.sampleSize < experiment.analysis.targetSampleSize) {
    return { status: 'collecting', seen: results.sampleSize, target: experiment.analysis.targetSampleSize };
  }
  // SRM gate FIRST — an invalid split makes any p-value meaningless.
  const srm = checkSRM(results.assignmentCounts, experiment);
  if (!srm.ok) return { status: 'invalid', reason: srm.reason };

  // Guardrails: a primary win that regresses a guardrail is NOT a ship.
  const guardrailBreach = experiment.analysis.guardrailMetrics.find(m => results.regressed(m));
  if (guardrailBreach) return { status: 'blocked', reason: `guardrail regressed: ${guardrailBreach}` };

  const primary = results.test(experiment.analysis.primaryMetric);    // fixed-horizon test at target N
  return { status: 'decided', ship: primary.significant && primary.lift > 0, lift: primary.lift, ci: primary.ci };
}
// WRONG: calling decide() every hour and stopping the moment primary.significant flips true is PEEKING.
//        With repeated looks the real false-positive rate is far above 5%. Read once at target N,
//        or use an explicit always-valid sequential test.
```

## Kill-switch + consent

```ts
// Kill-switch rides the feature-flag infra: force the experiment to control without a deploy.
async kill(experimentId: string, reason: string, ctx: AuthContext): Promise<void> {
  await this.flags.disable(`experiment:${experimentId}`);      // stops new enrollment instantly
  await this.specs.patch(experimentId, { enabled: false });    // existing units fall through to control
  await this.audit.record({ action: 'experiment.kill', experimentId, reason, actorId: ctx.userId });
}
// Consent is checked in assign() BEFORE enrollment; a non-consented user is never enrolled and
// emits no exposure/metric events (see compliance + analytics). They silently get control.
```

A harmful variant is killable in seconds with no deploy; a non-consented user is never enrolled.

## Common mistakes

### Per-request random assignment
`const variant = Math.random() < 0.5 ? 'a' : 'b'` → the same user gets A then B across page loads → their events split across arms → the experiment is noise. Bucket on `hash(experimentId + stableUserId + salt)`.

### Unstable bucketing unit
Bucketing on a per-visit session id → one human is many "users" in different arms. Bucket on the auth id or a server-issued sticky id stable across sessions/devices.

### Client-trusted assignment
`variant = req.query.variant`, or the client posts which arm it's in → a caller (or bot army) forces an arm → poisoned split. Assign server-side from a server-authoritative unit; tell the client its variant.

### Exposure at assignment time
Logging "exposed" inside `assign()`, even on requests that never render the variant → the denominator counts users who never saw it → diluted/biased effect. Log at the application site only.

### Double-counted exposure
Exposure fires on every re-render/refresh with no dedup → inflated denominator. Dedup per (experiment, unit, session).

### Overlapping experiments
Two tests change the same surface with no exclusion → you can't attribute the metric move → both unreadable. Put them in one mutual-exclusion layer.

### Peeking / no fixed sample size
Watching the dashboard and stopping the instant `p < 0.05` → the real false-positive rate is far above 5% → you ship noise. Pre-register the sample size; read once (or use a sequential test).

### Ignored SRM
Intended 50/50, realized 53/47, shipped anyway → a broken assignment silently invalidated the test. Check SRM first; quarantine on mismatch.

### PII in experiment events
Exposure payload includes email / name → experiment telemetry becomes a PII store. Send the unit id + variant + dedup key only.

### Consent ignored
An opted-out user is still enrolled and tracked → a compliance breach in the experiment path. No consent → control, no events.

### No kill-switch
A harmful treatment needs a deploy to stop → minutes-to-hours of harm. Every experiment force-disables to control without a deploy.

### Eyeballed readout
The "winner" is a hand-run `GROUP BY variant` with no tenant scope / no as-of / no reproducibility → a ship decision on a number nobody can re-derive. Compute via the reporting layer.

## Cross-references

- `<rules-path>/ab-testing-discipline.md` — the hard-rule list (deterministic bucketing, server-authoritative unit, exposure-on-application, mutual exclusion, fixed sample size, SRM, kill-switch, consent).
- `<rules-path>/feature-flags` — the assignment/rollout + kill-switch infra. BOUNDARY: a flag is a rollout toggle; an experiment is a measured comparison built on top of it (stable bucketing + exposure + analysis contract).
- `<rules-path>/analytics` — exposure + metric events route through the tracking contract: dedup keys, server-stamped identity, consent.
- `<rules-path>/compliance` — consent classes; a non-consented user is not enrolled and emits no events.
- `reporting` — the experiment readout is a trust-critical number: tenant-scoped, reproducible, as-of-labeled, computed on the read store.
- `<commands-path>/audit-experiment.md` — diagnose a specific experiment's assignment + exposure + analysis contract.
- `<agents-path>/ab-testing-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-experimentation-platform.md` — ADR pinning the platform, the analysis methodology, and the SRM/kill-switch contract.
