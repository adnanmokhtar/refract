---
description: "Graduate a VALIDATED entry in decisions-pending.md into a numbered ADR in the project's detected ADR home."
kind: command
pack: learning
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /promote-decision

**One command. Turn a pending architectural decision into a numbered ADR.** A decision that lives only in `ai/dynamic/decisions-pending.md` is invisible to future sessions and cannot be cited. This graduates it into the project's ADR home and keeps the pending entry as the record of where it came from.

## When to use

- A pending decision in `ai/dynamic/decisions-pending.md` has been **made** (the team chose a direction) and should become permanent.
- `/audit-knowledge` listed it as a stuck `VALIDATED` entry (`memory-hygiene-scan` §5, KN-24) with this command.
- NOT for emerging code patterns — that's `/promote-pattern` (→ `ai/patterns/`).

## Args

```
/promote-decision <id>          # graduate the named pending decision
/promote-decision               # list VALIDATED pending decisions, ask which
```

## Step 0 — Detect the ADR home (never assume `ai/decisions/`)

Projects keep ADRs in `docs/decisions/`, `docs/adr/`, `doc/adr/`, `adr/`, `architecture/decisions/` or `ai/decisions/`. Writing to `ai/decisions/` when the ADRs live in `docs/decisions/` creates a competing ledger with 0 ADRs in it: on a real NestJS monorepo, 40 ADRs sat in `docs/decisions/`, its index said "do not create a competing `ai/decisions/` ledger", and this command used to write there anyway (KN-29). Ask the engine:

```bash
KS="${KS:-.claude/skills}"; [ -f "$KS/decision-record-scan/scripts/adr-index.py" ] || KS="$HOME/.claude/templates/packs/learning/skills"
python3 -I "$KS/decision-record-scan/scripts/adr-index.py" . --list > "${TMPDIR:-/tmp}/adr-list.tsv" 2> "${TMPDIR:-/tmp}/adr-list.err"
echo "adr-index exit $?"; head -3 "${TMPDIR:-/tmp}/adr-list.err"
HOME_DIR=$(awk -F'\t' 'NR==2 { sub(/\/[^\/]*$/, "", $2); print $2 }' "${TMPDIR:-/tmp}/adr-list.tsv")
NEXT=$(awk -F'\t' 'NR>1 && $1 ~ /^[0-9]+$/ { if ($1 + 0 > m) m = $1 + 0 } END { printf "%04d", m + 1 }' "${TMPDIR:-/tmp}/adr-list.tsv")
echo "ADR home: ${HOME_DIR:-none} · next number: $NEXT"
```

- The ledger's home line says how it was chosen (declared by an index, or the directory with most `NNNN-*.md`). Use that directory for the new file, and its highest number + 1.
- **No home** (no `NNNN-*.md` anywhere): the project has no ADR layer yet. Ask once: create `ai/decisions/` (the Refract baseline default) or the directory the user names. Never pick silently.
- **Several candidate homes tie** and no index declares one: ask which, naming them.
- **The engine is absent or exits 2:** fall back to `ls` over the six candidates above, print `adr-index NOT-RUN`, and ask before writing.

## What happens (via knowledge-curator)

Dispatch `knowledge-curator` in mode `promote` (the `Task` tool) with the entry id and `$HOME_DIR`. It drafts; you show; the user approves:

1. **Read** the entry in `ai/dynamic/decisions-pending.md` (context, options, what was blocking). Its status must be `VALIDATED` (held ≥ 2 weeks, ≥ 1 implementation, [`learning-sink.md`](../../../snippets/learning-sink.md)).
2. **Allocate** `$NEXT` from Step 0.
3. **Author** the ADR at `$HOME_DIR/<NNNN>-<slug>.md` in the shape the home already uses (read one existing ADR first: Nygard `## Status` heading, MADR frontmatter, or `Status:` line). Sections: context, decision, status (`Accepted`), consequences, alternatives considered, date, and — when it closes a V1↔V2 divergence — the `user_decision_quote:` the migration discipline requires. A decision that supersedes an existing ADR carries `Supersedes: <id>`, and the old ADR gains `Superseded by: <new id>` (both ends; `decision-record-scan` §2).
4. **Mark, never remove**, the pending entry: change its status to `PROMOTED → ADR-<NNNN>` with the date and the ADR path. The entry stays as the record of where the decision came from (curator invariant "archive, don't delete").
5. **Update the index** — add the line to `ai/_decision-index.md` (or the index the home declares); cross-link from `ai/status.md § Recent Changes` if it changed the status quo. Append the audit line to `ai/dynamic/promotions.md` ([`learning-sink.md` § Confirm-list and the promotion audit line](../../../snippets/learning-sink.md)): `adr <ADR path> ← ai/dynamic/decisions-pending.md:<line>`, the implementation as evidence, the user's approval words as `confirmed:`.
6. **Regenerate** the Tier-1 derived files (`ai/_session-digest.md` reflects the new last-3-decisions) through `knowledge-curator` § 8.

## Phase 6 — Validate (verify before declaring done)

Do NOT report success on assertion. HALT unless every check below passes:

- **ADR file exists in the detected home** — `adr-index.py . --list` now prints a row for `<NNNN>` whose file is under `$HOME_DIR`, with status `accepted`. A row under any other directory is the competing-ledger defect: remove the file you wrote and halt.
- **Required sections present**: context, decision, status, consequences, alternatives considered — plus `user_decision_quote:` when the ADR closes a V1↔V2 divergence.
- **No placeholder text** (`<TODO>`, `<slug>`, `<NNNN>`, `{{}}`) remains in the authored file.
- **Pending entry is marked, exactly once** — `grep -c 'PROMOTED → ADR-<NNNN>' ai/dynamic/decisions-pending.md` returns 1, and the entry's heading is still there. Zero means step 4 did not land; two means a duplicate.
- **Supersede pair runs both ways** (when step 3 superseded one) — `adr-index.py . --list` shows the old id's `superseded_by` = the new id and the new id's `supersedes` = the old one.
- **Index line appended** — the new `<NNNN>` line is in the index exactly once.
- **Audit line appended** — `grep -c 'adr <ADR path>' ai/dynamic/promotions.md` returns 1.
- **Digest regenerated** — `ai/_session-digest.md` lists the new ADR. The path is `ai/_session-digest.md`, not `ai/dynamic/`: a grep for a path the baseline never creates passes for the wrong reason.

If any check fails, halt and report which — a half-promoted decision (ADR written, index not updated, or the entry still `VALIDATED`) is worse than an un-promoted one, because it now exists in two states that will drift.

## Halts

- The pending decision isn't actually resolved (still "blocked / undecided", or below `VALIDATED`) → refuse; a pending decision isn't an ADR until a direction is chosen.
- The ADR home is unknown or ambiguous (Step 0) → ask; never default to `ai/decisions/` while ADRs exist elsewhere.
- The decision contradicts an accepted ADR and the user has not said "supersede" → halt and ask.

## Output (brief)

- ADR path + number (under the detected home) · pending entry `PROMOTED → ADR-<NNNN>` · index line · digest regenerated · supersede pair (if any).

## See also

- `/promote-pattern` — the pattern sibling (→ `ai/patterns/`).
- `/audit-knowledge` — lists `VALIDATED` decisions stuck past their threshold (KN-24) and ADR-home drift (KN-29).
- `decision-record-scan` (`adr-index.py --list`) · `ai/_decision-index.md` · `ai/dynamic/decisions-pending.md`.
