# `_topics.md` fallback-strategy ledger

Every topic in a pack's `_topics.md` declares a `fallback:` — the strategy `phase-4.2-apply.md
§ 4.2-AUTHOR step 2` uses when extraction finds NO signal for that topic. Two values are legal: a
**path** inside the pack (the file is copied verbatim — see `_fallback-baseline.md` for the gate on
what that file may say), or the literal **`stub-from-sections`**, which
`templates/phases/phase-4.2-apply.md:26` defines as "emits a sectioned stub from that topic's
`sections:` list". That sentence is the only definition of the sentinel anywhere in the tree; there
is no skeleton template and no second definition.

Check **3b** of `scripts/validate-pack-consistency.sh` gates the strategy, where check 3 gates only
whether the value resolves. It asks one question: **can the strategy this topic names deliver
anything at all?**

- **`STUB-NO-SECTIONS` — hard FAIL, and it is NOT ledgerable.** The sentinel with no **non-empty**
  `sections:` list. The stub is built FROM that list, so a missing key, a `sections: []`, and a
  bare `sections:` with nothing under it are the same thing: an **empty file** — usually with a
  finished artifact of the same name sitting beside it on disk. (The check used to test for the
  *presence of the key* while its own finding text said an empty list emits nothing, so both empty
  spellings passed. It counts the items now, in both the inline `[a, b]` and the block `- a`
  form.) There is no legitimate instance,
  so there is nothing for a reader to decide and nothing to suppress; a line below claiming to
  suppress one WARNs and suppresses nothing. This defect recurred **five times** — `security`
  (its `CHANGELOG.md:87`), `infrastructure` (`CHANGELOG.md:106`), `distributed-systems`, the eight
  skill topics across `data-engineering` and `finops`, and finally `observability`'s four
  (`add-metrics`, `add-tracing`, `alert-design`, `slo-audit` — 855 finished lines the topics were
  refusing to deliver) — because each occurrence was hand-repaired and none was gated.
- **`STUB-OVER-SOURCE` — FAIL if new, ledgered here.** The sentinel where a finished artifact of
  the same `kind:` and name already ships in the pack. That is a judgement call: a pack may
  genuinely prefer a neutral skeleton the project fills in to a generic file it did not write. So
  it is ratcheted rather than banned. Anything **not** listed below is a hard FAIL.

Nothing downstream catches either one. `phase-4.0-preflight.md:495-510` measures the **pack
source**, never the emitted file; `:561` counts **files**, and a 0-byte file counts as present;
`phase-5-verify.md:185-220` covers only the foundational `ai/` set and says so at `:187`. The size
of an emitted pack artifact is measured nowhere. This ledger is the last place it is visible.

**The ledger is 5 entries.** If a comment anywhere advertises a different number, that comment
is stale — this file is the authority, and check 3b FAILs when the sentence and the entries
disagree.

## Working with this file

- **Repairing a topic** → point its `fallback:` at the artifact that already ships, then delete its
  line here. The gate WARNs on a line that no longer reproduces ("no longer reproduces — drop its
  line"), so a stale entry cannot linger.
- **Adding a line** → only for a `STUB-OVER-SOURCE` you have looked at and decided is correct.
  Say why in the trailing comment — **the reason is mandatory and mechanically enforced**: a line
  with no `# reason` suppresses nothing, the finding stays red, and the gate WARNs that the line is
  inert.
- **Regenerating** → `bash scripts/validate-pack-consistency.sh --record-strategy` rewrites the
  block below from what reproduces now, carrying existing reasons over verbatim. A newly recorded
  line is written **without** a reason and therefore suppresses nothing until a human writes one.
  A `--record` that could silence an unread finding would be the mute button this ratchet exists
  to prevent.
- **Reviewing coverage** → `--coverage-report` prints every ledgered entry plus the per-pack
  greenfield coverage table. Those percentages are reported and never gated: measured across the
  23 packs the line ratio runs 48-100% with no gap in it, and it **inverts** against harm —
  `ai-engineering` is second-worst at 50% with zero zero-delivery topics (its gap is deliberate
  abridgement), while `observability` sat mid-table at 72% while four of its topics delivered an
  empty file. `_fallback-baseline.md` § "Not in the ratchet, deliberately" made the same call for
  length ratio.
