---
track: migration
purpose: Per-feature V1→V2 port — read V1 deeply, rebuild in V2 with parity guarantees, capture migration-time perf wins (caching / indexes / query optimisation / column projection). Cross-stack.
essentials:
  agents: [migration-architect, parity-auditor]
  commands: [migration-scan, migration-plan, migration-phase, migration-gate, migration-final, migration-rollback, migration-replan, migration-park, migration-unpark, migration-deprecate, compare-v1, port-feature, migration-status, draft-phase-adrs]
  skills: [extract-v1-contract, parity-test-generate, perf-uplift-survey]
  rules: [migration-discipline]
  ai-patterns: [feature-port, parity-testing, migration-ledger]
---

# Migration — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

This pack auto-loads when Phase 2 detects migration signals (parallel V1+V2 directories, `legacy/`+`new/` folders, version-suffixed module trees, dual app workspaces with `-v2` / `-next` / `-new` suffixes, README mentions of V1→V2/legacy migration). It can also be opt-in via `--include=migration` for greenfield projects planning a migration.

Rationale per category (one line each):
- **agents**: `migration-architect` plans the port (per-feature scope, parity strategy, perf-uplift candidates, cutover); `parity-auditor` verifies V1↔V2 equivalence before cutover.
- **commands**: Two suites. **Suite A — phased flow** (run in order): `/migration-scan` (deep V1↔V2 read; fresh ledger with everything `unverified`), `/migration-plan` (phased plan honoring V2 structure), `/migration-phase <N>` (audit + gap-find + port + verify per feature in phase N), `/migration-gate <N>` (read-only phase exit gate; refuses on any blocker), `/migration-final` (full sweep + V1 retirement plan). **Suite B — per-feature** (finer control outside the phased flow): `/port-feature` (one-shot port), `/migration-status` (lighter read of the ledger). Use Suite A for the full migration; Suite B for one-off ports.
- **skills**: `extract-v1-contract` reads V1 feature into a structured contract (inputs/outputs/side-effects/business-rules); `parity-test-generate` builds golden-master / record-replay / property-based tests that exercise V1+V2 with the same input; `perf-uplift-survey` finds migration-time perf wins (N+1, missing indexes, unbounded SELECT *, no caching, sequential awaits).
- **rules**: `migration-discipline` codifies the contract — parity is non-negotiable; perf uplift only when it preserves observable behaviour; every intentional behaviour break documented in an ADR.
- **ai-patterns**: `feature-port` is the playbook (per-feature lifecycle); `parity-testing` is the test technique catalogue; `migration-ledger` is the state-tracking convention (what's V1-only / In-progress / V2-shadow / V2-canary / V2-only / V1-deleted).

## Phased flow vs per-feature flow — which command when

The pack offers two flows that compose. **`/migration-phase <N>` dispatches `/port-feature <id>` per feature in phase N.** The phased flow is the batch wrapper; the per-feature flow is the unit of work. Both end at the same gate: `parity-auditor` verifies the artifact set per `migration-discipline.md` § "Required artifacts per feature".

```
First time setup
  ↓
/migration-scan ──→ ai/migration/{ledger.md, scan-report.md}
  ↓
/migration-plan ──→ ai/migration/plan.md
  ↓
─────── for each phase N ───────
│
│  /migration-phase <N>            ← batch orchestrator
│    ↓ (dispatches per row)
│    /port-feature <id>            ← per-feature orchestrator (≡ feature-port.md 6 phases)
│      ↓ (mandates)
│      • extract-v1-contract       → contracts/<feature>.md (9 sections)
│      • migration-architect       → plans/<feature>.md
│      • parity-test-generate      → <parity-test-root>/<feature>/ + tolerance.yaml
│      • perf-uplift-survey        → perf-decisions/<feature>.md
│      • write rollback runbook    → runbooks/migration-rollback-<feature>.md
│      • parity-auditor Stage A    → audits/<feature>.md
│
│  /migration-gate <N>             ← phase exit verifier
│    ↓ (12-check artifact validation; calls validate-migration-artifacts.sh)
│    PASS → continue to phase N+1
│    REFUSED → fix blockers; re-run /migration-phase <N>
│
─────────────────────────────────
  ↓
/migration-final ──→ ai/migration/{final-report.md, retirement-plan.md}
```

**Use the per-feature flow directly** (skip `/migration-phase`) when:
- You're porting a single feature outside a phase (e.g., a hotfix port).
- You want the full discipline on one row without coordinating across a phase.
- You're advancing a single feature through cutover stages (Shadow → Canary).

**Use the phased flow** for the full migration: it's the batch coordinator that produces phase-level artifacts (`audits/phase-<N>.md`) and gates phase exits.

**Use `/compare-v1` as preliminary** before either: read-only audit of V1↔V2 for a feature; output is the input the AUDIT step consumes.

**Use `/migration-status`** any time as a read-only health check.

## What this pack is NOT for

- **Behavior-preserving small refactors within a single version** → use the `code-quality` pack's `refactorer` agent.
- **Strategic monolith→microservices / framework upgrade planning** → use the `code-quality` pack's `legacy-modernizer` agent (this pack consumes its strategy and operates per-feature underneath it).
- **Database schema migrations only** (column adds, index changes, data backfills) → use the `database` pack's `migration-rehearsal` skill + `add-migration` command.

## How this pack relates to others

- **`code-quality/legacy-modernizer`** sets the *strategy* (strangler-fig vs big-bang, framework choice, timeline). Its plan generates the **list of features** that this pack ports one at a time.
- **`backend/parallelize-independent-ops`** + **`backend/concurrency-discipline`** are commonly applied during port (sequential awaits in V1 → bounded parallel in V2). The perf-uplift-survey skill cross-references them.
- **`database/query-optimizer`** + **`database/migration-rehearsal`** are commonly applied during port (V1 N+1 → V2 single query; missing index → added index). The perf-uplift-survey skill cross-references them.
- **`testing/tdd-orchestrator`** runs the parity test suite this pack generates. Parity tests are NOT speculative tests — they're golden-master / record-replay tests pinned to V1's *actual* observable behaviour.
