---
artifact: rule-7-phase-4-6-file-adaptation
purpose: Per-file adaptation procedure for Phase 4.6. Loaded ONLY during apply. Excluded from agent default context.
---

### Rule 7: Phase 4.6 (study + decide per-file) is MANDATORY, not optional

Pack-added files (rules + agents + patterns + skills copied via Phase 4.2 / 4.4 / 4.4b) start out GENERIC — they cite hypothetical bases (e.g. "the project's `<service-base>` / `<repository-base>` / `<controller-base>`" with placeholders). By this point in the run you have the BIGGEST possible picture of the codebase (Phase 0 extract, Phase 2 profile, Phase 2.5 idioms, business-domain detection, ADRs, failure catalog, prior conventions). Phase 4.6 is where you USE that picture to make judgment calls per-file: **does this pack file align with the project? If not, what specifically needs to change to align it?** The replacement values come from extraction — never from any other project's run.

### `<TBD: …>` stack-placeholder vocabulary (Phase 4.6)

Universal-style docs must not pin to a single frontend/backend/mobile stack. Either enumerate multiple stacks in one breath **or** leave a typed placeholder for Phase 4.6 / 4.6-DEEP to substitute from `.claude/_extracted-codebase.md` and `.claude/_extracted-idioms.md`. Recognized tokens (extend only with CHANGELOG + `audit-stack-leakage.sh` allowlist updates):

| Token | Meaning |
|---|---|
| `<TBD: tab-primitive>` | Tab UI component for the project (e.g. Vue `<v-tabs>` · React `<Tabs>` / `<TabView>` · Svelte tab containers · Angular `<mat-tab-group>`). |
| `<TBD: form-input>` | Bound input primitive (`<v-text-field>`, `<TextField>`, `<input>`, …). |
| `<TBD: form-state-helper>` | Form state library (vee-validate, react-hook-form, Formik, Angular Reactive Forms, …). |
| `<TBD: store>` | Client/app store (Pinia, Redux, Zustand, NgRx, …). |
| `<TBD: router-file>` | Router module (`routes.ts`, Next `pages/` / `app/`, SvelteKit `+page`, Angular routing module, …). |
| `<TBD: iteration-construct>` | List iteration (`v-for`, `.map(…)`, `{#each}`, `*ngFor`). |
| `<TBD: conditional-construct>` | Conditional render (`v-if`, JSX `&&`, `{#if}`, `*ngIf`). |
| `<TBD: framework-mount-hook>` | Mount/init hook per framework (`onMounted`, `useEffect(..., [])`, `onMount`, `ngOnInit`, …). |
| `<TBD: framework-effect-hook>` | Reactive/effect hook per framework (`watch`, `useEffect`, Svelte reactive blocks, RxJS pipe, …). |

**Optional banner** for swept markdown (YAML frontmatter blockquote or first paragraph after frontmatter):

```markdown
> **STACK-AGNOSTIC**: Inline syntax in this doc is illustrative. Stack-specific
> primitives are filled by `/setup-project` Phase 4.6 from the project's
> `_extracted-codebase.md` / `_extracted-idioms.md`. `<TBD: ...>` placeholders
> survive until then.
```

`scripts/apply-anchors.sh` counts `<TBD:...>` tokens per injected file and adds a **Stack placeholders pending** line inside the auto-generated `## Project-specific` block; Phase 4.6-DEEP (`apply-pack-adaptation`) replaces tokens using extraction.

**The historical bug**: under context pressure, the LLM running `/setup-project` "saves time" by skipping Phase 4.6 — the user opens the regenerated `.claude/rules/<name>.md` and finds it talks about generic `<concept>` patterns instead of the project's actual `<project-base-class>` base class. The user correctly says "you didn't adapt — you just copied templates." This is the failure mode this rule exists to prevent.

**The contract — STUDY → DECIDE → ACT, per file**:

For each pack-added file, the LLM MUST:

1. **READ the file** (the generic pack content).
2. **READ the relevant project context** — `.claude/codebase-profile.md`, `ai/conventions.md`, `ai/business-domain.md`, `ai/_decision-index.md`, `ai/failures/_index.md`, project-authored patterns at `ai/patterns/`, project-authored agents/rules/runbooks. (You have this loaded already from Phase 0 + Phase 2.)
3. **DECIDE one of three actions** based on the bigger picture:

   | Decision | When | Action |
   |---|---|---|
   | **CHANGE (anchor + inject)** | Pack file is generic but topic IS load-bearing in this project (e.g., `database-principles.md` for a multi-tenant project with custom repository base). | Prepend `## Project-specific (<project-name>)` block citing real paths, base classes, project idioms, ADRs, failures. Body stays. |
   | **CHANGE (anchor + warn)** | Pack file's generic guidance CONFLICTS with project (e.g., pack says "use `<framework-idiom>`" but project has `ai/failures/<NNNN>` saying NEVER use it). | Anchor block must explicitly OVERRIDE the conflicting body section. Add "**Conflicts with generic body**:" sub-block calling out the specific conflict + the project's resolution. |
   | **LEAVE** | Pack file is for a concern not present in this project (e.g., `gitops-principles.md` in a non-GitOps project) OR the project already has a richer project-authored equivalent (e.g., project has `ai/patterns/data-access.md` 130+ lines + `.claude/rules/database.md`, so `database-principles.md` from pack is purely supplementary). | Either delete the pack file OR add a 3-5 line note at top: "This project's primary guidance is `<project-file>`. The generic pack content below is supplementary background only." |

