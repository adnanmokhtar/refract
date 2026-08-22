---
name: progressive-delivery
description: Audit the two pieces that decouple deploy from release — feature-flag lifecycle (no stale/orphaned/permanent flags, kill-switch on risky flows, flag-config parity across envs) and automated canary ANALYSIS wiring (a canary that promotes/aborts itself on SLO/error metrics, not a human eyeballing a dashboard).
---

# progressive-delivery

A risky change ships behind a flag with a kill-switch and an automated metric gate on its rollout. This skill audits those two mechanisms — nothing else.

## Premise

A flag that lives forever, a canary with no automated analysis/abort, or a risky flow with no kill-switch is forbidden. Every finding cites the real artifact: the flag key and the file that defines it, the grep that proves it's never referenced (dead) or hardcoded-on (stale), the AnalysisTemplate/Flagger metric block that is present or absent, the two env configs whose flag values diverge. A "flag looks stale" claim without the reference-count grep is not a finding. A "canary has no gate" claim without showing the rollout spec has no analysis step is not a finding.

**Boundary (read first — this is not a deploy-strategy skill):**
- `@deployment-engineer` owns canary/blue-green as a **deploy STRATEGY** — which one, resource overhead, rollback command. It does not audit whether a flag is orphaned or whether a canary's metric gate is actually wired.
- `monitor-deploy` watches **a single deploy's** health window and triggers `/rollback-deploy` on breach. It does not own the flag's whole lifecycle, cross-env flag parity, or the canary's *automated promotion* logic.
- **THIS** owns (a) flag lifecycle — stale/orphaned/permanent flags, kill-switch presence, cross-env parity, flag→config coupling; and (b) automated canary ANALYSIS wiring — the AnalysisTemplate/metric gate that promotes or aborts without a human.

## When to use

- Before merging a change gated by a new feature flag — confirm it has an owner, a removal date, and a kill-switch if the flow is risky.
- Quarterly flag hygiene sweep — hunt dead flags (defined, never referenced) and stale flags (permanently on, should be deleted).
- When adopting or reviewing a canary rollout — verify the metric gate is real, not a manual `promote` a human clicks.
- After a full rollout — confirm the flag was removed, not left at 100% forever.

## Adapt to the flag + canary tooling

- **Flags:** LaunchDarkly (`ld.variation(...)`, dashboard flag list), Unleash (`isEnabled(...)`, `/api/admin/features`), Flagsmith, or config-based (`flags.yaml`, env vars, a `features` table). Resolve the flag registry AND the code call-sites — you need both to prove dead/live.
- **Canary analysis:** Argo Rollouts + `AnalysisTemplate` (metric queries + `successCondition`/`failureLimit`), Flagger (`Canary` + `metrics[]` + `webhooks`), Spinnaker/Kayenta (canary config + judge). The gate is the `analysis`/`metrics` block; its absence is the finding.

## Scans for

