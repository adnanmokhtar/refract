# Decision index

Flat one-line summary of every ADR in `ai/decisions/`. Auto-maintained by `knowledge-curator`. Used by agents for fast lookup ("did we decide X?") without loading every ADR file.

Last updated: <YYYY-MM-DD by knowledge-curator>

---

## Accepted (active)

| ID | Date | Title | One-liner |
|---|---|---|---|
| ADR-0001 | <YYYY-MM-DD> | <title> | <one-sentence decision> |
| ADR-0002 | <YYYY-MM-DD> | <title> | <one-sentence decision> |

## Superseded (historical context only)

| ID | Date | Superseded by | Title |
|---|---|---|---|
| ADR-0007 | <YYYY-MM-DD> | ADR-0042 | <title> |

## Pending (not yet formal — see decisions-pending.md for details)

| Topic | Lifespan | Implementations |
|---|---|---|
| <e.g., "BullMQ over Redis Streams"> | 3 weeks | 3 modules |

---

## How to use

- **Before proposing an architectural change**: scan this index. If the area has an ADR, READ that ADR before contradicting it.
- **Quick "did we decide X?" lookup**: grep this file by keyword.
- **Conflict detection**: if your proposal contradicts an Accepted ADR, you must either (a) align with it OR (b) write a superseding ADR.

## How this is maintained

- **Auto-regenerated** by `knowledge-curator` on every `/audit-knowledge`, after every `/promote-decision`, and on `post-commit-learn` if `ai/decisions/` changed.
- **Source of truth**: the full ADR files in `ai/decisions/`. This is a derived index.
- **Don't hand-edit.** Edit the source ADRs.

## See also

- `ai/decisions/` — full ADR files (load on demand for context).
- `ai/dynamic/decisions-pending.md` — informal decisions awaiting graduation.
- `/promote-decision` — graduates pending → formal ADR.
- `/audit-knowledge` — regenerates this index.
