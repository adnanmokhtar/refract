---
name: apply-pack-adaptation
description: Per-file STUDY → DECIDE → ACT for pack-added files in /setup-project Phase 4.6 (round one — CREATE / ENHANCE / REFRESH), Phase 4.6-DEEP / 4.7-DEEP (round two — REFINE), and Phase 4.8-DEEP (round-two adapter sync). Reads each file plus the project's extracted codebase + business + idioms context (round one) AND `.claude/_refine-extract.md` (round two), decides CHANGE-anchor / CHANGE-anchor-with-warn / LEAVE-with-redirect / LEAVE-delete (round one) OR ANCHOR-DEEP / LEAVE-DEEP / LEAVE-DEEP-IDEMPOTENT / NEW-FILE (round two) OR RE-TRANSLATED / INDEX-REFRESHED / SKIPPED-NO-CHANGES / NO-OP-ADAPTER (adapter sync), applies the decision with marker-bracketed in-place edits + hash-check rollback, and writes a decision log Phase 5.3 audits. Frees /setup-project's main context for orchestration.
---

# apply-pack-adaptation

## Purpose

Pack-added files (rules + agents + patterns + skills copied via Phase 4.2 / 4.4 / 4.4b of `/setup-project`) start out GENERIC — they cite hypothetical bases (e.g. "the project's `<service-base>` / `<repository-base>` / `<controller-base>`" with placeholders). This skill makes per-file judgment calls to align them with the project's actual code, using the bigger picture from extraction.

**The historical bug this prevents**: under context pressure, the LLM running `/setup-project` "saves time" by skipping per-file adaptation — the user opens the regenerated `.claude/rules/<name>.md` and finds it talks about generic `<concept>` patterns instead of the project's actual `<project-base-class>` base class. The user correctly says "you didn't adapt — you just copied templates." This skill exists to make that failure impossible: it runs in its own context window, it has the full extraction loaded, and Phase 5.3 audits its decision log.

## When invoked

- **Round one** — `/setup-project` Phase 4.6 in CREATE / ENHANCE-retrofit / ENHANCE-extend / REFRESH.
  - After Phase 4.2 / 4.4 / 4.4b have copied pack files into the project.
  - Before Phase 4.7 (knowledge base) — so adapted rules are in their final shape when CLAUDE.md cross-references them.
- **Round two** — `/setup-project` Phase 4.6-DEEP in REFINE mode (`--refine`).
  - After Phase 2.7–2.12 have produced `.claude/_refine-extract.md` (deep extraction substrate).
  - Operates on the SAME pack-added files from a prior round-one run (or current run when `--enhance --refine` is piped). The skill re-reads each artifact's existing `## Project-specific` block and decides whether to deepen it.
  - Skips any artifact whose anchor-density score (per `compute-anchor-density` skill) is ≥ 70/100 — round-one anchor is sufficient there. Targets only SHALLOW (< 70) artifacts.
- **Round-two adapter sync** — `/setup-project` Phase 4.8-DEEP in REFINE mode (`--refine`).
  - After Phase 4.6-DEEP + Phase 4.7-DEEP complete and have produced their decision logs.
  - Operates on **per-adapter output files** (`.cursor/rules/*.mdc`, `opencode.json`, `CONVENTIONS.md`, `.continue/rules/*.md`, `.clinerules/*.md`, `.windsurf/rules/*.md`, `.github/instructions/*.md`, `.github/prompts/*.md`, `AGENTS.md`, `GEMINI.md`) — NOT on `.claude/{rules,commands,agents,skills}/*.md` (those were the input to 4.6-DEEP).
  - Re-translates only the adapter outputs whose source artifact appears in the 4.6-DEEP / 4.7-DEEP affected list. The `claude-code` adapter is a NO-OP (it reads `.claude/` directly).
  - Index outputs (`AGENTS.md` § "Named procedures", `opencode.json` `commands` block, `.continue/config.yaml` `prompts:` block, `.clinerules/{80-commands,81-agents,82-skills}.md`, etc.) are regenerated fully when the affected list contains any `NEW-FILE` entry.

## Inputs

The skill reads (must exist before invocation):

| Path | Source | Use | Required when |
|---|---|---|---|
| `.claude/_extracted-codebase.md` | Phase 2 (extract-codebase-overview) | Real paths, base classes, conventions, signals, anti-patterns | always |
| `.claude/_extracted-idioms.md` | Phase 2.5 (extract-base-class-idiom) | Per-base-class deep idioms — the substrate for project-specific anchors | always |
| `.claude/_extracted-business.md` | Phase 2 Step 13 (extract-business-context) | Mission, personas, business model, regulatory context | always |
| `.claude/codebase-profile.md` | Phase 2 (condensed projection) | Backward-compat fast lookup for stack/profile | always |
| `ai/conventions.md` | Phase 4.7 or pre-existing | Already-detected conventions | always |
| `ai/business-domain.md` | Phase 4.4b or pre-existing | Domain entities + flows | always |
| `ai/_decision-index.md` | Pre-existing in REFRESH | ADR list | when present |
| `ai/failures/_index.md` | Pre-existing in REFRESH | Validated anti-patterns ("we tried X; it broke") | when present |
| `.claude/_refine-extract.md` | Phases 2.7–2.12 (round-two deep extraction) | Domain entities + invariants + flows + emergent conventions + hot paths + failure history with `file:line` citations | **REFINE mode only** |
| `.claude/_setup-quality.md` (prior run) | Phase 5.5 of any prior `--refine` run | Per-artifact anchor-density baseline; used to decide which artifacts to skip (≥ 70) and which to re-anchor (< 70). | REFINE mode, when present |
| `.claude/_phase-4-6-decisions.md` (prior run) | Prior Phase 4.6 / 4.6-DEEP runs | Idempotency check — has this exact deep extraction already been consumed by this artifact? | REFINE mode, when present |
| `.claude/_phase-4-6-decisions.md` (current run) | Phase 4.6-DEEP just completed in this REFINE run | Source of "affected artifact list" for ADAPTER-SYNC mode (rows with action `ANCHOR-DEEP` or `NEW-FILE`). | **ADAPTER-SYNC mode** |
| `.claude/_phase-4-7-decisions.md` (current run) | Phase 4.7-DEEP just completed in this REFINE run | Affected `ai/*.md` files for ADAPTER-SYNC mode. | **ADAPTER-SYNC mode** |
| `.claude/codebase-profile.md` § Adapters | Phase 3.2 selection | List of selected non-claude-code adapters for ADAPTER-SYNC to iterate. | **ADAPTER-SYNC mode** |
| `templates/tool-adapters/<adapter>/_translate.md` | Tool-adapter pack | Per-adapter translation rules — how a `.claude/<kind>/<name>.md` becomes the adapter's output format (the same logic regular Phase 4.8 uses, scoped to ONE artifact at a time). When this file is absent, the skill falls back to Phase 4.8.0's per-adapter contract table in `commands/setup-project.md` (the canonical source). | optional in ADAPTER-SYNC mode (fallback to Phase 4.8.0 contract) |
| `templates/tool-adapters/<adapter>/_user-customization.md` | Tool-adapter pack | Per-adapter customization surface — declares which adapter files are wholly auto-generated (re-write freely) vs which have user-customizable sections (use `<!-- generated:start/end -->` markers + hash-check). When this file is absent, the skill defaults to **"wholly auto-generated, no markers, full overwrite is safe"** for every adapter output (consistent with how regular Phase 4.8 currently writes). | optional in ADAPTER-SYNC mode (fallback to wholly-auto-generated default) |

