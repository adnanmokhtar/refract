# Handoff edge-integrity baseline

`scripts/lint-handoffs.sh` is the **edge** gate. The other 18 gates verify the *catalog* — they
count (`verify-readme-stats`, `verify-pack-matrix`, `check-rule-budget`), they check that a path
*exists* (`validate-pack-consistency` check 3 stats a `fallback:` path and never opens it), or they
compare two catalogs of *names* (`lint-tool-parity`, `lint-overlay-catalog`, `verify-doc-sync`).
None of them opens a cited file to ask whether the claim made *about* it is true. That gap produced
one recurring defect class across eight review passes:

> **File A states a property OF a named artifact B. The property is decidable by opening B.
> Nothing opens B.**

This file is the ratchet for the four rules that now close it. Known violations listed here are
suppressed into one counted summary WARN; anything **not** listed is a hard FAIL.

## Working with this file

- **Repairing a citation** → fix it, then delete its line here. The gate WARNs on a line that no
  longer reproduces ("no longer reproduces — drop its line"), so a stale entry cannot linger.
- **Adding a line** → only for a violation you have looked at. Say why in the trailing comment —
  **the reason is mandatory and mechanically enforced**: a line with no `# reason` suppresses
  nothing, the finding stays red, and the gate WARNs that the line is inert. A line added to
  silence a finding you did not read is the failure mode this gate exists to prevent.
  (`tests/validators/lint-handoffs.sh/bad/baseline-without-reason/` pins that behaviour.)
- **`REPAIR:` is not the same as accepted.** A reason beginning `REPAIR:` records a defect whose
  fix is known and pending, not a state anyone has blessed. Those lines are counted separately in
  their own WARN and under `--handoff-report`, because a baseline seeded on day one is exactly how
  baselining becomes the normal response. Every `REPAIR:` line below carries the concrete fix.
- Format: `<key>  <RULE>  # reason`, one per line, key space-free. Rules:
  `SKILL-INPUT` · `SECTION-ANCHOR` · `NAME-DRIFT` · `SCAFFOLD-ORDINAL` (see the header comment in
  `scripts/lint-handoffs.sh` for what each one measured and what it cannot see).
  Keys are `<citing-file>::<target>::<slug>` for SECTION-ANCHOR, `<prose-name>::<script-name>`
  for NAME-DRIFT, `<citing-file>::<skill>::<key>` for SKILL-INPUT, and
  `<citing-file>::<artifact>::<ordinal>` for SCAFFOLD-ORDINAL. No line numbers, deliberately:
  a citation that merely moves down a file is the same citation.

**The backlog is 8 lines — 0 of them `REPAIR:`.** If a comment anywhere in the repo advertises a
different number, that comment is stale; this file is the authority. **Both numbers are checked
against the entries below on every run** and the gate FAILs when they disagree, so this sentence is
a contract rather than a note: it cannot rot into a worklist that is not there, and a ledger read
short says so by name instead of silently un-suppressing its missing entries. **Both numbers are checked
against the entries below on every run** and the gate FAILs when they disagree — this sentence is
a contract, not a note, so it cannot rot into a worklist that is not there. The same check is what
makes a ledger truncated mid-write say so by name, instead of silently un-suppressing its missing
entries and surfacing as a batch of ratcheted defects going red with nothing to explain them.

`SKILL-INPUT` and `SCAFFOLD-ORDINAL` have **no lines and no section here**, because they are green
at HEAD `5ffd22b` (0 findings each). Do not create empty sections for them — an empty section reads
as an invitation.

## Backlog

```
templates/tool-adapters/_memory-recall-coverage.md::commands/setup-project-adapters.md::phase-4-8-0-marks-eight-tools          SECTION-ANCHOR  # KEEP: the number IS resolvable - setup-project-adapters.md:33-39 publishes the map itself ("Phase 4.8 / Phase 4.8.0 -> **Phase B - Per-adapter completeness contract**") under a heading that says in as many words "when another doc points at a number, resolve it here". What the gate cannot do is follow a published redirect; the citation is correct as-is. Revisit if the anchor set ever learns to resolve through that table.
templates/tool-adapters/_registry.md::commands/setup-project-adapters.md::phase-4-8-0                                          SECTION-ANCHOR  # KEEP: identical case to _memory-recall-coverage.md above, same published map at setup-project-adapters.md:33-39. Correct as-is.
_arch.md::_anchors.md                                       NAME-DRIFT  # KEEP: distinct artifacts. `ai/audit/_arch.md` is the audit architecture sub-wave's output (commands/audit.md:184, emitted by the `architectural-diagnosis` skill); `_anchors.md` is align's anchor ledger. The 0.74 similarity is four shared letters, not a drifted spelling.
_domain-coverage-report.md::_pack-coverage-report.md        NAME-DRIFT  # KEEP: `_domain-coverage-report.md` DOES have a writer - an inline shell snippet inside the phase itself (templates/phases/phase-4.2-apply.md:343, `: > "$TARGET_REPO/.claude/_domain-coverage-report.md"`). The rule's writer population is scripts/*.{sh,py}; a phase-embedded emitter sits outside it by construction. Distinct from the pack coverage report.
_extracted-business.md::_extracted-codebase.md              NAME-DRIFT  # KEEP: three separate extraction artifacts, all written by skills rather than scripts - `_extracted-codebase.md` (the technical picture), `_extracted-idioms.md` (idioms), `_extracted-business.md` (the WHY, from the `extract-business-context` skill, templates/phases/phase-2-profile.md:160). Not a misspelling of each other.
_phase-1-decisions.md::_phase-4-6-decisions.md              NAME-DRIFT  # KEEP: one decision log per phase, by design. `ai/decisions/_phase-1-decisions.md` holds Phase 1's ADR drafts (docs/REFERENCE.md:385); `_phase-4-6-decisions.md` holds Phase 4.6's anchoring rows. The 0.91 similarity is the shared naming convention working as intended.
_refine-extract.md::_refresh-extract.md                     NAME-DRIFT  # KEEP: genuinely different artifacts of genuinely different modes. `_refresh-extract.md` is written by scripts/refresh-extract-checklist.sh:44 for --refresh; `_refine-extract.md` is produced by the REFINE-mode phases 2.7-2.12 and is a hard prerequisite for apply-pack-adaptation in REFINE (SKILL.md:534). No script writes it because no script is meant to.
_setup-history.md::_history.md                              NAME-DRIFT  # KEEP: `ai/_setup-history.md` is the append-only per-run log every /setup-project writes in the TARGET repo (templates/observability.md:9). `_history.md` is the migration detector's file. Different repos, different writers, different lifetimes.
```