4. **ACT on the decision** — write the file. Then move to the next.

**The judgment, not the injection, is the value-add.** A blanket "prepend anchor everywhere" misses the cases where the project HAS a better project-authored equivalent (in which case the pack file is noise) or where the pack file should be deleted entirely (off-topic for this project). A blanket "leave everything as-is" misses the cases where injection is critical for usefulness. The right answer is per-file judgment with the bigger picture.

**Per-mode behavior — Phase 4.6 fires in EVERY mode, only the depth differs**:

| Mode | Source of project context | Anchor depth |
|---|---|---|
| **CREATE** (greenfield, no source yet) | The user's prompt + any manifest hints (package.json description, declared stack) + business-domain detection from prompt + chosen track packs. NO codebase to detect from yet. | **Lighter anchor** — cite prompt-declared mission/domain/stack/anti-goals, business-domain entities (from `~/.claude/templates/business-domains/<domain>/glossary.md`), planned base classes per chosen architecture (e.g., "this project will use Clean Architecture per `<framework>` conventions"). Anchor flags `_TBD — populate as code is written_` for facts not yet knowable. Phase 6 `/refresh-knowledge` re-anchors once code exists. |
| **ENHANCE-retrofit** (source exists, no `.claude/`/`ai/` yet) | Phase 2 codebase profile (real base classes detected, real paths, real extender counts, real conventions, real signals) + business-domain detection from entity names/folders/deps. | **Full anchor** — cite real base class paths + extender counts + actual file paths + detected naming + detected signals + business-domain facts. This is the strongest case for Phase 4.6 — the codebase is rich, no prior `.claude/` to compete with, packs land cleanly with project-aligned anchors. |
| **ENHANCE-extend** (source + `.claude/` + `ai/` all exist) | Phase 2 profile + extracted prior knowledge (existing custom rules/agents, prior conventions, prior ADRs). | **Full anchor** — same as retrofit, PLUS cross-reference any project-authored equivalent. If project has a richer agent/rule for the same concern, decision tilts to LEAVE-with-redirect (don't compete with it). |
| **REFRESH** (forced regen with prior knowledge) | Phase 0.2 extract (prior insights) + Phase 2 profile (re-detected) + extract-base-class-idiom output (Phase 2.5). | **Richest anchor** — uses everything: real codebase + extracted project idioms + ADR rationale + failure-catalog. This is the highest-fidelity adaptation path. |

**The constant across modes**: Phase 4.6 is mandatory. The DECISION (CHANGE-anchor / CHANGE-anchor-with-warn / LEAVE-with-redirect) is made per-file, in every mode, with whatever context is available. CREATE-mode anchors may be thinner (5-10 lines instead of 20-40), but they MUST exist — even a thin anchor citing "this project's stack is X, planned base classes are Y, anti-goals are Z" beats a generic pack file with zero project context.

**Why this matters for CREATE mode specifically**: a greenfield project that just received a generic `.claude/rules/database-principles.md` (zero anchor) will accumulate code that DRIFTS from the project's actual emerging conventions, because the rule has no "this is what THIS project does" guidance. The anchor — even a 5-line one citing the planned architecture — establishes a fixed point. Phase 6 `/refresh-knowledge` then enriches it as code accumulates.

**Adapt** (when CHANGE-anchor decision is made) — prepend a `## Project-specific (<project-name>)` block citing:
- Real file paths (base class locations from `.claude/codebase-profile.md`)
- Real base class names (with extender counts proving they're load-bearing)
- Real project idioms (project-specific decorators, configuration patterns, naming quirks)
- Cross-references to relevant ADRs / patterns / runbooks / failure-catalog entries
- Project-specific anti-patterns / failures (from `ai/failures/_index.md` if relevant)

Generic body BELOW the anchor block stays untouched — the anchor adapts WITHOUT replacing the universal guidance.

**Wrong** (the generic-template-shipped pattern):
```
.claude/rules/database-principles.md (after refresh)
─────────────────────────────────────────────────────
