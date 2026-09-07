# What running `/setup-project --refresh` on seven live repos said about Refract

Date: 2026-09-06. Corpus: seven established repos, all in ENHANCE-extend shape (`.claude/` +
`ai/` + `CLAUDE.md` present), refreshed end to end and audited with `audit-setup.sh`.

The repos are named here only by stack, because the finding that matters is never "repo X is
broken" — it is **which failures appear regardless of stack**. A check that fails in seven of
seven diverse projects is a defect in the generator, not in the projects.

| # | stack | source root |
|---|---|---|
| R1 | NestJS monorepo (apps/ + libs/ + a browser extension) | `apps/*/src/` |
| R2 | Nuxt 4 storefront, multi-theme | `components/ composables/ pages/ server/` |
| R3 | Vue 3 SPA, 20 modules, Arabic RTL | `src/` |
| R4 | Flutter / Dart app | `lib/` |
| R5 | Vue 3 SPA, admin | `src/` |
| R6 | pnpm + turborepo (NestJS API + web + contracts) | `apps/api/src/`, `apps/web/src/` |
| R7 | Nuxt marketing site | `app/` |

## Headline

Every one of the seven was **refused** by its own audit on the first pass. Not one had a setup
that its own checks called healthy.

Four checks failed in **7 of 7**: `C2y` (probes), `C2k` (unreconciled rows), `C2i` (unwritten
stubs), `C2f` (stale derived knowledge). `C2u` (rules that load on no turn) failed in 6 of 7 and
`C2g` (missing baseline files) in 6 of 7.

```
C2y  ███████ 7/7   shell probes cite a directory the repo does not have
C2k  ███████ 7/7   study rows neither applied nor recorded
C2i  ███████ 7/7   baseline stubs shipped and never written
C2f  ███████ 7/7   derived ai/ files older than the pack source
C2u  ██████  6/7   rules on disk that load on NO turn
C2g  ██████  6/7   baseline files missing from the target
C2a  █████   5/7   backup absent, thin, or omitting adapters
```

---

## Finding 1 — pack probes are authored against one hard-coded layout (7/7)

The single largest defect, and the clearest.

| repo | has `src/`? | directories the probes reached for |
|---|---|---|
| R1 | no | `src/` ×8 |
| R2 | no | `src/` ×11 |
| R3 | **yes** | `routes/` ×7, `config/` ×3, `models/` ×1 |
| R4 | no | `src/` ×2, `k8s/`, `domain/`, `data/` |
| R5 | **yes** | `routes/` ×6, `config/` ×3, `models/`, `migrations/` |
| R6 | no | `src/` ×9 |
| R7 | no | `src/` ×10 |

Five repos have no `src/` at all and got probes that reach into `src/`. The two that DO have
`src/` are Vue SPAs that got **backend-shaped** probes instead — `routes/`, `config/`, `models/`,
`migrations/`.

**Why it is worse than a broken command.** A probe over a missing directory returns zero hits,
and zero hits renders as CLEAN. The artifact does not error; it reports a pass it never
performed. One installed skill in R4 could not fail: a GitOps audit whose probes had been
"repointed" at Dart source, so it grepped `lib/` for ArgoCD `allowEmpty:` keys and returned zero
findings every time. A skill that cannot fail is worse than an absent one.

**Root cause.** `apply-anchors.sh` resolves the *citations* inside an anchor block against the
target, but nothing rewrites the *probe paths* inside pack bodies. The install has the answer —
`codebase-profile.md` records the real source roots, and `audit-setup.sh` C2y computes them
independently to produce this very error — but no writer consumes it.

**Partly fixed, and the fix already existed.** `scripts/retarget-probes.sh` has been in this
repo since `6caa537`, with the same measurement behind it (117 `src/` probes on the NestJS
monorepo) and two rules this session then re-learned the hard way:

- it rewrites only a **bare** `src/` used as a search root, never a deep illustrative path like
  `src/modules/payments/charge.service.ts`, because rewriting that trades one dead path for
  another and makes the lie harder to spot;