1. **Dead flag** — flag key present in the registry/config but zero references in code (grep the key across the tree; 0 hits = dead, delete it).
2. **Stale flag** — flag hardcoded on (`return true`, default `on` with no variation, 100% rollout) with a create date past the removal window → it's now permanent config, remove the branch.
3. **No removal date / owner** — a live flag with no expiry annotation, no owning team, no cleanup ticket → it will outlive its purpose.
4. **Missing kill-switch** — a risky mutation (payments, deletes, migrations, external side-effects, fan-out writes) shipped behind a flag whose only path is deploy-to-disable, not flip-to-disable.
5. **Canary with no automated gate** — a Rollout/Canary that ramps traffic but has no `analysis`/`metrics` block, so promotion is a manual click and abort depends on a human watching a dashboard.
6. **Cross-env flag drift** — same flag key resolves to different values across `dev`/`staging`/`prod` configs with no documented reason (staging can't validate what prod will do).
7. **Flag→config coupling** — a flag that also silently rewires config/secrets/routing, so flipping it does more than gate a code path (blast radius hidden).

## How to detect

```bash
# Dead/stale flags (config-based): every declared key vs its reference count in code.
# --include takes ONE glob and does NOT brace-expand: '*.{ts,js}' matches a file literally
# named that, i.e. nothing, so every flag would report 0 refs = DEAD. Repeat the flag instead.
INC=(--include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx'
     --include='*.py' --include='*.go' --include='*.rb' --include='*.java' --include='*.kt')

for key in $(yq '.flags | keys | .[]' flags.yaml 2>/dev/null); do
  n=$(grep -rIl "${INC[@]}" -- "$key" src/ api/ 2>/dev/null | wc -l)
  echo "$n refs   $key"        # 0 = dead; also check if hardcoded on (stale)
done
```

**Sanity-check the harness before you trust a zero.** A reference-count grep that is misconfigured
reports every flag dead, and "delete these 23 flags" is exactly the finding you cannot take back.
Run it against a key you *know* is live first; if that returns 0, the grep is broken, not the flag.
The extension list must also match the repo — a `.svelte`/`.vue`/`.erb` codebase whose flags are
read in templates will report dead flags against a `.ts`-only include list.

```bash
# Canary analysis gate present? (Argo Rollouts) — a Rollout with steps but no analysis is no-gate.
grep -rl 'kind: Rollout' k8s/ 2>/dev/null | while read -r f; do
  grep -q 'analysis:' "$f" || echo "NO-GATE: $f (setWeight steps, no AnalysisTemplate)"
done

# Cross-env flag drift (config-based): diff the flag blocks between envs.
diff <(yq '.flags' config/staging.yaml) <(yq '.flags' config/prod.yaml)
```

For LaunchDarkly/Unleash, pull the flag registry from the admin API (`/api/admin/features`, LD `flags` endpoint) for the key list, then run the same reference-count grep against code.

## Output

```
progressive-delivery audit — <service/repo>

Feature-flag lifecycle (registry: LaunchDarkly, 23 flags):
  ✗ DEAD      checkout_v2_layout      — defined, 0 code references (grep across src/ + api/)
  ✗ STALE     enable_new_search       — hardcoded true since 2025-01, past 90d window — remove branch
  ✗ NO-KILL   async_refund_processor  — payment mutation, disable path = redeploy, not flag flip
  ⚠ DRIFT     rate_limit_tier         — staging=off prod=on, no note; staging can't reproduce prod
  ✓ OK        beta_dashboard          — owner @growth, removal 2026-09, kill-switch present

Automated canary analysis (Argo Rollouts):
  ✗ NO-GATE   payments-api Rollout    — setWeight steps present, no AnalysisTemplate → manual promote only
  ✓ OK        web Rollout             — AnalysisTemplate error-rate<0.5% + p95 gate, failureLimit=1, auto-abort

Blockers:
  1. async_refund_processor — add flag-flip kill-switch before merge (payment side-effect, no fast off).
  2. payments-api canary — wire AnalysisTemplate (error-rate + p95); a canary without an auto-abort is a slow full deploy.

Cleanup:
  - Delete checkout_v2_layout (dead) and enable_new_search (stale) — 2 flags, ~40 LOC of dead branches.
```

## False positives / gotchas

- A flag with **0 code references** may be read by a downstream service or SDK you didn't grep — confirm it's not consumed out-of-repo before deleting.
- **Kill-switch ≠ rollback.** monitor-deploy's rollback restores the previous revision; a kill-switch flips behavior *without* redeploy. A risky flow needs the flip, not just the redeploy path — don't accept "we can roll back" as a kill-switch.
- A **canary metric gate that only checks readiness** (pods READY) is not analysis — analysis compares error-rate/latency of the canary subset vs stable. Readiness-only is a no-gate finding.
- **Kayenta/judge configs** can exist but be scored advisory-only (no auto-abort) — a gate that reports but never aborts is still a no-gate for this skill's purpose.
- **Permanent operational flags** (kill-switches, circuit-breakers, region toggles) are *meant* to live forever — don't flag them as stale; distinguish release flags (temporary) from ops flags (permanent) before reporting.
- Cross-env drift is expected for **sampling/rollout-percentage** flags mid-ramp — only flag drift on boolean release gates, not in-progress percentage ramps.

## Halt conditions

- Refuse to call a flag dead without the reference-count grep across the code tree — no grep, no verdict. And refuse to trust a grep that returned 0 for *every* key: that is a broken harness, not a repo full of dead flags. Prove the harness on a known-live key before reporting any DEAD.
- Refuse to call a canary "no automated gate" without showing the Rollout/Canary spec lacks an `analysis`/`metrics` block.
- Halt if the flag registry is unresolvable (no LD/Unleash access, no config file) — audit what you can grep and say the registry side is unverified; don't guess flag state.
- Missing kill-switch on a payment/delete/migration flow = block. Canary on a high-blast-radius service with no auto-abort = block.
- Don't recommend deleting a flag whose removal you can't prove is safe (out-of-repo consumers) — surface it for owner confirmation instead.

## Related

- `@deployment-engineer` — owns canary/blue-green as a deploy STRATEGY (this owns the flag lifecycle + the canary's automated analysis wiring).
- `monitor-deploy` — watches a single deploy's metrics window (this watches the flag's whole life + the canary's auto-promote/abort logic).
- observability pack `slo` skill — defines the SLO/error-budget metrics the canary AnalysisTemplate should gate on.
