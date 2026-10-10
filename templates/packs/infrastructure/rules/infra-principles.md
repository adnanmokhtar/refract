---
paths:
  - "**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs,vue,svelte,astro}"
  - "**/*.{py,pyi,rb,php,go,rs,java,kt,kts,scala,groovy,cs,fs,vb,swift,m,mm,dart}"
  - "**/*.{ex,exs,erl,hrl,clj,cljs,cljc,hs,ml,elm,lua,pl,pm,r,R,jl,zig,nim,cr,c,h,cc,cpp,cxx,hpp}"
  - "**/*.{sql,prisma,graphql,gql,proto}"
  - "**/*.{html,htm,css,scss,sass,less,styl,pcss}"
  - "**/*.{erb,haml,slim,hbs,handlebars,ejs,njk,liquid,twig,cshtml,razor,jinja,jinja2,j2,mustache,pug,mjml,tex}"
  - "**/*.{yml,yaml,json,jsonc,json5,toml,ini,cfg,conf,properties,xml,env,plist,gradle}"
  - "**/{Dockerfile,Containerfile,Jenkinsfile,Procfile,Makefile,Vagrantfile,Caddyfile,Tiltfile}*"
  - "**/*.{dockerfile,tf,tfvars,hcl,nomad,sh,bash,ps1,nix,service}"
  - "**/{.github,.gitlab,.circleci,.buildkite,k8s,kubernetes,helm,charts,deploy,deployment,infra,infrastructure,terraform,pulumi,ansible,nginx,docker}/**"
paths-origin: pack-default-7bed019f
name: infra-principles
description: Infrastructure Principles
kind: rule
pack: infrastructure
severity: must
applies-to: infrastructure-track, every-code-writing-task-in-infrastructure
---

# Infrastructure Principles

> **Hard rule.** Production container images MUST be pinned to an immutable digest or git-SHA tag (`:latest` is forbidden); MUST run as non-root; MUST declare healthchecks, a CPU request, a memory request and a memory limit (a CPU limit is optional — see Must). Secrets MUST come from a manager (not git, not env files in images), and every stateful workload MUST have a tested backup + restore runbook.

## Must

- Match complexity to need. A VM + a process supervisor + a reverse proxy is valid infrastructure for many products. K8s is justified by real pain (multi-team, multi-env, > 5 services), not resume gravity.
- Multi-stage build: the runtime stage carries the artifact and its runtime deps — no compiler, no package manager, no source tree.
- Non-root container user; read-only root filesystem where the app allows it.
- Images pinned to an immutable reference in prod — `@sha256:…` or a git-SHA tag, never a moving tag.
- Healthcheck at every layer: image healthcheck, orchestrator liveness + readiness (+ startup for slow boots), load-balancer health. No readiness probe means traffic hits a dead pod mid-deploy.
- A CPU request, a memory request and a memory limit on every container, init and sidecar containers included. No request: the scheduler over-packs the node, the pod is evicted first under pressure, and an autoscaler targeting that resource never scales. No memory limit: one leak takes the node's memory from its neighbours. Keep the memory limit equal to the request unless a measured profile says otherwise. A missing CPU **limit** is not a defect: CPU requests already guarantee each neighbour its share, and a limit throttles a request-serving process while the node sits idle. Set one only for a noisy batch neighbour, or equal to the request where CPU-manager pinning needs Guaranteed QoS (infrastructure precedent 1).
- TLS everywhere, service-to-service included, auto-renewed.
- Secrets from a manager, mounted as files rather than env vars — env is readable from `/proc/<pid>/environ`, crash dumps, and every child process.
- Persistent data on a managed store or object storage, never on container-local disk.
- Every stateful production store: automated backups + point-in-time recovery + a restore drilled on a fixed cadence + a declared RPO/RTO. Backup config with no fresh drill is BLOCK, never ready — `dr-audit` verifies the coverage.
- Every ingress path intentional and least-exposed: no `0.0.0.0/0` (or `::/0`) on non-public ports, datastores in private subnets, default-deny `NetworkPolicy` per namespace — `network-exposure-audit` sweeps the running and declared footprint.
- Resolve versions from the vendor, not from memory. Supported orchestrator minors, provider majors, runtime LTS windows and controller support status all move on a published schedule; a version recalled rather than looked up is how a manifest ships a removed API or an unpatched base.

## Must not

- Commit secrets to git, even base64-encoded. Scanners find them; so do attackers.
- Apply IaC or cluster changes from a developer laptop against prod. Use CI, with an audit trail.
- Grant wildcard cluster roles (`*` verbs / `*` resources) to a service account.
- Leave a single point of failure on a revenue-critical path. Multi-AZ at minimum; multi-region only if the SLO demands it.
- Run a horizontal autoscaler without `min` + `max`. Unbounded up is bill shock; unbounded down is a cold start at peak.

## Should

- All infrastructure defined as code, reviewed in PRs like app code, linted in CI, with the provider lock file committed so a plan is reproducible.
- Drift detection: a scheduled `plan` alerts on any diff vs main.
- Image vulnerability scan in CI blocking on critical CVEs — and the signature it produces verified at admission, not merely generated (`release-security` signs, `admission-policy` enforces).
- A PodDisruptionBudget on every served workload that runs at least two replicas (count the HPA or KEDA floor, not `spec.replicas`), with `maxUnavailable: 1` or a `minAvailable` below that floor, so a drain cannot take every replica at once. Never put a PDB on a single replica: it pins `disruptionsAllowed` at zero and blocks every drain and node upgrade. Run a second replica or accept the disruption. DaemonSets need none.
- Cost guardrails: per-environment budget alerts, non-prod auto-shutdown overnight, object-storage lifecycle to a cheaper tier then expiry.

Enforcement tooling is named in `STACK.md § Enforcement tooling`, not here — tools churn (two of the four manifest validators this rule used to name are unmaintained or dead); these rules do not.