## Not in the ratchet, deliberately

Each of these was measured over the whole tree before it was rejected. The numbers are recorded
here so the next person does not re-derive them and reach a different conclusion by accident.

- **`_topics.md` `sections:` vs fallback headings.** The tempting one: a topic declares
  `sections: [persona, halt_conditions, …]` and a `fallback:` path, and `validate-pack-consistency`
  check 3 confirms that path exists without ever opening it — precisely the gap this gate exists
  to close. But `sections:` is a *semantic content spec for AUTHOR mode*, not a heading spec.
  Measured across all 293 topic/fallback pairs: **1004 misses across 232 pairs (79%)**, top misses
  `output_format` ×83, `persona` ×82, `overview` ×53, `examples` ×34, `pitfalls` ×28. Check 8b of
  `validate-pack-consistency.sh` records the identical measurement for the identical rule (221 of
  293, 75%) and concludes *"a gate that flags half the corpus gets muted, and a muted gate is worse
  than none."* Downgrading to WARN does not fix it — 1004 WARNs is the mute button with extra steps.
  **Not implemented at any severity.**
- **Assertive-citation polarity.** Two of the six original instances are polarity flips: a sentence
  that cites a section and then asserts the opposite of what the section says. Both are **repaired
  in this change set** — `commands/do.md:116` now resolves by the remedy, not "by the noun" — and
  the rule still does not enter the ratchet, because repairing the instances did not narrow the
  blind spot. The candidate population — a line carrying a `§` or "per the … note|table|rule"
  citation *and* a modal (`must|never|always|only|forbidden|refuse|halt`) — is **525 lines** at
  `5ffd22b`, and no shell rule separates a contradicting one from the rest. There is a tempting
  shortcut: grep the phrase the two instances shared, "by the noun". **Do not ship that.** After
  the repair that phrase survives in exactly one non-self file —
  `templates/tool-adapters/_orchestration-sync.md:33`, where it asserts the *correct* polarity
  ("never by the noun") — so the grep now matches nothing but a true statement, which is the
  plainest possible demonstration that it was never measuring the defect. A grep tuned to a defect
  already found proves nothing about the next one, and is precisely how a gate earns distrust.
- **Bare-basename `§` citations.** Three options were measured, not two. (a) Full repo path only —
  88 citations checked. (b) **Unique path suffix, `/` still required** (`frontend/rules/migration-frontend.md`
  → the one repo file that ends with it). This is the middle option, and it is **IMPLEMENTED**: it
  moved the checked population 88 → 127 and produced 8 findings, every one hand-opened, every one a
  real dangling anchor, all repaired in the change that added it. It was worth naming as its own
  option because it is neither of the two extremes and it cost nothing. (c) Unique *basename*, no
  `/` — **rejected, and here is the count that decides it**: of the 843 bare-basename citations,
  **532 name no repo file at all** (overwhelmingly the *consuming project's* files, which a pack is
  supposed to talk about) and **168 name a basename several repo files carry** (`SKILL.md`,
  `_topics.md`, `CHANGELOG.md`, `adapter.md`). Only **143** are unique in this tree. Resolving on
  "unique basename" would therefore apply a rule the corpus contradicts five times in six. The line
  the gate draws is: a target is checked when the citation *identifies* it, skipped when it merely
  *names* it.

## What a green run does NOT mean

Every rule here compares text against text and understands neither side. It decides whether a named
thing **exists** where the citation says it does; it never decides whether what is there **says**
what the citing sentence claims. A citation that states the *opposite* of the section it points at
passes. A section rewritten under the same heading passes. A counted fidelity claim ("keeps every
halt condition, every invariant, every row") is not evaluated at all. The full list is under
`WHAT THIS GATE CANNOT SEE` in the `scripts/lint-handoffs.sh` header. Treat a green run as a floor
on edge integrity, never as a certificate that a citation still means what it meant.

`scripts/lint-handoffs.sh` and this file are both excluded from every scan the gate performs. This
ledger quotes the defects it records verbatim, so scanning it would re-detect what it exists to
record; and the script's header names `_refresh-knowledge-extract.md` — the original NAME-DRIFT
instance — which would otherwise enter the rule's script-name set and blind it to its own
regression.