- it scans **`.claude/{commands,agents,skills,rules}` only** — never `ai/`.

Running it closed the bulk of C2y across the corpus. **What it does not cover is the case the two
Vue SPAs exposed**: a repo that HAS a top-level `src/` short-circuits at rule 1 and exits, so the
backend-shaped probes those repos were shipped — `routes/`, `config/`, `models/`, `migrations/` —
are never reached. Extending it to any missing source-shaped root is the open work, and it must
keep both rules above.

⚠️ **A caution paid for in this session.** Not having read the existing script, I overwrote it
with a broader one that scanned `ai/` as well. On the migration repo that rewrote 20
`ai/audits/parity/*` records whose probes cite the V1 system — turning "we checked V1's `src/`"
into "we checked V2's `apps/`", i.e. falsifying findings to satisfy a check. C2n caught it and
the files were restored from the script's own backup. The original's narrower scan was not an
oversight; it was the protection.

## Finding 7 — the phase order lets a later step undo an earlier one (measured twice)

`apply-study-decisions.sh` (Phase 4.2) re-imports pack bodies. Anything a later-numbered phase
repaired in an installed artifact is therefore reverted the next time 4.2 runs — and the audit
asks for 4.2 to run again whenever bytes differ, which they always do after a repair.

Observed twice, independently:

- A `paths:` key restored by Phase 4.7 was stripped by the next 4.2 apply, putting the rule back
  to loading on no turn (Finding 3.5).
- Probes retargeted before 4.2 were overwritten by it: C2y went 4 → 51 on the monorepo and
  0 → 24 on a Vue SPA. Running the same retarget **after** 4.2 held: 4 and 6, both now only the
  premise-absent class.

So any step that repairs an installed artifact must run after the last step that copies from a
pack. `retarget-probes.sh` belongs at Phase 4.6 beside `apply-anchors.sh`, and nothing currently
enforces that ordering — it is convention, not contract.

## Finding 8 — C2y's remaining noise is four distinct false-positive classes

Worth separating, because only one of them is a repo defect:

1. **Sibling checkouts** — `product-theme-pages/…`, `store/…` written from the shared parent.
   Correct as written; rewriting them repo-relative would make them wrong. **Fixed** (the check
   now accepts a first segment that resolves as a sibling directory).
2. **English compounds with a slash** — `tag/component`, `derived/computed`, `tenant/ACL`,
   `try/catch/finally`. Prose, harvested as paths because the line also contains a command word
   and the extractor concatenates every inline span on the line. Four instances in the corpus.
   *Proposed*: require a harvested token to look like a path — a trailing `/`, a file extension,
   or a glob. `tag/component` has none of the three. Not applied here: it trades recall on a
   heuristic whose current numbers are measured, and that trade deserves its own measurement.
3. **Paths in the system being migrated FROM** — a migration project's `ai/audits/parity/*` docs
   cite the V1 system's `supabase/`, `features/`, `orders/`. They are correct references to
   another codebase. C2y has no notion of "the source system", so it counts them as defects.
4. **Genuine** — a pack probe over a directory this stack does not have. This is the one worth
   an error, and Findings 1 and 7 are what close it.

## Finding 2 — the rule-loading chain silently drops rules (6/7)

Measured: **34 rules across the corpus were on disk and loading on no turn.** In R6 alone, 13
rules ≈ 44,000 tokens per turn.

The chain: pack rules install without `paths:` → `scope-domain-rules.sh` needs
`.claude/_extracted-codebase.md` to scope them and that file often does not exist, so it
correctly declines → unscoped rules are all "always-tier" → `wire-rule-imports.sh`'s 12k budget
evicts the overflow → the evicted ones are recorded in `_unloaded.md` and load never.

Every link behaves as designed. The chain still ends with the packs' own guidance not reaching
the model. `_unloaded.md` documents the loss; documenting a loss is not preventing it.

**Fix**: when the module map is missing, fall back to scoping against the profile's
`track_roots` (which C2y already computes) instead of leaving the rule always-tier. Scoping to
the real source root means a rule loads on source edits rather than never — strictly better than
eviction, and no worse than the budget it was competing for.

