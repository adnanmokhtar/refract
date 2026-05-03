---
description: Project-wide architectural diagnosis. Builds dependency + responsibility maps, flags layer violations, cyclic dependencies, god modules, anemic modules, wrong-level responsibilities, cross-cutting duplication, missing abstractions, bottleneck modules. Emits the foundation fix list (cascade impact) — these run BEFORE tactical fixes in /optimize. Stack-agnostic; reads PROJECT_KIND for stack-specific layer rules.
kind: skill
pack: code-quality
---

# Skill: architectural-diagnosis

## Purpose

Produce a project-wide architectural picture **before any optimisation fix lands**. Scoped at the module/layer level (NOT statement level). Surfaces the foundation issues whose fix cascades through dozens of tactical findings — so /optimize can apply them first and save 10× the work that scan-then-patch would burn.

This is the first skill /optimize dispatches. Output is consumed by /optimize Phase 1 (Apply foundations).

## When to use

- Dispatched by `/optimize` Phase 0 — every run starts here.
- Dispatched by `/setup-project --refine` when the user wants an architectural snapshot.
- Standalone diagnostic: `/optimize --diagnose-only` (writes the artifact, no fixes).
- NOT for per-feature work — /add-feature / /fix-bug have their own scope.

## Inputs (precise contract)

| Input | Source | Required |
|---|---|---|
| Codebase root | Orchestrator | YES |
| `PROJECT_KIND` | `_extracted-codebase.md § Gold standards` | YES (sets layer rules + stack-specific detectors) |
| Layer definition | `ai/architecture.md` OR `_extracted-idioms.md § Layers` | YES (without it, layer-violation detector skips with WARN) |
| Module boundary list | `_extracted-idioms.md § Modules` OR auto-detected from the project's actual layout (e.g., `<modules-root>/*`, `apps/*`, `packages/*`, the ecosystem's standard module locations) | YES |
| Scope filter (optional) | Caller flag (e.g., `--scope=orders`) | NO (default: full repo) |

## Outputs (precise contract)

`ai/optimize/_architecture-decisions.md` — a structured artifact consumed by /optimize Phase 1:

```markdown
# Architecture decisions — generated <iso>

> Diagnosis run at commit <sha>. PROJECT_KIND: <stack>.
> Layer rules read from: ai/architecture.md (or fallback noted)

## Maps (internal references)

- Dependency graph fingerprint: ai/optimize/_dep-graph.json (one row per module → its imports)
- Responsibility map fingerprint: ai/optimize/_responsibility-map.md (one row per module: name, responsibility, owns-state?, behaviour-vs-data)

## Findings (foundation-impact)

### F-A-001 — layer-violation [P0]
- **Class**: layer-violation
- **Subclass**: presentation-imports-data
- **Evidence**:
  - <modules-root>/orders/<page-or-leaf>/<feature-list>.<ext>:42 imports the project's data-access primitive directly
  - <modules-root>/orders/<page-or-leaf>/<feature-detail>.<ext>:18 imports the project's data-access primitive directly
  - 5 more (see _dep-graph.json query: presentation→data)
- **Cascade**: closes 14 tactical findings (8 N+1, 4 over-projection, 2 sequential await) that originate in these UI files
- **Closure verb**: move-responsibility
- **Foundation fix**: extract a feature-service primitive at <modules-root>/orders/<service-layer>/<feature-service>.<ext>; route presentation-layer fetches through it
- **Net-lines estimate**: +120 (service) / -340 (consumer code shrinks) = -220 net
- **Behaviour**: preserved
- **Risk**: low (mechanical move; tests cover the affected paths)

### F-A-002 — god-module [P1]
- **Class**: god-module
- **Subclass**: outward-imports-bloat
- **Evidence**:
  - <modules-root>/orders/services/OrderService.<ext> has 38 methods + 47 outward imports + 1240 LOC
  - 12 distinct conceptual responsibilities detected (events, payments, refunds, shipping, …)
- **Cascade**: closes 8 SOLID/SRP findings + simplifies 4 future fix sites
- **Closure verb**: split-god-module
- **Foundation fix**: split into 4 services (OrderEvents, OrderPayments, OrderShipping, OrderQueries) per responsibility map
- **Net-lines estimate**: 0 (move + re-export)
- **Behaviour**: preserved
- **Risk**: medium (callers of OrderService import paths change; codemod required)

### F-A-003 — missing-abstraction [P1]
... (etc)

## Decision summary

- Total architectural findings: 7
- Foundation fixes (apply Phase 1): 5
- Cosmetic (apply tactical Phase 2): 2
- Estimated tactical findings dissolved by foundations: ~49 of ~67

## Application order (foundation phase)

1. F-A-001 (layer violation — biggest cascade)
2. F-A-003 (missing abstraction — unblocks dedup phase)
3. F-A-002 (god module — split AFTER abstraction lands so split is cleaner)
4. F-A-005 (decouple cycle)
5. F-A-006 (centralize cross-cutting)
```

