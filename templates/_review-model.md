# `_review-model.md` — the review model `/audit` resolves against

**Status:** Phase 0 of [`docs/plans/audit-review-matrix.md`](../docs/plans/audit-review-matrix.md).
**Consumed by:** `commands/audit.md` Phase 0 (resolution), `templates/_review-matrix.md` (Phase 1,
cell population), `scripts/validate-review-model.sh` (mechanical acceptance).
**Not a rule file.** It is read by the command at resolve time, never installed into a project's
`.claude/rules/`. See the token-budget risk in the plan §7.

---

## 1. The three dimensions, and the sorting rule

A review target is addressed by three independent things. Mixing them into one flat list is the
defect this file exists to fix — it double-counts findings and lets the ranker compare a finding
against itself.

| Dimension | Question it answers | Cardinality |
|---|---|---|
| **Surface** | *Where in the code?* | per-project, resolved from detection |
| **Concern** | *Which cross-cutting property, everywhere it appears?* | 12, fixed (§3) |
| **Axis** | *Which system property, evaluated per surface and globally?* | 26, fixed (§4) |

**The sorting rule.** For any candidate item, ask in this order:

1. Does it name a *place code lives*? → **surface**.
2. Does it apply to *every surface that has an actor / consumer / payload*? → **concern**.
3. Otherwise → **axis**.

**The no-double-count rule.** *A concern is never also a standalone axis.* Its score is the
aggregation of its cells. `Security: 14 findings` is a computed roll-up of
`Security × {every resolved surface}` — never a bucket a separate agent fills. An item appearing
in two dimensions is a Phase 0 failure, not a modelling choice.

---

## 2. Surfaces — **derived, never authored**

