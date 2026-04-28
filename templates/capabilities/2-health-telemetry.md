---
artifact: capability-2-health-telemetry
purpose: Setup health score + per-run telemetry (B3). Local-only; no PII; surfaces in _session-digest.md (Tier 1).
imported-by: templates/capabilities.md (index), commands/setup-project.md (orchestrator)
---

### 📊 2. Setup health score + telemetry (B3)

**Problem solved**: command writes 50+ files. Are they helping? Which agents/skills/commands actually get invoked? Has the setup decayed since apply? No way to know without measurement.

**Design**:

#### 2.1 Health score formula

Score is `0–100`, computed by `--health` flag and at end of every Phase 5:

```
health_score = (
  0.25 × baseline_completeness +    # full `templates/repo-baseline/ai/` seeded tree present in project `ai/`
  0.20 × pack_coverage +            # per-track minimums met (Phase 4.0)
  0.15 × adapter_completeness +     # per-adapter contracts (Phase 4.8.0)
  0.15 × cross_ref_integrity +      # broken refs / ghost files
  0.10 × convention_match +         # codebase conventions match `ai/conventions.md`
  0.10 × version_currency +         # how far behind latest packs
  0.05 × usage_signal               # invocation telemetry presence
)
```

Each sub-score 0–100. Composite tagged:
- `90–100`: Excellent
- `70–89`: Good
- `50–69`: Drift detected
- `< 50`: Setup needs refresh

#### 2.2 `--health` output

```
$ /setup-project --health

SETUP HEALTH SCORE: 87/100  (Good)

  ✓ Baseline completeness:    100/100  (13/13 baseline files)
  ✓ Pack coverage:             95/100  (backend 5/5 ★, security 2/2 ★, testing 3/3 ★)
  ⚠ Adapter completeness:      75/100  (cursor: 8/10 commands translated; opencode: complete)
  ✓ Cross-ref integrity:       100/100 (0 broken refs)
  ⚠ Convention match:          80/100  (3 generic rules detected; Phase 4.6 may need re-run)
  ⚠ Version currency:          70/100  (backend 1 minor behind, security 1 major BREAKING behind)
  ⚠ Usage signal:              60/100  (3 of 12 agents never invoked in last 30 days)

Top 3 actions:
  1. Run /setup-project --refresh   → close version-currency gap (+10)
  2. Re-run Phase 4.6 conventions  → close convention-match gap (+5)
  3. Translate 2 missing cursor commands → close adapter-completeness gap (+5)

Last computed: 2026-04-25T14:35:00Z
```

#### 2.3 Telemetry log

Every command/agent/skill invocation appends one line to `.claude/_telemetry.jsonl`:

```jsonl
{"ts":"2026-04-25T14:30:00Z","kind":"command","name":"/add-module","tool":"claude-code","duration_ms":45000,"success":true}
{"ts":"2026-04-25T14:32:10Z","kind":"agent","name":"nestjs-architect","invoked_by":"/add-module","duration_ms":12000,"success":true}
{"ts":"2026-04-25T14:33:00Z","kind":"skill","name":"endpoint-test","invoked_by":"manual","duration_ms":3000,"success":true}
```

Format: append-only JSONL. Pruned to last 90 days at session start. NEVER sent off-machine — entirely local telemetry.

Wired via:
- Each generated command's Phase 7 (Improve) appends a telemetry entry.
- Each agent's pre-flight emits a `kind:"agent"` entry.
- Each skill's `SKILL.md` includes a telemetry-emit step.

#### 2.4 Drift score (sub-component)

Computed by comparing `.claude/codebase-profile.md` § "Detected stack/conventions" against current state of code. Mismatches = drift.

```
DRIFT REPORT
  Profile says: base class BaseService (47 extenders)
  Current code: BaseService (52 extenders) ✓
  Profile says: file naming kebab-case + suffix matrix
  Current code: kebab-case + suffix matrix ✓
  Profile says: tenantId column on every entity
  Current code: 3 NEW entities WITHOUT tenant_id  ⚠
    apps/master/src/billing-experiments/.../experiment.entity.ts
    libs/common-modules/src/notifications/.../template.entity.ts
    apps/tenant/src/v3/products/.../variant.entity.ts
```

Drift findings auto-feed Phase 6 learning loop (the `convention-drift-detector` agent picks them up).

#### 2.5 Phase 6 effectiveness metrics

Once telemetry has 30+ days of history, Phase 6 reports include:
- **Correction rate**: corrections per session (target: declining over time).
- **Pattern reuse**: ratio of new modules using existing patterns vs inventing new ones.
- **Agent utility**: invocation count per agent (low-utility agents flagged for removal).
- **Skill cache-hit**: how often `getOrSet` hits in skill flows (target: rising).

Output in `ai/_session-digest.md` § "Setup health" line.

#### 2.6 Hard rules

- **Telemetry is local-only.** NEVER make a network call from the telemetry path. NEVER include user/PII data in telemetry entries.
- **Health score MUST appear in `_session-digest.md`.** Tier 1 visibility — silent decay isn't allowed.
- **`.claude/_telemetry.jsonl` MUST be `.gitignore`d.** Phase 4.1 enforces.

---

