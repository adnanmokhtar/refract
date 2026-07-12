---
artifact: knowledge-hub
purpose: Authoritative inventory of what the command knows about — tracks, business domains, technical signals, agents, commands, skills, tool adapters.
imported-by: commands/setup-project.md (orchestrator), referenced by Phase 2 detection and Appendix B relevance filter.
---

### Tracks (15)

`code-quality` · `documentation` · `backend` · `frontend` · `database` · `testing` · `security` · `devops` · `performance` · `observability` · `distributed-systems` · `infrastructure` · `mobile` · `ui-ux` · `business` · `learning` (Phase 6 maintenance pack)

Each track has agents / commands / skills / rules / ai-patterns / references in `~/.claude/templates/packs/<track>/`.

### Technical signals (resolved at runtime from `templates/domains/_registry.md`)

The authoritative list of implemented technical signals lives in `~/.claude/templates/domains/_registry.md`. Phase 2 detection + Phase 4.4 application both consult that file rather than any hard-coded list in this command — that way new signal overlays can be added under `~/.claude/templates/domains/<signal>/` without touching the spec.

Each technical signal has `agents/`, `commands/`, `rules/`, `ai-patterns/`, and `_version.json` in `~/.claude/templates/domains/<signal>/`. Triggered by Phase 4.4 when the signal is detected in the codebase.

### Technical signals cataloged (deferred — generate-on-detection if encountered)

`event-driven` · `workflow-orchestration` · `mlops` · `gitops` · `desktop-apps` · `developer-portal`

These names are reserved; if a project triggers one, generate from external library / best practices and save back to `~/.claude/templates/domains/<signal>/` for reuse (Phase 4.5).

### Business domains (15 implemented)

`ecommerce` · `marketplace` · `lms` · `booking` · `fintech` · `insurance` · `healthcare` · `real-estate` · `logistics` · `saas-b2b` · `content` · `social` · `affiliate` · `restaurant-pos` · `on-demand`

Each business domain has 6 files in `~/.claude/templates/business-domains/<domain>/`: `glossary.md`, `core-flows.md`, `feature-checklist.md`, `compliance.md`, `stakeholders.md`, `anti-patterns.md`. Triggered by Phase 4.4b when the business domain is detected. See Phase 2.x for detection logic.

### Framework / engine references

- **Backend**: nestjs, hexagonal-nestjs, express, fastapi, django, laravel, rails, go, spring-boot, dotnet, flask, phoenix-elixir.
- **Frontend**: angular, react, vue, nuxt, nextjs, svelte.
- **Database**: postgres, mysql, mongodb.
- **Infrastructure**: docker, kubernetes, docker-swarm, terraform.
- **Mobile**: react-native, flutter.

### Agents materialized (51)

Architect: `system-architect`, `resilience-reviewer`, `event-sourcing-architect`, `workflow-orchestrator`, `websocket-engineer`, `api-architect`, `schema-architect`, `ui-architect`, `design-system-architect`, `infra-architect`, `k8s-reviewer`, `kubernetes-architect`, `mobile-architect`, `telemetry-architect`.

Review: `code-reviewer`, `api-reviewer`, `schema-reviewer`, `test-reviewer`, `ui-reviewer`, `observability-reviewer`, `security-auditor`, `auth-reviewer`, `tenant-isolation-reviewer`, `prompt-reviewer`, `ci-reviewer`, `ux-reviewer`, `design-system-guardian`, `accessibility-auditor`, `i18n-auditor`, `data-flow-auditor`, `api-contract-sentry`, `theme-specialist`, `error-detective`, `dependency-auditor`.

Specialists: `query-optimizer`, `database-optimizer`, `performance-optimizer`, `test-engineer`, `tdd-orchestrator`, `bug-investigator`, `dead-code-finder`, `refactorer`, `monorepo-architect`, `legacy-modernizer`, `sre-engineer`, `devops-architect`, `deployment-engineer`, `incident-responder`.

