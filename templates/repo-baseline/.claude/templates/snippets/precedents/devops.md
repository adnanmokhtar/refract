# Precedents — DevOps (pipeline integrity, cache, release, deploy, environment parity, containers, compose)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 and § 10 for
every candidate in a **delivery-integrity** class: with no attacker involved, the pipeline's own
semantics let a red build merge, ship what was not tested, cancel or race a mutating deploy, drop
in-flight work at shutdown, or leave no rollback target. The oracles that prove them are in
[`proof-oracles.md`](../proof-oracles.md) § DevOps (V209–V243). The platform facts every verdict
cites (default shells, skip semantics, concurrency, default timeouts) are in
[`ci-platform-semantics.md`](../ci-platform-semantics.md). The job graph comes from
`.claude/scripts/ci-graph.py`. The detectors are `pipeline-integrity-scan`, `pipeline-cache-scan`,
`release-integrity-scan`, `deploy-safety-scan`, `container-build-scan` and `compose-scan` (devops
pack), judged by `@ci-reviewer` (pipeline rows) and `@deployment-engineer` (release, deploy,
container and compose rows).

**An attacker-path claim is not a devops claim.** "Someone outside the trust boundary reaches code
execution, a token, a secret or the published artifact" goes through
[`finding-verification.md`](../finding-verification.md) to the security pack (`ci-security-scan`,
`iac-scan`) when it is installed (§ 1).

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening** (or Refuted, where the entry says so); the flip
evidence makes it a candidate again. A precedent applies only when its "must be true" clause is
shown with a `file:line`, a `ci-graph.py` row or a `gh api` line. Numbers are stable: detectors cite
`precedents/devops.md § <n>`.

Index: the claim and the gates · posting rules § 1–6 · pipeline § 7–16 · release § 17–21 · deploy
§ 22–28 · containers and compose § 29–40 · tools and versions § 41–46 · rationalizations.

## The claim, restated

§ 1 of the protocol takes this shape here. A candidate that fits it with no concrete value is not a
finding.

