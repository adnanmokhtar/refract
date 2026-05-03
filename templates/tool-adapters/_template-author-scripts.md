# Template-pack authoring scripts (claude-config repo)

Commands and pack templates under `commands/`, `templates/packs/*/commands/`, `templates/snippets/`, and `templates/governance/` are maintained in **this** repository. `/setup-project` Phase 5 (`scripts/audit-setup.sh`) runs mechanical checks against the **template pack source tree** (not only the target repo’s `.claude/`).

## Phase 5 hooks (audit-setup.sh)

| Check | Script | Purpose |
|-------|--------|---------|
| **C2f** | `audit-stack-leakage.sh` | Universal docs must stay stack-agnostic (multi-stack diversity or `<TBD:…>` placeholders). `--repo-root` points at claude-config root. |
| **C2g** | `audit-command-dry.sh` | Commands must link `templates/governance/core-discipline.md` when restating SOLID/clean-code vocabulary; must link `templates/snippets/phase-3-always-reads.md` when pasting the full Phase 3 ALWAYS path list; hand-wave grep sections should link `templates/snippets/hand-wave-grep.md`. |

Run locally from claude-config root:

```bash
./scripts/audit-stack-leakage.sh --repo-root="$(pwd)"
./scripts/audit-command-dry.sh
```

## Canonical pointers (do not duplicate in commands)

| Artifact | Role |
|----------|------|
| [`templates/governance/core-discipline.md`](../governance/core-discipline.md) | Single link target for SOLID + clean-code discipline (points at align + engineering + quality rules). |
| [`templates/snippets/phase-3-always-reads.md`](../snippets/phase-3-always-reads.md) | Universal Phase 3 file list. |
| [`templates/snippets/hand-wave-grep.md`](../snippets/hand-wave-grep.md) | Mechanical hand-wave grep procedure. |
| [`templates/snippets/intent-gate-skeleton.md`](../snippets/intent-gate-skeleton.md) | Intent-routing table skeleton. |
| [`templates/snippets/instrumentation-parity.md`](../snippets/instrumentation-parity.md) | Observability naming-parity halt. |

### Deployed project layout (`/setup-project`)

Pack sources under `templates/packs/.../commands/` use `../../../snippets/` (valid in **this** repo). After **`scripts/apply-study-decisions.sh`** copies a command or agent into a target, links are rewritten to `../templates/snippets/` and `../templates/governance/` so they resolve from `.claude/commands/*.md` and `.claude/agents/*.md` to **`.claude/templates/snippets/`** and **`.claude/templates/governance/`**.

**`templates/repo-baseline/.claude/templates/`** ships those snippet + governance files into every setup — baseline sync copies them beside `.claude/commands/`. Without that tree, relative links would jump above the project root.

## See also

- [`docs/REFERENCE.md`](../../docs/REFERENCE.md) § **Validator scripts** — full table including `audit-command-dry.sh`.
- [`templates/canonical-command-template.md`](../canonical-command-template.md) — Phase 3 references snippets + `core-discipline.md`.