## Detectors (the 8 architectural smells)

### 1. layer-violation

**Fingerprint**: a module in layer L imports a module in layer L+k where k is forbidden (e.g., presentation → data without going through service).

**How to detect**:
1. Read layer rules from `ai/architecture.md` § Layers (or `_extracted-idioms.md § Layers`). Expected shape: `presentation → application → domain → infrastructure` OR project-specific `core / domain / api / ui`.
2. For each module, build its layer attribution from path conventions (e.g., `<components-root>/*` = presentation, `<services-root>/*` = application, `<repos-root>/*` = data — actual roots per `_extracted-idioms.md § Layers`).
3. Build the project's import graph (1 line per `import` statement; resolve relative paths to module attribution).
4. Flag every edge that crosses a forbidden boundary.

**Subclasses**:
- `presentation-imports-data` (UI doing DB queries)
- `data-imports-presentation` (a repository importing a UI primitive)
- `domain-imports-infrastructure` (pure business logic depending on a framework)
- `cross-module-direct-import` (module A reaches into module B's internals instead of going through B's public API)

**Closure verb**: `move-responsibility` (push the misplaced logic to the right layer; expose via the proper layer's interface).

### 2. cyclic-dependency

**Fingerprint**: module A imports module B which imports A (transitively).

**How to detect**: standard SCC (strongly-connected component) analysis on the import graph. Each non-trivial SCC (size ≥ 2) is a cycle.

**Subclasses**:
- `direct-cycle` (A ↔ B)
- `transitive-cycle` (A → B → C → A)
- `barrel-induced` (cycle exists only because both modules import a shared barrel `index.ts` that re-exports them)

**Closure verb**: `decouple-cycle` (extract shared types to a third module; move the dependency edge; replace direct import with dependency injection or event bus).

### 3. bottleneck-module

**Fingerprint**: a single module is in-degree ≥ 30 (most other modules transitively flow through it). Often a "utils" or "helpers" or "shared" module that becomes a single-point-of-failure for changes + a single-point-of-N+1 for performance.

**How to detect**: in-degree count from import graph. Anything ≥ 30 inbound edges is suspicious.

**Closure verb**: `split-god-module` (split bottleneck along functional cohesion lines; consumers import only the slice they need).

### 4. god-module

**Fingerprint**: ANY of:
- ≥ 30 outward imports (depends on too much)
- ≥ 500 LOC with mixed responsibilities (≥ 4 distinct conceptual responsibilities detected)
- ≥ 25 exported symbols with no cohesive narrative

**How to detect**:
- Outward imports: count `import` statements per file.
- LOC: line count.
- Mixed responsibilities: read all exported symbol names + their JSDoc/leading comment; cluster by topic. ≥ 4 clusters = mixed.

**Closure verb**: `split-god-module` (along responsibility boundaries).

### 5. anemic-module

**Fingerprint**: a module exports only data shapes (interfaces / types / consts) and zero behaviour, AND that data is consumed by a single caller, AND the caller's logic operates exclusively on that data.

**How to detect**:
- Module exports: 100% types/interfaces/data, 0% functions/classes with behaviour.
- Caller scan: only ONE module imports the data.
- Operate-on scan: that single caller has functions whose logic almost entirely manipulates the imported data.

**Closure verb**: `merge-anemic-module` (move the data into the consumer; or, if the data is too big, move the consumer's behaviour into the module so it gains responsibility).

### 6. wrong-level-responsibility

**Fingerprint**: behaviour that belongs at layer L lives at layer L+k.

**Common shapes**:
- Components doing data validation (should be in service / domain).
- Services doing UI formatting (should be in presentation).
- Controllers doing business logic (should be in domain / use-case).
- Repositories doing transformation (should be in service mapper).
- Handlers doing retry/circuit-breaker logic (should be in middleware / interceptor).

**How to detect**: per-stack heuristic patterns (per-stack pack provides fingerprints). Universal fallback: per-module count of operations-by-kind (validation / fetch / format / transform / persist) and flag modules where the dominant operation kind doesn't match the layer.

**Closure verb**: `move-responsibility`.

### 7. cross-cutting-duplication

**Fingerprint**: auth check / log statement / error handler / retry policy / metric emission / tracing span starts duplicated across N modules with the same shape, no centralised primitive.

**How to detect**: scan for repeated patterns across modules. If ≥ 5 modules contain the same shape (e.g., the same 6-line auth-check block, or the same try/catch with `console.error(err)`), it's a cross-cutting concern that should be centralised (middleware / decorator / interceptor / aspect).

**Closure verb**: `centralize-cross-cutting`.

### 8. missing-abstraction

**Fingerprint**: ≥ 3 sites duplicate the same shape that wants a primitive (e.g., 5 different pagination implementations; 4 different error envelopes; 3 different retry loops).

**How to detect**: AST-shape clustering. For each function/class whose signature + body shape repeats with minor variation across modules, count the sites. ≥ 3 = missing abstraction.

**Closure verb**: `introduce-abstraction` (author the primitive; route consumers through it; delete the local copies).

## Procedure (step-by-step — what the skill executes)

1. **Pin commit** — `git -C <root> rev-parse HEAD` → recorded in artifact header.
2. **Build dependency graph** — walk every `.ts/.tsx/.js/.jsx/.vue/.py/.go/.java/.cs/.rb` file; extract `import` / `from … import` / `require()` / `using` statements; resolve to module attribution; emit `ai/optimize/_dep-graph.json` (rows: `{from, to, layer_from, layer_to}`).
3. **Build responsibility map** — per module, list exported symbols + 1-line summary derived from name + leading comment + JSDoc. Emit `ai/optimize/_responsibility-map.md`.
4. **Run 8 detectors** (in order — each writes its findings into the artifact's "Findings" section):
   1. layer-violation
   2. cyclic-dependency
   3. bottleneck-module
   4. god-module
   5. anemic-module
   6. wrong-level-responsibility
   7. cross-cutting-duplication
   8. missing-abstraction
5. **For each finding**: cite ≥1 `<path:line>` evidence; pick closure verb from the rule's vocabulary; estimate cascade (which tactical findings would dissolve); estimate net-lines; assess risk.
6. **Compute application order** — biggest-cascade-first, with dependencies (some foundations need to land before others; e.g., introduce abstraction before split-god-module).
7. **Write `ai/optimize/_architecture-decisions.md`** with the structure shown above. NO fixes are applied by this skill — application is /optimize Phase 1.
8. **Halt conditions**:
   - Layer rules missing AND no per-stack fallback → emit WARN, skip layer-violation detector, continue.
   - Project too small for diagnosis (≤ 5 modules) → emit "skip — small project" and no foundations queued.
   - Cyclic dependency that crosses ≥ 4 modules → flag for user review (multi-PR decoupling required, surfaces a small plan).

## Hard rules

- Every finding cites ≥ 1 `<path:line>` evidence.
- No "looks like" / "seems duplicated" — only AST-shape-confirmed clusters count.
- The artifact is INTERNAL (not shown to user). /optimize summarises it in 1-2 lines per architectural fix in the end-of-run output.
- Closure verbs are the closed set above; no novel architectural moves invented at fix time.
- If a finding's risk is `high` (cyclic dependency requires multi-PR; god-module split would change a public API), surface for user decision rather than auto-applying.

## Mandatory Phase-0 evidence emission

The artifact at `ai/optimize/_architecture-decisions.md` MUST contain machine-verifiable evidence in the body. Without it, `validate-optimize-artifacts.sh § check_phase_0_evidence` halts the run. Required block shape (paste verbatim):

```
## Phase 0 — Dependency map evidence
Source files walked: <count>
Import statements parsed: <count>
Sample (first 20 rows; full graph at ai/optimize/_dep-graph.json):
  <module-A> → <module-B>  (via <import-statement-path:line>)
  <module-A> → <module-C>  (via <import-statement-path:line>)
  ...

## Phase 0 — Responsibility map evidence
Source: ai/optimize/_responsibility-map.md
Sample (first 20 modules):
  <module-path>: owns <responsibility>; exports <symbol-count> symbols at <path:lines>
  ...

## Phase 0 — Layer attribution evidence
Layer rules read from: <ai/architecture.md OR _extracted-idioms.md § Layers>
Modules attributed (per layer):
  presentation: [<module-paths>]
  application: [<module-paths>]
  domain: [<module-paths>]
  infrastructure: [<module-paths>]

## Phase 0 — Detector run evidence
For EACH of the 8 detectors, paste:
  Detector: <detector-name>
  Modules scanned: <count>
  Fingerprint matches: <count>
  Sample matches (first 10):
    - <path:line> — <fingerprint-excerpt>
    - <path:line> — <fingerprint-excerpt>
  No-match modules: <count>
```

Without these blocks the validator halts with: "Phase 0 evidence missing in <file>; architectural diagnosis cannot be trusted."

## Halt #A1 — Phase 0 must be auditable

A Phase 0 run that outputs only architecture-decisions.md without the four evidence blocks above is a "summary diagnosis" — flagged equivalent to the F039 anti-Trusted-Summary recurrence. The validator refuses to advance /optimize past Phase 0 without visible evidence.

## Failure modes

- **No findings** → emit "Codebase already architecturally clean; tactical sweep proceeds directly."
- **All findings high-risk** → halt /optimize; surface the list with one-line risk reasons; user picks which to attempt.
- **Layer rules contradict path conventions** → emit WARN, prefer rules from `ai/architecture.md`, note the path-convention drift as a separate finding (drift class).

## References

- `align-discipline.md` — the closure-verb closed vocabulary (architectural verbs are a sub-set).
- `engineering-principles.md` (this pack) — the principles foundation fixes restore.
- `quality-principles.md` (this pack) — the principles tactical sweep enforces.
- `migration-discipline.md` — referenced for the 6-axis dead-code check (used in step 4.7 to flag dead modules as deletion candidates).