Docs + process: `doc-writer`, `api-documenter`, `business-analyst`, `business-auditor`.

### Agents cataloged (generate on signal match)

`devops-incident-responder`, `network-engineer`, `mcp-developer`, `readme-generator`, `git-workflow-manager`, `cqrs-specialist`, `saga-orchestrator`, `workflow-debugger`, `mlops-engineer`, `ml-pipeline-architect`, `model-serving-specialist`, `gitops-architect`, `argocd-specialist`, `progressive-delivery-engineer`, `electron-pro`, `tauri-specialist`, `developer-portal-architect`, `openapi-specialist`.

### Skills (26+ materialized)

Universal: `dead-branch-scan`, `doc-drift-scan`, `adr`, `onboard`.
Backend: `endpoint-test`, `log-tail`, `env-diff`, `debug-tenant`, `module-scaffold`, `api-snapshot`.
Database: `schema-diff`, `migration-rehearsal`.
Testing: `coverage-gap`, `contract-test`.
Security: `secret-scan`, `deps-audit`, `threat-model`.
Performance: `n-plus-one-scan`, `profile-endpoint`.
Observability: `alert-audit`.
Frontend: `visual-check`, `ssr-audit`, `lighthouse-ci`, `bundle-analyze`, `a11y-audit`, `i18n-audit`.
Infrastructure: `k8s-audit`, `dockerfile-lint`.
Distributed: `chaos-test`.

### Commands (40+)

Orchestration: `/add-feature`, `/fix-bug`, `/review-changes`, `/analyze-module`, `/trace-flow`, `/add-module`, `/add-endpoint`, `/add-page`, `/add-component`, `/add-crud-page`.
Quality: `/pre-commit`, `/check-health`, `/simplify`, `/find-module`, `/verify-plan` (universal — audits implementation against a plan written by `<command> --plan`; ships in repo-baseline).
Docs: `/doc-refresh`, `/add-adr`.
DB: `/add-migration`, `/db-audit`, `/optimize-query`, `/migration-review`.
Testing: `/add-test`, `/flaky-test-hunt`.
Security: `/security-audit`.
Performance: `/perf-audit`.
Observability: `/add-telemetry`.
Frontend: `/design-review`, `/design-system`, `/i18n-audit`, `/a11y-audit`.
Infrastructure: `/k8s-generate`, `/dockerize`, `/add-ci`.
Business: `/analyze-task`, `/audit-business`, `/expand-task`.
Domain: `/prompt-eval`, `/token-audit`, `/simulate-webhook`, `/tenant-leak-audit`, `/replay-charge`.
Workspace: `/cross-repo-task`, `/project-map`, `/sync-contract`, `/sibling-sync`.

### Variant packs cataloged (generate on stack match)

`frontend-vue-options`, `frontend-vue-composition`, `nuxt-store`, `hexagonal-nestjs`, `multi-theme`, `ssr`.

### Tool adapters (10 — driver configs for each AI coding tool)

The `ai/` knowledge base is **tool-agnostic and model-agnostic**. The same project knowledge drives any of these AI coding tools; each needs a small adapter producing its native config format. See `~/.claude/templates/tool-adapters/README.md` + `_registry.md` for the capability matrix.

