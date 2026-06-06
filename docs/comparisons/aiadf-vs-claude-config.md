# Comparison: claude-config vs `ai-assisted-development-framework`

> Compared repo: [HosamZewain/ai-assisted-development-framework](https://github.com/HosamZewain/ai-assisted-development-framework)
> Date: 2026-06-07 · Compared at: their `main` (created 2026-06-06, 12 files, ~30 KB, 10 ⭐)
> Outcome: nothing adopted wholesale; 3 ideas implemented (learning pack v1.2.0 — see CHANGELOG § Unreleased).

## At a glance

| | **HosamZewain's framework** | **claude-config** |
|---|---|---|
| **Size** | 12 files, ~30 KB | ~900+ files (packs, commands, agents, skills, scripts, validators) |
| **Maturity** | 1 day old at comparison time | Months of iteration, versioned packs, changelogs, incident-driven hardening |
| **What it is** | A **documentation template** + 1 generator prompt | An **executable orchestration system** |
| **Philosophy** | "Put context in the repo, not chat memory" | Same — plus *enforce* it mechanically |
| **Target user** | Teams starting from zero with AI tools | Power users running production-scale AI workflows |

## What their repo contains

- `AGENTS.md` + `CLAUDE.md` (~3.5 KB): "read `docs/ai/context.md` first, load other docs conditionally, make the smallest safe change", work rules, mandatory final-response block.
- `docs/ai/` (8 stub files): context, architecture, coding-standards, testing-policy, security-policy, release-policy, code-review, glossary — mostly `TBD - needs team confirmation` placeholders.
- `examples/generate-framework-prompt.md` (10 KB): a prompt that makes an AI tool inspect the codebase and fill the stubs, with honesty markers (`Inferred from codebase:`, `TBD`, `Not found in current codebase scan`).
- `examples/review-framework-prompt.md`: a 12-point self-review checklist for the generated files.
- `.agents/skills/` (5 skills): **referenced in the README but absent from the repo** at comparison time.

## Concept-by-concept

| Concern | Their repo | claude-config | Verdict |
|---|---|---|---|
| **Project context** | 8 hand-edited stub docs filled by one AI prompt | `/setup-project` deep extraction: 15-step codebase walk, idiom extraction (5 strategies), business-context capture, domain detection against 15+ domain glossaries, REFINE round-two (entities, flows, hot paths, failure history) | **claude-config, by generations** |
| **Token-efficient loading** | "Read `context.md` always; other docs conditionally" | `_essentials.md` / `_topics.md` topology, import tiers, conditional pack loading | **Equivalent idea; ours mechanized** |
| **Workflows** | 5 skills *promised* (`.agents/skills/` — directory doesn't exist in the repo) | ~35 executable commands + agents + multi-agent parallel waves (`/migrate`, `/audit`, `/optimize`, `/align`, `/polish`, …) | **claude-config; theirs is vaporware** |
| **Enforcement** | Prose rules ("make the smallest safe change") — relies on the model obeying | Validator scripts that **halt gates** (`validate-*-artifacts.sh`), hand-wave greps, gap-count parity, 13 migration hard halts, mechanical evidence checks | **claude-config — the biggest gap** |
| **Migration (V1→V2)** | Nothing | Entire migration pack: contracts, parity tests, ledger state machine, dead-code 6-axis check, tier system, navigation inventory, anti-pattern catalogue | **claude-config; zero coverage on their side** |
| **Code review** | 1-page checklist + output format | `/code-review`, `parity-auditor`, `change-brief` comprehension gate, security review, per-axis enumeration with `<path:line>` citations | **claude-config** |
| **Multi-tool support** | One shared `AGENTS.md` ("works with Codex, Cursor, Antigravity…") | 11 tool adapters with per-tool executable translation, `sync-to-global.sh`, coverage audits, parallel orchestrator scripts for tools without sub-agents | **claude-config** |
| **Security rules** | Good always-on "AI Must Never" list (never drop tenant filters, never log secrets, never hardcode tenant IDs) | Security pack + `/audit` security axis + threat-model agents — mostly *detection-time* | **Theirs simpler but always-on; ours deeper** — see "Open ideas" |
| **Learning loop** | None — docs go stale until someone edits them | Phase 6: drift detectors, knowledge curator, `/setup-project-health`, oracle-drift hashing | **claude-config** |
| **Release/deploy stage** | `release-policy.md`: risk levels (low/medium/high), readiness checklist, **post-release monitoring expectations** | Thin — packs are dev-time + CI-time; nothing owns deploy-time | **Theirs (only axis they win)** — small, but real |
| **Adoptability** | Copy 12 files, productive in 10 minutes | Steep — full pack system, anchors, oracles | **Theirs** |

## What we adopted (implemented 2026-06-07, learning pack v1.2.0)

Their three genuinely good ideas exposed inconsistencies in our own philosophy:

1. **Provenance markers** (their `TBD - needs team confirmation` / `Inferred from codebase:` vocabulary) → every claim in our `_extracted-*` oracle files is now `[found: <path:line>]` / `[inferred: <basis>]` / `[unconfirmed]` (`templates/phases/phase-2-profile.md § Provenance discipline`). We were enforcing citations on migration artifacts while the oracle they all trust was unverified — their tiny repo caught our own Trusted-Summary anti-pattern applied to ourselves.
2. **Human sign-off** (their "Draft PR → Tech Lead approves" adoption flow) → `approved_by:` / `approved_hash:` stamp on oracle files + `/setup-project-health` check 9 (`§ Oracle approval`).
3. **Honesty clause** (their mandatory final-response block: tests not run + why / risks / rollback notes) → `Not validated:` / `Risks:` / `Revert:` lines now close every `/migrate` / `/optimize` / `/align` / `/polish` / `/unify-surfaces` run summary (hard rule per command + `templates/tool-adapters/_orchestration-sync.md`).

## What we deliberately did NOT take

- **Their doc structure** (8 static files) — our extraction artifacts are richer and regenerated, not hand-maintained.
- **"No full codebase scan" rule** — correct for their cheap-context world; wrong for our deep commands whose whole value IS the exhaustive scan.
- **Their generator prompt** — `/setup-project` does the same job with 15 steps, parallel subagents, quality gates, and idempotency.

## Open ideas (noted, not implemented)

- **Release/deploy-stage surface**: a generic risk-level taxonomy for everyday changes + release-readiness checklist + post-release monitoring expectations. The only lifecycle stage where they cover ground we don't. Candidate: a small `release` pack or a section in repo-baseline runbooks.
- **Always-on security never-rules**: verify that generated project CLAUDE.md files carry the baseline "never weaken auth / never drop tenant filters / no schema change without migration + rollback" rules in the always-loaded tier (prevention), not only in audit-time detectors (detection).
- **Lite-tier install**: their adoptability is why the repo spread. If the packs should ever be adopted by teams beyond the author, a minimal install (CLAUDE.md + a handful of small docs, no pack machinery) would be the on-ramp.
- **Code-anchored project glossary**: their `Term → Definition → Where used: <path> → Related modules` format anchored to the actual codebase is a slightly different artifact from our generic business-domain glossaries. Low priority; partially served by `_extracted-codebase.md`.

## Bottom line

**Same philosophy, ~100× difference in depth and enforcement.** Their repo is a good *starter kit* for a team with nothing; claude-config is a *system*. Adopting their repo would be a downgrade on every axis except simplicity — but as a mirror it was useful: it caught 3 honesty gaps in our pipeline that our own anti-Trusted-Summary discipline should have caught, and those are now fixed.
