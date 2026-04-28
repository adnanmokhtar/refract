---
phase: 4
sub-phase: "4.7-DEEP"
name: refresh-ai-knowledge
applies-to-modes: [REFINE]
inputs: [.claude/_refine-extract.md (deep findings), existing ai/ knowledge base]
outputs: [updated ai/conventions.md / ai/patterns/ / ai/business-flows.md (managed sections only)]
exit-criteria: every deepened finding mapped into the right ai/ file; user-authored sections preserved verbatim
imported-by: templates/phases/phase-4-apply.md
---

### Phase 4.7-DEEP — Refresh ai/ knowledge base from deep extraction (REFINE mode only)

**Trigger**: REFINE mode AND ≥1 deep-extraction phase was STRONG (not all WEAK).

**Mechanism**: enrich (not replace) the auto-generated portions of `ai/` files using the deep-extraction substrate.

| ai/ file | Round-one source | REFINE-DEEP enrichment |
|---|---|---|
| `ai/architecture.md` | Phase 2 import-edge summary, layer pattern detection | + Phase 2.8 layer diagram, bounded-context boundaries, 3-5 representative request lifecycles with `file:line` |
| `ai/business-domain.md` | Phase 2.x business-domain detection | + Phase 2.7 entity list with invariants, lifecycle events, relationships |
| `ai/conventions.md` | Phase 2 detected conventions (file-naming, suffix matrix, base classes) | + Phase 2.10 emergent conventions (error shape, pagination shape, transaction-boundary, async-work naming) |
| `ai/patterns/parallel-io.md` *(if backend track)* | Phase 2 Step 15 concurrency primitives | + Phase 2.11 hot paths that should use parallel I/O — with current sequential-await citations |
| `ai/failures/<theme>.md` *(new files)* | n/a (didn't exist round-one unless user authored) | + Phase 2.12 recurring failure themes — one file per theme, with affected files + commit refs + root-cause family + prevention guidance |
| `ai/runbooks/<flow>.md` *(only when explicitly opted-in via `--refine --include-runbooks`)* | n/a | + Phase 2.9 flow narrations |

**Boundaries**:
- Each `ai/` file gets a `<!-- refine-enriched:start -->` ... `<!-- refine-enriched:end -->` block injected near the relevant section. Outside these markers stays untouched.
- `ai/status.md`, `ai/decisions/*.md` (ADRs), `ai/dynamic/feedback-learned.md` are NEVER touched by REFINE — they're Phase 6 / append-only / user-authored history.
- `ai/runbooks/` enrichment is opt-in only because runbooks are operational docs the team owns; REFINE doesn't presume to write them without explicit consent.

**Safety contract** (parity with Phase 4.6-DEEP): Phase 4.7-DEEP delegates each per-file enrichment to the `apply-pack-adaptation` skill so the same marker-bracketed write + hash-check + rollback applies to `ai/*.md` files:

1. **Markers are the only writable region.** Bytes outside `<!-- refine-enriched:start -->` ... `<!-- refine-enriched:end -->` are bit-identical pre/post run. Headers, user notes between sections, manually-added cross-refs, and any unrelated user prose all survive verbatim.
2. **Hash-check before and after**: `pre_outside_hash = SHA-256(file_bytes_outside_markers)` is captured before the rewrite; `post_outside_hash` is captured after; mismatch → ROLLBACK (restore pre-write bytes from in-memory copy) and record `ROLLBACK-MARKER-DRIFT` in `_phase-4-6-decisions.md` for that file. The REFINE run continues with the next file.
3. **Markers absent in target file** (e.g. user has hand-edited `ai/conventions.md` heavily and removed prior REFINE markers, or the file was authored before markers existed): inject the markers around an empty block at the end of the relevant section, then write the enrichment between them. Record `MARKERS-INJECTED` in the decision log so subsequent runs know the markers are now in place. NEVER overwrite the file body to install markers.
4. **First-run on `ai/failures/<theme>.md` files** is a NEW-FILE write (no markers exist yet) — the hash-check is not applicable; the contract becomes "the file did not exist pre-run; if write fails for any reason, no partial file is left on disk" (atomic write to `<file>.tmp` + rename, OR halt before write).
5. **Idempotency hash recording**: each per-file enrichment row in `_phase-4-6-decisions.md` records the SHA-256 of the `_refine-extract.md` sections actually consumed. The next REFINE run reads these hashes; if all relevant sections still match → the row becomes `LEAVE-DEEP-IDEMPOTENT` and the file is not rewritten.

This contract makes Phase 4.7-DEEP safe to run repeatedly. User-authored content in `ai/*.md` is bit-identical pre/post REFINE — only the markered region is rewritten, only when deep extraction has new signal to add.

