---
description: Audit a specific experiment — deterministic/stable bucketing, server-vs-client identity, exposure logging, mutual exclusion, SRM/peeking, kill-switch, and consent/PII — against the real assignment code, never an assumed shape.
---

# /audit-experiment

Diagnose whether a specific experiment is consistent + unbiased + analysis-ready: how it assigns variants, whether the same user always gets the same arm, whether exposure is logged once on actual application, whether identity is server-trusted, and whether the analysis contract is sound — from the REAL assignment code, not a guess.

## Premise

Real signals only. Cite the actual assignment/bucketing function at `<path:line>`, where the bucketing unit is resolved at `<path:line>`, the exposure-log call + the branch it fires on at `<path:line>`, the mutual-exclusion declaration, the SRM check, the sample-size/horizon contract, the kill-switch, and the consent gate — never narrate an experiment shape you didn't read. Read before judging: locate the assignment in source and confirm what the bucketing unit actually is (auth id? server-signed sticky id? a request field?) BEFORE ruling on it.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the assignment/bucketing fn at `<path:line>` and whether it is deterministic (`hash(...)`) or random/per-request, (2) where the bucketing unit comes from at `<path:line>` and whether it is server-authoritative + stable, (3) the exposure-log call at `<path:line>`, whether it fires only on actual application, and whether it is deduped, (4) the mutual-exclusion + SRM + fixed-sample contract, and (5) the kill-switch + consent gate. If any of these cannot be produced from real code, HALT and say which — never an assumed assignment, never an assumed exposure point.

This audit is READ-ONLY. It inspects assignment, exposure, and analysis code; it does NOT enroll units, fire events, or mutate experiment state.

## What it does

1. **Locate** the assignment — cite `<path:line>` and the exact bucketing expression / call chain.
2. **Deterministic vs. random** — is the variant `hash(experimentId + unit + salt)` (a pure function), or `Math.random()` / a per-request roll / a time-seeded value? Random/per-request = BLOCKER: the user flips arms, the data is unanalyzable.
3. **Stable + server-authoritative unit** — where does the bucketing unit come from? Auth id / server-signed sticky id (good), or `req.body`/`req.query`/`req.headers` (client-trusted = BLOCKER)? Is it stable across sessions/devices/server+client, or a fresh per-visit id (unstable = BLOCKER)? Cite `<path:line>`.
4. **Exposure logging** — is exposure logged at all? Does it fire ONLY when the variant is actually applied (render/apply site), or at assignment time / on an unreached branch (biased denominator = BLOCKER)? Is it deduped per (experiment, unit, session), or double-counted on re-render (BLOCKER)? Cite the call at `<path:line>`.
5. **Mutual exclusion** — do conflicting experiments on the same surface/metric share an exclusion layer, or can one unit be in both (interaction effects = finding/BLOCKER)?
6. **SRM + peeking** — is there a fixed sample size / horizon declared up front, and is the decision read once (not peeked)? Is SRM checked before any decision? Missing = finding/BLOCKER.
7. **Kill-switch** — can the experiment be forced to control without a deploy? Missing = finding.
8. **Consent + PII** — are non-consented users excluded (no enrollment, no events)? Do exposure/metric payloads carry PII (email/name)? PII or ignored consent = BLOCKER.
9. **Report** — assignment verdict, identity verdict, exposure verdict, exclusion/SRM/sample verdict, kill-switch + consent verdict, and the top fix.

## Flow

```text
locate assignment (<path:line>)
  -> deterministic hash? or Math.random()/per-request?         [BLOCKER if random]
  -> unit server-authoritative + stable?                       [BLOCKER if client-supplied / unstable]
  -> exposure logged? only on application? deduped?            [BLOCKER if missing/misfired/dup]
  -> mutual exclusion on conflicting experiments?              [finding if absent]
  -> fixed sample size + no peeking + SRM checked?             [finding/BLOCKER if absent]
  -> kill-switch forces control without deploy?                [finding if absent]
  -> non-consented excluded? no PII in events?                 [BLOCKER if violated]
  -> report: verdicts + top fix
```

## Output

```
/audit-experiment — <experiment id> @ <path:line>

Assignment (<path:line>):
  pickVariant(spec, unitId) -> hash(experimentId + salt + unitId)        deterministic   [or: Math.random() — BLOCKER]

Bucketing unit:    sticky.getOrIssue(ctx)  server-signed cookie  @ service.ts:38         [or: req.query.uid — BLOCKER]
                   stable across sessions/devices: YES                                   [or: per-visit session id — BLOCKER]
Exposure:          exposeOnce(a, ctx) @ checkout.controller.ts:14  on render  deduped    [or: at assign() — BLOCKER / no dedup — BLOCKER / MISSING — BLOCKER]
Mutual exclusion:  layer 'checkout' @ exclusion.ts:9                                      [or: NONE — interaction risk]
Sample / peeking:  targetSampleSize declared; decision read once @ decide.ts:11          [or: peeked / no fixed N — finding]
SRM:               checkSRM() before decision @ srm.ts:7                                  [or: NOT CHECKED — finding]
Kill-switch:       flags.disable('experiment:<id>') @ service.ts:..                       [or: NONE — finding]
Consent / PII:     non-consented -> control, no events; payload = unitId+variant only     [or: PII in payload — BLOCKER / consent ignored — BLOCKER]

Verdict: OK | NEEDS-DETERMINISTIC | NEEDS-SERVER-IDENTITY | NEEDS-EXPOSURE-FIX | BLOCKER(contaminated-data)

Top recommendation:
  - <e.g. replace Math.random() with hash(experimentId+stableUnit+salt); or move exposeOnce() to the render site; or resolve the unit from ctx, not req.query>
```

## Rules

- READ-ONLY audit. Never enroll a unit, fire an event, or mutate experiment state.
- Cite-or-halt: real assignment fn, real unit source, real exposure call, real analysis contract — or halt naming what's missing.
- Always print the assignment verdict first; random/per-request assignment is a BLOCKER (the user flips variants, the data is unanalyzable), reported before anything else.
- A client-supplied bucketing unit or a client-trusted variant is a BLOCKER (poisoned split) — say so, don't soften it.
- Exposure logged at assignment time, on an unreached branch, or without dedup is a BLOCKER (biased denominator) — name the branch it actually fires on.
- Never report an assignment shape, exposure point, or analysis contract you didn't read from source.

## Cross-references

- `.claude/rules/ab-testing-discipline.md` — the hard-rule list this command enforces (deterministic bucketing, server-authoritative unit, exposure-on-application, mutual exclusion, fixed sample size, SRM, kill-switch, consent).
- `ai/patterns/experiment-assignment.md` — the deterministic hash + server-authoritative unit + exposure-on-application + SRM + fixed-sample code shapes.
- `<rules-path>/feature-flags` — the kill-switch + rollout infra (boundary: flags = rollout, experiments = measured comparison).
- `<rules-path>/analytics` — exposure + metric events flow through the tracking contract (dedup, server-stamped identity, consent).
- `reporting` — the readout is a trust-critical number (tenant-scoped, reproducible, as-of-labeled).
- `<agents-path>/ab-testing-reviewer.md` — review gate that consumes these findings.