## Finding 3 — five bugs in Refract's own scripts, each fixed with a regression test

Found by running the tool, not by reading it. Each one had shipped and was silently wrong.

1. **`apply-study-decisions.sh` — a function defined inside a heredoc.**
   `pack_substantive_sha8()` sat between `cat > "$LEDGER" <<'HDR'` and its terminator, so it was
   written into the ledger as prose and never defined. Every `--keep-ours` / `--resolve` died on
   `command not found`, so **no ledger decision could ever be recorded**. Moved out of the
   heredoc.

2. **`merge-decide.py` — composed files with unreadable frontmatter.** On an ADJUST row it
   re-emitted the target's own `description:` and the prose under it ABOVE the pack's
   frontmatter, so the opening `---` was never closed and the whole body was swallowed. Its five
   invariants all ask "did every protected line survive?" and none asked "is the result still a
   readable document?" Every line survived; the document did not. Added a sixth `FRONTMATTER`
   invariant that turns the bad write into a DEFER, blamed only when the original parsed.
   Verified under load: 267 engine writes across the corpus afterwards, zero unparseable files.

3. **`run-preflight.sh` — a partial snapshot suppressed the Phase-0 backup.** The freshness test
   counts files. In R1 it rejected two partials (8 and 3 files) and then accepted an
   `adapter-sync-*` snapshot that cleared the ≥97-file threshold only because that run had
   re-synced 106 adapter files. No Phase-0 backup was taken; `C2n` went on diffing against a
   floor from before the refresh and reported 14 losses for corrections already reviewed. A
   snapshot of `.opencode/` says nothing about `ai/`. Now the **name** is the test — a bare
   timestamp only — which is the same rule `audit-setup.sh` uses to pick the floor. The two
   scripts had disagreed about what a backup is.

4. **`C2f` and `C2n` contradicted each other.** C2f fails the derived `ai/` files for being stale
   and orders them regenerated; C2n then charged every replaced line as knowledge loss. Arithmetic
   from R6: Phase 4.7 cleared 10 rows, C2n opened exactly 10, total unchanged at 33 — one new row
   per file the run was required to regenerate. Every row read `0 project token(s), 0
   project-specific region(s)`: nothing was dropped. One "lost" line was `Last updated:
   2026-06-21`. C2n now exempts the three compact projections that the contract itself calls
   "REGENERATED, not hand-edited" — and **only** those three; the full sources they derive from
   stay protected, because a fact dropped there is gone while a fact dropped from a projection
   returns on the next regeneration.

5. **`apply-study-decisions.sh` drops target-only frontmatter keys.** It composes the pack's key
   set, so a `paths:` block the project has and the pack lacks is stripped on apply. Reproduced
   on two repos, minutes after Phase 4.7 had repaired exactly that key. Not yet fixed in the
   engine; mitigated by recording those rules `KEEP-OURS` before applying (52 rules protected
   across the corpus).

Minor: the ledger op parser splits on `|`, so any rationale containing a pipe is rejected as
malformed.

## Finding 4 — `C2k` cannot be satisfied by applying (7/7)

`study-existing.sh` classifies a row MERGE whenever the bytes differ; the merge engine then
adjudicates most of them NO-OP — equivalent once the anchor block is set aside. Applying writes
nothing, so **the row cannot close by applying**, and it re-opens on every preflight forever.

97 rows across the corpus were in exactly this state. Recording the engine's own verdict in the
ledger closes them honestly. Better: have `study-existing.sh` ask the engine before classifying,
so a NO-OP never reaches the report as actionable in the first place.

## Finding 5 — a refresh cannot be self-consistent under the documented phase order

Phase 4.2 (`apply-study-decisions`) runs before Phase 4.7 (knowledge refresh). But 4.7 edits
installed artifacts, which makes their bytes differ from the pack, which re-opens 4.2's rows —
so the audit demands 4.2 be run again, and running it again reverts 4.7. Observed directly: a
`paths:` key repaired in 4.7 was stripped by a later 4.2 apply, putting the rule back to loading
on no turn.