> **This section may not coin a name.** Every non-structural surface name MUST be a literal key
> from [`templates/domains/_registry.md`](domains/_registry.md) § Registry (implemented) — the
> same registry that `§11 technical_signals` emits against and that Phase 4.4 feeds to
> `cp templates/domains/<signal>/…`.
>
> **HISTORY — why this is a MUST and not a preference.**
> [`phase-2-profile.md:269`](phases/phase-2-profile.md#L269) records the identical defect one
> layer down: a free-text §11 label like `media-transcoding` "resolves to **no folder** and the
> domain is silently skipped." A matrix cell addressing a surface no detector ever emits fails
> the same way and is *equally silent* — the cell is simply never dispatched, and nothing in the
> N/A ledger can report a surface that was never named.
>
> The draft plan spoke `Files` / `WS` / `Jobs`. The registry speaks `file-upload` / `real-time` /
> `background-jobs`. **The registry wins.**

### 2.1 Signal surfaces — the 35 implemented registry keys

Admissible surface names, verbatim. Which of them are *live* for a given run is not decided here
— that is §11 `technical_signals` filtered by the Relevance Filter (`setup-project.md` Appendix B).
This file only fixes the vocabulary.

```
ab-testing            data-pipeline         ledger                reporting
admin                 document-generation   media-processing      scheduling
ai                    event-sourced         moderation            search
analytics             feature-flags         multi-tenant          settings
audit-log             file-upload           notifications         streaming-delivery
auth                  forms                 payment               subscriptions
background-jobs       i18n                  public-api            webhook
caching               import                rate-limiting         workflow
compliance            integrations          real-time
```

Regenerate — this block is a projection, and drift is a build break:

```sh
awk '/^## Registry \(implemented\)/,/^## Registry \(cataloged/' templates/domains/_registry.md \
  | grep -oE '^\| `[a-z0-9-]+`' | tr -d '|` ' | sort
```

Keys under § Registry (cataloged but generate-on-detection) are **not** admissible surfaces until
promoted. A cell may not address a surface whose folder does not exist.

### 2.2 Structural surfaces — the explicitly-marked exception

Four surfaces exist in essentially every project of their kind and are covered by no technical
signal. They are the **only** names in this file not drawn from the registry, and they are listed
here separately so the validator can exempt exactly these four and nothing else:

| Structural surface | Present when | Material lives in | Why no registry key |
|---|---|---|---|
| `_database` | a persistence layer exists (migrations / ORM models / schema) | `database`, `migration` | Persistence is not a cross-cutting *signal*; it is the substrate. `multi-tenant` and `caching` are signals **on** it. |
| `_deployment` | Dockerfile / IaC / CI deploy manifests exist | `infrastructure`, `devops` | Ships nothing under `templates/domains/`. |
| `_routes` | `project_kind` includes `server` | `backend` | The HTTP entry surface. `public-api` is the *versioned-contract* signal on top of it, not a synonym. |
| `_screens` | `project_kind` includes `browser` or `mobile` | `frontend`, `mobile`, `ui-ux` | The render entry surface. |

**The "Material lives in" column is read by the matrix generator** — it is the structural
counterpart to `_registry.md`, and it names only packs that are *about that surface*.
Cross-cutting packs (`security`, `performance`, `observability`, `testing`, `code-quality`,
`finops`, …) are deliberately **excluded**: they are axis-major, they apply to every surface, and
listing them under each one would mark every cell confirmed by construction — the same
over-counting that made the first full-text pass score 312/420.

**Leading `_` is load-bearing**: it makes "is this a registry key or a structural exception"
mechanically decidable, and guarantees a structural name can never silently shadow a future
registry key.

**Resolved surface set for a run:**

```
SURFACES = (§11 technical_signals ∩ §2.1)  ∪  (§2.2 structural, gated on project_kind)
```

Typical N = 8–14.

---

## 3. Concerns — 12

Cross-cutting properties. Each is evaluated on **every** resolved surface that can carry it; its
headline number is the roll-up of its cells.

### 3.1 The 7 supplied (§7)

The source cross-cutting list, verbatim and in order. **Only four of the seven appear in the
30-list** — that overlap is precisely the double-count §1 forbids. The other three exist *only*
as concerns and have no axis number at all.

| # | Concern | In the 30? | Asks |
|---|---|---|---|
| C1 | **Security** | yes — `02` | Is it exploitable? |
| C2 | **Performance** | yes — `06` | What does it cost per invocation? |
| C3 | **Observability** | yes — `09` | If it breaks at 03:00, can anyone tell? |
| C4 | **Error Handling** | **no** | What happens on the unhappy path — and does the caller learn? |
| C5 | **Logging** | **no** | What is written, who can read it, and what does it cost? |
| C6 | **Configuration** | yes — `24` Configuration Management | Same value in every environment, and who may change it? |
| C7 | **Compliance** | **no** | Which regime applies here, and is the obligation met at this call site? |

> **C4, C5 and C7 are the highest-value slots in this table**, because a concern that never had an
> axis number was never in any checklist. The plan's own Phase 4 "known-empty" list independently
> arrived at one of them — *"Logging as a concern: logger identity is extracted (§ 8) but nothing
> reviews **what** is logged."* That gap is C5, and it was found from the other direction.

### 3.2 The 5 added (plan §3.1)

| # | Concern | Why cross-cutting, not an axis | Gate |
|---|---|---|---|
| C8 | **Authorization** | Security asks *is it exploitable*; AuthZ asks *at which layer is the check*. Controller-layer in some modules, repository-layer in others is the single most common architectural inconsistency. Cuts every surface with an actor. | `auth` |
| C9 | **Idempotency** | Cuts `public-api` (POST), `background-jobs` (at-least-once), `webhook` (replay), `integrations` (sync), `payment`. The one scale detector (#11) is too narrow to carry it. | — |
| C10 | **Versioning / Compatibility** | API versions, schema versions, event-schema evolution, forced-update, SDK compat. Cuts every surface with a consumer. | — |
| C11 | **Data Lifecycle / Retention** | Cuts `_database`, `file-upload`, logs, backups, `analytics`, `audit-log`. Nothing today reviews *how long does this live and who deletes it*. | — |
| C12 | **Tenancy Isolation** | Conditional. When present it cuts everything. | `multi-tenant` |

---

## 4. Axes — 26

30 source items, minus the 6 surfaces (§2), minus the 4 concerns that double-counted (C1, C2, C3,
C6), leaves **20 axes**. Plus the 6 added by plan §3.2 = **26**.

> The plan claims 23. **That is wrong**, and it is wrong for a traceable reason: plan §2.2 asserts
> *"Seven of the 30 are concerns"*. Only **four** are. Three of the seven — Error Handling,
> Logging, Compliance — never appeared in the 30, so subtracting seven removed three items that
> were never there. `30 − 6 − 7 + 6 = 23` was arithmetic on a wrong premise. See §8.

### 4.1 From the source list — 20, keeping the source numbering

Numbers are the source list's own, so any finding traces back to the item the reviewer asked for.

```
01  Architecture                 16  Data Integrity
03  Correctness                  17  Resilience
04  Scalability                  19  Capacity Planning
07  Reliability                  20  Operational Readiness
08  Testing                      21  Requirements / Business Fit
10  Maintainability              22  Modularity / Boundaries
12  Domain Modeling              23  Dependency Management
13  Concurrency                  25  Migration / Schema Evolution
14  Distributed Systems          26  Backup / Disaster Recovery
                                 29  Cost Efficiency
                                 30  Developer Experience
```

Absent numbers: `02 06 09 24` → concerns (C1 C2 C3 C6). `05 11 15 18 27 28` → surfaces (§2).

> **`17 Resilience` is missing from plan §2.3 and is restored here.** That omission is the entire
> reason §2.3 lists 19 where the model requires 20. It is an axis, not a concern — the source
> cross-cutting list does not contain it, which settles the question by evidence rather than taste.

### 4.2 Added by plan §3.2 — 6, numbered onward from the source list

| # | Axis | Gate — in checkable vocabulary (§5) |
|---|---|---|
| 31 | **Accessibility** | `project_kind ∈ {browser, mobile}` |
| 32 | **Internationalization** | `project_kind ∈ {browser, mobile}` **or** signal `i18n` |
| 33 | **UX / Interaction** | `project_kind ∈ {browser, mobile}` |
| 34 | **Release / Change Management** | surface `_deployment` resolved |
| 35 | **Data Privacy / PII** | — (always) |
| 36 | **AI / LLM Surface** | signal `ai` |

> 35 Data Privacy / PII is an *axis* while C7 Compliance is a *concern*, and they are not the same
> question. Compliance asks *which regime binds this call site*; Data Privacy asks *where does PII
> enter, propagate, get logged, get exported*. One is a rulebook, the other is a flow.

## 5. Conditional gating — expressed only in checkable vocabulary

> **Second fork, same class as §2.** The plan's draft gate read *"`Accessibility`/`UX` need a
> `frontend-*` or `mobile-*` PROJECT_KIND."* `frontend-*` is **prose**. It appears in
> `commands/*.md` narrative and in nothing a machine emits.
> [`scripts/detect-project-kind.sh`](../scripts/detect-project-kind.sh) prints a set drawn from
> exactly `browser server mobile cli`, falling back to `any`, and
> [`templates/packs/_project-kind.md`](packs/_project-kind.md) fixes that as a closed 5-value
> contract carrying its own measured defect (49,450 bytes — 17.6% of a run — of browser-only
> content installed on a headless API).
>
> **A gate in this file may reference only:**
> 1. a literal key from `_registry.md` § Registry (implemented) — a *signal* gate; or
> 2. a member of `{browser, server, mobile, cli, any}` — a *kind* gate; or
> 3. a structural surface name from §2.2.
>
> `frontend-*`, `backend-*`, `data-*` and `mobile-*` are **not** admissible here. A gate naming
> one is unresolvable and its axis silently never fires.

| Gated item | Gate | Fires when |
|---|---|---|
| C12 Tenancy Isolation | signal `multi-tenant` | key present in §11 |
| C8 Authorization | signal `auth` | key present in §11 |
| A25 AI / LLM Surface | signal `ai` | key present in §11 |
| A20 Accessibility | kind `browser` ∨ `mobile` | detector set intersects |
| A22 UX / Interaction | kind `browser` ∨ `mobile` | detector set intersects |
| A21 Internationalization | kind `browser` ∨ `mobile` ∨ signal `i18n` | either |
| A23 Release / Change Mgmt | surface `_deployment` | structural surface resolved |

**`any` is not a wildcard pass.** `detect-project-kind.sh` prints `any` when nothing resolves —
an undetectable repo. Per `_project-kind.md`, `any` means *do not strip*, so a kind-gated axis
under `any` **runs and is reported with its gate recorded as unresolved**. It is never silently
skipped, and never silently passed either.

---

## 6. What a cell is

```
cell  =  (concern | axis)  ×  surface
```

**Cells are the output granularity, not the dispatch granularity.** Dispatch is surface-major:
one agent per resolved surface carrying that surface's concern checklist, plus one global agent
for the axes with no single surface (A1 Architecture, A14 Modularity, A5 Testing,
A6 Maintainability, A19 Developer Experience, A13 Requirements). ~12 agents, the same order as
today's 8. See plan §4.

Every cell terminates in exactly one of three states — **reviewed** / **N/A with a reason string**
/ **live but unreviewed**. A cell may never be silently absent. See plan §3.

---

## 7. The source list — 30 + 7

Supplied 2026-08-30. **Recorded here because it existed nowhere in the repository**: the plan
reasoned about "the user's 30 + 7" across five sections and never reproduced it, so every
downstream count was unverifiable. This section is now the source of truth; §3 and §4 are
projections of it.

### 7.1 The 30

```
01  Architecture              11  API Design                21  Requirements / Business Fit
02  Security                  12  Domain Modeling           22  Modularity / Boundaries
03  Correctness               13  Concurrency               23  Dependency Management
04  Scalability               14  Distributed Systems       24  Configuration Management
05  Database                  15  Messaging / Events        25  Migration / Schema Evolution
06  Performance               16  Data Integrity            26  Backup / Disaster Recovery
07  Reliability               17  Resilience                27  External Dependencies
08  Testing                   18  Deployment / Infra        28  Caching / Invalidation
09  Observability             19  Capacity Planning         29  Cost Efficiency
10  Maintainability           20  Operational Readiness     30  Developer Experience
```

### 7.2 The 7 cross-cutting

```
Security   Performance   Observability   Error Handling   Logging   Configuration   Compliance
```

### 7.3 Every item has exactly one home

| Home | Count | Source numbers |
|---|---|---|
| **Surface** (§2) | 6 | `05` `11` `15` `18` `27` `28` |
| **Concern** (§3) — also in the 30 | 4 | `02`→C1 `06`→C2 `09`→C3 `24`→C6 |
| **Concern** (§3) — cross-cutting only, no source number | 3 | Error Handling→C4, Logging→C5, Compliance→C7 |
| **Axis** (§4) | 20 | the remaining 20 numbers |

```
30 = 6 surfaces + 4 concerns + 20 axes          ✓ every number classified once
 7 = 4 that double-counted + 3 concern-only     ✓ every concern classified once
```

**Nothing lives in two dimensions**, which is the §1 rule and the Phase 0 acceptance. The four
double-counted items keep their source number for traceability but are scored **only** as a
concern roll-up — never additionally as an axis bucket.

Final model: **26 axes × 12 concerns × N surfaces**, N ≈ 8–14 per project.

---

## 8. Corrections this section forces on the plan

Recording these rather than silently diverging — `docs/plans/audit-review-matrix.md` is patched to
match, and the reasoning must survive so the numbers are not "fixed" back later.

| Plan says | Truth | Root cause |
|---|---|---|
| §2.2 *"Seven of the 30 are concerns"* | **Four** are | Error Handling, Logging and Compliance are on the cross-cutting list and were never in the 30. Subtracting 7 removed 3 items that did not exist. |
| §2.3 lists 19 axes | **20** | `17 Resilience` was dropped. It is on neither the surface list nor the cross-cutting list, so it is an axis. |
| §3.3 *"23 axes × 12 concerns"* | **26 axes × 12 concerns** | Consequence of the two rows above: `30 − 6 − 4 = 20`, `+6 added = 26`. The concern count of 12 was always right. |

The plan's structural insights — the three-dimension sort, surface-major dispatch, the N/A ledger —
are unaffected. Only the counts were wrong.

## 9. Acceptance

`scripts/validate-review-model.sh` asserts, mechanically:

1. every §2.1 surface name is a literal implemented key in `_registry.md`;
2. §2.1 is complete — no implemented key is missing from it (bidirectional);
3. every §2.2 structural name starts with `_` and is **not** a registry key;
4. every gate in §5 resolves to a registry key, a `_project-kind.md` value, or a §2.2 name;
5. no name appears in two dimensions;
6. every cross-file path cited here resolves on disk;
7. §7.1 is a complete `01`–`30` with no gap and no duplicate;
8. every source number is classified exactly once across §2 / §3 / §4 — the §7.3 identity
   `30 = 6 + 4 + 20` recomputed from the sections themselves, not read from the table;
9. all 7 of §7.2 appear in §3.1, and exactly 4 of them carry a source number.

Exit non-zero on any failure. Run it in CI beside the other `validate-*.sh`.