Skill parameters:

- **`pack_added_files`** — list of file paths to process. In round one: pack files added by Phase 4.2 / 4.4 / 4.4b in the current run. In REFINE: list of artifacts targeted for round-two deepening (typically those with score < 70). In ADAPTER-SYNC: the affected-artifact list (union of round-two ANCHOR-DEEP + NEW-FILE + 4.7-DEEP markered changes).
- **`project_name`** — for anchor headers.
- **`mode`** — `CREATE` / `ENHANCE-retrofit` / `ENHANCE-extend` / `REFRESH` / **`REFINE`** / **`ADAPTER-SYNC`** (drives anchor depth + ACT options + decision-log section).
- **`refine_extract_path`** *(REFINE only)* — path to `.claude/_refine-extract.md`. The skill HALTS if mode = REFINE but this input is missing or empty.
- **`max_subagents`** *(REFINE / ADAPTER-SYNC only, optional)* — cap on parallel re-anchor / re-translate subagents. Default 8. Set lower on large codebases to bound cost; the skill honors the cap when fanning out per-artifact deep-anchor work AND per-(adapter × artifact) translation work.
- **`adapters`** *(ADAPTER-SYNC only)* — list of selected non-claude-code adapters from `.claude/codebase-profile.md`. The skill iterates one outer loop per adapter; within each adapter, it walks the affected list. `claude-code` is filtered out before the loop (always NO-OP).
- **`index_refresh`** *(ADAPTER-SYNC only)* — boolean. True iff the affected list contains ≥1 NEW-FILE row from 4.6-DEEP. Determines whether adapter "index" outputs (`AGENTS.md` invokable-commands, `opencode.json` `commands` block, etc.) regenerate.

## Decision matrix (the contract)

For each file, EXACTLY ONE decision is recorded. The set of available decisions depends on `mode`.

### Round one — CREATE / ENHANCE / REFRESH

