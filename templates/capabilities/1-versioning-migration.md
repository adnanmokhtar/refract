---
artifact: capability-1-versioning-migration
purpose: "Setup versioning + migration (B2). Every artifact carries setup-project: vN; migrations live in templates/migrations/."
imported-by: templates/capabilities.md (index), commands/setup-project.md (orchestrator)
---

### 🧮 1. Setup versioning + migration (B2)

**Problem solved**: packs evolve in `~/.claude/templates/`; old projects don't know they're stale; manual `--refresh` is the only signal. Result: silent rot across projects.

**Design**:

#### 1.1 Version every artifact source

Every pack / business-domain / technical-signal directory gets a `_version.json`:

```
~/.claude/templates/packs/backend/_version.json
{
  "version": "2.4.0",
  "released": "2026-04-15",
  "min_setup_command": "3.0.0",
  "deprecated": false,
  "summary": "Adds saga-orchestrator agent + distributed-tx pattern."
}

~/.claude/templates/business-domains/ecommerce/_version.json
~/.claude/templates/domains/multi-tenant/_version.json
~/.claude/templates/tool-adapters/cursor/_version.json
```

The setup command itself versions in its frontmatter:

```yaml
---
description: <as before>
setup_command_version: 3.0.0
released: 2026-04-25
---
```

#### 1.2 Stamp into project on apply

Phase 4.1 (after baseline scaffold) appends a `## Setup version` block to `.claude/codebase-profile.md`:

```yaml
## Setup version
setup_command: 3.0.0
applied_at: 2026-04-25T14:30:00Z
mode: REFRESH
flags: [--refresh, --lang=ar]
packs:
  backend: 2.4.0
  database: 1.5.2
  security: 1.0.0
  testing: 1.3.0
  code-quality: 1.0.0
  documentation: 1.0.0
  learning: 1.0.0
business_domain: ecommerce@1.2.0
technical_signals:
  multi-tenant: 1.4.0
  payment: 1.1.0
tool_adapters:
  claude-code: 3.0.0
  cursor: 1.2.0
  opencode: 1.1.0
```

#### 1.3 Drift detection at session start

`session-start.sh` reads recorded versions from `.claude/codebase-profile.md` and compares against `_version.json` of each currently-installed template. Output (only if drift detected):

```
⚠ Setup updates available (run /setup-project --diff for details, --refresh to apply):
   backend         2.4.0 → 2.5.1  (3 patches, 1 minor — additive)
   security        1.0.0 → 1.1.0  ★ BREAKING (agent rename)
   ecommerce       1.2.0 → 1.3.0  (new flow templates)

Last refresh: 6 weeks ago.
```

Suppression: user can add `setup_drift_check: false` to their `.claude/settings.json` to silence the nag (NOT recommended).

#### 1.4 `--diff` flag (read-only preview)

```
$ /setup-project --diff

PACK DRIFT REPORT (.claude/codebase-profile.md vs ~/.claude/templates/)

  backend          2.4.0 → 2.5.1
    +1 minor: pattern/saga-orchestrator.md (NEW)
    +3 patches: rule wording fixes
    Migration: none required (additive)

  security         1.0.0 → 1.1.0  ★ BREAKING
    !1 major: agent api-architect → backend-architect (renamed)
    Migration script: ~/.claude/templates/packs/security/migrations/v1.0-to-v1.1.sh
    Auto-applied by /setup-project --refresh.

  ecommerce        1.2.0 → 1.3.0
    +1 minor: core-flows: subscription-billing flow added
    Migration: none required (additive)

To apply: /setup-project --refresh    (REFRESH preserves your ADRs + custom rules)
```

#### 1.5 Changelog format

Each pack maintains a `CHANGELOG.md`:

```markdown
# backend pack changelog

## [2.5.1] - 2026-04-30
### Fixed
- typo in rule/services.md

## [2.5.0] - 2026-04-25
### Added
- pattern/saga-orchestrator.md
- agent/distributed-tx-architect.md
### Migration
- additive only; /setup-project --refresh handles automatically

## [2.4.0] - 2026-04-15
### Added
- pattern/distributed-transactions.md
```

#### 1.6 Migration scripts

For breaking changes (major version bump), add a migration script:

```
~/.claude/templates/packs/security/migrations/v1.0-to-v1.1.sh

#!/usr/bin/env bash
# Renames api-architect → backend-architect across all setup files.
set -euo pipefail
PROJECT_ROOT="${1:-.}"

[ -f "$PROJECT_ROOT/.claude/agents/api-architect.md" ] && \
  mv "$PROJECT_ROOT/.claude/agents/api-architect.md" \
     "$PROJECT_ROOT/.claude/agents/backend-architect.md"

# Update references
for f in "$PROJECT_ROOT/CLAUDE.md" "$PROJECT_ROOT/AGENTS.md" "$PROJECT_ROOT/.claude/GUIDE.md"; do
  [ -f "$f" ] && sed -i.bak 's/api-architect/backend-architect/g' "$f" && rm "$f.bak"
done
```

REFRESH mode auto-runs migration scripts in version order before regen. Plan output shows which scripts will run + lets user approve.

#### 1.7 Hard rule

- **Every pack source MUST have `_version.json`.** Phase 4.0 pack-load preflight refuses to apply a pack without it.
- **Breaking changes (major bump) MUST have a migration script.** CI on `~/.claude/templates/` enforces this.
- **`setup_command_version` and pack versions MUST be recorded** in every project's `.claude/codebase-profile.md`. Without these, drift detection is impossible.

---