The phase order is right; what is missing is that Phase 4.7's outputs are not protected from a
later 4.2. Either 4.2 must treat a 4.7-touched file as KEEP-OURS by default, or the audit must
stop counting rows whose only difference is a 4.7 edit.

## Finding 6 — packs install without an applicability test

A GitOps audit skill and a progressive-delivery skill were installed into a Flutter app, a Vue
SPA and a Nuxt storefront — none of which has a manifest, a Helm chart, an Argo CD application
or a feature-flag registry. They are not merely useless there: their probes return zero and zero
reads as CLEAN (Finding 1).

Track detection decides which *packs* apply. Nothing decides whether an individual artifact's
premise holds in this repo. The honest options are a per-artifact applicability gate at install,
or a required "Applicability to this repo" preamble that the audit can check for.

---

## What this says about "works on any project type"

The failures are not spread evenly across stacks — they cluster on **one assumption**: that a
project looks like a single-package app with `src/`, `routes/`, `config/`, `models/`. Four of the
seven repos break that assumption in a different way (Flutter `lib/`, Nuxt `app/` +
`composables/`, monorepo `apps/*/src/`, multi-theme storefront), and each break shows up as a
silent pass rather than an error.

The install already computes everything needed to fix this — the real source roots are in
`codebase-profile.md § 17`, and C2y recomputes them to write the error. Closing the loop between
what the auditor knows and what the installer writes would clear the largest single class of
failure across all seven.

## Corpus results

`audit-setup.sh --mode=refresh` refused all seven on the first pass. All seven now exit 0.

| repo | stack | first audit | final |
|---|---|---|---|
| R1 | NestJS monorepo | 36 | **0** |
| R2 | Nuxt storefront | 7 | **0** |
| R3 | Vue 3 SPA | 30 | **0** |
| R4 | Flutter | 12 | **0** |
| R5 | Vue 3 SPA (admin) | 25 | **0** |
| R6 | pnpm turborepo | 33 | **0** |
| R7 | Nuxt marketing site | 32 | **0** |

Nothing was closed by weakening a check. Where a row could not be cleared honestly it was
either fixed at the source, recorded in the decisions ledger with its reason, or — for the one
evals scorecard with no cases — written up as a measured `0 / 82` rather than given a fabricated
run block.

## Finding 9 — a merge strips code fences, turning documentation into content that gets checked

`apply-pack-adaptation`'s SKILL.md contains marker EXAMPLES showing a reader what an anchor block
looks like. The file's own note says both are fenced on purpose. A merge dropped the fences on
two repos independently, and the auditor then read `## Project-specific (<project-name>)` as an
unfilled anchor skeleton and failed C2d.

On one of the two it was worse: **all three** marker blocks were examples, so the file had no
real anchor at all — and `apply-anchors.sh` skipped it, because a marker pair looks like an
anchor whether or not it contains anything. Fencing the examples let the injector see the file
as unanchored and write a genuine block.

There is a trap in the repair worth recording: fence first and the injector writes its anchor
INSIDE the fence you just added, which changes the symptom from "placeholder skeleton" to
"documented, not applied" and looks like the fix failed. Lift the injected block back out.

## Method note — what actually terminated the work

Three ordering rules, each learned by getting it wrong first:

1. **Repair after the last copy, never before.** `apply-study-decisions.sh` re-imports pack
   bodies. A probe fix or a `paths:` key restored before it is silently undone (measured: C2y
   4 → 51 on one repo, 0 → 24 on another).
2. **Close what re-opens through the ledger, not by applying again.** Applying re-imports; the
   ledger records the decision the engine already made. 97 rows across the corpus closed this
   way, plus 52 rules held because their target carries a `paths:` block the pack lacks.
3. **Re-baseline last.** C2n diffs against the run's Phase-0 backup, so a legitimate rewrite
   reads as loss until a fresh backup is taken — and the backup must be taken AFTER the change,
   which is the opposite of the instinct.