| Tool | Key | Native config | Rules | Agents | Skills | Commands | Hooks |
|---|---|---|---|---|---|---|---|
| Claude Code | `claude-code` | `.claude/` + `CLAUDE.md` | ✓ | ✓ | ✓ | ✓ | ✓ |
| OpenCode | `opencode` | `AGENTS.md` + `opencode.json` | ✓ | ✓ | partial | ✓ | — |
| Cursor | `cursor` | `.cursor/rules/*.mdc` | ✓ | partial | — | — | — |
| Aider | `aider` | `.aider.conf.yml` + `CONVENTIONS.md` | ✓ | — | — | — | — |
| Continue.dev | `continue` | `.continue/config.yaml` + rules/ | ✓ | partial | — | partial | — |
| Cline / Roo | `cline` | `.clinerules/*.md` | ✓ | — | — | — | — |
| Windsurf | `windsurf` | `.windsurf/rules/*.md` | ✓ | — | — | — | — |
| GitHub Copilot | `copilot` | `.github/copilot-instructions.md` + `.github/instructions/` | ✓ | — | — | — | — |
| Codex / AGENTS.md | `codex` | `AGENTS.md` (cross-tool canonical) | ✓ | partial | — | — | — |
| Gemini CLI | `gemini` | `GEMINI.md` | ✓ | — | — | — | — |

**`AGENTS.md` is the de-facto cross-tool standard** — consumed by Codex, Cursor (fallback), Aider (via `read:`), Amp, Cline, Copilot, Windsurf, OpenCode, and Gemini CLI (fallback). The codex adapter is the canonical writer; for the live consumer count see `~/.claude/templates/tool-adapters/_registry.md`. Every `/setup-project` run writes `AGENTS.md` regardless of which adapters are selected — the codex adapter ALWAYS runs.

**Full artifact translation, not just rules.** Each adapter emits the tool's native equivalent for FOUR Claude-Code artifact types:

| Artifact | How each tool handles it |
|---|---|
| **Rules** | Every tool has rule/instructions format — translated natively (globs, frontmatter, etc.). |
| **Commands** (`.claude/commands/*.md`) | OpenCode `commands:`, Copilot `.github/prompts/*.prompt.md`, Continue `prompts:`, Cursor `command-*.mdc`. Aider/Cline/Windsurf/Codex/Gemini: embedded as named sections in their rule/convention file, invoked verbally. |
| **Agents** (`.claude/agents/*.md`) | Every tool except Aider/Cline/Codex/Gemini gets `agent-<name>` named prompts. NO tool has auto-dispatch — the user invokes by name. Claude Code is unique there. |
| **Skills** (`.claude/skills/<name>/SKILL.md`) | OpenCode reads `~/.claude/skills/` globally (free). Others translate to named procedures. Shell scripts are documented but not auto-executed. |
| **Hooks** (`.claude/hooks/*.sh`) | Translated NATIVELY for most tools (as of 2026-07). Each repo hook maps to the tool's own lifecycle-hook config by event (PreToolUse / PostToolUse / UserPromptSubmit / SessionStart / Stop): Codex `.codex/hooks.json`, Gemini + Qwen `settings.json` `hooks`, Copilot `.github/hooks/*.json`, Cursor `.cursor/hooks.json`, Cline `.clinerules/hooks/<Event>`, Windsurf `.windsurf/hooks.json`, Kimi `~/.kimi/config.toml` (user-level). OpenCode is partial (`~` — TS plugins `.opencode/plugins/*.ts`); Aider is partial (`~` — `lint-cmd`/`test-cmd`, post-edit only). The repo's `.sh` scripts need a thin per-tool shim (differing event-payload JSON, block-decision fields, timeout units). **Only Continue** has no agent-loop hooks → `.husky/` git hooks + always-apply rule fallback. Per-tool detail: each `templates/tool-adapters/<tool>/adapter.md` § Hooks. |

See `ai/references/tool-parity.md` (written into every project) for the honest native/translated/not-possible matrix.

**Models are separate from tools.** Any driver can route to any model (Claude, Kimi K2, GPT-5, Gemini, Qwen, DeepSeek, local via Ollama) — the `ai/references/models.md` doc documents the routing patterns. Treat the project knowledge in `ai/` as model-agnostic prose.

### External library references

When a needed agent isn't materialized, check:
- `awesome-claude-code-subagents` — 10-category agent library.
- `agents-main/plugins/` — themed plugin packs (backend, frontend-mobile, database-design, api-scaffolding, observability-monitoring, kubernetes-operations, etc.).

---

