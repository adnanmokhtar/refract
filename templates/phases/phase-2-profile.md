---
phase: 2
name: profile
applies-to-modes: [ENHANCE, REFRESH, REFINE]
inputs: [target-repo, mode]
outputs: [codebase-profile.md, detected-tracks, technical-signals, business-domain, deep-extraction (REFINE only)]
exit-criteria: profile written; tracks scored against templates/tracks/*/detect.md; uncertainty flags surfaced
sub-phases:
  - 2.0: top-level signals
  - 2.5: deep idiom extraction
  - 2.6: profile-informed coverage gap check (ENHANCE + REFRESH)
  - 2.7-2.12: deep extraction (REFINE only — domain entities, architecture, e2e flows, conventions, perf, failures)
note: Phase 2.6 prose appears textually before Phase 2 body in this file because 2.6 is conceptually a GATE on Phase 2's output (coverage-gap check). Read order: 2.0 → 2.5 → 2.6 (gate) → 2.7-2.12 (REFINE-only deep extraction). The textual ordering is intentional; do not "fix" it without also rewiring downstream consumers.
---

**Stage-gate concession (extraction artifacts ≠ deliverables)**: The four deep-extraction files this phase can produce (`_extracted-codebase.md`, `_extracted-idioms.md`, `_extracted-business.md`, `_refine-extract.md`) are **CONTEXT for later phases, not user-facing deliverables**. They exist to make Phase 4 generation cheaper and more project-specific. With `--lightweight`, only `codebase-profile.md` is required; the other three are skipped, and Phase 4 reads source directly when it needs deeper detail.

### Provenance discipline (every extraction artifact — added 2026-06-07)

Every factual claim written to `_extracted-codebase.md`, `_extracted-idioms.md`, `_extracted-business.md`, or `_refine-extract.md` carries exactly one provenance class:

| Marker | Meaning | Example |
|---|---|---|
| `[found: <path:line>]` | Read directly from source; the citation resolves at the current commit. An existing `<path:line>` citation on the claim row counts as this marker — no double-annotation. | `Errors route through handleApiError [found: src/utils/errors.ts:12]` |
| `[inferred: <basis>]` | Derived from structure / naming / co-occurrence — NOT read from an authoritative source. The basis is mandatory: name what it was derived from. | `Hexagonal architecture [inferred: core/ + adapters/ folder split; import graph not walked]` |
| `[unconfirmed]` | Load-bearing claim that cannot be established from the repo — needs a human answer. | `Payment retry policy [unconfirmed — no retry code or doc found; ask team]` |

**Rules**:
- An uncited, unmarked factual claim is invalid — same mechanical-halt family as the hand-wave grep (`extract-codebase-overview § Mechanical halt`). Regenerate with a citation OR downgrade to `[inferred: <basis>]` / `[unconfirmed]`. Honest downgrade beats confident fabrication.
- **Downstream consumer contract**: Phase 4 generators anchor rules ONLY to `[found:]` claims. `[inferred:]` claims may inform topic selection, but any generated artifact that relies on one must first re-verify it against source (promoting it to `[found:]`) or carry the marker forward into the generated text. Oracle readers in the migration / align packs (mapping-doc authors, Reuse-Before-Create checks, `check_v2_structure` fingerprint sources) treat `[inferred:]` rows as needs-source-check before use, and NEVER close an audit finding against an `[unconfirmed]` claim.
- `[unconfirmed]` items are the question queue for the team — they surface in `/setup-project-health` (check 9) and in the Phase 3 plan's open-questions block. They are visible debt, not silent gaps.
- **Sampling downgrade (a citation proves a file, never a population)**: when a claim **generalizes** across a population — "all entities carry a tenant column", "file naming is kebab-case", "errors route through the shared handler" — and its source section is marked `[SAMPLED: <seen>/<present> <unit>]`, it may NOT be written `[found:]`, even though its citation resolves. Write it `[inferred: <basis>; sampled <seen>/<present> <unit>]`. This is the only provenance error a resolving citation actively hides: the sampled file really does do X, so a path check passes, while "and so do the other 402" was never read. Claims scoped to the cited file itself (`BaseRepository is defined at <path:line>`) are unaffected — they claim nothing about a population and stay `[found:]`.
  The behaviour change needs no new machinery: the downstream consumer contract below already routes `[inferred:]` claims away from anchoring, so a convention generalized from 10 of 412 files automatically stops being anchorable and must be re-verified against source before it can become a rule. That is the entire fix.
  **No fourth provenance class.** Do not introduce `[sampled:]`. Every consumer contract in this repo — the rule below, the migration / align oracle readers, `/setup-project-health` check 9 which explicitly counts both spellings — is written against exactly three classes. Sampling is a *qualifier on the basis*, carried inside `[inferred: …]`.
- Section-level flags (`[EXTRACTION-WEAK: ...]`, `<NOT-DETECTED: ...>`, `[SAMPLED: <seen>/<present> <unit>]`) are unchanged in kind — they operate at section granularity; provenance markers operate at claim granularity. A `[NOT-DETECTED]` section needs no per-claim markers. `[EXTRACTION-WEAK]` and `[SAMPLED]` are deliberately NOT the same signal and must not collapse into one: `[EXTRACTION-WEAK]` means **no signal** for a topic and routes the track to COPY mode (`phase-4.0-preflight.md` § 4.2); `[SAMPLED]` means **partial signal** — the claim is usable, it just may not generalize — and changes confidence, never generator mode. If they ever produce the same behaviour, one of them is redundant and should be deleted rather than kept.
- `_extracted-business.md` keeps its pre-existing facet vocabulary — `[CONFIDENT]` / `[INFERRED]` / `[UNKNOWN]` map 1:1 onto `[found:]` / `[inferred:]` / `[unconfirmed]` (see `extract-business-context.md § Premise`). One semantic, two spellings; consumers count both.

**Why**: the extraction artifacts are the oracle every downstream generator and migration audit trusts. An inferred claim presented as found is the Trusted Summary anti-pattern applied to our own pipeline — a wrong idiom in the oracle propagates into wrong mapping docs and wrong audits, with no way to tell afterwards which oracle lines were guesses.

### Phase 2.6 — Profile-informed coverage gap check (ENHANCE + REFRESH modes)

**Critical for ENHANCE-extend** — prevents the failure mode where the command sees `.claude/` exists, runs delta-against-prompt, finds "no new prompt = no work," and concludes "idempotent" while the existing setup is missing 50+ files.

**For REFRESH** — runs after Phase 0 extract AND Phase 2 + 2.5 deep profile. The coverage gap is computed against the BACKUP state (what existed before regen) so the report can categorize each gap as: (a) missing in old AND new — pure new gap to fill; (b) missing in old, present in new — pre-existing gap closed by regen; (c) present in old, missing in new — REGRESSION (must investigate before applying). Category (c) is a halt condition; the brain's regen plan must explain why an existing artifact was dropped and either re-add it or get explicit user approval.

**Why this runs AFTER Phase 2**: gap detection only makes sense once we know which tracks are LOAD-BEARING for this codebase. A "you're missing 2 backend agents" verdict is meaningless if the codebase isn't a backend service; a "you're missing tenant-leak rules" verdict is wrong if the codebase isn't multi-tenant. Profile first, derive what the project ACTUALLY needs, then check the floor.

For ENHANCE-retrofit / ENHANCE-extend / REFRESH, run this check after Phase 2.5:

#### 2.6.a Determine load-bearing tracks (from Phase 2 profile, not from a static checklist)

Phase 2 already produced `.claude/_extracted-codebase.md` + `.claude/codebase-profile.md` — including detected stack, signals (multi-tenant / webhook / payment / AI / search / queue / realtime / mobile / etc.), and business domain. From those, mark each track:

- **LOAD-BEARING** — the track's signal matched in the profile (e.g., `backend` is load-bearing because Node/Python/Go/Java/PHP/Ruby manifests detected; `database` because a DB driver is in deps; `multi-tenant` because tenant column or context is detected; `payment` because a payment SDK is in deps).
- **ALWAYS-ON** — `security`, `code-quality`, `documentation`, `learning` apply regardless. These are the four tracks every project gets, full stop.
- **NOT-APPLICABLE** — track signal absent (e.g., `frontend` for an API-only repo; `mobile` for a backend; `distributed-systems` for a single-process app). Marked `n/a` in the gap report — NOT counted as a gap.

This step replaces the older "preview Phase 2" sub-step (no longer needed — Phase 2 has already run by this point and produced the full profile).

#### 2.6.b Compare actual against minimums (load-bearing tracks only)

For each LOAD-BEARING / ALWAYS-ON track, compare existing artifact counts against the appropriate minimum:

- **Standard mode (default)**: use the **minimum-artifacts table** (defined in Phase 4.0). Floors are aspirational quality gates for tracks that ARE generated, not enforcement that every project gets every track.
- **Minimal mode (`--minimal` set)**: use the count from the track's `_essentials.md` manifest (`essentials.agents` length, etc.). Lower bar — only shortfall against the focused subset triggers retry.

NOT-APPLICABLE tracks are skipped entirely — no gap, no shortfall, no retry. They never appear in the report's gap list (they appear in a separate `not-applicable` section so the user can see what was filtered and why).

The check is otherwise identical:

> **Note**: the `<preview-selected-tracks>` and `<from minimums table>` placeholders below resolve at runtime — `preview-selected-tracks` = the list produced by 2.6.a (LOAD-BEARING ∪ ALWAYS-ON track names), and `from minimums table` = the per-track floor lookup defined in Phase 4.0. TODO: define a stable preview/report shape in `templates/schemas/coverage-gap.schema.json` so 2.6.b inputs and 2.6.c outputs are validated end-to-end (file does not yet exist — do not fabricate).

```bash
for track in <preview-selected-tracks>; do
  expected_agents=<from minimums table>
  actual_agents=$(ls .claude/agents/*.md 2>/dev/null | wc -l)
  if [ "$actual_agents" -lt "$expected_agents" ]; then
    GAP="$GAP\n  Track $track: agents $actual_agents/$expected_agents (need $((expected_agents - actual_agents)) more)"
  fi
  # ... repeat for commands, skills, rules, ai-patterns
done

# Plus required baseline check
if [ ! -f ".claude/hooks/post-edit-check.sh" ]; then GAP="$GAP\n  Baseline: missing post-edit-check.sh"; fi
if [ ! -f ".claude/hooks/pre-edit-guard.sh" ]; then GAP="$GAP\n  Baseline: missing pre-edit-guard.sh"; fi
# ... all 7 hooks

if [ ! -f "ai/_session-digest.md" ]; then GAP="$GAP\n  Baseline: missing _session-digest.md"; fi
if [ ! -f "ai/_decision-index.md" ]; then GAP="$GAP\n  Baseline: missing _decision-index.md"; fi
if [ ! -f "ai/_convention-cheatsheet.md" ]; then GAP="$GAP\n  Baseline: missing _convention-cheatsheet.md"; fi
```

#### 2.6.c Report the coverage gap (with explicit LOAD-BEARING / NOT-APPLICABLE breakdown)

Output the gap inventory at the START of the plan, BEFORE the prompt-vs-state delta. The report MUST explicitly show which tracks were filtered out as not-applicable so the user can verify the profile-based filter — it's the difference between "you're missing 50 files" (force-fit) and "for the 8 tracks this codebase needs, you're at the floor in 2 of them" (profile-informed):

```
COVERAGE GAP CHECK (ENHANCE-extend, profile-informed):
  Status: <COMPLETE | INCOMPLETE — N gaps detected in load-bearing tracks>

  Load-bearing tracks (from Phase 2 profile):
    backend          agents: 1/3 ❌  commands: 1/8 ❌  skills: 0/4 ❌  rules: 1/1 ✓  patterns: 5/5 ✓
    database         agents: 2/4 ❌  commands: 1/4 ❌  skills: 1/2 ❌  rules: 1/1 ✓  patterns: 3/3 ✓
    (other detected tracks ...)

  Always-on tracks:
    code-quality     agents: 1/5 ❌  commands: 0/4 ❌  skills: 0/1 ❌  rules: 0/1 ❌  patterns: 0/0 ✓
    security         agents: 1/2 ❌  commands: 0/1 ❌  skills: 0/2 ❌  rules: 0/1 ❌  patterns: 0/2 ❌
    documentation    ...
    learning         agents: 0/3 ❌  commands: 2/4 ❌  skills: 0/1 ❌  rules: 0   ✓  patterns: 0   ✓

  Not-applicable tracks (filtered from gap check — no signal in profile):
    frontend         n/a  (no UI framework / asset pipeline detected)
    mobile           n/a  (no React Native / Flutter / iOS / Android signals)
    distributed-systems  n/a  (single-process app — no service-mesh / RPC / queue signals)
    ui-ux            n/a  (no UI framework detected)

  Baseline gaps:
    Hooks: 2/7 (missing: post-edit-check, pre-edit-guard, guard-destructive, update-session-log, post-merge-learn)
    ai/_session-digest.md: missing
    ai/_decision-index.md: missing
    ai/_convention-cheatsheet.md: missing

  Total files to add: <N> (only counting load-bearing + always-on shortfalls + baseline)
```

#### 2.6.d Decision logic — DO NOT CONCLUDE "idempotent" if coverage gaps exist (in load-bearing tracks)

The idempotent decision requires BOTH (1) no prompt delta AND (2) no coverage gap in load-bearing/always-on tracks (Phase 2.6.c sums to zero). If either fails, the command HAS work. See Critical Execution Rule 1 (top of file) for the wrong/right example.

Gaps in NOT-APPLICABLE tracks are ignored by design — that's the whole point of profile-informed gap detection. A single-tenant API repo isn't "missing" multi-tenant rules; those rules don't apply.

When coverage gaps exist in load-bearing/always-on tracks, ENHANCE proceeds to Phase 3 (prompt delta + plan), then Phase 4 (apply). Even if prompt delta is empty, there's a contract violation to fix.

### Phase 2 — Profile codebase (deep extraction, not just detection)

Goal: produce **two artifacts** that together drive every downstream decision:

1. `.claude/_extracted-codebase.md` — the deep technical full-picture (architecture, modules, base classes, data model, API surface, conventions, signals, tests, anti-patterns, recent activity).
2. `.claude/_extracted-business.md` — the WHY (mission, personas, business model, KPIs, constraints, anti-goals, competitive context).

A condensed projection of both feeds the legacy `.claude/codebase-profile.md` (kept for backward-compat — Phase 3 plan reads it).

**Critical mindset shift (since v3.0)**: Phase 2 is no longer a lightweight detection pass. It is the **substrate-creation phase**. Phase 4 generators do not invent project-specific content; they author from these two extracted files. If Phase 2 is shallow, Phase 4 reverts to generic templates and the entire generated setup is generic.

#### 2.0 Orchestrator invocation (the single entry point)

Invoke the **`extract-codebase-overview`** skill (lives in `~/.claude/templates/packs/learning/skills/extract-codebase-overview/SKILL.md`). The skill orchestrates the entire deep extraction:
- Step 1-2: stack + repo shape (deterministic) — the shape and the member list are **handed in** by Phase 1, never re-derived from workspace manifests here. See § 2.0.a.
- Step 3: architecture + layering (import-graph sample).
- Step 4: module enumeration.
- Step 5: idiom extraction — detects project's primary idiom pattern (class-inheritance / composables / shared-wrappers / shared-services / type-system) and dispatches the matching extractor skill. Always writes `_extracted-idioms.md` even for projects with no load-bearing idioms (minimal-strategy fallback). Up to 6 concurrent extractor subagents. See § Phase 2.5 below for full strategy logic.
- Step 6: data model.
- Step 7: API surface.
- Step 8: convention auto-detection.
- Step 9: cross-cutting concerns + signals (replaces the legacy "Technical signals detected" line in old profile).
- Step 10: tests + coverage shape.
- Step 11: anti-patterns observed (acknowledge, don't fix).
- Step 12: recent activity (last 30 days).
- Step 13: **delegates to `extract-business-context` skill** for the WHY → writes `.claude/_extracted-business.md`. (This is Phase 2.y in old numbering — now invoked as Step 13.)
- Step 14-15: write + verify.

Outputs:
- `.claude/_extracted-codebase.md` (the technical full-picture).
- `.claude/_extracted-idioms.md` (deep extraction — strategy-adaptive: per-base-class for OOP projects, per-composable for Vue 3 / React functional, per-shared-wrapper for design-system-heavy projects, etc. ALWAYS written; minimal-strategy fallback if no load-bearing idioms detected).
- `.claude/_extracted-business.md` (the WHY).

**`.claude/codebase-profile.md`** is a derived view (kept for backward-compat consumers): condensed, human-readable, contains the same 14 fields the old profile had — but each field cites its source section in `_extracted-codebase.md`.

#### 2.0.a Shape + member handoff (the input the per-member split hangs on)

**The orchestrator is handed the shape; it never re-derives it.** Phase 1 already decided `repo_shape` and listed the members (`phase-1-detect-mode.md § Decide shape`), and its table fires on signals a manifest scan does not reproduce — in particular the two rows where no member-declaring manifest exists anywhere: sub-manifest dirs inside one git repo (**monorepo**), and sub-manifest dirs that are separate checkouts, or a plain server-directory-beside-client-directory pair, under one parent (**workspace**). A second, manifest-only shape detection inside the extraction re-answers a settled question — and answers it `single` for exactly the shape that has no manifest to find, which is the most common multi-member shape on disk. That silent `single` is what makes every per-member contract below unreachable: not refused, not flagged, just never entered.

Pass, verbatim from the Phase 1 output, alongside `project_root`:

```
repo_shape:   <single | monorepo | workspace>
shape_signal: "<the Phase 1 row that fired>"
members:                        # never empty — `single` carries exactly one entry, root `.`
  - name: <member-a>
    root: <path/to/member-a>    # `.` for repo_shape: single
    manifest: <path/to/member-a/<manifest-file>>
```

**The receiver, named.** All three are declared inputs of the orchestrator skill — `extract-codebase-overview/SKILL.md § Inputs` marks `repo_shape`, `shape_signal` and `members` **required** — and its Step 2 consumes them: the `## Repository shape` entry set IS `members` (same order, one entry each, no additions and no drops), a manifest scan is explicitly barred from re-answering the shape question there, and an absent or empty `members` halts with `[SHAPE-INPUT-MISSING]` instead of falling back to a `single` default. Step 2.5 buckets the census on those entries and halts when it has fewer buckets than members. A handed-in value nothing branches on is decoration; this one is checkable in the skill file, and Steps 3, 4, 6, 7, 8 and 12 each run per member over that member's bucket.

Three obligations follow, each checkable against the written artifact:

1. **`## Repository shape` carries one entry per handed-in member** — nested package dirs and plain sibling directories alike, whether or not a workspace manifest names them. Fewer entries than `members` is a dropped member, not a tidier list: a member with no entry gets no census bucket, so it gets no walk, no conventions row, and no rules.
2. **The Step 2.5 per-package census buckets on those entries, and the buckets are the split key — not a line in the header.** Each member's `present` is the population its own capped steps sample from, and the denominator its `[SAMPLED: <seen>/<present> <unit>]` is quoted against. One aggregate census over a two-member tree cannot show that one member was walked and the other was not — which is the hiding place the per-package split exists to close.
3. **Every capped or sampled step runs once per member, over that member's population** — architecture layers, modules, idioms, data model, API surface, conventions. A step that walks the union and reports one winner produces the blended value § 17 forbids, and produces it with a citation that resolves, which is what lets it survive review.

**Halt condition**: `members` holds ≥ 2 entries while `_extracted-codebase.md` shows one `## Repository shape` entry or one census bucket. That is a member-blind extraction, and every downstream per-member field would then be filled from a repo-wide sample. Re-run Steps 2 + 2.5 with the handed-in member list before writing the substrate — the skill's Step 2 takes that list as an input rather than re-detecting it, so the re-run converges instead of reproducing the same `single`. Nothing downstream can recover a split the substrate never made.

**Mode behavior**:

**In CREATE mode**: orchestrator runs Step 1-2 only (stack from prompt + manifest if any) + asks the consolidated business-context question. Steps 3-12 produce skeleton sections marked `_TBD — populate as code is written_`. Phase 6 `/refresh-knowledge` re-runs the full extraction once code exists.

**In ENHANCE mode (retrofit + extend)**: orchestrator runs ALL 15 steps. Heavy walks (Step 4 modules, Step 5 base classes, Step 7 API surface) delegate to Explore subagents in parallel.

**In REFRESH mode**: orchestrator runs ALL 15 steps, AND merges with `.claude/_refresh-extract.md` (scaffolded by `refresh-extract-checklist.sh`, filled by Phase 0.2). Merge rules:
- **Codebase wins** on: stack, base classes, paths, naming, aliases, testing setup, data access, error handling, observability, auth, i18n, anti-patterns. (These are observable from code; if extract disagrees, extract is stale.)
- **Extract wins** on: business domain, project intent, custom glossary terms, validated corrections, ADR-recorded decisions, custom rules with project-idiom WHY blocks. (These are decisions/answers the user gave; codebase doesn't encode them.)
- **Both contribute** to: technical-signals detection (extract may say "we treat this as multi-tenant" even if not 100% obvious from code), conventions (codebase scan + extract's prior conventions both feed `ai/conventions.md`).
- **Conflict logging**: any extract item that contradicts codebase MUST be logged in `.claude/codebase-profile.md` § "Stale extract items" with a one-line explanation. Phase 5 audit confirms each conflict was either dropped (codebase won) or resolved (user re-confirmed via question).

Profile content (written to `.claude/codebase-profile.md`):

> **Heading contract (deterministic consumer — do not paraphrase).** `scripts/apply-anchors.sh`
> parses this file for exactly five headings and builds the round-one `## Project-specific` block of
> **every** pack-derived artifact out of them: `Architecture`, `Naming`, `Testing`, `Data access`,
> `Error handling`. Write them as H2 headings, either `## Naming` or `## 3. Naming` — the parser
> accepts both, and the canonical shape in `templates/appendices.md § Appendix D` is the unnumbered
> one. A heading the parser cannot find renders as `<not declared in codebase-profile.md>` in every
> artifact in the repo, and if none of the five resolve the script exits 3 rather than shipping an
> anchor block whose every line is a placeholder. The numbering below is prose structure for the
> reader; the five heading SPELLINGS are a machine contract, in the same way §11's
> `technical_signals:` array is.

**Before filling any field below, read § 17 (repo shape + members) — it decides how many answers each field has.** When `repo_shape` is `monorepo` or `workspace`, fields **1–10 and 15 are answered ONCE PER MEMBER**, and each answer is tagged with the member it came from. Fields 11–14 and 16 stay repo-wide (union across members for 11; whole-tree for 13–14; 16 spans members by construction).

> **Never average two members into one value.** This is the single most damaging failure this phase can produce. A repo with a server package and a client package has two file-naming conventions, two test layouts, two error hierarchies — sampling across both and reporting the winner yields a value that is wrong for *both* packages, carried downstream with the confidence of a measured one. It then lands in the `## Project-specific` block of every adapted rule, and every agent that reads it "fixes" correct code to match a convention that exists nowhere in the repo. If two members disagree on a field, that IS the finding: record both, tagged. Record a single value only when you checked every member and they genuinely agree — and say that you checked.

**How the split is performed — one field, one member, one census bucket.** The member list comes from § 17; the *evidence* for each member's answer comes from that member's own bucket in the Step 2.5 per-package census (§ 2.0.a). Tag every per-member answer with the bucket it was drawn from: `<value> [member: <name>; <files_cited>/<present> files]`. Two consequences, and they are the reason the census is bucketed at all rather than totalled:

- **A member whose bucket shows `present > 0` and `files_cited = 0` was never walked.** Record `<TBD: unwalked — <present> source files, 0 cited>` for its fields 1–10 + 15. Do NOT let it inherit a sibling's answer: an unwalked member that quietly reads as agreeing with the one beside it is indistinguishable from a checked one, and that is precisely how a blended convention ships with the confidence of a measured one.
- **"All members agree" is a claim about every bucket.** It may be written only when every member has `files_cited > 0`. Otherwise the honest shape is per-member values with the unwalked members marked — which also tells the next run where to look first.

1. **Architecture** — actual layer names, dependency direction (not doc-claimed).
2. **Base classes / inheritance patterns** — every base class with ≥3 extenders found by Phase 2.5 extraction. Class names + paths + extender counts come straight from this codebase; if the project is functional / module-style without inheritance bases, this section is empty (and that's a valid project shape — don't manufacture base classes).
3. **Naming** — kebab / PascalCase / snake + suffix conventions.
4. **Aliases** — from tsconfig / pyproject / manifest.
5. **Testing** — framework, file naming, folder layout, mock style.
6. **Data access** — base repo path + tenant/soft-delete auto-filter + criteria system.
7. **Error handling** — root domain error class, HTTP mapping layer.
8. **Observability** — logger lib, metric lib, tracer, correlation propagation.
9. **Auth** — JWT/session/OAuth + guard / middleware names.
10. **i18n** — library, locales, key convention.
11. **Technical signals detected** — multi-tenant, webhook, payment, AI, real-time, etc.

    **CRITICAL — emit canonical registry keys, not prose labels.** Phase 4.4 consumes this section by running `cp templates/domains/<signal>/…` with `<signal>` used *literally*. A free-text label like `media-transcoding`, `queue/async-jobs`, or `token-protected delivery` resolves to **no folder** and the domain is silently skipped. Therefore §11 MUST record each detected signal as its **exact key from `~/.claude/templates/domains/_registry.md`**, machine-readable on its own line:

    ```
    technical_signals: [multi-tenant, media-processing, streaming-delivery, background-jobs, real-time, webhook, file-upload, caching, auth]
    ```

    A human-readable prose line (with evidence `<path:line>`) MAY follow, but the `technical_signals:` array is the contract Phase 4.4 reads. Normalize every observation to its registry key — common aliases:

    | If you observe… | Canonical key |
    |---|---|
    | transcode / thumbnail / ffmpeg / sharp / image-resize / HLS *packaging* | `media-processing` |
    | HLS / DASH / CMAF / `.m3u8` / `.mpd` / manifest / segment delivery / byte-range / adaptive bitrate / `EXT-X-KEY` / DRM / encrypted-segment / video *playback* | `streaming-delivery` |
    | queue / job / worker / BullMQ / Sidekiq / Celery / Temporal / Agenda / cron | `background-jobs` |
    | websocket / SSE / Socket.io / WebRTC / pub-sub / presence | `real-time` |
    | tenant / `tenant_id` / `app_id` scoping / row-level-security | `multi-tenant` |
    | Redis / Memcached / `Cache-Control` / CDN cache | `caching` |
    | JWT / session / OAuth / login / token auth / guards | `auth` |
    | upload / multipart / presigned / `express-fileupload` | `file-upload` |
    | callback URL / `*_url` POST-on-event | `webhook` |

    A key that has no folder under `templates/domains/` is NOT a valid signal — drop it or map it to the nearest real key. If a genuinely-new concern has no registry key, note it as `[SIGNAL-UNMAPPED: <desc>]` so the gap is visible (it will not be auto-applied).
12. **Business domain detected** — see §2.x below. THIS IS DIFFERENT FROM technical signals — it's "what business is this product running" (ecommerce / lms / fintech / etc.). Without this, the setup gives generic backend scaffolding instead of domain-aware tooling.
13. **Anti-patterns** — console.log / any / swallowed errors counts (acknowledge; don't fix).
14. **Phase + status** — declared phase + code-vs-doc consistency.
15. **Concurrency primitives** — what the project actually uses for parallel I/O and CPU offloading. Detected by grepping for: `Promise.all` / `Promise.allSettled` / `Bluebird.map` / `p-limit` / `pMap` / `asyncio.gather` / `asyncio.Semaphore` / `errgroup.WithContext` / `CompletableFuture.allOf` / `StructuredTaskScope` / `Parallel.ForEachAsync` / `Task.async_stream` / `pmap`. Record: (a) which primitive(s) appear (with sample file:line citations), (b) whether the project ships a bounded-concurrency helper (`runWithLimit` / `parallel` / `concurrentMap` / equivalent — fingerprint: a function taking `items, fn, { concurrency }`), (c) observed concurrency caps (search `concurrency:`, `Semaphore(N)`, `g.SetLimit(N)`, `MaxDegreeOfParallelism`, `pLimit(N)`), (d) DB pool size from config (`pool.max`, `DATABASE_POOL_SIZE`, etc.), (e) cancellation primitive (`AbortController` / `context.Context` / `CancellationToken`), (f) whether sequential-await-in-loop appears in any hot path (count occurrences from `rg 'for \(const \w+ of \w+\)\s*\{[^}]*await' --multiline`). Phase 4.6 anchors `.claude/rules/concurrency-discipline.md` + `ai/patterns/parallel-io.md` to whichever primitive is dominant; if multiple primitives coexist, report as `[CONCURRENCY-DRIFT: <primitive-A> at <count> sites, <primitive-B> at <count> sites]` so the user can decide which is canonical. Skipped for synchronous-only stacks (Ruby without Async, sync-only Python, single-threaded scripts).
16. **Migration layout** — does the codebase show V1+V2 cohabitation? Detected by: (a) parallel directory pairs at the same depth where one shows version suffix or "legacy"/"new" semantics (`v1/`+`v2/`, `legacy/`+`new/`, `<name>/`+`<name>_v2/`, `<name>/`+`<name>-next/`), (b) version-suffixed sibling files (`*_v1.<ext>` paired with `*_v2.<ext>`, `*Old.<ext>` + `*New.<ext>`), (c) workspace packages with `-v2` / `-next` / `-new` suffix, (d) URL/route version prefixes hosting different code paths (`/v1/...` and `/v2/...` mapped to disjoint controller trees), (e) README sections explicitly mentioning "V1 → V2" / "legacy migration" / "rewrite", (f) presence of `ai/migration/ledger.md` or `ai/migration/contracts/`. Record: V1 root path, V2 root path, naming convention used (suffix vs subfolder vs separate workspace), migration ledger path if present, feature inventory (per-route or per-module list of V1 functions/classes/endpoints — this becomes the bootstrap input for the ledger), README evidence quotes if any, cutover mechanism if visible (feature flag library, env var, router rule). If any signal fires → set trigger `migration_layout_detected: true`; the `migration` pack auto-loads in Phase 4. If `ai/migration/ledger.md` exists → set `migration_ledger_present: true` so `port-feature` + `migration-status` know to read rather than bootstrap. If detection is ambiguous (a single `_v2`-suffixed file with no pair, or a single mention of "v2" in README) → flag as `[MIGRATION-WEAK]` and ask the user once: "Detected possible migration layout — confirm? (yes / no / explicit V1 + V2 paths)". Skipped when the codebase shows no version-suffixed paths AND no migration ledger AND no README mention.

17. **Repo shape + members + per-track roots** — carried forward from Phase 1 and completed here. Phase 1 decided `repo_shape` and listed the member directories; Phase 2 is where each member gets a detected stack, a source root, and its own load-bearing track set. **This field is the contract three later phases read**: Phase 3 prints it as `SHAPE:`, Phase 4.0 gates sub-project recursion on `repo_shape: workspace`, and Phase 4.2 reads `is_multi_track` + `track_roots` to path-scope each track's rules. Absent or unset, all three fall back to the single-package path. Emit it machine-readable, on its own lines:

    ```
    repo_shape: monorepo            # single | monorepo | workspace — from Phase 1, never re-decided here
    shape_signal: "2 sub-manifest dirs in one git repo, no member-declaring manifest"
    members:
      - name: <member-a>
        root: <path/to/member-a>    # dir whose manifest was found; `.` for repo_shape: single
        manifest: <path/to/member-a/<manifest-file>>
        stack: <language + framework, as detected in THIS dir>
        tracks: [<load-bearing track ids for THIS member>]
        src_glob: <path/to/member-a>/**
      - name: <member-b>
        root: <path/to/member-b>
        manifest: <path/to/member-b/<manifest-file>>
        stack: <language + framework, as detected in THIS dir>
        tracks: [<load-bearing track ids for THIS member>]
        src_glob: <path/to/member-b>/**
    is_multi_track: true            # see derivation below
    track_roots:                    # union over members: track id -> comma-separated globs
      <track-id>: "<glob>[,<glob>…]"
    ```

    **Deriving `is_multi_track`** — it is `true` when the count of DISTINCT load-bearing *stack* tracks across all members is ≥ 2. Stack tracks are the ones 2.6.a marks LOAD-BEARING from a stack signal; the four ALWAYS-ON tracks (`security`, `code-quality`, `documentation`, `learning`) never count toward it, because every project has them and scoping them would scope everything. Note this is **independent of `repo_shape`**: a `single`-shape repo with a server directory and a client directory under one manifest is multi-track and needs the same rule scoping. `repo_shape: single` therefore still emits `members` with exactly one entry (`root: .`) — the field is never empty.

    **Deriving `track_roots`** — for each load-bearing stack track, the glob(s) covering the source that track's rules should apply to. For `monorepo` / `workspace`, that is the `src_glob` of every member whose `tracks` include it, joined by commas. For `single`, detect the track's source root inside the one member (the directory holding that track's framework entry point, config, or the bulk of its source files) rather than defaulting to the repo root — scoping a track to `**` scopes it to nothing.

    **When detection is thin**: a member whose stack cannot be determined (no recognizable framework, manifest with no dependencies) is recorded with `stack: <TBD: undetermined>` and `tracks: []` rather than dropped — a member missing from this list is a member that gets no rules, no adapters, and no conventions row, which is a worse failure than an undetermined one. If NO member's stack resolves, flag `[SHAPE-UNRESOLVED]`; do not silently collapse to `repo_shape: single`.

#### 2.x Business-domain detection (separate from technical signals)

Stack tells us "what tech is in use." Domain tells us "what business is the product actually running." Each business domain has its own canonical entities, flows, compliance regime, stakeholder vocabulary, and anti-patterns. A `<TBD: backend-framework>` + Postgres ecommerce store and a Django + Postgres LMS share zero domain knowledge — stack similarity does not imply domain similarity.

**Catalog**: `~/.claude/templates/business-domains/` — the authoritative list of supported business domains lives in `~/.claude/templates/business-domains/_registry.md` (every entry there has `name`, `summary`, `regulatory_overlay_hints`). The brain MUST resolve the catalog from `_registry.md` rather than from any hard-coded list in this command, because new domains can be added without spec edits. Each domain folder has `glossary.md` + `core-flows.md` + `feature-checklist.md` + `compliance.md` + `stakeholders.md` + `anti-patterns.md` + `_version.json`.

**Detection signals** (each domain's `glossary.md` lists its own; the union is searched in Phase 2):

| Source | Signal example |
|---|---|
| Entity / model names | `Product` + `Cart` + `Order` → ecommerce; `Course` + `Enrollment` + `Lesson` → lms; `Patient` + `Encounter` + `Prescription` → healthcare; `Policy` + `Claim` + `Premium` → insurance |
| Folder / route names | `cart/` + `checkout/` + `/checkout` → ecommerce; `courses/` + `lessons/` → lms; `policies/` + `claims/` → insurance |
| Dependencies | `stripe` + `medusajs` → ecommerce; `learnpress` / `tutor` → lms; `acme-fhir` / `hl7` → healthcare |
| README / repo name | cheap last-resort hint; never primary signal |

**Decision**:
- 3+ signals match a single domain → confident classification, proceed.
- 3+ signals AND multiple domains match (e.g., ecommerce + affiliate) → both apply (projects often union domains).
- Conflicting domains with no clear winner → ask ONE consolidated question:
  > "I see signals for [X] and [Y]. Treat as [combined] or [pick one]?"
- Greenfield CREATE with prompt → extract domain from prompt ("WhatsApp sales agent" → ecommerce + AI; "course platform" → lms; "doctor appointments" → booking + healthcare).
- No signal at all + no prompt clue → ask once: "What's the business domain? [list of 15 domains, or 'other']."

**Output of detection**: write `business_domain` (or `business_domains: [...]` for unions) into `.claude/codebase-profile.md`. This drives Phase 4's domain-content population.

#### 2.y Project intent + context capture

Stack tells us "what tech." Domain tells us "what kind of product." This step tells us **why this exists, for whom, and at what maturity** — without it, Claude generates technically-correct setup that misses the point.

Sources (priority order):
1. User's prompt (if provided to `/setup-project`).
2. `README.md` (parse for intro / mission / target users / one-liner).
3. `package.json` `description` + `keywords`.
4. `ai/status.md` if pre-existing.
5. Ask the user once, with sensible defaults from above.

Capture these facets into `.claude/codebase-profile.md` under `## Project intent`:

| Facet | Question | Used for |
|---|---|---|
| **Mission / one-liner** | "In one sentence, what does this product do?" | CLAUDE.md opener; AGENTS.md opener; ADR context |
| **Target users + personas** | "Who uses it? (e.g., Egyptian SMB merchants, US enterprise IT admins, gig drivers)" | UX rules, API design, error message tone, i18n priority |
| **Business model** | "How does it make money / serve mission? (subscription / per-tx / ad / freemium / open-source / internal-tooling)" | Drives billing, plan, observability, churn-tracking decisions |
| **Maturity stage** | "Where is this in lifecycle? (idea / prototype / MVP / paying customers / scale / mature / sunsetting)" | Phase 1 bias; what's overkill vs essential |
| **Success KPIs** | "How will you know this works? (top 1-3 metrics that move when this product wins)" | Drives observability + dashboard requirements |
| **Constraints** | "Hard limits — latency targets, cost ceilings, team size, hardware/infra restrictions, **regulatory / compliance regime** (which frameworks apply: none / GDPR / CCPA / HIPAA / PCI-DSS / SOC2 / ISO-27001 / NPHIES (Saudi healthcare) / SCFHS / MOH-SA / CBAHI / SAMA (Saudi finance) / regional / industry-specific — list ALL that apply, not just one)?" | Anti-pattern rules; what to NEVER do; **drives Phase 4.4b regulatory overlay** (writes project-specific `ai/business-compliance.md` overriding generic domain-pack defaults) |
| **Anti-goals** | "What is this product NOT trying to be?" | CLAUDE.md anti-patterns; scope-creep guard |
| **Competitive context** | "What's the closest existing alternative? Why this one?" | Differentiation patterns; what NOT to copy |

**Decision rules:**
- ENHANCE mode + intent already in `ai/status.md` / `ai/business-domain.md` → confirm + don't re-ask.
- ENHANCE mode + intent absent → ask once, consolidated (one message, all 8 facets in a block, with what we inferred from README/code as defaults).
- CREATE mode + prompt rich → extract from prompt; flag whatever's missing.
- CREATE mode + prompt sparse → ask. Don't assume.

**Output**: `.claude/codebase-profile.md` `## Project intent` section + Phase 4.7b populates the user-facing files.

Output format: structured markdown (see Appendix D).

### Phase 2.5 — Deep idiom extraction (the "full picture")

Generic pack templates produce generic output. To author project-specific patterns + agents + rules in Phase 4, the brain needs the project's **idioms** — not just its file paths and dependency list.

**Trigger**: ENHANCE / REFRESH / REFINE mode. ALWAYS runs (no longer gated on "≥1 base class with ≥3 extenders"). Phase 2.5 ALWAYS writes `_extracted-idioms.md` — the only question is which extraction strategy fits the project. CREATE mode skips (no extenders / composables / wrappers exist yet; idioms emerge during code phase).

**The fix (2026-05-02)**: prior logic only extracted from class-inheritance hierarchies. Vue 3 Composition API, React functional, Angular standalone, and other functional / composition-style projects have no class-inheritance — but they DO have load-bearing idioms (composables / hooks / shared wrappers / shared services / type primitives). The extractor now detects the project's primary idiom pattern and switches strategy. **`_extracted-idioms.md` is always written**, even if minimal.

#### Idiom-pattern detection

Phase 2.5 first scores the project across 5 idiom patterns:

| Pattern | Detection signal | Examples |
|---|---|---|
| **class-inheritance** | ≥1 base class with ≥3 extenders | Backend OOP frameworks (NestJS, Django class-views, Rails, ASP.NET) |
| **composables** | Functions matching `use<X>` pattern with ≥3 callers each | Vue 3 Composition API, React hooks |
| **shared-wrappers** | Components in shared/ folder with ≥3 import sites | UI component libraries, design-system wrappers |
| **shared-services** | Singleton services / utility modules with ≥3 import sites | API clients, event buses, formatters |
| **type-system** | Generic types / DTOs with ≥3 instantiation sites | TypeScript generic helpers, dataclasses with generics |

A project may match MULTIPLE patterns. The extractor runs ALL matched patterns; an idiom is "load-bearing" when it has ≥3 dependents regardless of pattern.

#### Extraction strategy per pattern

**ONE skill covers all five patterns**: `extract-base-class-idiom`, invoked per load-bearing unit with `unit_kind` set. The walk is identical for every kind — read the unit in full, count its dependents, sample 3-5 across the range, name the automatic behaviors and the escape hatches, cite the pitfalls from git history — because that shape is a property of "≥3 things depend on this", not of inheritance. The skill's § Inputs table gives the per-kind terminology (what a "dependent" is, how to find it, what "configuration surface" and "override hooks" mean).

This used to name three further skills — `extract-composable-idiom`, `extract-wrapper-idiom`, `extract-service-idiom` — and **none of them ever shipped**. `templates/packs/learning/skills/` contained exactly one extractor. The always-write fallback below fires only when NO pattern matched, so a Vue 3 or React-hooks app *matched* `composables` and then dispatched to a skill that did not exist: undefined behaviour, not a defined degrade, leaving `_extracted-idioms.md § Composables` / `§ Wrappers` empty while `templates/packs/ui-ux/_topics.md` and align's `reinvented-wrapper` detector read them as populated. Three thin new skills would have been the worse fix; the shape was always one skill's.

| Pattern | Dispatch | Threshold | Output section |
|---|---|---|---|
| **class-inheritance** | `extract-base-class-idiom` with `unit_kind: base-class` | ≥3 extenders | `## Base classes` |
| **composables** | `extract-base-class-idiom` with `unit_kind: composable` | ≥3 callers (e.g. `useCrud`, `useForm`, `useAuth`) | `## Composables / Hooks` |
| **shared-wrappers** | `extract-base-class-idiom` with `unit_kind: wrapper` | ≥3 usage sites (e.g. `AppButton`, `BaseDataTable`) | `## Wrappers` |
| **shared-services** | `extract-base-class-idiom` with `unit_kind: service` | ≥3 import sites | `## Shared services` |
| **type-system** | `extract-base-class-idiom` with `unit_kind: type-primitive` | ≥3 instantiation sites | `## Type primitives` |

Pass `unit_path` + `unit_kind` + `output_path = .claude/_extracted-idioms.md` per unit. A project matching several patterns runs the skill once per unit per pattern, up to the concurrency cap below. For `wrapper` units the skill is required to name the raw primitive being wrapped — that is precisely the field align's `reinvented-wrapper` detector reads, and a wrapper row without it is unusable downstream.

#### Always-write fallback

If NO patterns matched (greenfield project, single-file scripts, very small codebase) → still write `_extracted-idioms.md` with a minimal structure. Note the precondition: this fires only on **no match**, so it never covered the "matched a pattern, had no extractor" hole above — that hole is closed by the dispatch table, not by this fallback.

```yaml
# _extracted-idioms.md (minimal — no load-bearing patterns yet)
project_kind: <detected>
extraction_strategy: minimal
patterns_matched: []
idioms: []
note: "No load-bearing idioms detected (insufficient code volume OR functional-style without ≥3 dependents). Re-run /setup-project --refine after the codebase grows."
```

This ensures downstream consumers (`/align-scan`, `/migration-recheck`, etc.) ALWAYS find the file. No more silent skips.

#### Mechanism

Spawn each idiom extraction as an Explore subagent — they're independent. Cap at 6 concurrent.

#### Output schema

`.claude/_extracted-idioms.md` always includes:

```markdown
---
project_kind: <kind>
extraction_strategy: class-inheritance | composables | shared-wrappers | shared-services | type-system | minimal | mixed
patterns_matched: [list]
extracted_at: <iso>
approved_by:          # empty at generation — human reviewer stamps <name>@<iso> after reading (§ Oracle approval below)
approved_hash:        # body hash at approval time — /setup-project-health prints the paste-ready stamp command
---

# Project idioms — <project>

## Strategy
<brief explanation of which patterns were extracted and why>

## Wrappers (only if shared-wrappers pattern matched)
- <WrapperName> (<path>) — <one-line role> — <count> usage sites
- ...

## Composables / Hooks (only if composables pattern matched)
- <useName> (<path>) — <one-line role> — <count> callers
- ...

## Shared services (only if shared-services pattern matched)
- <serviceName> (<path>) — <one-line role> — <count> importers
- ...

## Base classes (only if class-inheritance pattern matched)
- <BaseClass> (<path>) — <count> extenders — <one-line role>
- ...

## Type primitives (only if type-system pattern matched)
- <TypeName> (<path>) — <count> instantiation sites — <one-line role>
- ...

## Conventions (always)
- Naming: <project's naming convention> [found: <path:line> | inferred: <basis>]
- Layering: <project's architectural layering> [found: <path:line> | inferred: <basis>]
- Error handling: <project's error-handler primitive> [found: <path:line>]
- ... (mirrors codebase-profile.md content)
```

**Provenance in this schema**: idiom rows (`Wrappers` / `Composables` / `Shared services` / `Base classes` / `Type primitives`) carry `(<path>)` + a dependent count by construction — that IS their `[found:]` provenance; no extra marker needed. The `## Conventions` section is where inference creeps in (naming/layering claims generalized from samples) — every row there carries an explicit marker per § Provenance discipline.

**Quality gate**: if extraction yields zero load-bearing idioms across ALL patterns AND `codebase-profile.md` shows the project has > 1000 LOC → flag as `[EXTRACTION-WEAK]` in the plan; consumers should still proceed (the file exists), but the agent surfaces "low-confidence idiom inventory; recommend manual review of `_extracted-idioms.md` before relying on it for `/align-scan`."

#### Oracle approval (human sign-off — added 2026-06-07)

`_extracted-idioms.md` + `_extracted-codebase.md` become the oracle for every downstream consumer the moment they're written — without this stamp, no human ever confirms them. The approval flow:

- Generation writes `approved_by:` / `approved_hash:` **empty**. Setup completes normally — approval is non-blocking.
- The user reads the file once and stamps it: set `approved_by: <name>@<iso>` and `approved_hash:` to the body hash (`grep -v '^approved_' .claude/_extracted-idioms.md | shasum -a 256 | cut -c1-12`). `/setup-project-health` prints this as a paste-ready command.
- Regeneration (REFRESH / REFINE) **preserves the two lines verbatim** but the body changes → hash mismatch → health reports "oracle changed since approval" until re-stamped. NEVER auto-restamp — the mismatch is the signal that a human needs to re-read.
- `/setup-project-health` check 9 reports: empty stamp → `warn` ("oracle never human-reviewed"); hash mismatch → `warn` ("oracle changed since approval by <name>@<date>"); `[unconfirmed]` count > 0 → `warn` with the list.
- Approval is **advisory** (`warn`, never `fail`) — solo projects can ignore it; teams get a visible "the oracle was reviewed by <who> at <when>" guarantee before audits build on it.

**Skip individual idiom (not the whole file) when**: idiom has <3 dependents (insufficient signal — not load-bearing) OR idiom is a thin wrapper (<50 lines AND no automatic behaviors AND no override hooks).

**Why this exists**: without it, Phase 4 has nothing project-specific to say. Pack templates carry generic prose; injection of file paths in Phase 4.6 helps but doesn't fix the core gap (the body still reads as generic). Phase 2.5 + Phase 4.2-AUTHOR together flip the model: **packs become topic checklists; the codebase becomes the source of content.** And — critical for Composition-API / functional projects — extraction now matches the project's actual idiom shape, not just OOP inheritance.

### Phase 2.7–2.12 — Lightweight gate + cost cap (shared across deep-extraction phases)

**Lightweight gate**: Phases 2.7–2.12 run ONLY when (a) mode = REFINE AND (b) `--lightweight` flag is NOT set. With `--lightweight`, Phase 2.5 caps at 3 base classes (sample, don't walk all) — this is a sample like any other and must be disclosed, not merely applied: the run records `[SAMPLED: 3/<bases with ≥3 extenders> bases]` on `## Base classes` and names `--lightweight` as the cap in `walk_scope` (`extract-codebase-overview § Step 2.5`). A shallow extraction that reads as a complete one is the failure this whole discipline exists to prevent, and `--lightweight` was previously the one cap no artifact recorded. Output: condensed `.claude/codebase-profile.md` only. Skip the three deep-extraction files (`_extracted-idioms.md`, `_extracted-business.md` deep portion, `_refine-extract.md`) — Phase 4.6/4.7 are also skipped per `phase-1-detect-mode.md`.



All six deep-extraction phases (2.7–2.12) AND Phase 4.6-DEEP AND Phase 4.8-DEEP fan out subagents — one per business-domain (2.7), one per surface (2.8), one per flow (2.9), one per convention sweep (2.10), one per hot-path candidate (2.11), one per recurring theme (2.12), one per shallow artifact (4.6-DEEP), one per (adapter × affected-artifact) tuple (4.8-DEEP). On a large codebase the total fan-out is unbounded by default.

The `--max-subagents=<N>` flag (default `8` in REFINE mode) caps the **total concurrent subagent count across all REFINE phases**. Within a phase, fan-out stops at the remaining budget; remaining work serializes (sequential subagent calls). Phase boundaries are sequential anyway (a phase's subagents must all complete before the next phase starts), so the cap is per-phase in practice. Without the flag, REFINE on a 100k+ LOC codebase can spawn 30+ concurrent subagents — manageable but not always desirable for cost-sensitive runs.

**When to lower the cap** (e.g. `--max-subagents=4`): cost-sensitive runs, very large codebases (>500k LOC) where each subagent reads a lot of code, or environments with API-rate-limit pressure. **When to raise it** (e.g. `--max-subagents=16`): time-sensitive runs on small codebases where the user wants fastest possible completion.

**The cap doesn't apply** to round-one phases — Phase 2 Step 5 (base-class idiom extraction) already has its own cap of 6 (independent of `--max-subagents`); Phase 4.2 per-track copies and Phase 4.8 per-adapter generation also have their own intrinsic caps. `--max-subagents` is a REFINE-only knob.

### Phase 2.7 — Deep extraction: domain entities (REFINE mode only)

**Trigger**: REFINE mode (`--refine`). Skipped in CREATE / ENHANCE / REFRESH (those modes use the lighter Phase 2.x business-domain detection — sufficient for the floor, not for round-two depth).

**Why a separate phase**: round-one detection asks "is this an e-commerce / healthcare / billing app?" by reading folder names + dependency manifests + entity-name keywords. Round-two needs the actual entities — class names, field names, relationships, lifecycle events, invariants — read from the code itself, not inferred from the surface. A first-pass `ai/business-domains/<domain>.md` says "this is a billing app handling invoices and subscriptions." A round-two pass says "this app's billing domain has 7 entities (`Invoice`, `Subscription`, `Plan`, `Coupon`, `LedgerEntry`, `Refund`, `PaymentAttempt`), with these 4 lifecycle events (`invoice.finalized`, `invoice.paid`, `invoice.uncollectible`, `subscription.canceled`), invariant: `LedgerEntry.amount` SUM per `Invoice` MUST equal `Invoice.total`, currently enforced by `Reports/services/billing/ledger.py:assert_balanced` (line 142)." The second is anchorable; the first is generic.

**Mechanism**: invoke the `extract-domain-entities-deeply` skill (lives in `~/.claude/templates/packs/learning/skills/extract-domain-entities-deeply/SKILL.md`) ONCE per detected business-domain (from Phase 2.x). The skill walks: ORM/model class definitions (Django models / SQLAlchemy / Sequelize / Prisma / Mongoose / Pydantic / Zod schemas) → migrations directory (forward + reverse for full lineage) → repository / DAO classes → integration / e2e tests (the contract + edge cases the team explicitly tests) → docstrings / domain README files. Synthesizes a structured map: entities, fields with types + constraints + defaults, relationships (FK / cascade rules), enumerations, lifecycle events, invariants.

**Parallelism**: one Explore subagent per business-domain (typically 1–3); independent.

**Output**: `.claude/_refine-extract.md` § "Domain entities" — one sub-section per domain. Schema validation OPTIONAL — `~/.claude/templates/schemas/_extracted-domain.schema.json` is `[PLANNED]` (not shipped); Phase 5.4 emits `SCHEMA_MISSING` and continues per `capabilities/3-schema-validation.md § 3.5`.

**Quality gate**: if entity count < 3 OR no relationships extracted OR no invariants cited (with `file:line`), flag as `[REFINE-WEAK: domain=<name>]` and fall back to the round-one detection for that domain (no shallow rewrite).

**Skip when**: project has zero ORM/schema files (pure scripting / CLI-only / shell repo) — domain extraction has no substrate.

### Phase 2.8 — Deep extraction: architecture (REFINE mode only)

**Trigger**: REFINE mode. **Mechanism**: invoke `extract-architecture-deeply`. The skill walks: top-level package / module graph (import-edge analysis — direction + count) → request lifecycle for ≥1 representative endpoint per surface (HTTP / GraphQL / queue consumer / scheduled job — controller → service → repository → external sink) → bounded-context boundaries (which modules NEVER import which? — that's a deliberate boundary) → cross-cutting concerns location (auth, logging, tracing, rate-limiting — middleware / decorator / mixin location). Synthesizes: layer diagram (text), import-graph summary ("Reports → core, services, BillingPlans; Reports never imports Patients directly — uses BillingPlans as a façade"), 3-5 representative request lifecycles with `file:line` citations.

**Output**: `.claude/_refine-extract.md` § "Architecture" + ASCII layer diagram. Schema OPTIONAL — `~/.claude/templates/schemas/_extracted-architecture.schema.json` is `[PLANNED]` (not shipped).

**Quality gate**: if no import-graph extracted OR no representative lifecycle traced OR no boundary identified, flag `[REFINE-WEAK: architecture]` and skip Phase 4.6-DEEP rewrite of `ai/architecture.md` (leave round-one version).

### Phase 2.9 — Deep extraction: end-to-end flows (REFINE mode only)

**Trigger**: REFINE mode. **Mechanism**: invoke `extract-flows-deeply`. The skill walks ≥3 representative business-critical flows (signup / checkout / payment / report-generation / file-upload / whatever the domain says is critical from Phase 2.7 lifecycle events) AND ≥2 admin / internal flows (e.g. `bulk-import`, `nightly-batch-job`). For each flow: trigger → entry point → all step files in order with `file:line` citations → side effects (DB writes, external API calls, queue publishes, email sends) → error paths → idempotency mechanism (or absence of one).

**Output**: `.claude/_refine-extract.md` § "Flows" — one sub-section per flow. Schema OPTIONAL — `~/.claude/templates/schemas/_extracted-flows.schema.json` is `[PLANNED]` (not shipped).

**Quality gate**: minimum 5 flows total (3 business + 2 admin); below that, flag `[REFINE-WEAK: flows-coverage]`.

### Phase 2.10 — Deep extraction: emerging conventions (REFINE mode only)

**Trigger**: REFINE mode. **Mechanism**: invoke `extract-conventions-emerging`. Round-one Phase 2 picks up explicit conventions (file-naming pattern, base classes, suffix matrix, test colocation). Round-two looks for **emergent** ones — patterns that recur 5+ times across the codebase but aren't documented anywhere: error-shape conventions (every controller catches `X` and rethrows as `Y`); pagination conventions (every list endpoint accepts `limit/offset` OR `cursor` — pick the actual one); validation library + decorator/serializer pattern; logging shape (`logger.info({event, user_id, request_id})` — extract the actual fields the project uses); transaction-boundary convention (transactions opened in service layer? repository layer?); naming for async work (`*_job.py` vs `tasks/*` vs `workers/*`); convention for dates / money / IDs (UUID vs ULID vs auto-increment; `Decimal` vs `float`; ISO-string vs epoch).

**Output**: `.claude/_refine-extract.md` § "Conventions (emergent)" with each pattern + occurrence count + 3 sample `file:line` citations.

**Quality gate**: minimum 3 emergent conventions OR explicit "no emergent conventions detected — codebase is highly heterogeneous" finding (the negative finding is also useful — it tells round-two not to invent uniformity).

### Phase 2.11 — Deep extraction: performance hot paths (REFINE mode only)

**Trigger**: REFINE mode. **Mechanism**: invoke `extract-hotpaths`. Walks: endpoints / queries / jobs that are likely high-volume (heuristics — high test coverage, high git churn, high import-fan-in, mentioned in any monitoring config / Datadog dashboard / Sentry rule); ORM eager-loading patterns (`select_related`, `prefetch_related`, `joinedload`, `with`, `include`); raw-SQL files; index definitions in migrations; cache usage (Redis / Memcached / in-memory LRU); existing N+1 risk markers (loop bodies that call `.objects.get` / `Repository.findOne` / `await fetch`).

**Output**: `.claude/_refine-extract.md` § "Hot paths" — list of top-10 likely hot paths with: file:line, current concurrency mode (sequential / batched / parallel), N+1 risk score (none / low / med / high), index coverage (yes / partial / no), cache layer (yes / no), 1-line uplift recommendation (or "looks healthy").

**Quality gate**: if no hot paths extracted, flag `[REFINE-WEAK: hotpaths]` — round-two won't generate perf advice for this project (the floor stays from round-one's generic backend perf rule).

**Why this matters**: this is what makes round-two output something a senior engineer would actually read. A generic `query-optimizer.md` is forgettable. A `query-optimizer.md` whose `## Project-specific` block lists the actual endpoints with N+1 risk and the actual indexes that need to be added is a tool that gets used.

### Phase 2.12 — Deep extraction: failure history (REFINE mode only)

**Trigger**: REFINE mode AND (a) git log accessible AND (b) ≥30 commits OR (c) presence of any of: `docs/postmortems/`, `docs/incidents/`, `INCIDENTS.md`, `RUNBOOK.md` content with "incident" / "outage" / "regression" / "post-mortem" mentions.

**Mechanism**: invoke `extract-failures-from-history`. Walks: git log for `revert`, `hotfix`, `incident`, `regression`, `rollback`, `outage` commit messages → reads the diffs of those commits to identify the affected file/function → reads commit message body for cause description → groups failures by recurring theme (auth bypass / N+1 perf / migration drift / payment double-charge / etc.) → cross-references with `ai/failures/_index.md` if present (round-one might have surfaced a few; round-two finds the rest).

**Output**: `.claude/_refine-extract.md` § "Failure history" — list of recurring themes with: theme, occurrence count, affected files (sample), commit refs, root-cause family. **Round-two will materialize these into `ai/failures/<theme>.md` files in Phase 4.6-DEEP** so future agents inject them in pre-flight (per Hard Rule on architectural-agent failure catalog injection).

**Quality gate**: if extraction yields zero recurring themes (all incidents one-off), record `## No recurring failure themes` in the file (negative finding) and skip Phase 4.6-DEEP failure-file generation.

**Privacy / safety**: NEVER extract failure-history content from any source the user hasn't explicitly opted into via prompt or `/setup-project --refine --include-incidents=docs/postmortems/` — the skill stays inside the repo + local git log; no external bug-tracker calls.

---

**Joint output of Phases 2.7–2.12**: a single `.claude/_refine-extract.md` with six labeled sections + a header summarizing extraction quality:

```
# Refine extraction — round two
> Generated by /setup-project --refine on <YYYY-MM-DD HH:MM>.
> Inputs: project at <path>, last commit <sha>, prior setup version <semver>.

## Extraction quality summary
- Domain entities: STRONG (3 domains, 21 entities, 9 invariants cited)
- Architecture: STRONG (3 layers, 4 boundaries, 5 lifecycles)
- Flows: STRONG (3 business + 3 admin)
- Emergent conventions: STRONG (4 conventions surfaced)
- Hot paths: STRONG (10 paths, 6 with uplift candidates)
- Failure history: WEAK (only 12 relevant commits — round-two will not generate failure files for this project)

## Round-two strategy
- Will rewrite Project-specific blocks for: <list of artifacts where ≥1 deep input is now available>
- Will leave-as-is: <list of artifacts where deep extraction added no new signal>
- New files to materialize: <ai/failures/*.md from Phase 2.12 if STRONG; etc.>
```

This file is the **substrate for Phase 4.6-DEEP**.

