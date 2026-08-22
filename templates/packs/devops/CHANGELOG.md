# devops pack — changelog

Release history for `templates/packs/devops/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

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