| Decision | When | Action |
|---|---|---|
| **CHANGE-anchor** | Topic IS load-bearing in this project; pack body is broadly correct. | Prepend a `## Project-specific (<project-name>)` block citing real paths, base classes, idioms, ADRs, failures. Body stays unchanged. |
| **CHANGE-anchor-with-warn** | Topic IS load-bearing; pack body CONFLICTS with the project (e.g., pack says "use X"; project's `ai/failures/<NNNN>` says "we tried X, broke"). | Anchor MUST include a `**Conflicts with generic body**:` sub-block calling out the specific conflict + the project's resolution. Body stays. |
| **LEAVE-with-redirect** | Topic IS load-bearing BUT project has a richer project-authored equivalent (e.g., project has `ai/patterns/data-access.md` 130 lines + `.claude/rules/database.md` — pack's `database-principles.md` is supplementary). | Prepend a 3-5 line note: `> This project's primary guidance is <project-file> (NN lines). The generic content below is supplementary background only.` Body stays. |
| **LEAVE-delete** | Topic is NOT applicable to this project (e.g., `gitops-principles.md` in a non-GitOps project, `kubernetes-rules.md` in a serverless-only project). Should rarely happen — Phase 4.2 should have filtered these. | Delete the file. Record reason in decision log. |

### Round two — REFINE (Phase 4.6-DEEP)

In REFINE the artifacts already exist and already carry a round-one anchor. We are NOT re-running the round-one decision; we are deepening the existing block.

| Decision | When | Action |
|---|---|---|
| **ANCHOR-DEEP** | Artifact's anchor-density score < 70 AND `_refine-extract.md` has STRONG signal relevant to the artifact's topic (entities / flows / hot paths / emergent conventions / failure themes). | REWRITE the existing block delimited by `<!-- project-specific:start -->` ... `<!-- project-specific:end -->` markers. Keep the round-one summary as the first 5 lines; append concrete deep-extraction citations (entities with invariants, flow `file:line`, hot-path N+1 sites, missing indexes, recurring failure themes). |
| **LEAVE-DEEP** | Artifact's score < 70 BUT `_refine-extract.md` adds no new signal for this topic (e.g., a `code-quality.md` rule has no entities/flows to cite — the score is intrinsically capped). | Leave block untouched. Record reason `no-deep-signal-applies` in decision log. Score-low + no-signal is a legitimate stable state, not a failure. |
| **LEAVE-DEEP-IDEMPOTENT** | Prior REFINE run already deep-anchored this artifact AND `_refine-extract.md` content unchanged since then (compared via hash of relevant `_refine-extract.md` sections recorded in `_phase-4-6-decisions.md`). | Leave block untouched. Record `idempotent` reason. This is the converging case — what makes 2nd / 3rd `--refine` runs reach "plateau reached." |
| **NEW-FILE** | Deep extraction surfaced a genuine artifact need round one didn't catch. Concrete examples: Phase 2.12 found a recurring `auth-bypass` failure theme → write `ai/failures/auth-bypass.md`. Phase 2.11 found 6 hot paths with N+1 risk → ensure `.claude/skills/query-optimizer.md` exists (gap-fill + deep-anchor in one step). | Create the new file with the appropriate template + a project-specific block populated from `_refine-extract.md`. Mark `gen-by: refine-deep` in the new file's frontmatter. |
| **CHANGE-anchor-with-warn** | Same shape as round one. Rare in REFINE — round-one already established the floor — but possible when `_refine-extract.md` § "Failure history" reveals a new conflict with a pack body recommendation. | Same action as round one; recorded under the REFINE decision-log section. |

In REFINE mode, `LEAVE-with-redirect` and `LEAVE-delete` are NOT available decisions — those were round-one calls and stay as-is.

### Round-two adapter sync — ADAPTER-SYNC (Phase 4.8-DEEP)

In ADAPTER-SYNC the artifacts being processed are **per-adapter output files** (one row per `(adapter, output-file)` tuple), not the `.claude/{rules,commands,agents,skills}/*.md` source files. The decisions describe what happened to each adapter output:

| Decision | When | Action |
|---|---|---|
| **RE-TRANSLATED** | Source artifact is in the affected list (ANCHOR-DEEP or NEW-FILE in 4.6-DEEP, or markered-change in 4.7-DEEP) AND the adapter has a per-artifact output file for it (e.g. `.cursor/rules/<x>.mdc` for `.claude/rules/<x>.md`). | Re-render that single adapter file from the deepened source, using the per-adapter translation rules from `templates/tool-adapters/<adapter>/_translate.md`. Apply the same marker-bracketed write contract used for `.claude/` files (see "Marker safety contract" below). |
| **INDEX-REFRESHED** | `index_refresh = true` AND the adapter has an "index" output that enumerates every command / agent / skill (`AGENTS.md` § "Invokable commands" / "Named personas" / "Named procedures"; `opencode.json` `commands` block; `.continue/config.yaml` `prompts:` block; `.clinerules/{80-commands,81-agents,82-skills}.md`; `.windsurf/rules/{80-commands,81-agents,82-skills}.md`; `.cursor/rules/00-project.mdc` cross-refs). | Regenerate the index output fully (every command / agent / skill in `.claude/` re-listed, not just the affected ones). Reuses Phase 4.8.0 contract. |
| **SKIPPED-NO-CHANGES** | The adapter has NO per-artifact output for any item in the affected list AND `index_refresh = false`. Example: REFINE only deepened `.claude/rules/<x>.md`, but the adapter is `gemini` (thin-pointer variant) — it has nothing to re-translate. | No write. Record the decision row + reason. |
| **NO-OP-ADAPTER** | The adapter is `claude-code` (always NO-OP — REFINE wrote `.claude/` directly). OR the adapter is `gemini` in thin-pointer-to-AGENTS.md mode. | No write. Record the decision row noting it's a structural NO-OP. |
| **ROLLBACK-MARKER-DRIFT** | Adapter output has user-customizable sections (`<!-- generated:start/end -->` markers per `_user-customization.md`); post-write hash check on bytes outside markers fails. | Restore pre-write bytes from in-memory copy. Record reason. The user MUST review the adapter file manually. |
| **MARKERS-MISSING-ADAPTER** | Adapter output has a customization surface declared but the file lacks the `<!-- generated:start/end -->` markers (file pre-dates the marker contract OR user removed them). | Inject markers around an empty block at the appropriate location, then proceed with RE-TRANSLATED. Record `MARKERS-INJECTED-ADAPTER` so subsequent runs see the markers. |
| **NEEDS-FULL-PHASE-4.8** | Adapter has internally-coupled outputs (e.g. `opencode.json` whose `commands` block depends on the same JSON's `provider` block — a mid-file partial rewrite isn't safe). | Defer to a full Phase 4.8 re-run for that one adapter (regenerate the entire output file from scratch). Record the decision; Phase 5 verification handles the actual re-run. Used sparingly — `_user-customization.md` declares whether this is required for an adapter. |

**Bypass**: every entry in the affected-list × selected-adapters cross product MUST yield exactly one row. Phase 5 verification audits the cross-product against the decision log; any missing row → HALT + retry.

## STUDY → DECIDE → ACT loop (per file)

### 1. STUDY (read everything relevant)

For each file:

- Read the file content. In round one, this is the generic pack body just-copied. In REFINE, this is the existing artifact (with its round-one anchor block).
- Identify the topic the file is ABOUT (data access, error handling, auth, testing, multi-tenancy, observability, gitops, kubernetes, etc.).
- Cross-reference against `_extracted-codebase.md`:
  - Does this codebase have base classes / paths / signals related to the topic?
  - Has the topic been the subject of a validated failure (`ai/failures/_index.md`)?
- Cross-reference against `ai/patterns/*.md` and existing `.claude/rules/*.md`:
  - Does the project already have a richer file for the same topic?
- For workflow / process files (git-workflow, documentation, code-review-flow): skip the identifier-injection requirement. The anchor cites team conventions instead (PR template, commit-message format, review SLA from `_extracted-business.md` § Constraints or `_extracted-codebase.md` § Recent activity).
- **REFINE-only additions**:
  - Read `.claude/_refine-extract.md` and identify the sections relevant to this artifact's topic. Examples: a `database.md` rule maps to `## Domain entities` + `## Hot paths`; a `backend-architect.md` agent maps to `## Architecture` + `## Flows`; a `parallelize-independent-ops.md` skill maps to `## Hot paths` (specifically N+1 / sequential-await citations).
  - Read the existing artifact's `## Project-specific` block. Inventory: what identifiers / paths / signals is it ALREADY citing? (This is the round-one baseline; ANCHOR-DEEP only adds NEW citations on top.)
  - Read `.claude/_setup-quality.md` (if present) for this artifact's prior score. If ≥ 70 AND `--refine` was not invoked with `--aggressive` (future flag), short-circuit to `LEAVE-DEEP-IDEMPOTENT` (no STUDY work wasted; skip DECIDE).
  - Read the prior `.claude/_phase-4-6-decisions.md` REFINE section (if present). If a prior REFINE run already deep-anchored this artifact AND the relevant `_refine-extract.md` sections haven't changed (compare hashes recorded in the prior decision row) → short-circuit to `LEAVE-DEEP-IDEMPOTENT`.
- **ADAPTER-SYNC additions** (per (adapter, source-artifact) tuple):
  - Read `.claude/_phase-4-6-decisions.md` REFINE section + `.claude/_phase-4-7-decisions.md` REFINE section. Build the affected-artifact list (rows with action `ANCHOR-DEEP` / `NEW-FILE` / markered-rewrite / `MARKERS-INJECTED`). Ignore `LEAVE-DEEP*` / `ROLLBACK-MARKER-DRIFT` rows (no propagation needed).
  - Read the deepened source artifact (`.claude/<kind>/<name>.md` or `ai/<name>.md`) — this is the new content to translate.
  - Read the current per-adapter output (e.g. `.cursor/rules/<name>.mdc`) — this is the file being rewritten. Capture its byte-level state for the hash check.
  - Read `templates/tool-adapters/<adapter>/_translate.md` — per-adapter translation rules (how `.claude/rules/<x>.md` becomes `.cursor/rules/<x>.mdc`, which sections embed vs which reference).
  - Read `templates/tool-adapters/<adapter>/_user-customization.md` — does this output file have user-customizable sections? If yes, locate `<!-- generated:start/end -->` markers; if absent, prepare to inject them (MARKERS-INJECTED-ADAPTER).

### 2. DECIDE

**Round one** — per the round-one matrix above:

- **Topic load-bearing + no project equivalent + no conflict** → CHANGE-anchor
- **Topic load-bearing + pack body conflicts with project** → CHANGE-anchor-with-warn
- **Topic load-bearing + project has richer equivalent** → LEAVE-with-redirect
- **Topic not load-bearing AT ALL** → LEAVE-delete

**REFINE** — per the REFINE matrix above:

- **Score ≥ 70 OR idempotency hash matches** → LEAVE-DEEP-IDEMPOTENT
- **Score < 70 AND `_refine-extract.md` has STRONG signal for this topic** → ANCHOR-DEEP
- **Score < 70 AND no relevant signal in `_refine-extract.md`** → LEAVE-DEEP (record `no-deep-signal-applies`)
- **Deep extraction surfaced a NEW required artifact (not in `pack_added_files`)** → NEW-FILE (push the path onto the work list, then ANCHOR-DEEP it on the next loop iteration)
- **`_refine-extract.md` § "Failure history" surfaces a conflict with the pack body** → CHANGE-anchor-with-warn (same shape as round one)

**ADAPTER-SYNC** — per the ADAPTER-SYNC matrix above:

- **Adapter is `claude-code`** → NO-OP-ADAPTER (always; never iterate further within this adapter loop)
- **Adapter is `gemini` AND `GEMINI.md` is the thin-pointer variant** → NO-OP-ADAPTER
- **Source artifact in affected list AND adapter has a per-artifact output for it AND the output file is wholly auto-generated** → RE-TRANSLATED
- **Source artifact in affected list AND adapter's output file has user-customizable sections AND markers absent** → MARKERS-INJECTED-ADAPTER + RE-TRANSLATED (single decision row recording both)
- **Source artifact in affected list AND markers present AND post-write hash matches** → RE-TRANSLATED
- **Source artifact in affected list AND markers present AND post-write hash mismatches** → ROLLBACK-MARKER-DRIFT (the rewrite was unsafe — preserve user content)
- **`index_refresh = true` AND adapter has an "index" output** → INDEX-REFRESHED (one row per index file regenerated)
- **No source artifact in affected list maps to this adapter AND `index_refresh = false`** → SKIPPED-NO-CHANGES
- **Adapter has internally-coupled outputs (e.g. `opencode.json`'s `commands` block depends on the same JSON's `provider` block)** → NEEDS-FULL-PHASE-4.8 (defer to a complete `opencode.json` regen)

### 3. ACT (apply the decision)

#### CHANGE-anchor / CHANGE-anchor-with-warn — anchor block shape (round one)

The block is bracketed by HTML markers. **Every Phase 4.6 anchor MUST emit these markers** — they are the contract REFINE depends on. Without them, REFINE has no idempotent way to rewrite only the auto-generated portion.

```markdown
<!-- project-specific:start -->
## Project-specific (<project-name>)

> Auto-generated by /setup-project Phase 4.6 (apply-pack-adaptation skill) on <YYYY-MM-DD>.
> The generic rule below applies; this section anchors it to <project-name>'s actual code.
> REFINE rewrites between these markers; user-authored content outside is preserved verbatim.

**Where this applies in <project-name>**:
- `<RealBaseClassFromExtraction>` at `<real/path/from/extraction>` (<N> extenders)
- <real automatic behavior — e.g., "auto-filters tenant_id via AsyncLocalStorage">
- <real path conventions — e.g., "modules under libs/<name>/src/...">

**Project-specific guidance** (overrides generic body where they conflict):
- <real project-specific rule from extraction or ADR>
- <real project-specific anti-pattern from ai/failures/ if any>

**Conflicts with generic body** (CHANGE-anchor-with-warn ONLY):
- Generic body says: "<verbatim quote of conflicting line>"
- This project's resolution: "<what we do instead, why — cite ADR or failure entry>"

**Cross-references**:
- ai/patterns/<related>.md (NN lines)
- ai/decisions/<NNN>-<slug>.md
- ai/failures/<NNNN>-<slug>.md (if relevant)
<!-- project-specific:end -->

---

[Generic body unchanged below from here]
```

**CRITICAL — identifier traceability**: every concrete identifier (class name, path, helper, library) cited in the anchor MUST be findable in `.claude/_extracted-codebase.md` or `.claude/_extracted-idioms.md` (round one) OR in `.claude/_refine-extract.md` (round two). Phase 5.3.5 (leak scan) cross-references against extraction; an identifier not in extraction = leak from another project's run = HALT.

#### ANCHOR-DEEP — deepening the existing block (REFINE only)

The block is REWRITTEN in place between the markers. The structure layers round-one + round-two:

```markdown
<!-- project-specific:start -->
## Project-specific (<project-name>)

> Round-one anchor (Phase 4.6 / <round-one-date>); deepened by /setup-project --refine on <YYYY-MM-DD>.
> The generic rule below applies; this section anchors it to <project-name>'s actual code.
> REFINE rewrites between these markers; user-authored content outside is preserved verbatim.

**Where this applies in <project-name>** (round-one summary, 3-5 lines):
- <round-one citations: base classes + paths + suffix matrix as before>

**Domain entities involved** (ANCHOR-DEEP — from `_refine-extract.md` § "Domain entities"):
- `<EntityName>` at `<file:line>` — <invariants the rule must preserve>
- ...

**Flows that exercise this rule** (ANCHOR-DEEP — from `_refine-extract.md` § "Flows"):
- <flow-name>: `<entry-file:line>` → `<step-file:line>` → ... — <the side effect / error path the rule guards>
- ...

**Hot paths to watch** (ANCHOR-DEEP — from `_refine-extract.md` § "Hot paths"; only when relevant):
- `<hot-path-name>`: `<file:line>` — N+1 risk: <yes/no, evidence>; index coverage: <covered / missing on `<column>`>; cache layer: <present / absent>
- ...

**Emergent conventions to follow** (ANCHOR-DEEP — from `_refine-extract.md` § "Conventions (emergent)"):
- <pattern>: <how it manifests> — recur count: <N>; first occurrence: `<file:line>`
- ...

**Failure themes to avoid** (ANCHOR-DEEP — from `_refine-extract.md` § "Failure history"; only when STRONG):
- `<theme>`: <occurrence count> incidents; root-cause family: `<family>`; representative commits: `<sha1>`, `<sha2>` — see `ai/failures/<theme>.md`.
- ...

**Cross-references**:
- ai/patterns/<related>.md
- ai/decisions/<NNN>-<slug>.md
- ai/failures/<theme>.md (if a failure-history section is present above)
<!-- project-specific:end -->
```

**CRITICAL — REFINE writes ONLY between the markers.** Bytes outside the markers are bit-identical pre/post run. See "Marker safety contract" below for the hash-check + rollback protocol.

**CRITICAL — every citation in the deep anchor MUST be sourced from `_refine-extract.md`.** No round-two output may invent identifiers, paths, or `file:line` references; the leak scan (Phase 5.3.5) cross-checks against `_refine-extract.md` for REFINE-mode anchors and against `_extracted-codebase.md` for round-one anchors.

**Length budget for ANCHOR-DEEP**: 25-50 lines between the markers, depending on how many signal categories apply. A 60+ line anchor is a smell — split topic into a separate companion file (NEW-FILE) rather than overflowing one rule's block.

#### LEAVE-DEEP / LEAVE-DEEP-IDEMPOTENT — no file write

No write. Just record the decision row in `_phase-4-6-decisions.md`. For LEAVE-DEEP-IDEMPOTENT, also record the hash of the relevant `_refine-extract.md` sections so the next REFINE run can short-circuit faster.

#### NEW-FILE — generate a previously-missing artifact (REFINE only)

Used when deep extraction surfaces a new artifact need:

1. Pick the closest template from `~/.claude/templates/packs/<track>/<kind>/<canonical-name>.md`. If none exists, synthesize from a sibling template + the deep-extraction substrate.
2. Write the new file with the marker-bracketed `## Project-specific` block populated by ANCHOR-DEEP rules.
3. Mark frontmatter with `gen-by: refine-deep` and `created-on: <YYYY-MM-DD>` so subsequent runs know it originated in REFINE.
4. Append a `NEW-FILE` row to the decision log noting the source signal (e.g. "Phase 2.12 recurring `auth-bypass` theme → `ai/failures/auth-bypass.md`").

If extraction has no signal for the topic (`[EXTRACTION-WEAK: <base>]` flag from Phase 2.5):
- Produce a thinner anchor (5-10 lines) citing whatever facts ARE known: stack from `codebase-profile.md`, path conventions, file-naming pattern, framework defaults.
- Mark `[EXTRACTION-WEAK]` in the anchor for Phase 5 visibility.
- A 5-line anchor citing 2 known facts is BETTER than a placeholder anchor with `<TODO>`.

#### LEAVE-with-redirect — note shape

```markdown
> **This project's primary guidance is `<project-file>`** (<NN> lines, project-authored).
> The generic pack content below is supplementary background only.
> When working in this area, prefer `<project-file>` for project-specific decisions.

---

[Generic body unchanged below from here]
```

#### LEAVE-delete — delete the file

```bash
rm "<file>"
# Record in decision log with reason.
```

#### RE-TRANSLATED / INDEX-REFRESHED — adapter output rewrite (ADAPTER-SYNC only)

For each `(adapter, output-file)` tuple receiving RE-TRANSLATED or INDEX-REFRESHED:

1. **Read** the deepened source content from `.claude/<kind>/<name>.md` (for RE-TRANSLATED, single artifact) OR the full set of `.claude/{rules,commands,agents,skills}/*.md` (for INDEX-REFRESHED, full enumeration).
2. **Translate** per `templates/tool-adapters/<adapter>/_translate.md`. Each adapter has its own format — Cursor needs `.mdc` frontmatter (`description`, `globs`, `alwaysApply`) + body, OpenCode needs JSON entry shape, Aider needs Markdown sections in `CONVENTIONS.md`, etc. The translation logic is the same one regular Phase 4.8 uses; ADAPTER-SYNC just feeds it ONE artifact at a time (RE-TRANSLATED) or the full set (INDEX-REFRESHED).
3. **Locate markers** if `_user-customization.md` declares the file has user-customizable sections (look for `<!-- generated:start -->` ... `<!-- generated:end -->`). If absent: insert markers around what is currently the auto-generated portion (best-effort identification: if the file has a clear "above-the-fold" generated section vs "below-the-fold" user section, the heuristic in `_user-customization.md` describes where to draw the boundary). Record `MARKERS-INJECTED-ADAPTER` once per file.
4. **Write atomically**: hash bytes outside markers (or hash empty if file is wholly auto-generated), perform the rewrite, hash again. Mismatch on a markered file → `ROLLBACK-MARKER-DRIFT`. Wholly-auto-generated file → no hash check (the whole file is the generated payload).
5. **Record** the decision row in `_phase-4-8-decisions.md` (separate from `_phase-4-6-decisions.md` — different scope, different audit).

**Per-adapter translation cheatsheet** (the cases ADAPTER-SYNC handles most often):

| Source change | Target adapter | RE-TRANSLATED outputs |
|---|---|---|
| `.claude/rules/database.md` ANCHOR-DEEP'd | `cursor` | `.cursor/rules/<NN>-database.mdc` body re-rendered from new `.claude/rules/database.md` body. |
| `.claude/rules/database.md` ANCHOR-DEEP'd | `aider` | `CONVENTIONS.md` § "Database conventions" re-rendered (top 6-10 must/must-not from updated `ai/_convention-cheatsheet.md`). |
| `.claude/rules/database.md` ANCHOR-DEEP'd | `cline` / `windsurf` / `continue` / `copilot` | Per-adapter rule file (`.clinerules/<NN>-database.md`, `.windsurf/rules/<NN>-database.md`, `.continue/rules/database.md`, `.github/instructions/database.instructions.md`) re-rendered. |
| `.claude/commands/db-migration.md` NEW-FILE | `opencode` | `.opencode/commands/db-migration.md` written (NATIVE folder); optional `opencode.json` `commands` mirror also regenerated when `--legacy-opencode` is set. |
| `.claude/commands/db-migration.md` NEW-FILE | `cursor` | `.cursor/commands/db-migration.md` created (NATIVE folder, ≥ Cursor 2.3); plus `.cursor/rules/00-project.mdc` cross-refs section regenerated (INDEX-REFRESHED). |
| `.claude/commands/db-migration.md` NEW-FILE | `cline` | `.clinerules/workflows/db-migration.md` created (NATIVE workflow folder = slash command). |
| `.claude/commands/db-migration.md` NEW-FILE | `windsurf` | `.windsurf/workflows/db-migration.md` created (NATIVE Cascade workflow). |
| `.claude/commands/db-migration.md` NEW-FILE | `continue` | `.continue/prompts/db-migration.md` created with `invokable: true` (NATIVE prompts folder). |
| `.claude/commands/db-migration.md` NEW-FILE | `copilot` | `.github/prompts/db-migration.prompt.md` created (NATIVE). |
| `.claude/agents/backend-reviewer.md` NEW-FILE | `opencode` | `.opencode/agents/backend-reviewer.md` (NATIVE folder); AGENTS.md `## Named personas` index updated. |
| `.claude/agents/backend-reviewer.md` NEW-FILE | `copilot` | `.github/agents/backend-reviewer.agent.md` (NATIVE Apr 2026 GA folder). |
| `.claude/agents/backend-reviewer.md` NEW-FILE | `cursor` | `.cursor/commands/agent-backend-reviewer.md` (translated as command — Cursor has no agent dispatch). |
| `.claude/skills/module-scaffold/` NEW-FILE | `cursor` / `opencode` / `copilot` | `.cursor/skills/module-scaffold/SKILL.md` / `.opencode/skills/module-scaffold/SKILL.md` / `.github/skills/module-scaffold/SKILL.md` (NATIVE folder copies — including any supporting scripts). |
| `.claude/hooks/post-edit-check.sh` NEW-FILE | `cursor` | `.cursor/hooks.json` `afterToolCall` array updated; `.cursor/hooks/post-edit-check.sh` copied verbatim (NATIVE Cursor 2.3+ hooks). |
| `ai/architecture.md` markered-change | `aider` | `.aider.conf.yml` `read:` list refreshed if architecture is in the list (INDEX-REFRESHED); `CONVENTIONS.md` not touched (architecture isn't embedded there). |
| `ai/architecture.md` markered-change | `codex` | `AGENTS.md` § "Architecture" re-rendered (RE-TRANSLATED). |
| `ai/failures/auth-bypass.md` NEW-FILE | every adapter that mentions failures | Most adapters cross-reference `ai/failures/` rather than embed it — `.aider.conf.yml` `read:` list refreshed (INDEX-REFRESHED) for adapters that read it; `AGENTS.md` § "Driver-dependent safety" cross-ref refreshed for `codex`. |

#### NEEDS-FULL-PHASE-4.8 — defer to full adapter regen

Some adapter outputs aren't safely partial-rewritable (e.g., `opencode.json`'s schema couples blocks together). Decision row records the deferral; Phase 5 verification triggers a regular Phase 4.8 re-run for that single adapter (Phase 4.8 generates the entire output from the full `.claude/` set — same logic as round one). The cost is bounded — only the affected adapter's outputs are full-regen'd; other adapters use partial RE-TRANSLATED.

## Mode behavior — anchor depth differs

| Mode | Source of project context | Anchor depth |
|---|---|---|
| **CREATE** (greenfield) | Prompt + manifest hints + business-domain detection from prompt + chosen track packs. NO codebase yet. | **Lighter** (5-10 lines): cite prompt-declared mission/domain/stack/anti-goals, planned base classes per chosen architecture. Anchor flags `_TBD — populate as code is written_` for unknowns. Phase 6 `/refresh-knowledge` re-anchors once code exists. |
| **ENHANCE-retrofit** (source exists, no `.claude/`/`ai/`) | Phase 2 codebase profile (real base classes, real paths, real extender counts, real conventions, real signals) + business-domain detection. | **Full** (20-40 lines): cite real base class paths + extender counts + actual file paths + detected naming + detected signals + business-domain facts. Strongest case. |
| **ENHANCE-extend** (source + `.claude/` + `ai/` exist) | Phase 2 profile + extracted prior knowledge (existing custom rules, prior conventions, prior ADRs). | **Full + cross-ref**: same as retrofit, PLUS cross-reference any project-authored equivalent. If project has a richer agent/rule, decision tilts to LEAVE-with-redirect. |
| **REFRESH** (forced regen with prior knowledge) | Phase 0.2 extract + Phase 2 profile + Phase 2.5 idioms. | **Richest** for round one: uses everything — real codebase + extracted project idioms + ADR rationale + failure-catalog. Highest-fidelity adaptation. |
| **REFINE** (round-two deepening, opt-in via `--refine`) | Phase 2 profile + Phase 2.5 idioms + **Phases 2.7–2.12 deep extraction** (`_refine-extract.md`) + prior `_setup-quality.md` + prior decision log. | **Deepest** — ANCHOR-DEEP layer adds entity invariants, flow `file:line` traces, hot-path N+1/index/cache evidence, emergent-convention recurrence counts, failure-theme history on top of the round-one anchor. Skips artifacts already scoring ≥ 70 unless `--aggressive`. |
| **ADAPTER-SYNC** (round-two adapter sync, runs in Phase 4.8-DEEP) | The deepened `.claude/{rules,commands,agents,skills}/*.md` + `ai/*.md` from the just-completed REFINE run, plus per-adapter `_translate.md` + `_user-customization.md` rules. | **Adapter-derived** — no new anchor depth is added; the skill propagates the already-deepened `.claude/` content into adapter formats. Per-artifact RE-TRANSLATED for affected outputs; INDEX-REFRESHED for cross-cutting summaries. Skips adapters where the affected list yields zero work (SKIPPED-NO-CHANGES). `claude-code` and thin-pointer `gemini` are always NO-OP-ADAPTER. |

## Marker safety contract (REFINE only)

REFINE deepens existing artifacts in place. Without an explicit safety contract, an LLM editing a 200-line file could silently shift formatting, drop a user-added section, or rewrite outside the anchor block. The contract:

1. **Markers are the only writable region.** Every byte the skill writes lands strictly between `<!-- project-specific:start -->` and `<!-- project-specific:end -->`. Bytes outside (header, generic body, user-added sections below the body, footer) are bit-identical pre/post run.

2. **Hash-check before and after**:
   - Read the file. Locate both markers (or fail with `markers-missing` and skip the artifact — it's a round-one Phase 4.6 bug, not a REFINE concern).
   - Capture `pre_outside_hash = SHA-256(file_bytes_outside_markers)` (concatenated bytes BEFORE the start marker + bytes AFTER the end marker).
   - Build the new block content. Compose the full new file = `bytes_before_start_marker || start_marker || new_block || end_marker || bytes_after_end_marker`.
   - Write atomically (write to `<file>.tmp` + rename, OR use a single write call — never partial truncate).
   - Re-read the file. Capture `post_outside_hash = SHA-256(file_bytes_outside_markers)`.
   - **Assertion**: `pre_outside_hash == post_outside_hash`. If mismatch → ROLLBACK (restore pre-run bytes from in-memory copy) AND record a row in `_phase-4-6-decisions.md` with decision `ROLLBACK-MARKER-DRIFT` and an error reason. Halt the REFINE run for this artifact only; continue with the next.

3. **Marker integrity**: never edit the marker comment lines themselves. The two markers are byte-stable strings — the skill must use them verbatim, not regex-flexed variants.

4. **Concurrency**: never run two REFINE workers on the same artifact in parallel. The per-artifact fan-out cap (`max_subagents`) ensures each file has a single writer.

5. **Idempotency hash recording**: on successful ANCHOR-DEEP, record in the decision row the SHA-256 of the `_refine-extract.md` sections actually consumed (e.g. `entities:<sha>`, `flows:<sha>`, `hotpaths:<sha>`). The next REFINE run reads these hashes; if all relevant sections still match → decision is LEAVE-DEEP-IDEMPOTENT (skip rewrite even when score < 70).

6. **`ai/*.md` enrichment uses `<!-- refine-enriched:start -->` ... `<!-- refine-enriched:end -->`** instead of `project-specific` markers — but the same hash-check + rollback contract applies. Phase 4.7-DEEP delegates to this skill for the per-file enrichment write, inheriting the safety guarantees.

7. **Adapter outputs (ADAPTER-SYNC mode) use `<!-- generated:start -->` ... `<!-- generated:end -->` markers** when `templates/tool-adapters/<adapter>/_user-customization.md` declares the file has user-customizable sections. The same hash-check + rollback contract applies: pre/post hashes of bytes outside the markers MUST match; mismatch → `ROLLBACK-MARKER-DRIFT`. Adapter outputs declared as wholly-auto-generated (no customization surface, e.g. `.cursor/rules/command-<x>.mdc` per regular Phase 4.8) are re-written wholesale without a hash check (the whole file IS the generated payload — re-running ADAPTER-SYNC on unchanged inputs produces byte-identical output, which is the natural idempotency guarantee). The customization surface map (which files have markers vs which don't) lives in each adapter's `_user-customization.md` so it stays close to the per-adapter contract.

8. **Cross-mode marker semantics** (the three marker tokens never collide):
   - `<!-- project-specific:start/end -->` — round-one Phase 4.6 anchors in `.claude/{rules,commands,agents,skills}/*.md`. Owned by 4.6 and 4.6-DEEP (REFINE rewrites this region).
   - `<!-- refine-enriched:start/end -->` — round-two Phase 4.7-DEEP enrichment in `ai/*.md`. Owned by 4.7-DEEP only (round one Phase 4.7 doesn't use markers — it writes the full file from scratch on first run).
   - `<!-- generated:start/end -->` — adapter outputs in ADAPTER-SYNC mode (Phase 4.8-DEEP). Owned by 4.8 (regular Phase 4.8 places the markers on first write) and 4.8-DEEP (rewrites within them). The marker token is `generated` because adapter files are entirely tool-tooling-driven — no anchor / no enrichment metaphor; they are simply "the generated portion of this adapter file."

   A single file NEVER has more than one marker pair. The three tokens partition the artifact universe by phase ownership.

## Special case — engineering-principles.md (project-governance pack file)

This file has section-level **Applies when** clauses. Adapt as follows:

- For each section, read its **Applies when** clause.
- Check `_extracted-codebase.md` § Architecture and § Base classes:
  - Section says "module-based / package-based" → check if profile reports modules with explicit boundaries.
  - Section says "layered backend (Controller→Service→Repository)" → check if profile reports those layer names.
- If clause MATCHES: keep section, apply normal CHANGE-anchor logic (anchor cites this project's specific module list / layer names from extraction).
- If clause does NOT MATCH: REPLACE the section body (everything between the heading and the next heading) with a single line:

  ```
  _Not applicable to this project — <reason from profile, e.g. "this is a functional-core codebase without layered architecture; see ADR-0007">._
  ```

  Keep the section header for forward-compat (in case the project evolves and the rule becomes load-bearing later).

## Special case — workflow / process files

Files that don't reference base classes / paths / framework-specific identifiers (`git-workflow.md`, `documentation-principles.md`, `code-review-flow.md`, etc.):

- Skip the identifier-injection requirement (no `BaseClass at path/...` anchor lines).
- The anchor cites team conventions instead: PR template / commit-message format / review SLA / branching strategy from `_extracted-codebase.md` § Recent activity (commit-message style sample) and `_extracted-business.md` § Constraints (team size, SLA).
- Quality bar (per Phase 5.3): anchor still must be ≥3 lines of project-specific content beyond the section header — generic "this project uses git" doesn't pass.

## Outputs

The skill writes:

1. **The adapted files** — in-place edits.
   - Round one: anchor block prepended OR redirect note prepended OR file deleted.
   - REFINE: marker-bracketed block REWRITTEN (ANCHOR-DEEP) OR file untouched (LEAVE-DEEP / LEAVE-DEEP-IDEMPOTENT) OR new file created (NEW-FILE).

2. **`.claude/_phase-4-6-decisions.md`** — decision log for Phase 5.3 audit. Round-one and REFINE rows go under separate sections to keep history readable:

   ```markdown
   # Phase 4.6 Decision Log

   > Auto-generated by `apply-pack-adaptation` skill.
   > Phase 5.3 audits this against pack-added files. Every pack-added file MUST have an entry here.

   ## Round one — <mode> (<YYYY-MM-DD HH:MM>)

   | File | Decision | Reason | Identifiers cited |
   |---|---|---|---|
   | `.claude/rules/database-principles.md` | CHANGE-anchor | Multi-tenant project with custom repository base (15 extenders detected) | `BaseRepository@libs/db/repo.ts`, `tenant_id` filter, `soft-delete` |
   | `.claude/rules/database.md` | LEAVE-with-redirect | Project has richer `ai/patterns/data-access.md` (130 lines) | (redirect target) |
   | `.claude/rules/gitops-principles.md` | LEAVE-delete | No GitOps signal in profile (no `.argocd/`, no flux config, no `kubernetes` track selected) | — |
   | `.claude/rules/engineering-principles.md` | CHANGE-anchor (sections filtered) | Layered-architecture section applies (Controller→Service→Repository detected); module-boundaries section applies; Kubernetes section N/A | `apps/<modules>` paths, `BaseService@libs/...`, `BaseController@libs/...` |

   ### Summary (round one)
   - CHANGE-anchor:           <X> files
   - CHANGE-anchor-with-warn: <Y> files
   - LEAVE-with-redirect:     <Z> files
   - LEAVE-delete:            <W> files
   - Total pack-added:        <N> files
   - EXTRACTION-WEAK flags:   <K> (anchors thin due to no extraction signal)

   ## REFINE — round two (<YYYY-MM-DD HH:MM>)

   | File | Decision | Score Δ | Signals consumed | Refine-extract hashes | Reason |
   |---|---|---|---|---|---|
   | `.claude/rules/database.md` | ANCHOR-DEEP | 42 → 88 (+46) | domain-entity, hot-path, n+1-citation, missing-index | entities:`abc1234…`, hotpaths:`def5678…` | 7 entities + 4 hot paths cited |
   | `.claude/rules/code-quality.md` | LEAVE-DEEP | 65 → 65 (0) | — | — | no-deep-signal-applies (rule is about prose discipline, not entities/flows) |
   | `.claude/agents/backend-architect.md` | ANCHOR-DEEP | 38 → 79 (+41) | layer-or-boundary, flow | architecture:`9abcdef0…`, flows:`12345678…` | 3 lifecycles + 5 boundaries cited |
   | `ai/failures/auth-bypass.md` | NEW-FILE | n/a → 82 | failure-theme | failures:`fedcba98…` | Phase 2.12 surfaced `auth-bypass` as recurring (4 incidents over 18 months) |
   | `.claude/skills/parallelize-independent-ops.md` | LEAVE-DEEP-IDEMPOTENT | 84 → 84 | (cached) | (matches prior run) | hashes match prior REFINE; no new signal |
   | `.claude/rules/security.md` | ROLLBACK-MARKER-DRIFT | 62 → 62 | — | — | post-write hash mismatch — file restored, REFINE skipped this artifact |

   ### Summary (REFINE round two)
   - ANCHOR-DEEP:               <X> files
   - LEAVE-DEEP:                <Y> files
   - LEAVE-DEEP-IDEMPOTENT:     <Z> files
   - NEW-FILE:                  <W> files
   - CHANGE-anchor-with-warn:   <V> files (rare in REFINE)
   - ROLLBACK-MARKER-DRIFT:     <R> files (always 0 in a healthy run)
   - Average score: <prior> → <current> (Δ <delta>)
   - Plateau check: signals_consumed = <P>% — re-running `--refine` would add ≤ <est> points.
   ```

3. **`.claude/_phase-4-8-decisions.md`** *(ADAPTER-SYNC mode only)* — adapter-sync decision log for Phase 5 audit. Separate file from `_phase-4-6-decisions.md` because the scope is different (per-adapter outputs, not pack-added source artifacts):

   ```markdown
   # Phase 4.8 Decision Log

   > Auto-generated by `apply-pack-adaptation` skill in ADAPTER-SYNC mode.
   > Phase 5 audits this against the affected-list × selected-adapters cross product.
   > Every (adapter, output-file) tuple in the cross product MUST have a row here.

   ## REFINE adapter sync (<YYYY-MM-DD HH:MM>)

   Affected source list (from `_phase-4-6-decisions.md` REFINE + `_phase-4-7-decisions.md` REFINE):
   - `.claude/rules/database.md` (ANCHOR-DEEP)
   - `.claude/commands/db-migration.md` (NEW-FILE)
   - `ai/architecture.md` (markered-rewrite)
   - `ai/failures/auth-bypass.md` (NEW-FILE)
   index_refresh = true (NEW-FILE present)

   Selected adapters: cursor, opencode, aider, claude-code

   | Adapter | Output file | Action | Triggered by | Outside-marker hash check | Notes |
   |---|---|---|---|---|---|
   | claude-code | (n/a) | NO-OP-ADAPTER | structural | n/a | REFINE writes `.claude/` directly |
   | cursor | `.cursor/rules/database.mdc` | RE-TRANSLATED | `.claude/rules/database.md` ANCHOR-DEEP | match (no markers — wholly auto-generated) | body re-rendered |
   | cursor | `.cursor/rules/command-db-migration.mdc` | RE-TRANSLATED | `.claude/commands/db-migration.md` NEW-FILE | match (new file — no pre-hash) | created |
   | cursor | `.cursor/rules/00-project.mdc` | INDEX-REFRESHED | NEW-FILE in affected list | match | cross-refs updated |
   | opencode | `opencode.json` `commands` block | NEEDS-FULL-PHASE-4.8 | NEW-FILE in affected list | n/a | provider/model blocks coupled — defer to full regen |
   | aider | `CONVENTIONS.md` | RE-TRANSLATED | `.claude/rules/database.md` ANCHOR-DEEP + NEW-FILE in commands | match (markered) | must/must-not list refreshed; named-procedures index refreshed |
   | aider | `.aider.conf.yml` | INDEX-REFRESHED | NEW-FILE in affected list | match | `read:` list updated |

   ### Summary
   - RE-TRANSLATED:               <X> files
   - INDEX-REFRESHED:              <Y> files
   - SKIPPED-NO-CHANGES:           <Z> files
   - NO-OP-ADAPTER:                <W> files (claude-code + thin-pointer gemini)
   - MARKERS-INJECTED-ADAPTER:     <I> files (markers added on first ADAPTER-SYNC of pre-existing adapter file)
   - ROLLBACK-MARKER-DRIFT:        <R> files (always 0 in a healthy run; non-zero means user MUST review)
   - NEEDS-FULL-PHASE-4.8:         <N> files (deferred to full Phase 4.8 regen — Phase 5 triggers)
   - Adapters synced:              <A> / <T> selected (claude-code excluded; thin-pointer gemini may be excluded)
   - Total propagation rows:       <P>  (= |affected list| × |selected adapters| − |NO-OP-ADAPTER skips|)
   ```

4. **Inline `[EXTRACTION-WEAK]` flags** in any anchor produced under weak extraction signal — Phase 5 audit reports these so the user can decide whether to deepen the codebase before next refresh.

5. **Inline `[REFINE-WEAK: <axis>]` flags** in any ANCHOR-DEEP block where a relevant extraction phase produced WEAK output (e.g. `_refine-extract.md` § "Failure history" empty due to too few git commits). The block still gets the deepening that IS available; the flag tells Phase 5.5 to factor this into the plateau diagnosis.

## Error handling

- **Extraction-weak (topic load-bearing but no extraction signal)**: produce thin anchor with whatever facts ARE known. Mark `[EXTRACTION-WEAK]`. Don't HALT — a 5-line factual anchor beats a placeholder.
- **Conflict between pack body and project**: anchor MUST be CHANGE-anchor-with-warn shape with `**Conflicts with generic body**:` sub-block. Don't silently override; surface the conflict.
- **Identifier in anchor not in extraction**: this is a LEAK (the LLM hallucinated or carried over from another project's run). Rerun STUDY for that file with explicit instruction "only cite identifiers found in `.claude/_extracted-codebase.md` or `.claude/_extracted-idioms.md` (round one) or `.claude/_refine-extract.md` (round two)." If retry still leaks → halt with the leak list.
- **Decision log incomplete (some pack-added file missing an entry)**: Phase 5.3 audit catches this and triggers retry. The skill MUST emit one row per pack-added file even when LEAVE-delete / LEAVE-DEEP / LEAVE-DEEP-IDEMPOTENT (the row records the no-op + reason).
- **REFINE-only — `_refine-extract.md` missing or empty**: the skill HALTS in REFINE mode without it (Phases 2.7–2.12 are the prerequisite). Caller (`/setup-project --refine`) must run those phases first.
- **REFINE-only — `markers-missing` on a target artifact**: the artifact was never round-one-anchored (or the anchor predates the marker-emit contract). Emit a decision row with `MARKERS-MISSING — round-one Phase 4.6 bug` and skip the file. Suggest the user re-run round-one Phase 4.6 (typically via `--refresh` or by manually adding the markers around the existing block).
- **REFINE-only — `ROLLBACK-MARKER-DRIFT`** (post-write hash mismatch): always restore the pre-write bytes from in-memory copy, record the row, continue with the next artifact. NEVER leave a partial write. Phase 5.3 surfaces these as setup-quality regressions.
- **ADAPTER-SYNC — affected list empty**: union of `_phase-4-6-decisions.md` REFINE + `_phase-4-7-decisions.md` REFINE has zero ANCHOR-DEEP / NEW-FILE / markered-rewrite rows. Skill writes a single-row log entry `## REFINE adapter sync (<date>) — SKIPPED-NO-CHANGES (affected list empty; nothing to propagate)` and returns. Phase 5 verification accepts this as a healthy no-op (e.g. on a fully idempotent rerun where 4.6-DEEP and 4.7-DEEP returned all LEAVE-DEEP-IDEMPOTENT).
- **ADAPTER-SYNC — adapter `_translate.md` missing**: not a halt — falls back to Phase 4.8.0's per-adapter contract table (the canonical translation rules live in `commands/setup-project.md` § "Per-adapter completeness contract" anyway). The skill records `FALLBACK-TO-PHASE-4.8-CONTRACT <adapter>` in the decision row notes column.
- **ADAPTER-SYNC — adapter `_user-customization.md` missing**: not a halt — falls back to "wholly auto-generated, no markers, full overwrite is safe" default. This matches regular Phase 4.8's existing write behavior; ADAPTER-SYNC is byte-equivalent on idempotent reruns. Notes column records `WHOLLY-AUTO-GENERATED-DEFAULT`.
- **ADAPTER-SYNC — `ROLLBACK-MARKER-DRIFT` on adapter file**: same recovery as REFINE — restore pre-write bytes, record the row, continue with the next adapter file. The `_user-customization.md` for the adapter declared a customization surface; the user has hand-edited bytes outside the markers; the rewrite is not safe; user MUST review the file manually before next ADAPTER-SYNC. The decision log row provides the diff hint.
- **ADAPTER-SYNC — `NEEDS-FULL-PHASE-4.8` outcome**: skill records the deferral; Phase 5 verification triggers a full Phase 4.8 regen for that single adapter (not the whole adapter set — bounded blast radius). The full regen uses regular Phase 4.8's logic, NOT this skill — this skill exits cleanly after recording the deferral row.

## Bypass

There is none. Every pack-added file gets a decision recorded — including LEAVE-delete (records the deletion). Phase 5.3 audits the decision log against pack-added files; any file without a decision = skill was skipped or crashed = HALT + retry.

## Why this is a skill, not inline in /setup-project

- `/setup-project` is ~5000 lines. Under context pressure, the LLM running it has historically skipped Phase 4.6 — the failure mode this skill exists to prevent.
- A skill runs in a sub-context with the inputs it needs and the contract it implements — no orchestration noise, no cross-cutting rules from setup-project's main loop.
- Phase 5.3 audit catches skill failures (decision log incomplete, anchors missing, identifiers not in extraction) — the audit + retry loop is what makes this safe to extract.
- This mirrors the Phase 2 pattern (extract-codebase-overview skill) that proved this architectural separation works.
- Round-one, round-two anchor (REFINE 4.6-DEEP + 4.7-DEEP), and round-two adapter sync (ADAPTER-SYNC for 4.8-DEEP) share the SAME skill (this one) by design. The decision matrix differs by mode but the STUDY → DECIDE → ACT discipline + leak-scan + decision log + marker safety contract are identical. One skill, three modes — keeps the safety guarantees + audit surface unified across all of round-one + round-two + adapter propagation. The adapter-sync mode is conceptually "marker-safe rewrite of derivative files" — and that's exactly what the skill already does for `.claude/{rules,commands,agents,skills}/*.md` (project-specific markers) and `ai/*.md` (refine-enriched markers); adding adapter outputs (generated markers) is a third class of derivative file with the same shape of safety contract.