- **What replaces the percentage** → the **count** of zero-delivery topics per pack, recorded in
  [`_greenfield-budget.md`](_greenfield-budget.md) and regenerated with `--record-budget`. It may
  not grow. This is worth being precise about, because this file previously claimed the count was
  gated when nothing gated it: the two rules above catch a sentinel with no sections and a sentinel
  standing over a shipped artifact, but a sentinel that declares `sections:` and has **no** artifact
  of that name fires neither — so a pack could add unlimited zero-delivery topics and stay green,
  which is exactly the failure the coverage discussion exists to prevent. The count is
  padding-proof where the percentage is not: nothing you *add* lowers it. Its ceiling — per-pack
  granularity, so a repair-plus-regression inside one pack nets to zero — is stated in the budget
  file.
- Format: `<pack>/<topic>  STUB-OVER-SOURCE  # reason`, one per line.

## Ledger

```
infrastructure/audit-iam           STUB-OVER-SOURCE # 246 lines of provider-specific policy grammar; a project whose IAM provider was not detected receives guidance for the wrong provider. Sections declared, so the outline still lands.
infrastructure/cost-audit          STUB-OVER-SOURCE # 248 lines keyed to a billing surface (tags, reservations, egress lanes) that only extraction can name; the skeleton preserves the audit's section order and lets AUTHOR mode fill it from the actual bill. Revisit if the command is ever rewritten cloud-agnostically.
infrastructure/multi-region        STUB-OVER-SOURCE # the pattern is 197 lines of AWS/GCP/Azure-specific region topology; a project on one cloud that fails region detection is better served by its own section skeleton than by a three-cloud narrative it must delete. `sections:` is declared, so the stub is a real outline, not an empty file.
infrastructure/provision-tier      STUB-OVER-SOURCE # 314 lines built around a tier ladder (dev/stage/prod sizing) whose numbers are wrong for every project that does not share this pack's assumed shape; a stub with the tier headings is the honest delivery.
infrastructure/tf-plan-review      STUB-OVER-SOURCE # the skill is 191 lines of `terraform plan` output parsing; on a project where no Terraform was detected the sentinel is what keeps a Terraform-shaped skill from being installed as fact.
```

## Not in this ledger, deliberately

- **`backend`'s nine sentinel topics** (`data-access`, `base-service`, `controller`, `mapper`,
  `dto-validation`, `database`, `dtos-mappers`, `controllers`, `events`) never fire either rule:
  they declare `sections:` and **no** artifact of that name ships in the pack, which is the
  sentinel's legitimate use and is documented on purpose at `backend/_topics.md:26`. That is the
  discrimination a per-pack exception list would have destroyed — the check separates the
  legitimate use of the sentinel from the abuse of it without one.
- **Coverage percentage at any severity** — see "Reviewing coverage" above.
- **`testing/tdd`, removed from the ledger 2026-08-23 by repairing it rather than re-wording it.**
  It was the weakest of the six entries: a 3-item `sections:` list (`[understand, dispatch,
  surface]`) against a 98-line source, i.e. three empty headings — the closest thing in the ledger
  to the empty-file harm the whole check exists to prevent. Its stated reason ("the source reads as
  a generic tutorial when copied cold") did not match the file: `testing/commands/tdd.md` is a thin
  dispatcher that says outright "the discipline lives in the agent", and its Phase 2 carries the
  `RED-UNOBSERVABLE` substitute-proof rule for criteria that cannot be made to fail on demand
  (security and concurrency ones, disproportionately) — which the skeleton discarded. There is
  nothing project-specific in it to get wrong, so its `fallback:` now names `commands/tdd.md` and a
  no-signal project gets all 98 lines. See `_fallback-baseline.md` § "Source-as-fallback is a
  trade" for what that costs.