> When **[the event that really happens: a failing test, a second push during a deploy, a re-run
> of the release, a SIGTERM during a rollout, a cold start of N replicas, a docs-only PR, a registry
> cleanup]** reaches **[the unit: the required job, the deploy step, the publish step, the
> container's PID 1, the migration runner, the compose service]**, **[the config at file:line]**
> **[lets a red build merge / ships an artifact that was not tested / cancels or races a mutating
> deploy / drops in-flight work / leaves no rollback target / builds green from a drifted
> lockfile]**, proven by **[the oracle and its tier]**.

**The proof rule.** A grep hit is a candidate, and a `ci-graph.py` row is a structural fact about the
files. The class oracle in `proof-oracles.md` § DevOps at its tier is the proof: T (`ci-graph.py` or
a tool's exit code), R (a sandbox run), B (a built image or a registry read), A (a settings API read)
or S (a static trace). A row that needs A with no token prints `UNREADABLE(gh api …: 403)` and stays
**Unconfirmed**; an R or B row with no docker daemon prints `blocked (no docker)` with the command
written out. Neither is ever `checked`.

## Reading the seven gates for DevOps

| Gate | DevOps |
|---|---|
| 1 Reachability | The workflow runs on the trigger that matters (the default branch, the required set, the deploy environment); the Dockerfile and stage are the ones CI builds (`--target`, compose `build.target`, bake); the compose file and overlay are the ones prod loads |
| 2 Trigger condition | The event occurs: a test can fail, two pushes land inside one deploy window, the release job is re-run, the orchestrator sends SIGTERM, the replica count is above one |
| 3 Version | Platform semantics and their date (`ci-platform-semantics.md`), action pins, the Helm major, the BuildKit frontend (`# syntax=`), runner and tool versions — each read from a file or a command, never recalled |
| 4 No existing control | An aggregator, a ruleset, an environment rule, an environment-keyed concurrency group in another workflow, a platform release phase, `tini` / `--init`, a runner lock, an admission policy |
| 5 Real impact | A red merge, an untested ship, a half-applied deploy, an outage at rollout, no rollback target. "Best practice" and speed alone fail here (speed is L, report-only) |
| 6 Proof | The oracle at its tier: T / R / B / A / S (above) |
| 7 Deployment and environment | Prod versus preview; which workflow is live (`gh api …/actions/workflows` `state`); which overlay or values file renders prod |

## Do not flag — posting rules the verifier applies

1. **A security-shaped claim is routed, never posted here.** An attacker path (injection, a privileged trigger with untrusted code, cache poisoning, pinning × privilege, OIDC width, secret exposure, runner trust) goes to the security pack (`ci-security-scan`, `iac-scan` § 5) when it is installed. Without it, the row is tagged `security-class (owner pack not installed)` at the devops severity, never graded as security would grade it.
2. **Gate-command masking on test, lint and a11y jobs is routed to its owner** — testing `suite-execution-scan` § 4 / § 6, code-quality `suppression-scan`, frontend `a11y-scan` § 7. This pack posts only the required-check join it supplies (`ci-graph.py --required`), which those owners read for severity.
3. **Infrastructure manifest fields and probe semantics are routed:** probe presence, shape and timing, `preStop`, `terminationGracePeriodSeconds`, resources, rollout shape and `revisionHistoryLimit` to infrastructure; a liveness handler that checks a shared dependency to performance `request-path-scan` § 15; readiness that lies to observability HC-01.
4. **Pre-existing lines.** On a diff run, a defect on lines the change neither touched nor copied is Pre-existing (`refute-before-report.md § 5`) and never blocks.
5. **One finding per unit.** A reusable workflow, a composite action, a GitLab template or `extends:` base, a shared Dockerfile base stage or a kustomize base is one finding with N call sites, fixed once in the unit.
6. **A settings finding cites the `gh api` line** (rules, rulesets, environments, workflows, caches). A 403 or 404 is `UNREADABLE`, never "absent"; GitLab settings likewise cite the `glab api` line.

## Not a finding — pipeline

7. **Masking on a job that is neither required nor a deploy ancestor.** `continue-on-error`, `allow_failure`, `|| true` on a job outside the required set and outside every `needs:` chain that reaches a deploy or publish job (`ci-graph.py --required --deploy-ancestors`). *Must be true:* the rules API was read. *Flips back:* the job is required, or an ancestor of a deploy; the rules API is unreadable → `[report-flagged]`, never cleared.
8. **`always()`, `failure()` and `!cancelled()` on cleanup, artifact-on-failure and notify steps**, and on an aggregator that checks `needs.*.result`. *Flips back:* the job deploys or publishes (`DEPLOY-ALWAYS`), or the aggregator does not read its needs' results.
9. **Job-level path filtering behind an `always()` aggregator** that treats skipped-by-design as success (the alls-green pattern, astral-sh/uv's "all required jobs passed"), and workflow-level `paths:` on a workflow none of whose jobs is required. *Flips back:* a path-filtered workflow emits a required context (`REQUIRED-PATH-FILTERED`): its check stays Pending and the PR waits, which teaches admin bypass.
10. **An aggregator is itself a finding** when its `if:` lacks `always()` (a failed need skips it, and a skipped required check is success) or it checks only `!= 'failure'` (a cancelled need passes). This entry never clears a candidate; it names the shape the aggregator in § 8 must have.
11. **`timeout-minutes` cannot be set on a `uses:` caller job.** The no-timeout finding belongs to the called workflow's jobs [K?: settle on the fixture]. `ci-graph.py --check=timeout` skips caller jobs for this reason.
12. **`continue-on-error: ${{ matrix.experimental }}` with `fail-fast: false`** on a declared-experimental leg (a nightly runtime). *Flips back:* the expression is true on a leg the project declares supported.
13. **`|| true` on idempotent cleanup** (`docker rm -f`, `pkill`, `rm -rf` of a scratch dir, a cache prune). *Flips back:* the masked command is the gate itself (a scan, a test, a migration check, a smoke test).
14. **A pipe on CircleCI's default shell** (`/bin/bash -eo pipefail`), a script that checks `PIPESTATUS`, and `grep -q` used as a condition. *Must be true:* the row of `ci-platform-semantics.md` for that platform and that step's effective shell (`ci-graph.py --shell-of`).
15. **`cancel-in-progress` on PR CI and per-PR previews.** Cancelling a superseded PR run is the intended behaviour. *Flips back:* the cancelled unit mutates shared state — a staging or prod deploy, `terraform apply`, a migration, a publish (`DEPLOY-CANCEL`).
16. **Retries scoped to infrastructure failure classes** (GitLab `retry: when: [runner_system_failure, stuck_or_timeout_failure]`, a retried registry pull). *Flips back:* `retry` with the default `when: always` or a retry wrapper around the test command (testing § 6 owns test retries).

## Not a finding — release

17. **Declared independent versioning.** A monorepo whose packages version separately (changesets `fixed`/`linked` absent by design, release-please per-package manifest) is not a split version source.
18. **`changeset publish` skipping already-published versions** is idempotent by design; so are `--skip-existing`, `--skip-duplicate` and goreleaser `keep-existing`.
19. **A per-architecture manifest list is one digest.** Promoting the index digest promotes every platform. A platform that cannot pull by digest, paired with an immutable tag (`immutable: true` release, ECR `IMMUTABLE`), is addressable. *Flips back:* the tag is mutable and is what deploys.
20. **A static SPA built per environment** when the per-env build is declared and deterministic (the same commit, lockfile and build command with only public config differing). *Flips back:* a server image is built per environment, or the build differs in more than the declared public config.
21. **An `--ignore-unfixed` (`--only-fixed`) scan PASS means "no fixable High/Critical".** The report says so; it is not "no vulnerabilities".

## Not a finding — deploy

22. **Migrate-on-boot with exactly one replica** (and no HPA `minReplicas` > 1) plus a runner that takes a lock, a leader gate (`RUN_MIGRATIONS=1` on one instance), or a platform release phase that runs once (Heroku `release:`, Fly `release_command`, Render `preDeployCommand`). *Must be true:* the replica count is read from the **render**, and the lock from the runner's version (the lock column of `deploy-safety-scan` § 1). *Flips back:* a second replica, an HPA, or a lockless runner.
23. **A GitOps CI that only commits manifests** (an image bump in a config repo): the deploy gate is the controller's health check, not a CI rollout wait. `gitops-audit` reads it.
24. **Preview and ephemeral environments** need no reviewer, no test gate, and may cancel freely, **unless** they hold prod credentials, prod data, or deploy to a shared namespace.
25. **Workers need SIGTERM checkpointing, not a `preStop` sleep.** A queue consumer with no inbound traffic is judged on whether in-flight jobs finish or return to the queue, not on endpoint propagation.
26. **Platform-set environment variables** (`PORT`, `HOSTNAME`, `KUBERNETES_*`, `CI`, `GITHUB_*`, `NODE_ENV` set by the image) are declared by the platform. A typed config schema validated at boot (a NestJS `ConfigModule` schema, pydantic `BaseSettings`, envalid) is the declaration of every key it lists.
27. **Permanent operational flags** (kill switches, maintenance mode) are not stale flags, and drift on a percentage ramp across environments is the ramp working.
28. **Declared synthetic-load canary analysis** (a canary judged on generated traffic by design) is a real gate when its check can fail (`proof-oracles.md` V232).

## Not a finding — containers and compose

29. **No HEALTHCHECK on a Kubernetes-only image** is a nit: the kubelet ignores it. It is a finding only where compose, Swarm or ECS gate on it.
30. **Distroless and scratch final stages** have no shell: an exec-form self-check with the app's own binary (`["/app", "healthcheck"]`), or none plus an orchestrator probe, is correct.
31. **A floating minor tag with a bump bot** (`node:22-bookworm-slim` with Renovate or Dependabot's `docker` manager, or a scheduled rebuild) beats a digest pin with no bot, which rots.
32. **DL3008 / DL3018 package-version pins** are not findings unless the repo claims reproducible builds: pins break when the distro drops a point release.
33. **Read the base image's user before an `INHERIT-EXTERNAL` row counts.** `crane config <ref> | jq -r .config.User`: nginx-unprivileged (101), distroless `:nonroot` and Chainguard (65532) and bitnami (1001) are non-root; the official `node` image is root by default.
34. **`COPY . .` after a manifest-first install** with a `.dockerignore` that covers `.git`, `.env*` and `node_modules` is correct layer order.
35. **Shell-form CMD on an alpine/busybox base ending in one command** is L: ash tail-execs it, so SIGTERM reaches the app (measured 0.1 s stop). Dash and bash bases keep M/H, with the measured stop time in the row (10.2 s → exit 137).
36. **`STOPSIGNAL SIGQUIT`** (nginx, php-fpm) **and `SIGWINCH`** (httpd) are those servers' graceful signals, not a misconfiguration.
37. **A numeric `USER`** (`USER 10001`) is the form Kubernetes `runAsNonRoot` can verify; a named user is not the fix (hadolint DL3066).
38. **Builder-stage findings count only for build-time classes** (a secret build arg, `curl | sh`, TLS verification disabled, an unpinned fetch, an unenforced lockfile). Runtime classes (USER, HEALTHCHECK, signals) are judged on the shipped stage only.
39. **Image size is judged against the repo's baseline** (`/dockerize` Phase 7, `THR-IMAGE-GROWTH`), never an absolute number.
40. **A dev-only compose file** (`compose.dev.yaml`, an override used only locally) drops one severity level for `compose-scan` § 1, § 3 and § 5. *Flips back:* a deploy script or CI step loads it on a server.

## Tools and versions — read at audit time

41. **A tool that errored, parsed nothing or could not reach the registry is NOT-RUN, never PASS**: a hadolint parse error (that file is unscanned), `docker build --check` with an unreachable registry, trivy with 0 targets, zizmor exit 3 (no inputs) or `--format=sarif` (exit 0 always), poutine without `--fail-on-violation`, octoscan given a directory, actionlint exit 3 (no project), `ci-graph.py` exit 2 (no YAML loader, a parse error, no workflow found).
42. **Helm 4 renamed `--atomic` to `--rollback-on-failure`** and changed the `--wait` behaviour [K?: re-read `helm upgrade --help` on the installed Helm; infrastructure's notes report v4.2.4]. A Helm 3 flag on a Helm 4 pipeline is a candidate, not a finding, until the installed major is read.
43. **The GitHub Actions `run:` default is `bash -e {0}` without pipefail; an explicit `shell: bash` adds `-o pipefail`** (GitHub Docs, *Workflow syntax*, fetched 2026-10-10). A pipe under the default masks the producer's exit; the same pipe under `shell: bash` does not.
44. **YAML 1.1 loaders read the `on:` key as boolean `true`** (PyYAML and Ruby psych, measured 2026-10-10). A script that looks up `d["on"]` sees no triggers and reports nothing; `ci-graph.py` remaps it, and any other YAML reader must too.
45. **`act` is not authoritative** for concurrency, environments, OIDC or the merge queue [K: re-check the limits on the installed act before an oracle cites it].
46. **A green `act` run, or a single green CI run, is not proof that a PC-* class is closed.** The seeded failure (`proof-oracles.md` V209, V212) is: one failing command per gate on a sandbox branch, every required context concluding `failure`.

## Rationalizations to reject (DevOps)

**Wrongly accepting:** "zizmor / actionlint / hadolint flagged it" (which rule, on which reachable
file, and is the class this pack's?) · "every job needs `timeout-minutes`" on a `uses:` caller ·
"pin every apt package" with no reproducibility claim · "no HEALTHCHECK" on a k8s-only image ·
"cancel-in-progress is dangerous" on PR CI · "migrate-on-boot is always wrong" with one replica and
a locking runner · "the image is 900 MB" with no baseline.

**Wrongly dismissing:** "CI is green, so the gate works" (seed a failure) · "the deploy has
`needs:`" (with `if: always()` it runs anyway) · "it built, so the Dockerfile is fine" · "exec
form, so signals work" (no handler as PID 1: 10 s, then exit 137) · "we have a HEALTHCHECK" (inert
on Kubernetes) · "the scan passed" (on which digest — the one pushed?) · "rollback = redeploy the
previous tag" (a mutable tag, or a pruned digest) · "we cancel stale runs" (on a deploy).

---

Sources: the devops research catalog (2026-10-10) and its notes — C § 1 (platform semantics, GitHub
Docs *Workflow syntax* and *Troubleshooting required status checks*, GitLab CI YAML reference,
CircleCI and Atlassian support pages, all fetched 2026-10-10), C § 4–§ 6 (precedents 1–12), B § 4
(P-1…P-18, with the measured `docker stop` matrix on node:22 alpine and bookworm-slim), and the
batch-4 devops eval (2026-10-10), which renumbered them and verified the `on:` remap (P6) and the
stage-chain user resolution (P2). Paraphrased; no text reproduced beyond short quoted identifiers.
