# devops pack — changelog

Release history for `templates/packs/devops/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 2.1.0 — 2026-10-19

**Phase 6: `platform-engineer`, the roster's infrastructure writer.**

- **New agent `platform-engineer`** (writer, one task at a time). It writes CI files, Dockerfile / compose, IaC roots, `release.md`, `ai/runtime/slos.md` and `ai/runbooks/**`, always plan or diff before any apply. It absorbs no specialist yet: devops-architect, deployment-engineer, infra-architect, kubernetes-architect, cost-architect and sre-engineer stay the owners of their decisions.
- **`/add-ci` and `/dockerize` dispatch it for Phase 4**, and a Phase 6 finding goes back to it as a new task. Inside a run it is the only writer of those paths; repo-baseline's `ownership-guard.py` enforces this while a run is open. Without it (minimal mode) the command prints `HANDOFF UNROUTED (devops not installed)` and the main session writes, as before. It is also the P6 infra writer for delivery's `/add-feature`, and Phase 4 writer for infrastructure's `/k8s-generate` and `/provision-tier`.
- `ci-reviewer` and `deployment-engineer` example findings no longer quote a benchmark fixture's seeded file and line (`lint-fixture-leakage.py`).

## 2.0.4 — 2026-10-18

- References follow the skill renames that un-hid `/secret-scan`, `/threat-model`, `/log-tail` and `/endpoint-test` (a same-named skill shadows a command).

## 2.0.3 — 2026-10-15

**`ci-graph.py --required` is offline by default** (repo-baseline change after a verbatim pre-flight reached GitHub during a read-only audit). `/devops-audit`'s `SETTINGS=1` branch, `@ci-reviewer`, `pipeline-integrity-scan`, `pipeline-cache-scan` and `STACK.md` now pass `--required --online` where the user allowed outbound reads; without it the script prints `NOT-RUN OFFLINE` and exits 2 (required-ness unknown, never "not required").

## 2.0.2 — 2026-10-14

**`deploy-safety-scan` §1's lock column now reads from the dated migration-runner table (batch-5 integrator, distributed-systems eval IR-3).** Each runner names its behaviour at boot — **waits** (Knex, golang-migrate, EF Core ≥ 9, Flyway, Liquibase; Prisma for 10 s), **fails fast** (Rails: `ConcurrentMigrationError`, a crash-loop), **skips** (Laravel `--isolated`: a held or stale mutex skips the migrations and exits 0) or **none** (MikroORM, TypeORM, Drizzle, Sequelize/umzug, Django, Alembic, Doctrine; goose opt-in) — with its `broker-semantics.md` MG row and `precedents/performance.md` § 77 as the source; the `[K?]` tags those rows settled are gone. Only a **waits** row clears gate 4, behind a session-mode pooler or none; fails-fast and skips stay findings at floor ≥ 2.

## 2.0.1 — 2026-10-10

**The gaps the `ci-defects` benchmark fixture measured (its `DEFECTS.md` § Integrator requests IR-1…IR-10) are fixed; that fixture's verbatim pre-flights now surface 114 of 117 seeds, 3 partial, 0 missed (run 1: 107 / 4 / 6).** `kubectl` with global flags before the verb (`kubectl --kubeconfig "$K" -n ns apply`) is a deploy verb and a rollout wait in `pipeline-integrity-scan` greps 4a/6, `ci-graph.py` `MUT`/`WAIT` and `deploy-safety-scan` 0d (whose wait accounting is now position-aware, counts `kubectl … wait` and never leaves a local `kustomize edit set image` pending); `ci-graph.py` marks a job whose only verbs publish (`docker push`, `npm publish`) `deploy-via=publish-verb` (JOB `deploys=no publishes=yes`, no `DEPLOY-NOGROUP`/`GROUP-NOT-ENV`, so no false `BUILD-IN-DEPLOY`), adds `--serial-chains` (`SERIAL-CHAIN` facts for `pipeline-cache-scan` §4, beside a GitLab `STAGE-LADDER` awk) and `--settings-dir=<dir>`, which reads the saved `gh api` responses (rules, environments, rulesets) offline into the required join plus `ENVIRONMENT` and `RULESET` rows; `/devops-audit --settings-dir=` passes `SETTINGS_DIR` to every detector. `pipeline-cache-scan` 1a closes a cache step that starts `- id:` (an off-by-one let a later `path:` overwrite it); `release-integrity-scan` counts a containerised scanner (`docker run … aquasec/trivy@sha256:… image`) as a `SCAN` row with the scanned ref, and its trigger grep no longer matches `types: [created]` under `issue_comment:`; `container-build-scan` ignores a `|` inside a quoted `sed` expression and prints `APT-UPDATE-ALONE`. `ci-graph.py --self-test` 64/64 (was 55). Patch release: no command, skill or agent added or renamed; new `ci-graph.py` flags are additive.

## 2.0.0 — 2026-10-10

**The devops pack became a set of detectors with one audit, one fix loop and two judges (Track A batch 4).** Before this release the pack had one runnable detector (`dockerfile-lint`, whose root check had an inheritance false positive and a `0:0` false negative and which read `./Dockerfile` only) and three agents that graded in prose; its own generators emitted the defects it should catch: `/add-ci` and the `cicd-pipeline` pattern put a workflow-level `cancel-in-progress` over the prod deploy, scanned a `load: true` image and then pushed a rebuild, and tag-pinned third-party actions in a `packages: write` + `id-token: write` job; `@devops-architect` recommended a migration initContainer and promotion by retagging a mutable `:prod`. Now every delivery-integrity class has one owning skill with a one-script pre-flight (every `rg` names its path; include globs first, exclusions last), a tool lane whose errors are NOT-RUN never PASS, a class-coverage block, a refute step against `precedents/devops.md` and a failing-first oracle at a named tier (T `ci-graph.py` or a tool exit · R a sandbox run · B a built image or a registry read · A a settings read · S a static trace · L a live rollout, `proof-oracles.md` § DevOps V209–V243 and V290). Attacker paths in CI and in images are security's (`ci-security-scan`, `iac-scan`), and this pack no longer grades them (`STACK.md` § Boundaries). Major version: new commands, a renamed skill (`dockerfile-lint` → `container-build-scan`), two agents rebuilt as judges with changed contracts, three `_examples` deleted.

New detectors (`skills/`), each measured 2026-10-10 on a seeded sample, the benchmark fixtures and a read-only real repo (no name recorded; `git status` clean before and after):
- `pipeline-integrity-scan` §1–§8 across GitHub Actions, GitLab CI, CircleCI, Bitbucket, Azure Pipelines and Jenkins: masking on non-domain gates (deploy, publish, scan, smoke, build, the aggregator), exit status lost by the shell (per-platform rows S1–S7), the required-check join (a check satisfied by a skip, never reported, path-filtered, no `merge_group`), deploy and publish gating (`if: always()` on a deploy, `workflow_run` with no conclusion check), unvalidated refs, timeouts (`THR-CI-JOB-TIMEOUT`), matrices that hide a declared runtime, dead schedules; plus the security fallback lane, tagged, when the security pack is absent (V209–V216).
- `pipeline-cache-scan` §1–§4: cache keys (no lockfile hash, no arch, a prefix restore that skips the install, an inexact `cache-hit` guard), the Docker layer cache (`mode=min`, a shared default `scope`, a per-run key), superseded runs and affected detection on a shallow clone, and run timing as L, report-only (V217–V219).
- `release-integrity-scan` §1–§7: movable release refs, split version sources, non-idempotent re-runs, **shipped ≠ tested** (a rebuild after the scan, per-environment build args; the scanned digest must equal the pushed, staging and prod digest), provenance and verification pinned to workflow and ref, release-PR automation on `GITHUB_TOKEN`, and rollback addressability (registry retention that deletes N-1) (V220–V226).
- `deploy-safety-scan` §1–§6: migration **topology** — who runs it, how many times, under which lock (MikroORM 6.6.16 measured lockless: three concurrent `getMigrator().up()` applied a data migration three times) — deploy concurrency keyed on the environment (`THR-DEPLOY-CONCURRENCY`), environment protection, the rollout gate, the code side of the shutdown chain (a `process.on(<variable>)` loop that awaits the framework close is the handler) and config/runtime parity across environments (V227–V234).
- `container-build-scan` §1–§10 **replaces `dockerfile-lint`**: the stage-chain user resolved through `FROM <stage>` (inherited `USER 10001` is non-root; `0:0` is root; an external base with no USER is settled by `crane config`), PID 1 and signals, layer order and the ignore file that applies, the lockfile enforced inside the build (`ENV CI=true` did not freeze pnpm 9.15.9), RUN correctness, HEALTHCHECK binaries and port, base / platform / libc, runtime content (a `VOLUME` write is kept under BuildKit), the `docker build --check` + hadolint v2.15.1 lane (a parse error or `DL1000` is NOT-RUN), reproducibility and size against `THR-IMAGE-GROWTH` (V235–V243). Root, secret build args and `curl | sh` stay security `iac-scan` §1's.
- `compose-scan` §1–§7 over the merged model (`docker compose config`, Compose v5.1.4 semantics measured): `depends_on` gating and healthchecks (an image `HEALTHCHECK` satisfies `service_healthy`), interpolation, what production actually loads (override auto-merge, profiles), image tags, anonymous volumes on stateful services, scale blockers and legacy keys, restart and stop timing against the drain (V241).

Rewritten or trimmed:
- `progressive-delivery` §1–§9: dead and orphan flag keys (with a harness sanity line), stale flags, owner and removal date, kill switches, the **canary gate that can fail** (`NEVER-FAILS`, `LIMIT>=COUNT`, `ZERO-FALLBACK`, `NO-ANALYSIS`, `BG-AUTO-PROMOTE`, `SKIP-ANALYSIS`, render-only weakening from an overlay), every canary selector grounded through observability's `rule-inventory.py --check=selectors`, flag drift across environments (`STAGED` is the release order), config flags, the provider-outage default and build-time flags (V232, V233). Guessed directories replaced by root discovery.
- `gitops-audit` §1–§3: out-of-band mutation into a namespace a CD target owns (the controller's own install is not), live drift on a named controller context only, drift nobody sees (V290). The controller spec (prune, waves, `selfHeal` × HPA, `ignoreDifferences`) moved to infrastructure `k8s-render-scan` §4; committed Secrets to security. No `2>/dev/null` on a guessed directory.
- `release-security` is the runner `release-integrity-scan` §5 calls: scan before push (or gate the deploy on the scanned pushed digest), `--certificate-identity '<workflow>@<ref>'` plus the issuer instead of a regexp, `--type slsaprovenance1`, `actions/attest` v4, cosign ≥ 3.1.3 (`THR-SCANNER-FLOOR`), scanners pinned by version and digest, `syft --scope all-layers` for audit, the `mode=max` build-arg leak, and "scanned digest == pushed digest".
- `monitor-deploy` is unchanged.

Commands:
- `/devops-audit` (new): render once (infrastructure's `render.sh` when installed, an empty scratch `KUBECONFIG` throughout), dispatch all eight detectors plus `ci-graph.py` on a whole-repo run, hand the rows to the two judges, refute every kept BLOCKER and HIGH through `@verifier`, print the class ledger and the coverage ledger, judge five GO-critical controls, and write `ai/audits/<date>-devops.md`. The settings lane (`--settings`, read-only `gh api`) and the sandbox lane (`--sandbox=<owner/repo>`) open only on the user's word; without them those rows print `UNREADABLE` or `UNVERIFIED`, never pass.
- `/devops-fix` (new): the class's oracle failing first, the fix at the shared unit, `ci-graph.py --diff-guard=<base> --allow-job=<file>:<job>` on every workflow change (a workflow-level finding adds the key-scoped `--allow-workflow=<file>:<key>`), a grep of the fix's own diff for weakening shapes (`continue-on-error`, `|| true`, `if: false`, a path filter on a required workflow, a scanner exit flag zeroed), re-detection, and a STOP before changing who or what deploys.
- `/add-ci` emits a PR-scoped cancel and an environment-keyed deploy group, builds the image once and pushes by digest behind the scan, pins third-party actions by SHA in privileged jobs, sets `persist-credentials: false`, and runs `ci-graph.py` plus `pipeline-integrity-scan` (and security's CI scan when installed) on its own output.
- `/dockerize` Phase 6 dispatches `container-build-scan` and times a `docker stop` on the smoke container (V231: under 10 s, exit ≠ 137); Phase 7 records the size baseline `THR-IMAGE-GROWTH` reads. `/rollback-deploy` R3 reads `release-integrity-scan` §7. `/deploy-stage` S2–S5 read the rendered manifests and cite their owners' rows instead of their own greps; the S3 CPU-limit demand is withdrawn (infrastructure's precedent).

Agents, rules and patterns:
- `@ci-reviewer` and `@deployment-engineer` are rebuilt as judges (`role: judge`, `writes: none`) that refute and grade detector rows; the ~15 security classes `@ci-reviewer` re-owned in prose are one routing line each to `ci-security-scan`; `@deployment-engineer` drops `Write`/`Edit`. `@devops-architect` carries a proposer Contract, scopes cancel to PR CI, promotes by digest, runs migrations as one Job or a platform release phase, and rolls back to the previous digest. `lint-agent-contract.sh` lists devops as a pack whose agents must have a Contract.
- `devops-principles` adds three one-liners (cancel only where nothing shared is mutated; promote by digest, never a rebuild of the scanned image; numeric `USER` for `runAsNonRoot`). `ai-patterns/deployment.md` adds migration topology and same-digest promotion; `ai-patterns/cicd-pipeline.md` (and its `_examples` twin) fixes the example it shipped.
- `STACK.md` gains the boundary table: what security, testing, infrastructure, observability and database own versus devops. `_essentials.md` ships the eight detectors, `release-security`, the two judges and the audit/fix pair in minimal mode.
- Deleted: `skills/dockerfile-lint/`, `_examples/dockerfile-lint.md`, `_examples/gitops-audit.md` and `_examples/progressive-delivery.md` (their sources are the fallbacks).

Shared machinery this pack is the first user of (repo baseline and snippets): `.claude/scripts/ci-graph.py` (the GitHub Actions job graph with a real YAML loader and the `on:` remap; publishes counts `docker/build-push-action` with `outputs: …push=true` and no `push:` input; deploys counts an `environment:`, a deploy verb, or a deploy action with no environment — `JOB` rows print `env=` and `deploy-via=`; `--diff-guard` refuses a bare `--allow-workflow=<file>`, which used to let every guarded key in the file through; `--self-test` 55 cases), `snippets/precedents/devops.md` § 1–§ 58, `snippets/ci-platform-semantics.md` (S1–S7, R1–R11, C1–C11, dated changes), `proof-oracles.md` § DevOps, nine devops `ownership.json` rows (plus the security CI-attacker row) and five thresholds (`THR-CI-JOB-TIMEOUT`, `THR-DEPLOY-CONCURRENCY`, `THR-IMAGE-GROWTH`, `THR-SCANNER-FLOOR`; `THR-SHUTDOWN-GRACE` is infrastructure's). Every `rg` call in the pack puts include globs first and the exclusion array last (ripgrep lets the later `-g` win; the reversed order re-included `tests/` and `*.spec.*` in `deploy-safety-scan`, `release-integrity-scan` and `pipeline-cache-scan`).

## 1.6.0 — 2026-08-22

- **`/rollback-deploy` rebuilt around the ordering defect.** The migration/state check ran AFTER the
  revert; it is now a four-question reversibility gate (R1 migration direction, R2 target still
  retained, R3 artifact reference immutable, R4 shared state the old version cannot read) that runs
  BEFORE execution, each with a halt. Adds the rollback-vs-forward-fix decision as step 2, a
  `## Hard rules` section its `_topics.md` spec declared but the file lacked, `## Premise`, a
  platform selector mapping for `--to=`, and `--force` for a named override.
- **"Known-good" now has a data source.** Revision history (`kubectl rollout history` / `helm
  history`) lists revisions, not health. S1 in `/deploy-stage` and `deployment-engineer` now resolve
  a target's health from the deploy ledger (`ai/runtime/deploys.md`), a `monitor-deploy` GREEN
  record, or platform deployment status — or report the target `UNVERIFIED`. This closes the gate
  chain that previously terminated in an unimplemented check.
- **The deploy ledger is now created, not conditionally appended.** `/deploy-stage` Phase 5 said
  `ai/runtime/deploys.md` *(if exists)* while Phase 6 said the same write was "non-optional" — and
  nothing in the repo created the file, so on a project whose deploys succeed the guard never fired,
  the ledger never appeared, and S1's first-listed health source was permanently unresolvable. Phase 5
  now creates it, and specifies the row: the revision cell must be the platform's own selector (so
  `/rollback-deploy` step 3 can match it), the verdict cell must be the `monitor-deploy` result rather
  than the deploy tool's exit code, and `RED`/`INCOMPLETE` runs get a row too — "rev 41 was RED" is
  what stops the next rollback from targeting it. `/rollback-deploy` step 8 writes the same shape.
- **`@deployment-engineer` is dispatched.** Its frontmatter claimed it adjudicates `/deploy-stage`'s
  verdict; nothing invoked it. `/deploy-stage` Phase 6 now dispatches it, with a labelled
  `[self-adjudicated]` path when it is not installed. `@ci-reviewer` is likewise now dispatched by
  `/add-ci` Phase 6 on the workflow that command just generated.
- **Currency, structural fix.** Every pinned action version in the pack was 1-3 majors stale and the
  Node base image was EOL. Rather than re-pinning to today's numbers, the pack now teaches
  resolution: `gh api repos/<o>/<r>/releases/latest` per action, runtime majors from the vendor's
  published release schedule, and an explicit pin decision (branch ref never / mutable major /
  SHA + automated bumps). A correctly pinned EOL base is now named as a first-class defect.
- **Broken mechanisms fixed.** `dockerfile-lint`'s pin check (`grep -E ':(latest|[0-9]+)\s|@sha256'`)
  required whitespace after the tag, so `FROM node:latest AS build` PASSED — in a skill that requires
  multi-stage, i.e. in the normal case — while `FROM node:22-alpine` was reported unpinned. Its
  non-root check read the last `USER` anywhere in the file rather than the final stage's, a false
  PASS on the one thing it exists to catch. Both replaced with classifiers, verified against
  multi-stage fixtures.
  `/dockerize`'s smoke test ran the healthcheck in a container where `CMD` was overridden so the
  server never started, with no `--name` to read logs from. `progressive-delivery`'s flag-reference
  grep used `--include='*.{ts,js,...}'`, which does not brace-expand, so every flag reported DEAD.
  `gitops-audit`'s prune greps hung on empty input.
- **`gitops-audit` prune safety corrected.** It named `prune-propagation` (not a field) and treated
  `ignoreDifferences` / `FailOnSharedResource` as prune guards. The real controls are
  `automated.allowEmpty` (default `false` — the finding is an explicit `true`), `PruneLast=true`,
  and `PrunePropagationPolicy`.
- **`dockerfile-lint` HEALTHCHECK rationale corrected.** It claimed a missing HEALTHCHECK degrades
  Kubernetes probes; kubelet never reads the image's HEALTHCHECK. Severity now depends on the
  runtime, and BuildKit checks (`# syntax=`, cache mounts, `--mount=type=secret` over `ARG`) were added.
- **`release-security`** leads with `cosign attest --type cyclonedx`; `cosign attach` is deprecated
  (cosign declares it removed in v4.0.0) and is the weaker control regardless.
- **`ai-patterns/deployment.md` no longer contradicts the rule.** "Two patterns — pick ONE … NEVER
  mix" is replaced by a classification (additive / destructive / decomposition) plus the
  expand-contract sequence, which is deliberately both. The unsourced "Friday deploys have an
  empirically high rollback rate" is replaced with the argument that actually holds.
- **Rule shrink: devops-principles 4,969 → 3,327 chars (~1,242 → ~831 tok, -33%).** Review checklist
  moved to `ai-patterns/deployment.md`, Enforcement toolbox to `ai-patterns/cicd-pipeline.md`, vendor
  lists dropped, two skill-restating paragraphs compressed to one line each. Two new Must-nots added
  (untrusted CI-context interpolation; liveness depending on a downstream). `scripts/_rule-budget-baseline.txt`
  needs re-recording.
- **Essentials fixed.** `--minimal` shipped `/deploy-stage` without `monitor-deploy` or
  `/rollback-deploy`, so its gate was structurally unreachable and every minimal deploy exited
  INCOMPLETE. Both are now essentials.
- Fallback gap closed: the `deployment-engineer` fallback regained the entire S1-S5 Safe-Delivery
  verdict, and all three agent fallbacks regained their `## Related` sibling-boundary sections.

## 1.5.0 — 2026-07-10

- deploy-stage Safe-Delivery Gate: five evidence-bearing dims (S1 rollback resolved+exercised · S2
  health/readiness · S3 resource limits · S4 no plaintext secrets · S5 reproducible), unmet →
  INCOMPLETE.
- deployment-engineer: matching S1-S5 verdict with copy-pasteable grep detectors.

## 1.4.0 — 2026-07-10

- skills +2: progressive-delivery (feature-flag lifecycle + automated canary-analysis gate) and
  gitops-audit (git->cluster reconciliation discipline, drift, no out-of-band kubectl, no plaintext
  secrets).

## 1.3.0 — 2026-07-09

- NEW skills/release-security.md (kind:skill, dockerfile_detected) — image CVE scan (trivy image
  --severity HIGH,CRITICAL --ignore-unfixed) + SBOM (syft CycloneDX) + digest signing (cosign,
  keyless via CI OIDC) + SLSA provenance + verify-at-admission; EPSS/KEV triage; full runner spine
  (Premise/Prerequisites/Procedure/Output/gotchas/When-to-run/Halt). Explicitly disjoint from
  deps-audit (manifest layer) and dockerfile-lint (Dockerfile). Registered in _topics + _essentials;
  abridged _examples/release-security.md.
- Wired release-security into commands/dockerize.md (post-build release dispatch) +
  commands/add-ci.md (docker-build release-security step: trivy scan + syft SBOM + cosign keyless
  sign + provenance). Closes the enforcement-theater the security-auditor A03 check opened — the
  audit now dispatches to a real producer.

## 1.2.0 — 2026-06-22

- Sync-chain repair: _topics.md now declares deploy-stage and rollback-deploy as commands
  (kind:command, deploy_target_detected trigger). Both shipped under commands/ but were absent from
  the topic list, so /setup-project AUTHOR-mode generation silently dropped them. No _examples/
  stubs exist, so the fallbacks point at the live sources (commands/deploy-stage.md,
  commands/rollback-deploy.md).
- Version record now reflects the long-tail audit fixes already landed in pack content (add-ci
  security + coverage job, app-code stub scan) that had not been version-stamped.
